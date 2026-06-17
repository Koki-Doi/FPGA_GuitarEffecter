#!/usr/bin/env python3
"""Collect AudioLab real-hardware reference captures.

Runs on the PYNQ-Z2. It sends deterministic 24-bit test signals through the
FPGA DMA path, writes the same effect control words used by the live overlay,
captures the processed DMA output, and saves a manifest that can be compared
against tools/dsp_sim with compare_hw_reference.py.

The script also records Pmod I2S2 status counters and can capture a short
line-in passthrough sample so the analog front end is represented separately
from the digital DSP island.

PYNQ Python 3.6 compatibility: no dataclasses, no argparse BooleanOptionalAction.
"""

import argparse
import datetime as _dt
import hashlib
import json
import math
import os
import platform
import socket
import subprocess
import sys
import time
import wave

import numpy as np


REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FS = 96000
FS24 = (1 << 23) - 1

WORD_ORDER = ["gate", "od", "dist", "eq", "rat", "amp",
              "amp_tone", "cab", "reverb", "ns", "comp", "wah"]

GENERAL_WORD_ATTRS = (
    ("gate", "axi_gpio_gate"),
    ("overdrive", "axi_gpio_overdrive"),
    ("distortion", "axi_gpio_distortion"),
    ("eq", "axi_gpio_eq"),
    ("rat", "axi_gpio_delay"),
    ("amp", "axi_gpio_amp"),
    ("amp_tone", "axi_gpio_amp_tone"),
    ("cab", "axi_gpio_cab"),
    ("reverb", "axi_gpio_reverb"),
)

DEDICATED_WORD_ATTRS = (
    ("ns", "axi_gpio_noise_suppressor"),
    ("comp", "axi_gpio_compressor"),
    ("wah", "axi_gpio_wah"),
)

PMOD_REG = dict(
    VERSION=0x00,
    STATUS=0x04,
    FRAME_COUNT=0x08,
    NONZERO_COUNT=0x0C,
    SDOUT_XCOUNT=0x10,
    CLIP_COUNT=0x14,
    LAST_LEFT=0x18,
    LAST_RIGHT=0x1C,
    PEAK_ABS_LEFT=0x20,
    PEAK_ABS_RIGHT=0x24,
    MODE=0x28,
    CLEAR=0x2C,
)

PMOD_MODE = dict(tone=0, loopback=1, dsp=2, mute=3)

REFERENCE_SOURCES = [
    dict(
        name="Neural Amp Modeler",
        url="https://github.com/sdatkinson/neural-amp-modeler",
        license="MIT",
        use="capture/fit methodology reference; no source copied",
    ),
    dict(
        name="spotify/pedalboard",
        url="https://github.com/spotify/pedalboard",
        license="GPL-3.0-or-later",
        use="audio I/O and external VST render workflow reference only",
    ),
    dict(
        name="AIDA-X",
        url="https://github.com/AidaDSP/AIDA-X",
        license="GPL-3.0-or-later",
        use="amp/cab model player and meter/clip workflow reference only",
    ),
    dict(
        name="BYOD",
        url="https://github.com/Chowdhury-DSP/BYOD",
        license="GPL-3.0-or-later",
        use="distortion chain coverage and UI parameter reference only",
    ),
    dict(
        name="Airwindows Dirt/Edge family",
        url="https://www.airwindows.com/dirt/",
        license="MIT for source releases",
        use="aliasing/ultrasonic-filtering measurement reference; no code copied",
    ),
]


def _timestamp():
    return _dt.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")


def _mkdir(path):
    if not os.path.isdir(path):
        os.makedirs(path)


def _run_text(cmd):
    try:
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=REPO)
        out, _err = proc.communicate()
        if proc.returncode == 0:
            return out.decode("utf-8", "replace").strip()
    except Exception:
        pass
    return None


def _md5_file(path):
    if not os.path.exists(path):
        return None
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _dbfs(value):
    value = float(abs(value))
    if value <= 0.0:
        return float("-inf")
    return 20.0 * math.log10(value / float(FS24))


def _write_json(path, obj):
    with open(path, "w") as f:
        json.dump(obj, f, indent=2, sort_keys=True)
        f.write("\n")


def _write_wav_stereo(path, frames):
    """Write int32 stereo, 24-bit-domain frames as 16-bit WAV for listening."""
    x = np.asarray(frames, dtype=np.int64)
    if x.ndim == 1:
        x = np.column_stack([x, x])
    if x.shape[1] != 2:
        raise ValueError("frames must have shape (N, 2)")
    x16 = np.clip(x >> 8, -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(FS)
        w.writeframes(x16.tobytes())


def _stats_channel(x):
    x = np.asarray(x, dtype=np.int64)
    if x.size == 0:
        return dict(mean=0.0, rms=0.0, peak_abs=0, min=0, max=0,
                    peak_dBFS=float("-inf"), rms_dBFS=float("-inf"),
                    clip_like_count=0, nonzero_count=0)
    xf = x.astype(np.float64)
    rms = float(np.sqrt(np.mean(xf * xf)))
    peak = int(np.max(np.abs(x)))
    return dict(
        mean=float(np.mean(xf)),
        rms=rms,
        peak_abs=peak,
        min=int(np.min(x)),
        max=int(np.max(x)),
        peak_dBFS=_dbfs(peak),
        rms_dBFS=_dbfs(rms),
        clip_like_count=int(np.sum(np.abs(x) >= FS24 - 8)),
        nonzero_count=int(np.sum(x != 0)),
    )


def _stats_stereo(frames):
    x = np.asarray(frames)
    if x.ndim == 1:
        return dict(mono=_stats_channel(x))
    return dict(left=_stats_channel(x[:, 0]), right=_stats_channel(x[:, 1]))


def _tone(frames, freq_hz, amp_dbfs=-18.0):
    amp = FS24 * (10.0 ** (amp_dbfs / 20.0))
    n = np.arange(frames, dtype=np.float64)
    x = amp * np.sin(2.0 * np.pi * float(freq_hz) * n / FS)
    return np.round(x).astype(np.int32)


def _log_sweep(frames, f1=60.0, f2=12000.0, amp_dbfs=-24.0):
    amp = FS24 * (10.0 ** (amp_dbfs / 20.0))
    dur = max(float(frames) / FS, 1.0 / FS)
    n = np.arange(frames, dtype=np.float64)
    t = n / FS
    k = math.log(float(f2) / float(f1)) / dur
    phase = 2.0 * math.pi * float(f1) * (np.exp(k * t) - 1.0) / k
    x = amp * np.sin(phase)
    # Small fade avoids a click at the end of the sweep.
    fade = min(frames // 20, 2048)
    if fade > 0:
        win = np.ones(frames)
        win[:fade] = np.linspace(0.0, 1.0, fade)
        win[-fade:] = np.linspace(1.0, 0.0, fade)
        x *= win
    return np.round(x).astype(np.int32)


def _pluck(frames, f0=110.0, level=0.14):
    n = np.arange(frames, dtype=np.float64)
    t = n / FS
    tone = np.zeros(frames, dtype=np.float64)
    for h in range(1, 13):
        tone += (1.0 / h) * np.sin(2.0 * np.pi * f0 * h * t)
    peak = np.max(np.abs(tone))
    if peak > 0:
        tone /= peak
    env = np.exp(-n / (0.28 * FS))
    attack = np.minimum(1.0, n / (0.003 * FS))
    x = tone * env * attack * level * FS24
    return np.round(x).astype(np.int32)


def _multisine(frames, amp_dbfs=-24.0):
    freqs = [82.4, 110.0, 220.0, 440.0, 880.0, 1760.0, 3520.0, 7040.0]
    n = np.arange(frames, dtype=np.float64)
    x = np.zeros(frames, dtype=np.float64)
    for i, freq in enumerate(freqs):
        x += (1.0 / math.sqrt(len(freqs))) * np.sin(
            2.0 * np.pi * freq * n / FS + i * 0.37)
    peak = np.max(np.abs(x))
    if peak > 0:
        x /= peak
    x *= FS24 * (10.0 ** (amp_dbfs / 20.0))
    return np.round(x).astype(np.int32)


def _two_tone(frames, amp_dbfs=-24.0):
    n = np.arange(frames, dtype=np.float64)
    amp = FS24 * (10.0 ** (amp_dbfs / 20.0))
    x = 0.5 * np.sin(2.0 * np.pi * 700.0 * n / FS)
    x += 0.5 * np.sin(2.0 * np.pi * 1200.0 * n / FS)
    x *= amp
    return np.round(x).astype(np.int32)


def _level_steps(frames):
    levels = [-42.0, -36.0, -30.0, -24.0, -18.0, -12.0]
    out = np.zeros(frames, dtype=np.float64)
    idx = 0
    for level in levels:
        end = int(round((levels.index(level) + 1) * frames / float(len(levels))))
        seg_n = max(0, end - idx)
        if seg_n:
            out[idx:end] = _tone(seg_n, 440.0, amp_dbfs=level).astype(np.float64)
        idx = end
    return np.round(out).astype(np.int32)


def _decay_floor(frames):
    x = _pluck(frames, f0=146.8, level=0.10).astype(np.float64)
    rng = np.random.RandomState(12345)
    noise = rng.normal(0.0, FS24 * (10.0 ** (-72.0 / 20.0)), frames)
    x += noise
    return np.clip(np.round(x), -FS24 - 1, FS24).astype(np.int32)


def _impulse(frames):
    x = np.zeros(frames, dtype=np.int32)
    if frames > 128:
        x[128] = int(round(FS24 * 0.5))
    return x


def stimulus_mono(name, frames, tail_frames):
    if name == "silence":
        return np.zeros(frames, dtype=np.int32)
    if name == "sine_100":
        return _tone(frames, 100.0, amp_dbfs=-24.0)
    if name == "sine_440":
        return _tone(frames, 440.0, amp_dbfs=-24.0)
    if name == "sine_1k":
        return _tone(frames, 1000.0, amp_dbfs=-18.0)
    if name == "sine_6k":
        return _tone(frames, 6000.0, amp_dbfs=-30.0)
    if name == "sweep":
        return _log_sweep(frames)
    if name == "pluck":
        return _pluck(frames)
    if name == "multisine":
        return _multisine(frames)
    if name == "two_tone":
        return _two_tone(frames)
    if name == "level_steps":
        return _level_steps(frames)
    if name == "decay_floor":
        return _decay_floor(tail_frames)
    if name == "impulse":
        return _impulse(tail_frames)
    raise ValueError("unknown stimulus: {}".format(name))


def stimulus_stereo(name, frames, tail_frames):
    mono = stimulus_mono(name, frames, tail_frames)
    return np.column_stack([mono, mono]).astype(np.int32)


def base_kwargs():
    return dict(
        noise_gate_on=False,
        noise_gate_threshold=35,
        overdrive_on=False,
        overdrive_tone=65,
        overdrive_level=100,
        overdrive_drive=30,
        overdrive_model=0,
        distortion_on=False,
        distortion_tone=50,
        distortion_level=35,
        distortion=20,
        distortion_pedal_mask=0,
        distortion_bias=50,
        distortion_tight=50,
        distortion_mix=100,
        rat_on=False,
        rat_filter=35,
        rat_level=100,
        rat_drive=55,
        rat_mix=100,
        amp_on=False,
        amp_input_gain=35,
        amp_bass=50,
        amp_middle=50,
        amp_treble=50,
        amp_presence=45,
        amp_resonance=35,
        amp_master=80,
        amp_character=35,
        amp_model_idx=0,
        amp_drive_mode=0,
        cab_on=False,
        cab_mix=100,
        cab_level=100,
        cab_model=1,
        cab_air=50,
        eq_on=False,
        eq_low=100,
        eq_mid=100,
        eq_high=100,
        reverb_on=False,
        reverb_decay=30,
        reverb_tone=65,
        reverb_mix=20,
    )


def case(name, stage, stimulus, route_effect="guitar_chain", kwargs=None,
         ns=None, comp=None, wah=None, notes="", refs=None):
    k = base_kwargs()
    if kwargs:
        k.update(kwargs)
    return dict(
        name=name,
        stage=stage,
        stimulus=stimulus,
        route_effect=route_effect,
        kwargs=k,
        noise_suppressor=ns or dict(enabled=False, threshold=35, decay=40,
                                    damp=70, mode=0),
        compressor=comp or dict(enabled=False, threshold=45, ratio=35,
                                response=45, makeup=50),
        wah=wah or dict(enabled=False, position=0, q=50, volume=50, bias=50,
                        position_raw=None),
        notes=notes,
        reference_sources=refs or [],
    )


def pedal_mask(name):
    pedals = ["clean_boost", "tube_screamer", "rat", "ds1",
              "big_muff", "fuzz_face", "metal"]
    return 1 << pedals.index(name)


def build_cases(suite):
    cases = []

    baseline_stimuli = ["sine_1k", "sweep", "pluck", "multisine", "impulse", "silence"]
    for stim in baseline_stimuli:
        cases.append(case("bypass_axis_{}".format(stim), "bypass_axis",
                          stim, route_effect="passthrough",
                          notes="AXIS switch passthrough, no DSP chain"))
        cases.append(case("bypass_chain_{}".format(stim), "bypass_chain",
                          stim, route_effect="guitar_chain",
                          notes="DSP chain all-off bypass"))

    cases.append(case(
        "noise_suppressor_decay_floor", "noise_suppressor", "decay_floor",
        kwargs=dict(noise_gate_on=True, noise_gate_threshold=55),
        ns=dict(enabled=True, threshold=55, decay=20, damp=90, mode=0),
        refs=["BYOD", "spotify/pedalboard"]))
    cases.append(case(
        "noise_suppressor_silence", "noise_suppressor", "silence",
        kwargs=dict(noise_gate_on=True, noise_gate_threshold=55),
        ns=dict(enabled=True, threshold=55, decay=20, damp=90, mode=0)))

    cases.append(case(
        "compressor_level_steps", "compressor", "level_steps",
        comp=dict(enabled=True, threshold=50, ratio=65, response=35, makeup=55),
        refs=["spotify/pedalboard", "BYOD"]))
    cases.append(case(
        "compressor_pluck", "compressor", "pluck",
        comp=dict(enabled=True, threshold=45, ratio=60, response=65, makeup=60)))

    for pos in [0, 25, 50, 75, 100]:
        cases.append(case(
            "wah_pos{:03d}_sweep".format(pos), "wah", "sweep",
            wah=dict(enabled=True, position=pos, q=60, volume=50, bias=50,
                     position_raw=None)))

    overdrives = ["ts9", "od1", "bd2", "jan_ray", "ocd", "centaur"]
    for idx, name in enumerate(overdrives):
        cases.append(case(
            "overdrive_{}_pluck".format(name), "overdrive", "pluck",
            kwargs=dict(overdrive_on=True, overdrive_model=idx,
                        overdrive_drive=58, overdrive_tone=60,
                        overdrive_level=90),
            refs=["BYOD", "Airwindows Dirt/Edge family"]))
        if suite == "full":
            cases.append(case(
                "overdrive_{}_sine_1k".format(name), "overdrive", "sine_1k",
                kwargs=dict(overdrive_on=True, overdrive_model=idx,
                            overdrive_drive=58, overdrive_tone=60,
                            overdrive_level=90)))

    pedals = ["clean_boost", "tube_screamer", "rat", "ds1",
              "big_muff", "fuzz_face", "metal"]
    for name in pedals:
        k = dict(distortion_on=True, distortion_pedal_mask=pedal_mask(name),
                 distortion=64, distortion_tone=55, distortion_level=30,
                 distortion_bias=50, distortion_tight=55, distortion_mix=100)
        if name == "rat":
            k.update(rat_on=True, rat_filter=45, rat_level=30,
                     rat_drive=64, rat_mix=100)
        if name == "metal":
            k.update(distortion=70, distortion_level=28, distortion_tight=80)
        cases.append(case("dist_{}_pluck".format(name), "distortion", "pluck",
                          kwargs=k, refs=["BYOD", "Airwindows Dirt/Edge family"]))
        if suite == "full":
            cases.append(case("dist_{}_sine_440".format(name), "distortion",
                              "sine_440", kwargs=k))
            cases.append(case("dist_{}_two_tone".format(name), "distortion",
                              "two_tone", kwargs=k))

    amp_models = ["jc_120", "twin_reverb", "ac30",
                  "rockerverb", "jcm800", "triamp_mk3"]
    for idx, name in enumerate(amp_models):
        for drive_mode in ([0, 1] if suite == "full" else [1]):
            cases.append(case(
                "amp_{}_mode{}_pluck".format(name, drive_mode),
                "amp", "pluck",
                kwargs=dict(amp_on=True, amp_model_idx=idx,
                            amp_drive_mode=drive_mode,
                            amp_input_gain=48 if drive_mode else 38,
                            amp_bass=52, amp_middle=56, amp_treble=60,
                            amp_presence=64, amp_resonance=42,
                            amp_master=78),
                refs=["Neural Amp Modeler", "AIDA-X", "Airwindows Dirt/Edge family"]))

    for model in [0, 1, 2]:
        for air in ([0, 50, 100] if suite == "full" else [50]):
            cases.append(case(
                "cab_model{}_air{:03d}_sweep".format(model, air),
                "cab", "sweep",
                kwargs=dict(cab_on=True, cab_model=model, cab_air=air,
                            cab_mix=100, cab_level=100),
                refs=["AIDA-X"]))

    for label, low, mid, high in [
            ("low_boost", 160, 100, 100),
            ("mid_cut", 100, 55, 100),
            ("high_boost", 100, 100, 155)]:
        cases.append(case(
            "eq_{}_sweep".format(label), "eq", "sweep",
            kwargs=dict(eq_on=True, eq_low=low, eq_mid=mid, eq_high=high)))

    for label, decay, tone, mix in [
            ("short", 25, 65, 20),
            ("long", 70, 55, 35)]:
        cases.append(case(
            "reverb_{}_impulse".format(label), "reverb", "impulse",
            kwargs=dict(reverb_on=True, reverb_decay=decay,
                        reverb_tone=tone, reverb_mix=mix),
            refs=["spotify/pedalboard", "AIDA-X"]))

    chain_common = dict(cab_on=True, cab_model=1, cab_air=60,
                        cab_mix=85, cab_level=95,
                        reverb_on=True, reverb_decay=25,
                        reverb_tone=65, reverb_mix=15)
    cases.append(case(
        "chain_basic_clean_pluck", "chain", "pluck",
        kwargs=dict(chain_common, amp_on=True, amp_model_idx=0,
                    amp_drive_mode=0, amp_input_gain=38,
                    amp_treble=62, amp_presence=45, amp_master=75),
        comp=dict(enabled=True, threshold=50, ratio=25, response=50, makeup=52)))
    cases.append(case(
        "chain_light_crunch_pluck", "chain", "pluck",
        kwargs=dict(chain_common, overdrive_on=True, overdrive_model=0,
                    overdrive_drive=45, overdrive_tone=60, overdrive_level=80,
                    amp_on=True, amp_model_idx=2, amp_drive_mode=1,
                    amp_input_gain=46, amp_master=70)))
    cases.append(case(
        "chain_metal_tight_pluck", "chain", "pluck",
        kwargs=dict(chain_common, noise_gate_on=True, noise_gate_threshold=55,
                    distortion_on=True, distortion_pedal_mask=pedal_mask("metal"),
                    distortion=70, distortion_tone=55, distortion_level=28,
                    distortion_tight=80, amp_on=True, amp_model_idx=5,
                    amp_drive_mode=1, amp_input_gain=55, amp_presence=70,
                    amp_master=65, eq_on=True, eq_low=95, eq_mid=90,
                    eq_high=115),
        ns=dict(enabled=True, threshold=55, decay=20, damp=90, mode=0),
        comp=dict(enabled=True, threshold=60, ratio=40, response=35, makeup=50)))
    cases.append(case(
        "chain_fuzz_wall_pluck", "chain", "pluck",
        kwargs=dict(chain_common, distortion_on=True,
                    distortion_pedal_mask=pedal_mask("fuzz_face"),
                    distortion=74, distortion_tone=45, distortion_level=25,
                    distortion_bias=40, distortion_tight=20,
                    amp_on=True, amp_model_idx=3, amp_drive_mode=1,
                    amp_input_gain=48, amp_master=68)))

    if suite == "quick":
        keep = []
        wanted = [
            "bypass_axis_sine_1k", "bypass_chain_sine_1k",
            "bypass_chain_sweep", "bypass_chain_pluck",
            "noise_suppressor_decay_floor", "compressor_level_steps",
            "wah_pos050_sweep", "overdrive_ts9_pluck",
            "overdrive_bd2_pluck", "dist_rat_pluck", "dist_metal_pluck",
            "amp_jc_120_mode1_pluck", "amp_jcm800_mode1_pluck",
            "cab_model1_air050_sweep", "eq_mid_cut_sweep",
            "reverb_long_impulse", "chain_metal_tight_pluck",
        ]
        by_name = dict((c["name"], c) for c in cases)
        for name in wanted:
            if name in by_name:
                keep.append(by_name[name])
        cases = keep

    return cases


def find_pmod_status(overlay):
    from pynq import MMIO
    for key in sorted(getattr(overlay, "ip_dict", {})):
        if "pmod_status" in key or "pmod_i2s2_status" in key:
            entry = overlay.ip_dict[key]
            addr = entry.get("phys_addr")
            if addr is None:
                continue
            rng = entry.get("addr_range", 0x10000)
            return key, MMIO(addr, rng)
    return None, None


def pmod_snapshot(mmio):
    if mmio is None:
        return None
    out = {}
    for name, off in PMOD_REG.items():
        try:
            out[name] = int(mmio.read(off) & 0xFFFFFFFF)
        except Exception as exc:
            out[name] = "read_error: {}".format(exc)
    if isinstance(out.get("PEAK_ABS_LEFT"), int):
        out["PEAK_ABS_LEFT_dBFS"] = _dbfs(out["PEAK_ABS_LEFT"] & 0xFFFFFF)
    if isinstance(out.get("PEAK_ABS_RIGHT"), int):
        out["PEAK_ABS_RIGHT_dBFS"] = _dbfs(out["PEAK_ABS_RIGHT"] & 0xFFFFFF)
    return out


def pmod_write_mode(mmio, mode_name):
    if mmio is None or mode_name == "keep":
        return None
    mode = PMOD_MODE[mode_name]
    mmio.write(PMOD_REG["MODE"], mode & 0x3)
    time.sleep(0.02)
    return int(mmio.read(PMOD_REG["MODE"]) & 0x3)


def pmod_clear(mmio):
    if mmio is not None:
        mmio.write(PMOD_REG["CLEAR"], 1)
        time.sleep(0.02)


def control_words_for_case(AudioLabOverlay, cm, spec):
    general = AudioLabOverlay.guitar_effect_control_words(**spec["kwargs"])
    ns = spec["noise_suppressor"]
    comp = spec["compressor"]
    wah = spec["wah"]
    ns_word = cm.noise_suppressor_word(
        ns["threshold"], ns["decay"], ns["damp"], ns.get("mode", 0))
    comp_word = cm.compressor_word(
        comp["threshold"], comp["ratio"], comp["response"], comp["makeup"],
        enabled=comp["enabled"])
    wah_word = cm.wah_word(
        position=wah.get("position"),
        position_raw=wah.get("position_raw"),
        q=wah["q"],
        volume=wah["volume"],
        bias=wah["bias"],
        enabled=wah["enabled"])
    words = dict(general)
    words["ns"] = ns_word
    words["comp"] = comp_word
    words["wah"] = wah_word
    top = [
        int(words["gate"]) & 0xFFFFFFFF,
        int(words["overdrive"]) & 0xFFFFFFFF,
        int(words["distortion"]) & 0xFFFFFFFF,
        int(words["eq"]) & 0xFFFFFFFF,
        int(words["rat"]) & 0xFFFFFFFF,
        int(words["amp"]) & 0xFFFFFFFF,
        int(words["amp_tone"]) & 0xFFFFFFFF,
        int(words["cab"]) & 0xFFFFFFFF,
        int(words["reverb"]) & 0xFFFFFFFF,
        int(words["ns"]) & 0xFFFFFFFF,
        int(words["comp"]) & 0xFFFFFFFF,
        int(words["wah"]) & 0xFFFFFFFF,
    ]
    return words, top


def write_control_words(overlay, words):
    missing = []
    for key, attr in GENERAL_WORD_ATTRS:
        if hasattr(overlay, attr):
            overlay._write_gpio(getattr(overlay, attr), words[key])
        else:
            missing.append(attr)
    for key, attr in DEDICATED_WORD_ATTRS:
        if hasattr(overlay, attr):
            overlay._write_gpio(getattr(overlay, attr), words[key])
        else:
            missing.append(attr)
    return missing


class TimeoutError(RuntimeError):
    pass


def _with_alarm(timeout_s):
    if timeout_s is None or timeout_s <= 0:
        return None
    try:
        import signal
    except Exception:
        return None

    def handler(_signum, _frame):
        raise TimeoutError("DMA transfer timed out after {} s".format(timeout_s))

    old_handler = signal.signal(signal.SIGALRM, handler)
    signal.alarm(int(math.ceil(timeout_s)))
    return old_handler


def _clear_alarm(old_handler):
    if old_handler is None:
        return
    import signal
    signal.alarm(0)
    signal.signal(signal.SIGALRM, old_handler)


def dma_roundtrip(overlay, frames, route_effect, timeout_s):
    from pynq import allocate
    from audio_lab_pynq.AudioLabOverlay import XbarSource, XbarEffect, XbarSink

    effect = XbarEffect.guitar_chain
    if route_effect == "passthrough":
        effect = XbarEffect.passthrough

    overlay.route(XbarSource.dma, effect, XbarSink.dma)
    send_buf = allocate(shape=frames.shape, dtype=np.int32)
    recv_buf = allocate(shape=frames.shape, dtype=np.int32)
    old_handler = None
    try:
        send_buf[:] = frames
        old_handler = _with_alarm(timeout_s)
        overlay.axi_dma_0.recvchannel.transfer(recv_buf)
        overlay.axi_dma_0.sendchannel.transfer(send_buf)
        overlay.axi_dma_0.sendchannel.wait()
        overlay.axi_dma_0.recvchannel.wait()
        out = np.array(recv_buf)
    finally:
        _clear_alarm(old_handler)
        try:
            send_buf.freebuffer()
        except Exception:
            pass
        try:
            recv_buf.freebuffer()
        except Exception:
            pass
    return out


def analog_capture(overlay, frames):
    from audio_lab_pynq.diagnostics import capture_input
    return capture_input(overlay, num_frames=frames, restore_route=True)


def environment_info():
    bit = os.path.join(REPO, "audio_lab_pynq", "bitstreams", "audio_lab.bit")
    hwh = os.path.join(REPO, "audio_lab_pynq", "bitstreams", "audio_lab.hwh")
    return dict(
        created_utc=_timestamp(),
        host=socket.gethostname(),
        platform=platform.platform(),
        python=sys.version,
        cwd=os.getcwd(),
        repo=REPO,
        git_head=_run_text(["git", "rev-parse", "HEAD"]),
        git_branch=_run_text(["git", "branch", "--show-current"]),
        bit_md5=_md5_file(bit),
        hwh_md5=_md5_file(hwh),
        sample_rate_hz=FS,
    )


def main():
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--suite", choices=["quick", "full"], default="full",
                   help="Case suite to capture. Default: full.")
    p.add_argument("--frames", type=int, default=24000,
                   help="Frames for normal stimuli. Default: 24000 (0.25 s).")
    p.add_argument("--tail-frames", type=int, default=96000,
                   help="Frames for impulse/decay stimuli. Default: 96000.")
    p.add_argument("--out-dir", default=None,
                   help="Output directory. Default: measurements/real_hw/<timestamp>.")
    p.add_argument("--download", action="store_true",
                   help="Program the bitstream. Default is attach with download=False.")
    p.add_argument("--case-filter", action="append", default=[],
                   help="Only capture cases whose name contains this substring. "
                        "May be repeated.")
    p.add_argument("--max-cases", type=int, default=0,
                   help="Limit number of digital cases after filtering.")
    p.add_argument("--list-cases", action="store_true",
                   help="List cases and exit without touching hardware.")
    p.add_argument("--digital-timeout-s", type=float, default=20.0,
                   help="Alarm timeout per DMA roundtrip. Default: 20.")
    p.add_argument("--analog-frames", type=int, default=96000,
                   help="Also capture line_in passthrough for this many frames. "
                        "Use 0 to skip. Default: 96000.")
    p.add_argument("--start-pmod-mode", choices=["keep", "mute", "dsp"],
                   default="mute",
                   help="Pmod MODE before digital DMA captures. Default: mute.")
    p.add_argument("--leave-pmod-mode", choices=["keep", "mute", "dsp"],
                   default="mute",
                   help="Pmod MODE at script end. Default: mute.")
    p.add_argument("--stop-on-error", action="store_true",
                   help="Abort on first case error instead of recording it.")
    args = p.parse_args()

    specs = build_cases(args.suite)
    if args.case_filter:
        specs = [c for c in specs
                 if any(token in c["name"] for token in args.case_filter)]
    if args.max_cases and args.max_cases > 0:
        specs = specs[:args.max_cases]

    if args.list_cases:
        for spec in specs:
            print("{name:40s} {stage:18s} {stimulus}".format(**spec))
        return 0

    if args.out_dir is None:
        args.out_dir = os.path.join(REPO, "measurements", "real_hw", _timestamp())
    _mkdir(args.out_dir)
    cases_dir = os.path.join(args.out_dir, "cases")
    _mkdir(cases_dir)

    # Import PYNQ modules only after --list-cases.
    from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay
    from audio_lab_pynq import control_maps as cm
    from audio_lab_pynq.AudioLabOverlay import XbarSource, XbarEffect, XbarSink

    print("[collect] output: {}".format(args.out_dir))
    print("[collect] loading AudioLabOverlay(download={})".format(bool(args.download)))
    ovl = AudioLabOverlay(download=bool(args.download))
    pmod_key, pmod_mmio = find_pmod_status(ovl)

    manifest = dict(
        schema_version=1,
        environment=environment_info(),
        suite=args.suite,
        frames=args.frames,
        tail_frames=args.tail_frames,
        word_order=WORD_ORDER,
        digital_capture_caveat=(
            "DMA source samples are sent back-to-back. This is useful as a "
            "bitstream stress/cross-check and should be compared with "
            "compare_hw_reference.py --gap 0. It is not the same pacing as "
            "the live Pmod I2S2 line-in path, where valid samples arrive at "
            "96 kHz with idle DSP-island cycles between them. For live-tone "
            "fidelity, capture line_in -> guitar_chain -> dma while an "
            "external deterministic source drives Pmod Line In."
        ),
        reference_sources=REFERENCE_SOURCES,
        pmod_status_ip=pmod_key,
        pmod_start=pmod_snapshot(pmod_mmio),
        cases=[],
        analog_captures=[],
    )

    pmod_write_mode(pmod_mmio, args.start_pmod_mode)
    pmod_clear(pmod_mmio)

    for index, spec in enumerate(specs):
        name = spec["name"]
        print("[collect] {}/{} {}".format(index + 1, len(specs), name))
        case_dir = os.path.join(cases_dir, name)
        _mkdir(case_dir)
        record = dict(spec)
        record["status"] = "pending"
        record["case_dir"] = os.path.relpath(case_dir, args.out_dir)
        record["pmod_before"] = pmod_snapshot(pmod_mmio)
        try:
            words, top_words = control_words_for_case(AudioLabOverlay, cm, spec)
            missing = write_control_words(ovl, words)
            frames = stimulus_stereo(spec["stimulus"], args.frames, args.tail_frames)
            out = dma_roundtrip(
                ovl, frames, spec["route_effect"], args.digital_timeout_s)

            in_npy = os.path.join(case_dir, "input.npy")
            out_npy = os.path.join(case_dir, "hw_output.npy")
            np.save(in_npy, frames)
            np.save(out_npy, out)
            _write_wav_stereo(os.path.join(case_dir, "input.wav"), frames)
            _write_wav_stereo(os.path.join(case_dir, "hw_output.wav"), out)

            record.update(
                status="ok",
                missing_gpio=missing,
                control_words=dict((k, int(v) & 0xFFFFFFFF)
                                   for k, v in words.items()),
                control_words_topentity=[int(w) & 0xFFFFFFFF for w in top_words],
                input_file=os.path.relpath(in_npy, args.out_dir),
                hw_output_file=os.path.relpath(out_npy, args.out_dir),
                input_stats=_stats_stereo(frames),
                hw_output_stats=_stats_stereo(out),
                pmod_after=pmod_snapshot(pmod_mmio),
            )
        except Exception as exc:
            record["status"] = "error"
            record["error"] = "{}: {}".format(type(exc).__name__, exc)
            record["pmod_after"] = pmod_snapshot(pmod_mmio)
            print("[collect] ERROR {}: {}".format(name, record["error"]))
            if args.stop_on_error:
                manifest["cases"].append(record)
                _write_json(os.path.join(args.out_dir, "capture_manifest.json"),
                            manifest)
                raise
        _write_json(os.path.join(case_dir, "case.json"), record)
        manifest["cases"].append(record)
        _write_json(os.path.join(args.out_dir, "capture_manifest.json"), manifest)

    if args.analog_frames and args.analog_frames > 0:
        print("[collect] analog line_in passthrough capture: {} frames".format(
            args.analog_frames))
        analog_dir = os.path.join(args.out_dir, "analog_line_in")
        _mkdir(analog_dir)
        pmod_clear(pmod_mmio)
        analog_record = dict(
            name="analog_line_in_passthrough",
            frames=args.analog_frames,
            route="line_in -> passthrough -> dma",
            pmod_before=pmod_snapshot(pmod_mmio),
        )
        try:
            samples = analog_capture(ovl, args.analog_frames)
            npy = os.path.join(analog_dir, "analog_line_in.npy")
            np.save(npy, samples)
            _write_wav_stereo(os.path.join(analog_dir, "analog_line_in.wav"),
                              samples)
            analog_record.update(
                status="ok",
                file=os.path.relpath(npy, args.out_dir),
                stats=_stats_stereo(samples),
                pmod_after=pmod_snapshot(pmod_mmio),
            )
        except Exception as exc:
            analog_record.update(
                status="error",
                error="{}: {}".format(type(exc).__name__, exc),
                pmod_after=pmod_snapshot(pmod_mmio),
            )
        _write_json(os.path.join(analog_dir, "analog_line_in.json"),
                    analog_record)
        manifest["analog_captures"].append(analog_record)

    pmod_write_mode(pmod_mmio, args.leave_pmod_mode)
    try:
        ovl.route(XbarSource.line_in, XbarEffect.passthrough,
                  XbarSink.headphone)
    except Exception:
        pass
    manifest["pmod_end"] = pmod_snapshot(pmod_mmio)
    _write_json(os.path.join(args.out_dir, "capture_manifest.json"), manifest)
    print("[collect] done: {}".format(
        os.path.join(args.out_dir, "capture_manifest.json")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
