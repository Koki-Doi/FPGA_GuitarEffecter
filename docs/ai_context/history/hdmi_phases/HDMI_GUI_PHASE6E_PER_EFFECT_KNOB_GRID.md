# HDMI GUI Phase 6E — Per-effect knob grid + AMP presence/resonance

## Why this phase exists

Phase 6D restored the compact-v2 layout from `0a07f2a` and added a
conditional dropdown marker around the matching ACTIVE MODELS row.
Phase 6D's bottom panel still showed `PEDAL MODEL` / `AMP MODEL` /
`CAB` slot rows with abbreviated model names (`CLEAN`, `TS`, `RAT`,
`DS1`, `MUFF`, `FUZZ`, `METAL`, `JC`, `CLEAN`, `BRIT`, `HIGH`,
`1x12`, `2x12`, `4x12`). The user asked for per-effect parameter
labels instead:

| SELECTED FX        | Parameters                                         |
|--------------------|----------------------------------------------------|
| Noise Suppressor   | THRESHOLD, DECAY, DAMP                             |
| Compressor         | THRESHOLD, RATIO, RESPONSE, MAKEUP                 |
| Overdrive          | TONE, LEVEL, DRIVE                                 |
| Distortion Pedalboard | TONE, LEVEL, DRIVE, BIAS, TIGHT, MIX            |
| RAT Distortion     | FILTER, LEVEL, DRIVE, MIX                          |
| Amp Simulator      | GAIN, BASS, MIDDLE, TREBLE, PRESENCE, RESONANCE, MASTER, CHARACTER |
| Cab IR             | MIX, LEVEL, MODEL, AIR                             |
| EQ                 | LOW, MID, HIGH                                     |
| Reverb             | DECAY, TONE, MIX                                   |

## What Phase 6E does

* Replaces the `_slot_row` PEDAL MODEL / AMP MODEL / CAB rows in
  `_render_frame_800x480_compact_v2` with a per-SELECTED-FX knob
  grid. Each cell shows: parameter label (top-left), numeric percent
  (top-right), and a horizontal value bar (bottom). The grid adapts
  to the parameter count:
  - 3 knobs -> 3x1 (NS / OD / EQ / REVERB)
  - 4 knobs -> 2x2 (CMP / RAT / CAB)
  - 6 knobs -> 3x2 (Distortion + all pedal sub-models)
  - 8 knobs -> 4x2 (AMP SIM)
* SELECTED FX = SAFE BYPASS / PRESET renders the panel with a small
  `NO  PARAMETERS` notice and no knob cells.
* ACTIVE MODELS column (PEDAL / AMP / CAB rows with live model
  labels and the Phase 6D conditional dropdown marker) is preserved.
* SELECTED FX label + big name + ON/BYPASS chip + IN/OUT LEVELS
  meters are unchanged from Phase 6D.

## AMP SIM expansion (8 knobs, no bit/hwh change)

PRESENCE and RESONANCE were already wired in the DSP via
`axi_gpio_amp.ctrlC` / `axi_gpio_amp.ctrlD` on `fAmp` in
`hw/ip/clash/src/AudioLab/Effects/Amp.hs`, and exposed by
`AudioLabOverlay.set_guitar_effects(amp_presence=..., amp_resonance=...)`.
Phase 6E reorganises the AppState `knob_values` layout so the
existing DSP capability surfaces in the Notebook + HDMI GUI:

| Slot | Phase 6D AMP | Phase 6E AMP |
|------|--------------|--------------|
| 0    | gain         | gain         |
| 1    | bass         | bass         |
| 2    | mid          | middle       |
| 3    | treble       | treble       |
| 4    | master       | **presence** |
| 5    | character    | **resonance**|
| 6    | (unused)     | master       |
| 7    | (unused)     | character    |

`AppState.knob_values` default is now `[45, 55, 60, 50, 45, 35, 70,
60]` (length 8). Effects with fewer than 8 knobs leave the extra
slots at 0. `load_state_json` pads short legacy snapshots from 6 to
8 on load.

`HdmiEffectStateMirror._set_knobs` and
`_set_effect_index_for_selected_fx` now compare against length 8 and
clamp `knob_index < 8`. The mirror's
`_apply_guitar_effects_state(... "AMP SIM" ...)` maps
`amp_presence` -> idx 4, `amp_resonance` -> idx 5, `amp_master` ->
idx 6, `amp_character` -> idx 7. Pre-existing `set_amp_model(...)`
and `jc_clean / clean_combo / british_crunch / high_gain_stack(...)`
already accepted `presence=` / `resonance=` kwargs and forward them
to `AudioLabOverlay.set_amp_model` / `set_guitar_effects`, so they
hit the DSP directly with no change.

## Per-FX param layout API

`GUI/pynq_multi_fx_gui.py`:

* `SELECTED_FX_PARAM_LAYOUT` -- dict mapping canonical SELECTED FX
  to a list of `(label, knob_values_index)`.
* `selected_fx_param_layout(state)` -- public helper resolving the
  list from a state. Used by tests and any future widget that wants
  to show the same labels as the panel.

The display ordering decouples from the underlying `knob_values`
indices. Overdrive / Distortion / RAT use the user-requested order
(TONE / LEVEL / DRIVE / ...) while keeping the existing knob slot
mapping written by the mirror. Pedal sub-models (CLEAN BOOST,
TUBE SCREAMER, DS-1, BIG MUFF, FUZZ FACE, METAL) reuse the
Distortion Pedalboard layout; RAT has its own FILTER / LEVEL /
DRIVE / MIX layout.

## Notebook update

`notebooks/HdmiRealtimePedalboardOneCell.ipynb` (single code cell)
adds `presence` and `resonance` IntSliders to Section D (Amp
controls), renames the `mid` description to `middle`, and forwards
both new sliders through both `_apply_amp()` (Apply Amp button) and
the `_apply_selected_model()` AMP path (Apply Selected Model
button). Resource monitor and 800x480 `placement="manual"` /
`offset_x=0` / `offset_y=0` invariants are unchanged.

## CLI test update

`scripts/test_hdmi_realtime_pedalboard_controls.py` -- the three
amp steps (`jc_clean`, `british_crunch`, `high_gain_stack`) now
include explicit `presence` / `resonance` kwargs so the PYNQ run
exercises the new AppState index mapping end-to-end. The Phase 6D
`scripts/test_hdmi_model_selection_ui.py` 16-step coverage is
unchanged.

## Local validation

```
python3 -m py_compile GUI/pynq_multi_fx_gui.py
python3 -m py_compile audio_lab_pynq/hdmi_effect_state_mirror.py
python3 -m py_compile scripts/test_hdmi_model_selection_ui.py
python3 -m py_compile scripts/test_hdmi_realtime_pedalboard_controls.py
python3 tests/test_hdmi_selected_fx_state.py         # 8 PASS
python3 tests/test_hdmi_model_state_mapping.py       # 13 PASS (+2 new)
python3 tests/test_hdmi_origin_mapping.py            # 7 PASS (+1 new)
python3 tests/test_hdmi_resource_monitor.py          # 15 PASS
python3 tests/test_hdmi_gui_bridge.py                # exit 0
```

Notebook one-cell + `presence`/`resonance` keyword check passes.
`git diff --check` clean.

## PYNQ-Z2 run

```
ssh xilinx@192.168.1.9 \
  'cd /home/xilinx/Audio-Lab-PYNQ && \
   sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
     scripts/test_hdmi_realtime_pedalboard_controls.py \
     --hold-seconds-per-step 1 --final-hold-seconds 4'
```

`[phase6c] OK`, 16/16 PASS including the three amp steps with
explicit `presence` / `resonance` kwargs.

```
ssh xilinx@192.168.1.9 \
  'cd /home/xilinx/Audio-Lab-PYNQ && \
   sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
     scripts/test_hdmi_model_selection_ui.py \
     --hold-seconds-per-step 1 --final-hold-seconds 3'
```

`[phase6b] OK`, 16/16 PASS, VDMA `DMASR=0x00011000`,
`vtc_ctl=0x00000006`, 800x480 `(0,0,800,480)`, ADC HPF true,
R19=0x23. Per-step `render_s ~ 0.15-0.18 s`, `compose_s ~ 0.026 s`,
`framebuffer_copy_s ~ 0.21 s`.

## Files changed

* `GUI/pynq_multi_fx_gui.py`
* `audio_lab_pynq/hdmi_effect_state_mirror.py`
* `scripts/test_hdmi_realtime_pedalboard_controls.py`
* `notebooks/HdmiRealtimePedalboardOneCell.ipynb`
* `tests/test_hdmi_model_state_mapping.py`
* `tests/test_hdmi_origin_mapping.py`
* `docs/ai_context/HDMI_GUI_PHASE6E_PER_EFFECT_KNOB_GRID.md` (new)
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
* `hw/ip/clash/src/AudioLab/Effects/Amp.hs`

PRESENCE / RESONANCE were already in the DSP; only the
AppState / GUI / Notebook layers needed an update.
Remote PYNQ `audio_lab.bit` / `audio_lab.hwh` md5 hashes still match
the local copies (`9ba72e48...` / `162e6e41...`).

No Vivado build, no Clash regeneration, no `git push` /
`git pull` / `git fetch`.

## Open items / not addressed in this phase

* `DIST_SLOT_LABELS` / `AMP_SLOT_LABELS` / `CAB_SLOT_LABELS`
  constants stay in the module for backward compatibility with
  diagnostic scripts that overlay slot rows; they are no longer
  drawn on the compact-v2 panel.
* The SELECTED FX big-name text can still overlap the start of the
  ACTIVE MODELS column when the name is long ("NOISE SUPPRESSOR",
  "COMPRESSOR"). Pre-existing pre-Phase-6D issue, not addressed.
