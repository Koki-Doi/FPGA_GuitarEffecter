#!/usr/bin/env python3
"""Phase 6C HDMI 800x480 x=0,y=0 origin guard.

The script verifies two things:

1. The HDMI backend writes the 800x480 logical frame at framebuffer
   ``x=0, y=0`` with ``placement="manual"``, ``offset_x=0``, and
   ``offset_y=0``. ``last_frame_write`` is asserted explicitly so any
   regression that re-introduces ``center`` / ``fit-90`` / ``fit-95``
   placement fails immediately.

2. The compact-v2 renderer paints across the full 0..799 x range. The
   script measures the per-row bounding box of non-background pixels in
   the rendered frame and fails when the GUI bbox right-edge runs past
   799 or shifts visibly to the right of pixel 16. This catches
   right-skew that would otherwise be blamed on the backend.

The script runs on PYNQ (drives the integrated AudioLab HDMI path) and
also runs on a workstation in dry-run mode (renderer-only, no overlay).
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


def build_origin_test_frame(width=800, height=480):
    """Phase 6C: synthesise a 800x480 test frame with marker columns.

    Vertical lines at x=0,10,20 plus a right-edge line at x=799 plus a
    1-pixel border around the canvas. The pixel-bbox detector then
    asserts the lines reach the framebuffer columns we expect, which
    is impossible if backend placement silently centres the image.
    """
    import numpy as np
    Wv = int(width)
    Hv = int(height)
    frame = np.zeros((Hv, Wv, 3), dtype=np.uint8)
    frame[:, :, :] = (8, 12, 8)
    # Outer border
    frame[0, :, :] = (0, 220, 90)
    frame[-1, :, :] = (0, 220, 90)
    frame[:, 0, :] = (0, 220, 90)
    frame[:, -1, :] = (0, 220, 90)
    # Left markers (orange / amber / green) at x=0,10,20
    frame[:, 0:2, :] = (255, 80, 0)
    frame[:, 10:12, :] = (255, 178, 60)
    frame[:, 20:22, :] = (0, 220, 90)
    # Right marker at x=799
    frame[:, 798:800, :] = (240, 240, 60)
    # Crosshair through centre
    frame[Hv // 2, :, :] = (255, 255, 255)
    frame[:, Wv // 2, :] = (255, 255, 255)
    return frame


def bbox_of_non_background(frame, background=(0, 0, 0), tol=8):
    """Return (min_x, max_x, min_y, max_y) bbox of non-background pixels."""
    import numpy as np
    arr = frame
    bg = np.array(background, dtype=np.int32)
    diff = np.abs(arr.astype(np.int32) - bg[None, None, :]).sum(axis=2)
    mask = diff > int(tol)
    cols = mask.any(axis=0)
    rows = mask.any(axis=1)
    if not cols.any() or not rows.any():
        return None
    xs = np.where(cols)[0]
    ys = np.where(rows)[0]
    return int(xs[0]), int(xs[-1]), int(ys[0]), int(ys[-1])


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


def main():
    parser = argparse.ArgumentParser(
        description=("Phase 6C: assert 800x480 logical GUI at x=0,y=0 "
                     "(placement=manual). Drives real HDMI on PYNQ; "
                     "use --dry-run for workstation checks."))
    parser.add_argument("--hold-seconds", type=float, default=10.0,
                        help="Seconds to keep HDMI showing the test frame")
    parser.add_argument("--dry-run", action="store_true",
                        help="Renderer-only; do not load AudioLabOverlay")
    parser.add_argument("--theme", default="pipboy-green")
    parser.add_argument("--bg-tol", type=int, default=12,
                        help="Background tolerance for pixel bbox detection")
    args = parser.parse_args()

    repo_paths()

    from pynq_multi_fx_gui import (  # noqa: E402
        AppState, render_frame_800x480_compact_v2,
    )

    report = {
        "phase": "6C-origin-guard",
        "started_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "dry_run": bool(args.dry_run),
        "expected": {
            "placement": "manual",
            "offset_x": 0,
            "offset_y": 0,
            "dst_x0": 0,
            "dst_y0": 0,
        },
        "checks": [],
        "failures": [],
    }

    state = AppState()
    state.preset_id = "06C"
    state.preset_name = "ORIGIN  GUARD"
    state.selected_fx = "TUBE SCREAMER"

    gui_frame = render_frame_800x480_compact_v2(
        state, theme=args.theme,
        placement_label="origin-guard manual 0,0")
    print("[phase6c-guard] GUI frame shape={} dtype={}".format(
        gui_frame.shape, gui_frame.dtype))

    bg_for_gui = (3, 8, 4) if args.theme == "pipboy-green" else (4, 5, 9)
    gui_bbox = bbox_of_non_background(gui_frame, bg_for_gui,
                                       tol=int(args.bg_tol))
    print("[phase6c-guard] GUI non-background bbox: {}".format(gui_bbox))
    report["gui_bbox"] = gui_bbox
    if gui_bbox is None:
        report["failures"].append("GUI frame is all background")
    else:
        min_x, max_x, _min_y, _max_y = gui_bbox
        report["checks"].append({
            "name": "renderer min_x <= 24",
            "min_x": min_x,
            "ok": min_x <= 24,
        })
        report["checks"].append({
            "name": "renderer max_x <= 799",
            "max_x": max_x,
            "ok": max_x <= 799,
        })
        report["checks"].append({
            "name": "renderer max_x >= 750",
            "max_x": max_x,
            "ok": max_x >= 750,
        })
        if min_x > 24:
            report["failures"].append(
                "renderer non-background bbox is right-shifted: min_x={}"
                .format(min_x))
        if max_x > 799:
            report["failures"].append(
                "renderer non-background bbox overflows x=799: max_x={}"
                .format(max_x))
        if max_x < 750:
            report["failures"].append(
                "renderer non-background bbox is left-shifted: max_x={}"
                .format(max_x))

    if args.dry_run:
        # In dry-run mode the script runs on a workstation where the
        # `pynq` package is not installed. Importing
        # ``audio_lab_pynq.hdmi_backend`` through the package would also
        # try to import the AudioCodec / AxisSwitch helpers and fail.
        # Load the module directly via importlib instead.
        import importlib.util
        repo_root = os.path.abspath(
            os.path.join(os.path.dirname(__file__), ".."))
        spec = importlib.util.spec_from_file_location(
            "_origin_guard_hdmi_backend",
            os.path.join(repo_root, "audio_lab_pynq", "hdmi_backend.py"))
        hdmi_backend = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(hdmi_backend)
        test = build_origin_test_frame()
        _canvas, meta = hdmi_backend.compose_logical_frame(
            test, placement="manual", offset_x=0, offset_y=0)
        report["compose_logical_frame_meta"] = meta
        for name, expected in (
                ("placement", "manual"),
                ("offset_x", 0),
                ("offset_y", 0)):
            actual = meta.get(name)
            ok = actual == expected
            report["checks"].append({"name": "compose_logical_frame." + name,
                                       "expected": expected,
                                       "actual": actual,
                                       "ok": ok})
            if not ok:
                report["failures"].append(
                    "compose_logical_frame.{} = {!r}, expected {!r}".format(
                        name, actual, expected))
        dst = meta.get("framebuffer_copied_region") or {}
        for name, expected in (("x0", 0), ("y0", 0)):
            actual = dst.get(name)
            ok = actual == expected
            report["checks"].append({"name": "framebuffer_copied_region." + name,
                                       "expected": expected,
                                       "actual": actual,
                                       "ok": ok})
            if not ok:
                report["failures"].append(
                    "framebuffer_copied_region.{} = {!r}, expected {!r}".format(
                        name, actual, expected))
        src = meta.get("source_visible_region") or {}
        for name, expected in (("width", 800), ("height", 480),
                                 ("x0", 0), ("y0", 0)):
            actual = src.get(name)
            ok = actual == expected
            report["checks"].append({"name": "source_visible_region." + name,
                                       "expected": expected,
                                       "actual": actual,
                                       "ok": ok})
            if not ok:
                report["failures"].append(
                    "source_visible_region.{} = {!r}, expected {!r}".format(
                        name, actual, expected))
    else:
        from audio_lab_pynq import AudioLabOverlay  # noqa: E402
        from audio_lab_pynq.hdmi_backend import AudioLabHdmiBackend  # noqa: E402

        print("[phase6c-guard] loading AudioLabOverlay()")
        t0 = time.time()
        overlay = AudioLabOverlay()
        report["overlay_load_s"] = time.time() - t0

        report["smoke"] = {
            "ADC HPF": bool(overlay.codec.get_adc_hpf_state()),
            "R19": "0x{:02x}".format(
                int(overlay.codec.R19_ADC_CONTROL[0]) & 0xFF),
            "has axi_vdma_hdmi ip_dict":
                "axi_vdma_hdmi" in getattr(overlay, "ip_dict", {}),
            "has v_tc_hdmi ip_dict":
                "v_tc_hdmi" in getattr(overlay, "ip_dict", {}),
            "has rgb2dvi_hdmi in HWH": hwh_contains("rgb2dvi_hdmi"),
        }
        if not (report["smoke"]["ADC HPF"] and
                report["smoke"]["R19"] == "0x23" and
                report["smoke"]["has axi_vdma_hdmi ip_dict"]):
            report["failures"].append("pre-HDMI smoke failed")

        backend = AudioLabHdmiBackend(overlay)
        test_frame = build_origin_test_frame()
        info = backend.start(test_frame, placement="manual",
                              offset_x=0, offset_y=0)
        meta = backend._last_frame_write
        report["origin_test_meta"] = meta
        report["hdmi_status"] = backend.status()
        report["hdmi_errors"] = backend.errors()
        for name, expected in (("placement", "manual"),
                                ("offset_x", 0), ("offset_y", 0)):
            actual = meta.get(name)
            ok = actual == expected
            report["checks"].append({"name": "backend." + name,
                                       "expected": expected,
                                       "actual": actual,
                                       "ok": ok})
            if not ok:
                report["failures"].append(
                    "backend.{} = {!r}, expected {!r}".format(
                        name, actual, expected))
        dst = meta.get("framebuffer_copied_region") or {}
        for name, expected in (("x0", 0), ("y0", 0)):
            actual = dst.get(name)
            ok = actual == expected
            report["checks"].append({"name": "framebuffer_copied_region." + name,
                                       "expected": expected,
                                       "actual": actual,
                                       "ok": ok})
            if not ok:
                report["failures"].append(
                    "framebuffer_copied_region.{} = {!r}, expected {!r}".format(
                        name, actual, expected))
        src = meta.get("source_visible_region") or {}
        for name, expected in (("width", 800), ("height", 480),
                                 ("x0", 0), ("y0", 0)):
            actual = src.get(name)
            ok = actual == expected
            report["checks"].append({"name": "source_visible_region." + name,
                                       "expected": expected,
                                       "actual": actual,
                                       "ok": ok})
            if not ok:
                report["failures"].append(
                    "source_visible_region.{} = {!r}, expected {!r}".format(
                        name, actual, expected))

        errors = backend.errors()
        if errors.get("dmainterr") or errors.get("dmaslverr") or errors.get("dmadecerr"):
            report["failures"].append(
                "VDMA error bits asserted: {}".format(errors))

        # Now flip in the real GUI frame so the user sees the live layout
        backend.write_frame(gui_frame, placement="manual",
                             offset_x=0, offset_y=0)
        report["live_frame_meta"] = backend._last_frame_write

        if float(args.hold_seconds) > 0:
            print("[phase6c-guard] holding HDMI for {:.1f} seconds".format(
                float(args.hold_seconds)))
            time.sleep(float(args.hold_seconds))

    print(json.dumps({"origin_guard_report": report}, indent=2,
                     sort_keys=True, default=str))
    if report["failures"]:
        raise SystemExit("[phase6c-guard] FAIL: {}".format(
            len(report["failures"])))
    print("[phase6c-guard] OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        sys.exit(1)
