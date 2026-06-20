# Codex Agent Guide

This repository is **Audio-Lab-PYNQ** (a.k.a. FPGA_GuitarEffecter), a real-time
guitar effect chain that runs on a PYNQ-Z2 board. The current deployed audio
path uses a Digilent Pmod I2S2 module on PMOD JB for line input/output, keeps
the ADAU1761 codec configured for I2C/HPF health checks and debug visibility,
and processes samples through a Clash/VHDL DSP block synthesised under Vivado
2019.1 plus a Python / PYNQ control layer.

## Read These First

Codex must not re-scan the whole repository on each session. Even after a
context reset or compaction, treat `docs/ai_context/` as the source of truth,
not the possibly summarised conversation history.

1. `docs/ai_context/PROJECT_CONTEXT.md` - what the system does and where the
   pieces live.
2. `docs/ai_context/CURRENT_STATE.md` - what is in flight right now and what
   should not be touched.
3. `docs/ai_context/DECISIONS.md` - load-bearing design decisions and why each
   decision exists.

Then read the topic doc that matches the work:

| Work | Read |
| --- | --- |
| Adding a new effect | `docs/ai_context/EFFECT_ADDING_GUIDE.md` (+ `EFFECT_STAGE_TEMPLATE.md`) |
| Clash / DSP edits | `docs/ai_context/DSP_EFFECT_CHAIN.md` |
| DSP simulation / measured voicing | `tools/dsp_sim/README.md`, `docs/ai_context/MODEL_REALISM_GAP_ANALYSIS.md`, `docs/ai_context/DECISIONS.md` D121-D145 |
| Refactoring (DSP / Python / build) | `docs/ai_context/REFACTORING_CANDIDATES.md` |
| GPIO bit allocation | `docs/ai_context/GPIO_CONTROL_MAP.md` |
| Audio routing / passthrough debug | `docs/ai_context/AUDIO_SIGNAL_PATH.md` |
| Distortion model work | `docs/ai_context/DISTORTION_REFACTOR_PLAN.md` |
| Vivado / timing | `docs/ai_context/TIMING_AND_FPGA_NOTES.md`, `docs/ai_context/DSP_ISLAND_CLOCK_DESIGN.md` |
| Bitstream build / deploy | `docs/ai_context/BUILD_AND_DEPLOY.md` |
| PYNQ-Z2 board operations | `docs/ai_context/PYNQ_RUNTIME.md` |
| Wah effect / FP02M pedal | `docs/ai_context/WAH_EFFECT_INTEGRATION_PLAN.md`, `docs/ai_context/FP02M_PEDAL_INTEGRATION.md`, `docs/ai_context/XADC_INTEGRATION_DESIGN.md` |
| Pmod I2S2 external audio | `docs/ai_context/PMOD_I2S2_INTEGRATION_PLAN.md`, `docs/ai_context/AUDIO_SIGNAL_PATH.md` |
| Rotary encoder runtime / GUI live apply | `docs/ai_context/ENCODER_GUI_CONTROL_SPEC.md`, `docs/ai_context/ENCODER_INPUT_IMPLEMENTATION.md`, `docs/ai_context/ENCODER_INPUT_MAP.md`, `scripts/run_encoder_hdmi_gui.py` |
| Footswitch FX toggle / preset stepping | `docs/ai_context/FOOTSWITCH_INTEGRATION.md` (+ `DECISIONS.md` D78) |
| HDMI GUI / 5-inch LCD | `docs/ai_context/HDMI_GUI_INTEGRATION_PLAN.md` (+ `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE5A_OUTPUT_SIDE_DIAGNOSIS.md`, `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE5B_NATIVE_800X480_TIMING_PLAN.md`, `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE6F_FIX_HDMI_X_ORIGIN.md`, `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE6G_ACTUAL_UI_X_ORIGIN.md`, `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE6H_PORT_1PY_SPEC.md`, `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE6H_NATIVE_800X480_TIMING.md` (rejected), `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE6I_800X480_TIMING_SWEEP.md`) |
| Resuming after a stop | `docs/ai_context/RESUME_PROMPTS.md` (current prompts only; per-phase history in `docs/ai_context/RESUME_PROMPTS_HISTORY.md`) |

## Resuming Work

When a previous turn stopped mid-implementation:

1. Run `git status --short` and `git diff --stat` first. Do not discard
   uncommitted work.
2. Re-read `docs/ai_context/CURRENT_STATE.md` and
   `docs/ai_context/RESUME_PROMPTS.md`.
3. Continue from the staged / unstaged state. Do not silently revert to an older
   design because the conversation history is fragmented.

## Hard Constraints

- `hw/Pynq-Z2/block_design.tcl` is **off-limits** unless the user explicitly
  approves a block-design change. New control bits go into spare bytes of the
  existing AXI GPIOs; new effect stages reuse existing GPIO topology. Shipped
  additive exceptions include `axi_gpio_noise_suppressor` at `0x43CC0000`
  (D11), `axi_gpio_compressor` at `0x43CD0000` (D14), `axi_gpio_wah` at
  `0x43D30000` (D72/D73), `xadc_wiz_a0` at `0x43D40000` (D76), and
  `axi_footswitch_input` at `0x43D50000` (D78). These are added by dedicated
  `*_integration.tcl` scripts sourced from `create_project.tcl`, not by editing
  `block_design.tcl`.
- **GPIO design is fixed** (`DECISIONS.md` D12). Names, addresses, and
  `ctrlA` / `ctrlB` / `ctrlC` / `ctrlD` semantics in
  `docs/ai_context/GPIO_CONTROL_MAP.md` are a contract. Do not rename
  `axi_gpio_delay`, move bytes, or repurpose `legacy mirror` / `reserved` slots
  for unrelated effects. New effects land on documented reserved bits / bytes
  first.
- C++ DSP prototypes were removed (`DECISIONS.md` D13). Live DSP behaviour is
  owned by `hw/ip/clash/src/LowPassFir.hs` plus the `hw/ip/clash/src/AudioLab/`
  modules it imports. Do not write a new C++ prototype as a stepping stone.
- The ADAU1761 ADC HPF is **default-on** (`R19_ADC_CONTROL == 0x23`). Do not
  remove or skip the HPF enable in `config_codec()`.
- The selectable distortion section is **pedal-mask-based** (D6/D9). Do not
  roll it back to a `model_select` / 8-way mux design. Bits 3 / 4 / 5 are
  implemented as `ds1` / `big_muff` / `fuzz_face`; bit 7 stays reserved for an
  8th pedal slot.
- Any change under `hw/ip/clash/src/LowPassFir.hs` or `hw/ip/clash/src/AudioLab/`
  that changes DSP logic requires Clash VHDL regeneration, IP repackage,
  Vivado bit/hwh rebuild, a fresh timing summary, deploy, programmatic smoke,
  and user ear-bench before it can be treated as accepted. D109 BOUNDS (does NOT
  eliminate) the safe-bypass CDC knife-edge, so a DSP voicing rebuild is allowed
  but EACH new bitstream must be ear-benched for a constant DIGITAL BUZZ on the
  bypass passthrough -- the slack number does not predict it. **Accepted deployed
  baseline is D148**: merge commit `96ef899`, bit md5
  `972d9ba6645dd966e6bdcb5bc3daf478`, hwh md5
  `2b888ff1ec3168cd64e1b679bbbc71be` -- the JC-120 / Fender-Twin clean-headroom
  fix for a playing-only `音割れ` (bypass confirmed clean = NOT CDC), localized
  with the new `tools/dsp_sim/clip_onset.py` (JC ~0.18 FS at the power/master
  soft knee, Twin ~0.12-0.18 FS at the `ampAsymClip` waveshaper) and fixed with
  placement-safe knee constants only (`ampPowerKnee` JC 6.8M->8.2M + Twin
  4.6M->6.8M + clean-mode-only `ampCleanKneeBonus`, Twin 2.5M); golden 20/20 NO
  re-bless. The merge ALSO carries D146 (hard pblock locking the audio-output CDC
  cells to `SLICE_X100Y116:SLICE_X113Y137` -- the robust knife-edge attack) and
  D147 (amp sag-attack slew `ampSagAttackStep=96`). It supersedes the
  long-standing **D135** (`765323b`, bit `533d586901dc3669285a49c6d82bab9f`) =
  large non-IR realism (Fuzz Face 900 Hz mid-hump biquad + tighter clip knees +
  opened tone LPF; AC30/JCM800 stronger `ampScoop` + model-local presence; Amp
  MIDDLE more audible; AC30 clean headroom; Cab non-IR body tap). **History: the
  D136-D142 `feature/amp-clean-headroom` amp-clean line was BENCH-REJECTED and
  rolled back to D135 on 2026-06-19: the cumulative footprint re-triggered the
  knife-edge (constant digital buzz). Re-placing (Explore = byte-identical
  placement) AND tightening the CDC `set_max_delay` 10->6 ns BOTH failed; the
  voicing was correct in the offline sim -- the blocker was placement. The
  narrower D144 chord-detune candidate was also BENCH-REJECTED ("失敗") and rolled
  back to D135.** The robust attack that finally landed = the D146 hard pblock
  above (the `tools/dsp_sim/chord_eval.py` chord-IMD detector and `clip_onset.py`
  from that arc were KEPT). The post-D112 sag-removal/static-trim line
  (D119/D120) remains abandoned; do not re-attempt Amp sag removal or static sag
  trimming without explicit direction. Roll back to D135 via
  `git checkout 765323b -- hw/Pynq-Z2/bitstreams/`.
  See `DECISIONS.md` D109-D148, `CURRENT_STATE.md`, and `baselines.json`.
- For effect voicing work, prefer the offline DSP sim / measurement loop before
  paying the Vivado cost: build/run `tools/dsp_sim`, use
  `tools/dsp_sim/measure.py` for net tone-curve checks, and keep golden/bypass
  invariants passing. The sim is a design filter, not an acceptance substitute;
  timing, board smoke, and user bench listening still gate deployed DSP changes.
- The audio sample rate is **96 kHz as of D98**. Pmod BCLK is MCLK/2 with
  MCLK still 12.288 MHz; LRCK is 96 kHz. Any fs-dependent DSP constant must be
  voiced for 96 kHz, not the pre-D98 48 kHz path. The 4x oversampler interp and
  15-tap decimation FIRs are ratio-based and were intentionally left
  fs-independent.
- The DSP runs in a **clock-domain island on FCLK_CLK1**, currently set by
  `hw/Pynq-Z2/island_integration.tcl` to **33.33 MHz** (D75 50 MHz -> D89
  40 MHz -> D94 33.33 MHz). Only `clash_lowpass_fir_0` is clocked by FCLK1.
  The rest of the fabric (AXI / DMA / `i2s_to_stream` / Pmod / HDMI) stays on
  FCLK0 at 100 MHz, bridged by `cc_dsp_in` / `cc_dsp_out`. Do **not** lower the
  whole fabric clock; that corrupts the I2S/Pmod CDCs and causes audible buzz.
- Three DSP-island pieces are load-bearing and must not be reverted:
  `Pipeline.hs` `acceptReady = readyOut` (the `paceCount` removal), the
  `syncCtrl` control-word CDC in `LowPassFir.hs`, and the D109 CDC hardening in
  `hw/Pynq-Z2/audio_lab.xdc`.
- The D109 `audio_lab.xdc` CDC hardening is specific: `clk_fpga_0` and `clk`
  must remain timed relative to each other, with `set_max_delay -datapath_only
  10.000` both directions. Do not collapse the constraints back to one blanket
  async 7-domain `set_clock_groups`; that reintroduces the safe-bypass
  knife-edge. A `CRITICAL WARNING 12-4739` on `set_clock_groups` is expected and
  harmless.
- Pmod I2S2 PMOD JB audio is the current external audio path (D48/D49/D50).
  `create_project.tcl` sources `pmod_i2s2_integration.tcl`; `pmod_status_0` is
  at `0x43D20000`; runtime modes are `0=tone`, `1=loopback`, `2=dsp`,
  `3=mute`. Mode 2 mirrors the IP RIGHT slot into both DAC channels via
  `mode2_right_snapshot`. The older PCM5102 + PCM1808 PMOD JB path is retired
  and must not be re-enabled without a new hardware phase.
- The ZOOM FP02M expression pedal drives Wah POSITION through `xadc_wiz_a0`
  (Arduino A0 = VAUX1, AXI MMIO register `0x244`). The pedal is the sole
  `position_raw` writer; Q / VOLUME / BIAS stay GUI / encoder driven.
  `axi_gpio_wah` enable lives on its own `ctrlD` bit 7, so enabled Wah must
  route the AXIS crossbar off passthrough.
- Rotary-encoder overlay writes go only through
  `audio_lab_pynq/encoder_effect_apply.py::EncoderEffectApplier` (D37). It
  translates compact-v2 `AppState` into `AudioLabOverlay` APIs and must not do
  raw GPIO writes. RAT is selectable in the encoder GUI as of D91; keep the
  pedal bit 2 -> `rat_on` routing and Distortion knob -> `rat_*` mapping.
  Library defaults stay conservative (`skip_rat=True`, 100 ms throttle), while
  `scripts/run_encoder_hdmi_gui.py` opts into the current bench runtime by
  default (`--include-rat`, `--apply-interval-ms 20`, active poll 60 Hz).
- The 3PDT footswitch path is live in D78+ bitstreams. `axi_footswitch_input`
  is at `0x43D50000`; FS1 toggles the bound effect, FS2/FS3 step chain presets,
  and five FS1 stomps within 3 s rebind the target effect. The standalone HDMI
  runner polls footswitches by default; use `--no-footswitch` only for a
  deliberate diagnostic.
- The compact-v2 800x480 GUI renderer is split under `GUI/compact_v2/`
  (`knobs.py` / `state.py` / `layout.py` / `renderer.py` / `hit_test.py`);
  `GUI/pynq_multi_fx_gui.py` is a thin re-export shim. The HDMI state mirror is
  split under `audio_lab_pynq/hdmi_state/`. Edit the owning submodule, not the
  shim.
- Notebook-only edits do **not** rebuild the bitstream. Update the notebook,
  run `bash scripts/deploy_to_pynq.sh`, and sync through the deploy script. The
  deploy path maintains the required bit/hwh copies documented in
  `BUILD_AND_DEPLOY.md`. The board serves Notebooks from
  `/home/xilinx/jupyter_notebooks/audio_lab/`; use
  `http://192.168.1.9:9090/tree/audio_lab`. D145 requires deploy to discover
  the configured root via `jupyter notebook list`, restore `xilinx:xilinx`
  ownership, and JSON-validate all 15 files.
- HDMI GUI runtime uses the integrated AudioLab overlay. Load
  `AudioLabOverlay()` once and use `audio_lab_pynq.hdmi_backend`; do not call
  `Overlay("base.bit")`, do not call `run_pynq_hdmi()`, and do not load a
  second overlay after AudioLab. For the 5-inch LCD, keep Phase 6I VESA SVGA
  `800x600 @ 60 Hz / 40 MHz`; the compact-v2 GUI occupies framebuffer
  `x=0,y=0,w=800,h=480`, with rows `480..599` black. Do not switch back to
  720p or the rejected native 800x480 timing. After a bit is already loaded,
  prefer `download=False` smart attach patterns for display-only notebook
  reruns to avoid knocking the 40 MHz rgb2dvi PLL out of lock.
- Physical LCD fit and bench-audio quality cannot be fully verified by Codex.
  Programmatic smoke can narrow failures, but final acceptance for the display
  and sound comes from the user's bench confirmation.
- `git push`, `git pull`, `git fetch`, and any other remote operation are
  forbidden. Local commits only.
- Do not clone reference repositories into the working tree. Treat them as
  algorithmic references; do not paste source. **Never copy GPL-licensed code**
  (guitarix, BYOD, etc.) into this WTFPL project.

## Style

- Replies and progress reports: Japanese.
- Identifiers (file names, signals, functions, IPs, register names) stay in
  their original English form.
- No emojis in code or documentation unless the user asks for them.
