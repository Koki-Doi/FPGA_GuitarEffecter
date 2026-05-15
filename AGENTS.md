# Codex Agent Guide

This repository is **Audio-Lab-PYNQ** (a.k.a. FPGA_GuitarEffecter), a real-time
guitar effect chain that runs on a PYNQ-Z2 board with an ADAU1761 codec, a
Clash/VHDL DSP block synthesised under Vivado 2019.1, and a Python /
PYNQ-Jupyter control layer.

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
| Vivado / timing | `docs/ai_context/TIMING_AND_FPGA_NOTES.md` |
| Bitstream build / deploy | `docs/ai_context/BUILD_AND_DEPLOY.md` |
| PYNQ-Z2 board operations | `docs/ai_context/PYNQ_RUNTIME.md` |
| HDMI GUI / 5-inch LCD | `docs/ai_context/HDMI_GUI_INTEGRATION_PLAN.md` (+ `HDMI_GUI_PHASE5A_OUTPUT_SIDE_DIAGNOSIS.md`, `HDMI_GUI_PHASE5B_NATIVE_800X480_TIMING_PLAN.md`) |
| Resuming after a stop | `docs/ai_context/RESUME_PROMPTS.md` |

## Hard constraints

- `hw/Pynq-Z2/block_design.tcl` is **off-limits** unless the user explicitly
  approves a block-design change. New control bits go into spare bytes of the
  existing AXI GPIOs; new effect stages reuse existing GPIO topology. The
  shipped exceptions are `axi_gpio_noise_suppressor` at `0x43CC0000`
  (THRESHOLD / DECAY / DAMP noise-suppressor work, `DECISIONS.md` D11) and
  `axi_gpio_compressor` at `0x43CD0000` (THRESHOLD / RATIO / RESPONSE /
  enable+MAKEUP compressor work, `DECISIONS.md` D14); do not remove them or
  shuffle their addresses.
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
- Notebook-only edits do **not** rebuild the bitstream. Update the
  notebook, run `bash scripts/deploy_to_pynq.sh`, done.
- HDMI GUI runtime uses the integrated AudioLab overlay. Load
  `AudioLabOverlay()` once and use `audio_lab_pynq.hdmi_backend`; do not
  call `Overlay("base.bit")`, do not call `run_pynq_hdmi()`, and do not
  load a second overlay after AudioLab. For the 5-inch 800x480 LCD, the
  Phase 5C default visible viewport is framebuffer `x=0,y=0,w=800,h=480`
  inside the fixed 1280x720 HDMI signal.
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
