# Current state

Last updated: 2026-05-05 (post-deploy of the noise-suppressor refactor).

## Headline

The noise-suppressor refactor is **shipped**. A dedicated
`axi_gpio_noise_suppressor` IP at `0x43CC0000` carries THRESHOLD /
DECAY / DAMP / mode for a BOSS NS-2 / NS-1X-style noise suppressor;
the Clash side replaces the legacy hard noise gate stages with the
new envelope + smoothed-gain block; the Python API ships
`set_noise_suppressor_settings` / `get_noise_suppressor_settings` and
mirrors the threshold byte into the legacy `gate_control.ctrlB` slot
for backward compatibility. The pedal-mask distortion section from
the prior arc is unchanged and still active.

The earlier 8-way `model_select` distortion attempt is still gone
(`DECISIONS.md` D6); the legacy hard noise gate is now also retired
from the active pipeline (`DECISIONS.md` D11).

## Working tree

`feature/noise-suppressor-gpio-ui` carries the noise-suppressor work,
tagged at the parent commit as `before-noise-suppressor-gpio-ui`. The
branch is local-only; nothing has been pushed.

The previous pedal-mask arc lives on `master`:

```
3f2137d  Update AI context docs after pedal-mask distortion deployment
2198873  Add one-cell guitar pedalboard notebook
e1bb313  Add distortion pedalboard controls to GuitarEffectSwitcher notebook
baa97ff  Refactor distortion models into pedal-style pipeline
```

The noise-suppressor branch touches:

- `hw/Pynq-Z2/block_design.tcl` -- new `axi_gpio_noise_suppressor` IP
  at `0x43CC0000`, `NUM_MI` bumped to 14.
- `hw/ip/clash/src/LowPassFir.hs` -- new `noise_suppressor_control`
  port, `fNs` field on `Frame`, `nsEnvNext` / `nsGainNext` /
  `nsApplyFrame` / helpers, pipeline wiring updated.
- `hw/ip/clash/vhdl/LowPassFir/*` -- regenerated VHDL + repackaged IP.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` -- rebuilt with the new
  GPIO and DSP block.
- `audio_lab_pynq/AudioLabOverlay.py` -- `NOISE_SUPPRESSOR_*`
  constants, `_noise_threshold_to_u8`, `set_/get_noise_suppressor_*`,
  `_apply_noise_suppressor_state_to_word`, `set_guitar_effects`
  mirrors threshold + on-flag into the new GPIO.
- `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb` -- Noise
  Gate accordion replaced with Noise Suppressor section (THRESHOLD /
  DECAY / DAMP sliders + four NS presets); `apply_settings` /
  `safe_bypass` / `refresh_status` updated.
- `tests/test_overlay_controls.py` -- threshold scale anchors
  (0/10/50/100 -> 0/3/13/26), clamps, NS settings round trip, GPIO
  word packing, mirror-to-gate test, `set_guitar_effects` NS GPIO
  mirror.
- `docs/ai_context/*.md` -- this file plus GPIO map, DSP chain,
  decisions, build/deploy, project context, timing, resume prompts.

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
  the noise-suppressor build's WNS without flagging the regression
  first.
- Do **not** revive the legacy `gateGainNext` / `gateFrame` registers
  in the active pipeline. The active gain stage is the noise
  suppressor (`nsApplyFrame`); the legacy helpers are kept as Haskell
  source for backward compatibility but are not wired up.
- Do **not** drop the legacy `gate_control.ctrlB` write from
  `set_guitar_effects` -- older bitstreams without
  `axi_gpio_noise_suppressor` still rely on it.
- Do **not** push, pull, or fetch.
