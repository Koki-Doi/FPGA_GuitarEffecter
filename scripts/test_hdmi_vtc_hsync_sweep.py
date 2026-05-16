#!/usr/bin/env python3
"""Phase 6F: sweep VTC HSync shifts while displaying a labeled calibration
pattern so the user can identify which shift aligns the LCD viewport.

Each step:
1. Writes the calibration frame so source x=0..799 has a thick orange
   border at x=0..3, green border at x=796..799, a vertical white grid
   every 100 px with the X coordinate labeled at the top and bottom.
2. Writes GEN_HSYNC with shift = step value.
3. Triggers REG_UPDATE.
4. Holds for ``--step-seconds`` so the user can read the X label that
   sits at the LCD's actual left edge.
5. Restores the original HSync on exit.

Default sweep: 0, 50, 100, 150, 200, 300, -150 cycles.

No bit/hwh / Vivado / Clash change.
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


def render_labelled_calibration(shift):
    import numpy as np
    from PIL import Image, ImageDraw
    from pynq_multi_fx_gui import draw_text

    W, H = 800, 480
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)

    # Borders: orange on left, green on right, white top/bottom.
    d.rectangle((0, 0, 3, H - 1), fill=(255, 110, 0, 255))
    d.rectangle((W - 4, 0, W - 1, H - 1), fill=(0, 240, 90, 255))
    d.rectangle((0, 0, W - 1, 3), fill=(255, 255, 255, 255))
    d.rectangle((0, H - 4, W - 1, H - 1), fill=(255, 255, 255, 255))

    # 100 px grid + labels at top and bottom edges.
    for x in range(0, W + 1, 100):
        col = (40, 200, 80, 255) if x % 200 == 0 else (40, 80, 40, 255)
        if 0 < x < W:
            d.line((x, 8, x, H - 8), fill=col, width=1)
        label = "x={}".format(x)
        draw_text(img, (x + 4, 12), label,
                  fill=(180, 240, 200, 255), scale=1, letter_spacing=1)
        draw_text(img, (x + 4, H - 22), label,
                  fill=(180, 240, 200, 255), scale=1, letter_spacing=1)

    # 100 px grid + labels at left and right edges.
    for y in range(0, H + 1, 100):
        col = (40, 200, 80, 255) if y % 200 == 0 else (40, 80, 40, 255)
        if 0 < y < H:
            d.line((8, y, W - 8, y), fill=col, width=1)
        label = "y={}".format(y)
        draw_text(img, (12, y + 4), label,
                  fill=(180, 240, 200, 255), scale=1, letter_spacing=1)
        draw_text(img, (W - 60, y + 4), label,
                  fill=(180, 240, 200, 255), scale=1, letter_spacing=1)

    # Big central label showing the current shift value.
    draw_text(img, (W // 2, 60), "HSYNC SHIFT = {:+d}".format(int(shift)),
              fill=(255, 215, 80, 255), scale=2, anchor="mt",
              letter_spacing=2)

    # Crosshair at center.
    cx, cy = W // 2, H // 2
    d.line((cx - 80, cy, cx + 80, cy), fill=(255, 215, 80, 255), width=2)
    d.line((cx, cy - 80, cx, cy + 80), fill=(255, 215, 80, 255), width=2)

    return np.asarray(img.convert("RGB"), dtype="uint8")


def main():
    parser = argparse.ArgumentParser(
        description="Phase 6F: sweep VTC HSync shifts with labeled "
                    "calibration pattern.")
    parser.add_argument("--shifts", type=str,
                        default="0,50,100,150,200,300,-150",
                        help="comma-separated HSync shifts to test")
    parser.add_argument("--step-seconds", type=float, default=8.0,
                        help="how long to hold each shift")
    args = parser.parse_args()

    shifts = [int(x) for x in args.shifts.split(",") if x.strip()]

    repo_paths()

    print("[sweep] importing AudioLabOverlay")
    from audio_lab_pynq import AudioLabOverlay
    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend

    print("[sweep] loading AudioLabOverlay()")
    overlay = AudioLabOverlay()
    # Disable the persistent +150 shift baked into Phase 6G so the
    # sweep starts from the IP-baked default and our deltas are
    # absolute, not stacked on top of +150.
    backend = AudioLabHdmiBackend(overlay, hsync_shift=0)
    print("[sweep] starting backend (HSync at IP default)")
    backend.start(rgb_frame=None)

    mmio = backend.vtc_mmio
    orig = int(mmio.read(GEN_HSYNC_OFFSET))
    orig_start = orig & 0x1FFF
    orig_end = (orig >> 16) & 0x1FFF

    def restore():
        try:
            mmio.write(GEN_HSYNC_OFFSET, orig)
            mmio.write(VTC_CTL_OFFSET,
                       VTC_CTL_GENERATION_ENABLE | VTC_CTL_REG_UPDATE)
            print("[sweep] restored GEN_HSYNC = 0x{:08x}".format(orig))
        except Exception as exc:
            print("[sweep] restore FAILED: {}".format(exc))

    def handler(signum, frame):
        print("[sweep] signal {} -- restoring".format(signum))
        restore()
        sys.exit(1)

    signal.signal(signal.SIGINT, handler)
    signal.signal(signal.SIGTERM, handler)

    print("[sweep] original HSync HSTART={}, HEND={} (back porch = {})"
          .format(orig_start, orig_end, 1650 - orig_end))
    try:
        for shift in shifts:
            new_start = (orig_start + shift) & 0x1FFF
            new_end = (orig_end + shift) & 0x1FFF
            new_val = ((new_end & 0x1FFF) << 16) | (new_start & 0x1FFF)
            frame = render_labelled_calibration(shift)
            backend.write_frame(frame, placement="manual",
                                offset_x=0, offset_y=0)
            mmio.write(GEN_HSYNC_OFFSET, new_val)
            mmio.write(VTC_CTL_OFFSET,
                       VTC_CTL_GENERATION_ENABLE | VTC_CTL_REG_UPDATE)
            print("[sweep] shift={:+5d}  HSync {}..{}  back_porch={}  "
                  "holding {:.1f}s".format(
                      shift, new_start, new_end, 1650 - new_end,
                      args.step_seconds))
            time.sleep(float(args.step_seconds))
    finally:
        restore()


if __name__ == "__main__":
    main()
