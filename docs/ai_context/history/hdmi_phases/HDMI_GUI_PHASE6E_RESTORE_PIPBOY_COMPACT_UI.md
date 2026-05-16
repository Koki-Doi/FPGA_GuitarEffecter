# HDMI GUI Phase 6E — Restore Pip-Boy compact UI with conditional model dropdown

## Why this phase exists

The compact-v2 800x480 fx panel had drifted from the Phase 4G/5D
Pip-Boy baseline through Phase 6C (which dropped a 150x30 dropdown
chip over the ACTIVE MODELS column) and Phase 6F (which retuned the
chassis margins to compensate the LCD viewport). The user reported
that the result no longer matched the original Pip-Boy compact UI:
status values were occluded, the chassis layout looked unfamiliar,
and the dropdown was always visible regardless of SELECTED FX.

Phase 6E consolidates the Phase 6D conditional-dropdown work
(commit `f90ba07`), the Phase 6E per-effect knob grid (commit
`ea68bbe`), the Phase 6F chassis-shift rollback (uncommitted prior
to this doc), and the Phase 6G VTC HSync runtime shift into a
single "restored Pip-Boy compact-v2 UI" baseline.

## Pip-Boy visual elements preserved

`GUI/pynq_multi_fx_gui.py`:

- `DEFAULT_800X480_THEME = "pipboy-green"` -- phosphor green palette
  (`LED`, `LED_SOFT`, `LED_DIM`).
- `PIPBOY_THEME` dict with dark gradient `BG_GRAD`, panel fills, chip
  fills, amber `BYPASS_COL` warning color.
- `_apply_scanlines_inplace(arr, SCANLINE_STEP, SCANLINE_RGBA)`
  applied as the final pass before the framebuffer copy, giving the
  CRT scanline overlay.
- Rounded chassis frame at the Phase 4G `outer=(12,12,788,468)` /
  `left=24` / `right=24` coordinates (Phase 6F's tightened chassis
  rolled back here -- the LCD shift fix moved to the VTC layer in
  Phase 6G instead).
- TL / TR / BL / BR corner markers + `v=compact-v2` placement label
  along the bottom of the canvas.

## Restored status values

Every render of the compact-v2 800x480 panel paints:

- Header band: PRESET id (`02A`), preset name (`BASIC CLEAN`),
  ACTIVE | SAFE BYPASS status chip.
- SIGNAL CHAIN row with the 8 effect slots, per-effect ON/OFF state
  (filled vs. dim), SEL marker for the selected effect.
- SELECTED FX label + large name, ON/BYPASS chip on the right.
- ACTIVE MODELS column: PEDAL / AMP / CAB rows with live model
  labels (`TUBE SCRMR`, `BRIT CRUNCH`, `4X12 CLOSED`, etc.).
- Per-effect parameter knob grid driven by
  `SELECTED_FX_PARAM_LAYOUT`. Each cell shows label, numeric
  percent, and a horizontal value bar.
- LEVELS section with IN / OUT meters.
- SAFE BYPASS / PRESET show a `NO  PARAMETERS` notice with the rest
  of the panel intact.

## Conditional [model ▼] marker

`_should_show_selected_model_dropdown(state) -> bool` returns True
only when SELECTED FX is PEDAL / AMP / CAB family. For those
categories, the renderer paints a thin outline + filled-triangle
glyph around the matching ACTIVE MODELS row -- it never overlaps
the ON/BYPASS chip (the PEDAL row's right edge clips at
`s_chip[0] - 12`). Other categories produce no marker; the
ACTIVE MODELS rows render identically to the `0a07f2a` baseline.

Visibility matrix:

| SELECTED FX        | Category          | Dropdown marker? |
|--------------------|-------------------|------------------|
| CLEAN BOOST        | PEDAL             | visible          |
| TUBE SCREAMER      | PEDAL             | visible          |
| RAT                | PEDAL             | visible          |
| DS-1               | PEDAL             | visible          |
| BIG MUFF           | PEDAL             | visible          |
| FUZZ FACE          | PEDAL             | visible          |
| METAL              | PEDAL             | visible          |
| AMP SIM            | AMP               | visible          |
| CAB                | CAB               | visible          |
| REVERB             | REVERB            | hidden           |
| EQ                 | EQ                | hidden           |
| COMPRESSOR         | COMPRESSOR        | hidden           |
| NOISE SUPPRESSOR   | NOISE SUPPRESSOR  | hidden           |
| SAFE BYPASS        | SAFE              | hidden           |
| PRESET             | PRESET            | hidden           |
| OVERDRIVE          | OVERDRIVE         | hidden           |

The short label dict (`TUBE SCRMR`, `CLN BOOST`, `BRIT CRUNCH`,
`HI-GAIN`, `1x12 OPN`, `2x12 CMB`, `4x12 CLS`, etc.) is used by the
mirror's `dropdown_short_label(...)` so a future Notebook widget /
status panel can show the chip text without re-deriving it.

## Notebook + DSP control preserved

`HdmiEffectStateMirror` and `audio_lab_pynq/AudioLabOverlay` flows
are untouched. The Notebook `HdmiRealtimePedalboardOneCell.ipynb`
keeps its category dropdown, model dropdown, ON/OFF toggles, and
parameter sliders. Every widget edit:

1. Calls a `HdmiEffectStateMirror` method.
2. Mirror calls `AudioLabOverlay.set_*` -- real DSP update via the
   existing axi_gpio_* IPs (no bit/hwh change).
3. Mirror updates AppState (`selected_fx`,
   `selected_model_category`, `dropdown_label`,
   `selected_model_dropdown_visible`, model labels, knob_values).
4. Mirror triggers the HDMI render at `placement="manual"`,
   `offset_x=0`, `offset_y=0`.

`HdmiEffectStateMirror.summary()` / `resource_summary()` still
return the live PS/GUI/HDMI snapshot for the Notebook panel.

## VTC HSync shift (Phase 6G; preserved here)

`audio_lab_pynq/hdmi_backend.py::_start_vtc` patches the AXI VTC
`GEN_HSYNC` register from the IP-baked
`HSTART=1390, HEND=1430` (back porch 220) to
`HSTART=1540, HEND=1580` (back porch 70) so the LCD viewport aligns
source `x=0` with LCD `x=0`. This is a runtime MMIO write only --
no bit / hwh / Vivado / Clash change. `AUDIOLAB_HDMI_HSYNC_SHIFT=0`
disables the patch; passing `hsync_shift=N` to the constructor
overrides the default. `backend.status()` exposes `vtc_gen_hsync`,
`vtc_hsync_shift`, `vtc_original_hsync`, and `vtc_patched_hsync`
for diagnostics.

The framebuffer destination stays at `(0, 0, 800, 480)`. No
`offset_x` / `offset_y` compensation, no center placement, no
fit-XX scaling. The HDMI signal is still 1280x720; only the HSync
position within each line changed.

## Files referenced / restored against

Pip-Boy baseline: commit `2e6a439` ("Add Pip-Boy inspired green
HDMI GUI theme"). Theme palette and scanline pass have been intact
since then.

Phase 4G compact-v2 layout: commit `0a07f2a` (latest known-good
chassis margins prior to Phase 6F).

Phase 6D conditional dropdown: commit `f90ba07`.

Phase 6E per-effect knob grid: commit `ea68bbe`.

Phase 6F chassis tighten: rolled back to the `0a07f2a` margins in
this phase because the renderer-level shift was the wrong layer.

Phase 6G VTC HSync shift: in `audio_lab_pynq/hdmi_backend.py`
(this phase), with diagnostic scripts at
`scripts/test_hdmi_800x480_viewport_calibration.py`,
`scripts/test_hdmi_vtc_dump.py`,
`scripts/test_hdmi_vtc_hsync_shift.py`.

## Local validation

```
python3 -m py_compile GUI/pynq_multi_fx_gui.py
python3 -m py_compile audio_lab_pynq/hdmi_effect_state_mirror.py
python3 -m py_compile audio_lab_pynq/hdmi_backend.py
python3 -m py_compile scripts/test_hdmi_model_selection_ui.py
python3 -m py_compile scripts/test_hdmi_realtime_pedalboard_controls.py
python3 tests/test_hdmi_selected_fx_state.py         # 8 PASS
python3 tests/test_hdmi_model_state_mapping.py       # 13 PASS
python3 tests/test_hdmi_origin_mapping.py            # 7 PASS
python3 tests/test_hdmi_resource_monitor.py          # 15 PASS
python3 tests/test_hdmi_gui_bridge.py                # exit 0
```

Notebook one-cell shape preserved for both HDMI notebooks.
`git diff --check` clean.

## Hard constraints honoured

- `hw/Pynq-Z2/block_design.tcl` unchanged.
- `hw/Pynq-Z2/audio_lab.xdc` unchanged.
- `hw/Pynq-Z2/create_project.tcl` unchanged.
- `hw/Pynq-Z2/bitstreams/audio_lab.bit` unchanged
  (md5 `9ba72e48...`).
- `hw/Pynq-Z2/bitstreams/audio_lab.hwh` unchanged
  (md5 `162e6e41...`).
- `hw/ip/clash/src/LowPassFir.hs` unchanged.
- 800x480 framebuffer destination `(0, 0, 800, 480)`, placement
  `manual`, offset `(0, 0)`.
- `Overlay("base.bit")`, `run_pynq_hdmi()`, second-overlay loads
  not used.
- No `git push` / `git pull` / `git fetch`.

## Open items / not addressed in this phase

- The Phase 6G VTC HSync shift assumes the IP-baked back porch is
  220 cycles (standard 720p60). If a future bit/hwh rebuild changes
  that, the +150 default may need re-tuning. The shift is
  parameterised via env var / constructor argument so the override
  is straightforward.
- The diagnostic scripts (`test_hdmi_vtc_dump.py`,
  `test_hdmi_vtc_hsync_shift.py`,
  `test_hdmi_800x480_viewport_calibration.py`) are kept under
  `scripts/` for repeat measurements; they are not wired into the
  unit-test suite.
