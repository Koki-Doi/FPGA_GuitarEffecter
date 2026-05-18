"""Offline tests for audio_lab_pynq.encoder_effect_apply.EncoderEffectApplier."""

import sys
import time
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(REPO_ROOT / "GUI"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import _pynq_mock  # noqa: E402
_pynq_mock.install()


from audio_lab_pynq.encoder_effect_apply import (  # noqa: E402
    EncoderEffectApplier,
    RAT_PEDAL_INDEX,
    is_rat_pedal_index,
)
from compact_v2.state import AppState  # type: ignore  # noqa: E402


class FakeOverlay(object):
    """Records every set_* / clear_* call but stores no real state."""

    def __init__(self):
        self.calls = []

    def _rec(self, name, kwargs):
        self.calls.append((name, dict(kwargs)))

    def set_noise_suppressor_settings(self, **kwargs):
        self._rec("set_noise_suppressor_settings", kwargs)
        return {"ok": True}

    def set_compressor_settings(self, **kwargs):
        self._rec("set_compressor_settings", kwargs)
        return {"ok": True}

    def set_guitar_effects(self, **kwargs):
        self._rec("set_guitar_effects", kwargs)
        return {"ok": True}

    def clear_distortion_pedals(self):
        self._rec("clear_distortion_pedals", {})
        return {"pedal_mask": 0}


def _kwargs_of(overlay, method):
    for name, kwargs in overlay.calls:
        if name == method:
            return kwargs
    return None


# ---- basic behaviour ----------------------------------------------------

def test_dry_run_does_not_call_overlay():
    ov = FakeOverlay()
    ap = EncoderEffectApplier(ov, dry_run=True)
    state = AppState()
    assert ap.apply_appstate(state, force=True) is True
    assert ov.calls == []
    assert ap.last_apply_ok is True
    assert "dry" in ap.last_apply_message


def test_apply_appstate_calls_three_overlay_methods():
    ov = FakeOverlay()
    ap = EncoderEffectApplier(ov)
    state = AppState()
    assert ap.apply_appstate(state, force=True) is True
    methods = [name for name, _ in ov.calls]
    assert "set_noise_suppressor_settings" in methods
    assert "set_compressor_settings" in methods
    assert "set_guitar_effects" in methods
    assert ap.apply_count == 1
    assert ap.error_count == 0


def test_throttle_blocks_back_to_back_calls():
    ov = FakeOverlay()
    ap = EncoderEffectApplier(ov, apply_interval_s=0.5)
    state = AppState()
    assert ap.apply_appstate(state, force=False) is True
    n_calls = len(ov.calls)
    # Immediately try again without force: should be throttled.
    ran = ap.apply_appstate(state, force=False)
    assert ran is False
    assert len(ov.calls) == n_calls


def test_force_bypasses_throttle():
    ov = FakeOverlay()
    ap = EncoderEffectApplier(ov, apply_interval_s=10.0)
    state = AppState()
    ap.apply_appstate(state, force=True)
    n_calls = len(ov.calls)
    ap.apply_appstate(state, force=True)
    assert len(ov.calls) > n_calls


# ---- RAT exclusion ------------------------------------------------------

def test_skip_rat_excludes_pedal_mask_bit():
    ov = FakeOverlay()
    ap = EncoderEffectApplier(ov, skip_rat=True)
    state = AppState()
    state.dist_model_idx = RAT_PEDAL_INDEX
    ap.apply_appstate(state, force=True)
    kw = _kwargs_of(ov, "set_guitar_effects")
    assert kw is not None
    assert kw.get("distortion_pedal_mask") == 0
    assert kw.get("rat_on") is False
    assert "Distortion:rat" in ap.unsupported


def test_include_rat_sets_bit_2():
    ov = FakeOverlay()
    ap = EncoderEffectApplier(ov, skip_rat=False)
    state = AppState()
    state.dist_model_idx = RAT_PEDAL_INDEX
    ap.apply_appstate(state, force=True)
    kw = _kwargs_of(ov, "set_guitar_effects")
    assert kw is not None
    assert kw.get("distortion_pedal_mask") == (1 << RAT_PEDAL_INDEX)
    # rat_on is still False here -- live apply uses pedal mask only.
    assert kw.get("rat_on") is False


def test_is_rat_pedal_index_helper():
    assert is_rat_pedal_index(2) is True
    assert is_rat_pedal_index(0) is False
    assert is_rat_pedal_index("nope") is False


# ---- effect on/off ------------------------------------------------------

def test_effect_on_off_uses_dedicated_setters():
    ov = FakeOverlay()
    ap = EncoderEffectApplier(ov)
    assert ap.apply_effect_on_off("Noise Sup", True) is True
    assert _kwargs_of(ov, "set_noise_suppressor_settings") == {"enabled": True}
    ov.calls.clear()
    assert ap.apply_effect_on_off("Compressor", False) is True
    assert _kwargs_of(ov, "set_compressor_settings") == {"enabled": False}
    ov.calls.clear()
    assert ap.apply_effect_on_off("Amp Sim", True) is True
    assert _kwargs_of(ov, "set_guitar_effects") == {"amp_on": True}


def test_effect_on_off_unsupported_records_label():
    ov = FakeOverlay()
    ap = EncoderEffectApplier(ov)
    ok = ap.apply_effect_on_off("Made Up Effect", True)
    assert ok is False
    assert "Made Up Effect" in ap.unsupported
    assert ap.last_apply_ok is False


# ---- safe bypass --------------------------------------------------------

def test_safe_bypass_clears_pedals_and_disables_all():
    ov = FakeOverlay()
    ap = EncoderEffectApplier(ov)
    assert ap.apply_safe_bypass() is True
    methods = [name for name, _ in ov.calls]
    assert "clear_distortion_pedals" in methods
    assert "set_noise_suppressor_settings" in methods
    assert "set_compressor_settings" in methods
    gkw = _kwargs_of(ov, "set_guitar_effects")
    assert gkw is not None
    for flag in ("noise_gate_on", "overdrive_on", "distortion_on",
                 "rat_on", "amp_on", "cab_on", "eq_on", "reverb_on"):
        assert gkw[flag] is False


# ---- exception handling -------------------------------------------------

class ExplodingOverlay(FakeOverlay):
    def set_guitar_effects(self, **kwargs):
        raise RuntimeError("axi locked")


def test_apply_exception_does_not_propagate():
    ov = ExplodingOverlay()
    ap = EncoderEffectApplier(ov)
    state = AppState()
    ran = ap.apply_appstate(state, force=True)
    assert ran is True  # ran but errored
    assert ap.last_apply_ok is False
    assert "err" in ap.last_apply_message.lower()
    assert ap.error_count == 1


_TEST_FUNCTIONS = [
    test_dry_run_does_not_call_overlay,
    test_apply_appstate_calls_three_overlay_methods,
    test_throttle_blocks_back_to_back_calls,
    test_force_bypasses_throttle,
    test_skip_rat_excludes_pedal_mask_bit,
    test_include_rat_sets_bit_2,
    test_is_rat_pedal_index_helper,
    test_effect_on_off_uses_dedicated_setters,
    test_effect_on_off_unsupported_records_label,
    test_safe_bypass_clears_pedals_and_disables_all,
    test_apply_exception_does_not_propagate,
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
