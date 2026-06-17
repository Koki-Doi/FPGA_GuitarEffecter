#!/usr/bin/env python3
"""Objective dynamics / time-domain / chain-safety evaluation.

`measure.py --check` covers static tone shape, and `dist_eval.py --check`
covers distortion character. This tool covers the parts those two cannot see:

  * Compressor: gain reduction must grow with input level and RATIO.
  * Noise Suppressor: the tail must close while the attack is preserved, and
    DECAY / DAMP must produce measurable release / closed-depth separation.
  * Wah: POSITION must move the resonant peak upward across the guitar band.
  * Reverb: DECAY / TONE / MIX must move RT60, tail brightness, and wet level.
  * Chain safety: representative multi-effect chains must not full-scale clip.

It still runs the exact Clash `topEntity` through `tools/dsp_sim/dsp_sim`; no
Vivado build or board access is involved.

Examples:
  python3 tools/dsp_sim/dynamics_eval.py --check
  python3 tools/dsp_sim/dynamics_eval.py --check --sections compressor,wah
  python3 tools/dsp_sim/dynamics_eval.py --batch --sections chain
"""
import argparse
import concurrent.futures
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import measure  # noqa: E402
import reverb  # noqa: E402
import run_sim  # noqa: E402
import signals as sig  # noqa: E402
from metrics import (  # noqa: E402
    clip_count,
    is_strictly_rising,
    peak_dbfs,
    rms_dbfs,
    spectral_centroid_hz,
    window_dbfs,
)

FS = 96000
SIM = run_sim.SIM_BIN_DEFAULT
ORDER = measure.ORDER
SECTIONS = ("compressor", "noise", "wah", "reverb", "chain")


def _pack(words):
    return [int(words[k]) & 0xFFFFFFFF for k in ORDER]


def _render(words, x, sim_bin=SIM):
    return run_sim.run_dsp(sim_bin, _pack(words), x, gap=run_sim.GAP)


def _result(name, ok, detail):
    return {"name": name, "ok": bool(ok), "detail": detail}


def _gain_db(y, x):
    return rms_dbfs(y) - rms_dbfs(x)


def _words_comp(cm, ratio, threshold=35, response=45, makeup=50):
    w = measure._base(cm)
    w["comp"] = cm.compressor_word(threshold, ratio, response, makeup, True)
    return w


def evaluate_compressor(cm, sim_bin=SIM):
    x_low = sig.sine(FS, 220, 0.08, 0.08)
    x_hot = sig.sine(FS, 220, 0.08, 0.24)
    y_low = _render(_words_comp(cm, ratio=85), x_low, sim_bin)
    y_light = _render(_words_comp(cm, ratio=20), x_hot, sim_bin)
    y_heavy = _render(_words_comp(cm, ratio=85), x_hot, sim_bin)

    low_gain = _gain_db(y_low, x_low)
    light_gain = _gain_db(y_light, x_hot)
    heavy_gain = _gain_db(y_heavy, x_hot)
    ratio_span = heavy_gain - light_gain
    level_span = heavy_gain - low_gain
    clips = clip_count(y_low) + clip_count(y_light) + clip_count(y_heavy)
    ok = (heavy_gain <= -3.0 and ratio_span <= -2.0 and
          level_span <= -2.5 and clips == 0)
    return _result(
        "compressor",
        ok,
        ("hot gain heavy %.1fdB, light %.1fdB, ratio span %.1fdB, "
         "level span %.1fdB, clips %d" %
         (heavy_gain, light_gain, ratio_span, level_span, clips)),
    )


def _words_noise(cm, threshold=70, decay=30, damp=90):
    w = measure._base(cm)
    w["gate"] = cm.gate_word(noise_gate_on=True)
    w["ns"] = cm.noise_suppressor_word(threshold, decay, damp)
    return w


def evaluate_noise(cm, sim_bin=SIM):
    x = sig.decaying_sine_with_floor(FS, 220, 0.24, 0.045, 0.20)
    y_bypass = _render(measure._base(cm), x, sim_bin)
    y_ns = _render(_words_noise(cm), x, sim_bin)
    y_fast = _render(_words_noise(cm, threshold=70, decay=20, damp=90), x, sim_bin)
    y_slow = _render(_words_noise(cm, threshold=70, decay=80, damp=90), x, sim_bin)
    y_light = _render(_words_noise(cm, threshold=70, decay=40, damp=25), x, sim_bin)
    y_deep = _render(_words_noise(cm, threshold=70, decay=40, damp=90), x, sim_bin)
    attack_delta = (
        window_dbfs(y_ns, FS, 0.000, 0.045)
        - window_dbfs(y_bypass, FS, 0.000, 0.045)
    )
    tail_delta = (
        window_dbfs(y_ns, FS, 0.145, 0.210)
        - window_dbfs(y_bypass, FS, 0.145, 0.210)
    )
    decay_span = (
        window_dbfs(y_slow, FS, 0.115, 0.175)
        - window_dbfs(y_fast, FS, 0.115, 0.175)
    )
    damp_span = (
        window_dbfs(y_light, FS, 0.150, 0.220)
        - window_dbfs(y_deep, FS, 0.150, 0.220)
    )
    clips = (
        clip_count(y_ns) + clip_count(y_fast) + clip_count(y_slow) +
        clip_count(y_light) + clip_count(y_deep)
    )
    ok = (tail_delta <= -5.0 and attack_delta >= -3.0 and
          decay_span >= 1.0 and damp_span >= 6.0 and clips == 0)
    return _result(
        "noise",
        ok,
        ("tail delta %.1fdB, attack delta %.1fdB, decay span %.1fdB, "
         "damp span %.1fdB, clips %d") %
        (tail_delta, attack_delta, decay_span, damp_span, clips),
    )


def _words_wah(cm, position, q=70, volume=55, bias=64):
    w = measure._base(cm)
    w["wah"] = cm.wah_word(position, q, volume, bias, True)
    return w


def _wah_peak(cm, x, freqs, l_byp, position, sim_bin):
    y = _render(_words_wah(cm, position), x, sim_bin)
    levels = measure.tone_levels(y, FS, freqs, len(x))
    net = 20.0 * np.log10((levels + 1) / (l_byp + 1))
    idx = int(np.argmax(net))
    return int(freqs[idx]), float(net[idx]), clip_count(y)


def evaluate_wah(cm, sim_bin=SIM):
    freqs = np.round(np.logspace(np.log10(250), np.log10(2800), 28)).astype(int)
    x = measure.multitone(FS, freqs, 4096, 0.08)
    y_bypass = _render(measure._base(cm), x, sim_bin)
    l_byp = measure.tone_levels(y_bypass, FS, freqs, len(x))
    peaks = [_wah_peak(cm, x, freqs, l_byp, pos, sim_bin) for pos in (5, 50, 95)]
    pf = [p[0] for p in peaks]
    gains = [p[1] for p in peaks]
    clips = sum(p[2] for p in peaks)
    ok = (pf[0] < pf[1] < pf[2] and (pf[2] - pf[0]) >= 900 and
          min(gains) >= 1.0 and clips == 0)
    return _result(
        "wah",
        ok,
        "peak Hz %d -> %d -> %d, gains %.1f/%.1f/%.1fdB, clips %d" %
        (pf[0], pf[1], pf[2], gains[0], gains[1], gains[2], clips),
    )


def _reverb_light(cm, decay, tone, mix, seconds, sim_bin):
    x, nb = reverb.burst_input(FS, seconds, burst_ms=24.0, level=0.45)
    words = dict(zip(ORDER, reverb.reverb_words(cm, decay, tone, mix)))
    y = _render(words, x, sim_bin)
    tail = y[nb + int(0.008 * FS):]
    if len(tail) < 16:
        return {"rt60_s": float("nan"), "centroid": float("nan"), "wet_db": float("-inf")}
    edc = reverb.schroeder_edc_db(tail)
    rt60, _slope, r2, span = reverb.rt60_from_edc(edc, FS)
    dry = x[:nb].astype(np.float64)
    wet_db = rms_dbfs(tail) - rms_dbfs(dry)
    return {
        "rt60_s": rt60,
        "centroid": spectral_centroid_hz(tail, FS),
        "wet_db": wet_db,
        "r2": r2,
        "span": span,
        "clips": clip_count(y),
    }


def evaluate_reverb(cm, sim_bin=SIM, jobs=1, seconds=0.30):
    points = [(20, 65, 90), (60, 65, 90), (100, 65, 90),
              (70, 10, 90), (70, 90, 90), (70, 65, 35), (70, 65, 95)]

    def one(p):
        d, t, m = p
        return p, _reverb_light(cm, d, t, m, seconds, sim_bin)

    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, jobs)) as ex:
        data = dict(ex.map(one, points))

    rt = [data[p]["rt60_s"] for p in points[:3]]
    tone_low = data[(70, 10, 90)]["centroid"]
    tone_high = data[(70, 90, 90)]["centroid"]
    mix_low = data[(70, 65, 35)]["wet_db"]
    mix_high = data[(70, 65, 95)]["wet_db"]
    clips = sum(data[p]["clips"] for p in points)
    finite_rt = all(v == v for v in rt)
    ok = (finite_rt and is_strictly_rising(rt, min_step=0.02) and
          tone_high > tone_low + 500.0 and mix_high > mix_low + 2.0 and clips == 0)
    return _result(
        "reverb",
        ok,
        ("RT60 %.3f -> %.3f -> %.3fs, tone %.0f -> %.0fHz, "
         "mix %.1f -> %.1fdB, clips %d") %
        (rt[0], rt[1], rt[2], tone_low, tone_high, mix_low, mix_high, clips),
    )


def _chain_words(cm, name):
    w = measure._base(cm)
    if name == "clean_rig":
        w["gate"] = cm.gate_word(amp_on=True, cab_on=True)
        w["amp"] = cm.amp_word(18, 70, 50, 35)
        w["amp_tone"] = cm.amp_tone_word(52, 50, 56, amp_model_idx=0, amp_drive_mode=0)
        w["cab"] = cm.cab_word(100, 100, 0, 55)
    elif name == "crunch_rig":
        w["gate"] = cm.gate_word(overdrive_on=True, amp_on=True, cab_on=True)
        w["od"] = cm.overdrive_word(60, 90, 58, overdrive_model=0)
        w["amp"] = cm.amp_word(28, 68, 58, 40)
        w["amp_tone"] = cm.amp_tone_word(55, 55, 60, amp_model_idx=4, amp_drive_mode=1)
        w["cab"] = cm.cab_word(100, 95, 1, 50)
    elif name == "metal_rig":
        w["gate"] = cm.gate_word(distortion_on=True, amp_on=True, cab_on=True)
        w["dist"] = cm.distortion_word(45, 45, 70, pedal_mask=1 << 6)
        w["amp"] = cm.amp_word(24, 62, 55, 40)
        w["amp_tone"] = cm.amp_tone_word(52, 48, 56, amp_model_idx=5, amp_drive_mode=1)
        w["cab"] = cm.cab_word(100, 95, 2, 45)
    elif name == "wet_lead":
        w["gate"] = cm.gate_word(
            distortion_on=True, amp_on=True, cab_on=True, reverb_on=True)
        w["dist"] = cm.distortion_word(55, 45, 64, pedal_mask=1 << 3)
        w["amp"] = cm.amp_word(26, 62, 62, 42)
        w["amp_tone"] = cm.amp_tone_word(52, 56, 60, amp_model_idx=4, amp_drive_mode=1)
        w["cab"] = cm.cab_word(100, 95, 1, 50)
        w["reverb"] = cm.reverb_word(45, 60, 25)
    else:
        raise ValueError("unknown chain %r" % name)
    return w


def evaluate_chain(cm, sim_bin=SIM):
    x = run_sim.synth_guitar(FS, 0.12, f0=110.0, plucks=1, level=0.14)
    rows = []
    ok = True
    for name in ("clean_rig", "crunch_rig", "metal_rig", "wet_lead"):
        y = _render(_chain_words(cm, name), x, sim_bin)
        pk, rms, clips = peak_dbfs(y), rms_dbfs(y), clip_count(y)
        good = (clips == 0 and pk <= -0.2 and -34.0 <= rms <= -8.0)
        ok = ok and good
        rows.append("%s peak %.1f rms %.1f clips %d%s" %
                    (name, pk, rms, clips, "" if good else " FAIL"))
    return _result("chain", ok, "; ".join(rows))


def _parse_sections(text):
    if not text or text == "all":
        return list(SECTIONS)
    out = [s.strip() for s in text.split(",") if s.strip()]
    bad = [s for s in out if s not in SECTIONS]
    if bad:
        raise SystemExit("unknown section(s): %s (valid: %s)" %
                         (", ".join(bad), ", ".join(SECTIONS)))
    return out


def run_sections(cm, sections, sim_bin, jobs, reverb_seconds):
    out = []
    for section in sections:
        if section == "compressor":
            out.append(evaluate_compressor(cm, sim_bin))
        elif section == "noise":
            out.append(evaluate_noise(cm, sim_bin))
        elif section == "wah":
            out.append(evaluate_wah(cm, sim_bin))
        elif section == "reverb":
            out.append(evaluate_reverb(cm, sim_bin, jobs=jobs, seconds=reverb_seconds))
        elif section == "chain":
            out.append(evaluate_chain(cm, sim_bin))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true",
                    help="print PASS/FAIL and return non-zero on failure")
    ap.add_argument("--batch", action="store_true",
                    help="print the measurements without treating failures as fatal")
    ap.add_argument("--sections", default="all",
                    help="comma list: compressor,noise,wah,reverb,chain (default: all)")
    ap.add_argument("--jobs", type=int, default=min(os.cpu_count() or 1, 4),
                    help="parallel workers for independent reverb renders")
    ap.add_argument("--reverb-seconds", type=float, default=0.30,
                    help="short render length for the reverb control check")
    ap.add_argument("--sim-bin", default=SIM)
    args = ap.parse_args()
    if not args.check and not args.batch:
        args.check = True
    if not os.path.exists(args.sim_bin):
        sys.exit("build the sim first: tools/dsp_sim/build_sim.sh")
    cm = run_sim.load_control_maps()
    sections = _parse_sections(args.sections)
    results = run_sections(cm, sections, args.sim_bin, args.jobs, args.reverb_seconds)
    npass = 0
    print("objective dynamics/time/chain checks:")
    for r in results:
        npass += int(r["ok"])
        print("  %-4s %-10s %s" % ("PASS" if r["ok"] else "FAIL", r["name"], r["detail"]))
    print("\n  %d/%d sections passed." % (npass, len(results)))
    if args.check and npass != len(results):
        sys.exit(1)


if __name__ == "__main__":
    main()
