# BOSS BD-2 Blues Driver — circuit research for the FPGA DSP model

Research date: 2026-05-24. Branch: `feature/improve-bd2-overdrive-model`.

This document is the source-of-truth research note for the BD-2 Overdrive
model (`OVERDRIVE_MODELS` index 2, label `BOSS / BD-2`). It is the prerequisite
for any coefficient or DSP-stage change to the BD-2 path. It does NOT cover
TS9, OD-1, Jan Ray, OCD, or Centaur — those models stay byte-exact.

The goal is to ground every BD-2 DSP coefficient in something documented in the
real-pedal literature, not in "sounds nicer when I turn it up".

## Sources

| # | Source | URL | Credibility | What we used it for |
| - | ------ | --- | ----------- | ------------------- |
| 1 | Analog Is Not Dead — Circuit Analysis: the Boss BD2 | https://www.analogisnotdead.com/article25/circuit-analysis-the-boss-bd2 | High. Stage-by-stage trace with named designators (J2/J3/Q1, R8/R9/C4/C5, D7-D10, R32/R33, etc.). | Stage topology, feedback network shape, clipping order, JFET discrete-op-amp construction, gyrator post-bass-boost. |
| 2 | Guitar Pedals Visualized — Boss BD-2w | https://guitarpedalsvisualized.wordpress.com/2022/03/08/boss-bd-2w/ | High. Frequency-response graphs for tone min / 12:00 / max with Hz axes. | Tone-control response curve (the only single-knob behaviour we have measured data for). |
| 3 | Aion FX — Sapphire Amp Overdrive (BD-2 clone) project | https://aionfx.com/project/sapphire-amp-overdrive/ | High. Aion FX repackages many classic circuits and their notes track the original schematic. | OD-2 lineage of the discrete-op-amp stage, "fixed Fender tonestack + bass boost" framing, "fizzy/splatty at high gain" known limitation. |
| 4 | PedalPCB Forum — "This Week on the Breadboard: Blues Driver BD-2 & BD-2w part 1", Chuck D. Bones | https://forum.pedalpcb.com/threads/this-week-on-the-breadboard-blues-driver-bd-2-bd-2w-part-1.7390/ | High. Measurement-based — author breadboarded the circuit and probed each stage. | Per-stage gain (40 dB each), per-stage bandwidth (first stage 700 Hz HPF + 2..3 kHz peak; second stage flat 100 Hz..6 kHz), gyrator 32 H synth at 120 Hz, **finding that the D7-D10 ground-clippers are effectively inactive in stock BD-2 (impedance + leakage)** — i.e. most of the distortion comes from op-amp rail saturation, not the diodes. |
| 5 | Premier Guitar — Boss BD-2 Mods | https://www.premierguitar.com/gear/boss-bd-2-mods | Medium. Mod-focused; the listed mods reveal which components dominate each behaviour. | Confirmation that C22/R31 dominate the ~700 Hz pre-clip HPF, that R34/C24 add another ~72 Hz bass boost in the second stage, and that the C17/R25/C19 network removes harmonics above ~5 kHz (the post-clip LPF). |

Forum / mod / Tumblr / Reddit posts encountered during the search but not
cited above are explicitly treated as anecdotal and were not used to set any
coefficient.

## BD-2 stage block diagram

Synthesised from sources [1], [3], [4]:

```
guitar
  v
[ JFET input buffer, unity gain ]            -- ~Hz HPF from input cap
  v
[ Discrete op-amp gain stage #1 ]            -- J2/J3 + Q1, max gain ~40 dB
   feedback ~ gain pot gang #1 + R8/R9/C4/C5
   bandwidth: HPF ~700 Hz (C4 R5 / C22 R31),
              peak 2..3 kHz, then rolls off
  v
[ Fender-style fixed tonestack ]             -- treble=0, mid=6, bass=10
   modest pre-clip EQ that tightens the
   low-mid before the second stage
  v
[ Diode clipper, D7-D10 to ground ]          -- two pairs, BUT Chuck D. Bones
   reports the impedance + diode leakage     measured these as essentially
                                             inactive at stock impedances
  v
[ Discrete op-amp gain stage #2 ]            -- same topology, gang #2
   bandwidth: flat 100 Hz..6 kHz
   gain ~40 dB, this is where rail
   clipping (~8 V / 0 V single supply)
   does most of the audible distortion
  v
[ Post-clip LPF, C17 R25 C19 ]               -- ~5 kHz, removes high harmonics
                                             before the tone control sees them
  v
[ Single-knob tone control + master vol ]    -- Fender-style:
                                             tone min: 750 Hz mid focus
                                             tone 12:  3 dB @ 100 Hz, flat by 500 Hz
                                             tone max: rising treble boost
  v
[ Gyrator bass boost ]                       -- C21 + C22 synth 32 H,
                                             ~+6 dB bump at 100..120 Hz
  v
[ JFET output buffer ]
  v
amp / next pedal
```

## BD-2 personality — what defines "BD-2-ness"

These are the load-bearing characteristics the DSP model must approximate.
Every coefficient choice in `Overdrive.hs` for model `2` should be
traceable back to one of these:

1. **Two cascaded gain stages, both contributing to the distortion shape.**
   ~40 dB available per stage, ganged. At low GAIN both stages stay in
   their linear region. At mid GAIN the second stage begins to clip on
   loud picking attacks. At high GAIN both stages saturate, so the
   distortion is the cascade of two soft-knee non-linearities, not one
   hard clip. This is what produces the "multi-stage" feel and is the
   single biggest sonic differentiator from the TS9 (which is a single
   op-amp + diodes).

2. **2..3 kHz presence peak from the first stage.**
   Source [4] explicitly measures peak response between 2 and 3 kHz on
   the first stage. This is what gives the BD-2 its "bright but
   articulate" mid-treble — coordinated with the ~700 Hz pre-clip HPF,
   it ensures pick-attack transients survive the cascade.

3. **Wide bandwidth post-clip.**
   The second stage is flat 100 Hz..6 kHz. Unlike a TS9 which scoops
   bass and sharply peaks at 700 Hz, the BD-2 keeps low-mids and
   upper-mids alive. This is the BD-2's "wide" feel.

4. **~700 Hz pre-clip HPF that tightens the low-mid before clipping.**
   Without this, the second stage would muddy. The ~700 Hz corner is
   the load-bearing reason BD-2 doesn't smear when you palm-mute or
   play big chords.

5. **~5 kHz post-clip LPF that controls but does not kill fizz.**
   This is the BD-2's anti-ice-pick element. It rolls off harmonics
   above ~5 kHz but lets the 2..5 kHz presence through, which is why
   the BD-2 sounds bright but rarely painful at sane tone settings.

6. **Touch response from cascaded variable-gain stages.**
   Because the gain pot controls feedback (not a fixed pre-multiplier),
   pulling guitar volume back genuinely shrinks the available gain in
   both stages simultaneously, so the cascade collapses back toward
   linear. "Clean-up on volume rolloff" is a real circuit property, not
   marketing.

7. **Asymmetric op-amp rail clipping.**
   The discrete op-amps run from a single supply (~9 V split as ~8/0
   via the R32/R33 divider with C28 reference). When the signal swings
   above the upper rail vs below the lower rail, it sees different
   headroom, so the rail saturation is asymmetric. This is the source
   of BD-2 even-harmonic content, not the diodes.

8. **Tone-knob behaviour: low/mid focus at min, flat at noon, rising
   treble at max.** Per [2], a single-knob Fender-style tonestack:
   - tone < 50: smooth, mid-focused (~750 Hz centred), useful for
     taming a bright amp.
   - tone ~ 50: ~flat with -3 dB at 100 Hz, settling flat by 500 Hz.
   - tone > 50: rising-with-frequency treble boost, can become
     ice-picky on a bright amp.

9. **Known weakness: high-gain "fizzy / splatty" decay** ([3]). The
   second stage saturates hard, the gyrator boost re-adds 100 Hz bass
   AFTER the clip, and the post-clip LPF rolls off above 5 kHz; the
   net effect on decaying notes can be a slightly artificial-sounding
   tail. The DSP model should not try to "fix" this — it is part of
   the BD-2 personality. But the DSP model should also not amplify it.

## What we explicitly do NOT model

- **JFET / discrete-op-amp transistor-level behaviour.** This pedal
  uses J2/J3/Q1 differential pairs; modelling each transistor's
  drain-source curve at sample rate is wildly out of scope for this
  FPGA. We model the cascaded soft-clip behaviour, not the
  device-level non-linearity.
- **Diode clippers D7-D10.** Source [4]'s breadboard measurement
  reports these are essentially inactive in stock BD-2 at the local
  impedance, so adding a third clip stage to model them is wrong —
  it would push the BD-2 model toward a TS9 / RAT character that the
  real pedal does not have.
- **Gyrator-based 100..120 Hz post-bump.** We can replicate the
  perceived "bass body" with a simpler post-clip low-shelf if it's
  audibly missing. Modelling the gyrator inductance synthesis on a
  signed-25 fixed-point integer path costs more than the audible
  benefit. Defer.
- **Power supply capacitance multiplier (Q5, C25..C28).** Irrelevant
  to the audio path.
- **The Waza Craft "C" mode tonestack changes** described in [2].
  The model is the original BD-2, not the BD-2w.

## DSP-side blueprint (what the implementation needs to add for model 2)

This is the structural intent; the exact constants and helper choices
will be decided when reading the existing `Overdrive.hs` helpers
(`asymSoftClip`, `softClipK`, `onePoleU8`, `mulU8/U12`, `satShift*`).

For BD-2 (`overdriveModel == 2`) only:

1. **Pre-clip HPF / low-mid tighten.**
   One-pole high-pass at ~700 Hz, only applied when the model is BD-2.
   Other models pass through unchanged. This emulates the
   C4/R5 + C22/R31 pre-stage HPF.

2. **Pre-clip upper-mid emphasis (~2.5 kHz).**
   A light per-sample shelf or one-pole peak around 2..3 kHz. Cheapest
   FPGA realisation: scale the pre-clip signal by `(1 + (x - lpf(x)) * k)`
   where `lpf` is a slow one-pole — this is effectively the same shape
   the discrete-op-amp first stage produces. Only used when BD-2.

3. **First soft-clip stage (mild, asymmetric).**
   Re-use the existing `asymSoftClip` with **softer** knees than the
   second stage. This models the first-stage op-amp beginning to
   approach the rails on hot picking but not yet rail-clipping on
   mid-level signal. Other models do not get this first stage.

4. **Second soft-clip stage (main saturation, gain-dependent).**
   Re-use the existing `asymSoftClip` for the bulk of the distortion,
   with the same `odKneeP` / `odKneeN` table entries we already have
   for BD-2 (3_000_000 / 2_700_000). Optionally make the knees
   tighten slightly with `ctrlC` (drive) so high-GAIN settings move
   the model toward "fuzzy / splatty" rather than "transparent" —
   this matches the documented high-gain limitation. Cap the
   tightening so we never go below TS9 territory (else BD-2 starts
   sounding like a TS9 and the personality is lost).

5. **Post-clip LPF (~5 kHz fizz guard).**
   One-pole low-pass at ~5 kHz, BD-2 only. Other models keep the
   current behaviour. This is the BD-2's anti-ice-pick element from
   the C17/R25/C19 network and should be on **before** the tone
   knob has the chance to boost the treble.

6. **Tone control shaping is left to the existing tone stage.**
   The existing wet/dry blend in `overdriveToneMultiplyFrame` +
   `overdriveToneBlendFrame` is generic across models. The fizz guard
   above sits in front of it so the BD-2 tone-up direction still
   sounds bright but cannot push 8 kHz+ harmonics that the real pedal
   never has.

7. **Output safety / level.** Keep the existing `odSafetyKnee` 2 = 3_400_000
   and `level` byte path. No change to the per-model safety constant —
   that was set in D45/D46 specifically to give the BD-2 more
   headroom than TS9/OD-1, which still matches the wide-bandwidth
   character.

### Constraint: do not add a new pipeline stage

Sources [1]-[5] make it clear the BD-2 has at least 4 nonlinear
elements (first op-amp + tonestack + diodes + second op-amp + post-LPF
+ tone), but the FPGA pipeline has 6 stages of which 4 already do the
overdrive work for every model. The lesson from D58 / D59 / D60 is
that adding register stages or DSP multipliers triggers Vivado P&R
shifts that can introduce bypass-path noise the macroscopic timing
summary does not catch.

So the BD-2 work must:

- Stay inside the existing 6-stage Overdrive pipeline.
- Not add new register stages.
- Not add new DSP48E1 multipliers (the existing `mulU8` / `mulU12`
  in each stage stay; new constants are fine, new multiplies are
  not).
- The model-conditional logic must compile down to a small constant
  LUT mux on the existing arithmetic operands — the same cheap
  pattern Vivado already routes well, and the opposite of the
  rejected May-4 `model_select` shape with 8 parallel non-linear
  paths behind a mux.

If the BD-2 work needs feedback state (a one-pole filter `prev`
sample), that state is a single `Sample` register and lives next to
the existing `odTonePrev` register in `Pipeline.hs`. One extra Sample
register is acceptable; a new pipeline stage is not.

## Coefficient first-cut proposals (subject to review against existing helpers)

These are starting values, deliberately conservative. They will be
finalised when we read the existing `asymSoftClip` / `onePoleU8`
implementations and confirm Q-format.

| Element | Proposed value | Why |
| --- | --- | --- |
| Pre-clip HPF alpha (~700 Hz @ 48 kHz) | ≈ 235 / 255 (≈ 0.92) | Standard one-pole HPF for 700 Hz / 48 kHz |
| Pre-clip upper-mid emphasis gain | small (e.g. +25% of HF residual) | Mild — too much and BD-2 becomes ice-picky |
| First-stage softer knees (asymSoftClip) | `kneeP_first = 3_400_000`, `kneeN_first = 3_100_000` | Above the second-stage knees so the first stage only barely engages at mid GAIN |
| Second-stage knees (existing) | `kneeP = 3_000_000`, `kneeN = 2_700_000` | Keep — these are already in `odKneeP/odKneeN` for model 2 |
| Optional knee tightening with drive | up to -15% at `ctrlC=255` | Matches "fizzy at high gain", capped so BD-2 doesn't become TS9 |
| Post-clip LPF alpha (~5 kHz @ 48 kHz) | ≈ 90 / 255 (≈ 0.35 → corner ~5 kHz) | Matches the C17/R25/C19 network behaviour |
| Output safety knee (existing) | `safetyKnee = 3_400_000` | Keep — D45 value, fine. |

Every BD-2 constant added must be in its own per-model lookup
function (`bd2PreHpAlpha`, `bd2PostLpAlpha`, `bd2FirstKneeP`,
`bd2FirstKneeN`, etc.) so the other models' behaviour is byte-exact
unchanged. Model 0/1/3/4/5 still go through their existing
constants only.

## Validation plan (before committing the DSP change)

After implementation + Clash regen + Vivado build + deploy:

1. **TS9 / OD-1 / Centaur / Jan Ray / OCD bypass smoke.** All five
   non-BD-2 models must still pass the standard `FRAME_COUNT delta ~
   144000`, `CLIP_COUNT delta = 0` mode-2 safe-clean test, AND must
   still sound audibly identical to their pre-change selves (the
   user must A/B them by ear on bench). If any of the other five
   models change audibly, the BD-2 model leak is a bug and the
   build is rejected.

2. **BD-2 gain sweep.** GAIN 20 / 50 / 80 with tone 50 must produce
   audibly different distortion textures: edge-of-breakup, full
   BD-2 overdrive, rough/fuzzy. Bypass switching must not pop.

3. **BD-2 tone sweep.** Tone 30 / 50 / 70 at GAIN 50 must show
   smooth-dark / flat / rising-bright behaviour respectively, with
   no ice-pick above 8 kHz.

4. **Macroscopic numbers do not gate audio.** Per the D58 / D59 / D60
   lesson, `CLIP_COUNT = 0` and `WNS within +/- 0.5 ns of D58.2` are
   **necessary but NOT sufficient** for accepting the build. The
   bench ear on safe-bypass + the BD-2 audition is the dispositive
   sensor.
