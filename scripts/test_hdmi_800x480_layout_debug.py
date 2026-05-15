#!/usr/bin/env python3
"""Phase 4H 800x480 layout-debug overlay.

Renders the compact-v2 800x480 logical GUI and draws a diagnostic
overlay on top: a 50 px coordinate grid, axis labels around the
border, panel bounding boxes for header / chain / FX / monitor, the
canvas outer frame, and a footer that names the variant, the
placement offset, and the canvas size.

This script is used after Phase 4G when the user reports the
horizontal direction does not overflow on the 5-inch LCD but the left
strip still appears unused or invisible. The overlay makes it possible
to see, from a single photo:

- whether x=0..100 of the logical canvas reaches the panel at all,
- whether the renderer leaves any logical region cosmetically empty,
- which panel bbox lands where on the visible viewport.

The script loads ``AudioLabOverlay()`` exactly once, does not load
``base.bit``, does not load a second overlay, and does not call
``run_pynq_hdmi()``.
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


CANVAS_W = 800
CANVAS_H = 480


def repo_paths():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(script_dir, ".."))
    for path in (repo_root, os.path.join(repo_root, "GUI"),
                 "/home/xilinx/Audio-Lab-PYNQ",
                 "/home/xilinx/Audio-Lab-PYNQ/GUI"):
        if path not in sys.path:
            sys.path.insert(0, path)


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


def _label(draw, xy, text, font, fill=(255, 230, 100),
           anchor="lt", bg=(2, 4, 6)):
    x, y = int(xy[0]), int(xy[1])
    w, h = _text_size(draw, text, font)
    if anchor == "mm":
        box = (x - w // 2 - 3, y - h // 2 - 2,
               x + w // 2 + 3, y + h // 2 + 2)
        pos = (x - w // 2, y - h // 2)
    elif anchor == "rt":
        box = (x - w - 5, y - 2, x + 2, y + h + 2)
        pos = (x - w, y)
    elif anchor == "lb":
        box = (x - 2, y - h - 2, x + w + 5, y + 2)
        pos = (x, y - h)
    elif anchor == "rb":
        box = (x - w - 5, y - h - 2, x + 2, y + 2)
        pos = (x - w, y - h)
    else:
        box = (x - 2, y - 2, x + w + 5, y + h + 2)
        pos = (x, y)
    draw.rectangle(box, fill=bg)
    draw.text(pos, text, font=font, fill=fill)


def overlay_layout_debug(rgb_frame, offset_x, offset_y, variant_label):
    """Return an RGB888 ndarray with a layout-debug overlay composited."""
    if rgb_frame.shape != (CANVAS_H, CANVAS_W, 3):
        raise ValueError(
            "expected 480x800x3 base frame, got {}".format(rgb_frame.shape))
    pil = Image.fromarray(rgb_frame, "RGB").convert("RGBA")
    overlay = Image.new("RGBA", pil.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    font_tiny = _font(11)
    font_small = _font(14)
    font_med = _font(18)

    # 50 px grid lines spanning the whole logical canvas.
    for x in range(0, CANVAS_W + 1, 50):
        col = (255, 240, 120, 110) if x % 100 == 0 else (200, 200, 60, 70)
        if x in (0, CANVAS_W):
            col = (255, 255, 255, 220)
        xx = min(CANVAS_W - 1, x)
        draw.line((xx, 0, xx, CANVAS_H - 1), fill=col, width=1)
    for y in range(0, CANVAS_H + 1, 50):
        col = (255, 240, 120, 110) if y % 100 == 0 else (200, 200, 60, 70)
        if y in (0, CANVAS_H):
            col = (255, 255, 255, 220)
        yy = min(CANVAS_H - 1, y)
        draw.line((0, yy, CANVAS_W - 1, yy), fill=col, width=1)

    # Logical canvas hard border so the LCD viewport can be matched
    # against (0,0)..(800,480) directly.
    draw.rectangle((0, 0, CANVAS_W - 1, CANVAS_H - 1),
                   outline=(255, 255, 255, 230))

    # Axis labels.
    for x in range(0, CANVAS_W + 1, 100):
        xx = min(CANVAS_W - 1, x)
        anchor = "rt" if x >= CANVAS_W else "lt"
        _label(draw, (xx + (-3 if x >= CANVAS_W else 2), 2),
               "x{}".format(x), font_tiny, fill=(255, 240, 120),
               anchor=anchor)
        _label(draw, (xx + (-3 if x >= CANVAS_W else 2), CANVAS_H - 14),
               "x{}".format(x), font_tiny, fill=(255, 240, 120),
               anchor=anchor)
    for y in range(0, CANVAS_H + 1, 100):
        yy = min(CANVAS_H - 1, y)
        anchor = "lb" if y >= CANVAS_H else "lt"
        _label(draw, (2, yy + (-3 if y >= CANVAS_H else 2)),
               "y{}".format(y), font_tiny, fill=(255, 240, 120),
               anchor=anchor)
        _label(draw, (CANVAS_W - 26, yy + (-3 if y >= CANVAS_H else 2)),
               "y{}".format(y), font_tiny, fill=(255, 240, 120),
               anchor=anchor)

    # Panel bboxes from compact_v2_panel_boxes() so the user can compare
    # rendered panel edges with the visible viewport.
    from pynq_multi_fx_gui import compact_v2_panel_boxes
    boxes = compact_v2_panel_boxes(CANVAS_W, CANVAS_H)
    palette = {
        "outer":  (255, 90, 90, 220),
        "header": (90, 220, 255, 220),
        "chain":  (160, 255, 110, 220),
        "fx":     (255, 200, 70, 220),
        "side":   (210, 130, 255, 220),
    }
    for name, box in boxes.items():
        x0, y0, x1, y1 = [int(v) for v in box]
        col = palette[name]
        draw.rectangle((x0, y0, x1, y1), outline=col)
        _label(draw, (x0 + 4, y0 + 4), "{} {},{}".format(name, x0, y0),
               font_small, fill=col, anchor="lt")
        _label(draw, (x1 - 4, y1 - 4), "{},{}".format(x1, y1),
               font_small, fill=col, anchor="rb")

    # Left strip emphasis: the area the user reported as "unused/invisible".
    draw.rectangle((0, 0, 100, CANVAS_H - 1),
                   outline=(255, 90, 90, 200))
    _label(draw, (4, CANVAS_H // 2), "LEFT  STRIP  x=0..100",
           font_med, fill=(255, 90, 90), anchor="lm")

    # Top strip emphasis: phase 4H added top safe margin for this region.
    draw.rectangle((0, 0, CANVAS_W - 1, 40),
                   outline=(90, 220, 255, 200))
    _label(draw, (CANVAS_W // 2, 4), "TOP  STRIP  y=0..40",
           font_med, fill=(90, 220, 255), anchor="mt")

    # Footer summary: variant, requested placement, canvas size.
    foot_text = "debug=layout  variant={}  offset=({:+d},{:+d})  canvas={}x{}".format(
        variant_label, int(offset_x), int(offset_y), CANVAS_W, CANVAS_H)
    fw, fh = _text_size(draw, foot_text, font_med)
    draw.rectangle((CANVAS_W // 2 - fw // 2 - 8, CANVAS_H - fh - 10,
                    CANVAS_W // 2 + fw // 2 + 8, CANVAS_H - 4),
                   fill=(0, 0, 0, 220), outline=(255, 240, 120, 230))
    draw.text((CANVAS_W // 2 - fw // 2, CANVAS_H - fh - 8),
              foot_text, font=font_med, fill=(255, 240, 120))

    composed = Image.alpha_composite(pil, overlay).convert("RGB")
    return np.asarray(composed, dtype=np.uint8)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--hold-seconds", type=int, default=60)
    parser.add_argument("--variant", default="compact-v2",
                        choices=("compact-v1", "compact-v2"))
    parser.add_argument("--placement", default="manual",
                        choices=("center", "manual"))
    parser.add_argument("--offset-x", type=int, default=0,
                        help="manual placement X offset (may be negative)")
    parser.add_argument("--offset-y", type=int, default=0,
                        help="manual placement Y offset (may be negative)")
    args = parser.parse_args()

    repo_paths()
    variant_label = args.variant
    report = {
        "phase": "4H-layout-debug",
        "started_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "variant": variant_label,
        "placement": args.placement,
        "offset_x": int(args.offset_x),
        "offset_y": int(args.offset_y),
        "hold_seconds": int(args.hold_seconds),
    }

    print("[phase4h] importing AudioLabOverlay")
    t0 = time.time()
    from audio_lab_pynq import AudioLabOverlay
    report["overlay_import_s"] = time.time() - t0
    print("[phase4h] AudioLabOverlay imported in {:.3f} s".format(
        report["overlay_import_s"]))

    print("[phase4h] loading AudioLabOverlay() (single load)")
    t0 = time.time()
    overlay = AudioLabOverlay()
    report["overlay_load_s"] = time.time() - t0
    print("[phase4h] AudioLabOverlay() ready in {:.3f} s".format(
        report["overlay_load_s"]))

    pre_smoke = smoke(overlay)
    report["smoke_pre_hdmi"] = pre_smoke
    print(json.dumps({"smoke_pre_hdmi": pre_smoke}, indent=2, sort_keys=True))
    if not (pre_smoke["ADC HPF"] and pre_smoke["R19"] == "0x23" and
            not pre_smoke["has axi_gpio_delay_line"] and
            pre_smoke["has legacy axi_gpio_delay"] and
            pre_smoke["has axi_vdma_hdmi ip_dict"] and
            pre_smoke["has v_tc_hdmi ip_dict"]):
        raise SystemExit("[phase4h] pre-HDMI smoke failed")

    from pynq_multi_fx_gui import (
        AppState, make_pynq_static_render_cache, render_frame_800x480,
        compact_v2_panel_boxes,
    )
    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend

    state = AppState()
    cache = make_pynq_static_render_cache()
    print("[phase4h] rendering compact-v2 base frame")
    t0 = time.time()
    base_frame = render_frame_800x480(state, cache=cache,
                                      variant=args.variant,
                                      placement_label="debug=layout")
    base_render_s = time.time() - t0
    print("[phase4h] base frame render={:.3f}s".format(base_render_s))

    print("[phase4h] compositing layout-debug overlay")
    t0 = time.time()
    frame = overlay_layout_debug(base_frame, args.offset_x, args.offset_y,
                                 variant_label)
    overlay_s = time.time() - t0
    print("[phase4h] overlay composed in {:.3f}s shape={}".format(
        overlay_s, list(frame.shape)))

    report["base_render_s"] = base_render_s
    report["overlay_compose_s"] = overlay_s
    report["panel_boxes"] = {
        k: list(v) for k, v in compact_v2_panel_boxes().items()
    }

    backend = AudioLabHdmiBackend(overlay)
    print("[phase4h] starting HDMI back end placement={} offset=({:+d},{:+d})".format(
        args.placement, int(args.offset_x), int(args.offset_y)))
    t0 = time.time()
    backend.start(frame, placement=args.placement,
                  offset_x=args.offset_x, offset_y=args.offset_y)
    report["backend_start_s"] = time.time() - t0
    time.sleep(0.1)

    status = backend.status()
    errors = backend.errors()
    last_write = status.get("last_frame_write", {}) or {}
    report["hdmi_status"] = status
    report["hdmi_errors"] = errors
    report["last_frame_write"] = last_write
    print(json.dumps({"hdmi_errors": errors,
                      "backend_start_s": report["backend_start_s"],
                      "panel_boxes": report["panel_boxes"],
                      "framebuffer_copied_region":
                          last_write.get("framebuffer_copied_region"),
                      "source_visible_region":
                          last_write.get("source_visible_region")},
                     indent=2, sort_keys=True))
    if (errors.get("dmainterr") or errors.get("dmaslverr")
            or errors.get("dmadecerr")):
        raise SystemExit("[phase4h] VDMA error bits set")

    if int(args.hold_seconds) > 0:
        print("[phase4h] holding layout-debug pattern for {} seconds".format(
            int(args.hold_seconds)))
        time.sleep(int(args.hold_seconds))

    print("[phase4h] applying Safe Bypass through existing overlay APIs")
    overlay.clear_distortion_pedals()
    overlay.set_noise_suppressor_settings(enabled=False)
    overlay.set_compressor_settings(enabled=False)
    overlay.set_guitar_effects(noise_gate_on=False, overdrive_on=False,
                               distortion_on=False, rat_on=False,
                               amp_on=False, cab_on=False, eq_on=False,
                               reverb_on=False)

    post_smoke = smoke(overlay)
    report["smoke_post_hdmi"] = post_smoke
    print(json.dumps({"smoke_post_hdmi": post_smoke}, indent=2, sort_keys=True))
    print("[phase4h] left-strip / top-strip visibility is user visual confirmation pending")
    print(json.dumps({"summary": report}, indent=2, sort_keys=True,
                     default=str))
    print("[phase4h] OK")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
