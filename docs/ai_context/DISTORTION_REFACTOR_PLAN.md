# Distortion refactor plan

The selectable-distortion work has shipped. This document keeps the
design notes plus the staged plan for the remaining pedals; it is no
longer a "what should we do" file.

## What was shipped

Implementation commit: `baa97ff Refactor distortion models into
pedal-style pipeline`. Notebook follow-ups: `e1bb313` (switcher
add-on) and `2198873` (one-cell pedalboard). All three live on
`master`. The build was deployed to the lab board and verified
live; see `CURRENT_STATE.md`.

| Pedal | bit | Clash stage |
| --- | --- | --- |
| `clean_boost` | 0 | implemented (3 register stages: mul -> shift -> level + safety softClip) |
| `tube_screamer` | 1 | implemented (5 register stages: input HPF -> mul -> asym soft clip -> post LPF -> level) |
| `rat` | 2 | mapped onto the existing RAT stage; Python sets `gate_control` bit 4 when this bit is set |
| `ds1` | 3 | reserved — mask accepted, no Clash stage yet |
| `big_muff` | 4 | reserved — mask accepted, no Clash stage yet |
| `fuzz_face` | 5 | reserved — mask accepted, no Clash stage yet |
| `metal` | 6 | implemented (5 register stages: tight HPF -> mul -> hard clip -> post LPF -> level) |
| reserved | 7 | unused |

### Why the `model_select` design was rejected

The first attempt routed a single 4-bit `model_select` into every
distortion stage. Each stage had a `case modelSelect of …` over all
voicings, building eight parallel multipliers / clippers / filters
behind one big mux. Vivado WNS regressed from -7.722 ns to
-15.067 ns. The pedal-mask design replaces that with seven
independently enabled small stages, restoring WNS to -7.801 ns. Do
not bring `model_select` back — see `DECISIONS.md` D6 and
`TIMING_AND_FPGA_NOTES.md`.

## Control plane (final)

Master enable: `gate_control` bit 2 (the existing `distortion_on`
flag, shared with the legacy distortion stage).

| Field | Carries |
| --- | --- |
| `distortion_control.ctrlA` | tone (shared) |
| `distortion_control.ctrlB` | level (shared) |
| `distortion_control.ctrlC` | drive (shared) |
| `distortion_control.ctrlD[6:0]` | pedal enable mask |
| `distortion_control.ctrlD[7]` | reserved |
| `gate_control.ctrlC` | bias (used by future bias-aware pedals) |
| `gate_control.ctrlD` | mix (used by future wet/dry pedals) |
| `overdrive_control.ctrlD` | tight |

Every byte was already spare in the existing bitstream; no
`block_design.tcl` change was needed.

A pedal stage processes audio when both:

```
flag2(fGate)                                  -- section master
flag of distortion_control.ctrlD[bit_for_stage]
```

are true. When either is false the stage is bit-exact bypass. The
legacy distortion stage has an extra negation:

```
distortionLegacyOn = flag2(fGate) AND NOT anyDistPedalOn
```

so it stays out of the way as soon as any pedal-mask bit is set.

## Python API (final)

Stable. Implemented in `audio_lab_pynq/AudioLabOverlay.py`.

```python
ovl.set_distortion_pedal(name, enabled=True, exclusive=True)
ovl.set_distortion_pedals(**kwargs)
ovl.clear_distortion_pedals()
ovl.get_distortion_pedals()           # -> dict[str, bool]
ovl.set_distortion_drive(value)
ovl.set_distortion_tone(value)
ovl.set_distortion_level(value)
ovl.set_distortion_bias(value)
ovl.set_distortion_tight(value)
ovl.set_distortion_mix(value)
ovl.set_distortion_settings(drive=, tone=, level=, bias=, tight=, mix=,
                            pedal=, pedals=, exclusive=True)
ovl.get_distortion_settings()
```

`exclusive=True` (the default) clears every other distortion-pedal
bit before setting the requested one. `exclusive=False` allows
stacking (advanced; the one-cell notebook auto-trims `level` to 25
in that mode).

`set_guitar_effects(distortion_on=...)` still flips the master in
`gate_control` bit 2; the pedal mask survives across that call
because it is read from `_dist_state`.

## Safe defaults at construction time

`AudioLabOverlay.DISTORTION_DEFAULTS`:

| Field | Default |
| --- | --- |
| `pedal_mask` | 0 |
| `drive` | 20 |
| `tone` | 50 |
| `level` | 35 |
| `bias` | 50 |
| `tight` | 50 |
| `mix` | 100 |

The section master starts off (gate.bit2 = 0), so loading the
overlay never produces a loud transient.

## Notebooks

| Notebook | Role |
| --- | --- |
| `DistortionModelsDebug.ipynb` | Walkthrough of the pedal-mask API: pedal list, bit positions, exclusive cycle, advanced stack, reset. |
| `GuitarEffectSwitcher.ipynb` | Original ipywidgets switcher with a Distortion Pedalboard section appended (state check, presets, live cell, stack cell, safe-OFF). |
| `GuitarPedalboardOneCell.ipynb` | Two-cell, single-screen UI for the whole chain. Apply / Safe Bypass / Refresh + four preset buttons. Reserved pedals are selectable with a warning. |

## Phasing — what is left

The big refactor is done; remaining work is incremental.

- **Phase C — Reserved pedals.**
  Implement `ds1`, `big_muff`, `fuzz_face` as their own small Clash
  stages. Insert them in the pipeline between tube_screamer and
  metal, mirroring the existing pedal stage shape (HPF -> mul ->
  clip -> post LPF -> level). Each addition needs a Vivado
  rebuild and a fresh timing review; do not let WNS slip much past
  the current -7.801 ns without flagging.
- **Phase D — Timing tightening.**
  WNS is currently -7.801 ns, baseline-equivalent but still
  negative. A pass that splits any remaining deep combinational
  block and pipelines the address paths into the cab tap / reverb
  BRAM should bring WNS toward 0.
- **Phase E — UI / preset polish.**
  Per-pedal default presets in `DistortionModelsDebug.ipynb`,
  per-pedal capture-and-compare in the one-cell notebook, A/B
  toggles, etc. No bitstream rebuild needed for any of this.

## Anti-goals

- **No** "one Clash function with a case over all seven pedals."
  That is the failed pattern. Each pedal is its own register-staged
  block.
- **No** hidden global state outside `Frame` and the per-stage
  `register …` values. Everything that crosses pipeline stages must
  be visible in the wiring of `fxPipeline`.
- **No** copying from GPL-licensed reference projects (guitarix,
  BYOD, …). Algorithm shape is a fair reference; source is not.
- **No** deploying a bitstream with WNS markedly worse than the
  current -7.801 ns without flagging the regression first.
