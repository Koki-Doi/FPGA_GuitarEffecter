# Design decisions (ADR-style)

Each entry is a decision that earlier work made and that future work
should not silently revisit. New decisions go at the bottom; old ones do
not get removed even when superseded — they get updated.

---

## D1 — ADAU1761 ADC HPF is enabled by default

- **Decision.** `config_codec()` writes `R19_ADC_CONTROL = 0x03`, then
  uses RMW via `enable_adc_hpf()` to set R19[5], so the post-init value
  is `0x23`. A 300 ms settle is included before the DAC is enabled.
- **Why.** With the HPF off, capture-with-input-shorted showed a
  significant DC offset and elevated RMS. Toggling R19[5] removed the
  offset and dropped RMS dramatically, so the user requested it be the
  permanent default.
- **Important caveats.**
  - This is a ~2 Hz DC blocker, **not** a 20–40 Hz guitar low-cut.
    Treat it as an offset remover, nothing more.
  - The IIR has τ ≈ 80 ms at 48 kHz. After any toggle, allow ~3–4 τ
    (≈ 300 ms) before measurement, and discard the first ~50 ms of any
    capture (handled in `diagnostic_capture` with `settling_ms` and
    `discard_initial_frames`).
- **How to apply.** Never remove the `enable_adc_hpf()` call from
  `config_codec()`. If a future test needs it off, do it explicitly and
  restore the default.

## D2 — `block_design.tcl` is off-limits by default

- **Decision.** New control bits and new effect stages reuse the spare
  bytes of the existing `axi_gpio_*` IPs. Adding or reconfiguring an
  AXI GPIO requires a `block_design.tcl` change and explicit user
  approval.
- **Why.** The existing block design has timing margin already eaten
  (see `TIMING_AND_FPGA_NOTES.md`). Touching the block design risks
  regenerating addresses, breaking the C++/Python address map, and
  destabilising the build.
- **How to apply.** When asked for new control bits, look for a spare
  byte first (`GPIO_CONTROL_MAP.md`). Only escalate to a block-design
  change when the user agrees in writing.

## D3 — Deploys go through `scripts/deploy_to_pynq.sh`

- **Decision.** Any change that ships to the PYNQ-Z2 goes through that
  script, which uses SSH key auth and never stores a password.
- **Why.** Earlier ad-hoc `scp` flows risked interactive password
  prompts that the agent could not satisfy and risked desyncing the
  package install vs the bitstream.
- **How to apply.** Use the script. Override host or paths via env
  vars (`PYNQ_HOST`, `PYNQ_USER`, `PYNQ_REPO_DIR`, `PYNQ_NB_DIR`,
  `SSH_KEY`).

## D4 — PYNQ overlay work needs root

- **Decision.** Anything that touches `Overlay()`, DMA, `pynq.allocate`
  or the `/dev/uio*` devices runs as `sudo`. Use
  `sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 …`.
- **Why.** The PYNQ Linux image gates UIO and contiguous-memory
  allocation behind root. Trying to use the overlay as `xilinx`
  fails with surprising error messages that point in the wrong
  direction.

## D5 — Live package source is `/home/xilinx/Audio-Lab-PYNQ/`

- **Decision.** Always put `/home/xilinx/Audio-Lab-PYNQ` first on
  `PYTHONPATH` for board-side runs.
- **Why.** The PYNQ image carries an older copy of `audio_lab_pynq`
  under `/usr/local/lib/python3.6/dist-packages/`. Without the
  PYTHONPATH override the test may run the wrong code and silently
  succeed, hiding regressions.

## D6 — The `model_select` 8-way mux distortion plan is dead

- **Decision.** Selectable distortion models are implemented as
  independent pedal stages (each with its own enable bit), not as a
  numeric `model_select` driving a giant case statement.
- **Why.** The `model_select` build pushed Vivado WNS from −7.722 ns
  to −15.067 ns. The combinational depth of the per-stage 8-way case
  is the cause; the design will not deploy safely in that shape.
- **How to apply.** Read `DISTORTION_REFACTOR_PLAN.md`. Do not add
  new `case modelSelect of …` blocks to `LowPassFir.hs`. Pedal
  enables live in `distortion_control.ctrlD`; the section master
  stays at `gate_control.ctrlA[2]`.

## D7 — Reference repositories are read-only inspiration

- **Decision.** Algorithmic structure of guitarix, BYOD, JS-Rocks,
  PunkMuff, ToobAmp, dm-Rat, etc. may be studied. Their **source
  code is not copied** into this repository.
- **Why.** Several of those projects are GPL-licensed. This
  repository is WTFPL. Pasting GPL code (whole or near-verbatim) is
  not compatible. Beyond the licence question, hand-rolling the Clash
  forces us to keep the implementation small enough to fit the FPGA.
- **How to apply.** No `git submodule add`, no `git clone` into the
  tree. If a reference is needed for a session, clone it into
  `/tmp` or another scratch path the repo never sees.
