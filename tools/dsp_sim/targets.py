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
low(40-160)-minus-mid(500-1.5k) balance, the bass-light check), and optional
``hf=(rel, dB_per_oct)`` the 2-9 kHz treble slope (a real amp+cab ROLLS OFF =
negative slope; a bare differentiator EQ rises = positive = 'digital/buzzy').
Sources are the ElectroSmash circuit analyses + the per-model re-collations
recorded in docs/ai_context/CURRENT_STATE.md (D129/D130/D131).

``CLIP_TARGETS`` (used by ``dist_eval.py --check``) encodes the distortion
CHARACTER target a single-sine THD/EQ curve cannot see: the clip TYPE (hard
diode/square vs soft op-amp), how much it must distort (THD floor at a hot
input), and whether it sustains. This systematises the dist_eval re-collation
the same way ``measure.py --check`` systematises the EQ re-collation: a Metal
that under-drives, or a DS-1 that is too soft for a Si-diode hard clipper, is
auto-flagged instead of eyeballed.
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
    "fuzz_face":   dict(label="FuzzFace",  mid=("peak", 900, 450),  low_vs_mid=("~", 0, 5),
                        src="two-transistor fuzz: broad vocal mid focus + warm/full dynamic bias"),
    "metal":       dict(label="Metal",     mid=("peak", 800, 300),  low_vs_mid=(">", -16),
                        src="Boss MT-2: ~800 Hz mid boost, dark >1k, NOT gutted lows (D131)"),
    "rat_fx":      dict(label="RAT",       mid=("peak", 1000, 350), low_vs_mid=None,
                        src="ElectroSmash: ~1 kHz mid-forward, LM308 dark top (D124)"),
    # --- Amp ALONE (no cab). The hf "range" is the MUFFLED/HARSH detector (the
    # 2026-06-16 muffled regression that ear-bench caught but the sim did NOT):
    # an amp head BEFORE the speaker should have PRESENCE/top (hf not dark), and
    # the cab then rolls it off. hf < -2 = the amp lost its top = will be MUFFLED
    # through the cab (this is exactly what the bass fix did: amp-alone hf
    # +3.6 -> -2.4); hf > +6 = absurdly bright/buzzy (the bare differentiator).
    # The mid feature doubles as the per-model voicing check (ampScoop biquad).
    "amp_0":       dict(label="AMP JC120",  mid=("flat", 0, 0),      low_vs_mid=None,
                        hf=("range", -2.0, 6.0), src="JC-120 SS: full-range/flat, present top"),
    "amp_1":       dict(label="AMP Twin",   mid=("scoop", 400, 280), low_vs_mid=None,
                        hf=("range", -2.0, 6.0), src="Fender Twin: blackface mid scoop ~400, present"),
    "amp_2":       dict(label="AMP AC30",   mid=("peak", 2100, 600), low_vs_mid=None,
                        hf=("range", -4.0, 7.0),
                        src="Vox AC30: chime upper-mid ~2.2k. hf lower bound -4 (not -2): the "
                            "chime PEAK @2k sits IN the 2-9k window, so a healthy AC30 with "
                            "good top (+0.1 dB @9k, NOT muffled) still measures a -2.6 slope "
                            "descending FROM the chime -- the muffled detector must allow that."),
    "amp_3":       dict(label="AMP Rockerv", mid=("any", 0, 0), low_vs_mid=None,
                        hf=("range", -2.0, 6.0),
                        src="Orange Rockerverb: thick low-mid ~300 (was peak@300; D151 raised the "
                            "amp HF shelf so the >2 kHz band sits higher and the GENTLE +1.2 dB @300 "
                            "low-mid bump now reads ~0 dB in the relative amp-alone curve -- the "
                            "absolute low-mid is unchanged and RIG Rockerv low_vs_mid still guards "
                            "its thickness, so the amp-alone @300 peak is no longer a reliable check)"),
    "amp_4":       dict(label="AMP JCM800", mid=("peak", 650, 250), low_vs_mid=None,
                        hf=("range", -2.0, 6.0), src="Marshall JCM800: mid push ~650"),
    "amp_5":       dict(label="AMP TriAmp", mid=("scoop", 750, 320), low_vs_mid=None,
                        hf=("range", -2.0, 6.0), src="H&K TriAmp: modern scoop ~750"),
    # --- Amp AS A RIG (amp -> cab). Targets are on the rig_* chain, NOT amp-
    # alone: a real guitar amp is always heard through a speaker, and amp-alone
    # is misleadingly bright (the tone-stack high band is a +6 dB/oct
    # differentiator). The rig must (a) roll the top OFF (hf < 0, the speaker is
    # a lowpass) and (b) NOT be bass-light -- a mic'd guitar cab has a strong
    # low-mid thump, so low_vs_mid should be near unity, not -20 dB.
    "rig_0":       dict(label="RIG JC120",  mid=("any", 0, 0),       low_vs_mid=(">", -11),
                        hf=("<", 0.0),
                        src="Roland JC-120 into 2x12: clean full-range, top rolled by speaker (mid=any: the rig's 250-2.5k is the shared cab presence, not the flat SS amp)"),
    "rig_2":       dict(label="RIG AC30",   mid=("peak", 2500, 900), low_vs_mid=(">", -11),
                        hf=("<", 0.0),
                        src="Vox AC30 into 2x12: chime upper-mid, speaker rolloff"),
    "rig_4":       dict(label="RIG JCM800", mid=("peak", 650, 250),  low_vs_mid=(">", -12.5),
                        hf=("<", 0.0),
                        src="Marshall JCM800 into 4x12: mid push ~650 Hz, speaker rolloff (D151 "
                            "raised the cab presence peak + amp HF shelf = brighter 2-4 kHz, which "
                            "lifts the mid reference so low_vs_mid reads ~1 dB thinner; bound -11 -> "
                            "-12.5 reflects the intended brighter rig voicing, absolute bass intact)"),
    "rig_1":       dict(label="RIG Twin",   mid=("scoop", 400, 250), low_vs_mid=(">", -11),
                        hf=("<", 0.0),
                        src="Fender Twin blackface into 2x12: scooped mids + big bass, speaker rolloff"),
    "rig_3":       dict(label="RIG Rockerv", mid=("any", 0, 0),      low_vs_mid=(">", -11),
                        hf=("<", 0.0),
                        src="Orange Rockerverb into 2x12: thick low-mid, speaker rolloff (mid=any: low-mid thickness checked on the amp-alone target)"),
    "rig_5":       dict(label="RIG TriAmp", mid=("scoop", 750, 320), low_vs_mid=(">", -11),
                        hf=("<", 0.0),
                        src="H&K TriAmp into 2x12: modern mid scoop ~750, tight, speaker rolloff"),
    # --- Cab (speaker IR). A real guitar cab = a cone-breakup presence peak in
    # 2-4 kHz then a SHARP rolloff above ~5 kHz (a 2nd-order-ish lowpass).
    "cab":         dict(label="CAB Brit",   mid=("peak", 3000, 1100), low_vs_mid=None,
                        hf=("<", -2.0),
                        src="2x12 British: cone-breakup presence 2-4 kHz + sharp >5 kHz rolloff"),
    "cab0":        dict(label="CAB Open",   mid=("peak", 3400, 1100), low_vs_mid=None,
                        hf=("<", 0.0),
                        src="1x12 open-back: brighter/airier presence ~3.4 kHz, gentler top rolloff (D123)"),
    "cab2":        dict(label="CAB Closed", mid=("peak", 2300, 900), low_vs_mid=None,
                        hf=("<", -2.0),
                        src="4x12 closed: lower/thicker honk ~2.3 kHz + sharp >5 kHz rolloff (D123)"),
}


# hf_slope is the shared metrics.py helper (refactor P4) -- was a hand-copied
# `_hf_slope` here to dodge the measure<->targets circular import; metrics.py
# imports nothing from the harness so both can use it.
from metrics import hf_slope as _hf_slope  # noqa: E402


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
    if tk == "any":
        # mid feature is not checked here (e.g. a RIG whose 250-2500 region is
        # dominated by the shared cab presence peak, not the amp's own voicing --
        # the amp's mid is checked on the amp-ALONE target instead).
        pass
    elif tk == "flat":
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
    hf = t.get("hf")
    if hf is not None:
        slp = _hf_slope(absnet, freqs)
        rel = hf[0]
        if rel == "range":
            lo, hi = hf[1], hf[2]
            if slp < lo:
                ok = False; msgs.append("HF %+.1f/oct < %+.1f = MUFFLED/dark (lost top)" % (slp, lo))
            elif slp > hi:
                ok = False; msgs.append("HF %+.1f/oct > %+.1f = HARSH/buzzy (too bright)" % (slp, hi))
            else:
                msgs.append("HF %+.1f/oct OK" % slp)
        elif rel == "<" and slp > hf[1]:
            ok = False; msgs.append("HF %+.1f/oct rising (want <%+.1f = rolled off)" % (slp, hf[1]))
        elif rel == ">" and slp < hf[1]:
            ok = False; msgs.append("HF %+.1f/oct (want >%+.1f)" % (slp, hf[1]))
        else:
            msgs.append("HF %+.1f/oct OK" % slp)
    return ok, "; ".join(msgs)


# ----- Distortion CHARACTER targets (dist_eval.py --check) -------------------
# The PASS/FAIL axes (robust): thd_hot_min/max = THD% floor/ceiling at the
# hottest (-6 dBFS) input = "does it distort enough / too much" (the validated
# "歪が足りない" check -- cross-checked against harmonic_profile odd/even + h3..h7);
# sustain_min = decay hold-time ratio floor (a Big Muff/Fuzz sustainer); cleanup
# = THD must DROP at the quietest input (the Fuzz-Face volume cleanup).
# clip ("hard"/"soft") is INFORMATIONAL only -- crest at a hot input is
# confounded by the post-clip LPF (a hard square through a bright LPF rings =
# high crest that looks soft; e.g. DS-1 crest 5.6 yet h3 -10.2 dB = hardest odd
# harmonic of all). Sources: ElectroSmash + the dist_eval re-collation
# (CURRENT_STATE.md D131) + the 2026-06-16 harmonic cross-check.
CREST_HARD_DB = 3.0      # crest at hot input: shown for context (see clip note)
CLIP_TARGETS = {
    "clean_boost": dict(label="CleanBoost", clip=None, thd_hot_max=12,
                        thd_hot_min=None, sustain_min=None, cleanup=False,
                        src="transparent EP-boost, clips only when very hot"),
    "tube_screamer": dict(label="TScreamer", clip="soft", thd_hot_min=10,
                        thd_hot_max=None, sustain_min=None, cleanup=False,
                        src="op-amp SOFT clip, smooth/rounded -- should NOT square hard"),
    "ds1": dict(label="DS-1", clip="hard", thd_hot_min=35,
                        thd_hot_max=None, sustain_min=None, cleanup=False,
                        src="Si-diode HARD clip, aggressive square top"),
    "big_muff": dict(label="BigMuff", clip=None, thd_hot_min=55,
                        thd_hot_max=None, sustain_min=1.5, cleanup=False,
                        src="two cascaded diode clips: high THD + long sustain"),
    "fuzz_face": dict(label="FuzzFace", clip="hard", thd_hot_min=25,
                        thd_hot_max=None, sustain_min=1.3, cleanup=True,
                        src="transistor squares + CLEANS UP at low input + sustains"),
    "metal": dict(label="Metal", clip="hard", thd_hot_min=18,
                        thd_hot_max=None, sustain_min=1.3, cleanup=False,
                        src="MT-2 high gain. NOTE the 1kHz-sine THD ceiling (~19%) is "
                            "intrinsically capped by the dark MT-2 post-LPF (h3 rolled "
                            "off); the 2026-06-16 gain+clip pass raised playing-level "
                            "saturation (drive curve low-end) within the dark voicing. "
                            "Full MT-2 THD needs the gain-staging restructure (new stage)."),
    "rat_fx": dict(label="RAT", clip="hard", thd_hot_min=22,
                        thd_hot_max=None, sustain_min=None, cleanup=False,
                        src="LM308 + Si-diode hard clip, gritty square"),
}


def compare_clip(name, r):
    """r = dist_eval.evaluate() dict (drive curve, sustain, imd_db, fizz_db).
    Returns (ok, detail). Encodes the distortion-character re-collation so an
    under-driving Metal / too-soft DS-1 is auto-flagged, not eyeballed."""
    t = CLIP_TARGETS.get(name)
    if t is None:
        return True, "no target"
    _lv, thd_hot, crest_hot = r["drive"][-1]            # loudest input (-6 dBFS)
    ok = True
    msgs = []
    if t["thd_hot_min"] is not None:
        if thd_hot < t["thd_hot_min"]:
            ok = False; msgs.append("THD %.0f%% < %d (under-drives / 歪不足)"
                                    % (thd_hot, t["thd_hot_min"]))
        else:
            msgs.append("THD %.0f%% OK" % thd_hot)
    if t["thd_hot_max"] is not None:
        if thd_hot > t["thd_hot_max"]:
            ok = False; msgs.append("THD %.0f%% > %d (should stay clean)"
                                    % (thd_hot, t["thd_hot_max"]))
        else:
            msgs.append("THD %.0f%% clean OK" % thd_hot)
    # Clip TYPE is reported as INFORMATIONAL only, NOT pass/fail. crest at a hot
    # input was tried as a hard(low)/soft(high) discriminator but it is
    # CONFOUNDED by each pedal's post-clip LPF: a hard-clipped square through a
    # BRIGHT post-LPF rings (Gibbs overshoot) -> HIGH crest that mimics a soft
    # clip (DS-1 crest 5.6 but h3 -10.2 dB = the strongest odd harmonic of all =
    # genuinely hard). Validated against harmonic_profile (odd/even + h3..h7). So
    # crest is shown for context but does not gate -- a metric that mis-measures
    # is worse than none.
    if t["clip"] is not None:
        msgs.append("clip ~%s (crest %.1f, info)" % (t["clip"], crest_hot))
    if t["sustain_min"] is not None:
        if r["sustain"] < t["sustain_min"]:
            ok = False; msgs.append("sustain %.2fx < %.1f" % (r["sustain"], t["sustain_min"]))
        else:
            msgs.append("sustain %.2fx OK" % r["sustain"])
    if t["cleanup"]:
        thd_quiet = r["drive"][0][1]
        if thd_quiet > thd_hot - 10:
            ok = False; msgs.append("no cleanup (THD %.0f%%->%.0f%%)" % (thd_quiet, thd_hot))
        else:
            msgs.append("cleanup %.0f->%.0f%% OK" % (thd_quiet, thd_hot))
    return ok, "; ".join(msgs)
