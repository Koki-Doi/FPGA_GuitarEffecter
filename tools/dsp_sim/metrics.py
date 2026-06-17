#!/usr/bin/env python3
"""Shared spectral / band measurement helpers for the dsp_sim harness.

Extracted (refactor P4, 2026-06-17) so `measure.py` and `targets.py` use ONE
copy instead of `measure.hf_slope` + a hand-copied `targets._hf_slope` (the copy
existed only to dodge a circular import: measure imports targets). This module
imports nothing from the harness, so both can import it freely.
"""
import numpy as np

FS24 = 1 << 23

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


def rms_dbfs(x, floor=1.0):
    """RMS level in dBFS for signed-24 samples."""
    x = np.asarray(x, dtype=np.float64)
    if x.size == 0:
        return float("-inf")
    rms = np.sqrt(np.mean(x * x)) + floor
    return float(20.0 * np.log10(rms / FS24))


def peak_dbfs(x, floor=1.0):
    """Peak level in dBFS for signed-24 samples."""
    x = np.asarray(x, dtype=np.float64)
    if x.size == 0:
        return float("-inf")
    peak = np.max(np.abs(x)) + floor
    return float(20.0 * np.log10(peak / FS24))


def crest_db(x):
    """Peak/RMS crest factor in dB."""
    x = np.asarray(x, dtype=np.float64)
    if x.size == 0:
        return float("nan")
    peak = np.max(np.abs(x)) + 1.0
    rms = np.sqrt(np.mean(x * x)) + 1.0
    return float(20.0 * np.log10(peak / rms))


def clip_count(x):
    """Number of samples at signed-24 full-scale."""
    x = np.asarray(x)
    return int(np.sum(np.abs(x) >= FS24 - 1))


def window_dbfs(x, fs, start_s, end_s=None):
    """RMS dBFS for a time window."""
    start = max(0, int(round(start_s * fs)))
    end = len(x) if end_s is None else max(start, int(round(end_s * fs)))
    return rms_dbfs(np.asarray(x)[start:end])


def band_levels_db(y, fs, bands):
    """Integrated power per band in dBFS-like units.

    This is intended for *differences* between two renders, so exact FFT window
    normalisation is less important than stable, finite numbers.
    """
    y = np.asarray(y, dtype=np.float64)
    if y.size == 0:
        return np.array([float("-inf") for _ in bands])
    p = np.abs(np.fft.rfft(y * np.hanning(len(y)))) ** 2
    freqs = np.fft.rfftfreq(len(y), 1.0 / fs)
    out = []
    for _name, lo, hi in bands:
        m = (freqs >= lo) & (freqs < hi)
        e = float(np.sum(p[m])) / (FS24 ** 2) + 1e-12
        out.append(10.0 * np.log10(e))
    return np.array(out)


def spectral_centroid_hz(y, fs, lo=None, hi=None):
    """Spectral centroid in Hz, optionally inside a frequency range."""
    y = np.asarray(y, dtype=np.float64)
    if y.size == 0:
        return float("nan")
    spec = np.abs(np.fft.rfft(y * np.hanning(len(y))))
    freqs = np.fft.rfftfreq(len(y), 1.0 / fs)
    if lo is not None or hi is not None:
        lo = 0.0 if lo is None else lo
        hi = fs / 2.0 if hi is None else hi
        m = (freqs >= lo) & (freqs <= hi)
        spec, freqs = spec[m], freqs[m]
    return float(np.sum(freqs * spec) / (np.sum(spec) + 1e-9))


def peak_frequency_hz(y, fs, lo, hi):
    """Dominant spectral peak frequency in [lo, hi]."""
    y = np.asarray(y, dtype=np.float64)
    if y.size == 0:
        return float("nan"), float("-inf")
    spec = np.abs(np.fft.rfft(y * np.hanning(len(y))))
    freqs = np.fft.rfftfreq(len(y), 1.0 / fs)
    m = (freqs >= lo) & (freqs <= hi)
    if not m.any():
        return float("nan"), float("-inf")
    idx = int(np.argmax(spec[m]))
    sub_freqs = freqs[m]
    sub_spec = spec[m]
    return float(sub_freqs[idx]), float(20.0 * np.log10((sub_spec[idx] + 1.0) / FS24))


def is_strictly_rising(values, min_step=0.0):
    """True when every successive value rises by at least ``min_step``."""
    return all((b - a) >= min_step for a, b in zip(values, values[1:]))
