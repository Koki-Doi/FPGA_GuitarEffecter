#!/usr/bin/env python3
"""Calibrate the FP02M pedal heel/toe range and save JSON (D74).

Samples the Arduino A0 raw value at the heel and toe positions, derives
raw_min / raw_max / invert, and writes a calibration JSON consumed by
scripts/run_fp02m_wah_test.py and the GUI runner's pedal loop.

Usage on the PYNQ-Z2 (after wiring + XADC Wizard build):

    python3 scripts/calibrate_fp02m.py \
        --output ~/.config/audio_lab/fp02m_calibration.json

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
    """Load fp02m.py standalone (no pynq dependency) so calibration runs
    even where the audio_lab_pynq package import chain is unavailable."""
    path = os.path.join(_REPO, "audio_lab_pynq", "fp02m.py")
    spec = importlib.util.spec_from_file_location("fp02m_standalone", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_fp = _load_fp02m()
Fp02mA0Reader = _fp.Fp02mA0Reader
Fp02mCalibration = _fp.Fp02mCalibration
DEFAULT_CALIBRATION_PATH = _fp.DEFAULT_CALIBRATION_PATH
MIN_CALIBRATION_SPAN = _fp.MIN_CALIBRATION_SPAN


def _build_argparser():
    p = argparse.ArgumentParser(description="Calibrate the FP02M heel/toe range.")
    p.add_argument("--output", default=DEFAULT_CALIBRATION_PATH,
                   help="Calibration JSON output path.")
    p.add_argument("--samples", type=int, default=200,
                   help="Samples averaged per position (default 200).")
    p.add_argument("--rate", type=float, default=100.0,
                   help="Sample rate in Hz (default 100).")
    p.add_argument("--deadband", type=int, default=1)
    p.add_argument("--smoothing-alpha", type=float, default=0.25)
    p.add_argument("--notes", default="",
                   help="Free text (e.g. measured TRS pinout).")
    p.add_argument("--iio-root", default="/sys/bus/iio/devices")
    return p


def _sample_mean(reader, n, rate):
    period = 1.0 / max(1.0, float(rate))
    vals = []
    for _ in range(max(1, n)):
        t0 = time.time()
        try:
            vals.append(reader.read_raw())
        except Exception as exc:
            print("read error during sampling: %r" % (exc,))
        elapsed = time.time() - t0
        if elapsed < period:
            time.sleep(period - elapsed)
    if not vals:
        return None
    return int(round(sum(vals) / float(len(vals))))


def main(argv=None):
    args = _build_argparser().parse_args(argv)
    reader = Fp02mA0Reader(iio_root=args.iio_root)
    if not reader.available():
        print("A0 read path UNAVAILABLE -- cannot calibrate.")
        print("The deployed overlay has no XADC channel for A0 (VAUX1).")
        print("Build the XADC Wizard first (XADC_INTEGRATION_DESIGN.md).")
        return 2

    print("FP02M calibration. Read path: %s (%s)"
          % (reader.read_path, reader.channel_path))
    try:
        input("Set the pedal to the HEEL position, then press Enter...")
    except EOFError:
        print("no interactive stdin; aborting.")
        return 2
    heel = _sample_mean(reader, args.samples, args.rate)
    print("heel raw ~= %s" % heel)

    input("Set the pedal to the TOE position, then press Enter...")
    toe = _sample_mean(reader, args.samples, args.rate)
    print("toe raw ~= %s" % toe)

    if heel is None or toe is None:
        print("ERROR: failed to sample one of the positions.")
        return 1

    raw_min = min(heel, toe)
    raw_max = max(heel, toe)
    invert = heel > toe  # heel reads higher -> flip so heel maps to 0
    cal = Fp02mCalibration(
        raw_min=raw_min, raw_max=raw_max, invert=invert,
        deadband=args.deadband, smoothing_alpha=args.smoothing_alpha,
        read_path=reader.read_path, notes=args.notes)

    print("---")
    print("raw_min=%d raw_max=%d span=%d invert=%s"
          % (cal.raw_min, cal.raw_max, cal.span, cal.invert))
    if not cal.is_valid():
        print("ERROR: heel/toe span (%d) is below the minimum (%d). The pedal "
              "did not move enough, or the wiring is wrong. NOT saving."
              % (cal.span, MIN_CALIBRATION_SPAN))
        return 1

    path = cal.save(args.output)
    print("saved calibration -> %s" % path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
