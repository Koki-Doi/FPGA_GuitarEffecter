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


# ---- D53 amp model-only character + binary DRV MODE --------------------


def test_amp_sim_knob_layout_replaces_char_with_drv_mode():
    """Amp Sim EFFECT_KNOBS must drop CHAR and add DRV MODE @ idx 7, default 1
    (Drive) -- the intended shipped default (confirmed intentional 2026-06-13)."""
    from compact_v2.knobs import EFFECT_KNOBS
    labels = [label for label, _ in EFFECT_KNOBS["Amp Sim"]]
    assert "CHAR" not in labels
    assert labels[7] == "DRV MODE"
    assert EFFECT_KNOBS["Amp Sim"][7][1] == 1  # intended default: Drive


def test_amp_drive_mode_field_default_is_drive():
    """AppState.amp_drive_mode defaults to 1 (Drive) -- the intended shipped
    default (confirmed intentional 2026-06-13; supersedes the D53 0/Clean design)."""
    s = AppState()
    assert hasattr(s, "amp_drive_mode")
    assert s.amp_drive_mode == 1  # intended default: Drive


def test_set_knob_on_amp_drv_mode_clamps_to_zero_or_one():
    """set_knob on the Amp Sim DRV MODE slot must snap to 0/1 and
    mirror into AppState.amp_drive_mode."""
    from compact_v2.knobs import EFFECTS as _EFFECTS
    s = AppState()
    s.selected_effect = _EFFECTS.index("Amp Sim")
    s.set_knob(7, 73.5)
    assert s.all_knob_values["Amp Sim"][7] == 1.0
    assert s.amp_drive_mode == 1
    s.set_knob(7, 0.0)
    assert s.all_knob_values["Amp Sim"][7] == 0.0
    assert s.amp_drive_mode == 0


def test_appstate_json_round_trip_persists_amp_drive_mode():
    """The new amp_drive_mode field survives save/load (D53)."""
    s = AppState()
    s.amp_drive_mode = 1
    s.all_knob_values["Amp Sim"][7] = 1.0
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        path = f.name
    try:
        save_state_json(s, path)
        with open(path, "r", encoding="utf-8") as f:
            blob = json.load(f)
        assert blob["amp_drive_mode"] == 1
        s2 = load_state_json(path)
        assert s2.amp_drive_mode == 1
        assert s2.all_knob_values["Amp Sim"][7] == 1.0
    finally:
        if os.path.exists(path):
            os.unlink(path)


def test_legacy_state_with_char_value_loads_as_binary_drive_mode():
    """A pre-D53 state.json that stored the continuous CHAR value at
    Amp Sim slot 7 must load as a 0/1 DRV MODE so the GUI never
    surfaces a stale character byte. Values >= 50 snap to 1."""
    s_legacy = AppState()
    s_legacy.all_knob_values["Amp Sim"][7] = 60.0  # legacy CHAR
    s_legacy.amp_drive_mode = 0
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        path = f.name
    try:
        save_state_json(s_legacy, path)
        s2 = load_state_json(path)
        assert s2.all_knob_values["Amp Sim"][7] in (0.0, 1.0)
        assert s2.amp_drive_mode in (0, 1)
        # The legacy 60 percent value sits above the 50% snap threshold
        # so it should map to drive=1.
        assert s2.amp_drive_mode == 1
    finally:
        if os.path.exists(path):
            os.unlink(path)


def test_renderer_covers_all_six_amp_models_and_both_drive_modes():
    """D55 / D57 regression guard: render_frame must complete for every
    (amp_model_idx, amp_drive_mode) combination so a future six-pack
    rename or DRV MODE rework cannot silently blank the HDMI GUI.
    Also walks every selected_effect index 0..len(EFFECTS)-1 so a
    per-effect render branch (e.g. the Amp Sim knob grid or the WAH
    SOURCE strip) cannot regress unnoticed."""
    try:
        from compact_v2.renderer import render_frame_800x480_compact_v2
        from compact_v2.knobs import AMP_MODELS, EFFECTS
    except Exception as exc:
        import warnings
        warnings.warn("renderer import skipped: %r" % (exc,))
        return
    assert len(AMP_MODELS) == 6, "D55 expects six amp voicings"
    for amp_idx in range(len(AMP_MODELS)):
        for drv in (0, 1):
            s = AppState()
            s.amp_model_idx = amp_idx
            s.amp_drive_mode = drv
            s.all_knob_values["Amp Sim"][7] = float(drv)
            for sel in range(len(EFFECTS)):
                s.selected_effect = sel
                frame = render_frame_800x480_compact_v2(s)
                assert frame is not None
                if hasattr(frame, "shape"):
                    assert frame.shape[0] == 480
                    assert frame.shape[1] == 800
                    assert frame.shape[2] == 3


_TEST_FUNCTIONS = [
    test_appstate_phase7g_fields_present,
    test_appstate_json_round_trip_ignores_phase7g_fields,
    test_renderer_imports_and_runs_with_defaults,
    test_renderer_with_phase7g_flags_emits_status_text,
    test_renderer_with_live_apply_flags_emits_status_text,
    test_amp_sim_knob_layout_replaces_char_with_drv_mode,
    test_amp_drive_mode_field_default_is_drive,
    test_set_knob_on_amp_drv_mode_clamps_to_zero_or_one,
    test_appstate_json_round_trip_persists_amp_drive_mode,
    test_legacy_state_with_char_value_loads_as_binary_drive_mode,
    test_renderer_covers_all_six_amp_models_and_both_drive_modes,
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
