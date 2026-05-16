"""
DOY FX CORE — Multi-Effects Processor GUI (800x480 logical)
===========================================================
Multi-effects pedal GUI for the 5-inch HDMI LCD wired through the
integrated AudioLab overlay (`audio_lab.bit`). Pure PIL + NumPy.

Public API
----------
    state = AppState()
    frame = render_frame_800x480_compact_v2(state)  # (480, 800, 3) uint8

`render_frame_800x480(state, variant="compact-v1")` preserves the Phase 4E
logical layout for diagnostic scripts. The 1280x720 reference layout and
the Tkinter desktop preview app (Windows-only) were removed once the
compact-v2 LCD layout was confirmed on the live PYNQ HDMI output.
"""

import json
import math
import os
import time
from typing import Dict, List, Tuple, Optional

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

try:
    from dataclasses import dataclass, field
except ImportError:
    _MISSING = object()

    class _CompatField:
        def __init__(self, default=_MISSING, default_factory=_MISSING):
            self.default = default
            self.default_factory = default_factory

        def value(self):
            if self.default_factory is not _MISSING:
                return self.default_factory()
            if self.default is not _MISSING:
                return self.default
            raise TypeError("missing default")

    def field(default=_MISSING, default_factory=_MISSING):
        return _CompatField(default=default, default_factory=default_factory)

    def dataclass(cls):
        annotations = getattr(cls, "__annotations__", {})
        names = list(annotations.keys())
        defaults = {name: getattr(cls, name, _MISSING) for name in names}

        def __init__(self, *args, **kwargs):
            if len(args) > len(names):
                raise TypeError("__init__() takes %d positional arguments but %d were given" %
                                (len(names) + 1, len(args) + 1))
            positional = dict(zip(names, args))
            for name in names:
                if name in positional and name in kwargs:
                    raise TypeError("__init__() got multiple values for argument '%s'" % name)
                if name in positional:
                    value = positional[name]
                elif name in kwargs:
                    value = kwargs.pop(name)
                else:
                    default = defaults.get(name, _MISSING)
                    if isinstance(default, _CompatField):
                        value = default.value()
                    elif default is not _MISSING:
                        value = default
                    else:
                        raise TypeError("__init__() missing required argument: '%s'" % name)
                setattr(self, name, value)
            if kwargs:
                unknown = next(iter(kwargs))
                raise TypeError("__init__() got an unexpected keyword argument '%s'" % unknown)

        def __repr__(self):
            parts = ["%s=%r" % (name, getattr(self, name)) for name in names]
            return "%s(%s)" % (cls.__name__, ", ".join(parts))

        cls.__init__ = __init__
        cls.__repr__ = __repr__
        return cls


class _RandomStateCompat:
    """Small adapter for NumPy 1.16, which has RandomState but no default_rng."""
    def __init__(self, seed=None):
        self._rng = np.random.RandomState(seed)

    def integers(self, low, high=None, size=None, dtype=None, endpoint=False):
        if high is None:
            low, high = 0, low
        if endpoint:
            high = high + 1
        values = self._rng.randint(low, high=high, size=size)
        if dtype is not None:
            if hasattr(values, "astype"):
                values = values.astype(dtype)
            else:
                values = np.asarray(values, dtype=dtype).item()
        return values

    def uniform(self, low=0.0, high=1.0, size=None):
        return self._rng.uniform(low, high, size)


def _rng(seed=None):
    if hasattr(np.random, "default_rng"):
        return np.random.default_rng(seed)
    return _RandomStateCompat(seed)


def _patch_old_pillow_draw_keywords():
    """Allow Pillow 5.1 on PYNQ to ignore newer ImageDraw keyword arguments."""
    draw_cls = ImageDraw.ImageDraw
    if getattr(draw_cls, "_audio_lab_keyword_compat", False):
        return

    def wrap_method(name, drop_sequences):
        original = getattr(draw_cls, name, None)
        if original is None:
            return

        def wrapped(self, *args, **kwargs):
            try:
                return original(self, *args, **kwargs)
            except TypeError as first_error:
                last_error = first_error
                for drop_keys in drop_sequences:
                    reduced = dict(kwargs)
                    changed = False
                    for key in drop_keys:
                        if key in reduced:
                            changed = True
                            reduced.pop(key, None)
                    if not changed:
                        continue
                    try:
                        return original(self, *args, **reduced)
                    except TypeError as error:
                        last_error = error
                raise last_error

        setattr(draw_cls, name, wrapped)

    wrap_method("rectangle", [("width",)])
    wrap_method("ellipse", [("width",)])
    wrap_method("arc", [("width",)])
    wrap_method("polygon", [("width",)])
    wrap_method("line", [("joint",), ("joint", "width")])
    wrap_method("rounded_rectangle", [("width",)])
    draw_cls._audio_lab_keyword_compat = True


_patch_old_pillow_draw_keywords()

# Active render cache used by low-level helpers. Kept as a simple global so
# the existing draw_* functions can be accelerated without changing every
# function signature.
_ACTIVE_RENDER_CACHE = None


def _pynq_static_mode() -> bool:
    return bool(getattr(_ACTIVE_RENDER_CACHE, "pynq_static_mode", False))


# =============================================================================
# CANVAS / PALETTE
# =============================================================================

# Chassis (metallic black)
CHASSIS_HI       = (52, 56, 64)
CHASSIS_MID_HI   = (38, 42, 48)
CHASSIS_MID      = (28, 32, 38)
CHASSIS_MID_LO   = (20, 23, 28)
CHASSIS_LO       = (10, 12, 16)
CHASSIS_EDGE     = (74, 79, 87)
CHASSIS_INK      = (5, 6, 9)

# Cyan / blue LED accent
LED              = (0, 229, 255)
LED_SOFT         = (140, 246, 255)
LED_DIM          = (0, 122, 156)
LED_DEEP         = (0, 60, 80)
LED_GHOST        = (10, 36, 46)

# Display (LCD) colours
SCR_BG           = (6, 9, 16)
SCR_BG_HI        = (10, 14, 24)
SCR_GRID         = (14, 38, 50)
SCR_TEXT         = (185, 247, 255)
SCR_TEXT_DIM     = (77, 138, 154)
SCR_TEXT_DEAD    = (44, 83, 96)

# Warning / hot
WARN_AMBER       = (255, 170, 60)
WARN_RED         = (255, 64, 48)

# Text
INK_HI           = (220, 230, 240)
INK_MID          = (140, 152, 165)
INK_LO           = (90, 100, 112)


# =============================================================================
# 800x480 THEME PALETTES
# =============================================================================
# Phase 5D introduces a Pip-Boy-inspired phosphor-green palette for the
# 5-inch LCD compact-v2 layout. The look is "phosphor green monochrome
# CRT" with an amber warning accent, dark olive background, and a soft
# horizontal scanline overlay -- no Pip-Boy logo, fonts, icons, or
# screen layouts are copied. The original cyan palette is preserved as
# theme "cyan" for legacy callers.
#
# Each theme is a flat dict. The compact-v2 renderer reads colours only
# from the palette dict; the 1280x720 / compact-v1 paths still read
# from the module-level constants above and are not retuned in this
# phase.

def _make_theme(*, name,
                led, led_soft, led_dim, led_deep, led_ghost,
                scr_text, scr_text_dim, scr_text_dead, scr_grid,
                ink_hi, ink_mid, ink_lo,
                warn_amber, bypass_col,
                bg_grad,
                chassis_inner_fill,
                panel_header_fill, panel_chain_fill, panel_fx_fill,
                header_chip_fill, fx_chip_fill,
                chain_on_fill, chain_off_fill,
                chain_off_outline, chain_off_text, chain_badge_off,
                bar_bg_fill, bar_outline,
                scanline_rgba=None, scanline_step=0):
    return {
        "name": name,
        "LED": led, "LED_SOFT": led_soft, "LED_DIM": led_dim,
        "LED_DEEP": led_deep, "LED_GHOST": led_ghost,
        "SCR_TEXT": scr_text, "SCR_TEXT_DIM": scr_text_dim,
        "SCR_TEXT_DEAD": scr_text_dead, "SCR_GRID": scr_grid,
        "INK_HI": ink_hi, "INK_MID": ink_mid, "INK_LO": ink_lo,
        "WARN_AMBER": warn_amber, "BYPASS_COL": bypass_col,
        "BG_GRAD": list(bg_grad),
        "CHASSIS_INNER_FILL": chassis_inner_fill,
        "PANEL_HEADER_FILL": panel_header_fill,
        "PANEL_CHAIN_FILL": panel_chain_fill,
        "PANEL_FX_FILL": panel_fx_fill,
        "HEADER_CHIP_FILL": header_chip_fill,
        "FX_CHIP_FILL": fx_chip_fill,
        "CHAIN_ON_FILL": chain_on_fill,
        "CHAIN_OFF_FILL": chain_off_fill,
        "CHAIN_OFF_OUTLINE": chain_off_outline,
        "CHAIN_OFF_TEXT": chain_off_text,
        "CHAIN_BADGE_OFF": chain_badge_off,
        "BAR_BG_FILL": bar_bg_fill,
        "BAR_OUTLINE": bar_outline,
        "SCANLINE_RGBA": scanline_rgba,
        "SCANLINE_STEP": int(scanline_step),
    }


CYAN_THEME = _make_theme(
    name="cyan",
    led=LED, led_soft=LED_SOFT, led_dim=LED_DIM,
    led_deep=LED_DEEP, led_ghost=LED_GHOST,
    scr_text=SCR_TEXT, scr_text_dim=SCR_TEXT_DIM,
    scr_text_dead=SCR_TEXT_DEAD, scr_grid=SCR_GRID,
    ink_hi=INK_HI, ink_mid=INK_MID, ink_lo=INK_LO,
    warn_amber=WARN_AMBER,
    bypass_col=(220, 110, 75),
    bg_grad=[(0.0, (24, 28, 36)), (0.55, (10, 13, 20)), (1.0, (4, 5, 9))],
    chassis_inner_fill=(7, 10, 16, 220),
    panel_header_fill=(10, 18, 26, 255),
    panel_chain_fill=(8, 13, 20, 255),
    panel_fx_fill=(8, 14, 22, 255),
    header_chip_fill=(8, 14, 20, 255),
    fx_chip_fill=(6, 10, 16, 255),
    chain_on_fill=(8, 44, 56, 255),
    chain_off_fill=(14, 18, 24, 255),
    chain_off_outline=(95, 105, 117, 220),
    chain_off_text=(135, 146, 158, 255),
    chain_badge_off=(52, 60, 70),
    bar_bg_fill=(4, 6, 10, 255),
    bar_outline=(0, 0, 0, 255),
    scanline_rgba=None,
    scanline_step=0,
)

# Pip-Boy-inspired phosphor green CRT palette. Intentionally generic:
# this is "phosphor green monochrome with amber accent and dark olive
# chassis", not a recreation of any specific game's UI. No logos,
# fonts, icons, or screen text are copied.
PIPBOY_THEME = _make_theme(
    name="pipboy-green",
    led=(90, 220, 110),
    led_soft=(175, 245, 185),
    led_dim=(52, 140, 76),
    led_deep=(28, 76, 38),
    led_ghost=(12, 30, 16),
    scr_text=(170, 240, 180),
    scr_text_dim=(90, 160, 100),
    scr_text_dead=(50, 90, 60),
    scr_grid=(16, 50, 22),
    ink_hi=(210, 245, 210),
    ink_mid=(130, 195, 140),
    ink_lo=(80, 130, 90),
    warn_amber=(255, 178, 60),
    bypass_col=(235, 165, 70),
    bg_grad=[(0.0, (12, 28, 14)), (0.55, (6, 16, 8)), (1.0, (3, 8, 4))],
    chassis_inner_fill=(5, 14, 7, 220),
    panel_header_fill=(8, 22, 12, 255),
    panel_chain_fill=(7, 18, 10, 255),
    panel_fx_fill=(7, 20, 11, 255),
    header_chip_fill=(6, 16, 9, 255),
    fx_chip_fill=(4, 10, 6, 255),
    chain_on_fill=(10, 46, 18, 255),
    chain_off_fill=(10, 22, 14, 255),
    chain_off_outline=(60, 100, 70, 220),
    chain_off_text=(110, 160, 120, 255),
    chain_badge_off=(38, 64, 44),
    bar_bg_fill=(4, 10, 6, 255),
    bar_outline=(0, 0, 0, 255),
    scanline_rgba=(0, 100, 40, 32),
    scanline_step=3,
)

THEMES = {
    "cyan": CYAN_THEME,
    "pipboy-green": PIPBOY_THEME,
}
DEFAULT_800X480_THEME = "pipboy-green"


def resolve_theme(theme):
    """Look up a palette by name. Falls back to the default theme."""
    if isinstance(theme, dict):
        return theme
    if theme is None:
        return THEMES[DEFAULT_800X480_THEME]
    return THEMES.get(str(theme), THEMES[DEFAULT_800X480_THEME])


def _apply_scanlines_inplace(arr, step, rgba):
    """Blend a thin horizontal scanline colour onto every ``step``th row
    of an ``HxWx3`` uint8 RGB array, in-place. Cheap O(H/step * W * 3)
    numpy slice + multiply -- no PIL alpha_composite cost. Returns
    ``arr`` for convenience; returns the input untouched when scanlines
    are disabled (``step <= 0`` or ``rgba`` is ``None``).
    """
    if rgba is None or int(step) <= 0:
        return arr
    step = int(step)
    sr, sg, sb, sa = (int(c) for c in rgba)
    a = max(0, min(255, sa)) / 255.0
    if a <= 0.0:
        return arr
    rows = arr[step - 1::step, :, :].astype(np.float32)
    blend = np.array([sr, sg, sb], dtype=np.float32)
    rows *= (1.0 - a)
    rows += a * blend
    np.clip(rows, 0, 255, out=rows)
    arr[step - 1::step, :, :] = rows.astype(np.uint8)
    return arr


# =============================================================================
# EFFECTS / CONSTANTS
# =============================================================================
# Audio-Lab-PYNQ chain order:
# Noise Suppressor -> Compressor -> Overdrive -> Distortion Pedalboard
# -> Amp Simulator -> Cab IR -> EQ -> Reverb
EFFECTS = ["Noise Sup", "Compressor", "Overdrive", "Distortion",
           "Amp Sim", "Cab IR", "EQ", "Reverb"]
EFFECTS_SHORT = ["NS", "CMP", "OD", "DIST", "AMP", "CAB", "EQ", "RVB"]

# Per-effect knob assignments (label, default 0..100). The fixed 8-slot
# layout matches the AMP SIM expansion in Phase 6E (GAIN / BASS /
# MIDDLE / TREBLE / PRESENCE / RESONANCE / MASTER / CHARACTER); shorter
# effects pad the remaining slots with the empty marker ("", 0) so the
# panel renderer can filter unused entries.
EFFECT_KNOBS = {
    "Noise Sup":  [("THRESHOLD", 35), ("DECAY", 45),   ("DAMP", 80),
                   ("", 0),           ("", 0),         ("", 0),
                   ("", 0),           ("", 0)],
    "Compressor": [("THRESHOLD", 50), ("RATIO", 45),   ("RESPONSE", 40),
                   ("MAKEUP", 55),    ("", 0),         ("", 0),
                   ("", 0),           ("", 0)],
    "Overdrive":  [("DRIVE", 35),     ("TONE", 60),    ("LEVEL", 60),
                   ("", 0),           ("", 0),         ("", 0),
                   ("", 0),           ("", 0)],
    "Distortion": [("DRIVE", 50),     ("TONE", 55),    ("LEVEL", 35),
                   ("BIAS", 50),      ("TIGHT", 60),   ("MIX", 100),
                   ("", 0),           ("", 0)],
    "Amp Sim":    [("GAIN", 45),      ("BASS", 55),    ("MIDDLE", 60),
                   ("TREBLE", 50),    ("PRESENCE", 45),("RESONANCE", 35),
                   ("MASTER", 70),    ("CHARACTER", 60)],
    "Cab IR":     [("MIX", 100),      ("LEVEL", 70),   ("MODEL", 33),
                   ("AIR", 35),       ("", 0),         ("", 0),
                   ("", 0),           ("", 0)],
    "EQ":         [("LOW", 50),       ("MID", 55),     ("HIGH", 55),
                   ("", 0),           ("", 0),         ("", 0),
                   ("", 0),           ("", 0)],
    "Reverb":     [("DECAY", 30),     ("TONE", 65),    ("MIX", 25),
                   ("", 0),           ("", 0),         ("", 0),
                   ("", 0),           ("", 0)],
}

# Phase 6E: SELECTED-FX-driven display layout for the per-effect knob
# grid that replaced the PEDAL / AMP / CAB slot rows. Each entry is
# ``(label, knob_values_index)``; the mirror writes parameter values
# into ``knob_values[index]`` so the grid stays decoupled from the
# selected_effect's EFFECT_KNOBS order. Display order is what the user
# requested in Phase 6E (Noise Suppressor THRESHOLD/DECAY/DAMP,
# Compressor THRESHOLD/RATIO/RESPONSE/MAKEUP, Overdrive TONE/LEVEL/
# DRIVE, Distortion Pedalboard TONE/LEVEL/DRIVE/BIAS/TIGHT/MIX,
# RAT FILTER/LEVEL/DRIVE/MIX, Amp Simulator GAIN/BASS/MIDDLE/TREBLE/
# PRESENCE/RESONANCE/MASTER/CHARACTER, Cab IR MIX/LEVEL/MODEL/AIR,
# EQ LOW/MID/HIGH, Reverb DECAY/TONE/MIX). PEDAL sub-models (CLEAN
# BOOST etc.) share the Distortion Pedalboard layout.
_DISTORTION_PARAM_LAYOUT = [
    ("TONE", 1), ("LEVEL", 2), ("DRIVE", 0),
    ("BIAS", 3), ("TIGHT", 4), ("MIX", 5),
]
SELECTED_FX_PARAM_LAYOUT = {
    "NOISE SUPPRESSOR": [("THRESHOLD", 0), ("DECAY", 1), ("DAMP", 2)],
    "COMPRESSOR": [("THRESHOLD", 0), ("RATIO", 1),
                   ("RESPONSE", 2), ("MAKEUP", 3)],
    "OVERDRIVE": [("TONE", 1), ("LEVEL", 2), ("DRIVE", 0)],
    "DISTORTION": list(_DISTORTION_PARAM_LAYOUT),
    "CLEAN BOOST": list(_DISTORTION_PARAM_LAYOUT),
    "TUBE SCREAMER": list(_DISTORTION_PARAM_LAYOUT),
    "DS-1": list(_DISTORTION_PARAM_LAYOUT),
    "DS 1": list(_DISTORTION_PARAM_LAYOUT),
    "BIG MUFF": list(_DISTORTION_PARAM_LAYOUT),
    "FUZZ FACE": list(_DISTORTION_PARAM_LAYOUT),
    "METAL": list(_DISTORTION_PARAM_LAYOUT),
    "RAT": [("FILTER", 1), ("LEVEL", 2), ("DRIVE", 0), ("MIX", 3)],
    "AMP SIM": [("GAIN", 0), ("BASS", 1), ("MIDDLE", 2), ("TREBLE", 3),
                ("PRESENCE", 4), ("RESONANCE", 5),
                ("MASTER", 6), ("CHARACTER", 7)],
    "CAB": [("MIX", 0), ("LEVEL", 1), ("MODEL", 2), ("AIR", 3)],
    "EQ": [("LOW", 0), ("MID", 1), ("HIGH", 2)],
    "REVERB": [("DECAY", 0), ("TONE", 1), ("MIX", 2)],
    "SAFE BYPASS": [],
    "PRESET": [],
}

# Distortion Pedalboard model names (pedal-mask bit -> name).
DIST_MODELS = ["CLEAN BOOST", "TUBE SCREAMER", "RAT", "DS-1",
               "BIG MUFF", "FUZZ FACE", "METAL"]
DIST_MODEL_KEYS = ["clean_boost", "tube_screamer", "rat", "ds1",
                   "big_muff", "fuzz_face", "metal"]
DIST_SLOT_LABELS = ["CLEAN", "TS", "RAT", "DS1", "MUFF", "FUZZ", "METAL"]
# Legacy alias.
DISTORTION_PEDALS = [m.lower().replace(" ", "_").replace("-", "") for m in DIST_MODELS]

# Amp Simulator named voicings (label, character byte center value).
AMP_MODELS = [("JC CLEAN", 10), ("CLEAN COMBO", 35),
              ("BRITISH CRUNCH", 60), ("HIGH GAIN STACK", 85)]
AMP_MODEL_KEYS = ["jc_clean", "clean_combo", "british_crunch", "high_gain_stack"]
AMP_SLOT_LABELS = ["JC", "CLEAN", "BRIT", "HIGH"]

# Cabinet IR model names. The deployed DSP exposes cab_model 0/1/2.
CAB_MODELS = ["1x12 OPEN", "2x12 COMBO", "4x12 CLOSED"]
CAB_MODEL_KEYS = ["1x12", "2x12", "4x12"]
CAB_SLOT_LABELS = ["1x12", "2x12", "4x12"]

# 13 Chain Presets (1-click chain swap).
CHAIN_PRESETS = [
    "Safe Bypass", "Basic Clean", "Clean Sustain", "Light Crunch",
    "TS Lead", "RAT Rhythm", "Metal Tight", "Ambient Clean",
    "Solo Boost", "Noise Controlled High Gain",
    "DS-1 Crunch", "Big Muff Sustain", "Vintage Fuzz",
]


# =============================================================================
# APP STATE
# =============================================================================
@dataclass
class AppState:
    preset_id: str   = "02A"
    preset_name: str = "BASIC  CLEAN"
    preset_idx: int  = 1     # index into CHAIN_PRESETS (0..12)
    bpm: int         = 120
    key: str         = "E"

    # signal-chain (indices into EFFECTS — drag-reorder writes into this list)
    chain: List[int] = field(default_factory=lambda: list(range(8)))
    # ON/OFF per effect (indexed by chain position == EFFECTS index in default order)
    effect_on: List[bool] = field(default_factory=lambda:
        [True,  True, False, False, True, True, True, True])
    selected_effect: int  = 4   # Amp Sim
    selected_fx: Optional[str] = None  # Display override for notebook-driven mirrors

    # parameter knobs (8 slots; AMP SIM uses all 8 for GAIN/BASS/MIDDLE/
    # TREBLE/PRESENCE/RESONANCE/MASTER/CHARACTER, other effects fill only
    # the first 3-6 slots with the rest left at 0)
    knob_values: List[float] = field(default_factory=lambda:
        [45, 55, 60, 50, 45, 35, 70, 60])
    selected_knob: int       = 0

    # model-pick indices for the three model-driven effects
    dist_model_idx: int = 1   # Tube Screamer
    amp_model_idx:  int = 2   # British Crunch
    cab_model_idx:  int = 2   # 4x12 British
    pedal_model: str = "tube_screamer"
    amp_model: str = "british_crunch"
    cab_model: str = "4x12"
    pedal_model_label: str = "TUBE SCREAMER"
    amp_model_label: str = "BRITISH CRUNCH"
    cab_model_label: str = "4x12 CLOSED"
    active_model_category: str = ""
    selected_model_category: str = ""
    dropdown_label: str = ""
    dropdown_short_label: str = ""
    selected_model_dropdown_visible: bool = False
    active_pedals: List[str] = field(default_factory=list)
    model_slots: Dict[str, List[Dict[str, object]]] = field(default_factory=dict)

    # footswitches
    fs_states: List[bool] = field(default_factory=lambda:
        [False, False, True, False, False, True, False, False])
    fs_selected: int = 0

    # visualizer mode: 'wave' | 'spectrum' | 'both'
    display_mode: str = "both"

    # animation clock (seconds)
    t: float = 0.0

    # transient flash (seconds remaining)
    save_flash: float = 0.0

    # I/O metering — driven from t inside the renderer for live feel
    in_level: float  = 0.6
    out_level: float = 0.7
    cpu: int         = 42

    def knobs(self) -> List[Tuple[str, float]]:
        labels = [k[0] for k in EFFECT_KNOBS[EFFECTS[self.selected_effect]]]
        return list(zip(labels, self.knob_values))


def _normalize_selected_fx_label(value) -> str:
    text = str(value or "").replace("_", " ").replace("-", " ").strip().upper()
    return " ".join(text.split())


def _selected_fx_label(state: AppState) -> str:
    override = getattr(state, "selected_fx", None)
    if override is not None and str(override).strip():
        return str(override).strip()
    return EFFECTS[state.selected_effect]


def _selected_fx_on(state: AppState) -> bool:
    label = _normalize_selected_fx_label(_selected_fx_label(state))
    if label == "SAFE BYPASS":
        return False
    if label == "PRESET":
        return any(bool(v) for v in getattr(state, "effect_on", []) or [])
    return bool(state.effect_on[state.selected_effect])


def _compact_model_label(label: str) -> str:
    label = str(label or "").upper()
    replacements = {
        "TUBE SCREAMER": "TUBE SCRMR",
        "BRITISH CRUNCH": "BRIT CRUNCH",
        "HIGH GAIN STACK": "HI-GAIN STACK",
        "CLEAN BOOST": "CLEAN BOOST",
    }
    return replacements.get(label, label)


# Phase 6C: short labels for the [model ▼] dropdown chip drawn next to
# SELECTED FX. The chip is ~150 px wide on the compact-v2 800x480 panel,
# so anything beyond ~12 characters runs off the right edge.
_DROPDOWN_CHIP_SHORT = {
    "CLEAN BOOST": "CLN BOOST",
    "TUBE SCREAMER": "TUBE SCRMR",
    "RAT": "RAT",
    "DS-1": "DS-1",
    "BIG MUFF": "BIG MUFF",
    "FUZZ FACE": "FUZZ",
    "METAL": "METAL",
    "JC CLEAN": "JC CLEAN",
    "CLEAN COMBO": "CLN COMBO",
    "BRITISH CRUNCH": "BRIT CRUNCH",
    "HIGH GAIN STACK": "HI-GAIN",
    "1X12 OPEN": "1x12 OPN",
    "2X12 COMBO": "2x12 CMB",
    "4X12 CLOSED": "4x12 CLS",
    "REVERB": "REVERB",
    "EQ": "EQ",
    "COMPRESSOR": "COMP",
    "NOISE SUPPRESSOR": "NOISE SUP",
    "OVERDRIVE": "OD",
    "SAFE BYPASS": "SAFE",
    "PRESET": "PRESET",
}

# SELECTED FX -> dropdown category. Mirrors
# audio_lab_pynq.hdmi_effect_state_mirror.SELECTED_FX_CATEGORY but kept
# here so the renderer does not need to import the mirror module.
_DROPDOWN_CATEGORY = {
    "CLEAN BOOST": "PEDAL",
    "TUBE SCREAMER": "PEDAL",
    "RAT": "PEDAL",
    "DS 1": "PEDAL",
    "DS-1": "PEDAL",
    "BIG MUFF": "PEDAL",
    "FUZZ FACE": "PEDAL",
    "METAL": "PEDAL",
    "DISTORTION": "PEDAL",
    "OVERDRIVE": "OVERDRIVE",
    "AMP SIM": "AMP",
    "CAB": "CAB",
    "REVERB": "REVERB",
    "EQ": "EQ",
    "COMPRESSOR": "COMPRESSOR",
    "NOISE SUPPRESSOR": "NOISE SUPPRESSOR",
    "SAFE BYPASS": "SAFE",
    "PRESET": "PRESET",
}


def _dropdown_short(label: str) -> str:
    text = str(label or "").upper()
    return _DROPDOWN_CHIP_SHORT.get(text, text)


def _dropdown_category(state) -> str:
    label = _normalize_selected_fx_label(_selected_fx_label(state))
    return _DROPDOWN_CATEGORY.get(label, label)


def _dropdown_label(state) -> str:
    """Phase 6C: text rendered inside the SELECTED FX [model ▼] chip.

    Mirrors the live model selection when SELECTED FX is a model-driven
    effect (PEDAL / AMP / CAB) and otherwise echoes the effect family.
    Prefers the explicit ``dropdown_label`` AppState field when present
    so the mirror can override the renderer-derived choice.
    """
    explicit = getattr(state, "dropdown_label", None)
    if explicit:
        return str(explicit).upper()
    category = _dropdown_category(state)
    if category == "PEDAL":
        return _pedal_label(state)
    if category == "AMP":
        return _amp_label(state)
    if category == "CAB":
        return _cab_label(state)
    if category == "SAFE":
        return "SAFE BYPASS"
    if category == "PRESET":
        return "PRESET"
    if category == "REVERB":
        return "REVERB"
    if category == "EQ":
        return "EQ"
    if category == "COMPRESSOR":
        return "COMPRESSOR"
    if category == "NOISE SUPPRESSOR":
        return "NOISE SUPPRESSOR"
    if category == "OVERDRIVE":
        return "OVERDRIVE"
    return category or "N/A"


def _should_show_selected_model_dropdown(state) -> bool:
    """Phase 6D: dropdown indicator visible only for PEDAL / AMP / CAB.

    The HDMI GUI restores the compact-v2 layout from commit 0a07f2a, so
    no extra chip is drawn for REVERB / EQ / COMPRESSOR / NOISE
    SUPPRESSOR / SAFE BYPASS / PRESET / OVERDRIVE. The indicator is a
    thin outline + triangle glyph painted around the matching row of
    ACTIVE MODELS; selecting the chip is still notebook-side.
    """
    category = _dropdown_category(state)
    return category in ("PEDAL", "AMP", "CAB")


def _selected_model_dropdown_label(state) -> str:
    """Phase 6D: text the conditional [model ▼] marker reflects.

    Returns the current pedal / amp / cab label for PEDAL / AMP / CAB
    categories and an empty string otherwise so callers can use the
    truthiness as a visibility flag.
    """
    if not _should_show_selected_model_dropdown(state):
        return ""
    category = _dropdown_category(state)
    if category == "PEDAL":
        return _pedal_label(state)
    if category == "AMP":
        return _amp_label(state)
    if category == "CAB":
        return _cab_label(state)
    return ""


def selected_fx_param_layout(state) -> list:
    """Phase 6E: per-SELECTED-FX parameter list for the knob grid.

    Returns a list of ``(label, knob_values_index)`` pairs ordered for
    display. Mirrors :data:`SELECTED_FX_PARAM_LAYOUT` but resolves the
    SELECTED FX override on ``state`` so callers do not need to do the
    lookup themselves. Returns ``[]`` for SAFE BYPASS / PRESET / any
    SELECTED FX that has no parameter knobs.
    """
    label = _normalize_selected_fx_label(_selected_fx_label(state))
    return list(SELECTED_FX_PARAM_LAYOUT.get(label, []))


def _draw_dropdown_arrow(draw, xy, color):
    """Phase 6D: small filled triangle glyph used by the dropdown marker."""
    x0, y0, x1, y1 = (int(v) for v in xy)
    if x1 <= x0 or y1 <= y0:
        return
    tri_w = max(6, min(10, x1 - x0))
    tri_h = max(4, min(6, y1 - y0))
    cx = (x0 + x1) // 2
    top = (y0 + y1) // 2 - tri_h // 2
    triangle = [
        (cx - tri_w // 2, top),
        (cx + tri_w // 2, top),
        (cx, top + tri_h),
    ]
    try:
        draw.polygon(triangle, fill=color + (255,),
                     outline=color + (255,))
    except TypeError:
        draw.polygon(triangle, fill=color + (255,))


def _pedal_label(state: AppState) -> str:
    label = getattr(state, "pedal_model_label", None)
    if label:
        return str(label).upper()
    idx = max(0, min(len(DIST_MODELS) - 1,
                     int(getattr(state, "dist_model_idx", 0) or 0)))
    return DIST_MODELS[idx]


def _amp_label(state: AppState) -> str:
    label = getattr(state, "amp_model_label", None)
    if label:
        return str(label).upper()
    idx = max(0, min(len(AMP_MODELS) - 1,
                     int(getattr(state, "amp_model_idx", 0) or 0)))
    return AMP_MODELS[idx][0]


def _cab_label(state: AppState) -> str:
    label = getattr(state, "cab_model_label", None)
    if label:
        return str(label).upper()
    idx = max(0, min(len(CAB_MODELS) - 1,
                     int(getattr(state, "cab_model_idx", 0) or 0)))
    return CAB_MODELS[idx]


# =============================================================================
# FONT — pure PIL default, scaled with NEAREST for crisp LCD-style headings.
# =============================================================================
_BASE_FONT = None
def _base_font():
    global _BASE_FONT
    if _BASE_FONT is None:
        # Try the size kwarg (Pillow 10.1+); fall back to the bitmap default.
        try:
            _BASE_FONT = ImageFont.load_default(size=11)
        except TypeError:
            _BASE_FONT = ImageFont.load_default()
    return _BASE_FONT

# Smooth TrueType cache for hero numerics (e.g. big preset id "01A").
_SMOOTH_FONT_CACHE = {}
_SMOOTH_TTF_CANDIDATES = [
    "DejaVuSans-Bold.ttf", "DejaVuSans.ttf",
    "Arial Bold.ttf", "arialbd.ttf", "Arial.ttf", "arial.ttf",
    "Helvetica.ttf", "LiberationSans-Bold.ttf",
]
def _smooth_font(size: int):
    if size in _SMOOTH_FONT_CACHE:
        return _SMOOTH_FONT_CACHE[size]
    f = None
    for name in _SMOOTH_TTF_CANDIDATES:
        try:
            f = ImageFont.truetype(name, size)
            break
        except (OSError, IOError):
            continue
    if f is None:
        f = _base_font()
    _SMOOTH_FONT_CACHE[size] = f
    return f

def draw_smooth_text(img: Image.Image, xy, text: str, size: int, fill,
                    anchor: str = "lt", letter_spacing: int = 0):
    """Anti-aliased text for hero numerics. No NEAREST-upscale crunch."""
    font = _smooth_font(size)
    text = str(text)
    if not text:
        return
    global _ACTIVE_RENDER_CACHE
    fill_key = tuple(fill) if isinstance(fill, (tuple, list)) else fill
    cache_key = ("smooth_text", text, int(size), fill_key, int(letter_spacing))
    scratch = None
    if _ACTIVE_RENDER_CACHE is not None:
        scratch = _ACTIVE_RENDER_CACHE.text_cache.get(cache_key)
        if scratch is not None:
            _ACTIVE_RENDER_CACHE.stats["text_hits"] += 1
    if scratch is None:
        # measure
        if letter_spacing == 0:
            tw, th = _measure(text, font)
            scratch = Image.new("RGBA", (max(1, tw + 4), max(1, th + 8)), (0, 0, 0, 0))
            ImageDraw.Draw(scratch).text((2, 2), text, fill=fill, font=font)
        else:
            widths = [_measure(c, font)[0] for c in text]
            total = sum(widths) + letter_spacing * max(0, len(text) - 1)
            th = _measure("Hg", font)[1]
            scratch = Image.new("RGBA", (max(1, total + 4), max(1, th + 8)), (0, 0, 0, 0))
            sd = ImageDraw.Draw(scratch)
            x = 2
            for c, cw in zip(text, widths):
                sd.text((x, 2), c, fill=fill, font=font)
                x += cw + letter_spacing
        if _ACTIVE_RENDER_CACHE is not None:
            _ACTIVE_RENDER_CACHE.text_cache[cache_key] = scratch
            _ACTIVE_RENDER_CACHE.stats["text_misses"] += 1
    sw, sh = scratch.size
    ax = {"l": 0, "m": -sw // 2, "r": -sw}[anchor[0]]
    ay = {"t": 0, "m": -sh // 2, "b": -sh}[anchor[1]]
    img.alpha_composite(scratch, (int(xy[0]) + ax, int(xy[1]) + ay))

def _measure(text: str, font) -> Tuple[int, int]:
    if hasattr(font, "getbbox"):
        b = font.getbbox(text)
        return (b[2] - b[0], b[3] - b[1])
    if hasattr(font, "getsize"):
        return font.getsize(text)
    return (len(text) * 6, 11)

def draw_text(img: Image.Image, xy, text: str, fill, scale: int = 1,
              anchor: str = "lt", letter_spacing: int = 0,
              shadow=None, glow=None):
    """
    Draw small or scaled-up text on `img` (RGBA preferred for blending).
    `scale` upscales the bitmap with NEAREST for sharp pixel-LCD text.
    `anchor`: 'lt' (default), 'mt', 'rt', 'lm', 'mm', 'rm', 'lb', 'mb', 'rb'
    """
    font = _base_font()
    text = str(text)
    if not text:
        return

    # render to scratch (cached). Glow/shadow are applied after positioning,
    # but the glyph bitmap itself is independent of destination.
    global _ACTIVE_RENDER_CACHE
    fill_key = tuple(fill) if isinstance(fill, (tuple, list)) else fill
    cache_key = ("text", text, fill_key, int(scale), int(letter_spacing))
    scratch = None
    if _ACTIVE_RENDER_CACHE is not None:
        scratch = _ACTIVE_RENDER_CACHE.text_cache.get(cache_key)
        if scratch is not None:
            _ACTIVE_RENDER_CACHE.stats["text_hits"] += 1
    if scratch is None:
        if letter_spacing == 0:
            tw, th = _measure(text, font)
            scratch = Image.new("RGBA", (max(1, tw + 2), max(1, th + 4)), (0, 0, 0, 0))
            sd = ImageDraw.Draw(scratch)
            sd.text((1, 1), text, fill=fill, font=font)
        else:
            widths = [_measure(c, font)[0] for c in text]
            total = sum(widths) + letter_spacing * max(0, len(text) - 1)
            th = _measure("Hg", font)[1]
            scratch = Image.new("RGBA", (max(1, total + 2), max(1, th + 4)), (0, 0, 0, 0))
            sd = ImageDraw.Draw(scratch)
            x = 1
            for c, cw in zip(text, widths):
                sd.text((x, 1), c, fill=fill, font=font)
                x += cw + letter_spacing

        if scale != 1:
            scratch = scratch.resize(
                (scratch.width * scale, scratch.height * scale), Image.NEAREST)
        if _ACTIVE_RENDER_CACHE is not None:
            _ACTIVE_RENDER_CACHE.text_cache[cache_key] = scratch
            _ACTIVE_RENDER_CACHE.stats["text_misses"] += 1

    sw, sh = scratch.size

    # anchor → offset
    ax = {"l": 0, "m": -sw // 2, "r": -sw}[anchor[0]]
    ay = {"t": 0, "m": -sh // 2, "b": -sh}[anchor[1]]
    px, py = int(xy[0]) + ax, int(xy[1]) + ay

    if glow and not _pynq_static_mode():
        # neon glow halo
        halo = Image.new("RGBA", scratch.size, (0, 0, 0, 0))
        halo_d = ImageDraw.Draw(halo)
        # use the same scratch shape as a coloured stamp
        mask = scratch.split()[3]
        coloured = Image.new("RGBA", scratch.size, glow + (0,))
        coloured.putalpha(mask)
        coloured = coloured.filter(ImageFilter.GaussianBlur(radius=max(2, scale * 1.3)))
        img.alpha_composite(coloured, (px, py))

    if shadow:
        sx, sy, sc = shadow
        mask = scratch.split()[3]
        sh_layer = Image.new("RGBA", scratch.size, sc + (0,))
        sh_layer.putalpha(mask)
        img.alpha_composite(sh_layer, (px + sx, py + sy))

    img.alpha_composite(scratch, (px, py))


# =============================================================================
# LOW-LEVEL DRAWING HELPERS
# =============================================================================
def _lerp(a, b, t):
    return a + (b - a) * t

def _lerp_color(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return (int(_lerp(c1[0], c2[0], t)),
            int(_lerp(c1[1], c2[1], t)),
            int(_lerp(c1[2], c2[2], t)))

def vertical_gradient(w: int, h: int, stops):
    """
    stops = [(0.0, (r,g,b)), (0.4, (...)), (1.0, (...))]
    Cached because the same panel gradients are reused heavily.
    """
    if w <= 0 or h <= 0:
        return Image.new("RGB", (max(1,w), max(1,h)), (0,0,0))
    global _ACTIVE_RENDER_CACHE
    key = (int(w), int(h), tuple((float(pos), tuple(col)) for pos, col in stops))
    if _ACTIVE_RENDER_CACHE is not None:
        cached = _ACTIVE_RENDER_CACHE.gradient_cache.get(key)
        if cached is not None:
            _ACTIVE_RENDER_CACHE.stats["gradient_hits"] += 1
            return cached
    arr = np.zeros((h, w, 3), dtype=np.uint8)
    ys = np.arange(h) / max(1, h - 1)
    stops = sorted(stops, key=lambda s: s[0])
    for c in range(3):
        col = np.zeros(h, dtype=np.float32)
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i+1]
            mask = (ys >= t0) & (ys <= t1 + 1e-6)
            if not mask.any(): continue
            seg_t = (ys[mask] - t0) / max(1e-6, t1 - t0)
            col[mask] = c0[c] + (c1[c] - c0[c]) * seg_t
        arr[:, :, c] = col[:, None]
    img = Image.fromarray(arr, "RGB")
    if _ACTIVE_RENDER_CACHE is not None:
        _ACTIVE_RENDER_CACHE.gradient_cache[key] = img
        _ACTIVE_RENDER_CACHE.stats["gradient_misses"] += 1
    return img

def rounded_rect(draw: ImageDraw.ImageDraw, xy, radius, fill=None, outline=None, width=1):
    x0, y0, x1, y1 = xy
    if x1 <= x0 or y1 <= y0:
        return
    r = max(0, min(int(radius), (x1 - x0) // 2, (y1 - y0) // 2))
    try:
        draw.rounded_rectangle([x0, y0, x1, y1], radius=r,
                               fill=fill, outline=outline, width=width)
    except (AttributeError, TypeError):
        draw.rectangle([x0, y0, x1, y1], fill=fill, outline=outline, width=width)




def draw_meter(img: Image.Image, x: int, y: int, w: int, h: int,
               value: float, label: str = "", segments: int = 18,
               glow: bool = True):
    """Horizontal segmented meter with cyan→amber→red ramp."""
    # housing
    d = ImageDraw.Draw(img)
    rounded_rect(d, (x, y, x + w, y + h), 3, fill=(4, 5, 8, 255),
                 outline=(0, 0, 0, 255), width=1)
    rounded_rect(d, (x + 1, y + 1, x + w - 1, y + h - 1), 2,
                 outline=(255, 255, 255, 18), width=1)

    # segments
    pad = 3
    seg_w = (w - pad * 2 - (segments - 1) * 2) / segments
    lit = int(round(value * segments))
    for i in range(segments):
        t = i / max(1, segments - 1)
        if t < 0.65:
            col = LED
        elif t < 0.85:
            col = WARN_AMBER
        else:
            col = WARN_RED
        sx = x + pad + i * (seg_w + 2)
        sy = y + pad
        sx2 = sx + seg_w
        sy2 = y + h - pad
        if i < lit:
            # glowing stamp
            if glow and not _pynq_static_mode():
                stamp = Image.new("RGBA", (int(seg_w + 8), int(sy2 - sy + 8)), (0, 0, 0, 0))
                sd = ImageDraw.Draw(stamp)
                sd.rectangle((4, 4, int(seg_w + 4), int(sy2 - sy + 4)),
                             fill=col + (255,))
                stamp = stamp.filter(ImageFilter.GaussianBlur(1.6))
                img.alpha_composite(stamp, (int(sx) - 4, int(sy) - 4))
            d.rectangle((int(sx), int(sy), int(sx2), int(sy2)), fill=col)
        else:
            d.rectangle((int(sx), int(sy), int(sx2), int(sy2)),
                        fill=(18, 22, 28, 255))

    if label:
        draw_text(img, (x - 6, y + h // 2), label, fill=INK_MID + (255,),
                  scale=1, anchor="rm", letter_spacing=1)










# =============================================================================
# RENDER CACHE / FAST RENDER PATH
# =============================================================================
class RenderCache:
    """Small, PYNQ-friendly cache for PIL/NumPy rendering.

    This is intentionally conservative: it avoids external dependencies and
    keeps only a handful of full-frame entries. The largest win is avoiding
    full redraws when the GUI state has not changed or when visual meters are
    throttled to lower FPS.
    """
    def __init__(self, visualizer_fps: float = 5.0, meter_fps: float = 10.0,
                 max_frame_entries: int = 8, pynq_static_mode: bool = False):
        self.visualizer_fps = float(visualizer_fps)
        self.meter_fps = float(meter_fps)
        self.max_frame_entries = int(max_frame_entries)
        self.pynq_static_mode = bool(pynq_static_mode)
        self.static_layers = {}
        self.semi_static_layers = {}
        self.text_cache = {}
        self.gradient_cache = {}
        self.mask_cache = {}
        self.glow_cache = {}
        self.knob_body_cache = {}
        self.chain_block_cache = {}
        self.meter_segment_cache = {}
        self.frame_cache = {}
        self.frame_cache_order = []
        self.last_static_key = None
        self.last_semistatic_key = None
        self.last_visualizer_time = 0.0
        self.last_meter_time = 0.0
        self.cached_visualizer_layer = None
        self.cached_meter_layer = None
        self.stats = {
            "frame_hits": 0,
            "frame_misses": 0,
            "static_hits": 0,
            "static_misses": 0,
            "semistatic_hits": 0,
            "semistatic_misses": 0,
            "text_hits": 0,
            "text_misses": 0,
            "gradient_hits": 0,
            "gradient_misses": 0,
            "visualizer_updates": 0,
            "meter_updates": 0,
        }

    def clear_frame_cache(self):
        self.frame_cache.clear()
        self.frame_cache_order.clear()

    def put_frame(self, key, arr):
        self.frame_cache[key] = arr
        self.frame_cache_order.append(key)
        while len(self.frame_cache_order) > self.max_frame_entries:
            old = self.frame_cache_order.pop(0)
            self.frame_cache.pop(old, None)




def make_pynq_static_render_cache(max_frame_entries: int = 8) -> RenderCache:
    """Cache profile for PYNQ HDMI static/change-driven display."""
    return RenderCache(visualizer_fps=0.0, meter_fps=0.0,
                       max_frame_entries=max_frame_entries,
                       pynq_static_mode=True)


def state_semistatic_signature(state: AppState):
    """State components that require the non-background UI to be redrawn.

    Do not include state.t directly; otherwise animation time invalidates the
    cache every frame and defeats throttling.
    """
    return (
        state.preset_id,
        state.preset_name,
        getattr(state, "preset_idx", None),
        tuple(state.chain),
        tuple(bool(v) for v in state.effect_on),
        int(state.selected_effect),
        getattr(state, "selected_fx", None),
        int(state.selected_knob),
        tuple(int(round(v)) for v in state.knob_values),
        getattr(state, "dist_model_idx", None),
        getattr(state, "amp_model_idx", None),
        getattr(state, "cab_model_idx", None),
        getattr(state, "pedal_model", None),
        getattr(state, "amp_model", None),
        getattr(state, "cab_model", None),
        getattr(state, "pedal_model_label", None),
        getattr(state, "amp_model_label", None),
        getattr(state, "cab_model_label", None),
        getattr(state, "active_model_category", None),
        getattr(state, "selected_model_category", None),
        getattr(state, "dropdown_label", None),
        getattr(state, "dropdown_short_label", None),
        bool(getattr(state, "selected_model_dropdown_visible", False)),
        tuple(getattr(state, "active_pedals", []) or []),
        bool(state.save_flash > 0),
    )


def state_dynamic_signature(state: AppState, cache: RenderCache):
    """Quantized dynamic state.

    Meters and visualizer are intentionally bucketed to lower update rates.
    This is the practical part that makes Tk/PYNQ display usable: frames between
    buckets can reuse the previous RGB array.
    """
    if getattr(cache, "pynq_static_mode", False):
        return ("static",)
    vf = float(cache.visualizer_fps)
    mf = float(cache.meter_fps)
    viz_bucket = 0 if vf <= 0 else int(float(state.t) * max(0.5, vf))
    meter_bucket = 0 if mf <= 0 else int(float(state.t) * max(1.0, mf))
    # Level values are intentionally not part of the key; they are sampled at
    # the beginning of each meter bucket. Including raw/quantized levels here
    # would invalidate the frame cache almost every tick and undo throttling.
    return (viz_bucket, meter_bucket)



def _draw_800x480_chain(img: Image.Image, state: AppState, xy):
    x0, y0, x1, y1 = [int(v) for v in xy]
    d = ImageDraw.Draw(img)
    draw_text(img, (x0, y0), "CHAIN", fill=SCR_TEXT_DIM + (255,),
              scale=1, letter_spacing=2)
    row_y0 = y0 + 20
    row_y1 = y1
    n = max(1, len(EFFECTS))
    gap = 6
    w = int((x1 - x0 - gap * (n - 1)) / n)
    for pos, eff_idx in enumerate(state.chain[:n]):
        bx0 = x0 + pos * (w + gap)
        bx1 = bx0 + w
        on = bool(state.effect_on[eff_idx]) if eff_idx < len(state.effect_on) else False
        selected = eff_idx == state.selected_effect
        if on:
            fill = (7, 40, 50, 255)
            outline = LED + ((230,) if selected else (130,))
            text_col = LED + (255,)
        else:
            fill = (13, 16, 21, 255)
            outline = (85, 94, 104, 220)
            text_col = (115, 125, 135, 255)
        rounded_rect(d, (bx0, row_y0, bx1, row_y1), 5,
                     fill=fill, outline=outline, width=2 if selected else 1)
        draw_text(img, ((bx0 + bx1) // 2, row_y0 + 9),
                  EFFECTS_SHORT[eff_idx], fill=text_col, scale=1,
                  anchor="mt", letter_spacing=1)
        d.rectangle((bx0 + 7, row_y1 - 8, bx1 - 7, row_y1 - 5),
                    fill=(LED if on else (45, 52, 60)) + (255,))


def _draw_800x480_monitor(img: Image.Image, state: AppState, xy):
    x0, y0, x1, y1 = [int(v) for v in xy]
    d = ImageDraw.Draw(img)
    rounded_rect(d, (x0, y0, x1, y1), 8,
                 fill=(5, 9, 15, 255), outline=LED + (70,), width=1)
    draw_text(img, (x0 + 12, y0 + 10), "SIGNAL  MONITOR",
              fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=2)
    draw_text(img, (x1 - 12, y0 + 10), "STATIC",
              fill=SCR_TEXT_DEAD + (255,), scale=1, anchor="rt",
              letter_spacing=1)

    ix0, iy0, ix1, iy1 = x0 + 14, y0 + 34, x1 - 14, y1 - 14
    for gx in range(ix0, ix1 + 1, 48):
        d.line((gx, iy0, gx, iy1), fill=SCR_GRID, width=1)
    for gy in range(iy0, iy1 + 1, 28):
        d.line((ix0, gy, ix1, gy), fill=SCR_GRID, width=1)

    mid = iy0 + (iy1 - iy0) // 3
    amp = max(8, (iy1 - iy0) // 5)
    pts = []
    samples = 92
    for i in range(samples):
        x = ix0 + int((ix1 - ix0) * i / float(samples - 1))
        y = mid + int(amp * (
            math.sin(i * 0.18 + state.t * 0.2) * 0.55 +
            math.sin(i * 0.53) * 0.18))
        pts.append((x, y))
    d.line(pts, fill=LED_SOFT, width=2)
    d.line((ix0, mid, ix1, mid), fill=LED + (70,), width=1)

    bars = 28
    base_y = iy1
    bw = (ix1 - ix0) / float(bars)
    for i in range(bars):
        phase = i / float(max(1, bars - 1))
        v = 0.12 + 0.66 * math.exp(-phase * 2.4)
        v += 0.12 * (0.5 + 0.5 * math.sin(i * 0.71))
        if i == int((state.selected_effect / float(max(1, len(EFFECTS) - 1))) * (bars - 1)):
            v = min(1.0, v + 0.20)
        h = int(v * ((iy1 - iy0) * 0.44))
        sx0 = int(ix0 + i * bw + 2)
        sx1 = int(ix0 + (i + 1) * bw - 2)
        sy0 = base_y - h
        col = _lerp_color(LED_DIM, LED_SOFT, min(1.0, v))
        d.rectangle((sx0, sy0, sx1, base_y), fill=col + (230,))
        d.line((sx0, sy0, sx1, sy0), fill=LED_SOFT + (255,), width=1)


def _draw_800x480_levels(img: Image.Image, state: AppState, xy):
    x0, y0, x1, y1 = [int(v) for v in xy]
    d = ImageDraw.Draw(img)
    rounded_rect(d, (x0, y0, x1, y1), 8,
                 fill=(7, 12, 18, 255), outline=LED + (55,), width=1)
    draw_text(img, (x0 + 12, y0 + 10), "LEVELS",
              fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=2)
    draw_text(img, (x1 - 12, y0 + 10), "DSP  OK",
              fill=LED + (255,), scale=1, anchor="rt", letter_spacing=1)
    draw_meter(img, x0 + 52, y0 + 38, x1 - x0 - 70, 18,
               state.in_level, label="IN", segments=18, glow=False)
    draw_meter(img, x0 + 52, y0 + 74, x1 - x0 - 70, 18,
               state.out_level, label="OUT", segments=18, glow=False)


def _render_frame_800x480_logical(state: AppState, width: int = 800,
                                  height: int = 480,
                                  cache: Optional[RenderCache] = None) -> np.ndarray:
    """Render a 5-inch-LCD logical GUI frame.

    This is not a downscale of the 1280x720 layout. It keeps the same dark
    AudioLab visual language but prioritizes large preset/status text, a
    compact chain view, and a simplified signal monitor for an 800x480 panel.
    """
    if cache is None:
        cache = make_pynq_static_render_cache()
    elif not getattr(cache, "pynq_static_mode", False):
        cache.pynq_static_mode = True
        cache.visualizer_fps = 0.0
        cache.meter_fps = 0.0

    key = ("logical_800x480_v1", int(width), int(height),
           state_semistatic_signature(state), state_dynamic_signature(state, cache))
    cached = cache.frame_cache.get(key)
    if cached is not None:
        cache.stats["frame_hits"] += 1
        return cached

    global _ACTIVE_RENDER_CACHE
    prev = _ACTIVE_RENDER_CACHE
    _ACTIVE_RENDER_CACHE = cache
    try:
        img = Image.new("RGBA", (int(width), int(height)), (0, 0, 0, 255))
        room = vertical_gradient(int(width), int(height),
                                 [(0.0, (22, 26, 32)),
                                  (0.55, (8, 10, 15)),
                                  (1.0, (3, 4, 7))])
        img.paste(room, (0, 0))

        d = ImageDraw.Draw(img)
        safe = 24
        rounded_rect(d, (8, 8, int(width) - 8, int(height) - 8), 12,
                     fill=None, outline=(255, 255, 255, 28), width=1)
        rounded_rect(d, (safe, safe, int(width) - safe, int(height) - safe), 10,
                     fill=(7, 10, 15, 190), outline=LED + (45,), width=1)

        active_n = sum(1 for v in state.effect_on if v)
        bypassed = active_n == 0
        status = "SAFE  BYPASS" if bypassed else "ACTIVE"
        status_col = (180, 95, 70) if bypassed else LED

        header = (safe + 12, safe + 12, int(width) - safe - 12, safe + 86)
        hx0, hy0, hx1, hy1 = header
        rounded_rect(d, header, 8, fill=(8, 16, 23, 255),
                     outline=LED + (70,), width=1)
        draw_text(img, (hx0 + 16, hy0 + 12), "PRESET",
                  fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=2)
        draw_smooth_text(img, (hx0 + 16, hy0 + 28), state.preset_id,
                         size=34, fill=INK_HI + (255,), letter_spacing=1)
        draw_smooth_text(img, ((hx0 + hx1) // 2, hy0 + 20),
                         state.preset_name.replace("  ", " "),
                         size=38, fill=INK_HI + (255,), anchor="mt")
        draw_text(img, (hx1 - 16, hy0 + 16), status,
                  fill=status_col + (255,), scale=2, anchor="rt",
                  letter_spacing=1)
        draw_text(img, (hx1 - 16, hy0 + 50),
                  "FX {}/{}".format(active_n, len(EFFECTS)),
                  fill=SCR_TEXT_DIM + (255,), scale=1, anchor="rt",
                  letter_spacing=1)

        _draw_800x480_chain(img, state,
                            (safe + 12, safe + 102,
                             int(width) - safe - 12, safe + 172))

        selected = _selected_fx_label(state)
        selected_on = _selected_fx_on(state)
        fx_box = (safe + 12, safe + 188, safe + 288, int(height) - safe - 12)
        fx0, fy0, fx1, fy1 = fx_box
        rounded_rect(d, fx_box, 8, fill=(8, 13, 20, 255),
                     outline=LED + (60,), width=1)
        draw_text(img, (fx0 + 14, fy0 + 12), "SELECTED FX",
                  fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=2)
        draw_smooth_text(img, (fx0 + 14, fy0 + 34), selected.upper(),
                         size=25, fill=LED + (255,))
        draw_text(img, (fx1 - 14, fy0 + 14), "ON" if selected_on else "BYPASS",
                  fill=(LED if selected_on else (180, 90, 70)) + (255,),
                  scale=1, anchor="rt", letter_spacing=1)
        rows_y = fy0 + 78
        knobs = state.knobs()[:4]
        for i, (label, value) in enumerate(knobs):
            if not label:
                continue
            ry = rows_y + i * 36
            draw_text(img, (fx0 + 16, ry), label,
                      fill=(LED if i == state.selected_knob else SCR_TEXT_DIM) + (255,),
                      scale=1, letter_spacing=1)
            bar_x0, bar_x1 = fx0 + 88, fx1 - 42
            rounded_rect(d, (bar_x0, ry + 4, bar_x1, ry + 16), 4,
                         fill=(3, 5, 8, 255), outline=(0, 0, 0, 255), width=1)
            fill_w = int((bar_x1 - bar_x0 - 2) * max(0.0, min(1.0, value / 100.0)))
            if fill_w > 0:
                d.rectangle((bar_x0 + 1, ry + 5, bar_x0 + fill_w, ry + 15),
                            fill=LED_DIM + (255,))
            draw_text(img, (fx1 - 14, ry), "{:>3}".format(int(value)),
                      fill=LED + (255,), scale=1, anchor="rt")

        _draw_800x480_monitor(img, state,
                              (safe + 304, safe + 188,
                               int(width) - safe - 12, safe + 330))
        _draw_800x480_levels(img, state,
                             (safe + 304, safe + 344,
                              int(width) - safe - 12, int(height) - safe - 12))

        arr = np.asarray(img.convert("RGB"), dtype=np.uint8)
        cache.put_frame(key, arr)
        cache.stats["frame_misses"] += 1
        return arr
    finally:
        _ACTIVE_RENDER_CACHE = prev


COMPACT_V2_LAYOUT = {
    # Phase 4G compact-v2 coordinates for 800x480, restored in Phase 6G.
    # Phase 6F tried to compensate the LCD's right-shift at the
    # renderer level by tightening the chassis margin to 4 px, but the
    # actual cause was the VTC HSync timing (the LCD's HDMI receiver
    # samples 150 source pixels later than expected). Phase 6G fixes
    # that at the VTC layer (AudioLabHdmiBackend._start_vtc applies a
    # +150 HSync shift), so the chassis is back to the Phase 4G
    # baseline.
    "outer": (12, 12, 788, 468),
    "left": 24,
    "right": 24,
    "header_y": (20, 100),
    "chain_y": (110, 250),
    "bottom_y": (260, 454),
}


def compact_v2_panel_boxes(width=800, height=480):
    """Return the compact-v2 panel rectangles for diagnostic overlays.

    Keyed bounding boxes (x0, y0, x1, y1) in the 800x480 logical canvas:

    - ``outer``  : full chassis frame.
    - ``header`` : preset + status band.
    - ``chain``  : signal chain row.
    - ``fx``     : selected-FX panel (spans the full bottom row).

    Coordinates exactly mirror ``_render_frame_800x480_compact_v2`` so the
    layout-debug overlay can draw bboxes on top of a real frame.
    """
    Wv = int(width)
    Hv = int(height)
    left = COMPACT_V2_LAYOUT["left"]
    right = COMPACT_V2_LAYOUT["right"]
    hy0, hy1 = COMPACT_V2_LAYOUT["header_y"]
    cy0, cy1 = COMPACT_V2_LAYOUT["chain_y"]
    if Wv == 800 and Hv == 480:
        outer = COMPACT_V2_LAYOUT["outer"]
        by0, by1 = COMPACT_V2_LAYOUT["bottom_y"]
    else:
        outer = (12, 12, Wv - 12, Hv - 12)
        by0 = COMPACT_V2_LAYOUT["bottom_y"][0]
        by1 = Hv - 26
    boxes = {
        "outer": outer,
        "header": (left, hy0, Wv - right, hy1),
        "chain": (left, cy0, Wv - right, cy1),
        "fx": (left, by0, Wv - right, by1),
    }
    return boxes


def _render_frame_800x480_compact_v2(state: AppState, width: int = 800,
                                     height: int = 480,
                                     cache: Optional[RenderCache] = None,
                                     placement_label: Optional[str] = None,
                                     theme=None
                                     ) -> np.ndarray:
    """Phase 4G compact-v2 800x480 layout for the 5-inch HDMI LCD.

    The v1 logical layout looked right-shifted on the actual panel because
    its inner safe margin combined with the LCD's viewport cropping left a
    wide blank strip on the left. v2 keeps the same dark visual language
    but tightens the outer margin, fills the full 776x456 inner area,
    uses larger text and 2 px strokes, and draws corner markers so a
    photo can verify which framebuffer pixels reach the panel.

    Phase 4H briefly tried to push the chassis down ~18 px and use an
    18 px left margin to chase a reported top-clip / unused left strip;
    on the actual 5-inch LCD that direction produced a downward + right
    skew, so Phase 4I rolled the coordinates back to this Phase 4G
    baseline. The renderer still reads its rectangles from the public
    ``compact_v2_panel_boxes`` helper so diagnostic scripts can overlay
    the same bboxes.
    """
    if cache is None:
        cache = make_pynq_static_render_cache()
    elif not getattr(cache, "pynq_static_mode", False):
        cache.pynq_static_mode = True
        cache.visualizer_fps = 0.0
        cache.meter_fps = 0.0

    palette = resolve_theme(theme)
    theme_name = str(palette.get("name", DEFAULT_800X480_THEME))

    label_key = "" if placement_label is None else str(placement_label)
    key = ("compact_v2_800x480", int(width), int(height), label_key,
           theme_name,
           state_semistatic_signature(state),
           state_dynamic_signature(state, cache))
    cached = cache.frame_cache.get(key)
    if cached is not None:
        cache.stats["frame_hits"] += 1
        return cached

    # Palette-resolved local aliases. These shadow the module-level
    # constants for the body of this function so existing call sites
    # like ``LED + (255,)`` keep working without renames.
    LED       = palette["LED"]
    LED_SOFT  = palette["LED_SOFT"]
    LED_DIM   = palette["LED_DIM"]
    SCR_TEXT_DIM = palette["SCR_TEXT_DIM"]
    INK_HI    = palette["INK_HI"]
    bypass_color = palette["BYPASS_COL"]

    global _ACTIVE_RENDER_CACHE
    prev = _ACTIVE_RENDER_CACHE
    _ACTIVE_RENDER_CACHE = cache
    try:
        Wv = int(width)
        Hv = int(height)
        img = Image.new("RGBA", (Wv, Hv), (0, 0, 0, 255))
        gradient = vertical_gradient(Wv, Hv, palette["BG_GRAD"])
        img.paste(gradient, (0, 0))
        d = ImageDraw.Draw(img)

        boxes = compact_v2_panel_boxes(Wv, Hv)
        outer = boxes["outer"]
        rounded_rect(d, outer, 12,
                     fill=palette["CHASSIS_INNER_FILL"],
                     outline=LED + (90,), width=2)

        active_n = sum(1 for v in state.effect_on if v)
        bypassed = active_n == 0
        status = "SAFE  BYPASS" if bypassed else "ACTIVE"
        status_col = bypass_color if bypassed else LED

        header = boxes["header"]
        hx0, hy0, hx1, hy1 = header
        rounded_rect(d, header, 10, fill=palette["PANEL_HEADER_FILL"],
                     outline=LED + (110,), width=2)
        draw_text(img, (hx0 + 18, hy0 + 10), "PRESET",
                  fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=3)
        draw_smooth_text(img, (hx0 + 18, hy0 + 28),
                         state.preset_id, size=44,
                         fill=INK_HI + (255,), letter_spacing=1)
        draw_smooth_text(img, ((hx0 + hx1) // 2, hy0 + 22),
                         state.preset_name.replace("  ", " "),
                         size=36, fill=INK_HI + (255,), anchor="mt")
        chip_w, chip_h = 158, 34
        chip = (hx1 - 16 - chip_w, hy0 + 12,
                hx1 - 16, hy0 + 12 + chip_h)
        rounded_rect(d, chip, 8, fill=palette["HEADER_CHIP_FILL"],
                     outline=status_col + (255,), width=2)
        draw_text(img, ((chip[0] + chip[2]) // 2,
                        (chip[1] + chip[3]) // 2),
                  status, fill=status_col + (255,), scale=2,
                  anchor="mm", letter_spacing=2)
        draw_text(img, (hx1 - 16, hy0 + 54),
                  "FX  {}/{}".format(active_n, len(EFFECTS)),
                  fill=LED + (255,), scale=2, anchor="rt",
                  letter_spacing=2)

        chain = boxes["chain"]
        cx0, cy0, cx1, cy1 = chain
        rounded_rect(d, chain, 10, fill=palette["PANEL_CHAIN_FILL"],
                     outline=LED + (90,), width=2)
        draw_text(img, (cx0 + 16, cy0 + 10), "SIGNAL  CHAIN",
                  fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=3)
        draw_text(img, (cx1 - 16, cy0 + 10),
                  "SEL {}".format(EFFECTS_SHORT[state.selected_effect]),
                  fill=LED + (255,), scale=1, anchor="rt",
                  letter_spacing=2)
        n = max(1, len(EFFECTS))
        gap = 8
        inner_pad = 14
        row_y0 = cy0 + 36
        row_y1 = cy1 - 14
        avail_w = (cx1 - cx0) - inner_pad * 2
        cell_w = int((avail_w - gap * (n - 1)) / n)
        for pos, eff_idx in enumerate(state.chain[:n]):
            bx0 = cx0 + inner_pad + pos * (cell_w + gap)
            bx1 = bx0 + cell_w
            on = (bool(state.effect_on[eff_idx])
                  if eff_idx < len(state.effect_on) else False)
            selected = eff_idx == state.selected_effect
            if on:
                fill = palette["CHAIN_ON_FILL"]
                outline = LED + ((255,) if selected else (170,))
                text_col = LED + (255,)
            else:
                fill = palette["CHAIN_OFF_FILL"]
                outline = palette["CHAIN_OFF_OUTLINE"]
                text_col = palette["CHAIN_OFF_TEXT"]
            rounded_rect(d, (bx0, row_y0, bx1, row_y1), 8,
                         fill=fill, outline=outline,
                         width=3 if selected else 2)
            draw_text(img, ((bx0 + bx1) // 2, row_y0 + 14),
                      EFFECTS_SHORT[eff_idx],
                      fill=text_col, scale=2, anchor="mt",
                      letter_spacing=2)
            badge_y = row_y1 - 14
            d.rectangle((bx0 + 10, badge_y, bx1 - 10, badge_y + 6),
                        fill=(LED if on else palette["CHAIN_BADGE_OFF"]) + (255,))

        fx_box = boxes["fx"]
        fx0, fy0, fx1, fy1 = fx_box
        rounded_rect(d, fx_box, 10, fill=palette["PANEL_FX_FILL"],
                     outline=LED + (90,), width=2)
        selected_name = _selected_fx_label(state)
        selected_on = _selected_fx_on(state)
        pedal_idx = max(0, min(len(DIST_MODELS) - 1,
                               int(getattr(state, "dist_model_idx", 0) or 0)))
        amp_idx = max(0, min(len(AMP_MODELS) - 1,
                             int(getattr(state, "amp_model_idx", 0) or 0)))
        cab_idx = max(0, min(len(CAB_MODELS) - 1,
                             int(getattr(state, "cab_model_idx", 0) or 0)))
        pedal_label = _pedal_label(state)
        amp_label = _amp_label(state)
        cab_label = _cab_label(state)
        draw_text(img, (fx0 + 16, fy0 + 10), "SELECTED  FX",
                  fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=3)
        draw_smooth_text(img, (fx0 + 16, fy0 + 28),
                         selected_name.upper(), size=28,
                         fill=LED + (255,))
        s_chip_w, s_chip_h = 110, 30
        s_chip = (fx1 - 16 - s_chip_w, fy0 + 18,
                  fx1 - 16, fy0 + 18 + s_chip_h)
        s_col = LED if selected_on else bypass_color
        rounded_rect(d, s_chip, 6, fill=palette["FX_CHIP_FILL"],
                     outline=s_col + (255,), width=2)
        draw_text(img, ((s_chip[0] + s_chip[2]) // 2,
                        (s_chip[1] + s_chip[3]) // 2),
                  "ON" if selected_on else "BYPASS",
                  fill=s_col + (255,), scale=2, anchor="mm",
                  letter_spacing=2)

        # Phase 6D: restore the compact-v2 layout from 0a07f2a. The
        # standalone [model ▼] chip Phase 6C dropped between the
        # SELECTED FX name and the ON/BYPASS chip overlapped the
        # ACTIVE MODELS column, which hid the PEDAL / AMP rows. The
        # dropdown marker is now a thin outline + triangle glyph drawn
        # only around the matching ACTIVE MODELS row (PEDAL / AMP / CAB)
        # when the SELECTED FX category warrants it. Other effects --
        # REVERB / EQ / COMPRESSOR / NOISE SUPPRESSOR / SAFE / PRESET --
        # get no extra marker and the row renders identically to
        # 0a07f2a. The Notebook ipywidgets remain the actual control.
        model_x0 = fx0 + 270
        model_x1 = fx1 - 16
        draw_text(img, (model_x0, fy0 + 10), "ACTIVE  MODELS",
                  fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=3)
        model_rows = [
            ("PEDAL", _compact_model_label(pedal_label)),
            ("AMP", _compact_model_label(amp_label)),
            ("CAB", _compact_model_label(cab_label)),
        ]
        dropdown_category = (_dropdown_category(state)
                             if _should_show_selected_model_dropdown(state)
                             else "")
        category_to_row = {"PEDAL": 0, "AMP": 1, "CAB": 2}
        highlight_row = category_to_row.get(dropdown_category, -1)
        # The ON/BYPASS chip lives at (s_chip[0], fy0+18) -- y=18..48 in
        # FX-panel-local coordinates. The PEDAL row sits at ry=fy0+31,
        # so its highlight rect would collide with the chip if it
        # extended to model_x1. Cap the right edge at s_chip[0]-12 for
        # the PEDAL row only, and let AMP/CAB rows (below the chip)
        # extend all the way to model_x1.
        for row, (label, value) in enumerate(model_rows):
            ry = fy0 + 31 + row * 18
            if row == highlight_row:
                outline_y0 = ry - 3
                outline_y1 = ry + 13
                outline_x0 = model_x0 + 64
                if outline_y1 > fy0 + 18 and outline_y0 < fy0 + 48:
                    outline_x1 = min(model_x1 - 4, s_chip[0] - 12)
                else:
                    outline_x1 = model_x1 - 4
                rounded_rect(d,
                             (outline_x0, outline_y0,
                              outline_x1, outline_y1),
                             4, fill=palette["FX_CHIP_FILL"],
                             outline=LED + (220,), width=1)
                _draw_dropdown_arrow(
                    d, (outline_x1 - 12, ry + 1,
                        outline_x1 - 4, ry + 9), LED)
            draw_text(img, (model_x0, ry), label,
                      fill=SCR_TEXT_DIM + (255,), scale=1,
                      letter_spacing=2)
            value_color = LED + (255,)
            draw_text(img, (model_x0 + 72, ry), value,
                      fill=value_color, scale=1, letter_spacing=1)

        def _slot_row(labels, active_index, x0, y0, x1, h, gap=6):
            count = max(1, len(labels))
            cell_w = int((x1 - x0 - gap * (count - 1)) / count)
            for i, text in enumerate(labels):
                bx0 = x0 + i * (cell_w + gap)
                bx1 = bx0 + cell_w
                active = i == active_index
                fill = (palette["CHAIN_ON_FILL"] if active
                        else palette["CHAIN_OFF_FILL"])
                outline = LED + ((230,) if active else (90,))
                text_col = LED + (255,) if active else SCR_TEXT_DIM + (255,)
                rounded_rect(d, (bx0, y0, bx1, y0 + h), 5,
                             fill=fill, outline=outline,
                             width=2 if active else 1)
                draw_text(img, ((bx0 + bx1) // 2, y0 + h // 2),
                          text, fill=text_col, scale=1, anchor="mm",
                          letter_spacing=1)

        # Phase 6E: replace the PEDAL MODEL / AMP MODEL / CAB slot rows
        # with a per-SELECTED-FX parameter knob grid (label + value bar +
        # numeric percent). Layout adapts to the parameter count:
        #   3 knobs -> 3x1
        #   4 knobs -> 2x2
        #   6 knobs -> 3x2
        #   8 knobs -> 4x2 (AMP SIM)
        # The IN / OUT meters keep their original anchor on the right.
        # Phase 6E: the ACTIVE MODELS column's CAB row ends near fy0+78,
        # so the knob grid starts at fy0+82 to leave breathing room and
        # not paint over the CAB live label.
        knob_y0 = fy0 + 82
        knob_y1 = fy1 - 14
        meter_x0 = fx0 + 548
        meter_x1 = fx1 - 18
        knob_x0 = fx0 + 16
        knob_x1 = meter_x0 - 12

        params = selected_fx_param_layout(state)
        values = list(getattr(state, "knob_values", []) or [])
        # Pad short value lists so we can index up to 8 without IndexError.
        while len(values) < 8:
            values.append(0)
        count = len(params)
        if count == 0:
            cols, rows = 0, 0
        elif count <= 3:
            cols, rows = count, 1
        elif count == 4:
            cols, rows = 2, 2
        elif count <= 6:
            cols, rows = 3, 2
        else:
            cols, rows = 4, 2

        if count > 0:
            grid_gap_x = 8
            grid_gap_y = 6
            cell_w = int((knob_x1 - knob_x0 - grid_gap_x * (cols - 1))
                         / cols)
            cell_h = int((knob_y1 - knob_y0 - grid_gap_y * (rows - 1))
                         / rows)
            for slot, (param_label, knob_idx) in enumerate(params):
                col = slot % cols
                row = slot // cols
                bx0 = knob_x0 + col * (cell_w + grid_gap_x)
                by0 = knob_y0 + row * (cell_h + grid_gap_y)
                bx1 = bx0 + cell_w
                by1 = by0 + cell_h
                rounded_rect(d, (bx0, by0, bx1, by1), 6,
                             fill=palette["FX_CHIP_FILL"],
                             outline=LED + (110,), width=1)
                # Label on the top row of the cell.
                draw_text(img, (bx0 + 8, by0 + 6), param_label,
                          fill=SCR_TEXT_DIM + (255,), scale=1,
                          letter_spacing=2)
                # Numeric percent on the right of the same row.
                try:
                    raw_value = float(values[knob_idx])
                except (TypeError, ValueError, IndexError):
                    raw_value = 0.0
                percent = max(0.0, min(150.0, raw_value))
                draw_text(img, (bx1 - 8, by0 + 6),
                          "{:d}".format(int(round(percent))),
                          fill=LED + (255,), scale=1, anchor="rt",
                          letter_spacing=1)
                # Value bar across the bottom half of the cell.
                bar_x0 = bx0 + 8
                bar_x1 = bx1 - 8
                bar_y0 = by1 - 14
                bar_y1 = by1 - 6
                rounded_rect(d, (bar_x0, bar_y0, bar_x1, bar_y1), 3,
                             fill=palette["BAR_BG_FILL"],
                             outline=palette["BAR_OUTLINE"], width=1)
                bar_pct = max(0.0, min(1.0, percent / 100.0))
                fill_w = int((bar_x1 - bar_x0 - 2) * bar_pct)
                if fill_w > 0:
                    d.rectangle((bar_x0 + 1, bar_y0 + 1,
                                 bar_x0 + fill_w, bar_y1 - 1),
                                fill=LED_DIM + (255,))
        else:
            draw_text(img, (knob_x0, knob_y0 + 8),
                      "NO  PARAMETERS",
                      fill=SCR_TEXT_DIM + (255,), scale=1,
                      letter_spacing=3)

        bottom_y = fy0 + 126
        draw_text(img, (meter_x0, bottom_y), "LEVELS",
                  fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=2)
        def _mini_meter(label, y, value):
            draw_text(img, (meter_x0, y - 1), label,
                      fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=1)
            bx0 = meter_x0 + 32
            bx1 = meter_x1
            rounded_rect(d, (bx0, y, bx1, y + 9), 3,
                         fill=palette["BAR_BG_FILL"],
                         outline=palette["BAR_OUTLINE"], width=1)
            v = max(0.0, min(1.0, float(value)))
            fill_w = int((bx1 - bx0 - 2) * v)
            if fill_w > 0:
                d.rectangle((bx0 + 1, y + 1,
                             bx0 + fill_w, y + 8),
                            fill=LED_DIM + (255,))
        _mini_meter("IN", bottom_y + 20, state.in_level)
        _mini_meter("OUT", bottom_y + 40, state.out_level)

        # Corner canvas markers + variant label.
        marker = LED + (255,)
        d.rectangle((2, 2, 18, 5), fill=marker)
        d.rectangle((2, 2, 5, 18), fill=marker)
        d.rectangle((Wv - 18, 2, Wv - 3, 5), fill=marker)
        d.rectangle((Wv - 5, 2, Wv - 3, 18), fill=marker)
        d.rectangle((2, Hv - 5, 18, Hv - 3), fill=marker)
        d.rectangle((2, Hv - 18, 5, Hv - 3), fill=marker)
        d.rectangle((Wv - 18, Hv - 5, Wv - 3, Hv - 3), fill=marker)
        d.rectangle((Wv - 5, Hv - 18, Wv - 3, Hv - 3), fill=marker)
        draw_text(img, (8, 8), "TL", fill=marker, scale=1, letter_spacing=1)
        draw_text(img, (Wv - 8, 8), "TR", fill=marker, scale=1,
                  anchor="rt", letter_spacing=1)
        draw_text(img, (8, Hv - 8), "BL", fill=marker, scale=1,
                  anchor="lb", letter_spacing=1)
        draw_text(img, (Wv - 8, Hv - 8), "BR", fill=marker, scale=1,
                  anchor="rb", letter_spacing=1)

        label_text = "v=compact-v2"
        if placement_label:
            label_text = "v=compact-v2  " + str(placement_label)
        draw_text(img, (Wv // 2, Hv - 4), label_text,
                  fill=LED_SOFT + (255,), scale=1, anchor="mb",
                  letter_spacing=2)

        # Convert to a writable RGB ndarray *before* applying the
        # Pip-Boy-style scanline overlay so the blend is a single
        # vectorised numpy slice (much cheaper than PIL
        # alpha_composite on a 480x800 RGBA buffer).
        arr = np.array(img.convert("RGB"), dtype=np.uint8)
        _apply_scanlines_inplace(arr,
                                 palette.get("SCANLINE_STEP", 0),
                                 palette.get("SCANLINE_RGBA"))
        cache.put_frame(key, arr)
        cache.stats["frame_misses"] += 1
        return arr
    finally:
        _ACTIVE_RENDER_CACHE = prev



def render_frame_800x480(state: AppState, width: int = 800,
                         height: int = 480,
                         cache: Optional[RenderCache] = None,
                         variant: str = "compact-v1",
                         placement_label: Optional[str] = None,
                         theme=None) -> np.ndarray:
    """Convenience wrapper for the 800x480 5-inch logical layout.

    ``variant`` selects which 800x480 design to render. The Phase 4E
    layout is preserved as ``compact-v1`` for the existing call sites.
    ``compact-v2`` is the Phase 4G layout tuned for the 5-inch LCD; it
    tightens margins, uses larger text, and draws TL/TR/BL/BR corner
    markers plus an optional ``placement_label`` overlay so a photo can
    confirm which pixels reach the panel.

    ``theme`` selects an 800x480 colour palette. Valid names are listed
    in ``THEMES``; the default is ``DEFAULT_800X480_THEME`` (Phase 5D
    Pip-Boy-inspired phosphor green). Pass ``"cyan"`` for the legacy
    look. compact-v1 ignores the theme and keeps the pre-Phase-5D
    visuals so prior tooling stays bit-stable.
    """
    v = str(variant).lower()
    if v in ("compact-v1", "v1", "logical", ""):
        return _render_frame_800x480_logical(
            state, width=width, height=height, cache=cache)
    if v in ("compact-v2", "v2"):
        return _render_frame_800x480_compact_v2(
            state, width=width, height=height, cache=cache,
            placement_label=placement_label, theme=theme)
    raise ValueError(
        "unknown 800x480 variant {!r}; expected compact-v1 or compact-v2"
        .format(variant))


def render_frame_800x480_compact_v2(state: AppState, width: int = 800,
                                    height: int = 480,
                                    cache: Optional[RenderCache] = None,
                                    placement_label: Optional[str] = None,
                                    theme=None
                                    ) -> np.ndarray:
    """Direct entry point for the Phase 4G compact-v2 800x480 layout.

    ``theme`` selects an 800x480 colour palette. Defaults to
    ``DEFAULT_800X480_THEME`` (Phase 5D Pip-Boy-inspired phosphor green);
    pass ``"cyan"`` for the legacy look.
    """
    return _render_frame_800x480_compact_v2(
        state, width=width, height=height, cache=cache,
        placement_label=placement_label, theme=theme)


# =============================================================================
# JSON STATE PERSISTENCE
# =============================================================================
STATE_FILE = "fx_gui_state.json"

_STATE_KEYS = ("preset_id", "preset_name", "preset_idx",
               "selected_effect", "selected_fx", "selected_knob",
               "effect_on", "knob_values", "chain", "display_mode",
               "dist_model_idx", "amp_model_idx", "cab_model_idx",
               "fs_states", "fs_selected")


def save_state_json(state: AppState, path: str = STATE_FILE) -> None:
    try:
        data = {k: getattr(state, k) for k in _STATE_KEYS}
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception as exc:
        print(f"[state] save failed: {exc}")


def load_state_json(path: str = STATE_FILE) -> AppState:
    state = AppState()
    if not os.path.exists(path):
        return state
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        for k in _STATE_KEYS:
            if k in data:
                setattr(state, k, data[k])
        # sanity: list lengths
        if len(state.effect_on) != len(EFFECTS):
            state.effect_on = [True] * len(EFFECTS)
        if len(state.knob_values) != 8:
            defaults = [k[1] for k in
                        EFFECT_KNOBS[EFFECTS[state.selected_effect]]]
            # pad short legacy snapshots to the Phase 6E 8-slot layout
            while len(defaults) < 8:
                defaults.append(0)
            state.knob_values = defaults[:8]
        if len(state.chain) != len(EFFECTS):
            state.chain = list(range(len(EFFECTS)))
        state.selected_effect = max(0, min(len(EFFECTS) - 1,
                                           state.selected_effect))
        state.selected_knob = max(0, min(7, state.selected_knob))
    except Exception as exc:
        print(f"[state] load failed ({exc}); using defaults")
        state = AppState()
    return state
