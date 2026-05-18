"""Offline tests for the D46 Overdrive model select.

Covers:
- ``OVERDRIVE_MODELS`` enum order matches the documented model select.
- ``OVERDRIVE_DEFAULTS`` carries the new ``model`` key, default = 0 (TS9).
- ``guitar_effect_control_words(overdrive_model=...)`` packs the model
  into ``overdrive_word.ctrlD[2:0]`` without disturbing ``distTight``
  bits[7:3].
- Invalid model values clamp to 0 (TS9).
- ``set_overdrive_model`` / ``set_overdrive_settings`` round-trip through
  the cached state.
- ``_merge_cached_distortion_state`` preserves a cached OD model across a
  partial ``set_guitar_effects`` call.
- ``AppState.overdrive_model_idx`` persists through save / load JSON.
- ``EncoderUiController`` cycles the new ``overdrive_model_idx`` field.
"""

import json
import os
import sys
import tempfile
import types
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(REPO_ROOT / "GUI"))
sys.path.insert(0, str(Path(__file__).resolve().parent))


# pynq mock so AudioLabOverlay imports off-board.
pynq = types.ModuleType("pynq")


class _Overlay(object):
    pass


class _DefaultIP(object):
    bindto = []

    def __init__(self, description=None):
        self.description = description or {}

    def read(self, _offset):
        return 0

    def write(self, _offset, _value):
        pass


pynq.Overlay = _Overlay
pynq.DefaultIP = _DefaultIP
sys.modules.setdefault("pynq", pynq)

pylibi2c = types.ModuleType("pylibi2c")


class _I2CDevice(object):
    def __init__(self, *_a, **_k):
        pass

    def ioctl_read(self, _o, length):
        return bytes([0] * length)

    def ioctl_write(self, _o, _d):
        pass


pylibi2c.I2CDevice = _I2CDevice
sys.modules.setdefault("pylibi2c", pylibi2c)


from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay
from audio_lab_pynq.effect_defaults import (
    OVERDRIVE_DEFAULTS,
    OVERDRIVE_MODELS,
    OVERDRIVE_MODEL_LABELS,
)


class FakeGpio(object):
    def __init__(self):
        self.writes = []

    def write(self, offset, value):
        self.writes.append((offset, value))


def make_overlay():
    overlay = AudioLabOverlay.__new__(AudioLabOverlay)
    overlay.axi_gpio_gate = FakeGpio()
    overlay.axi_gpio_overdrive = FakeGpio()
    overlay.axi_gpio_distortion = FakeGpio()
    overlay.axi_gpio_eq = FakeGpio()
    overlay.axi_gpio_reverb = FakeGpio()
    overlay.axi_gpio_delay = FakeGpio()
    overlay.axi_gpio_amp = FakeGpio()
    overlay.axi_gpio_amp_tone = FakeGpio()
    overlay.axi_gpio_cab = FakeGpio()
    overlay._dist_state = dict(AudioLabOverlay.DISTORTION_DEFAULTS)
    overlay._od_state = dict(AudioLabOverlay.OVERDRIVE_DEFAULTS)
    overlay._cached_gate_word = 0
    overlay._cached_overdrive_word = 0
    overlay._cached_distortion_word = 0
    overlay.routes = []

    def _route(_src, effect, sink):
        overlay.routes.append((effect, sink))

    overlay.route = _route
    return overlay


# ---- enum / defaults ---------------------------------------------------


def test_overdrive_models_order_matches_doc():
    expected = ("ts9", "od1", "bd2", "jan_ray", "ocd", "centaur")
    assert tuple(OVERDRIVE_MODELS) == expected
    assert len(OVERDRIVE_MODEL_LABELS) == len(expected)
    assert AudioLabOverlay.OVERDRIVE_MODEL_COUNT == 6


def test_overdrive_model_labels_are_inspired_by():
    # Spot-check that the user-facing labels match what the GUI / docs
    # expect. The labels are inspired-by, not commercial copies.
    assert OVERDRIVE_MODEL_LABELS[0] == "Ibanez / TS9"
    assert OVERDRIVE_MODEL_LABELS[1] == "BOSS / OD-1"
    assert OVERDRIVE_MODEL_LABELS[2] == "BOSS / BD-2"
    assert OVERDRIVE_MODEL_LABELS[3] == "Vemuram / Jan Ray"
    assert OVERDRIVE_MODEL_LABELS[4] == "Fulltone / OCD"
    assert OVERDRIVE_MODEL_LABELS[5] == "CENTAUR"


def test_overdrive_defaults_include_model_key():
    assert "model" in OVERDRIVE_DEFAULTS
    assert OVERDRIVE_DEFAULTS["model"] == 0


# ---- word packing ------------------------------------------------------


def test_overdrive_model_lands_in_ctrlD_low_3_bits():
    for model_idx in range(6):
        words = AudioLabOverlay.guitar_effect_control_words(
            overdrive_on=True,
            overdrive_drive=30,
            overdrive_tone=50,
            overdrive_level=100,
            overdrive_model=model_idx,
            distortion_tight=50,  # tight=50 -> 128 (0x80), low 3 bits = 0
        )
        ctrlD = (words["overdrive"] >> 24) & 0xFF
        assert ctrlD & 0x07 == model_idx, (model_idx, hex(ctrlD))
        # tight=50 maps to 128 (0x80), masked to top 5 bits = 0x80.
        assert ctrlD & 0xF8 == 0x80, hex(ctrlD)


def test_overdrive_model_does_not_corrupt_tight_at_high_tight():
    # tight=100 -> _percent_to_u8(100, 255) = 255 (0xFF). With the new
    # mask, the byte becomes 0xF8; the Clash distTight consumer's
    # `>> 3` shift sees 0x1F (31) in both old and new layouts, so the
    # musical result is unchanged.
    for model_idx in range(6):
        words = AudioLabOverlay.guitar_effect_control_words(
            distortion_tight=100,
            overdrive_model=model_idx,
        )
        ctrlD = (words["overdrive"] >> 24) & 0xFF
        assert ctrlD & 0xF8 == 0xF8, hex(ctrlD)
        assert ctrlD & 0x07 == model_idx
        assert ctrlD >> 3 == 0x1F


def test_overdrive_model_invalid_falls_back_to_ts9():
    # 6 and 7 are documented reserved values; 8 is over-range; the
    # writer clamps them all to 0 (TS9). The Clash side independently
    # falls through to model 0 in the case lookup.
    for bad in (6, 7, 8, 12, 255, -1):
        words = AudioLabOverlay.guitar_effect_control_words(
            overdrive_model=bad)
        ctrlD = (words["overdrive"] >> 24) & 0xFF
        assert ctrlD & 0x07 == 0, (bad, hex(ctrlD))


def test_normalize_overdrive_model_accepts_strings():
    assert AudioLabOverlay._normalize_overdrive_model("ts9") == 0
    assert AudioLabOverlay._normalize_overdrive_model("OD1") == 1
    assert AudioLabOverlay._normalize_overdrive_model("jan_ray") == 3
    assert AudioLabOverlay._normalize_overdrive_model("jan-ray") == 3
    assert AudioLabOverlay._normalize_overdrive_model("centaur") == 5
    # Display labels are accepted too.
    assert AudioLabOverlay._normalize_overdrive_model("Ibanez / TS9") == 0
    assert AudioLabOverlay._normalize_overdrive_model("Fulltone / OCD") == 4
    # Unknown strings fall through to ValueError or 0 depending on
    # whether the int parser also rejects them. Integers in the range
    # 0..5 are accepted as-is.
    for value in range(6):
        assert AudioLabOverlay._normalize_overdrive_model(value) == value


# ---- public API --------------------------------------------------------


def test_set_overdrive_model_updates_cache_and_writes_gpio():
    overlay = make_overlay()
    overlay.set_overdrive_model(3)
    state = overlay.get_overdrive_settings()
    assert state["model_idx"] == 3
    assert state["model"] == "jan_ray"
    assert state["model_label"] == "Vemuram / Jan Ray"
    last_od = overlay.axi_gpio_overdrive.writes[-1][1]
    assert (last_od >> 24) & 0x07 == 3


def test_set_overdrive_settings_preserves_other_effects():
    # set_overdrive_settings must NOT route through the gate / amp /
    # cab / etc. flag bytes (that would silently turn other sections
    # off). Only the overdrive word -- and, when ``enabled`` is
    # supplied, the gate flag bit 1 -- should move.
    overlay = make_overlay()
    overlay.set_guitar_effects(amp_on=True, cab_on=True)
    gate_before = overlay._cached_gate_word
    overlay.set_overdrive_settings(model=4, drive=80, tone=40)
    # gate word's amp / cab bits intact because set_overdrive_settings
    # was called without ``enabled``.
    assert overlay._cached_gate_word == gate_before
    od_after = overlay._cached_overdrive_word
    assert (od_after >> 24) & 0x07 == 4
    assert (od_after >> 16) & 0xFF == AudioLabOverlay._percent_to_u8(80, 255)
    assert od_after & 0xFF == AudioLabOverlay._percent_to_u8(40, 255)


def test_set_overdrive_settings_enabled_flips_gate_bit_1():
    overlay = make_overlay()
    overlay.set_overdrive_settings(enabled=True)
    assert overlay._cached_gate_word & 0x02
    overlay.set_overdrive_settings(enabled=False)
    assert overlay._cached_gate_word & 0x02 == 0


def test_merge_cached_distortion_state_preserves_od_model():
    # Set the OD model, then call set_guitar_effects without an
    # ``overdrive_model`` kwarg. The cache must keep the previously
    # selected model.
    overlay = make_overlay()
    overlay.set_overdrive_model(2)
    overlay.set_guitar_effects(overdrive_on=True, overdrive_drive=50)
    od = overlay._cached_overdrive_word
    assert (od >> 24) & 0x07 == 2


def test_set_guitar_effects_with_overdrive_model_overrides_cache():
    overlay = make_overlay()
    overlay.set_overdrive_model(1)
    overlay.set_guitar_effects(overdrive_on=True, overdrive_model=4)
    od = overlay._cached_overdrive_word
    assert (od >> 24) & 0x07 == 4
    # And the cache reflects the new value.
    assert overlay._od_state["model"] == 4


def test_distortion_tight_write_does_not_clobber_od_model():
    overlay = make_overlay()
    overlay.set_overdrive_model(5)
    overlay.set_distortion_settings(tight=70)
    od = overlay._cached_overdrive_word
    assert (od >> 24) & 0x07 == 5
    # tight byte (top 5 bits) reflects the new tight=70.
    assert (od >> 24) & 0xF8 == AudioLabOverlay._percent_to_u8(70, 255) & 0xF8


# ---- AppState persistence ---------------------------------------------


def test_appstate_overdrive_model_idx_persists_through_save_load():
    # Imported locally so the GUI / compact_v2 sys.path additions take
    # effect after our REPO_ROOT prepend.
    from compact_v2.state import AppState, save_state_json, load_state_json
    state = AppState()
    assert state.overdrive_model_idx == 0
    state.overdrive_model_idx = 4
    with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False) as fp:
        path = fp.name
    try:
        save_state_json(state, path)
        loaded = load_state_json(path)
        assert loaded.overdrive_model_idx == 4
    finally:
        os.remove(path)


# ---- Encoder cycling ---------------------------------------------------


def test_encoder_overdrive_model_cycle_uses_dedicated_index():
    """Encoder 2 rotate while OVERDRIVE is selected and model_select_mode
    is on must cycle ``overdrive_model_idx``, NOT ``dist_model_idx``."""
    from compact_v2.state import AppState
    from audio_lab_pynq.encoder_ui import EncoderUiController

    state = AppState()
    state.selected_effect = 2          # Overdrive
    state.model_select_mode = True

    initial_dist = state.dist_model_idx
    initial_od = state.overdrive_model_idx

    controller = EncoderUiController(state)

    class _Ev(object):
        def __init__(self, eid, kind, delta=0):
            self.encoder_id = eid
            self.kind = kind
            self.delta = delta

    controller.handle_event(_Ev(1, "rotate", 1))
    assert state.overdrive_model_idx == (initial_od + 1) % 6
    assert state.dist_model_idx == initial_dist  # unchanged

    controller.handle_event(_Ev(1, "rotate", 5))  # back around
    assert state.overdrive_model_idx == initial_od
    assert state.dist_model_idx == initial_dist


# ---- test runner --------------------------------------------------------


_TEST_FUNCTIONS = [
    test_overdrive_models_order_matches_doc,
    test_overdrive_model_labels_are_inspired_by,
    test_overdrive_defaults_include_model_key,
    test_overdrive_model_lands_in_ctrlD_low_3_bits,
    test_overdrive_model_does_not_corrupt_tight_at_high_tight,
    test_overdrive_model_invalid_falls_back_to_ts9,
    test_normalize_overdrive_model_accepts_strings,
    test_set_overdrive_model_updates_cache_and_writes_gpio,
    test_set_overdrive_settings_preserves_other_effects,
    test_set_overdrive_settings_enabled_flips_gate_bit_1,
    test_merge_cached_distortion_state_preserves_od_model,
    test_set_guitar_effects_with_overdrive_model_overrides_cache,
    test_distortion_tight_write_does_not_clobber_od_model,
    test_appstate_overdrive_model_idx_persists_through_save_load,
    test_encoder_overdrive_model_cycle_uses_dedicated_index,
]


class TestOverdriveModelSelect(unittest.TestCase):
    pass


for _fn in _TEST_FUNCTIONS:
    def _make(fn):
        def runner(self):
            fn()
        runner.__name__ = "test_" + fn.__name__
        return runner
    setattr(TestOverdriveModelSelect, _fn.__name__, _make(_fn))


if __name__ == "__main__":
    unittest.main()
