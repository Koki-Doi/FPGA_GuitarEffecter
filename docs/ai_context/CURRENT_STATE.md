# Current state

Last updated: 2026-05-09 (internal mono DSP pipeline deployed at
192.168.1.9; DMA TLAST/backpressure check passed).

## PYNQ-Z2 network identity

The lab board should be kept at a stable router DHCP reservation:

| Field | Value |
| --- | --- |
| Device name | `PYNQ-Z2` |
| eth0 MAC | `00:05:6B:02:CA:04` |
| Reserved IP | `192.168.1.9` |
| SSH | `ssh xilinx@192.168.1.9` |
| Jupyter | `http://192.168.1.9:9090/tree` |

Use `bash scripts/show_pynq_network_info.sh` to confirm hostname, IP,
and eth0 MAC from the board. The reservation itself must be created in
the router management UI; do not rely on ad-hoc IP scans as normal
operation, and do not write a static IP directly on the PYNQ for this
workflow. After changing the reservation, reboot the PYNQ-Z2 and run:

```sh
ssh xilinx@192.168.1.9 'hostname; ip -br addr; cat /sys/class/net/eth0/address'
bash scripts/deploy_to_pynq.sh
```

## Internal mono DSP pipeline (this branch, `feature/internal-mono-dsp-pipeline`)

This pass converts the active DSP signal path to mono internally while
preserving the deployed stereo external contract.

What landed:

- `topEntity`, port names, port order, external I/O, AXI Stream 48-bit
  input/output, `block_design.tcl`, GPIO topology, Python API,
  Notebook UI, and Chain Presets are unchanged.
- AXI input still arrives as stereo frames, but `AudioLab.Axis.makeInput`
  treats ADC Left as the guitar mono source and discards Right to avoid
  unconnected-channel noise. The physical `Frame` record keeps its
  L/R-shaped fields for compatibility, but the active helpers use one
  mono sample/state.
- Effect stages in `AudioLab.Effects.*` now process the active path from
  mono helpers/state. The stereo duplicate state in the main path was
  collapsed where safe; coefficients, clip knees, byte mappings, enable
  semantics, and stage order were not retuned.
- `AudioLab.Axis.pipeData` duplicates the mono result to output
  Left/Right, so the external AXI/I2S stream remains stereo-compatible.
- AXI Stream packet metadata remains separate from sample data:
  `Frame.fLast` carries input TLAST to output TLAST, and
  `AudioLab.Pipeline` now paces accepted input frames so the fixed-
  latency DSP pipeline does not drop an in-flight output frame or TLAST
  when the S2MM DMA side briefly deasserts ready.
- No 96 kHz work, PCM1808 / PCM5102 support, external ADC/DAC support,
  I2S addition, internal 32-bit conversion, new GPIO, Delay-line IP, or
  `axi_gpio_delay_line` was added.

Build/deploy status:

- Local tests passed:
  `python3 -m compileall audio_lab_pynq scripts`,
  `python3 tests/test_overlay_controls.py`, and Notebook JSON checks
  for `GuitarPedalboardOneCell.ipynb`, `GuitarEffectSwitcher.ipynb`,
  and `DistortionModelsDebug.ipynb`.
- Clash type check and VHDL generation passed. Vivado IP repackage
  passed. Vivado bitstream build completed with
  `write_bitstream completed successfully`.
- Final routed timing: WNS = -8.155 ns, TNS = -6492.876 ns,
  WHS = +0.052 ns, THS = 0.000 ns. Versus the minimal mono build /
  `37ef4c7` baseline (WNS = -8.022 ns), WNS delta is -0.133 ns.
  Hold remains clean.
- Utilization after place: Slice LUTs = 15473 (29.08%), Slice
  Registers = 14914 (14.02%), Block RAM Tile = 7 (5.00%), DSPs = 83
  (37.73%).
- PYNQ-Z2 deploy completed with `bash scripts/deploy_to_pynq.sh`
  using the default `PYNQ_HOST=192.168.1.9`.
- PYNQ smoke test confirmed `ADC HPF: True`, `R19 = 0x23`,
  `has delay_line gpio: False`, `has legacy axi_gpio_delay: True`,
  and all requested chain presets.
- DMA validation after PYNQ reboot used one overlay load and one
  composite DMA packet for Case A (Left nonzero / Right different),
  Case B (Left zero / Right large), and Case C (Right inverted noise).
  All cases completed without timeout; send and recv DMASR both ended
  at `0x00001002`. With `skip_frames = 16`, output L/R were identical
  (`max_abs_lr_diff_steady_state = 0`) and Right input rejection was
  confirmed (`max_abs_output_when_left_zero = 0`,
  `max_abs_output_change_when_right_input_changes = 0`).

## LowPassFir behavior-preserving split (this branch, `feature/split-lowpassfir-behavior-preserving`)

This pass is **only** a Haskell/Clash module split. It prepares the DSP
source for future mono / 96 kHz / external ADC-DAC / internal-width /
I2S work without implementing any of those changes now.

What landed:

- `hw/ip/clash/src/LowPassFir.hs` is now a thin top module that keeps
  the `LowPassFir` module name, `Synthesize` annotation, `topEntity`
  type, port names, port order, and external I/O unchanged.
- New `hw/ip/clash/src/AudioLab/*` modules hold the moved code:
  `Types`, `FixedPoint`, `Control`, `Axis`,
  `Effects.NoiseSuppressor`, `Effects.Compressor`,
  `Effects.Overdrive`, `Effects.Distortion`, `Effects.Amp`,
  `Effects.Cab`, `Effects.Eq`, `Effects.Reverb`, and `Pipeline`.
- Function bodies were moved, not retuned. The split keeps the existing
  `Frame` shape, sample widths, accumulator widths, fixed-point helper
  arithmetic, coefficients, clip knees, enable / bypass behavior, and
  pipeline stage order.
- `AudioLab.Pipeline` owns `fxPipeline`; effect modules expose the
  same stage functions to the pipeline.
- `hw/ip/clash/vhdl/LowPassFir/*` was regenerated and the IP was
  repackaged.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` was rebuilt locally.

Build/deploy status:

- Local tests passed:
  `python3 -m compileall audio_lab_pynq scripts`,
  `python3 tests/test_overlay_controls.py`, and Notebook JSON checks
  for `GuitarPedalboardOneCell.ipynb`, `GuitarEffectSwitcher.ipynb`,
  and `DistortionModelsDebug.ipynb`.
- Clash type check and VHDL generation passed. Vivado IP repackage
  passed. Vivado bitstream build completed with
  `write_bitstream completed successfully`.
- Final routed timing: WNS = -8.022 ns, TNS = -13937.512 ns,
  WHS = +0.052 ns, THS = 0.000 ns. This is equal to the previous
  deployed Amp Simulator fizz-control baseline (WNS delta 0.000 ns).
  Hold remains clean.
- Utilization after place: Slice LUTs = 21809 (40.99%), Slice
  Registers = 18675 (17.55%), Block RAM Tile = 7 (5.00%), DSPs = 158
  (71.82%).
- PYNQ-Z2 deploy completed with
  `PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh`.
- PYNQ smoke test loaded `AudioLabOverlay`, confirmed `ADC HPF: True`
  and `R19 = 0x23`, confirmed `has delay_line gpio: False` and
  `has legacy axi_gpio_delay: True`, listed all four amp models, and
  applied Safe Bypass, Basic Clean, Tube Screamer Lead, RAT Rhythm,
  DS-1 Crunch, Big Muff Sustain, Vintage Fuzz, Metal Tight, and
  Ambient Clean.

What did **not** change:

- No DSP algorithm change, coefficient change, bit-width change,
  mono conversion, 96 kHz work, PCM1808 / PCM5102 support, I2S
  interface change, or external ADC/DAC support.
- No `topEntity` interface change, no `block_design.tcl` change, no
  new AXI GPIO, and no GPIO address / `ctrlA`-`ctrlD` semantic change.
- No Python API, Notebook UI, Chain Preset, or effect preset change.
- No Delay implementation from `feature/bram-delay-500ms`; no
  `axi_gpio_delay_line`. Legacy `axi_gpio_delay` remains present.
- No C++ DSP prototype or GPL/commercial source-code import.

## Amp Simulator fizz-control pass (this branch, `feature/amp-sim-fizz-control`)

This pass targets **only** high-frequency fizz generated inside the
Amp Simulator. It does not address input -> bypass tone differences,
noise floor, codec/I2S/hardware routing, or capture-analysis tooling.
It also does not touch Cab Sim topology, Compressor, Noise Suppressor,
Reverb, Delay, Python API, Notebook UI, GPIO names/addresses, or
`block_design.tcl`.

What landed:

- `hw/ip/clash/src/LowPassFir.hs`:
  - `ampPreLowpassFrame`: existing one-pole post-clip smoothing keeps
    `baseAlpha = 128 + (charByte >> 2)` but increases the per-model
    darken from `0 / 2 / 8 / 16` to `0 / 4 / 12 / 24`. `jc_clean`
    stays bright; `high_gain_stack` is damped most strongly.
  - `ampTrebleGain`: now takes the existing `amp_character` byte and
    applies a small model-dependent cap. The base treble return is
    reduced from roughly `64 + 7/16*T` to `64 + 13/32*T`, then trimmed
    by `0 / 2 / 5 / 9` for the four amp bands so TREBLE=100 cannot
    restore as much 8..16 kHz fizz.
  - `ampResPresenceProductsFrame`: presence remains tied to the
    existing `amp_presence` byte but gets extra model-dependent trim
    of `0`, `presence>>5`, `presence>>4`, or `presence>>3`. This keeps
    clean presence open while capping the high-gain presence return.
  - `ampPowerFrame` and `ampResPresenceMixFrame`: safety `softClipK`
    knee tightened from `3_500_000` to `3_400_000` to keep internal
    gain spikes from leaking as broad high-frequency fizz.
- `hw/ip/clash/vhdl/LowPassFir/*`: regenerated VHDL + repackaged IP.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}`: rebuilt and deployed.

Build/deploy status:

- Local tests passed:
  `python3 -m compileall audio_lab_pynq scripts`,
  `python3 tests/test_overlay_controls.py`, and Notebook JSON checks
  for `GuitarPedalboardOneCell.ipynb`, `GuitarEffectSwitcher.ipynb`,
  and `DistortionModelsDebug.ipynb`.
- Clash type check and VHDL generation passed. Vivado bitstream build
  completed with `write_bitstream completed successfully`.
- Final routed timing: WNS = -8.022 ns, TNS = -13937.512 ns,
  WHS = +0.052 ns, THS = 0.000 ns. This improves WNS by 0.709 ns vs
  the previous deployed audio-analysis baseline (-8.731 ns). Hold
  remains clean.
- Utilization after place: Slice LUTs = 21809 (40.99%), Slice
  Registers = 18675 (17.55%), Block RAM Tile = 7 (5.00%), DSPs = 158
  (71.82%). No BRAM increase was introduced by this pass.
- PYNQ-Z2 deploy completed with
  `PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh`.
- PYNQ smoke test loaded `AudioLabOverlay`, confirmed `ADC HPF: True`
  and `R19 = 0x23`, confirmed `has delay_line gpio: False` and
  `has legacy axi_gpio_delay: True`, exercised all four amp models,
  and applied Safe Bypass, Basic Clean, Tube Screamer Lead, RAT
  Rhythm, DS-1 Crunch, Big Muff Sustain, Vintage Fuzz, Metal Tight,
  and Ambient Clean.

What did **not** change:

- `hw/Pynq-Z2/block_design.tcl`, `topEntity` ports, `Frame` shape,
  GPIO address map, Python API, Notebook UI, or chain preset structure.
- Delay implementation from `feature/bram-delay-500ms` was not mixed
  in; `axi_gpio_delay_line` is absent and legacy `axi_gpio_delay`
  remains present.
- Compressor / Noise Suppressor / Overdrive / Distortion Pedalboard /
  Cab IR / EQ / Reverb voicings were not retuned in this pass.
- No C++ DSP prototype, commercial amp circuit/IR/coefficients, GPL
  code, analysis tool, or test-signal generator was added.

## Amp Simulator named models (this branch, `feature/audio-analysis-voicing-fixes`)

Four named amp voicings (`jc_clean` / `clean_combo` / `british_crunch`
/ `high_gain_stack`) were layered onto the existing
`amp_character` knob. The Python side adds an
`AMP_MODELS` table plus `get_amp_model_names`,
`amp_model_to_character`, and `set_amp_model` convenience helpers; the
numeric `amp_character` argument still works directly. The Clash side
quantises the same character byte into a two-bit `ampModelSel` index
and applies a small extra darken to the post-clip pre-LPF for the
higher-gain bands so high-gain pedals into the amp do not produce a
second brightening on top of the audio-analysis pass. **No new GPIO,
no new `topEntity` port, no `block_design.tcl` change**, no `Frame`
field added; only one cheap helper and one alpha bias.

What landed:

- `hw/ip/clash/src/LowPassFir.hs`: new `ampModelSel :: Unsigned 8 ->
  Unsigned 2` helper, and `ampPreLowpassFrame` subtracts a
  per-model darken (0 / 2 / 8 / 16) from the existing
  `baseAlpha = 128 + (charByte >> 2)`. Bands match the documented
  Python ranges (character 0..24 / 25..49 / 50..74 / 75..100).
- `audio_lab_pynq/effect_defaults.py`: `AMP_MODELS = {jc_clean: 10,
  clean_combo: 35, british_crunch: 60, high_gain_stack: 85}`.
- `audio_lab_pynq/AudioLabOverlay.py`: `AMP_MODELS` class attr,
  `get_amp_model_names()`, `amp_model_to_character(name)`,
  `set_amp_model(name, **overrides)` convenience method.
- `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb`: Amp
  Model dropdown above the Character slider; selection writes the
  matching centre value into the slider so the chain-preset/safe-
  bypass logic stays untouched. Inline fallback `AMP_MODELS` mirrors
  the package values byte-for-byte.
- `tests/test_overlay_controls.py`: anchor / table-shape / mapping
  / per-model byte-distinctness / overrides tests.
- `hw/ip/clash/vhdl/LowPassFir/*`: regenerated VHDL + repackaged IP.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}`: rebuilt; final routed
  timing recorded in `TIMING_AND_FPGA_NOTES.md`.

What did **not** change:

- `block_design.tcl`, `topEntity` port list, `Frame` shape.
- Existing `amp_character` API surface; the convenience helpers
  share the same byte and write through `set_guitar_effects`.
- The audio-analysis voicing fixes (the cap on the post-clip pre-LPF
  is preserved; the model-specific darken sits on top).
- Cab IR / Compressor / Overdrive / Distortion Pedalboard / EQ /
  Reverb voicings (untouched in this pass).

## Audio-analysis voicing fixes (prior arc on this branch)

Recording analysis of Bypass / NoiseSuppressor / Compressor /
Overdrive / DS-1 / AmpSim / Cabinet / Reverb showed four actionable
voicing gaps: AmpSim had too much >5 kHz fizz, Cabinet roll-off was
directionally right but still weak after high-gain pedals, Overdrive
was nearly indistinguishable from Bypass, and Compressor crest factor
barely moved. The findings are recorded in
`docs/ai_context/AUDIO_RECORDING_ANALYSIS.md`.

This pass is **not** a new effect. It retunes only existing
`LowPassFir.hs` stages and keeps the fixed GPIO contract intact:
no new AXI GPIO, no new `topEntity` port, no `block_design.tcl`
change, no AXI address change, and no Python API / Notebook UI
surface change.

What landed:

- `hw/ip/clash/src/LowPassFir.hs`:
  - Compressor: `compThresholdSample`, `compEnvNext`,
    `compTargetGain`, and `compGainNext` now start compression a bit
    earlier and react a little faster while preserving the makeup
    safety contract.
  - Overdrive: `overdriveDriveMultiplyFrame` has a stronger midrange
    drive curve, `overdriveDriveClipFrame` uses lower asymmetric knees,
    and `overdriveLevelFrame` adds a lower output safety `softClipK`.
  - Amp: `ampDriveMultiplyFrame`, `ampPreLowpassFrame`,
    `ampToneProductsFrame` / `ampTrebleGain`, `ampPowerFrame`,
    `ampResPresenceProductsFrame` / `ampResPresenceMixFrame`, and
    `ampMasterFrame` were retuned to reduce painful high-end fizz and
    keep MASTER / presence / treble from slamming later stages.
  - Cab: `cabCoeff` was rebuilt again so model 0 / 1 / 2 are more
    clearly separated. Model 2 is now the darkest 4x12-style setting
    for DS-1 / RAT / Big Muff / Fuzz / Metal. `cabLevelMixFrame`
    keeps the existing timing-friendly `softClip`; a lower
    `softClipK 3_400_000` trial was rejected after timing slipped too
    far.
- `audio_lab_pynq/effect_presets.py`:
  - DS-1 Crunch now leans on Cab model 2 with capped `air`.
  - Safe Bypass remains all-off, Compressor makeup stays in 45..60,
    and Distortion levels stay <= 35.
- `tests/test_overlay_controls.py`:
  - Added Overdrive enable-word sanity coverage and high-gain Cab
    model-2 safety coverage for the chain presets.
- `scripts/analyze_effect_recordings.py`:
  - Added a lightweight WAV analysis script that regenerates the nine
    comparison views used for this pass.
- `hw/ip/clash/vhdl/LowPassFir/*` was regenerated and the Vivado IP
  repackaged.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` was rebuilt and deployed.
  Final routed timing: WNS = -8.731 ns, TNS = -13665.555 ns,
  WHS = +0.051 ns, THS = 0.000 ns. This regresses WNS by 0.814 ns vs
  the previous deployed Amp/Cab build's -7.917 ns, still inside the
  accepted -6..-9 ns deploy band; hold remains clean.
- PYNQ-Z2 deploy completed with
  `PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh`.
  Smoke test loaded `AudioLabOverlay`, confirmed `ADC HPF: True`,
  `R19_ADC_CONTROL = 0x23`, found both Compressor and Noise Suppressor
  GPIOs, applied Overdrive and Compressor sanity settings, and applied
  all chain presets.
- The requested practical check sequence was applied on the board
  (Safe Bypass, Basic Clean, Light Crunch, Overdrive standalone,
  Compressor standalone, Tube Screamer Lead, DS-1 Crunch, RAT Rhythm,
  Big Muff Sustain, Vintage Fuzz, Metal Tight, Ambient Clean). The
  terminal session can verify preset application, not subjective
  loudspeaker / headphone listening.

What did **not** change:

- `hw/Pynq-Z2/block_design.tcl`.
- `topEntity` port list.
- GPIO names, addresses, or `ctrlA` / `ctrlB` / `ctrlC` / `ctrlD`
  meanings.
- Python API method names or Notebook UI structure.
- C++ DSP prototypes (`src/effects` remains removed).
- Commercial amp / cabinet IR / pedal circuit constants or GPL code.

## Amp/Cab real-voicing pass (this branch, `feature/amp-cab-real-voicing`)

The existing Amp Simulator and Cab IR stages were re-voiced toward a
generic guitar amp / cabinet response. This is **not** a new effect:
no new GPIO, no new `topEntity` port, no `block_design.tcl` change,
and no AXI address change. The work only changes constants / clip
helpers inside existing `LowPassFir.hs` stages plus a small chain
preset retune.

What landed:

- `hw/ip/clash/src/LowPassFir.hs`:
  - `ampHighpassFrame`: feedback coefficient `254 -> 253`, tightening
    sub-low rumble before the gain stages.
  - `ampDriveMultiplyFrame`: input gain ceiling reduced from ~31x to
    ~21x so high-gain pedals do not get squared again by the amp.
  - `ampAsymClip`, `ampPreLowpassFrame`, `ampSecondStageMultiplyFrame`:
    lower clip knees, darker pre-LPF range, and a slightly more
    character-driven second stage for clean / crunch / high-gain
    response separation.
  - `ampPowerFrame`, `ampResPresenceMixFrame`, `ampMasterFrame`: safety
    `softClipK` knees lowered so MASTER / presence / resonance cannot
    blow the post-amp chain into hard clipping.
  - `ampResPresenceProductsFrame`: presence capped to 75 % of the byte
    and resonance to 87.5 %, keeping high-end bite and low-end push
    without ice-pick highs or low-frequency bloom.
  - `cabCoeff`: the existing 4-tap cabinet table was rebuilt into
    three clearer models:
    - model 0: 1x12 open back style, lighter body, more open mid/air.
    - model 1: 2x12 combo style, balanced roll-off with presence left.
    - model 2: 4x12 closed back style, more delayed-body taps and the
      strongest fizz damping for Metal / Big Muff / Fuzz Face.
    `air` now restores only a capped direct-tap amount; `air=100` does
    not return to raw line-direct sound.
- `audio_lab_pynq/effect_presets.py`:
  - Basic Clean / Clean Sustain now use mild Amp + model 0 Cab.
  - Light Crunch uses model 0 Cab.
  - Metal / Noise Controlled High Gain use lower presence and model 2
    Cab with lower air.
  - Big Muff Sustain and Vintage Fuzz now lean on model 2 Cab; Vintage
    Fuzz keeps `mix=90` so it stays rawer than Metal.
- `hw/ip/clash/vhdl/LowPassFir/*` was regenerated and the Vivado IP
  repackaged.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` was rebuilt and deployed.
  Final routed timing: WNS = -7.917 ns, TNS = -13100.457 ns,
  WHS = +0.051 ns, THS = 0.000 ns. This regresses WNS by 0.382 ns vs
  the reserved-pedal build's -7.535 ns, still inside the -7..-9 ns
  deploy band; hold remains clean.
- PYNQ-Z2 deploy completed. Smoke test passed over Safe Bypass, Basic
  Clean, Light Crunch, Tube Screamer Lead, RAT Rhythm, DS-1 Crunch,
  Big Muff Sustain, Vintage Fuzz, Metal Tight, and Ambient Clean.
  `ADC HPF: True`; `R19_ADC_CONTROL = 0x23`.

What did **not** change:

- `hw/Pynq-Z2/block_design.tcl`.
- `topEntity` port list.
- GPIO names, addresses, or `ctrlA` / `ctrlB` / `ctrlC` / `ctrlD`
  meanings for `axi_gpio_amp`, `axi_gpio_amp_tone`, or `axi_gpio_cab`.
- Python API method names or Notebook UI structure.
- C++ DSP prototypes (`src/effects` remains removed).
- Commercial amp / cabinet IR / schematic coefficient copies or GPL
  code. The voicing is generic and hand-rolled.

## Reserved-pedal implementation (this branch, `feature/add-reserved-distortion-pedals`)

The three previously-reserved distortion pedals (`ds1` bit 3,
`big_muff` bit 4, `fuzz_face` bit 5) now have working Clash stages
in the deployed bitstream, slotting into the existing pedal-mask
pipeline alongside `clean_boost` / `tube_screamer` / `metal`. No
new GPIO, no new `topEntity` port, no `block_design.tcl` change.
Bit 7 of the pedal mask remains the only reserved slot, held for a
future 8th pedal.

What landed:

- `hw/ip/clash/src/LowPassFir.hs` -- three new pedal sections:
  - `ds1`: 5-stage chain (HPF -> mul -> asym soft clip with low
    knees -> post LPF -> level+safety). Voicing aim: BOSS DS-1
    style edgy crunch, brighter than tube_screamer.
  - `big_muff`: 5-stage chain (pre-gain ~1.5x..~13x -> softClipK
    medium knee -> softClipK tighter knee with ~0.75x gain ->
    tone LPF -> level+safety). Voicing aim: Big Muff Pi style
    thick fuzz with cascaded soft clip and a darker top end.
  - `fuzz_face`: 4-stage chain (pre-gain ~2x..~10x -> strong
    asymSoftClip with low/asymmetric knees -> tone LPF -> level+
    safety). Voicing aim: Fuzz Face style raw asymmetric breakup,
    "round vs. bright" tone axis.
  - `ds1On` / `bigMuffOn` / `fuzzFaceOn` predicates wired into
    `fxPipeline` between `metalLevelPipe` and `distortionPedalsPipe`.
  - `distortionPedalsPipe = fuzzFaceLevelPipe` (the new last stage
    of the per-pedal section).
- `audio_lab_pynq/effect_defaults.py` --
  `DISTORTION_PEDALS_IMPLEMENTED` now lists all seven pedal names.
- `audio_lab_pynq/effect_presets.py` -- six new
  `DISTORTION_PRESETS` entries (DS-1 Crunch / DS-1 Lead / Big Muff
  Sustain / Big Muff Wall / Fuzz Face / Fuzz Face Vintage), three
  new `CHAIN_PRESETS` entries (DS-1 Crunch / Big Muff Sustain /
  Vintage Fuzz). Every new preset keeps distortion `level <= 35`
  and compressor `makeup` in the 45..60 band so the safety
  contract (`DECISIONS.md` D15) holds.
- `audio_lab_pynq/AudioLabOverlay.py` -- bit-position docstring
  promoted from "reserved" to "implemented" for bits 3-5; no API
  surface change.
- `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb` --
  Distortion Pedalboard dropdown / SelectMultiple now expose plain
  `ds1` / `big_muff` / `fuzz_face` entries; the legacy
  `*_reserved` labels stay in `PEDAL_LABEL_TO_API` as backward-
  compatible aliases (also resolve to the implemented pedals).
  Reserved-pedal warning banner removed (RESERVED_PEDALS = empty
  set). Preset row split across two HBoxes since the new pedals
  doubled the button count. Fallback inline `PRESETS` /
  `CHAIN_PRESETS_INLINE` updated.
- `audio_lab_pynq/notebooks/DistortionModelsDebug.ipynb` --
  pedal list table updated to mark bits 3-5 as implemented and
  describe the voicing target. Live cell comment lists the new
  pedal names. Stack-mode comment updated for the new chain order.
- `audio_lab_pynq/notebooks/GuitarEffectSwitcher.ipynb` --
  pedalboard section text updated to mark all seven slots as
  implemented; three new preset cells (DS-1 Crunch / Big Muff
  Sustain / Fuzz Face) added after the Metal Tight cell.
- `tests/test_overlay_controls.py` -- new tests:
  `DISTORTION_PEDALS_IMPLEMENTED` shape, exclusive sets for ds1 /
  big_muff / fuzz_face, mask bit 7 stays unused, new presets
  satisfy the level cap, three new chain presets exist with the
  expected pedal name and the makeup/level contract.
- `hw/ip/clash/vhdl/LowPassFir/*` -- regenerated VHDL +
  repackaged IP (no `topEntity` port change; new pedal stages
  appear inside the existing module).

Hardware:

- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` -- rebuilt. Final
  routed timing recorded in `TIMING_AND_FPGA_NOTES.md`.
- PYNQ-Z2 deploy + smoke test recorded once the build completes.

What did **not** change:

- `block_design.tcl` (GPIO inventory, addresses, AXI interconnect).
  No new GPIO; no new master count.
- `topEntity` port list of `LowPassFir.hs`.
- `gate_control.ctrlA` flag byte semantics; the section still rides
  on bit 2 (legacy `distortion_on`).
- Existing `clean_boost` / `tube_screamer` / `rat` / `metal`
  voicing -- the new pedals slot in *after* the existing chain so
  none of the prior-build register stages were edited.
- Reserved bytes / bits other than the now-implemented bits 3-5
  (`axi_gpio_eq.ctrlD`, `axi_gpio_noise_suppressor.ctrlD`,
  `axi_gpio_distortion.ctrlD[7]` all stay reserved).
- Existing public Python API surface; chain preset names, byte
  caps, and Safe Bypass shape (existing tests pass byte-for-byte).
- C++ DSP prototypes (still removed, `DECISIONS.md` D13).

---

## Real-pedal voicing pass (prior branch, `feature/real-pedal-voicing-pass`)

Existing effect stages were re-tuned to be closer to recognised
real-pedal voicings, using only the existing GPIOs and `topEntity`
ports. No new effect stage, no new register, no `block_design.tcl`
change. The deployed bit/hwh was rebuilt from the new
`LowPassFir.hs` and pushed to the board.

What landed:

- `hw/ip/clash/src/LowPassFir.hs` -- voicing changes inside the
  existing register stages:
  - **Overdrive**: symmetric `softClip` -> `asymSoftClip` (tube-style
    even-harmonic content).
  - **clean_boost**: drive ceiling lowered from ~5x to ~4x;
    `cleanBoostLevelFrame` safety knee dropped from ~4.2M to ~3.2M.
  - **tube_screamer**: pre-HPF alpha range bumped (3..18), drive
    ceiling lowered (~7x vs. ~9x), asym clip knees dropped to
    `2_900_000 / 2_500_000`, post-LPF range shifted to
    `64..191` (darker top end at every TONE setting).
  - **RAT**: hard-clip floor lowered to `2_500_000` (more aggressive
    at high DRIVE), `ratPostLowpassFrame` alpha 192 -> 176, tone alpha
    base 224 -> 200.
  - **metal**: HPF alpha range bumped (6..37), drive ceiling lowered
    (~19x vs. ~22x), clip floor raised to `1_500_000`, post-LPF range
    shifted to `48..175` (darker top).
  - **Compressor**: soft-knee offset (`softThreshold = threshold -
    (threshold >> 4)`), gentler reduction slope (`excess >> 12` vs.
    `>> 11`).
  - **Noise Suppressor**: threshold hysteresis -- `closeT = threshold
    - (threshold >> 2)`, mid-gain check on the gain register decides
    the in-band region (no chatter).
  - **Cab IR**: 4-tap coefficient table re-balanced -- c0 reduced,
    c1/c2 increased -- so the very-high frequencies (close to
    Nyquist) are damped more.
  - **Reverb**: tone byte scaled (`tone - tone >> 3`) so TONE=100
    still keeps ~12.5 % damping in the recirculation path.
  - **EQ**: post-EQ mix wrapped in `softClip` so a max-boost on all
    three bands saturates softly instead of slamming the saturator.
- `docs/ai_context/REAL_PEDAL_VOICING_TARGETS.md` (new) -- per-effect
  reference style, current implementation, gap, plan, risk, and
  listening points.
- `docs/ai_context/DECISIONS.md` D16 -- recorded the constraints of
  the voicing pass.
- `docs/ai_context/DSP_EFFECT_CHAIN.md`,
  `docs/ai_context/TIMING_AND_FPGA_NOTES.md`,
  `docs/ai_context/RESUME_PROMPTS.md`, `README.md` -- updated.
- `hw/ip/clash/vhdl/LowPassFir/*` -- regenerated VHDL + repackaged IP.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` -- rebuilt. Final
  routed timing: WNS = -6.405 ns, TNS = -8806.714 ns,
  WHS = +0.052 ns, THS = 0.000 ns. **Improves on the deployed
  Compressor build's WNS (-7.516 ns) by 1.111 ns**; hold remains
  clean.
- PYNQ-Z2 deploy: completed; smoke test (`apply_chain_preset` over
  all 10 presets) passes, `R19_ADC_CONTROL = 0x23`, ADC HPF default-on
  preserved.

What did **not** change:

- `block_design.tcl` (GPIO inventory, addresses, AXI interconnect).
- `topEntity` port list of `LowPassFir.hs`.
- `gate_control.ctrlA` flag byte semantics.
- `axi_gpio_compressor` / `axi_gpio_noise_suppressor` enable
  semantics.
- Reserved bytes / bits (`axi_gpio_eq.ctrlD`,
  `axi_gpio_noise_suppressor.ctrlD`,
  `axi_gpio_distortion.ctrlD[3..5,7]`).
- Existing public Python API surface; chain preset names, byte caps,
  and Safe Bypass shape (no `effect_presets.py` change).
- C++ DSP prototypes (still removed, `DECISIONS.md` D13).

---

## Chain presets (prior branch, `feature/pedalboard-quality-presets`)

Ten named pedalboard voicings (Safe Bypass / Basic Clean / Clean
Sustain / Light Crunch / Tube Screamer Lead / RAT Rhythm / Metal
Tight / Ambient Clean / Solo Boost / Noise Controlled High Gain)
combine every section of the chain (Compressor + Noise Suppressor
+ Overdrive + Distortion Pedalboard + Amp + Cab IR + EQ + Reverb)
into one named state. Compressor `makeup` is held at 45..60 and
Distortion `level` is capped at 35 across every preset, so a click
on the wrong preset cannot blow the chain into clipping.

What landed:

- `audio_lab_pynq/effect_presets.py` -- `CHAIN_PRESETS` dict-of-dicts
  plus `CHAIN_PRESET_SECTIONS` canonical section list.
- `audio_lab_pynq/AudioLabOverlay.py` -- `apply_chain_preset`,
  `get_chain_preset_names`, `get_chain_preset`,
  `get_current_pedalboard_state`. Robust to missing GPIOs (older
  bitstream without `axi_gpio_compressor` still applies the rest).
- `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb` -- new
  Chain Preset dropdown + Apply Chain Preset / Show Current State
  buttons; existing accordion / Apply / Safe Bypass / Refresh kept
  intact. Two-cell layout preserved. Inline `CHAIN_PRESETS_INLINE`
  fallback for older deployed packages.
- `tests/test_overlay_controls.py` -- chain preset shape /
  Safe-Bypass-off-everywhere / makeup-band / distortion-level-cap /
  apply round-trip / unknown-name / missing-GPIO survival tests.
- `README.md`, `docs/ai_context/*.md` -- this file plus DSP_EFFECT_CHAIN
  / DECISIONS (new D15) / EFFECT_ADDING_GUIDE / RESUME_PROMPTS.

What did **not** change:

- Hardware (`block_design.tcl`, `LowPassFir.hs`, IP packaging,
  bitstream / hwh). The deployed Compressor build (`d216a9c`) is
  unchanged.
- Existing GPIO names, addresses, or ctrlA / B / C / D meanings.
- Compressor / Noise Suppressor / Distortion / amp / cab / eq /
  reverb DSP behaviour.
- Existing public Python API surface
  (every `set_*_settings` / `set_guitar_effects` keyword still
  works the same).

Vivado / Clash were **not** run. No timing review needed.

---


## Compressor add (this branch, `feature/compressor-effect`)

A new stereo-linked feed-forward peak compressor section was added on
its own AXI GPIO. Sits between the noise suppressor and the overdrive
in the Clash pipeline. Enable flag lives inside the new GPIO; the
master flag byte (`gate_control.ctrlA`) was not touched.

What landed:

- `hw/Pynq-Z2/block_design.tcl` -- new `axi_gpio_compressor` IP at
  `0x43CD0000`, `NUM_MI` bumped from 14 to 15, M14_AXI / M14_ACLK /
  M14_ARESETN wired, address segment added.
- `hw/ip/clash/src/LowPassFir.hs` -- new `compressor_control` port,
  `fComp` field on `Frame`, `compEnvNext` / `compTargetGain` /
  `compGainNext` / `compApplyFrame` / `compMakeupFrame` helpers, and
  the `compLevelPipe -> compEnv -> compGain -> compApplyPipe ->
  compMakeupPipe` block in `fxPipeline` between the noise suppressor
  and the overdrive.
- `audio_lab_pynq/control_maps.py` -- `makeup_to_u7`,
  `compressor_enable_makeup_byte`, `compressor_word` helpers.
- `audio_lab_pynq/effect_defaults.py` -- `COMPRESSOR_DEFAULTS`
  (`enabled=False, threshold=45, ratio=35, response=45, makeup=50`).
- `audio_lab_pynq/effect_presets.py` -- `COMPRESSOR_PRESETS`
  (Comp Off / Light Sustain / Funk Tight / Lead Sustain / Limiter-ish).
- `audio_lab_pynq/AudioLabOverlay.py` -- `axi_gpio_compressor`
  attribute, `_compressor_state` cache, `_apply_compressor_state_to_word`,
  `set_compressor_settings(threshold=, ratio=, response=, makeup=,
  enabled=)`, `get_compressor_settings()`, per-knob shortcuts.
- `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb` -- new
  Compressor accordion section (THRESHOLD / RATIO / RESPONSE /
  MAKEUP sliders + 5 presets); `apply_settings` / `safe_bypass` /
  `refresh_status` updated; chain header includes Compressor.
- `tests/test_overlay_controls.py` -- compressor encoding /
  round-trip / clamp / preset snapshot tests; defaults sanity test.
- `docs/ai_context/*.md` and `README.md` -- this file plus
  GPIO_CONTROL_MAP / DSP_EFFECT_CHAIN / DECISIONS (new D14) /
  BUILD_AND_DEPLOY / EFFECT_ADDING_GUIDE / RESUME_PROMPTS / TIMING.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` -- rebuilt with the
  new GPIO and DSP block. Final routed timing: WNS=-7.516 ns,
  TNS=-8815.426 ns, WHS=+0.052 ns, THS=0.000 ns. Regresses 0.405 ns
  vs the noise-suppressor build's `-7.111 ns`; still inside the
  historical deploy band.

What did **not** change:

- Existing GPIO names, addresses, or ctrlA / B / C / D meanings.
- Noise Suppressor stage, distortion pedal-mask, RAT, amp / cab / EQ /
  reverb stages.
- The pedal-mask shape from `baa97ff`.
- Existing public Python API surface (every `set_*_settings` /
  `set_guitar_effects` keyword still works the same).

---


## Effect-chain refactor (this branch, `feature/effect-chain-refactor`)

The Python control layer was split into smaller modules, the GPIO
inventory was promoted to a fixed ledger, the C++ DSP prototypes were
removed, and a new effect-adding guide / template were added. **No GPIO
re-allocation, no Clash change, no Vivado / bit / hwh rebuild.** The
deployed bitstream is unchanged.

What landed:

- `audio_lab_pynq/control_maps.py` — pack / unpack / clamp helpers (single
  source of truth for byte encoding).
- `audio_lab_pynq/effect_defaults.py` — per-effect default dicts; the
  legacy class attributes (`AudioLabOverlay.DISTORTION_DEFAULTS`,
  `NOISE_SUPPRESSOR_DEFAULTS`, `DISTORTION_PEDALS`,
  `DISTORTION_PEDALS_IMPLEMENTED`) are re-exported from here.
- `audio_lab_pynq/effect_presets.py` — Notebook + API presets;
  `DISTORTION_PRESETS`, `NOISE_SUPPRESSOR_PRESETS`. The notebook
  imports these with an inline fallback.
- `AudioLabOverlay.py` — the legacy classmethods (`_clamp_percent`,
  `_percent_to_u8`, `_level_to_q7`, `_pack3`, `_pack4`,
  `_noise_threshold_to_u8`, `_noise_suppressor_word`) are now thin
  delegates to `control_maps`. **Every public API is unchanged.**
- `tests/test_overlay_controls.py` — added module-level tests for
  `control_maps` / `effect_defaults` / `effect_presets`, plus
  byte-for-byte snapshot tests covering every preset and the Safe
  Bypass shape so future refactors cannot silently change the bits.
- `docs/ai_context/GPIO_CONTROL_MAP.md` — promoted to a fixed
  inventory with `active / reserved / legacy mirror / unused /
  deprecated` status per byte and an explicit "do not repurpose"
  rule set.
- `docs/ai_context/EFFECT_ADDING_GUIDE.md` (new) — decision flow,
  Clash rules, Python rules, notebook rules, deploy checklist.
- `docs/ai_context/EFFECT_STAGE_TEMPLATE.md` (new) — fillable spec
  sheet for new effects.
- `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb` — pulled
  presets from `effect_presets.py` (with inline fallback for older
  deployed packages); introduced `make_slider` / `make_section`
  helpers; split `apply_settings` into
  `apply_distortion_settings` / `apply_noise_suppressor_settings` /
  `apply_chain_settings`. Two-cell layout, Apply-button discipline,
  and visual structure are unchanged.
- `src/effects/` — **removed.** The C++ DSP prototypes were never on
  the live PL path; keeping them around invited the "implement in
  C++ then port" pattern that this project does not follow. See
  `DECISIONS.md` D12. `make tests` now runs Python tests only.

What did **not** change:

- GPIO names, addresses, and ctrlA / ctrlB / ctrlC / ctrlD assignments.
- `block_design.tcl`, `LowPassFir.hs` (DSP source), VHDL, IP packaging.
- `audio_lab.bit` / `audio_lab.hwh`. Timing baseline (WNS = -7.111 ns,
  WHS = +0.053 ns, THS = 0.000 ns) is unaffected — no rebuild was
  performed.
- Any audible behaviour. Snapshot tests guarantee the bits sent to
  the FPGA match the previous deployed bitstream byte-for-byte.

## Headline

The reserved-pedal implementation is **shipped**. `ds1` (bit 3),
`big_muff` (bit 4), and `fuzz_face` (bit 5) of the pedal-mask scheme
now have working independent register-staged Clash blocks; the Python
API and notebook UIs treat them as first-class implemented pedals.
Bit 7 stays reserved for a future 8th pedal slot. No new GPIO, no
`topEntity` port, no `block_design.tcl` change.

Earlier shipped milestones (still active in the deployed bitstream):
the pedal-mask distortion refactor (`DECISIONS.md` D6), the noise-
suppressor refactor (`DECISIONS.md` D11), the compressor section
(`DECISIONS.md` D14), the chain-preset layer (`DECISIONS.md` D15),
and the real-pedal voicing pass (`DECISIONS.md` D16). The 8-way
`model_select` distortion attempt remains rejected (`DECISIONS.md` D6).

## Working tree

`feature/add-reserved-distortion-pedals` carries the reserved-pedal
implementation, tagged at the parent commit as
`before-add-reserved-distortion-pedals`. The branch is local-only;
nothing has been pushed.

The previous pedal-mask arc lives on `master`:

```
3f2137d  Update AI context docs after pedal-mask distortion deployment
2198873  Add one-cell guitar pedalboard notebook
e1bb313  Add distortion pedalboard controls to GuitarEffectSwitcher notebook
baa97ff  Refactor distortion models into pedal-style pipeline
```

The noise-suppressor branch touches:

- `hw/Pynq-Z2/block_design.tcl` -- new `axi_gpio_noise_suppressor` IP
  at `0x43CC0000`, `NUM_MI` bumped to 14.
- `hw/ip/clash/src/LowPassFir.hs` -- new `noise_suppressor_control`
  port, `fNs` field on `Frame`, `nsEnvNext` / `nsGainNext` /
  `nsApplyFrame` / helpers, pipeline wiring updated.
- `hw/ip/clash/vhdl/LowPassFir/*` -- regenerated VHDL + repackaged IP.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` -- rebuilt with the new
  GPIO and DSP block.
- `audio_lab_pynq/AudioLabOverlay.py` -- `NOISE_SUPPRESSOR_*`
  constants, `_noise_threshold_to_u8`, `set_/get_noise_suppressor_*`,
  `_apply_noise_suppressor_state_to_word`, `set_guitar_effects`
  mirrors threshold + on-flag into the new GPIO.
- `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb` -- Noise
  Gate accordion replaced with Noise Suppressor section (THRESHOLD /
  DECAY / DAMP sliders + four NS presets); `apply_settings` /
  `safe_bypass` / `refresh_status` updated.
- `tests/test_overlay_controls.py` -- threshold scale anchors
  (0/10/50/100 -> 0/3/13/26), clamps, NS settings round trip, GPIO
  word packing, mirror-to-gate test, `set_guitar_effects` NS GPIO
  mirror.
- `docs/ai_context/*.md` -- this file plus GPIO map, DSP chain,
  decisions, build/deploy, project context, timing, resume prompts.

## What ships in the current bitstream

Pedal stages live between the existing RAT block and the amp /
cab / EQ / reverb tail of the pipeline. Master enable stays on
`gate_control` bit 2 (the existing `distortion_on`).

| Pedal | bit (`distortion_control.ctrlD`) | Status |
| --- | --- | --- |
| `clean_boost` | 0 | Clash stage implemented (3 register stages). |
| `tube_screamer` | 1 | Clash stage implemented (5 register stages). |
| `rat` | 2 | Mapped onto the existing RAT stage; Python forces `gate_control` bit 4 high when this bit is set. |
| `ds1` | 3 | Clash stage implemented (5 register stages; HPF -> mul -> asym soft clip -> post LPF -> level+safety). BOSS DS-1 style voicing. |
| `big_muff` | 4 | Clash stage implemented (5 register stages; pre-gain -> two cascaded soft clip stages -> tone LPF -> level+safety). Big Muff Pi style voicing. |
| `fuzz_face` | 5 | Clash stage implemented (4 register stages; pre-gain -> strong asym soft clip -> tone LPF -> level+safety). Fuzz Face style voicing. |
| `metal` | 6 | Clash stage implemented (5 register stages). |
| reserved | 7 | Unused; held for a future 8th pedal slot. |

Legacy distortion (the original `distortion_*` API and Clash stages)
still works: it gates on `distortion_legacyOn = flag2(fGate) AND
NOT anyDistPedalOn`. As soon as any pedal-mask bit is set, the
legacy stage steps aside.

## Live verification

Run on the board after deploy:

```
ADC HPF        : True
R19_ADC_CONTROL: 0x23
clean_boost    mask=0x01  drive=40 level=35
tube_screamer  mask=0x02  drive=40 level=35
rat            mask=0x04  drive=40 level=35
ds1            mask=0x08  drive=40 level=35
big_muff       mask=0x10  drive=40 level=35
fuzz_face      mask=0x20  drive=40 level=35
metal          mask=0x40  drive=40 level=35
cleared        mask=0x00
```

ADC HPF default-on (`R19_ADC_CONTROL = 0x23`) survives. Every pedal
mask bit lands at the documented position. `clear_distortion_pedals`
returns the section to zero.

## Vivado timing summary (deployed bit)

| Build | WNS | TNS | Verdict |
| --- | --- | --- | --- |
| Pre-refactor baseline | -7.722 ns | -4613.495 ns | Shipped, audio works in practice. |
| Rejected `model_select` | -15.067 ns | -7308.247 ns | Not deployed. |
| pedal-mask (initial) | -7.801 ns | -7381.742 ns | Deployed. |
| Noise suppressor add | -7.111 ns | -7683.480 ns | Deployed. |
| Compressor add | -7.516 ns | -8815.426 ns | Deployed. |
| Real-pedal voicing pass | -6.405 ns | -8806.714 ns | Deployed. |
| Reserved-pedal implementation | -7.535 ns | -11297.604 ns | Deployed. WNS regresses 1.130 ns vs voicing-pass build, still inside the historical -7..-9 ns band. |
| Amp/Cab real-voicing pass | -7.917 ns | -13100.457 ns | Deployed. WNS regresses 0.382 ns vs reserved-pedal build; hold clean. |
| **Audio-analysis voicing fixes (current)** | **-8.731 ns** | -13665.555 ns | Deployed. WNS regresses 0.814 ns vs Amp/Cab build; hold clean and still inside the accepted deploy band. |

Hold timing is fine (`WHS = +0.051 ns`, `THS = 0.000 ns`). Setup is
still slightly negative; not a regression versus the historical
deploy band, but the build is not formally clean. Treat any further
timing slip with suspicion. The full chronology (with per-build
notes) is in
[`TIMING_AND_FPGA_NOTES.md`](TIMING_AND_FPGA_NOTES.md).

## Notebooks

| Notebook | Status |
| --- | --- |
| `audio_lab_pynq/notebooks/InputDebug.ipynb` | Existing input-noise triage notebook, ADC HPF default-on aware. |
| `audio_lab_pynq/notebooks/GuitarEffectsChain.ipynb` | Existing chain UI. Untouched in this refactor. |
| `audio_lab_pynq/notebooks/GuitarEffectSwitcher.ipynb` | **Updated** for the reserved-pedal implementation: pedalboard section text marks all seven slots implemented; new DS-1 Crunch / Big Muff Sustain / Fuzz Face preset cells added after the Metal Tight cell. |
| `audio_lab_pynq/notebooks/DistortionModelsDebug.ipynb` | **Updated** for the reserved-pedal implementation: pedal table now marks bits 3-5 as implemented; live cell comment lists the new pedals; stack-mode comment mentions the updated chain order. |
| `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb` | **Updated** for the reserved-pedal implementation: dropdown / SelectMultiple expose plain `ds1` / `big_muff` / `fuzz_face` entries (legacy `*_reserved` aliases kept for backward compat); reserved-pedal warning banner removed; preset row split into two HBoxes; fallback inline `PRESETS` / `CHAIN_PRESETS_INLINE` updated. |

All five notebooks are deployed under
`/home/xilinx/jupyter_notebooks/audio_lab/` on the board.

## What to do next

Open work, in roughly priority order:

1. **8th pedal slot.** Bit 7 of `distortion_control.ctrlD` is the
   only remaining reserved pedal slot. If a future voicing wants
   in, it lands there as a new register-staged Clash block
   following the same shape as the new `ds1` / `big_muff` /
   `fuzz_face` stages.
2. **Drive WNS toward 0.** The deployed build is at the value
   recorded in `TIMING_AND_FPGA_NOTES.md`; the audio path
   tolerates the current band in practice but the build is not
   formally clean. Worth a pass that splits any remaining deeper
   combinational stage and / or pipelines the cab or reverb tap
   address paths.
3. **UI / preset polish** in the notebooks. Possible adds:
   per-pedal default presets, an A/B compare cell, a quick-record
   cell that pairs the pedalboard with the existing diagnostic
   capture helpers.
4. **Diagnostic capture for distortion stages.** Re-use
   `diagnostics.capture_input` to log a clip waveform per pedal so
   we can compare voicings without ear fatigue.

## Things to be careful about

- Do **not** silently revert the ADC HPF default-on. `R19_ADC_CONTROL`
  must read back as `0x23` after `config_codec()`.
- Do **not** reintroduce a single function with a `case` over all
  seven pedals. That is exactly what regressed timing the first time;
  see `TIMING_AND_FPGA_NOTES.md`.
- Do **not** deploy a bitstream whose WNS is significantly worse than
  the current audio-analysis voicing build's WNS (-8.731 ns) without
  flagging the regression first. A -15 ns-class result remains a hard
  reject.
- Do **not** revive the legacy `gateGainNext` / `gateFrame` registers
  in the active pipeline. The active gain stage is the noise
  suppressor (`nsApplyFrame`); the legacy helpers are kept as Haskell
  source for backward compatibility but are not wired up.
- Do **not** drop the legacy `gate_control.ctrlB` write from
  `set_guitar_effects` -- older bitstreams without
  `axi_gpio_noise_suppressor` still rely on it.
- Do **not** push, pull, or fetch.
