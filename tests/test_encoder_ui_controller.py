"""Offline tests for audio_lab_pynq.encoder_ui.EncoderUiController."""

import copy
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
from compact_v2.knobs import (  # type: ignore  # noqa: E402
    EFFECTS, DIST_MODELS, OVERDRIVE_MODELS, AMP_MODELS, CAB_MODELS,
)


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


def _event(kind, encoder_id, delta=0, pressed=(False, False, False)):
    return EncoderEvent(
        kind, encoder_id, delta=delta, raw_delta=int(delta) * 4,
        pressed_state=pressed,
    )


def _models(state):
    return (
        state.dist_model_idx,
        state.overdrive_model_idx,
        state.amp_model_idx,
        state.cab_model_idx,
    )


def _snapshot(state):
    return {
        "selected_effect": state.selected_effect,
        "selected_knob": state.selected_knob,
        "effect_on": list(state.effect_on),
        "models": _models(state),
        "values": copy.deepcopy(state.all_knob_values),
        "model_select_mode": bool(state.model_select_mode),
        "edit_mode": bool(state.edit_mode),
    }


def _current_value(state):
    name = EFFECTS[state.selected_effect]
    return float(state.all_knob_values[name][state.selected_knob])


def _set_selected_effect(state, effect_name):
    state.selected_effect = EFFECTS.index(effect_name)
    state.focus_effect_index = state.selected_effect


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


def test_encoder0_rotate_changes_only_effect_and_clamps_knob():
    s = _new_state()
    _set_selected_effect(s, "Amp Sim")
    s.selected_knob = 7
    before = _snapshot(s)

    ctl = EncoderUiController(s)
    ctl.handle_event(_event("rotate", 0, 1))

    assert s.selected_effect == EFFECTS.index("Cab IR")
    assert s.focus_effect_index == s.selected_effect
    assert s.selected_knob == 3
    assert s.focus_param_index == 3
    assert s.effect_on == before["effect_on"]
    assert _models(s) == before["models"]
    assert s.all_knob_values == before["values"]
    assert s.last_control_source == "encoder"


def test_encoder0_rotate_wraps_around():
    s = _new_state()
    s.selected_effect = len(EFFECTS) - 1
    ctl = EncoderUiController(s)
    ctl.handle_event(_event("rotate", 0, 1))
    assert s.selected_effect == 0


def test_encoder0_switch_toggles_current_effect_only():
    s = _new_state()
    _set_selected_effect(s, "Distortion")
    s.selected_knob = 2
    before = _snapshot(s)
    idx = s.selected_effect

    ctl = EncoderUiController(s)
    ctl.handle_event(_event("short_press", 0))

    expected_effect_on = list(before["effect_on"])
    expected_effect_on[idx] = not expected_effect_on[idx]
    assert s.effect_on == expected_effect_on
    assert s.selected_effect == before["selected_effect"]
    assert s.selected_knob == before["selected_knob"]
    assert _models(s) == before["models"]
    assert s.all_knob_values == before["values"]
    assert s.apply_pending is True
    assert s.value_dirty is True


def test_encoder0_long_press_is_noop_for_control_state():
    s = _new_state()
    before = _snapshot(s)
    ctl = EncoderUiController(s)
    ctl.handle_event(_event("long_press", 0))
    assert _snapshot(s) == before


def test_encoder1_rotate_without_switch_changes_only_knob():
    s = _new_state()
    _set_selected_effect(s, "Amp Sim")
    s.selected_knob = 0
    s.model_select_mode = True  # stale persisted mode must not drive dispatch
    before = _snapshot(s)

    ctl = EncoderUiController(s)
    ctl.handle_event(_event("rotate", 1, 1, pressed=(False, False, False)))

    assert s.selected_effect == before["selected_effect"]
    assert s.selected_knob == 1
    assert s.focus_param_index == 1
    assert _models(s) == before["models"]
    assert s.all_knob_values == before["values"]
    assert s.effect_on == before["effect_on"]
    assert s.model_select_mode is False


def test_encoder1_pressed_rotate_overdrive_changes_only_overdrive_model():
    s = _new_state()
    _set_selected_effect(s, "Overdrive")
    s.selected_knob = 1
    before = _snapshot(s)

    ctl = EncoderUiController(s)
    ctl.handle_event(_event("rotate", 1, 1, pressed=(False, True, False)))

    assert s.overdrive_model_idx == (before["models"][1] + 1) % len(OVERDRIVE_MODELS)
    assert s.dist_model_idx == before["models"][0]
    assert s.amp_model_idx == before["models"][2]
    assert s.cab_model_idx == before["models"][3]
    assert s.selected_effect == before["selected_effect"]
    assert s.selected_knob == before["selected_knob"]
    assert s.all_knob_values == before["values"]


def test_encoder1_pressed_rotate_distortion_changes_only_distortion_model():
    s = _new_state()
    _set_selected_effect(s, "Distortion")
    s.dist_model_idx = 3
    before = _snapshot(s)

    ctl = EncoderUiController(s)
    ctl.handle_event(_event("rotate", 1, 1, pressed=(False, True, False)))

    assert s.dist_model_idx == 4
    assert s.overdrive_model_idx == before["models"][1]
    assert s.amp_model_idx == before["models"][2]
    assert s.cab_model_idx == before["models"][3]
    assert s.selected_knob == before["selected_knob"]
    assert s.all_knob_values == before["values"]


def test_encoder1_pressed_rotate_amp_changes_only_amp_model():
    s = _new_state()
    _set_selected_effect(s, "Amp Sim")
    s.amp_model_idx = len(AMP_MODELS) - 1
    before = _snapshot(s)

    ctl = EncoderUiController(s)
    ctl.handle_event(_event("rotate", 1, 1, pressed=(False, True, False)))

    assert s.amp_model_idx == 0
    assert s.dist_model_idx == before["models"][0]
    assert s.overdrive_model_idx == before["models"][1]
    assert s.cab_model_idx == before["models"][3]
    assert s.selected_knob == before["selected_knob"]
    assert s.all_knob_values == before["values"]


def test_encoder1_pressed_rotate_cab_changes_only_cab_model():
    s = _new_state()
    _set_selected_effect(s, "Cab IR")
    s.cab_model_idx = len(CAB_MODELS) - 1
    before = _snapshot(s)

    ctl = EncoderUiController(s)
    ctl.handle_event(_event("rotate", 1, 1, pressed=(False, True, False)))

    assert s.cab_model_idx == 0
    assert s.dist_model_idx == before["models"][0]
    assert s.overdrive_model_idx == before["models"][1]
    assert s.amp_model_idx == before["models"][2]
    assert s.selected_knob == before["selected_knob"]
    assert s.all_knob_values == before["values"]


def test_encoder1_rotate_uses_only_encoder1_switch_state():
    s = _new_state()
    _set_selected_effect(s, "Overdrive")
    s.selected_knob = 0
    before = _snapshot(s)

    ctl = EncoderUiController(s)
    ctl.handle_event(_event("rotate", 1, 1, pressed=(True, False, True)))

    assert s.selected_knob == 1
    assert _models(s) == before["models"]


def test_encoder1_switch_click_only_is_noop():
    s = _new_state()
    _set_selected_effect(s, "Overdrive")
    s.selected_knob = 2
    before = _snapshot(s)

    ctl = EncoderUiController(s)
    ctl.handle_event(_event("short_press", 1))

    assert _snapshot(s) == before


def test_encoder1_pressed_rotate_on_non_model_effect_is_noop():
    s = _new_state()
    _set_selected_effect(s, "Reverb")
    s.selected_knob = 1
    before = _snapshot(s)

    ctl = EncoderUiController(s)
    ctl.handle_event(_event("rotate", 1, 1, pressed=(False, True, False)))

    assert _snapshot(s) == before


def test_encoder2_rotate_changes_only_current_knob_value():
    s = _new_state()
    _set_selected_effect(s, "Distortion")
    s.selected_knob = 2
    before = _snapshot(s)
    before_value = _current_value(s)

    ctl = EncoderUiController(s, value_step=5.0)
    ctl.handle_event(_event("rotate", 2, 2))

    assert s.all_knob_values[EFFECTS[s.selected_effect]][s.selected_knob] == (
        before_value + 10.0)
    assert s.selected_effect == before["selected_effect"]
    assert s.selected_knob == before["selected_knob"]
    assert _models(s) == before["models"]
    assert s.effect_on == before["effect_on"]
    for effect_name, values in before["values"].items():
        if effect_name == EFFECTS[s.selected_effect]:
            continue
        assert s.all_knob_values[effect_name] == values
    assert s.edit_mode is True
    assert s.value_dirty is True
    assert s.apply_pending is True


def test_encoder2_rotate_clamps_to_0_100():
    s = _new_state()
    _set_selected_effect(s, "Amp Sim")
    s.selected_knob = 0
    name = EFFECTS[s.selected_effect]
    s.all_knob_values[name][0] = 0.0
    ctl = EncoderUiController(s, value_step=10.0)
    ctl.handle_event(_event("rotate", 2, -5))
    assert s.all_knob_values[name][0] == 0.0
    s.all_knob_values[name][0] = 95.0
    ctl.handle_event(_event("rotate", 2, 5))
    assert s.all_knob_values[name][0] == 100.0


def test_model_indices_wrap_for_model_effects():
    cases = (
        ("Distortion", "dist_model_idx", len(DIST_MODELS)),
        ("Overdrive", "overdrive_model_idx", len(OVERDRIVE_MODELS)),
        ("Amp Sim", "amp_model_idx", len(AMP_MODELS)),
        ("Cab IR", "cab_model_idx", len(CAB_MODELS)),
    )
    s = _new_state()
    ctl = EncoderUiController(s, skip_rat=False)
    for effect_name, attr, count in cases:
        _set_selected_effect(s, effect_name)
        setattr(s, attr, count - 1)
        ctl.handle_event(_event("rotate", 1, 1, pressed=(False, True, False)))
        assert getattr(s, attr) == 0
        ctl.handle_event(_event("rotate", 1, -1, pressed=(False, True, False)))
        assert getattr(s, attr) == count - 1


def test_handle_events_dispatches_in_order():
    s = _new_state()
    s.selected_effect = 0
    s.selected_knob = 0
    ctl = EncoderUiController(s)
    ctl.handle_events([
        _event("rotate", 0, 1),
        _event("rotate", 0, 1),
        _event("rotate", 1, 2, pressed=(False, False, False)),
    ])
    assert s.selected_effect == 2
    assert s.selected_knob == 2


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


def _last_kwargs(overlay, method):
    matches = [kw for name, kw in overlay.calls if name == method]
    return matches[-1] if matches else None


def test_distortion_pressed_rotate_skip_rat_advances_past_bit_2():
    s = _new_state()
    _set_selected_effect(s, "Distortion")
    s.dist_model_idx = 1
    ctl, _, _ = _make_controller(s, dry_run=True, skip_rat=True)
    ctl.handle_event(_event("rotate", 1, 1, pressed=(False, True, False)))
    assert s.dist_model_idx != RAT_PEDAL_INDEX
    assert s.dist_model_idx == 3


def test_distortion_pressed_rotate_include_rat_lands_on_bit_2():
    s = _new_state()
    _set_selected_effect(s, "Distortion")
    s.dist_model_idx = 1
    ctl, _, _ = _make_controller(s, dry_run=True, skip_rat=False)
    ctl.handle_event(_event("rotate", 1, 1, pressed=(False, True, False)))
    assert s.dist_model_idx == RAT_PEDAL_INDEX


def test_encoder0_short_press_drives_applier_on_off():
    s = _new_state()
    idx = s.selected_effect
    prev = bool(s.effect_on[idx])
    ctl, applier, overlay = _make_controller(
        s, dry_run=False, apply_interval_s=0.0)
    ctl.handle_event(_event("short_press", 0))
    assert s.effect_on[idx] is (not prev)
    methods = [name for name, _ in overlay.calls]
    assert any(m.startswith("set_") for m in methods)


def test_encoder1_pressed_rotate_overdrive_live_applies_model():
    s = _new_state()
    _set_selected_effect(s, "Overdrive")
    ctl, _, overlay = _make_controller(
        s, dry_run=False, apply_interval_s=0.0)
    ctl.handle_event(_event("rotate", 1, 1, pressed=(False, True, False)))
    gkw = _last_kwargs(overlay, "set_guitar_effects")
    assert gkw is not None
    assert gkw["overdrive_model"] == s.overdrive_model_idx


def test_encoder2_rotate_throttle_active():
    s = _new_state()
    _set_selected_effect(s, "Amp Sim")
    s.selected_knob = 0
    ctl, applier, overlay = _make_controller(
        s, dry_run=False, apply_interval_s=10.0)
    ctl.handle_event(_event("rotate", 2, 1))
    n_after_first = len(overlay.calls)
    ctl.handle_event(_event("rotate", 2, 1))
    assert len(overlay.calls) == n_after_first


def test_encoder2_short_press_calls_mirror_apply():
    s = _new_state()
    s.apply_pending = True
    s.value_dirty = True
    mirror = MirrorSpy()
    ctl = EncoderUiController(s, mirror=mirror)
    ctl.handle_event(_event("short_press", 2))
    assert mirror.calls and mirror.calls[0][0] == "update_from_appstate"
    assert s.apply_pending is False
    assert s.value_dirty is False
    assert s.edit_mode is False


def test_encoder2_short_press_falls_back_to_bridge_apply():
    s = _new_state()
    s.apply_pending = True
    s.value_dirty = True
    bridge = BridgeSpy()
    overlay = object()
    ctl = EncoderUiController(s, overlay=overlay, bridge=bridge)
    ctl.handle_event(_event("short_press", 2))
    assert bridge.calls
    assert bridge.calls[0]["overlay"] is overlay
    assert bridge.calls[0]["dry_run"] is False
    assert bridge.calls[0]["force"] is True
    assert bridge.calls[0]["event"] == "encoder_apply"
    assert s.apply_pending is False
    assert s.value_dirty is False


def test_encoder2_short_press_forces_apply():
    s = _new_state()
    _set_selected_effect(s, "Amp Sim")
    ctl, applier, overlay = _make_controller(
        s, dry_run=False, apply_interval_s=10.0)
    ctl.handle_event(_event("rotate", 2, 1))
    n_before = len(overlay.calls)
    ctl.handle_event(_event("short_press", 2))
    assert len(overlay.calls) > n_before
    assert s.apply_pending is False
    assert s.value_dirty is False


def test_encoder2_long_press_resets_to_default_and_applies():
    s = _new_state()
    _set_selected_effect(s, "EQ")
    s.selected_knob = 0
    name = EFFECTS[s.selected_effect]
    s.all_knob_values[name][0] = 90.0
    ctl, applier, overlay = _make_controller(
        s, dry_run=False, apply_interval_s=0.0)
    ctl.handle_event(_event("long_press", 2))
    assert s.all_knob_values[name][0] == 50.0
    methods = [name for name, _ in overlay.calls]
    assert "set_guitar_effects" in methods


def test_live_apply_disabled_skips_rotate_apply():
    s = _new_state()
    _set_selected_effect(s, "Amp Sim")
    ctl, applier, overlay = _make_controller(
        s, dry_run=False, apply_interval_s=0.0, live_apply=False)
    ctl.handle_event(_event("rotate", 2, 1))
    assert overlay.calls == []
    ctl.handle_event(_event("short_press", 2))
    assert len(overlay.calls) > 0


def test_applier_status_propagates_to_state():
    s = _new_state()
    ctl, applier, overlay = _make_controller(s, dry_run=False)
    ctl.handle_event(_event("short_press", 0))
    assert hasattr(s, "last_apply_ok")
    assert hasattr(s, "last_apply_message")
    assert s.last_apply_message != ""


_TEST_FUNCTIONS = [
    test_appstate_defaults_have_encoder_fields,
    test_encoder0_rotate_changes_only_effect_and_clamps_knob,
    test_encoder0_rotate_wraps_around,
    test_encoder0_switch_toggles_current_effect_only,
    test_encoder0_long_press_is_noop_for_control_state,
    test_encoder1_rotate_without_switch_changes_only_knob,
    test_encoder1_pressed_rotate_overdrive_changes_only_overdrive_model,
    test_encoder1_pressed_rotate_distortion_changes_only_distortion_model,
    test_encoder1_pressed_rotate_amp_changes_only_amp_model,
    test_encoder1_pressed_rotate_cab_changes_only_cab_model,
    test_encoder1_rotate_uses_only_encoder1_switch_state,
    test_encoder1_switch_click_only_is_noop,
    test_encoder1_pressed_rotate_on_non_model_effect_is_noop,
    test_encoder2_rotate_changes_only_current_knob_value,
    test_encoder2_rotate_clamps_to_0_100,
    test_model_indices_wrap_for_model_effects,
    test_handle_events_dispatches_in_order,
    test_distortion_pressed_rotate_skip_rat_advances_past_bit_2,
    test_distortion_pressed_rotate_include_rat_lands_on_bit_2,
    test_encoder0_short_press_drives_applier_on_off,
    test_encoder1_pressed_rotate_overdrive_live_applies_model,
    test_encoder2_rotate_throttle_active,
    test_encoder2_short_press_calls_mirror_apply,
    test_encoder2_short_press_falls_back_to_bridge_apply,
    test_encoder2_short_press_forces_apply,
    test_encoder2_long_press_resets_to_default_and_applies,
    test_live_apply_disabled_skips_rotate_apply,
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
