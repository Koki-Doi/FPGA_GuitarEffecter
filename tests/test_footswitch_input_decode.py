"""Offline tests for audio_lab_pynq.footswitch_input (no pynq required)."""

import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import _pynq_mock  # noqa: E402
_pynq_mock.install()

from audio_lab_pynq.footswitch_input import (  # noqa: E402
    FootswitchInput, FootswitchEvent, decode_status,
    REG_STATUS, REG_CONFIG, REG_CLEAR_EVENTS, REG_VERSION,
    CONFIG_DEFAULT, EXPECTED_VERSION,
    CH_FX_TOGGLE, CH_PRESET_NEXT, CH_PRESET_PREV,
)


class FakeMMIO(object):
    """Minimal MMIO: a register dict with read/write + a STATUS feeder."""

    def __init__(self):
        self.regs = {
            REG_STATUS: 0,
            REG_CONFIG: CONFIG_DEFAULT,
            REG_VERSION: EXPECTED_VERSION,
        }
        self.writes = []

    def read(self, offset):
        return int(self.regs.get(int(offset), 0))

    def write(self, offset, value):
        self.writes.append((int(offset), int(value)))
        self.regs[int(offset)] = int(value)


class DecodeTests(unittest.TestCase):
    def test_decode_status_press_and_level(self):
        # press_event bits[2:0], level bits[10:8]
        status = (0b101) | (0b110 << 8)
        d = decode_status(status)
        self.assertEqual(d["press_event"], [1, 0, 1])
        self.assertEqual(d["level"], [0, 1, 1])

    def test_channel_constants(self):
        self.assertEqual((CH_FX_TOGGLE, CH_PRESET_NEXT, CH_PRESET_PREV), (0, 1, 2))


class DriverTests(unittest.TestCase):
    def setUp(self):
        self.mmio = FakeMMIO()
        self.fsw = FootswitchInput(self.mmio)

    def test_requires_mmio(self):
        with self.assertRaises(RuntimeError):
            FootswitchInput(None)
        with self.assertRaises(RuntimeError):
            FootswitchInput(object())

    def test_version_and_levels(self):
        self.assertEqual(self.fsw.read_version(), EXPECTED_VERSION)
        self.mmio.regs[REG_STATUS] = (0b011 << 8)  # levels only
        self.assertEqual(self.fsw.read_levels(), (1, 1, 0))

    def test_poll_emits_press_per_latched_channel(self):
        self.mmio.regs[REG_STATUS] = 0b101  # ch0 + ch2 latched
        events = self.fsw.poll(timestamp=1.5)
        chans = sorted(e.channel for e in events)
        self.assertEqual(chans, [0, 2])
        self.assertTrue(all(isinstance(e, FootswitchEvent) for e in events))
        self.assertTrue(all(e.kind == "press" for e in events))
        self.assertEqual(events[0].timestamp, 1.5)

    def test_poll_no_events_when_idle(self):
        self.mmio.regs[REG_STATUS] = 0
        self.assertEqual(self.fsw.poll(), [])

    def test_clear_events_word(self):
        self.fsw.clear_events()
        off, word = self.mmio.writes[-1]
        self.assertEqual(off, REG_CLEAR_EVENTS)
        self.assertEqual(word, 0b111)
        self.fsw.clear_events(channels=(1,))
        off, word = self.mmio.writes[-1]
        self.assertEqual(word, 0b010)

    def test_configure_roundtrip(self):
        cfg = self.fsw.configure(debounce_ms=20, clear_on_read=False)
        self.assertEqual(cfg & 0xFF, 20)
        self.assertEqual((cfg >> 8) & 1, 0)
        # re-enable clear-on-read, keep debounce
        cfg2 = self.fsw.configure(clear_on_read=True)
        self.assertEqual(cfg2 & 0xFF, 20)
        self.assertEqual((cfg2 >> 8) & 1, 1)

    def test_from_overlay_clears_on_attach(self):
        class _Ovl(object):
            def __init__(self, mmio):
                self.fsw_in_0 = type("IP", (), {"mmio": mmio})()
        ovl = _Ovl(self.mmio)
        FootswitchInput.from_overlay(ovl)
        # last write should be a CLEAR_EVENTS flush
        off, word = self.mmio.writes[-1]
        self.assertEqual(off, REG_CLEAR_EVENTS)
        self.assertEqual(word, 0b111)


if __name__ == "__main__":
    unittest.main()
