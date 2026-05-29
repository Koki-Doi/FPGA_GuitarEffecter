#!/usr/bin/env python3
"""Probe the PYNQ-Z2 Arduino A0 analog input for the FP02M pedal (D74).

Confirms whether A0 (= Zynq XADC VAUX1) is readable from Python on the
currently loaded overlay, and -- if it is -- streams raw / voltage /
position_u8 so you can verify the FP02M moves the value heel..toe.

On the deployed AudioLab overlay there is no XADC IP, so the read path is
reported as ``unavailable`` and the script exits cleanly (it never
crashes). It becomes useful once the XADC Wizard is built (see
docs/ai_context/XADC_INTEGRATION_DESIGN.md).

Usage on the PYNQ-Z2:

    python3 scripts/probe_fp02m_a0.py --duration 10 --rate 100

PYNQ Python 3.6 compatible (no f-strings).
"""

import argparse
import os
import sys
import time

import importlib.util

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.abspath(os.path.join(_HERE, os.pardir))
if _REPO not in sys.path:
    sys.path.insert(0, _REPO)


def _load_fp02m():
    """Load audio_lab_pynq/fp02m.py standalone so this probe runs even
    where the pynq package (imported by audio_lab_pynq/__init__.py) is
    absent -- fp02m itself has no pynq dependency."""
    path = os.path.join(_REPO, "audio_lab_pynq", "fp02m.py")
    spec = importlib.util.spec_from_file_location("fp02m_standalone", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_fp = _load_fp02m()
Fp02mA0Reader = _fp.Fp02mA0Reader
Fp02mCalibration = _fp.Fp02mCalibration
Fp02mPositionMapper = _fp.Fp02mPositionMapper


def _build_argparser():
    p = argparse.ArgumentParser(description="Probe Arduino A0 for the FP02M pedal.")
    p.add_argument("--duration", type=float, default=10.0,
                   help="Seconds to stream (default 10).")
    p.add_argument("--rate", type=float, default=100.0,
                   help="Read rate in Hz (default 100).")
    p.add_argument("--iio-root", default="/sys/bus/iio/devices",
                   help="IIO devices root (override for testing).")
    p.add_argument("--quiet", action="store_true",
                   help="Only print the summary, not every sample.")
    return p


def main(argv=None):
    args = _build_argparser().parse_args(argv)
    reader = Fp02mA0Reader(iio_root=args.iio_root)

    print("A0 read path: %s" % reader.read_path)
    if not reader.available():
        print("A0 read path: UNAVAILABLE")
        print("  No external XADC (VAUX1) channel is exposed on this overlay.")
        print("  The deployed AudioLab overlay has no XADC IP; add the XADC")
        print("  Wizard (docs/ai_context/XADC_INTEGRATION_DESIGN.md) to read A0.")
        return 2

    print("A0 channel: %s" % reader.channel_path)
    period = 1.0 / max(1.0, float(args.rate))
    # Provisional full-range mapper just so we can print a position_u8;
    # NOT a calibration. raw range is observed, not assumed.
    mapper = Fp02mPositionMapper(Fp02mCalibration(0, 4095, smoothing_alpha=1.0))

    raw_min_seen = None
    raw_max_seen = None
    samples = 0
    last_raw = None
    stuck_count = 0
    t_end = time.time() + max(0.1, float(args.duration))
    try:
        while time.time() < t_end:
            t0 = time.time()
            try:
                raw = reader.read_raw()
            except Exception as exc:  # broad: probe must not crash
                print("read error: %r" % (exc,))
                time.sleep(period)
                continue
            volts = None
            try:
                volts = reader.read_voltage()
            except Exception:
                volts = None
            samples += 1
            raw_min_seen = raw if raw_min_seen is None else min(raw_min_seen, raw)
            raw_max_seen = raw if raw_max_seen is None else max(raw_max_seen, raw)
            if last_raw is not None and raw == last_raw:
                stuck_count += 1
            last_raw = raw
            pos = mapper.raw_to_u8(raw)
            if not args.quiet:
                vtxt = ("%.3fV" % volts) if volts is not None else "n/a"
                print("raw=%-6d voltage=%-7s position_u8=%-3d" % (raw, vtxt, pos))
            elapsed = time.time() - t0
            if elapsed < period:
                time.sleep(period - elapsed)
    except KeyboardInterrupt:
        print("\n(interrupted)")

    print("---")
    print("samples=%d" % samples)
    print("raw_min_seen=%s" % raw_min_seen)
    print("raw_max_seen=%s" % raw_max_seen)
    span = (raw_max_seen - raw_min_seen) if (raw_min_seen is not None
                                             and raw_max_seen is not None) else 0
    print("raw_span=%d" % span)
    # Anomaly hints (non-fatal):
    if samples == 0:
        print("WARN: no samples read.")
    elif stuck_count >= max(1, samples - 1):
        print("WARN: value appears STUCK (did not change). Check wiring / pedal.")
    elif span < 16:
        print("WARN: raw span very narrow (<16). Sweep the pedal heel..toe; "
              "if it stays narrow the wiper / range may be mis-wired.")
    else:
        print("OK: A0 moved over a usable range. Run scripts/calibrate_fp02m.py "
              "to capture heel/toe.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
