# Codex Agent Guide

This repository is **Audio-Lab-PYNQ** (a.k.a. FPGA_GuitarEffecter), a real-time
guitar effect chain that runs on a PYNQ-Z2 board. The current deployed audio
path uses a Digilent Pmod I2S2 module on PMOD JB for line input/output, keeps
the ADAU1761 codec configured for I2C/HPF health checks and debug visibility,
and processes samples through a Clash/VHDL DSP block synthesised under Vivado
2019.1 plus a Python / PYNQ-Jupyter control layer.

## Read these first, in order

Codex must not re-scan the whole repository on each session. Read the shared
AI context instead:

1. `docs/ai_context/PROJECT_CONTEXT.md` — what the system does and where the
   pieces live.
2. `docs/ai_context/CURRENT_STATE.md` — what is in flight right now and what
   should not be touched.
3. `docs/ai_context/DECISIONS.md` — load-bearing design decisions and the
   reason for each.

Then read the topic doc that matches the work:

| Work | Read |
| --- | --- |
| Adding a new effect | `docs/ai_context/EFFECT_ADDING_GUIDE.md` (+ `EFFECT_STAGE_TEMPLATE.md`) |
| Clash / DSP edits | `docs/ai_context/DSP_EFFECT_CHAIN.md` |
| GPIO bit allocation | `docs/ai_context/GPIO_CONTROL_MAP.md` |
| Audio routing / passthrough debug | `docs/ai_context/AUDIO_SIGNAL_PATH.md` |
| Distortion model work | `docs/ai_context/DISTORTION_REFACTOR_PLAN.md` |
| Vivado / timing | `docs/ai_context/TIMING_AND_FPGA_NOTES.md` (+ `DSP_ISLAND_CLOCK_DESIGN.md` for the 50 MHz island) |
| Bitstream build / deploy | `docs/ai_context/BUILD_AND_DEPLOY.md` |
| PYNQ-Z2 board operations | `docs/ai_context/PYNQ_RUNTIME.md` |
| Wah effect / FP02M pedal | `docs/ai_context/WAH_EFFECT_INTEGRATION_PLAN.md`, `FP02M_PEDAL_INTEGRATION.md`, `XADC_INTEGRATION_DESIGN.md` |
| Pmod I2S2 external audio | `docs/ai_context/PMOD_I2S2_INTEGRATION_PLAN.md` |
| Rotary encoder runtime | `docs/ai_context/ENCODER_GUI_CONTROL_SPEC.md`, `ENCODER_INPUT_IMPLEMENTATION.md`, `ENCODER_INPUT_MAP.md` |
| HDMI GUI / 5-inch LCD | `docs/ai_context/HDMI_GUI_INTEGRATION_PLAN.md` (+ `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE5A_OUTPUT_SIDE_DIAGNOSIS.md`, `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE5B_NATIVE_800X480_TIMING_PLAN.md`, `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE6F_FIX_HDMI_X_ORIGIN.md`, `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE6G_ACTUAL_UI_X_ORIGIN.md`, `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE6H_PORT_1PY_SPEC.md`, `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE6H_NATIVE_800X480_TIMING.md` (rejected), `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE6I_800X480_TIMING_SWEEP.md`) |
| Resuming after a stop | `docs/ai_context/RESUME_PROMPTS.md` (current; per-phase history in `docs/ai_context/RESUME_PROMPTS_HISTORY.md`) |

## Hard constraints

- `hw/Pynq-Z2/block_design.tcl` is **off-limits** unless the user explicitly
  approves a block-design change. New control bits go into spare bytes of the
  existing AXI GPIOs; new effect stages reuse existing GPIO topology. The
  shipped exceptions are `axi_gpio_noise_suppressor` at `0x43CC0000`
  (THRESHOLD / DECAY / DAMP noise-suppressor work, `DECISIONS.md` D11),
  `axi_gpio_compressor` at `0x43CD0000` (THRESHOLD / RATIO / RESPONSE /
  enable+MAKEUP compressor work, `DECISIONS.md` D14), and `axi_gpio_wah`
  at `0x43D30000` (POSITION / Q / VOLUME / enable+BIAS wah work,
  `DECISIONS.md` D72 / D73); do not remove them or shuffle their addresses.
  These three GPIOs and the `xadc_wiz_a0` XADC Wizard at `0x43D40000`
  (Arduino A0 = VAUX1 for the FP02M pedal, `DECISIONS.md` D76) are added by
  additive `*_integration.tcl` scripts sourced from `create_project.tcl`,
  **never** by editing `block_design.tcl`.
- **GPIO design is fixed** (`DECISIONS.md` D12). Names, addresses, and the
  `ctrlA` / `ctrlB` / `ctrlC` / `ctrlD` semantics in
  `docs/ai_context/GPIO_CONTROL_MAP.md` are a contract. Do not rename
  `axi_gpio_delay`, do not move bytes, do not repurpose `legacy mirror` or
  `reserved` slots for unrelated effects. New effects land on documented
  reserved bits / bytes first.
- C++ DSP prototypes were removed (`DECISIONS.md` D13). The single source of
  truth for DSP behaviour is `hw/ip/clash/src/LowPassFir.hs`. Do not write a
  new C++ prototype as a stepping stone to a new effect.
- The ADAU1761 ADC HPF is **default-on** (`R19_ADC_CONTROL == 0x23`). Do not
  remove or skip the HPF enable in `config_codec()`.
- The selectable distortion section is **pedal-mask-based** (commit
  `baa97ff`, plus the reserved-pedal implementation in `c8f8d8c` that filled
  bits 3 / 4 / 5 with `ds1` / `big_muff` / `fuzz_face` Clash stages). Do not
  roll it back to a `model_select` / 8-way mux design; that is the pattern
  that wrecked timing earlier and is already recorded as a dead end
  (`DECISIONS.md` D6 / D9). Bit 7 stays reserved for an 8th pedal slot.
- Any change to `hw/ip/clash/src/LowPassFir.hs` requires a Vivado bit/hwh
  rebuild and a fresh **timing summary**. A bitstream whose WNS is
  significantly worse than the previous deployed build must not be deployed
  (latest baseline is recorded in `docs/ai_context/TIMING_AND_FPGA_NOTES.md`).
- The DSP runs in a **50 MHz clock-domain island** (`DECISIONS.md` D75,
  full record `DSP_ISLAND_CLOCK_DESIGN.md`). Only `clash_lowpass_fir_0` is
  clocked by `FCLK_CLK1` (50 MHz); the rest of the fabric (AXI / DMA /
  `i2s_to_stream` / Pmod / HDMI) stays on `FCLK_CLK0` (100 MHz), bridged by
  `axis_clock_converter` `cc_dsp_in` / `cc_dsp_out` in
  `island_integration.tcl` (additive, sourced after `xadc_integration.tcl`;
  `block_design.tcl` NOT edited). Do **not** lower the whole fabric to
  50 MHz (corrupts the I2S/Pmod CDCs -> audible buzz). Three load-bearing
  pieces must not be reverted: the `paceCount` removal in `Pipeline.hs`
  (`acceptReady = readyOut`), the `syncCtrl` control-word CDC in
  `LowPassFir.hs`, and the `set_clock_groups -asynchronous` over all 7
  clock domains in `audio_lab.xdc`. A `CRITICAL WARNING 12-4739` on the
  `set_clock_groups` line is expected and harmless.
- Pmod I2S2 PMOD JB audio is the current external audio path
  (`DECISIONS.md` D48 / D49 / D50). `create_project.tcl` sources
  `pmod_i2s2_integration.tcl`; the AXI status/control slave is at
  `0x43D20000` and runtime modes are `0=tone`, `1=loopback`, `2=dsp`,
  `3=mute`. Mode 2 mirrors the IP RIGHT slot into both DAC channels (D50).
  The older PCM5102 + PCM1808 PMOD JB path is **retired**; its files stay
  in-tree as reference only and must not be re-enabled without a new
  hardware phase.
- The ZOOM FP02M expression pedal drives Wah POSITION via the `xadc_wiz_a0`
  XADC Wizard (Arduino A0 = VAUX1, AXI MMIO read, `DECISIONS.md` D76,
  `FP02M_PEDAL_INTEGRATION.md`). The pedal is the sole `position_raw`
  writer; Q / VOLUME / BIAS stay GUI / encoder driven. `axi_gpio_wah`
  enable lives on its own `ctrlD` bit 7 (not `gate_control`), so an
  enabled Wah must also re-route the AXIS crossbar off `passthrough`.
- The compact-v2 800x480 GUI renderer is split per-theme under
  `GUI/compact_v2/` (`knobs.py` / `state.py` / `layout.py` / `renderer.py`
  / `hit_test.py`); `GUI/pynq_multi_fx_gui.py` is a thin re-export shim
  (`DECISIONS.md` D26). The HDMI state mirror is similarly split under
  `audio_lab_pynq/hdmi_state/`. Edit the owning submodule, not the shim.
  Encoder-driven overlay writes go only through
  `audio_lab_pynq/encoder_effect_apply.py::EncoderEffectApplier`
  (`DECISIONS.md` D37) -- no raw GPIO writes from the encoder loop.
- Notebook-only edits do **not** rebuild the bitstream. Update the
  notebook, run `bash scripts/deploy_to_pynq.sh`, done. The deploy syncs
  bit/hwh to **five** sites (see `BUILD_AND_DEPLOY.md`).
- HDMI GUI runtime uses the integrated AudioLab overlay. Load
  `AudioLabOverlay()` once and use `audio_lab_pynq.hdmi_backend`; do not
  call `Overlay("base.bit")`, do not call `run_pynq_hdmi()`, and do not
  load a second overlay after AudioLab. For the 5-inch 800x480 LCD, the
  current Phase 6I signal is VESA SVGA `800x600 @ 60 Hz / 40 MHz`; the
  compact-v2 GUI occupies framebuffer `x=0,y=0,w=800,h=480`, with rows
  `480..599` black. Do not switch back to 720p or the rejected native
  800x480 timing.
- `git push`, `git pull`, `git fetch`, and any other remote operation are
  forbidden. Local commits only.
- Do not clone reference repositories into the working tree. Treat them as
  algorithmic references; do not paste source. **Never copy GPL-licensed
  code** (guitarix, BYOD, etc.) into this WTFPL project.

## Style

- Replies and progress reports: Japanese.
- Identifiers (file names, signals, functions, IPs, register names) stay in
  the original English.
- No emojis in code or documentation unless the user asks for them.
