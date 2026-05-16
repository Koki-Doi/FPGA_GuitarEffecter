# HDMI GUI Phase 6B model selection UI

Date: 2026-05-15

## Purpose

Phase 6B extends the Phase 6A Notebook-driven HDMI state mirror so Jupyter
Notebook operations can select pedal, amp, and cab models and show those
models on the 800x480 HDMI GUI in near real time.

The control direction is still one-way:

```text
Notebook fx.* helper -> HdmiEffectStateMirror -> AudioLabOverlay existing API
                      -> AppState model labels -> HDMIBackend redraw
```

The HDMI GUI remains display-only. It does not write DSP controls, does not
start an interactive GUI event loop, and does not poll/write GPIO every frame.
The standard display remains the Phase 5C placement: 800x480 logical GUI at
framebuffer `x=0,y=0` inside the fixed 1280x720 HDMI signal.

## Existing API / bitstream support

No Vivado rebuild, Clash edit, `block_design.tcl` edit, `audio_lab.xdc` edit,
or bit/hwh regeneration is required for Phase 6B. The requested pedal and amp
models are already exposed by the deployed Python API and existing GPIO
contracts. The cab DSP currently exposes three numeric cab models only.

| UI category | Requested model name | Existing DSP support | Existing API argument | Existing value/index/byte | Requires bit/hwh change? | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Pedal / Distortion | `clean_boost` | yes | `set_distortion_settings(pedal="clean_boost", ...)` + `set_guitar_effects(distortion_on=True, distortion_pedal_mask=...)` | `axi_gpio_distortion.ctrlD` bit 0 | no | Phase 6B helper: `fx.clean_boost(...)`; SELECTED FX `CLEAN BOOST`. |
| Pedal / Distortion | `tube_screamer` | yes | `set_distortion_settings(pedal="tube_screamer", ...)` + `set_guitar_effects(...)` | `axi_gpio_distortion.ctrlD` bit 1 | no | Phase 6B helper: `fx.tube_screamer(...)`; SELECTED FX `TUBE SCREAMER`. |
| Pedal / Distortion | `rat` | yes | `set_distortion_settings(pedal="rat", ...)` + `set_guitar_effects(rat_on=True, ...)` | `axi_gpio_distortion.ctrlD` bit 2 + legacy `axi_gpio_delay` RAT controls | no | Keeps the existing RAT contract; no new RAT stage or GPIO. |
| Pedal / Distortion | `ds1` | yes | `set_distortion_settings(pedal="ds1", ...)` + `set_guitar_effects(...)` | `axi_gpio_distortion.ctrlD` bit 3 | no | SELECTED FX `DS-1`. |
| Pedal / Distortion | `big_muff` | yes | `set_distortion_settings(pedal="big_muff", ...)` + `set_guitar_effects(...)` | `axi_gpio_distortion.ctrlD` bit 4 | no | SELECTED FX `BIG MUFF`. |
| Pedal / Distortion | `fuzz_face` | yes | `set_distortion_settings(pedal="fuzz_face", ...)` + `set_guitar_effects(...)` | `axi_gpio_distortion.ctrlD` bit 5 | no | SELECTED FX `FUZZ FACE`. |
| Pedal / Distortion | `metal` | yes | `set_distortion_settings(pedal="metal", ...)` + `set_guitar_effects(...)` | `axi_gpio_distortion.ctrlD` bit 6 | no | SELECTED FX `METAL`; bit 7 remains reserved. |
| Amp | `jc_clean` | yes | `set_amp_model("jc_clean", ...)` | `amp_character=10` | no | GUI shows AMP MODEL `JC CLEAN`; SELECTED FX remains `AMP SIM`. |
| Amp | `clean_combo` | yes | `set_amp_model("clean_combo", ...)` | `amp_character=35` | no | GUI shows AMP MODEL `CLEAN COMBO`. |
| Amp | `british_crunch` | yes | `set_amp_model("british_crunch", ...)` | `amp_character=60` | no | GUI shortens display to `BRIT CRUNCH` where space is tight. |
| Amp | `high_gain_stack` | yes | `set_amp_model("high_gain_stack", ...)` | `amp_character=85` | no | GUI shortens display to `HI-GAIN STACK` where space is tight. |
| Cab | `1x12` | yes | `set_guitar_effects(cab_on=True, cab_model=0, ...)` | `axi_gpio_cab.ctrlC = 0` | no | GUI label `1x12 OPEN`; aliases include `1x12_open` / `model0`. |
| Cab | `2x12` | yes | `set_guitar_effects(cab_on=True, cab_model=1, ...)` | `axi_gpio_cab.ctrlC = 85` | no | GUI label `2x12 COMBO`; Notebook example uses `fx.cab(model="2x12", air=40)`. |
| Cab | `4x12` | yes | `set_guitar_effects(cab_on=True, cab_model=2, ...)` | `axi_gpio_cab.ctrlC = 170` | no | GUI label `4x12 CLOSED`; aliases include `4x12_british` / `model2`. |

The older GUI placeholder labels `4x12 V30` and `DIRECT DI` are not current
DSP cab models. Phase 6B does not expose them as selectable live models.

## Implementation

`audio_lab_pynq/hdmi_effect_state_mirror.py` now owns the model-name mapping:

- `PEDAL_MODEL_LABELS`, `PEDAL_MODEL_TO_INDEX`
- `AMP_MODEL_LABELS`, `AMP_MODEL_TO_INDEX`, `AMP_MODEL_CHARACTER`
- `CAB_MODEL_LABELS`, `CAB_MODEL_TO_INDEX`
- `normalize_pedal_model()`, `normalize_amp_model()`,
  `normalize_cab_model()`

The wrapper keeps shadow model state:

- `current_pedal_model`, `current_amp_model`, `current_cab_model`
- `current_pedal_label`, `current_amp_label`, `current_cab_label`
- `active_pedals`

Every model operation updates the DSP through existing `AudioLabOverlay` APIs,
updates `AppState`, marks `SELECTED FX`, records the selected-FX history, and
renders one HDMI frame. Direct `ovl.set_*` calls still should not be used from
the Notebook because they bypass the "last edited model/effect" state.

## SELECTED FX rules

| Method | SELECTED FX | Model label updated |
| --- | --- | --- |
| `clean_boost(...)` | `CLEAN BOOST` | PEDAL MODEL `CLEAN BOOST` |
| `tube_screamer(...)` | `TUBE SCREAMER` | PEDAL MODEL `TUBE SCREAMER` |
| `rat(...)` | `RAT` | PEDAL MODEL `RAT` |
| `ds1(...)` | `DS-1` | PEDAL MODEL `DS-1` |
| `big_muff(...)` | `BIG MUFF` | PEDAL MODEL `BIG MUFF` |
| `fuzz_face(...)` | `FUZZ FACE` | PEDAL MODEL `FUZZ FACE` |
| `metal(...)` | `METAL` | PEDAL MODEL `METAL` |
| `set_amp_model("jc_clean", ...)` | `AMP SIM` | AMP MODEL `JC CLEAN` |
| `set_amp_model("clean_combo", ...)` | `AMP SIM` | AMP MODEL `CLEAN COMBO` |
| `set_amp_model("british_crunch", ...)` | `AMP SIM` | AMP MODEL `BRITISH CRUNCH` |
| `set_amp_model("high_gain_stack", ...)` | `AMP SIM` | AMP MODEL `HIGH GAIN STACK` |
| `set_cab_model("1x12" / "2x12" / "4x12", ...)` | `CAB` | CAB MODEL label |
| `reverb(...)` | `REVERB` | model labels preserved |

## GUI changes

`GUI/pynq_multi_fx_gui.py` keeps the compact-v2 800x480 layout and the
Phase 5C manual placement. The bottom `fx` panel now shows:

- `SELECTED FX`
- selected effect ON/BYPASS status
- `ACTIVE MODELS`: PEDAL / AMP / CAB labels
- pedal model slots: `CLEAN`, `TS`, `RAT`, `DS1`, `MUFF`, `FUZZ`, `METAL`
- amp model slots: `JC`, `CLEAN`, `BRIT`, `HIGH`
- cab model slots: `1x12`, `2x12`, `4x12`
- small IN/OUT level bars

The Pip-Boy-inspired `pipboy-green` theme remains the default compact-v2
theme. Long labels are shortened only for constrained display areas:
`TUBE SCREAMER` -> `TUBE SCRMR`, `BRITISH CRUNCH` -> `BRIT CRUNCH`,
`HIGH GAIN STACK` -> `HI-GAIN STACK`.

## Notebook

Notebook: `notebooks/HdmiEffectStatusOneCell.ipynb`

It remains exactly one code cell and loads:

- `AudioLabOverlay()` once
- `AudioLabHdmiBackend` once
- `HdmiEffectStateMirror`
- `render_frame_800x480(..., variant="compact-v2", theme="pipboy-green")`
- `placement="manual"`, `offset_x=0`, `offset_y=0`

Notebook helpers left in the cell:

- `fx.safe_bypass()`
- `fx.basic_clean()`
- `fx.noise_gate(...)`
- `fx.comp(...)`
- `fx.od(...)`
- `fx.dist(model="tube_screamer", ...)`
- `fx.clean_boost(...)`
- `fx.tube_screamer(...)`
- `fx.rat(...)`
- `fx.ds1(...)`
- `fx.big_muff(...)`
- `fx.fuzz_face(...)`
- `fx.metal(...)`
- `fx.amp(model="british_crunch", ...)`
- `fx.jc_clean(...)`
- `fx.clean_combo(...)`
- `fx.british_crunch(...)`
- `fx.high_gain_stack(...)`
- `fx.cab(model="2x12", ...)`
- `fx.eq(...)`
- `fx.reverb(...)`
- `fx.render()`
- `fx.summary()`
- `fx.selected_history()`

## Tests

Unit tests:

```sh
python3 tests/test_hdmi_selected_fx_state.py
python3 tests/test_hdmi_model_state_mapping.py
```

PYNQ CLI test:

```sh
sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
  python3 scripts/test_hdmi_model_selection_ui.py \
  --hold-seconds-per-step 1 --final-hold-seconds 10
```

The CLI test verifies AudioLab overlay load, ADC HPF/R19, HDMI IP presence,
800x480 manual x0/y0 rendering, expected/actual SELECTED FX, current
pedal/amp/cab model labels, VDMA error bits, VTC status, and render/compose/
copy timings.

## Local verification

- `python3 -m py_compile audio_lab_pynq/hdmi_effect_state_mirror.py`
- `python3 -m py_compile GUI/pynq_multi_fx_gui.py`
- `python3 -m py_compile scripts/test_hdmi_selected_fx_switch.py`
- `python3 -m py_compile scripts/test_hdmi_model_selection_ui.py`
- `python3 tests/test_hdmi_selected_fx_state.py`: PASS
- `python3 tests/test_hdmi_model_state_mapping.py`: PASS
- notebook JSON one-cell check: PASS
- `git diff --check`: PASS

## PYNQ result

Command:

```sh
sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ:/home/xilinx/Audio-Lab-PYNQ/GUI \
  python3 scripts/test_hdmi_model_selection_ui.py \
  --hold-seconds-per-step 1 --final-hold-seconds 10
```

Result:

- AudioLabOverlay import: `4.833 s`
- AudioLabOverlay load: `2.670 s`
- ADC HPF: `true`
- `R19=0x23`
- HDMI IPs present in `ip_dict` / HWH
- `axi_gpio_delay_line`: false
- legacy `axi_gpio_delay`: true
- failures: `0`
- skips: `0`
- final `VDMACR=0x00010001`
- final `DMASR=0x00011000`
- final `vtc_ctl=0x00000006`
- VDMA error bits: `dmainterr=false`, `dmaslverr=false`,
  `dmadecerr=false`
- final render / compose / framebuffer copy:
  `0.1537 s` / `0.0261 s` / `0.2056 s`
- copied framebuffer region: `x=0..800`, `y=0..480`
- `placement=manual`, `offset_x=0`, `offset_y=0`

Expected/actual SELECTED FX:

| Step | Operation | Expected | Actual | Result | Model label after step |
| --- | --- | --- | --- | --- | --- |
| 1 | `clean_boost` | `CLEAN BOOST` | `CLEAN BOOST` | PASS | PEDAL `CLEAN BOOST` |
| 2 | `tube_screamer` | `TUBE SCREAMER` | `TUBE SCREAMER` | PASS | PEDAL `TUBE SCREAMER` |
| 3 | `rat` | `RAT` | `RAT` | PASS | PEDAL `RAT` |
| 4 | `ds1` | `DS-1` | `DS-1` | PASS | PEDAL `DS-1` |
| 5 | `big_muff` | `BIG MUFF` | `BIG MUFF` | PASS | PEDAL `BIG MUFF` |
| 6 | `fuzz_face` | `FUZZ FACE` | `FUZZ FACE` | PASS | PEDAL `FUZZ FACE` |
| 7 | `metal` | `METAL` | `METAL` | PASS | PEDAL `METAL` |
| 8 | `jc_clean` | `AMP SIM` | `AMP SIM` | PASS | AMP `JC CLEAN` |
| 9 | `british_crunch` | `AMP SIM` | `AMP SIM` | PASS | AMP `BRITISH CRUNCH` |
| 10 | `high_gain_stack` | `AMP SIM` | `AMP SIM` | PASS | AMP `HIGH GAIN STACK` |
| 11 | `cab 2x12` | `CAB` | `CAB` | PASS | CAB `2x12 COMBO` |
| 12 | `reverb` | `REVERB` | `REVERB` | PASS | model labels preserved |

Representative per-step timing after the first cold render:

- render: `0.149..0.158 s`
- compose: `0.0256..0.0262 s`
- framebuffer copy: `0.2055..0.2061 s`

The first model render (`clean_boost`) was cold-cache render `0.411 s`.

## Not implemented in Phase 6B

- GUI-originated DSP control events
- continuous 30fps GUI loop
- per-frame GPIO writes
- direct overlay method monkey patching
- new cab models beyond current `cab_model=0/1/2`
- Vivado/Clash/bit/hwh changes
