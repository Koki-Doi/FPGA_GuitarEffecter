"""Per-effect knob layout + model tables + chain preset names for the
compact-v2 800x480 GUI.

Pure constants; no PIL / numpy / state imports. Other compact_v2
submodules and the legacy ``pynq_multi_fx_gui`` shim re-export these
names so existing notebook / script imports keep working.
"""

from typing import List, Tuple  # noqa: F401  -- referenced by external callers

EFFECTS = ["Noise Sup", "Compressor", "Overdrive", "Distortion",
           "Amp Sim", "Cab IR", "EQ", "Reverb"]
EFFECTS_SHORT = ["NS", "CMP", "OD", "DIST", "AMP", "CAB", "EQ", "RVB"]

# Per-effect knob assignments (label, default 0..100).
# Amp Sim has 8 params (4x2 grid); all others have ≤6.
EFFECT_KNOBS = {
    "Noise Sup":  [("THRESH", 35),  ("DECAY",  45),  ("DAMP",   80)],
    "Compressor": [("THRESH", 50),  ("RATIO",  45),  ("RESP",   40),  ("MAKEUP", 55)],
    "Overdrive":  [("TONE",   60),  ("LEVEL",  60),  ("DRIVE",  35)],
    "Distortion": [("TONE",   55),  ("LEVEL",  35),  ("DRIVE",  50),
                   ("BIAS",   50),  ("TIGHT",  60),  ("MIX",   100)],
    "Amp Sim":    [("GAIN",   45),  ("BASS",   55),  ("MID",    60),  ("TREB",  50),
                   ("PRES",   50),  ("RES",    50),  ("MSTR",   70),  ("DRV MODE", 0)],
    "Cab IR":     [("MIX",   100),  ("LEVEL",  70),  ("MODEL",  33),  ("AIR",   35)],
    "EQ":         [("LOW",    50),  ("MID",    55),  ("HIGH",   55)],
    "Reverb":     [("DECAY",  30),  ("TONE",   65),  ("MIX",    25)],
}

# Pre-computed default knob values for per-effect initialisation.
_EFFECT_KNOB_DEFAULTS = {
    name: [float(k[1]) for k in knobs]
    for name, knobs in EFFECT_KNOBS.items()
}

# Binary knobs (effect_name, knob_index): value clamped to {0.0, 1.0}.
# Amp Sim slot 7 replaced the old continuous CHAR knob (D53): the amp
# character byte is now derived from amp_model_idx only, and the user
# only chooses a 0/1 DRV MODE here that shifts the character byte
# within its amp-model band (see AudioLabOverlay.amp_tone_word_for_model
# and DECISIONS.md D53).
BINARY_KNOBS = {
    ("Amp Sim", 7),
}


def is_binary_knob(effect_name, knob_index):
    """Return True if the knob at (effect_name, knob_index) is 0/1 only."""
    try:
        return (str(effect_name), int(knob_index)) in BINARY_KNOBS
    except Exception:
        return False


def binary_knob_display(value):
    """Snap value to '0' or '1' for renderer display of a binary knob."""
    try:
        return 1 if float(value) >= 0.5 else 0
    except Exception:
        return 0

# Distortion Pedalboard model names (pedal-mask bit -> name).
DIST_MODELS = ["CLEAN BOOST", "TUBE SCREAMER", "RAT", "DS-1",
               "BIG MUFF", "FUZZ FACE", "METAL"]
# Legacy alias.
DISTORTION_PEDALS = [m.lower().replace(" ", "_").replace("-", "") for m in DIST_MODELS]

# Overdrive model names. Order matches the 3-bit OD_MODEL field carried
# in axi_gpio_overdrive.ctrlD[2:0] (DECISIONS.md D45). Values 0..5 are
# valid; the Clash side falls back to 0 (TS9) for 6/7. The single
# generic Overdrive was retired -- every load picks one of these six.
OVERDRIVE_MODELS = [
    "Ibanez / TS9",
    "BOSS / OD-1",
    "BOSS / BD-2",
    "Vemuram / Jan Ray",
    "Fulltone / OCD",
    "CENTAUR",
]

# Amp Simulator named voicings (label, character byte center value).
AMP_MODELS = [("JC CLEAN", 10), ("CLEAN COMBO", 35),
              ("BRITISH CRUNCH", 60), ("HIGH GAIN STACK", 85)]

# Cabinet IR model names.
CAB_MODELS = ["1x12 OPEN BACK", "2x12 BRITISH", "4x12 CLOSED"]

# 13 Chain Presets (1-click chain swap).
CHAIN_PRESETS = [
    "Safe Bypass", "Basic Clean", "Clean Sustain", "Light Crunch",
    "TS Lead", "RAT Rhythm", "Metal Tight", "Ambient Clean",
    "Solo Boost", "Noise Controlled High Gain",
    "DS-1 Crunch", "Big Muff Sustain", "Vintage Fuzz",
]
