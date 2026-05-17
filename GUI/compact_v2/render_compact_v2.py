"""Compact-v2 800x480 renderer implementation.

This module holds the large Phase 4G/6H compact-v2 drawing routine so
``GUI.compact_v2.renderer`` can stay focused on shared primitives, cache
objects, and public dispatch wrappers.
"""

from typing import Optional

import numpy as np
from PIL import Image, ImageDraw

from .knobs import EFFECTS, EFFECTS_SHORT, DIST_MODELS, AMP_MODELS, CAB_MODELS
from .state import AppState
from .layout import (
    DEFAULT_800X480_THEME, resolve_theme, _apply_scanlines_inplace,
    _apply_vignette_inplace, compact_v2_panel_boxes,
)
from . import renderer as _renderer
from .renderer import (
    RenderCache, make_pynq_static_render_cache,
    state_semistatic_signature, state_dynamic_signature,
    vertical_gradient, rounded_rect, draw_text, draw_smooth_text,
    _smooth_font, _measure,
)


def render_compact_v2(state: AppState, width: int = 800,
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

    prev = _renderer._ACTIVE_RENDER_CACHE
    _renderer._ACTIVE_RENDER_CACHE = cache
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
        _renderer._ACTIVE_RENDER_CACHE = prev



