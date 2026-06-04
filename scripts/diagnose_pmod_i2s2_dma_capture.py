#!/usr/bin/env python3
"""DMA-capture the Pmod ADC samples that i2s_to_stream actually emits.

Mode 1 (Pmod-master bit-echo) is clean by ear. Mode 2 (ADC -> AXIS
passthrough -> DAC) is "slightly distorted" by ear even with every
effect off. We do NOT know whether the bug is on the AXIS path side
(i2s_to_stream deserialize / re-serialize / re-clock) or further
downstream (Pmod DAC SDIN mux timing).

This script captures the AXIS passthrough samples to DMA, computes
peak / RMS / dBFS / clip + a small histogram of the LSB, and compares
against the pmod_status counters that read the ADC SDOUT *bit by bit*
via the Pmod master's own deserializer.

If the two match: i2s_to_stream is reading the ADC bits identically to
the Pmod-master shift register; the audio distortion must come from the
DAC-side path (i2s_to_stream/so timing into pmod_master's mode-2 mux).

If the two differ: i2s_to_stream is mis-aligning the ADC bits. The
distortion is on the input side.

The capture goes through axis_switch_source/M00 -> axis_switch_sink/M01
(DMA sink) — exactly the same AXIS endpoints mode 2 uses to drive the
DAC, just routed to DMA instead of headphone. During the capture window
the DAC produces silence; after capture the route is restored to the
mode-2 path (sink=headphone) so the user can keep listening.

PYNQ Python 3.6 compatibility: no f-string `=` syntax, no dataclass.
"""

import argparse
import math
import sys
import time

import numpy as np


REG = dict(
    PEAK_ABS_LEFT  = 0x20,
    PEAK_ABS_RIGHT = 0x24,
    CLIP_COUNT     = 0x14,
    NONZERO_COUNT  = 0x0C,
    MODE           = 0x28,
    CLEAR          = 0x2C,
)
FULL_SCALE_24 = (1 << 23) - 1


def _find_pmod_status(overlay):
    from pynq import MMIO
    for key in sorted(getattr(overlay, "ip_dict", {})):
        if "pmod_status" in key or "pmod_i2s2_status" in key:
            entry = overlay.ip_dict[key]
            addr = entry.get("phys_addr")
            if addr is None:
                continue
            rng = entry.get("addr_range", 0x10000)
            return MMIO(addr, rng)
    return None


def _dbfs(x):
    x = float(x)
    if x <= 0:
        return float("-inf")
    return 20.0 * math.log10(x / FULL_SCALE_24)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--frames", type=int, default=96000,
                   help="DMA frames to capture (1 frame = 1 stereo sample). "
                        "Default 96000 ~= 1 second @ 96 kHz (D98; was 48000 @48k).")
    p.add_argument("--restore-mode-2", action="store_true", default=True,
                   help="After capture, set MODE=2 and route line_in -> "
                        "passthrough -> headphone so DAC plays again.")
    p.add_argument("--end-mute", action="store_true",
                   help="Set MODE=3 (mute) at the end instead of restoring "
                        "mode 2.")
    args = p.parse_args()

    print("[dma] capturing %d frames (%.3f s) of AXIS-passthrough"
          % (args.frames, args.frames / 96000.0))

    from audio_lab_pynq import AudioLabOverlay
    from audio_lab_pynq.diagnostics import (capture_input,
                                            compute_input_stats,
                                            format_input_stats)
    from audio_lab_pynq.AudioLabOverlay import (XbarSource, XbarEffect,
                                                XbarSink)

    ovl = AudioLabOverlay()
    print("[dma] AudioLabOverlay loaded")

    mmio = _find_pmod_status(ovl)
    if mmio is None:
        print("[dma] ERROR: pmod_status not found")
        return 1

    # Apply safe-clean to be sure no effect is touching the chain. Pure
    # passthrough mode of axis_switch is selected by all-False flags.
    ovl.set_compressor_settings(enabled=False)
    ovl.set_noise_suppressor_settings(enabled=False)
    ovl.set_guitar_effects(
        noise_gate_on=False, overdrive_on=False, distortion_on=False,
        rat_on=False, amp_on=False, cab_on=False, eq_on=False,
        reverb_on=False,
    )
    print("[dma] safe-clean applied (all effects off)")

    # Make sure MODE stays at 2 throughout so the DAC + ADC path is the
    # mode-2 path the user is actually hearing.
    mmio.write(REG["MODE"], 2)
    time.sleep(0.05)
    rb_mode = mmio.read(REG["MODE"]) & 0x3
    print("[dma] MODE=2 readback = %d" % rb_mode)

    # Clear pmod_status counters so the peak / nonzero numbers we read
    # back at the end reflect only the capture window.
    mmio.write(REG["CLEAR"], 1)
    time.sleep(0.05)

    print("[dma] capturing ...")
    samples = capture_input(ovl, num_frames=args.frames)
    # After capture_input, the route is restored to (line_in, passthrough,
    # headphone). The user can hear audio again now.

    pl = mmio.read(REG["PEAK_ABS_LEFT"]) & 0xFFFFFF
    pr = mmio.read(REG["PEAK_ABS_RIGHT"]) & 0xFFFFFF
    clip = mmio.read(REG["CLIP_COUNT"]) & 0xFFFFFFFF
    nz = mmio.read(REG["NONZERO_COUNT"]) & 0xFFFFFFFF
    print("")
    print("[dma] === Pmod-master deserializer (ADC SDOUT echo) ===")
    print("    PEAK_ABS_LEFT  = %u  (%.1f dBFS)" % (pl, _dbfs(pl)))
    print("    PEAK_ABS_RIGHT = %u  (%.1f dBFS)" % (pr, _dbfs(pr)))
    print("    CLIP_COUNT     = %u" % clip)
    print("    NONZERO_COUNT  = %u" % nz)

    stats = compute_input_stats(samples)
    print("")
    print("[dma] === i2s_to_stream deserializer (DMA capture) ===")
    print(format_input_stats(stats))

    # Bit-pattern checks on the DMA capture.
    print("")
    print("[dma] === DMA capture bit pattern ===")
    for i, ch in enumerate(("left", "right")):
        col = samples[:, i].astype(np.int64)
        # 24-bit signed values should never exceed +/-8388607.
        too_big = int(np.sum((col > FULL_SCALE_24) | (col < -FULL_SCALE_24 - 1)))
        # LSB stickiness: how often is LSB exactly zero (would suggest the
        # IP is truncating to <24 bits silently).
        lsb_zero = int(np.sum((col & 0x1) == 0))
        # Saturation count (very close to FS).
        near_sat = int(np.sum(np.abs(col) > FULL_SCALE_24 - 8))
        # Bincount on bottom 3 bits: cast to a non-negative int32 first.
        bottom3 = np.asarray(col & 0x7, dtype=np.int32)
        bc = np.bincount(bottom3, minlength=8)
        # Top 4 bits of |sample| - if sample width is effectively less than
        # 24 bits, top bits never set.
        abs_col = np.abs(col).astype(np.int64)
        top_bits_used = int(np.max(abs_col))
        print("    %s : count=%d, lsb_zero=%d (%.1f%%), "
              "near_FS=%d, out_of_24=%d, max_abs=%d"
              % (ch, col.size, lsb_zero, 100.0 * lsb_zero / col.size,
                 near_sat, too_big, top_bits_used))
        print("      bottom3 bin = %s" % bc.tolist())
        # DC offset and amplitude estimate.
        print("      mean=%.1f  rms=%.1f" %
              (float(np.mean(col)), float(np.sqrt(np.mean(col.astype(np.float64) ** 2)))))

    # Spot check: any sample equal to exactly +/-FS or 0x800000 (the
    # values that pmod_status flags as clip)?
    print("")
    pos_fs = int(np.sum((samples == FULL_SCALE_24)))
    neg_fs = int(np.sum((samples == -FULL_SCALE_24 - 1)))
    print("[dma] DMA capture clip-like values: +FS=%d, -FS=%d" % (pos_fs, neg_fs))

    # Compute a rough cross-check: DMA peak vs Pmod-master peak. They
    # should match to within ~1 LSB if the deserialization is the same.
    dma_pl = int(np.max(np.abs(samples[:, 0])))
    dma_pr = int(np.max(np.abs(samples[:, 1])))
    print("")
    print("[dma] === peak abs cross-check ===")
    print("    Pmod-master L = %u  vs  DMA L = %u  (delta = %d)"
          % (pl, dma_pl, dma_pl - pl))
    print("    Pmod-master R = %u  vs  DMA R = %u  (delta = %d)"
          % (pr, dma_pr, dma_pr - pr))

    # First 12 samples in hex. Looking for: bit shifts, sign-bit corruption,
    # cross-channel bleed, etc.
    print("")
    print("[dma] === first 12 stereo frames (hex 24-bit) ===")
    print("    %5s   %-12s %-12s   %-12s %-12s" %
          ("idx", "L(int)", "L(hex)", "R(int)", "R(hex)"))
    for i in range(12):
        L = int(samples[i, 0])
        R = int(samples[i, 1])
        print("    %5d   %12d %-12s   %12d %-12s" %
              (i, L, "0x%06X" % (L & 0xFFFFFF), R, "0x%06X" % (R & 0xFFFFFF)))

    # Top-bit histogram for LEFT: how often is each of the upper 4 bits set?
    print("")
    print("[dma] === top-bit prevalence (across all frames) ===")
    print("    bit#  | LEFT count    | RIGHT count")
    for bit in range(23, 11, -1):
        mask = 1 << bit
        lcnt = int(np.sum((np.asarray(samples[:, 0], dtype=np.int64) & mask) != 0))
        rcnt = int(np.sum((np.asarray(samples[:, 1], dtype=np.int64) & mask) != 0))
        print("    bit %2d | %10d  | %10d" % (bit, lcnt, rcnt))

    # Diff between LEFT >> 1 and RIGHT (a common bug is "L = R left-shifted",
    # not the case here but useful sanity).
    print("")
    print("[dma] === shift-by-1 sanity ===")
    print("    L>>1 vs L: max(|L>>1 - L|) = %d  (zero if not aliased)"
          % int(np.max(np.abs((samples[:, 0] >> 1).astype(np.int64) -
                              samples[:, 0].astype(np.int64)))))
    print("    L vs R: max(|L - R|) = %d"
          % int(np.max(np.abs(samples[:, 0].astype(np.int64) -
                              samples[:, 1].astype(np.int64)))))

    if args.end_mute:
        mmio.write(REG["MODE"], 3)
        time.sleep(0.05)
        print("[dma] MODE = 3 (mute) at end")
    elif args.restore_mode_2:
        # capture_input already restored route to (line_in, passthrough,
        # headphone). MODE was set to 2 above and stays.
        print("[dma] MODE stays at 2, AXIS route restored to headphone")

    return 0


if __name__ == "__main__":
    sys.exit(main())
