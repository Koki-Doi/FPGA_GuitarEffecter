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

# Overdrive section.
OVERDRIVE_DEFAULTS = {
    "enabled": False,
    "tone": 65,
    "level": 100,
    "drive": 30,
}

# RAT distortion (axi_gpio_delay).
RAT_DEFAULTS = {
    "enabled": False,
    "filter": 35,
    "level": 100,
    "drive": 55,
    "mix": 100,
}

# Amp simulator named "models" -- convenience labels that map onto the
# existing ``amp_character`` percent value. Four models are documented;
# they are inspirations, not commercial circuit / IR / coefficient
# copies (DECISIONS.md D7). The numeric ``amp_character`` knob still
# works directly; this dict only adds a friendlier API on top.
#
# Bands inside the Clash ``ampModelSel`` helper:
#   character 0..24   -> model 0 (jc_clean)
#   character 25..49  -> model 1 (clean_combo)
#   character 50..74  -> model 2 (british_crunch)
#   character 75..100 -> model 3 (high_gain_stack)
# The values below land in the centre of each band so the labelled
# voicings are stable against a small notebook bump.
AMP_MODELS = {
    "jc_clean":        10,
    "clean_combo":     35,
    "british_crunch":  60,
    "high_gain_stack": 85,
}

# Amp simulator (axi_gpio_amp + axi_gpio_amp_tone).
AMP_DEFAULTS = {
    "enabled": False,
    "input_gain": 35,
    "bass": 50,
    "middle": 50,
    "treble": 50,
    "presence": 45,
    "resonance": 35,
    "master": 80,
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
}


__all__ = [
    "DISTORTION_DEFAULTS",
    "DISTORTION_PEDALS",
    "DISTORTION_PEDALS_IMPLEMENTED",
    "NOISE_SUPPRESSOR_DEFAULTS",
    "COMPRESSOR_DEFAULTS",
    "OVERDRIVE_DEFAULTS",
    "RAT_DEFAULTS",
    "AMP_DEFAULTS",
    "AMP_MODELS",
    "CAB_DEFAULTS",
    "EQ_DEFAULTS",
    "REVERB_DEFAULTS",
    "SAFE_BYPASS_DEFAULTS",
]
