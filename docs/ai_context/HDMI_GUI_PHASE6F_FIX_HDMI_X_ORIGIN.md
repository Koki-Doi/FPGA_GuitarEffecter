# HDMI GUI Phase 6F — Investigate recurring right-shifted GUI

Updated 2026-05-16: the right-shift report was rechecked after the
GitHub-code replacement on branch `feature/hdmi-gui-model-selection-ui`.
The fix stayed Python-only. No bit / hwh / Vivado / Clash / GPIO
change was made.

## Why this phase exists

The user reported the 800x480 HDMI GUI on the 5-inch LCD looked
right-shifted again (large empty strip on the LCD's left edge),
despite the Phase 6G VTC HSync runtime patch (`+150` cycles). The
brief was to walk through the Python pipeline end-to-end and only
escalate to bit/hwh changes if the renderer / backend / notebook
were proven correct.

## Diagnostic pipeline

### Step A — renderer bbox guard (`scripts/test_hdmi_render_bbox.py`, new)

For each of 9 SELECTED FX cases (AMP SIM / CAB / TUBE SCREAMER /
REVERB / COMPRESSOR / NOISE SUPPRESSOR / EQ / SAFE BYPASS / PRESET)
the compact-v2 800x480 renderer paints non-background pixels with
`min_x=0`, `max_x=799`, `min_y=0`, `max_y=477`. The Pip-Boy chassis
reaches both canvas edges; no right-shift at the renderer level.

### Step B — backend compose destination (`scripts/test_hdmi_800x480_origin_guard.py`, expanded)

`compose_logical_frame(..., placement="manual", offset_x=0,
offset_y=0)` produces meta:

| field                              | value     |
|------------------------------------|-----------|
| `placement`                        | `manual`  |
| `offset_x` / `offset_y`            | `0` / `0` |
| `framebuffer_copied_region.x0/y0`  | `0 / 0`   |
| `framebuffer_copied_region.x1/y1`  | `800 / 480` |
| `source_visible_region.width/height` | `800 / 480` |
| `source_visible_region.x0/y0`      | `0 / 0`   |

Phase 6F added explicit top-level `dst_x0`, `dst_y0`, `src_width`,
`src_height` aliases in `AudioLabHdmiBackend.last_frame_write`, and
the guard asserts those aliases plus `source_visible_region`.
Any regression that re-introduces center placement / fit-XX scaling /
wrong source size now fails before relying on visual inspection.

2026-05-16 local dry-run result:

- renderer bbox: `(0, 799, 0, 479)`
- `placement="manual"`, `offset_x=0`, `offset_y=0`
- `dst_x0=0`, `dst_y0=0`, `src_width=800`, `src_height=480`
- `framebuffer_copied_region=(0,0,800,480)`
- `source_visible_region=(0,0,800,480)`

### Step C — runtime confirmation on PYNQ

- Renderer bbox guard 9/9 PASS on the board.
- Origin guard PASS (`[phase6c-guard] OK`, 0 failures) with the
  full live HDMI path. Smoke check shows ADC HPF true, R19 0x23,
  axi_vdma_hdmi / v_tc_hdmi in `ip_dict`, rgb2dvi_hdmi in HWH.
- `scripts/test_hdmi_model_selection_ui.py` 16/16 PASS with
  `vtc_ctl=0x00000006`, `DMASR=0x00011000` (no halted / idle /
  dmainterr / dmaslverr / dmadecerr bits), per-frame
  `render_s ~0.15-0.18 s`, `compose_s ~0.026 s`,
  `framebuffer_copy_s ~0.21 s`, `placement=manual`,
  `offset_x=0`, `offset_y=0`.

2026-05-16 runtime confirmation on PYNQ:

- Origin guard PASS with the full live HDMI path.
- Renderer bbox: `(0, 799, 0, 479)`.
- `last_frame_write`: `placement=manual`, `offset_x=0`,
  `offset_y=0`, `dst_x0=0`, `dst_y0=0`, `src_width=800`,
  `src_height=480`.
- Framebuffer probe after the synthetic origin frame:
  `shape=[720,1280,3]`, `nonzero_bbox=[0,799,0,479]`,
  `outside_800x480_sum=0`, `x0_column_sum=161230`,
  `x10_column_sum=236912`, `x20_column_sum=149255`,
  `x240_column_sum=14741`, `x799_column_sum=259425`,
  `x800_column_sum=0`.
- Smoke check: ADC HPF true, R19 `0x23`, `axi_vdma_hdmi` /
  `v_tc_hdmi` present, `rgb2dvi_hdmi` present in HWH.
- HDMI status: `vtc_ctl=0x00000006`, `vtc_gen_hsync=0x0596056e`,
  `vtc_hsync_shift=0`, no VDMA internal / slave / decode error bits.
- Origin-test compose/copy: `0.0274 s` / `0.2386 s`.

The Python pipeline is therefore proven correct through actual
framebuffer contents. If the LCD image still appears right-shifted,
the offset is downstream of the 1280x720 framebuffer copy.

### Step D — VTC HSync sweep (`scripts/test_hdmi_vtc_hsync_sweep.py`, new)

To check whether the LCD viewport responds to HSync timing, the
sweep wrote `GEN_HSYNC` with shifts `0, +50, +100, +150, +200,
+300, -150` cycles, held each for 8 s on the LCD, and displayed a
labeled calibration pattern (orange left border, green right
border, `x=NN` label every 100 px on the top and bottom edges,
`HSYNC SHIFT = +N` legend in the top center).

User feedback: `shift = 0` (= IP-baked default,
`HSTART=1390 HEND=1430 back_porch=220`) produced the cleanest
LCD alignment. The Phase 6G `+150` shift did not improve the LCD
view; non-zero shifts either had no visible effect or made things
worse.

## Resolution

Phase 6F rolls back `VTC_HSYNC_SHIFT_DEFAULT` in
`audio_lab_pynq/hdmi_backend.py` from `150` to `0`. The runtime
override hook is retained (env var
`AUDIOLAB_HDMI_HSYNC_SHIFT` and constructor kwarg `hsync_shift=N`)
so a future LCD with a different sync-recovery characteristic can
be compensated without code changes, and `backend.status()` still
exposes `vtc_gen_hsync`, `vtc_hsync_shift`, `vtc_original_hsync`,
`vtc_patched_hsync` for diagnostics.

No bit / hwh / Vivado / Clash change. The Python pipeline is
correct; further LCD alignment work, if needed, would be a
hardware-side investigation (LCD HDMI receiver scaling / EDID /
panel offset) that is out of scope here.

For the 2026-05-16 recurrence, no renderer coordinates, notebook
offsets, backend placement behavior, bitstream, or HSync timing were
changed. The only code-side change was diagnostic hardening:

- `audio_lab_pynq/hdmi_backend.py` exposes top-level `dst_*` and
  `src_*` fields in `last_frame_write`.
- `scripts/test_hdmi_800x480_origin_guard.py` asserts those fields and
  probes the actual DDR framebuffer for the `[0,799] x [0,479]`
  non-black bbox.
- `tests/test_hdmi_origin_mapping.py` asserts the same compose fields.

## UI / functionality preserved

- Pip-Boy compact-v2 800x480 panel: phosphor green palette
  (`DEFAULT_800X480_THEME = "pipboy-green"`), dark gradient,
  scanline overlay, rounded chassis frame at
  `outer=(12,12,788,468)` / `left=24` / `right=24`, amber
  `BYPASS_COL`, corner markers, `v=compact-v2` placement label.
- Header: PRESET id + name + ACTIVE | SAFE BYPASS chip.
- SIGNAL CHAIN row with the 8 effect slots, per-effect ON/OFF
  state, SEL marker.
- SELECTED FX label + big name + ON/BYPASS chip.
- ACTIVE MODELS column with PEDAL / AMP / CAB live labels and the
  Phase 6D conditional dropdown marker (PEDAL / AMP / CAB only).
- Per-effect parameter knob grid: Noise Suppressor THRESHOLD /
  DECAY / DAMP, Compressor THRESHOLD / RATIO / RESPONSE / MAKEUP,
  Overdrive TONE / LEVEL / DRIVE, Distortion Pedalboard TONE /
  LEVEL / DRIVE / BIAS / TIGHT / MIX, RAT FILTER / LEVEL / DRIVE
  / MIX, Amp Simulator GAIN / BASS / MIDDLE / TREBLE / PRESENCE /
  RESONANCE / MASTER / CHARACTER, Cab IR MIX / LEVEL / MODEL /
  AIR, EQ LOW / MID / HIGH, Reverb DECAY / TONE / MIX.
- SAFE BYPASS / PRESET: `NO  PARAMETERS` notice; everything else
  intact.
- IN / OUT LEVELS meters anchored on the right.
- Notebook ipywidgets remain the sole control surface;
  `HdmiEffectStateMirror` -> `AudioLabOverlay.set_*` -> real DSP
  edit on every interaction. HDMI is display-only.
- 800x480 framebuffer destination at `(0,0,800,480)`,
  `placement="manual"`, `offset_x=0`, `offset_y=0`.

## Files

New:

- `scripts/test_hdmi_render_bbox.py` --- renderer bbox guard.
- `scripts/test_hdmi_vtc_hsync_sweep.py` --- HSync sweep with
  labeled calibration pattern and SIGINT-safe restore.
- `docs/ai_context/HDMI_GUI_PHASE6F_FIX_HDMI_X_ORIGIN.md` (this
  doc).

Modified:

- `audio_lab_pynq/hdmi_backend.py` --- `VTC_HSYNC_SHIFT_DEFAULT = 0`
  (Phase 6G rolled back); override hook + status() fields retained.
- `scripts/test_hdmi_800x480_origin_guard.py` --- added
  `source_visible_region.width/height/x0/y0` asserts.
- `docs/ai_context/CURRENT_STATE.md` / `HDMI_GUI_INTEGRATION_PLAN.md`
  / `RESUME_PROMPTS.md` --- Phase 6F notes.

Not changed:

- `hw/Pynq-Z2/block_design.tcl`, `audio_lab.xdc`,
  `create_project.tcl`, `bitstreams/audio_lab.bit`,
  `bitstreams/audio_lab.hwh`, `hw/ip/clash/src/LowPassFir.hs`.
- GUI renderer / mirror / notebooks (renderer + mirror untouched
  in Phase 6F since the renderer/mirror were proven correct).
- Remote PYNQ `audio_lab.bit` / `audio_lab.hwh` md5 still match
  local (`9ba72e48...` / `162e6e41...`).

## PYNQ runtime snapshot

```
ssh xilinx@192.168.1.9 \
  'cd /home/xilinx/Audio-Lab-PYNQ && \
   sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
     scripts/test_hdmi_model_selection_ui.py \
     --hold-seconds-per-step 0.8 --final-hold-seconds 6'
```

Result: `[phase6b] OK`, 16/16 PASS, `vtc_hsync_shift=0`,
`vtc_gen_hsync=0x0596056e` (= IP default), `vtc_ctl=0x00000006`,
`DMASR=0x00011000`, framebuffer `(0,0,800,480)`, placement
`manual`, offset `(0,0)`, ADC HPF true, R19 0x23.

2026-05-16 rerun:

- `scripts/test_hdmi_800x480_origin_guard.py --hold-seconds 30`:
  PASS, `nonzero_bbox=[0,799,0,479]`,
  `outside_800x480_sum=0`, `dst_x0=0`, `dst_y0=0`,
  `src_width=800`, `src_height=480`.
- `scripts/test_hdmi_model_selection_ui.py --hold-seconds-per-step 1
  --final-hold-seconds 10`: PASS 16/16. PEDAL / AMP / CAB showed the
  conditional dropdown; REVERB / COMPRESSOR / NOISE SUPPRESSOR /
  SAFE BYPASS / PRESET hid it. Final frame:
  `render_s=0.1654`, `compose_s=0.0283`, `framebuffer_copy_s=0.2310`,
  `DMASR=0x00011000`, `vtc_ctl=0x00000006`,
  `dst_x0=0`, `dst_y0=0`.
- `scripts/test_hdmi_realtime_pedalboard_controls.py
  --hold-seconds-per-step 1 --final-hold-seconds 10`: PASS 16/16.
  Notebook-equivalent operations still call the real
  `AudioLabOverlay` DSP API through `HdmiEffectStateMirror`.
  Final resource summary: `render_s=0.1629`, `compose_s=0.0281`,
  `framebuffer_copy_s=0.2350`, `total_update_s=0.4280`,
  `DMASR=0x00011000`, `vtc_ctl=0x00000006`,
  `dst_x0=0`, `dst_y0=0`.

Local 2026-05-16 validation:

- `py_compile` for the renderer, backend, mirror, and HDMI scripts:
  PASS.
- `tests/test_hdmi_selected_fx_state.py`: 8 PASS.
- `tests/test_hdmi_model_state_mapping.py`: 13 PASS.
- `tests/test_hdmi_origin_mapping.py`: 7 PASS.
- `scripts/test_hdmi_render_bbox.py`: 9/9 PASS,
  bbox min_x `0`, max_x `799`.
- `scripts/test_hdmi_800x480_origin_guard.py --dry-run`: PASS.
- `git diff --check`: PASS.
- Vivado tracked files stayed clean:
  `block_design.tcl`, `audio_lab.xdc`, `create_project.tcl`,
  `audio_lab.bit`, `audio_lab.hwh`.

## Open items / not addressed

- The user's reported LCD right-shift, if still present at
  `shift=0`, is not reproducible through software --- the
  renderer / backend / VTC layer is correct, and the LCD did not
  respond to HSync sweeps. Further investigation would need the
  LCD's own configuration (HDMI EDID, scaling mode, panel
  offset) and is outside the scope of Phase 6F.
- bit/hwh changes were not made and not proposed. The
  Phase 6F sweep result (no visible HSync response) suggests
  HDMI signal timing is not the lever; a bit/hwh-level change
  would have the same null effect.
