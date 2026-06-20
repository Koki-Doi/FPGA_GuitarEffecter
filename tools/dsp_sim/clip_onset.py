#!/usr/bin/env python3
"""Clean-amp clipping-onset sweep (the D147 JC-120 / Fender-Twin bench follow-up).

The fixed-0.12-FS `dist_eval.py --check` clean ceiling could not explain the
D147 bench report that JC-120 and Fender/Twin Reverb audibly clip while the
other Amp models sound good. JC-120 is sag-exempt and byte-identical to D135, and
Twin passes the 0.15-FS chord ceiling, so the symptom is level-dependent: it only
shows once the input is hot enough to reach a clip stage. This tool sweeps the
input level for the CLEAN amps and reports, per model, where audible clipping
begins (THD%, peak FS, crest, hard-clip count) so the responsible gain/headroom
stage can be localized before any voicing change.

  python3 tools/dsp_sim/clip_onset.py            # default models 0,1,2,4
  python3 tools/dsp_sim/clip_onset.py --models 0,1,2,3,4,5
  python3 tools/dsp_sim/clip_onset.py --drive-mode 0 --freq 220
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run_sim          # noqa: E402
import measure          # noqa: E402
import harmonics        # noqa: E402
import signals as sig   # noqa: E402

SIM = run_sim.SIM_BIN_DEFAULT
FS = 96000
GAP = run_sim.GAP
NAMES = ["JC-120", "Twin", "AC30", "Rockerverb", "JCM800", "TriAmp"]
# realistic clean-amp op point (same knobs measure.py/dist_eval use for amp_N)
INPUT_GAIN, MASTER, PRESENCE, RESONANCE = 18, 60, 45, 35
LEVELS = [0.05, 0.08, 0.12, 0.18, 0.25, 0.35, 0.50]


def _words(cm, idx, drive):
    w = measure._base(cm)
    w["gate"] = cm.gate_word(amp_on=True)
    w["amp"] = cm.amp_word(input_gain=INPUT_GAIN, master=MASTER,
                           presence=PRESENCE, resonance=RESONANCE)
    w["amp_tone"] = cm.amp_tone_word(50, 50, 50, amp_model_idx=idx,
                                     amp_drive_mode=drive)
    return [w[k] for k in run_sim.WORD_ORDER]


def sweep(cm, idx, drive, freq):
    rows = []
    for lv in LEVELS:
        x = sig.sine(FS, freq, 0.10, lv)
        y = run_sim.run_dsp(SIM, _words(cm, idx, drive), x, gap=GAP)
        thd = harmonics.harmonic_profile(y, FS, float(freq))["thd_pct"]
        m = run_sim.metrics(y, FS)
        peak_fs = 10 ** (m["peak_dBFS"] / 20.0)
        rows.append((lv, peak_fs, thd, m["crest_dB"], m["clip_count"]))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--models", default="0,1,2,4")
    ap.add_argument("--drive-mode", type=int, default=0)
    ap.add_argument("--freq", type=int, default=220)
    args = ap.parse_args()
    cm = run_sim.load_control_maps()
    idxs = [int(s) for s in args.models.split(",")]
    print("clean-amp clip-onset sweep  (input_gain=%d master=%d, drive_mode=%d, %d Hz)"
          % (INPUT_GAIN, MASTER, args.drive_mode, args.freq))
    print("THD%% high + crest collapsing toward ~3 dB = audible clipping.\n")
    for idx in idxs:
        print("  %-10s  in_FS  peak_FS   THD%%   crest_dB  clips" % NAMES[idx])
        for lv, peak, thd, crest, clips in sweep(cm, idx, args.drive_mode, args.freq):
            flag = "  <== CLIP" if thd > 5.0 else ""
            print("    %18.2f  %6.3f  %5.1f  %7.2f  %5d%s"
                  % (lv, peak, thd, crest, clips, flag))
        print()


if __name__ == "__main__":
    main()
