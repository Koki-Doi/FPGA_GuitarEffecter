# Effect stage template

Fill this template out before adding a new effect. It pins down the
control-plane decisions that have to be consistent across Python,
Clash, the notebook UI, and the tests. See
[`EFFECT_ADDING_GUIDE.md`](EFFECT_ADDING_GUIDE.md) for the rules
behind each section.

Do **not** edit this template in place to record a real effect.
Copy it to a new file (e.g. `EFFECT_<name>.md`) or paste into a PR
description.

---

## Effect name

What it is called in the API and UI (e.g. `compressor`, `chorus`).
Match the naming convention of existing effects (lower_snake_case
for API names, `Title Case` for the UI label).

## Purpose

One paragraph: what the effect does, what voicing it targets, why
it is worth adding.

## Parameters

| Parameter | Range | Default | Notes |
| --- | --- | --- | --- |
| ... | 0..100 | 50 | ... |

If the effect has more than 4 parameters, decide which 4 ride on a
single GPIO and which (if any) are derivable in Python.

## GPIO mapping

- Target GPIO: `axi_gpio_*` (existing) or new IP.
- Bytes used: `ctrlA = ...`, `ctrlB = ...`, `ctrlC = ...`,
  `ctrlD = ...`.
- Bits / mask if relevant (e.g. for an enable bit on
  `gate_control.ctrlA`).
- Status of each byte / bit you touch: must match
  [`GPIO_CONTROL_MAP.md`](GPIO_CONTROL_MAP.md).

If this needs a new AXI GPIO, stop and re-read
`EFFECT_ADDING_GUIDE.md` Section 1; that path is gated on user
approval.

## Python API

- New methods on `AudioLabOverlay`:
  - `set_<effect>_settings(...)`
  - `get_<effect>_settings()`
  - `set_<effect>_<knob>` shortcuts (only if useful).
- New entries in `effect_defaults.py`: `..._DEFAULTS`.
- New entries in `effect_presets.py`: `..._PRESETS` (optional).
- Encoding helpers used from `control_maps.py`.

## Clash stage position

- Where in `fxPipeline` the new stage lands. The existing order is:
  `nsLevelPipe -> nsApply -> overdrive -> legacy distortion -> RAT ->
  clean_boost -> tube_screamer -> metal -> amp -> cab IR -> EQ ->
  reverb -> output`.
- Number of register stages.
- Whether it reuses any `Frame` accumulator field.

## DSP algorithm

- One-line summary.
- Numeric type discipline (`Sample` / `Wide`).
- Non-linear elements (clip / waveshape / saturate).
- Filter state and where it lives.

## Safety / bypass behaviour

- The enable bit name and its source GPIO bit.
- Bit-exact bypass: every output sample equals the input sample when
  the enable bit is clear.
- Anything that could surprise on first enable (peak follower zero,
  HPF settling, etc.).

## Saturation / overflow policy

- Where every `Wide` output is saturated (`satWide`, `satShiftN`,
  `softClip`, `hardClip`).
- Per-stage gain budget — what is the worst-case input that this
  stage must not wrap on.

## Timing risk

- Combinational depth estimate (multiplier? clip? IIR? sum-of-products?).
- Whether it shares a multiplier with another stage.
- WNS / WHS / THS expected vs the baseline in
  [`TIMING_AND_FPGA_NOTES.md`](TIMING_AND_FPGA_NOTES.md).

## Notebook UI

- Which accordion section it goes in (existing or new).
- Slider ranges and defaults.
- Preset entries (if any).
- Stack-mode behaviour, if applicable.

## Tests

- Snapshot tests in `tests/test_overlay_controls.py` covering at
  least: bytes-on-GPIO for the default state, for one preset, and
  for the off state.
- Round-trip tests for `set_*_settings` / `get_*_settings`.
- Cache-preservation tests if the new writer touches a shared GPIO
  byte.

## Docs

- Update `GPIO_CONTROL_MAP.md` only if a `reserved` byte is now
  `active`. Do not change the GPIO layout.
- Update `DSP_EFFECT_CHAIN.md` with the new stage block.
- Update `CURRENT_STATE.md` after deploy + live-verify.
- Add a `DECISIONS.md` ADR if anything non-obvious was decided.

## Deploy checklist

- [ ] Python tests pass (`python3 tests/test_overlay_controls.py`).
- [ ] Notebook JSON parses.
- [ ] If Clash changed: VHDL regenerated, IP repackaged.
- [ ] If `block_design.tcl` changed: explicit user approval recorded
      in the PR.
- [ ] Vivado WNS not significantly worse than the deployed baseline.
- [ ] `bash scripts/deploy_to_pynq.sh` succeeded.
- [ ] Board-side smoke test:
      `ovl.codec.R19_ADC_CONTROL[0] == 0x23`,
      `ovl.set_<effect>_settings(...)` round-trip prints OK.
