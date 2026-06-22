"""Compact-v2 per-panel draw functions.

Refactor P2 (2026-06-22): the panel-level draw functions (the compact-v1 800x480
CHAIN / SIGNAL MONITOR / LEVELS panels and the compact-v2 PRESET header / EFFECT
CHAIN / corner markers / encoder-status strip) split out of `renderer.py`. They
call the low-level primitives from `_render_primitives` (which owns the shared
render-cache holder), so there is no circular import: panels -> primitives, and
renderer -> primitives + panels. Behaviour is byte-for-byte identical to the
pre-split renderer (verified by the 108-frame render-snapshot digest).
"""

import math

from PIL import Image, ImageDraw

from .knobs import EFFECTS, EFFECTS_SHORT
from .state import AppState
from .layout import (
    LED, LED_SOFT, LED_DIM, LED_DEEP, LED_GHOST,
    SCR_BG, SCR_BG_HI, SCR_GRID, SCR_TEXT, SCR_TEXT_DIM, SCR_TEXT_DEAD,
    WARN_AMBER, WARN_RED,
    INK_HI, INK_MID, INK_LO,
)
from ._render_primitives import (
    draw_text, draw_smooth_text, vertical_gradient, rounded_rect, draw_meter,
    _lerp_color, _pynq_static_mode,
)


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


def _draw_cv2_header(img, d, state, palette, boxes):
    """Draw the compact-v2 PRESET header panel (`boxes["header"]`)."""
    LED = palette["LED"]
    SCR_TEXT_DIM = palette["SCR_TEXT_DIM"]
    INK_HI = palette["INK_HI"]
    bypass_color = palette["BYPASS_COL"]
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


def _draw_cv2_chain(img, d, state, palette, boxes):
    """Draw the compact-v2 EFFECT CHAIN strip (`boxes["chain"]`)."""
    LED = palette["LED"]
    SCR_TEXT_DIM = palette["SCR_TEXT_DIM"]

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


def _draw_cv2_corner_markers(img, d, palette, Wv, Hv, placement_label):
    """Draw the corner canvas markers + bottom variant label."""
    LED = palette["LED"]
    LED_SOFT = palette["LED_SOFT"]
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


def _draw_cv2_encoder_status(img, d, state, palette, Wv, Hv):
    """Draw the Phase 7G+ encoder status strip (right edge, above BR).

    Only appears when at least one optional encoder field is set, so
    legacy AppState instances render identically.
    """
    LED = palette["LED"]
    bypass_color = palette["BYPASS_COL"]
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
