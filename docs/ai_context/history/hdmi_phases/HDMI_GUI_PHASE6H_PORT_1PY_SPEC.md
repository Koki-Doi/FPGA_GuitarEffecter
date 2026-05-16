# HDMI GUI Phase 6H — Port compact-v2 HDMI GUI to (1).py spec

## Context

Commit `d7ea0ab` ("Port compact-v2 HDMI GUI to (1).py spec and enlarge
model labels", 2026-05-16) replaced `GUI/pynq_multi_fx_gui.py` with a
refactor based on the user-supplied `(1).py` reference. The port keeps
the Phase 5C runtime contract (800x480 logical frame at framebuffer
`x=0,y=0`, manual placement, `audio_lab.bit` unchanged) and the Phase 5D
Pip-Boy phosphor-green theme, but consolidates the per-effect knob spec
and the model-dropdown rendering. The intermediate Phase 6G renderer
x-tightening (outer `x=4`, header `x=8`, panels `x=12`, explicit
`x=0..1` rail) is rolled back to the Phase 4G / 4I baseline coordinates
in the same commit.

## What changed

### Renderer

- Outer chassis restored to `(12, 12, 788, 468)` (Phase 4G / 4I
  baseline). `left=right=24`, `header_y=(20,100)`,
  `chain_y=(110,250)`, `bottom_y=(260,454)` unchanged. The
  `compact_v2_panel_boxes()` helper still mirrors these values so
  diagnostic overlays stay accurate.
- Inline numpy edge-vignette is applied to the final RGBA frame
  (`_apply_edge_vignette`); the Pip-Boy palette is retuned and the
  scanline overlay strength is adjusted accordingly. No layout-side
  rebuild.
- PEDAL / AMP / CAB dropdown chip is now drawn inline inside
  `_render_frame_800x480_compact_v2` and only for those three categories.
  The label uses `draw_smooth_text` with a fit-to-chip size search
  (`22 -> 20 -> 18 -> 16 -> 14`) so long labels such as
  `HIGH GAIN STACK`, `1x12 OPEN BACK`, `BRITISH CRUNCH`, `TUBE SCREAMER`
  stay inside the chip safe area, while shorter labels (e.g. `CLEAN`,
  `RAT`) render at the maximum size 22.

### Knob spec consolidation

- `EFFECT_KNOBS` is now a single per-effect dict keyed by the
  title-case `EFFECTS` names with short labels:

  | EFFECTS key   | Knob labels |
  | --- | --- |
  | `Noise Sup`   | `THRESH`, `DECAY`, `DAMP` |
  | `Compressor` | `THRESH`, `RATIO`, `RESP`, `MAKEUP` |
  | `Overdrive`  | `TONE`, `LEVEL`, `DRIVE` |
  | `Distortion` | `TONE`, `LEVEL`, `DRIVE`, `BIAS`, `TIGHT`, `MIX` |
  | `Amp Sim`    | `GAIN`, `BASS`, `MID`, `TREB`, `PRES`, `RES`, `MSTR`, `CHAR` |
  | `Cab IR`     | `MIX`, `LEVEL`, `MODEL`, `AIR` |
  | `EQ`         | `LOW`, `MID`, `HIGH` |
  | `Reverb`     | `DECAY`, `TONE`, `MIX` |

  The selected-FX knob grid still adapts per effect (3 → 3x1,
  4 → 2x2, 6 → 3x2, 8 → 4x2).
- The legacy `SELECTED_FX_PARAM_LAYOUT` table and the
  `_should_show_selected_model_dropdown`,
  `_selected_model_dropdown_label`, `_dropdown_short`,
  `_pedal_label` / `_amp_label` / `_cab_label`, and
  `selected_fx_param_layout` helpers are removed. The renderer reads
  the model index directly off `state.dist_model_idx`,
  `state.amp_model_idx`, `state.cab_model_idx` and the dropdown
  label off the matching `*_MODELS` constant.

### AppState

- `AppState` now stores knob values in a single per-effect dict,
  `all_knob_values: Dict[str, List[float]]`. The flat
  `knob_values` field is removed.
- New helpers: `state.knobs()` returns the active effect's
  `[(label, value), ...]`; `state.set_knob(label, value)` updates the
  active effect's knob by label. Both bridge the renderer and tests
  without re-introducing the flat field.
- New entry point: `hit_test_compact_v2(x, y, state, width, height)`
  exposed for future touch / mouse interaction work. It returns
  panel / knob hit information based on `compact_v2_panel_boxes()` and
  the active per-effect knob grid.

### Tests

- `tests/test_hdmi_origin_mapping.py` drops the removed-helper
  assertions and adds:
  - `test_renderer_compact_v2_actual_panel_boxes_start_near_x0`:
    asserts `outer[0]==12`, `header[0]==24`, `chain[0]==24`,
    `fx[0]==24`.
  - `test_effect_knobs_matches_v1_spec`: enumerates the
    title-case `EFFECT_KNOBS` keys and short labels above.
  - `test_renderer_compact_v2_pedal_amp_cab_render`: PEDAL / AMP /
    CAB render smoke covering inline dropdown rendering.
  - The existing strong-UI-bbox assertion is loosened to
    `strong_ui_bbox.min_x <= 28` to match the restored x=24 baseline
    plus a few px of stroke width.
- `tests/test_hdmi_gui_bridge.py` seeds `state.knob_values` from
  `state.knobs()` inside the knob-drag throttle test, because
  `AppState` no longer exposes the flat field by default.

## What did NOT change

- HDMI runtime contract: still 1280x720 HDMI signal, 800x480 logical
  frame, `placement="manual"`, `offset_x=0`, `offset_y=0`,
  `dst_x0=0`, `dst_y0=0`, `audio_lab.bit` / `audio_lab.hwh`
  untouched, no Vivado / block-design / Clash / GPIO change.
- `audio_lab_pynq.hdmi_backend.AudioLabHdmiBackend`: unchanged.
- `audio_lab_pynq.notebooks.HdmiGui.ipynb` runtime cell: unchanged.
- Phase 6G strong-UI-bbox diagnostics
  (`scripts/test_hdmi_render_bbox.py`,
  `scripts/test_hdmi_actual_ui_origin_visual.py`,
  `scripts/test_hdmi_800x480_origin_guard.py`): unchanged.
- `HdmiEffectStateMirror` / `AudioLabOverlay` effect APIs: unchanged.
- Notebook-driven realtime pedalboard control: unchanged.

## Verification

Local renderer check after the port (TUBE SCREAMER, `pipboy-green`):

| field | value |
| --- | --- |
| `strong_ui_bbox` | `[24, 776, 20, 454]` |
| `estimated_outer_frame_left_x` | `24` |
| `estimated_header_left_x` | `24` |
| `estimated_chain_left_x` | `24` |
| `estimated_selected_panel_left_x` | `24` |
| `estimated_main_panel_left_x` | `24` |

All values satisfy the Phase 6G pass thresholds
(`strong_ui_bbox.min_x <= 28`, panel-left estimates `<= 40`).

Test suite after the port:

- `tests/test_hdmi_origin_mapping.py`: 8 PASS (3 new, 5 retained).
- `tests/test_hdmi_gui_bridge.py`: PASS with the `knob_values`
  reseed for the knob-drag throttle test.
- `tests/test_hdmi_selected_fx_state.py`: 8 PASS.
- `tests/test_hdmi_model_state_mapping.py`: 13 PASS.

## Bit/hwh decision

No bit/hwh / Vivado / Clash / GPIO / block-design change in `d7ea0ab`.
The port is renderer / AppState / tests only. Deployment is the
standard `bash scripts/deploy_to_pynq.sh` (Python files copied to
`/home/xilinx/Audio-Lab-PYNQ/`); the notebook entry stays
`audio_lab_pynq/notebooks/HdmiGui.ipynb` and reloads
`AudioLabOverlay()` once per session.

## Follow-ups

- Touch / mouse hit-testing: `hit_test_compact_v2` is in place but no
  consumer wires it to a physical input source yet. If a future input
  device is added, this is the entry point.
- Native 800x480 HDMI timing: still deferred (Phase 6I/J candidate)
  and still requires explicit user approval before any Vivado /
  bit/hwh work.
- `(1).py` follow-on tweaks (knob spacing, additional model labels,
  dropdown chip width adjustments): land as renderer-only changes on
  top of this port.
