#!/usr/bin/env python3
"""Phase 6F-A: renderer bbox guard.

Asserts that the compact-v2 800x480 renderer paints non-background
pixels starting near the LEFT edge (min_x <= 30) and reaching close
to the RIGHT edge (max_x >= 760, max_x <= 799). If the renderer is
right-shifted at the canvas level, no amount of compose / VTC tuning
will fix the LCD view -- this catches that root cause first.

Runs on workstation (no PYNQ overlay required). Does not modify
bit/hwh, GPIO, or DSP.
"""
from __future__ import print_function

import argparse
import os
import sys


def repo_paths():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(script_dir, ".."))
    for path in (repo_root, os.path.join(repo_root, "GUI")):
        if path not in sys.path:
            sys.path.insert(0, path)
    return repo_root


def non_background_bbox(arr, bg=(3, 8, 4), tol=12):
    import numpy as np
    diff = np.abs(arr.astype("int16") - np.array(bg, dtype="int16"))
    mask = (diff > tol).any(axis=-1)
    if not mask.any():
        return None
    ys, xs = mask.nonzero()
    return int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())


def measure(selected_fx, theme="pipboy-green"):
    from pynq_multi_fx_gui import AppState, render_frame_800x480
    state = AppState()
    state.selected_fx = selected_fx
    frame = render_frame_800x480(
        state, variant="compact-v2", theme=theme)
    assert frame.shape == (480, 800, 3), frame.shape
    bbox = non_background_bbox(frame)
    return frame.shape, bbox


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
        shape, bbox = measure(fx, theme=args.theme)
        if bbox is None:
            failures.append((fx, "no non-background pixels"))
            print("[bbox] {:20} FAIL: empty frame".format(fx))
            continue
        min_x, max_x, min_y, max_y = bbox
        status = "PASS"
        notes = []
        if min_x > args.min_x_max:
            status = "FAIL"
            notes.append("min_x={} > {}".format(min_x, args.min_x_max))
        if max_x > 799:
            status = "FAIL"
            notes.append("max_x={} > 799".format(max_x))
        if max_x < args.max_x_min:
            status = "FAIL"
            notes.append("max_x={} < {}".format(max_x, args.max_x_min))
        print("[bbox] {:20} {} shape={} bbox=(min_x={}, max_x={}, "
              "min_y={}, max_y={}) {}".format(
                  fx, status, shape, min_x, max_x, min_y, max_y,
                  ", ".join(notes)))
        if status != "PASS":
            failures.append((fx, " / ".join(notes)))

    if failures:
        print("[bbox] {} FAILURES".format(len(failures)))
        for fx, msg in failures:
            print("[bbox]   {}: {}".format(fx, msg))
        raise SystemExit(1)
    print("[bbox] OK (renderer paints across canvas; "
          "no right-shift at renderer level)")


if __name__ == "__main__":
    main()
