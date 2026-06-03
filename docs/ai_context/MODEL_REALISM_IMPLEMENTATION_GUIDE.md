# Model realism — implementation guide (HOW to build each improvement)

Companion to `REAL_HARDWARE_FIDELITY_ROADMAP.md` (measurement-first phase
strategy) and `MODEL_REALISM_GAP_ANALYSIS.md` (the WHAT/WHY). This file is
the **HOW**: concrete Clash implementation methods for each prioritized
realism item, with the exact helpers/slots to use, fixed-point math, FPGA
cost, timing risk, GPIO impact, and the build/validation gate.

## Implementation progress (2026-06-01) — item 4 & 5a accepted as D79

> Items 1 & 2 skipped per request. Items 4 and 5a were implemented in priority
> order, built, deployed, bench-auditioned, and accepted as **D79**. `main`
> now carries bit `f0cb0276f27187d72476a2e773dd9a6e` / hwh
> `5fa0b84e9fe852c68629c651f94e4a9d`; D78 `45e78763...` is the rollback.
> Static timing is still NOT proof by itself (D74/D78 lesson), but this pass
> has the required bench result: all_off clean / no bitcrusher. Build env note:
> the dev `clash` fails standalone
> because cabal store has a stray `clash-prelude-1.8.2`; build with
> `CLASH_FLAGS="-package-id clash-prelude-1.8.1-043657e64d575898396c414bafaea7f08fdd2ba6b4085ce0bd624cd91d00144c -isrc --vhdl" make Pynq-Z2`
> (Makefile unedited). `make clean` deletes the git-tracked `hw/ip/clash/vhdl/`
> + `hw/Pynq-Z2/bitstreams/` — restore with `git checkout --` after.
>
> | Item | Branch | Clash | Vivado | Island WNS (clk_fpga_1) | Audio fabric (clk_fpga_0) | Verdict |
> | --- | --- | --- | --- | --- | --- | --- |
> | 4 clip hardness | `feature/realism-clip-hardness` | OK | OK | **-0.173 ns** (= D78) | +0.683 / 0 fail | timing clean; bench accepted as part of D79. Intermediate bit `e884360a` |
> | 5a Klon blend | `feature/realism-klon-clean-blend` (on item4) | OK | OK | **-0.496 ns**, 32 fail | +0.532 / 0 fail | accepted as D79. Worse than D78 (-0.173) but better than the bench-approved D75 (-0.706); phys_opt already on. bit `f0cb0276` |
>
> Baselines for comparison: D78 -0.173 (accepted), D76 -0.368 (accepted), D75
> -0.706 (bench-"perfect"). All failures are intra-DS-1 CARRY4 (the perennial
> island critical path), NOT new Klon-blend paths — the blend add landed on the
> audio fabric region's slack budget via P&R, not as a new long path.
>
> **item5a timing note (measured, for the human / next pass):** the Klon
> level-stage blend uses TWO `mulU8` in PARALLEL (wet*blend + clean*cleanWeight)
> + satShift8, giving island WNS -0.496. **A one-multiply LERP rewrite was tried
> and REJECTED:** `blended = clean + (mulU8 (wet-clean) blend >> 8)` built and
> ran but measured **-3.627 ns / 117 fail** — far WORSE, because the LERP form is
> a *serial* subtract→multiply→shift→add chain that lengthens the DS-1 CARRY4
> path, whereas the two parallel multiplies route better (same lesson as Wah:
> avoid two multiplies in series; parallel arithmetic is faster on this island).
> So the committed 5a is the 2-mul parallel form (-0.496). Do NOT "optimise" it
> to a single serial multiply. -0.496 passed the bench as D79. If a future pass
> wants more island margin, recover it with placement/phys_opt directives or by
> registering the blend into its own pipeline stage (a new `register` between
> clip and level, carrying the clean in a slot), NOT by serialising the math.

Read first: `MODEL_REALISM_GAP_ANALYSIS.md`, `DSP_EFFECT_CHAIN.md`,
`Types.hs`, `FixedPoint.hs`, `TIMING_AND_FPGA_NOTES.md`,
`DECISIONS.md` D13/D45/D55/D75/D76/D78/D79.

## D80 Python-only control realism pass

R0a (knob taper + preset polish) is now implemented without a bitstream
rebuild. `audio_lab_pynq/knob_tapers.py` converts user-facing physical knob
positions to the existing linear overlay percent API for GUI / encoder /
chain-preset writes. Low-level `set_guitar_effects()` and
`set_distortion_settings()` remain linear. Preset DRIVE / Amp GAIN positions
were raised where needed so the tapered hardware values land near the previous
practical voicings while the displayed settings feel closer to real pedals.
This does not affect the D79 timing baseline.

---

(Design spec for all items follows. Items 4/5a are accepted as D79. **Item 3
(resonant tone stacks) is now implemented for two targets:**
- **D81 — Tube Screamer ~720 Hz mid hump:** pre-clip `tubeScreamerMidFrame`
  peaking biquad (DF1, hand-designed f0=720 Hz / Q=0.8 / +6 dB, **Q14** coeffs
  via new `FixedPoint.mulS16` + `satShift14` — Q8/`mulS10` collapses the
  low-frequency DC gain), five multiplies in parallel, pipeline `x1/x2/y1/y2`,
  bit-exact bypass. Island WNS -0.193 ns. bit `3a79745f`.
- **D82 — Big Muff ~700 Hz mid-scoop notch:** post-clip peaking biquad with
  negative gain (f0=700 Hz / Q=0.8 / -10 dB), between clip2 and the tone LPF.
  **Pipeline-split (load-bearing):** the single-stage 5-mul form measured
  -0.659 ns (biquad feedback near-critical, pressuring DS-1). An IIR feedback
  loop CANNOT be naively pipelined; the fix precomputes the feedforward sum
  `b0*x+b1*x1+b2*x2` into `fAcc3L` one stage earlier (`bigMuffScoopFeedforwardFrame`)
  and closes the loop in `bigMuffScoopRecursiveFrame` with only `-a1*y1-a2*y2`
  (shorter single-cycle feedback path, math identical) — recovered to -0.534 ns
  with the biquad off the critical set. bit `ee295544`.

- **D83 — amp-stack shared biquad, Fender blackface mid scoop:** ONE shared
  peaking biquad in the amp tone path (between `ampStage2Pipe` and
  `ampToneFilterPipe`, on `monoWet`), coefficients muxed by `ampModelIdxF`
  (`ampScoopFeedforwardCoeffs`/`ampScoopFeedbackCoeffs`), reusing the D82
  feedforward/recursive split. Filled the Fender scoop (JC-120 idx 0 + Twin
  idx 1, f0=400 Hz / Q=0.7 / -5 dB); models 2-5 flat = unity = byte-identical.
  Island WNS -0.381 ns (beat D82's -0.534 despite +5 DSP). bit `cef494cb`.

- **D84 — AC30 chime + JCM800 mid (coefficient-only):** filled idx 2 (Vox
  chime, +4 dB @ 2200 Hz) and idx 4 (Marshall mid, +4 dB @ 650 Hz) into the
  same D83 amp-scoop mux; Rockerverb/TriAmp stay flat. Island WNS -0.472 ns.
  bit `dc030473`.

All four bench-accepted, no GPIO/API change. **item 3 (resonant tone stacks) is
substantially complete.**

**Item 5b (dynamic behaviour, R2) is now in progress:**
- **D85 — Fuzz Face dynamic bias (part 1):** a playing-level peak-follower
  envelope (`fuzzFaceBiasEnvNext`, instant attack / ~43 ms release / reset-0 on
  bypass) drifts the clip knees -- soft = cleaner asymmetric Ge knees, hard =
  knees pull together (sputter). DSP-free (abs+shift+compare), bit-exact bypass.
  Island WNS -0.122 ns (best of the run). bit `b2d8a41b`.
- **D86 — power-amp sag (part 2, item 5b complete):** a slow peak-follower of
  the master-input level (`ampSagEnvNext`, ~170 ms release, reset-0 on bypass)
  lowers the `ampMasterFrame` level on loud passages and recovers. **DSP-free**
  -- reuses the existing master `mulU8` by dropping the level operand
  (`sagByte = min(env bits 22..17, level>>1)`, bounded = no choke); JC-120
  excluded (solid-state). Island WNS -0.397 ns. bit `1ab991c7`.

**item 5b (dynamic behaviour) is complete.**

**item 1 (cab IR) step A is done (D87):** an additive 15-tap symmetric
linear-phase speaker-rolloff FIR on the cab output (sharper >5 kHz rolloff,
fizz reduction, model HF separation), per-model hand-designed coeffs, folded to
8 mulS10. A FIR is feedforward so it pipelines freely -- the single-cycle
15-tap sum blew timing to -1.1 ns (FIR = critical path); splitting into a
products stage (8 products from one history snapshot -> 3 Wide partial sums)
and a mix stage recovered to -0.476 ns. Does NOT touch the accepted D71
nonlinear cab core. bit `8a3754c1`. **step B = the real 128-256-tap MAC
convolution** (time-mux MAC + BRAM + handshake) remains the next phase.

**item 2 (oversampling) in progress (D88):** Metal MT-2 hard clip now runs 4x
oversampled -- linear-interp upsample (shifts/adds, no mult; band-limited input
makes it == a full anti-image FIR), 4 hard clips, 15-tap symmetric anti-alias
decimation FIR (Q9, 8 folded mulS10), pipeline-split products/mix. Offline +
bench ~-12 dB inharmonic-fizz reduction. (DSP-free 2x only -2.8 dB; proper 2x
plateaus -5.8 dB since >48 kHz still folds; 4x is the worthwhile rate.) Island
WNS -0.496 ns (worst path still DS-1). bit `d4c250be`. **Extend the same 4x
oversampler to RAT, then Big Muff -- one model/phase; DS-1 excluded (critical
path).**)

Read first: `DSP_EFFECT_CHAIN.md` (stage order), `Types.hs` (Frame),
`FixedPoint.hs` (helpers), `TIMING_AND_FPGA_NOTES.md` (timing baseline),
`DECISIONS.md` D13/D45/D55/D75/D76/D78/D79.

## 0. DSP environment recap (the constraints every item must fit)

From the source (verified):

- **Sample = `Signed 24`** (`±8_388_607` full-scale), **Wide = `Signed 48`**
  (accumulators), mono, **48 kHz**, one sample/cycle fully-pipelined.
- DSP runs on the **50 MHz island** (`clash_lowpass_fir_0`, FCLK1; D75). Its
  DS-1 CARRY4 arithmetic is the critical path; D78 showed adding *anything*
  (even an unrelated AXI master) can tip it into an audible bitcrusher.
  **Every item here must be followed by a WNS-vs-baseline review + bench
  audio.** Current accepted baseline: D79 `f0cb0276` (island WNS -0.496 ns,
  audio fabric +0.532 / 0 fail); D78 `45e78763` is the rollback.
- **Helpers available** (`FixedPoint.hs`): `mulU8/9/10/12` (Sample×unsigned →
  Wide), `mulS10` (Sample×Signed10 → Wide), `satWide`, `satShift7..12`,
  `softClip`, `softClipK knee`, `asymSoftClip kneeP kneeN`,
  `asymHardClip kneeP kneeN`, `hardClip x thr`, `onePoleU8 alpha prev x`.
- **Frame scratch slots** (`Types.hs`): per-sample accumulators `fAccL`,
  `fAcc2L`, `fAcc3L` (Wide) and filter-state carriers `fEqLowL`, `fEqMidL`,
  `fEqHighL`, `fEqHighLpL` (Sample). Effects reuse these between their own
  stages (e.g. Amp tone uses fEqLow/Mid/High). **A new multi-stage effect can
  borrow them as long as no *other* effect needs them live across the same
  cycles** — they are not persistent state, just intra-effect plumbing.
- **Persistent state** (across samples) is threaded as **function arguments
  fed by `register`** in `Pipeline.hs`. Pattern: a stage like
  `ampHighpassFrame prevIn prevOut f` or `onePoleU8 alpha prev x` reads the
  previous sample from a register the pipeline maintains. To add a new IIR you
  add a new `register`-backed previous-sample value and thread it in.
- **BRAM delay line** pattern (`Reverb.hs` + `Types.hs`): `ReverbAddr =
  Index 1024`, `ReverbMem = Vec 1024 Sample`, `advanceAddr`, `attachAddr`,
  `addrNext`, `writeReverb`. A circular buffer with one write + one (or more)
  read taps per sample. **This is the reuse pattern for FIR/IR convolution
  and for any longer delay.**
- **GPIO contract is fixed** (D12). New knobs must land on documented
  reserved bytes/bits first (e.g. `axi_gpio_eq.ctrlD`,
  `axi_gpio_noise_suppressor.ctrlD`, distortion mask bit 7). Re-voicing that
  reuses existing knobs needs **no** GPIO change.
- **No schematic-exact coeff tables / GPL code** (D7/D45/D55). Everything is
  hand-rolled "inspired-by" shapes.

---

## Item 4 first — per-model clip *hardness* (cheapest, highest differentiation)

Do this one first: lowest FPGA cost, lowest timing risk, biggest
per-model separation per unit effort. No new GPIO.

### Idea
Today OD models share one `asymSoftClip` curve (1/4 positive, 1/8 negative
slope) and differ only by knee. Real op-amp / Si-diode / Ge-diode / LED /
MOSFET / tube clipping differ in **knee hardness** (compression slope above
the knee) and resulting harmonic order. Make the slope per-model.

### Method
Generalise the existing `asymSoftClip` to take per-half **shift amounts**
(the compression slope is `>> shift`; bigger shift = harder/more compressed =
more odd harmonics; `shift=1` ≈ near-hard). Add to `FixedPoint.hs`:

```haskell
-- slope above knee = 1 / 2^shift. shiftP/shiftN in 1..4.
asymSoftClipS :: Int -> Int -> Sample -> Sample -> Sample -> Sample
asymSoftClipS shiftP shiftN kneeP kneeN x
  | x > kneeP     = resize (resize kneeP    + (((resize x :: Signed 25) - resize kneeP)    `shiftR` shiftP))
  | x < negKneeN  = resize (resize negKneeN + (((resize x :: Signed 25) - resize negKneeN) `shiftR` shiftN))
  | otherwise     = x
 where negKneeN = negate kneeN
```

Then per-model `odClipShiftP/odClipShiftN :: Unsigned 3 -> Int` tables in
`Overdrive.hs`, e.g. TS9 = (2,3) (soft op-amp), OCD = (1,1) (MOSFET hard),
Klon = (1,2), OD-1 = (2,3), Jan Ray = (3,3) (gentle), CENTAUR clipped-path
(1,2). Same idea per pedal in `Distortion.hs` (DS-1 → harder, near `asymHardClip`).

### Cost / risk
**Tiny.** `shiftR` by a *constant* is free wiring; the per-model `shift` is a
small mux selecting among 1..4 (a few LUTs), feeding an existing subtract/add.
No new DSP48, no new register stage, no BRAM. This is the same "constant LUT
mux into an existing arithmetic op" pattern D45 already proved routes well.
Timing risk: negligible. **Caveat:** a *variable* shift amount (`shiftR` by a
signal) is more expensive than a constant shift; keep the choice to a 2–4 way
mux of constant-shift results, not a barrel shifter.

### GPIO: none. Validation: golden-byte tests unchanged; bench A/B each model.

---

## Item 3 — resonant tone stacks (biquads): TS hump, Muff notch, amp stacks

Restores the signature EQ shapes a one-pole tilt cannot make. Medium cost.

### Idea
A **biquad** (2nd-order IIR) can make a resonant peak (TS ~720 Hz hump, Vox
chime, AC30 upper-mid), a notch (Big Muff mid-scoop), or a real tone-stack
band. One-pole filters (current `onePoleU8`) can only tilt.

### Method
Direct-form-I biquad, fixed-point. Coeffs as `Signed` Q-format constants
(precomputed offline per target curve — *shapes we choose*, not copied
schematic tables). Needs **2 sample-delay registers of input and 2 of output**
threaded through the pipeline (like the existing prev-sample IIRs), and **5
multiplies** (b0,b1,b2,a1,a2) per biquad.

```haskell
-- y[n] = b0*x + b1*x1 + b2*x2 - a1*y1 - a2*y2   (all in Wide, then satShift)
biquad :: BiquadCoeffs -> (Sample,Sample,Sample,Sample) -> Sample -> (Sample, ...)
-- x1,x2,y1,y2 come from registers; return new y plus updated state.
```

Coeffs scaled so unity passband ≈ no change (test: flat input → flat out).
Reuse `mulS10` (Sample×Signed10) if 10-bit coeff precision suffices; if not,
widen to a `mulS16`-style helper (new, Sample×Signed16 → Wide) — still one
DSP48 each.

Where to place:
- **TS hump / Muff notch / Metal mid**: as the existing tone stage of that
  pedal in `Distortion.hs` (replace the one-pole `postLpf`/`tone` stage).
- **Amp Fender/Vox/Marshall stacks**: replace `ampToneFilterFrame` +
  `ampToneBandFrame` (currently a difference-filter 3-band) with a per-family
  biquad pair, selected by `ampModelIdxF`.

### Cost / risk
**Medium.** Each biquad ≈ 5 DSP48 + 4 sample registers + adders. The island
is DSP-tight (D55/D58 history: adding 4 multipliers shifted P&R and caused a
bypass saturation noise). So: **share ONE biquad instance** reused across
stages where possible (coeffs muxed per model — constants into a shared MAC),
rather than instantiating one per model. Budget DSP count against
`TIMING_AND_FPGA_NOTES.md` (D76 used 89 DSP). Expect this to be the item that
most needs a timing-headroom pass first.

### GPIO
None if it replaces existing tone stages (reuses TONE/MID knobs). A new
"parametric mid sweep" knob (Metal) would need a reserved byte.

### Validation
Unity-coeff test = bit-identical passband; sweep test (chirp in, check the
peak/notch lands at the target Hz); bench A/B. Watch for IIR limit cycles at
low signal — add a tiny leak (subtract `y>>N`) if the tail rings.

---

## Item 5a — Klon/CENTAUR clean-blend (single-model, iconic, cheap)

### Idea
The Klon's identity is a **parallel clean path mixed with a hard-clipped
germanium path** — its "transparency" is the dry signal, not a soft clip.
Currently CENTAUR is just another soft-clip OD (no blend).

### Method
In `Overdrive.hs`, only when `model == 5`:
1. Keep the existing clipped wet in `monoWet`.
2. Carry the pre-clip clean sample in a spare slot (e.g. `fAcc2L` or a
   dedicated `setMonoDry` already present) through the clip stage.
3. In the level stage, blend: `out = satShift8 (mulU8 clean invBlend + mulU8
   clipped blend)` where `blend` rises with DRIVE (Klon "gain" raises the
   clipped proportion). Hard-clip the wet path (use `asymHardClipS` from
   Item 4 with a small knee) for the germanium character.

### Cost / risk
Low: one extra `mulU8` + add (1 DSP48 or reuse the tone multiply slot) and one
carried sample. Only active for model 5 (a mux), so the other five models are
unchanged. Timing: small.

### GPIO: none (DRIVE knob drives the blend). Validation: at DRIVE=0 model 5
should be ~clean (blend≈0); bench A/B vs other models.

---

## Item 5b — Fuzz Face / amp dynamic bias-shift & sag (touch response)

### Idea
Fuzz Face cleans up with input level and "sputters/gates" at low input; tube
amps **sag** (compress) and shift bias under load. All are **input-level- or
envelope-dependent** behaviours the static clips lack.

### Method (envelope → parameter modulation, no new GPIO)
1. Compute a slow envelope of `|monoSample|` with a one-pole (reuse
   `onePoleU8` with a small alpha, prev in a new register). The chain already
   has an envelope follower in `Compressor.hs`/`NoiseSuppressor.hs` to model
   after.
2. **Fuzz Face bias shift:** offset the clip knees by `±(env >> k)` so the
   waveform centre drifts with level → asymmetric, level-dependent gating.
   `asymHardClip (kneeP - biasShift) (kneeN + biasShift)`.
3. **Amp sag:** scale the post-clip/power gain down by `(env >> k)` so loud
   passages compress (`mulU8 x (255 - (envByte>>k))`). Apply at
   `ampPowerFrame` / `ampMasterFrame`.

### Cost / risk
Low-medium: one envelope register + a subtract/shift into existing knees/gain.
No new DSP48 if you reuse a multiply already in the stage. The envelope is
cheap (it already exists for Comp/NS). Risk: envelope time constants must be
tuned so it compresses musically, not pumps — bench-driven.

### GPIO: none (reuses existing knobs + derived envelope). Validation:
pick-dynamics test (soft vs hard pick should differ); Fuzz Face guitar-volume
cleanup audible; amp sag audible on loud chords.

---

## Item 1 — real short-IR cabinet (BRAM convolution) [biggest cab win]

### Idea
Replace the 4-tap pseudo-IR with a **real short impulse response** (128–256
taps) convolved via BRAM. This is the single biggest cab realism gain:
genuine presence peak, sharp >5 kHz rolloff, cone-breakup comb character, and
real model distinctness.

### Method
1. **Storage:** store the IR coefficients in a `Vec N Sample` ROM (or BRAM if
   N is large) per model. For 3 models × 256 taps that is 768 coeffs — fits in
   a small BRAM. Use the `ReverbMem`/`blockRam` pattern from `Reverb.hs`
   (`Index N`, `advanceAddr`, circular write of the input history).
2. **Delay line:** a circular input-history buffer in BRAM (`Index 256`),
   exactly the Reverb write pattern (`writeReverb`-style `(addr, sample)`).
3. **Convolution MAC:** here is the hard part on a 1-sample/cycle pipeline. A
   full 256-tap FIR needs 256 MACs/sample — impossible in one cycle at 48 kHz
   on this fabric as combinational logic. **Options:**
   - (a) **Time-multiplexed MAC**: the audio rate is 48 kHz but the fabric is
     50–100 MHz, so there are ~1000–2000 clocks per audio sample. A small
     state machine can do 128–256 MACs sequentially into one accumulator using
     **one DSP48**, reading IR[k] and history[addr-k] each clock. This is the
     standard FPGA FIR and is very DSP-cheap (1 multiplier) at the cost of a
     sequencer + dual-port BRAM reads. **This is the recommended path.**
   - (b) Partitioned/block FIR if latency must stay sub-sample (not needed
     here; one-sample latency is fine for a cab).
4. **Integration:** this breaks the "every stage is `Frame->Frame`,
   one-sample/cycle" assumption for the Cab stage only — the Cab becomes a
   multi-cycle sub-block that must complete within the audio-sample period.
   The AXIS handshake (`Pipeline.hs` `acceptReady`, D75 `paceCount` removal)
   must gate so the pipeline waits for the MAC to finish. **This is a
   structural change — its own phase.**

### Cost / risk
Medium DSP (1 MAC) but **non-trivial control logic** (MAC sequencer + BRAM
dual-port + handshake gating) and it changes the Cab stage timing model.
Highest *engineering* cost of the cheap-DSP items, but the IR ROM is just data
so model retuning afterwards is free. Must re-verify the 50 MHz island
handshake and WNS carefully (D75 island rules are load-bearing).

### GPIO
MODEL/AIR keep their bytes (MODEL selects IR set; AIR can cross-fade two IRs
or apply a high-shelf as today). No new GPIO required for 3 models.

### IR sourcing (license-safe)
Do **not** ship captured commercial-cab IRs of unknown license. Generate the
IRs ourselves from the *target frequency response we design* (inverse-FFT of a
hand-drawn magnitude curve: low rolloff ~80 Hz, presence peak ~3–5 kHz, sharp
rolloff >5 kHz, model-specific). That keeps it "inspired-by," same policy as
the rest of the chain (D7/D45).

### Validation
Impulse-in → capture output = the stored IR (correctness). Chirp → magnitude
matches the designed curve. Bench A/B: models clearly distinct; high-gain fizz
tamed far better than the 4-tap version.

---

## Item 2 — oversampling the nonlinearities [biggest "digital fizz" win, costliest]

### Idea
Run the clip/waveshaper at 2×–4× to push alias products above the audible band
before decimating. Removes the metallic aliasing that makes high-gain patches
sound digital. Helps **every** OD/DIST/AMP model.

### Method
Around a clip stage:
1. **Upsample** ×N: zero-stuff or linear-interp the input to N sub-samples.
2. **Anti-imaging LPF** (the interpolation filter) — a short FIR/biquad.
3. **Nonlinearity** evaluated N times.
4. **Anti-aliasing LPF** before decimation — another short FIR/biquad.
5. **Decimate** ×N (keep 1 of N).

On a 48 kHz audio rate with a 50 MHz clock there are plenty of cycles, so the
N sub-evaluations can be **time-multiplexed** through one shared clip+filter
datapath (same sequencer idea as the cab MAC), keeping DSP count bounded.

### Cost / risk
**Highest.** Needs the up/down FIRs + N sequential nonlinearity evals +
control logic, and it touches the most timing-sensitive part (the DS-1/amp
clips that already dominate WNS). Realistically this is a **dedicated research
phase** that probably needs island/clock headroom work first (more pipeline
registers, or a faster island clock if the CDC allows). Start with **2×** on
**only the worst aliasers** (RAT/DS-1/Metal/high-gain amp), not the whole chain.

### GPIO: none. Validation: chirp/THD test — alias tones (inharmonic spurs)
must drop substantially vs the 1× version; bench A/B on high-gain models.

---

## Recommended sequencing (remaining work)

1. **Done in D79: Item 4 (per-model clip hardness)** — cheap, high
   differentiation, no GPIO.
2. **Done in D79: Item 5a (Klon blend)**. **Still open: Item 5b
   (Fuzz/amp sag)** — model-local, no GPIO.
3. **Item 3 (biquad tone stacks)** — medium; share one biquad instance, watch
   DSP count. May need a small timing-headroom pass first. No GPIO if it
   replaces existing tone stages.
4. **Item 1 (cab IR convolution)** — structural (MAC sequencer + BRAM +
   handshake); its own phase with careful island/WNS review. No GPIO.
5. **Item 2 (oversampling)** — largest; dedicated research phase, likely needs
   clock/pipeline headroom first; start 2× on the worst aliasers only.

### Universal gate for every item (from the D74/D78 bitcrusher lessons)
- Vivado `write_bitstream` 0 errors.
- Routed **island (clk_fpga_1) WNS not worse than the accepted baseline by
  an audibly meaningful margin** (D79 = -0.496 ns; D78 rollback = -0.173
  ns; D75 bench-perfect = -0.706 ns). If worse, recover placement/phys_opt
  headroom or do not deploy.
- bit/hwh synced to the 5 sites; `download=True` once after power-cycle.
- **Bench audio A/B is mandatory** — static timing passing is NOT sufficient
  proof (D65/D74/D78). Listen for bitcrusher/aliasing on all_off bypass +
  each touched model.
- Golden-byte tests (`tests/test_overlay_controls.py`) pass; ADC HPF stays
  `0x23`.

## Out of scope / not done
- Items 5b and 3 remain spec-only.
- No GPIO changes were made by D79.
- Stereo/dual-mic/room and chorus (JC-120) not covered.
- Exact new coefficient *values* are left to the implementation pass (this
  guide specifies method, slots, helpers, and cost — not final constants).
