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
  Python API / Notebook UI break. Final deployed timing is
  WNS = -8.731 ns, TNS = -13665.555 ns, WHS = +0.051 ns,
  THS = 0.000 ns. See `AUDIO_RECORDING_ANALYSIS.md`, `DECISIONS.md`
  D17, and `TIMING_AND_FPGA_NOTES.md`.
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
| [`DISTORTION_REFACTOR_PLAN.md`](DISTORTION_REFACTOR_PLAN.md) | The distortion-model refactor (pedal-mask + reserved-pedal phases). |
| [`REAL_PEDAL_VOICING_TARGETS.md`](REAL_PEDAL_VOICING_TARGETS.md) | Reference voicings the existing effect stages aim at. |
| [`RESUME_PROMPTS.md`](RESUME_PROMPTS.md) | Re-entering after rate-limit or context reset. |

## What this directory is *not*

- It is not a substitute for reading the actual source. When the docs and
  the source disagree, the source wins — and the doc is wrong and should be
  updated.
- It is not a generated artefact. It is hand-written and lives in git
  alongside the code.
- It is not a sandbox for ephemeral notes. Anything that does not pay rent
  in helping a future agent should be deleted.
