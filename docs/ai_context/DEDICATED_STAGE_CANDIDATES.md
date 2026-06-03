# Dedicated-stage candidates — which models need structural DSP, ranked

Companion to `MODEL_REALISM_GAP_ANALYSIS.md` (the WHAT/WHY per model) and
`MODEL_REALISM_IMPLEMENTATION_GUIDE.md` (the HOW). This file answers one
question: **of the currently-implemented models, which ones are poorly served
by their shared stage and warrant more structural DSP — and in what order?**

## The two patterns already in the build

The project deliberately uses two patterns, and the right choice is per the
model's *structure*, not its name:

| Pattern | Used by | When it is right |
| --- | --- | --- |
| **Dedicated stage** (its own always-instantiated datapath) | the 7 Distortion pedals (clean_boost / tube_screamer / ds1 / big_muff / fuzz_face / metal / rat) | the model's signal flow is fundamentally different (diode-to-ground hard clip vs 2-cascade + notch vs bias-starve fuzz …) |
| **Shared stage + coefficient/parameter mux** | Overdrive (6 models), Amp (6 models), Cab (3 models) | models differ only in *voicing* (knee / gain / EQ / clip hardness) — one datapath, model selects constants |

Key consequence (see `TIMING_AND_FPGA_NOTES.md` D89/D90): every dedicated stage
consumes FPGA area and 50 MHz/40 MHz-island routing whether the model is on or
off. The Zynq-7020 budget (~53k LUT, 220 DSP) and the timing-tight DS-1 island
make "a dedicated stage per model" **area- and timing-prohibitive** for
voicing-variant models — and pointless, since the muxed version sounds
identical. **Most structural needs are better met by a model-gated *sub-path*
or a muxed biquad inside the shared stage** (the D79 Klon clean-blend, D81/D83/
D84 biquads, and D86 sag envelope all do exactly this), NOT by a new full
stage.

## Ranked candidates (highest structural mismatch first)

Ranking = audible-character gap × how badly the shared topology fails to
capture it. Note that for all but #1 the recommended fix is an *extension of
the shared stage*, not a separate dedicated stage.

### 1. JC-120 (Amp Sim model 0) — clean bypass sub-path  [HIGHEST]

- **Mismatch.** The shared Amp stage runs **two always-on asymmetric soft-clip
  stages** (`ampWaveshapeFrame` + `ampSecondStageFrame`) for every model. The
  real JC-120 is a solid-state, hi-fi *clean* channel that does not clip; the
  always-on waveshaper colours a signal it should leave clean. The D83 Fender
  scoop biquad applies, but the clip colouring remains.
- **Fix (cheap, model-gated, no new full stage).** When `ampModelIdxF == 0`,
  route a **clean bypass** around the two clip stages (output the pre-clip
  signal, or a very-high-knee soft clip that only catches extreme peaks).
  A mux on the existing path — no new DSP. Optionally keep a small amount of
  the tone stack so EQ knobs still work.
- **Why first.** Clearest structural mismatch, clearest audible win (a truly
  clean clean channel), lowest cost. (Chorus is out of scope.)

### 2. Tube Screamer (dedicated **Overdrive** model 0) — ~720 Hz mid-hump biquad  [HIGH]

- **Mismatch.** The dedicated Overdrive effect shares **one tone tilt** across
  all six models. The TS's defining ~720 Hz **mid hump** is a resonant peak a
  one-pole tilt cannot make, so TS9 (model 0) sounds like the other ODs with a
  different knee.
- **Fix.** Add a **model-muxed peaking biquad** inside the shared Overdrive
  stage (exactly the D81 hump and D83/D84 amp-stack pattern). NOT a dedicated
  stage. Caveat: the *Distortion pedalboard's* `tube_screamer` pedal already
  got this biquad in D81 — that is a **different** block from the dedicated
  Overdrive model 0, which is still flat.
- **Generalises.** The same shared-OD biquad, with per-model coefficients,
  also gives OCD its upper-mid honk, BD-2 its brightness, etc. — i.e. the
  "per-model tone shaping" the gap analysis wants, for the cost of one shared
  biquad + a coefficient mux.

### 3. Klon / CENTAUR (Overdrive model 5) — refine the parallel clean-blend  [MEDIUM, partly done]

- **Mismatch.** The Klon's identity is a **parallel clean path mixed with a
  germanium hard-clipped path**. This is structurally distinct from a single
  soft-clip OD.
- **Status.** **Already implemented as a model-5-gated sub-path** in D79
  (item 5a): a parallel clean stash blended in the level stage. The structure
  exists; remaining work is *refinement* (a germanium-style hard clip on the
  wet path, a better blend law as DRIVE rises), which is incremental — **no new
  stage needed**.

### 4. AC30 (Amp Sim model 2) — cathode-bias sag refinement  [MEDIUM–LOW, mostly covered]

- **Mismatch.** Vox class-A character = a chimey upper-mid peak + cathode-bias
  sag/compression with early breakup.
- **Status.** The chime peak is done (D84 biquad). The sag/compression is
  largely covered by the **D86 power-amp sag envelope**, which already applies
  to the tube amps (AC30 included; JC-120 excluded). An AC30-specific sag
  voicing is incremental tuning — **no new stage**.

## Explicitly NOT candidates for a dedicated per-model stage

- **Distortion pedals** (RAT / DS-1 / Big Muff / Fuzz / Metal / clean_boost):
  already each a dedicated stage. RAT, DS-1-adjacent, Metal, and Big Muff are
  also the ones already 4x-oversampled (D88–D90).
- **Cab (3 models):** the real win is the **128–256-tap MAC convolution**
  (cab IR item 1 step B) — a *shared* MAC structure with per-model IR ROM, not
  three dedicated stages.
- **OD-1 / Jan Ray / OCD / BD-2:** voicing variants — covered by D79 clip
  hardness plus the shared-OD per-model tone biquad of candidate #2.

## Summary

Genuinely "needs a different signal path" = **only JC-120 (a clean bypass)**,
and even that is a model-gated mux, not a full stage. Candidates 2–4 are all
**extensions of the shared stage** (muxed biquad / refined sub-path / envelope)
and should be implemented that way. The Distortion-pedalboard style of a full
dedicated stage per model is reserved for genuinely different topologies and is
otherwise avoided on FPGA-area and DS-1-island-timing grounds (D89/D90).

Recommended order to implement: **JC-120 clean path → shared-OD per-model tone
biquads (TS9 first) → Klon wet-path refinement → AC30 sag tuning.** Each is a
separate bitstream + WNS-vs-baseline + bench-audio gate (the D74/D78 lesson:
static timing is necessary but not sufficient).
