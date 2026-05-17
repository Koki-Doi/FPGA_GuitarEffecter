"""Offline tests for audio_lab_pynq.encoder_input.

No pynq install needed -- the tests build a fake MMIO with a dict-backed
register file. The audio_lab_pynq package __init__ does pull in pynq via
AxisSwitch, so we register the standard test-suite stub first.
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import _pynq_mock  # noqa: E402
_pynq_mock.install()


from audio_lab_pynq.encoder_input import (  # noqa: E402
    EncoderInput, EncoderEvent, EXPECTED_VERSION, CONFIG_DEFAULT,
    REG_STATUS, REG_DELTA_PACKED, REG_COUNT0, REG_COUNT1, REG_COUNT2,
    REG_BUTTON_STATE, REG_CONFIG, REG_CLEAR_EVENTS, REG_VERSION,
    decode_status, unpack_delta, _s8, _s32, EDGES_PER_DETENT,
)


class FakeMmio(object):
    """Minimal dict-backed MMIO for offline testing."""

    def __init__(self, regs=None):
        self.regs = dict(regs or {})
        self.writes = []
        # Default reads for unset registers
        self.regs.setdefault(REG_STATUS, 0)
        self.regs.setdefault(REG_DELTA_PACKED, 0)
        self.regs.setdefault(REG_COUNT0, 0)
        self.regs.setdefault(REG_COUNT1, 0)
        self.regs.setdefault(REG_COUNT2, 0)
        self.regs.setdefault(REG_BUTTON_STATE, 0)
        self.regs.setdefault(REG_CONFIG, CONFIG_DEFAULT)
        self.regs.setdefault(REG_VERSION, EXPECTED_VERSION)

    def read(self, offset):
        return self.regs.get(offset, 0)

    def write(self, offset, value):
        self.writes.append((offset, value))
        if offset == REG_CONFIG:
            self.regs[REG_CONFIG] = value & 0xFFFFFFFF


# ---- helpers ---------------------------------------------------------------

def test_s8_sign_extend():
    assert _s8(0x00) == 0
    assert _s8(0x7F) == 127
    assert _s8(0x80) == -128
    assert _s8(0xFF) == -1
    assert _s8(0xFE) == -2


def test_s32_sign_extend():
    assert _s32(0x00000000) == 0
    assert _s32(0x7FFFFFFF) == 2147483647
    assert _s32(0x80000000) == -2147483648
    assert _s32(0xFFFFFFFF) == -1


def test_unpack_delta_basic():
    # enc0=+4, enc1=-1, enc2=+8 -> packed = 0x000800FF04 -> low 24 bits
    packed = (0x04) | ((0xFF) << 8) | ((0x08) << 16)
    assert unpack_delta(packed) == (4, -1, 8)


def test_decode_status_bits():
    status = (
        (1 << 0)   |  # enc0 rotate
        (1 << 2)   |  # enc2 rotate
        (1 << 9)   |  # enc1 short
        (1 << 18)  |  # enc2 long
        (1 << 24)  |  # enc0 sw_level
        (1 << 26)     # enc2 sw_level
    )
    d = decode_status(status)
    assert d["rotate_event"] == [1, 0, 1]
    assert d["short_press"]  == [0, 1, 0]
    assert d["long_press"]   == [0, 0, 1]
    assert d["sw_level"]     == [1, 0, 1]


# ---- driver --------------------------------------------------------------

def test_construct_requires_real_mmio():
    bad = object()
    try:
        EncoderInput(bad)
    except RuntimeError as exc:
        assert "mmio" in str(exc).lower()
    else:
        raise AssertionError("expected RuntimeError for non-MMIO arg")


def test_version_and_config_reads():
    mm = FakeMmio()
    enc = EncoderInput(mm)
    assert enc.read_version() == EXPECTED_VERSION
    assert enc.read_config() == CONFIG_DEFAULT


def test_from_overlay_discovers_module_ref_bus_interface_name():
    class FakeOverlay(object):
        enc_in_0 = object()  # PYNQ exposes the module as a non-MMIO hierarchy.
        ip_dict = {
            "enc_in_0/s_axi": {
                "phys_addr": 0x43D10000,
                "addr_range": 0x10000,
            }
        }

    enc = EncoderInput.from_overlay(FakeOverlay())
    assert isinstance(enc, EncoderInput)


def test_configure_round_trip():
    mm = FakeMmio()
    enc = EncoderInput(mm)
    new = enc.configure(debounce_ms=10, clear_on_read=False,
                        reverse_direction=(True, False, True),
                        clk_dt_swap=(False, True, False))
    # Check bits
    assert (new & 0xFF) == 10
    assert (new & (1 << 8)) == 0
    assert (new >> 10) & 0x7 == 0b101  # rev: enc0+enc2
    assert (new >> 13) & 0x7 == 0b010  # swap: enc1


def test_clear_events_write_word():
    mm = FakeMmio()
    enc = EncoderInput(mm)
    enc.clear_events(rotate=(0, 1), short_press=(2,), long_press=())
    # Last write to CLEAR_EVENTS
    offsets = [o for o, _ in mm.writes if o == REG_CLEAR_EVENTS]
    assert offsets, "expected CLEAR_EVENTS write"
    last = [v for o, v in mm.writes if o == REG_CLEAR_EVENTS][-1]
    expected = (1 << 0) | (1 << 1) | (1 << (8 + 2))
    assert last == expected


def test_poll_rotate_detents():
    """A raw delta of 4 edges (= 1 detent) should emit one rotate event."""
    mm = FakeMmio({
        REG_DELTA_PACKED: 0x04,  # enc0 = +4 edges = +1 detent
        REG_STATUS: 1,           # enc0 rotate_event
    })
    enc = EncoderInput(mm)
    events = enc.poll()
    rotates = [e for e in events if e.kind == "rotate"]
    assert len(rotates) == 1
    assert rotates[0].encoder_id == 0
    assert rotates[0].delta == 1
    assert rotates[0].raw_delta == 4


def test_poll_partial_delta_carry():
    """Two consecutive polls of 2 edges should add up to one detent emission."""
    mm = FakeMmio({REG_DELTA_PACKED: 0x02, REG_STATUS: 1})
    enc = EncoderInput(mm)
    evs1 = enc.poll()
    rotates1 = [e for e in evs1 if e.kind == "rotate"]
    assert rotates1 == []  # only 2 of 4 edges
    # Next poll: another +2 edges. Carry was 2, total 4 -> 1 detent.
    mm.regs[REG_DELTA_PACKED] = 0x02
    mm.regs[REG_STATUS] = 1
    evs2 = enc.poll()
    rotates2 = [e for e in evs2 if e.kind == "rotate"]
    assert len(rotates2) == 1
    assert rotates2[0].delta == 1


def test_poll_short_long_press_emit():
    mm = FakeMmio({
        REG_STATUS: (1 << 8) | (1 << 17),  # enc0 short, enc1 long
    })
    enc = EncoderInput(mm)
    events = enc.poll()
    shorts = [e for e in events if e.kind == "short_press"]
    longs  = [e for e in events if e.kind == "long_press"]
    assert len(shorts) == 1 and shorts[0].encoder_id == 0
    assert len(longs)  == 1 and longs[0].encoder_id == 1


def test_poll_synthetic_release_edge():
    mm = FakeMmio()
    enc = EncoderInput(mm)
    # First poll with SW level high (= pressed)
    mm.regs[REG_STATUS] = (1 << 24)  # enc0 sw_level
    enc.poll()
    # Next poll: SW level low (released)
    mm.regs[REG_STATUS] = 0
    events = enc.poll()
    releases = [e for e in events if e.kind == "release"]
    assert len(releases) == 1
    assert releases[0].encoder_id == 0


_TEST_FUNCTIONS = [
    test_s8_sign_extend,
    test_s32_sign_extend,
    test_unpack_delta_basic,
    test_decode_status_bits,
    test_construct_requires_real_mmio,
    test_version_and_config_reads,
    test_from_overlay_discovers_module_ref_bus_interface_name,
    test_configure_round_trip,
    test_clear_events_write_word,
    test_poll_rotate_detents,
    test_poll_partial_delta_carry,
    test_poll_short_long_press_emit,
    test_poll_synthetic_release_edge,
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
