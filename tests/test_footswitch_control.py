"""Offline tests for audio_lab_pynq.footswitch_control (no pynq required)."""

import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(REPO_ROOT / "GUI"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import _pynq_mock  # noqa: E402
_pynq_mock.install()

from audio_lab_pynq.footswitch_input import FootswitchEvent  # noqa: E402
from audio_lab_pynq.footswitch_control import (  # noqa: E402
    FootswitchController, apply_chain_preset_to_state, chain_preset_names,
    IDX_AMP, IDX_DISTORTION, IDX_COMPRESSOR, IDX_REVERB,
)
from audio_lab_pynq.effect_presets import CHAIN_PRESETS  # noqa: E402
from compact_v2.state import AppState  # type: ignore  # noqa: E402
from compact_v2.knobs import EFFECTS  # type: ignore  # noqa: E402


class FakeApplier(object):
    def __init__(self):
        self.on_off = []

    def apply_effect_on_off(self, name, enabled):
        self.on_off.append((name, bool(enabled)))
        return True


class FakeOverlay(object):
    def __init__(self):
        self.presets = []

    def apply_chain_preset(self, name):
        self.presets.append(name)
        return {}


def _press(channel, ts):
    return FootswitchEvent(kind="press", channel=channel, timestamp=ts)


class FxToggleTests(unittest.TestCase):
    def setUp(self):
        self.applier = FakeApplier()
        self.state = AppState()
        self.ctrl = FootswitchController(
            applier=self.applier, state=self.state, effects=EFFECTS)

    def test_single_press_toggles_bound_effect(self):
        target = self.state.footswitch_fx_target  # default 5 (Amp Sim)
        before = self.state.effect_on[target]
        self.ctrl.handle_event(_press(0, 0.0))
        self.assertEqual(self.state.effect_on[target], not before)
        self.assertEqual(self.applier.on_off[-1],
                         (EFFECTS[target], not before))

    def test_two_presses_return_to_start(self):
        target = self.state.footswitch_fx_target
        before = self.state.effect_on[target]
        self.ctrl.handle_event(_press(0, 0.0))
        self.ctrl.handle_event(_press(0, 1.0))
        self.assertEqual(self.state.effect_on[target], before)

    def test_five_presses_in_window_rebind(self):
        self.state.footswitch_fx_target = IDX_AMP   # 5
        self.state.selected_effect = IDX_DISTORTION  # 4
        before_amp = self.state.effect_on[IDX_AMP]
        for i in range(5):
            self.ctrl.handle_event(_press(0, i * 0.1))  # all within 3 s
        # Rebound to the GUI-selected effect ...
        self.assertEqual(self.state.footswitch_fx_target, IDX_DISTORTION)
        # ... and the old target's on/off netted back to where it started.
        self.assertEqual(self.state.effect_on[IDX_AMP], before_amp)

    def test_slow_presses_do_not_rebind(self):
        self.state.footswitch_fx_target = IDX_AMP
        self.state.selected_effect = IDX_DISTORTION
        for i in range(5):
            self.ctrl.handle_event(_press(0, i * 5.0))  # 5 s apart -> never 5/3s
        self.assertEqual(self.state.footswitch_fx_target, IDX_AMP)

    def test_rebind_press_does_not_toggle_old_target(self):
        # exactly 5 fast presses: 4 toggles + 1 rebind (no toggle)
        self.state.footswitch_fx_target = IDX_AMP
        self.state.selected_effect = IDX_COMPRESSOR
        for i in range(5):
            self.ctrl.handle_event(_press(0, i * 0.1))
        # applier saw exactly 4 toggle writes (the 5th press was a rebind)
        self.assertEqual(len(self.applier.on_off), 4)


class PresetStepTests(unittest.TestCase):
    def setUp(self):
        self.applier = FakeApplier()
        self.overlay = FakeOverlay()
        self.state = AppState()
        self.names = chain_preset_names()
        self.ctrl = FootswitchController(
            applier=self.applier, state=self.state, effects=EFFECTS,
            overlay=self.overlay)

    def test_next_advances_and_applies(self):
        self.state.preset_idx = 0
        self.ctrl.handle_event(_press(1, 0.0))
        self.assertEqual(self.state.preset_idx, 1)
        self.assertEqual(self.overlay.presets[-1], self.names[1])
        self.assertEqual(self.state.preset_name, self.names[1].upper())

    def test_next_wraps(self):
        self.state.preset_idx = len(self.names) - 1
        self.ctrl.handle_event(_press(1, 0.0))
        self.assertEqual(self.state.preset_idx, 0)
        self.assertEqual(self.overlay.presets[-1], self.names[0])

    def test_prev_wraps_from_zero(self):
        self.state.preset_idx = 0
        self.ctrl.handle_event(_press(2, 0.0))
        self.assertEqual(self.state.preset_idx, len(self.names) - 1)
        self.assertEqual(self.overlay.presets[-1], self.names[-1])

    def test_preset_mirrors_effect_on(self):
        # Step until we land on "Basic Clean" and check the mirrored flags.
        idx = self.names.index("Basic Clean")
        self.state.preset_idx = idx - 1
        self.ctrl.handle_event(_press(1, 0.0))
        self.assertEqual(self.state.preset_idx, idx)
        spec = CHAIN_PRESETS["Basic Clean"]
        self.assertEqual(self.state.effect_on[IDX_COMPRESSOR],
                         bool(spec["compressor"]["enabled"]))
        self.assertEqual(self.state.effect_on[IDX_REVERB],
                         bool(spec["reverb"]["enabled"]))


class PresetMirrorTests(unittest.TestCase):
    def test_metal_tight_maps_pedal_and_cab(self):
        state = AppState()
        apply_chain_preset_to_state(state, "Metal Tight")
        # distortion section on with pedal "metal" -> dist_model_idx 6
        self.assertTrue(state.effect_on[IDX_DISTORTION])
        self.assertEqual(state.dist_model_idx, 6)
        self.assertEqual(state.cab_model_idx, 2)

    def test_eq_scale_halved(self):
        state = AppState()
        apply_chain_preset_to_state(state, "Ambient Clean")
        spec = CHAIN_PRESETS["Ambient Clean"]["eq"]
        eq = state.all_knob_values["EQ"]
        self.assertAlmostEqual(eq[0], spec["low"] / 2.0)
        self.assertAlmostEqual(eq[2], spec["high"] / 2.0)

    def test_unknown_preset_noop(self):
        state = AppState()
        before = list(state.effect_on)
        apply_chain_preset_to_state(state, "does-not-exist")
        self.assertEqual(state.effect_on, before)


if __name__ == "__main__":
    unittest.main()
