"""Pixel hit-test for the compact-v2 800x480 GUI.

Maps a (x, y) click into one of (`select_effect`, `toggle_effect`,
`toggle_selected_fx`, `select_knob`, `set_knob`, `prev_model`,
`next_model`) by reading the same `compact_v2_panel_boxes` rectangles
the renderer uses.
"""

from .knobs import EFFECTS, EFFECTS_SHORT
from .layout import compact_v2_panel_boxes
from .state import AppState

def hit_test_compact_v2(x: int, y: int, state: AppState,
                         width: int = 800, height: int = 480):
    """Map a pixel coordinate (logical 800x480) to a GUI action.

    Returns one of:
        ('select_effect',    eff_idx)          left-click on chain block
        ('toggle_effect',    eff_idx)          right-click on chain block
        ('toggle_selected_fx', None)           click on FX on/bypass chip
        ('select_knob',      knob_idx)         click on knob label area
        ('set_knob',         (knob_idx, val))  click / drag on knob bar
        None                                   no hit
    """
    boxes = compact_v2_panel_boxes(width, height)

    # Chain blocks
    cx0, cy0, cx1, cy1 = boxes["chain"]
    n = max(1, len(EFFECTS))
    gap = 8
    inner_pad = 14
    row_y0 = cy0 + 36
    row_y1 = cy1 - 14
    avail_w = (cx1 - cx0) - inner_pad * 2
    cell_w = int((avail_w - gap * (n - 1)) / n)
    if row_y0 <= y <= row_y1:
        for pos in range(n):
            bx0 = cx0 + inner_pad + pos * (cell_w + gap)
            bx1 = bx0 + cell_w
            if bx0 <= x <= bx1:
                eff_idx = state.chain[pos] if pos < len(state.chain) else pos
                return ('select_effect', eff_idx)

    # FX panel
    fx0, fy0, fx1, fy1 = boxes["fx"]

    # FX on/bypass chip
    s_chip_w, s_chip_h = 110, 30
    if (fx1 - 16 - s_chip_w <= x <= fx1 - 16 and
            fy0 + 18 <= y <= fy0 + 18 + s_chip_h):
        return ('toggle_selected_fx', None)

    # Model dropdown (DIST, AMP, CAB only)
    selected_short = EFFECTS_SHORT[state.selected_effect]
    has_model = selected_short in ("DIST", "AMP", "CAB")
    if has_model:
        dd_y0 = fy0 + 36
        dd_y1 = fy0 + 66
        _full_x0 = fx0 + 250
        _full_x1 = fx1 - 16 - 110 - 8
        _shrink = (_full_x1 - _full_x0) * 15 // 100
        dd_x0 = _full_x0 + _shrink
        dd_x1 = _full_x1 - _shrink
        arr_w = 22
        if dd_y0 <= y <= dd_y1:
            if dd_x0 <= x <= dd_x0 + arr_w:
                return ('prev_model', None)
            if dd_x1 - arr_w <= x <= dd_x1:
                return ('next_model', None)

    # Knob grid
    knobs = state.knobs()
    n_knobs = len(knobs)
    if n_knobs == 0:
        return None
    if n_knobs <= 3:
        cols, rows = n_knobs, 1
    elif n_knobs == 4:
        cols, rows = 2, 2
    elif n_knobs <= 6:
        cols, rows = 3, 2
    else:
        cols, rows = 4, 2
    col_gap = 16 if cols == 4 else 28
    row_gap = 14
    grid_x0 = fx0 + 20
    grid_x1 = fx1 - 20
    grid_y0 = fy0 + 72 if has_model else fy0 + 64
    grid_y1 = fy1 - 14
    col_w = (grid_x1 - grid_x0 - col_gap * (cols - 1)) // cols
    row_h = (grid_y1 - grid_y0 - row_gap * (rows - 1)) // rows
    bar_h = 12
    text_block_h = 30
    if grid_y0 <= y <= grid_y1:
        for i in range(n_knobs):
            col_i = i % cols
            row_i = i // cols
            cxx0 = grid_x0 + col_i * (col_w + col_gap)
            cxx1 = cxx0 + col_w
            cyy0r = grid_y0 + row_i * (row_h + row_gap)
            cyy1r = cyy0r + row_h
            bar_y0 = (cyy0r + 4 + text_block_h) if rows == 1 else (cyy1r - bar_h)
            bar_y1 = bar_y0 + bar_h
            if cxx0 <= x <= cxx1 and cyy0r <= y <= bar_y1:
                if bar_y0 <= y <= bar_y1:
                    rel = max(0.0, min(1.0, (x - cxx0) / max(1, cxx1 - cxx0)))
                    return ('set_knob', (i, rel * 100.0))
                return ('select_knob', i)
    return None
