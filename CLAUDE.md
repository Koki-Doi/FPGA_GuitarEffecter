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
| Clash / DSP edits | `docs/ai_context/DSP_EFFECT_CHAIN.md` |
| GPIO bit allocation | `docs/ai_context/GPIO_CONTROL_MAP.md` |
| Audio routing / passthrough debug | `docs/ai_context/AUDIO_SIGNAL_PATH.md` |
| Distortion model work | `docs/ai_context/DISTORTION_REFACTOR_PLAN.md` |
| Vivado / timing | `docs/ai_context/TIMING_AND_FPGA_NOTES.md` |
| Bitstream build / deploy | `docs/ai_context/BUILD_AND_DEPLOY.md` |
| PYNQ-Z2 board operations | `docs/ai_context/PYNQ_RUNTIME.md` |
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
  approves a block-design change.
- The ADAU1761 ADC HPF is **default-on** (`R19_ADC_CONTROL == 0x23`). Do not
  weaken or skip the HPF enable in `config_codec()`.
- The selectable distortion section is **pedal-mask-based** (commit
  `baa97ff`, deployed). Do not roll it back to a `model_select` / 8-way
  mux design; see `docs/ai_context/DECISIONS.md` D6.
- Any edit to `hw/ip/clash/src/LowPassFir.hs` requires a Vivado bit/hwh
  rebuild and a timing-summary check. A bitstream with significantly worse
  WNS than the deployed -7.801 ns must not be deployed.
- Notebook-only edits do **not** rebuild the bitstream. Update the
  notebook, run `bash scripts/deploy_to_pynq.sh`, done.
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
