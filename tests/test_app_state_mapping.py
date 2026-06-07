"""Tests for shared compact-v2 AppState effect-order helpers."""

import importlib.util
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(REPO_ROOT / "GUI"))
sys.path.insert(0, str(Path(__file__).resolve().parent))


def _load_mapping():
    path = REPO_ROOT / "audio_lab_pynq" / "app_state_mapping.py"
    spec = importlib.util.spec_from_file_location("_test_app_state_mapping", str(path))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


asm = _load_mapping()


class State(object):
    pass


def test_shared_effect_order_matches_compact_v2_gui():
    from compact_v2.knobs import EFFECTS

    assert tuple(EFFECTS) == asm.EFFECTS
    assert asm.IDX_WAH == 2
    assert asm.IDX_OVERDRIVE == 3
    assert asm.IDX_DISTORTION == 4
    assert asm.NUM_EFFECTS == len(EFFECTS)


def test_effect_enabled_reads_by_name():
    state = State()
    state.effect_on = [False] * asm.NUM_EFFECTS
    state.effect_on[asm.IDX_WAH] = True

    assert asm.effect_enabled(state, asm.EFFECT_WAH) is True
    assert asm.effect_enabled(state, asm.EFFECT_AMP) is False
    assert asm.effect_enabled(state, "missing", default=True) is True


def test_ensure_effect_on_length_pads_and_trims():
    assert asm.ensure_effect_on_length([True], fill=False) == (
        [True] + [False] * (asm.NUM_EFFECTS - 1))
    assert asm.ensure_effect_on_length([True] * 20) == [True] * asm.NUM_EFFECTS


def test_knob_list_returns_fallback_for_missing_or_short_values():
    state = State()
    state.all_knob_values = {"Wah": [1.0, 2.0]}

    assert asm.knob_list(state, "Wah", [0, 50, 50, 50]) == [0, 50, 50, 50]
    state.all_knob_values["Wah"] = [1.0, 2.0, 3.0, 4.0]
    assert asm.knob_list(state, "Wah", [0, 50, 50, 50]) == [1.0, 2.0, 3.0, 4.0]


def test_footswitch_index_exports_follow_shared_mapping():
    import _pynq_mock
    _pynq_mock.install()

    from audio_lab_pynq import footswitch_control as fc

    assert fc.IDX_NOISE_SUP == asm.IDX_NOISE_SUP
    assert fc.IDX_COMPRESSOR == asm.IDX_COMPRESSOR
    assert fc.IDX_WAH == asm.IDX_WAH
    assert fc.IDX_OVERDRIVE == asm.IDX_OVERDRIVE
    assert fc.IDX_DISTORTION == asm.IDX_DISTORTION
    assert fc.IDX_AMP == asm.IDX_AMP
    assert fc.IDX_CAB == asm.IDX_CAB
    assert fc.IDX_EQ == asm.IDX_EQ
    assert fc.IDX_REVERB == asm.IDX_REVERB
