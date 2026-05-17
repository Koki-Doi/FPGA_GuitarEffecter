"""Per-effect knob layout + model tables + chain preset names.

The canonical, renderer-independent catalog lives in
``audio_lab_pynq.effect_catalog``. This module preserves the historical
``GUI.compact_v2.knobs`` import path used by the renderer, notebooks, and
tests.
"""

from typing import List, Tuple  # noqa: F401  -- referenced by external callers

try:
    from audio_lab_pynq.effect_catalog import (
        CHAIN_PRESETS,
        DIST_MODELS,
        DISTORTION_PEDALS,
        EFFECTS,
        EFFECTS_SHORT,
        EFFECT_KNOBS,
        EFFECT_KNOB_DEFAULTS as _EFFECT_KNOB_DEFAULTS,
        GUI_AMP_MODELS as AMP_MODELS,
        GUI_CAB_MODELS as CAB_MODELS,
    )
except Exception:  # pragma: no cover - supports isolated GUI copies.
    EFFECTS = ["Noise Sup", "Compressor", "Overdrive", "Distortion",
               "Amp Sim", "Cab IR", "EQ", "Reverb"]
    EFFECTS_SHORT = ["NS", "CMP", "OD", "DIST", "AMP", "CAB", "EQ", "RVB"]
    EFFECT_KNOBS = {
        "Noise Sup": [("THRESH", 35), ("DECAY", 45), ("DAMP", 80)],
        "Compressor": [
            ("THRESH", 50), ("RATIO", 45), ("RESP", 40), ("MAKEUP", 55),
        ],
        "Overdrive": [("TONE", 60), ("LEVEL", 60), ("DRIVE", 35)],
        "Distortion": [
            ("TONE", 55), ("LEVEL", 35), ("DRIVE", 50),
            ("BIAS", 50), ("TIGHT", 60), ("MIX", 100),
        ],
        "Amp Sim": [
            ("GAIN", 45), ("BASS", 55), ("MID", 60), ("TREB", 50),
            ("PRES", 50), ("RES", 50), ("MSTR", 70), ("CHAR", 60),
        ],
        "Cab IR": [("MIX", 100), ("LEVEL", 70), ("MODEL", 33), ("AIR", 35)],
        "EQ": [("LOW", 50), ("MID", 55), ("HIGH", 55)],
        "Reverb": [("DECAY", 30), ("TONE", 65), ("MIX", 25)],
    }
    _EFFECT_KNOB_DEFAULTS = dict(
        (name, [float(k[1]) for k in knobs])
        for name, knobs in EFFECT_KNOBS.items())
    DIST_MODELS = ["CLEAN BOOST", "TUBE SCREAMER", "RAT", "DS-1",
                   "BIG MUFF", "FUZZ FACE", "METAL"]
    DISTORTION_PEDALS = [
        "clean_boost", "tube_screamer", "rat", "ds1",
        "big_muff", "fuzz_face", "metal",
    ]
    AMP_MODELS = [("JC CLEAN", 10), ("CLEAN COMBO", 35),
                  ("BRITISH CRUNCH", 60), ("HIGH GAIN STACK", 85)]
    CAB_MODELS = ["1x12 OPEN BACK", "2x12 BRITISH", "4x12 CLOSED"]
    CHAIN_PRESETS = [
        "Safe Bypass", "Basic Clean", "Clean Sustain", "Light Crunch",
        "TS Lead", "RAT Rhythm", "Metal Tight", "Ambient Clean",
        "Solo Boost", "Noise Controlled High Gain",
        "DS-1 Crunch", "Big Muff Sustain", "Vintage Fuzz",
    ]
