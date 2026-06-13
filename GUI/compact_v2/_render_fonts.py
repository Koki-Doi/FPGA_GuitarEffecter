"""Font caches + text measurement for the compact_v2 renderer.

Side-effect-free leaf extracted verbatim from ``renderer.py``. The bitmap
and TrueType font caches live here; ``renderer.py`` re-imports these names
so ``from compact_v2.renderer import _base_font`` keeps working.
"""
from typing import Tuple

from PIL import ImageFont


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


def _measure(text: str, font) -> Tuple[int, int]:
    if hasattr(font, "getbbox"):
        b = font.getbbox(text)
        return (b[2] - b[0], b[3] - b[1])
    if hasattr(font, "getsize"):
        return font.getsize(text)
    return (len(text) * 6, 11)
