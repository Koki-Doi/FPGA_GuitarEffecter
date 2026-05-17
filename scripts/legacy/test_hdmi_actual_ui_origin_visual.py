#!/usr/bin/env python3
"""Phase 6G/6H: show the actual compact UI with visible x-origin markers.

This is intentionally not the synthetic origin guard. It renders the
real compact-v2 Pip-Boy UI, adds small coordinate ticks and labels on
top of that real UI, then writes it to the integrated AudioLab HDMI
backend at manual 0,0. If `X0` and the left phosphor rail are visible at
the LCD's left edge, renderer/backend origin is correct. If they are
still shifted right or clipped, the remaining issue is downstream of
the Python renderer/framebuffer copy.
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


def hwh_contains(instance_name):
    candidates = [
        os.path.join(os.path.dirname(__file__), "..",
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
        "R19": "0x{:02x}".format(
            int(overlay.codec.R19_ADC_CONTROL[0]) & 0xFF),
        "has axi_vdma_hdmi ip_dict": "axi_vdma_hdmi" in ip_keys,
        "has v_tc_hdmi ip_dict": "v_tc_hdmi" in ip_keys,
        "has rgb2dvi_hdmi in HWH": hwh_contains("rgb2dvi_hdmi"),
        "has v_axi4s_vid_out_hdmi in HWH":
            hwh_contains("v_axi4s_vid_out_hdmi"),
    }


def framebuffer_nonzero_probe(framebuffer):
    import numpy as np
    arr = np.asarray(framebuffer)

    def column_sum(x):
        x = int(x)
        if x < 0 or x >= int(arr.shape[1]):
            return None
        return int(arr[:, x, :].sum())

    mask = arr.sum(axis=2) > 0
    cols = mask.any(axis=0)
    rows = mask.any(axis=1)
    if not cols.any() or not rows.any():
        bbox = None
    else:
        xs = np.where(cols)[0]
        ys = np.where(rows)[0]
        bbox = [int(xs[0]), int(xs[-1]), int(ys[0]), int(ys[-1])]
    return {
        "shape": list(arr.shape),
        "nonzero_bbox": bbox,
        "x0_column_sum": column_sum(0),
        "x10_column_sum": column_sum(10),
        "x20_column_sum": column_sum(20),
        "x40_column_sum": column_sum(40),
        "x799_column_sum": column_sum(799),
        "x800_column_sum": column_sum(800),
        "outside_800x480_sum": int(arr[480:, :, :].sum()
                                   + arr[:480, 800:, :].sum()),
    }


def state_for_selected_fx(selected_fx):
    from pynq_multi_fx_gui import AppState
    state = AppState()
    state.preset_id = "06G"
    state.preset_name = "ACTUAL UI ORIGIN"
    state.selected_fx = selected_fx
    state.pedal_model_label = "TUBE SCREAMER"
    state.amp_model_label = "HIGH GAIN STACK"
    state.cab_model_label = "2x12 COMBO"
    state.in_level = 0.62
    state.out_level = 0.58
    if selected_fx == "CAB":
        state.selected_effect = 6
        state.cab_model = "2x12"
        state.cab_model_label = "2x12 COMBO"
    elif selected_fx == "AMP SIM":
        state.selected_effect = 5
        state.amp_model = "high_gain_stack"
        state.amp_model_label = "HIGH GAIN STACK"
    elif selected_fx == "TUBE SCREAMER":
        state.selected_effect = 2
        state.pedal_model = "tube_screamer"
        state.pedal_model_label = "TUBE SCREAMER"
    else:
        state.selected_effect = 0
    return state


def add_visual_origin_overlay(frame, theme="pipboy-green"):
    import numpy as np
    from PIL import Image, ImageDraw
    from pynq_multi_fx_gui import draw_text, resolve_theme

    palette = resolve_theme(theme)
    led = palette["LED"]
    amber = palette["BYPASS_COL"]
    img = Image.fromarray(frame).convert("RGBA")
    d = ImageDraw.Draw(img)
    width, height = img.size

    # Coordinate ticks on top of the real UI. They are small enough not
    # to cover the compact panels, but bright enough for a quick LCD photo.
    for x, color, label in (
            (0, amber, "X0"),
            (10, led, "10"),
            (20, led, "20"),
            (40, led, "40"),
            (799, amber, "X799")):
        x0 = max(0, min(width - 1, int(x)))
        x1 = min(width - 1, x0 + (2 if x0 < width - 2 else 0))
        d.rectangle((x0, 0, x1, 54), fill=color + (255,))
        d.rectangle((x0, height - 26, x1, height - 1),
                    fill=color + (255,))
        if label == "X0":
            draw_text(img, (4, 24), label, fill=amber + (255,),
                      scale=1, letter_spacing=1)
        elif label == "X799":
            draw_text(img, (width - 4, 24), label, fill=amber + (255,),
                      scale=1, anchor="rt", letter_spacing=1)
        else:
            draw_text(img, (x0 + 4, 6), label, fill=led + (255,),
                      scale=1, letter_spacing=1)
    return np.array(img.convert("RGB"), dtype=np.uint8)


def serious_vdma_error(errors):
    return bool(errors and (
        errors.get("dmainterr") or errors.get("dmaslverr") or
        errors.get("dmadecerr")))


def main():
    parser = argparse.ArgumentParser(
        description="Phase 6H actual compact UI native 800x480 visual check.")
    parser.add_argument("--selected-fx", default="CAB",
                        choices=("PRESET", "CAB", "AMP SIM",
                                 "TUBE SCREAMER"))
    parser.add_argument("--hold-seconds", type=float, default=60.0)
    parser.add_argument("--theme", default="pipboy-green")
    parser.add_argument("--dry-run", action="store_true",
                        help="Render and analyze only; do not load overlay")
    args = parser.parse_args()

    repo_paths()
    from pynq_multi_fx_gui import render_frame_800x480  # noqa: E402
    from test_hdmi_render_bbox import analyze_frame  # noqa: E402

    state = state_for_selected_fx(args.selected_fx)
    frame = render_frame_800x480(
        state, variant="compact-v2", theme=args.theme,
        placement_label="actual-ui-x0")
    visual_frame = add_visual_origin_overlay(frame, theme=args.theme)
    bg = (3, 8, 4) if args.theme == "pipboy-green" else (4, 5, 9)
    analysis = analyze_frame(visual_frame, background=bg)
    report = {
        "phase": "6H-native800-actual-ui-origin-visual",
        "selected_fx": args.selected_fx,
        "theme": args.theme,
        "variant": "compact-v2",
        "placement": "manual",
        "offset_x": 0,
        "offset_y": 0,
        "visual_markers": {
            "left_label": "X0",
            "right_label": "X799",
            "ticks": [0, 10, 20, 40, 799],
        },
        "strong_ui_analysis": analysis,
        "failures": [],
    }
    if analysis.get("estimated_main_panel_left_x") is None or \
            analysis.get("estimated_main_panel_left_x") > 40:
        report["failures"].append("estimated_main_panel_left_x > 40")
    if analysis.get("estimated_selected_panel_left_x") is None or \
            analysis.get("estimated_selected_panel_left_x") > 40:
        report["failures"].append("estimated_selected_panel_left_x > 40")

    if args.dry_run:
        print(json.dumps({"actual_ui_origin_visual": report}, indent=2,
                         sort_keys=True))
        if report["failures"]:
            raise SystemExit("[phase6h-visual] FAIL")
        print("[phase6h-visual] OK (dry-run)")
        return

    from audio_lab_pynq import AudioLabOverlay  # noqa: E402
    from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend  # noqa: E402

    print("[phase6h-visual] loading AudioLabOverlay()")
    t0 = time.time()
    overlay = AudioLabOverlay()
    report["overlay_load_s"] = time.time() - t0
    report["smoke"] = smoke(overlay)
    if not (report["smoke"]["ADC HPF"] and
            report["smoke"]["R19"] == "0x23" and
            report["smoke"]["has axi_vdma_hdmi ip_dict"] and
            report["smoke"]["has v_tc_hdmi ip_dict"]):
        report["failures"].append("pre-HDMI smoke failed")

    backend = AudioLabHdmiBackend(overlay)
    backend.start(visual_frame, placement="manual", offset_x=0, offset_y=0)
    report["last_frame_write"] = backend._last_frame_write
    report["hdmi_status"] = backend.status()
    report["hdmi_errors"] = backend.errors()
    report["framebuffer_probe"] = framebuffer_nonzero_probe(
        backend._framebuffer)
    meta = backend._last_frame_write
    for name, expected in (("placement", "manual"), ("offset_x", 0),
                           ("offset_y", 0), ("dst_x0", 0), ("dst_y0", 0),
                           ("src_width", 800), ("src_height", 480)):
        if meta.get(name) != expected:
            report["failures"].append(
                "{} = {!r}, expected {!r}".format(
                    name, meta.get(name), expected))
    if serious_vdma_error(report["hdmi_errors"]):
        report["failures"].append(
            "VDMA error bits asserted: {}".format(report["hdmi_errors"]))

    if float(args.hold_seconds) > 0:
        print("[phase6h-visual] holding actual UI origin frame for {:.1f}s"
              .format(float(args.hold_seconds)))
        time.sleep(float(args.hold_seconds))

    print(json.dumps({"actual_ui_origin_visual": report}, indent=2,
                     sort_keys=True, default=str))
    if report["failures"]:
        raise SystemExit("[phase6h-visual] FAIL: {}".format(
            len(report["failures"])))
    print("[phase6h-visual] OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        sys.exit(1)
