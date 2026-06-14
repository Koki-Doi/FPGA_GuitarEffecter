#!/usr/bin/env python3
"""Harmonic / spectral metrics for realism voicing (work order step 3).

The OD / Distortion / Amp target metrics in REALISM_IMPROVEMENT_WORK_ORDER.md
(fundamental gain, 2nd/3rd/5th harmonic, odd/even ratio, THD, alias / non-harmonic
energy) need a single-sine harmonic analysis that the existing harness did not
have (measure.py does net frequency shaping vs bypass; run_sim.py does
RMS/peak/crest/centroid/clip_count). This module adds the missing piece.

Pure numpy analysis (no sim dependency) so it is testable without the Clash
binary; a thin CLI runs a config from measure.py through the DSP on a 1 kHz
sine and prints the profile.

  python3 tools/dsp_sim/harmonics.py --config ds1 --drive 65
  python3 tools/dsp_sim/harmonics.py --config od_0 --drive 60 --f0 1000
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run_sim  # noqa: E402
import signals as sig  # noqa: E402

FS24 = run_sim.FS24


def _bin_peak(spec, k, half=2):
    lo = max(0, k - half)
    return float(np.max(spec[lo:k + half + 1]))


def harmonic_profile(y, fs, f0, n_harm=8):
    """Single-sine harmonic profile.

    Returns dict: fundamental_dBFS, h2..hN (dB rel fundamental), thd_pct,
    odd_even_ratio_dB, harmonic_energy_dBFS, nonharmonic_dBFS (alias / IMD /
    noise proxy = energy outside DC + harmonic bins).
    """
    y = y.astype(np.float64)
    n = len(y)
    w = np.hanning(n)
    spec = np.abs(np.fft.rfft(y * w))
    df = fs / n
    full = float(np.sum(spec ** 2)) + 1e-9

    harm_k = [int(round(h * f0 / df)) for h in range(1, n_harm + 1)]
    harm_k = [k for k in harm_k if k < len(spec)]
    h = np.array([_bin_peak(spec, k) for k in harm_k])
    fund = h[0] + 1e-9

    # energy bookkeeping: subtract DC + harmonic bins (+/-2) from total
    used = np.zeros(len(spec), dtype=bool)
    used[0:3] = True                                   # DC region
    for k in harm_k:
        used[max(0, k - 2):k + 3] = True
    harm_energy = float(np.sum(spec[used] ** 2)) + 1e-9
    nonharm_energy = full - harm_energy

    odd = float(np.sum(h[2::2] ** 2))                  # h3,h5,h7 (index 2,4,6)
    even = float(np.sum(h[1::2] ** 2)) + 1e-9          # h2,h4,h6
    thd = float(np.sqrt(np.sum(h[1:] ** 2)) / fund)

    out = {
        "fundamental_dBFS": 20 * np.log10(fund / FS24),
        "thd_pct": 100.0 * thd,
        "odd_even_ratio_dB": 10 * np.log10((odd + 1e-9) / even),
        "harmonic_energy_dBFS": 10 * np.log10(harm_energy / FS24 ** 2),
        "nonharmonic_dBFS": 10 * np.log10(max(nonharm_energy, 1e-9) / FS24 ** 2),
    }
    for i, hv in enumerate(h[1:], start=2):
        out["h%d_dB" % i] = 20 * np.log10((hv + 1e-9) / fund)
    return out


def band_energy_db(y, fs, lo, hi):
    """Integrated magnitude (dBFS) in [lo, hi) Hz -- for Cab band readouts
    (low bump / 2-4 kHz presence / 8-12 kHz fizz)."""
    y = y.astype(np.float64)
    n = len(y)
    spec = np.abs(np.fft.rfft(y * np.hanning(n)))
    freqs = np.fft.rfftfreq(n, 1.0 / fs)
    m = (freqs >= lo) & (freqs < hi)
    e = float(np.sum(spec[m] ** 2)) + 1e-9
    return 10 * np.log10(e / FS24 ** 2)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", default="ds1", help="measure.py config (od_0..5, pedal, rat_fx, amp_0..5, cab, bypass)")
    ap.add_argument("--drive", type=int, default=60)
    ap.add_argument("--f0", type=float, default=1000.0)
    ap.add_argument("--fs", type=int, default=sig.FS_DEFAULT)
    ap.add_argument("--level", type=float, default=sig.DRIVE)
    ap.add_argument("--seconds", type=float, default=0.25)
    args = ap.parse_args()
    if not os.path.exists(run_sim.SIM_BIN_DEFAULT):
        sys.exit("build the sim first: tools/dsp_sim/build_sim.sh")
    import measure  # noqa: E402  (build_config)
    cm = run_sim.load_control_maps()
    x = sig.sine(args.fs, args.f0, args.seconds, args.level)
    words = measure.build_config(cm, args.config, args.drive, 50, 50)
    y = run_sim.run_dsp(run_sim.SIM_BIN_DEFAULT, words, x, gap=run_sim.GAP)
    prof = harmonic_profile(y, args.fs, args.f0)
    m = run_sim.metrics(y, args.fs)
    print("config=%s drive=%d f0=%.0f level=%.2f" % (args.config, args.drive, args.f0, args.level))
    print("  fundamental %+.1f dBFS | THD %.1f%% | odd/even %+.1f dB" %
          (prof["fundamental_dBFS"], prof["thd_pct"], prof["odd_even_ratio_dB"]))
    print("  harmonics (dB rel fund): " +
          " ".join("h%d %+.1f" % (i, prof["h%d_dB" % i]) for i in range(2, 9)))
    print("  nonharmonic(alias/IMD) %+.1f dBFS | harmonic %+.1f dBFS" %
          (prof["nonharmonic_dBFS"], prof["harmonic_energy_dBFS"]))
    print("  peak %+.1f rms %+.1f crest %.1f clip %d" %
          (m["peak_dBFS"], m["rms_dBFS"], m["crest_dB"], m["clip_count"]))


if __name__ == "__main__":
    main()
