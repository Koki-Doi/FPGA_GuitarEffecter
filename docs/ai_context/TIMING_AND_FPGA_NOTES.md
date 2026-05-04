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
| **Pedal-mask refactor (May 4, deployed)** | **-7.801 ns** | -7381.742 ns | Seven independent pedal stages. Deployed; live-verified. Setup slack roughly baseline-equivalent. |

WHS = +0.050 ns / THS = 0.000 ns on the deployed build, so hold is
clean. WNS is still slightly negative; treat any further timing
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
worse than the deployed build (-7.801 ns, the pedal-mask refactor).
If it is, the change must be revisited (more pipeline stages,
simpler mux structure, or fewer features) before any deploy.

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
