#!/usr/bin/env python3
"""Phase 7C on-board smoke for the external PCM5102 DAC bring-up.

Usage on the PYNQ-Z2:

    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \\
        scripts/test_pcm5102_dac_tone.py --duration 30

What this script does:
  * Loads AudioLabOverlay (the new bit has the pcm5102_dac_tone module wired
    to PMOD JB; the module starts emitting tone the moment its reset is
    released, which happens at overlay download time).
  * Prints the overlay ip_dict / clock_dict to confirm:
      - clk_wiz_audio_ext is present and reports 12.288 MHz
      - pcm5102_dac_0 module reference is present (no AXI registers expected)
      - existing audio path (axi_dma_0, i2s_to_stream_0, clash_lowpass_fir_0,
        axi_gpio_*, axi_encoder_input, axi_vdma_hdmi, v_tc_hdmi) is intact
  * Waits the requested duration so the user can listen / measure / probe
    JB1..JB7 with a logic analyser or scope.

What it does NOT do:
  * Does not write any GPIO. Does not touch ADAU1761. Does not touch HDMI.
  * Does not route the FPGA DSP output to the external DAC.
  * Does not enable PCM1808 (ADC) -- still Phase 7D.

PYNQ Python 3.6 compatibility: no dataclass, no `from __future__ import
annotations`, no typing.Literal.
"""

import argparse
import time


JB_WIRING = (
    "  JB1 (W14)  EXT_AUDIO_MCLK  -> PCM5102 SCK   expected 12.288 MHz\n"
    "  JB2 (Y14)  EXT_AUDIO_BCLK  -> PCM5102 BCK   expected  3.072 MHz\n"
    "  JB3 (T11)  EXT_AUDIO_LRCLK -> PCM5102 LCK   expected 48.000 kHz\n"
    "  JB7 (V16)  EXT_DAC_DIN     -> PCM5102 DIN   expected 1 kHz sine\n"
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
    # The encoder IP is exposed under the hierarchical `enc_in_0/s_axi` name
    # (see encoder_integration.tcl); match by substring rather than exact key.
    expected = (
        ("axi_dma_0",            "ADAU1761 DMA",        "exact"),
        ("axi_gpio_distortion",  "DSP GPIO contract",   "exact"),
        ("enc_in_0",             "rotary encoder PL IP", "substr"),
        ("axi_vdma_hdmi",        "HDMI VDMA",           "exact"),
        ("v_tc_hdmi",            "HDMI VTC",            "exact"),
    )
    for name, desc, match in expected:
        if match == "exact":
            present = name in ip_dict
        else:
            present = any(name in k for k in ip_dict)
        if not present:
            print("[pcm5102] ERROR: %s missing from overlay -- %s broken?" % (name, desc))
            ok = False
        else:
            print("[pcm5102] OK: %s present (%s)" % (name, desc))
    return ok


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--duration", type=float, default=30.0,
                   help="Seconds to keep the overlay loaded so the DAC tone "
                        "stays driven. Default 30.")
    p.add_argument("--no-summary", action="store_true",
                   help="Skip the ip_dict / clock_dict dump.")
    args = p.parse_args()

    print("PCM5102 DAC tone smoke (Phase 7C DAC-only bring-up)")
    print("Expected wiring:")
    print(JB_WIRING)

    from audio_lab_pynq import AudioLabOverlay  # type: ignore
    overlay = AudioLabOverlay()

    if not args.no_summary:
        _print_overlay_summary(overlay)

    if not _check_required_ips(overlay):
        print("[pcm5102] FAILED: required IPs missing; bit/hwh likely stale")
        return 2

    print("")
    print("[pcm5102] EXT DAC tone is free-running on PMOD JB.")
    print("[pcm5102] The tone is generated entirely in PL; nothing to enable")
    print("[pcm5102] from software.  Listen on PCM5102 line out, or scope")
    print("[pcm5102] JB1/JB2/JB3/JB7 to verify the clocks and data.")
    print("[pcm5102] If silent: check XSMT (must be high), PCM5102 VCC/GND,")
    print("[pcm5102] and the line-out cable.  Don't expect headphone drive.")
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
