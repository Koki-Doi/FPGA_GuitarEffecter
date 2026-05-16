#!/usr/bin/env python3
"""Phase 6G HDMI 800x480 viewport calibration pattern.

Renders a graduated grid + axis labels into the 800x480 logical
canvas and pushes it through the integrated AudioLab HDMI backend at
``placement="manual"``, ``offset_x=0``, ``offset_y=0``.

Use this on the real 5-inch LCD to read off which source X / Y
coordinates align with the physical LCD edges. The Phase 6F chassis
left-shift did not change the visible result, which means the LCD
viewport is cropping a different region of the 1280x720 HDMI signal
than ``(0, 0, 800, 480)``. The pattern lets us measure that offset
directly.

Pattern contents (drawn at framebuffer coords for the 800x480
canvas):
- Solid 4 px border on the full canvas (so the user can see which
  edges actually reach the LCD).
- A 5 px corner marker square at each canvas corner with a label:
  ``TL 0,0``, ``TR 799,0``, ``BL 0,479``, ``BR 799,479``.
- Vertical grid lines every 50 px with the X coordinate labelled at
  the top and bottom of the canvas.
- Horizontal grid lines every 50 px with the Y coordinate labelled
  on the left and right of the canvas.
- A central crosshair + ``CENTER 400,240`` label.

No ``Overlay("base.bit")``, no ``run_pynq_hdmi()``, no second
overlay. No bit/hwh change.
"""
from __future__ import print_function

import argparse
import json
import os
import sys
import time
import traceback


def repo_paths():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(script_dir, ".."))
    for path in (repo_root, os.path.join(repo_root, "GUI"),
                 "/home/xilinx/Audio-Lab-PYNQ",
                 "/home/xilinx/Audio-Lab-PYNQ/GUI"):
        if path not in sys.path:
            sys.path.insert(0, path)
    return repo_root


def render_calibration_frame():
    import numpy as np
    from PIL import Image, ImageDraw
    from pynq_multi_fx_gui import draw_text  # noqa: E402

    W, H = 800, 480
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)

    GRID = (40, 80, 40)
    GRID_HI = (60, 160, 60)
    AXIS = (200, 220, 200)
    CORNER = (240, 80, 40)
    CENTER = (240, 200, 40)
    BORDER = (255, 255, 255)

    # 50 px vertical grid + X labels
    for x in range(0, W, 50):
        col = GRID_HI if x % 100 == 0 else GRID
        d.line((x, 0, x, H - 1), fill=col, width=1)
        draw_text(img, (x + 2, 10), "x={}".format(x),
                  fill=AXIS + (255,), scale=1, letter_spacing=1)
        draw_text(img, (x + 2, H - 18), "x={}".format(x),
                  fill=AXIS + (255,), scale=1, letter_spacing=1)

    # 50 px horizontal grid + Y labels
    for y in range(0, H, 50):
        col = GRID_HI if y % 100 == 0 else GRID
        d.line((0, y, W - 1, y), fill=col, width=1)
        draw_text(img, (4, y + 2), "y={}".format(y),
                  fill=AXIS + (255,), scale=1, letter_spacing=1)
        draw_text(img, (W - 50, y + 2), "y={}".format(y),
                  fill=AXIS + (255,), scale=1, letter_spacing=1)

    # Right-edge column for x=800 so the user can confirm the right
    # canvas edge reaches the LCD.
    d.line((W - 1, 0, W - 1, H - 1), fill=GRID_HI, width=1)
    draw_text(img, (W - 60, 22), "x=800",
              fill=AXIS + (255,), scale=1, letter_spacing=1)
    draw_text(img, (W - 60, H - 30), "x=800",
              fill=AXIS + (255,), scale=1, letter_spacing=1)

    # Solid 4 px white border on the full canvas
    d.rectangle((0, 0, W - 1, 3), fill=BORDER)
    d.rectangle((0, H - 4, W - 1, H - 1), fill=BORDER)
    d.rectangle((0, 0, 3, H - 1), fill=BORDER)
    d.rectangle((W - 4, 0, W - 1, H - 1), fill=BORDER)

    # Corner marker squares + labels
    sz = 24
    d.rectangle((0, 0, sz, sz), fill=CORNER)
    draw_text(img, (sz + 4, 6), "TL 0,0",
              fill=(255, 255, 255, 255), scale=1, letter_spacing=2)
    d.rectangle((W - 1 - sz, 0, W - 1, sz), fill=CORNER)
    draw_text(img, (W - 1 - sz - 4, 6), "TR 799,0",
              fill=(255, 255, 255, 255), scale=1, anchor="rt",
              letter_spacing=2)
    d.rectangle((0, H - 1 - sz, sz, H - 1), fill=CORNER)
    draw_text(img, (sz + 4, H - 18), "BL 0,479",
              fill=(255, 255, 255, 255), scale=1, letter_spacing=2)
    d.rectangle((W - 1 - sz, H - 1 - sz, W - 1, H - 1), fill=CORNER)
    draw_text(img, (W - 1 - sz - 4, H - 18), "BR 799,479",
              fill=(255, 255, 255, 255), scale=1, anchor="rt",
              letter_spacing=2)

    # Center crosshair
    cx, cy = W // 2, H // 2
    d.line((cx - 60, cy, cx + 60, cy), fill=CENTER, width=2)
    d.line((cx, cy - 60, cx, cy + 60), fill=CENTER, width=2)
    draw_text(img, (cx, cy - 70),
              "CENTER  400,240",
              fill=CENTER + (255,), scale=2, anchor="mb",
              letter_spacing=2)

    return np.asarray(img.convert("RGB"), dtype="uint8")


def main():
    parser = argparse.ArgumentParser(
        description=("Phase 6G: display 800x480 viewport calibration "
                     "pattern via the integrated AudioLab HDMI path."))
    parser.add_argument("--hold-seconds", type=float, default=60.0,
                        help="seconds to hold the calibration frame")
    parser.add_argument("--offset-x", type=int, default=0)
    parser.add_argument("--offset-y", type=int, default=0)
    args = parser.parse_args()

    repo_paths()

    print("[phase6g] importing AudioLabOverlay")
    t0 = time.time()
    from audio_lab_pynq import AudioLabOverlay
    overlay_import_s = time.time() - t0
    print("[phase6g] AudioLabOverlay imported in {:.3f} s".format(
        overlay_import_s))

    print("[phase6g] loading AudioLabOverlay()")
    overlay = AudioLabOverlay()
    print("[phase6g] AudioLabOverlay ready")

    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend
    backend = AudioLabHdmiBackend(overlay)

    print("[phase6g] rendering calibration frame")
    frame = render_calibration_frame()
    print("[phase6g] frame shape = {}".format(frame.shape))

    print("[phase6g] starting HDMI backend with calibration frame")
    backend.start(frame, placement="manual",
                  offset_x=args.offset_x, offset_y=args.offset_y)

    meta = backend.write_frame(
        frame, placement="manual",
        offset_x=args.offset_x, offset_y=args.offset_y)
    status = backend.status() or {}
    errors = backend.errors() or {}
    print(json.dumps({
        "frame_meta": meta,
        "hdmi_status": status,
        "hdmi_errors": errors,
        "offset_x": args.offset_x,
        "offset_y": args.offset_y,
    }, indent=2, sort_keys=True, default=str))

    print("[phase6g] holding calibration frame for {} s".format(
        args.hold_seconds))
    print("[phase6g] Read off the X/Y axis labels at each LCD corner")
    print("[phase6g] and report:")
    print("[phase6g]   - which 'x=NN' label is at the LCD's left edge")
    print("[phase6g]   - which 'x=NN' label is at the LCD's right edge")
    print("[phase6g]   - which 'y=NN' label is at the LCD's top edge")
    print("[phase6g]   - which 'y=NN' label is at the LCD's bottom edge")
    print("[phase6g]   - whether each corner marker (TL/TR/BL/BR) is")
    print("[phase6g]     visible or cut off")
    time.sleep(float(args.hold_seconds))

    print("[phase6g] done")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        sys.exit(1)
