# HDMI GUI Phase 6G — Actual compact UI x-origin

## Status (2026-05-16)

Phase 6G shipped a stronger renderer-side x-origin diagnostic but its
specific renderer coordinate-tightening (outer `x=4..796`, header
`x=8..792`, chain / selected-FX `x=12..788`, plus a deliberate
`x=0..1` phosphor rail) was rolled back the same day by commit
`d7ea0ab` ("Port compact-v2 HDMI GUI to (1).py spec and enlarge model
labels"). The (1).py spec is the official compact-v2 layout going
forward and reuses the Phase 4G / 4I baseline coordinates
(outer `(12, 12, 788, 468)`, header / chain / fx panels at `left=24`,
`right=24`). The Phase 6G strong-UI-bbox detector and the actual-UI
visual test were kept; only the renderer x-tightening reverted. See
`docs/ai_context/HDMI_GUI_PHASE6H_PORT_1PY_SPEC.md` for the port.

## Why Phase 6F was insufficient

Phase 6F proved the 800x480 logical frame was copied to the
1280x720 framebuffer at `dst_x0=0`, `dst_y0=0`, and that the DDR
framebuffer had non-black pixels in `[0,799] x [0,479]`. That was not
enough to prove the **actual compact UI panel body** started near x=0.

The old checks could pass when any of these touched x=0:

- dark background pixels different from the assumed background color
- scanline overlay
- synthetic origin-guard markers
- corner markers
- full-frame decorative noise or rails

The user-visible bug was different: the main panel / outer frame /
status content appeared to start far to the right. Phase 6G therefore
added a detector that looks at strong UI strokes and panel borders, not
only "anything non-background".

## Renderer layout fix (intermediate, rolled back by d7ea0ab)

Phase 6G initially shifted only the internal renderer x-origin:

| UI element | Before (Phase 4G/4I) | Phase 6G intermediate |
| --- | ---: | ---: |
| full chassis outer frame | `x=12..788` | `x=4..796` |
| header panel | `x=24..776` | `x=8..792` |
| chain panel | `x=24..776` | `x=12..788` |
| selected-FX / parameter panel | `x=24..776` | `x=12..788` |
| normal left UI rail | corner marker only | `x=0..1` plus `x=2` rail |
| top / bottom rails | corner markers only | `y=0..1`, `y=478..479` |

This was not a backend offset and not a fit/center workaround. The HDMI
backend still wrote the 800x480 frame at manual `offset_x=0`,
`offset_y=0`, `dst_x0=0`, `dst_y0=0`. The change was renderer-only and
preserved `audio_lab.bit` / `audio_lab.hwh`.

`d7ea0ab` restored the Phase 4G / 4I baseline coordinates as part of
the (1).py spec port:

| UI element | Phase 6G intermediate | d7ea0ab (current) |
| --- | ---: | ---: |
| full chassis outer frame | `x=4..796` | `x=12..788` |
| header / chain / selected-FX panels | `x=8..792` / `x=12..788` | `x=24..776` |
| normal left UI rail / top / bottom rails | explicit `x=0..1` rail | corner markers only |

The current `strong_ui_bbox` is `[24, 776, 20, 454]` for the live
PYNQ pipboy-green render, with all four estimated panel-left values at
`x=24`. That is still inside the Phase 6G `<=40` pass threshold, so the
diagnostic survives the rollback.

## Strong UI bbox diagnostics (retained)

`scripts/test_hdmi_render_bbox.py` was rewritten in Phase 6G and is
still the active diagnostic. It still prints the old non-background
bbox for reference, but PASS/FAIL now comes from:

- `strong_ui_bbox`
- `vertical_border_candidates`
- `horizontal_border_candidates`
- `estimated_outer_frame_left_x`
- `estimated_header_left_x`
- `estimated_chain_left_x`
- `estimated_selected_panel_left_x`
- `estimated_main_panel_left_x`

The detector thresholds bright phosphor / amber UI strokes and then
looks for continuous vertical and horizontal border candidates. It
ignores the old "anything non-background" criterion as a pass condition.

Local results for the current (`d7ea0ab`) renderer, SELECTED FX = TUBE
SCREAMER, theme `pipboy-green`:

| field | value |
| --- | --- |
| `strong_ui_bbox` | `[24, 776, 20, 454]` |
| `estimated_outer_frame_left_x` | `24` |
| `estimated_header_left_x` | `24` |
| `estimated_chain_left_x` | `24` |
| `estimated_selected_panel_left_x` | `24` |
| `estimated_main_panel_left_x` | `24` |

The pass thresholds are `strong_ui_bbox.min_x <= 28` and
`estimated_main_panel_left_x <= 40` / `estimated_selected_panel_left_x
<= 40`. The measured `24` clears both, so the (1).py spec coordinates
satisfy the Phase 6G content-origin contract without needing the
intermediate tighter coordinates.

PYNQ results captured during the original intermediate run (before
rollback) for reference: `estimated_main_panel_left_x=4`,
`estimated_header_left_x=8`, `estimated_selected_panel_left_x=12` for
every tested SELECTED FX (AMP SIM / CAB / TUBE SCREAMER / REVERB /
COMPRESSOR / NOISE SUPPRESSOR / EQ / SAFE BYPASS / PRESET).

## Actual UI visual test (retained)

New script:

- `scripts/test_hdmi_actual_ui_origin_visual.py`

It renders the real compact-v2 UI, then overlays small coordinate aids:

- left label `X0`
- right label `X799`
- ticks at `x=0`, `x=10`, `x=20`, `x=40`, `x=799`

This is for physical LCD judgement. If `X0` and the visible left edge of
the GUI body align with the LCD's left edge, Python renderer/backend
origin is correct. If `X0` is still shifted right or hidden while the
script reports x=0 placement, the remaining problem is downstream HDMI
timing / LCD receiver mapping rather than Python renderer geometry.

PYNQ command run (intermediate Phase 6G state):

```sh
sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
  scripts/test_hdmi_actual_ui_origin_visual.py \
  --hold-seconds 60 --selected-fx CAB
```

Result (intermediate state, pre-rollback):

- PASS, 0 failures.
- strong UI analysis: `main_x=4`, `header_x=8`, `selected_x=12`.
- `last_frame_write`: `placement=manual`, `offset_x=0`,
  `offset_y=0`, `dst_x0=0`, `dst_y0=0`, `src_width=800`,
  `src_height=480`.
- framebuffer probe: `nonzero_bbox=[0,799,0,479]`,
  `outside_800x480_sum=0`, `x0_column_sum=142608`,
  `x10_column_sum=47192`, `x20_column_sum=51731`,
  `x40_column_sum=76336`, `x799_column_sum=51806`,
  `x800_column_sum=0`.
- VDMA: no internal / slave / decode error bits,
  `DMASR=0x00010000` during the static visual hold.
- VTC: `vtc_ctl=0x00000006`, `vtc_gen_hsync=0x0596056e`,
  `vtc_hsync_shift=0`.
- compose/copy: `0.0274 s` / `0.2800 s`.

After `d7ea0ab` the same test still PASSes locally / on PYNQ; the
strong-UI-bbox values shift to `main_x=24, header_x=24, selected_x=24`
but remain well under the `<=40` thresholds, so no LCD-side regression
is expected versus the Phase 6G intermediate state.

LCD physical visual result is not observable over SSH. The frame is
held for 60 seconds specifically so the LCD photo can decide whether
`X0` appears at the left edge.

## Model UI / DSP control preservation

PYNQ model-selection replay run during the intermediate state:

- `scripts/test_hdmi_model_selection_ui.py --hold-seconds-per-step 1
  --final-hold-seconds 10`
- Result: 16/16 PASS, 0 failures.
- PEDAL / AMP / CAB show the conditional dropdown marker.
- REVERB / COMPRESSOR / NOISE SUPPRESSOR / SAFE BYPASS / PRESET hide it.
- Final `last_frame_write`: `dst_x0=0`, `dst_y0=0`,
  `src_width=800`, `src_height=480`.
- Final VDMA: `DMASR=0x00011000`, no internal / slave / decode error
  bits.
- Final VTC: `vtc_ctl=0x00000006`.
- Final render/compose/copy: `0.1567 s` / `0.0362 s` / `0.2362 s`.
- ADC HPF true, R19 `0x23`.

After `d7ea0ab` the Notebook / real DSP control path is unchanged:
`HdmiEffectStateMirror` still calls the existing `AudioLabOverlay`
effect APIs and then renders the HDMI GUI. HDMI remains display-only.
The (1).py port also moved PEDAL / AMP / CAB dropdown rendering inline
inside `_render_frame_800x480_compact_v2`, removing the
`_should_show_selected_model_dropdown`, `_selected_model_dropdown_label`,
`_dropdown_short`, and `_pedal/amp/cab_label` helpers, but the same
PEDAL / AMP / CAB ↔ dropdown visibility contract is preserved.

## Local validation (Phase 6G intermediate state)

- `py_compile`: renderer, backend, mirror, render bbox script, origin
  guard, actual UI visual script, model-selection script all PASS.
- `scripts/test_hdmi_render_bbox.py`: 9/9 PASS.
- `scripts/test_hdmi_actual_ui_origin_visual.py --dry-run
  --selected-fx CAB`: PASS.
- `scripts/test_hdmi_800x480_origin_guard.py --dry-run`: PASS with
  strong UI checks.
- `tests/test_hdmi_selected_fx_state.py`: 8 PASS.
- `tests/test_hdmi_model_state_mapping.py`: 13 PASS.
- `tests/test_hdmi_origin_mapping.py`: 8 PASS.
- `git diff --check`: PASS.

Post-`d7ea0ab` the test set has been updated to the (1).py spec
(`outer.x0==12`, `header/chain/fx.x0==24`,
`strong_ui_bbox.min_x <= 28`) and continues to PASS locally. See
`docs/ai_context/HDMI_GUI_PHASE6H_PORT_1PY_SPEC.md`.

## Bit/hwh decision

No bit/hwh / Vivado / Clash / GPIO / block-design change was made in
Phase 6G or in the `d7ea0ab` (1).py spec port that supersedes it.

Phase 6G fixed the renderer's actual content x-origin first, as
requested, and the (1).py port retained the same `x=0,y=0` framebuffer
contract. If a new LCD photo still shows `X0` shifted right or a large
left blank area while the script reports the panel x-origins in the
`<=40` range, the diagnosis should stop treating Python as the cause
and evaluate native 800x480 HDMI timing as a future Phase 6I/J:

- VTC active area: H=800, V=480
- VDMA HSIZE/STRIDE: `2400` bytes
- VDMA VSIZE: `480`
- pixel clock / porch / sync candidates for the specific LCD
- Digilent `rgb2dvi` clock-range compatibility
- timing closure risk and rollback plan

That bit/hwh path needs explicit user confirmation before implementation.
