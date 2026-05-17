"""
DOY FX CORE — Multi-Effects Processor GUI (800x480 logical)
===========================================================
Thin re-export shim over ``GUI/compact_v2/``. The actual code lives in:

  GUI/compact_v2/knobs.py     -- EFFECTS / EFFECT_KNOBS / model tables /
                                 CHAIN_PRESETS
  GUI/compact_v2/state.py     -- AppState dataclass +
                                 save_state_json / load_state_json
  GUI/compact_v2/layout.py    -- palette constants, themes,
                                 _apply_scanlines_inplace /
                                 _apply_vignette_inplace,
                                 compact_v2_panel_boxes
  GUI/compact_v2/renderer.py  -- RandomStateCompat / fonts /
                                 draw_text / draw_smooth_text /
                                 RenderCache / state_*_signature /
                                 render_frame_800x480 /
                                 render_frame_800x480_compact_v2
  GUI/compact_v2/render_compact_v2.py
                              -- large compact-v2 800x480 drawing body
  GUI/compact_v2/hit_test.py  -- hit_test_compact_v2

Public API
----------
    from pynq_multi_fx_gui import AppState, render_frame_800x480_compact_v2
    state = AppState()
    frame = render_frame_800x480_compact_v2(state)  # (480, 800, 3) uint8

`render_frame_800x480(state, variant="compact-v1")` preserves the Phase 4E
logical layout for diagnostic scripts. The 1280x720 reference layout and
the Tkinter desktop preview app (Windows-only) were removed once the
compact-v2 LCD layout was confirmed on the live PYNQ HDMI output
(`DECISIONS.md` D24).

This shim supports both call-site conventions:

- notebooks / scripts that add ``REPO_ROOT/GUI`` to sys.path import this
  module as top-level ``pynq_multi_fx_gui`` and resolve
  ``compact_v2.*`` directly.
- tests / packagers that add ``REPO_ROOT`` to sys.path import the
  module as ``GUI.pynq_multi_fx_gui`` and need
  ``GUI.compact_v2.*``.
"""

try:
    from compact_v2.knobs import (  # noqa: F401
        EFFECTS, EFFECTS_SHORT, EFFECT_KNOBS, _EFFECT_KNOB_DEFAULTS,
        DIST_MODELS, DISTORTION_PEDALS, AMP_MODELS, CAB_MODELS,
        CHAIN_PRESETS,
    )
    from compact_v2.state import (  # noqa: F401
        AppState, STATE_FILE, _STATE_KEYS,
        save_state_json, load_state_json,
    )
    from compact_v2.layout import (  # noqa: F401
        CHASSIS_HI, CHASSIS_MID_HI, CHASSIS_MID, CHASSIS_MID_LO,
        CHASSIS_LO, CHASSIS_EDGE, CHASSIS_INK,
        LED, LED_SOFT, LED_DIM, LED_DEEP, LED_GHOST,
        SCR_BG, SCR_BG_HI, SCR_GRID, SCR_TEXT, SCR_TEXT_DIM,
        SCR_TEXT_DEAD,
        WARN_AMBER, WARN_RED,
        INK_HI, INK_MID, INK_LO,
        CYAN_THEME, PIPBOY_THEME, THEMES, DEFAULT_800X480_THEME,
        resolve_theme, _make_theme,
        _apply_scanlines_inplace, _apply_vignette_inplace,
        COMPACT_V2_LAYOUT, compact_v2_panel_boxes,
    )
    from compact_v2.renderer import (  # noqa: F401
        _RandomStateCompat, _rng,
        _patch_old_pillow_draw_keywords,
        _ACTIVE_RENDER_CACHE, _pynq_static_mode,
        _base_font, _smooth_font,
        _SMOOTH_FONT_CACHE, _SMOOTH_TTF_CANDIDATES,
        draw_smooth_text, draw_text, _measure,
        _lerp, _lerp_color, vertical_gradient, rounded_rect, draw_meter,
        RenderCache, make_pynq_static_render_cache,
        state_semistatic_signature, state_dynamic_signature,
        _draw_800x480_chain, _draw_800x480_monitor, _draw_800x480_levels,
        _render_frame_800x480_logical, _render_frame_800x480_compact_v2,
        render_frame_800x480, render_frame_800x480_compact_v2,
    )
    from compact_v2.hit_test import hit_test_compact_v2  # noqa: F401
except ImportError:
    # Loaded as GUI.pynq_multi_fx_gui (tests / packagers add REPO_ROOT
    # to sys.path instead of REPO_ROOT/GUI).
    from GUI.compact_v2.knobs import (  # noqa: F401
        EFFECTS, EFFECTS_SHORT, EFFECT_KNOBS, _EFFECT_KNOB_DEFAULTS,
        DIST_MODELS, DISTORTION_PEDALS, AMP_MODELS, CAB_MODELS,
        CHAIN_PRESETS,
    )
    from GUI.compact_v2.state import (  # noqa: F401
        AppState, STATE_FILE, _STATE_KEYS,
        save_state_json, load_state_json,
    )
    from GUI.compact_v2.layout import (  # noqa: F401
        CHASSIS_HI, CHASSIS_MID_HI, CHASSIS_MID, CHASSIS_MID_LO,
        CHASSIS_LO, CHASSIS_EDGE, CHASSIS_INK,
        LED, LED_SOFT, LED_DIM, LED_DEEP, LED_GHOST,
        SCR_BG, SCR_BG_HI, SCR_GRID, SCR_TEXT, SCR_TEXT_DIM,
        SCR_TEXT_DEAD,
        WARN_AMBER, WARN_RED,
        INK_HI, INK_MID, INK_LO,
        CYAN_THEME, PIPBOY_THEME, THEMES, DEFAULT_800X480_THEME,
        resolve_theme, _make_theme,
        _apply_scanlines_inplace, _apply_vignette_inplace,
        COMPACT_V2_LAYOUT, compact_v2_panel_boxes,
    )
    from GUI.compact_v2.renderer import (  # noqa: F401
        _RandomStateCompat, _rng,
        _patch_old_pillow_draw_keywords,
        _ACTIVE_RENDER_CACHE, _pynq_static_mode,
        _base_font, _smooth_font,
        _SMOOTH_FONT_CACHE, _SMOOTH_TTF_CANDIDATES,
        draw_smooth_text, draw_text, _measure,
        _lerp, _lerp_color, vertical_gradient, rounded_rect, draw_meter,
        RenderCache, make_pynq_static_render_cache,
        state_semistatic_signature, state_dynamic_signature,
        _draw_800x480_chain, _draw_800x480_monitor, _draw_800x480_levels,
        _render_frame_800x480_logical, _render_frame_800x480_compact_v2,
        render_frame_800x480, render_frame_800x480_compact_v2,
    )
    from GUI.compact_v2.hit_test import hit_test_compact_v2  # noqa: F401
