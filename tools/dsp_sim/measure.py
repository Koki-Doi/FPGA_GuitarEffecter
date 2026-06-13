#!/usr/bin/env python3
"""Offline effect-voicing measurement (built on the DSP sim).

Measures an effect's net frequency shaping vs bypass -- the objective tone curve
(mid hump / low cut / high rolloff / notch) -- so a "bring it closer to the real
pedal" voicing change can be verified against a measured target instead of by
ear-bench guesswork. Runs the EXACT Clash DSP on the host (tools/dsp_sim), no
Vivado build.

Method: a flat-ish multitone (log-spaced sines) is rendered through the effect
and through bypass; per-tone output magnitude (effect - bypass, dB) is the net
gain curve. Mild input level so the clip stage's tone shaping shows without
brick-walling.

  python3 tools/dsp_sim/measure.py --config ts_dist
  python3 tools/dsp_sim/measure.py --list
"""
import argparse
import importlib.util
import os
import sys

import numpy as np

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SIM_BIN = os.path.join(REPO, "tools", "dsp_sim", "dsp_sim")
FS24 = 1 << 23
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run_sim  # noqa: E402

ORDER = ["gate", "od", "dist", "eq", "rat", "amp",
         "amp_tone", "cab", "reverb", "ns", "comp", "wah"]
# DISTORTION_PEDALS bit order: clean_boost0 tube_screamer1 rat2 ds13 big_muff4 fuzz_face5 metal6
PEDAL_BIT = {"clean_boost": 0, "tube_screamer": 1, "rat": 2, "ds1": 3,
             "big_muff": 4, "fuzz_face": 5, "metal": 6}


def _base(cm):
    return {
        "gate": cm.gate_word(), "od": cm.overdrive_word(65, 100, 30),
        "dist": cm.distortion_word(50, 35, 0, 0), "eq": cm.eq_word(100, 100, 100),
        "rat": cm.rat_word(35, 100, 0, 100), "amp": cm.amp_word(35, 80, 45, 35),
        "amp_tone": cm.amp_tone_word(50, 50, 50, amp_model_idx=0, amp_drive_mode=0),
        "cab": cm.cab_word(100, 100, 1, 50), "reverb": cm.reverb_word(0, 65, 0),
        "ns": cm.noise_suppressor_word(35, 40, 70),
        "comp": cm.compressor_word(45, 35, 45, 50, False),
        "wah": cm.wah_word(0, 50, 50, 50, False),
    }


def build_config(cm, name, drive=60, tone=50, level=50):
    w = _base(cm)
    if name == "bypass":
        pass
    elif name in PEDAL_BIT:  # a distortion pedal
        w["gate"] = cm.gate_word(distortion_on=True)
        w["dist"] = cm.distortion_word(tone=tone, level=level, drive=drive,
                                       pedal_mask=1 << PEDAL_BIT[name])
    elif name.startswith("od_"):  # an overdrive model: od_<idx>
        idx = int(name.split("_")[1])
        w["gate"] = cm.gate_word(overdrive_on=True)
        w["od"] = cm.overdrive_word(tone=tone, level=level, drive=drive,
                                    overdrive_model=idx)
    elif name == "rat_fx":
        w["gate"] = cm.gate_word(rat_on=True)
        w["rat"] = cm.rat_word(filter_=tone, level=level, drive=drive, mix=100)
    else:
        raise ValueError("unknown config %r" % name)
    return [int(w[k]) & 0xFFFFFFFF for k in ORDER]


def multitone(fs, freqs, n, level):
    t = np.arange(n) / fs
    x = np.zeros(n)
    rng = np.random.RandomState(7)
    for f in freqs:
        x += np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi))  # random phase -> low crest
    x *= level / np.max(np.abs(x))
    return np.round(x * FS24).astype(np.int64)


def tone_levels(y, fs, freqs, n):
    w = np.hanning(len(y))
    spec = np.abs(np.fft.rfft(y.astype(np.float64) * w))
    bins = np.fft.rfftfreq(n, 1.0 / fs)
    out = []
    for f in freqs:
        k = int(round(f / (fs / n)))
        out.append(np.max(spec[max(0, k - 2):k + 3]))  # peak near the tone bin
    return np.array(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", default="ts_dist")
    ap.add_argument("--drive", type=int, default=60)
    ap.add_argument("--tone", type=int, default=50)
    ap.add_argument("--level", type=float, default=0.05, help="multitone peak frac of FS")
    ap.add_argument("--fs", type=int, default=96000)
    ap.add_argument("--gap", type=int, default=run_sim.GAP)
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()
    aliases = {"ts_dist": "tube_screamer", "ds1": "ds1", "big_muff": "big_muff",
               "fuzz": "fuzz_face", "metal": "metal", "clean_boost": "clean_boost"}
    if args.list:
        print("pedals:", list(PEDAL_BIT), "| od_0..od_5 | rat_fx | aliases:", aliases)
        return
    name = aliases.get(args.config, args.config)
    if not os.path.exists(SIM_BIN):
        sys.exit("build the sim first: tools/dsp_sim/build_sim.sh")
    cm = run_sim.load_control_maps()

    n = 16384
    freqs = np.round(np.logspace(np.log10(70), np.log10(9000), 26)).astype(int)
    x = multitone(args.fs, freqs, n, args.level)
    y_eff = run_sim.run_dsp(SIM_BIN, build_config(cm, name, args.drive, args.tone, args.level and 50),
                            x, gap=args.gap)
    y_byp = run_sim.run_dsp(SIM_BIN, build_config(cm, "bypass"), x, gap=args.gap)
    L_eff = tone_levels(y_eff, args.fs, freqs, n)
    L_byp = tone_levels(y_byp, args.fs, freqs, n)
    net = 20 * np.log10((L_eff + 1) / (L_byp + 1))
    net -= np.median(net)  # show shape relative to its own median (tilt/hump/notch)

    print("config=%s drive=%d tone=%d  | net frequency shaping vs bypass (dB, median-removed):"
          % (name, args.drive, args.tone))
    for f, d in zip(freqs, net):
        bar = "#" * int(round(max(0, d + 12)))   # -12 dB floor for the bar
        print("  %5d Hz  %+5.1f dB  %s" % (f, d, bar))
    pk = freqs[int(np.argmax(net))]
    nt = freqs[int(np.argmin(net))]
    print("  -> peak %+.1f dB @ %d Hz | dip %+.1f dB @ %d Hz | tilt(9k-70) %+.1f dB"
          % (net.max(), pk, net.min(), nt, net[-1] - net[0]))


if __name__ == "__main__":
    main()
