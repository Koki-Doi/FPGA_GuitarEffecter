#!/usr/bin/env python3
"""Pmod I2S2 self-loopback diagnostic for the I2S / ADC / DAC / AXIS path.

Hardware setup:
    Pmod Line Out (DAC, JB4 T10) -> CABLE -> Pmod Line In (ADC, JB10 W13)
    No external instrument required.

What this script does:
    Runs a sequence of "phases" that exercise each MODE of pmod_i2s2_master.v
    and the axis_switch routes, then reports per-phase statistics that
    distinguish a clean path from a broken one. The dispositive
    bit-crusher / quantization checks are:

        * uniq1k  = number of unique sample values in the first 1000 polls
                    (low = the path is quantising or sample-dropping)
        * maxRun  = longest run of identical consecutive samples
                    (>2 hints at stair-step / bit-crusher behaviour)

    A healthy path returns uniq1k near 1000 and maxRun = 1 or 2 across
    every phase.

What this script does NOT do:
    * No bit/hwh / Vivado / Clash rebuild.
    * No DSP source edit.
    * No GPIO / block design touch.
    * No commit / push.

It only WRITES to:
    * `pmod_status_0.MODE` register (0..3) and the CLEAR pulse register
    * `axis_switch` route via `AudioLabOverlay.route(...)`
    * `axi_dma_0` sendchannel (for MM2S sine playback)
    * `axi_dma_0.recvchannel` via `capture_input` for DMA capture phases

All writes are restored to MUTE + `line_in -> passthrough -> headphone`
at the end of each phase / on exit.

Usage on the PYNQ-Z2 (cable Pmod OUT -> IN connected):

    sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \\
        scripts/diagnose_pmod_loopback.py

Optional flags:
    --phase {1,2,3,5,6,b,all}   default 'all'
    --short                     skip the long sweeps (faster smoke)

PYNQ Python 3.6 compatible (no f-strings, no dataclass).

See docs/ai_context/PMOD_LOOPBACK_DIAGNOSTIC.md for what each phase tests
and how to interpret the numbers.
"""

import argparse
import sys
import time

import numpy as np


PMOD_STATUS_ADDR = 0x43D20000
PMOD_STATUS_RANGE = 0x10000
REG_VERSION    = 0x00
REG_STATUS     = 0x04
REG_FRAME      = 0x08
REG_NONZERO    = 0x0C
REG_SDOUT_X    = 0x10
REG_CLIP       = 0x14
REG_LAST_L     = 0x18
REG_LAST_R     = 0x1C
REG_PEAK_L     = 0x20
REG_PEAK_R     = 0x24
REG_MODE       = 0x28
REG_CLEAR      = 0x2C

try:
    from audio_lab_pynq.constants import SAMPLE_RATE_HZ
except Exception:  # off-board (pynq unavailable); constants.py is the source of truth
    SAMPLE_RATE_HZ = 96000
FS_AUDIO = SAMPLE_RATE_HZ


def _sign24(x):
    x &= 0xFFFFFF
    if x & 0x800000:
        return x - 0x1000000
    return x


def _dbfs(x):
    if x <= 0:
        return float("-inf")
    return 20.0 * np.log10(float(x) / ((1 << 23) - 1))


def _safe_mute(ov, st):
    """Restore route + mute."""
    from audio_lab_pynq.AudioLabOverlay import XbarSource, XbarEffect, XbarSink
    try:
        ov.route(XbarSource.line_in, XbarEffect.passthrough, XbarSink.headphone)
    except Exception:
        pass
    st.write(REG_MODE, 3)


def phase_state(ov, st):
    """Report the initial board state (bit/hwh md5, PL.timestamp, all
    pmod_status registers)."""
    from pynq import PL
    print("=== Phase 0: state ===")
    print("  PL.bitfile_name :", PL.bitfile_name)
    print("  PL.timestamp    :", PL.timestamp)
    try:
        print("  ADC HPF         :", ov.codec.get_adc_hpf_state())
    except Exception as exc:
        print("  ADC HPF read failed:", exc)
    print("  pmod_status registers:")
    for n, off in [("VERSION", REG_VERSION), ("STATUS", REG_STATUS),
                   ("FRAME", REG_FRAME), ("NONZERO", REG_NONZERO),
                   ("SDOUT_X", REG_SDOUT_X), ("CLIP", REG_CLIP),
                   ("LAST_L", REG_LAST_L), ("LAST_R", REG_LAST_R),
                   ("PEAK_L", REG_PEAK_L), ("PEAK_R", REG_PEAK_R),
                   ("MODE", REG_MODE)]:
        print("    %-9s = 0x%08X" % (n, st.read(off)))


def phase1_per_mode_baseline(ov, st, window_s=3.0):
    """For each MODE in {3,0,1,2,3}, clear counters, wait `window_s`,
    then read FRAME/NONZERO/CLIP deltas + LAST + PEAK. No external signal."""
    print()
    print("=== Phase 1: per-MODE baseline (no MM2S, cable loop only) ===")
    print("  %-6s %12s %12s %10s %10s %10s %10s %10s" %
          ("phase", "frame_d", "nonzero_d", "clip_d", "peakL", "peakR",
           "lastL", "lastR"))
    for label, mode in [("MUTE", 3), ("TONE", 0), ("LOOP", 1), ("DSP", 2), ("MUTE", 3)]:
        st.write(REG_MODE, mode); time.sleep(0.3)
        st.write(REG_CLEAR, 1);   time.sleep(0.05)
        f0 = st.read(REG_FRAME); n0 = st.read(REG_NONZERO); c0 = st.read(REG_CLIP)
        time.sleep(window_s)
        f1 = st.read(REG_FRAME); n1 = st.read(REG_NONZERO); c1 = st.read(REG_CLIP)
        print("  %-6s %12d %12d %10d %10d %10d %10d %10d" %
              (label,
               (f1 - f0) & 0xFFFFFFFF,
               (n1 - n0) & 0xFFFFFFFF,
               (c1 - c0) & 0xFFFFFFFF,
               st.read(REG_PEAK_L), st.read(REG_PEAK_R),
               _sign24(st.read(REG_LAST_L)), _sign24(st.read(REG_LAST_R))))


def phase3_dma_capture_fft(ov, st):
    """MODE 0 internal 1 kHz tone (cable loop active) -> capture -> FFT.
    Also MODE 3 mute reference. The capture path is line_in -> passthrough
    -> dma, so the DAC stops getting axis data during capture; on MODE 0
    the DAC keeps playing the internal tone anyway, so capture sees the
    cable-echoed 1 kHz tone."""
    from audio_lab_pynq.diagnostics import capture_input
    print()
    print("=== Phase 3: DMA capture + FFT (MODE 0 1 kHz reference) ===")

    def run(label, mode):
        st.write(REG_MODE, mode); time.sleep(0.5)
        samples = capture_input(ov, num_frames=24000)  # 0.5 s
        L = samples[:, 0].astype(np.float64)
        L_dc = L - np.mean(L)
        spec = np.abs(np.fft.rfft(L_dc * np.hanning(len(L_dc))))
        freqs = np.fft.rfftfreq(len(L_dc), 1.0 / FS_AUDIO)
        peak = int(np.max(np.abs(L)))
        print("  %s (MODE %d):" % (label, mode))
        print("    L: rms=%.0f peak=%d (%.1f dBFS) mean=%.0f" %
              (np.sqrt(np.mean(L * L)), peak, _dbfs(peak), np.mean(L)))
        top3 = np.argsort(spec[2:])[-3:][::-1] + 2
        print("    top 3 spectral peaks (uniform 96 kHz fs):")
        for b in top3:
            print("      %7.1f Hz mag=%.0f" % (freqs[b], spec[b]))

    run("MODE 0 internal 1 kHz tone, cable loop", 0)
    run("MODE 3 mute, cable loop",                3)


def _play_and_poll(ov, st, freq, lvl_dbfs, duration_s, effect_name,
                   poll_n=20000):
    """Play `duration_s` of MM2S sine at (freq, lvl_dbfs) through MODE 2
    using axis route `dma -> <effect_name> -> headphone`. While the DAC
    plays, poll LAST_LEFT `poll_n` times to reconstruct a quasi-uniform
    time series. Returns dict with peak / unique-count / max-run / etc."""
    from audio_lab_pynq.AudioLabOverlay import XbarSource, XbarEffect, XbarSink
    from pynq import allocate

    effect_enum = (XbarEffect.passthrough if effect_name == "passthrough"
                   else XbarEffect.guitar_chain)

    n = int(duration_s * FS_AUDIO)
    amp = ((1 << 23) - 1) * (10.0 ** (lvl_dbfs / 20.0))
    t = np.arange(n, dtype=np.float64)
    tone = (amp * np.sin(2.0 * np.pi * freq * t / FS_AUDIO)).astype(np.int32)
    frames = np.empty((n, 2), dtype=np.int32)
    frames[:, 0] = tone
    frames[:, 1] = tone

    st.write(REG_MODE, 2); time.sleep(0.2)
    ov.route(XbarSource.dma, effect_enum, XbarSink.headphone)
    buf = allocate(shape=frames.shape, dtype=np.int32)
    buf[:] = frames

    ov.axi_dma_0.sendchannel.transfer(buf)

    samples = np.empty(poll_n, dtype=np.int64)
    t0 = time.perf_counter()
    for i in range(poll_n):
        samples[i] = _sign24(st.read(REG_LAST_L))
    poll_duration = time.perf_counter() - t0

    ov.axi_dma_0.sendchannel.wait()
    buf.freebuffer()

    diffs = np.diff(samples)
    transitions = int(np.sum(diffs != 0))
    uniq1k = len(set(int(x) for x in samples[:1000]))
    runs = 1; max_run = 1; cur = samples[0]
    for x in samples[1:]:
        if x == cur:
            runs += 1
            if runs > max_run:
                max_run = runs
        else:
            runs = 1; cur = x
    pk = int(np.max(np.abs(samples)))
    return dict(pk=pk, pk_db=_dbfs(pk),
                rms=float(np.sqrt(np.mean(samples.astype(np.float64) ** 2))),
                mean=int(np.mean(samples)),
                uniq1k=uniq1k, max_run=max_run, trans=transitions,
                poll_kHz=len(samples) / poll_duration / 1000.0)


def phase_sweep(ov, st, effect_name, label, freqs, levels, duration_s=1.0):
    print()
    print("=== %s: MM2S sweep dma -> %s -> headphone, cable loop -> ADC ===" %
          (label, effect_name))
    print("  %-7s %5s | %-8s %5s %6s %5s | %s" %
          ("f(Hz)", "lvl", "peak", "dBFS", "uniq1k", "maxRun", "flag"))
    bad_freqs = []
    for f in freqs:
        for lvl in levels:
            r = _play_and_poll(ov, st, f, lvl, duration_s, effect_name,
                               poll_n=20000)
            flag = ""
            if r["uniq1k"] < 500:
                flag += "QUANT! "
            if r["max_run"] > 4:
                flag += "STAIR! "
            if flag:
                bad_freqs.append((f, lvl, flag))
            print("  %-7d %5g | %-8d %5.1f %6d %5d | %s" %
                  (f, lvl, r["pk"], r["pk_db"], r["uniq1k"], r["max_run"],
                   flag.strip()))
    return bad_freqs


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--phase", choices=["0", "1", "3", "5", "6", "b", "all"],
                   default="all")
    p.add_argument("--short", action="store_true",
                   help="skip the long sweeps (faster smoke)")
    args = p.parse_args()

    from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay
    from pynq import MMIO

    ov = AudioLabOverlay(download=False)
    ov.set_compressor_settings(enabled=False)
    ov.set_noise_suppressor_settings(enabled=False)
    ov.set_guitar_effects(noise_gate_on=False, overdrive_on=False,
                          distortion_on=False, rat_on=False, amp_on=False,
                          cab_on=False, eq_on=False, reverb_on=False)
    st = MMIO(PMOD_STATUS_ADDR, PMOD_STATUS_RANGE)

    phases = args.phase
    bad = []
    try:
        if phases in ("0", "all"):
            phase_state(ov, st)
        if phases in ("1", "all"):
            window = 1.5 if args.short else 3.0
            phase1_per_mode_baseline(ov, st, window_s=window)
        if phases in ("3", "all"):
            phase3_dma_capture_fft(ov, st)
        if phases in ("5", "all"):
            freqs = [1000, 4000, 8000, 12000]
            levels = [-12.0]
            bad += phase_sweep(ov, st, "passthrough",
                               "Phase 5 (sanity, no DSP)",
                               freqs, levels,
                               duration_s=0.8 if args.short else 1.0)
        if phases in ("b", "all"):
            freqs = [1000, 4000, 8000, 10000, 12000]
            levels = [-20.0, -12.0]
            if not args.short:
                freqs.append(15000)
                levels.insert(0, -30.0)
            bad += phase_sweep(ov, st, "guitar_chain",
                               "Phase B (DSP chain all-off)",
                               freqs, levels,
                               duration_s=0.8 if args.short else 1.0)
        print()
        if bad:
            print("=== VERDICT: %d bit-crusher / quantization indicators triggered ===" % len(bad))
            for f, lvl, flag in bad:
                print("  %d Hz / %g dBFS: %s" % (f, lvl, flag.strip()))
            sys.exit(1)
        else:
            print("=== VERDICT: PASS (no bit-crusher / quantization signature in any phase) ===")
            sys.exit(0)
    finally:
        _safe_mute(ov, st)


if __name__ == "__main__":
    main()
