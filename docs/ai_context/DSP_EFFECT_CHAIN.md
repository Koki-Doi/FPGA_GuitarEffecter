# DSP effect chain

The entire PL DSP pipeline lives in a single Clash module:
`hw/ip/clash/src/LowPassFir.hs` (the file name is historical — it has long
since stopped being just an FIR). This module is the **only** source of
truth for DSP behaviour on the live PYNQ-Z2 build.

The earlier C++ DSP prototypes that lived under `src/effects/` were
removed (`DECISIONS.md` D12). They were not on the live PL path and
their continued presence risked steering future work into "implement
in C++ then port" loops, which this project does not do.

The live build also carries a "real-pedal voicing pass" and a later
recording-analysis-driven voicing pass of the existing stages
(`DECISIONS.md` D16 / D17); see
[`REAL_PEDAL_VOICING_TARGETS.md`](REAL_PEDAL_VOICING_TARGETS.md) for
the per-stage target style, current implementation, gap, plan, risk,
and listening points, and
[`AUDIO_RECORDING_ANALYSIS.md`](AUDIO_RECORDING_ANALYSIS.md) for the
measurement findings. These passes change constants and clip-helper
choice inside the existing register stages; they do not change the
pipeline shape, the GPIO inventory, or the `topEntity` ports.

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
  -> compLevel -> compApply -> compMakeup               (stereo-linked feed-forward peak compressor; bit-exact bypass when off)
  -> overdrive (drive mul -> boost -> clip -> tone -> level)
  -> legacy distortion (drive mul -> boost -> clip -> tone -> level)
  -> RAT (HPF -> drive -> opamp LPF -> hard clip -> post LPF -> tone -> level -> mix)
  -> clean_boost          (3 stages: mul -> shift -> level + softClip safety)
  -> tube_screamer        (5 stages: HPF -> mul -> asym soft clip -> post LPF -> level)
  -> metal_distortion     (5 stages: tight HPF -> mul -> hard clip -> post LPF -> level)
  -> amp simulator (HPF -> drive -> waveshape -> pre-LPF -> 2nd stage -> tone stack -> power -> resonance/presence -> master)
  -> cab IR (4-tap cabinet FIR + level/mix)
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

## Compressor section

Stereo-linked feed-forward peak compressor on its own
`axi_gpio_compressor` GPIO carried in `fComp` (THRESHOLD / RATIO /
RESPONSE bytes plus a packed enable+MAKEUP byte). Sits between the
noise suppressor and the overdrive: tightens picking and evens out
level before the gain stages. Enable lives on `fComp ctrlD` bit 7
(not on `gate_control.ctrlA` -- the flag byte was already full).
Bit-exact bypass when the enable bit is clear. RNNoise / FFT /
spectral / lookahead methods were intentionally **not** adopted --
too heavy for this PL budget.

Same shape as the noise suppressor (one envelope-input register
stage reusing `gateLevelFrame`, two feedback registers for
envelope + smoothed gain, one apply register stage, plus a separate
makeup multiply stage so each register holds a single multiply).
Wiring lives in `fxPipeline` as
`compLevelPipe -> compEnv -> compGain -> compApplyPipe -> compMakeupPipe`.

| Stage | What it does |
| --- | --- |
| `compLevelPipe` (reuses `gateLevelFrame`) | `fWetL = max(\|L\|, \|R\|)` -- one register stage feeding the envelope follower (stereo-linked sidechain). |
| `compEnv` (`compEnvNext` register feedback) | Peak follower. Attack-instantaneous; release ~ `env >> 8 + 1` per sample plus a response-controlled extra step (`max(1, ((255 - response_byte) >> 4) + ((255 - response_byte) >> 6))`). Reset to 0 when the compressor enable is clear. |
| `compGain` (`compGainNext` register feedback) | Smoothed gain. Both attack and release use a response-controlled step (`max(1, ((255 - response_byte) >> 3) + ((255 - response_byte) >> 5))`). Target is `gateUnity` when `env <= softThreshold`, otherwise `gateUnity - reduction`, where the audio-analysis pass uses `threshold = (byte << 13) * 7/8`, `softThreshold = threshold - threshold/8`, and `reduction = clamp(0, gateUnity, (((excess >> 12) + (excess >> 14)) * ratio_byte) >> 8)`. |
| `compApplyPipe` (`compApplyFrame`) | Multiply each channel by the smoothed gain (`mulU12 x gain`) and saturate (`satShift12`). Bit-exact bypass when the compressor is off. |
| `compMakeupPipe` (`compMakeupFrame`) | Q8 makeup multiply (`factor = 192 + makeup_u7` in `[192, 319]`, applied via `mulU9 + satShift8`). Bit-exact bypass when the compressor is off. |

### Parameter mappings

| Knob | Python | byte (ctrl byte of fComp) | DSP effect |
| --- | --- | --- | --- |
| THRESHOLD | 0..100 | `ctrlA = round(threshold * 255 / 100)` | scaled to `Sample` via `compThresholdSample = (asSigned9 ctrlA << 13) - ((asSigned9 ctrlA << 13) >> 3)`, so compression begins a little earlier on guitar-level material. |
| RATIO | 0..100 | `ctrlB = round(ratio * 255 / 100)` | linear gain-reduction factor: 0 = ~no compression, 255 = strong limiting. Reduction scales with both excess (`env - threshold`) and ratio_byte. |
| RESPONSE | 0..100 | `ctrlC = round(response * 255 / 100)` | shared attack/release smoothing time. 0 -> fastest; 255 -> slowest (~128 samples to converge). |
| MAKEUP | 0..100 | `ctrlD bits[6:0] = round(makeup * 127 / 100)` (clamped to 0..127) | Q8 makeup factor `192 + makeup_u7` (range 192..319, ~0.75x..1.25x). Conservative on purpose -- a Compressor preset cannot blow the rest of the chain into clipping. |
| enable | bool | `ctrlD bit 7` | section enable. Bit-exact bypass when clear. |

### Why a new GPIO

The compressor wanted five distinct knobs (threshold / ratio /
response / makeup / enable). `gate_control.ctrlA` (the master flag
byte) was already full, every existing `reserved` byte is held for
a different planned feature, and the compressor benefits from being
able to flip its own enable without read-modify-write on a shared
flag byte. So a new `axi_gpio_compressor` IP was added at
`0x43CD0000` and a new `compressor_control` port was added to the
Clash top entity. See `DECISIONS.md` D14.

## Overdrive section

Driven by the existing `axi_gpio_overdrive` GPIO. Enable remains
`gate_control.ctrlA` bit 1, and `ctrlA` / `ctrlB` / `ctrlC` remain
tone / level / drive. The audio-analysis pass found the stage too close
to Bypass at the recorded input level, so it retunes existing stages
only:

| Stage | Current shape |
| --- | --- |
| `overdriveDriveMultiplyFrame` | Q8 pre-gain is now `256 + drive*5`, about 1x..6x, so DRIVE 30..50 reaches the asymmetric clip knee more often. |
| `overdriveDriveBoostFrame` | Existing `satShift8` return to `Sample`. |
| `overdriveDriveClipFrame` | `asymSoftClip 2_700_000 2_300_000`, lower than the previous `3_300_000 / 2_900_000`, for audible light crunch without becoming DS-1 / RAT style distortion. |
| `overdriveToneMultiplyFrame` -> `overdriveToneBlendFrame` | Existing one-pole tone blend; no GPIO or UI change. |
| `overdriveLevelFrame` | Existing Q7 level multiply now runs through `softClipK 3_200_000` so higher drive settings do not create a large output jump. |

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
| `metal` (bit 6) | `metalHpfFrame` -> `metalMulFrame` -> `metalClipFrame` -> `metalPostLpfFrame` -> `metalLevelFrame` |
| `ds1` (bit 3) | `ds1HpfFrame` -> `ds1MulFrame` -> `ds1ClipFrame` -> `ds1ToneFrame` -> `ds1LevelFrame` (BOSS DS-1 style: HPF, drive, asym soft clip with low knees, post LPF, level+safety) |
| `big_muff` (bit 4) | `bigMuffPreFrame` -> `bigMuffClip1Frame` -> `bigMuffClip2Frame` -> `bigMuffToneFrame` -> `bigMuffLevelFrame` (Big Muff Pi style: pre-gain, two cascaded soft clips, tone LPF, level+safety) |
| `fuzz_face` (bit 5) | `fuzzFacePreFrame` -> `fuzzFaceClipFrame` -> `fuzzFaceToneFrame` -> `fuzzFaceLevelFrame` (Fuzz Face style: pre-gain, strong asym soft clip, tone LPF, level+safety) |

The pipeline order in `fxPipeline` is:
`cleanBoost* -> tubeScreamer* -> metal* -> ds1* -> bigMuff* -> fuzzFace*`,
with `distortionPedalsPipe = fuzzFaceLevelPipe`. Each pedal section
is independently enabled, so off-pedals never touch the sample.

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

## Amp Simulator section

Driven by the existing `axi_gpio_amp` and `axi_gpio_amp_tone` GPIOs:
`input_gain` / `master` / `presence` / `resonance` plus B/M/T /
`character`. Enable remains `gate_control.ctrlA` bit 6. The Amp/Cab and
audio-analysis voicing passes changed constants inside the existing
stages only; no register stage, GPIO, or `topEntity` port was added.

| Stage | What it does |
| --- | --- |
| `ampHighpassFrame` | First-order HPF using the existing input/output state registers. Feedback coefficient is now `253/256`, a little tighter than the prior `254/256` path. |
| `ampDriveMultiplyFrame` / `ampDriveBoostFrame` | Q7-style preamp gain. The ceiling is now ~19x rather than the prior ~21x so Amp-only and post-pedal use do not create as much line-direct fizz. |
| `ampWaveshapeFrame` | Character-controlled asymmetric soft clip with lower hand-rolled knees. Higher `character` lowers the knees and increases asymmetry. |
| `ampPreLowpassFrame` | One-pole post-clip smoothing. Alpha range is darker (`128..191`) while high character still keeps some edge. |
| `ampSecondStageMultiplyFrame` / `ampSecondStageFrame` | Second gain/clip stage. Gain now depends more on `character` and less on raw input gain. |
| `ampToneFilterFrame` -> `ampToneMixFrame` | Existing three-band B/M/T tone-stack approximation. Treble uses `ampTrebleGain`, an internally capped version of `ampToneGain`, so treble at 100 no longer restores as much >5 kHz energy. |
| `ampPowerFrame` | `softClipK 3_500_000` power-stage safety instead of the wider default `softClip`. |
| `ampResPresenceProductsFrame` / `ampResPresenceMixFrame` | Resonance and presence are internally capped harder (`resonance * 3/4`, `presence * 5/8`) and mixed through `softClipK 3_500_000`. |
| `ampMasterFrame` | Master multiply followed by `softClipK 3_300_000` so MASTER cannot slam the Cab/EQ/Reverb stages into hard clip. |

## Cab IR section

Driven by the existing `axi_gpio_cab` GPIO. `ctrlA = mix`,
`ctrlB = level`, `ctrlC = model`, `ctrlD = air`; those byte meanings
are unchanged. Enable remains `gate_control.ctrlA` bit 7. The live
stage is still the existing 4-tap FIR split over `cabProductsFrame`,
`cabIrFrame`, and `cabLevelMixFrame`; no long IR loader and no extra
AXI GPIO were added.

The audio-analysis pass rebuilt the 4-tap coefficient table again:

| Model | Target | DSP shape |
| --- | --- | --- |
| 0 | 1x12 open back style | Lower total body, lighter low end, enough mid/air for clean and crunch, but less direct tap than the previous table. |
| 1 | 2x12 combo style | Balanced response for Tube Screamer Lead / RAT Rhythm; highs are rolled off more than model 0 but not as dark as model 2. |
| 2 | 4x12 closed back style | Lowest direct tap and strongest delayed-body taps for DS-1 / Metal / Big Muff / Fuzz Face; strongest high-fizz damping. |

`air` still selects three variants per model, but the brightest row
only restores a capped amount of direct tap. `air=100` therefore adds
presence without reverting to raw line-direct tone. `mix=0` remains
dry/raw and `mix=100` remains fully cabinet-shaped; `level` still runs
through the existing `softClip` in the post-Cab mix stage. The May 7
analysis build briefly tried a lower `softClipK 3_400_000` knee here,
but that path pushed WNS outside the deployable range; the deployed
voicing keeps the timing-friendly `softClip` and puts the audible
high-frequency roll-off in the Cab tap table instead.

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

## Chain preset orchestration (Python only)

`audio_lab_pynq.effect_presets.CHAIN_PRESETS` defines named voicings
that combine every section into one state. They are applied through
`AudioLabOverlay.apply_chain_preset(name)` which orchestrates the
existing per-section setters (`set_compressor_settings`,
`set_noise_suppressor_settings`, `set_distortion_pedal` /
`set_distortion_settings`, `set_guitar_effects`). No new GPIO, no
new Clash stage -- the DSP pipeline is unchanged. See
[`DECISIONS.md`](DECISIONS.md) D15.

Per-preset safety contract (enforced by `tests/test_overlay_controls.py`):

- Compressor `makeup` stays in 45..60.
- Distortion `level` is capped at 35.
- `Safe Bypass` has every section `enabled=False` and `reverb.mix=0`.

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
