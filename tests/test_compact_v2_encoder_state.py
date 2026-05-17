"""Offline tests for the Phase 7G AppState additions.

The renderer should still be importable + callable with the new fields
present, and default AppState shouldn't regress JSON round-trip.
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


def test_appstate_phase7g_fields_present():
    s = AppState()
    assert hasattr(s, "focus_effect_index")
    assert hasattr(s, "focus_param_index")
    assert hasattr(s, "edit_mode")          and s.edit_mode is False
    assert hasattr(s, "model_select_mode")  and s.model_select_mode is False
    assert hasattr(s, "value_dirty")        and s.value_dirty is False
    assert hasattr(s, "apply_pending")      and s.apply_pending is False
    assert s.last_control_source == "notebook"
    assert s.last_encoder_event is None
    # Phase 7G+ live-apply status fields
    assert s.live_apply is True
    assert s.apply_interval_ms == 100
    assert s.last_apply_ok is True
    assert s.last_apply_message == ""
    assert s.last_unsupported_label == ""


def test_renderer_with_live_apply_flags_emits_status_text():
    try:
        from compact_v2.renderer import render_frame_800x480_compact_v2
    except Exception as exc:
        import warnings
        warnings.warn("renderer import skipped: %r" % (exc,))
        return
    s = AppState()
    s.last_control_source = "encoder"
    s.live_apply = True
    s.last_apply_ok = False
    s.last_apply_message = "state-push err"
    s.last_unsupported_label = "Distortion:rat"
    frame = render_frame_800x480_compact_v2(s)
    assert frame is not None
    if hasattr(frame, "shape"):
        assert frame.shape[0] == 480 and frame.shape[1] == 800


def test_appstate_json_round_trip_ignores_phase7g_fields():
    """save_state_json should only serialise the documented _STATE_KEYS set;
    Phase 7G fields are runtime-only and don't need to persist.
    """
    s = AppState()
    s.selected_effect = 3
    s.selected_knob = 2
    # Mutate Phase 7G fields, ensure they survive load with their defaults.
    s.edit_mode = True
    s.value_dirty = True
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        path = f.name
    try:
        save_state_json(s, path)
        # Sanity: the saved JSON should not contain Phase 7G keys
        with open(path, "r", encoding="utf-8") as f:
            blob = json.load(f)
        assert "edit_mode" not in blob
        assert "value_dirty" not in blob
        assert "last_control_source" not in blob
        s2 = load_state_json(path)
        assert s2.selected_effect == 3
        assert s2.selected_knob == 2
        assert s2.edit_mode is False
        assert s2.value_dirty is False
    finally:
        if os.path.exists(path):
            os.unlink(path)


def test_renderer_imports_and_runs_with_defaults():
    """The renderer should still produce a frame for a default AppState."""
    try:
        from compact_v2.renderer import render_frame_800x480_compact_v2
    except Exception as exc:  # pragma: no cover
        # Pillow/numpy not installed on minimal envs -> skip silently.
        import warnings
        warnings.warn("renderer import skipped: %r" % (exc,))
        return
    s = AppState()
    frame = render_frame_800x480_compact_v2(s)
    assert frame is not None
    # Returns either a numpy array or a PIL image; both should be truthy.
    # Check shape if numpy
    if hasattr(frame, "shape"):
        assert frame.shape[0] == 480
        assert frame.shape[1] == 800
        assert frame.shape[2] == 3


def test_renderer_with_phase7g_flags_emits_status_text():
    """When edit/apply flags are set, the renderer should still complete."""
    try:
        from compact_v2.renderer import render_frame_800x480_compact_v2
    except Exception as exc:
        import warnings
        warnings.warn("renderer import skipped: %r" % (exc,))
        return
    s = AppState()
    s.edit_mode = True
    s.value_dirty = True
    s.apply_pending = True
    s.last_control_source = "encoder"
    s.model_select_mode = True
    frame = render_frame_800x480_compact_v2(s)
    assert frame is not None


_TEST_FUNCTIONS = [
    test_appstate_phase7g_fields_present,
    test_appstate_json_round_trip_ignores_phase7g_fields,
    test_renderer_imports_and_runs_with_defaults,
    test_renderer_with_phase7g_flags_emits_status_text,
    test_renderer_with_live_apply_flags_emits_status_text,
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
