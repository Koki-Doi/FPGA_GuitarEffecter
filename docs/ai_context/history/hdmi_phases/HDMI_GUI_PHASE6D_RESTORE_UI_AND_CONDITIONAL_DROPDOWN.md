# HDMI GUI Phase 6D — Restore compact UI and add conditional model dropdown

## Why this phase exists

Phase 6C (`b1a4b03`) added a `[model ▼]` dropdown-style chip next to
SELECTED FX on the 800x480 compact-v2 panel. The chip was placed at

```
(s_chip[0] - 12 - 150, fy0 + 18, s_chip[0] - 12, fy0 + 48)
=> (488, 278, 638, 308)
```

inside the FX panel. The ACTIVE MODELS column lives at
`model_x0 = fx0 + 270 = 294`, with PEDAL / AMP / CAB rows at
`y = fy0 + 31 / +49 / +67`, i.e. y = 291 / 309 / 327. The chip's
30 px tall rectangle therefore covered the PEDAL row (y=291) and
intruded into the AMP row (y=309), hiding the live model labels the
user expected to see. On the LCD it read as "UIが全然違う / 各
ステータスの値が消えている".

## What Phase 6D does

* Restore the compact-v2 panel layout to the `0a07f2a` baseline:
  SELECTED FX label + big name on the left, ACTIVE MODELS column in
  the middle (PEDAL / AMP / CAB rows with live labels), ON/BYPASS
  chip on the right. PEDAL MODEL / AMP MODEL / CAB / LEVELS rows
  below render exactly as in `0a07f2a`.
* The standalone `[model ▼]` chip Phase 6C drew over the ACTIVE
  MODELS rows is **removed**.
* When the SELECTED FX has a model-driven category (PEDAL / AMP /
  CAB), the renderer paints a thin outline + small filled triangle
  glyph **around the matching ACTIVE MODELS row** to signal "this
  row is the dropdown-editable model". For the PEDAL row the
  outline's right edge is clipped to `s_chip[0] - 12` so it never
  collides with the ON/BYPASS chip. AMP / CAB rows are below the
  chip and extend to `model_x1 - 4`.
* When the SELECTED FX is REVERB / EQ / COMPRESSOR / NOISE
  SUPPRESSOR / SAFE BYPASS / PRESET / OVERDRIVE, no extra outline /
  glyph is drawn; the row renders identically to `0a07f2a`.
* The notebook ipywidgets remain the *only* way to actually change
  models. HDMI is display-only, as agreed in Phase 6C.

## Renderer helpers

`GUI/pynq_multi_fx_gui.py`:

* `_should_show_selected_model_dropdown(state) -> bool`
* `_selected_model_dropdown_label(state) -> str`
* `_dropdown_category(state) -> str`
* `_draw_dropdown_arrow(draw, xy, color)`

The standalone `_draw_dropdown_chip` helper from Phase 6C is gone.
`AppState` gains `selected_model_dropdown_visible: bool` so external
callers and tests can read the same gating decision the renderer
uses.

## Mirror helpers

`audio_lab_pynq/hdmi_effect_state_mirror.py`:

* `dropdown_label_for(...)` now returns `""` for non-PEDAL/AMP/CAB
  categories so the renderer can use truthiness as a visibility
  flag.
* `dropdown_visible_for(selected_fx) -> bool` is the new public
  helper.
* `_update_dropdown_app_state` sets the AppState fields
  `selected_model_category`, `dropdown_label`, `dropdown_short_label`,
  and the new `selected_model_dropdown_visible`. Non-model effects
  get empty labels and `dropdown_visible = False`.

## Restored status / parameter values

The compact-v2 panel now consistently renders:

* SELECTED FX label, big name, ON/BYPASS chip
* ACTIVE MODELS column (PEDAL / AMP / CAB rows with live labels)
* PEDAL MODEL slot row with active slot highlight
* AMP MODEL slot row with active slot highlight
* CAB slot row with active slot highlight
* LEVELS mini-meters (IN / OUT)
* SIGNAL CHAIN row with per-effect ON/OFF state and SEL ?
* PRESET id / preset name / ACTIVE | SAFE BYPASS status header
* `v=compact-v2` placement label and corner markers

## Dropdown visibility matrix

| SELECTED FX        | Category          | Dropdown visible? |
|--------------------|-------------------|-------------------|
| CLEAN BOOST        | PEDAL             | YES               |
| TUBE SCREAMER      | PEDAL             | YES               |
| RAT                | PEDAL             | YES               |
| DS-1               | PEDAL             | YES               |
| BIG MUFF           | PEDAL             | YES               |
| FUZZ FACE          | PEDAL             | YES               |
| METAL              | PEDAL             | YES               |
| AMP SIM            | AMP               | YES               |
| CAB                | CAB               | YES               |
| REVERB             | REVERB            | NO                |
| EQ                 | EQ                | NO                |
| COMPRESSOR         | COMPRESSOR        | NO                |
| NOISE SUPPRESSOR   | NOISE SUPPRESSOR  | NO                |
| SAFE BYPASS        | SAFE              | NO                |
| PRESET             | PRESET            | NO                |
| OVERDRIVE          | OVERDRIVE         | NO                |

## Local validation

```
python3 -m py_compile GUI/pynq_multi_fx_gui.py
python3 -m py_compile audio_lab_pynq/hdmi_effect_state_mirror.py
python3 -m py_compile scripts/test_hdmi_model_selection_ui.py
python3 -m py_compile scripts/test_hdmi_realtime_pedalboard_controls.py
python3 tests/test_hdmi_selected_fx_state.py         # 8 PASS
python3 tests/test_hdmi_model_state_mapping.py       # 11 PASS
python3 tests/test_hdmi_origin_mapping.py            # 6 PASS
python3 tests/test_hdmi_resource_monitor.py          # 15 PASS
python3 tests/test_hdmi_gui_bridge.py                # exit 0
```

Notebook one-cell shape verified for `HdmiEffectStatusOneCell.ipynb`
and `HdmiRealtimePedalboardOneCell.ipynb`. `git diff --check` clean.

## PYNQ-Z2 run

```
ssh xilinx@192.168.1.9 \
  'cd /home/xilinx/Audio-Lab-PYNQ && \
   sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
     scripts/test_hdmi_model_selection_ui.py \
     --hold-seconds-per-step 1 --final-hold-seconds 4' \
  > /tmp/hdmi_phase6d_restore_ui_dropdown.log
```

Result: `[phase6b] OK`. All 16 steps PASS (7 PEDAL, 3 AMP, 1 CAB,
1 REVERB, 1 COMPRESSOR, 1 NOISE SUPPRESSOR, 1 SAFE BYPASS,
1 PRESET). For each step the script asserts both
`selected_model_dropdown_visible` and the matching dropdown label
against `dropdown_visible_for`.

Observed runtime snapshot:

* `overlay_load_s ~ 2.75 s`
* per-frame `render_s ~ 0.15-0.18 s`
* `compose_s ~ 0.026 s`
* `framebuffer_copy_s ~ 0.21 s`
* `backend_update_s ~ 0.23 s`
* VDMA DMASR `0x00011000` (no halted/idle, no DMA error bits)
* VTC ctl `0x00000006`
* placement `manual`, offset 0,0
* logical 800x480 copied into framebuffer `(x0=0,y0=0,x1=800,y1=480)`
* `ADC HPF true / R19 0x23`

## Files changed

* `GUI/pynq_multi_fx_gui.py`
* `audio_lab_pynq/hdmi_effect_state_mirror.py`
* `scripts/test_hdmi_model_selection_ui.py`
* `tests/test_hdmi_selected_fx_state.py`
* `tests/test_hdmi_model_state_mapping.py`
* `tests/test_hdmi_origin_mapping.py`
* `tests/test_hdmi_resource_monitor.py`
* `docs/ai_context/HDMI_GUI_PHASE6D_RESTORE_UI_AND_CONDITIONAL_DROPDOWN.md` (new)
* `docs/ai_context/CURRENT_STATE.md`
* `docs/ai_context/HDMI_GUI_INTEGRATION_PLAN.md`
* `docs/ai_context/RESUME_PROMPTS.md`

## Files explicitly NOT changed

* `hw/Pynq-Z2/block_design.tcl`
* `hw/Pynq-Z2/audio_lab.xdc`
* `hw/Pynq-Z2/create_project.tcl`
* `hw/Pynq-Z2/bitstreams/audio_lab.bit`
* `hw/Pynq-Z2/bitstreams/audio_lab.hwh`
* `hw/ip/clash/src/LowPassFir.hs`

No Vivado rebuild. No bit/hwh regeneration. The remote PYNQ
`audio_lab.bit` / `audio_lab.hwh` md5 hashes match the local copies
exactly. No `git push` / `git pull` / `git fetch`.

## Open items / not addressed in this phase

* The Notebook-side ipywidgets remain the actual control surface; no
  HDMI-side input was added (per spec).
* The PEDAL-row outline shares the same vertical band as the
  ON/BYPASS chip; it is clipped to `s_chip[0] - 12` instead of being
  pushed onto its own row. If we later want a fuller "chip" look
  (rounded shape + bigger label), we will need to revisit the FX
  panel layout itself, not just the highlight.
