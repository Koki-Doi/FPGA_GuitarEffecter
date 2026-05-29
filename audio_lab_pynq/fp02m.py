"""ZOOM FP02M expression pedal -> Wah POSITION support (DECISIONS.md D74).

Reads the FP02M wiper voltage from the PYNQ-Z2 Arduino **A0** analog input
and maps it to the Wah POSITION raw byte (0..255) consumed by
``axi_gpio_wah.ctrlA`` through ``set_wah_settings(position_raw=...)``.

A0 is a Zynq XADC **VAUX1** channel routed through the PL. The currently
deployed overlay has **no XADC IP**, so ``Fp02mA0Reader.available()``
returns ``False`` and callers fall back to SOURCE=MANUAL. Once the XADC
Wizard is built (see ``docs/ai_context/XADC_INTEGRATION_DESIGN.md``) the
same reader auto-discovers the VAUX1 IIO channel and starts returning
values -- no code change needed.

Layers:

- :class:`Fp02mCalibration` -- raw_min / raw_max / invert / deadband /
  smoothing_alpha (+ JSON load/save, validation).
- :class:`Fp02mA0Reader` -- XADC-IIO backend (``/sys/bus/iio``).
- :class:`MockFp02mReader` -- deterministic test reader.
- :class:`Fp02mPositionMapper` -- raw -> u8 with invert + clamp + EMA.
- :class:`Fp02mWahController` -- reader + mapper + deadband + safe
  error fallback; ``poll_once()`` emits a new byte only when it moved.

Kept Python-3.6-safe (no dataclasses, no PEP604 unions): the PYNQ-Z2
board runs CPython 3.6.
"""

import glob
import json
import os
import re
import time
from typing import List, Optional

# A0 (0..3.3 V) is divided down to the XADC 0..1 V unipolar range on the
# PYNQ-Z2 analog front end; voltage reporting multiplies the XADC volts
# back up. Calibration works in raw counts, so this only affects the
# informational ``read_voltage``.
A0_INPUT_DIVIDER = 3.3

# AXI register offsets in the xadc_wiz (v3.3) memory map. The XADC status
# registers mirror the DRP space at AXI base + 0x200; each channel is one
# 16-bit value in the top 12 bits (>> 4 for the 12-bit code).
XADC_REG_TEMP = 0x200
XADC_REG_VCCINT = 0x204
XADC_REG_VAUX1 = 0x244   # Arduino A0 = VAUX1 (DRP 0x11)
# Plausible VCCINT 12-bit band (~0.78..1.27 V on the 0..1 V * 3 internal
# scale) used to confirm the PL XADC core is actually converting.
_XADC_VCCINT_MIN = 600
_XADC_VCCINT_MAX = 1700

# IIO channels whose mid-token names one of these is an internal PS-XADC
# rail, NOT the external A0 (VAUX1) channel. Used to recognise that the
# current overlay exposes no external analog input.
_XADC_INTERNAL_TOKENS = (
    "vccint", "vccaux", "vccbram", "vccpint", "vccpaux",
    "vccoddr", "vccddr", "vrefp", "vrefn", "temp",
)

_IIO_VOLTAGE_RE = re.compile(r"^in_voltage(\d+)_(?:(.+)_)?raw$")

DEFAULT_CALIBRATION_PATH = os.path.expanduser(
    "~/.config/audio_lab/fp02m_calibration.json")

# Reject a calibration whose heel..toe span is narrower than this many raw
# counts -- it is almost certainly a mis-wired pedal or a stuck input, and
# mapping it would amplify noise into zipper artefacts.
MIN_CALIBRATION_SPAN = 16


def _clamp(value, lo, hi):
    return lo if value < lo else (hi if value > hi else value)


def _clamp_u8(value):
    try:
        v = int(round(float(value)))
    except (TypeError, ValueError):
        return 0
    return _clamp(v, 0, 255)


class Fp02mCalibration(object):
    """Heel/toe raw range + smoothing/deadband for the FP02M wiper.

    ``raw_min`` / ``raw_max`` are stored ordered (min <= max); ``invert``
    records whether the heel position read *higher* than the toe so the
    mapper flips the output. A calibration with too narrow a span is
    treated as invalid (``is_valid()`` is False) and the runtime refuses
    to map it -- no silent fake range.
    """

    def __init__(self, raw_min, raw_max, invert=False, deadband=1,
                 smoothing_alpha=0.25, read_path="iio", created_at=None,
                 notes=""):
        lo = int(raw_min)
        hi = int(raw_max)
        if hi < lo:
            lo, hi = hi, lo
        self.raw_min = lo
        self.raw_max = hi
        self.invert = bool(invert)
        self.deadband = max(0, int(deadband))
        try:
            a = float(smoothing_alpha)
        except (TypeError, ValueError):
            a = 0.25
        self.smoothing_alpha = _clamp(a, 0.0, 1.0)
        self.read_path = str(read_path)
        self.created_at = created_at
        self.notes = str(notes or "")

    @property
    def span(self):
        return self.raw_max - self.raw_min

    def is_valid(self, min_span=MIN_CALIBRATION_SPAN):
        return self.span >= int(min_span)

    def to_dict(self):
        return {
            "raw_min": self.raw_min,
            "raw_max": self.raw_max,
            "invert": self.invert,
            "deadband": self.deadband,
            "smoothing_alpha": self.smoothing_alpha,
            "created_at": self.created_at,
            "read_path": self.read_path,
            "notes": self.notes,
        }

    @classmethod
    def from_dict(cls, data):
        return cls(
            raw_min=data.get("raw_min", 0),
            raw_max=data.get("raw_max", 0),
            invert=data.get("invert", False),
            deadband=data.get("deadband", 1),
            smoothing_alpha=data.get("smoothing_alpha", 0.25),
            read_path=data.get("read_path", "iio"),
            created_at=data.get("created_at"),
            notes=data.get("notes", ""),
        )

    def save(self, path=DEFAULT_CALIBRATION_PATH):
        if self.created_at is None:
            self.created_at = time.strftime("%Y-%m-%dT%H:%M:%S")
        d = os.path.dirname(os.path.abspath(path))
        if d and not os.path.isdir(d):
            os.makedirs(d)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(self.to_dict(), f, ensure_ascii=False, indent=2)
        return path

    @classmethod
    def load(cls, path=DEFAULT_CALIBRATION_PATH):
        """Return a calibration from JSON, or None if missing / unreadable."""
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            return cls.from_dict(data)
        except (OSError, IOError, ValueError):
            return None

    def __repr__(self):
        return ("Fp02mCalibration(raw_min=%d, raw_max=%d, invert=%r, "
                "deadband=%d, smoothing_alpha=%.3f)" % (
                    self.raw_min, self.raw_max, self.invert,
                    self.deadband, self.smoothing_alpha))


class Fp02mReaderBase(object):
    """Common interface; subclasses override ``available`` / ``read_raw``."""

    read_path = "none"

    def available(self):
        return False

    def read_raw(self):
        raise NotImplementedError

    def read_voltage(self):
        return None


class Fp02mA0Reader(Fp02mReaderBase):
    """Read Arduino A0 (VAUX1) via the Linux IIO ``xadc`` driver.

    Discovery: find the ``xadc`` IIO device and, among its
    ``in_voltage*_raw`` channels, pick the one that is the **external A0**
    channel (filename token ``vaux1`` preferred, else any non-internal
    aux / VP-VN channel). The deployed overlay exposes only internal
    rails, so no external channel is found and ``available()`` is False.
    """

    read_path = "iio"

    def __init__(self, iio_root="/sys/bus/iio/devices", channel_path=None,
                 prefer_token="vaux1"):
        self.iio_root = iio_root
        self.prefer_token = prefer_token
        self._channel_path = channel_path
        self._scale_path = None
        if self._channel_path is None:
            self._discover()
        elif os.path.exists(self._channel_path):
            self._scale_path = self._channel_path.replace("_raw", "_scale")

    def _xadc_device_dirs(self):
        dirs = []
        for dev in sorted(glob.glob(os.path.join(self.iio_root, "iio:device*"))):
            name_path = os.path.join(dev, "name")
            try:
                with open(name_path) as f:
                    name = f.read().strip()
            except (OSError, IOError):
                continue
            if name == "xadc":
                dirs.append(dev)
        return dirs

    @staticmethod
    def _is_external_channel(token):
        """True when an ``in_voltageN_<token>_raw`` channel is the external
        analog input rather than an internal PS rail.
        ``token`` is None for a bare ``in_voltageN_raw`` (VP/VN)."""
        if token is None:
            return True  # dedicated VP/VN analog input
        token = token.lower()
        if token.startswith("vaux"):
            return True
        return token not in _XADC_INTERNAL_TOKENS

    def _discover(self):
        for dev in self._xadc_device_dirs():
            candidates = []  # (priority, raw_path)
            for raw_path in sorted(glob.glob(os.path.join(dev, "in_voltage*_raw"))):
                base = os.path.basename(raw_path)
                m = _IIO_VOLTAGE_RE.match(base)
                if not m:
                    continue
                token = m.group(2)
                if not self._is_external_channel(token):
                    continue
                tok = (token or "").lower()
                prio = 0 if tok == self.prefer_token else (1 if tok.startswith("vaux") else 2)
                candidates.append((prio, raw_path))
            if candidates:
                candidates.sort(key=lambda c: c[0])
                self._channel_path = candidates[0][1]
                self._scale_path = self._channel_path.replace("_raw", "_scale")
                return
        self._channel_path = None
        self._scale_path = None

    @property
    def channel_path(self):
        return self._channel_path

    def available(self):
        return (self._channel_path is not None
                and os.path.exists(self._channel_path))

    def read_raw(self):
        with open(self._channel_path) as f:
            return int(f.read().strip())

    def read_voltage(self):
        if not self.available():
            return None
        raw = self.read_raw()
        scale_mv = None
        if self._scale_path and os.path.exists(self._scale_path):
            try:
                with open(self._scale_path) as f:
                    scale_mv = float(f.read().strip())
            except (OSError, IOError, ValueError):
                scale_mv = None
        if scale_mv is None:
            return None
        xadc_volts = raw * scale_mv / 1000.0
        return xadc_volts * A0_INPUT_DIVIDER


class Fp02mXadcMmioReader(Fp02mReaderBase):
    """Read Arduino A0 (VAUX1) from the PL ``xadc_wiz_a0`` via AXI MMIO.

    This is the path that actually works on the AudioLab overlay: the PL
    XADC Wizard is a separate access path from the PS-XADC that backs the
    Linux IIO ``xadc`` device, and it is NOT exposed as an IIO channel, so
    :class:`Fp02mA0Reader` (IIO) stays unavailable for VAUX1. The wizard's
    AXI status registers are read directly instead (D74).

    ``reg_source`` is any object with a ``read(offset)`` method returning
    the 16-bit register value -- typically ``overlay.xadc_wiz_a0`` (a PYNQ
    ``DefaultIP``) or a ``pynq.MMIO``. ``available()`` confirms the core is
    converting by sanity-checking the on-chip VCCINT register, so a stale
    or unprogrammed PL reads as unavailable rather than feeding garbage to
    the Wah.
    """

    read_path = "xadc-mmio"

    def __init__(self, reg_source, vaux_offset=XADC_REG_VAUX1):
        self.reg_source = reg_source
        self.vaux_offset = vaux_offset

    @classmethod
    def from_overlay(cls, overlay, ip_name="xadc_wiz_a0",
                     vaux_offset=XADC_REG_VAUX1):
        """Build a reader from a loaded overlay, or an unavailable reader
        (reg_source=None) if the overlay has no XADC Wizard."""
        reg = getattr(overlay, ip_name, None) if overlay is not None else None
        return cls(reg, vaux_offset=vaux_offset)

    def _read_reg(self, offset):
        return int(self.reg_source.read(offset)) & 0xFFFF

    def available(self):
        if self.reg_source is None or not hasattr(self.reg_source, "read"):
            return False
        try:
            vccint = self._read_reg(XADC_REG_VCCINT) >> 4
        except Exception:
            return False
        return _XADC_VCCINT_MIN <= vccint <= _XADC_VCCINT_MAX

    def read_raw(self):
        # 12-bit code in the top 12 bits of the 16-bit status word.
        return (self._read_reg(self.vaux_offset) >> 4) & 0x0FFF

    def read_voltage(self):
        try:
            raw = self.read_raw()
        except Exception:
            return None
        return (raw / 4096.0) * A0_INPUT_DIVIDER


class MockFp02mReader(Fp02mReaderBase):
    """Deterministic test reader.

    - ``values``: sequence of raw ints, returned in order (last value
      repeats after the sequence is exhausted).
    - ``stuck``: if set, always returns this value (overrides ``values``).
    - ``raise_after``: after this many successful reads, ``read_raw``
      raises -- to exercise the controller's error fallback.
    - ``available``: what ``available()`` reports.
    """

    read_path = "mock"

    def __init__(self, values=None, stuck=None, raise_after=None,
                 available=True):
        self._values = list(values) if values is not None else []
        self._stuck = stuck
        self._raise_after = raise_after
        self._available = bool(available)
        self._i = 0
        self._reads = 0

    def available(self):
        return self._available

    def set_available(self, value):
        self._available = bool(value)

    def read_raw(self):
        if self._raise_after is not None and self._reads >= self._raise_after:
            self._reads += 1
            raise IOError("mock A0 read failure")
        self._reads += 1
        if self._stuck is not None:
            return int(self._stuck)
        if not self._values:
            return 0
        if self._i < len(self._values):
            v = self._values[self._i]
            self._i += 1
        else:
            v = self._values[-1]
        return int(v)


class Fp02mPositionMapper(object):
    """Map a calibrated raw reading to a Wah POSITION byte (0..255).

    ``raw_to_u8`` is stateless; ``update_smoothed`` applies an
    exponential moving average in the output (u8) domain so the result is
    independent of the ADC bit width. Invert and clamp are honoured in
    both. The deadband decision lives in :class:`Fp02mWahController`.
    """

    def __init__(self, calibration):
        self.calibration = calibration
        self._smoothed = None  # float in 0..255

    def raw_to_u8(self, raw):
        cal = self.calibration
        span = cal.span
        if span <= 0:
            return 0
        try:
            r = float(raw)
        except (TypeError, ValueError):
            return 0
        r = _clamp(r, cal.raw_min, cal.raw_max)
        frac = (r - cal.raw_min) / float(span)
        if cal.invert:
            frac = 1.0 - frac
        return _clamp_u8(round(frac * 255.0))

    def update_smoothed(self, raw):
        target = self.raw_to_u8(raw)
        alpha = self.calibration.smoothing_alpha
        if self._smoothed is None or alpha >= 1.0:
            self._smoothed = float(target)
        else:
            self._smoothed += alpha * (target - self._smoothed)
        return _clamp_u8(round(self._smoothed))

    def reset(self):
        self._smoothed = None


class Fp02mWahController(object):
    """Tie a reader + calibration into a pollable Wah POSITION source.

    ``poll_once()`` returns a new POSITION byte (0..255) only when it
    moved past the deadband since the last emit, else ``None`` (so the
    caller does not issue a redundant GPIO write). Repeated read errors
    flip ``available`` to False and set ``fell_back`` so the GUI can drop
    back to SOURCE=MANUAL. A calibration that is missing or too narrow
    keeps the controller unavailable from the start.
    """

    def __init__(self, reader, calibration, deadband=None,
                 error_fallback_count=5, min_span=MIN_CALIBRATION_SPAN):
        self.reader = reader
        self.calibration = calibration
        self.mapper = Fp02mPositionMapper(calibration) if calibration else None
        if deadband is not None:
            self.deadband = max(1, int(deadband))
        elif calibration is not None:
            self.deadband = max(1, int(calibration.deadband))
        else:
            self.deadband = 1
        self.error_fallback_count = max(1, int(error_fallback_count))
        self._last_u8 = None
        self._err_streak = 0
        self.fell_back = False
        self.last_error = None
        cal_ok = bool(calibration is not None and calibration.is_valid(min_span))
        self.available = bool(reader is not None
                              and reader.available() and cal_ok)
        self.unavailable_reason = self._initial_reason(reader, calibration, cal_ok)

    @staticmethod
    def _initial_reason(reader, calibration, cal_ok):
        if reader is None or not reader.available():
            return "A0 read path unavailable (no XADC channel)"
        if calibration is None:
            return "no calibration (run scripts/calibrate_fp02m.py)"
        if not cal_ok:
            return "calibration span too narrow (re-calibrate)"
        return ""

    @property
    def last_u8(self):
        return self._last_u8

    def display_pct(self):
        if self._last_u8 is None:
            return None
        return round(self._last_u8 * 100.0 / 255.0, 1)

    def poll_once(self):
        if not self.available or self.mapper is None:
            return None
        try:
            raw = self.reader.read_raw()
            self._err_streak = 0
        except Exception as exc:  # broad: a flaky ADC must not crash the GUI
            self._err_streak += 1
            self.last_error = repr(exc)
            if self._err_streak >= self.error_fallback_count:
                self.available = False
                self.fell_back = True
                self.unavailable_reason = "repeated A0 read errors"
            return None
        u8 = self.mapper.update_smoothed(raw)
        if (self._last_u8 is None
                or abs(u8 - self._last_u8) >= self.deadband):
            self._last_u8 = u8
            return u8
        return None


def load_calibration(path=DEFAULT_CALIBRATION_PATH):
    """Convenience: return an Fp02mCalibration from JSON or None."""
    return Fp02mCalibration.load(path)


__all__ = [
    "A0_INPUT_DIVIDER",
    "DEFAULT_CALIBRATION_PATH",
    "MIN_CALIBRATION_SPAN",
    "Fp02mCalibration",
    "Fp02mReaderBase",
    "Fp02mA0Reader",
    "Fp02mXadcMmioReader",
    "XADC_REG_VAUX1",
    "MockFp02mReader",
    "Fp02mPositionMapper",
    "Fp02mWahController",
    "load_calibration",
]
