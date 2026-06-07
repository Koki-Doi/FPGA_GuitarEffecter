"""Per-effect knob layout + model tables + chain preset names for the
compact-v2 800x480 GUI.

Pure constants; no PIL / numpy / state imports. Other compact_v2
submodules and the legacy ``pynq_multi_fx_gui`` shim re-export these
names so existing notebook / script imports keep working.
"""

from typing import List, Tuple  # noqa: F401  -- referenced by external callers

EFFECTS = ["Noise Sup", "Compressor", "Wah", "Overdrive", "Distortion",
           "Amp Sim", "Cab IR", "EQ", "Reverb"]
EFFECTS_SHORT = ["NS", "CMP", "WAH", "OD", "DIST", "AMP", "CAB", "EQ", "RVB"]

# Per-effect knob assignments (label, default 0..100).
# Amp Sim has 8 params (4x2 grid); all others have <=6.
EFFECT_KNOBS = {
    "Noise Sup":  [("THRESH", 20),  ("DECAY",  90),  ("DAMP",  100)],
    "Compressor": [("THRESH", 30),  ("RATIO",  70),  ("RESP",   85),  ("MAKEUP", 55)],
    "Wah":        [("POS",     0),  ("Q",      50),  ("VOL",    50),  ("BIAS",   50)],
    "Overdrive":  [("TONE",   35),  ("LEVEL",  50),  ("DRIVE",  55)],
    "Distortion": [("TONE",   50),  ("LEVEL",  35),  ("DRIVE",  50),
                   ("BIAS",   50),  ("TIGHT",  60),  ("MIX",   100)],
    "Amp Sim":    [("GAIN",   80),  ("BASS",   50),  ("MID",    65),  ("TREB",  72),
                   ("PRES",   78),  ("RES",    70),  ("MSTR",   70),  ("DRV MODE", 1)],
    "Cab IR":     [("MIX",   100),  ("LEVEL",  70),  ("MODEL",  33),  ("AIR",  100)],
    "EQ":         [("LOW",    50),  ("MID",    50),  ("HIGH",   50)],
    "Reverb":     [("DECAY",  30),  ("TONE",   65),  ("MIX",    65)],
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

# Amp Simulator named voicings (D55). The list index IS the
# ``amp_model_idx`` 0..5 written to ``axi_gpio_amp_tone.ctrlD[2:0]``;
# the tuple shape is preserved as (label, idx) so existing callers
# that index the second tuple field keep working. The Clash voicings
# are described in ``docs/ai_context/AMP_MODEL_RESEARCH_D55.md``.
AMP_MODELS = [
    ("JC-120",       0),
    ("Twin Reverb",  1),
    ("AC30",         2),
    ("Rockerverb",   3),
    ("JCM800",       4),
    ("TriAmp Mk3",   5),
]

# Cabinet IR model names.
CAB_MODELS = ["1x12 OPEN BACK", "2x12 BRITISH", "4x12 CLOSED"]

# 13 Chain Presets (1-click chain swap).
CHAIN_PRESETS = [
    "Safe Bypass", "Basic Clean", "Clean Sustain", "Light Crunch",
    "TS Lead", "RAT Rhythm", "Metal Tight", "Ambient Clean",
    "Solo Boost", "Noise Controlled High Gain",
    "DS-1 Crunch", "Big Muff Sustain", "Vintage Fuzz",
]
