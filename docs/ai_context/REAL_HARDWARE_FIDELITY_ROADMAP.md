# Real-hardware fidelity roadmap

Status: **R0a (Python taper, D80) + R3 first biquad (D81) done.** D80 added
`audio_lab_pynq/knob_tapers.py`, updated live GUI/encoder/preset apply paths,
and retuned the preset knob positions (Python-only). **D81 then landed the
first R3 resonant biquad: the Tube Screamer ~720 Hz mid hump** (Clash, built /
deployed / bench-accepted; new bitstream baseline `3a79745f`, island WNS
-0.193 ns). See the R3 section below. Full R0 reference capture is still
pending and remains the recommended calibration step before further DSP
retuning.

This document answers the practical question: how do we move AudioLab closer
to real pedals, amps, and cabinets **without** violating the current project
constraints? Use it before editing `LowPassFir.hs`, `AudioLab.Effects.*`, or
the runtime presets. Detailed per-effect gaps live in
`MODEL_REALISM_GAP_ANALYSIS.md`; concrete implementation recipes live in
`MODEL_REALISM_IMPLEMENTATION_GUIDE.md`.

## Current baseline and boundary

- Current accepted bitstream baseline is **D79**: bit md5
  `f0cb0276f27187d72476a2e773dd9a6e`, hwh md5
  `5fa0b84e9fe852c68629c651f94e4a9d`; island WNS `-0.496 ns`, 100 MHz
  audio fabric `+0.532 ns / 0 fail`.
- The DSP runs mono at 48 kHz inside the **50 MHz DSP island**. DS-1 CARRY4
  arithmetic is the perennial critical path.
- `block_design.tcl` remains off-limits. New runtime control must use the
  existing GPIO topology unless the user explicitly approves a hardware
  topology phase.
- "Closer to real hardware" means **perceptual and behavioural similarity**:
  transfer curve, tone shape, dynamic response, speaker rolloff, control
  taper, and level behaviour. It does **not** mean copying schematic-derived
  coefficient tables, commercial IRs of unknown license, GPL DSP source, or
  exact proprietary models.
- Every Clash/DSP change still requires a fresh bit/hwh build, timing summary,
  5-site deploy, and bench A/B. Static timing is necessary but not sufficient
  after the D58-D64 / D74 / D78 audible-regression history.

## First principle: measure before retuning

The next realism pass should start with a repeatable reference-capture method.
Without this, each coefficient change turns into a subjective one-off bench
session.

Recommended capture rig:

1. Record a dry DI phrase once: single notes, chords, palm mutes, low/high
   strings, soft/hard pick, and sustained decay. Keep peak around `-12 dBFS`
   at the Pmod I2S2 input.
2. Reamp the same DI into the real pedal / amp / cab reference, then capture
   its output at line level. Keep the direct loopback jumper off and preserve
   the same gain staging for every take.
3. Run the same DI through AudioLab in Pmod mode 2 with matching knob names
   and nominal settings.
4. Compare both objective and audible results:
   - RMS / peak / crest factor before and after each stage.
   - Harmonic series for 100 Hz, 440 Hz, and 1 kHz sine inputs at low/mid/high
     drive.
   - Alias spur check: non-harmonic bins above the expected harmonic series.
   - Chirp or log-sweep magnitude for tone stacks and cabinet models.
   - Decay envelope for compressor, noise suppressor, amp sag, and fuzz gating.
5. Bench-listen the same captures through the normal monitor path. The final
   gate is still the ear: all_off clean, no bitcrusher, touched models closer,
   untouched models not worse.

This can reuse the existing recording-analysis style in
`scripts/analyze_effect_recordings.py`. Any new analysis script should report
compact numeric deltas rather than trying to become the source of truth for
tone decisions.

## Realism levers, ranked by usefulness

| Lever | What it makes more real | Implementation shape | GPIO impact | Risk |
| --- | --- | --- | --- | --- |
| Capture-calibrated presets and knob tapers | Knobs feel like pedals; reference settings land near expected sounds | Python presets / mapping only; no bit rebuild | none | low |
| Per-model transfer curve shape | Diode, MOSFET, op-amp, Ge, and tube clips stop sounding like the same clip with different knees | Fixed-shift clip families, asymmetric knees, model-local safety knees | none | low-medium |
| Dynamic bias / sag | Fuzz Face cleanup, amp compression, pick sensitivity | Envelope follower -> modulate existing knees or gain | none | medium |
| Resonant tone stacks | TS hump, Big Muff notch, DS-1 / Metal scoop, Fender / Vox / Marshall identity | Shared biquad or two one-pole sections with fixed coefficient sets | none if replacing existing tone controls | medium-high |
| Generated short cab IR | Real speaker rolloff, presence peak, cone breakup, model separation | BRAM history + time-multiplexed MAC; generated in-project IRs | none | high structural |
| Selective oversampling | Removes digital fizz from high-gain nonlinearities | 2x first, only around RAT / DS-1 / Metal / high-gain Amp clips | none | highest |

## Recommended phase order

### R0: reference capture and control calibration

Do this first because it does not touch the bitstream.

Progress: **D80 completed the first no-bitstream control pass**. Gain/drive
knobs now use a conservative audio taper in GUI / encoder / chain-preset
paths, tone knobs use a mild centre-preserving taper, and preset DRIVE /
Amp GAIN positions were adjusted so the tapered hardware writes stay near the
previous practical voicings. Full reference capture is still pending and should
be the next calibration step before more DSP retuning.

- Build a small capture matrix for the real references and the current D79
  AudioLab models. At minimum: TS9, DS-1, Big Muff, Fuzz Face, one clean amp,
  one high-gain amp, and all three Cab models.
- Normalize comparison by input level and output loudness. A louder model can
  sound "better" while being less accurate.
- Record control points at 0 / 25 / 50 / 75 / 100 for DRIVE, TONE, LEVEL,
  Amp GAIN, PRES, RES, Cab AIR, Wah Q, and Compressor RESPONSE.
- Document where the GUI percent should map nonlinearly. Many real knobs are
  audio/log taper; AudioLab currently treats most knobs as linear percent.
- Result: preset and taper adjustments, plus a clear target list for R1/R2.

Acceptance: no source audio regression; docs include enough capture detail to
repeat the run later.

### R1: no-topology tone closer pass

Use only existing stages and constant tables. This is the safest bitstream
class and follows the accepted D62/D66/D67/D68 pattern.

- Keep edits single-model or single-family when possible.
- Prefer fixed constants, compile-time shifts, and existing helper choices.
- Avoid adding a new feedback register, helper cascade, or DSP48 multiplier in
  this phase.
- Good candidates:
  - TS9 / Tube Screamer: stronger low cut and darker post-filter target.
  - Big Muff: darken high fizz while preserving sustain.
  - Amp clean models: reduce hidden clipping at low gain for JC-120 / Twin.
  - Cab model separation: one more 4-tap coefficient retune if capture shows a
    clear target.

Acceptance: D79 all_off remains clean; touched model improves against the R0
capture; unrelated models are A/B checked.

### R2: dynamic behaviour without new controls

This is the best next "real hardware" improvement after D79 because it adds
what static waveshapers cannot: level-dependent response.

Candidate implementations:

- **Fuzz Face cleanup / bias drift**: derive a slow envelope from the input
  level and modulate clip centre or knee asymmetry. Soft playing should clean
  up; hard picking should sputter or compress more. Reuse the envelope pattern
  from Compressor / Noise Suppressor.
- **Amp sag**: derive a slower envelope after the second gain stage and reduce
  power/master gain slightly on loud passages. It should compress chords and
  recover after the transient, not pump.
- **BD-2 / OD pick dynamics**: make the safety knee or post-tilt respond
  lightly to input level so soft notes remain clearer than hard notes.

Rules:

- Add at most one new envelope path per phase.
- Keep modulation bounded and musically subtle. A real-feeling dynamic model is
  usually less obvious than a bad one.
- Reset the envelope on effect bypass so bypass remains bit-exact.

Acceptance: soft/hard pick A/B shows different response; no zipper, pumping,
or stuck bias; bypass is unchanged.

### R3: resonant tone-stack phase

This targets the "samey" model problem directly.

Progress: **D81 + D82 landed the first two resonant biquads.** D81 = the Tube
Screamer ~720 Hz mid hump (pre-clip peaking biquad, +6 dB, island WNS -0.193 ns).
**D82 = the Big Muff ~700 Hz mid-scoop notch** (post-clip peaking biquad with
negative gain, -10 dB dip; island WNS -0.534 ns). Both hand-designed Q14
targets via `mulS16`/`satShift14`, pipeline-level `x1/x2/y1/y2` state, bit-exact
bypass, no GPIO/API change; built / deployed / bench-accepted. **Key D82 lesson:
an IIR biquad's feedback loop cannot be naively pipelined** (it changes the
transfer function); when the single-stage 5-multiply form pressured the DS-1
P&R (-0.659 ns), the fix was to precompute the FEEDFORWARD sum
(`b0*x+b1*x1+b2*x2`) one stage earlier and close the loop in the recursive stage
with only `-a1*y1-a2*y2` (recovered to -0.534 ns, biquad off the critical set).
**D83 started the amp-stack family work**: ONE shared peaking biquad in the amp
tone path with coefficients muxed by `ampModelIdxF`
(`ampScoopFeedforwardCoeffs`/`ampScoopFeedbackCoeffs`), reusing the D82 split.
This phase filled the Fender blackface mid scoop (JC-120 + Twin, ~400 Hz,
-5 dB); models 2-5 use flat coeffs (exact unity = byte-identical). Island WNS
-0.381 ns -- the +5 DSP did NOT bust the budget (it actually beat D82's -0.534;
the per-biquad cost estimate is P&R-variable, not a fixed -0.3 ns).
**D84 filled AC30 chime (idx 2, +4 dB @ 2200 Hz) and JCM800 mid (idx 4, +4 dB
@ 650 Hz) into the same amp-scoop mux** (coefficient-only; Rockerverb/TriAmp
stay flat). Island WNS -0.472 ns, bench-accepted. **item 3 (resonant tone
stacks) is now substantially complete** -- TS hump, Big Muff notch, and the
Fender/Vox/Marshall amp families all have their signature resonant shapes.
Remaining realism work: **item 5b** (Fuzz/amp dynamic bias-sag, R2 -- the next
phase), then item 1 (cab IR) and item 2 (oversampling). Note the island sits at
~-0.47 ns after four biquads; item 1/2 (heavier DSP) need a timing-headroom
plan first.

Recommended start:

1. Implement one shared, fixed-coefficient biquad helper or a cheaper
   two-one-pole resonant approximation.
2. Use it first for a single high-value target:
   - Tube Screamer mid hump, or
   - Big Muff mid notch, or
   - Fender / Vox / Marshall amp-stack family.
3. Reuse the existing TONE / BASS / MID / TREB controls. Do not add GPIO.

Important constraint: do not instantiate a separate biquad per model. Mux
coefficients into one shared structure inside the relevant stage. Adding many
parallel multipliers repeats the D58 lesson.

Acceptance: log-sweep shows the intended hump/notch/scoop; user bench confirms
the model identity is clearer; DSP count and WNS stay within the D79/D78/D75
acceptance band.

### R4: generated short cabinet IR

Cab realism is the biggest remaining audible gap. The current Cab is stronger
than a bare 4-tap FIR, but its frequency response is still fundamentally 4 taps.

Recommended design:

- Generate in-project IRs from hand-drawn magnitude targets:
  - 1x12 open: loose low end, smoother mids, more air.
  - 2x12 British: mid-forward, Celestion-like presence peak.
  - 4x12 closed: low-mid thump, presence peak, sharp high rolloff.
- Use 128 taps first, not 256. Keep latency acceptable and BRAM pressure low.
- Implement a time-multiplexed MAC: one DSP48 walks the tap list during the
  audio-sample period instead of trying to build a 128-MAC combinational FIR.
- MODEL selects the IR set. AIR can remain a high-shelf or crossfade a brighter
  generated IR variant.

This is structural because the Cab stage stops being a simple one-cycle
`Frame -> Frame` stage. It needs its own phase, handshake review, and careful
interaction with the D75 `acceptReady = readyOut` rule.

Acceptance: impulse-in reproduces the generated IR; chirp response matches the
target; high-gain fizz is reduced more than the 4-tap Cab; no new bypass noise.

### R5: selective 2x oversampling for worst clippers

Oversampling is the most direct fix for digital fizz, but it is also the
riskiest in this design.

Start only with 2x and only one target, in this order:

1. RAT or DS-1 clip stage.
2. Metal clip stage.
3. High-gain Amp waveshaper.

Do not oversample the whole chain. The practical design is a sequenced local
sub-block: interpolate one extra sub-sample, clip both sub-samples, low-pass,
then decimate. Keep the anti-alias filter small. A "correct" oversampler that
adds a large FIR and several clip evaluations at once is unlikely to survive
the current island margin.

Acceptance: non-harmonic alias spurs fall on sine tests; high-gain bench tone
is less metallic; timing and bypass remain acceptable.

## Hardware-front-end realism

Some "DSP realism" complaints are actually input-chain issues.

- Guitar pickups want Hi-Z loading. The Pmod I2S2 line input is not a guitar
  pickup input. Use a proper buffer / pedal / reamp / DI path before judging
  model fidelity from a passive guitar.
- Keep levels repeatable. A real pedal driven 12 dB hotter will not match an
  AudioLab model driven at nominal line level.
- Keep ADAU1761 HPF health checks in place even though Pmod I2S2 is the active
  external path; the codec remains useful debug visibility.
- Do not add "realistic hiss" globally. Noise is useful only if it is explicitly
  tied to a model and can be bypassed; all_off must remain clean.

## Things to avoid

- Do not copy commercial IRs or GPL code into this WTFPL project.
- Do not copy schematic coefficient tables directly. Design target curves and
  generate our own constants.
- Do not revive C++ DSP prototypes.
- Do not make global multi-model retunes and deploy them as one unreviewable
  bitstream. The history says small, isolated phases are safer.
- Do not use a headline WNS improvement as proof of audio health.
- Do not "simplify" parallel arithmetic into a serial LERP without measuring;
  D79 proved that the serial form can be much worse on this island.

## Documentation outputs for each future phase

Every future "more real" phase should leave these artifacts:

- A short target note: reference behaviour, chosen approximation, and what is
  intentionally not modeled.
- Exact files touched and whether a bitstream rebuild is required.
- Timing summary: island WNS, audio fabric WNS/fail count, WHS/THS if recorded,
  bit/hwh md5.
- Bench matrix: all_off, bypass of touched effect, touched model settings,
  adjacent/untouched models, and any rollback result.
- A decision entry in `DECISIONS.md` only after the phase is actually accepted
  or rejected on the bench.
