#!/usr/bin/env python3
"""Canonical measurement input signals (realism work order step 2).

Deterministic, level-recorded test inputs so every realism retune candidate is
A/B'd against the SAME stimulus -- the work order's rule "input level が記録され、
音が大きいだけの候補を良い音と誤認しない". Every generator returns a 24-bit mono
int64 array (FS24 full-scale convention, identical to run_sim/measure), feedable
straight into ``run_sim.run_dsp``.

Two canonical drive levels (peak as fraction of full-scale):
  - LINEAR  = 0.05  small-signal magnitude probe (Cab / tone-stack / filter
              shape): low enough to stay out of the clip stages.
  - DRIVE   = 0.20  harmonic / clipping probe (OD / Distortion / Amp transfer
              curve): a realistic guitar-into-ADC peak (~0.1-0.2), NOT 0.85
              which just brick-walls the clip stages.

Generators (all deterministic, no RNG):
  sine          1k / 100 / 5k single tone   -> harmonics, transfer curve, alias
  log_sweep     exponential chirp           -> Cab / tone-stack magnitude
  two_tone      f1 + f2 equal amplitude     -> intermodulation / non-harmonic
  impulse       single full click           -> reverb tail, cab ring, density
  decaying_sine plucked-note envelope       -> comp release, NS close

Palm-mute phrase and DI guitar phrase are NOT synthesised here (they can't be
faithfully faked); use ``run_sim.py --wav-in <file>`` with a fixed recorded WAV
and note its name + level as the regression anchor.

  python3 tools/dsp_sim/signals.py --dump            # write all canonical WAVs
  python3 tools/dsp_sim/signals.py --list            # print the fixed catalogue
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run_sim  # noqa: E402  (FS24 / write_wav reuse, no pynq runtime needed)

FS24 = run_sim.FS24
FS_DEFAULT = 96000           # D98 sample rate
LINEAR = 0.05                # small-signal magnitude probe
DRIVE = 0.20                 # harmonic / clipping probe


def _q24(x, level):
    """Normalise float waveform to ``level`` peak and quantise to 24-bit int64."""
    peak = np.max(np.abs(x))
    if peak > 0:
        x = x / peak * level
    return np.round(x * FS24).astype(np.int64)


def sine(fs, f, seconds, level):
    n = int(fs * seconds)
    t = np.arange(n) / fs
    return _q24(np.sin(2 * np.pi * f * t), level)


def log_sweep(fs, f0, f1, seconds, level):
    """Exponential (constant-octave-rate) chirp f0 -> f1."""
    n = int(fs * seconds)
    t = np.arange(n) / fs
    k = (f1 / f0) ** (1.0 / seconds)
    phase = 2 * np.pi * f0 * (k ** t - 1.0) / np.log(k)
    return _q24(np.sin(phase), level)


def two_tone(fs, f1, f2, seconds, level):
    """Equal-amplitude two-tone for intermodulation products."""
    n = int(fs * seconds)
    t = np.arange(n) / fs
    return _q24(np.sin(2 * np.pi * f1 * t) + np.sin(2 * np.pi * f2 * t), level)


def impulse(fs, seconds, level, at=0.05):
    """Single full-scale click at ``at`` seconds; rest silence."""
    n = int(fs * seconds)
    x = np.zeros(n, dtype=np.int64)
    x[int(at * fs)] = int(round(level * FS24))
    return x


def decaying_sine(fs, f, seconds, tau, level):
    """Plucked-note envelope: 3 ms attack, exponential decay (tau seconds)."""
    n = int(fs * seconds)
    t = np.arange(n) / fs
    atk = np.minimum(1.0, t / 0.003)
    env = atk * np.exp(-t / tau)
    return _q24(np.sin(2 * np.pi * f * t) * env, level)


# Fixed canonical catalogue: name -> (callable, recorded level, note).
# These are the step-2 regression anchors. Changing a param here is a
# measurement-condition change and must be recorded.
def catalogue(fs=FS_DEFAULT):
    return {
        "sine_1k":       (sine(fs, 1000, 0.25, DRIVE),               DRIVE,  "harmonic / transfer curve / clipping"),
        "sine_100":      (sine(fs, 100, 0.25, DRIVE),                DRIVE,  "low-freq tightness / bass clipping"),
        "sine_5k":       (sine(fs, 5000, 0.25, DRIVE),               DRIVE,  "alias / fizz / HF harshness"),
        "sweep_lin":     (log_sweep(fs, 20, 20000, 2.0, LINEAR),     LINEAR, "Cab / tone-stack / filter magnitude (linear)"),
        "two_tone":      (two_tone(fs, 1000, 1100, 0.5, DRIVE),      DRIVE,  "intermodulation / non-harmonic products"),
        "impulse":       (impulse(fs, 0.5, 0.50),                    0.50,   "reverb tail / cab ring / echo density"),
        "decay_220":     (decaying_sine(fs, 220, 1.5, 0.30, DRIVE),  DRIVE,  "comp release / NS close behaviour"),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--fs", type=int, default=FS_DEFAULT)
    ap.add_argument("--out-dir", default="/tmp/dsp_sim_signals")
    ap.add_argument("--dump", action="store_true", help="write all canonical WAVs")
    ap.add_argument("--list", action="store_true", help="print the fixed catalogue")
    args = ap.parse_args()

    cat = catalogue(args.fs)
    if args.list or not args.dump:
        print("canonical inputs (fs=%d):" % args.fs)
        for name, (x, lvl, note) in cat.items():
            print("  %-12s level=%.2f  n=%-7d %s" % (name, lvl, len(x), note))
        print("\npalm_mute / di_phrase: external WAV via run_sim.py --wav-in (record name+level)")
        if not args.dump:
            return
    os.makedirs(args.out_dir, exist_ok=True)
    for name, (x, lvl, _note) in cat.items():
        path = os.path.join(args.out_dir, name + ".wav")
        run_sim.write_wav(path, x, args.fs)
        print("  wrote %s (level=%.2f)" % (path, lvl))


if __name__ == "__main__":
    main()
