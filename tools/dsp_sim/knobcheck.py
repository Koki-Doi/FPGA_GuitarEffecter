#!/usr/bin/env python3
"""How much does the SOUND change -- per frequency band -- when you move a knob?

For every knob of every effect this renders the EXACT Clash DSP at two knob
settings and reports **how much the audio output changes, broken down by
frequency band** -- so you see not just that a knob moves the sound, but by how
much and *where* in the spectrum (a TREBLE knob lifts the top bands and leaves
the low ones alone; a LEVEL knob moves every band equally; an inert knob moves
nothing).

Per knob it prints the band-by-band level change dB (the `to` setting minus the
`from` setting) across these bands plus the overall RMS change:

    80Hz   200    500    1k     3k     8k     | overall
   (50-120)(120-350)(350-800)(800-1600)(1.6-4k)(4-14k)

Why this makes hardware comparison easy: there is no per-sample DMA capture off
the board, so a sample-exact sim-vs-board diff is impossible. But "turn this knob
and listen to which part of the spectrum moves, and by how much" is exactly what
you do on the board -- so this per-band table is the reference: sweep the same
knob on the GUI/encoder and check the same bands move by a comparable amount.

  python3 tools/dsp_sim/knobcheck.py --all                 # every effect, 25->75
  python3 tools/dsp_sim/knobcheck.py --effect amp          # one effect
  python3 tools/dsp_sim/knobcheck.py --effect eq --from 0 --to 100
  python3 tools/dsp_sim/knobcheck.py --bands               # print the band table
  python3 tools/dsp_sim/knobcheck.py --list

The default transition is the usable range 25->75 (non-degenerate, readable);
use --from 0 --to 100 for the full extremes. Input per effect (96 kHz mono,
level-recorded so the board can be driven the same way): a 0.15-FS broadband
multitone for tone/drive/level effects, a 220 Hz decaying pluck for compressor,
a faster 220 Hz pluck with a tail-window metric for Noise Suppressor, and a
noise burst + tail for reverb.
"""
import argparse
import concurrent.futures
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run_sim    # noqa: E402
import measure    # noqa: E402  (multitone, _base, ORDER)
import signals as sig  # noqa: E402
import reverb     # noqa: E402  (burst_input)

FS = 96000
FS24 = run_sim.FS24
ORDER = measure.ORDER
SIM = run_sim.SIM_BIN_DEFAULT

# Frequency bands the change is resolved into (guitar-relevant log split).
BANDS = [("80Hz", 50, 120), ("200", 120, 350), ("500", 350, 800),
         ("1k", 800, 1600), ("3k", 1600, 4000), ("8k", 4000, 14000)]
QUIET = 1.0     # dB: |band change| and |overall| all below this => "barely audible"


# ---- inputs (level-recorded, board-reproducible) -----------------------------
def in_multitone():
    freqs = np.round(np.logspace(np.log10(70), np.log10(11000), 36)).astype(int)
    return measure.multitone(FS, freqs, 4096, 0.15)        # drives mild clipping + shows tone
def in_pluck():
    return sig.decaying_sine(FS, 220, 0.35, 0.12, sig.DRIVE)   # comp/NS dynamic action
def in_ns_pluck():
    return sig.decaying_sine_with_floor(FS, 220, 0.24, 0.045, sig.DRIVE)
def in_reverb():
    x, _ = reverb.burst_input(FS, 0.6, level=0.45)             # burst + tail
    return x

INPUTS = {"multitone": in_multitone, "pluck": in_pluck, "ns_pluck": in_ns_pluck,
          "reverb": in_reverb}


# ---- per-band level metric ---------------------------------------------------
def band_levels_db(y):
    """Power in each band, in dB (FS24 reference). Robust floor so a silent
    render is a finite very-low number rather than -inf."""
    p = np.abs(np.fft.rfft(y.astype(np.float64) * np.hanning(len(y)))) ** 2
    freqs = np.fft.rfftfreq(len(y), 1.0 / FS)
    out = []
    for _name, lo, hi in BANDS:
        m = (freqs >= lo) & (freqs < hi)
        e = float(np.sum(p[m])) / (FS24 ** 2) + 1e-12
        out.append(10.0 * np.log10(e))
    return np.array(out)


def overall_db(y):
    return 20.0 * np.log10((np.sqrt(np.mean(y.astype(np.float64) ** 2)) + 1.0) / FS24)


def metric_view(name, label, y):
    """Pick the part of the render that carries the knob's meaning.

    Noise Suppressor DECAY/DAMP act after the note falls below threshold. A
    whole-render RMS is dominated by the preserved attack and falsely marks
    those knobs as inert, so measure the closing tail instead.
    """
    if name == "noise_sup":
        if label == "DECAY":
            start = int(0.105 * FS)
            stop = int(0.170 * FS)
        elif label == "DAMP":
            start = int(0.150 * FS)
            stop = int(0.235 * FS)
        else:
            start = int(0.095 * FS)
            stop = int(0.220 * FS)
        return y[start:min(stop, len(y))]
    return y


# ---- effect definitions (enable, base params, word builder, input, knobs) ----
def _eff(cm):
    return {
        "overdrive": dict(gate=dict(overdrive_on=True), input="multitone",
            base=dict(tone=50, level=60, drive=60, model=0),
            word=lambda p: {"od": cm.overdrive_word(p["tone"], p["level"], p["drive"],
                                                    overdrive_model=p["model"])},
            knobs=[("DRIVE", "drive"), ("TONE", "tone"), ("LEVEL", "level")]),
        "distortion": dict(gate=dict(distortion_on=True), input="multitone",
            base=dict(tone=50, level=50, drive=65, pedal=3),   # 3 = ds1
            word=lambda p: {"dist": cm.distortion_word(p["tone"], p["level"], p["drive"],
                                                      pedal_mask=1 << p["pedal"])},
            knobs=[("DRIVE", "drive"), ("TONE", "tone"), ("LEVEL", "level")]),
        "rat": dict(gate=dict(rat_on=True), input="multitone",
            base=dict(filter_=40, level=100, drive=70, mix=100),
            word=lambda p: {"rat": cm.rat_word(p["filter_"], p["level"], p["drive"], p["mix"])},
            knobs=[("DRIVE", "drive"), ("FILTER", "filter_"), ("LEVEL", "level"), ("MIX", "mix")]),
        "amp": dict(gate=dict(amp_on=True), input="multitone",
            base=dict(input_gain=40, master=70, presence=45, resonance=35,
                      bass=50, middle=50, treble=50, model=4, drive_mode=1),
            word=lambda p: {
                "amp": cm.amp_word(p["input_gain"], p["master"], p["presence"], p["resonance"]),
                "amp_tone": cm.amp_tone_word(p["bass"], p["middle"], p["treble"],
                                             amp_model_idx=p["model"], amp_drive_mode=p["drive_mode"])},
            knobs=[("INPUT_GAIN", "input_gain"), ("MASTER", "master"), ("PRESENCE", "presence"),
                   ("RESONANCE", "resonance"), ("BASS", "bass"), ("MIDDLE", "middle"),
                   ("TREBLE", "treble")]),
        "cab": dict(gate=dict(cab_on=True), input="multitone",
            base=dict(mix=100, level=100, model=1, air=50),
            word=lambda p: {"cab": cm.cab_word(p["mix"], p["level"], p["model"], p["air"])},
            knobs=[("MIX", "mix"), ("LEVEL", "level"), ("AIR", "air")]),
        "eq": dict(gate=dict(eq_on=True), input="multitone",
            base=dict(low=50, mid=50, high=50),
            word=lambda p: {"eq": cm.eq_word(p["low"], p["mid"], p["high"])},
            knobs=[("LOW", "low"), ("MID", "mid"), ("HIGH", "high")]),
        "reverb": dict(gate=dict(reverb_on=True), input="reverb",
            base=dict(decay=70, tone=65, mix=90),
            word=lambda p: {"reverb": cm.reverb_word(p["decay"], p["tone"], p["mix"])},
            knobs=[("DECAY", "decay"), ("TONE", "tone"), ("MIX", "mix")]),
        "noise_sup": dict(gate=dict(noise_gate_on=True), input="ns_pluck",
            base=dict(threshold=70, decay=40, damp=70),
            word=lambda p: {"ns": cm.noise_suppressor_word(p["threshold"], p["decay"], p["damp"])},
            knobs=[("THRESHOLD", "threshold"), ("DECAY", "decay"), ("DAMP", "damp")]),
        "compressor": dict(gate=dict(), input="pluck",
            base=dict(threshold=35, ratio=60, response=45, makeup=50),
            word=lambda p: {"comp": cm.compressor_word(p["threshold"], p["ratio"],
                                                     p["response"], p["makeup"], enabled=True)},
            knobs=[("THRESHOLD", "threshold"), ("RATIO", "ratio"),
                   ("RESPONSE", "response"), ("MAKEUP", "makeup")]),
        "wah": dict(gate=dict(), input="multitone",
            base=dict(position=50, q=50, volume=50, bias=64),
            word=lambda p: {"wah": cm.wah_word(p["position"], p["q"], p["volume"],
                                             p["bias"], enabled=True)},
            knobs=[("POSITION", "position"), ("Q", "q"), ("VOLUME", "volume"), ("BIAS", "bias")]),
    }


def build_words(cm, eff, params):
    w = measure._base(cm)
    w["gate"] = cm.gate_word(**eff["gate"])
    w.update(eff["word"](params))
    return [int(w[k]) & 0xFFFFFFFF for k in ORDER]


def render(cm, eff, key, value, x):
    p = dict(eff["base"])
    p[key] = value
    return run_sim.run_dsp(SIM, build_words(cm, eff, p), x, gap=run_sim.GAP)


def check_effect(cm, name, eff, lo, hi, jobs):
    x = INPUTS[eff["input"]]()
    tasks = [(label, key, v) for (label, key) in eff["knobs"] for v in (lo, hi)]
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as ex:
        outs = list(ex.map(lambda t: render(cm, eff, t[1], t[2], x), tasks))
    ren = {}
    for (label, key, v), y in zip(tasks, outs):
        ren.setdefault(label, {})[v] = y
    hdr = "  ".join("%6s" % b[0] for b in BANDS)
    print("== %s ==  (input %s, %d->%d)" % (name.upper(), eff["input"], lo, hi))
    print("  %-11s %s | overall" % ("knob band dB:", hdr))
    for label, key in eff["knobs"]:
        y_hi = metric_view(name, label, ren[label][hi])
        y_lo = metric_view(name, label, ren[label][lo])
        d = band_levels_db(y_hi) - band_levels_db(y_lo)
        dov = overall_db(y_hi) - overall_db(y_lo)
        cells = "  ".join("%+6.1f" % v for v in d)
        flag = "  <== barely audible" if (np.max(np.abs(d)) < QUIET and abs(dov) < QUIET) else ""
        print("  %-11s %s | %+6.1f%s" % (label, cells, dov, flag))
    print()


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--effect", help="one effect (see --list); else --all")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--from", dest="lo", type=int, default=25, help="knob 'from' setting")
    ap.add_argument("--to", dest="hi", type=int, default=75, help="knob 'to' setting")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--bands", action="store_true", help="print the band definitions")
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 1)
    args = ap.parse_args()
    if args.bands:
        for n, lo, hi in BANDS:
            print("  %-6s %5d - %5d Hz" % (n, lo, hi))
        return
    cm = run_sim.load_control_maps()
    eff = _eff(cm)
    if args.list:
        for n, e in eff.items():
            print("  %-11s knobs: %s" % (n, ", ".join(k[0] for k in e["knobs"])))
        return
    if not os.path.exists(SIM):
        sys.exit("build the sim first: tools/dsp_sim/build_sim.sh")
    print("knob per-band audio change | fs=%d gap=%d | %d -> %d\n"
          "  each cell = band level change dB (knob %d minus knob %d); + = that band "
          "got louder.\n  flat row = pure level knob; tilted = tonal; ~0 across all "
          "bands = barely audible.\n" % (FS, run_sim.GAP, args.lo, args.hi, args.hi, args.lo))
    names = list(eff) if (args.all or not args.effect) else [args.effect]
    for n in names:
        if n not in eff:
            sys.exit("unknown effect %r (see --list)" % n)
        check_effect(cm, n, eff[n], args.lo, args.hi, args.jobs)


if __name__ == "__main__":
    main()
