#!/usr/bin/env python3
"""HDMI LCD fit / overscan test pattern for the integrated AudioLab overlay.

This script loads ``AudioLabOverlay`` exactly once, draws a 1280x720 RGB
test pattern, and sends it through ``AudioLabHdmiBackend`` with an optional
fit mode. It never loads ``base.bit`` and never calls ``run_pynq_hdmi()``.
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


FIT_MODE_CHOICES = ("native", "fit-97", "fit-95", "fit-90", "fit-85", "fit-80")
WIDTH = 1280
HEIGHT = 720


def _repo_paths():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(script_dir, ".."))
    for path in (repo_root, os.path.join(repo_root, "GUI"),
                 "/home/xilinx/Audio-Lab-PYNQ",
                 "/home/xilinx/Audio-Lab-PYNQ/GUI"):
        if path not in sys.path:
            sys.path.insert(0, path)


def _font(size):
    # PYNQ's Pillow image often has DejaVu. Fall back to the built-in bitmap
    # font so the pattern still runs on a minimal image.
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
           anchor="mm", bg=(0, 0, 0)):
    x, y = xy
    w, h = _text_size(draw, text, font)
    if anchor == "mm":
        box = (x - w // 2 - 6, y - h // 2 - 4,
               x + w // 2 + 6, y + h // 2 + 4)
        pos = (x - w // 2, y - h // 2)
    elif anchor == "lt":
        box = (x - 4, y - 3, x + w + 6, y + h + 5)
        pos = (x, y)
    elif anchor == "rt":
        box = (x - w - 6, y - 3, x + 4, y + h + 5)
        pos = (x - w, y)
    elif anchor == "lb":
        box = (x - 4, y - h - 5, x + w + 6, y + 3)
        pos = (x, y - h)
    elif anchor == "rb":
        box = (x - w - 6, y - h - 5, x + 4, y + 3)
        pos = (x - w, y - h)
    else:
        box = (x - 4, y - 3, x + w + 6, y + h + 5)
        pos = (x, y)
    draw.rectangle(box, fill=bg, outline=(80, 80, 80))
    draw.text(pos, text, font=font, fill=fill)


def draw_fit_pattern(width=WIDTH, height=HEIGHT, fit_mode="native",
                     scale=None):
    img = Image.new("RGB", (int(width), int(height)), (5, 7, 9))
    draw = ImageDraw.Draw(img)
    font_big = _font(42)
    font_med = _font(28)
    font_small = _font(20)

    # Low-contrast grid first.
    for x in range(0, int(width), 80):
        color = (35, 45, 55) if x % 160 else (50, 65, 78)
        draw.line((x, 0, x, int(height) - 1), fill=color)
    for y in range(0, int(height), 60):
        color = (35, 45, 55) if y % 120 else (50, 65, 78)
        draw.line((0, y, int(width) - 1, y), fill=color)

    # Colored edge bands are deliberately thin enough that overscan cropping
    # is obvious, but thick enough to be visible on small LCDs.
    draw.rectangle((0, 0, int(width) - 1, 7), fill=(255, 0, 0))
    draw.rectangle((0, int(height) - 8, int(width) - 1, int(height) - 1),
                   fill=(0, 0, 255))
    draw.rectangle((0, 0, 7, int(height) - 1), fill=(0, 255, 0))
    draw.rectangle((int(width) - 8, 0, int(width) - 1, int(height) - 1),
                   fill=(255, 255, 0))

    # Inset borders: these make LCD crop amount easy to estimate by eye.
    borders = [
        (0, (255, 255, 255), 1, "0px"),
        (10, (255, 64, 64), 2, "10px"),
        (20, (255, 210, 64), 2, "20px"),
        (40, (64, 220, 255), 2, "40px"),
    ]
    for inset, color, width_px, label in borders:
        for n in range(width_px):
            draw.rectangle((inset + n, inset + n,
                            int(width) - 1 - inset - n,
                            int(height) - 1 - inset - n),
                           outline=color)
        _label(draw, (int(width) // 2, inset + 18), label,
               font_small, fill=color)

    cx = int(width) // 2
    cy = int(height) // 2
    draw.line((cx, 0, cx, int(height) - 1), fill=(0, 255, 160), width=2)
    draw.line((0, cy, int(width) - 1, cy), fill=(0, 255, 160), width=2)
    for radius in (14, 13, 12):
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius),
                     outline=(0, 255, 160))

    _label(draw, (cx, cy - 48), "CENTER", font_big, fill=(255, 255, 255))
    _label(draw, (cx, cy + 24), "{}x{}".format(int(width), int(height)),
           font_med, fill=(255, 255, 255))
    scale_text = "custom {:.3f}".format(float(scale)) if scale is not None else fit_mode
    _label(draw, (cx, cy + 72), "fit mode: {}".format(scale_text),
           font_med, fill=(255, 220, 80))

    _label(draw, (48, 48), "TL", font_big, fill=(255, 255, 255), anchor="lt")
    _label(draw, (int(width) - 48, 48), "TR", font_big,
           fill=(255, 255, 255), anchor="rt")
    _label(draw, (48, int(height) - 48), "BL", font_big,
           fill=(255, 255, 255), anchor="lb")
    _label(draw, (int(width) - 48, int(height) - 48), "BR", font_big,
           fill=(255, 255, 255), anchor="rb")

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
    parser.add_argument("--fit-mode", default="native",
                        choices=FIT_MODE_CHOICES)
    parser.add_argument("--scale", type=float, default=None,
                        help="custom 0..1 scale overriding --fit-mode")
    parser.add_argument("--hold-seconds", type=int, default=60)
    args = parser.parse_args()

    _repo_paths()

    report = {
        "phase": "4D-fit-pattern",
        "started_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "fit_mode": args.fit_mode,
        "scale_override": args.scale,
        "hold_seconds": int(args.hold_seconds),
    }

    print("[phase4d] importing AudioLabOverlay")
    t0 = time.time()
    from audio_lab_pynq import AudioLabOverlay
    print("[phase4d] AudioLabOverlay imported in {:.3f} s".format(time.time() - t0))

    print("[phase4d] loading AudioLabOverlay() (single load)")
    t0 = time.time()
    overlay = AudioLabOverlay()
    print("[phase4d] AudioLabOverlay() ready in {:.3f} s".format(time.time() - t0))

    pre_smoke = smoke(overlay)
    report["smoke_pre_hdmi"] = pre_smoke
    print(json.dumps({"smoke_pre_hdmi": pre_smoke}, indent=2, sort_keys=True))
    if not (pre_smoke["ADC HPF"] and pre_smoke["R19"] == "0x23" and
            not pre_smoke["has axi_gpio_delay_line"] and
            pre_smoke["has legacy axi_gpio_delay"] and
            pre_smoke["has axi_vdma_hdmi ip_dict"] and
            pre_smoke["has v_tc_hdmi ip_dict"]):
        raise SystemExit("[phase4d] pre-HDMI smoke failed")

    print("[phase4d] drawing fit test pattern")
    t0 = time.time()
    frame = draw_fit_pattern(fit_mode=args.fit_mode, scale=args.scale)
    draw_s = time.time() - t0
    print("[phase4d] frame shape={} dtype={} draw={:.3f}s".format(
        list(frame.shape), frame.dtype, draw_s))

    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend
    backend = AudioLabHdmiBackend(overlay)
    print("[phase4d] starting HDMI back end fit_mode={} scale_override={}".format(
        args.fit_mode, args.scale))
    t0 = time.time()
    backend.start(frame, fit_mode=args.fit_mode, scale=args.scale)
    backend_start_s = time.time() - t0
    time.sleep(0.1)

    status = backend.status()
    errors = backend.errors()
    report["draw_s"] = draw_s
    report["backend_start_s"] = backend_start_s
    report["hdmi_status"] = status
    report["hdmi_errors"] = errors
    print(json.dumps({"hdmi_status": status, "hdmi_errors": errors,
                      "backend_start_s": backend_start_s},
                     indent=2, sort_keys=True))
    if errors.get("dmainterr") or errors.get("dmaslverr") or errors.get("dmadecerr"):
        raise SystemExit("[phase4d] VDMA error bits set")

    if int(args.hold_seconds) > 0:
        print("[phase4d] holding HDMI scanout for {} seconds".format(
            int(args.hold_seconds)))
        time.sleep(int(args.hold_seconds))

    print("[phase4d] physical LCD fit is user visual confirmation pending")
    print(json.dumps({"summary": report}, indent=2, sort_keys=True))
    print("[phase4d] OK")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
