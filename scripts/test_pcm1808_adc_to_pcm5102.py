#!/usr/bin/env python3
"""Phase 7D on-board smoke for the PCM1808 ADC -> AudioLab DSP -> PCM5102 DAC
end-to-end external-codec path.

Usage on the PYNQ-Z2:

    # passive listen (no signal injection, no capture)
    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \\
        scripts/test_pcm1808_adc_to_pcm5102.py --duration 60

    # ** OUTPUT-SIDE ONLY ** verify PCM5102 alive independent of PCM1808:
    #   DMA -> i2s_to_stream_0/axis_hp -> i2s_to_stream_0/so -> PCM5102 DIN
    #   (PCM1808 / mux completely bypassed for the duration of the tone)
    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \\
        scripts/test_pcm1808_adc_to_pcm5102.py --inject-sine

    # ** INPUT-SIDE ONLY ** capture whatever PCM1808 DOUT is feeding the
    #   mux + i2s_to_stream_0/si and print stats. With Phase 7D bit
    #   (sel_external_i = 1) this captures PCM1808.  Useful to tell apart:
    #     mean ~ 0 and std ~ 0       -> PCM1808 sending pure zeros
    #     mean ~ 0 and std small     -> PCM1808 alive, noise floor only
    #     mean far from 0            -> bit alignment / format mismatch
    #     std large                  -> PCM1808 picking up the loopback
    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \\
        scripts/test_pcm1808_adc_to_pcm5102.py --capture-adc

    # both diagnostics back to back
    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \\
        scripts/test_pcm1808_adc_to_pcm5102.py --inject-sine --capture-adc

What this bit does (DECISIONS.md D41):
  * Input pin JB4 (T10) reads PCM1808 DOUT and feeds it through the new
    `pcm1808_input_select` wire mux into the existing `i2s_to_stream_0/si`
    pin. The mux's select line is tied to 1 by an xlconstant in the
    integration tcl, so PCM1808 is the active ADC source. ADAU1761 ADC
    (sdata_i / F17) is left wired into the mux's other input and can be
    re-selected by flipping the constant to 0 and rebuilding.
  * BCK (JB2 / Y14) and LRCK (JB3 / T11) are shared with PCM5102 -- both
    chips slave off the ADAU1761 PLL via the existing ADAU I2S clocks.
  * SCKI (JB1 / W14) is the 12.288 MHz output of `clk_wiz_audio_ext`
    that Phase 7C added (no longer driven to GND; PCM5102 SCK is now
    physically tied to GND on the module so re-driving JB1 only feeds
    PCM1808 SCKI).
  * Output side is unchanged: i2s_to_stream_0/so still drives the ADAU
    DAC pin and is mirrored to PMOD JB7 (PCM5102 DIN) via the Phase 7E
    pcm5102_audio_out pass-through.

Known caveat baked into this bit (DECISIONS.md D41):
  * The 12.288 MHz SCKI is NOT bit-true synchronous to ADAU's BCK
    (separate PLLs). PCM1808 does not have a PCM510x-style SCKI-free
    fallback, so async clocks may produce noisy / unlocked output. If
    the bench shows graininess like Phase 7E's pre-fix PCM5102 audio,
    the next step is to make the FPGA the I2S master.

Smoke checks performed:
  * AudioLabOverlay loads (no overlay regression).
  * `axi_dma_0`, `axi_gpio_distortion`, `enc_in_0`, `axi_vdma_hdmi`,
    `v_tc_hdmi` all still present in ip_dict (existing peripherals intact).
  * ADAU1761 codec was configured by the overlay (ADC HPF True / R19=0x23
    inherited from D1) so BCLK / LRCLK are running for PCM1808 to clock on.
  * `pcm1808_input_select`, `pcm5102_audio_out`, `clk_wiz_audio_ext`, and
    `adc_sel_const` are not expected in ip_dict (they have no AXI).
  * Holds the overlay loaded for the requested duration so the user can
    feed audio in and listen on PCM5102 line out.

PYNQ Python 3.6 compatibility: no dataclass, no future annotations,
no typing.Literal.
"""

import argparse
import time


JB_WIRING = (
    "  JB1 (W14)  EXT_AUDIO_MCLK    = constant 0 (D40 SCK-low preserved)\n"
    "  JB2 (Y14)  EXT_AUDIO_BCLK    -> PCM1808 BCK + PCM5102 BCK = ADAU BCLK\n"
    "  JB3 (T11)  EXT_AUDIO_LRCLK   -> PCM1808 LRCK + PCM5102 LCK = ADAU LRCLK\n"
    "  JB4 (T10)  EXT_ADC_DOUT      <- PCM1808 DOUT  (Phase 7D input)\n"
    "  JB7 (V16)  EXT_DAC_DIN       -> PCM5102 DIN   = i2s_to_stream_0/so\n"
    "  JB8 (W16)  EXT_PCM1808_SCKIE -> PCM1808 SCKI  = 12.288 MHz (D42 dedicated pin)\n"
    "  PCM5102 SCK -> GND (NOT JB1, NOT JB8).\n"
    "  PCM1808 FMT / MD0 / MD1 -> strapped to I2S slave mode on the module.\n"
)


def _print_overlay_summary(overlay):
    ip_dict = getattr(overlay, "ip_dict", {})
    print("[pcm1808] AudioLabOverlay loaded")
    print("[pcm1808] ip_dict keys (%d):" % len(ip_dict))
    for k in sorted(ip_dict):
        addr = ip_dict[k].get("phys_addr", None)
        if addr is not None:
            print("    %-32s  phys_addr=0x%08X" % (k, addr))
        else:
            print("    %s" % k)


def _check_required_ips(overlay):
    ip_dict = getattr(overlay, "ip_dict", {})
    ok = True
    expected = (
        ("axi_dma_0",            "ADAU1761 DMA",         "exact"),
        ("axi_gpio_distortion",  "DSP GPIO contract",    "exact"),
        ("enc_in_0",             "rotary encoder PL IP", "substr"),
        ("axi_vdma_hdmi",        "HDMI VDMA",            "exact"),
        ("v_tc_hdmi",            "HDMI VTC",             "exact"),
    )
    for name, desc, match in expected:
        if match == "exact":
            present = name in ip_dict
        else:
            present = any(name in k for k in ip_dict)
        if not present:
            print("[pcm1808] ERROR: %s missing from overlay -- %s broken?" % (name, desc))
            ok = False
        else:
            print("[pcm1808] OK: %s present (%s)" % (name, desc))
    return ok


def _report_codec_status(overlay):
    codec = getattr(overlay, "codec", None)
    if codec is None:
        print("[pcm1808] overlay.codec not present; cannot read ADAU state")
        return
    try:
        hpf = codec.get_adc_hpf_state()
        print("[pcm1808] ADAU1761 ADC HPF state          : %r" % (hpf,))
    except Exception as exc:  # noqa: BLE001
        print("[pcm1808] codec.get_adc_hpf_state raised  : %r" % (exc,))
    try:
        vol = codec.get_input_digital_volume()
        print("[pcm1808] ADAU1761 input digital volume   : %r" % (vol,))
    except Exception as exc:  # noqa: BLE001
        print("[pcm1808] codec.get_input_digital_volume raised : %r" % (exc,))


def _inject_sine(overlay, freq_hz, duration_s, amplitude_dbfs):
    """Bypass the input chain by routing DMA -> passthrough -> i2s_to_stream_0
    -> PCM5102 DIN. If a tone is heard on PCM5102 line out, the entire output
    side (PCM5102 + JB1/2/3/7 wiring + i2s_to_stream_0 + Xbar) is alive and
    any "no audio" issue is on the PCM1808 input side."""
    print("[pcm1808] --inject-sine: DMA -> i2s_to_stream_0 -> PCM5102")
    print("[pcm1808]   freq=%.1f Hz duration=%.1f s amplitude=%.1f dBFS"
          % (freq_hz, duration_s, amplitude_dbfs))
    print("[pcm1808]   PCM1808 / pcm1808_input_select / sdata_i are bypassed")
    print("[pcm1808]   for the duration of this tone (route restored after).")
    try:
        overlay.output_sine_test(freq_hz=freq_hz, duration_s=duration_s,
                                 amplitude_dbfs=amplitude_dbfs)
        print("[pcm1808]   inject-sine completed")
    except Exception as exc:  # noqa: BLE001
        print("[pcm1808]   output_sine_test raised: %r" % (exc,))


def _capture_adc(overlay, num_frames):
    """Capture whatever is currently feeding i2s_to_stream_0/si. With the
    Phase 7D mux selecting PCM1808, this captures PCM1808 DOUT. Prints
    simple stats so we can tell silence vs noise vs DC offset vs bit-shift."""
    print("[pcm1808] --capture-adc: capturing %d frames (~%.2f s)"
          % (num_frames, num_frames / 48000.0))
    print("[pcm1808]   route is forced to line_in -> passthrough -> DMA")
    print("[pcm1808]   so PCM5102 hears the captured signal directly too.")
    try:
        samples, stats = overlay.diagnostic_capture(
            "pcm1808_loopback", num_frames=num_frames,
            settling_ms=200, discard_initial_frames=4800)
        # diagnostic_capture already prints stats; also print a coarser
        # bit-alignment hint that is most useful for PCM1808 bring-up.
        try:
            import numpy as _np  # type: ignore
            arr = _np.asarray(samples)
            if arr.ndim == 2 and arr.shape[1] >= 2:
                l = arr[:, 0].astype("int64")
                r = arr[:, 1].astype("int64")
                print("[pcm1808]   L: min=%d max=%d mean=%.1f abs_max=%d"
                      % (l.min(), l.max(), float(l.mean()), int(abs(l).max())))
                print("[pcm1808]   R: min=%d max=%d mean=%.1f abs_max=%d"
                      % (r.min(), r.max(), float(r.mean()), int(abs(r).max())))
                # crude shift hint: top byte should swing for a healthy 24-bit
                # sample reaching i2s_to_stream_0; if it never moves, the
                # interesting bits are landing somewhere PCM1808 doesn't drive.
                topl = (l >> 16).astype("int64")
                botl = (l & 0xFFFF).astype("int64")
                print("[pcm1808]   L top16 range=%d, low16 range=%d"
                      % (int(topl.max() - topl.min()),
                         int(botl.max() - botl.min())))
            else:
                print("[pcm1808]   captured shape unexpected: %r" % (arr.shape,))
        except Exception as exc:  # noqa: BLE001
            print("[pcm1808]   stats post-processing failed: %r" % (exc,))
        return samples, stats
    except Exception as exc:  # noqa: BLE001
        print("[pcm1808]   diagnostic_capture raised: %r" % (exc,))
        return None, None


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--duration", type=float, default=60.0,
                   help="Seconds to hold the overlay so PCM1808 -> PCM5102 keeps "
                        "streaming. Default 60.  Ignored when --inject-sine or "
                        "--capture-adc is given alone.")
    p.add_argument("--no-summary", action="store_true",
                   help="Skip the ip_dict dump.")
    p.add_argument("--inject-sine", action="store_true",
                   help="Bypass PCM1808 / mux and play a DMA-driven sine "
                        "out of PCM5102. Confirms the output side is alive "
                        "independent of the input.")
    p.add_argument("--sine-freq", type=float, default=1000.0,
                   help="--inject-sine frequency in Hz (default 1000).")
    p.add_argument("--sine-duration", type=float, default=3.0,
                   help="--inject-sine duration in seconds (default 3).")
    p.add_argument("--sine-amplitude-dbfs", type=float, default=-18.0,
                   help="--inject-sine amplitude in dBFS (default -18).")
    p.add_argument("--capture-adc", action="store_true",
                   help="Capture i2s_to_stream_0 input samples (PCM1808 DOUT "
                        "under Phase 7D mux) and print stats. Diagnoses "
                        "whether PCM1808 is sending zeros / DC / noise / "
                        "actual signal.")
    p.add_argument("--capture-frames", type=int, default=48000,
                   help="--capture-adc number of frames (default 48000 = 1 s).")
    args = p.parse_args()

    print("PCM1808 ADC -> AudioLab DSP -> PCM5102 DAC smoke (Phase 7D)")
    print("Input  : external PCM1808 on PMOD JB4 (build-time mux default = PCM1808)")
    print("DSP    : existing AudioLab DSP chain (Clash LowPassFir + effects)")
    print("Output : external PCM5102 on PMOD JB (parallel to ADAU1761 DAC,")
    print("         PCM5102 SCK hard-tied to GND on the module, DECISIONS.md D40)")
    print("Wiring :")
    print(JB_WIRING)

    from audio_lab_pynq import AudioLabOverlay  # type: ignore
    overlay = AudioLabOverlay()

    if not args.no_summary:
        _print_overlay_summary(overlay)

    if not _check_required_ips(overlay):
        print("[pcm1808] FAILED: required IPs missing; bit/hwh likely stale")
        return 2

    _report_codec_status(overlay)

    if args.inject_sine:
        print("")
        _inject_sine(overlay, args.sine_freq, args.sine_duration,
                     args.sine_amplitude_dbfs)

    if args.capture_adc:
        print("")
        _capture_adc(overlay, args.capture_frames)

    # If the user asked for diagnostics only, skip the passive hold loop.
    if args.inject_sine or args.capture_adc:
        print("[pcm1808] diagnostics done; exiting (skip passive hold)")
        return 0

    print("")
    print("[pcm1808] PCM1808 line-in -> AXIS DSP -> PCM5102 line out")
    print("[pcm1808] Feed a line-level source into PCM1808 (NOT a guitar")
    print("[pcm1808] directly -- it is not Hi-Z). Effects toggled via the")
    print("[pcm1808] notebook or encoder GUI should change the PCM5102 sound.")
    print("[pcm1808] If silent: check PCM1808 VCC / GND, mode strap (I2S")
    print("[pcm1808] slave), JB4 DOUT wire, and that BCK / LRCK / SCKI are")
    print("[pcm1808] reaching the module on JB2 / JB3 / JB1.")
    print("[pcm1808] If noisy / grainy: see DECISIONS.md D41 -- the SCKI is")
    print("[pcm1808] not bit-true synchronous to BCK; the next step is to")
    print("[pcm1808] make the FPGA the I2S master.")
    print("[pcm1808] Holding overlay for %.1f s..." % args.duration)

    try:
        t0 = time.time()
        while time.time() - t0 < args.duration:
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("[pcm1808] interrupted")

    print("[pcm1808] done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
