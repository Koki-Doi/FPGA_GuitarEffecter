"""Compact-v2 render primitives + the shared render-cache holder.

Refactor P2 (2026-06-22): the low-level draw primitives (`draw_text`,
`draw_smooth_text`, `vertical_gradient`, `rounded_rect`, `draw_meter`, the
`_lerp` helpers) and the module-level `_ACTIVE_RENDER_CACHE` they read live here
so the per-panel draw functions can move to `_render_panels` WITHOUT a circular
import. The cache is set/restored through `set_active_render_cache()` (the "tiny
shared-cache holder" the refactor doc called for) instead of a cross-module
`global` rebind, so the frame builders in `renderer.py` and the primitives here
share exactly one cache object. Behaviour is byte-for-byte identical to the
pre-split renderer (verified by the 108-frame render-snapshot digest).
"""

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from .layout import (
    LED, LED_SOFT, LED_DIM, LED_DEEP, LED_GHOST,
    SCR_BG, SCR_BG_HI, SCR_GRID, SCR_TEXT, SCR_TEXT_DIM, SCR_TEXT_DEAD,
    WARN_AMBER, WARN_RED,
    INK_HI, INK_MID, INK_LO,
)
from ._render_fonts import _base_font, _smooth_font, _measure


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


# Active render cache used by low-level helpers. Kept as a simple module global so
# the existing draw_* functions can be accelerated without changing every
# function signature. The frame builders in renderer.py set/restore it via
# set_active_render_cache() so both modules share one object (P2).
_ACTIVE_RENDER_CACHE = None


def set_active_render_cache(cache):
    """Set the active render cache; return the previous value (save/restore)."""
    global _ACTIVE_RENDER_CACHE
    prev = _ACTIVE_RENDER_CACHE
    _ACTIVE_RENDER_CACHE = cache
    return prev


def _pynq_static_mode() -> bool:
    return bool(getattr(_ACTIVE_RENDER_CACHE, "pynq_static_mode", False))



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
