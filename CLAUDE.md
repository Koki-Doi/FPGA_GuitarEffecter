# Claude Code Agent Guide

This repository is **Audio-Lab-PYNQ** (a.k.a. FPGA_GuitarEffecter), a real-time
guitar effect chain that runs on a PYNQ-Z2 board with an ADAU1761 codec, a
Clash/VHDL DSP block synthesised under Vivado 2019.1, and a Python / PYNQ
control layer.

## Read these before doing any non-trivial investigation

Claude Code must not re-scan the whole repository on each new session.
Even after `/compact` or a context reset, treat `docs/ai_context/` as the
source of truth — not the (possibly summarised) conversation history.

1. `docs/ai_context/PROJECT_CONTEXT.md`
2. `docs/ai_context/CURRENT_STATE.md`
3. `docs/ai_context/DECISIONS.md`

Then the topic file that matches the task:

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
| HDMI GUI / 5-inch LCD | `docs/ai_context/HDMI_GUI_INTEGRATION_PLAN.md` (+ `HDMI_GUI_PHASE5A_OUTPUT_SIDE_DIAGNOSIS.md`, `HDMI_GUI_PHASE5B_NATIVE_800X480_TIMING_PLAN.md`, `HDMI_GUI_PHASE6F_FIX_HDMI_X_ORIGIN.md`, `HDMI_GUI_PHASE6G_ACTUAL_UI_X_ORIGIN.md`, `HDMI_GUI_PHASE6H_PORT_1PY_SPEC.md`, `HDMI_GUI_PHASE6H_NATIVE_800X480_TIMING.md` (rejected), `HDMI_GUI_PHASE6I_800X480_TIMING_SWEEP.md`); runtime entry is `audio_lab_pynq/notebooks/HdmiGui.ipynb` (single cell, resource monitor, `OFFSET_X` / `OFFSET_Y` calibration). |
| Resuming after a stop | `docs/ai_context/RESUME_PROMPTS.md` |

## Resuming after a rate-limit / context reset

When a previous turn stopped mid-implementation:

1. Run `git status --short` and `git diff --stat` first; do **not** discard
   uncommitted work.
2. Read `docs/ai_context/CURRENT_STATE.md` and
   `docs/ai_context/RESUME_PROMPTS.md`.
3. Continue from the staged/unstaged state — do not silently revert to an
   older design just because the conversation history is fragmented.

## Hard constraints

- `hw/Pynq-Z2/block_design.tcl` is **off-limits** unless the user explicitly
  approves a block-design change. Shipped exceptions are
  `axi_gpio_noise_suppressor` at `0x43CC0000`, added for the THRESHOLD /
  DECAY / DAMP noise-suppressor work (`DECISIONS.md` D11), and
  `axi_gpio_compressor` at `0x43CD0000`, added for the THRESHOLD /
  RATIO / RESPONSE / MAKEUP compressor work (`DECISIONS.md` D14). Do
  not remove them or shuffle their addresses.
- **GPIO design is fixed** (`DECISIONS.md` D12). Names, addresses, and the
  `ctrlA` / `ctrlB` / `ctrlC` / `ctrlD` semantics in
  `docs/ai_context/GPIO_CONTROL_MAP.md` are a contract — never rename
  `axi_gpio_delay`, never repurpose a `legacy mirror` or `reserved` slot
  for an unrelated effect. New effects land on documented reserved bits
  / bytes first.
- C++ DSP prototypes were removed (`DECISIONS.md` D13). The single source
  of truth for DSP behaviour is `hw/ip/clash/src/LowPassFir.hs`. Do not
  write a new C++ prototype as a stepping stone; new effect work goes
  Python API + UI reservation -> Clash stage -> (rare) new GPIO.
- The ADAU1761 ADC HPF is **default-on** (`R19_ADC_CONTROL == 0x23`). Do not
  weaken or skip the HPF enable in `config_codec()`.
- The selectable distortion section is **pedal-mask-based** (commit
  `baa97ff`, deployed; plus the reserved-pedal implementation in
  `c8f8d8c` that filled bits 3 / 4 / 5 with `ds1` / `big_muff` /
  `fuzz_face` Clash stages, also deployed). Do not roll it back to a
  `model_select` / 8-way mux design; see `docs/ai_context/DECISIONS.md`
  D6 and D9. Bit 7 of the pedal mask stays reserved for an 8th pedal
  slot.
- Any edit to `hw/ip/clash/src/LowPassFir.hs` requires a Vivado bit/hwh
  rebuild and a timing-summary check. A bitstream with significantly worse
  WNS than the previous deployed build must not be deployed (latest
  baseline is recorded in `docs/ai_context/TIMING_AND_FPGA_NOTES.md`).
- Notebook-only edits do **not** rebuild the bitstream. Update the
  notebook, run `bash scripts/deploy_to_pynq.sh`, done.
- HDMI GUI runtime uses the integrated AudioLab overlay. Load
  `AudioLabOverlay()` once and use `audio_lab_pynq.hdmi_backend`; do not
  call `Overlay("base.bit")`, and do not load a second overlay after
  AudioLab. The 1280x720 reference renderer and the Tkinter Windows
  preview were removed from `GUI/pynq_multi_fx_gui.py` (`DECISIONS.md`
  D24); `run_pynq_hdmi()` and `render_frame*` no longer exist.
  Two notebooks share the same overlay: `audio_lab_pynq/notebooks/HdmiGui.ipynb`
  is the original live-loop viewer (resource monitor, `OFFSET_X` / `OFFSET_Y`
  calibration, model dropdowns), and `audio_lab_pynq/notebooks/HdmiGuiShow.ipynb`
  is a one-shot single-cell renderer. The `HdmiGuiShow.ipynb` cell first
  reads `v_tc_hdmi GEN_ACTSZ` and, if it already reads `0x02580320`,
  attaches via `AudioLabOverlay(download=False)` so it does NOT
  re-program the FPGA on every run — this is required because the
  Phase 6I rgb2dvi PLL sits at the lower edge (`VCO=800 MHz`) and a
  second `download=True` in the same session can knock the PLL out
  and drop the LCD to white. The diagnostic script equivalent is
  `scripts/test_hdmi_800x480_frame.py`. After Phase 6I (`DECISIONS.md`
  D25), the integrated HDMI path runs **VESA SVGA 800x600 @ 60 Hz /
  40 MHz** (not 720p, not native 800x480). The framebuffer in
  `audio_lab_pynq/hdmi_backend.py` is `800x600` (`DEFAULT_WIDTH=800,
  DEFAULT_HEIGHT=600`); the compact-v2 800x480 GUI composes at
  framebuffer `(0,0)` so visible rows `0..479` carry the UI and rows
  `480..599` stay black. Do not switch back to 720p, and do not retry
  "native 800x480 @ 40 MHz" (Phase 6H attempt; LCD white screen).
  When editing `hw/Pynq-Z2/hdmi_integration.tcl`, set
  `CONFIG.VIDEO_MODE {Custom}` in a first `set_property` pass before
  the per-field `GEN_*` values, set
  `GEN_F0_VBLANK_HSTART = GEN_F0_VBLANK_HEND = HDMI_ACTIVE_W`
  explicitly, drop `GEN_CHROMA_PARITY` (does not exist on v_tc 6.1),
  and sync **five** bit/hwh copies on deploy
  (`hw/Pynq-Z2/bitstreams/`, repo `audio_lab_pynq/bitstreams/`,
  `/usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams/`,
  `/home/xilinx/jupyter_notebooks/audio_lab/bitstreams/`, and
  `/usr/local/lib/python3.6/dist-packages/pynq/overlays/audio_lab/`).
  After deploy, if the LCD shows white even though VTC GEN_ACTSZ and
  VDMA look healthy, power-cycle the PYNQ-Z2 and run the notebook
  cell once — the rgb2dvi PLL only re-locks reliably from cold start.
- The compact-v2 800x480 layout (`_render_frame_800x480_compact_v2`)
  has three panels: `header`, `chain`, and a full-width `fx` (the old
  bottom-right `side` monitor was removed). After the Phase 6H (1).py
  spec port (`DECISIONS.md` D24, `d7ea0ab`), `EFFECT_KNOBS` is a single
  dict keyed by the title-case `EFFECTS` names (`Noise Sup`,
  `Compressor`, `Overdrive`, `Distortion`, `Amp Sim`, `Cab IR`, `EQ`,
  `Reverb`) with `[(label, default), ...]` short labels. The
  selected-FX knob grid adapts per effect: 3 knobs → 3×1, 4 → 2×2,
  6 → 3×2, 8 → 4×2 (`Amp Sim`). `AppState` stores values in
  `all_knob_values: Dict[str, List[float]]`; the flat `knob_values`
  field is removed. New helpers: `state.knobs()`,
  `state.set_knob(label, value)`, `hit_test_compact_v2(x, y, state)`.
  PEDAL / AMP / CAB draw the model dropdown chip inline (with a
  fit-to-chip label size search `22 → 14`); REVERB / COMPRESSOR /
  NOISE SUPPRESSOR / SAFE BYPASS / PRESET hide it. Adding a new effect
  extends `EFFECT_KNOBS` with the real labels and the grid follows.
- `git push`, `git pull`, `git fetch`, and other remote operations are
  forbidden. Local commits only.
- Do not clone reference repositories into the tree. Do not paste GPL code
  (guitarix, BYOD, etc.). Algorithm structure is a fair reference; source
  is not.

## Style

- Progress narration and reports: Japanese, terse.
- Identifiers (file names, signals, functions, IPs, register names) stay
  in their original English form.
- No emojis in code or docs unless the user asks for them.
