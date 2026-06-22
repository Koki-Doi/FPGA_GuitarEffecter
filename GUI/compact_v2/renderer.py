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
    OVERDRIVE_MODELS,
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

# Side-effect-free leaves extracted from this module (behaviour-identical),
# re-imported so the public `from compact_v2.renderer import X` surface is
# unchanged. See _render_compat / _render_fonts / _render_cache.
from ._render_compat import _RandomStateCompat, _rng
from ._render_fonts import (
    _base_font, _smooth_font, _measure,
    _SMOOTH_FONT_CACHE, _SMOOTH_TTF_CANDIDATES,
)
from ._render_cache import (
    RenderCache, make_pynq_static_render_cache,
    state_semistatic_signature, state_dynamic_signature,
)


# Render primitives + the shared render-cache holder, and the per-panel draw
# functions, live in _render_primitives / _render_panels (refactor P2). Re-imported
# here so `from compact_v2.renderer import draw_text` (etc.) stays unchanged and the
# frame builders below call them directly; the cache is set/restored via
# _rp.set_active_render_cache() so both modules share one cache object.
from . import _render_primitives as _rp
from ._render_primitives import (
    _patch_old_pillow_draw_keywords, _pynq_static_mode,
    _ACTIVE_RENDER_CACHE,  # re-export only (live value lives in _render_primitives)
    draw_smooth_text, draw_text, _lerp, _lerp_color,
    vertical_gradient, rounded_rect, draw_meter,
)
from ._render_panels import (
    _draw_800x480_chain, _draw_800x480_monitor, _draw_800x480_levels,
    _draw_cv2_header, _draw_cv2_chain, _draw_cv2_corner_markers,
    _draw_cv2_encoder_status,
)


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

    prev = _rp.set_active_render_cache(cache)
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
        _rp.set_active_render_cache(prev)






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

    prev = _rp.set_active_render_cache(cache)
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

        _draw_cv2_header(img, d, state, palette, boxes)
        _draw_cv2_chain(img, d, state, palette, boxes)

        fx_box = boxes["fx"]
        fx0, fy0, fx1, fy1 = fx_box
        rounded_rect(d, fx_box, 10, fill=palette["PANEL_FX_FILL"],
                     outline=LED + (90,), width=2)
        selected_name = EFFECTS[state.selected_effect]
        selected_short = EFFECTS_SHORT[state.selected_effect]
        selected_on = bool(state.effect_on[state.selected_effect])
        model_label = None
        # Wah does not pick a model but does show a SOURCE: MANUAL label
        # so future FP02M / Arduino A0 work has a UI affordance to flip
        # without touching the GPIO layout. ``source_label`` is rendered
        # as a static text strip in the same row as the model dropdown
        # would have been; the knob grid shifts down the same amount.
        source_label = None
        if selected_short == "DIST":
            idx = max(0, min(len(DIST_MODELS) - 1,
                             int(getattr(state, "dist_model_idx", 0) or 0)))
            model_label = DIST_MODELS[idx]
        elif selected_short == "OD":
            # D45: the single generic Overdrive was retired; the OD
            # chip now always shows one of the six selectable models.
            idx = max(0, min(len(OVERDRIVE_MODELS) - 1,
                             int(getattr(state, "overdrive_model_idx", 0) or 0)))
            model_label = OVERDRIVE_MODELS[idx]
        elif selected_short == "AMP":
            idx = max(0, min(len(AMP_MODELS) - 1,
                             int(getattr(state, "amp_model_idx", 0) or 0)))
            model_label = AMP_MODELS[idx][0]
        elif selected_short == "CAB":
            idx = max(0, min(len(CAB_MODELS) - 1,
                             int(getattr(state, "cab_model_idx", 0) or 0)))
            model_label = CAB_MODELS[idx]
        elif selected_short == "WAH":
            # SOURCE strip: MANUAL (GUI / encoder) or PEDAL (FP02M / A0).
            # In PEDAL mode without an available reader, show UNAVAIL so the
            # user knows POSITION is not being driven (D74).
            src = str(getattr(state, "wah_source", "manual") or "manual")
            if src == "pedal" and not bool(getattr(state, "wah_pedal_available", False)):
                source_label = "SOURCE: PEDAL (UNAVAIL)"
            else:
                source_label = "SOURCE: " + src.upper()
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
        if model_label is None and source_label is not None:
            # Render the SOURCE label in the same row the model
            # dropdown would otherwise occupy, but as plain text (no
            # chip / no arrows) -- the source is informational today
            # and only flips automatically once FP02M / Arduino A0
            # input is wired. Left-align right after the FX module
            # title so it does not collide with the ON/BYPASS chip.
            sl_x = fx0 + 250
            sl_y = fy0 + 51
            draw_smooth_text(img, (sl_x, sl_y), source_label, size=20,
                             fill=LED_DIM + (255,), anchor="lm")
        knobs = [k for k in state.knobs() if k[0]]
        # D74: in WAH PEDAL mode with an available reader, the POS knob
        # (index 0) displays the live FP02M value rather than the stored
        # manual percent. The manual value is still kept in all_knob_values
        # so flipping back to MANUAL restores it.
        if (selected_short == "WAH" and knobs
                and str(getattr(state, "wah_source", "manual") or "manual") == "pedal"
                and bool(getattr(state, "wah_pedal_available", False))):
            knobs[0] = (knobs[0][0], state.wah_position_display_pct())
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
        # Shift the knob grid down the same amount whether the FX panel
        # is showing a model dropdown or the WAH SOURCE strip.
        grid_y0 = fy0 + 72 if (model_label is not None or source_label is not None) else fy0 + 64
        grid_y1 = fy1 - 14
        col_gap = 16 if cols == 4 else 28
        row_gap = 14
        col_w = (grid_x1 - grid_x0 - col_gap * (cols - 1)) // cols
        row_h = (grid_y1 - grid_y0 - row_gap * (rows - 1)) // rows
        bar_h = 12
        from .knobs import is_binary_knob as _is_binary_knob
        _fx_name = EFFECTS[state.selected_effect]
        for i, (label, value) in enumerate(knobs):
            col = i % cols
            row = i // cols
            cx0 = grid_x0 + col * (col_w + col_gap)
            cx1 = cx0 + col_w
            cy0r = grid_y0 + row * (row_h + row_gap)
            cy1r = cy0r + row_h
            is_sel = (i == state.selected_knob)
            _binary_here = _is_binary_knob(_fx_name, i)

            label_y = cy0r + 4
            value_y = cy0r + 4
            draw_text(img, (cx0, label_y), label,
                      fill=(LED if is_sel else SCR_TEXT_DIM) + (255,),
                      scale=2, letter_spacing=2)
            if _binary_here:
                _disp = "  1" if float(value) >= 0.5 else "  0"
            else:
                _disp = "{:>3}".format(int(value))
            draw_text(img, (cx1, value_y),
                      _disp,
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
            if _binary_here:
                v_clamp = 1.0 if float(value) >= 0.5 else 0.0
            else:
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

        _draw_cv2_corner_markers(img, d, palette, Wv, Hv, placement_label)
        _draw_cv2_encoder_status(img, d, state, palette, Wv, Hv)

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
        _rp.set_active_render_cache(prev)




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
