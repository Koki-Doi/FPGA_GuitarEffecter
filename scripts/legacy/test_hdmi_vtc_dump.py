#!/usr/bin/env python3
"""Phase 6G VTC register dump.

Reads the AXI VTC generator timing registers so we can see the
horizontal/vertical front porch / sync / back porch values currently
baked in (or asserted at runtime) and decide how to compensate the
LCD viewport shift in software.

No bit / hwh / Clash / Vivado change. Read-only.
"""
from __future__ import print_function

import os
import sys
import time


def repo_paths():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(script_dir, ".."))
    for path in (repo_root, os.path.join(repo_root, "GUI"),
                 "/home/xilinx/Audio-Lab-PYNQ",
                 "/home/xilinx/Audio-Lab-PYNQ/GUI"):
        if path not in sys.path:
            sys.path.insert(0, path)
    return repo_root


# AXI VTC v6.x register map (PG016, latest 1280x720 generator).
VTC_REGS = [
    ("CTL              0x000", 0x000),
    ("ISR              0x004", 0x004),
    ("ERROR            0x008", 0x008),
    ("GIER             0x00C", 0x00C),
    ("VTC_VER          0x010", 0x010),
    ("ACTIVE_SIZE      0x060", 0x060),
    ("TIMING_STATUS    0x038", 0x038),
    ("DET_HSIZE        0x044", 0x044),
    ("DET_VSIZE        0x048", 0x048),
    ("DET_HSYNC        0x050", 0x050),
    ("DET_VBLANK_F0    0x054", 0x054),
    ("DET_VSYNC_F0     0x058", 0x058),
    ("DET_VBLANK_F1    0x05C", 0x05C),
    # Generator side
    ("GEN_HSIZE        0x064", 0x064),
    ("GEN_VSIZE        0x068", 0x068),
    ("GEN_ENC          0x06C", 0x06C),
    ("GEN_POL          0x070", 0x070),
    ("GEN_HSYNC        0x074", 0x074),
    ("GEN_VBLANK_F0    0x078", 0x078),
    ("GEN_VSYNC_F0     0x07C", 0x07C),
    ("GEN_VBLANK_F1    0x080", 0x080),
    ("GEN_VSYNC_F1     0x084", 0x084),
    ("GEN_FSYNC0       0x088", 0x088),
    # Generator HV offset registers (newer VTC firmware)
    ("GEN_HV_OFFSET    0x090", 0x090),
    ("GEN_HV_FSYNC     0x094", 0x094),
]


def main():
    repo_paths()
    print("[vtc_dump] importing AudioLabOverlay")
    from audio_lab_pynq import AudioLabOverlay
    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend

    print("[vtc_dump] loading AudioLabOverlay()")
    overlay = AudioLabOverlay()
    backend = AudioLabHdmiBackend(overlay)
    # Just trigger initialization to make sure VTC is running; no frame
    # is required for reads. Allocate framebuffer + start VTC.
    print("[vtc_dump] starting backend (allocates fb, programs VDMA + VTC)")
    backend.start(rgb_frame=None)

    mmio = backend.vtc_mmio
    print("\n[vtc_dump] VTC IP @ phys 0x{:08x}, range {} bytes".format(
        int(backend._vtc_ip_desc.get("phys_addr", 0)),
        int(backend._vtc_ip_desc.get("addr_range", 0))))
    print("\n[vtc_dump] dense register dump 0x000..0x0FC:")
    for off in range(0x000, 0x100, 4):
        try:
            val = int(mmio.read(off))
            lo = val & 0x1FFF  # 13-bit low
            hi = (val >> 16) & 0x1FFF  # 13-bit high
            print("[vtc_dump] 0x{:03x} = 0x{:08x}   lo13={:5d}  hi13={:5d}".format(
                off, val, lo, hi))
        except Exception as exc:
            print("[vtc_dump] 0x{:03x} read failed: {}".format(off, exc))

    print("")
    print("[vtc_dump] HSYNC packing per PG016 v6.x:")
    print("  Bits [12:0]   = HSYNC_HEND   (active end pixel, exclusive)")
    print("  Bits [28:16]  = HSYNC_HSTART (active start pixel)")
    print("  GEN_HSIZE     [12:0] = active line size,")
    print("                [28:16]= total line size")


if __name__ == "__main__":
    main()
