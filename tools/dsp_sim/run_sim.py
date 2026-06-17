#!/usr/bin/env python3
"""Tier-1 offline DSP voicing harness (orchestrator).

Renders audio through the EXACT Clash ``topEntity`` fixed-point pipeline on the
host CPU -- the same source Vivado synthesises to the FPGA -- so a voicing
change can be A/B'd in seconds instead of a 30-40 min Vivado build + ear bench.

Pipeline:
  config (preset + knobs)  --control_maps.py-->  12 control words
  guitar WAV (or synth)    --24bit mono------->  Sim.hs (clash topEntity)
  Sim output               --align/metrics--->  out WAV + objective metrics

The control words are built with the project's own ``audio_lab_pynq/control_maps.py``
(imported by file path so no ``pynq`` runtime is needed), so the encoding is
identical to what the board would receive.

Usage:
  # build the harness once (or after any DSP-source edit):
  #   clash -O1 -ihw/ip/clash/src -itools/dsp_sim \
  #         -package-id <clash-prelude-id> tools/dsp_sim/Sim.hs \
  #         -o tools/dsp_sim/dsp_sim -outputdir /tmp/dsp_sim_build
  python3 tools/dsp_sim/run_sim.py --demo                 # bypass vs amp A/B on a synth pluck
  python3 tools/dsp_sim/run_sim.py --preset amp --amp-model 4 --wav-in guitar.wav
"""
import argparse
import importlib.util
import os
import subprocess
import sys
import wave

import numpy as np
from metrics import clip_count, crest_db, peak_dbfs, rms_dbfs, spectral_centroid_hz

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SIM_BIN_DEFAULT = os.path.join(REPO, "tools", "dsp_sim", "dsp_sim")
FS24 = 1 << 23           # 24-bit full scale
LATENCY = 106            # measured pipeline through-latency (cycles), fixed by structure
GAP = 8                  # idle cycles after each valid sample (FPGA AXIS valid-gating).
                         # gap=0 (back-to-back) mis-times the recursive biquad/SVF
                         # feedback and the amp oscillates at Nyquist -- NOT what the
                         # FPGA does (it gets ~347 idle island-cycles between samples).
                         # gap>=8 is enough for all recursions to settle: it is
                         # BIT-IDENTICAL to gap=32/106 (verified amp/rat/reverb,
                         # max|diff|=0) -- raising it only burns time. 8 is therefore
                         # the default (was 32, ~2.6x slower for the same bytes);
                         # gap>=LATENCY (106) is the unconditional 1-sample-in-flight
                         # bound if a future stage ever needs more settling.

# topEntity control-word order (see LowPassFir.hs t_inputs):
WORD_ORDER = ["gate", "od", "dist", "eq", "rat", "amp",
              "amp_tone", "cab", "reverb", "ns", "comp", "wah"]


def load_control_maps():
    """Load control_maps.py directly (it has no imports) to dodge the package
    __init__ which would pull in pynq."""
    path = os.path.join(REPO, "audio_lab_pynq", "control_maps.py")
    spec = importlib.util.spec_from_file_location("control_maps", path)
    cm = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cm)
    return cm


def build_words(cm, preset, amp_model=4, amp_drive_mode=1, knobs=None):
    """Build the 12 control words (topEntity order) for a preset.

    Effects whose section master is off are bit-exact bypassed regardless of
    their per-effect word, so only the enabled effect's word matters.
    """
    k = dict(input_gain=55, bass=52, middle=58, treble=62, presence=72,
             resonance=40, master=80)
    if knobs:
        k.update(knobs)
    amp_on = (preset == "amp")
    words = {
        "gate": cm.gate_word(amp_on=amp_on),
        "od": cm.overdrive_word(tone=65, level=100, drive=30),
        "dist": cm.distortion_word(tone=50, level=35, drive=0, pedal_mask=0),
        "eq": cm.eq_word(low=100, mid=100, high=100),
        "rat": cm.rat_word(filter_=35, level=100, drive=0, mix=100),
        "amp": cm.amp_word(input_gain=k["input_gain"], master=k["master"],
                           presence=k["presence"], resonance=k["resonance"]),
        "amp_tone": cm.amp_tone_word(bass=k["bass"], middle=k["middle"],
                                     treble=k["treble"], amp_model_idx=amp_model,
                                     amp_drive_mode=amp_drive_mode),
        "cab": cm.cab_word(mix=100, level=100, model=1, air=50),
        "reverb": cm.reverb_word(decay=0, tone=65, mix=0),
        "ns": cm.noise_suppressor_word(threshold=35, decay=40, damp=70),
        "comp": cm.compressor_word(threshold=45, ratio=35, response=45,
                                   makeup=50, enabled=False),
        "wah": cm.wah_word(position=0, q=50, volume=50, bias=50, enabled=False),
    }
    return [int(words[name]) & 0xFFFFFFFF for name in WORD_ORDER]


def synth_guitar(fs, seconds, f0=110.0, plucks=4, level=0.12):
    """Harmonically rich, dynamically plucked tone so the amp drive + power-sag
    dynamics (the user's 'volume pumping') are exercised. ``level`` is the peak
    as a fraction of full-scale -- a real guitar into the ADC sits well below
    FS (~0.1-0.2); driving it to ~0.85 just brick-walls the amp clip stages
    (the 'input clipping' seen on the board)."""
    n = int(fs * seconds)
    t = np.arange(n) / fs
    # sawtooth-ish: sum of decaying harmonics
    tone = np.zeros(n)
    for h in range(1, 13):
        tone += (1.0 / h) * np.sin(2 * np.pi * f0 * h * t)
    tone /= np.max(np.abs(tone))
    # repeated plucks: fast attack + exponential decay
    env = np.zeros(n)
    for p in range(plucks):
        start = int(p * n / plucks)
        seg = np.arange(n - start)
        e = np.exp(-seg / (0.28 * fs))           # ~0.28 s decay
        atk = np.minimum(1.0, np.arange(n - start) / (0.003 * fs))  # 3 ms attack
        env[start:] = np.maximum(env[start:], e * atk)
    x = tone * env * level
    return np.round(x * FS24).astype(np.int64)


def run_dsp(sim_bin, words, samples, gap=GAP, flush=LATENCY + 64):
    """Feed words + a *gated* sample stream to the Clash sim and return the
    aligned processed output (the oValid cycles, one per input sample). ``gap``
    idle cycles after each valid sample replicate the FPGA AXIS valid-gating
    (see the GAP note); the Sim filters by oValid so no latency trim is needed."""
    n = len(samples)
    toks = ([str(int(w) & 0xFFFFFFFF) for w in words]
            + [str(flush), str(int(gap))]
            + [str(int(s)) for s in samples])
    proc = subprocess.run([sim_bin], input=" ".join(toks),
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          text=True, timeout=1800)
    if proc.returncode != 0:
        raise RuntimeError("sim failed: " + proc.stderr[-500:])
    out = np.array([int(v) for v in proc.stdout.split()], dtype=np.int64)
    return out[:n]                                  # already aligned (oValid-filtered)


def short_term_rms_db(x, win=2048, hop=512):
    fs_floor = 1.0
    frames = []
    for i in range(0, max(0, len(x) - win + 1), hop):
        seg = x[i:i + win].astype(np.float64)
        frames.append(np.sqrt(np.mean(seg * seg)) + fs_floor)
    if not frames and len(x):
        seg = x.astype(np.float64)
        frames.append(np.sqrt(np.mean(seg * seg)) + fs_floor)
    return 20 * np.log10(np.array(frames) / FS24)


def metrics(x, fs):
    st = short_term_rms_db(x)
    active = st[st > (st.max() - 30.0)] if st.size else st
    return {
        "peak_dBFS": peak_dbfs(x),
        "rms_dBFS": rms_dbfs(x),
        "crest_dB": crest_db(x),
        "level_stability_std_dB": float(np.std(active)),   # higher => more pumping
        "centroid_Hz": spectral_centroid_hz(x[:min(len(x), 1 << 15)], fs),
        "clip_count": clip_count(x),
    }


def write_wav(path, x24, fs):
    x16 = np.clip(x24 >> 8, -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(fs)
        w.writeframes(x16.tobytes())


def read_wav(path):
    with wave.open(path, "rb") as w:
        fs = w.getframerate()
        sw = w.getsampwidth()
        nch = w.getnchannels()
        raw = w.readframes(w.getnframes())
    if sw == 2:
        a = np.frombuffer(raw, dtype="<i2").astype(np.int64)
        a = a.reshape(-1, nch)[:, 0] << 8          # 16 -> 24 bit
    elif sw == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, nch, 3)[:, 0, :]
        a = (b[:, 0].astype(np.int64) | (b[:, 1].astype(np.int64) << 8)
             | (b[:, 2].astype(np.int64) << 16))
        a = np.where(a >= (1 << 23), a - (1 << 24), a)
    else:
        raise ValueError("unsupported sample width %d" % sw)
    return fs, a


def fmt(m):
    return ("peak {peak_dBFS:6.2f} dBFS | rms {rms_dBFS:6.2f} | crest {crest_dB:5.2f} dB "
            "| lvl-stab.std {level_stability_std_dB:5.2f} dB | centroid {centroid_Hz:6.0f} Hz "
            "| clips {clip_count}").format(**m)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--demo", action="store_true",
                    help="render bypass vs amp on a synth pluck and compare")
    ap.add_argument("--preset", choices=["bypass", "amp"], default="amp")
    ap.add_argument("--amp-model", type=int, default=4,
                    help="0=JC-120 1=Twin 2=AC30 3=Rockerverb 4=JCM800 5=TriAmp")
    ap.add_argument("--drive-mode", type=int, default=1)
    ap.add_argument("--wav-in", default=None, help="input WAV (16/24-bit mono); else synth")
    ap.add_argument("--seconds", type=float, default=1.5)
    ap.add_argument("--in-level", type=float, default=0.12,
                    help="synth peak as fraction of full-scale (real guitar ~0.1-0.2)")
    ap.add_argument("--fs", type=int, default=96000)
    ap.add_argument("--out-dir", default="/tmp/dsp_sim_out")
    ap.add_argument("--gap", type=int, default=GAP,
                    help="idle cycles after each valid sample (FPGA AXIS gating; >=8)")
    ap.add_argument("--sim-bin", default=SIM_BIN_DEFAULT)
    args = ap.parse_args()

    if not os.path.exists(args.sim_bin):
        sys.exit("sim binary not found: %s\n(build it first -- see the module docstring)" % args.sim_bin)
    os.makedirs(args.out_dir, exist_ok=True)
    cm = load_control_maps()

    if args.wav_in:
        fs, x_in = read_wav(args.wav_in)
    else:
        fs, x_in = args.fs, synth_guitar(args.fs, args.seconds, level=args.in_level)
    write_wav(os.path.join(args.out_dir, "input.wav"), x_in, fs)
    print("input : %d samples @ %d Hz  | %s" % (len(x_in), fs, fmt(metrics(x_in, fs))))

    presets = ["bypass", "amp"] if args.demo else [args.preset]
    for preset in presets:
        words = build_words(cm, preset, amp_model=args.amp_model,
                            amp_drive_mode=args.drive_mode)
        y = run_dsp(args.sim_bin, words, x_in, gap=args.gap)
        tag = preset if preset == "bypass" else "amp_m%d" % args.amp_model
        out_wav = os.path.join(args.out_dir, "out_%s.wav" % tag)
        write_wav(out_wav, y, fs)
        # bit-exact bypass invariant (the knife-edge property), checked offline:
        extra = ""
        if preset == "bypass":
            exact = bool(np.array_equal(y, x_in))
            extra = "  [bypass bit-exact == input: %s]" % exact
        print("%-9s: %s%s" % (tag, fmt(metrics(y, fs)), extra))
        print("           -> %s" % out_wav)


if __name__ == "__main__":
    main()
