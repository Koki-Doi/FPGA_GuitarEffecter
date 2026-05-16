# HDMI GUI Phase 6A selected FX state mirror

Date: 2026-05-15 JST

## Summary

Phase 6A adds a Notebook-driven effect state mirror for the integrated HDMI
GUI. The operating model is one-way:

```text
Jupyter Notebook operation
  -> HdmiEffectStateMirror
  -> existing AudioLabOverlay API
  -> GUI AppState update
  -> 800x480 HDMI redraw at framebuffer x=0,y=0
```

The GUI still does not control the DSP. Users edit effects from the
Notebook, and the HDMI GUI displays the resulting state. No continuous GUI
loop, no per-frame GPIO writes, no `Overlay("base.bit")`, no
`run_pynq_hdmi()`, and no second overlay load are introduced.

The key Phase 6A behavior is:

- `SELECTED FX` means "last edited effect".
- Preset application sets `SELECTED FX = PRESET`.
- Safe Bypass sets `SELECTED FX = SAFE BYPASS`.
- Direct `ovl.set_*` calls are not enough to infer "last edited effect";
  Notebook code must use `fx.*` or `mirror.*`.

## Files

Added:

- `audio_lab_pynq/hdmi_effect_state_mirror.py`
- `notebooks/HdmiEffectStatusOneCell.ipynb`
- `scripts/test_hdmi_selected_fx_switch.py`
- `tests/test_hdmi_selected_fx_state.py`

Changed:

- `GUI/pynq_multi_fx_gui.py`
  - adds `AppState.selected_fx`
  - `SELECTED FX` display uses `selected_fx` when set
  - existing `selected_effect` behavior remains the fallback

## Mapping

| Operation | SELECTED FX |
| --- | --- |
| `safe_bypass()` | `SAFE BYPASS` |
| `apply_chain_preset(...)` | `PRESET` |
| `set_noise_suppressor_settings(...)` | `NOISE SUPPRESSOR` |
| `set_compressor_settings(...)` | `COMPRESSOR` |
| `set_distortion_settings(...)` | `DISTORTION` |
| `clear_distortion_pedals()` | `DISTORTION` |
| `set_guitar_effects(overdrive_*)` | `OVERDRIVE` |
| `set_guitar_effects(rat_*)` | `RAT` |
| `set_guitar_effects(amp_*)` | `AMP SIM` |
| `set_guitar_effects(cab_*)` | `CAB` |
| `set_guitar_effects(eq_*)` | `EQ` |
| `set_guitar_effects(reverb_*)` | `REVERB` |

When one `set_guitar_effects(...)` call includes multiple categories, the
wrapper uses Python keyword insertion order and marks the last explicit
category as `SELECTED FX`. The fallback priority is:

```text
reverb > cab > amp > eq > rat > overdrive > distortion > compressor > noise suppressor
```

Comparison is normalized for assertions:

- `AMP SIM`, `Amp Sim`, and `amp_sim` compare equal.
- `NOISE SUPPRESSOR`, `Noise Sup`, and `NS` compare equal.
- The GUI display string remains human-readable.

## HdmiEffectStateMirror

`HdmiEffectStateMirror` owns:

- `last_edited_effect`
- `selected_fx_history`
- `render_history`
- `last_render_info`
- `last_selected_fx_expected`
- `last_selected_fx_actual`

Every public operation goes through `mark_selected_fx(...)`, then renders
through `render_frame_800x480(...)` and `AudioLabHdmiBackend`. If an
expected selected-FX value is supplied, `render()` asserts it before and
after drawing.

The wrapper updates only visible GUI state and calls the existing
`AudioLabOverlay` methods. It does not monkey-patch the overlay and does not
try to infer edits made by unrelated direct overlay calls.

## Notebook

Notebook:

- `notebooks/HdmiEffectStatusOneCell.ipynb`

It contains exactly one code cell. The cell:

- loads `AudioLabOverlay()` once
- creates `AudioLabHdmiBackend` once
- creates `HdmiEffectStateMirror`
- renders the 800x480 compact-v2 GUI at manual `offset_x=0`, `offset_y=0`
- optionally runs the selected-FX switch sequence on start
- leaves a user-facing `fx` object

User-facing helpers left in the cell:

- `fx.safe_bypass()`
- `fx.basic_clean()`
- `fx.noise_gate(...)`
- `fx.comp(...)`
- `fx.od(...)`
- `fx.dist(...)`
- `fx.rat(...)`
- `fx.amp(...)`
- `fx.cab(...)`
- `fx.eq(...)`
- `fx.reverb(...)`
- `fx.render()`
- `fx.summary()`
- `fx.selected_history()`

The Notebook prints each step in this form:

```text
[03] fx.noise_gate
expected SELECTED FX: NOISE SUPPRESSOR
actual SELECTED FX  : NOISE SUPPRESSOR
result              : PASS
```

## Tests

Local unit test:

```sh
python3 tests/test_hdmi_selected_fx_state.py
```

Result:

- `PASS test_normalize_selected_fx_aliases`
- `PASS test_method_mapping_and_history_order`
- `PASS test_mark_selected_fx_and_assertion_failure`
- `PASS test_render_validates_expected_selected_fx`
- `PASS test_set_guitar_effects_last_kwarg_category_wins`

Notebook JSON check:

- one cell total
- one code cell
- includes `HOLD_SECONDS_PER_STEP`
- includes `HdmiEffectStateMirror`
- includes `SELECTED FX` / `selected_fx`

## PYNQ run

The full `scripts/deploy_to_pynq.sh` stages `audio_lab.bit` /
`audio_lab.hwh`, so Phase 6A used targeted `rsync` / `scp` for Python,
GUI, script, and Notebook files only. Bit/hwh were not overwritten.

PYNQ command:

```sh
ssh xilinx@192.168.1.9 '
  cd /home/xilinx/Audio-Lab-PYNQ &&
  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
    python3 scripts/test_hdmi_selected_fx_switch.py \
      --hold-seconds-per-step 1 --final-hold-seconds 10
'
```

Result:

- script exit: OK
- `AudioLabOverlay()` loaded once
- `AudioLabHdmiBackend` initialized once
- no `base.bit`
- no `run_pynq_hdmi()`
- no second overlay
- pre/post smoke:
  - ADC HPF: `true`
  - `R19`: `0x23`
  - `axi_gpio_delay_line`: absent
  - legacy `axi_gpio_delay`: present
  - `axi_gpio_noise_suppressor`: present
  - `axi_gpio_compressor`: present
  - `axi_vdma_hdmi` / `v_tc_hdmi`: present
  - `rgb2dvi_hdmi` / `v_axi4s_vid_out_hdmi`: present in HWH
- final VDMA:
  - `VDMACR=0x00010001`
  - `DMASR=0x00011000`
  - HSIZE/STRIDE/VSIZE `3840/3840/720`
  - framebuffer `0x16900000`, size `2764800`
  - no `dmainterr`, `dmaslverr`, or `dmadecerr`
- VTC:
  - `vtc_ctl=0x00000006`
- placement:
  - logical input `[480,800,3]` / `uint8`
  - manual `offset_x=0`, `offset_y=0`
  - requested destination/source/framebuffer copied region all
    `x=0..800`, `y=0..480`
  - `clipped=false`
  - `negative_offset=false`

### SELECTED FX step results

| Step | Operation | Expected | Actual | Result | Render | Compose | Copy | VDMA |
| ---: | --- | --- | --- | --- | ---: | ---: | ---: | --- |
| 1 | `safe_bypass` | `SAFE BYPASS` | `SAFE BYPASS` | PASS | `0.397 s` | `0.02565 s` | `0.20719 s` | no error |
| 2 | `apply_chain_preset Basic Clean` | `PRESET` | `PRESET` | PASS | `0.160 s` | `0.02552 s` | `0.20553 s` | no error |
| 3 | `set_noise_suppressor_settings` | `NOISE SUPPRESSOR` | `NOISE SUPPRESSOR` | PASS | `0.178 s` | `0.02528 s` | `0.20590 s` | no error |
| 4 | `set_compressor_settings` | `COMPRESSOR` | `COMPRESSOR` | PASS | `0.150 s` | `0.02531 s` | `0.20562 s` | no error |
| 5 | `set_guitar_effects overdrive` | `OVERDRIVE` | `OVERDRIVE` | PASS | `0.147 s` | `0.02525 s` | `0.20555 s` | no error |
| 6 | `set_distortion_settings` | `DISTORTION` | `DISTORTION` | PASS | `0.158 s` | `0.02529 s` | `0.20551 s` | no error |
| 7 | `set_guitar_effects RAT` | `RAT` | `RAT` | PASS | `0.140 s` | `0.02533 s` | `0.20550 s` | no error |
| 8 | `set_guitar_effects amp` | `AMP SIM` | `AMP SIM` | PASS | `0.143 s` | `0.02523 s` | `0.20555 s` | no error |
| 9 | `set_guitar_effects cab` | `CAB` | `CAB` | PASS | `0.150 s` | `0.02567 s` | `0.20543 s` | no error |
| 10 | `set_guitar_effects eq` | `EQ` | `EQ` | PASS | `0.145 s` | `0.02562 s` | `0.20553 s` | no error |
| 11 | `set_guitar_effects reverb` | `REVERB` | `REVERB` | PASS | `0.145 s` | `0.02571 s` | `0.20560 s` | no error |

`selected_fx_history` order matched the table exactly.

## Not Done

- No GUI-originated DSP control.
- No continuous GUI event loop.
- No 30fps refresh target.
- No direct `AudioLabOverlay` monkey patching.
- No attempt to detect direct `ovl.set_*` calls made outside the wrapper.
- No Vivado rebuild.
- No bit/hwh regeneration or deploy.
- No HDMI IP / VDMA / VTC configuration change.
