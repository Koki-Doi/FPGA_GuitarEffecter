#!/usr/bin/env python3
"""Offline effect-voicing measurement (built on the DSP sim).

Measures an effect's net frequency shaping vs bypass -- the objective tone curve
(mid hump / scoop / low cut / HF rolloff / notch) -- so a "bring it closer to the
real pedal" voicing change is verified against a measured target instead of by
ear-bench guesswork. Runs the EXACT Clash DSP on the host, no Vivado build.

  python3 tools/dsp_sim/measure.py --config ts_dist        # full curve, one effect
  python3 tools/dsp_sim/measure.py --batch                 # summary table, all effects
  python3 tools/dsp_sim/measure.py --list
"""
import argparse
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
PEDAL_BIT = {"clean_boost": 0, "tube_screamer": 1, "rat": 2, "ds1": 3,
             "big_muff": 4, "fuzz_face": 5, "metal": 6}
AMP_NAMES = ["JC-120", "Twin", "AC30", "Rockerverb", "JCM800", "TriAmp"]

# (config, drive, label, documented real-hardware target shape)
BATCH = [
    ("od_0", 60, "OD TS9",      "mid hump ~720Hz, input low-cut"),
    ("od_1", 60, "OD OD-1",     "asym (even harm), mild"),
    ("od_2", 60, "OD BD-2",     "brighter, dynamic"),
    ("od_3", 45, "OD JanRay",   "transparent, flat-ish, low-mid warmth"),
    ("od_4", 65, "OD OCD",      "harder knee, upper-mid honk"),
    ("od_5", 60, "OD Klon",     "clean-blend, transparent"),
    ("clean_boost", 50, "DIST clean_boost", "mostly flat boost"),
    ("tube_screamer", 60, "DIST TubeScreamer", "mid hump ~720Hz, low-cut"),
    ("ds1", 65, "DIST DS-1",    "scooped-ish, aggressive, HPF in"),
    ("big_muff", 70, "DIST BigMuff", "deep mid scoop, bass+treble"),
    ("fuzz_face", 70, "DIST FuzzFace", "warm, rounded, dynamic bias"),
    ("metal", 70, "DIST Metal", "scooped mids, very bright, high gain"),
    ("rat_fx", 55, "RAT",       "mid-forward, filter rolloff, gritty"),
    ("amp_0", 0, "AMP JC-120",  "clean SS, flat-ish"),
    ("amp_1", 0, "AMP Twin",    "glassy clean, slight scoop"),
    ("amp_2", 0, "AMP AC30",    "chime peak ~2-3kHz, upper-mid"),
    ("amp_3", 0, "AMP Rockerverb", "thick low-mid, dark"),
    ("amp_4", 0, "AMP JCM800",  "mid push ~650Hz, bite"),
    ("amp_5", 0, "AMP TriAmp",  "modern scoop ~750Hz, tight"),
    ("cab", 0, "CAB",           "body bump ~100Hz, cone-breakup peak ~1-4kHz, sharp >5kHz rolloff"),
]


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
    elif name in PEDAL_BIT:
        w["gate"] = cm.gate_word(distortion_on=True)
        w["dist"] = cm.distortion_word(tone=tone, level=level, drive=drive,
                                       pedal_mask=1 << PEDAL_BIT[name])
    elif name.startswith("od_"):
        w["gate"] = cm.gate_word(overdrive_on=True)
        w["od"] = cm.overdrive_word(tone=tone, level=level, drive=drive,
                                    overdrive_model=int(name.split("_")[1]))
    elif name == "rat_fx":
        w["gate"] = cm.gate_word(rat_on=True)
        w["rat"] = cm.rat_word(filter_=tone, level=level, drive=drive, mix=100)
    elif name.startswith("amp_"):
        # low input_gain + Clean mode so the tone-stack / model voicing curve
        # shows without brick-walling the clip stages.
        w["gate"] = cm.gate_word(amp_on=True)
        w["amp"] = cm.amp_word(input_gain=18, master=60, presence=45, resonance=35)
        w["amp_tone"] = cm.amp_tone_word(50, 50, 50, amp_model_idx=int(name.split("_")[1]),
                                         amp_drive_mode=0)
    elif name == "cab" or (name.startswith("cab") and name[3:].isdigit()):
        # "cab" = legacy alias for model 1 (British); "cab0".."cab2" pick the
        # cab model so Open(0) / British(1) / Closed(2) can each be measured
        # (REALISM_REFERENCE_PRESETS.md step 4 blocker fix).
        model = int(name[3:]) if name[3:].isdigit() else 1
        w["gate"] = cm.gate_word(cab_on=True)
        w["cab"] = cm.cab_word(mix=100, level=100, model=model, air=50)
    else:
        raise ValueError("unknown config %r" % name)
    return [int(w[k]) & 0xFFFFFFFF for k in ORDER]


def multitone(fs, freqs, n, level):
    t = np.arange(n) / fs
    x = np.zeros(n)
    rng = np.random.RandomState(7)
    for f in freqs:
        x += np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi))
    x *= level / np.max(np.abs(x))
    return np.round(x * FS24).astype(np.int64)


def tone_levels(y, fs, freqs, n):
    w = np.hanning(len(y))
    spec = np.abs(np.fft.rfft(y.astype(np.float64) * w))
    out = []
    for f in freqs:
        k = int(round(f / (fs / n)))
        out.append(np.max(spec[max(0, k - 2):k + 3]))
    return np.array(out)


def net_curve(cm, name, freqs, x, L_byp, fs, gap, drive=60):
    y = run_sim.run_dsp(SIM_BIN, build_config(cm, name, drive, 50, 50), x, gap=gap)
    net = 20 * np.log10((tone_levels(y, fs, freqs, len(x)) + 1) / (L_byp + 1))
    return net - np.median(net)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", default="ts_dist")
    ap.add_argument("--drive", type=int, default=60)
    ap.add_argument("--level", type=float, default=0.05)
    ap.add_argument("--fs", type=int, default=96000)
    ap.add_argument("--gap", type=int, default=run_sim.GAP)
    ap.add_argument("--n", type=int, default=8192)
    ap.add_argument("--batch", action="store_true")
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()
    aliases = {"ts_dist": "tube_screamer", "fuzz": "fuzz_face"}
    if args.list:
        print("pedals:", list(PEDAL_BIT), "| od_0..5 | amp_0..5 | rat_fx | cab")
        return
    if not os.path.exists(SIM_BIN):
        sys.exit("build the sim first: tools/dsp_sim/build_sim.sh")
    cm = run_sim.load_control_maps()
    freqs = np.round(np.logspace(np.log10(70), np.log10(9000), 26)).astype(int)
    x = multitone(args.fs, freqs, args.n, args.level)
    L_byp = tone_levels(run_sim.run_dsp(SIM_BIN, build_config(cm, "bypass"), x, gap=args.gap),
                        args.fs, freqs, args.n)

    if args.batch:
        print("net tone shaping vs bypass (median-removed). peak/dip = the model's "
              "voicing feature; flag = looks off vs the target.\n")
        print("  %-20s %-13s %-12s %-7s | %s" %
              ("config", "peak", "dip", "tilt", "target (real hardware)"))
        for name, drive, label, target in BATCH:
            net = net_curve(cm, name, freqs, x, L_byp, args.fs, args.gap, drive)
            pk_i, dp_i = int(np.argmax(net)), int(np.argmin(net))
            print("  %-20s %+4.1fdB@%4dHz %+4.1fdB@%4dHz %+5.1f | %s" %
                  (label, net[pk_i], freqs[pk_i], net[dp_i], freqs[dp_i],
                   net[-1] - net[0], target))
        return

    name = aliases.get(args.config, args.config)
    net = net_curve(cm, name, freqs, x, L_byp, args.fs, args.gap, args.drive)
    print("config=%s drive=%d | net frequency shaping vs bypass (dB):" % (name, args.drive))
    for f, d in zip(freqs, net):
        print("  %5d Hz  %+5.1f dB  %s" % (f, d, "#" * int(round(max(0, d + 12)))))
    print("  -> peak %+.1f @ %dHz | dip %+.1f @ %dHz | tilt %+.1f" %
          (net.max(), freqs[int(np.argmax(net))], net.min(),
           freqs[int(np.argmin(net))], net[-1] - net[0]))


if __name__ == "__main__":
    main()
