#!/usr/bin/env python3
"""Visible viewport calibration pattern for the integrated AudioLab HDMI path.

This Phase 4F helper loads ``AudioLabOverlay`` exactly once, draws a
1280x720 framebuffer-coordinate grid, and scans it out through
``AudioLabHdmiBackend``. It is intended for small HDMI LCDs that crop or
sample only part of the 1280x720 signal.

The script never loads ``base.bit`` and never calls ``run_pynq_hdmi()``.
"""
from __future__ import print_function

import argparse
import json
import os
import sys
import time
import traceback

import numpy as np
from PIL import Image, ImageDraw, ImageFont


WIDTH = 1280
HEIGHT = 720
LOGICAL_WIDTH = 800
LOGICAL_HEIGHT = 480


def _repo_paths():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(script_dir, ".."))
    for path in (repo_root, os.path.join(repo_root, "GUI"),
                 "/home/xilinx/Audio-Lab-PYNQ",
                 "/home/xilinx/Audio-Lab-PYNQ/GUI"):
        if path not in sys.path:
            sys.path.insert(0, path)


def _font(size):
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, int(size))
        except Exception:
            pass
    return ImageFont.load_default()


def _text_size(draw, text, font):
    try:
        return draw.textsize(text, font=font)
    except Exception:
        return (len(str(text)) * 8, 12)


def _label(draw, xy, text, font, fill=(255, 255, 255),
           anchor="lt", bg=(4, 6, 8)):
    x, y = int(xy[0]), int(xy[1])
    w, h = _text_size(draw, text, font)
    if anchor == "mm":
        box = (x - w // 2 - 5, y - h // 2 - 4,
               x + w // 2 + 5, y + h // 2 + 4)
        pos = (x - w // 2, y - h // 2)
    elif anchor == "rt":
        box = (x - w - 7, y - 3, x + 3, y + h + 5)
        pos = (x - w, y)
    elif anchor == "lb":
        box = (x - 4, y - h - 5, x + w + 6, y + 3)
        pos = (x, y - h)
    elif anchor == "rb":
        box = (x - w - 7, y - h - 5, x + 3, y + 3)
        pos = (x - w, y - h)
    else:
        box = (x - 4, y - 3, x + w + 6, y + h + 5)
        pos = (x, y)
    draw.rectangle(box, fill=bg, outline=(70, 78, 88))
    draw.text(pos, text, font=font, fill=fill)


def _rect_outline(draw, box, fill, width=1):
    x0, y0, x1, y1 = [int(v) for v in box]
    for n in range(int(width)):
        draw.rectangle((x0 + n, y0 + n, x1 - n, y1 - n), outline=fill)


def draw_viewport_pattern():
    img = Image.new("RGB", (WIDTH, HEIGHT), (4, 6, 8))
    draw = ImageDraw.Draw(img)
    font_tiny = _font(14)
    font_small = _font(18)
    font_med = _font(24)
    font_big = _font(34)

    # Full framebuffer grid. Stronger lines every 200 px help users estimate
    # the LCD's cropped viewport from a quick visual check.
    for x in range(0, WIDTH + 1, 20):
        xx = min(WIDTH - 1, x)
        if x % 200 == 0:
            color = (70, 92, 112)
        elif x % 100 == 0:
            color = (48, 64, 80)
        else:
            color = (24, 32, 42)
        draw.line((xx, 0, xx, HEIGHT - 1), fill=color)
    for y in range(0, HEIGHT + 1, 20):
        yy = min(HEIGHT - 1, y)
        if y % 200 == 0:
            color = (70, 92, 112)
        elif y % 100 == 0:
            color = (48, 64, 80)
        else:
            color = (24, 32, 42)
        draw.line((0, yy, WIDTH - 1, yy), fill=color)

    # High-contrast framebuffer edges and center cross.
    _rect_outline(draw, (0, 0, WIDTH - 1, HEIGHT - 1), (255, 255, 255), 3)
    draw.line((WIDTH // 2, 0, WIDTH // 2, HEIGHT - 1),
              fill=(0, 255, 160), width=2)
    draw.line((0, HEIGHT // 2, WIDTH - 1, HEIGHT // 2),
              fill=(0, 255, 160), width=2)
    _label(draw, (WIDTH // 2, HEIGHT // 2), "FB CENTER 640,360",
           font_big, fill=(0, 255, 160), anchor="mm")

    # Coordinate labels.
    for x in range(0, WIDTH + 1, 100):
        xx = min(WIDTH - 1, x)
        anchor = "rt" if x >= WIDTH else "lt"
        _label(draw, (xx + (0 if x >= WIDTH else 3), 4),
               "x{}".format(x), font_tiny, fill=(210, 230, 255),
               anchor=anchor)
    for y in range(0, HEIGHT + 1, 100):
        yy = min(HEIGHT - 1, y)
        anchor = "lb" if y >= HEIGHT else "lt"
        _label(draw, (4, yy + (0 if y >= HEIGHT else 3)),
               "y{}".format(y), font_tiny, fill=(210, 230, 255),
               anchor=anchor)

    _label(draw, (12, 42), "FB TL 0,0", font_small, fill=(255, 255, 255))
    _label(draw, (WIDTH - 12, 42), "FB TR 1280,0", font_small,
           fill=(255, 255, 255), anchor="rt")
    _label(draw, (12, HEIGHT - 12), "FB BL 0,720", font_small,
           fill=(255, 255, 255), anchor="lb")
    _label(draw, (WIDTH - 12, HEIGHT - 12), "FB BR 1280,720", font_small,
           fill=(255, 255, 255), anchor="rb")

    candidates = [
        (0, 0, (255, 90, 90), "800x480 offset 0,0"),
        (120, 60, (255, 210, 80), "800x480 offset 120,60"),
        (240, 120, (80, 220, 255), "800x480 center 240,120"),
        (320, 120, (190, 130, 255), "800x480 offset 320,120"),
    ]
    for ox, oy, color, label in candidates:
        x0, y0 = int(ox), int(oy)
        x1 = x0 + LOGICAL_WIDTH - 1
        y1 = y0 + LOGICAL_HEIGHT - 1
        _rect_outline(draw, (x0, y0, x1, y1), color, 4)
        _label(draw, (x0 + 12, y0 + 12), label, font_med,
               fill=color, anchor="lt")
        _label(draw, (x1 - 12, y1 - 12),
               "{}x{}".format(LOGICAL_WIDTH, LOGICAL_HEIGHT),
               font_small, fill=color, anchor="rb")

    _label(draw, (WIDTH // 2, HEIGHT - 56),
           "Read visible top-left / bottom-right coordinates on the LCD",
           font_med, fill=(255, 255, 255), anchor="mm")
    return np.asarray(img, dtype=np.uint8)


def smoke(overlay):
    ip_keys = set(getattr(overlay, "ip_dict", {}).keys())
    return {
        "ADC HPF": bool(overlay.codec.get_adc_hpf_state()),
        "R19": "0x{:02x}".format(int(overlay.codec.R19_ADC_CONTROL[0]) & 0xFF),
        "has axi_gpio_delay_line": hasattr(overlay, "axi_gpio_delay_line"),
        "has legacy axi_gpio_delay": hasattr(overlay, "axi_gpio_delay"),
        "has axi_vdma_hdmi ip_dict": "axi_vdma_hdmi" in ip_keys,
        "has v_tc_hdmi ip_dict": "v_tc_hdmi" in ip_keys,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--hold-seconds", type=int, default=60)
    args = parser.parse_args()

    _repo_paths()
    report = {
        "phase": "4F-viewport-calibration",
        "started_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "hold_seconds": int(args.hold_seconds),
        "framebuffer_size": [WIDTH, HEIGHT],
        "candidate_frames": [
            {"offset_x": 0, "offset_y": 0, "size": [800, 480]},
            {"offset_x": 120, "offset_y": 60, "size": [800, 480]},
            {"offset_x": 240, "offset_y": 120, "size": [800, 480]},
            {"offset_x": 320, "offset_y": 120, "size": [800, 480]},
        ],
    }

    print("[phase4f] importing AudioLabOverlay")
    t0 = time.time()
    from audio_lab_pynq import AudioLabOverlay
    report["overlay_import_s"] = time.time() - t0
    print("[phase4f] AudioLabOverlay imported in {:.3f} s".format(
        report["overlay_import_s"]))

    print("[phase4f] loading AudioLabOverlay() (single load)")
    t0 = time.time()
    overlay = AudioLabOverlay()
    report["overlay_load_s"] = time.time() - t0
    print("[phase4f] AudioLabOverlay() ready in {:.3f} s".format(
        report["overlay_load_s"]))

    pre_smoke = smoke(overlay)
    report["smoke_pre_hdmi"] = pre_smoke
    print(json.dumps({"smoke_pre_hdmi": pre_smoke}, indent=2, sort_keys=True))
    if not (pre_smoke["ADC HPF"] and pre_smoke["R19"] == "0x23" and
            not pre_smoke["has axi_gpio_delay_line"] and
            pre_smoke["has legacy axi_gpio_delay"] and
            pre_smoke["has axi_vdma_hdmi ip_dict"] and
            pre_smoke["has v_tc_hdmi ip_dict"]):
        raise SystemExit("[phase4f] pre-HDMI smoke failed")

    print("[phase4f] drawing 1280x720 viewport calibration pattern")
    t0 = time.time()
    frame = draw_viewport_pattern()
    report["draw_s"] = time.time() - t0
    print("[phase4f] frame shape={} dtype={} draw={:.3f}s".format(
        list(frame.shape), frame.dtype, report["draw_s"]))

    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend
    backend = AudioLabHdmiBackend(overlay)
    print("[phase4f] starting HDMI back end with native calibration frame")
    t0 = time.time()
    backend.start(frame)
    report["backend_start_s"] = time.time() - t0
    time.sleep(0.1)

    status = backend.status()
    errors = backend.errors()
    report["hdmi_status"] = status
    report["hdmi_errors"] = errors
    print(json.dumps({"hdmi_status": status, "hdmi_errors": errors,
                      "backend_start_s": report["backend_start_s"]},
                     indent=2, sort_keys=True))
    if errors.get("dmainterr") or errors.get("dmaslverr") or errors.get("dmadecerr"):
        raise SystemExit("[phase4f] VDMA error bits set")

    if int(args.hold_seconds) > 0:
        print("[phase4f] holding HDMI scanout for {} seconds".format(
            int(args.hold_seconds)))
        time.sleep(int(args.hold_seconds))

    print("[phase4f] physical viewport coordinates are user visual confirmation pending")
    print(json.dumps({"summary": report}, indent=2, sort_keys=True))
    print("[phase4f] OK")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
