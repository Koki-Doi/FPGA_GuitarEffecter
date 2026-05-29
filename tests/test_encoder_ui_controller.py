"""Offline tests for audio_lab_pynq.encoder_ui.EncoderUiController.

D47 spec:

* Encoder 0 rotate -> effect select (no toggle).
* Encoder 0 button-down rising edge -> toggle ``effect_on[selected_effect]``.
* Encoder 0 HW short_press event -> same toggle as the level-edge path
  (D51 fallback for taps shorter than the poll period).
* Encoder 1 rotate without hold -> knob select.
* Encoder 1 rotate with hold -> model index cycle (OD / DIST / AMP / CAB).
* Encoder 2 rotate -> knob value change.
* long_press / click on any encoder: no-op.
* short_press on Encoder 1 / Encoder 2: no-op.
* Encoder 1 / Encoder 2 standalone button: no-op.
* PRESET-like slots are NOT bypassable from the encoder.
"""

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


def _new_state():
    return AppState()


def _snapshot(s):
    """Capture every controller-mutable field so we can diff after a call."""
    return {
        "selected_effect":     s.selected_effect,
        "selected_knob":       s.selected_knob,
        "effect_on":           list(s.effect_on),
        "dist_model_idx":      s.dist_model_idx,
        "overdrive_model_idx": s.overdrive_model_idx,
        "amp_model_idx":       s.amp_model_idx,
        "cab_model_idx":       s.cab_model_idx,
        "all_knob_values":     {k: list(v) for k, v in s.all_knob_values.items()},
    }


# ---- Encoder 0: rotate = effect select, button-down = toggle -------------

def test_appstate_defaults_have_encoder_fields():
    s = AppState()
    assert hasattr(s, "focus_effect_index")
    assert hasattr(s, "focus_param_index")
    assert hasattr(s, "edit_mode")
    assert hasattr(s, "model_select_mode")
    assert s.last_control_source == "notebook"


def test_enc0_rotate_only_changes_selected_effect():
    s = _new_state()
    snap = _snapshot(s)
    ctl = EncoderUiController(s)
    ctl.handle_event(EncoderEvent("rotate", 0, 2, 8))
    assert s.selected_effect == (snap["selected_effect"] + 2) % len(EFFECTS)
    # effect_on / model indices / knob values unchanged
    assert s.effect_on == snap["effect_on"]
    assert s.dist_model_idx == snap["dist_model_idx"]
    assert s.overdrive_model_idx == snap["overdrive_model_idx"]
    assert s.amp_model_idx == snap["amp_model_idx"]
    assert s.cab_model_idx == snap["cab_model_idx"]
    assert s.all_knob_values == snap["all_knob_values"]


def test_enc0_rotate_wraps_around():
    s = _new_state()
    s.selected_effect = len(EFFECTS) - 1
    ctl = EncoderUiController(s)
    ctl.handle_event(EncoderEvent("rotate", 0, 1, 4))
    assert s.selected_effect == 0


def test_enc0_button_down_edge_toggles_current_effect():
    s = _new_state()
    idx = s.selected_effect
    prev = bool(s.effect_on[idx])
    pre = _snapshot(s)
    ctl = EncoderUiController(s)
    ctl.process_button_state([False, False, False])  # seed
    ctl.process_button_state([True, False, False])   # rising edge on enc0
    assert s.effect_on[idx] is (not prev)
    # nothing else moves
    assert s.selected_effect == pre["selected_effect"]
    assert s.selected_knob == pre["selected_knob"]
    assert s.dist_model_idx == pre["dist_model_idx"]
    assert s.overdrive_model_idx == pre["overdrive_model_idx"]
    assert s.all_knob_values == pre["all_knob_values"]


def test_enc0_button_hold_does_not_repeat_toggle():
    s = _new_state()
    idx = s.selected_effect
    prev = bool(s.effect_on[idx])
    ctl = EncoderUiController(s)
    ctl.process_button_state([False, False, False])
    ctl.process_button_state([True, False, False])
    after_first = bool(s.effect_on[idx])
    # Holding (same pressed state) emits no further toggle.
    for _ in range(5):
        ctl.process_button_state([True, False, False])
    assert s.effect_on[idx] is after_first
    assert s.effect_on[idx] is (not prev)


def test_enc0_button_release_does_not_toggle():
    s = _new_state()
    idx = s.selected_effect
    ctl = EncoderUiController(s)
    ctl.process_button_state([False, False, False])
    ctl.process_button_state([True, False, False])  # toggle
    after_press = bool(s.effect_on[idx])
    ctl.process_button_state([False, False, False])  # release -- no toggle
    assert s.effect_on[idx] is after_press


def test_enc0_short_press_event_toggles_current_effect():
    """D51 fallback: the HW short_press latch on Encoder 0 toggles the
    selected effect even when the SW level rising edge was not visible
    between polls (taps shorter than the poll period)."""
    s = _new_state()
    idx = s.selected_effect
    before = bool(s.effect_on[idx])
    ctl = EncoderUiController(s)
    ctl.handle_event(EncoderEvent("short_press", 0))
    assert bool(s.effect_on[idx]) == (not before)


def test_enc0_short_press_and_level_edge_in_same_tick_toggles_once():
    """The short_press latch is consumed first; the level-edge path that
    runs inside the same tick must not double-toggle."""
    s = _new_state()
    idx = s.selected_effect
    before = bool(s.effect_on[idx])
    ctl = EncoderUiController(s)
    ctl.process_button_state([False, False, False])  # seed prev=0
    ctl._enc0_toggle_consumed_this_tick = False
    ctl.handle_event(EncoderEvent("short_press", 0))  # toggle #1 (short_press)
    # process_button_state with cur[0]=True would ordinarily fire a rising edge,
    # but the consumed flag prevents the double toggle.
    ctl.process_button_state([True, False, False])
    assert bool(s.effect_on[idx]) == (not before)


def test_enc0_long_press_event_is_noop_no_safe_bypass():
    s = _new_state()
    original = list(s.effect_on)
    ctl = EncoderUiController(s)
    ctl.handle_event(EncoderEvent("long_press", 0))
    # No safe-bypass: nothing flipped.
    assert s.effect_on == original


def test_enc0_button_down_on_preset_like_slot_is_noop():
    """If the selected slot maps to something outside EFFECT_KNOBS (PRESET-
    like placeholder), the toggle is suppressed."""
    import audio_lab_pynq.encoder_ui as ui_mod  # type: ignore

    s = _new_state()
    fake_idx = s.selected_effect
    orig_name = ui_mod.EFFECTS[fake_idx]
    ui_mod.EFFECTS[fake_idx] = "PRESET"
    try:
        snap = _snapshot(s)
        ctl = EncoderUiController(s)
        ctl.process_button_state([False, False, False])
        ctl.process_button_state([True, False, False])
        # PRESET slot must not be toggled.
        assert s.effect_on == snap["effect_on"]
    finally:
        ui_mod.EFFECTS[fake_idx] = orig_name


# ---- Encoder 1: rotate w/o hold = knob select, with hold = model cycle ----

def test_enc1_rotate_without_hold_only_changes_selected_knob():
    s = _new_state()
    s.selected_effect = 4  # Amp Sim (8 knobs)
    s.selected_knob = 0
    snap = _snapshot(s)
    ctl = EncoderUiController(s)
    ctl.set_button_state([False, False, False])
    ctl.handle_event(EncoderEvent("rotate", 1, 1, 4))
    assert s.selected_knob == 1
    # Model index / value untouched.
    assert s.amp_model_idx == snap["amp_model_idx"]
    assert s.dist_model_idx == snap["dist_model_idx"]
    assert s.overdrive_model_idx == snap["overdrive_model_idx"]
    assert s.cab_model_idx == snap["cab_model_idx"]
    assert s.all_knob_values == snap["all_knob_values"]


def test_enc1_hold_rotate_on_overdrive_cycles_overdrive_model_only():
    s = _new_state()
    s.selected_effect = EFFECTS.index("Overdrive")
    snap = _snapshot(s)
    ctl = EncoderUiController(s)
    ctl.set_button_state([False, True, False])
    ctl.handle_event(EncoderEvent("rotate", 1, 1, 4))
    assert s.overdrive_model_idx == (snap["overdrive_model_idx"] + 1) % 6
    # Other indices and knobs untouched.
    assert s.dist_model_idx == snap["dist_model_idx"]
    assert s.selected_knob == snap["selected_knob"]
    assert s.all_knob_values == snap["all_knob_values"]


def test_enc1_hold_rotate_on_distortion_cycles_dist_model_only_skip_rat():
    s = _new_state()
    s.selected_effect = EFFECTS.index("Distortion")
    s.dist_model_idx = 1  # tube screamer
    snap = _snapshot(s)
    ctl = EncoderUiController(s, skip_rat=True)
    ctl.set_button_state([False, True, False])
    ctl.handle_event(EncoderEvent("rotate", 1, 1, 4))
    assert s.dist_model_idx == 3  # skip bit 2 (RAT)
    assert s.overdrive_model_idx == snap["overdrive_model_idx"]


def test_enc1_hold_rotate_on_amp_cycles_amp_model_only():
    s = _new_state()
    s.selected_effect = EFFECTS.index("Amp Sim")
    snap = _snapshot(s)
    ctl = EncoderUiController(s)
    ctl.set_button_state([False, True, False])
    ctl.handle_event(EncoderEvent("rotate", 1, 2, 8))
    assert s.amp_model_idx == (snap["amp_model_idx"] + 2) % 6
    assert s.dist_model_idx == snap["dist_model_idx"]
    assert s.overdrive_model_idx == snap["overdrive_model_idx"]
    assert s.cab_model_idx == snap["cab_model_idx"]


def test_enc1_hold_rotate_on_cab_cycles_cab_model_only():
    s = _new_state()
    s.selected_effect = EFFECTS.index("Cab IR")
    snap = _snapshot(s)
    ctl = EncoderUiController(s)
    ctl.set_button_state([False, True, False])
    ctl.handle_event(EncoderEvent("rotate", 1, 1, 4))
    assert s.cab_model_idx == (snap["cab_model_idx"] + 1) % 3
    assert s.dist_model_idx == snap["dist_model_idx"]
    assert s.overdrive_model_idx == snap["overdrive_model_idx"]
    assert s.amp_model_idx == snap["amp_model_idx"]


def test_enc1_hold_rotate_on_non_model_effect_is_noop():
    s = _new_state()
    s.selected_effect = EFFECTS.index("Reverb")  # no model
    s.selected_knob = 0
    snap = _snapshot(s)
    ctl = EncoderUiController(s)
    ctl.set_button_state([False, True, False])
    ctl.handle_event(EncoderEvent("rotate", 1, 1, 4))
    # selected_knob NOT advanced because Encoder1 was held: hold+rotate on a
    # non-model effect is a no-op rather than a knob select.
    assert s.selected_knob == snap["selected_knob"]
    assert s.dist_model_idx == snap["dist_model_idx"]
    assert s.overdrive_model_idx == snap["overdrive_model_idx"]
    assert s.all_knob_values == snap["all_knob_values"]


def test_enc1_short_press_event_is_noop():
    s = _new_state()
    snap = _snapshot(s)
    pre_msm = s.model_select_mode
    pre_em = s.edit_mode
    ctl = EncoderUiController(s)
    ctl.handle_event(EncoderEvent("short_press", 1))
    assert s.model_select_mode == pre_msm
    assert s.edit_mode == pre_em
    assert s.dist_model_idx == snap["dist_model_idx"]
    assert s.overdrive_model_idx == snap["overdrive_model_idx"]


def test_enc1_long_press_event_is_noop():
    s = _new_state()
    snap = _snapshot(s)
    ctl = EncoderUiController(s)
    ctl.handle_event(EncoderEvent("long_press", 1))
    assert s.dist_model_idx == snap["dist_model_idx"]
    assert s.overdrive_model_idx == snap["overdrive_model_idx"]


def test_enc0_pressed_does_not_change_enc1_dispatch():
    """Encoder 0 / Encoder 2 button state must not influence Encoder 1 rotate.
    Only Encoder 1's own button state gates knob-select vs model-cycle."""
    s = _new_state()
    s.selected_effect = EFFECTS.index("Overdrive")
    s.selected_knob = 0
    snap = _snapshot(s)
    ctl = EncoderUiController(s)
    # Press encoder0 / encoder2 -- but NOT encoder1.
    ctl.set_button_state([True, False, True])
    ctl.handle_event(EncoderEvent("rotate", 1, 1, 4))
    # Should behave as plain knob-select.
    assert s.selected_knob == 1
    assert s.overdrive_model_idx == snap["overdrive_model_idx"]


# ---- Encoder 2: rotate = value change, button = no-op ----------------------

def test_enc2_rotate_only_changes_current_knob_value():
    s = _new_state()
    s.selected_effect = 4  # Amp Sim
    s.selected_knob = 0
    name = EFFECTS[s.selected_effect]
    initial = float(s.all_knob_values[name][0])
    snap = _snapshot(s)
    ctl = EncoderUiController(s, value_step=5.0)
    ctl.handle_event(EncoderEvent("rotate", 2, 2, 8))
    new = float(s.all_knob_values[name][0])
    assert new == min(100.0, initial + 10.0)
    assert s.selected_effect == snap["selected_effect"]
    assert s.selected_knob == snap["selected_knob"]
    assert s.dist_model_idx == snap["dist_model_idx"]
    assert s.overdrive_model_idx == snap["overdrive_model_idx"]


def test_enc2_rotate_clamps_to_0_100():
    s = _new_state()
    s.selected_effect = 4
    s.selected_knob = 0
    name = EFFECTS[s.selected_effect]
    s.all_knob_values[name][0] = 0.0
    ctl = EncoderUiController(s, value_step=10.0)
    ctl.handle_event(EncoderEvent("rotate", 2, -5, -20))
    assert s.all_knob_values[name][0] == 0.0
    s.all_knob_values[name][0] = 95.0
    ctl.handle_event(EncoderEvent("rotate", 2, 5, 20))
    assert s.all_knob_values[name][0] == 100.0


def test_enc2_short_press_event_is_noop_no_forced_apply():
    s = _new_state()
    s.selected_effect = 4
    s.selected_knob = 0
    name = EFFECTS[s.selected_effect]
    s.all_knob_values[name][0] = 42.0
    snap = _snapshot(s)
    ctl = EncoderUiController(s)
    ctl.handle_event(EncoderEvent("short_press", 2))
    assert s.all_knob_values == snap["all_knob_values"]


def test_enc2_long_press_event_is_noop_no_knob_reset():
    s = _new_state()
    s.selected_effect = EFFECTS.index("EQ")
    s.selected_knob = 0
    name = EFFECTS[s.selected_effect]
    s.all_knob_values[name][0] = 90.0
    ctl = EncoderUiController(s)
    ctl.handle_event(EncoderEvent("long_press", 2))
    # No knob reset to default.
    assert s.all_knob_values[name][0] == 90.0


def test_enc2_standalone_button_state_does_not_change_anything():
    s = _new_state()
    snap = _snapshot(s)
    ctl = EncoderUiController(s)
    ctl.process_button_state([False, False, False])
    ctl.process_button_state([False, False, True])
    ctl.process_button_state([False, False, False])
    assert s.effect_on == snap["effect_on"]
    assert s.selected_effect == snap["selected_effect"]
    assert s.selected_knob == snap["selected_knob"]
    assert s.all_knob_values == snap["all_knob_values"]


def test_enc1_standalone_button_state_does_not_change_anything():
    s = _new_state()
    snap = _snapshot(s)
    ctl = EncoderUiController(s)
    ctl.process_button_state([False, False, False])
    ctl.process_button_state([False, True, False])  # standalone enc1 press
    ctl.process_button_state([False, False, False])
    assert s.effect_on == snap["effect_on"]
    assert s.dist_model_idx == snap["dist_model_idx"]
    assert s.overdrive_model_idx == snap["overdrive_model_idx"]


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
    assert s.selected_effect == 2
    name = EFFECTS[s.selected_effect]
    expected_knob = 2 % max(1, len(s.all_knob_values.get(name, [0])))
    assert s.selected_knob == expected_knob


# ---- Live apply integration (Encoder 0 button-down edge + Encoder 2 rotate)

from audio_lab_pynq.encoder_effect_apply import (  # noqa: E402
    EncoderEffectApplier, RAT_PEDAL_INDEX)


class _RecOverlay(object):
    def __init__(self):
        self.calls = []

    def _rec(self, n, kw):
        self.calls.append((n, dict(kw)))

    def set_noise_suppressor_settings(self, **kw):
        self._rec("set_noise_suppressor_settings", kw); return {}

    def set_compressor_settings(self, **kw):
        self._rec("set_compressor_settings", kw); return {}

    def set_guitar_effects(self, **kw):
        self._rec("set_guitar_effects", kw); return {}

    def clear_distortion_pedals(self):
        self._rec("clear_distortion_pedals", {}); return {}


def _make_controller(state, *, dry_run=True, apply_interval_s=10.0,
                     skip_rat=True, live_apply=True):
    overlay = _RecOverlay()
    applier = EncoderEffectApplier(
        overlay, apply_interval_s=apply_interval_s,
        dry_run=dry_run, skip_rat=skip_rat,
    )
    ctl = EncoderUiController(
        state, applier=applier, live_apply=live_apply, skip_rat=skip_rat)
    return ctl, applier, overlay


def test_enc0_button_down_edge_drives_applier_on_off():
    s = _new_state()
    idx = s.selected_effect
    prev = bool(s.effect_on[idx])
    ctl, _, overlay = _make_controller(s, dry_run=False, apply_interval_s=0.0)
    ctl.process_button_state([False, False, False])
    ctl.process_button_state([True, False, False])
    assert s.effect_on[idx] is (not prev)
    methods = [name for name, _ in overlay.calls]
    assert any(m.startswith("set_") for m in methods)


def test_enc2_rotate_throttle_active():
    s = _new_state()
    s.selected_effect = 4  # Amp Sim
    s.selected_knob = 0
    ctl, _, overlay = _make_controller(
        s, dry_run=False, apply_interval_s=10.0)
    ctl.handle_event(EncoderEvent("rotate", 2, 1, 4))
    n_after_first = len(overlay.calls)
    # Second rotation within the throttle window must not trigger a new write.
    ctl.handle_event(EncoderEvent("rotate", 2, 1, 4))
    assert len(overlay.calls) == n_after_first


def test_short_long_press_events_never_trigger_overlay_writes():
    """Only Encoder 0 short_press is allowed to drive the applier (D51
    fallback for missed level-edge taps); every other button event kind
    on every encoder stays a no-op."""
    s = _new_state()
    ctl, _, overlay = _make_controller(s, dry_run=False, apply_interval_s=0.0)
    for kind, eid in (
        ("short_press", 1), ("short_press", 2),
        ("long_press", 0), ("long_press", 1), ("long_press", 2),
        ("click", 0), ("click", 1), ("click", 2),
    ):
        ctl.handle_event(EncoderEvent(kind, eid))
    assert overlay.calls == []


def test_skip_rat_cycle_advances_past_bit_2_via_hold():
    s = _new_state()
    s.selected_effect = EFFECTS.index("Distortion")
    s.dist_model_idx = 1
    ctl, _, _ = _make_controller(s, dry_run=True, skip_rat=True)
    ctl.set_button_state([False, True, False])
    ctl.handle_event(EncoderEvent("rotate", 1, 1, 4))
    assert s.dist_model_idx != RAT_PEDAL_INDEX
    assert s.dist_model_idx == 3


def test_include_rat_cycle_lands_on_bit_2_via_hold():
    s = _new_state()
    s.selected_effect = EFFECTS.index("Distortion")
    s.dist_model_idx = 1
    ctl, _, _ = _make_controller(s, dry_run=True, skip_rat=False)
    ctl.set_button_state([False, True, False])
    ctl.handle_event(EncoderEvent("rotate", 1, 1, 4))
    assert s.dist_model_idx == RAT_PEDAL_INDEX


def test_tick_reads_button_state_and_dispatches():
    """Verify the runner-facing tick() consumes both events and button state."""
    s = _new_state()
    idx = s.selected_effect
    prev = bool(s.effect_on[idx])
    ctl, _, _ = _make_controller(s, dry_run=True, apply_interval_s=0.0)

    class _StubInput(object):
        def __init__(self):
            self._level = 0
            self._events = []

        def set_button(self, level):
            self._level = level & 0x7

        def queue(self, events):
            self._events = list(events)

        def read_button_state(self):
            return self._level

        def poll(self, timestamp=0.0):
            out = self._events
            self._events = []
            return out

    inp = _StubInput()
    # First tick seeds prev_pressed without emitting any edge.
    ctl.tick(inp)
    inp.set_button(0x1)  # enc0 pressed
    ctl.tick(inp)
    assert s.effect_on[idx] is (not prev)
    # Hold across additional ticks: no further toggle.
    after = bool(s.effect_on[idx])
    ctl.tick(inp)
    ctl.tick(inp)
    assert s.effect_on[idx] is after


# ---- D53 binary DRV MODE knob -------------------------------------------


def test_enc2_rotate_on_amp_drv_mode_toggles_zero_one():
    """Encoder 2 on the Amp Sim binary slot (idx 7) must snap to 0/1
    rather than stepping by value_step (D53)."""
    s = _new_state()
    s.selected_effect = EFFECTS.index("Amp Sim")
    s.selected_knob = 7
    # Start at 0.
    s.all_knob_values["Amp Sim"][7] = 0.0
    s.amp_drive_mode = 0
    ctl = EncoderUiController(s)
    ctl.handle_event(EncoderEvent("rotate", 2, 1, 4))
    assert s.all_knob_values["Amp Sim"][7] == 1.0
    assert s.amp_drive_mode == 1
    # A negative delta clamps back to 0.
    ctl.handle_event(EncoderEvent("rotate", 2, -1, -4))
    assert s.all_knob_values["Amp Sim"][7] == 0.0
    assert s.amp_drive_mode == 0


def test_enc2_rotate_on_amp_drv_mode_repeated_delta_stays_binary():
    """Multiple positive deltas on the DRV MODE knob keep value at 1
    instead of accumulating beyond 1.0."""
    s = _new_state()
    s.selected_effect = EFFECTS.index("Amp Sim")
    s.selected_knob = 7
    s.all_knob_values["Amp Sim"][7] = 0.0
    s.amp_drive_mode = 0
    ctl = EncoderUiController(s)
    for _ in range(5):
        ctl.handle_event(EncoderEvent("rotate", 2, 1, 4))
    assert s.all_knob_values["Amp Sim"][7] == 1.0
    assert s.amp_drive_mode == 1


def test_enc2_rotate_on_continuous_knob_still_steps():
    """Continuous knobs keep the value_step behaviour (regression guard)."""
    s = _new_state()
    s.selected_effect = EFFECTS.index("Amp Sim")
    s.selected_knob = 0  # GAIN -- continuous
    s.all_knob_values["Amp Sim"][0] = 45.0
    ctl = EncoderUiController(s)
    ctl.handle_event(EncoderEvent("rotate", 2, 2, 8))
    assert s.all_knob_values["Amp Sim"][0] == 55.0


# ---- D74 Encoder 2 button = Wah SOURCE toggle ----------------------------

def test_enc2_button_toggles_wah_source_when_wah_selected():
    s = _new_state()
    s.selected_effect = EFFECTS.index("Wah")
    s.wah_source = "manual"
    ctl = EncoderUiController(s)
    ctl.process_button_state([False, False, False])  # seed
    ctl.process_button_state([False, False, True])   # enc2 rising edge
    assert s.wah_source == "pedal"
    ctl.process_button_state([False, False, False])  # release
    ctl.process_button_state([False, False, True])   # toggle back
    assert s.wah_source == "manual"


def test_enc2_button_noop_when_not_wah():
    s = _new_state()
    s.selected_effect = EFFECTS.index("Amp Sim")
    s.wah_source = "manual"
    ctl = EncoderUiController(s)
    ctl.process_button_state([False, False, False])
    ctl.process_button_state([False, False, True])
    assert s.wah_source == "manual"  # unchanged


def test_enc2_button_hold_does_not_repeat_toggle():
    s = _new_state()
    s.selected_effect = EFFECTS.index("Wah")
    s.wah_source = "manual"
    ctl = EncoderUiController(s)
    ctl.process_button_state([False, False, False])
    ctl.process_button_state([False, False, True])   # toggle -> pedal
    for _ in range(5):
        ctl.process_button_state([False, False, True])  # held, no repeat
    assert s.wah_source == "pedal"


_TEST_FUNCTIONS = [
    test_enc2_button_toggles_wah_source_when_wah_selected,
    test_enc2_button_noop_when_not_wah,
    test_enc2_button_hold_does_not_repeat_toggle,
    test_appstate_defaults_have_encoder_fields,
    # Encoder 0
    test_enc0_rotate_only_changes_selected_effect,
    test_enc0_rotate_wraps_around,
    test_enc0_button_down_edge_toggles_current_effect,
    test_enc0_button_hold_does_not_repeat_toggle,
    test_enc0_button_release_does_not_toggle,
    test_enc0_short_press_event_toggles_current_effect,
    test_enc0_short_press_and_level_edge_in_same_tick_toggles_once,
    test_enc0_long_press_event_is_noop_no_safe_bypass,
    test_enc0_button_down_on_preset_like_slot_is_noop,
    # Encoder 1
    test_enc1_rotate_without_hold_only_changes_selected_knob,
    test_enc1_hold_rotate_on_overdrive_cycles_overdrive_model_only,
    test_enc1_hold_rotate_on_distortion_cycles_dist_model_only_skip_rat,
    test_enc1_hold_rotate_on_amp_cycles_amp_model_only,
    test_enc1_hold_rotate_on_cab_cycles_cab_model_only,
    test_enc1_hold_rotate_on_non_model_effect_is_noop,
    test_enc1_short_press_event_is_noop,
    test_enc1_long_press_event_is_noop,
    test_enc0_pressed_does_not_change_enc1_dispatch,
    # Encoder 2
    test_enc2_rotate_only_changes_current_knob_value,
    test_enc2_rotate_clamps_to_0_100,
    test_enc2_short_press_event_is_noop_no_forced_apply,
    test_enc2_long_press_event_is_noop_no_knob_reset,
    test_enc2_standalone_button_state_does_not_change_anything,
    test_enc1_standalone_button_state_does_not_change_anything,
    # Sequencing
    test_handle_events_dispatches_in_order,
    # Live-apply integration
    test_enc0_button_down_edge_drives_applier_on_off,
    test_enc2_rotate_throttle_active,
    test_short_long_press_events_never_trigger_overlay_writes,
    test_skip_rat_cycle_advances_past_bit_2_via_hold,
    test_include_rat_cycle_lands_on_bit_2_via_hold,
    test_tick_reads_button_state_and_dispatches,
    # D53 binary DRV MODE
    test_enc2_rotate_on_amp_drv_mode_toggles_zero_one,
    test_enc2_rotate_on_amp_drv_mode_repeated_delta_stays_binary,
    test_enc2_rotate_on_continuous_knob_still_steps,
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
