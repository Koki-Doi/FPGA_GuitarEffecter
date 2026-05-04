# Current state

Last updated: 2026-05-04.

## Headline

The selectable-distortion refactor is **mid-flight and pending a redesign**.
The first attempt (`model_select` driving a single 8-way mux per stage)
made Vivado timing significantly worse and was halted before deploy. The
agreed next step is the pedal-mask design described in
`DISTORTION_REFACTOR_PLAN.md`.

## What is in the working tree

`git status --short` at the time this doc was written:

```
 M audio_lab_pynq/AudioCodec.py
 M audio_lab_pynq/AudioLabOverlay.py
 M audio_lab_pynq/diagnostics.py
 M audio_lab_pynq/notebooks/InputDebug.ipynb
 M hw/Pynq-Z2/bitstreams/audio_lab.bit
 M hw/Pynq-Z2/bitstreams/audio_lab.hwh
 M hw/ip/clash/src/LowPassFir.hs
 M hw/ip/clash/vhdl/LowPassFir/LowPassFir.topEntity/clash-manifest.json
 M hw/ip/clash/vhdl/LowPassFir/LowPassFir.topEntity/clash_lowpass_fir.vhdl
 M hw/ip/clash/vhdl/LowPassFir/LowPassFir.topEntity/clash_lowpass_fir_types.vhdl
 M hw/ip/clash/vhdl/LowPassFir/component.xml
 M tests/test_overlay_controls.py
?? .claude/
?? audio_lab_pynq/notebooks/DistortionModelsDebug.ipynb
```

These changes are **not** to be discarded. They contain:

- The ADC HPF default-on work for `AudioCodec.py` /
  `AudioLabOverlay.py` / `diagnostics.py` / `InputDebug.ipynb`. That
  work is correct and effective on the live board; it just has not
  been split into its own commit yet.
- The first (rejected) distortion-model implementation in
  `LowPassFir.hs` and the matching Python facade in
  `AudioLabOverlay.py`, plus the giant 8-way case structure that
  needs to be replaced with the pedal-stage design.
- The regenerated VHDL and the Vivado-built `.bit` / `.hwh`. The
  bitstream is **timing-failed** (WNS = -15.067 ns) and must not be
  deployed.
- A draft `DistortionModelsDebug.ipynb` written for the old API; it
  will be replaced when the pedal-mask API lands.

## What was previously decided

- ADC HPF default-on (`R19_ADC_CONTROL = 0x23`) is permanent.
  Settling delay added in `config_codec()` and 400 ms / 2400-frame
  skip used in `InputDebug.ipynb` after toggles.
- The deploy path is `scripts/deploy_to_pynq.sh` to
  `xilinx@192.168.1.8` with key auth + passwordless `sudo`.
- `block_design.tcl` is not changing for this refactor. New pedal
  bits live in spare bytes of existing AXI GPIOs.

## What to do next

In this order:

1. Run `git status --short` and `git diff --stat` to confirm the
   working-tree state matches what is described above.
2. Read `DISTORTION_REFACTOR_PLAN.md`.
3. In `LowPassFir.hs`, retire (or split) the `model_select`-style
   functions:
   `distModel`, `modelInputHpfAlpha`, `modelPostFilterAlpha`,
   `modelPreGain`, `distModelInputFilterFrame`, `distModelBiasFrame`,
   `distModelPreGainMulFrame`, `distModelPreGainBoostFrame`,
   `distModelClipFrame`, `distModelInterGainFrame`,
   `distModelInterClipFrame`, `distModelPostFilterFrame`,
   `distModelLevelFrame`. Restore the legacy distortion stages in
   the pipeline. Add new per-pedal stages instead.
4. In `AudioLabOverlay.py`, replace the model-index API with the
   pedal-mask API described in `DISTORTION_REFACTOR_PLAN.md`. Do
   **not** rip out the cached-word machinery — it is what makes the
   AXI-GPIO-output-only model survive.
5. Update `tests/test_overlay_controls.py` so that assertions live on
   the pedal-mask layout, not the old `distortion_model` field.
6. Run `python3 -m compileall audio_lab_pynq scripts` and the
   overlay-control tests.
7. Regenerate VHDL → repackage Clash IP → run Vivado.
8. Compare WNS against the baseline in `TIMING_AND_FPGA_NOTES.md`.
   Deploy only if it is no worse than the baseline.
9. Smoke-test on the board, then commit.

## Things to be careful about

- Do **not** silently revert older work. Both `AudioCodec.py` and
  `diagnostics.py` carry the ADC HPF feature; that must survive.
- Do **not** delete the cached distortion state in the Python init —
  the next API still needs it.
- Do **not** deploy the currently-built `audio_lab.bit`. It is
  timing-failed.
- Do **not** push, pull, or fetch.
