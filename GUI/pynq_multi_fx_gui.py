"""
DOY FX CORE — Multi-Effects Processor GUI
==========================================
Hi-fi multi-effects pedal GUI for PYNQ-Z2 HDMI out (1280x720, RGB).
Pure PIL + NumPy. No external assets, no system fonts, no OpenCV/matplotlib.

Public API
----------
    state = AppState()
    rgb = render_frame(state)            # -> np.ndarray (720, 1280, 3) uint8
    Image.fromarray(rgb).save("preview.png")

PYNQ offscreen usage
--------------------
    state = AppState()
    frame = render_frame_fast(state)

AudioLab must not use run_pynq_hdmi()/base.bit directly because that would
replace the DSP overlay. HDMI output is expected to be wired through a future
audio_lab.bit that also contains the video output path.
"""

import json
import math
import os
import time
from typing import List, Tuple, Optional

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
W, H = 1280, 720

# ---- LAYOUT GRID (single source of truth for margins) -------------------
# Outer chassis padding. Use these instead of bare 36/12 throughout.
CHASSIS_PAD     = 36   # chassis edge -> any panel edge
PANEL_INSET     = 12   # panel edge   -> inner content
GUTTER          = 14   # gap between adjacent sub-zones inside a panel

# Vertical band splits (top→bottom):
#   top status bar   : Y_TOPBAR_T  .. Y_TOPBAR_B
#   main display     : Y_MAIN_T    .. Y_MAIN_B
#   knob panel       : Y_KNOB_T    .. Y_KNOB_B   (fills to bottom)
Y_TOPBAR_T, Y_TOPBAR_B = 32, 86
Y_MAIN_T,   Y_MAIN_B   = 100, 458
Y_KNOB_T,   Y_KNOB_B   = 472, 700

# Common content rects (left, top, right, bottom)
RECT_TOPBAR = (CHASSIS_PAD,     Y_TOPBAR_T, W - CHASSIS_PAD, Y_TOPBAR_B)
RECT_MAIN   = (CHASSIS_PAD,     Y_MAIN_T,   W - CHASSIS_PAD, Y_MAIN_B)
RECT_KNOB   = (CHASSIS_PAD,     Y_KNOB_T,   W - CHASSIS_PAD, Y_KNOB_B)

# Main-display inner columns (preset | middle | right). Tuned so the
# right column fits SELECTED FX + INPUT + OUTPUT cards without overlap.
COL_LEFT_W  = 268
COL_RIGHT_W = 280
# -------------------------------------------------------------------------

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
# EFFECTS / CONSTANTS
# =============================================================================
# Audio-Lab-PYNQ chain order:
# Noise Suppressor -> Compressor -> Overdrive -> Distortion Pedalboard
# -> Amp Simulator -> Cab IR -> EQ -> Reverb
EFFECTS = ["Noise Sup", "Compressor", "Overdrive", "Distortion",
           "Amp Sim", "Cab IR", "EQ", "Reverb"]
EFFECTS_SHORT = ["NS", "CMP", "OD", "DIST", "AMP", "CAB", "EQ", "RVB"]

# Per-effect knob assignments (label, default 0..100). Up to 6 are shown
# in the panel; longer sets (Amp=8, Distortion=6) are truncated to top 6.
EFFECT_KNOBS = {
    "Noise Sup":  [("THRESH", 35),  ("DECAY", 45),   ("DAMP", 80),
                   ("", 0),         ("", 0),         ("", 0)],
    "Compressor": [("THRESH", 50),  ("RATIO", 45),   ("RESPONSE", 40),
                   ("MAKEUP", 55),  ("", 0),         ("", 0)],
    "Overdrive":  [("DRIVE", 35),   ("TONE", 60),    ("LEVEL", 60),
                   ("", 0),         ("", 0),         ("", 0)],
    "Distortion": [("DRIVE", 50),   ("TONE", 55),    ("LEVEL", 35),
                   ("BIAS", 50),    ("TIGHT", 60),   ("MIX", 100)],
    "Amp Sim":    [("GAIN", 45),    ("BASS", 55),    ("MID", 60),
                   ("TREBLE", 50),  ("MASTER", 70),  ("CHAR", 60)],
    "Cab IR":     [("MIX", 100),    ("LEVEL", 70),   ("MODEL", 33),
                   ("AIR", 35),     ("", 0),         ("", 0)],
    "EQ":         [("LOW", 50),     ("MID", 55),     ("HIGH", 55),
                   ("", 0),         ("", 0),         ("", 0)],
    "Reverb":     [("DECAY", 30),   ("TONE", 65),    ("MIX", 25),
                   ("", 0),         ("", 0),         ("", 0)],
}

# Distortion Pedalboard model names (pedal-mask bit -> name).
DIST_MODELS = ["CLEAN BOOST", "TUBE SCREAMER", "RAT", "DS-1",
               "BIG MUFF", "FUZZ FACE", "METAL"]
# Legacy alias.
DISTORTION_PEDALS = [m.lower().replace(" ", "_").replace("-", "") for m in DIST_MODELS]

# Amp Simulator named voicings (label, character byte center value).
AMP_MODELS = [("JC CLEAN", 10), ("CLEAN COMBO", 35),
              ("BRITISH CRUNCH", 60), ("HIGH GAIN STACK", 85)]

# Cabinet IR model names.
CAB_MODELS = ["1x12 COMBO", "2x12 BLACK", "4x12 BRITISH", "4x12 V30", "DIRECT DI"]

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

    # parameter knobs (6 per effect, 0..100)
    knob_values: List[float] = field(default_factory=lambda: [45, 55, 60, 50, 70, 60])
    selected_knob: int       = 0

    # model-pick indices for the three model-driven effects
    dist_model_idx: int = 1   # Tube Screamer
    amp_model_idx:  int = 2   # British Crunch
    cab_model_idx:  int = 2   # 4x12 British

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

    # I/O metering — driven from t inside render_frame for live feel
    in_level: float  = 0.6
    out_level: float = 0.7
    cpu: int         = 42

    def knobs(self) -> List[Tuple[str, float]]:
        labels = [k[0] for k in EFFECT_KNOBS[EFFECTS[self.selected_effect]]]
        return list(zip(labels, self.knob_values))


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

def add_brushed_metal(img: Image.Image, intensity: int = 5):
    """Composite very subtle horizontal brushed-metal noise on RGB image."""
    if img.mode != "RGB": return img
    w, h = img.size
    # 1D noise repeated vertically gives horizontal striations
    rng = _rng(7)
    line = rng.integers(-intensity, intensity + 1, size=w, dtype=np.int16)
    noise = np.tile(line, (h, 1)).astype(np.int16)
    arr = np.array(img, dtype=np.int16)
    for c in range(3):
        arr[:, :, c] = np.clip(arr[:, :, c] + noise, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGB")

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

def panel_with_bevel(img: Image.Image, xy, fill_top, fill_bot,
                     radius=10, glow_color=None, glow_alpha=70):
    """Paste a vertically-graded rounded panel with top highlight + bottom shadow."""
    x0, y0, x1, y1 = [int(v) for v in xy]
    w, h = x1 - x0, y1 - y0
    if w <= 0 or h <= 0:
        return
    grad = vertical_gradient(w, h, [(0.0, fill_top), (1.0, fill_bot)])
    grad = add_brushed_metal(grad, intensity=3)
    # rounded mask
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    rounded_rect(md, (0, 0, w, h), radius, fill=255)
    img.paste(grad, (x0, y0), mask)

    # outer glow
    if glow_color is not None:
        halo = Image.new("RGBA", (w + 20, h + 20), (0, 0, 0, 0))
        hd = ImageDraw.Draw(halo)
        rounded_rect(hd, (10, 10, 10 + w, 10 + h), radius,
                     outline=glow_color + (glow_alpha,), width=3)
        halo = halo.filter(ImageFilter.GaussianBlur(6))
        img.alpha_composite(halo, (x0 - 10, y0 - 10))

    # bevel: top highlight + bottom shadow
    rgba = img if img.mode == "RGBA" else None
    bevel = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bevel)
    rounded_rect(bd, (0, 0, w - 1, h - 1), radius,
                 outline=(255, 255, 255, 28), width=1)
    rounded_rect(bd, (1, 1, w - 2, h - 2), radius - 1 if radius > 0 else 0,
                 outline=(255, 255, 255, 14), width=1)
    rounded_rect(bd, (0, 1, w - 1, h - 1), radius,
                 outline=(0, 0, 0, 80), width=1)
    bevel_mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(bevel_mask).rectangle((0, 0, w, h), fill=255)
    if rgba is not None:
        rgba.alpha_composite(bevel, (x0, y0))
    else:
        img.paste(bevel, (x0, y0), bevel)

def inset_screen(img: Image.Image, xy, radius=8, bg_top=SCR_BG_HI, bg_bot=SCR_BG):
    """Recessed dark display surface."""
    x0, y0, x1, y1 = [int(v) for v in xy]
    w, h = x1 - x0, y1 - y0
    if w <= 0 or h <= 0:
        return
    grad = vertical_gradient(w, h, [(0.0, bg_top), (0.5, bg_bot), (1.0, bg_top)])
    mask = Image.new("L", (w, h), 0)
    rounded_rect(ImageDraw.Draw(mask), (0, 0, w, h), radius, fill=255)
    img.paste(grad, (x0, y0), mask)

    # subtle scanline texture
    sl = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sld = ImageDraw.Draw(sl)
    for y in range(0, h, 2):
        sld.line([(0, y), (w, y)], fill=(0, 0, 0, 40))
    sl_mask = Image.new("L", (w, h), 0)
    rounded_rect(ImageDraw.Draw(sl_mask), (0, 0, w, h), radius, fill=255)
    sl.putalpha(sl_mask)
    img.alpha_composite(sl, (x0, y0))

    # vignette
    vig = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vig)
    rounded_rect(vd, (-2, -2, w + 2, h + 2), radius + 2,
                 outline=(0, 0, 0, 220), width=4)
    vig = vig.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(vig, (x0, y0))

    # rim
    rim = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rounded_rect(ImageDraw.Draw(rim), (0, 0, w - 1, h - 1), radius,
                 outline=(0, 0, 0, 255), width=1)
    rounded_rect(ImageDraw.Draw(rim), (1, 1, w - 2, h - 2), radius - 1 if radius > 0 else 0,
                 outline=LED + (28,), width=1)
    img.alpha_composite(rim, (x0, y0))

def screw(img: Image.Image, x: int, y: int, r: int = 7):
    """Phillips-head metal screw."""
    layer = Image.new("RGBA", (r * 4, r * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = r * 2, r * 2
    # body radial-ish
    for i in range(r, 0, -1):
        t = (r - i) / r
        col = _lerp_color((90, 95, 102), (15, 17, 22), t * 0.85 + 0.05)
        d.ellipse((cx - i, cy - i, cx + i, cy + i), fill=col + (255,))
    # rim shadow
    d.ellipse((cx - r, cy - r, cx + r, cy + r),
              outline=(0, 0, 0, 220), width=1)
    # cross
    d.line((cx - r + 2, cy, cx + r - 2, cy), fill=(8, 9, 12, 255), width=1)
    d.line((cx, cy - r + 2, cx, cy + r - 2), fill=(8, 9, 12, 255), width=1)
    # highlight glint
    d.arc((cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1),
          200, 320, fill=(220, 230, 240, 110), width=1)
    img.alpha_composite(layer, (x - r * 2, y - r * 2))


# =============================================================================
# DRAWING — CHASSIS BACKGROUND
# =============================================================================
def draw_background(img: Image.Image, state: AppState):
    """Full chassis: deep room + brushed-metal top panel + corner screws."""
    # deep room
    room = vertical_gradient(W, H, [(0.0, (24, 28, 34)), (0.5, (10, 12, 16)),
                                    (1.0, (4, 5, 8))])
    img.paste(room, (0, 0))

    # top vignette light
    vig = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vig)
    vd.ellipse((W * 0.08, -200, W * 0.92, 280), fill=(255, 255, 255, 18))
    vig = vig.filter(ImageFilter.GaussianBlur(45))
    img.alpha_composite(vig)

    # main chassis panel
    panel_with_bevel(img, (12, 12, W - 12, H - 12),
                     fill_top=(58, 62, 70), fill_bot=(14, 16, 22),
                     radius=20)

    # subtle inner panel groove
    rd = ImageDraw.Draw(img)
    rounded_rect(rd, (18, 18, W - 18, H - 18), 17,
                 outline=(0, 0, 0, 200), width=1)
    rounded_rect(rd, (19, 19, W - 19, H - 19), 16,
                 outline=(255, 255, 255, 22), width=1)

    # screws disabled by spec
    # (kept the helper function above in case it is needed later)
    return


# =============================================================================
# LEDS / METERS / SMALL PARTS
# =============================================================================
def draw_led(img: Image.Image, x: int, y: int, on: bool = True,
             color: Tuple[int, int, int] = LED, size: int = 8):
    """Round LED with bloom when on."""
    if on and not _pynq_static_mode():
        halo = Image.new("RGBA", (size * 6, size * 6), (0, 0, 0, 0))
        hd = ImageDraw.Draw(halo)
        for r, a in [(size * 2.6, 60), (size * 1.8, 110), (size * 1.2, 180)]:
            hd.ellipse((size * 3 - r, size * 3 - r, size * 3 + r, size * 3 + r),
                       fill=color + (a,))
        halo = halo.filter(ImageFilter.GaussianBlur(2))
        img.alpha_composite(halo, (x - size * 3, y - size * 3))

    body = Image.new("RGBA", (size * 2 + 4, size * 2 + 4), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    cx, cy = size + 2, size + 2
    if on:
        bd.ellipse((cx - size, cy - size, cx + size, cy + size),
                   fill=color + (255,))
        # hot core
        bd.ellipse((cx - size + 2, cy - size + 2, cx + size - 2, cy + size - 2),
                   fill=(min(255, color[0] + 90), min(255, color[1] + 90),
                         min(255, color[2] + 90), 220))
        bd.ellipse((cx - 2, cy - 3, cx + 2, cy + 1),
                   fill=(255, 255, 255, 200))
    else:
        bd.ellipse((cx - size, cy - size, cx + size, cy + size),
                   fill=(40, 44, 50, 255))
        bd.ellipse((cx - size, cy - size, cx + size, cy + size),
                   outline=(0, 0, 0, 200), width=1)
    img.alpha_composite(body, (x - size - 2, y - size - 2))


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
# TOP STATUS BAR
# =============================================================================
def draw_top_status(img: Image.Image, state: AppState):
    bar_y0, bar_y1 = 32, 86
    bar_x0, bar_x1 = 36, W - 36

    panel_with_bevel(img, (bar_x0, bar_y0, bar_x1, bar_y1),
                     fill_top=(38, 42, 48), fill_bot=(18, 21, 26), radius=8)

    d = ImageDraw.Draw(img)

    # Brand wordmark — title only, no preset subtitle here
    # (preset name/id is shown inside the CHAIN PRESET card).
    my = (bar_y0 + bar_y1) // 2
    draw_text(img, (bar_x0 + 22, my - 5), "FPGA  GUITAR  EFFECTOR",
              fill=INK_HI + (255,), scale=2, letter_spacing=2)


# =============================================================================
# MAIN DISPLAY (preset card + signal chain + visualizer + side panel)
# =============================================================================
def _main_display_layout():
    x0, y0, x1, y1 = 36, 32, W - 36, 458
    sx0, sy0, sx1, sy1 = x0 + 12, y0 + 12, x1 - 12, y1 - 12
    sep1 = sx0 + 268
    sep2 = sx1 - 280
    mx0 = sep1 + 14
    mx1 = sep2 - 14
    return {
        "panel": (x0, y0, x1, y1),
        "screen": (sx0, sy0, sx1, sy1),
        "separators": (sep1, sep2),
        "preset": (sx0 + 12, sy0 + 10, sep1 - 12, sy1 - 10),
        "chain": (mx0, sy0 + 10, mx1, sy0 + 162),
        "visualizer": (mx0, sy0 + 174, mx1, sy1 - 10),
        "right": (sep2 + 14, sy0 + 10, sx1 - 12, sy1 - 10),
    }


def draw_main_display_static_chrome(img: Image.Image, include_static_monitor: bool = False):
    """State-independent LCD panel chrome, cached in the fast render base."""
    layout = _main_display_layout()
    x0, y0, x1, y1 = layout["panel"]
    panel_with_bevel(img, (x0, y0, x1, y1),
                     fill_top=(20, 23, 28), fill_bot=(10, 12, 16), radius=10)

    # inset screen
    inset_screen(img, (x0 + 12, y0 + 12, x1 - 12, y1 - 12), radius=8)

    # vertical separators
    d = ImageDraw.Draw(img)
    sx0, sy0, sx1, sy1 = layout["screen"]
    sep1, sep2 = layout["separators"]
    for sep in (sep1, sep2):
        d.line((sep, sy0 + 14, sep, sy1 - 14), fill=(0, 0, 0, 200), width=1)
        d.line((sep + 1, sy0 + 14, sep + 1, sy1 - 14), fill=LED + (28,), width=1)

    if include_static_monitor:
        draw_visualizer_static(img, layout["visualizer"])


def draw_main_display_content(img: Image.Image, state: AppState):
    """State-dependent LCD contents drawn over cached chrome."""
    layout = _main_display_layout()
    # ---- LEFT: preset card ----
    _draw_preset_card(img, layout["preset"], state)

    # ---- MIDDLE: signal chain (top) + visualizer (bottom) ----
    draw_signal_chain(img, state, layout["chain"])
    if not _pynq_static_mode():
        draw_visualizer(img, state, layout["visualizer"])

    # ---- RIGHT: tuner + IN meter + DSP load ----
    _draw_right_panel(img, layout["right"], state)


def draw_main_display(img: Image.Image, state: AppState):
    """Recessed LCD area broken into preset/chain/viz/right-meter zones."""
    # Top bar removed — reclaim that strip so the main display fills the
    # full available height between the chassis edges.
    draw_main_display_static_chrome(img)
    draw_main_display_content(img, state)


def _draw_preset_card(img: Image.Image, xy, state: AppState):
    x0, y0, x1, y1 = xy

    # PRESET tag
    draw_text(img, (x0, y0), "CHAIN  PRESET", fill=SCR_TEXT_DIM + (255,),
              scale=1, letter_spacing=2)

    # Big preset id — smooth anti-aliased TrueType (no bitmap chunkiness)
    draw_smooth_text(img, (x0, y0 + 18), state.preset_id,
                     size=64, fill=INK_HI + (255,), letter_spacing=2)
    # name in display font
    draw_text(img, (x0, y0 + 96), state.preset_name,
              fill=INK_HI + (255,), scale=2, letter_spacing=1)

    # active-effect summary (real, derived from state)
    active_n = sum(1 for v in state.effect_on if v)
    total_n  = len(EFFECTS)
    bypassed = active_n == 0
    status_label = "BYPASS" if bypassed else "ACTIVE"
    draw_text(img, (x0, y0 + 138), "ACTIVE  FX", fill=SCR_TEXT_DIM + (255,),
              scale=1, letter_spacing=2)
    draw_text(img, (x0 + 96, y0 + 137), f"{active_n}/{total_n}",
              fill=LED + (255,), scale=1, glow=LED_DEEP, letter_spacing=1)

    draw_text(img, (x0, y0 + 160), "STATUS", fill=SCR_TEXT_DIM + (255,),
              scale=1, letter_spacing=2)
    draw_text(img, (x0 + 96, y0 + 159), status_label,
              fill=(LED if not bypassed else (180, 90, 70)) + (255,),
              scale=1, glow=LED_DEEP, letter_spacing=1)

    # ACTIVE FX chips removed by spec.

    # ===== SAVE button (full-width) =====
    d = ImageDraw.Draw(img)
    save_y0 = y1 - 56
    save_y1 = y1 - 32
    flashing = state.save_flash > 0
    rounded_rect(d, (x0, save_y0, x1, save_y1), 5,
                 fill=(LED if flashing else (10, 26, 34)) + (255,),
                 outline=LED + (200,), width=1)
    draw_text(img, ((x0 + x1) // 2, (save_y0 + save_y1) // 2 - 4),
              "SAVE  PRESET",
              fill=(8, 18, 22) + (255,) if flashing else LED + (255,),
              scale=1, anchor="mm", letter_spacing=3)

    # ===== BACK / NEXT row =====
    btn_y = y1 - 26
    btn_w = (x1 - x0 - 8) // 2
    for i, label in enumerate(["< BACK", "NEXT >"]):
        bx0 = x0 + i * (btn_w + 8)
        bx1 = bx0 + btn_w
        rounded_rect(d, (bx0, btn_y, bx1, btn_y + 22), 4,
                     fill=(10, 26, 34, 255), outline=LED + (140,), width=1)
        draw_text(img, ((bx0 + bx1) // 2, btn_y + 11), label,
                  fill=LED_SOFT + (255,), scale=1, anchor="mm", letter_spacing=2)


def _draw_right_panel(img: Image.Image, xy, state: AppState):
    """Right column: selected-effect parameter list + IN/OUT meters.

    All values shown here are derived from AppState (knob values, level meters).
    `state.in_level` / `state.out_level` are placeholders until the GUI is
    wired to the real ADAU1761 codec — see run_pynq_hdmi() for the integration
    point. Nothing on this panel claims to be a measurement that doesn't exist.
    """
    x0, y0, x1, y1 = xy
    w = x1 - x0
    d = ImageDraw.Draw(img)

    # ===== Selected effect — parameter list =====
    eff_name = EFFECTS[state.selected_effect]
    knobs = EFFECT_KNOBS[eff_name]
    on = state.effect_on[state.selected_effect]

    # Larger SELECTED FX card — dominates the right column. The IN/OUT
    # meters below it shrink (h=42 each) to make room.
    param_h = 288
    rounded_rect(d, (x0, y0, x1, y0 + param_h), 6,
                 outline=LED + (40,), width=1)
    draw_text(img, (x0 + 8, y0 + 8), "SELECTED  FX",
              fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=3)
    draw_text(img, (x1 - 8, y0 + 8), "ON" if on else "BYPASS",
              fill=(LED if on else (170, 90, 70)) + (255,),
              scale=1, anchor="rt", letter_spacing=2)

    draw_text(img, (x0 + 8, y0 + 24), eff_name.upper(),
              fill=LED + (255,), scale=2, glow=LED_DEEP, letter_spacing=1)

    # ===== MODEL selector (Distortion / Amp / Cab only) =====
    # The big effect-name text above renders quite tall at scale=2; the
    # MODEL strip needs real breathing room beneath it so the glow on the
    # bottom of glyphs like "R" / "P" doesn't clip into the strip border.
    model_label = _model_label_for(state)
    rows_y0 = y0 + 86
    if model_label is not None:
        my0 = y0 + 76
        my1 = my0 + 26
        # background strip
        rounded_rect(d, (x0 + 8, my0, x1 - 8, my1), 4,
                     fill=(8, 22, 28, 255), outline=LED + (90,), width=1)
        # prev / next arrow hot-zones (drawn as inset triangles)
        ax_l, ax_r = x0 + 14, x1 - 14
        ay = (my0 + my1) // 2
        d.polygon([(ax_l, ay), (ax_l + 8, ay - 5), (ax_l + 8, ay + 5)],
                  fill=LED + (255,))
        d.polygon([(ax_r, ay), (ax_r - 8, ay - 5), (ax_r - 8, ay + 5)],
                  fill=LED + (255,))
        draw_text(img, ((x0 + x1) // 2, ay - 4), model_label,
                  fill=INK_HI + (255,), scale=1, anchor="mm", letter_spacing=2)
        rows_y0 = my1 + 14

    # parameter rows — value mirrors what the knob below shows
    row_h = 20
    bar_x0 = x0 + 86
    bar_x1 = x1 - 44
    for i, (label, _default) in enumerate(knobs[:6]):
        if not label:
            continue
        ry = rows_y0 + i * row_h
        val = state.knob_values[i] if i < len(state.knob_values) else 0
        sel = (i == state.selected_knob)
        draw_text(img, (x0 + 10, ry + 4), label,
                  fill=(LED if sel else SCR_TEXT_DIM) + (255,),
                  scale=1, letter_spacing=2)
        by0 = ry + 6
        by1 = ry + 14
        rounded_rect(d, (bar_x0, by0, bar_x1, by1), 3,
                     fill=(4, 6, 10, 255), outline=(0, 0, 0, 255), width=1)
        fillw = int((bar_x1 - bar_x0 - 2) * (val / 100.0))
        if fillw > 0:
            g = vertical_gradient(fillw, by1 - by0 - 2,
                                  [(0.0, LED_SOFT), (1.0, LED_DIM)])
            img.paste(g.convert("RGB"), (bar_x0 + 1, by0 + 1))
        draw_text(img, (x1 - 8, ry + 4), f"{int(val):>3}",
                  fill=LED + (255,), scale=1, anchor="rt", letter_spacing=1)

    # ===== INPUT meter (mono — no L/R) =====
    in_y = y0 + param_h + 8
    in_h = 42
    rounded_rect(d, (x0, in_y, x1, in_y + in_h), 6,
                 outline=LED + (28,), width=1)
    draw_text(img, (x0 + 8, in_y + 8), "INPUT",
              fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=3)
    # NOTE: in_level is a placeholder until codec ADC RMS is wired in.
    draw_text(img, (x1 - 8, in_y + 8), f"{int(state.in_level*100):>3}%",
              fill=LED + (255,), scale=1, anchor="rt", letter_spacing=2)
    draw_meter(img, x0 + 12, in_y + 26, w - 24, 14,
               state.in_level, segments=24)

    # ===== OUTPUT meter =====
    out_y = in_y + in_h + 6
    out_h = 42
    rounded_rect(d, (x0, out_y, x1, out_y + out_h), 6,
                 outline=LED + (28,), width=1)
    draw_text(img, (x0 + 8, out_y + 8), "OUTPUT",
              fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=3)
    # NOTE: out_level is a placeholder until codec DAC RMS is wired in.
    draw_text(img, (x1 - 8, out_y + 8), f"{int(state.out_level*100):>3}%",
              fill=LED + (255,), scale=1, anchor="rt", letter_spacing=2)
    draw_meter(img, x0 + 12, out_y + 26, w - 24, 14,
               state.out_level, segments=24)


# =============================================================================
# SIGNAL CHAIN
# =============================================================================
def draw_signal_chain(img: Image.Image, state: AppState, xy):
    x0, y0, x1, y1 = xy
    d = ImageDraw.Draw(img)

    # title (no '6/9 BLOCKS · 2.3MS' subtitle — was a fake DSP figure)
    draw_text(img, (x0, y0), "SIGNAL CHAIN", fill=SCR_TEXT_DIM + (255,),
              scale=1, letter_spacing=3)

    # IO + 8 blocks + IO
    n = len(state.chain)
    rail_y0 = y0 + 18
    rail_y1 = y1 - 4
    rail_h  = rail_y1 - rail_y0

    # geometry: small IN, n blocks, small OUT, with thin wires
    io_w = 26
    wire_w = 8
    avail = (x1 - x0) - io_w * 2 - wire_w * (n + 1)
    blk_w = avail / n
    blk_h = rail_h - 6

    # IN
    _io_marker(img, x0, rail_y0 + (rail_h - 30) // 2, "IN")
    cur_x = x0 + io_w + wire_w

    blocks_xs = []
    for i, eff_idx in enumerate(state.chain):
        bx0 = int(cur_x)
        bx1 = int(cur_x + blk_w)
        by0 = rail_y0
        by1 = rail_y0 + blk_h
        on  = state.effect_on[eff_idx]
        selected = (eff_idx == state.selected_effect)
        _draw_chain_block(img, (bx0, by0, bx1, by1), eff_idx, on, selected, i + 1)
        blocks_xs.append((bx0, bx1, on))
        cur_x = bx1 + wire_w

    # OUT
    _io_marker(img, x1 - io_w, rail_y0 + (rail_h - 30) // 2, "OUT")

    # wires (between IO and blocks, and between blocks)
    wy = rail_y0 + blk_h // 2
    # IN -> first
    _wire(img, x0 + io_w, wy, blocks_xs[0][0], wy, on=True)
    for i in range(len(blocks_xs) - 1):
        on = blocks_xs[i][2] and blocks_xs[i+1][2]
        _wire(img, blocks_xs[i][1], wy, blocks_xs[i+1][0], wy, on=on)
    # last -> OUT
    _wire(img, blocks_xs[-1][1], wy, x1 - io_w, wy,
          on=blocks_xs[-1][2])


def _io_marker(img: Image.Image, x: int, y: int, label: str):
    d = ImageDraw.Draw(img)
    cx, cy = x + 13, y + 15
    rounded_rect(d, (x, y, x + 26, y + 30), 4,
                 outline=LED + (110,), width=1)
    d.ellipse((cx - 6, cy - 6, cx + 6, cy + 6), outline=LED + (200,), width=1)
    d.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=LED + (255,))
    draw_text(img, (cx, y + 36), label, fill=SCR_TEXT_DIM + (255,),
              scale=1, anchor="mt", letter_spacing=2)


def _wire(img: Image.Image, x0, y0, x1, y1, on: bool):
    d = ImageDraw.Draw(img)
    if on:
        # glow trace
        if not _pynq_static_mode():
            trace = Image.new("RGBA", (max(2, int(x1 - x0)) + 12, 18), (0, 0, 0, 0))
            td = ImageDraw.Draw(trace)
            td.rectangle((6, 7, max(7, int(x1 - x0)) + 6, 11), fill=LED + (180,))
            trace = trace.filter(ImageFilter.GaussianBlur(2))
            img.alpha_composite(trace, (int(x0) - 6, int(y0) - 9))
        d.line((x0, y0, x1, y1), fill=LED, width=2)
        # flowing dots
        d.ellipse((x0 - 2, y0 - 2, x0 + 2, y0 + 2), fill=LED_SOFT + (255,))
        d.ellipse((x1 - 2, y1 - 2, x1 + 2, y1 + 2), fill=LED_SOFT + (255,))
    else:
        d.line((x0, y0, x1, y1), fill=(40, 60, 70, 255), width=2)


def _block_icon(img: Image.Image, kind_idx: int, cx: int, cy: int, color):
    """Tiny iconographic glyph drawn with primitives."""
    d = ImageDraw.Draw(img)
    col = color + (255,)
    s = 11  # half-extent
    # Map new 9-effect index to the original 8-icon set:
    # NS, CMP, OD, DIST, RAT, AMP, CAB, EQ, RVB  ->
    # NS, CMP, OD, DIST, DIST, AMP, CAB, EQ, RVB
    kind_idx = (0, 1, 2, 3, 3, 4, 5, 6, 7)[kind_idx] if 0 <= kind_idx < 9 else 0
    if kind_idx == 0:    # Noise Gate — sawtooth into flatline
        pts = [(cx - s, cy + 4), (cx - 5, cy + 4), (cx - 3, cy - 4),
               (cx,     cy + 4), (cx + 4, cy - 6), (cx + 6, cy + 4),
               (cx + s, cy + 4)]
        d.line(pts, fill=col, width=2, joint="curve")
    elif kind_idx == 1:  # Compressor — triangle squashed
        d.polygon([(cx - s, cy + s - 2), (cx, cy - s + 2), (cx + s, cy + s - 2)],
                  outline=col, width=2)
        d.line((cx - s + 2, cy + 4, cx + s - 2, cy + 4), fill=col, width=2)
    elif kind_idx == 2:  # Overdrive — small clipped wave
        for i in range(-s, s + 1, 1):
            y = cy + int(8 * math.sin(i * 0.6))
            y = max(cy - 6, min(cy + 6, y))
            d.point((cx + i, y), fill=col)
            d.point((cx + i, y + 1), fill=col)
    elif kind_idx == 3:  # Distortion — heavily clipped square-ish wave
        steps = [-s, -s + 5, 0, 5, s - 5, s]
        for i, x in enumerate(steps[:-1]):
            x2 = steps[i + 1]
            yt = (-1) ** i * 6
            d.line((cx + x, cy + yt, cx + x2, cy + yt), fill=col, width=2)
            d.line((cx + x2, cy - 6, cx + x2, cy + 6), fill=col, width=2)
    elif kind_idx == 4:  # Amp Sim — speaker box
        d.rectangle((cx - s, cy - s + 2, cx + s, cy + s - 2),
                    outline=col, width=2)
        d.ellipse((cx - 8, cy - 5, cx + 2, cy + 5), outline=col, width=2)
        for k in (3, 6):
            d.line((cx + k + 1, cy - 4, cx + k + 1, cy + 4), fill=col, width=2)
    elif kind_idx == 5:  # Cab Sim — 4-cone grille
        d.rectangle((cx - s, cy - s, cx + s, cy + s), outline=col, width=2)
        for ox in (-5, 5):
            for oy in (-5, 5):
                d.ellipse((cx + ox - 3, cy + oy - 3, cx + ox + 3, cy + oy + 3),
                          outline=col, width=2)
    elif kind_idx == 6:  # EQ — three sliders
        for i, ox in enumerate([-7, 0, 7]):
            d.line((cx + ox, cy - s, cx + ox, cy + s), fill=col, width=1)
            ky = [-2, 4, -6][i]
            d.rectangle((cx + ox - 3, cy + ky - 2, cx + ox + 3, cy + ky + 2),
                        fill=col)
    elif kind_idx == 7:  # Reverb — concentric arcs
        for r, a in [(s, 255), (s - 5, 180), (s - 10, 110)]:
            if r <= 0: continue
            d.arc((cx - r, cy - r // 2, cx + r, cy + r // 2),
                  start=200, end=340, fill=color + (a,), width=2)


def _draw_chain_block(img: Image.Image, xy, eff_idx: int,
                      on: bool, selected: bool, num: int):
    x0, y0, x1, y1 = xy
    d = ImageDraw.Draw(img)

    # body
    if on:
        top = (8, 38, 50)
        bot = (4, 18, 26)
        border = LED + (220,) if selected else LED + (110,)
    else:
        top = (16, 18, 22)
        bot = (8, 10, 14)
        border = (255, 255, 255, 70) if selected else (60, 70, 80, 200)

    grad = vertical_gradient(x1 - x0, y1 - y0, [(0.0, top), (1.0, bot)])
    mask = Image.new("L", (x1 - x0, y1 - y0), 0)
    rounded_rect(ImageDraw.Draw(mask), (0, 0, x1 - x0, y1 - y0), 5, fill=255)
    img.paste(grad, (x0, y0), mask)

    if selected and not _pynq_static_mode():
        # outer cyan glow
        halo = Image.new("RGBA", (x1 - x0 + 24, y1 - y0 + 24), (0, 0, 0, 0))
        rounded_rect(ImageDraw.Draw(halo),
                     (12, 12, x1 - x0 + 12, y1 - y0 + 12), 5,
                     outline=LED + (160,), width=2)
        halo = halo.filter(ImageFilter.GaussianBlur(5))
        img.alpha_composite(halo, (x0 - 12, y0 - 12))

    rounded_rect(d, (x0, y0, x1 - 1, y1 - 1), 5,
                 outline=border, width=2 if selected else 1)
    rounded_rect(d, (x0 + 1, y0 + 1, x1 - 2, y1 - 2), 4,
                 outline=(255, 255, 255, 18), width=1)

    # block index
    draw_text(img, (x0 + 5, y0 + 4), f"{num:02d}",
              fill=SCR_TEXT_DEAD + (255,) if not on else SCR_TEXT_DIM + (255,),
              scale=1, letter_spacing=1)

    # icon
    icon_color = LED if on else (90, 100, 110)
    cx, cy = (x0 + x1) // 2, y0 + 38
    _block_icon(img, eff_idx, cx, cy, icon_color)

    # label
    label = EFFECTS_SHORT[eff_idx]
    draw_text(img, ((x0 + x1) // 2, y1 - 28),
              label,
              fill=LED + (255,) if on else (110, 120, 130, 255),
              scale=2, anchor="mm", letter_spacing=2,
              glow=LED_DIM if on else None)

    # bottom led bar
    bar_w = (x1 - x0) - 18
    bx0 = x0 + 9
    by  = y1 - 11
    if on:
        # bloom
        if not _pynq_static_mode():
            bloom = Image.new("RGBA", (bar_w + 12, 14), (0, 0, 0, 0))
            ImageDraw.Draw(bloom).rectangle((6, 4, bar_w + 6, 8), fill=LED + (210,))
            bloom = bloom.filter(ImageFilter.GaussianBlur(2))
            img.alpha_composite(bloom, (bx0 - 6, by - 4))
        d.rectangle((bx0, by - 1, bx0 + bar_w, by + 2), fill=LED)
    else:
        d.rectangle((bx0, by - 1, bx0 + bar_w, by + 2), fill=(40, 50, 58, 255))


# =============================================================================
# VISUALIZER
# =============================================================================
def draw_visualizer_static(img: Image.Image, xy):
    """Low-cost frozen SIGNAL MONITOR for PYNQ static/change-driven mode."""
    x0, y0, x1, y1 = xy
    d = ImageDraw.Draw(img)

    draw_text(img, (x0, y0), "SIGNAL  MONITOR",
              fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=3)
    draw_text(img, (x1, y0), "STATIC  PREVIEW",
              fill=SCR_TEXT_DEAD + (255,), scale=1, anchor="rt", letter_spacing=2)

    fy0 = y0 + 18
    fy1 = y1 - 4
    rounded_rect(d, (x0, fy0, x1, fy1), 5,
                 outline=LED + (40,), width=1)

    inner_w = x1 - x0 - 4
    inner_h = fy1 - fy0 - 4
    ix0, iy0 = x0 + 2, fy0 + 2

    for gx in range(0, inner_w, 24):
        d.line((ix0 + gx, iy0, ix0 + gx, iy0 + inner_h), fill=SCR_GRID, width=1)
    for gy in range(0, inner_h, 18):
        d.line((ix0, iy0 + gy, ix0 + inner_w, iy0 + gy), fill=SCR_GRID, width=1)

    n = 36
    bar_area_h = int(inner_h * 0.55)
    base_y = iy0 + inner_h
    bw = inner_w / n
    for i in range(n):
        phase = i / float(max(1, n - 1))
        v = 0.10 + 0.62 * math.exp(-phase * 2.1)
        v += 0.14 * (0.5 + 0.5 * math.sin(i * 0.73))
        v = max(0.04, min(1.0, v))
        sx = int(ix0 + i * bw + 2)
        sx2 = int(ix0 + (i + 1) * bw - 2)
        h = int(v * (bar_area_h - 6))
        sy = base_y - h
        sy2 = base_y - 2
        d.rectangle((sx, sy, sx2, sy2), fill=LED_DIM + (210,))
        d.line((sx, sy, sx2, sy), fill=LED_SOFT + (220,), width=1)

    wave_top = iy0
    wave_bot = iy0 + int(inner_h * 0.45)
    mid = (wave_top + wave_bot) // 2
    amp = (wave_bot - wave_top) // 2 - 5
    pts = []
    samples = 96
    for i in range(samples):
        x = ix0 + 2 + int((inner_w - 4) * i / float(samples - 1))
        y = mid + int(amp * (
            math.sin(i * 0.22) * 0.52 +
            math.sin(i * 0.71) * 0.18
        ))
        pts.append((x, y))
    d.line(pts, fill=LED_SOFT, width=1)
    d.line((ix0 + 2, mid, ix0 + inner_w - 2, mid),
           fill=LED + (60,), width=1)


def draw_visualizer(img: Image.Image, state: AppState, xy):
    """Fixed-mode SIGNAL MONITOR: spectrum bars + waveform overlay.

    No mode tabs (no WAVE/SPECTRUM/BOTH selector) — this is a single
    monitor view. The bar/wave data is derived from state.t and the
    chosen effect, not from real audio yet; once the codec stream is
    routed in, replace `bars` / `ys` below with real DSP buffers.
    """
    x0, y0, x1, y1 = xy
    d = ImageDraw.Draw(img)

    # title row (no tabs)
    draw_text(img, (x0, y0), "SIGNAL  MONITOR",
              fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=3)
    draw_text(img, (x1, y0), "PRE / POST  CHAIN",
              fill=SCR_TEXT_DEAD + (255,), scale=1, anchor="rt", letter_spacing=2)

    # frame
    fy0 = y0 + 18
    fy1 = y1 - 4
    rounded_rect(d, (x0, fy0, x1, fy1), 5,
                 outline=LED + (40,), width=1)

    # grid
    inner_w = x1 - x0 - 4
    inner_h = fy1 - fy0 - 4
    ix0, iy0 = x0 + 2, fy0 + 2

    for gx in range(0, inner_w, 24):
        d.line((ix0 + gx, iy0, ix0 + gx, iy0 + inner_h), fill=SCR_GRID, width=1)
    for gy in range(0, inner_h, 18):
        d.line((ix0, iy0 + gy, ix0 + inner_w, iy0 + gy), fill=SCR_GRID, width=1)

    # ---- spectrum bars (bottom 55%) ----
    n = 56
    bar_area_h = int(inner_h * 0.55)
    base_y = iy0 + inner_h
    bw = inner_w / n
    rng = np.arange(n)
    envelope = np.exp(-rng / 28.0)
    wob = (
        0.45 * np.sin(state.t * 1.7 + rng * 0.31)
      + 0.30 * np.sin(state.t * 2.9 + rng * 0.17)
      + 0.20 * np.sin(state.t * 5.3 + rng * 0.07)
    )
    seed = int(state.t * 30) % 9973
    rng_np = _rng(seed)
    noise = rng_np.uniform(-0.15, 0.20, size=n)
    bars = np.clip(envelope * (0.6 + 0.4 * (wob * 0.5 + 0.5)) + noise, 0.04, 1.0)
    emph_idx = int(_lerp(2, n - 4,
                         state.selected_effect / max(1, len(EFFECTS) - 1)))
    for k in range(-2, 3):
        j = emph_idx + k
        if 0 <= j < n:
            bars[j] = min(1.0, bars[j] + 0.35 * (1 - abs(k) * 0.3))

    for i, v in enumerate(bars):
        sx = int(ix0 + i * bw + 1)
        sx2 = int(ix0 + (i + 1) * bw - 1)
        h = int(v * (bar_area_h - 6))
        sy = base_y - h
        sy2 = base_y - 2
        for yy in range(sy, sy2):
            tt = (sy2 - yy) / max(1, sy2 - sy)
            col = _lerp_color(LED_DIM, LED_SOFT, tt * tt)
            d.line((sx, yy, sx2, yy), fill=col, width=1)
        d.line((sx, sy - 2, sx2, sy - 2), fill=LED_SOFT, width=1)

    # ---- waveform overlay (top ~45%) ----
    wave_top = iy0
    wave_bot = iy0 + int(inner_h * 0.45)
    mid = (wave_top + wave_bot) // 2
    amp = (wave_bot - wave_top) // 2 - 4
    xs = np.linspace(0, inner_w - 4, 220)
    t = state.t
    ys = (
        np.sin(xs * 0.06 + t * 4.0) * 0.55
      + np.sin(xs * 0.18 + t * 5.7) * 0.25
      + np.sin(xs * 0.31 + t * 9.3) * 0.12
    )
    rng_np = _rng(int(t * 24) % 9973)
    ys = ys + rng_np.uniform(-0.05, 0.05, size=ys.shape)
    ys = np.clip(ys, -1, 1)
    pts = list(zip((ix0 + 2 + xs).astype(int).tolist(),
                   (mid + ys * amp).astype(int).tolist()))
    glow_layer = Image.new("RGBA", (inner_w + 8, inner_h + 8), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow_layer)
    gd.line([(p[0] - ix0 + 4, p[1] - iy0 + 4) for p in pts],
            fill=LED + (180,), width=3)
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(2))
    img.alpha_composite(glow_layer, (ix0 - 4, iy0 - 4))
    d.line(pts, fill=LED_SOFT, width=1)
    d.line((ix0 + 2, mid, ix0 + inner_w - 2, mid),
           fill=LED + (60,), width=1)


# =============================================================================
# KNOB & KNOB PANEL
# =============================================================================
def _knob_body_layer(radius: int) -> Image.Image:
    """Cached knob chrome shared by all knob values in fast render mode."""
    R = int(radius)
    global _ACTIVE_RENDER_CACHE
    cache = _ACTIVE_RENDER_CACHE
    key = ("knob_body_v2", R)
    if cache is not None:
        cached = cache.knob_body_cache.get(key)
        if cached is not None:
            return cached

    size = R * 3
    cc = size // 2
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    rim = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim)
    rd.ellipse((cc - R - 2, cc - R - 2, cc + R + 2, cc + R + 2),
               fill=(50, 55, 62, 255))
    layer.alpha_composite(rim.filter(ImageFilter.GaussianBlur(0.5)))

    bd = ImageDraw.Draw(layer)
    for i in range(R, 0, -1):
        t = (R - i) / max(1, R)
        base_top = (90, 96, 105)
        base_bot = (10, 12, 16)
        col = _lerp_color(base_bot, base_top, 1.0 - t * 0.85)
        ox = -int(t * 2)
        oy = -int(t * 2)
        bd.ellipse((cc + ox - i, cc + oy - i,
                    cc + ox + i, cc + oy + i), fill=col + (255,))
    bd.ellipse((cc - R, cc - R, cc + R, cc + R),
               outline=(0, 0, 0, 220), width=1)
    bd.ellipse((cc - R + 1, cc - R + 1, cc + R - 1, cc + R - 1),
               outline=(255, 255, 255, 30), width=1)

    cap_r = int(R * 0.62)
    cd = ImageDraw.Draw(layer)
    for i in range(cap_r, 0, -1):
        t = (cap_r - i) / max(1, cap_r)
        col = _lerp_color((6, 8, 12), (60, 66, 74), 1.0 - t * 0.9)
        cd.ellipse((cc - i, cc - i, cc + i, cc + i), fill=col + (255,))

    spec = Image.new("RGBA", (R * 2, R * 2), (0, 0, 0, 0))
    ImageDraw.Draw(spec).ellipse((R // 4, R // 6, R, R // 2),
                                 fill=(255, 255, 255, 28))
    spec = spec.filter(ImageFilter.GaussianBlur(2))
    layer.alpha_composite(spec, (cc - R, cc - R))

    if cache is not None:
        cache.knob_body_cache[key] = layer
    return layer


def draw_knob(img: Image.Image, x: int, y: int, value: float,
              label: str = "", active: bool = True, selected: bool = False,
              radius: int = 36):
    """
    3D-looking encoder knob centred on (x, y). Value 0..100.
    """
    d = ImageDraw.Draw(img)
    R = radius
    norm = max(0.0, min(1.0, value / 100.0))
    start = -135.0
    end   = 135.0
    angle = start + norm * (end - start)

    # outer halo (glow when selected)
    if selected and active and not _pynq_static_mode():
        halo = Image.new("RGBA", (R * 4, R * 4), (0, 0, 0, 0))
        ImageDraw.Draw(halo).ellipse(
            (R - 2, R - 2, 3 * R + 2, 3 * R + 2),
            outline=LED + (180,), width=2)
        halo = halo.filter(ImageFilter.GaussianBlur(4))
        img.alpha_composite(halo, (x - 2 * R, y - 2 * R))

    # tick ring
    ticks = 25
    for i in range(ticks):
        t = i / (ticks - 1)
        a = math.radians(start + t * (end - start))
        r1 = R + 4
        r2 = R + 9
        x1 = x + math.sin(a) * r1
        y1 = y - math.cos(a) * r1
        x2 = x + math.sin(a) * r2
        y2 = y - math.cos(a) * r2
        if t <= norm and active:
            col = LED + (255,) if not selected else LED_SOFT + (255,)
            w = 2
        else:
            col = (255, 255, 255, 38)
            w = 1
        d.line((x1, y1, x2, y2), fill=col, width=w)

    body = _knob_body_layer(R)
    img.alpha_composite(body, (x - body.width // 2, y - body.height // 2))

    # inner cap
    cap_r = int(R * 0.62)

    # value indicator line
    a_rad = math.radians(angle)
    ix = x + math.sin(a_rad) * (cap_r - 4)
    iy = y - math.cos(a_rad) * (cap_r - 4)
    ind_col = LED if active else (90, 100, 110)
    # glow
    if not _pynq_static_mode():
        line_layer = Image.new("RGBA", (R * 2 + 8, R * 2 + 8), (0, 0, 0, 0))
        ld = ImageDraw.Draw(line_layer)
        ld.line((R + 4, R + 4,
                 R + 4 + math.sin(a_rad) * (cap_r - 4),
                 R + 4 - math.cos(a_rad) * (cap_r - 4)),
                fill=ind_col + (255,), width=3)
        line_layer = line_layer.filter(ImageFilter.GaussianBlur(1.6))
        img.alpha_composite(line_layer, (x - R - 4, y - R - 4))
    d.line((x, y, ix, iy), fill=ind_col, width=2)
    d.ellipse((ix - 2, iy - 2, ix + 2, iy + 2), fill=ind_col)

    # centre dot
    d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(0, 0, 0, 255))

    # value readout below
    draw_text(img, (x, y + R + 14), f"{int(round(value)):>3}",
              fill=LED + (255,) if active else SCR_TEXT_DEAD + (255,),
              scale=2, anchor="mm", glow=LED_DEEP if active else None)
    # label above
    draw_text(img, (x, y - R - 16), label,
              fill=INK_HI + (255,) if active else INK_LO + (255,),
              scale=1, anchor="mm", letter_spacing=2)


def draw_knob_panel(img: Image.Image, state: AppState):
    """Panel with 6 knobs for the currently selected effect.

    Footswitch row is intentionally removed (no physical FS on the
    hardware yet) so this panel is enlarged to fill the bottom of
    the chassis.
    """
    # Enlarged: was y0=472..y1=580. Now reaches further down where
    # the old footswitch row used to live.
    x0, y0, x1, y1 = 36, 472, W - 36, 700
    draw_knob_panel_static_chrome(img)
    draw_knob_panel_content(img, state)


def draw_knob_panel_static_chrome(img: Image.Image):
    x0, y0, x1, y1 = 36, 472, W - 36, 700
    panel_with_bevel(img, (x0, y0, x1, y1),
                     fill_top=(40, 44, 52), fill_bot=(16, 18, 24), radius=10)


def draw_knob_panel_content(img: Image.Image, state: AppState):
    x0, y0, x1, y1 = 36, 472, W - 36, 700
    # title strip — small, neutral label (no "EDIT XXX" framing)
    d = ImageDraw.Draw(img)
    eff = EFFECTS[state.selected_effect]
    on = state.effect_on[state.selected_effect]
    # Clickable strip — tap to toggle ON / BYP for this effect.
    rounded_rect(d, (x0 + 14, y0 + 10, x0 + 280, y0 + 30), 4,
                 fill=(10, 26, 34, 255) if on else (16, 14, 12, 255),
                 outline=LED + (140 if on else 70,), width=1)
    draw_led(img, x0 + 24, y0 + 20, on=on, color=LED, size=4)
    draw_text(img, (x0 + 36, y0 + 14),
              eff.upper(),
              fill=LED + (255,) if on else INK_HI + (255,),
              scale=1, letter_spacing=2)
    draw_text(img, (x0 + 272, y0 + 14),
              "ON" if on else "BYP",
              fill=LED + (255,) if on else (220, 110, 90, 255),
              scale=1, anchor="rt", letter_spacing=2)

    # right-side hint removed by spec.

    # 6 knobs — centred across the panel. Empty-label slots are unused
    # for this effect; only the active knobs are laid out, evenly spaced
    # and centred horizontally so the panel never looks left-anchored.
    knobs = state.knobs()
    active_idxs = [i for i, (lbl, _v) in enumerate(knobs) if lbl]
    n_active = len(active_idxs)
    cy = (y0 + y1) // 2 + 16     # vertical centre of the panel body
    if n_active > 0:
        avail_w = (x1 - x0) - 48          # 24px padding each side
        cell_w = avail_w / n_active
        row_x0 = x0 + 24 + cell_w * 0.5
        for slot, i in enumerate(active_idxs):
            label, val = knobs[i]
            cx = int(row_x0 + cell_w * slot)
            draw_knob(img, cx, cy, value=val,
                      label=label,
                      active=on,
                      selected=(i == state.selected_knob),
                      radius=44)


# =============================================================================
# FOOTSWITCH ROW
# =============================================================================
def draw_footswitch(img: Image.Image, x: int, y: int,
                    label: str, on: bool, selected: bool,
                    sub_label: str = ""):
    """One stomp-style switch with halo LED ring + bottom label."""
    d = ImageDraw.Draw(img)
    cx, cy = x, y
    R = 30  # outer

    # LED ring (halo above the stomp cap)
    ring_y = cy - R - 14
    ring_w = 56
    # ring container
    rounded_rect(d, (cx - ring_w // 2, ring_y - 4,
                     cx + ring_w // 2, ring_y + 6), 3,
                 fill=(6, 7, 10, 255), outline=(0, 0, 0, 255), width=1)
    if on:
        bloom = Image.new("RGBA", (ring_w + 30, 30), (0, 0, 0, 0))
        ImageDraw.Draw(bloom).rectangle(
            (15, 7, ring_w + 15, 17), fill=LED + (220,))
        bloom = bloom.filter(ImageFilter.GaussianBlur(4))
        img.alpha_composite(bloom, (cx - ring_w // 2 - 15, ring_y - 9))
        rounded_rect(d, (cx - ring_w // 2 + 2, ring_y - 2,
                         cx + ring_w // 2 - 2, ring_y + 4), 2,
                     fill=LED)
    else:
        rounded_rect(d, (cx - ring_w // 2 + 2, ring_y - 2,
                         cx + ring_w // 2 - 2, ring_y + 4), 2,
                     fill=(28, 32, 38, 255))

    # selected outline
    if selected:
        sel = Image.new("RGBA", (R * 4, R * 4), (0, 0, 0, 0))
        ImageDraw.Draw(sel).ellipse(
            (R, R, 3 * R, 3 * R), outline=LED + (220,), width=2)
        sel = sel.filter(ImageFilter.GaussianBlur(2.6))
        img.alpha_composite(sel, (cx - 2 * R, cy - 2 * R))

    # stomp cap — concentric shaded discs
    cap = Image.new("RGBA", (R * 3, R * 3), (0, 0, 0, 0))
    cd = ImageDraw.Draw(cap)
    cc = R * 3 // 2
    for i in range(R, 0, -1):
        t = (R - i) / max(1, R)
        col = _lerp_color((10, 12, 16), (76, 82, 92), 1.0 - t * 0.95)
        # shifted highlight
        ox = -int(t * 1.2); oy = -int(t * 1.2)
        cd.ellipse((cc + ox - i, cc + oy - i, cc + ox + i, cc + oy + i),
                   fill=col + (255,))
    # rim ring
    cd.ellipse((cc - R, cc - R, cc + R, cc + R),
               outline=(0, 0, 0, 220), width=1)
    cd.ellipse((cc - R + 1, cc - R + 1, cc + R - 1, cc + R - 1),
               outline=(255, 255, 255, 36), width=1)
    # inner cap
    inner_r = int(R * 0.55)
    for i in range(inner_r, 0, -1):
        t = (inner_r - i) / max(1, inner_r)
        col = _lerp_color((4, 5, 8), (45, 50, 58), 1.0 - t * 0.92)
        cd.ellipse((cc - i, cc - i, cc + i, cc + i), fill=col + (255,))
    # specular
    cd.ellipse((cc - R + 5, cc - R + 4, cc + 3, cc - 3),
               fill=(255, 255, 255, 22))
    img.alpha_composite(cap, (cx - R * 3 // 2, cy - R * 3 // 2))

    # cap glyph
    glyph_col = LED_SOFT if on else INK_MID
    draw_text(img, (cx, cy), label[:4].upper(),
              fill=glyph_col + (255,), scale=1, anchor="mm",
              letter_spacing=2,
              glow=LED_DIM if on else None)

    # below: full label
    if sub_label:
        draw_text(img, (cx, cy + R + 16), sub_label,
                  fill=INK_HI + (255,) if on else INK_MID + (255,),
                  scale=1, anchor="mt", letter_spacing=2)


def draw_footswitch_row(img: Image.Image, state: AppState):
    x0, y0, x1, y1 = 36, 596, W - 36, 700
    # base panel
    panel_with_bevel(img, (x0, y0, x1, y1),
                     fill_top=(34, 38, 44), fill_bot=(12, 14, 18), radius=10)

    # 8 switches: 1-4 utility, 5-8 effects-or-presets
    layout = [
        ("BANK\nDOWN", "BANK -",       False, "util"),
        ("BANK\nUP",   "BANK +",       False, "util"),
        ("TAP",        "TAP TEMPO",    True,  "util"),
        ("TUNER",      "TUNER",        False, "util"),
        ("FX1",        "DIST",         state.effect_on[3], "fx"),
        ("FX2",        "AMP",          state.effect_on[5], "fx"),
        ("FX3",        "REV",          state.effect_on[8], "fx"),
        ("SAVE",       "SAVE",         False, "util"),
    ]
    n = len(layout)
    cell_w = (x1 - x0) / n
    for i, (cap_lbl, sub, on, kind) in enumerate(layout):
        cx = int(x0 + cell_w * (i + 0.5))
        cy = y0 + 50
        draw_footswitch(img, cx, cy, cap_lbl, on,
                        selected=(i == state.fs_selected),
                        sub_label=sub)



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


_DEFAULT_RENDER_CACHE = RenderCache()


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
        int(state.selected_knob),
        tuple(int(round(v)) for v in state.knob_values),
        getattr(state, "dist_model_idx", None),
        getattr(state, "amp_model_idx", None),
        getattr(state, "cab_model_idx", None),
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


def render_static_base(width: int, height: int, cache: RenderCache) -> Image.Image:
    """Render/cached chassis background only.

    The returned image must be copied by callers before compositing dynamic
    layers over it.
    """
    key = (int(width), int(height), "static_base_v2",
           bool(getattr(cache, "pynq_static_mode", False)))
    if key in cache.static_layers:
        cache.stats["static_hits"] += 1
        return cache.static_layers[key]
    global _ACTIVE_RENDER_CACHE
    prev = _ACTIVE_RENDER_CACHE
    _ACTIVE_RENDER_CACHE = cache
    try:
        base = Image.new("RGBA", (W, H), (0, 0, 0, 255))
        draw_background(base, AppState())
        draw_main_display_static_chrome(
            base,
            include_static_monitor=bool(getattr(cache, "pynq_static_mode", False)))
        draw_knob_panel_static_chrome(base)
        if (width, height) != (W, H):
            base = base.resize((width, height), Image.BILINEAR)
        cache.static_layers[key] = base
        cache.stats["static_misses"] += 1
        return base
    finally:
        _ACTIVE_RENDER_CACHE = prev


def render_semistatic_layer(state: AppState, width: int, height: int,
                            cache: RenderCache) -> Image.Image:
    """Render/cached non-background GUI layer.

    In this first optimization pass the meter/monitor drawings still live
    inside this layer, but the layer key uses quantized dynamic buckets so it is
    not regenerated every display tick. This keeps visual output identical while
    avoiding a large refactor risk.
    """
    key = (int(width), int(height), state_semistatic_signature(state),
           state_dynamic_signature(state, cache))
    if key in cache.semi_static_layers:
        cache.stats["semistatic_hits"] += 1
        return cache.semi_static_layers[key]

    global _ACTIVE_RENDER_CACHE
    prev = _ACTIVE_RENDER_CACHE
    _ACTIVE_RENDER_CACHE = cache
    try:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        draw_main_display_content(layer, state)
        draw_knob_panel_content(layer, state)
        if state.save_flash > 0:
            flash = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            d = ImageDraw.Draw(flash)
            rounded_rect(d, (W // 2 - 140, 100, W // 2 + 140, 138), 6,
                         fill=LED + (235,), outline=(255, 255, 255, 255), width=1)
            draw_text(flash, (W // 2, 119),
                      "*  PRESET  SAVED",
                      fill=(8, 18, 22, 255), scale=2, anchor="mm",
                      letter_spacing=2)
            layer.alpha_composite(flash)
        if (width, height) != (W, H):
            layer = layer.resize((width, height), Image.BILINEAR)
        cache.semi_static_layers[key] = layer
        cache.stats["semistatic_misses"] += 1
        # Coarse counters for bench diagnostics.
        if not getattr(cache, "pynq_static_mode", False):
            cache.stats["visualizer_updates"] += 1
        cache.stats["meter_updates"] += 1
        # Prevent unbounded memory growth; keep latest few UI states.
        if len(cache.semi_static_layers) > cache.max_frame_entries:
            first = next(iter(cache.semi_static_layers))
            cache.semi_static_layers.pop(first, None)
        return layer
    finally:
        _ACTIVE_RENDER_CACHE = prev


def render_dynamic_layer(state: AppState, width: int, height: int,
                         cache: RenderCache) -> Image.Image:
    """Compatibility hook for future split dynamic rendering.

    The current safe optimization merges dynamic content into the throttled
    semistatic layer above. This hook stays available so the public structure is
    ready for a second pass without breaking call sites.
    """
    return Image.new("RGBA", (int(width), int(height)), (0, 0, 0, 0))


def render_frame_fast(state: AppState, width: int = 1280, height: int = 720,
                      cache: Optional[RenderCache] = None) -> np.ndarray:
    """Fast render path preserving the public ndarray contract."""
    if cache is None:
        cache = _DEFAULT_RENDER_CACHE
    key = (int(width), int(height), state_semistatic_signature(state),
           state_dynamic_signature(state, cache))
    cached = cache.frame_cache.get(key)
    if cached is not None:
        cache.stats["frame_hits"] += 1
        return cached

    base = render_static_base(width, height, cache).copy()
    ui = render_semistatic_layer(state, width, height, cache)
    base.alpha_composite(ui)
    arr = np.asarray(base.convert("RGB"), dtype=np.uint8)
    cache.put_frame(key, arr)
    cache.stats["frame_misses"] += 1
    return arr


def render_frame_pynq_static(state: AppState, width: int = 1280,
                             height: int = 720,
                             cache: Optional[RenderCache] = None) -> np.ndarray:
    """Render using the PYNQ static/change-driven profile."""
    if cache is None:
        cache = make_pynq_static_render_cache()
    elif not getattr(cache, "pynq_static_mode", False):
        cache.pynq_static_mode = True
        cache.visualizer_fps = 0.0
        cache.meter_fps = 0.0
    return render_frame_fast(state, width=width, height=height, cache=cache)


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

        selected = EFFECTS[state.selected_effect]
        selected_on = bool(state.effect_on[state.selected_effect])
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


def render_frame_legacy(state: AppState, width: int = 1280,
                        height: int = 720) -> np.ndarray:
    """Original full-redraw path retained for benchmarking/debugging."""
    full = _render_full(state)
    if (width, height) != (W, H):
        full = full.resize((width, height), Image.LANCZOS)
    return np.array(full.convert("RGB"), dtype=np.uint8)

# =============================================================================
# RENDER
# =============================================================================
def _render_full(state: AppState) -> Image.Image:
    """Internal: render the full 1280x720 RGBA composite."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))

    # 1. chassis & background
    draw_background(img, state)

    # 2. top status bar — removed by spec (was "FPGA GUITAR EFFECTOR" wordmark).

    # 3. main display: preset + chain + visualizer + side
    draw_main_display(img, state)

    # 4. parameter knob panel (now fills bottom — footswitch row removed)
    draw_knob_panel(img, state)

    # 5. footswitch row — intentionally NOT drawn.
    #    Hardware has no physical footswitches yet; drawing them would
    #    imply functionality that doesn't exist. The function is kept
    #    in this file for API compatibility but is never called from the
    #    main render path. To re-enable, add: draw_footswitch_row(img, state)

    # 6. transient SAVE flash
    if state.save_flash > 0:
        flash = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(flash)
        rounded_rect(d, (W // 2 - 140, 100, W // 2 + 140, 138), 6,
                     fill=LED + (235,), outline=(255, 255, 255, 255), width=1)
        draw_text(flash, (W // 2, 119),
                  "*  PRESET  SAVED",
                  fill=(8, 18, 22, 255), scale=2, anchor="mm",
                  letter_spacing=2)
        img.alpha_composite(flash)
    return img


def render_frame(state: AppState, width: int = 1280,
                 height: int = 720) -> np.ndarray:
    """
    Render one GUI frame as an RGB ndarray of shape (height, width, 3) uint8.
    Default 1280x720 stays bit-for-bit compatible with the PYNQ HDMI path.
    Uses RenderCache internally; call render_frame_legacy() for the old full-redraw path.
    """
    return render_frame_fast(state, width=width, height=height,
                             cache=_DEFAULT_RENDER_CACHE)


def render_frame_800x480(state: AppState, width: int = 800,
                         height: int = 480,
                         cache: Optional[RenderCache] = None) -> np.ndarray:
    """Convenience wrapper for the 800x480 5-inch logical layout."""
    return _render_frame_800x480_logical(
        state, width=width, height=height, cache=cache)


# =============================================================================
# DEMO MAIN — generates a few preview PNGs that show state changes.
# =============================================================================
def _demo_states() -> List[AppState]:
    """Return a small sequence of AppStates that exercise the GUI."""
    states = []

    s0 = AppState()                                    # initial preset (Basic Clean)
    states.append(s0)

    s1 = AppState(t=0.45, selected_effect=4,           # select Amp Sim
                  selected_knob=0, in_level=0.74,
                  out_level=0.81, cpu=46,
                  preset_id="04B",
                  preset_name="TS LEAD")
    s1.effect_on = [True, True, False, True, True, True, True, True]
    s1.knob_values = [k[1] for k in EFFECT_KNOBS["Amp Sim"]]
    states.append(s1)

    s2 = AppState(t=1.10, preset_id="07B", preset_name="AMBIENT  CLEAN",
                  selected_effect=7, selected_knob=2,
                  fs_selected=3, in_level=0.42, out_level=0.55, cpu=36,
                  display_mode="wave")
    s2.effect_on = [False, True, False, False, True, True, True, True]
    s2.knob_values = [k[1] for k in EFFECT_KNOBS["Reverb"]]
    states.append(s2)

    s3 = AppState(t=1.85, preset_id="11C", preset_name="METAL  TIGHT",
                  selected_effect=3, selected_knob=0, fs_selected=0,
                  in_level=0.85, out_level=0.92, cpu=58,
                  display_mode="spectrum")
    s3.effect_on = [True, True, False, True, True, True, True, False]
    s3.knob_values = [k[1] for k in EFFECT_KNOBS["Distortion"]]
    states.append(s3)

    s4 = AppState(t=2.55, preset_id="02C", preset_name="BIG MUFF SUSTAIN",
                  selected_effect=3, selected_knob=0,
                  fs_selected=3, save_flash=1.0,
                  in_level=0.62, out_level=0.71, cpu=42)
    s4.effect_on = [True, True, False, True, True, True, True, True]
    states.append(s4)

    return states

def main(out_dir: str = ".", try_cli: bool = False):
    states = _demo_states()
    for i, st in enumerate(states):
        arr = render_frame(st)
        path = os.path.join(out_dir, f"preview_{i:03d}.png")
        Image.fromarray(arr).save(path)
        print(f"[render] wrote {path}  shape={arr.shape}  dtype={arr.dtype}")
    # main preview alias
    Image.fromarray(render_frame(states[0])).save(os.path.join(out_dir, "preview.png"))
    print(f"[render] wrote {os.path.join(out_dir, 'preview.png')}")

    if try_cli:
        _cli_loop()


# =============================================================================
# OPTIONAL CLI LOOP — terminal-driven state mutations + PNG snapshots.
# =============================================================================
def _cli_loop():
    """
    Simple interactive loop. Each command emits a fresh frame_NNN.png.
    Commands:
      h / l  : prev / next effect block
      j / k  : current knob -- / ++
      , / .  : prev / next knob
      space  : toggle current effect ON/OFF
      m      : cycle visualizer mode
      s      : trigger preset SAVE flash
      q      : quit
    """
    state = AppState()
    frame_idx = 0
    print("CLI mode — type a command then ENTER. 'q' to quit.")
    while True:
        cmd = input("> ").strip().lower()
        if cmd == "q":
            break
        elif cmd == "h":
            state.selected_effect = (state.selected_effect - 1) % len(EFFECTS)
            state.knob_values = [k[1] for k in EFFECT_KNOBS[EFFECTS[state.selected_effect]]]
        elif cmd == "l":
            state.selected_effect = (state.selected_effect + 1) % len(EFFECTS)
            state.knob_values = [k[1] for k in EFFECT_KNOBS[EFFECTS[state.selected_effect]]]
        elif cmd == "j":
            state.knob_values[state.selected_knob] = max(
                0, state.knob_values[state.selected_knob] - 5)
        elif cmd == "k":
            state.knob_values[state.selected_knob] = min(
                100, state.knob_values[state.selected_knob] + 5)
        elif cmd == ",":
            state.selected_knob = (state.selected_knob - 1) % 6
        elif cmd == ".":
            state.selected_knob = (state.selected_knob + 1) % 6
        elif cmd == " " or cmd == "space":
            state.effect_on[state.selected_effect] = not state.effect_on[state.selected_effect]
        elif cmd == "m":
            order = ["both", "wave", "spectrum"]
            state.display_mode = order[(order.index(state.display_mode) + 1) % 3]
        elif cmd == "s":
            state.save_flash = 1.0
        else:
            print("?")
            continue
        state.t += 0.12
        path = f"frame_{frame_idx:03d}.png"
        Image.fromarray(render_frame(state)).save(path)
        print(f"  -> {path}")
        frame_idx += 1


# =============================================================================
# JSON STATE PERSISTENCE
# =============================================================================
STATE_FILE = "fx_gui_state.json"

_STATE_KEYS = ("preset_id", "preset_name", "preset_idx",
               "selected_effect", "selected_knob",
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
        if len(state.knob_values) != 6:
            state.knob_values = [k[1] for k in
                                 EFFECT_KNOBS[EFFECTS[state.selected_effect]]]
        if len(state.chain) != len(EFFECTS):
            state.chain = list(range(len(EFFECTS)))
        state.selected_effect = max(0, min(len(EFFECTS) - 1,
                                           state.selected_effect))
        state.selected_knob = max(0, min(5, state.selected_knob))
    except Exception as exc:
        print(f"[state] load failed ({exc}); using defaults")
        state = AppState()
    return state


# =============================================================================
# HIT TESTING — coordinates are in 1280x720 logical space.
# The Tk app maps mouse events back to logical space before calling these.
# =============================================================================

def _knob_centers(state: AppState = None):
    """Centres of the visible knobs in draw_knob_panel. Returns a list of
    length 6, with None for unused (empty-label) slots so caller indexing
    by knob index still works."""
    x0, y0, x1, y1 = 36, 472, W - 36, 700
    cy = (y0 + y1) // 2 + 16
    if state is None:
        # legacy fallback: assume all 6 slots active, evenly spaced
        avail_w = (x1 - x0) - 48
        cell_w = avail_w / 6.0
        row_x0 = x0 + 24 + cell_w * 0.5
        return [(int(row_x0 + cell_w * i), cy) for i in range(6)]
    eff_name = EFFECTS[state.selected_effect]
    labels = [lbl for lbl, _ in EFFECT_KNOBS[eff_name]]
    active_idxs = [i for i, lbl in enumerate(labels) if lbl]
    n_active = len(active_idxs)
    out = [None] * 6
    if n_active == 0:
        return out
    avail_w = (x1 - x0) - 48
    cell_w = avail_w / n_active
    row_x0 = x0 + 24 + cell_w * 0.5
    for slot, i in enumerate(active_idxs):
        out[i] = (int(row_x0 + cell_w * slot), cy)
    return out


def _footswitch_centers():
    # mirrors draw_footswitch_row: x0=36, y0=596, x1=W-36, y1=700, 8 switches
    x0, y0, x1, y1 = 36, 596, W - 36, 700
    cell_w = (x1 - x0) / 8.0
    cy = y0 + 50
    return [(int(x0 + (i + 0.5) * cell_w), cy) for i in range(8)]


def _chain_block_rects(state: AppState):
    """Return [(x0, y0, x1, y1, eff_idx), ...] for the 8 signal-chain blocks."""
    # main display now: 36,32..W-36,458 ; inset +12
    sx0, sy0, sx1, sy1 = 48, 44, W - 36 - 12, 458 - 12
    sep1 = sx0 + 268
    sep2 = sx1 - 280
    cx0 = sep1 + 14
    cx1 = sep2 - 14
    cy0 = sy0 + 10 + 18           # rail_y0
    cy1 = sy0 + 162 - 4           # rail_y1
    rail_h = cy1 - cy0
    blk_h = rail_h - 6
    n = len(state.chain)
    io_w, wire_w = 26, 8
    avail = (cx1 - cx0) - io_w * 2 - wire_w * (n + 1)
    blk_w = avail / n
    cur_x = cx0 + io_w + wire_w
    rects = []
    for i, eff_idx in enumerate(state.chain):
        bx0 = int(cur_x)
        bx1 = int(cur_x + blk_w)
        rects.append((bx0, cy0, bx1, cy0 + blk_h, eff_idx))
        cur_x = bx1 + wire_w
    return rects


def _preset_card_rect():
    """Inner box used by _draw_preset_card. (sx0+12, sy0+10, sep1-12, sy1-10)
    Computed from the main display layout: x0=36,y0=32,x1=W-36,y1=458 ;
    inset +12 ; sep1 = sx0+268."""
    sx0, sy0, sx1, sy1 = 48, 44, W - 36 - 12, 458 - 12
    sep1 = sx0 + 268
    return (sx0 + 12, sy0 + 10, sep1 - 12, sy1 - 10)


def _preset_save_rect():
    x0, y0, x1, y1 = _preset_card_rect()
    return (x0, y1 - 56, x1, y1 - 32)


def _preset_back_rect():
    x0, y0, x1, y1 = _preset_card_rect()
    btn_w = (x1 - x0 - 8) // 2
    return (x0, y1 - 26, x0 + btn_w, y1 - 4)


def _preset_next_rect():
    x0, y0, x1, y1 = _preset_card_rect()
    btn_w = (x1 - x0 - 8) // 2
    return (x0 + btn_w + 8, y1 - 26, x1, y1 - 4)


def _right_panel_rect():
    """Inner box used by _draw_right_panel. (sep2+14, sy0+10, sx1-12, sy1-10)."""
    sx0, sy0, sx1, sy1 = 48, 44, W - 36 - 12, 458 - 12
    sep2 = sx1 - 280
    return (sep2 + 14, sy0 + 10, sx1 - 12, sy1 - 10)


def _model_list_for(state: AppState):
    """Returns (names_list, current_idx, attr_name) for the currently selected
    effect, or None if it has no model choice."""
    eff_name = EFFECTS[state.selected_effect]
    if eff_name == "Distortion":
        return (DIST_MODELS, state.dist_model_idx, "dist_model_idx")
    if eff_name == "Amp Sim":
        return ([n for n, _ in AMP_MODELS], state.amp_model_idx, "amp_model_idx")
    if eff_name == "Cab IR":
        return (CAB_MODELS, state.cab_model_idx, "cab_model_idx")
    return None


def _model_label_for(state: AppState):
    info = _model_list_for(state)
    if info is None:
        return None
    names, idx, _ = info
    return names[idx % len(names)]


def _cycle_model(state: AppState, delta: int) -> bool:
    info = _model_list_for(state)
    if info is None:
        return False
    names, idx, attr = info
    setattr(state, attr, (idx + delta) % len(names))
    return True


def _cycle_preset(state: AppState, delta: int):
    idx = (state.preset_idx + delta) % len(CHAIN_PRESETS)
    state.preset_idx = idx
    state.preset_id = f"{idx + 1:02d}A"
    state.preset_name = CHAIN_PRESETS[idx].upper()


def _model_arrow_rects():
    """Hit rects for the MODEL prev/next arrows in the right panel.
    Mirrors the my0/my1 used in _draw_right_panel."""
    rx0, ry0, rx1, ry1 = _right_panel_rect()
    my0 = ry0 + 76
    my1 = my0 + 26
    # left half / right half of the model strip
    mid = (rx0 + 8 + rx1 - 8) // 2
    prev_rect = (rx0 + 8, my0, mid, my1)
    next_rect = (mid, my0, rx1 - 8, my1)
    return prev_rect, next_rect


def _knob_title_rect():
    """Hit rect for the clickable effect-name title above the knob panel."""
    # Mirrors the title strip drawn in draw_knob_panel: x0=36+14, y0=472+10
    return (36 + 14, 472 + 6, 36 + 360, 472 + 34)


def hit_test(state: AppState, lx: int, ly: int):
    """
    Translate a click in logical (1280x720) space into a (kind, index) tuple:
      ('title', 0)        effect-name strip above knob panel — toggles ON/OFF
      ('preset_back', 0)  < BACK button in preset card
      ('preset_next', 0)  NEXT > button in preset card
      ('preset_save', 0)  SAVE PRESET button in preset card
      ('model_prev', 0)   left arrow in MODEL strip (right panel)
      ('model_next', 0)   right arrow in MODEL strip (right panel)
      ('knob', i)         0..5
      ('chain', i)        chain position index (use state.chain[i] for eff_idx)
      None
    """
    # title strip (click to toggle current effect on/off)
    tx0, ty0, tx1, ty1 = _knob_title_rect()
    if tx0 <= lx <= tx1 and ty0 <= ly <= ty1:
        return ("title", 0)
    # preset SAVE / BACK / NEXT
    for kind, rect in (("preset_save", _preset_save_rect()),
                       ("preset_back", _preset_back_rect()),
                       ("preset_next", _preset_next_rect())):
        rx0, ry0, rx1, ry1 = rect
        if rx0 <= lx <= rx1 and ry0 <= ly <= ry1:
            return (kind, 0)
    # MODEL prev/next — only active for distortion/amp/cab
    if _model_label_for(state) is not None:
        prev_r, next_r = _model_arrow_rects()
        for kind, rect in (("model_prev", prev_r), ("model_next", next_r)):
            rx0, ry0, rx1, ry1 = rect
            if rx0 <= lx <= rx1 and ry0 <= ly <= ry1:
                return (kind, 0)
    # knobs — generous hit area (radius ~80 logical px, well past visual rim)
    for i, c in enumerate(_knob_centers(state)):
        if c is None:
            continue
        cx, cy = c
        if (lx - cx) ** 2 + (ly - cy) ** 2 <= 80 ** 2:
            return ("knob", i)
    # chain blocks
    for i, (bx0, by0, bx1, by1, _eff) in enumerate(_chain_block_rects(state)):
        if bx0 <= lx <= bx1 and by0 <= ly <= by1:
            return ("chain", i)
    return None


# =============================================================================
# WINDOWS MULTI-MONITOR ENUMERATION (best-effort, fallback to primary)
# =============================================================================
def get_monitor_rects():
    """Return list of (left, top, right, bottom). Falls back to a single
    primary rect if EnumDisplayMonitors is unavailable (non-Windows or err)."""
    try:
        import ctypes
        from ctypes import wintypes
        rects = []

        class RECT(ctypes.Structure):
            _fields_ = [('left', wintypes.LONG), ('top', wintypes.LONG),
                        ('right', wintypes.LONG), ('bottom', wintypes.LONG)]

        MonitorEnumProc = ctypes.WINFUNCTYPE(
            wintypes.BOOL, wintypes.HMONITOR, wintypes.HDC,
            ctypes.POINTER(RECT), wintypes.LPARAM)

        def cb(hMon, hdc, lprc, data):
            r = lprc.contents
            rects.append((r.left, r.top, r.right, r.bottom))
            return True

        ctypes.windll.user32.EnumDisplayMonitors(0, 0, MonitorEnumProc(cb), 0)
        if rects:
            return sorted(rects)
        sw = ctypes.windll.user32.GetSystemMetrics(0)
        sh = ctypes.windll.user32.GetSystemMetrics(1)
        return [(0, 0, sw, sh)]
    except Exception:
        # non-Windows or anything weird — Tk will tell us screen size later
        return None


# =============================================================================
# TKINTER APP — interactive preview window for Windows / desktop confirmation
# =============================================================================
class TkApp:
    """
    Tk-based interactive viewer. Uses render_frame() (PIL/NumPy) for the
    full hi-fi look; Tk only handles window, mouse and keyboard.
    """
    KEY_REPEAT_INFO = (
        "Keys: Left/Right=block  Up/Down=knob value  Tab/Shift+Tab=knob"
        "  Space=on/off  M=viz mode  S=save flash  F=fullscreen  Esc/Q=quit"
    )

    def __init__(self, width=800, height=480, fullscreen=False, monitor=0,
                 fps=20):
        # late import so the module stays importable on PYNQ without a display
        import tkinter as tk
        from PIL import ImageTk
        self._tk = tk
        self._ImageTk = ImageTk

        self.width = width
        self.height = height
        self.fullscreen = fullscreen
        self.monitor = monitor
        self.fps = max(5, min(60, fps))
        self.frame_interval_ms = int(1000 / self.fps)

        self.state = load_state_json()
        self._dirty = True
        self._last_save_t = time.time()

        self._drag_kind = None        # 'knob' / 'pedal'
        self._drag_idx = 0
        self._drag_start = (0, 0)
        self._drag_base_value = 0.0

        self.root = tk.Tk()
        self.root.title("DOY FX CORE — Preview")
        self.root.configure(bg="black")
        self.root.protocol("WM_DELETE_WINDOW", self._on_close)

        # Place + chrome
        if fullscreen:
            self._apply_fullscreen(monitor)
        else:
            self.root.geometry(f"{self.width}x{self.height}")

        self.canvas = tk.Canvas(self.root, width=self.width,
                                height=self.height, bg="black",
                                highlightthickness=0, bd=0)
        self.canvas.pack(fill="both", expand=True)
        self._photo = None
        self._img_id = self.canvas.create_image(0, 0, anchor="nw")

        # Bindings
        self.canvas.bind("<ButtonPress-1>", self._on_press)
        self.canvas.bind("<B1-Motion>",     self._on_drag)
        self.canvas.bind("<ButtonRelease-1>", self._on_release)
        self.root.bind("<Configure>", self._on_configure)
        for seq, fn in [
            ("<Left>",     lambda e: self._step_effect(-1)),
            ("<Right>",    lambda e: self._step_effect(+1)),
            ("<Up>",       lambda e: self._step_knob_value(+5)),
            ("<Down>",     lambda e: self._step_knob_value(-5)),
            ("<Tab>",      lambda e: self._step_knob(+1)),
            ("<Shift-Tab>", lambda e: self._step_knob(-1)),
            ("<space>",    lambda e: self._toggle_selected()),
            ("<m>",        lambda e: self._cycle_viz()),
            ("<M>",        lambda e: self._cycle_viz()),
            ("<s>",        lambda e: self._flash_save()),
            ("<S>",        lambda e: self._flash_save()),
            ("<f>",        lambda e: self._toggle_fullscreen()),
            ("<F>",        lambda e: self._toggle_fullscreen()),
            ("<Escape>",   lambda e: self._on_close()),
            ("<q>",        lambda e: self._on_close()),
            ("<Q>",        lambda e: self._on_close()),
        ]:
            self.root.bind(seq, fn)

        print(self.KEY_REPEAT_INFO)
        self._tick_start = time.time()
        self.root.after(0, self._tick)

    # ---- monitor / fullscreen ----
    def _apply_fullscreen(self, monitor_idx: int):
        rects = get_monitor_rects()
        if rects is None or not (0 <= monitor_idx < len(rects)):
            if rects is not None:
                print(f"[monitor] index {monitor_idx} out of range; "
                      f"available 0..{len(rects)-1}. Using 0.")
            self.root.attributes("-fullscreen", True)
            self.root.update_idletasks()
            self.width = self.root.winfo_screenwidth()
            self.height = self.root.winfo_screenheight()
            return
        l, t, r, b = rects[monitor_idx]
        w, h = r - l, b - t
        self.width, self.height = w, h
        self.root.attributes("-fullscreen", False)
        self.root.overrideredirect(False)
        self.root.geometry(f"{w}x{h}+{l}+{t}")
        self.root.update_idletasks()
        self.root.attributes("-fullscreen", True)
        self.root.overrideredirect(True)

    def _toggle_fullscreen(self):
        self.fullscreen = not self.fullscreen
        if self.fullscreen:
            self._apply_fullscreen(self.monitor)
        else:
            self.root.overrideredirect(False)
            self.root.attributes("-fullscreen", False)
            self.width, self.height = 800, 480
            self.root.geometry(f"{self.width}x{self.height}")
        self._dirty = True

    # ---- coordinate mapping (canvas px -> logical 1280x720) ----
    def _to_logical(self, x, y):
        cw = max(1, self.canvas.winfo_width())
        ch = max(1, self.canvas.winfo_height())
        lx = int(x * (W / cw))
        ly = int(y * (H / ch))
        return max(0, min(W - 1, lx)), max(0, min(H - 1, ly))

    # ---- input handlers ----
    def _on_press(self, e):
        lx, ly = self._to_logical(e.x, e.y)
        hit = hit_test(self.state, lx, ly)
        if hit is None:
            return
        kind, idx = hit
        if kind == "title":
            # toggle ON/OFF for the currently selected effect
            i = self.state.selected_effect
            self.state.effect_on[i] = not self.state.effect_on[i]
            self._dirty = True
            return
        if kind == "preset_save":
            self._flash_save()
            return
        if kind == "preset_back":
            _cycle_preset(self.state, -1)
            self._dirty = True
            return
        if kind == "preset_next":
            _cycle_preset(self.state, +1)
            self._dirty = True
            return
        if kind == "model_prev":
            _cycle_model(self.state, -1)
            self._dirty = True
            return
        if kind == "model_next":
            _cycle_model(self.state, +1)
            self._dirty = True
            return
        if kind == "knob":
            self.state.selected_knob = idx
            self._drag_kind = "knob"
            self._drag_idx = idx
            self._drag_start = (e.x, e.y)
            self._drag_base_value = self.state.knob_values[idx]
        elif kind == "chain":
            # idx = position in chain; selected_effect should be the EFF idx
            self.state.selected_effect = self.state.chain[idx]
            # refresh knob values for that effect
            eff_name = EFFECTS[self.state.selected_effect]
            self.state.knob_values = [k[1] for k in EFFECT_KNOBS[eff_name]]
            self._drag_kind = "pedal"
            self._drag_idx = idx
            self._drag_start = (e.x, e.y)
        self._dirty = True

    def _on_drag(self, e):
        if self._drag_kind == "knob":
            # vertical drag: up = +, down = -
            dy = self._drag_start[1] - e.y
            new_val = max(0.0, min(100.0, self._drag_base_value + dy * 1.6))
            self.state.knob_values[self._drag_idx] = new_val
            self._dirty = True
        elif self._drag_kind == "pedal":
            # horizontal drag = move position in chain
            lx0, _ = self._to_logical(*self._drag_start)
            lx, _ = self._to_logical(e.x, e.y)
            # determine target chain index
            rects = _chain_block_rects(self.state)
            new_idx = self._drag_idx
            for j, (bx0, _, bx1, _, _) in enumerate(rects):
                if bx0 <= lx <= bx1:
                    new_idx = j
                    break
            if new_idx != self._drag_idx:
                ch = self.state.chain
                eff = ch.pop(self._drag_idx)
                ch.insert(new_idx, eff)
                self._drag_idx = new_idx
                self._dirty = True

    def _on_release(self, _e):
        self._drag_kind = None

    def _on_configure(self, e):
        if e.widget is self.root:
            self.width = max(2, e.width)
            self.height = max(2, e.height)
            self._dirty = True

    # ---- key actions ----
    def _step_effect(self, d):
        n = len(EFFECTS)
        self.state.selected_effect = (self.state.selected_effect + d) % n
        eff = EFFECTS[self.state.selected_effect]
        self.state.knob_values = [k[1] for k in EFFECT_KNOBS[eff]]
        self._dirty = True

    def _step_knob(self, d):
        self.state.selected_knob = (self.state.selected_knob + d) % 6
        self._dirty = True

    def _step_knob_value(self, d):
        v = self.state.knob_values[self.state.selected_knob] + d
        self.state.knob_values[self.state.selected_knob] = max(0.0, min(100.0, v))
        self._dirty = True

    def _toggle_selected(self):
        se = self.state.selected_effect
        self.state.effect_on[se] = not self.state.effect_on[se]
        self._dirty = True

    def _cycle_viz(self):
        order = ["both", "wave", "spectrum"]
        self.state.display_mode = order[
            (order.index(self.state.display_mode) + 1) % 3]
        self._dirty = True

    def _flash_save(self):
        self.state.save_flash = 1.0
        save_state_json(self.state)
        self._dirty = True

    def _on_close(self):
        save_state_json(self.state)
        try:
            self.root.destroy()
        except Exception:
            pass

    # ---- main loop ----
    def _tick(self):
        # animate
        self.state.t += self.frame_interval_ms / 1000.0
        # subtle level meter motion
        self.state.in_level = 0.55 + 0.18 * math.sin(self.state.t * 1.3)
        self.state.out_level = 0.62 + 0.16 * math.sin(self.state.t * 1.5 + 0.7)
        if self.state.save_flash > 0:
            self.state.save_flash = max(0.0, self.state.save_flash - 0.04)

        arr = render_frame(self.state, width=self.width, height=self.height)
        pil = Image.fromarray(arr)
        photo = self._ImageTk.PhotoImage(pil)
        self.canvas.itemconfig(self._img_id, image=photo)
        self._photo = photo  # keep ref

        # auto-save every 5 s
        now = time.time()
        if now - self._last_save_t > 5.0:
            save_state_json(self.state)
            self._last_save_t = now

        self.root.after(self.frame_interval_ms, self._tick)

    def run(self):
        self.root.mainloop()


def run_windows_window(width=800, height=480, fullscreen=False, monitor=0):
    app = TkApp(width=width, height=height, fullscreen=fullscreen,
                monitor=monitor)
    app.run()


def run_windows_fullscreen(monitor=0):
    app = TkApp(fullscreen=True, monitor=monitor)
    app.run()


def save_previews(out_dir: str = "."):
    main(out_dir=out_dir, try_cli=False)


# =============================================================================
# BENCHMARK
# =============================================================================
def run_bench(n: int = 30):
    state = AppState()

    # Legacy full redraw baseline.
    t0 = time.perf_counter()
    for i in range(n):
        state.t = i / 30.0
        render_frame_legacy(state)
    legacy_dt = time.perf_counter() - t0
    legacy_ms = (legacy_dt / n) * 1000

    # Fast cached path. Use a fresh cache so diagnostics are meaningful.
    cache = RenderCache(visualizer_fps=5.0, meter_fps=10.0)
    state = AppState()
    cold_t0 = time.perf_counter()
    render_frame_fast(state, cache=cache)
    cold_ms = (time.perf_counter() - cold_t0) * 1000

    t0 = time.perf_counter()
    for i in range(n):
        state.t = i / 30.0
        state.in_level = 0.55 + 0.18 * math.sin(state.t * 1.3)
        state.out_level = 0.62 + 0.16 * math.sin(state.t * 1.5 + 0.7)
        render_frame_fast(state, cache=cache)
    fast_dt = time.perf_counter() - t0
    fast_ms = (fast_dt / n) * 1000
    fast_fps = 1000.0 / fast_ms if fast_ms > 0 else float("inf")
    legacy_fps = 1000.0 / legacy_ms if legacy_ms > 0 else float("inf")

    print(f"[bench] {n} frames @ 1280x720")
    print(f"[bench] legacy full redraw : {legacy_ms:.1f} ms/frame  -->  {legacy_fps:.1f} fps")
    print(f"[bench] fast cached path   : {fast_ms:.1f} ms/frame  -->  {fast_fps:.1f} fps")
    print(f"[bench] cold fast render   : {cold_ms:.1f} ms")
    print(f"[bench] speedup            : {legacy_ms / fast_ms:.2f}x")
    print(f"[bench] frame hits/misses  : {cache.stats['frame_hits']} / {cache.stats['frame_misses']}")
    print(f"[bench] static hits/misses : {cache.stats['static_hits']} / {cache.stats['static_misses']}")
    print(f"[bench] semi hits/misses   : {cache.stats['semistatic_hits']} / {cache.stats['semistatic_misses']}")
    print(f"[bench] text cache entries : {len(cache.text_cache)}")
    print(f"[bench] gradient entries   : {len(cache.gradient_cache)}")
    print(f"[bench] visual updates     : {cache.stats['visualizer_updates']}")
    print(f"[bench] meter updates      : {cache.stats['meter_updates']}")


# =============================================================================
# OPTIONAL PYNQ HDMI HOOK — kept as a separate function, never imported on Windows.
# =============================================================================
def run_pynq_hdmi(bitfile: str = "base.bit", fps: int = 5):
    """
    Drive a PYNQ-Z2 HDMI Out with render_frame(). Imports pynq lazily so this
    file stays importable on Windows / desktop where pynq is not installed.
    """
    from pynq import Overlay                              # noqa: F401
    from pynq.lib.video import VideoMode, PIXEL_RGB
    base = Overlay(bitfile)
    mode = VideoMode(W, H, 24)
    hdmi_out = base.video.hdmi_out
    hdmi_out.configure(mode, PIXEL_RGB)
    hdmi_out.start()
    state = load_state_json()
    dt = 1.0 / fps
    try:
        while True:
            state.t += dt
            frame = hdmi_out.newframe()
            frame[:] = render_frame(state)
            hdmi_out.writeframe(frame)
    finally:
        save_state_json(state)
        hdmi_out.stop()


# =============================================================================
# CLI ENTRY
# =============================================================================
def _build_argparser():
    import argparse
    p = argparse.ArgumentParser(
        description="DOY FX CORE multi-effects GUI (PIL/NumPy + optional Tk).")
    p.add_argument("--window", action="store_true",
                   help="Show interactive 800x480 Tk window.")
    p.add_argument("--fullscreen", action="store_true",
                   help="Show fullscreen on the chosen monitor (Windows).")
    p.add_argument("--monitor", "-m", type=int, default=0,
                   help="Monitor index for fullscreen (default 0).")
    p.add_argument("--width", type=int, default=800,
                   help="Window width when not fullscreen (default 800).")
    p.add_argument("--height", type=int, default=480,
                   help="Window height when not fullscreen (default 480).")
    p.add_argument("--bench", action="store_true",
                   help="Render 30 frames and report fps.")
    p.add_argument("--cli", action="store_true",
                   help="Terminal-driven CLI loop (legacy).")
    p.add_argument("--out", default=".",
                   help="Output directory for preview PNG generation.")
    return p


if __name__ == "__main__":
    args = _build_argparser().parse_args()
    if args.bench:
        run_bench()
    elif args.fullscreen:
        run_windows_fullscreen(monitor=args.monitor)
    elif args.window:
        run_windows_window(width=args.width, height=args.height,
                           fullscreen=False, monitor=args.monitor)
    elif args.cli:
        main(out_dir=args.out, try_cli=True)
    else:
        main(out_dir=args.out, try_cli=False)
