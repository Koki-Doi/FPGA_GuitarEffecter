"""Pure effect catalog shared by the GUI, HDMI mirror, and apply layers.

This module intentionally has no NumPy, Pillow, PYNQ, or overlay imports.
It is the Python-side source of truth for GUI-visible effect names, knob
layouts, model labels, and chain-preset display names.
"""

from __future__ import print_function

from audio_lab_pynq.effect_defaults import (
    AMP_MODELS as _AMP_MODEL_CHARACTER,
    DISTORTION_PEDALS as _DISTORTION_PEDALS,
)


EFFECT_NOISE_SUP = "Noise Sup"
EFFECT_COMPRESSOR = "Compressor"
EFFECT_OVERDRIVE = "Overdrive"
EFFECT_DISTORTION = "Distortion"
EFFECT_AMP = "Amp Sim"
EFFECT_CAB = "Cab IR"
EFFECT_EQ = "EQ"
EFFECT_REVERB = "Reverb"

EFFECTS = [
    EFFECT_NOISE_SUP,
    EFFECT_COMPRESSOR,
    EFFECT_OVERDRIVE,
    EFFECT_DISTORTION,
    EFFECT_AMP,
    EFFECT_CAB,
    EFFECT_EQ,
    EFFECT_REVERB,
]
EFFECTS_SHORT = ["NS", "CMP", "OD", "DIST", "AMP", "CAB", "EQ", "RVB"]
EFFECT_INDEX = dict((name, index) for index, name in enumerate(EFFECTS))


# Compact-v2 renderer knob labels and defaults. These are the labels shown
# inside the 800x480 UI and the ordering used by AppState.all_knob_values.
EFFECT_KNOBS = {
    EFFECT_NOISE_SUP: [("THRESH", 35), ("DECAY", 45), ("DAMP", 80)],
    EFFECT_COMPRESSOR: [
        ("THRESH", 50), ("RATIO", 45), ("RESP", 40), ("MAKEUP", 55),
    ],
    EFFECT_OVERDRIVE: [("TONE", 60), ("LEVEL", 60), ("DRIVE", 35)],
    EFFECT_DISTORTION: [
        ("TONE", 55), ("LEVEL", 35), ("DRIVE", 50),
        ("BIAS", 50), ("TIGHT", 60), ("MIX", 100),
    ],
    EFFECT_AMP: [
        ("GAIN", 45), ("BASS", 55), ("MID", 60), ("TREB", 50),
        ("PRES", 50), ("RES", 50), ("MSTR", 70), ("CHAR", 60),
    ],
    EFFECT_CAB: [("MIX", 100), ("LEVEL", 70), ("MODEL", 33), ("AIR", 35)],
    EFFECT_EQ: [("LOW", 50), ("MID", 55), ("HIGH", 55)],
    EFFECT_REVERB: [("DECAY", 30), ("TONE", 65), ("MIX", 25)],
}

EFFECT_KNOB_DEFAULTS = dict(
    (name, [float(default) for _label, default in knobs])
    for name, knobs in EFFECT_KNOBS.items()
)


# HdmiEffectStateMirror's legacy 8-slot knob table. It is kept as a named
# variant because external tests and notebook summaries still use the long
# labels and the eight-slot shape.
MIRROR_EFFECT_KNOBS = {
    EFFECT_NOISE_SUP: [
        ("THRESHOLD", 35), ("DECAY", 45), ("DAMP", 80),
        ("", 0), ("", 0), ("", 0), ("", 0), ("", 0),
    ],
    EFFECT_COMPRESSOR: [
        ("THRESHOLD", 50), ("RATIO", 45), ("RESPONSE", 40),
        ("MAKEUP", 55), ("", 0), ("", 0), ("", 0), ("", 0),
    ],
    EFFECT_OVERDRIVE: [
        ("DRIVE", 35), ("TONE", 60), ("LEVEL", 60),
        ("", 0), ("", 0), ("", 0), ("", 0), ("", 0),
    ],
    EFFECT_DISTORTION: [
        ("DRIVE", 50), ("TONE", 55), ("LEVEL", 35),
        ("BIAS", 50), ("TIGHT", 60), ("MIX", 100),
        ("", 0), ("", 0),
    ],
    EFFECT_AMP: [
        ("GAIN", 45), ("BASS", 55), ("MIDDLE", 60),
        ("TREBLE", 50), ("PRESENCE", 45), ("RESONANCE", 35),
        ("MASTER", 70), ("CHARACTER", 60),
    ],
    EFFECT_CAB: [
        ("MIX", 100), ("LEVEL", 70), ("MODEL", 33),
        ("AIR", 35), ("", 0), ("", 0), ("", 0), ("", 0),
    ],
    EFFECT_EQ: [
        ("LOW", 50), ("MID", 55), ("HIGH", 55),
        ("", 0), ("", 0), ("", 0), ("", 0), ("", 0),
    ],
    EFFECT_REVERB: [
        ("DECAY", 30), ("TONE", 65), ("MIX", 25),
        ("", 0), ("", 0), ("", 0), ("", 0), ("", 0),
    ],
}


PEDAL_MODELS = tuple(_DISTORTION_PEDALS)
PEDAL_MODEL_LABELS = {
    "clean_boost": "CLEAN BOOST",
    "tube_screamer": "TUBE SCREAMER",
    "rat": "RAT",
    "ds1": "DS-1",
    "big_muff": "BIG MUFF",
    "fuzz_face": "FUZZ FACE",
    "metal": "METAL",
}
PEDAL_MODEL_TO_INDEX = dict((name, index)
                            for index, name in enumerate(PEDAL_MODELS))
PEDAL_LABEL_TO_MODEL = dict((label, name)
                            for name, label in PEDAL_MODEL_LABELS.items())
DIST_MODELS = [PEDAL_MODEL_LABELS[name] for name in PEDAL_MODELS]
DISTORTION_PEDALS = list(PEDAL_MODELS)


AMP_MODELS = (
    "jc_clean",
    "clean_combo",
    "british_crunch",
    "high_gain_stack",
)
AMP_MODEL_LABELS = {
    "jc_clean": "JC CLEAN",
    "clean_combo": "CLEAN COMBO",
    "british_crunch": "BRITISH CRUNCH",
    "high_gain_stack": "HIGH GAIN STACK",
}
AMP_MODEL_CHARACTER = dict(
    (name, int(_AMP_MODEL_CHARACTER[name])) for name in AMP_MODELS
)
AMP_MODEL_TO_INDEX = dict((name, index)
                          for index, name in enumerate(AMP_MODELS))
GUI_AMP_MODELS = [
    (AMP_MODEL_LABELS[name], AMP_MODEL_CHARACTER[name])
    for name in AMP_MODELS
]


CAB_MODELS = ("1x12", "2x12", "4x12")
CAB_MODEL_LABELS = {
    "1x12": "1x12 OPEN",
    "2x12": "2x12 COMBO",
    "4x12": "4x12 CLOSED",
}
CAB_MODEL_TO_INDEX = dict((name, index)
                          for index, name in enumerate(CAB_MODELS))
GUI_CAB_MODELS = ["1x12 OPEN BACK", "2x12 BRITISH", "4x12 CLOSED"]


CHAIN_PRESETS = [
    "Safe Bypass", "Basic Clean", "Clean Sustain", "Light Crunch",
    "TS Lead", "RAT Rhythm", "Metal Tight", "Ambient Clean",
    "Solo Boost", "Noise Controlled High Gain",
    "DS-1 Crunch", "Big Muff Sustain", "Vintage Fuzz",
]
PRESET_NAME_ALIASES = {
    "TS Lead": "Tube Screamer Lead",
}


__all__ = [
    "EFFECT_NOISE_SUP",
    "EFFECT_COMPRESSOR",
    "EFFECT_OVERDRIVE",
    "EFFECT_DISTORTION",
    "EFFECT_AMP",
    "EFFECT_CAB",
    "EFFECT_EQ",
    "EFFECT_REVERB",
    "EFFECTS",
    "EFFECTS_SHORT",
    "EFFECT_INDEX",
    "EFFECT_KNOBS",
    "EFFECT_KNOB_DEFAULTS",
    "MIRROR_EFFECT_KNOBS",
    "PEDAL_MODELS",
    "PEDAL_MODEL_LABELS",
    "PEDAL_MODEL_TO_INDEX",
    "PEDAL_LABEL_TO_MODEL",
    "DIST_MODELS",
    "DISTORTION_PEDALS",
    "AMP_MODELS",
    "AMP_MODEL_LABELS",
    "AMP_MODEL_CHARACTER",
    "AMP_MODEL_TO_INDEX",
    "GUI_AMP_MODELS",
    "CAB_MODELS",
    "CAB_MODEL_LABELS",
    "CAB_MODEL_TO_INDEX",
    "GUI_CAB_MODELS",
    "CHAIN_PRESETS",
    "PRESET_NAME_ALIASES",
]
