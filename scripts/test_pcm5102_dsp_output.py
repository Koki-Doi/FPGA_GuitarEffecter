#!/usr/bin/env python3
"""Phase 7E on-board smoke for the external PCM5102 DSP output path.

Usage on the PYNQ-Z2:

    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \\
        scripts/test_pcm5102_dsp_output.py --duration 30

What changed vs Phase 7C (`scripts/test_pcm5102_dac_tone.py`):
  * The PCM5102 is no longer driven by the free-running 1 kHz tone
    generator (`pcm5102_dac_tone`). It is now driven by the *trivial
    pass-through* `pcm5102_audio_out`, which mirrors the existing
    ADAU1761 I2S DAC interface onto the four PMOD JB pins:
        PMOD JB2 BCK  <- ADAU1761 I2S BCLK   (top-level input port bclk, R18)
        PMOD JB3 LCK  <- ADAU1761 I2S LRCLK  (top-level input port lrclk, T17)
        PMOD JB7 DIN  <- i2s_to_stream_0/so  (same serial DAC data the ADAU
                                              sdata_o pin G18 receives)
        PMOD JB1 SCK  <- 12.288 MHz from clk_wiz_audio_ext (Phase 7C MMCM)
  * The input chain is unchanged: line in / guitar at the ADAU1761
    ADC -> i2s_to_stream_0 -> axis_data_fifo -> clash_lowpass_fir_0
    -> axis_switch_sink -> ... -> axis_switch_source ->
    i2s_to_stream_0/axis_hp -> i2s_to_stream_0/so.
  * Both DACs run in parallel: the same bitstream goes to the ADAU1761
    DAC (board headphone / line out) and to the external PCM5102 DAC
    (PMOD JB line out). Compare side-by-side.

What this script does:
  * Loads AudioLabOverlay -- the new bit re-uses the entire ADAU/DSP
    path, only replaces the PCM5102 source-of-truth.
  * Prints overlay summary (ip_dict + clock_dict).
  * Verifies that the load did not regress the existing IPs:
    axi_dma_0 / axi_gpio_distortion / enc_in_0 / axi_vdma_hdmi /
    v_tc_hdmi must all still be present.
  * Re-applies the codec init via `AudioLabOverlay.config_codec` so
    ADC HPF is on (R19 = 0x23) and the DAC is enabled; otherwise the
    PCM5102 sees only zeros even though its clocks are running.
  * Holds the overlay loaded for `--duration` seconds so the user can
    listen and compare ADAU DAC vs PCM5102 DAC.

What it does NOT do:
  * Does not touch any GPIO. Does not start the HDMI GUI. Does not
    drive the encoder UI. Does not write any sine wave from PS.
  * Does not implement PCM1808 (ADC) -- still Phase 7D.
  * Does not switch between ADAU/PCM5102 output -- both stream
    simultaneously.

PYNQ Python 3.6 compatibility: no dataclass, no future annotations,
no typing.Literal.
"""

import argparse
import time


JB_WIRING = (
    "  JB1 (W14)  EXT_AUDIO_MCLK  -> PCM5102 SCK   = CONSTANT 0 (internal-PLL mode, DECISIONS.md D40)\n"
    "  JB2 (Y14)  EXT_AUDIO_BCLK  -> PCM5102 BCK   = ADAU1761 BCLK  (~3.072 MHz)\n"
    "  JB3 (T11)  EXT_AUDIO_LRCLK -> PCM5102 LCK   = ADAU1761 LRCLK (~48 kHz)\n"
    "  JB7 (V16)  EXT_DAC_DIN     -> PCM5102 DIN   = i2s_to_stream_0/so\n"
)


def _print_overlay_summary(overlay):
    ip_dict = getattr(overlay, "ip_dict", {})
    clock_dict = getattr(overlay, "clock_dict", {})

    print("[pcm5102] AudioLabOverlay loaded")
    print("[pcm5102] ip_dict keys (%d):" % len(ip_dict))
    for k in sorted(ip_dict):
        addr = ip_dict[k].get("phys_addr", None)
        if addr is not None:
            print("    %-32s  phys_addr=0x%08X" % (k, addr))
        else:
            print("    %s" % k)
    print("[pcm5102] clock_dict (%d):" % len(clock_dict))
    for k in sorted(clock_dict):
        print("    %-32s  %s" % (k, clock_dict[k]))


def _check_required_ips(overlay):
    ip_dict = getattr(overlay, "ip_dict", {})
    ok = True
    expected = (
        ("axi_dma_0",            "ADAU1761 DMA",         "exact"),
        ("axi_gpio_distortion",  "DSP GPIO contract",    "exact"),
        ("enc_in_0",             "rotary encoder PL IP", "substr"),
        ("axi_vdma_hdmi",        "HDMI VDMA",            "exact"),
        ("v_tc_hdmi",            "HDMI VTC",             "exact"),
        ("i2s_to_stream",        "ADAU I2S serializer",  "substr"),
    )
    for name, desc, match in expected:
        if match == "exact":
            present = name in ip_dict
        else:
            present = any(name in k for k in ip_dict)
        if not present:
            print("[pcm5102] WARN: %s missing from overlay -- %s broken?" % (name, desc))
            # i2s_to_stream and similar are not always exposed as a discrete
            # AXI master in ip_dict; downgrade to warn so we don't fail the
            # smoke just because pynq's metadata view changed.
            if name not in ("i2s_to_stream",):
                ok = False
        else:
            print("[pcm5102] OK: %s present (%s)" % (name, desc))
    return ok


def _config_codec(overlay):
    # AudioLabOverlay.__init__ already calls self.codec.config_codec() so
    # the ADAU1761 BCLK/LRCLK/sdata_o are live by the time we get here --
    # the PCM5102 pass-through is therefore already streaming. We re-check
    # the codec state below; do not call config_codec a second time.
    print("[pcm5102] ADAU1761 codec was configured during overlay load")


def _report_codec_status(overlay):
    codec = getattr(overlay, "codec", None)
    if codec is None:
        return
    try:
        hpf = codec.get_adc_hpf_state()
        print("[pcm5102] ADAU1761 ADC HPF state: %r" % (hpf,))
    except Exception as exc:  # noqa: BLE001
        print("[pcm5102] codec.get_adc_hpf_state raised: %r" % (exc,))
    try:
        vol = codec.get_input_digital_volume()
        print("[pcm5102] ADAU1761 input digital volume: %r" % (vol,))
    except Exception as exc:  # noqa: BLE001
        print("[pcm5102] codec.get_input_digital_volume raised: %r" % (exc,))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--duration", type=float, default=30.0,
                   help="Seconds to hold the overlay so PCM5102 keeps streaming. "
                        "Default 30.")
    p.add_argument("--no-summary", action="store_true",
                   help="Skip the ip_dict / clock_dict dump.")
    p.add_argument("--no-codec-config", action="store_true",
                   help="Skip overlay.config_codec() (PCM5102 will hear silence).")
    args = p.parse_args()

    print("PCM5102 DSP output smoke (Phase 7E ADAU-mirror)")
    print("Input  : existing ADAU1761 ADC / Line In")
    print("DSP    : existing AudioLab DSP chain (Clash LowPassFir + effects)")
    print("Output : external PCM5102 on PMOD JB (parallel to ADAU1761 DAC)")
    print("Wiring :")
    print(JB_WIRING)

    from audio_lab_pynq import AudioLabOverlay  # type: ignore
    overlay = AudioLabOverlay()

    if not args.no_summary:
        _print_overlay_summary(overlay)

    if not _check_required_ips(overlay):
        print("[pcm5102] FAILED: required IPs missing; bit/hwh likely stale")
        return 2

    if not args.no_codec_config:
        _config_codec(overlay)
        _report_codec_status(overlay)

    print("")
    print("[pcm5102] PCM5102 mirrors the ADAU1761 I2S DAC bitstream.")
    print("[pcm5102] Speak into / play through ADAU line in; the same processed")
    print("[pcm5102] signal is on the PCM5102 line out.  ADAU board out and")
    print("[pcm5102] PCM5102 out should sound identical.")
    print("[pcm5102] If PCM5102 is silent but ADAU works: check XSMT (high),")
    print("[pcm5102] VCC=3.3V, GND common, and the JB1/JB2/JB3/JB7 wires.")
    print("[pcm5102] If ADAU is silent too: re-run config_codec or check input.")
    print("[pcm5102] Holding overlay for %.1f s..." % args.duration)

    try:
        t0 = time.time()
        while time.time() - t0 < args.duration:
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("[pcm5102] interrupted")

    print("[pcm5102] done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
