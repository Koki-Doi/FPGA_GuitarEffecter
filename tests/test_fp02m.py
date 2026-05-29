"""Offline tests for audio_lab_pynq.fp02m (FP02M -> Wah POSITION, D74).

Hardware-free: the XADC-IIO reader is exercised against a fake sysfs tree
and a deterministic MockFp02mReader. No PYNQ board required.
"""

import os
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import _pynq_mock  # noqa: E402
_pynq_mock.install()

from audio_lab_pynq.fp02m import (  # noqa: E402
    Fp02mCalibration,
    Fp02mA0Reader,
    Fp02mXadcMmioReader,
    MockFp02mReader,
    Fp02mPositionMapper,
    Fp02mWahController,
    MIN_CALIBRATION_SPAN,
    XADC_REG_VAUX1,
    load_calibration,
)


class _FakeXadcRegs(object):
    """Minimal stand-in for overlay.xadc_wiz_a0 (.read(offset))."""

    def __init__(self, regs):
        self.regs = dict(regs)

    def read(self, offset):
        return self.regs.get(offset, 0)


class XadcMmioReaderTests(unittest.TestCase):
    def test_available_and_reads_vaux1(self):
        # 12-bit codes shifted into the top 12 bits of the 16-bit word.
        regs = {0x204: 1395 << 4, XADC_REG_VAUX1: 2048 << 4}
        r = Fp02mXadcMmioReader(_FakeXadcRegs(regs))
        self.assertTrue(r.available())
        self.assertEqual(r.read_raw(), 2048)
        v = r.read_voltage()
        self.assertTrue(1.5 < v < 1.8)  # ~half of 3.3 V

    def test_unavailable_when_vccint_out_of_band(self):
        r = Fp02mXadcMmioReader(_FakeXadcRegs({0x204: 0, XADC_REG_VAUX1: 100 << 4}))
        self.assertFalse(r.available())

    def test_unavailable_when_no_source(self):
        self.assertFalse(Fp02mXadcMmioReader(None).available())

    def test_from_overlay_missing_ip(self):
        class _Ovl(object):
            pass
        r = Fp02mXadcMmioReader.from_overlay(_Ovl())
        self.assertFalse(r.available())

    def test_controller_drives_from_mmio(self):
        regs = {0x204: 1395 << 4, XADC_REG_VAUX1: 4095 << 4}
        r = Fp02mXadcMmioReader(_FakeXadcRegs(regs))
        cal = Fp02mCalibration(0, 4095, smoothing_alpha=1.0)
        ctrl = Fp02mWahController(r, cal, deadband=1)
        self.assertTrue(ctrl.available)
        self.assertEqual(ctrl.poll_once(), 255)


class CalibrationTests(unittest.TestCase):
    def test_orders_min_max(self):
        cal = Fp02mCalibration(raw_min=3000, raw_max=200)
        self.assertEqual(cal.raw_min, 200)
        self.assertEqual(cal.raw_max, 3000)

    def test_validity_span(self):
        self.assertTrue(Fp02mCalibration(100, 100 + MIN_CALIBRATION_SPAN).is_valid())
        self.assertFalse(Fp02mCalibration(500, 500).is_valid())  # raw_min == raw_max
        self.assertFalse(Fp02mCalibration(500, 505).is_valid())  # too narrow

    def test_smoothing_alpha_clamped(self):
        self.assertEqual(Fp02mCalibration(0, 100, smoothing_alpha=5.0).smoothing_alpha, 1.0)
        self.assertEqual(Fp02mCalibration(0, 100, smoothing_alpha=-1.0).smoothing_alpha, 0.0)

    def test_json_round_trip(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "sub", "cal.json")
            cal = Fp02mCalibration(120, 3910, invert=True, deadband=2,
                                   smoothing_alpha=0.3, notes="tip=wiper")
            cal.save(path)
            self.assertTrue(os.path.exists(path))
            loaded = Fp02mCalibration.load(path)
            self.assertEqual(loaded.raw_min, 120)
            self.assertEqual(loaded.raw_max, 3910)
            self.assertTrue(loaded.invert)
            self.assertEqual(loaded.deadband, 2)
            self.assertAlmostEqual(loaded.smoothing_alpha, 0.3)
            self.assertEqual(loaded.notes, "tip=wiper")
            self.assertIsNotNone(loaded.created_at)

    def test_load_missing_returns_none(self):
        self.assertIsNone(load_calibration("/nonexistent/path/cal.json"))


class MapperTests(unittest.TestCase):
    def setUp(self):
        self.cal = Fp02mCalibration(raw_min=0, raw_max=4095, smoothing_alpha=1.0)

    def test_endpoints_and_clamp(self):
        m = Fp02mPositionMapper(self.cal)
        self.assertEqual(m.raw_to_u8(0), 0)
        self.assertEqual(m.raw_to_u8(4095), 255)
        self.assertEqual(m.raw_to_u8(-100), 0)     # below range clamps
        self.assertEqual(m.raw_to_u8(99999), 255)  # above range clamps
        self.assertEqual(m.raw_to_u8(2048), 128)   # midpoint

    def test_invert(self):
        cal = Fp02mCalibration(raw_min=0, raw_max=4095, invert=True,
                               smoothing_alpha=1.0)
        m = Fp02mPositionMapper(cal)
        self.assertEqual(m.raw_to_u8(0), 255)
        self.assertEqual(m.raw_to_u8(4095), 0)

    def test_zero_span_safe(self):
        m = Fp02mPositionMapper(Fp02mCalibration(500, 500))
        self.assertEqual(m.raw_to_u8(500), 0)  # no divide-by-zero

    def test_smoothing_lags_target(self):
        cal = Fp02mCalibration(raw_min=0, raw_max=255, smoothing_alpha=0.25)
        m = Fp02mPositionMapper(cal)
        first = m.update_smoothed(0)      # seeds at 0
        self.assertEqual(first, 0)
        stepped = m.update_smoothed(255)  # target 255, EMA 0.25 -> ~64
        self.assertTrue(0 < stepped < 255)
        # converges upward on repeated max reads
        for _ in range(50):
            stepped = m.update_smoothed(255)
        self.assertEqual(stepped, 255)


class IIOReaderTests(unittest.TestCase):
    def _make_xadc_tree(self, root, channels):
        dev = os.path.join(root, "iio:device0")
        os.makedirs(dev)
        with open(os.path.join(dev, "name"), "w") as f:
            f.write("xadc\n")
        for fname, raw in channels.items():
            with open(os.path.join(dev, fname), "w") as f:
                f.write(str(raw) + "\n")
        return dev

    def test_internal_rails_only_is_unavailable(self):
        """Mirrors the deployed overlay: only internal rails -> A0 unreadable."""
        with tempfile.TemporaryDirectory() as root:
            self._make_xadc_tree(root, {
                "in_voltage0_vccint_raw": 1394,
                "in_voltage1_vccaux_raw": 1700,
                "in_voltage6_vrefp_raw": 1365,
                "in_temp0_raw": 2500,
            })
            reader = Fp02mA0Reader(iio_root=root)
            self.assertFalse(reader.available())
            self.assertIsNone(reader.channel_path)

    def test_vaux1_channel_is_discovered(self):
        """After the XADC Wizard adds VAUX1, the reader picks it up."""
        with tempfile.TemporaryDirectory() as root:
            dev = self._make_xadc_tree(root, {
                "in_voltage0_vccint_raw": 1394,
                "in_voltage9_vaux1_raw": 2048,
            })
            with open(os.path.join(dev, "in_voltage9_vaux1_scale"), "w") as f:
                f.write("0.2442\n")
            reader = Fp02mA0Reader(iio_root=root)
            self.assertTrue(reader.available())
            self.assertEqual(reader.read_raw(), 2048)
            self.assertIsNotNone(reader.read_voltage())

    def test_no_xadc_device_is_unavailable(self):
        with tempfile.TemporaryDirectory() as root:
            reader = Fp02mA0Reader(iio_root=root)
            self.assertFalse(reader.available())


class ControllerTests(unittest.TestCase):
    def _cal(self, **kw):
        kw.setdefault("raw_min", 0)
        kw.setdefault("raw_max", 4095)
        kw.setdefault("smoothing_alpha", 1.0)  # no smoothing lag in tests
        return Fp02mCalibration(**kw)

    def test_sweep_0_to_255(self):
        reader = MockFp02mReader(values=[0, 1024, 2048, 3072, 4095])
        ctrl = Fp02mWahController(reader, self._cal(), deadband=1)
        self.assertTrue(ctrl.available)
        out = []
        for _ in range(5):
            v = ctrl.poll_once()
            if v is not None:
                out.append(v)
        self.assertEqual(out[0], 0)
        self.assertEqual(out[-1], 255)
        self.assertTrue(all(out[i] <= out[i + 1] for i in range(len(out) - 1)))

    def test_deadband_suppresses_small_moves(self):
        # raw steps of 1 count on a 4096 range -> sub-deadband u8 moves
        reader = MockFp02mReader(values=[2048, 2049, 2050, 2051])
        ctrl = Fp02mWahController(reader, self._cal(), deadband=4)
        emitted = [ctrl.poll_once() for _ in range(4)]
        # first emits (last is None), rest suppressed by deadband
        self.assertEqual(emitted[0], 128)
        self.assertTrue(all(e is None for e in emitted[1:]))

    def test_stuck_value_emits_once(self):
        reader = MockFp02mReader(stuck=1000)
        ctrl = Fp02mWahController(reader, self._cal(), deadband=1)
        first = ctrl.poll_once()
        self.assertIsNotNone(first)
        self.assertIsNone(ctrl.poll_once())  # no change -> no emit

    def test_read_exception_falls_back_to_unavailable(self):
        reader = MockFp02mReader(values=[2048], raise_after=0)
        ctrl = Fp02mWahController(reader, self._cal(), deadband=1,
                                  error_fallback_count=3)
        self.assertTrue(ctrl.available)
        for _ in range(3):
            self.assertIsNone(ctrl.poll_once())  # never crashes
        self.assertFalse(ctrl.available)
        self.assertTrue(ctrl.fell_back)
        # once unavailable, polling is a safe no-op
        self.assertIsNone(ctrl.poll_once())

    def test_unavailable_reader_keeps_controller_off(self):
        reader = MockFp02mReader(values=[2048], available=False)
        ctrl = Fp02mWahController(reader, self._cal())
        self.assertFalse(ctrl.available)
        self.assertIsNone(ctrl.poll_once())
        self.assertIn("unavailable", ctrl.unavailable_reason)

    def test_invalid_calibration_keeps_controller_off(self):
        reader = MockFp02mReader(values=[500])
        ctrl = Fp02mWahController(reader, Fp02mCalibration(500, 502))
        self.assertFalse(ctrl.available)
        self.assertIn("narrow", ctrl.unavailable_reason)

    def test_no_calibration_keeps_controller_off(self):
        reader = MockFp02mReader(values=[500])
        ctrl = Fp02mWahController(reader, None)
        self.assertFalse(ctrl.available)
        self.assertIsNone(ctrl.poll_once())

    def test_display_pct(self):
        reader = MockFp02mReader(stuck=4095)
        ctrl = Fp02mWahController(reader, self._cal(), deadband=1)
        ctrl.poll_once()
        self.assertEqual(ctrl.display_pct(), 100.0)


if __name__ == "__main__":
    unittest.main()
