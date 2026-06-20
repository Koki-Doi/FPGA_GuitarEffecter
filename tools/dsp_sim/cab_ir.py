#!/usr/bin/env python3
"""Cab real-IR (R4 step B) offline DESIGN + VALIDATION tool -- sim-first.

The biggest remaining cab realism lever (REAL_HARDWARE_FIDELITY_ROADMAP.md R4):
the shipping cab linear voicing is a 15-tap symmetric speaker FIR
(`cabSpeakerFirCoeff`) cascaded with a per-model presence biquad
(`cabPresenceFFCoeff`/`cabPresenceFBCoeff`). 15 taps cannot make the SHARP
>5 kHz rolloff of a real guitar cab (it measures ~-5.5 dB/oct over 2-9 kHz; a
real 4x12 rolls off ~-12..-24 dB/oct above 5 kHz) and the peak/rolloff are two
separate stages. R4 step B replaces BOTH with ONE real 128-tap IR per model.

This tool is the *design* half of the sim-first phase: it has NO Clash/Vivado
dependency. It

  1. builds a hand-drawn per-model magnitude target (open 1x12 / british 2x12 /
     closed 4x12) -- our OWN target curve, not a captured commercial IR (D7),
  2. generates a 128-tap linear-phase FIR by windowed frequency sampling,
  3. quantizes to Signed-16 fixed point with a unity-DC sum of 2^16 (peak tap
     ~12160 needs 15 bits, S16 fits with margin and packs into a 16-bit BRAM
     word; one Zynq-7 DSP48 25x18 MAC per tap, output >> 16),
  4. validates each model against the cab targets in `targets.py` using the SAME
     comparator the board voicing uses (`targets.compare`), reports the headline
     >5 kHz rolloff slope, the presence-peak frequency, the latency, and the
     fixed-point quantization SNR, and
  5. A/B's the design against the CURRENT shipping linear voicing (15-tap FIR +
     presence biquad reconstructed from the Clash coefficients).

The IR replaces ONLY the linear post-voicing; the accepted nonlinear 4-tap cab
core (cabProductsFrame/cabSat/cabIr/cabLevelMix) is untouched, so the IR target
is flat (0 dB) through the lows/mids and carries only the presence peak + the
sharp HF rolloff -- an apples-to-apples swap on the same spectral axis.

Usage:
  python3 tools/dsp_sim/cab_ir.py              # design + validate + A/B table
  python3 tools/dsp_sim/cab_ir.py --check      # exit non-zero if any model FAILs
  python3 tools/dsp_sim/cab_ir.py --emit-clash # print ready-to-paste Vec 128 tables
  python3 tools/dsp_sim/cab_ir.py --taps 128 --bits 18 --window hamming
"""

import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import targets as targets_mod  # noqa: E402
from metrics import band_balance, hf_slope  # noqa: E402

FS = 96000                      # D98 sample rate
FS24 = 1 << 23                  # 24-bit full scale (unused here but the convention)
NFFT = 8192                     # design / analysis FFT length

# Measurement grid identical to measure.py (40 Hz .. 9 kHz, 30 log bins) so the
# IR is validated on the exact freqs targets.compare expects.
MEAS_FREQS = np.round(np.logspace(np.log10(40), np.log10(9000), 30)).astype(int)

MODELS = [
    # (clash model index >> 6, target key, label, magnitude breakpoints)
    (0, "cab0", "open 1x12"),
    (1, "cab",  "british 2x12"),
    (2, "cab2", "closed 4x12"),
]

# --- Hand-drawn magnitude targets (freq Hz, gain dB), log-freq interpolated. ---
# Passband 0 dB (the nonlinear core owns the absolute low end); a cone-breakup
# presence peak; then a sharp speaker rolloff. open = brightest/gentlest,
# closed = darkest/sharpest. Designed to land each model's presence freq inside
# the targets.py window (open 3400, brit 3000, closed 2300 Hz) and to push the
# 5-12 kHz rolloff far past what 15 taps can do.
TARGET_MAG_DB = {
    0: [  # open 1x12: bright/airy, gentle top
        (40, 0.0), (200, 0.0), (800, 0.0), (1800, 0.6),
        (3400, 3.0), (4800, 0.5), (6000, -3.5), (8000, -9.0),
        (10000, -16.0), (12000, -22.0), (16000, -30.0), (48000, -42.0),
    ],
    1: [  # british 2x12: mid-forward, sharp top
        (40, 0.0), (200, 0.0), (700, 0.0), (1500, 0.8),
        (3000, 3.5), (4200, 0.0), (5000, -4.0), (7000, -13.0),
        (9000, -22.0), (12000, -32.0), (16000, -44.0), (48000, -56.0),
    ],
    2: [  # closed 4x12: thick/dark, sharpest top
        (40, 0.0), (200, 0.0), (600, 0.0), (1200, 0.8),
        (2300, 4.0), (3400, 1.0), (4500, -5.0), (6000, -16.0),
        (8000, -27.0), (10000, -36.0), (14000, -50.0), (48000, -64.0),
    ],
}


# Rolloff-only targets (Option Y): flat passband + the SAME per-model HF rolloff,
# but NO presence bump -- for the design where a longer FIR supplies ONLY the
# sharp >5 kHz rolloff and the EXISTING per-model presence biquad keeps making
# the 2-4 kHz peak. The minimal-risk step: it needs far fewer taps (a pure
# lowpass resolves at ~23-31 taps; resolving the Q~1 presence peak needs ~95).
TARGET_MAG_DB_ROLLOFF = {
    0: [(40, 0.0), (3000, 0.0), (5000, -1.0), (6000, -3.5), (8000, -9.0),
        (10000, -16.0), (12000, -22.0), (16000, -30.0), (48000, -42.0)],
    1: [(40, 0.0), (2800, 0.0), (4200, -0.5), (5000, -4.0), (7000, -13.0),
        (9000, -22.0), (12000, -32.0), (16000, -44.0), (48000, -56.0)],
    2: [(40, 0.0), (2300, 0.0), (3600, -0.8), (4500, -5.0), (6000, -16.0),
        (8000, -27.0), (10000, -36.0), (14000, -50.0), (48000, -64.0)],
}


def target_response(model_idx, freqs, rolloff_only=False):
    """Linear magnitude of the hand-drawn target at `freqs` (log-freq interp)."""
    table = TARGET_MAG_DB_ROLLOFF if rolloff_only else TARGET_MAG_DB
    bp = np.array(table[model_idx], dtype=np.float64)
    db = np.interp(np.log2(np.clip(freqs, 1e-9, None)),
                   np.log2(bp[:, 0]), bp[:, 1])
    return 10.0 ** (db / 20.0)


def design_ir(model_idx, taps, window, rolloff_only=False):
    """128-tap linear-phase FIR via windowed frequency sampling. Returns the
    float IR (sum normalised to 1.0 = unity DC)."""
    fgrid = np.fft.rfftfreq(NFFT, 1.0 / FS)
    mag = target_response(model_idx, fgrid, rolloff_only)  # zero-phase magnitude
    h_full = np.fft.irfft(mag, NFFT)                       # symmetric about 0
    h_full = np.fft.fftshift(h_full)                       # center at NFFT/2
    c = NFFT // 2
    start = c - taps // 2
    h = h_full[start: start + taps].copy()                  # exactly `taps`, centered
    win = {"hamming": np.hamming, "hann": np.hanning,
           "blackman": np.blackman}[window](taps)
    h *= win
    h /= h.sum()                                           # unity DC
    return h


def quantize(h, bits, dc_shift):
    """Quantize float IR to Signed-`bits` ints with sum ~= 2^dc_shift (unity DC,
    output >> dc_shift). Returns (int_coeffs, fits, max_abs)."""
    scale = 1 << dc_shift
    q = np.round(h * scale).astype(np.int64)
    lim = 1 << (bits - 1)
    fits = bool(np.all(np.abs(q) < lim))
    return q, fits, int(np.max(np.abs(q)))


def freq_response_db(coeffs_int, dc_shift, freqs):
    """dB magnitude of an int FIR (scaled by 2^dc_shift) at `freqs`."""
    h = coeffs_int.astype(np.float64) / (1 << dc_shift)
    w = 2 * np.pi * freqs / FS
    n = np.arange(len(h))
    H = (h[None, :] * np.exp(-1j * w[:, None] * n[None, :])).sum(axis=1)
    return 20.0 * np.log10(np.abs(H) + 1e-12)


# --- Current shipping linear voicing: 15-tap FIR + presence biquad ------------
CUR_FIR_FOLDED = {  # cabSpeakerFirCoeff (8 folded half-taps, Signed 10, sum=256)
    0: [-1, 0, 2, 8, 19, 32, 43, 50],
    1: [0, 1, 4, 11, 20, 31, 40, 42],
    2: [0, 1, 5, 11, 21, 31, 38, 42],
}
CUR_PRES_FF = {  # cabPresenceFFCoeff (b0, b1, b2), Q14
    0: (17087, -28637, 12274),
    1: (16948, -29986, 13549),
    2: (16837, -30865, 14381),
}
CUR_PRES_FB = {  # cabPresenceFBCoeff (na1 = -a1, a2), Q14, a0 = 16384
    0: (28637, 12976),
    1: (29986, 14112),
    2: (30865, 14834),
}


def biquad_response_lin(model_idx, freqs):
    """Linear complex response of the EXISTING per-model presence biquad."""
    w = 2 * np.pi * freqs / FS
    b0, b1, b2 = CUR_PRES_FF[model_idx]
    na1, a2 = CUR_PRES_FB[model_idx]
    a0, a1 = 16384.0, -float(na1)
    z1, z2 = np.exp(-1j * w), np.exp(-2j * w)
    return (b0 + b1 * z1 + b2 * z2) / (a0 + a1 * z1 + a2 * z2)


def current_response_db(model_idx, freqs):
    """dB magnitude of the SHIPPING 15-tap FIR cascaded with the presence biquad."""
    folded = CUR_FIR_FOLDED[model_idx]
    fir = np.array(folded[:-1] + [folded[-1]] + folded[-2::-1], dtype=np.float64)
    fir /= 256.0                                           # unity DC (sum=256)
    w = 2 * np.pi * freqs / FS
    n = np.arange(len(fir))
    Hfir = (fir[None, :] * np.exp(-1j * w[:, None] * n[None, :])).sum(axis=1)
    return 20.0 * np.log10(np.abs(Hfir * biquad_response_lin(model_idx, freqs)) + 1e-12)


def rolloff_slope(coeffs_int, dc_shift, lo=5000, hi=12000):
    """dB/oct over [lo, hi] -- the headline 'sharp speaker rolloff' axis."""
    f = np.logspace(np.log10(lo), np.log10(hi), 20)
    db = freq_response_db(coeffs_int, dc_shift, f)
    x = np.log2(f)
    return float(np.polyfit(x - x.mean(), db, 1)[0])


def presence_peak(coeffs_int, dc_shift, lo=1500, hi=5000):
    f = np.logspace(np.log10(lo), np.log10(hi), 200)
    db = freq_response_db(coeffs_int, dc_shift, f)
    i = int(np.argmax(db))
    return float(f[i]), float(db[i])


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--taps", type=int, default=128)
    ap.add_argument("--bits", type=int, default=16, help="Signed coeff width "
                    "(16 validated sufficient: peak tap ~12160 needs 15 bits; "
                    "SNR is set by --dc-shift rounding, not width)")
    ap.add_argument("--dc-shift", type=int, default=16, help="unity-DC sum = 2^N, output >>N")
    ap.add_argument("--window", default="hamming", choices=["hamming", "hann", "blackman"])
    ap.add_argument("--rolloff-only", action="store_true",
                    help="Option Y: FIR supplies ONLY the sharp rolloff; the "
                    "EXISTING presence biquad keeps the peak (validated FIRxbiquad). "
                    "Far fewer taps needed -- the minimal-risk step.")
    ap.add_argument("--check", action="store_true", help="exit non-zero on any FAIL")
    ap.add_argument("--emit-clash", action="store_true", help="print Vec tables")
    args = ap.parse_args()

    print("Cab real-IR (R4 step B) design -- %d-tap linear-phase, Signed-%d, "
          "unity-DC 2^%d, %s window, fs=%d" %
          (args.taps, args.bits, args.dc_shift, args.window, FS))
    grp_delay = (args.taps - 1) / 2.0
    print("Latency: group delay %.1f samples = %.2f ms (linear-phase, symmetric)\n"
          % (grp_delay, 1000.0 * grp_delay / FS))

    hdr = ("model        | presence pk      | HFslp 2-9k | rolloff 5-12k | "
           "S%d fit | quant SNR | target" % args.bits)
    print(hdr)
    print("-" * len(hdr))

    if args.rolloff_only:
        print("Option Y: rolloff-only FIR + EXISTING presence biquad (validated FIRxbiquad)\n")

    all_ok = True
    clash_tables = []
    for model_idx, tkey, label in MODELS:
        h = design_ir(model_idx, args.taps, args.window, args.rolloff_only)
        q, fits, mx = quantize(h, args.bits, args.dc_shift)
        clash_tables.append((label, tkey, q))

        # quantization SNR: float vs quantized response over the audible grid
        af = np.logspace(np.log10(40), np.log10(20000), 400)
        ref = 20 * np.log10(np.abs(np.fft.rfft(h, NFFT))[
            np.clip((af / FS * NFFT).astype(int), 0, NFFT // 2)] + 1e-12)
        got = freq_response_db(q, args.dc_shift, af)
        qsnr = 10 * np.log10(np.mean(ref ** 2) / (np.mean((ref - got) ** 2) + 1e-12))

        # Validated response: in Option Y the FIR carries only the rolloff, so
        # the checked response is FIR x the EXISTING presence biquad.
        h_lin = q.astype(np.float64) / (1 << args.dc_shift)
        w = 2 * np.pi * MEAS_FREQS / FS
        nn = np.arange(len(h_lin))
        Hfir = (h_lin[None, :] * np.exp(-1j * w[:, None] * nn[None, :])).sum(axis=1)
        if args.rolloff_only:
            Hfir = Hfir * biquad_response_lin(model_idx, MEAS_FREQS)
        absnet = 20 * np.log10(np.abs(Hfir) + 1e-12)
        absnet = absnet - absnet[0]                       # DC-reference (bypass=0)
        bal = band_balance(absnet, MEAS_FREQS)
        slp = hf_slope(absnet, MEAS_FREQS)
        roll = rolloff_slope(q, args.dc_shift)
        # presence peak: on the validated (FIRxbiquad in Option Y) response
        pf_grid = np.logspace(np.log10(1500), np.log10(5000), 200)
        wpk = 2 * np.pi * pf_grid / FS
        Hpk = (h_lin[None, :] * np.exp(-1j * wpk[:, None] * nn[None, :])).sum(axis=1)
        if args.rolloff_only:
            Hpk = Hpk * biquad_response_lin(model_idx, pf_grid)
        pdb_grid = 20 * np.log10(np.abs(Hpk) + 1e-12)
        pf = float(pf_grid[int(np.argmax(pdb_grid))])
        pdb = float(pdb_grid.max())

        ok, detail = targets_mod.compare(tkey, absnet, MEAS_FREQS, bal)
        all_ok = all_ok and ok
        print("%-12s | %5.0f Hz %+5.1fdB | %+6.1f/oct | %+7.1f/oct  | %-5s | "
              "%5.1f dB | %s %s"
              % (label, pf, pdb, slp, roll, "OK" if fits else "OVF(%d)" % mx,
                 qsnr, "PASS" if ok else "FAIL", "" if ok else "<-"))
        print("             target(%s): %s" % (tkey, detail))

    # A/B headline vs the shipping 15-tap FIR + presence biquad
    print("\nA/B vs shipping 15-tap FIR + presence biquad (the lever):")
    print("model        | CUR rolloff 5-12k | IR rolloff 5-12k | CUR pk | IR pk")
    print("-" * 70)
    for model_idx, tkey, label in MODELS:
        h = design_ir(model_idx, args.taps, args.window)
        q, _, _ = quantize(h, args.bits, args.dc_shift)
        f = np.logspace(np.log10(5000), np.log10(12000), 20)
        cur = current_response_db(model_idx, f)
        cur_roll = float(np.polyfit(np.log2(f) - np.log2(f).mean(), cur, 1)[0])
        ir_roll = rolloff_slope(q, args.dc_shift)
        fp = np.logspace(np.log10(1500), np.log10(5000), 200)
        cur_pk = fp[int(np.argmax(current_response_db(model_idx, fp)))]
        ir_pk, _ = presence_peak(q, args.dc_shift)
        print("%-12s | %+8.1f/oct      | %+8.1f/oct     | %4.0f Hz | %4.0f Hz"
              % (label, cur_roll, ir_roll, cur_pk, ir_pk))

    if args.emit_clash:
        print("\n-- Clash coefficient tables (paste into Cab.hs) --")
        for label, tkey, q in clash_tables:
            terms = " :> ".join(str(int(v)) for v in q)
            print("\n-- %s (%s), Signed %d, sum=%d (unity DC, >> %d)"
                  % (label, tkey, args.bits, int(q.sum()), args.dc_shift))
            print("-- %s ::\n--   %s :> Nil" % (label.replace(" ", "_"), terms))

    if args.check and not all_ok:
        print("\nFAIL: one or more models missed its cab target")
        return 1
    print("\n%s" % ("All models PASS cab targets" if all_ok else "Some models FAIL"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
