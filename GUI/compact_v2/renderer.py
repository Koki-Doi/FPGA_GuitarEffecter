"""Compact-v2 800x480 renderer: primitives, cache, render functions.

Owns the heavyweight render-time pieces:
- `_RandomStateCompat` / `_rng` for NumPy 1.16 compatibility
- the Pillow 5.1 keyword-compat patch (`_patch_old_pillow_draw_keywords`)
- font caches and `draw_text` / `draw_smooth_text`
- `_lerp` / `vertical_gradient` / `rounded_rect` / `draw_meter`
- `RenderCache` + `make_pynq_static_render_cache` + the
  `state_semistatic_signature` / `state_dynamic_signature` helpers used
  by the change-driven render path
- the actual `_render_frame_800x480_*` builders and the public
  `render_frame_800x480` / `render_frame_800x480_compact_v2` dispatch
"""

import json
import math
import os
import time
from typing import List, Tuple, Optional

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from .knobs import (
    EFFECTS, EFFECTS_SHORT, EFFECT_KNOBS, _EFFECT_KNOB_DEFAULTS,
    DIST_MODELS, DISTORTION_PEDALS, AMP_MODELS, CAB_MODELS, CHAIN_PRESETS,
)
from .state import AppState
from .layout import (
    CHASSIS_HI, CHASSIS_MID_HI, CHASSIS_MID, CHASSIS_MID_LO, CHASSIS_LO,
    CHASSIS_EDGE, CHASSIS_INK,
    LED, LED_SOFT, LED_DIM, LED_DEEP, LED_GHOST,
    SCR_BG, SCR_BG_HI, SCR_GRID, SCR_TEXT, SCR_TEXT_DIM, SCR_TEXT_DEAD,
    WARN_AMBER, WARN_RED,
    INK_HI, INK_MID, INK_LO,
    THEMES, DEFAULT_800X480_THEME, resolve_theme,
    _apply_scanlines_inplace, _apply_vignette_inplace,
    COMPACT_V2_LAYOUT, compact_v2_panel_boxes,
)

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
        int(state.selected_knob),
        tuple(int(round(v))
              for nm in EFFECTS
              for v in state.all_knob_values.get(nm, [])),
        getattr(state, "dist_model_idx", None),
        getattr(state, "amp_model_idx", None),
        getattr(state, "cab_model_idx", None),
        bool(state.save_flash > 0),
        # Phase 7G+ live-apply status: include so the status strip refreshes
        # when the encoder runtime updates these fields.
        bool(getattr(state, "live_apply", True)),
        bool(getattr(state, "last_apply_ok", True)),
        str(getattr(state, "last_apply_message", "")),
        str(getattr(state, "last_unsupported_label", "")),
        bool(getattr(state, "edit_mode", False)),
        bool(getattr(state, "model_select_mode", False)),
        bool(getattr(state, "value_dirty", False)),
        bool(getattr(state, "apply_pending", False)),
        str(getattr(state, "last_control_source", "")),
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
    LED           = palette["LED"]
    LED_SOFT      = palette["LED_SOFT"]
    LED_DIM       = palette["LED_DIM"]
    SCR_TEXT_DIM  = palette["SCR_TEXT_DIM"]
    SCR_TEXT_DEAD = palette["SCR_TEXT_DEAD"]
    INK_HI        = palette["INK_HI"]
    bypass_color  = palette["BYPASS_COL"]

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

        header = boxes["header"]
        hx0, hy0, hx1, hy1 = header
        rounded_rect(d, header, 10, fill=palette["PANEL_HEADER_FILL"],
                     outline=LED + (110,), width=2)
        draw_text(img, (hx0 + 18, hy0 + 10), "> PRESET",
                  fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=3)
        d.line((hx0 + 14, hy0 + 24, hx1 - 14, hy0 + 24),
               fill=LED + (35,), width=1)
        draw_smooth_text(img, (hx0 + 18, hy0 + 28),
                         state.preset_id, size=44,
                         fill=INK_HI + (255,), letter_spacing=1)
        draw_smooth_text(img, ((hx0 + hx1) // 2, hy0 + 22),
                         state.preset_name.replace("  ", " "),
                         size=36, fill=INK_HI + (255,), anchor="mt")
        if bypassed:
            chip_w, chip_h = 158, 34
            chip = (hx1 - 16 - chip_w, hy0 + 12,
                    hx1 - 16, hy0 + 12 + chip_h)
            rounded_rect(d, chip, 8, fill=palette["HEADER_CHIP_FILL"],
                         outline=bypass_color + (255,), width=2)
            draw_text(img, ((chip[0] + chip[2]) // 2,
                            (chip[1] + chip[3]) // 2),
                      "BYPASS", fill=bypass_color + (255,), scale=2,
                      anchor="mm", letter_spacing=2)
        draw_text(img, (hx1 - 16, hy0 + 54),
                  "[{}/{}]  FX".format(active_n, len(EFFECTS)),
                  fill=LED + (255,), scale=2, anchor="rt",
                  letter_spacing=2)

        chain = boxes["chain"]
        cx0, cy0, cx1, cy1 = chain
        rounded_rect(d, chain, 10, fill=palette["PANEL_CHAIN_FILL"],
                     outline=LED + (90,), width=2)
        draw_text(img, (cx0 + 16, cy0 + 10), "> EFFECT CHAIN",
                  fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=3)
        d.line((cx0 + 14, cy0 + 26, cx1 - 14, cy0 + 26),
               fill=LED + (35,), width=1)
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
            draw_text(img, ((bx0 + bx1) // 2, (row_y0 + row_y1) // 2),
                      EFFECTS_SHORT[eff_idx],
                      fill=text_col, scale=2, anchor="mm",
                      letter_spacing=2)

        fx_box = boxes["fx"]
        fx0, fy0, fx1, fy1 = fx_box
        rounded_rect(d, fx_box, 10, fill=palette["PANEL_FX_FILL"],
                     outline=LED + (90,), width=2)
        selected_name = EFFECTS[state.selected_effect]
        selected_short = EFFECTS_SHORT[state.selected_effect]
        selected_on = bool(state.effect_on[state.selected_effect])
        model_label = None
        if selected_short == "DIST":
            idx = max(0, min(len(DIST_MODELS) - 1,
                             int(getattr(state, "dist_model_idx", 0) or 0)))
            model_label = DIST_MODELS[idx]
        elif selected_short == "AMP":
            idx = max(0, min(len(AMP_MODELS) - 1,
                             int(getattr(state, "amp_model_idx", 0) or 0)))
            model_label = AMP_MODELS[idx][0]
        elif selected_short == "CAB":
            idx = max(0, min(len(CAB_MODELS) - 1,
                             int(getattr(state, "cab_model_idx", 0) or 0)))
            model_label = CAB_MODELS[idx]
        draw_text(img, (fx0 + 16, fy0 + 10), "> FX MODULE",
                  fill=SCR_TEXT_DIM + (255,), scale=1, letter_spacing=3)
        d.line((fx0 + 14, fy0 + 24, fx1 - 14, fy0 + 24),
               fill=LED + (35,), width=1)
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
        draw_smooth_text(img, (fx0 + 16, fy0 + 28),
                         selected_name.upper(), size=30,
                         fill=LED + (255,))
        if model_label is not None:
            dd_y0 = fy0 + 36
            dd_y1 = fy0 + 66
            _full_x0 = fx0 + 250
            _full_x1 = s_chip[0] - 8
            _shrink = (_full_x1 - _full_x0) * 15 // 100  # 15% off each side = 30% total
            dd_x0 = _full_x0 + _shrink
            dd_x1 = _full_x1 - _shrink
            arr_w = 22
            rounded_rect(d, (dd_x0, dd_y0, dd_x1, dd_y1), 4,
                         fill=palette["FX_CHIP_FILL"],
                         outline=LED_DIM + (255,), width=1)
            d.rectangle((dd_x0 + 1, dd_y0 + 1, dd_x0 + arr_w - 1, dd_y1 - 1),
                         fill=palette["LED_DEEP"] + (255,))
            d.rectangle((dd_x1 - arr_w + 1, dd_y0 + 1, dd_x1 - 1, dd_y1 - 1),
                         fill=palette["LED_DEEP"] + (255,))
            draw_text(img, (dd_x0 + arr_w // 2, (dd_y0 + dd_y1) // 2),
                      "<", fill=LED + (255,), scale=1, anchor="mm")
            draw_text(img, (dd_x1 - arr_w // 2, (dd_y0 + dd_y1) // 2),
                      ">", fill=LED + (255,), scale=1, anchor="mm")
            # Model label: use anti-aliased TTF and pick the largest size
            # that still fits inside the chip's safe area (avoid clashing
            # with the left/right arrow zones).
            _model_max_w = max(8, (dd_x1 - dd_x0) - 2 * arr_w - 10)
            _model_max_h = max(8, (dd_y1 - dd_y0) - 4)
            _model_size = 14
            for _trial in (22, 20, 18, 16, 14):
                _f = _smooth_font(_trial)
                _tw, _th = _measure(model_label, _f)
                if _tw <= _model_max_w and _th <= _model_max_h:
                    _model_size = _trial
                    break
            draw_smooth_text(img, ((dd_x0 + dd_x1) // 2,
                                    (dd_y0 + dd_y1) // 2),
                             model_label, size=_model_size,
                             fill=LED + (255,), anchor="mm")
        knobs = [k for k in state.knobs() if k[0]]
        n_knobs = len(knobs)
        # Grid layout per effect (knob count -> cols, rows):
        #   3 knobs (NS, OD, EQ, RVB): 3 cols x 1 row
        #   4 knobs (CMP, CAB):        2 cols x 2 rows
        #   6 knobs (DIST, AMP):       3 cols x 2 rows
        if n_knobs <= 3:
            cols, rows = max(1, n_knobs), 1
        elif n_knobs == 4:
            cols, rows = 2, 2
        elif n_knobs <= 6:
            cols, rows = 3, 2
        else:
            cols, rows = 4, 2

        grid_x0 = fx0 + 20
        grid_x1 = fx1 - 20
        grid_y0 = fy0 + 72 if model_label is not None else fy0 + 64
        grid_y1 = fy1 - 14
        col_gap = 16 if cols == 4 else 28
        row_gap = 14
        col_w = (grid_x1 - grid_x0 - col_gap * (cols - 1)) // cols
        row_h = (grid_y1 - grid_y0 - row_gap * (rows - 1)) // rows
        bar_h = 12
        for i, (label, value) in enumerate(knobs):
            col = i % cols
            row = i // cols
            cx0 = grid_x0 + col * (col_w + col_gap)
            cx1 = cx0 + col_w
            cy0r = grid_y0 + row * (row_h + row_gap)
            cy1r = cy0r + row_h
            is_sel = (i == state.selected_knob)

            label_y = cy0r + 4
            value_y = cy0r + 4
            draw_text(img, (cx0, label_y), label,
                      fill=(LED if is_sel else SCR_TEXT_DIM) + (255,),
                      scale=2, letter_spacing=2)
            draw_text(img, (cx1, value_y),
                      "{:>3}".format(int(value)),
                      fill=LED + (255,), scale=2, anchor="rt",
                      letter_spacing=1)
            # Pip-Boy dot separator between label and value
            dot_y = label_y + 7
            dot_x0 = cx0 + (68 if cols == 4 else 92)
            for dx in range(dot_x0, cx1 - 36, 4 if cols == 4 else 5):
                d.rectangle((dx, dot_y, dx + 1, dot_y + 1),
                             fill=SCR_TEXT_DEAD + (255,))

            text_block_h = 30
            if rows == 1:
                bar_y0 = label_y + text_block_h
            else:
                bar_y0 = cy1r - bar_h
            bar_y1 = bar_y0 + bar_h
            bar_x0 = cx0
            bar_x1 = cx1
            v_clamp = max(0.0, min(1.0, value / 100.0))
            # Pip-Boy segmented progress bar
            n_seg = 14
            s_gap = 2
            s_w = max(1, (bar_x1 - bar_x0 - 2 - s_gap * (n_seg - 1)) // n_seg)
            lit_segs = int(round(v_clamp * n_seg))
            d.rectangle((bar_x0, bar_y0, bar_x1, bar_y1),
                        fill=palette["BAR_BG_FILL"])
            for si in range(n_seg):
                sx0 = bar_x0 + 1 + si * (s_w + s_gap)
                sx1 = sx0 + s_w
                if si < lit_segs:
                    d.rectangle((sx0, bar_y0 + 1, sx1, bar_y1 - 1),
                                fill=(LED if is_sel else LED_DIM) + (255,))

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

        label_text = "DOY-FX  //  AUDIO.LAB  //  v2"
        if placement_label:
            label_text = "DOY-FX  //  AUDIO.LAB  //  " + str(placement_label)
        draw_text(img, (Wv // 2, Hv - 4), label_text,
                  fill=LED_SOFT + (255,), scale=1, anchor="mb",
                  letter_spacing=2)

        # Phase 7G: tiny encoder status strip (right edge, above the BR
        # corner marker). Only appears when at least one optional encoder
        # field is set, so legacy AppState instances render identically.
        # Phase 7G+: live_apply / OK / ERR / RAT? appended when the
        # EncoderEffectApplier has run.
        _enc_flags = []
        if getattr(state, "edit_mode", False):
            _enc_flags.append("EDIT")
        if getattr(state, "model_select_mode", False):
            _enc_flags.append("MODEL")
        if getattr(state, "value_dirty", False):
            _enc_flags.append("DIRTY")
        if getattr(state, "apply_pending", False):
            _enc_flags.append("APPLY?")
        _src = getattr(state, "last_control_source", "notebook")
        if _src == "encoder":
            _enc_flags.append("ENC")
            if getattr(state, "live_apply", False):
                _enc_flags.append("LIVE")
            if not bool(getattr(state, "last_apply_ok", True)):
                _enc_flags.append("ERR")
            elif getattr(state, "last_apply_message", ""):
                _enc_flags.append("OK")
            _unsupported = getattr(state, "last_unsupported_label", "") or ""
            if "rat" in _unsupported.lower():
                _enc_flags.append("RAT?")
            elif _unsupported:
                _enc_flags.append("UNSUP")
        if _enc_flags:
            _enc_text = " ".join(_enc_flags)
            _flag_color = (
                bypass_color if (not bool(getattr(state, "last_apply_ok", True)))
                else LED)
            draw_text(img, (Wv - 22, Hv - 24), _enc_text,
                      fill=_flag_color + (255,), scale=1, anchor="rb",
                      letter_spacing=2)

        # Convert to a writable RGB ndarray *before* applying the
        # Pip-Boy-style scanline overlay so the blend is a single
        # vectorised numpy slice (much cheaper than PIL
        # alpha_composite on a 480x800 RGBA buffer).
        arr = np.array(img.convert("RGB"), dtype=np.uint8)
        _apply_scanlines_inplace(arr,
                                 palette.get("SCANLINE_STEP", 0),
                                 palette.get("SCANLINE_RGBA"))
        _apply_vignette_inplace(arr, palette.get("VIGNETTE_SIZE", 0))
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
