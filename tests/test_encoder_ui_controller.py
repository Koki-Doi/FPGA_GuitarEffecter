"""Offline tests for audio_lab_pynq.encoder_ui.EncoderUiController."""

import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(REPO_ROOT / "GUI"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import _pynq_mock  # noqa: E402
_pynq_mock.install()


from audio_lab_pynq.encoder_input import EncoderEvent  # noqa: E402
from audio_lab_pynq.encoder_ui import EncoderUiController  # noqa: E402

from compact_v2.state import AppState  # type: ignore  # noqa: E402
from compact_v2.knobs import EFFECTS  # type: ignore  # noqa: E402


class MirrorSpy(object):
    def __init__(self):
        self.calls = []

    def update_from_appstate(self, state):
        self.calls.append(("update_from_appstate",
                           state.selected_effect, state.selected_knob))


class BridgeSpy(object):
    def __init__(self):
        self.calls = []

    def apply(self, state, overlay=None, dry_run=True, force=False, event=None):
        self.calls.append({
            "state": state,
            "overlay": overlay,
            "dry_run": dry_run,
            "force": force,
            "event": event,
        })
        return {"operations": [{"method": "set_guitar_effects"}], "warnings": []}


def _new_state():
    return AppState()


def test_appstate_defaults_have_encoder_fields():
    s = AppState()
    assert hasattr(s, "focus_effect_index")
    assert hasattr(s, "focus_param_index")
    assert hasattr(s, "edit_mode")
    assert hasattr(s, "model_select_mode")
    assert hasattr(s, "value_dirty")
    assert hasattr(s, "apply_pending")
    assert hasattr(s, "last_control_source")
    assert s.last_control_source == "notebook"


def test_enc1_rotate_changes_selected_effect():
    s = _new_state()
    initial = s.selected_effect
    ctl = EncoderUiController(s)
    ctl.handle_event(EncoderEvent("rotate", 0, 2, 8))
    assert s.selected_effect == (initial + 2) % len(EFFECTS)
    assert s.focus_effect_index == s.selected_effect
    assert s.last_control_source == "encoder"


def test_enc1_rotate_wraps_around():
    s = _new_state()
    s.selected_effect = len(EFFECTS) - 1
    ctl = EncoderUiController(s)
    ctl.handle_event(EncoderEvent("rotate", 0, 1, 4))
    assert s.selected_effect == 0


def test_enc1_short_press_toggles_effect_on():
    s = _new_state()
    idx = s.selected_effect
    prev = bool(s.effect_on[idx])
    ctl = EncoderUiController(s)
    ctl.handle_event(EncoderEvent("short_press", 0))
    assert s.effect_on[idx] is (not prev)
    assert s.apply_pending is True
    assert s.value_dirty is True


def test_enc1_long_press_safe_bypass_round_trip():
    s = _new_state()
    original = list(s.effect_on)
    ctl = EncoderUiController(s)
    ctl.handle_event(EncoderEvent("long_press", 0))
    assert all(not v for v in s.effect_on)  # all bypassed
    # second long_press restores
    ctl.handle_event(EncoderEvent("long_press", 0))
    assert s.effect_on == original


def test_enc2_rotate_changes_selected_knob():
    s = _new_state()
    s.selected_effect = 4  # Amp Sim (8 knobs)
    s.selected_knob = 0
    ctl = EncoderUiController(s)
    ctl.handle_event(EncoderEvent("rotate", 1, 1, 4))
    assert s.selected_knob == 1
    assert s.focus_param_index == 1


def test_enc2_short_press_enters_model_select_for_pedal_effects():
    s = _new_state()
    # Find Distortion index (a MODEL_EFFECT)
    idx = EFFECTS.index("Distortion")
    s.selected_effect = idx
    s.model_select_mode = False
    ctl = EncoderUiController(s)
    ctl.handle_event(EncoderEvent("short_press", 1))
    assert s.model_select_mode is True
    # Toggles off
    ctl.handle_event(EncoderEvent("short_press", 1))
    assert s.model_select_mode is False


def test_enc2_short_press_noop_for_non_model_effects():
    s = _new_state()
    idx = EFFECTS.index("Reverb")  # not a MODEL_EFFECT
    s.selected_effect = idx
    s.model_select_mode = False
    ctl = EncoderUiController(s)
    ctl.handle_event(EncoderEvent("short_press", 1))
    assert s.model_select_mode is False


def test_enc3_rotate_changes_knob_value_and_marks_dirty():
    s = _new_state()
    s.selected_effect = 4  # Amp Sim
    s.selected_knob = 0
    name = EFFECTS[s.selected_effect]
    initial = float(s.all_knob_values[name][0])
    ctl = EncoderUiController(s, value_step=5.0)
    ctl.handle_event(EncoderEvent("rotate", 2, 2, 8))
    new = float(s.all_knob_values[name][0])
    assert new == min(100.0, initial + 10.0)
    assert s.value_dirty is True
    assert s.apply_pending is True
    assert s.edit_mode is True


def test_enc3_rotate_clamps_to_0_100():
    s = _new_state()
    s.selected_effect = 4
    s.selected_knob = 0
    name = EFFECTS[s.selected_effect]
    s.all_knob_values[name][0] = 0.0
    ctl = EncoderUiController(s, value_step=10.0)
    ctl.handle_event(EncoderEvent("rotate", 2, -5, -20))  # below 0
    assert s.all_knob_values[name][0] == 0.0
    s.all_knob_values[name][0] = 95.0
    ctl.handle_event(EncoderEvent("rotate", 2, 5, 20))  # above 100
    assert s.all_knob_values[name][0] == 100.0


def test_enc3_short_press_calls_mirror_apply():
    s = _new_state()
    s.apply_pending = True
    s.value_dirty = True
    mirror = MirrorSpy()
    ctl = EncoderUiController(s, mirror=mirror)
    ctl.handle_event(EncoderEvent("short_press", 2))
    assert mirror.calls and mirror.calls[0][0] == "update_from_appstate"
    assert s.apply_pending is False
    assert s.value_dirty is False
    assert s.edit_mode is False


def test_enc3_short_press_falls_back_to_bridge_apply():
    s = _new_state()
    s.apply_pending = True
    s.value_dirty = True
    bridge = BridgeSpy()
    overlay = object()
    ctl = EncoderUiController(s, overlay=overlay, bridge=bridge)
    ctl.handle_event(EncoderEvent("short_press", 2))
    assert bridge.calls
    assert bridge.calls[0]["overlay"] is overlay
    assert bridge.calls[0]["dry_run"] is False
    assert bridge.calls[0]["force"] is True
    assert bridge.calls[0]["event"] == "encoder_apply"
    assert s.apply_pending is False
    assert s.value_dirty is False


def test_handle_events_dispatches_in_order():
    s = _new_state()
    s.selected_effect = 0
    s.selected_knob = 0
    ctl = EncoderUiController(s)
    ctl.handle_events([
        EncoderEvent("rotate", 0, 1, 4),
        EncoderEvent("rotate", 0, 1, 4),
        EncoderEvent("rotate", 1, 2, 8),
    ])
    # selected_effect advanced by 2 (0 -> 2), then encoder 1 sets the knob
    # to (0 + 2) mod knob_count for the new effect.
    assert s.selected_effect == 2
    name = EFFECTS[s.selected_effect]
    expected_knob = 2 % max(1, len(s.all_knob_values.get(name, [0])))
    assert s.selected_knob == expected_knob


_TEST_FUNCTIONS = [
    test_appstate_defaults_have_encoder_fields,
    test_enc1_rotate_changes_selected_effect,
    test_enc1_rotate_wraps_around,
    test_enc1_short_press_toggles_effect_on,
    test_enc1_long_press_safe_bypass_round_trip,
    test_enc2_rotate_changes_selected_knob,
    test_enc2_short_press_enters_model_select_for_pedal_effects,
    test_enc2_short_press_noop_for_non_model_effects,
    test_enc3_rotate_changes_knob_value_and_marks_dirty,
    test_enc3_rotate_clamps_to_0_100,
    test_enc3_short_press_calls_mirror_apply,
    test_enc3_short_press_falls_back_to_bridge_apply,
    test_handle_events_dispatches_in_order,
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
