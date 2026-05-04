# DSP effect chain

The entire PL DSP pipeline lives in a single Clash module:
`hw/ip/clash/src/LowPassFir.hs` (the file name is historical — it has long
since stopped being just an FIR). The C++ files under `src/effects/` are
**reference implementations only**; they do not run on the board.

## Core types

```haskell
type Sample = Signed 24    -- Audio samples, two's complement
type Wide   = Signed 48    -- Wide accumulator for products and sums
type Ctrl   = BitVector 32 -- One AXI GPIO word
```

A `Frame` is the data record threaded down the pipeline. It carries the
left/right sample pair, every effect's control word, the dry copy used by
wet/dry mixes, and a set of `Wide` accumulators (`fAccL/R`, `fAcc2L/R`,
`fAcc3L/R`) that successive stages reuse. `Maybe Frame` is the pipeline
type; `Nothing` means a slot is idle.

## Numeric primitives

| Helper | Purpose |
| --- | --- |
| `mulU8 :: Sample -> Unsigned 8 -> Wide` | 24×8 signed-by-unsigned multiply, returns `Wide`. |
| `mulU9`, `mulU12` | 24×9 and 24×12 variants for headroom-sensitive products. |
| `mulS10` | 24×10 signed×signed, used by cab IR coefficients. |
| `satWide` | Saturating clamp from `Wide` back into `Sample`. |
| `satShift7/8/9/10/12` | `>> N` followed by `satWide`; how a stage returns to the 24-bit lane after a multiply. |
| `softClip` | Symmetric soft clip with a fixed knee at `4_194_304`. |
| `softClipK knee x` | Symmetric soft clip with a tunable knee. |
| `asymSoftClip kneeP kneeN x` | Different knees and slopes for + and − half. |
| `asymHardClip kneeP kneeN x` | Hard clamp with independent thresholds. |
| `hardClip x threshold` | Symmetric hard clip. |
| `onePoleU8 alpha prev x` | `alpha/256 · x + (256-alpha)/256 · prev`; one-pole IIR. |

The discipline is: **multiply** in `Wide`, **shift+sat** back into
`Sample`, then do further sample-domain work. Never feed an unsaturated
`Wide` into the next multiplication chain.

## Pipeline order

(Each arrow is at least one register.)

```
makeInput
  -> nsLevel -> nsApply                                 (noise suppressor envelope + apply, replaces the legacy hard gate)
  -> overdrive (drive mul -> boost -> clip -> tone -> level)
  -> legacy distortion (drive mul -> boost -> clip -> tone -> level)
  -> RAT (HPF -> drive -> opamp LPF -> hard clip -> post LPF -> tone -> level -> mix)
  -> clean_boost          (3 stages: mul -> shift -> level + softClip safety)
  -> tube_screamer        (5 stages: HPF -> mul -> asym soft clip -> post LPF -> level)
  -> metal_distortion     (5 stages: tight HPF -> mul -> hard clip -> post LPF -> level)
  -> amp simulator (HPF -> drive -> waveshape -> pre-LPF -> 2nd stage -> tone stack -> power -> resonance/presence -> master)
  -> cab IR (3-tap convolution + level/mix)
  -> EQ (3-band)
  -> reverb (BRAM tap + tone + feedback + mix)
  -> output AXIS register
```

## Noise Suppressor section

Replaces the legacy hard noise gate. Driven by the dedicated
`axi_gpio_noise_suppressor` GPIO carried in `fNs` (THRESHOLD / DECAY /
DAMP / mode bytes); enable still rides on `flag0(fGate)` (the existing
`noise_gate_on` bit) so `set_guitar_effects(noise_gate_on=...)` keeps
working. Bit-exact bypass when the flag is clear. RNNoise / FFT /
spectral methods were intentionally **not** adopted -- too heavy for
this PL budget.

Same shape as the legacy gate: one envelope-input register stage, two
feedback registers (envelope + smoothed gain), one apply register
stage. Wiring lives in `fxPipeline` as `nsLevelPipe -> nsEnv -> nsGain
-> nsPipe -> odDriveMulPipe`.

| Stage | What it does |
| --- | --- |
| `nsLevelPipe` (reuses `gateLevelFrame`) | `fWetL = max(\|L\|, \|R\|)` -- one register stage feeding the envelope follower. |
| `nsEnv` (`nsEnvNext` register feedback) | Peak follower. Attack-instantaneous; release ~ `env >> 8 + 1` per sample. Reset to 0 when the noise-suppressor enable is clear. |
| `nsGain` (`nsGainNext` register feedback) | Smoothed gain. Open is fast (`nsAttackStep = 512`, ~8 samples to unity). Close ramps toward `nsTargetGain` at `nsCloseStep` per sample, where `nsCloseStep = max(1, (255 - decay_byte) >> 2)`. Target is `gateUnity` when `env >= threshold`, otherwise `nsClosedGain damp = ((255 - damp_byte)^2) >> 5`. |
| `nsPipe` (`nsApplyFrame`) | Multiply each channel by the smoothed gain (`mulU12 x gain`) and saturate (`satShift12`). Bit-exact bypass when `flag0(fGate)` is clear. |

### Parameter mappings

| Knob | Python | byte (ctrl byte of fNs) | DSP effect |
| --- | --- | --- | --- |
| THRESHOLD | 0..100 | `ctrlA = round(threshold * 255 / 1000)` (so 100 -> 26) | scaled to `Sample` via `nsThresholdSample = asSigned9 ctrlA << 13`, identical scaling to the legacy gate threshold. |
| DECAY | 0..100 | `ctrlB = round(decay * 255 / 100)` | full-close range from ~1.4 ms (decay=0) to ~85 ms (decay=100). Linear ramp; integer step per sample. |
| DAMP | 0..100 | `ctrlC = round(damp * 255 / 100)` | closed gain ranges from ~50 % (damp=0) to 0 % (damp=100). Quadratic curve via `((255 - byte)^2) >> 5`. |
| mode | 0..255 raw | `ctrlD` | reserved; 0 today. Future use: NS-2 vs NS-1X mode, attack / hold knobs. |

The legacy noise-gate frame helpers (`gateLevelFrame`, `gateEnvNext`,
`gateOpenNext`, `gateGainNext`, `gateFrame`) are **kept as Haskell
source** so older bitstreams keep building, but no register in the
active pipeline references them; the synthesiser drops them.
`gate_control.ctrlB` is therefore unused in the new bitstream -- we
still mirror the threshold byte to it from Python for backward
compatibility with overlays that lack the new GPIO.

## Legacy distortion section

Six register stages, gated by
`distortionLegacyOn = flag2(fGate) AND NOT anyDistPedalOn`:

1. `distortionDriveMultiplyFrame` — pre-gain `mulU12`, `gain = 256 + drive*8`.
2. `distortionDriveBoostFrame` — `satShift8` back to `Sample`.
3. `distortionDriveClipFrame` — `hardClip` with a drive-dependent threshold.
4. `distortionToneMultiplyFrame` — products with previous sample (1-pole tone blend).
5. `distortionToneBlendFrame` — sum + `satShift8`.
6. `distortionLevelFrame` — `mulU8` by level, `satShift7`.

The `NOT anyDistPedalOn` part is what lets the user-facing
`exclusive=True` semantics actually exclude the legacy stage when
a pedal-mask bit is set. The legacy stage is otherwise unchanged
and the original `distortion=` / `distortion_tone` / `distortion_level`
API still drives it as before.

## Pedal-mask distortion section

Independent register-staged blocks. Each is enabled only when both
`flag2(fGate)` AND its bit in `distortion_control.ctrlD` are set.
When off, every stage is bit-exact bypass.

| Pedal | Frame functions (in order) |
| --- | --- |
| `clean_boost` (bit 0) | `cleanBoostMulFrame` -> `cleanBoostShiftFrame` -> `cleanBoostLevelFrame` |
| `tube_screamer` (bit 1) | `tubeScreamerHpfFrame` -> `tubeScreamerMulFrame` -> `tubeScreamerClipFrame` -> `tubeScreamerPostLpfFrame` -> `tubeScreamerLevelFrame` |
| `rat` (bit 2) | (no new stage — handled by the existing RAT block; Python flips `gate_control` bit 4 to engage it) |
| `ds1` (bit 3) | reserved; no Clash stage yet, audio passes through |
| `big_muff` (bit 4) | reserved; same |
| `fuzz_face` (bit 5) | reserved; same |
| `metal` (bit 6) | `metalHpfFrame` -> `metalMulFrame` -> `metalClipFrame` -> `metalPostLpfFrame` -> `metalLevelFrame` |

Per-channel filter state for the HPFs and post-LPFs lives in
pipeline-level registers wired up in `fxPipeline` (e.g.
`tsHpfLpPrevL`, `metalPostLpPrevR`). Frame fields `fEqLowL/R` and
`fEqHighLpL/R` are used as transient carriers between adjacent
stages and are reset by the EQ block downstream, so reusing them
inside the pedal stages is safe.

## Existing RAT section (for reference)

Eight register stages with intermediate state held outside the frame:
`ratHighpass -> ratDriveMul -> ratDriveBoost -> ratOpAmpLowpass ->
ratClip -> ratPostLowpass -> ratTone -> ratLevel -> ratMix`. This is the
template for any new "pedal" we add: a small chain of single-purpose
register stages that each do one thing.

## Adding a new effect

When adding a stage:

- Each new register stage should carry **one operation**: a multiply, a
  saturation/shift, an add, or a clip. Do not pile a multiply *and* a
  case-of-N *and* a clip inside one combinational block.
- Use the existing `Frame` accumulator fields (`fAccL/R`, `fAcc2L/R`,
  `fAcc3L/R`, `fEqLowL/R`, `fEqHighLpL/R`) for transient state — the
  distortion section can reuse them because EQ/amp stages overwrite
  them later.
- Per-channel filter state that must persist across samples lives in
  pipeline-level registers (see how `ratHpInPrevL` etc. are built up
  with `register 0 (frameOr ... <$> reg <*> pipe)`).
- When the enable bit is clear, the stage **must** preserve `fL` / `fR`
  bit-exactly. The pattern is `f { fL = if on then new else fL f }`.
- Wrap-around is forbidden. Every combinational path that produces a
  `Wide` value must end in `satWide`, `satShiftN`, or one of the
  `*Clip` functions before re-entering the `Sample` lane.

## What to avoid

- A single function that contains a `case modelSelect of …` with eight
  arms each producing a different multiply, filter, or clip. The
  synthesiser has to build all eight in parallel and mux at the end —
  the combinational depth and the fanout both grow, and timing
  collapses. The previous attempt at a unified model selector regressed
  WNS by roughly 7 ns.
- Reusing the same accumulator field within a stage for different
  purposes. The synthesiser will tolerate it, but it makes future edits
  brittle.
- Long chains of unsaturated arithmetic. Always saturate before letting
  a value leave a register stage.
