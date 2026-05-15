"""Phase 6C unit tests for the 800x480 x=0,y=0 HDMI origin contract.

These tests exercise both ends of the placement contract:

* ``hdmi_backend.compose_logical_frame`` must place an 800x480 logical
  frame at framebuffer ``x=0, y=0`` when called with
  ``placement="manual"``, ``offset_x=0``, ``offset_y=0``.
* ``pynq_multi_fx_gui.render_frame_800x480_compact_v2`` must paint a
  non-background bbox that reaches both the left and right edges of the
  800-pixel canvas (so the renderer is not silently right- or
  left-skewed).

The tests load the modules via ``importlib`` so they run without the
``pynq`` package being installed.
"""
import importlib.util
import sys
from pathlib import Path

import numpy as np


REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(REPO_ROOT / "GUI"))


def _load(name, relpath):
    spec = importlib.util.spec_from_file_location(
        name, str(REPO_ROOT / relpath))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


_HDMI_BACKEND = _load("_test_origin_hdmi_backend",
                       "audio_lab_pynq/hdmi_backend.py")
_GUI = _load("_test_origin_gui", "GUI/pynq_multi_fx_gui.py")

compose_logical_frame = _HDMI_BACKEND.compose_logical_frame
render_frame_800x480_compact_v2 = _GUI.render_frame_800x480_compact_v2
AppState = _GUI.AppState


def _non_background_bbox(frame, background, tol=12):
    arr = np.asarray(frame)
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


def test_compose_logical_manual_x0_y0_places_at_origin():
    src = np.zeros((480, 800, 3), dtype=np.uint8)
    src[:, :, :] = (0, 220, 90)
    canvas, meta = compose_logical_frame(
        src, placement="manual", offset_x=0, offset_y=0)
    assert canvas.shape == (720, 1280, 3)
    assert meta["placement"] == "manual"
    assert meta["offset_x"] == 0
    assert meta["offset_y"] == 0
    dst = meta["framebuffer_copied_region"]
    assert dst["x0"] == 0
    assert dst["y0"] == 0
    assert dst["x1"] == 800
    assert dst["y1"] == 480
    src_region = meta["source_visible_region"]
    assert src_region["x0"] == 0 and src_region["y0"] == 0
    # The first row of the destination should match the source content.
    assert (canvas[0, 0:800, :] == src[0, 0:800, :]).all()
    # Pixel outside the 800x480 region must remain background black.
    assert int(canvas[479, 801, :].sum()) == 0
    assert int(canvas[700, 100, :].sum()) == 0


def test_compose_logical_negative_offset_clips_not_indexes_offsides():
    src = np.zeros((480, 800, 3), dtype=np.uint8)
    src[:, :, :] = (200, 200, 200)
    canvas, meta = compose_logical_frame(
        src, placement="manual", offset_x=-50, offset_y=-30)
    assert meta["negative_offset"] is True
    dst = meta["framebuffer_copied_region"]
    src_region = meta["source_visible_region"]
    assert dst["x0"] == 0
    assert dst["y0"] == 0
    assert src_region["x0"] == 50
    assert src_region["y0"] == 30


def test_renderer_compact_v2_paints_across_full_x_range():
    state = AppState()
    state.preset_id = "06C"
    state.preset_name = "ORIGIN GUARD"
    state.selected_fx = "TUBE SCREAMER"
    frame = render_frame_800x480_compact_v2(state, theme="pipboy-green")
    assert frame.shape == (480, 800, 3)
    bbox = _non_background_bbox(frame, (3, 8, 4), tol=12)
    assert bbox is not None, "renderer produced an all-background frame"
    min_x, max_x, min_y, max_y = bbox
    assert min_x <= 24, "renderer right-shifted: min_x={}".format(min_x)
    assert max_x <= 799, "renderer overflowed x=799: max_x={}".format(max_x)
    assert max_x >= 760, "renderer left-shifted: max_x={}".format(max_x)
    assert min_y <= 24
    assert max_y <= 479
    assert max_y >= 440


def test_renderer_compact_v2_dropdown_chip_does_not_overflow():
    """The Phase 6C [model ▼] chip must not push pixels past x=799."""
    state = AppState()
    state.preset_id = "06C"
    state.preset_name = "DROPDOWN  RIGHT"
    state.selected_fx = "AMP SIM"
    state.pedal_model_label = "TUBE SCREAMER"
    state.amp_model_label = "HIGH GAIN STACK"
    state.cab_model_label = "4x12 CLOSED"
    state.dropdown_label = "HIGH GAIN STACK"
    frame = render_frame_800x480_compact_v2(state, theme="pipboy-green")
    bbox = _non_background_bbox(frame, (3, 8, 4), tol=12)
    assert bbox is not None
    min_x, max_x, _min_y, _max_y = bbox
    assert max_x <= 799, "dropdown chip overflowed x=799: max_x={}".format(max_x)


if __name__ == "__main__":
    tests = [
        test_compose_logical_manual_x0_y0_places_at_origin,
        test_compose_logical_negative_offset_clips_not_indexes_offsides,
        test_renderer_compact_v2_paints_across_full_x_range,
        test_renderer_compact_v2_dropdown_chip_does_not_overflow,
    ]
    for fn in tests:
        fn()
        print("PASS", fn.__name__)
