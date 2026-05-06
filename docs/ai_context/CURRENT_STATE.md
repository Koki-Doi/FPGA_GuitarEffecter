# Current state

Last updated: 2026-05-06 (real-pedal voicing pass on existing
effects; Clash + Vivado bit/hwh rebuilt and deployed).

## Real-pedal voicing pass (this branch, `feature/real-pedal-voicing-pass`)

Existing effect stages were re-tuned to be closer to recognised
real-pedal voicings, using only the existing GPIOs and `topEntity`
ports. No new effect stage, no new register, no `block_design.tcl`
change. The deployed bit/hwh was rebuilt from the new
`LowPassFir.hs` and pushed to the board.

What landed:

- `hw/ip/clash/src/LowPassFir.hs` -- voicing changes inside the
  existing register stages:
  - **Overdrive**: symmetric `softClip` -> `asymSoftClip` (tube-style
    even-harmonic content).
  - **clean_boost**: drive ceiling lowered from ~5x to ~4x;
    `cleanBoostLevelFrame` safety knee dropped from ~4.2M to ~3.2M.
  - **tube_screamer**: pre-HPF alpha range bumped (3..18), drive
    ceiling lowered (~7x vs. ~9x), asym clip knees dropped to
    `2_900_000 / 2_500_000`, post-LPF range shifted to
    `64..191` (darker top end at every TONE setting).
  - **RAT**: hard-clip floor lowered to `2_500_000` (more aggressive
    at high DRIVE), `ratPostLowpassFrame` alpha 192 -> 176, tone alpha
    base 224 -> 200.
  - **metal**: HPF alpha range bumped (6..37), drive ceiling lowered
    (~19x vs. ~22x), clip floor raised to `1_500_000`, post-LPF range
    shifted to `48..175` (darker top).
  - **Compressor**: soft-knee offset (`softThreshold = threshold -
    (threshold >> 4)`), gentler reduction slope (`excess >> 12` vs.
    `>> 11`).
  - **Noise Suppressor**: threshold hysteresis -- `closeT = threshold
    - (threshold >> 2)`, mid-gain check on the gain register decides
    the in-band region (no chatter).
  - **Cab IR**: 4-tap coefficient table re-balanced -- c0 reduced,
    c1/c2 increased -- so the very-high frequencies (close to
    Nyquist) are damped more.
  - **Reverb**: tone byte scaled (`tone - tone >> 3`) so TONE=100
    still keeps ~12.5 % damping in the recirculation path.
  - **EQ**: post-EQ mix wrapped in `softClip` so a max-boost on all
    three bands saturates softly instead of slamming the saturator.
- `docs/ai_context/REAL_PEDAL_VOICING_TARGETS.md` (new) -- per-effect
  reference style, current implementation, gap, plan, risk, and
  listening points.
- `docs/ai_context/DECISIONS.md` D16 -- recorded the constraints of
  the voicing pass.
- `docs/ai_context/DSP_EFFECT_CHAIN.md`,
  `docs/ai_context/TIMING_AND_FPGA_NOTES.md`,
  `docs/ai_context/RESUME_PROMPTS.md`, `README.md` -- updated.
- `hw/ip/clash/vhdl/LowPassFir/*` -- regenerated VHDL + repackaged IP.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` -- rebuilt. Final
  routed timing: WNS = -6.405 ns, TNS = -8806.714 ns,
  WHS = +0.052 ns, THS = 0.000 ns. **Improves on the deployed
  Compressor build's WNS (-7.516 ns) by 1.111 ns**; hold remains
  clean.
- PYNQ-Z2 deploy: completed; smoke test (`apply_chain_preset` over
  all 10 presets) passes, `R19_ADC_CONTROL = 0x23`, ADC HPF default-on
  preserved.

What did **not** change:

- `block_design.tcl` (GPIO inventory, addresses, AXI interconnect).
- `topEntity` port list of `LowPassFir.hs`.
- `gate_control.ctrlA` flag byte semantics.
- `axi_gpio_compressor` / `axi_gpio_noise_suppressor` enable
  semantics.
- Reserved bytes / bits (`axi_gpio_eq.ctrlD`,
  `axi_gpio_noise_suppressor.ctrlD`,
  `axi_gpio_distortion.ctrlD[3..5,7]`).
- Existing public Python API surface; chain preset names, byte caps,
  and Safe Bypass shape (no `effect_presets.py` change).
- C++ DSP prototypes (still removed, `DECISIONS.md` D13).

---

## Chain presets (prior branch, `feature/pedalboard-quality-presets`)

Ten named pedalboard voicings (Safe Bypass / Basic Clean / Clean
Sustain / Light Crunch / Tube Screamer Lead / RAT Rhythm / Metal
Tight / Ambient Clean / Solo Boost / Noise Controlled High Gain)
combine every section of the chain (Compressor + Noise Suppressor
+ Overdrive + Distortion Pedalboard + Amp + Cab IR + EQ + Reverb)
into one named state. Compressor `makeup` is held at 45..60 and
Distortion `level` is capped at 35 across every preset, so a click
on the wrong preset cannot blow the chain into clipping.

What landed:

- `audio_lab_pynq/effect_presets.py` -- `CHAIN_PRESETS` dict-of-dicts
  plus `CHAIN_PRESET_SECTIONS` canonical section list.
- `audio_lab_pynq/AudioLabOverlay.py` -- `apply_chain_preset`,
  `get_chain_preset_names`, `get_chain_preset`,
  `get_current_pedalboard_state`. Robust to missing GPIOs (older
  bitstream without `axi_gpio_compressor` still applies the rest).
- `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb` -- new
  Chain Preset dropdown + Apply Chain Preset / Show Current State
  buttons; existing accordion / Apply / Safe Bypass / Refresh kept
  intact. Two-cell layout preserved. Inline `CHAIN_PRESETS_INLINE`
  fallback for older deployed packages.
- `tests/test_overlay_controls.py` -- chain preset shape /
  Safe-Bypass-off-everywhere / makeup-band / distortion-level-cap /
  apply round-trip / unknown-name / missing-GPIO survival tests.
- `README.md`, `docs/ai_context/*.md` -- this file plus DSP_EFFECT_CHAIN
  / DECISIONS (new D15) / EFFECT_ADDING_GUIDE / RESUME_PROMPTS.

What did **not** change:

- Hardware (`block_design.tcl`, `LowPassFir.hs`, IP packaging,
  bitstream / hwh). The deployed Compressor build (`d216a9c`) is
  unchanged.
- Existing GPIO names, addresses, or ctrlA / B / C / D meanings.
- Compressor / Noise Suppressor / Distortion / amp / cab / eq /
  reverb DSP behaviour.
- Existing public Python API surface
  (every `set_*_settings` / `set_guitar_effects` keyword still
  works the same).

Vivado / Clash were **not** run. No timing review needed.

---


## Compressor add (this branch, `feature/compressor-effect`)

A new stereo-linked feed-forward peak compressor section was added on
its own AXI GPIO. Sits between the noise suppressor and the overdrive
in the Clash pipeline. Enable flag lives inside the new GPIO; the
master flag byte (`gate_control.ctrlA`) was not touched.

What landed:

- `hw/Pynq-Z2/block_design.tcl` -- new `axi_gpio_compressor` IP at
  `0x43CD0000`, `NUM_MI` bumped from 14 to 15, M14_AXI / M14_ACLK /
  M14_ARESETN wired, address segment added.
- `hw/ip/clash/src/LowPassFir.hs` -- new `compressor_control` port,
  `fComp` field on `Frame`, `compEnvNext` / `compTargetGain` /
  `compGainNext` / `compApplyFrame` / `compMakeupFrame` helpers, and
  the `compLevelPipe -> compEnv -> compGain -> compApplyPipe ->
  compMakeupPipe` block in `fxPipeline` between the noise suppressor
  and the overdrive.
- `audio_lab_pynq/control_maps.py` -- `makeup_to_u7`,
  `compressor_enable_makeup_byte`, `compressor_word` helpers.
- `audio_lab_pynq/effect_defaults.py` -- `COMPRESSOR_DEFAULTS`
  (`enabled=False, threshold=45, ratio=35, response=45, makeup=50`).
- `audio_lab_pynq/effect_presets.py` -- `COMPRESSOR_PRESETS`
  (Comp Off / Light Sustain / Funk Tight / Lead Sustain / Limiter-ish).
- `audio_lab_pynq/AudioLabOverlay.py` -- `axi_gpio_compressor`
  attribute, `_compressor_state` cache, `_apply_compressor_state_to_word`,
  `set_compressor_settings(threshold=, ratio=, response=, makeup=,
  enabled=)`, `get_compressor_settings()`, per-knob shortcuts.
- `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb` -- new
  Compressor accordion section (THRESHOLD / RATIO / RESPONSE /
  MAKEUP sliders + 5 presets); `apply_settings` / `safe_bypass` /
  `refresh_status` updated; chain header includes Compressor.
- `tests/test_overlay_controls.py` -- compressor encoding /
  round-trip / clamp / preset snapshot tests; defaults sanity test.
- `docs/ai_context/*.md` and `README.md` -- this file plus
  GPIO_CONTROL_MAP / DSP_EFFECT_CHAIN / DECISIONS (new D14) /
  BUILD_AND_DEPLOY / EFFECT_ADDING_GUIDE / RESUME_PROMPTS / TIMING.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` -- rebuilt with the
  new GPIO and DSP block. Final routed timing: WNS=-7.516 ns,
  TNS=-8815.426 ns, WHS=+0.052 ns, THS=0.000 ns. Regresses 0.405 ns
  vs the noise-suppressor build's `-7.111 ns`; still inside the
  historical deploy band.

What did **not** change:

- Existing GPIO names, addresses, or ctrlA / B / C / D meanings.
- Noise Suppressor stage, distortion pedal-mask, RAT, amp / cab / EQ /
  reverb stages.
- The pedal-mask shape from `baa97ff`.
- Existing public Python API surface (every `set_*_settings` /
  `set_guitar_effects` keyword still works the same).

---


## Effect-chain refactor (this branch, `feature/effect-chain-refactor`)

The Python control layer was split into smaller modules, the GPIO
inventory was promoted to a fixed ledger, the C++ DSP prototypes were
removed, and a new effect-adding guide / template were added. **No GPIO
re-allocation, no Clash change, no Vivado / bit / hwh rebuild.** The
deployed bitstream is unchanged.

What landed:

- `audio_lab_pynq/control_maps.py` — pack / unpack / clamp helpers (single
  source of truth for byte encoding).
- `audio_lab_pynq/effect_defaults.py` — per-effect default dicts; the
  legacy class attributes (`AudioLabOverlay.DISTORTION_DEFAULTS`,
  `NOISE_SUPPRESSOR_DEFAULTS`, `DISTORTION_PEDALS`,
  `DISTORTION_PEDALS_IMPLEMENTED`) are re-exported from here.
- `audio_lab_pynq/effect_presets.py` — Notebook + API presets;
  `DISTORTION_PRESETS`, `NOISE_SUPPRESSOR_PRESETS`. The notebook
  imports these with an inline fallback.
- `AudioLabOverlay.py` — the legacy classmethods (`_clamp_percent`,
  `_percent_to_u8`, `_level_to_q7`, `_pack3`, `_pack4`,
  `_noise_threshold_to_u8`, `_noise_suppressor_word`) are now thin
  delegates to `control_maps`. **Every public API is unchanged.**
- `tests/test_overlay_controls.py` — added module-level tests for
  `control_maps` / `effect_defaults` / `effect_presets`, plus
  byte-for-byte snapshot tests covering every preset and the Safe
  Bypass shape so future refactors cannot silently change the bits.
- `docs/ai_context/GPIO_CONTROL_MAP.md` — promoted to a fixed
  inventory with `active / reserved / legacy mirror / unused /
  deprecated` status per byte and an explicit "do not repurpose"
  rule set.
- `docs/ai_context/EFFECT_ADDING_GUIDE.md` (new) — decision flow,
  Clash rules, Python rules, notebook rules, deploy checklist.
- `docs/ai_context/EFFECT_STAGE_TEMPLATE.md` (new) — fillable spec
  sheet for new effects.
- `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb` — pulled
  presets from `effect_presets.py` (with inline fallback for older
  deployed packages); introduced `make_slider` / `make_section`
  helpers; split `apply_settings` into
  `apply_distortion_settings` / `apply_noise_suppressor_settings` /
  `apply_chain_settings`. Two-cell layout, Apply-button discipline,
  and visual structure are unchanged.
- `src/effects/` — **removed.** The C++ DSP prototypes were never on
  the live PL path; keeping them around invited the "implement in
  C++ then port" pattern that this project does not follow. See
  `DECISIONS.md` D12. `make tests` now runs Python tests only.

What did **not** change:

- GPIO names, addresses, and ctrlA / ctrlB / ctrlC / ctrlD assignments.
- `block_design.tcl`, `LowPassFir.hs` (DSP source), VHDL, IP packaging.
- `audio_lab.bit` / `audio_lab.hwh`. Timing baseline (WNS = -7.111 ns,
  WHS = +0.053 ns, THS = 0.000 ns) is unaffected — no rebuild was
  performed.
- Any audible behaviour. Snapshot tests guarantee the bits sent to
  the FPGA match the previous deployed bitstream byte-for-byte.

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
