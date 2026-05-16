"""Compact-v2 800x480 palette, theme, and panel layout.

Pure constants and small numpy helpers; no AppState / EFFECTS dependency.
Both the renderer and the hit-test layer read ``compact_v2_panel_boxes``
to agree on where each region of the 800x480 surface lives.
"""

import numpy as np

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
                scanline_rgba=None, scanline_step=0,
                vignette_size=0):
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
        "VIGNETTE_SIZE": int(vignette_size),
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
    led=(105, 235, 125),
    led_soft=(190, 252, 200),
    led_dim=(60, 155, 82),
    led_deep=(28, 76, 38),
    led_ghost=(12, 30, 16),
    scr_text=(160, 238, 172),
    scr_text_dim=(84, 155, 98),
    scr_text_dead=(44, 82, 54),
    scr_grid=(18, 54, 24),
    ink_hi=(212, 250, 215),
    ink_mid=(130, 195, 142),
    ink_lo=(78, 132, 90),
    warn_amber=(255, 178, 55),
    bypass_col=(240, 162, 65),
    bg_grad=[(0.0, (6, 18, 8)), (0.55, (3, 10, 5)), (1.0, (1, 5, 2))],
    chassis_inner_fill=(4, 12, 6, 228),
    panel_header_fill=(6, 20, 9, 255),
    panel_chain_fill=(5, 16, 8, 255),
    panel_fx_fill=(5, 18, 9, 255),
    header_chip_fill=(4, 14, 7, 255),
    fx_chip_fill=(3, 9, 5, 255),
    chain_on_fill=(8, 46, 16, 255),
    chain_off_fill=(8, 20, 11, 255),
    chain_off_outline=(52, 92, 62, 220),
    chain_off_text=(98, 150, 110, 255),
    chain_badge_off=(32, 56, 38),
    bar_bg_fill=(3, 9, 5, 255),
    bar_outline=(0, 0, 0, 255),
    scanline_rgba=(0, 78, 26, 62),
    scanline_step=2,
    vignette_size=55,
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


def _apply_vignette_inplace(arr, size):
    """Linear-falloff edge vignette for CRT look. Pure numpy slice ops.

    Darkens the outermost ``size`` pixels on all 4 borders from black to
    full brightness. Only O(4 * size * max(H,W)) elements touched -- far
    cheaper than a full-frame multiply. Returns ``arr`` unchanged when
    ``size <= 0``.
    """
    if size <= 0:
        return arr
    H, W = arr.shape[:2]
    s = min(int(size), H // 3, W // 3)
    if s <= 0:
        return arr
    fade = np.linspace(0.0, 1.0, s, dtype=np.float32)
    arr[:s] = (arr[:s].astype(np.float32) * fade[:, None, None]).clip(0, 255).astype(np.uint8)
    arr[H - s:] = (arr[H - s:].astype(np.float32) * fade[::-1, None, None]).clip(0, 255).astype(np.uint8)
    arr[:, :s] = (arr[:, :s].astype(np.float32) * fade[None, :, None]).clip(0, 255).astype(np.uint8)
    arr[:, W - s:] = (arr[:, W - s:].astype(np.float32) * fade[None, ::-1, None]).clip(0, 255).astype(np.uint8)
    return arr



COMPACT_V2_LAYOUT = {
    # Phase 4G compact-v2 coordinates for 800x480 (Phase 4I restored
    # baseline). Phase 4H pushed everything down by ~18 px and tightened
    # the left margin from 24 to 18 to chase a reported top-clip / unused
    # left strip on the 5-inch LCD; on the real panel that direction
    # produced a layout shifted down and to the right rather than fixing
    # the symptom, so Phase 4I rolled it back to the Phase 4G values
    # below. The dict is kept (instead of inlining literals as Phase 4G
    # did) so diagnostic scripts can read the exact same bboxes the
    # renderer draws.
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

