#!/usr/bin/env python3
"""Phase Pmod-2 / Pmod-3 ADC probe via the axi_pmod_i2s2_status counters.

Companion to scripts/test_pmod_i2s2.py. While test_pmod_i2s2.py prints
overall counter deltas, this script periodically polls the status block
and prints a per-bucket log so the user can correlate transient changes
(plugging Line Out -> Line In, muting the source, etc.) with what the
ADC channel actually sees.

Usage on the PYNQ-Z2:

    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \\
        scripts/pmod_i2s2_capture_probe.py --duration 10 --interval 0.5

What this script does:
  * Loads AudioLabOverlay (Pmod I2S2 variant bit).
  * Issues a CLEAR write at start so the counters start from 0.
  * In a loop, samples FRAME_COUNT, NONZERO_COUNT, SDOUT_XCOUNT,
    LAST_LEFT/RIGHT, PEAK_ABS_LEFT/RIGHT and prints a one-line summary
    of the delta per bucket.
  * At the end, prints a verdict line:
      PASS  : frame_count is rising AND peak_abs_* exceeded a threshold
      WARN  : frame_count is rising but ADC SDOUT looked flat
      FAIL  : frame_count never moved (LRCK/BCLK engine not alive)

What this script does NOT do:
  * Does not capture per-sample audio via DMA. The Pmod I2S2 ADC path is
    not wired into AXIS in this variant (DSP chain still owns the AXIS).
  * Does not touch ADAU1761, HDMI, encoder, GPIO_CONTROL_MAP.
  * Does not change MODE unless --mode is passed.

PYNQ Python 3.6 compatibility: no dataclass, no f-string `=` syntax.
"""

import argparse
import time


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


def _read(mmio, off):
    return mmio.read(off) & 0xFFFFFFFF


def _sign24(x):
    x = x & 0xFFFFFFFF
    if x & 0x80000000:
        return x - (1 << 32)
    return x


def _find_status(overlay):
    # PYNQ wraps pmod_status_0 as a DefaultHierarchy whose .read() does not
    # forward to the s_axi MMIO. Build a pynq.MMIO from the published
    # phys_addr / addr_range instead. See scripts/test_pmod_i2s2.py for the
    # same rationale.
    from pynq import MMIO  # noqa: F401
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


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--duration", type=float, default=10.0,
                   help="Total observation duration in seconds. Default 10.")
    p.add_argument("--interval", type=float, default=0.5,
                   help="Polling interval in seconds. Default 0.5.")
    p.add_argument("--mode", type=int, choices=(0, 1), default=None,
                   help="Optional mode write before observing.")
    p.add_argument("--peak-threshold", type=int, default=1 << 12,
                   help="peak_abs threshold for PASS (default %(default)d, "
                        "about -53 dBFS of 24-bit full-scale).")
    args = p.parse_args()

    print("Pmod I2S2 ADC probe (poll-based)")

    from audio_lab_pynq import AudioLabOverlay  # type: ignore
    overlay = AudioLabOverlay()
    mmio = _find_status(overlay)
    if mmio is None:
        print("[pmod_probe] FAIL: status IP not found in overlay")
        return 2

    if args.mode is not None:
        print("[pmod_probe] MODE write = %d" % args.mode)
        mmio.write(REG["MODE"], args.mode & 0x3)
    print("[pmod_probe] CLEAR pulse")
    mmio.write(REG["CLEAR"], 1)
    time.sleep(0.05)

    print("[pmod_probe] VERSION=0x%08X STATUS=0x%08X MODE=%d"
          % (_read(mmio, REG["VERSION"]),
             _read(mmio, REG["STATUS"]),
             _read(mmio, REG["MODE"]) & 0x3))
    print("[pmod_probe] sampling every %.2f s for %.1f s..."
          % (args.interval, args.duration))
    print("    %-8s  %-10s  %-10s  %-10s  %-10s  %-10s"
          % ("t", "d_frames", "d_xcount", "d_nz", "peak_l", "peak_r"))

    t0 = time.time()
    last = dict(frames=0, xcount=0, nz=0)
    end_peak_l = 0
    end_peak_r = 0
    end_frames = 0

    while time.time() - t0 < args.duration:
        time.sleep(args.interval)
        t = time.time() - t0
        cur_frames  = _read(mmio, REG["FRAME_COUNT"])
        cur_xcount  = _read(mmio, REG["SDOUT_XCOUNT"])
        cur_nz      = _read(mmio, REG["NONZERO_COUNT"])
        peak_l      = _read(mmio, REG["PEAK_ABS_LEFT"])
        peak_r      = _read(mmio, REG["PEAK_ABS_RIGHT"])
        d_frames    = (cur_frames - last["frames"]) & 0xFFFFFFFF
        d_xcount    = (cur_xcount - last["xcount"]) & 0xFFFFFFFF
        d_nz        = (cur_nz     - last["nz"])     & 0xFFFFFFFF
        print("    %-8.2f  %-10u  %-10u  %-10u  %-10u  %-10u"
              % (t, d_frames, d_xcount, d_nz, peak_l, peak_r))
        last["frames"] = cur_frames
        last["xcount"] = cur_xcount
        last["nz"]     = cur_nz
        end_peak_l = peak_l
        end_peak_r = peak_r
        end_frames = cur_frames

    print("")
    if end_frames == 0:
        print("[pmod_probe] FAIL: frame_count never moved -- LRCK/BCLK dead?")
        return 4
    peak_max = max(end_peak_l, end_peak_r)
    if peak_max >= args.peak_threshold:
        print("[pmod_probe] PASS: peak_abs(max) = %u (>= %u threshold). "
              "ADC sees signal." % (peak_max, args.peak_threshold))
        return 0
    print("[pmod_probe] WARN: frame_count rising but peak_abs(max) = %u "
          "(< %u threshold). ADC line-in looks silent."
          % (peak_max, args.peak_threshold))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
