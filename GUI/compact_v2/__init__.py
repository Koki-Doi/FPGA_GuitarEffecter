"""compact_v2: per-theme split of the 800x480 GUI module.

Previously a single 1685-line ``GUI/pynq_multi_fx_gui.py`` held the
palette, knob layout, AppState, primitives, render functions, and hit
tester. The pieces were extracted here so per-theme edits (palette,
knob rows, state schema, render code, hit map) sit in their own files
and stop colliding in merges.

``GUI/pynq_multi_fx_gui.py`` is a thin re-export shim over this
package; existing callers keep using
``from pynq_multi_fx_gui import X`` unchanged.
"""
from .knobs import (
    EFFECTS, EFFECTS_SHORT, EFFECT_KNOBS, _EFFECT_KNOB_DEFAULTS,
    DIST_MODELS, DISTORTION_PEDALS, AMP_MODELS, CAB_MODELS, CHAIN_PRESETS,
)
from .state import (
    AppState, STATE_FILE, _STATE_KEYS,
    save_state_json, load_state_json,
)
from .layout import (
    CHASSIS_HI, CHASSIS_MID_HI, CHASSIS_MID, CHASSIS_MID_LO, CHASSIS_LO,
    CHASSIS_EDGE, CHASSIS_INK,
    LED, LED_SOFT, LED_DIM, LED_DEEP, LED_GHOST,
    SCR_BG, SCR_BG_HI, SCR_GRID, SCR_TEXT, SCR_TEXT_DIM, SCR_TEXT_DEAD,
    WARN_AMBER, WARN_RED,
    INK_HI, INK_MID, INK_LO,
    CYAN_THEME, PIPBOY_THEME, THEMES, DEFAULT_800X480_THEME,
    resolve_theme, _make_theme,
    _apply_scanlines_inplace, _apply_vignette_inplace,
    COMPACT_V2_LAYOUT, compact_v2_panel_boxes,
)
from .renderer import (
    _RandomStateCompat, _rng,
    _patch_old_pillow_draw_keywords,
    _ACTIVE_RENDER_CACHE, _pynq_static_mode,
    _base_font, _smooth_font, _SMOOTH_FONT_CACHE, _SMOOTH_TTF_CANDIDATES,
    draw_smooth_text, draw_text, _measure,
    _lerp, _lerp_color, vertical_gradient, rounded_rect, draw_meter,
    RenderCache, make_pynq_static_render_cache,
    state_semistatic_signature, state_dynamic_signature,
    _draw_800x480_chain, _draw_800x480_monitor, _draw_800x480_levels,
    _render_frame_800x480_logical, _render_frame_800x480_compact_v2,
    render_frame_800x480, render_frame_800x480_compact_v2,
)
from .hit_test import hit_test_compact_v2
