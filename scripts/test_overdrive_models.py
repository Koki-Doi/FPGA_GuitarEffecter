#!/usr/bin/env python3
"""Cycle every Overdrive model on the deployed PYNQ-Z2 bitstream.

Loads the AudioLab overlay, enables the Overdrive section, and walks
through the six selectable models (TS9 -> OD-1 -> BD-2 -> Jan Ray ->
OCD -> CENTAUR) with a fixed DRIVE / TONE / LEVEL setting. Between
models the script pauses ``--duration-per-model`` seconds so the user
can audibly A/B the voicings on the PCM5102 line out (or the ADAU1761
mirror) while playing the guitar.

Typical use on board:

    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
        python3 scripts/test_overdrive_models.py --duration-per-model 5

Off-board, the script can still be syntax-checked
(``python3 -m py_compile scripts/test_overdrive_models.py``).

PYNQ Python 3.6 compatibility: no dataclasses, no
``from __future__ import annotations``, no ``typing.Literal``.
"""

import argparse
import sys
import time


def _parse_args():
    parser = argparse.ArgumentParser(
        description="Cycle every Overdrive model on the deployed bitstream "
                    "so the user can audibly compare TS9 / OD-1 / BD-2 / "
                    "Jan Ray / OCD / CENTAUR")
    parser.add_argument("--duration-per-model", type=float, default=5.0,
                        help="seconds to dwell on each model")
    parser.add_argument("--drive", type=int, default=55,
                        help="DRIVE percent (0..100)")
    parser.add_argument("--tone", type=int, default=60,
                        help="TONE percent (0..100)")
    parser.add_argument("--level", type=int, default=80,
                        help="LEVEL percent (0..200; 100 is unity)")
    parser.add_argument("--start-model", type=int, default=0,
                        help="first model to play (0..5)")
    parser.add_argument("--repeat", type=int, default=1,
                        help="number of full cycles through every model")
    parser.add_argument("--no-amp", action="store_true",
                        help="leave amp / cab off (overdrive only)")
    return parser.parse_args()


def main():
    args = _parse_args()
    try:
        from audio_lab_pynq import AudioLabOverlay
    except ImportError as exc:
        print("[overdrive-models] failed to import AudioLabOverlay: %s" % exc)
        return 1

    overlay = AudioLabOverlay()
    print("[overdrive-models] overlay loaded; ADC HPF=%s" %
          getattr(overlay, "adc_hpf_enabled", None))

    try:
        models = AudioLabOverlay.get_overdrive_model_names()
        labels = AudioLabOverlay.get_overdrive_model_labels()
    except AttributeError:
        print("[overdrive-models] AudioLabOverlay missing OD-model helpers; "
              "the deployed bit/hwh predates D46.")
        return 2

    # Sanity defaults: keep distortion section off; amp/cab on so the
    # user can hear the OD into a real-ish chain. The flag byte for
    # noise_gate_on / etc is preserved by set_guitar_effects' cached
    # state merge.
    amp_on = not args.no_amp
    cab_on = not args.no_amp

    start = max(0, min(len(models) - 1, args.start_model))
    order = [(start + i) % len(models) for i in range(len(models))]

    try:
        for cycle in range(max(1, args.repeat)):
            for idx in order:
                name = models[idx]
                label = labels[idx]
                print("[overdrive-models] cycle %d/%d  model[%d] = %s  (%s)" %
                      (cycle + 1, args.repeat, idx, name, label))
                overlay.set_guitar_effects(
                    overdrive_on=True,
                    overdrive_drive=args.drive,
                    overdrive_tone=args.tone,
                    overdrive_level=args.level,
                    overdrive_model=idx,
                    distortion_on=False,
                    rat_on=False,
                    amp_on=amp_on,
                    cab_on=cab_on,
                    eq_on=False,
                    reverb_on=False,
                )
                print("    waiting %.1fs ..." % args.duration_per_model)
                time.sleep(max(0.0, args.duration_per_model))
        print("[overdrive-models] done. Returning OD to TS9 (model 0).")
        overlay.set_overdrive_model(0)
        return 0
    except KeyboardInterrupt:
        print("[overdrive-models] interrupted; restoring OD model 0.")
        try:
            overlay.set_overdrive_model(0)
        except Exception:
            pass
        return 130


if __name__ == "__main__":
    sys.exit(main())
