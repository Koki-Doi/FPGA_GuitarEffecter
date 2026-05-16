#!/usr/bin/env python3
"""Phase 6G VTC HSync live shift experiment.

Saves the current VTC GEN_HSYNC value, writes a shifted value, triggers
REG_UPDATE, and holds the new timing for a configurable number of
seconds so the user can observe the LCD. The original value is
restored automatically on exit (and via signal handler) so a bad
timing does not leave the LCD desynced.

No bit / hwh / Vivado / Clash change. Runtime MMIO write only.

H sync register layout (per PG016 AXI VTC v6.x, register 0x078):
- bits [12:0]  = HSYNC_HSTART (cycle within line where HSync asserts)
- bits [28:16] = HSYNC_HEND   (cycle within line where HSync deasserts)

Standard 1280x720@60 timing:
- HFrame total      = 1650 cycles
- HActive           = 0 .. 1279
- HFront porch      = 1280 .. 1389  (110 cycles)
- HSync             = 1390 .. 1429  (40 cycles)
- HBack porch       = 1430 .. 1649  (220 cycles)

Shifting HSync later (e.g. HStart 1540, HEnd 1580) shortens the back
porch from 220 to 70, which moves the LCD viewport ~150 source pixels
to the right -- aligning the canvas TL (source x=0) with LCD x=0 when
the LCD currently shows source x=0 at LCD x~150.
"""
from __future__ import print_function

import argparse
import os
import signal
import sys
import time


VTC_CTL_OFFSET     = 0x000
VTC_CTL_REG_UPDATE = 1 << 1
VTC_CTL_GENERATION_ENABLE = 1 << 2
GEN_HSYNC_OFFSET   = 0x078


def repo_paths():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(script_dir, ".."))
    for path in (repo_root, os.path.join(repo_root, "GUI"),
                 "/home/xilinx/Audio-Lab-PYNQ",
                 "/home/xilinx/Audio-Lab-PYNQ/GUI"):
        if path not in sys.path:
            sys.path.insert(0, path)
    return repo_root


def pack_hsync(hstart, hend):
    return ((int(hend) & 0x1FFF) << 16) | (int(hstart) & 0x1FFF)


def unpack_hsync(value):
    return (int(value) & 0x1FFF, (int(value) >> 16) & 0x1FFF)


def main():
    parser = argparse.ArgumentParser(
        description=("Phase 6G: live-shift VTC HSync to compensate the LCD "
                     "150 px right-shift. Original value is restored on "
                     "exit."))
    parser.add_argument("--shift", type=int, default=150,
                        help="cycles to shift HSync later "
                             "(positive => active video starts later "
                             "in line => LCD viewport moves right)")
    parser.add_argument("--hold-seconds", type=float, default=30.0)
    parser.add_argument("--show-calibration", action="store_true",
                        help="render the calibration pattern while the "
                             "shift is active")
    args = parser.parse_args()

    repo_paths()

    print("[hsync_shift] importing AudioLabOverlay")
    from audio_lab_pynq import AudioLabOverlay
    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend

    print("[hsync_shift] loading AudioLabOverlay()")
    overlay = AudioLabOverlay()
    backend = AudioLabHdmiBackend(overlay)
    print("[hsync_shift] starting backend (allocates fb, programs VDMA + VTC)")
    if args.show_calibration:
        from test_hdmi_800x480_viewport_calibration import render_calibration_frame
        frame = render_calibration_frame()
        backend.start(frame, placement="manual", offset_x=0, offset_y=0)
    else:
        backend.start(rgb_frame=None)

    mmio = backend.vtc_mmio
    orig_hsync = int(mmio.read(GEN_HSYNC_OFFSET))
    orig_start, orig_end = unpack_hsync(orig_hsync)
    new_start = orig_start + int(args.shift)
    new_end = orig_end + int(args.shift)
    new_hsync = pack_hsync(new_start, new_end)

    print("[hsync_shift] original GEN_HSYNC = 0x{:08x} "
          "(HSTART={}, HEND={})".format(orig_hsync, orig_start, orig_end))
    print("[hsync_shift] proposed GEN_HSYNC = 0x{:08x} "
          "(HSTART={}, HEND={}) shift={}".format(
              new_hsync, new_start, new_end, args.shift))

    def restore():
        try:
            mmio.write(GEN_HSYNC_OFFSET, orig_hsync)
            mmio.write(VTC_CTL_OFFSET,
                       VTC_CTL_GENERATION_ENABLE | VTC_CTL_REG_UPDATE)
            print("[hsync_shift] restored GEN_HSYNC = 0x{:08x}".format(
                orig_hsync))
        except Exception as exc:
            print("[hsync_shift] restore FAILED: {}".format(exc))

    def handler(signum, frame):
        print("[hsync_shift] signal {} received -- restoring".format(signum))
        restore()
        sys.exit(1)

    signal.signal(signal.SIGINT, handler)
    signal.signal(signal.SIGTERM, handler)

    try:
        mmio.write(GEN_HSYNC_OFFSET, new_hsync)
        # REG_UPDATE forces the new timing to take effect on the next
        # vsync.
        mmio.write(VTC_CTL_OFFSET,
                   VTC_CTL_GENERATION_ENABLE | VTC_CTL_REG_UPDATE)
        readback = int(mmio.read(GEN_HSYNC_OFFSET))
        readback_start, readback_end = unpack_hsync(readback)
        print("[hsync_shift] wrote and triggered REG_UPDATE")
        print("[hsync_shift] readback GEN_HSYNC = 0x{:08x} "
              "(HSTART={}, HEND={})".format(
                  readback, readback_start, readback_end))
        print("[hsync_shift] holding new timing for {} seconds".format(
            args.hold_seconds))
        print("[hsync_shift] observe LCD now; report whether the GUI / "
              "calibration pattern moved")
        time.sleep(float(args.hold_seconds))
    finally:
        restore()


if __name__ == "__main__":
    main()
