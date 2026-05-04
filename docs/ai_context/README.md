# AI Development Context

This directory is the shared briefing for Claude Code and Codex working on
this repository. The goal is that an agent can pick up a task without
re-scanning the whole tree on every session.

The current load-bearing fact: the **pedal-mask distortion refactor
shipped** (commit `baa97ff`, deployed and live-verified). Notebook UIs
were updated alongside it. See `CURRENT_STATE.md` for the post-deploy
snapshot and `DISTORTION_REFACTOR_PLAN.md` for the staged plan for
the still-reserved pedals.

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
| [`GPIO_CONTROL_MAP.md`](GPIO_CONTROL_MAP.md) | Adding or moving control bits, naming new effect parameters. |
| [`DSP_EFFECT_CHAIN.md`](DSP_EFFECT_CHAIN.md) | Editing `LowPassFir.hs`, adding a new Clash stage. |
| [`PYNQ_RUNTIME.md`](PYNQ_RUNTIME.md) | Anything that runs on the PYNQ-Z2 board. |
| [`BUILD_AND_DEPLOY.md`](BUILD_AND_DEPLOY.md) | Generating a new bitstream, deploying to the board. |
| [`TIMING_AND_FPGA_NOTES.md`](TIMING_AND_FPGA_NOTES.md) | Whenever a Clash change touches synthesis. |
| [`DISTORTION_REFACTOR_PLAN.md`](DISTORTION_REFACTOR_PLAN.md) | The active distortion-model refactor. |
| [`RESUME_PROMPTS.md`](RESUME_PROMPTS.md) | Re-entering after rate-limit or context reset. |

## What this directory is *not*

- It is not a substitute for reading the actual source. When the docs and
  the source disagree, the source wins — and the doc is wrong and should be
  updated.
- It is not a generated artefact. It is hand-written and lives in git
  alongside the code.
- It is not a sandbox for ephemeral notes. Anything that does not pay rent
  in helping a future agent should be deleted.
