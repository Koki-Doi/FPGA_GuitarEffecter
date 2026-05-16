# AI Development Context

This directory is the shared briefing for Claude Code and Codex working on
this repository. The goal is that an agent can pick up a task without
re-scanning the whole tree on every session.

The current load-bearing facts:

- The **pedal-mask distortion refactor shipped** (commit `baa97ff`,
  deployed and live-verified). Notebook UIs were updated alongside
  it.
- The **reserved-pedal implementation shipped** on top
  (`feature/add-reserved-distortion-pedals`, commit `c8f8d8c`,
  deployed and live-verified). `ds1` (bit 3), `big_muff` (bit 4),
  and `fuzz_face` (bit 5) are now backed by independent
  register-staged Clash blocks. Bit 7 stays reserved for a future
  8th pedal. No new GPIO, no `topEntity` port, no
  `block_design.tcl` change. See `DECISIONS.md` D9 and
  `DISTORTION_REFACTOR_PLAN.md`.
- The **audio-analysis voicing fixes shipped** on top
  (`feature/audio-analysis-voicing-fixes`). Recording analysis drove
  existing-stage retunes in Compressor / Overdrive / Amp / Cab only:
  no new GPIO, no `topEntity` port, no `block_design.tcl` change, no
  Python API / Notebook UI break. See `AUDIO_RECORDING_ANALYSIS.md`,
  `DECISIONS.md` D17, and `TIMING_AND_FPGA_NOTES.md`.
- The **Amp Simulator named models shipped** on the same branch.
  Four named voicings (`jc_clean` / `clean_combo` / `british_crunch` /
  `high_gain_stack`) are layered on the existing `amp_character`
  byte; the Clash side adds an `ampModelSel` quantiser that biases
  the post-clip pre-LPF alpha per band. No new GPIO, no `topEntity`
  port, no `block_design.tcl` change, no `Frame` field added. The
  numeric `amp_character` knob still works directly. See
  `DECISIONS.md` D18 and `DSP_EFFECT_CHAIN.md` Amp Simulator section.
- The **noise-suppressor refactor shipped** earlier (branch
  `feature/noise-suppressor-gpio-ui`, merged into `main`). A
  dedicated `axi_gpio_noise_suppressor` IP at `0x43CC0000` carries
  THRESHOLD / DECAY / DAMP / mode for a BOSS NS-2 / NS-1X-style
  suppressor; the legacy hard noise gate is retired from the active
  pipeline. See `DECISIONS.md` D11, `DSP_EFFECT_CHAIN.md` Noise
  Suppressor 節, and `GPIO_CONTROL_MAP.md` Noise Suppressor 節.
- The **compressor section shipped** (`feature/compressor-effect`).
  A dedicated `axi_gpio_compressor` IP at `0x43CD0000` carries
  THRESHOLD / RATIO / RESPONSE / enable+MAKEUP for a stereo-linked
  feed-forward peak compressor; sits between the noise suppressor
  and the overdrive. See `DECISIONS.md` D14.
- The **chain-preset layer shipped** (`feature/pedalboard-quality-presets`)
  alongside the **real-pedal voicing pass**
  (`feature/real-pedal-voicing-pass`). Together they brought the
  user-facing pedalboard to its current shape. See `DECISIONS.md`
  D15 / D16.
- The **HDMI GUI framebuffer path shipped** in the integrated
  `audio_lab.bit`. Live HDMI uses `AudioLabOverlay()` plus
  `audio_lab_pynq.hdmi_backend.AudioLabHdmiBackend`; it must not load
  `Overlay("base.bit")` or call `GUI/pynq_multi_fx_gui.py::run_pynq_hdmi()`.
  For the 5-inch 800x480 LCD, the current Phase 6I (`DECISIONS.md`
  D25) signal is VESA SVGA `800x600 @ 60 Hz / 40 MHz` and the
  framebuffer in `audio_lab_pynq/hdmi_backend.py` is `800x600`; the
  compact 800x480 GUI composes at framebuffer `(0, 0)` so visible
  rows `0..479` carry the UI and rows `480..599` stay black. The
  earlier Phase 5C history adopted the fixed `1280x720` HDMI signal
  with the compact 800x480 GUI at framebuffer `x=0,y=0`; that
  baseline is now superseded by Phase 6I for the on-the-wire signal
  while the GUI side stays at 800x480 compact-v2. Phase 5D themed
  the GUI with the Pip-Boy-inspired phosphor green palette and
  scanline overlay. Phase 6F rechecked a recurring right-shift report,
  Phase 6G added strong-UI-bbox diagnostics plus an actual-UI visual
  test (intermediate renderer x-tightening rolled back), Phase 6H
  (`d7ea0ab`) ported the compact-v2 renderer to the (1).py spec
  (`EFFECT_KNOBS` dict, `AppState.all_knob_values`, inline PEDAL /
  AMP / CAB dropdown), the subsequent Phase 6H native 800x480 HDMI
  timing pass was **rejected** on the LCD (white screen), and Phase
  6I (`DECISIONS.md` D25) settled on VESA SVGA `800x600 @ 60 Hz /
  40 MHz` with the 800x480 compact-v2 GUI composing at framebuffer
  `(0, 0)` of a `800x600` framebuffer. See
  `history/hdmi_phases/HDMI_GUI_PHASE5A_OUTPUT_SIDE_DIAGNOSIS.md`,
  `history/hdmi_phases/HDMI_GUI_PHASE5B_NATIVE_800X480_TIMING_PLAN.md`,
  `history/hdmi_phases/HDMI_GUI_PHASE5D_PIPBOY_GREEN_THEME.md`,
  `history/hdmi_phases/HDMI_GUI_PHASE6F_FIX_HDMI_X_ORIGIN.md`,
  `history/hdmi_phases/HDMI_GUI_PHASE6G_ACTUAL_UI_X_ORIGIN.md`,
  `history/hdmi_phases/HDMI_GUI_PHASE6H_PORT_1PY_SPEC.md`,
  `history/hdmi_phases/HDMI_GUI_PHASE6H_NATIVE_800X480_TIMING.md` (rejected),
  `history/hdmi_phases/HDMI_GUI_PHASE6I_800X480_TIMING_SWEEP.md`, and
  `HDMI_GUI_INTEGRATION_PLAN.md`.
- Repo cleanup after Phase 5C confirmed `GUI/` is active code, while the
  old untracked `HDMI/` experiment tree is unused by deploy, tests, and
  runtime scripts. `HDMI/` was backed up under `/tmp/fpga_guitar_effecter_backup/`
  and removed from the working tree; active GUI documentation now lives
  in `GUI/README.md`.

See `CURRENT_STATE.md` for the post-deploy snapshot.

## Reading order

Always start here:

1. [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md) — what the system is and where
   each piece lives.
2. [`CURRENT_STATE.md`](CURRENT_STATE.md) — what shipped, what is reserved,
   and what to be careful about.
3. [`DECISIONS.md`](DECISIONS.md) — the design decisions that earlier work
   has already made, and **why**.

Then read whatever is topical for the task at hand:

| File | Use when |
| --- | --- |
| [`AUDIO_SIGNAL_PATH.md`](AUDIO_SIGNAL_PATH.md) | Tracing where samples go, debugging passthrough or routing. |
| [`GPIO_CONTROL_MAP.md`](GPIO_CONTROL_MAP.md) | Reading the fixed GPIO inventory. The address / ctrlA-D layout is locked; do not move bytes. |
| [`EFFECT_ADDING_GUIDE.md`](EFFECT_ADDING_GUIDE.md) | The playbook for adding a new effect (decision flow, GPIO rules, Clash rules, Python rules, deploy checklist). |
| [`EFFECT_STAGE_TEMPLATE.md`](EFFECT_STAGE_TEMPLATE.md) | Fillable spec sheet for a new effect; submit alongside the implementation PR. |
| [`DSP_EFFECT_CHAIN.md`](DSP_EFFECT_CHAIN.md) | Editing `LowPassFir.hs`, adding a new Clash stage. |
| [`PYNQ_RUNTIME.md`](PYNQ_RUNTIME.md) | Anything that runs on the PYNQ-Z2 board. |
| [`BUILD_AND_DEPLOY.md`](BUILD_AND_DEPLOY.md) | Generating a new bitstream, deploying to the board. |
| [`TIMING_AND_FPGA_NOTES.md`](TIMING_AND_FPGA_NOTES.md) | Whenever a Clash change touches synthesis. |
| [`HDMI_GUI_INTEGRATION_PLAN.md`](HDMI_GUI_INTEGRATION_PLAN.md) | HDMI GUI architecture, constraints, and Phase 4 through Phase 6I status (Section 11 has the Phase 6I C2 SVGA 800x600 result). |
| [`history/hdmi_phases/README.md`](history/hdmi_phases/README.md) | Per-phase HDMI GUI history index (Phase 1 -- Phase 6I), kept for archaeology. Read individual phase files only when you need contemporaneous detail. |
| [`DISTORTION_REFACTOR_PLAN.md`](DISTORTION_REFACTOR_PLAN.md) | The distortion-model refactor (pedal-mask + reserved-pedal phases). |
| [`REAL_PEDAL_VOICING_TARGETS.md`](REAL_PEDAL_VOICING_TARGETS.md) | Reference voicings the existing effect stages aim at. |
| [`RESUME_PROMPTS.md`](RESUME_PROMPTS.md) | Re-entering after rate-limit or context reset (current prompts only). Per-phase history in [`RESUME_PROMPTS_HISTORY.md`](RESUME_PROMPTS_HISTORY.md). |

## What this directory is *not*

- It is not a substitute for reading the actual source. When the docs and
  the source disagree, the source wins — and the doc is wrong and should be
  updated.
- It is not a generated artefact. It is hand-written and lives in git
  alongside the code.
- It is not a sandbox for ephemeral notes. Anything that does not pay rent
  in helping a future agent should be deleted.
