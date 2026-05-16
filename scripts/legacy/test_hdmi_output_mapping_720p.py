#!/usr/bin/env python3
"""Phase 5A 720p HDMI output mapping pattern for the 5-inch LCD.

This helper diagnoses the output-side mapping between the fixed
1280x720 HDMI active area and the LCD's visible viewport. It does not
try to compensate with Python offsets. A user should read the x/y
coordinates and candidate 800x480 boxes visible on the physical LCD.

Loads ``AudioLabOverlay()`` exactly once, does not load ``base.bit``,
does not load a second overlay, and does not call ``run_pynq_hdmi()``.
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
           anchor="lt", bg=(4, 6, 8), outline=(72, 82, 94)):
    x, y = int(xy[0]), int(xy[1])
    w, h = _text_size(draw, text, font)
    if anchor == "mm":
        box = (x - w // 2 - 6, y - h // 2 - 4,
               x + w // 2 + 6, y + h // 2 + 4)
        pos = (x - w // 2, y - h // 2)
    elif anchor == "rt":
        box = (x - w - 8, y - 3, x + 3, y + h + 5)
        pos = (x - w, y)
    elif anchor == "lb":
        box = (x - 4, y - h - 5, x + w + 6, y + 3)
        pos = (x, y - h)
    elif anchor == "rb":
        box = (x - w - 8, y - h - 5, x + 3, y + 3)
        pos = (x - w, y - h)
    else:
        box = (x - 4, y - 3, x + w + 6, y + h + 5)
        pos = (x, y)
    draw.rectangle(box, fill=bg, outline=outline)
    draw.text(pos, text, font=font, fill=fill)


def _rect_outline(draw, box, fill, width=1):
    x0, y0, x1, y1 = [int(v) for v in box]
    for n in range(int(width)):
        draw.rectangle((x0 + n, y0 + n, x1 - n, y1 - n), outline=fill)


def draw_output_mapping_pattern():
    img = Image.new("RGB", (WIDTH, HEIGHT), (3, 5, 8))
    draw = ImageDraw.Draw(img)
    font_tiny = _font(13)
    font_small = _font(18)
    font_med = _font(24)
    font_big = _font(40)

    for x in range(0, WIDTH + 1, 50):
        xx = min(WIDTH - 1, x)
        if x % 200 == 0:
            color = (78, 100, 122)
            line_w = 2
        elif x % 100 == 0:
            color = (52, 70, 88)
            line_w = 1
        else:
            color = (26, 36, 48)
            line_w = 1
        draw.line((xx, 0, xx, HEIGHT - 1), fill=color, width=line_w)
    for y in range(0, HEIGHT + 1, 50):
        yy = min(HEIGHT - 1, y)
        if y % 200 == 0:
            color = (78, 100, 122)
            line_w = 2
        elif y % 100 == 0:
            color = (52, 70, 88)
            line_w = 1
        else:
            color = (26, 36, 48)
            line_w = 1
        draw.line((0, yy, WIDTH - 1, yy), fill=color, width=line_w)

    _rect_outline(draw, (0, 0, WIDTH - 1, HEIGHT - 1), (255, 255, 255), 4)
    _rect_outline(draw, (10, 10, WIDTH - 11, HEIGHT - 11), (255, 82, 82), 2)
    _rect_outline(draw, (40, 40, WIDTH - 41, HEIGHT - 41), (255, 216, 76), 2)
    draw.line((WIDTH // 2, 0, WIDTH // 2, HEIGHT - 1),
              fill=(0, 255, 170), width=2)
    draw.line((0, HEIGHT // 2, WIDTH - 1, HEIGHT // 2),
              fill=(0, 255, 170), width=2)

    for x in range(0, WIDTH + 1, 100):
        xx = min(WIDTH - 1, x)
        if x >= WIDTH:
            _label(draw, (WIDTH - 4, 4), "x{}".format(x), font_tiny,
                   fill=(220, 236, 255), anchor="rt")
            _label(draw, (WIDTH - 4, HEIGHT - 4), "x{}".format(x), font_tiny,
                   fill=(220, 236, 255), anchor="rb")
        else:
            _label(draw, (xx + 3, 4), "x{}".format(x), font_tiny,
                   fill=(220, 236, 255))
            _label(draw, (xx + 3, HEIGHT - 4), "x{}".format(x), font_tiny,
                   fill=(220, 236, 255), anchor="lb")
    for y in range(0, HEIGHT + 1, 100):
        yy = min(HEIGHT - 1, y)
        if y >= HEIGHT:
            _label(draw, (4, HEIGHT - 4), "y{}".format(y), font_tiny,
                   fill=(220, 236, 255), anchor="lb")
            _label(draw, (WIDTH - 4, HEIGHT - 4), "y{}".format(y), font_tiny,
                   fill=(220, 236, 255), anchor="rb")
        else:
            _label(draw, (4, yy + 3), "y{}".format(y), font_tiny,
                   fill=(220, 236, 255))
            _label(draw, (WIDTH - 4, yy + 3), "y{}".format(y), font_tiny,
                   fill=(220, 236, 255), anchor="rt")

    _label(draw, (WIDTH // 2, 74), "OUTPUT MAP 720P", font_big,
           fill=(255, 255, 255), anchor="mm", bg=(0, 0, 0))
    _label(draw, (WIDTH // 2, 126), "1280x720 HDMI ACTIVE", font_med,
           fill=(0, 255, 170), anchor="mm", bg=(0, 0, 0))
    _label(draw, (WIDTH // 2, HEIGHT // 2), "CENTER 640,360", font_big,
           fill=(0, 255, 170), anchor="mm", bg=(0, 0, 0))

    candidates = [
        (0, 0, (255, 92, 92), "800x480 x0 y0"),
        (240, 120, (80, 220, 255), "800x480 center x240 y120"),
        (0, 120, (255, 220, 80), "800x480 x0 y120"),
        (160, 120, (190, 140, 255), "800x480 x160 y120"),
    ]
    for ox, oy, color, label in candidates:
        x0 = int(ox)
        y0 = int(oy)
        x1 = x0 + LOGICAL_WIDTH - 1
        y1 = y0 + LOGICAL_HEIGHT - 1
        _rect_outline(draw, (x0, y0, x1, y1), color, 4)
        _label(draw, (x0 + 12, y0 + 12), label, font_med,
               fill=color, anchor="lt", bg=(0, 0, 0))
        _label(draw, (x1 - 12, y1 - 12),
               "w800 h480", font_small, fill=color,
               anchor="rb", bg=(0, 0, 0))

    _label(draw, (14, 44), "TL 0,0", font_small, fill=(255, 255, 255))
    _label(draw, (WIDTH - 14, 44), "TR 1280,0", font_small,
           fill=(255, 255, 255), anchor="rt")
    _label(draw, (14, HEIGHT - 44), "BL 0,720", font_small,
           fill=(255, 255, 255), anchor="lb")
    _label(draw, (WIDTH - 14, HEIGHT - 44), "BR 1280,720", font_small,
           fill=(255, 255, 255), anchor="rb")
    _label(draw, (WIDTH // 2, HEIGHT - 28),
           "Read visible x/y labels on the LCD; do not tune offsets here",
           font_med, fill=(255, 255, 255), anchor="mm", bg=(0, 0, 0))
    return np.asarray(img, dtype=np.uint8)


def hwh_contains(instance_name):
    candidates = [
        os.path.join(os.path.dirname(__file__), "..",
                     "audio_lab_pynq", "bitstreams", "audio_lab.hwh"),
        os.path.join(os.path.dirname(os.path.dirname(__file__)),
                     "audio_lab_pynq", "bitstreams", "audio_lab.hwh"),
        "/usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams/audio_lab.hwh",
    ]
    for path in candidates:
        try:
            with open(os.path.abspath(path), "r") as fp:
                return instance_name in fp.read()
        except IOError:
            continue
    return False


def smoke(overlay):
    ip_keys = set(getattr(overlay, "ip_dict", {}).keys())
    return {
        "ADC HPF": bool(overlay.codec.get_adc_hpf_state()),
        "R19": "0x{:02x}".format(int(overlay.codec.R19_ADC_CONTROL[0]) & 0xFF),
        "has axi_gpio_delay_line": hasattr(overlay, "axi_gpio_delay_line"),
        "has legacy axi_gpio_delay": hasattr(overlay, "axi_gpio_delay"),
        "has axi_vdma_hdmi ip_dict": "axi_vdma_hdmi" in ip_keys,
        "has v_tc_hdmi ip_dict": "v_tc_hdmi" in ip_keys,
        "has rgb2dvi_hdmi in HWH": hwh_contains("rgb2dvi_hdmi"),
        "has v_axi4s_vid_out_hdmi in HWH": hwh_contains("v_axi4s_vid_out_hdmi"),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--hold-seconds", type=int, default=60)
    args = parser.parse_args()

    _repo_paths()
    report = {
        "phase": "5A-output-mapping-720p",
        "started_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "hold_seconds": int(args.hold_seconds),
        "framebuffer_size": [WIDTH, HEIGHT],
        "candidate_boxes": [
            {"offset_x": 0, "offset_y": 0, "size": [800, 480]},
            {"offset_x": 240, "offset_y": 120, "size": [800, 480]},
            {"offset_x": 0, "offset_y": 120, "size": [800, 480]},
            {"offset_x": 160, "offset_y": 120, "size": [800, 480]},
        ],
    }

    print("[phase5a] importing AudioLabOverlay")
    t0 = time.time()
    from audio_lab_pynq import AudioLabOverlay
    report["overlay_import_s"] = time.time() - t0
    print("[phase5a] AudioLabOverlay imported in {:.3f} s".format(
        report["overlay_import_s"]))

    print("[phase5a] loading AudioLabOverlay() (single load)")
    t0 = time.time()
    overlay = AudioLabOverlay()
    report["overlay_load_s"] = time.time() - t0
    print("[phase5a] AudioLabOverlay() ready in {:.3f} s".format(
        report["overlay_load_s"]))

    pre_smoke = smoke(overlay)
    report["smoke_pre_hdmi"] = pre_smoke
    print(json.dumps({"smoke_pre_hdmi": pre_smoke}, indent=2, sort_keys=True))
    if not (pre_smoke["ADC HPF"] and pre_smoke["R19"] == "0x23" and
            not pre_smoke["has axi_gpio_delay_line"] and
            pre_smoke["has legacy axi_gpio_delay"] and
            pre_smoke["has axi_vdma_hdmi ip_dict"] and
            pre_smoke["has v_tc_hdmi ip_dict"] and
            pre_smoke["has rgb2dvi_hdmi in HWH"] and
            pre_smoke["has v_axi4s_vid_out_hdmi in HWH"]):
        raise SystemExit("[phase5a] pre-HDMI smoke failed")

    print("[phase5a] drawing 1280x720 output mapping pattern")
    t0 = time.time()
    frame = draw_output_mapping_pattern()
    report["draw_s"] = time.time() - t0
    print("[phase5a] frame shape={} dtype={} draw={:.3f}s".format(
        list(frame.shape), frame.dtype, report["draw_s"]))

    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend
    backend = AudioLabHdmiBackend(overlay)
    print("[phase5a] starting HDMI backend with native 1280x720 frame")
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
        raise SystemExit("[phase5a] VDMA error bits set")

    if int(args.hold_seconds) > 0:
        print("[phase5a] holding HDMI scanout for {} seconds".format(
            int(args.hold_seconds)))
        time.sleep(int(args.hold_seconds))

    out_path = "/tmp/hdmi_phase5a_output_mapping_720p.json"
    with open(out_path, "w") as fp:
        json.dump(report, fp, indent=2, sort_keys=True, default=str)
    print("[phase5a] report saved to {}".format(out_path))
    print("[phase5a] user must read visible x/y coordinates on the LCD")
    print(json.dumps({"summary": report}, indent=2, sort_keys=True,
                     default=str))
    print("[phase5a] OK")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
