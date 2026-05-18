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


# ---- Phase 7G+ live-apply tests ----------------------------------------

from audio_lab_pynq.encoder_effect_apply import (  # noqa: E402
    EncoderEffectApplier, RAT_PEDAL_INDEX)


class _RecOverlay(object):
    def __init__(self):
        self.calls = []

    def _rec(self, n, kw):
        self.calls.append((n, dict(kw)))

    def set_noise_suppressor_settings(self, **kw):
        self._rec("set_noise_suppressor_settings", kw)
        return {}

    def set_compressor_settings(self, **kw):
        self._rec("set_compressor_settings", kw)
        return {}

    def set_guitar_effects(self, **kw):
        self._rec("set_guitar_effects", kw)
        return {}

    def clear_distortion_pedals(self):
        self._rec("clear_distortion_pedals", {})
        return {}


def _make_controller(state, *, dry_run=True, apply_interval_s=10.0,
                     skip_rat=True, live_apply=True):
    overlay = _RecOverlay()
    applier = EncoderEffectApplier(
        overlay,
        apply_interval_s=apply_interval_s,
        dry_run=dry_run,
        skip_rat=skip_rat,
    )
    ctl = EncoderUiController(
        state, applier=applier, live_apply=live_apply, skip_rat=skip_rat)
    return ctl, applier, overlay


def test_skip_rat_cycle_advances_past_bit_2():
    s = _new_state()
    s.selected_effect = EFFECTS.index("Distortion")
    s.model_select_mode = True
    s.dist_model_idx = 1  # tube_screamer
    ctl, _, _ = _make_controller(s, dry_run=True, skip_rat=True)
    # +1 from tube_screamer would land on RAT (idx 2); should jump to ds1 (3)
    ctl.handle_event(EncoderEvent("rotate", 1, 1, 4))
    assert s.dist_model_idx != RAT_PEDAL_INDEX
    assert s.dist_model_idx == 3


def test_skip_rat_cycle_backward_skips_bit_2():
    s = _new_state()
    s.selected_effect = EFFECTS.index("Distortion")
    s.model_select_mode = True
    s.dist_model_idx = 3  # ds1
    ctl, _, _ = _make_controller(s, dry_run=True, skip_rat=True)
    ctl.handle_event(EncoderEvent("rotate", 1, -1, -4))
    # -1 from ds1 would land on RAT (2); should jump to tube_screamer (1)
    assert s.dist_model_idx == 1


def test_include_rat_lands_on_bit_2():
    s = _new_state()
    s.selected_effect = EFFECTS.index("Distortion")
    s.model_select_mode = True
    s.dist_model_idx = 1
    ctl, _, _ = _make_controller(s, dry_run=True, skip_rat=False)
    ctl.handle_event(EncoderEvent("rotate", 1, 1, 4))
    assert s.dist_model_idx == RAT_PEDAL_INDEX


def test_enc1_short_press_drives_applier_on_off():
    s = _new_state()
    idx = s.selected_effect
    prev = bool(s.effect_on[idx])
    ctl, applier, overlay = _make_controller(s, dry_run=False,
                                             apply_interval_s=0.0)
    ctl.handle_event(EncoderEvent("short_press", 0))
    assert s.effect_on[idx] is (not prev)
    methods = [name for name, _ in overlay.calls]
    # The applier must have invoked at least one set_* call.
    assert any(m.startswith("set_") for m in methods)


def test_enc1_long_press_drives_safe_bypass():
    s = _new_state()
    ctl, applier, overlay = _make_controller(s, dry_run=False)
    ctl.handle_event(EncoderEvent("long_press", 0))
    methods = [name for name, _ in overlay.calls]
    assert "clear_distortion_pedals" in methods
    assert "set_guitar_effects" in methods
    gkw = next(kw for n, kw in overlay.calls if n == "set_guitar_effects")
    assert gkw["amp_on"] is False and gkw["distortion_on"] is False


def test_enc3_rotate_throttle_active():
    s = _new_state()
    s.selected_effect = 4  # Amp Sim
    s.selected_knob = 0
    ctl, applier, overlay = _make_controller(
        s, dry_run=False, apply_interval_s=10.0)
    ctl.handle_event(EncoderEvent("rotate", 2, 1, 4))
    n_after_first = len(overlay.calls)
    # Second rotation within the throttle window must not trigger a new write.
    ctl.handle_event(EncoderEvent("rotate", 2, 1, 4))
    assert len(overlay.calls) == n_after_first


def test_enc3_short_press_forces_apply():
    s = _new_state()
    s.selected_effect = 4
    s.selected_knob = 0
    ctl, applier, overlay = _make_controller(
        s, dry_run=False, apply_interval_s=10.0)
    ctl.handle_event(EncoderEvent("rotate", 2, 1, 4))
    n_before = len(overlay.calls)
    ctl.handle_event(EncoderEvent("short_press", 2))
    assert len(overlay.calls) > n_before
    assert s.apply_pending is False
    assert s.value_dirty is False


def test_enc3_long_press_resets_to_default_and_applies():
    s = _new_state()
    s.selected_effect = EFFECTS.index("EQ")
    s.selected_knob = 0
    name = EFFECTS[s.selected_effect]
    s.all_knob_values[name][0] = 90.0
    ctl, applier, overlay = _make_controller(
        s, dry_run=False, apply_interval_s=0.0)
    ctl.handle_event(EncoderEvent("long_press", 2))
    # Default for EQ LOW is 50
    assert s.all_knob_values[name][0] == 50.0
    methods = [name for name, _ in overlay.calls]
    assert "set_guitar_effects" in methods


def test_live_apply_disabled_skips_apply():
    s = _new_state()
    s.selected_effect = 4
    ctl, applier, overlay = _make_controller(
        s, dry_run=False, apply_interval_s=0.0, live_apply=False)
    ctl.handle_event(EncoderEvent("rotate", 2, 1, 4))
    assert overlay.calls == []
    # short press still applies
    ctl.handle_event(EncoderEvent("short_press", 2))
    assert len(overlay.calls) > 0


def test_applier_status_propagates_to_state():
    s = _new_state()
    ctl, applier, overlay = _make_controller(s, dry_run=False)
    ctl.handle_event(EncoderEvent("short_press", 0))
    assert hasattr(s, "last_apply_ok")
    assert hasattr(s, "last_apply_message")
    assert s.last_apply_message != ""


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
    # Phase 7G+ live apply
    test_skip_rat_cycle_advances_past_bit_2,
    test_skip_rat_cycle_backward_skips_bit_2,
    test_include_rat_lands_on_bit_2,
    test_enc1_short_press_drives_applier_on_off,
    test_enc1_long_press_drives_safe_bypass,
    test_enc3_rotate_throttle_active,
    test_enc3_short_press_forces_apply,
    test_enc3_long_press_resets_to_default_and_applies,
    test_live_apply_disabled_skips_apply,
    test_applier_status_propagates_to_state,
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
