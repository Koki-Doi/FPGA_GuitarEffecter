#!/usr/bin/env python3
"""Drive Wah POSITION from the FP02M pedal as a standalone bench test (D74).

Loads AudioLabOverlay, enables the Wah with fixed Q / VOLUME / BIAS, then
streams the FP02M A0 reading into ``set_wah_settings(position_raw=...)`` at
the configured rate. Use it to confirm a smooth pedal sweep with no zipper
noise before wiring the pedal into the full encoder GUI.

This is the standalone counterpart to the GUI runner's pedal loop
(scripts/run_encoder_hdmi_gui.py --wah-pedal). It does NOT touch HDMI or
the encoder.

Usage on the PYNQ-Z2 (after wiring + XADC Wizard build + calibration):

    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
        scripts/run_fp02m_wah_test.py \
        --calibration ~/.config/audio_lab/fp02m_calibration.json

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
    path = os.path.join(_REPO, "audio_lab_pynq", "fp02m.py")
    spec = importlib.util.spec_from_file_location("fp02m_standalone", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_fp = _load_fp02m()
Fp02mA0Reader = _fp.Fp02mA0Reader
Fp02mCalibration = _fp.Fp02mCalibration
Fp02mWahController = _fp.Fp02mWahController
DEFAULT_CALIBRATION_PATH = _fp.DEFAULT_CALIBRATION_PATH


def _build_argparser():
    p = argparse.ArgumentParser(description="FP02M -> Wah POSITION bench test.")
    p.add_argument("--calibration", default=DEFAULT_CALIBRATION_PATH,
                   help="Calibration JSON (run scripts/calibrate_fp02m.py).")
    p.add_argument("--rate", type=float, default=100.0,
                   help="Pedal read / write rate in Hz (default 100).")
    p.add_argument("--duration", type=float, default=30.0,
                   help="Seconds to run (default 30).")
    p.add_argument("--q", type=float, default=60.0, help="Wah Q (0..100).")
    p.add_argument("--volume", type=float, default=50.0,
                   help="Wah VOLUME (0..100, 50 = unity).")
    p.add_argument("--bias", type=float, default=50.0,
                   help="Wah BIAS (0..100, 50 = centred).")
    p.add_argument("--no-download", action="store_true",
                   help="Attach to the already-loaded bit (download=False). "
                        "Use after the first download in a session.")
    p.add_argument("--iio-root", default="/sys/bus/iio/devices")
    return p


def main(argv=None):
    args = _build_argparser().parse_args(argv)

    cal = Fp02mCalibration.load(args.calibration)
    if cal is None:
        print("No calibration at %s. Run scripts/calibrate_fp02m.py first."
              % args.calibration)
        return 2
    reader = Fp02mA0Reader(iio_root=args.iio_root)
    ctrl = Fp02mWahController(reader, cal)
    if not ctrl.available:
        print("Pedal controller unavailable: %s" % ctrl.unavailable_reason)
        return 2

    from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay  # noqa: E402
    ovl = AudioLabOverlay(download=not args.no_download)
    # Fixed Q / VOLUME / BIAS; enable the Wah. POSITION comes from the pedal.
    ovl.set_wah_settings(enabled=True, q=args.q, volume=args.volume,
                         bias=args.bias, source="pedal")
    print("Wah enabled (Q=%.0f VOL=%.0f BIAS=%.0f). Sweep the pedal..."
          % (args.q, args.volume, args.bias))

    period = 1.0 / max(1.0, float(args.rate))
    writes = 0
    t_end = time.time() + max(0.1, float(args.duration))
    try:
        while time.time() < t_end:
            t0 = time.time()
            u8 = ctrl.poll_once()
            if u8 is not None:
                ovl.set_wah_settings(position_raw=u8)
                writes += 1
                print("position_raw=%-3d (%.0f%%)" % (u8, u8 * 100.0 / 255.0))
            if not ctrl.available:
                print("pedal fell back to unavailable: %s" % ctrl.unavailable_reason)
                break
            elapsed = time.time() - t0
            if elapsed < period:
                time.sleep(period - elapsed)
    except KeyboardInterrupt:
        print("\n(interrupted)")
    finally:
        # Leave the Wah enabled but mute risk is low; return to manual source.
        try:
            ovl.set_wah_settings(source="manual")
        except Exception:
            pass

    print("--- writes=%d ---" % writes)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
