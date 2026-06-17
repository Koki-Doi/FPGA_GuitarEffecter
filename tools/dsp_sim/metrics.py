#!/usr/bin/env python3
"""Shared spectral / band measurement helpers for the dsp_sim harness.

Extracted (refactor P4, 2026-06-17) so `measure.py` and `targets.py` use ONE
copy instead of `measure.hf_slope` + a hand-copied `targets._hf_slope` (the copy
existed only to dodge a circular import: measure imports targets). This module
imports nothing from the harness, so both can import it freely.
"""
import numpy as np

# Guitar-relevant bands for the low-end / balance summary. LOW covers below the
# low-E (82 Hz) down to drop tunings (~62 Hz) so a thin-bass pedal is visible.
BANDS_HZ = [("low", 40, 160), ("lowmid", 160, 500), ("mid", 500, 1500),
            ("high", 1500, 9000)]


def band_balance(net, freqs):
    """Average dB in each guitar band (low/lowmid/mid/high) from an ABSOLUTE
    net curve, plus the low-vs-mid balance (negative = bass-light = thin)."""
    out = {}
    for name, lo, hi in BANDS_HZ:
        m = (freqs >= lo) & (freqs < hi)
        out[name] = float(np.mean(net[m])) if m.any() else float("nan")
    out["low_vs_mid"] = out["low"] - out["mid"]
    return out


def hf_slope(net, freqs, lo=2000, hi=9000):
    """Treble slope in dB/OCTAVE across [lo, hi] of an ABSOLUTE net curve -- the
    brightness / 'digital fizz' axis a single mid-feature misses. A real guitar
    amp+cab rolls the top OFF (strongly negative slope, the speaker is a
    ~2nd-order lowpass above ~4-5 kHz); a bare op-amp/differentiator EQ RISES
    (positive). The single number that separates 'sounds like a rig' from
    'sounds like a buzzy DI'."""
    m = (freqs >= lo) & (freqs <= hi)
    if m.sum() < 2:
        return float("nan")
    x = np.log2(freqs[m].astype(np.float64))      # octaves
    return float(np.polyfit(x - x.mean(), net[m], 1)[0])  # dB per octave
