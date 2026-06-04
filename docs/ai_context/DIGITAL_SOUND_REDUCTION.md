# Reducing the "digital" sound — causes and methods, ranked

The user's standing complaint: **the effects sound "digital" overall** even
after the D81-D90 realism passes. This doc names the concrete causes, ranks
them by how much they contribute to that perception, and gives the method,
cost, and current status of each. Read with `MODEL_REALISM_GAP_ANALYSIS.md`
(per-model gaps), `MODEL_REALISM_IMPLEMENTATION_GUIDE.md` (HOW),
`REAL_HARDWARE_FIDELITY_ROADMAP.md` (phase strategy), and
`DSP_ISLAND_CLOCK_DESIGN.md` (the timing budget that gates the big items).

## What "digital" actually is here

"Digital" is not one thing. In this fixed-point 48 kHz FPGA chain it is mostly:

1. **Aliasing** — inharmonic fold-back from clipping above Nyquist. The
   metallic / fizzy / harsh edge. The single most "digital" artifact.
2. **An artificial cabinet** — a 4-tap pseudo-IR cannot reproduce the comb
   filtering, cone-breakup peaks, and sharp rolloff that make a real speaker
   "in the room". A thin/boxy/synthetic cab makes the whole patch sound fake.
3. **Static, memoryless, samey processing** — real analog is dynamic,
   frequency-dependent, and each model is structurally distinct; identical
   clip curves + one-pole tilts sound sterile and "plug-in-like".
4. **Front-end mismatch** — a passive guitar into a line-level input (not a
   Hi-Z guitar input) loses pickup loading and sounds thin / brittle before
   any DSP runs.

## What is already done (so we don't re-litigate it)

- 4x oversampling of the hard/cascade clippers **Metal (D88), RAT (D89), Big
  Muff (D90)** -> ~-12 dB inharmonic fizz on those three.
- Resonant tone-stack biquads: TS hump (D81), Big Muff notch (D82),
  Fender/Vox/Marshall amp stacks (D83/D84).
- Dynamic behaviour: Fuzz Face level-dependent bias (D85), power-amp sag (D86).
- Cab speaker-rolloff FIR step A (D87) — sharper >5 kHz rolloff, but the cab is
  still fundamentally a 4-tap response.
- Per-model resonant tone biquads extended to the **dedicated Overdrive** stage
  (D92): TS9 +6 dB @ 720 Hz, BD-2 +3 dB @ 1500 Hz (item 5 below, partly done).
  D92 also gave JC-120 a true clean channel (clip bypass), refined the Klon
  wet/clean blend, and deepened AC30 class-A sag.
- The DSP island was lowered to **40 MHz (D89)** to fit the above. **It is no
  longer at the D90 -0.036 ns edge: after D92 the island measured WNS +0.155 ns
  / 0 fail and the whole design meets timing** (the +5-DSP OD biquad routed
  upstream of DS-1 and the JC-120 clean mux relieved idx-0 clip pressure). There
  is now a small positive margin, but **not enough for the big items below** (cab
  IR step B, amp oversampling) -- those still want the 33 MHz headroom phase.

## Ranked causes still contributing, with methods

### 1. The cabinet is still a 4-tap pseudo-IR  [BIGGEST]

- **Why it sounds digital.** Every amped patch ends in the cab. 4 taps (+ the
  D87 rolloff FIR + nonlinear speaker shaping) can tilt and rolloff but cannot
  make the dense comb-filtering, the ~1-4 kHz cone-breakup peaks, or the exact
  speaker rolloff that the ear reads as "a real cab in a room." This is almost
  certainly the dominant remaining "digital" tell.
- **Method.** Cab IR **step B**: a real **128-256-tap short IR** via a
  time-multiplexed MAC (one DSP walks the tap list across the ~833 island
  cycles per 48 kHz sample) + a circular input-history BRAM, per-model IR ROMs
  generated in-project from designed magnitude targets (license-safe, D7).
  See `MODEL_REALISM_IMPLEMENTATION_GUIDE.md` item 1 and
  `REAL_HARDWARE_FIDELITY_ROADMAP.md` R4.
- **Cost / risk.** High: it breaks the cab stage's 1-sample/cycle model -> a
  MAC sequencer + handshake gating that must respect the D75 `acceptReady`
  rule. Its own structural phase. **Needs island headroom first** (item 0).
- **Status.** Step A done (D87); step B not started. Highest realism-per-tell.

### 2. The Amp waveshapers are NOT oversampled  [BIG — in most patches]

- **Why.** `ampWaveshapeFrame` + `ampSecondStageFrame` are **two cascaded
  asymmetric soft clips** that run at 48 kHz, and the Amp Sim is on in almost
  every patch. Their aliasing is a broad, always-present "digital" layer that
  the Metal/RAT/Big Muff oversampling (distortion pedals only) never touched.
- **Method.** Apply the proven D88-D90 4x oversampler to the amp clip stages
  (reuse the `os4x*` helpers; soft-clip cascade variant like Big Muff's
  `bigMuffOsCascade`). Both stages can share one oversampled sub-block.
- **Cost / risk.** Medium-high DSP; **needs island headroom** (the amp clips
  are on the island, currently full at 40 MHz). The cascade-isolation lesson
  (D90: keep the cascade out of series with the FIR mul) applies directly.
- **Status.** Not started. Likely the 2nd-biggest single improvement, because
  the amp is in nearly every chain.

### 3. The remaining clips are NOT oversampled (Overdrive, DS-1, legacy dist, TS/Fuzz)  [MEDIUM]

- **Why.** `overdriveDriveClipFrame` (the dedicated OD), `ds1ClipFrame` (DS-1,
  deliberately excluded as the island critical path), the legacy distortion
  clip, and the soft TS/clean_boost/fuzz clips all still alias at 48 kHz.
- **Method.** Same 4x os4x oversampler, one clip at a time. DS-1 specifically
  needs the headroom phase first (it is the perennial critical path).
- **Cost / risk.** Medium; **headroom-gated**. Do high-gain/hard ones first
  (OD high-drive, DS-1) — they alias most.
- **Status.** Not started.

### 4. Mostly static / memoryless nonlinearities  [MEDIUM]

- **Why.** Real clipping interacts with reactive parts (bias drift, sag, Miller
  capacitance, frequency-dependent saturation). Most clips here are static.
- **Method.** Extend the D85/D86 envelope pattern (DSP-free) to more models:
  bias drift on the OD/DS-1 high-gain clips, frequency-dependent pre/de-emphasis
  around clips (treble distorts differently from bass), gentle program-dependent
  compression. One envelope per phase, bounded, reset-on-bypass.
- **Cost / risk.** Low-medium (envelopes are DSP-cheap, D85/D86 proved this).
- **Status.** Partially done (Fuzz bias, amp sag); easy incremental wins.

### 5. One-pole tone stacks where biquads belong  [MEDIUM, cosmetic]

- **Why.** Several tone controls are one-pole tilts that cannot make the
  resonant peaks/notches that give a model its identity -> "samey", flat.
- **Method.** Per-model muxed biquads inside the shared stages (the D81/D83/D84
  pattern). See `DEDICATED_STAGE_CANDIDATES.md` (TS9 Overdrive mid-hump, OCD
  honk, etc.).
- **Cost / risk.** Medium (DSP per biquad, but one shared biquad + coeff mux is
  bounded). Headroom-aware.
- **Status.** Partially done; **the dedicated Overdrive now has the shared
  per-model biquad (D92, TS9 + BD-2 filled, others flat)** -- remaining work is
  filling OCD honk / OD-1 / Jan Ray coefficients into the same mux (coefficient-
  only, ~0 extra DSP).

## Cheap headroom-free interims (ship before the 33 MHz phase)

Two low-cost moves that attack the same two facets (harshness, fizzy top)
*without* needing the island headroom phase, as a partial fix while the big
oversampling/cab items wait:

### A. Pre/de-emphasis around the Amp clips  [cheap anti-alias, no oversampler]

- **Idea.** Most clip aliasing comes from *high-frequency input content* folding
  back. Attenuate HF *into* the clipper (pre-emphasis cut), clip, then restore HF
  after (complementary de-emphasis). Fewer high harmonics are generated above
  Nyquist, so less folds back -- a fraction of the benefit of true 4x
  oversampling for a fraction of the cost (two one-pole filters per clip vs an
  upsampler + decimation FIR). NOT transparent (it reshapes the clip's harmonic
  balance), so it must be voiced, but it can be applied to the always-on amp
  clips *now*. The D87 cab FIR already darkens the top *when the cab is on*; this
  works at the clip itself and helps cab-off patches too.
- **Cost.** ~0 new DSP (one-pole `onePoleU8` filters reuse adders). Headroom-free.
- **Risk.** Voicing only; bit-exact bypass preserved by gating on the amp enable.

### B. Output "analog" HF shelf  [global de-fizz]

- **Idea.** Real analog gear is never brick-wall flat to 20 kHz; a gentle
  musical HF rolloff/shelf removes the sterile fizzy top that reads as digital.
  Add one mild high-shelf (or 2nd-order rolloff) on the final output (post-EQ /
  pre-reverb-out), always-on, subtle. A poor-man's stand-in until full
  oversampling + real cab land; helps every patch including cab-off.
- **Cost.** One biquad (~5 DSP) OR a one-pole shelf (~0 DSP) on the output.
- **Risk.** Low; keep it subtle so it does not dull genuinely bright patches.

### 6. Front-end: line input, not a Hi-Z guitar input  [MEDIUM — hardware, not DSP]

- **Why.** A passive guitar driving the Pmod I2S2 **line** input is loaded
  wrong: the pickup resonance and high end are altered before any DSP, so even
  a perfect model sounds thin/brittle = "digital". No DSP change fixes this.
- **Method.** Put a proper buffer / DI / pedal (Hi-Z, ~1 MΩ) in front, and keep
  input levels repeatable. Judge model fidelity only through a correct
  front-end. (Documented in the roadmap "Hardware-front-end realism".)
- **Status.** Operational guidance, not code.

### 7. Mono, no room / stereo  [LOW-MEDIUM, structural]

- **Why.** A bone-dry mono signal lacks the spatial cues of an amp in a room;
  it can read as flat/synthetic.
- **Method.** A subtle stereo cab (dual mic-position IRs) or a short
  early-reflection room on the cab output. Large structural change; defer.

### 8. Fixed-point quantization / truncation  [LOW — likely not the cause]

- **Why (and why minor).** The many `satShiftN` ops truncate (toward -inf),
  adding a sub-LSB DC bias and correlated quantization per stage. But the
  Sample is **24-bit**, so truncation sits near -144 dBFS -- almost certainly
  inaudible and NOT the source of the "digital" complaint. Mentioned only so it
  is not chased prematurely.
- **Method (if ever).** Round-to-nearest (add half-LSB before the shift) or
  TPDF dither at the final output. Cheap but very low expected payoff at 24-bit.

## Further / less-obvious methods (beyond the 8 above)

These attack the "digital" perception from angles the first 8 items do not. They
are mostly about *adding the analog imperfections that the ear expects* rather
than removing artifacts. Tagged by cost and whether they need the 33 MHz island
headroom phase.

### 9. Output-transformer emulation  [HIGH realism — D94 LF saturation + D96 HF droop]

- **Why it sounds digital without it.** A real tube amp's output transformer is a
  big part of "amp warmth": **low-frequency core saturation** (bass notes /
  power chords push the core and compress/round, adding low-order harmonics that
  a clean linear output never makes), a **gentle HF bandwidth limit**, a slight
  low-end resonance bump, and frequency-dependent phase. The chain currently
  goes clip -> tone -> cab with no transformer stage, so it misses this entire
  layer of "bloom".
- **Method.** A small post-power-amp block: a frequency-weighted soft saturator
  that saturates the LOW band harder than the highs (split low via a one-pole,
  soft-clip the low band only, recombine) + a gentle output high-shelf droop +
  optional low resonance bump. The "bass blooms and compresses, treble stays
  linear" behaviour is the audible tell. Reuses the existing softClipK / one-pole
  idioms.
- **Cost / risk.** Medium DSP (a band split + a saturator); on the island ->
  needs the 33 MHz headroom phase. Distinct from the cab IR (transformer is the
  power-amp's iron, cab is the speaker) -- both are missing and complementary.
- **Status (D94).** LF core saturation BUILT as a shift-only stage (one-pole LF
  split + low-band `softClipK`, 0 new DSP, gated amp-on, JC-120 excluded), on the
  same bitstream as the 40 -> 33 MHz island drop (which restored the island to
  WNS +3.150). The HF bandwidth droop + low-end resonance bump are still to come
  (left to the cab + D93 for now). bit `a1506fce`. **D96 adds the HF bandwidth droop** (one-pole high-cut, shift-only, 0 DSP) -- LF bloom + HF iron softness now both present; **D97 adds the low-end resonance bump** (~110 Hz peaking biquad) -- the transformer (LF saturation + HF droop + LF resonance) is now complete. See `DECISIONS.md` D94 + D96 + D97.

### 10. Waveshaper hysteresis / per-sample memory  [DONE D95 on the amp clips]

- **Why.** Real clipping is NOT memoryless: tube/diode/magnetic transfer curves
  depend on signal *history and slew direction* (the curve you trace going up
  differs from coming down). Every clip here is a static, memoryless transfer
  function -> the "frozen / same every cycle" quality the ear reads as digital.
  This is DIFFERENT from the D85/D86 envelope dynamics (those move a *parameter*
  slowly; hysteresis is a *per-sample* path dependence in the transfer curve).
- **Method.** Add a small one-sample feedback term to a clip: shift the effective
  knee by a fraction of the previous output (or of the input slew `x - xPrev`),
  so a rising edge clips slightly differently than a falling one. Bounded,
  reset-on-bypass. A little goes a long way; it "thickens" the saturation.
- **Cost / risk.** Low-medium (one prev register + an add per targeted clip, no
  multiply if done with shifts). Headroom-aware but cheap. Easy to overdo ->
  keep subtle, bench-tune.
- **Status (D95).** BUILT on both amp clip stages (`ampAsymClip` knee shifted by
  `prevOut >> 4`, registered prev = no combinational loop, 0 new DSP, JC-120 +
  amp-off byte-identical). Island stayed +3.085 (33 MHz headroom). bit
  `27c008ca`. `ampHystShift` is the subtlety knob. Could extend to the
  distortion/OD clips later. See `DECISIONS.md` D95.

### 11. Subtle "analog" modulation / micro-detune on the cab or output  [DONE D96]

- **Why.** A perfectly static spectrum is a digital tell -- real rooms, speakers
  and tubes have tiny, constant movement (air, microphonics, thermal drift). A
  bone-static patch sounds "frozen".
- **Method.** A *very* small LFO-modulated fractional delay (sub-millisecond,
  ~0.1-0.3 % depth) on the cab output, or a slightly detuned parallel voice
  (chorus-adjacent but far subtler), adds organic shimmer/movement without an
  audible chorus effect. Needs fractional-delay interpolation (the cab taps are
  integer-sample today).
- **Cost / risk.** Medium (interp + an LFO + a small delay line in BRAM);
  headroom-gated. Risk: overdone = obvious chorus/seasick. Keep depth tiny.

### 12. Multiband saturation (frequency-dependent clipping)  [BUILT D97 (amp mids)]

- **Why.** The D93 pre/de-emphasis is a crude single-band approximation of the
  fact that real circuits clip lows and highs *differently* (reactive parts make
  the knee frequency-dependent). Bass stays tight, mids saturate, highs fizz
  less.
- **Method.** Split into 2-3 bands (one-pole crossovers), saturate each with its
  own knee/hardness, recombine. The "proper" version of D93.
- **Cost / risk.** High DSP (crossovers + per-band saturators); firmly
  headroom-gated. Do only after the cheaper items prove insufficient.

### 13. Reverb diffusion quality  [BUILT D97 (allpass in the feedback)]

- **Why.** The current reverb is a simple BRAM feedback line; a sparse/comb-y
  reverb sounds metallic/digital on ambient patches. Real spring/room reverb is
  dense and diffuse.
- **Method.** Add a couple of allpass diffusers before/in the feedback loop (the
  Schroeder/Dattorro idiom) to increase echo density without lengthening decay.
- **Cost / risk.** Medium (a few allpass stages + BRAM); island-gated. Only helps
  reverb-on patches, so lower priority than amp/cab.

### 14. Intentional analog noise floor / "alive" idle  [LOW cost, polarising]

- **Why.** Dead-silent digital quiet between notes is itself a "digital" tell;
  real rigs have a faint hiss/hum floor that the brain associates with "real amp
  in the room". (Counter-pressure: most users want LESS noise -- so make it
  optional and *very* low.)
- **Method.** Inject an extremely low-level shaped noise (LFSR) only while the
  amp is on, well below the playing level. Cheap (an LFSR + an add). Strictly
  opt-in; default off.
- **Cost / risk.** Low DSP; high taste-risk. Likely a toggle, not a default.

### 15. Round-to-nearest in the per-stage shifts  [VERY LOW, free-ish]

- **Why.** Every `satShiftN` truncates toward -inf, so each stage adds a tiny
  consistent negative DC bias; across ~50 stages these correlate. Inaudible in
  level terms (24-bit) but the *correlation* is a (very minor) "digital" texture.
- **Method.** Add half-LSB (`+ (1 << (N-1))`) before each shift = round-to-
  nearest, removing the per-stage bias. Essentially free (an OR/add in the
  existing shift), no new DSP, no new state.
- **Cost / risk.** Negligible; expected payoff also small. Worth folding in
  opportunistically when a stage is touched anyway, not as its own phase.

**Quick ranking of these extras (realism per effort):** output-transformer (#9)
and hysteresis (#10) are the two with the best "more analog, believable" payoff;
#9 is headroom-gated, #10 is cheap-ish. Micro-modulation (#11) and reverb
diffusion (#13) are situational. Multiband (#12) is the expensive "proper" D93.
Noise floor (#14) and round-to-nearest (#15) are tiny/optional.

## The gating prerequisite: island headroom (item 0) — DONE (D94)

Items 1-3 (cab IR, amp + remaining-clip oversampling) all add DSP to the DS-1
island. **The 40 -> 33 MHz island drop was taken in D94** (bundled with the #9
transformer): `island_integration.tcl` `PCW_FPGA1_PERIPHERAL_FREQMHZ {33}`,
divisor 1000/5/6, DS-1 budget 25 -> 30 ns. The island is the only FCLK_CLK1
consumer, 1 sample/cycle, frequency-independent (paceCount removed), pitch set
by the I2S/Pmod clock -- safe, exactly as the D89 50 -> 40 step. **Result: island
WNS +3.150 ns at 33 MHz** (was -0.279 at 40 MHz post-D93), ~690 cycles/sample.
The headroom for the big items (cab IR step B + amp oversampling) is now in place
-- they no longer need a separate clock phase, just their own DSP.

## Recommended sequence (impact per effort, headroom-aware)

Order it as two facets: **harshness/fizz = aliasing** (the AMP is the most
pervasive offender, on in nearly every patch) and **fake/boxy = the 4-tap cab**.
The single highest-leverage *DSP* next move is amp aliasing, because the amp is
everywhere; the real cab IR is the biggest *realism* jump. They are complementary.

0. **Cheap interims first (no headroom needed):** pre/de-emphasis around the amp
   clips (A) and a subtle output HF shelf (B). Ship these before the 33 MHz phase
   to take the fizzy edge off immediately. Also confirm the **front-end Hi-Z
   buffer** (item 6) is in place -- a passive guitar into the Pmod line input may
   be a large part of the "thin/digital" impression and no DSP fixes it.
1. **Item 0 — island 40 -> 33 MHz** headroom phase (cheap tcl change, proven-safe
   like the D89 50->40 step; big unlock). Bench: pitch correct, all effects clean.
2. **Item 2 — oversample the Amp waveshapers** — broadest "less harsh" win (amp
   is in every patch); do this BEFORE the cab so the cab is not masking amp fizz.
3. **Item 1 — real cab IR (step B)** — the biggest single "more real / in the
   room" win (128-256-tap time-mux MAC).
4. **Item 3 — oversample the remaining clips** (OD high-gain, DS-1).
5. **Item 4 — more dynamic behaviour** (cheap envelope extensions) — interleave
   anytime; DSP-free.
6. **Item 5 — fill remaining per-model Overdrive tone biquads** (OCD/OD-1/Jan
   Ray coeffs into the D92 mux) — fixes "samey"; coefficient-only.
7. **Item 6 — front-end Hi-Z buffer** — operational, do in parallel.

Every DSP item is its own bitstream + WNS-vs-baseline + bench-audio gate. The
D74/D78 history stands: static timing passing is necessary but never sufficient
-- always bench-audition (all_off clean, touched models closer, untouched not
worse).

## One-line summary

The "digital" sound is mostly **aliasing on the still-un-oversampled stages
(especially the Amp, which is in every patch) plus the 4-tap cabinet**. The
highest-leverage plan is: **drop the island to 33 MHz for headroom, then build
the real cab IR and oversample the amp clips.** Dynamics and tone-biquad
polish are cheap incremental extras; the front-end (Hi-Z input) is a non-DSP
factor worth checking first.
