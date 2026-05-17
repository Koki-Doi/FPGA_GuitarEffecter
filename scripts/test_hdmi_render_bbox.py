#!/usr/bin/env python3
"""Phase 6F-A: renderer strong-UI bbox guard.

Asserts that the compact-v2 800x480 renderer paints actual bright UI
panel strokes near the LEFT edge and reaches close to the RIGHT edge.
The analysis intentionally lives in ``audio_lab_pynq.hdmi_state`` so
tests do not import a ``test_*.py`` script module.

Runs on workstation (no PYNQ overlay required). Does not modify
bit/hwh, GPIO, or DSP.
"""
from __future__ import print_function

import argparse
import json
import os
import sys


def repo_paths():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(script_dir, ".."))
    for path in (repo_root, os.path.join(repo_root, "GUI")):
        if path not in sys.path:
            sys.path.insert(0, path)
    return repo_root


def measure(selected_fx, theme="pipboy-green"):
    from audio_lab_pynq.hdmi_state.frame_analysis import analyze_frame
    from pynq_multi_fx_gui import AppState, render_frame_800x480
    state = AppState()
    state.selected_fx = selected_fx
    frame = render_frame_800x480(
        state, variant="compact-v2", theme=theme)
    assert frame.shape == (480, 800, 3), frame.shape
    background = (3, 8, 4) if theme == "pipboy-green" else (4, 5, 9)
    return analyze_frame(frame, background=background)


def main():
    parser = argparse.ArgumentParser(
        description="Phase 6F renderer bbox guard.")
    parser.add_argument("--theme", default="pipboy-green")
    parser.add_argument("--min-x-max", type=int, default=30,
                        help="max acceptable min_x (default 30)")
    parser.add_argument("--max-x-min", type=int, default=760,
                        help="min acceptable max_x (default 760)")
    args = parser.parse_args()

    repo_paths()

    fxs = [
        "AMP SIM", "CAB", "TUBE SCREAMER", "REVERB", "COMPRESSOR",
        "NOISE SUPPRESSOR", "EQ", "SAFE BYPASS", "PRESET",
    ]
    failures = []
    for fx in fxs:
        analysis = measure(fx, theme=args.theme)
        bbox = analysis.get("non_background_bbox")
        strong_bbox = analysis.get("strong_ui_bbox")
        if strong_bbox is None:
            failures.append((fx, "no non-background pixels"))
            print("[bbox] {:20} FAIL: no strong UI bbox".format(fx))
            continue
        min_x, max_x, min_y, max_y = strong_bbox
        main_left = analysis.get("estimated_main_panel_left_x")
        selected_left = analysis.get("estimated_selected_panel_left_x")
        status = "PASS"
        notes = []
        if min_x > args.min_x_max:
            status = "FAIL"
            notes.append("strong_min_x={} > {}".format(
                min_x, args.min_x_max))
        if max_x > 799:
            status = "FAIL"
            notes.append("strong_max_x={} > 799".format(max_x))
        if max_x < args.max_x_min:
            status = "FAIL"
            notes.append("strong_max_x={} < {}".format(
                max_x, args.max_x_min))
        if main_left is None or main_left > 40:
            status = "FAIL"
            notes.append("main_left={} > 40".format(main_left))
        if selected_left is None or selected_left > 40:
            status = "FAIL"
            notes.append("selected_left={} > 40".format(selected_left))
        print("[bbox] {:20} {} shape={} strong_ui_bbox={} "
              "non_background_bbox={} main_left={} selected_left={} {}"
              .format(
                  fx, status, analysis.get("shape"), strong_bbox, bbox,
                  main_left, selected_left, ", ".join(notes)))
        if status != "PASS":
            failures.append((fx, " / ".join(notes)))
        if status != "PASS":
            print(json.dumps(analysis, indent=2, sort_keys=True))

    if failures:
        print("[bbox] {} FAILURES".format(len(failures)))
        for fx, msg in failures:
            print("[bbox]   {}: {}".format(fx, msg))
        raise SystemExit(1)
    print("[bbox] OK (renderer paints across canvas; "
          "no right-shift at renderer level)")


if __name__ == "__main__":
    main()
