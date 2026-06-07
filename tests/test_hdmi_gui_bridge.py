import sys
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from GUI.audio_lab_gui_bridge import (  # noqa: E402
    AudioLabGuiBridge,
    app_state_to_audio_lab_sections,
    chain_preset_name_from_state,
    safe_bypass_plan,
    taper_guitar_effects_kwargs,
)

try:
    from GUI.pynq_multi_fx_gui import AppState  # noqa: E402
except Exception:
    class AppState(object):
        def __init__(self):
            self.preset_id = "02A"
            self.preset_name = "BASIC  CLEAN"
            self.preset_idx = 1
            # 9-effect layout post-Wah:
            # 0=Noise Sup, 1=Compressor, 2=Wah, 3=Overdrive,
            # 4=Distortion, 5=Amp Sim, 6=Cab IR, 7=EQ, 8=Reverb
            self.chain = list(range(9))
            self.effect_on = [
                True, True, False, True, False, True, True, True, True]
            self.selected_effect = 5  # Amp Sim
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
    assert "set_wah_settings" in methods
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

    # (1).py port removed the flat ``knob_values`` field on AppState; the
    # bridge still reads ``state.knob_values`` defensively via getattr, so
    # we seed it from the currently selected effect's knob defaults and
    # then mutate to trigger the knob-drag throttle path.
    state.knob_values = [v for _, v in state.knobs()] \
        if hasattr(state, "knobs") else [45, 55, 60, 50, 70, 60]
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
        "set_wah_settings",
        "set_guitar_effects",
    ]
    assert plan.operations[-1].kwargs["distortion_on"] is False
    assert plan.operations[-1].kwargs["reverb_on"] is False


def test_effect_on_flags_follow_named_wah_layout():
    state = AppState()

    sections = app_state_to_audio_lab_sections(state)

    assert sections["noise_suppressor"]["enabled"] is True
    assert sections["compressor"]["enabled"] is True
    assert sections["wah"]["enabled"] is False
    assert sections["overdrive"]["enabled"] is True
    assert sections["distortion"]["enabled"] is False
    assert sections["amp"]["enabled"] is True
    assert sections["cab"]["enabled"] is True
    assert sections["eq"]["enabled"] is False
    assert sections["reverb"]["enabled"] is True


def test_wah_section_maps_to_dedicated_overlay_call():
    state = AppState()
    if not hasattr(state, "all_knob_values"):
        state.all_knob_values = {}
    state.effect_on[2] = True
    state.all_knob_values["Wah"] = [33.0, 44.0, 55.0, 66.0]
    state.wah_source = "manual"

    plan = AudioLabGuiBridge().build_plan(state, force=True)
    op = [op for op in plan.operations if op.method == "set_wah_settings"][0]

    assert op.kwargs == dict(enabled=True, q=44, volume=55, bias=66,
                             source="manual", position=33)


def test_wah_pedal_source_does_not_overwrite_position():
    state = AppState()
    if not hasattr(state, "all_knob_values"):
        state.all_knob_values = {}
    state.effect_on[2] = True
    state.all_knob_values["Wah"] = [33.0, 44.0, 55.0, 66.0]
    state.wah_source = "pedal"

    plan = AudioLabGuiBridge().build_plan(state, force=True)
    op = [op for op in plan.operations if op.method == "set_wah_settings"][0]

    assert op.kwargs == dict(enabled=True, q=44, volume=55, bias=66,
                             source="pedal")


def test_eq_knobs_map_gui_percent_to_overlay_level_range():
    state = AppState()
    if not hasattr(state, "all_knob_values"):
        state.all_knob_values = {}
    state.all_knob_values["EQ"] = [50, 55, 60]

    sections = app_state_to_audio_lab_sections(state)

    assert sections["eq"]["low"] == 100
    assert sections["eq"]["mid"] == 110
    assert sections["eq"]["high"] == 120


def test_live_plan_tapers_gui_drive_but_keeps_levels():
    state = AppState()
    if not hasattr(state, "all_knob_values"):
        state.all_knob_values = {}
    # compact-v2 Overdrive order is TONE / LEVEL / DRIVE.
    state.all_knob_values["Overdrive"] = [75.0, 80.0, 50.0]

    plan = AudioLabGuiBridge().build_plan(state, force=True)
    op = [op for op in plan.operations if op.method == "set_guitar_effects"][0]
    expected = taper_guitar_effects_kwargs(dict(
        overdrive_drive=50,
        overdrive_tone=75,
        overdrive_level=80,
    ))

    assert op.kwargs["overdrive_drive"] == expected["overdrive_drive"]
    assert op.kwargs["overdrive_tone"] == expected["overdrive_tone"]
    assert op.kwargs["overdrive_level"] == 80


if __name__ == "__main__":
    tests = [
        test_default_app_state_maps_to_supported_overlay_api,
        test_dry_run_skips_same_state_rewrite,
        test_knob_drag_is_throttled_to_control_rate,
        test_chain_reorder_is_warning_only,
        test_chain_preset_alias_matches_overlay_name,
        test_safe_bypass_uses_existing_safe_api_sequence,
        test_effect_on_flags_follow_named_wah_layout,
        test_wah_section_maps_to_dedicated_overlay_call,
        test_wah_pedal_source_does_not_overwrite_position,
        test_eq_knobs_map_gui_percent_to_overlay_level_range,
        test_live_plan_tapers_gui_drive_but_keeps_levels,
    ]
    for test in tests:
        test()
