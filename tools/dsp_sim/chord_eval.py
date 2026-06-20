#!/usr/bin/env python3
"""Chord / intermodulation (IMD) + alias measurement -- "和音で音程が変" detector.

Single-tone THD/harmonics tools cannot see the problem the user hears on CHORDS:
when several notes hit a nonlinear stage at once, the stage produces
**intermodulation products** (f_i +/- f_j, 2f_i - f_j, ...) and, because the amp
clip stages are NOT oversampled, **aliases** (harmonics above fs/2 folded back).
Both land on frequencies that are NOT harmonics of any played note, so the chord
sounds muddy / detuned / dissonant even when each single note measures clean.

This tool feeds a real multi-note chord through the DSP island and reports, per
amp model / mode / level:

  * INHARM dB  -- energy NOT within +/-tol of any harmonic of any chord note,
                 relative to the loudest played fundamental. This is the IMD +
                 alias "mud" floor. A clean amp should sit very low (<= -40 dB);
                 rising toward -20..-10 dB is audible detune/dissonance.
  * top spurious -- the 3 loudest inharmonic spectral peaks (Hz @ dB rel fund):
                 the actual frequencies muddying the chord.

Chords (low, so their harmonic series is dense -- the worst case for IMD/alias):
  power   = root + perfect 5th            (E2 + B2)         -- the "should be clean even dirty" case
  major   = root + major 3rd + 5th        (E2 + G#2 + B2)   -- the classic "distortion can't do major chords"
  full    = root + 5th + octave + maj3(oct) (E2 B2 E3 G#3)  -- a 4-note voicing

Usage:
  python3 tools/dsp_sim/chord_eval.py                 # all models, clean+drive, all chords
  python3 tools/dsp_sim/chord_eval.py --chord major   # one chord
  python3 tools/dsp_sim/chord_eval.py --amp 4 --drive 1 --level 0.15 --wav /tmp/c.wav  # dump a wav
  python3 tools/dsp_sim/chord_eval.py --check         # PASS/FAIL clean-chord IMD ceilings
  python3 tools/dsp_sim/chord_eval.py --check-only    # ceilings only; skip the exhaustive survey

It also measures the BYPASS chord (amp off) as the reference floor, so the number
reported is what the AMP adds on top of the test signal's own windowing leakage.
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run_sim  # noqa: E402

FS = 96000
FS24 = run_sim.FS24
SIM = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dsp_sim")

# Note frequencies (equal temperament, A4=440). Low voicings = dense harmonics.
E2, B2, GS2, E3, GS3 = 82.41, 123.47, 103.83, 164.81, 207.65
CHORDS = {
    "power": [E2, B2],
    "major": [E2, GS2, B2],
    "full":  [E2, B2, E3, GS3],
}
MODELS = [(0, "JC-120"), (1, "Twin"), (2, "AC30"), (3, "Rockerverb"),
          (4, "JCM800"), (5, "TriAmp")]
# Clean-chord IMD ceilings (dB inharmonic rel fundamental) for --check. A clean
# amp must keep a major chord clean; high-gain "clean" channels are allowed more.
CLEAN_IMD_CEIL = {0: -34, 1: -32, 2: -26, 3: -24, 4: -26, 5: -26}


def _chord_signal(freqs, seconds, level):
    n = int(FS * seconds)
    t = np.arange(n) / FS
    x = np.zeros(n)
    for f in freqs:
        x += np.sin(2 * np.pi * f * t)
    x /= len(freqs)
    peak = np.max(np.abs(x))
    if peak > 0:
        x = x / peak * level
    return np.round(x * FS24).astype(np.int64)


def _words(cm, idx, drive, ig=18, master=60):
    w = {
        "gate": cm.gate_word(amp_on=True),
        "od": cm.overdrive_word(65, 100, 30),
        "dist": cm.distortion_word(50, 35, 0, 0),
        "eq": cm.eq_word(100, 100, 100),
        "rat": cm.rat_word(35, 100, 0, 100),
        "amp": cm.amp_word(input_gain=ig, master=master, presence=45, resonance=35),
        "amp_tone": cm.amp_tone_word(50, 50, 50, amp_model_idx=idx, amp_drive_mode=drive),
        "cab": cm.cab_word(100, 100, 1, 50),
        "reverb": cm.reverb_word(0, 65, 0),
        "ns": cm.noise_suppressor_word(35, 40, 70),
        "comp": cm.compressor_word(45, 35, 45, 50, False),
        "wah": cm.wah_word(0, 50, 50, 50, False),
    }
    return [w[k] for k in ["gate", "od", "dist", "eq", "rat", "amp", "amp_tone",
                           "cab", "reverb", "ns", "comp", "wah"]]


def _bypass_words(cm):
    w = _words(cm, 0, 0)
    w0 = cm.gate_word()           # all effects off = bypass
    w[0] = w0
    return w


def analyse(y, freqs, n_harm=40, tol_hz=3.0):
    """Inharmonic energy (rel loudest fundamental) + top spurious peaks."""
    y = y.astype(np.float64)
    n = len(y)
    w = np.hanning(n)
    spec = np.abs(np.fft.rfft(y * w))
    df = FS / n
    tol = max(2, int(round(tol_hz / df)))
    total = float(np.sum(spec ** 2)) + 1e-9

    used = np.zeros(len(spec), dtype=bool)
    used[0:tol + 1] = True
    for f in freqs:
        for k in range(1, n_harm + 1):
            kk = int(round(k * f / df))
            if kk < len(spec):
                used[max(0, kk - tol):kk + tol + 1] = True
    inh_energy = total - (float(np.sum(spec[used] ** 2)) + 1e-9)
    fund = max(float(spec[int(round(freqs[0] / df))]), 1e-9)
    inh_db = 10 * np.log10(max(inh_energy, 1e-9) / FS24 ** 2) - 20 * np.log10(fund / FS24)

    # top inharmonic peaks
    masked = spec.copy()
    masked[used] = 0.0
    peaks = []
    for _ in range(3):
        k = int(np.argmax(masked))
        if masked[k] <= 0:
            break
        peaks.append((k * df, 20 * np.log10(masked[k] / fund + 1e-12)))
        masked[max(0, k - tol):k + tol + 1] = 0.0
    return inh_db, peaks


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--chord", choices=list(CHORDS), default=None)
    ap.add_argument("--amp", type=int, default=None)
    ap.add_argument("--drive", type=int, default=None)
    ap.add_argument("--level", type=float, default=None)
    ap.add_argument("--wav", default=None, help="dump the chord output WAV (needs --amp)")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--check-only", action="store_true",
                    help="run only the clean major-chord ceiling checks")
    args = ap.parse_args()
    if not os.path.exists(SIM):
        sys.exit("build the sim first: tools/dsp_sim/build_sim.sh")
    cm = run_sim.load_control_maps()

    if args.wav is not None and args.amp is not None:
        ch = CHORDS[args.chord or "major"]
        x = _chord_signal(ch, 0.6, args.level or 0.15)
        y = run_sim.run_dsp(SIM, _words(cm, args.amp, args.drive or 0), x, gap=8)
        run_sim.write_wav(args.wav, y, FS)
        idb, pk = analyse(y, ch)
        print("wrote %s  inharm %+.1f dB  spurious %s" %
              (args.wav, idb, ["%.0fHz/%.0f" % (f, d) for f, d in pk]))
        return

    chords = [] if args.check_only else ([args.chord] if args.chord else list(CHORDS))
    levels = [args.level] if args.level else [0.10, 0.20]

    # bypass reference (amp off) per chord/level
    print("CHORD IMD / alias -- inharmonic energy (dB rel fundamental). "
          "Lower = cleaner chord.")
    for ch_name in chords:
        ch = CHORDS[ch_name]
        print("\n=== chord '%s' (%s Hz) ===" % (ch_name, "+".join("%.0f" % f for f in ch)))
        for lv in levels:
            xb = _chord_signal(ch, 0.2, lv)
            yb = run_sim.run_dsp(SIM, _bypass_words(cm), xb, gap=8)
            bdb, _ = analyse(yb, ch)
            print("  level %.2f FS  (bypass floor %+.1f dB)" % (lv, bdb))
            for idx, name in MODELS:
                ci, cpk = analyse(run_sim.run_dsp(SIM, _words(cm, idx, 0), xb, gap=8), ch)
                di, dpk = analyse(run_sim.run_dsp(SIM, _words(cm, idx, 1), xb, gap=8), ch)
                sp = " ".join("%.0fHz/%+.0f" % (f, d) for f, d in cpk[:2])
                print("    %-11s clean %+6.1f | drive %+6.1f   clean-spurious: %s"
                      % (name, ci, di, sp))

    if args.check or args.check_only:
        print("\n--- clean-chord IMD check (major triad @0.15 FS) ---")
        ch = CHORDS["major"]
        x = _chord_signal(ch, 0.2, 0.15)
        npass = 0
        for idx, name in MODELS:
            ci, _ = analyse(run_sim.run_dsp(SIM, _words(cm, idx, 0), x, gap=8), ch)
            ceil = CLEAN_IMD_CEIL[idx]
            ok = ci <= ceil
            npass += int(ok)
            print("  %-4s %-11s clean-chord IMD %+6.1f dB (ceiling %+d)%s"
                  % ("PASS" if ok else "FAIL", name, ci, ceil,
                     "" if ok else "  <== muddy chords"))
        print("\n  %d/%d amps keep major chords clean." % (npass, len(MODELS)))


if __name__ == "__main__":
    main()
