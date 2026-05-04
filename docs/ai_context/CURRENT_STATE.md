# Current state

Last updated: 2026-05-04 (post-deploy of the pedal-mask refactor).

## Headline

The selectable-distortion refactor is **shipped**. The pedal-mask
design is implemented in Clash, exposed through the Python API,
covered by tests, walked-through by two notebooks, built into a
fresh `audio_lab.bit` / `audio_lab.hwh`, deployed to the lab board,
and verified live.

The earlier 8-way `model_select` attempt is **gone**. Do not bring
that pattern back; see `DECISIONS.md` D6 for the reason.

## Working tree

```
$ git status --short
?? .claude/
```

The working tree is clean. The last three commits on `master` carry
the change:

```
2198873  Add one-cell guitar pedalboard notebook
e1bb313  Add distortion pedalboard controls to GuitarEffectSwitcher notebook
baa97ff  Refactor distortion models into pedal-style pipeline
```

`baa97ff` is the implementation commit (Clash + Python + tests +
regenerated VHDL/IP/bit/hwh, plus the ADC HPF default-on rollup that
had been sitting in the working tree from the previous arc). `e1bb313`
and `2198873` are notebook-only follow-ups.

## What ships in the current bitstream

Pedal stages live between the existing RAT block and the amp /
cab / EQ / reverb tail of the pipeline. Master enable stays on
`gate_control` bit 2 (the existing `distortion_on`).

| Pedal | bit (`distortion_control.ctrlD`) | Status |
| --- | --- | --- |
| `clean_boost` | 0 | Clash stage implemented (3 register stages). |
| `tube_screamer` | 1 | Clash stage implemented (5 register stages). |
| `rat` | 2 | Mapped onto the existing RAT stage; Python forces `gate_control` bit 4 high when this bit is set. |
| `ds1` | 3 | **Reserved.** Mask bit accepted by the API; FPGA has no stage yet, so audio passes through unchanged. |
| `big_muff` | 4 | **Reserved**, same caveat. |
| `fuzz_face` | 5 | **Reserved**, same caveat. |
| `metal` | 6 | Clash stage implemented (5 register stages). |
| reserved | 7 | Unused. |

Legacy distortion (the original `distortion_*` API and Clash stages)
still works: it gates on `distortion_legacyOn = flag2(fGate) AND
NOT anyDistPedalOn`. As soon as any pedal-mask bit is set, the
legacy stage steps aside.

## Live verification

Run on the board after deploy:

```
ADC HPF        : True
R19_ADC_CONTROL: 0x23
clean_boost    mask=0x01  drive=40 level=35
tube_screamer  mask=0x02  drive=40 level=35
rat            mask=0x04  drive=40 level=35
ds1            mask=0x08  drive=40 level=35
big_muff       mask=0x10  drive=40 level=35
fuzz_face      mask=0x20  drive=40 level=35
metal          mask=0x40  drive=40 level=35
cleared        mask=0x00
```

ADC HPF default-on (`R19_ADC_CONTROL = 0x23`) survives. Every pedal
mask bit lands at the documented position. `clear_distortion_pedals`
returns the section to zero.

## Vivado timing summary (deployed bit)

| Build | WNS | TNS | Verdict |
| --- | --- | --- | --- |
| Pre-refactor baseline | -7.722 ns | -4613.495 ns | Shipped, audio works in practice. |
| Rejected `model_select` | -15.067 ns | -7308.247 ns | Not deployed. |
| **pedal-mask (current)** | **-7.801 ns** | -7381.742 ns | Deployed. Roughly baseline-equivalent setup slack. |

Hold timing is fine (`WHS = +0.050 ns`, `THS = 0.000 ns`). Setup is
still slightly negative; not a regression versus baseline, but the
build is not formally clean. Treat any further timing slip with
suspicion.

## Notebooks

| Notebook | Status |
| --- | --- |
| `audio_lab_pynq/notebooks/InputDebug.ipynb` | Existing input-noise triage notebook, ADC HPF default-on aware. |
| `audio_lab_pynq/notebooks/GuitarEffectsChain.ipynb` | Existing chain UI. Untouched in this refactor. |
| `audio_lab_pynq/notebooks/GuitarEffectSwitcher.ipynb` | **Updated.** Original ipywidgets switcher cells preserved; a "Distortion Pedalboard" section appended (state check, exclusive single-pedal cell, four presets, live cell, advanced stack cell, safe-OFF cell). |
| `audio_lab_pynq/notebooks/DistortionModelsDebug.ipynb` | **Replaced** with a pedalboard walkthrough: lists pedals + bit positions + which are implemented vs reserved, cycles each pedal exclusively, has a live cell, an advanced stack cell, and a reset cell. |
| `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb` | **New.** Two-cell single-screen ipywidgets UI for the whole chain (Noise Gate -> Overdrive -> Distortion Pedalboard -> Amp -> Cab -> EQ -> Reverb). Apply / Safe Bypass / Refresh / four preset buttons; stack mode auto-trims `level` to 25; reserved pedals selectable with a warning banner. |

All five notebooks are deployed under
`/home/xilinx/jupyter_notebooks/audio_lab/` on the board.

## What to do next

Open work, in roughly priority order:

1. **Implement the reserved pedals** — `ds1`, `big_muff`,
   `fuzz_face`. Each as its own small Clash stage following the same
   shape (HPF -> mul -> clip -> post LPF -> level), inserted between
   tube_screamer and metal in the pipeline. Re-check timing after
   each addition.
2. **Drive WNS toward 0.** The current build is at -7.801 ns; the
   audio path tolerates this in practice but it is technically out
   of spec. Worth a pass that splits any remaining deeper
   combinational stage and / or pipelines the cab or reverb tap
   address paths.
3. **UI / preset polish** in the notebooks. Possible adds:
   per-pedal default presets, an A/B compare cell, a quick-record
   cell that pairs the pedalboard with the existing diagnostic
   capture helpers.
4. **Diagnostic capture for distortion stages.** Re-use
   `diagnostics.capture_input` to log a clip waveform per pedal so
   we can compare voicings without ear fatigue.

## Things to be careful about

- Do **not** silently revert the ADC HPF default-on. `R19_ADC_CONTROL`
  must read back as `0x23` after `config_codec()`.
- Do **not** reintroduce a single function with a `case` over all
  seven pedals. That is exactly what regressed timing the first time;
  see `TIMING_AND_FPGA_NOTES.md`.
- Do **not** deploy a bitstream whose WNS is significantly worse than
  -7.801 ns without flagging the regression to the user first.
- Do **not** push, pull, or fetch.
