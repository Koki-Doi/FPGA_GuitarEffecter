import sys
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from GUI.audio_lab_gui_bridge import (  # noqa: E402
    AudioLabGuiBridge,
    app_state_to_audio_lab_sections,
    chain_preset_name_from_state,
    safe_bypass_plan,
)

try:
    from GUI.pynq_multi_fx_gui import AppState  # noqa: E402
except Exception:
    class AppState(object):
        def __init__(self):
            self.preset_id = "02A"
            self.preset_name = "BASIC  CLEAN"
            self.preset_idx = 1
            self.chain = list(range(8))
            self.effect_on = [
                True, True, False, False, True, True, True, True]
            self.selected_effect = 4
            self.knob_values = [45, 55, 60, 50, 70, 60]
            self.dist_model_idx = 1
            self.amp_model_idx = 2
            self.cab_model_idx = 2


def test_default_app_state_maps_to_supported_overlay_api():
    state = AppState()
    plan = AudioLabGuiBridge().build_plan(state, force=True)
    methods = [op.method for op in plan.operations]

    assert "set_noise_suppressor_settings" in methods
    assert "set_compressor_settings" in methods
    assert "set_guitar_effects" in methods
    assert "apply_chain_preset" not in methods
    assert "set_chorus" not in methods
    assert "set_delay" not in methods


def test_dry_run_skips_same_state_rewrite():
    bridge = AudioLabGuiBridge()
    state = AppState()

    first = bridge.apply(state, dry_run=True, force=True)
    second = bridge.apply(state, dry_run=True)

    assert first["operations"]
    assert second["operations"] == []
    assert second["skipped"] == []


def test_knob_drag_is_throttled_to_control_rate():
    bridge = AudioLabGuiBridge(knob_throttle_seconds=0.10)
    state = AppState()
    bridge.apply(state, dry_run=True, force=True, now=10.00)

    state.knob_values = list(state.knob_values)
    state.knob_values[0] += 1
    throttled = bridge.apply(
        state, dry_run=True, event="knob_drag", now=10.05)
    released = bridge.apply(
        state, dry_run=True, event="knob_drag", now=10.20)

    assert throttled["operations"] == []
    assert throttled["skipped"]
    assert released["operations"]


def test_chain_reorder_is_warning_only():
    state = AppState()
    state.chain = list(reversed(state.chain))
    plan = AudioLabGuiBridge().build_plan(state, force=True)

    assert plan.warnings
    assert all(op.method != "set_chain_order" for op in plan.operations)


def test_chain_preset_alias_matches_overlay_name():
    state = AppState()
    state.preset_idx = 4  # GUI label: TS Lead

    assert chain_preset_name_from_state(state) == "Tube Screamer Lead"
    result = AudioLabGuiBridge().apply_chain_preset(state, dry_run=True)
    assert result["operations"][0]["method"] == "apply_chain_preset"
    assert result["operations"][0]["kwargs"]["name"] == "Tube Screamer Lead"


def test_safe_bypass_uses_existing_safe_api_sequence():
    plan = safe_bypass_plan()
    methods = [op.method for op in plan.operations]

    assert methods == [
        "clear_distortion_pedals",
        "set_distortion_settings",
        "set_noise_suppressor_settings",
        "set_compressor_settings",
        "set_guitar_effects",
    ]
    assert plan.operations[-1].kwargs["distortion_on"] is False
    assert plan.operations[-1].kwargs["reverb_on"] is False


def test_eq_knobs_map_gui_percent_to_overlay_level_range():
    state = AppState()
    state.selected_effect = 6
    state.knob_values = [50, 55, 60, 0, 0, 0]

    sections = app_state_to_audio_lab_sections(state)

    assert sections["eq"]["low"] == 100
    assert sections["eq"]["mid"] == 110
    assert sections["eq"]["high"] == 120


if __name__ == "__main__":
    tests = [
        test_default_app_state_maps_to_supported_overlay_api,
        test_dry_run_skips_same_state_rewrite,
        test_knob_drag_is_throttled_to_control_rate,
        test_chain_reorder_is_warning_only,
        test_chain_preset_alias_matches_overlay_name,
        test_safe_bypass_uses_existing_safe_api_sequence,
        test_eq_knobs_map_gui_percent_to_overlay_level_range,
    ]
    for test in tests:
        test()
