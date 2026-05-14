# Timing and FPGA notes

## Slack vocabulary

- **WNS** — Worst Negative Slack on setup paths. Negative means at least
  one path needs more time than the clock period allows.
- **TNS** — Total Negative Slack on setup. Sum of every failing endpoint;
  shows whether timing is "one bad path" vs. "broadly tight".
- **WHS / THS** — Hold-side equivalents. Hold violations cannot be hidden
  by lowering the clock, so they are more dangerous than setup ones.
- A negative WNS does not mean the design is broken in simulation; it
  means it may glitch at the configured clock frequency.

## Recorded baselines

| Build | WNS | TNS | Notes |
| --- | --- | --- | --- |
| Pre-distortion-refactor (May 1) | -7.722 ns | -4613.495 ns | Original baseline. Audio works in practice. |
| Distortion `model_select` attempt (May 4) | -15.067 ns | -7308.247 ns | 8-way model mux; **rejected**, never deployed. |
| Pedal-mask refactor (May 4) | -7.801 ns | -7381.742 ns | Seven independent pedal stages. Deployed; live-verified. Setup slack roughly baseline-equivalent. |
| **Noise-suppressor refactor (May 5, deployed)** | **-7.111 ns** | -7683.480 ns | Adds `axi_gpio_noise_suppressor` (`0x43CC0000`) and the `nsLevelPipe -> nsEnv -> nsGain -> nsPipe` block in place of the legacy hard gate. WNS improves by 0.690 ns vs the pedal-mask baseline; the new block has one fewer feedback register (no `gateOpen` boolean stage) so it is slightly cheaper than what it replaced. Hold remains clean (`WHS = +0.053 ns`, `THS = 0.000 ns`). |
| **Compressor add (May 5, deployed)** | **-7.516 ns** | -8815.426 ns | Adds `axi_gpio_compressor` (`0x43CD0000`) and the `compLevelPipe -> compEnv -> compGain -> compApplyPipe -> compMakeupPipe` block between the noise suppressor and the overdrive. Same shape as the noise suppressor (one envelope-input register stage, two feedback registers, one apply stage) plus a separate makeup multiply stage so each register holds a single multiply. WNS regresses by 0.405 ns vs the noise-suppressor build (`-7.111 ns -> -7.516 ns`), still inside the historical -7..-9 ns deploy band. Hold remains clean (`WHS = +0.052 ns`, `THS = 0.000 ns`). |
| **Real-pedal voicing pass (May 6, deployed)** | **-6.405 ns** | -8806.714 ns | Constants and clip-helper choice retuned inside the existing register stages of `LowPassFir.hs` (Overdrive / clean_boost / tube_screamer / RAT / metal / Compressor / Noise Suppressor / Cab IR / Reverb / EQ); see `REAL_PEDAL_VOICING_TARGETS.md` and `DECISIONS.md` D16. No new register stage, no new GPIO, no `block_design.tcl` change, no `topEntity` port change. WNS **improves** by 1.111 ns vs the Compressor build (`-7.516 ns -> -6.405 ns`); the swapped `asymSoftClip` / `softClipK` / hysteresis logic happens to route slightly better than the symmetric `softClip` / hard-knee paths it replaced. Hold remains clean (`WHS = +0.052 ns`, `THS = 0.000 ns`). |
| **Reserved-pedal implementation (May 7, deployed)** | **-7.535 ns** | -11297.604 ns | Adds three independent register-staged pedal sections (`ds1` 5 stages, `big_muff` 5 stages, `fuzz_face` 4 stages) to `fxPipeline` after `metalLevelPipe`; `distortionPedalsPipe = fuzzFaceLevelPipe`. No new GPIO, no new `topEntity` port, no `block_design.tcl` change. The three new stage chains add 14 register stages worth of pipeline depth but each stage holds at most one multiply / one one-pole IIR / one clip helper (same shape as the existing `clean_boost` / `tube_screamer` / `metal`). WNS regresses by 1.130 ns vs the voicing-pass build (`-6.405 ns -> -7.535 ns`); still inside the historical -7..-9 ns deploy band. Hold remains clean (`WHS = +0.051 ns`, `THS = 0.000 ns`). TNS rises (more failing endpoints because the new stages share the same critical-clock domain) but no single endpoint is dramatically worse. |
| **Amp Simulator named models (May 7, deployed)** | **-8.122 ns** | -13519.447 ns | Adds the `ampModelSel :: Unsigned 8 -> Unsigned 2` quantiser and a per-band darken (`0/2/8/16`) on `ampPreLowpassFrame`'s alpha. No new register stage, no new GPIO, no `topEntity` port change, no `Frame` field change. WNS improves 0.609 ns vs the audio-analysis build (`-8.731 ns -> -8.122 ns`); the cheaper alpha computation happens to route slightly better than the previous unbiased path. Hold stays clean (`WHS = +0.051 ns`, `THS = 0.000 ns`). |
| **Amp/Cab real-voicing pass (May 7, deployed)** | **-7.917 ns** | -13100.457 ns | Retunes only existing Amp/Cab stages: amp HPF/gain/clip/presence/resonance/master constants and the 4-tap `cabCoeff` model table. No new GPIO, no new `topEntity` port, no `block_design.tcl` change, no new register stage. WNS regresses by 0.382 ns vs the reserved-pedal build (`-7.535 ns -> -7.917 ns`), still inside the historical -7..-9 ns deploy band and far from the rejected -15 ns mux failure. Hold remains clean (`WHS = +0.051 ns`, `THS = 0.000 ns`). |
| **Audio-analysis voicing fixes (May 7, deployed)** | **-8.731 ns** | -13665.555 ns | Retunes only existing Compressor / Overdrive / Amp / Cab stages from the recording analysis in `AUDIO_RECORDING_ANALYSIS.md`: compressor threshold/knee/response constants, Overdrive drive/clip/safety constants, Amp treble/presence/LPF/safety constants, and the 4-tap `cabCoeff` table. No new GPIO, no new `topEntity` port, no `block_design.tcl` change, no new register stage. A trial Cab post-mix `softClipK 3_400_000` build reached WNS = -9.891 ns and was **not** deployed; the final deployed build keeps `cabLevelMixFrame` on the existing `softClip`. WNS regresses by 0.814 ns vs the Amp/Cab build (`-7.917 ns -> -8.731 ns`), still inside the accepted deploy band. Hold remains clean (`WHS = +0.051 ns`, `THS = 0.000 ns`). |
| **Amp Simulator fizz-control pass (May 8, deployed)** | **-8.022 ns** | -13937.512 ns | Retunes only existing Amp Simulator stages to reduce high-frequency fizz: `ampPreLowpassFrame` model darken becomes `0/4/12/24`, `ampTrebleGain` becomes character-aware with a small model trim, `ampResPresenceProductsFrame` adds model-dependent presence trim, and `ampPowerFrame` / `ampResPresenceMixFrame` safety knees move from `3_500_000` to `3_400_000`. No new GPIO, no new `topEntity` port, no `block_design.tcl` change, no new register stage, no Delay implementation. WNS improves by 0.709 ns vs the audio-analysis build (`-8.731 ns -> -8.022 ns`); hold remains clean (`WHS = +0.052 ns`, `THS = 0.000 ns`). Utilization after place: Slice LUTs 21809 (40.99%), Slice Registers 18675 (17.55%), Block RAM Tile 7 (5.00%), DSPs 158 (71.82%). |
| **LowPassFir behavior-preserving split (May 8, deployed)** | **-8.022 ns** | -13937.512 ns | Splits `LowPassFir.hs` into `AudioLab.Types`, `FixedPoint`, `Control`, `Axis`, `Effects.*`, and `Pipeline` modules without changing DSP behavior, coefficients, bit widths, `Frame` shape, pipeline order, `topEntity` ports, `block_design.tcl`, GPIOs, Python API, Notebook UI, or Chain Presets. VHDL/IP and bit/hwh rebuilt successfully; WNS delta is 0.000 ns vs the deployed Amp fizz-control baseline and hold remains clean (`WHS = +0.052 ns`, `THS = 0.000 ns`). Utilization after place is unchanged: Slice LUTs 21809 (40.99%), Slice Registers 18675 (17.55%), Block RAM Tile 7 (5.00%), DSPs 158 (71.82%). Deployed to PYNQ-Z2 with `PYNQ_HOST=192.168.1.9`; smoke test confirmed ADC HPF, absence of `axi_gpio_delay_line`, legacy `axi_gpio_delay`, amp models, and chain presets. |
| **Internal mono DSP pipeline (May 9, deployed)** | **-8.155 ns** | -6492.876 ns | Keeps external AXI/I2S as 48-bit stereo but runs the active DSP path from ADC Left as a mono source, discards Right input, and duplicates the mono result back to output Left/Right. `topEntity`, `block_design.tcl`, GPIOs, Python API, Notebook UI, and Chain Presets are unchanged. `Frame.fLast` carries TLAST from input to output; `fxPipeline` paces accepted DMA frames so the fixed-latency DSP core keeps one output per accepted input during short S2MM backpressure. WNS regresses by 0.133 ns vs the minimal mono / `37ef4c7` baseline (`-8.022 ns -> -8.155 ns`), still inside the deployed -6..-9 ns band. Hold remains clean (`WHS = +0.052 ns`, `THS = 0.000 ns`). Utilization after place: Slice LUTs 15473 (29.08%), Slice Registers 14914 (14.02%), Block RAM Tile 7 (5.00%), DSPs 83 (37.73%). Deployed to PYNQ-Z2 and DMA Case A/B/C completed without timeout; output L/R matched exactly after skip 16 and Right input rejection was confirmed. |
| **HDMI GUI Phase 4 integrated framebuffer (May 15, deployed)** | **-8.163 ns** | -6599.061 ns | Adds the HDMI GUI framebuffer path around the existing AudioLab DSP: `axi_vdma_hdmi` (`0x43CE0000`), `v_tc_hdmi` (`0x43CF0000`), `v_axi4s_vid_out_hdmi`, Digilent `rgb2dvi_hdmi`, `clk_wiz_hdmi`, `rst_video_0`, and `axi_smc_hdmi`. The HDMI path is sourced from `hw/Pynq-Z2/hdmi_integration.tcl`; Clash/DSP source, `topEntity`, existing GPIO names/addresses, and `axi_gpio_delay` legacy RAT semantics are unchanged. GUI RGB888 is packed as DDR `GBR888` and scanned out as a 24-bit stream. WNS regresses by only 0.008 ns vs the internal mono baseline (`-8.155 ns -> -8.163 ns`) and remains inside the Phase 4 deploy gate. Hold remains clean (`WHS = +0.051 ns`, `THS = 0.000 ns`). Utilization after place: Slice LUTs 18619 (35.00%), Slice Registers 20846 (19.59%), Block RAM Tile 9 (6.43%), DSPs 83 (37.73%). Deployed to PYNQ-Z2; smoke confirmed ADC HPF/R19, legacy GPIO contract, chain presets, HDMI IP in HWH/ip_dict, and static GUI frame VDMA scanout with no VDMA error bits. Physical monitor display still needs visual confirmation. |

WHS = +0.051 ns / THS = 0.000 ns on the deployed HDMI Phase 4 build, so
hold is clean. WNS is still slightly negative; treat any further timing
slip as a regression.

## Why the `model_select` attempt regressed timing

The first refactor put eight parallel computations behind a single
`case modelSelect of …` in every distortion stage:

- `distModelClipFrame` had eight different clip variants, each with its
  own knee/threshold arithmetic, fed into one final mux.
- `distModelPostFilterFrame` computed `lp`, `hp`, and `blend` in
  parallel and selected on `modelSelect`.
- `modelPreGain` returned a different `Unsigned 12` per model, yielding
  an 8-way mux feeding a 24×12 multiply.

Each of those builds a tall combinational tree per stage. Even with
register stages between, the **per-stage** depth blew through the 10 ns
clock window, pushing WNS from −7.7 ns to −15.1 ns.

## Rules of thumb that hold for this design

- A single `case` over a small enum is fine **inside a register stage**
  if the case body is cheap (a constant lookup, a conditional add).
  Do not put a multiply or a clip behind a wide case.
- Multipliers (`mulU8`, `mulU12`, `mulS10`) are DSP48 hard blocks and
  pipeline well, but their inputs and outputs need their own register
  stages in this design. Don't chain `mulU12 -> case -> hardClip` in
  one combinational block.
- One-pole IIR filters (`onePoleU8`) take one stage's worth of depth
  on their own. Keep them in their own register stage when possible.
- BRAM-backed delays (e.g. the reverb tap) should not have their
  address path cross a model selector — the address is needed early
  and any extra fanout makes the read-data path tighter.

## Deploy gate

A bitstream may be deployed only if the Vivado run prints
`write_bitstream completed successfully` **and** the final WNS is no
worse than the previous deployed build by an audibly meaningful
margin (latest deployed build: -8.163 ns from the HDMI GUI Phase 4
integrated framebuffer build). If timing
slips significantly, the change must be revisited (more pipeline
stages, simpler mux structure, or fewer features) before any deploy.

When adding a new pedal or filter stage:

- Keep each pedal as its own register-staged block. Reuse the
  shape of `clean_boost`, `tube_screamer`, or `metal`.
- **Do not** add a single function with a wide `case` selecting
  between independent multipliers / clippers / filters. That is the
  pattern that caused the -15.067 ns regression.

When timing is significantly worse, the user-visible failure modes are
typically:

- Audio glitches that come and go with PVT and routing decisions.
- Occasional wrong sample values, perceived as crackle or DC pops.
- In the worst case, BRAM corruption (this design has BRAM-backed
  reverb taps).

These do not show up in passthrough mode but appear once an effect that
exercises a slow path is enabled, which makes them hard to debug from
inside Jupyter.
