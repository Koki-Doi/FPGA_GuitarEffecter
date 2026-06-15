#!/usr/bin/env python3
"""Machine-readable real-hardware voicing TARGETS + an auto-comparator.

The realism re-collation (D121-D131) compared each model's measured curve to the
SPECIFIC real pedal/amp by EYE -- which let the Metal model ship sounding nothing
like an MT-2 (I read the harmonic series, not the EQ). This module encodes the
documented real-hardware feature of each model (the mid peak/scoop frequency, and
whether it should be bass-light or full) so `measure.py --check` can diff the sim
against it AUTOMATICALLY and flag deviations -- no more eyeballing / over-claiming.

Each target: ``mid=(kind, f0_hz, tol_hz)`` where kind is "peak"/"scoop"/"flat",
and optional ``low_vs_mid=(dB, rel)`` rel in {">", "<", "~"} (the absolute
low(40-160)-minus-mid(500-1.5k) balance, the bass-light check). Sources are the
ElectroSmash circuit analyses + the per-model re-collations recorded in
docs/ai_context/CURRENT_STATE.md (D129/D130/D131).
"""

# name -> dict(label, mid=(kind,f0,tol), low_vs_mid=(dB,rel) or None, src)
TARGETS = {
    "od_0":        dict(label="TS9",       mid=("peak", 720, 180),  low_vs_mid=None,
                        src="ElectroSmash: tone/clip LPF ~723 Hz mid hump"),
    "od_1":        dict(label="OD-1",      mid=("peak", 800, 250),  low_vs_mid=None,
                        src="significant mid hump, asym clip (D129)"),
    "od_2":        dict(label="BD-2",      mid=("peak", 2300, 600), low_vs_mid=None,
                        src="bright upper-mid, ~flat at noon (D129)"),
    "od_3":        dict(label="JanRay",    mid=("peak", 350, 250),  low_vs_mid=None,
                        src="transparent + slight low-mid warmth (D129)"),
    "od_4":        dict(label="OCD",       mid=("peak", 1300, 350), low_vs_mid=None,
                        src="upper-mid honk (MOSFET)"),
    "od_5":        dict(label="Klon",      mid=("peak", 1000, 300), low_vs_mid=None,
                        src="ElectroSmash: ~1 kHz mid bump signature (D129)"),
    "clean_boost": dict(label="CleanBoost", mid=("flat", 0, 0),     low_vs_mid=("~", 0, 4),
                        src="flat boost"),
    "tube_screamer": dict(label="TScreamer", mid=("peak", 720, 180), low_vs_mid=None,
                        src="ElectroSmash: 720 Hz mid hump + low cut"),
    "ds1":         dict(label="DS-1",      mid=("scoop", 500, 250), low_vs_mid=None,
                        src="ElectroSmash: Big-Muff-style tone scoop ~500 Hz (D129)"),
    "big_muff":    dict(label="BigMuff",   mid=("scoop", 1000, 300), low_vs_mid=(">", 3),
                        src="ElectroSmash: ~1 kHz scoop + accentuated lows (D131)"),
    "fuzz_face":   dict(label="FuzzFace",  mid=("flat", 0, 0),      low_vs_mid=("~", 0, 5),
                        src="warm/full, dynamic bias"),
    "metal":       dict(label="Metal",     mid=("peak", 800, 300),  low_vs_mid=(">", -16),
                        src="Boss MT-2: ~800 Hz mid boost, dark >1k, NOT gutted lows (D131)"),
    "rat_fx":      dict(label="RAT",       mid=("peak", 1000, 350), low_vs_mid=None,
                        src="ElectroSmash: ~1 kHz mid-forward, LM308 dark top (D124)"),
}


def _mid_feature(net, freqs, lo=250, hi=2500):
    """Dominant peak/scoop of a median-removed curve in the mid band: returns
    (kind, f0, dB)."""
    m = (freqs >= lo) & (freqs <= hi)
    sub, fsub = net[m], freqs[m]
    pk, dp = int(sub.argmax()), int(sub.argmin())
    if abs(sub[pk]) >= abs(sub[dp]):
        return "peak", int(fsub[pk]), float(sub[pk])
    return "scoop", int(fsub[dp]), float(sub[dp])


def compare(name, absnet, freqs, band_balance):
    """absnet = ABSOLUTE net curve vs bypass; band_balance = measure.band_balance.
    Returns (ok: bool, detail: str)."""
    t = TARGETS.get(name)
    if t is None:
        return True, "no target"
    np = __import__("numpy")
    net = absnet - np.median(absnet)                       # shape for the mid feature
    tk, tf, tol = t["mid"]
    msgs = []
    ok = True
    if tk == "flat":
        kind, f0, depth = _mid_feature(net, freqs)
        if abs(depth) > 3.0:
            ok = False
            msgs.append("expected ~flat mid, got %s %+.1fdB@%dHz" % (kind, depth, f0))
    else:
        # check the feature AT the target frequency (robust to OTHER features a
        # multi-feature pedal also has, e.g. the DS-1's bright top on top of its
        # 500 Hz scoop): the median-removed curve, averaged in a +/-tol window,
        # should be a clear peak (>0) or scoop (<0).
        m = (freqs >= tf - tol) & (freqs <= tf + tol)
        val = float(np.mean(net[m])) if m.any() else 0.0
        if tk == "peak" and val < 0.8:
            ok = False; msgs.append("no peak @%d (val %+.1f dB)" % (tf, val))
        elif tk == "scoop" and val > -0.8:
            ok = False; msgs.append("no scoop @%d (val %+.1f dB)" % (tf, val))
        else:
            msgs.append("%s@%d %+.1f dB OK" % (tk, tf, val))
    lvm = t["low_vs_mid"]
    if lvm is not None:
        bal = band_balance["low_vs_mid"]
        rel, db = lvm[0], lvm[1]
        tol = lvm[2] if len(lvm) > 2 else 0
        if rel == ">" and bal < db:
            ok = False; msgs.append("low_vs_mid %+.1f < target >%+.1f (too thin)" % (bal, db))
        elif rel == "<" and bal > db:
            ok = False; msgs.append("low_vs_mid %+.1f > target <%+.1f" % (bal, db))
        elif rel == "~" and abs(bal - db) > tol:
            ok = False; msgs.append("low_vs_mid %+.1f off ~%+.1f" % (bal, db))
        else:
            msgs.append("low_vs_mid %+.1f OK" % bal)
    return ok, "; ".join(msgs)
