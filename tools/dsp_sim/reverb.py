#!/usr/bin/env python3
"""Offline reverb / time-domain decay measurement (built on the DSP sim).

The frequency-shaping harness (``measure.py``) and the harmonic harness
(``harmonics.py``) are steady-state: they cannot see a *decay tail*, so the
realism work order step 10 (Reverb) was stuck in the ear-only domain
("offline harness inadequate", D125). This tool adds the missing time-domain
axis -- it excites the reverb with a short burst, captures the tail, and reports
objective decay metrics on the EXACT Clash DSP (no Vivado build):

  * RT60       -- Schroeder backward-integrated decay (T20 fit, extrapolated),
                  the tail length; the question "does DECAY actually do something
                  and monotonically?" (the inert-knob class that bit the
                  Compressor RATIO and the RAT FILTER).
  * tail tone  -- spectral centroid of the tail (TONE / HF damping; a metallic
                  bright tail vs a dark damped one).
  * wet level  -- tail RMS vs the dry burst (the MIX depth).
  * echo period-- autocorrelation peak of the tail (the 2048-sample / ~21.3 ms
                  comb spacing at 96 kHz -- sanity that the structure is the
                  single comb; ReverbAddr = Index 2048).

  python3 tools/dsp_sim/reverb.py                         # one render, full report
  python3 tools/dsp_sim/reverb.py --decay-sweep           # RT60 vs DECAY knob
  python3 tools/dsp_sim/reverb.py --tone-sweep            # tail brightness vs TONE
  python3 tools/dsp_sim/reverb.py --decay 80 --tone 40 --mix 90
"""
import argparse
import concurrent.futures
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run_sim  # noqa: E402

FS24 = run_sim.FS24
ORDER = ["gate", "od", "dist", "eq", "rat", "amp",
         "amp_tone", "cab", "reverb", "ns", "comp", "wah"]


def reverb_words(cm, decay, tone, mix):
    """12 control words: everything off except the reverb stage (enabled via the
    gate flag), so the tail is pure reverb."""
    w = {
        "gate": cm.gate_word(reverb_on=True),
        "od": cm.overdrive_word(65, 100, 30),
        "dist": cm.distortion_word(50, 35, 0, 0),
        "eq": cm.eq_word(100, 100, 100),
        "rat": cm.rat_word(35, 100, 0, 100),
        "amp": cm.amp_word(35, 80, 45, 35),
        "amp_tone": cm.amp_tone_word(50, 50, 50, amp_model_idx=0, amp_drive_mode=0),
        "cab": cm.cab_word(100, 100, 1, 50),
        "reverb": cm.reverb_word(decay=decay, tone=tone, mix=mix),
        "ns": cm.noise_suppressor_word(35, 40, 70),
        "comp": cm.compressor_word(45, 35, 45, 50, False),
        "wah": cm.wah_word(0, 50, 50, 50, False),
    }
    return [int(w[k]) & 0xFFFFFFFF for k in ORDER]


def burst_input(fs, seconds, burst_ms=40.0, level=0.45, seed=11):
    """A short windowed broadband-noise burst, then silence. Broadband so every
    comb mode is excited (the tail tone is meaningful); short so the decay tail
    is cleanly separable. A single impulse is too weak to lift the wet tail off
    the floor (D125) -- a burst carries enough energy."""
    n = int(fs * seconds)
    x = np.zeros(n, dtype=np.float64)
    nb = int(fs * burst_ms / 1000.0)
    rng = np.random.RandomState(seed)
    win = np.hanning(nb)
    x[:nb] = rng.uniform(-1.0, 1.0, nb) * win
    return np.round(x * level * FS24).astype(np.int64), nb


def schroeder_edc_db(tail):
    """Energy decay curve (dB, normalised to 0 at the start) via Schroeder
    backward integration of the squared tail -- monotone by construction, so it
    smooths the comb's periodic ripple into a clean decay slope."""
    e = tail.astype(np.float64) ** 2
    edc = np.cumsum(e[::-1])[::-1]
    edc = edc / (edc[0] + 1e-30)
    return 10.0 * np.log10(edc + 1e-30)


def rt60_from_edc(edc, fs, top=-5.0, bot=-25.0):
    """Fit the EDC slope over [top, bot] dB (T20) and extrapolate to 60 dB.

    Returns (rt60_s, slope_db_per_s, r2, span_db) where span_db is how far the
    EDC actually fell (so a floor-limited / too-short tail is visible). rt60 is
    NaN if the window is unusable."""
    span = float(edc[0] - edc.min())
    i0 = int(np.argmax(edc <= top))
    i1 = int(np.argmax(edc <= bot))
    if i1 <= i0 or i1 == 0:                       # never reached `bot`
        return float("nan"), float("nan"), 0.0, span
    t = np.arange(i0, i1) / fs
    y = edc[i0:i1]
    a, b = np.polyfit(t, y, 1)                     # y = a*t + b, a = dB/s (neg)
    yhat = a * t + b
    ss_res = float(np.sum((y - yhat) ** 2))
    ss_tot = float(np.sum((y - y.mean()) ** 2)) + 1e-30
    r2 = 1.0 - ss_res / ss_tot
    rt60 = float(-60.0 / a) if a < 0 else float("nan")
    return rt60, float(a), r2, span


def tail_centroid_hz(tail, fs):
    w = np.hanning(len(tail))
    spec = np.abs(np.fft.rfft(tail.astype(np.float64) * w))
    freqs = np.fft.rfftfreq(len(tail), 1.0 / fs)
    return float(np.sum(freqs * spec) / (np.sum(spec) + 1e-9))


def echo_period_ms(tail, fs, lo_ms=2.0, hi_ms=60.0):
    """Dominant tail repetition period via autocorrelation (the comb spacing)."""
    x = tail.astype(np.float64)
    x = x - x.mean()
    ac = np.correlate(x, x, mode="full")[len(x) - 1:]
    lo, hi = int(fs * lo_ms / 1000), min(int(fs * hi_ms / 1000), len(ac) - 1)
    if hi <= lo:
        return float("nan")
    k = lo + int(np.argmax(ac[lo:hi]))
    return 1000.0 * k / fs


def measure_reverb(cm, sim_bin, fs, seconds, decay, tone, mix, gap, guard_ms=8.0):
    x, nb = burst_input(fs, seconds, level=0.45)
    y = run_sim.run_dsp(sim_bin, reverb_words(cm, decay, tone, mix), x, gap=gap)
    g = int(fs * guard_ms / 1000.0)
    tail = y[nb + g:]
    dry = x[:nb].astype(np.float64)
    edc = schroeder_edc_db(tail)
    rt60, slope, r2, span = rt60_from_edc(edc, fs)
    dry_rms = np.sqrt(np.mean(dry * dry)) + 1.0
    tail_rms = np.sqrt(np.mean(tail.astype(np.float64) ** 2)) + 1.0
    return {
        "rt60_s": rt60, "edc_slope_db_s": slope, "edc_r2": r2, "edc_span_db": span,
        "tail_centroid_Hz": tail_centroid_hz(tail, fs),
        "wet_tail_minus_dry_dB": 20.0 * np.log10(tail_rms / dry_rms),
        "echo_period_ms": echo_period_ms(tail, fs),
        "tail_len_s": len(tail) / fs,
    }


def _parallel(cm, sim_bin, fs, seconds, gap, points, jobs):
    """points = list of (decay, tone, mix); returns results in input order."""
    def one(p):
        d, t, m = p
        return measure_reverb(cm, sim_bin, fs, seconds, d, t, m, gap)
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, jobs)) as ex:
        return list(ex.map(one, points))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--decay", type=int, default=70)
    ap.add_argument("--tone", type=int, default=65)
    ap.add_argument("--mix", type=int, default=90)
    ap.add_argument("--seconds", type=float, default=0.8,
                    help="total render length. 0.8 s gives a stable T20 RT60 across "
                         "the whole DECAY range (verified RT60 identical at 0.8/1.6 s "
                         "since the -5..-25 dB fit window is reached early); raise it "
                         "only to study the deep tail / very long DECAY.")
    ap.add_argument("--fs", type=int, default=96000)
    ap.add_argument("--gap", type=int, default=run_sim.GAP)
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 1)
    ap.add_argument("--decay-sweep", action="store_true",
                    help="RT60 vs DECAY (the 'is the knob real / monotonic' check)")
    ap.add_argument("--tone-sweep", action="store_true",
                    help="tail brightness vs TONE (HF damping)")
    ap.add_argument("--sim-bin", default=run_sim.SIM_BIN_DEFAULT)
    args = ap.parse_args()
    if not os.path.exists(args.sim_bin):
        sys.exit("build the sim first: tools/dsp_sim/build_sim.sh")
    cm = run_sim.load_control_maps()

    if args.decay_sweep:
        decays = [0, 25, 50, 70, 85, 100]
        pts = [(d, args.tone, args.mix) for d in decays]
        res = _parallel(cm, args.sim_bin, args.fs, args.seconds, args.gap, pts, args.jobs)
        print("RT60 vs DECAY (tone=%d mix=%d). monotone-rising = the knob works; "
              "r2<~0.9 or span<25 dB = tail too short/floor-limited (raise --seconds)\n"
              % (args.tone, args.mix))
        print("  %-7s %-10s %-12s %-7s %-9s" % ("DECAY", "RT60", "slope", "r2", "span"))
        for d, m in zip(decays, res):
            rt = "%.3f s" % m["rt60_s"] if m["rt60_s"] == m["rt60_s"] else "  --  "
            print("  %-7d %-10s %+7.1f dB/s %-7.2f %-6.1f dB"
                  % (d, rt, m["edc_slope_db_s"], m["edc_r2"], m["edc_span_db"]))
        return

    if args.tone_sweep:
        tones = [0, 25, 50, 75, 100]
        pts = [(args.decay, t, args.mix) for t in tones]
        res = _parallel(cm, args.sim_bin, args.fs, args.seconds, args.gap, pts, args.jobs)
        print("tail brightness vs TONE (decay=%d mix=%d). rising centroid = TONE "
              "opens the tail HF (more damping at low TONE)\n" % (args.decay, args.mix))
        print("  %-7s %-16s %-10s" % ("TONE", "tail centroid", "RT60"))
        for t, m in zip(tones, res):
            rt = "%.3f s" % m["rt60_s"] if m["rt60_s"] == m["rt60_s"] else "  --  "
            print("  %-7d %8.0f Hz       %s" % (t, m["tail_centroid_Hz"], rt))
        return

    m = measure_reverb(cm, args.sim_bin, args.fs, args.seconds,
                       args.decay, args.tone, args.mix, args.gap)
    print("reverb  decay=%d tone=%d mix=%d  fs=%d  tail=%.2fs"
          % (args.decay, args.tone, args.mix, args.fs, m["tail_len_s"]))
    rt = "%.3f s" % m["rt60_s"] if m["rt60_s"] == m["rt60_s"] else "n/a (tail too short/floor)"
    print("  RT60 (T20 extrap) : %s   [slope %+.1f dB/s, r2 %.2f, EDC span %.1f dB]"
          % (rt, m["edc_slope_db_s"], m["edc_r2"], m["edc_span_db"]))
    print("  tail centroid     : %.0f Hz   (TONE / HF damping)" % m["tail_centroid_Hz"])
    print("  wet tail vs dry   : %+.1f dB   (MIX depth)" % m["wet_tail_minus_dry_dB"])
    print("  echo period       : %.2f ms   (comb spacing ~21.3 ms = 2048 samp @ 96 kHz)" % m["echo_period_ms"])
    if m["edc_span_db"] < 25 or m["edc_r2"] < 0.9:
        print("  NOTE: EDC span/fit weak -- raise --seconds or --mix, or lower --decay,"
              " for a reliable RT60.")


if __name__ == "__main__":
    main()
