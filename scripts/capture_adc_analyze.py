#!/usr/bin/env python3
"""Bit-level analysis of the ADC -> DSP capture path (D74 bitcrusher hunt).

Captures the Pmod I2S2 ADC (line_in) via S2MM DMA in two routes and prints
bitcrusher / quantization indicators per channel:

  - passthrough     : line_in -> passthrough  -> dma  (cleanest bypass)
  - guitar_chain    : line_in -> guitar_chain -> dma  (the "dsp all_off" path
                      the operator hears as bitcrusher)

Per channel: peak / dBFS / RMS / DC / unique-value count / longest equal-run
/ clip count / stuck-low-bits (trailing zero bits common to all samples =
effective bit truncation) / quantization step / FFT top bins.

A healthy 24-bit ADC noise floor has many unique values, max_run ~1-3, and
NO stuck low bits. Stuck low bits or long runs == digital quantization
(bitcrusher). This needs NO instrument playing (idle noise floor already
shows truncation) and produces no loud output (DAC is silent during S2MM
capture).

  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
      scripts/capture_adc_analyze.py --frames 24000
"""

import importlib.util
import sys

import numpy as np

REPO = "/home/xilinx/Audio-Lab-PYNQ"
if REPO not in sys.path:
    sys.path.insert(0, REPO)

try:
    from audio_lab_pynq.constants import SAMPLE_RATE_HZ
except Exception:  # off-board (pynq unavailable); constants.py is the source of truth
    SAMPLE_RATE_HZ = 96000
FS = SAMPLE_RATE_HZ
FULL = (1 << 23)  # 24-bit signed full scale


def _max_run(a):
    if len(a) == 0:
        return 0
    # boundaries where value changes
    chg = np.nonzero(np.diff(a))[0]
    if len(chg) == 0:
        return len(a)
    idx = np.concatenate(([-1], chg, [len(a) - 1]))
    return int(np.max(np.diff(idx)))


def _trailing_zero_bits(v):
    if v == 0:
        return 32
    n = 0
    while (v & 1) == 0:
        v >>= 1
        n += 1
    return n


def _dbfs(pk):
    return 20.0 * np.log10(pk / float(FULL)) if pk > 0 else -200.0


def analyze(name, s):
    print("--- %s ---" % name)
    for ch in (0, 1):
        a = s[:, ch].astype(np.int64)
        peak = int(np.max(np.abs(a)))
        rms = float(np.sqrt(np.mean(a.astype(np.float64) ** 2)))
        uniq = int(len(np.unique(a)))
        mrun = _max_run(a)
        clip = int(np.sum(np.abs(a) >= (FULL - 2)))
        dc = float(np.mean(a))
        # OR of all sample magnitudes -> which low bits ever toggle.
        orv = int(np.bitwise_or.reduce(np.abs(a)))
        stuck_low = _trailing_zero_bits(orv) if orv else 32
        tag = "  <-- TRUNCATED?" if stuck_low >= 4 else ""
        print("  ch%d(%s): peak=%d (%.1f dBFS) rms=%.1f dc=%.1f uniq=%d "
              "max_run=%d clip=%d stuck_low_bits=%d (step=%d)%s"
              % (ch, "L" if ch == 0 else "R", peak, _dbfs(peak), rms, dc,
                 uniq, mrun, clip, stuck_low, (1 << stuck_low), tag))
    # FFT top bins on L (DC removed)
    L = s[:, 0].astype(np.float64)
    L -= np.mean(L)
    if np.any(L):
        spec = np.abs(np.fft.rfft(L * np.hanning(len(L))))
        fr = np.fft.rfftfreq(len(L), 1.0 / FS)
        top = np.argsort(spec[2:])[-4:][::-1] + 2
        print("  L FFT top bins: " + ", ".join(
            "%.0fHz(%.2e)" % (fr[b], spec[b]) for b in top))


def main(argv):
    frames = 24000
    for i, x in enumerate(argv):
        if x.startswith("--frames"):
            frames = int(x.split("=")[1] if "=" in x else argv[i + 1])

    from audio_lab_pynq.AudioLabOverlay import (
        AudioLabOverlay, XbarSource, XbarEffect, XbarSink)
    from audio_lab_pynq.diagnostics import capture_input
    from pynq import allocate

    ovl = AudioLabOverlay(download=("--download" in argv))
    ovl.set_guitar_effects(
        noise_gate_on=False, overdrive_on=False, distortion_on=False,
        rat_on=False, amp_on=False, cab_on=False, eq_on=False, reverb_on=False)
    try:
        ovl.set_wah_settings(enabled=False, source="manual")
    except Exception:
        pass

    spec = importlib.util.spec_from_file_location(
        "runner", REPO + "/scripts/run_encoder_hdmi_gui.py")
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    runner._write_pmod_mode(ovl, "dsp")  # ADC -> chain -> DAC active

    print("captured %d frames @ %d Hz per route (play the instrument during "
          "capture for signal analysis; idle is fine for truncation)." %
          (frames, FS))

    # passthrough capture (the validated capture_input path; line_in ->
    # passthrough -> dma). guitar_chain -> dma is NOT a valid capture sink
    # (transfer length 0 -> DMA wait busy-spins), so it is intentionally not
    # used here.
    sp = capture_input(ovl, num_frames=frames, source=XbarSource.line_in)
    analyze("passthrough  line_in -> passthrough -> dma", sp)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
