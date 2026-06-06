"""Per-effect default parameter dictionaries.

Centralising these keeps ``AudioLabOverlay``, the notebooks, and the
tests in agreement on what "default" looks like. The numeric ranges
are the Python-facing 0..100 / 0..200 scales documented in
``GPIO_CONTROL_MAP.md`` and ``DSP_EFFECT_CHAIN.md``.

``DISTORTION_DEFAULTS`` and ``NOISE_SUPPRESSOR_DEFAULTS`` are
re-exported by ``audio_lab_pynq.AudioLabOverlay`` as class attributes
for backward compatibility; do not change their byte-for-byte
behaviour without simultaneously updating the snapshot tests.
"""


# Distortion section (pedal mask + shared knobs).
# pedal_mask = 0 means "no pedal selected"; the section master flag
# (gate_control bit 2) starts off so loading the overlay is silent.
DISTORTION_DEFAULTS = {
    "pedal_mask": 0,
    "drive": 20,
    "tone": 50,
    "level": 35,
    "bias": 50,
    "tight": 50,
    "mix": 100,
}

# Selectable distortion pedals. Order matches the bit position in
# distortion_control.ctrlD; bit 7 is reserved.
DISTORTION_PEDALS = (
    "clean_boost",
    "tube_screamer",
    "rat",
    "ds1",
    "big_muff",
    "fuzz_face",
    "metal",
)

# Pedals that have a working Clash stage in the deployed bitstream.
# All seven pedal slots (bits 0..6) of the pedal mask now have a live
# Clash stage; bit 7 stays reserved for an 8th future pedal.
DISTORTION_PEDALS_IMPLEMENTED = (
    "clean_boost",
    "tube_screamer",
    "rat",
    "ds1",
    "big_muff",
    "fuzz_face",
    "metal",
)

# Noise Suppressor (BOSS NS-2 / NS-1X style operation).
# Driven by the dedicated axi_gpio_noise_suppressor at 0x43CC0000.
# enabled=False so loading the overlay never produces a gating
# transient; threshold/decay/damp ride the new 0..100 scale.
NOISE_SUPPRESSOR_DEFAULTS = {
    "enabled": False,
    "threshold": 35,
    "decay": 40,
    "damp": 70,
    "mode": 0,
}

# Compressor. Stereo-linked feed-forward peak compressor on its own
# axi_gpio_compressor at 0x43CD0000. Sits between the noise suppressor
# and the overdrive. enabled=False so loading the overlay never produces
# an unexpected gain change.
COMPRESSOR_DEFAULTS = {
    "enabled": False,
    "threshold": 45,
    "ratio": 35,
    "response": 45,
    "makeup": 50,
}

# Wah. Resonant band-pass wah on its own axi_gpio_wah at 0x43D30000.
# Sits between the Compressor and the Overdrive (the classic
# pre-distortion wah position). enabled=False so loading the overlay
# never produces an unexpected filter sweep; ``position`` defaults to
# 0 (heel-down, ~350 Hz centre); Q / VOLUME / BIAS default to the
# mid-range 50 so the initial sound is a mild / wide / centred BPF.
# ``source`` is a Python-side field ("manual" / "pedal") that holds
# where POSITION is being driven from -- "manual" today; FP02M /
# Arduino A0 future work will flip it to "pedal" without touching
# the GPIO byte layout.
WAH_DEFAULTS = {
    "enabled": False,
    "position": 0,         # GUI percent 0..100 (used when position_raw is None)
    "position_raw": None,  # FP02M / Arduino A0 raw byte 0..255 (D73 split)
    "q": 50,
    "volume": 50,
    "bias": 50,
    "source": "manual",
}

# Overdrive section. ``model`` is one of OVERDRIVE_MODELS (0..5);
# the generic single-character overdrive was retired in D45 and every
# load now picks one of the six selectable models. Default = TS9.
OVERDRIVE_DEFAULTS = {
    "enabled": False,
    "tone": 65,
    "level": 100,
    "drive": 30,
    "model": 0,
}

# Selectable Overdrive models. Order matches the model_select integer
# carried in overdrive_control.ctrlD[2:0] (= word bits 26..24); values
# 0..5 are valid, 6/7 fall back to TS9 in Clash.
#
# Model labels are inspired-by, not commercial circuit reproductions
# (DECISIONS.md D45). The UI display labels live alongside the internal
# enum names so AudioLabOverlay and the compact-v2 GUI can share one
# source of truth.
OVERDRIVE_MODELS = (
    "ts9",
    "od1",
    "bd2",
    "jan_ray",
    "ocd",
    "centaur",
)

OVERDRIVE_MODEL_LABELS = (
    "Ibanez / TS9",
    "BOSS / OD-1",
    "BOSS / BD-2",
    "Vemuram / Jan Ray",
    "Fulltone / OCD",
    "CENTAUR",
)

# RAT distortion (axi_gpio_delay).
RAT_DEFAULTS = {
    "enabled": False,
    "filter": 35,
    "level": 100,
    "drive": 55,
    "mix": 100,
}

# D55 Amp simulator models. Order matches the 3-bit ``amp_model_idx``
# field that the Python writer packs into ``axi_gpio_amp_tone.ctrlD[2:0]``.
# Values 0..5 are valid; 6/7 are reserved and the Clash side falls back to
# 0 = JC-120 if it ever sees them (the Python helpers clamp to
# ``AMP_MODEL_IDX_MAX = 5`` so they cannot be written through the normal
# path). Labels are inspired-by, not commercial circuit / IR /
# coefficient copies (`DECISIONS.md` D7).
#
# The legacy "amp_character percent" knob is retired (`DECISIONS.md`
# D53 / D54). ``AMP_MODELS`` still exists so back-compat lookups (e.g.
# ``set_amp_model("jc_120")``) work, but the numeric value is the
# ``amp_model_idx`` integer 0..5, not a 0..100 percent. The four
# centre values from the D52 "character band" world (10/35/60/85) are
# preserved as ``AMP_MODELS_LEGACY_PERCENT`` for any external caller
# still on that API.
AMP_MODELS = {
    "jc_120":         0,
    "twin_reverb":    1,
    "ac30":           2,
    "rockerverb":     3,
    "jcm800":         4,
    "triamp_mk3":     5,
}

AMP_MODEL_LABELS = (
    "JC-120",
    "Twin Reverb",
    "AC30",
    "Rockerverb",
    "JCM800",
    "TriAmp Mk3",
)

# Centre amp_character percent values for the retired D52 4-model API
# (kept only so the chain-preset back-compat path -- which still passes
# ``amp_character=`` -- does not regress on existing JSON presets).
AMP_MODELS_LEGACY_PERCENT = (10, 35, 60, 85)

# Amp simulator (axi_gpio_amp + axi_gpio_amp_tone).
AMP_DEFAULTS = {
    "enabled": False,
    "input_gain": 35,
    "bass": 60,       # D108: a touch more low end on the D101 amp (passes lows)
    "middle": 50,
    "treble": 60,     # D108: brighter -- compensate the D101 HP-pole HF removal
    "presence": 55,   # D108: +presence (2-5 kHz)
    "resonance": 35,
    "master": 62,     # D108: lower -- the D101 pole passes more low energy (was loud)
    "character": 35,
}

# Cab IR.
CAB_DEFAULTS = {
    "enabled": False,
    "mix": 100,
    "level": 100,
    "model": 1,  # 0/1/2 -> three preset IRs
    "air": 50,
}

# 3-band EQ.
EQ_DEFAULTS = {
    "enabled": False,
    "low": 100,
    "mid": 100,
    "high": 100,
}

# Reverb.
REVERB_DEFAULTS = {
    "enabled": False,
    "decay": 30,
    "tone": 65,
    "mix": 20,
}

# Safe Bypass: every effect off, parameters at the "neutral" end of
# their range. Used by the Notebook Safe Bypass button so nothing
# audible can leak through after a panic press.
SAFE_BYPASS_DEFAULTS = {
    "noise_gate_on": False,
    "noise_gate_threshold": 0,
    "overdrive_on": False,
    "overdrive_tone": 50,
    "overdrive_level": 100,
    "overdrive_drive": 0,
    "overdrive_model": 0,
    "distortion_on": False,
    "distortion_pedal_mask": 0,
    "distortion_tone": 50,
    "distortion_level": 35,
    "distortion": 0,
    "distortion_bias": 50,
    "distortion_tight": 50,
    "distortion_mix": 100,
    "rat_on": False,
    "rat_filter": 35,
    "rat_level": 100,
    "rat_drive": 0,
    "rat_mix": 100,
    "amp_on": False,
    "amp_input_gain": 0,
    "amp_bass": 50,
    "amp_middle": 50,
    "amp_treble": 50,
    "amp_presence": 45,
    "amp_resonance": 35,
    "amp_master": 80,
    "amp_character": 35,
    "cab_on": False,
    "cab_mix": 100,
    "cab_level": 100,
    "cab_model": 1,
    "cab_air": 50,
    "eq_on": False,
    "eq_low": 100,
    "eq_mid": 100,
    "eq_high": 100,
    "reverb_on": False,
    "reverb_decay": 0,
    "reverb_tone": 65,
    "reverb_mix": 0,
    "compressor_enabled": False,
    "compressor_threshold": 45,
    "compressor_ratio": 35,
    "compressor_response": 45,
    "compressor_makeup": 50,
    "wah_enabled": False,
    "wah_position": 0,
    "wah_position_raw": None,
    "wah_q": 50,
    "wah_volume": 50,
    "wah_bias": 50,
}


__all__ = [
    "DISTORTION_DEFAULTS",
    "DISTORTION_PEDALS",
    "DISTORTION_PEDALS_IMPLEMENTED",
    "NOISE_SUPPRESSOR_DEFAULTS",
    "COMPRESSOR_DEFAULTS",
    "WAH_DEFAULTS",
    "OVERDRIVE_DEFAULTS",
    "OVERDRIVE_MODELS",
    "OVERDRIVE_MODEL_LABELS",
    "RAT_DEFAULTS",
    "AMP_DEFAULTS",
    "AMP_MODELS",
    "AMP_MODEL_LABELS",
    "AMP_MODELS_LEGACY_PERCENT",
    "CAB_DEFAULTS",
    "EQ_DEFAULTS",
    "REVERB_DEFAULTS",
    "SAFE_BYPASS_DEFAULTS",
]
