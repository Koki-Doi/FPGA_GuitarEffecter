#!/usr/bin/env python3
"""Phase Pmod-1/2/3 on-board smoke for the Digilent Pmod I2S2 bring-up bit.

Usage on the PYNQ-Z2:

    # mode 0 -- internal 1 kHz tone + ADC probe (Line Out -> Line In)
    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \\
        scripts/test_pmod_i2s2.py --duration 5 --mode tone

    # mode 1 -- ADC -> DAC direct loopback (DSP NOT involved)
    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \\
        scripts/test_pmod_i2s2.py --duration 5 --mode loopback \\
        --confirm-loopback

Mode names map onto the `axi_pmod_i2s2_status` MODE register:
  - `tone`      => cfg_mode = 0 (default)
  - `loopback`  => cfg_mode = 1 (ADC -> DAC; NO DSP, NO effects)
The numeric values `0` / `1` are still accepted as aliases.

What this script does:
  * Loads AudioLabOverlay (the Pmod I2S2 bit instantiates
    `pmod_i2s2_master` driving JB1..JB4 + JB7..JB10 and exposes the
    runtime status registers via `axi_pmod_i2s2_status` at 0x43D20000).
  * Verifies the required IPs are still present (ADAU1761 DSP path,
    encoder, HDMI VDMA/VTC) and the Pmod I2S2 status block is mapped.
  * Optionally writes `cfg_mode` and issues a CLEAR pulse, then samples
    the status counters over `--duration` seconds and prints a PASS /
    WARN / FAIL summary:
      - frame_count    : must rise (LRCK frame engine alive)
      - sdout_xcount   : must rise if SDOUT carries activity
      - nonzero_count  : ditto, and indicates non-zero captured samples
      - peak_abs_*     : must be > 0 if the Pmod I2S2 ADC sees signal

Mode 1 safety:
  * The internal Pmod I2S2 module routes the captured ADC sample
    straight back to the DAC at full scale. With the on-module Line
    Out <-> Line In 3.5 mm jumper installed the loop has gain ~1
    and can FEED BACK / OSCILLATE.
  * Recommended: disconnect the Line Out <-> Line In jumper, then put
    a real audio source on Line In and listen on Line Out.
  * If you keep the jumper installed (e.g. you only want to look at
    the status counters), use a LOW audio source level on Line In;
    do NOT crank the source.
  * To prevent accidental engagement, this script REQUIRES
    `--confirm-loopback` to be passed when `--mode loopback` is
    selected. Otherwise it falls back to mode 0 with an error.

What this script does NOT do:
  * Does not change ADAU1761 codec config.
  * Does not touch HDMI / encoder / GPIO_CONTROL_MAP / DSP chain.
  * Does not route Pmod I2S2 ADC into the AudioLab DSP path (that
    is a separate decision and not implemented here).

PYNQ Python 3.6 compatibility: no dataclass, no f-string `=` syntax.
"""

import argparse
import time


JB_WIRING = (
    "  JB1  (W14)  D/A MCLK   12.288 MHz\n"
    "  JB2  (Y14)  D/A LRCK   48 kHz\n"
    "  JB3  (T11)  D/A SCLK    3.072 MHz\n"
    "  JB4  (T10)  D/A SDIN   24-bit I2S Philips MSB-first\n"
    "  JB7  (V16)  A/D MCLK   12.288 MHz (fanout)\n"
    "  JB8  (W16)  A/D LRCK   48 kHz     (fanout)\n"
    "  JB9  (V12)  A/D SCLK    3.072 MHz (fanout)\n"
    "  JB10 (W13)  A/D SDOUT  <- input\n"
)


# Register map for axi_pmod_i2s2_status (mirrors the Verilog header).
REG = dict(
    VERSION         = 0x00,
    STATUS          = 0x04,
    FRAME_COUNT     = 0x08,
    NONZERO_COUNT   = 0x0C,
    SDOUT_XCOUNT    = 0x10,
    CLIP_COUNT      = 0x14,
    LAST_LEFT       = 0x18,
    LAST_RIGHT      = 0x1C,
    PEAK_ABS_LEFT   = 0x20,
    PEAK_ABS_RIGHT  = 0x24,
    MODE            = 0x28,
    CLEAR           = 0x2C,
)
EXPECTED_VERSION = 0x00480001

# Symbolic mode names that map onto `cfg_mode_i` in `pmod_i2s2_master.v`.
MODE_TONE_PROBE              = 0  # internal 1 kHz tone on DAC, ADC reads it back
MODE_ADC_TO_DAC_DIRECT_LOOP  = 1  # ADC sample -> DAC sample, no DSP


def _parse_mode(value):
    """Accept --mode tone | loopback | 0 | 1. Return integer cfg_mode."""
    if value is None:
        return None
    s = str(value).strip().lower()
    if s in ("tone", "tone_probe", "probe", "0"):
        return MODE_TONE_PROBE
    if s in ("loopback", "adc_to_dac_loopback", "loop", "1"):
        return MODE_ADC_TO_DAC_DIRECT_LOOP
    raise argparse.ArgumentTypeError(
        "--mode must be one of: tone, loopback, 0, 1; got %r" % value)


LOOPBACK_WARNING = """\
================================================================
WARNING: Pmod I2S2 mode 1 = ADC -> DAC DIRECT LOOPBACK
================================================================
The PL routes the just-captured ADC sample straight to the DAC
at full scale. With the on-module Line Out <-> Line In 3.5 mm
jumper installed, the loop has gain ~ 1 and can FEED BACK or
OSCILLATE.

Recommended workflow:
  1. Disconnect the Line Out <-> Line In jumper (or unplug one
     end of the 3.5 mm cable).
  2. Put a REAL audio source on Line In at LOW volume.
  3. Listen on Line Out via a separate audio interface or
     headphone (NOT plugged back into Line In).
  4. Keep this run short (a few seconds) and stop if you hear
     squealing.

If you must keep the on-module jumper installed while you watch
the status counters, set the audio source level to its MINIMUM
before engaging mode 1.

To engage mode 1, pass `--confirm-loopback` on the command line.
================================================================
"""


def _find_pmod_status(overlay):
    """Locate the Pmod I2S2 status IP in the overlay and return an MMIO.

    PYNQ wraps the BD cell as `pmod_status_0` and the AXI-Lite slave shows
    up in `ip_dict` under `pmod_status_0/s_axi`. Going through
    `getattr(overlay, 'pmod_status_0')` returns a `DefaultHierarchy` that
    does NOT expose `.read(addr)` directly (it dispatches to the s_axi
    child), so the simplest robust approach is to build a `pynq.MMIO`
    from the published `phys_addr` / `addr_range`.
    """
    from pynq import MMIO  # noqa: F401  (resolved on the PYNQ board)
    ip_dict = getattr(overlay, "ip_dict", {})
    for key in sorted(ip_dict):
        if "pmod_status" in key or "pmod_i2s2_status" in key:
            entry = ip_dict[key]
            addr = entry.get("phys_addr")
            if addr is None:
                continue
            rng = entry.get("addr_range", 0x10000)
            return MMIO(addr, rng)
    return None


def _read(mmio, off):
    return mmio.read(off) & 0xFFFFFFFF


def _sign24(x):
    x = x & 0xFFFFFFFF
    if x & 0x80000000:
        # sign-extended 24-bit -> 32-bit Python int conversion
        return x - (1 << 32)
    return x


def _print_status(label, mmio):
    print("[pmod_i2s2] %s:" % label)
    print("    VERSION         = 0x%08X" % _read(mmio, REG["VERSION"]))
    st = _read(mmio, REG["STATUS"])
    mode = (st >> 8) & 0x3
    print("    STATUS          = 0x%08X (mode=%d, sdout_alive=%d, "
          "bclk_seen=%d, lrclk_seen=%d)"
          % (st, mode, (st >> 2) & 1, (st >> 1) & 1, st & 1))
    print("    FRAME_COUNT     = %u" % _read(mmio, REG["FRAME_COUNT"]))
    print("    NONZERO_COUNT   = %u" % _read(mmio, REG["NONZERO_COUNT"]))
    print("    SDOUT_XCOUNT    = %u" % _read(mmio, REG["SDOUT_XCOUNT"]))
    print("    CLIP_COUNT      = %u" % _read(mmio, REG["CLIP_COUNT"]))
    print("    LAST_LEFT       = %d" % _sign24(_read(mmio, REG["LAST_LEFT"])))
    print("    LAST_RIGHT      = %d" % _sign24(_read(mmio, REG["LAST_RIGHT"])))
    print("    PEAK_ABS_LEFT   = %u" % _read(mmio, REG["PEAK_ABS_LEFT"]))
    print("    PEAK_ABS_RIGHT  = %u" % _read(mmio, REG["PEAK_ABS_RIGHT"]))
    print("    MODE            = 0x%08X" % _read(mmio, REG["MODE"]))


def _check_required_ips(overlay):
    ip_dict = getattr(overlay, "ip_dict", {})
    expected = (
        ("axi_dma_0",            "ADAU1761 DMA",        "exact"),
        ("axi_gpio_distortion",  "DSP GPIO contract",   "exact"),
        ("enc_in_0",             "rotary encoder PL IP", "substr"),
        ("axi_vdma_hdmi",        "HDMI VDMA",           "exact"),
        ("v_tc_hdmi",            "HDMI VTC",            "exact"),
        ("pmod_status",          "Pmod I2S2 status IP", "substr"),
    )
    ok = True
    for name, desc, match in expected:
        if match == "exact":
            present = name in ip_dict
        else:
            present = any(name in k for k in ip_dict)
        if not present:
            print("[pmod_i2s2] ERROR: %s missing from overlay -- %s broken?" % (name, desc))
            ok = False
        else:
            print("[pmod_i2s2] OK: %s present (%s)" % (name, desc))
    return ok


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--duration", type=float, default=5.0,
                   help="Seconds to watch the status counters. Default 5.")
    p.add_argument("--mode", type=_parse_mode, default=None,
                   help="cfg_mode to write before the observation window. "
                        "Names: 'tone' (0, default) = internal 1 kHz tone + "
                        "ADC probe, 'loopback' (1) = ADC -> DAC direct loopback "
                        "(NO DSP). Numeric aliases 0/1 also accepted.")
    p.add_argument("--confirm-loopback", action="store_true",
                   help="Required when --mode loopback is selected. Without it "
                        "the script prints a safety warning and refuses to "
                        "engage mode 1 (falls back to mode 0).")
    p.add_argument("--clear", action="store_true",
                   help="Issue a CLEAR write (zeroes peak / nonzero counters) "
                        "before sampling. frame_count keeps running.")
    args = p.parse_args()

    print("Pmod I2S2 bring-up smoke (Phase Pmod-1/2/3)")
    print("Expected wiring:")
    print(JB_WIRING)

    requested_mode = args.mode
    effective_mode = requested_mode
    if requested_mode == MODE_ADC_TO_DAC_DIRECT_LOOP and not args.confirm_loopback:
        print(LOOPBACK_WARNING)
        print("[pmod_i2s2] --confirm-loopback NOT set -- refusing mode 1; "
              "falling back to mode 0 (tone + probe).")
        effective_mode = MODE_TONE_PROBE

    from audio_lab_pynq import AudioLabOverlay  # type: ignore
    overlay = AudioLabOverlay()
    print("[pmod_i2s2] AudioLabOverlay loaded")

    if not _check_required_ips(overlay):
        print("[pmod_i2s2] FAILED: required IPs missing; bit/hwh likely stale.")
        return 2

    mmio = _find_pmod_status(overlay)
    if mmio is None:
        print("[pmod_i2s2] FAILED: cannot locate Pmod I2S2 status IP -- "
              "check the hwh ip_dict for an entry containing pmod_status.")
        return 3

    ver = _read(mmio, REG["VERSION"])
    if ver != EXPECTED_VERSION:
        print("[pmod_i2s2] WARN: VERSION 0x%08X != expected 0x%08X"
              % (ver, EXPECTED_VERSION))

    if effective_mode is not None:
        mode_name = "tone" if effective_mode == MODE_TONE_PROBE else "loopback"
        print("[pmod_i2s2] writing MODE = %d (%s)" % (effective_mode, mode_name))
        if effective_mode == MODE_ADC_TO_DAC_DIRECT_LOOP:
            print("[pmod_i2s2] *** ADC -> DAC direct loopback engaged ***")
            print("[pmod_i2s2] Stop the run if you hear squealing / feedback.")
        mmio.write(REG["MODE"], effective_mode & 0x3)

    if args.clear:
        print("[pmod_i2s2] issuing CLEAR pulse (peak / nonzero / xcount reset)")
        mmio.write(REG["CLEAR"], 1)

    _print_status("initial", mmio)
    start_frames     = _read(mmio, REG["FRAME_COUNT"])
    start_nonzero    = _read(mmio, REG["NONZERO_COUNT"])
    start_xcount     = _read(mmio, REG["SDOUT_XCOUNT"])

    print("")
    print("[pmod_i2s2] waiting %.1f s ..." % args.duration)
    try:
        time.sleep(args.duration)
    except KeyboardInterrupt:
        print("[pmod_i2s2] interrupted")

    _print_status("after %.1f s" % args.duration, mmio)
    end_frames     = _read(mmio, REG["FRAME_COUNT"])
    end_nonzero    = _read(mmio, REG["NONZERO_COUNT"])
    end_xcount     = _read(mmio, REG["SDOUT_XCOUNT"])
    peak_l         = _read(mmio, REG["PEAK_ABS_LEFT"])
    peak_r         = _read(mmio, REG["PEAK_ABS_RIGHT"])

    d_frames  = (end_frames  - start_frames) & 0xFFFFFFFF
    d_nonzero = (end_nonzero - start_nonzero) & 0xFFFFFFFF
    d_xcount  = (end_xcount  - start_xcount)  & 0xFFFFFFFF

    print("")
    print("[pmod_i2s2] delta over %.1f s:" % args.duration)
    print("    frames     +%u  (expected ~%u for 48 kHz)"
          % (d_frames, int(args.duration * 48000)))
    print("    nonzero    +%u" % d_nonzero)
    print("    sdout_xcnt +%u" % d_xcount)
    print("    peak_abs_l = %u  (~%.3f of full-scale)"
          % (peak_l, peak_l / float(1 << 23)))
    print("    peak_abs_r = %u  (~%.3f of full-scale)"
          % (peak_r, peak_r / float(1 << 23)))

    pass_frames = d_frames > 0
    print("")
    print("[pmod_i2s2] PASS: frame_count rising"  if pass_frames
          else "[pmod_i2s2] FAIL: frame_count not rising -- "
               "LRCK/BCLK engine dead?")
    if pass_frames:
        if d_xcount == 0:
            print("[pmod_i2s2] INFO: SDOUT had no transitions -- check that "
                  "the Pmod I2S2 module is plugged in and JB10 (W13) is wired "
                  "to A/D SDOUT.")
        elif peak_l == 0 and peak_r == 0:
            print("[pmod_i2s2] INFO: SDOUT alive but samples are all zero -- "
                  "ADC is running but line-in is silent / shorted to GND.")
        else:
            print("[pmod_i2s2] INFO: ADC samples observed (peak_l=%u, peak_r=%u)"
                  % (peak_l, peak_r))

    return 0 if pass_frames else 4


if __name__ == "__main__":
    raise SystemExit(main())
