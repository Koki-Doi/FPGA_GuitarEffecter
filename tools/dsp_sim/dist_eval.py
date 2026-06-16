#!/usr/bin/env python3
"""Distortion CHARACTER evaluation (the perceptual axes a single-sine THD misses).

The net-frequency-response (`measure.py`) + single-sine harmonic profile
(`harmonics.py`) cannot tell you whether a pedal *distorts enough*, *sustains*,
or is *gritty* -- the qualities a player actually judges ("歪が足りない / 質感 /
サステイン / ジャリつき"). This tool measures them objectively on the EXACT Clash
DSP:

  * DRIVE/gain    -- THD% AND crest (dB) vs INPUT LEVEL. Rising THD + falling
                     crest = harder saturation; THD that DROPS at low input =
                     a Fuzz-Face-style cleanup. Tells you if a pedal under-drives.
  * SUSTAIN       -- decay-compression ratio: feed a decaying pluck, fit the
                     OUTPUT envelope decay vs the INPUT's. >1 = the pedal holds
                     the note (a Big Muff / Fuzz "sustainer"); ~1 = no sustain.
  * GRIT/fizz     -- two-tone INTERMODULATION (the non-harmonic "grit/ジャリ") and
                     >5 kHz inharmonic energy ("fizz"). High IMD = raspy/gnarly.
  * (clip shape   -- read crest at high input: ~3 dB = square/hard, higher = soft.)

  python3 tools/dsp_sim/dist_eval.py --config ds1 --drive 65
  python3 tools/dsp_sim/dist_eval.py --batch          # DS-1/BigMuff/FuzzFace/Metal/...
  python3 tools/dsp_sim/dist_eval.py --list
"""
import argparse
import concurrent.futures
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run_sim    # noqa: E402
import measure    # noqa: E402
import harmonics  # noqa: E402
import signals as sig  # noqa: E402

SIM = run_sim.SIM_BIN_DEFAULT
FS = 96000
GAP = run_sim.GAP
LEVELS = [-36, -30, -24, -18, -12, -6]   # input dBFS sweep for the drive curve

# (config, drive, label, real-pedal expectation)
BATCH = [
    ("clean_boost", 50, "CleanBoost", "~no distortion, crest stays high, no sustain"),
    ("tube_screamer", 60, "TubeScreamer", "moderate soft clip, mild sustain, low grit"),
    ("ds1", 65, "DS-1", "hard clip, aggressive, some grit"),
    ("big_muff", 70, "BigMuff", "HIGH gain + HIGH sustain (sustainer), smooth (low grit)"),
    ("fuzz_face", 70, "FuzzFace", "high gain that CLEANS UP at low input, sustain, gritty/gated"),
    ("metal", 70, "Metal", "VERY high gain (MT-2), tight, dense saturation"),
    ("rat_fx", 60, "RAT", "hard clip, gritty/gnarly, mid-forward"),
]


def _render(cm, cfg, drive, x):
    return run_sim.run_dsp(SIM, measure.build_config(cm, cfg, drive, 50, 50), x, gap=GAP)


def drive_curve(cm, cfg, drive):
    """THD% + crest(dB) at each input level (1 kHz sine)."""
    rows = []
    for lv in LEVELS:
        x = sig.sine(FS, 1000, 0.10, 10 ** (lv / 20.0))
        y = _render(cm, cfg, drive, x)
        thd = harmonics.harmonic_profile(y, FS, 1000.0)["thd_pct"]
        crest = run_sim.metrics(y, FS)["crest_dB"]
        rows.append((lv, thd, crest))
    return rows


def _env_db(y, win=2048, hop=512):
    f = []
    for i in range(0, len(y) - win, hop):
        seg = y[i:i + win].astype(np.float64)
        f.append(20 * np.log10(np.sqrt(np.mean(seg * seg)) + 1.0))
    return np.array(f), hop / FS


def _decay_time(env, dt, drop=15.0):
    """Time (s) from the envelope PEAK down to (peak - drop) dB. A hard clipper
    HOLDS the note at the ceiling (flat top) then drops -- this captures that
    hold/sustain duration, which a decay-slope fit (starting below the peak)
    misses. Returns a large value if it never drops that far (fully sustained)."""
    pk = int(np.argmax(env))
    e = env[pk:] - env[pk]
    below = int(np.argmax(e <= -drop))
    if below == 0:                        # never falls `drop` dB -> fully held
        return len(e) * dt
    return below * dt


def sustain_ratio(cm, cfg, drive):
    """OUTPUT note-decay time vs INPUT's (plucked 220 Hz). >1 = the pedal HOLDS
    the note (sustainer: the clipped top stays at the ceiling as the input decays)
    -- a Big Muff/Fuzz sustains; ~1 = the output follows the input decay."""
    x = sig.decaying_sine(FS, 220, 0.8, 0.22, 0.20)
    env_in, dt = _env_db(x)
    t_in = _decay_time(env_in, dt)
    y = _render(cm, cfg, drive, x)
    env_out, _ = _env_db(y)
    t_out = _decay_time(env_out, dt)
    ratio = t_out / t_in if (t_in == t_in and t_in > 0) else float("nan")
    return ratio, t_in, t_out


def grit(cm, cfg, drive):
    """Two-tone intermodulation grit (dB rel fundamentals) + >5 kHz inharmonic
    fizz (dB rel total)."""
    f1, f2 = 1000.0, 1100.0
    x = sig.two_tone(FS, f1, f2, 0.25, 0.15)
    y = _render(cm, cfg, drive, x)
    yf = y.astype(np.float64) * np.hanning(len(y))
    spec = np.abs(np.fft.rfft(yf))
    freqs = np.fft.rfftfreq(len(y), 1.0 / FS)
    df = FS / len(y)

    def pk(f):
        k = int(round(f / df))
        return float(np.max(spec[max(0, k - 2):k + 3])) if 0 < k < len(spec) else 0.0
    fund = 0.5 * (pk(f1) + pk(f2)) + 1e-9
    imd_f = [f2 - f1, 2 * f1 - f2, 2 * f2 - f1, 3 * f1 - 2 * f2, 3 * f2 - 2 * f1,
             f1 + f2, 2 * f1 + f2]
    imd = np.sqrt(sum(pk(f) ** 2 for f in imd_f if f > 0))
    imd_db = 20 * np.log10(imd / fund + 1e-9)
    hf = freqs >= 5000
    fizz = np.sqrt(np.sum(spec[hf] ** 2))
    total = np.sqrt(np.sum(spec ** 2)) + 1e-9
    fizz_db = 20 * np.log10(fizz / total + 1e-9)
    return imd_db, fizz_db


def evaluate(cm, cfg, drive):
    dc = drive_curve(cm, cfg, drive)
    sr, _si, _so = sustain_ratio(cm, cfg, drive)
    imd_db, fizz_db = grit(cm, cfg, drive)
    return {"drive": dc, "sustain": sr, "imd_db": imd_db, "fizz_db": fizz_db}


# Amp CLEAN-mode distortion detector ("クリーンモードでも歪む" -- the issue the sim
# did NOT catch before). A high-headroom CLEAN amp (JC-120/Twin) must stay clean
# at a normal playing level; only the high-gain models break up "clean". Measures
# THD at 0.12 FS (a realistic guitar peak), amp model N in Clean mode (the
# build_config amp path = input_gain 18, drive_mode 0). ceiling = max clean THD%%.
AMP_CLEAN = [
    ("amp_0", "JC-120",     5),    # SS, huge headroom -> must be clean
    ("amp_1", "Twin",       7),    # blackface clean
    ("amp_2", "AC30",      15),    # class-A, early breakup even "clean"
    ("amp_3", "Rockerverb", 30),   # high-gain, breaks up
    ("amp_4", "JCM800",     30),   # high-gain
    ("amp_5", "TriAmp",     35),   # highest-gain
]
AMP_CLEAN_LEVEL = 0.12


def amp_clean_thd(cm, cfg):
    """Clean-mode THD at a realistic 0.12 FS / 220 Hz pluck-ish input. High = the
    amp distorts when it should be clean (power-stage softClipK ceilings + drive
    gain). Detects the 'clean mode distorts' regression."""
    x = sig.sine(FS, 220, 0.12, AMP_CLEAN_LEVEL)
    y = _render(cm, cfg, 0, x)
    return harmonics.harmonic_profile(y, FS, 220.0)["thd_pct"]


def _print(label, r, target=None):
    print("== %s ==%s" % (label, ("   target: " + target) if target else ""))
    print("  drive curve (input dBFS -> THD%% / crest dB):")
    print("    " + "  ".join("%+3d:%3.0f%%/%4.1f" % (lv, thd, cr) for lv, thd, cr in r["drive"]))
    sat = r["drive"][-1]            # loudest input
    print("  @-6dBFS in : THD %.0f%%  crest %.1f dB (%s clip)"
          % (sat[1], sat[2], "hard/square" if sat[2] < 4.5 else "soft"))
    print("  sustain    : %.2fx decay-compression (>1 = sustains; ~1 = none)"
          % r["sustain"])
    print("  grit/IMD   : %+.1f dB (two-tone intermod; higher = grittier)" % r["imd_db"])
    print("  fizz >5kHz : %+.1f dB inharmonic\n" % r["fizz_db"])


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", default="ds1")
    ap.add_argument("--drive", type=int, default=65)
    ap.add_argument("--batch", action="store_true")
    ap.add_argument("--check", action="store_true",
                    help="auto-compare each pedal's distortion CHARACTER (clip "
                         "type via crest, THD floor, sustain, Fuzz cleanup) to its "
                         "real-pedal target (targets.CLIP_TARGETS) -- PASS/FAIL, the "
                         "dist_eval analogue of measure.py --check for EQ")
    ap.add_argument("--jobs", type=int, default=min(os.cpu_count() or 1, len(BATCH)))
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()
    if args.list:
        print("pedals:", list(measure.PEDAL_BIT), "| rat_fx | od_0..5")
        return
    if not os.path.exists(SIM):
        sys.exit("build the sim first: tools/dsp_sim/build_sim.sh")
    cm = run_sim.load_control_maps()
    if args.check:
        import targets as tg
        print("auto-check vs real-pedal distortion CHARACTER (targets.CLIP_TARGETS):\n")
        with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as ex:
            res = dict(ex.map(lambda it: (it[0], evaluate(cm, it[0], it[1])), BATCH))
        npass = 0
        for cfg, drive, label, target in BATCH:
            ok, detail = tg.compare_clip(cfg, res[cfg])
            npass += int(ok)
            print("  %-4s %-12s %s" % ("PASS" if ok else "FAIL", label, detail))
        print("\n  %d/%d pedals match their real-pedal character." % (npass, len(BATCH)))
        # Amp CLEAN-mode distortion detector (the '%s' issue) -- a clean amp must
        # stay clean at a normal playing level.
        print("\n  amp CLEAN-mode distortion @%.2f FS (high-headroom amps must stay clean):"
              % AMP_CLEAN_LEVEL)
        with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as ex:
            thds = dict(ex.map(lambda it: (it[0], amp_clean_thd(cm, it[0])), AMP_CLEAN))
        cpass = 0
        for cfg, label, ceil in AMP_CLEAN:
            thd = thds[cfg]
            ok = thd <= ceil
            cpass += int(ok)
            print("  %-4s %-12s clean THD %3.0f%% (ceiling %d%%)%s"
                  % ("PASS" if ok else "FAIL", label, thd, ceil,
                     "" if ok else "  <== distorts when clean"))
        print("\n  %d/%d amps stay clean at playing level." % (cpass, len(AMP_CLEAN)))
        return
    if args.batch:
        with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as ex:
            res = dict(ex.map(lambda it: (it[2], evaluate(cm, it[0], it[1])), BATCH))
        for cfg, drive, label, target in BATCH:
            _print(label, res[label], target)
        return
    _print(args.config, evaluate(cm, args.config, args.drive))


if __name__ == "__main__":
    main()
