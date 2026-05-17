"""Offline tests for shared catalog/apply-plan refactors."""

import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(REPO_ROOT / "GUI"))

from audio_lab_pynq.app_state_apply_plan import (  # noqa: E402
    RAT_PEDAL_INDEX,
    app_state_to_audio_lab_sections,
    encoder_state_plan,
    full_state_plan,
)
from audio_lab_pynq.effect_catalog import (  # noqa: E402
    EFFECT_KNOBS,
    EFFECT_KNOB_DEFAULTS,
    MIRROR_EFFECT_KNOBS,
)
from compact_v2.knobs import (  # type: ignore  # noqa: E402
    EFFECT_KNOBS as GUI_EFFECT_KNOBS,
    _EFFECT_KNOB_DEFAULTS as GUI_EFFECT_KNOB_DEFAULTS,
)
from audio_lab_pynq.hdmi_state.knobs import (  # noqa: E402
    GUI_EFFECT_KNOBS as HDMI_EFFECT_KNOBS,
)
from compact_v2.state import AppState  # type: ignore  # noqa: E402


def test_gui_and_hdmi_knobs_read_shared_catalog():
    assert GUI_EFFECT_KNOBS is EFFECT_KNOBS
    assert GUI_EFFECT_KNOB_DEFAULTS is EFFECT_KNOB_DEFAULTS
    assert HDMI_EFFECT_KNOBS is MIRROR_EFFECT_KNOBS


def test_bridge_and_encoder_plans_share_section_mapping():
    state = AppState()
    state.selected_effect = 6
    state.knob_values = [50, 55, 60, 0, 0, 0]
    sections = app_state_to_audio_lab_sections(state)
    bridge_plan = full_state_plan(state)

    assert sections["eq"]["mid"] == 110
    assert bridge_plan.sections["eq"]["mid"] == 110
    assert any(op.method == "set_guitar_effects"
               for op in bridge_plan.operations)


def test_encoder_plan_keeps_rat_exclusion_in_common_logic():
    state = AppState()
    state.dist_model_idx = RAT_PEDAL_INDEX
    plan = encoder_state_plan(state, skip_rat=True)
    guitar = [op for op in plan.operations if op.method == "set_guitar_effects"][0]

    assert guitar.kwargs["distortion_pedal_mask"] == 0
    assert guitar.kwargs["rat_on"] is False
    assert "Distortion:rat" in plan.unsupported


def test_encoder_plan_can_include_rat_bit_without_rat_flag():
    state = AppState()
    state.dist_model_idx = RAT_PEDAL_INDEX
    plan = encoder_state_plan(state, skip_rat=False)
    guitar = [op for op in plan.operations if op.method == "set_guitar_effects"][0]

    assert guitar.kwargs["distortion_pedal_mask"] == (1 << RAT_PEDAL_INDEX)
    assert guitar.kwargs["rat_on"] is False
    assert plan.unsupported == []


_TEST_FUNCTIONS = [
    test_gui_and_hdmi_knobs_read_shared_catalog,
    test_bridge_and_encoder_plans_share_section_mapping,
    test_encoder_plan_keeps_rat_exclusion_in_common_logic,
    test_encoder_plan_can_include_rat_bit_without_rat_flag,
]


def load_tests(_loader, _tests, _pattern):
    suite = unittest.TestSuite()
    for test in _TEST_FUNCTIONS:
        suite.addTest(unittest.FunctionTestCase(test))
    return suite


if __name__ == "__main__":
    for test in _TEST_FUNCTIONS:
        test()
        print("PASS", test.__name__)
