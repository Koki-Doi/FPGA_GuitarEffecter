"""Offline tests for the D74 FP02M Wah SOURCE GUI bits (compact-v2).

Covers: hit_test SOURCE-strip toggle, AppState live-pedal fields + display
percent, the renderer running in PEDAL mode, and that the live pedal fields
are NOT persisted by save/load (only wah_source is).
"""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(REPO_ROOT / "GUI"))

from compact_v2.state import AppState, save_state_json, load_state_json  # noqa: E402
from compact_v2.hit_test import hit_test_compact_v2  # noqa: E402
from compact_v2.knobs import EFFECTS  # noqa: E402
from compact_v2.renderer import render_frame_800x480_compact_v2  # noqa: E402


def _select_wah(s):
    s.selected_effect = EFFECTS.index("Wah")
    return s


def test_appstate_pedal_fields_default():
    s = AppState()
    assert s.wah_source == "manual"
    assert s.wah_position_pedal_u8 == 0
    assert s.wah_pedal_available is False


def test_display_pct():
    s = AppState()
    s.wah_position_pedal_u8 = 255
    assert s.wah_position_display_pct() == 100.0
    s.wah_position_pedal_u8 = 128
    assert 49.0 <= s.wah_position_display_pct() <= 51.0


def test_hit_test_source_strip_toggles():
    s = _select_wah(AppState())
    # The source strip lives in the model-row band of the FX panel.
    from compact_v2.layout import compact_v2_panel_boxes
    fx0, fy0, fx1, fy1 = compact_v2_panel_boxes(800, 480)["fx"]
    action = hit_test_compact_v2(fx0 + 300, fy0 + 50, s)
    assert action == ("toggle_wah_source", None)


def test_hit_test_source_strip_only_for_wah():
    s = AppState()
    s.selected_effect = EFFECTS.index("Amp Sim")
    from compact_v2.layout import compact_v2_panel_boxes
    fx0, fy0, fx1, fy1 = compact_v2_panel_boxes(800, 480)["fx"]
    action = hit_test_compact_v2(fx0 + 300, fy0 + 50, s)
    assert action != ("toggle_wah_source", None)


def test_renderer_runs_in_pedal_mode():
    s = _select_wah(AppState())
    s.wah_source = "pedal"
    s.wah_pedal_available = True
    s.wah_position_pedal_u8 = 200
    img = render_frame_800x480_compact_v2(s)
    assert img is not None
    assert img.shape[:2] == (480, 800)


def test_renderer_runs_pedal_unavailable():
    s = _select_wah(AppState())
    s.wah_source = "pedal"
    s.wah_pedal_available = False
    img = render_frame_800x480_compact_v2(s)
    assert img is not None


def test_live_pedal_fields_not_persisted():
    s = AppState()
    s.wah_source = "pedal"
    s.wah_position_pedal_u8 = 200
    s.wah_pedal_available = True
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "state.json")
        save_state_json(s, path)
        with open(path) as f:
            data = json.load(f)
        # wah_source IS persisted; the live readback fields are not.
        assert data.get("wah_source") == "pedal"
        assert "wah_position_pedal_u8" not in data
        assert "wah_pedal_available" not in data
        loaded = load_state_json(path)
        assert loaded.wah_source == "pedal"
        assert loaded.wah_position_pedal_u8 == 0   # fresh default
        assert loaded.wah_pedal_available is False


_TEST_FUNCTIONS = [
    test_appstate_pedal_fields_default,
    test_display_pct,
    test_hit_test_source_strip_toggles,
    test_hit_test_source_strip_only_for_wah,
    test_renderer_runs_in_pedal_mode,
    test_renderer_runs_pedal_unavailable,
    test_live_pedal_fields_not_persisted,
]


def load_tests(_loader, _tests, _pattern):
    suite = unittest.TestSuite()
    for test in _TEST_FUNCTIONS:
        suite.addTest(unittest.FunctionTestCase(test))
    return suite


if __name__ == "__main__":
    for t in _TEST_FUNCTIONS:
        t()
        print("PASS", t.__name__)
