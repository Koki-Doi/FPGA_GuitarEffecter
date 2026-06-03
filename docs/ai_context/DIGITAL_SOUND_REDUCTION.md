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
- The DSP island was lowered to **40 MHz (D89)** to fit the above; it is now
  near-full (D90 island WNS -0.036 ns).

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
- **Status.** Partially done; extend to the Overdrive models.

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

## The gating prerequisite: island headroom (item 0)

Items 1-3 (cab IR, amp + remaining-clip oversampling) all add DSP to the DS-1
island, which is **full at 40 MHz** (D90 WNS -0.036 ns). Before any of them:

- **Lower the island clock 40 -> 33 MHz** (`island_integration.tcl`,
  `PCW_FPGA1_PERIPHERAL_FREQMHZ {33}`, divisor 1000/5/6). DS-1 budget 25 -> 30
  ns. The island is the only FCLK_CLK1 consumer, 1 sample/cycle,
  frequency-independent (paceCount removed), and pitch is set by the I2S/Pmod
  clock -- so this is safe, exactly as the D89 50 -> 40 step was. 33 MHz still
  gives ~690 cycles/sample, plenty for a 256-tap time-mux cab MAC.
- This single change unlocks the biggest items (cab IR + amp oversampling).

## Recommended sequence (impact per effort, headroom-aware)

1. **Item 0 — island 40 -> 33 MHz** headroom phase (cheap tcl change, big
   unlock). Bench: pitch correct, all effects clean.
2. **Item 1 — real cab IR (step B)** — the biggest single "less digital" win.
3. **Item 2 — oversample the Amp waveshapers** — broad win (amp is everywhere).
4. **Item 3 — oversample the remaining clips** (OD high-gain, DS-1).
5. **Item 4 — more dynamic behaviour** (cheap envelope extensions) — interleave
   anytime; DSP-free.
6. **Item 5 — per-model Overdrive tone biquads** — fixes "samey".
7. **Item 6 — front-end Hi-Z buffer** — operational, do in parallel; it may
   account for a surprising amount of the "thin/digital" impression.

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
