#!/usr/bin/env python3
"""DMA-capture the i2s_to_stream output in MODE 1 (Pmod direct loopback).

Confirms the IP-side LEFT corruption is independent of audio mode (i.e.,
it's purely an i2s_to_stream extraction bug, NOT the mode-2 mux).

In MODE 1, the DAC is driven by Pmod-master's internal echo path, so the
user hears clean audio. The ADC samples still flow into the AXIS chain
via the fanout (pmod_i2s2_integration.tcl wires the same SDOUT port to
both pmod_master/ad_sdout_i AND i2s_to_stream/si). DMA captures that
AXIS path.

If LEFT in DMA is still broken (mismatched against Pmod-master peak),
the bug is in i2s_to_stream/i2sIn for sure.
If LEFT in DMA matches in mode 1, then mode 2's DAC path is what's
introducing the asymmetry.

PYNQ Python 3.6 compatibility.
"""

import sys
import time

import numpy as np

try:
    from audio_lab_pynq.constants import SAMPLE_RATE_HZ
except Exception:  # off-board (pynq unavailable); constants.py is the source of truth
    SAMPLE_RATE_HZ = 96000


REG = dict(
    PEAK_ABS_LEFT  = 0x20,
    PEAK_ABS_RIGHT = 0x24,
    CLIP_COUNT     = 0x14,
    NONZERO_COUNT  = 0x0C,
    MODE           = 0x28,
    CLEAR          = 0x2C,
)


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


def main():
    from audio_lab_pynq import AudioLabOverlay
    from audio_lab_pynq.diagnostics import capture_input, compute_input_stats, format_input_stats

    ovl = AudioLabOverlay()
    print("[mode1-dma] AudioLabOverlay loaded")

    mmio = _find_pmod_status(ovl)
    if mmio is None:
        print("[mode1-dma] ERROR: pmod_status not found")
        return 1

    # Safe-clean (passthrough route)
    ovl.set_compressor_settings(enabled=False)
    ovl.set_noise_suppressor_settings(enabled=False)
    ovl.set_guitar_effects(
        noise_gate_on=False, overdrive_on=False, distortion_on=False,
        rat_on=False, amp_on=False, cab_on=False, eq_on=False,
        reverb_on=False,
    )

    # MODE 1: ADC -> DAC direct loopback (Pmod internal). DMA capture
    # is independent of MODE and reads axis_li from i2s_to_stream.
    mmio.write(REG["MODE"], 1)
    time.sleep(0.05)
    print("[mode1-dma] MODE = 1 (Pmod direct echo) readback = %d"
          % (mmio.read(REG["MODE"]) & 0x3))
    mmio.write(REG["CLEAR"], 1)
    time.sleep(0.05)

    samples = capture_input(ovl, num_frames=SAMPLE_RATE_HZ)  # ~1 s

    pl = mmio.read(REG["PEAK_ABS_LEFT"]) & 0xFFFFFF
    pr = mmio.read(REG["PEAK_ABS_RIGHT"]) & 0xFFFFFF
    clip = mmio.read(REG["CLIP_COUNT"]) & 0xFFFFFFFF
    print("")
    print("[mode1-dma] Pmod-master deserializer (mode 1 path):")
    print("    PEAK_ABS_LEFT  = %u" % pl)
    print("    PEAK_ABS_RIGHT = %u" % pr)
    print("    CLIP_COUNT     = %u" % clip)

    stats = compute_input_stats(samples)
    print("")
    print("[mode1-dma] i2s_to_stream deserializer (DMA capture):")
    print(format_input_stats(stats))

    dma_pl = int(np.max(np.abs(samples[:, 0])))
    dma_pr = int(np.max(np.abs(samples[:, 1])))
    print("")
    print("[mode1-dma] === peak abs cross-check (mode 1, fanout) ===")
    print("    Pmod-master L = %u  vs  DMA L = %u  (delta = %d)"
          % (pl, dma_pl, dma_pl - pl))
    print("    Pmod-master R = %u  vs  DMA R = %u  (delta = %d)"
          % (pr, dma_pr, dma_pr - pr))

    # First few raw frames.
    print("")
    print("[mode1-dma] === first 8 stereo frames (hex 24-bit) ===")
    for i in range(8):
        L = int(samples[i, 0])
        R = int(samples[i, 1])
        print("    %5d  L=%12d  0x%06X    R=%12d  0x%06X"
              % (i, L, L & 0xFFFFFF, R, R & 0xFFFFFF))

    # Bit prevalence
    print("")
    print("[mode1-dma] === top-bit prevalence ===")
    for bit in range(23, 11, -1):
        mask = 1 << bit
        lcnt = int(np.sum((np.asarray(samples[:, 0], dtype=np.int64) & mask) != 0))
        rcnt = int(np.sum((np.asarray(samples[:, 1], dtype=np.int64) & mask) != 0))
        print("    bit %2d : LEFT=%d  RIGHT=%d" % (bit, lcnt, rcnt))

    return 0


if __name__ == "__main__":
    sys.exit(main())
