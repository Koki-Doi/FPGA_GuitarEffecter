# Model realism gap analysis — OD / DIST / AMP / CAB

Investigation only (2026-06-01). **Historical pre-D98/pre-D90 analysis.**
Several recommendations here were implemented later (96 kHz in D98, 4x
oversampling for Metal/RAT/Big Muff in D88-D90, D121-D135 voicing passes).
Use this file as the original gap map, not as the current implementation
inventory. Goal: for each
Overdrive / Distortion / Amp Sim / Cab IR model, document (1) what the real
hardware does, (2) what the current Clash DSP does, (3) the gap, (4) how to
get closer. Exact current constants live in the source files cited per
section; this doc is the analysis layer on top of them.

Current boundary (2026-06-22): accepted deployed baseline is D155
(`09c8a95`, bit `8d875cc8...`) = cab speaker FIR 31->47 taps capping the
D150-D155 voicing arc on top of D148 (JC/Twin clean-headroom + D146/D147),
superseding D153 (`b86c88a`). D144's
simulation-proven chord-detune candidate was bench-rejected and rolled back to
D135 because the rebuilt placement did not pass the hardware acceptance gate;
the D146 hard pblock is what finally let a clean-headroom voicing land. New
recommendations here are design inputs, never acceptance evidence.

Sources read: `hw/ip/clash/src/AudioLab/Effects/{Overdrive,Distortion,Amp,Cab}.hs`,
`GUI/compact_v2/knobs.py` (model lists), `REAL_PEDAL_VOICING_TARGETS.md`,
`AMP_MODEL_RESEARCH_D55.md`, `BD2_MODEL_RESEARCH.md`,
`DISTORTION_ASYMSOFTCLIP_RETUNE_RESEARCH.md`,
`GLOBAL_REAL_PEDAL_RETUNE_RESEARCH.md`, `AUDIO_RECORDING_ANALYSIS.md`.

Current constraint reminder (updated 2026-06-15): the live path is mono inside
the DSP but the external AXI/I2S contract remains stereo; audio runs at **96 kHz
as of D98**; Metal/RAT/Big Muff now use **4x oversampling**; and the DSP island
runs at **33.33 MHz as of D94**. Every remaining "add DSP" idea below must still
be weighed against timing/placement, D109 CDC slack, and bench safe-bypass
quality. Clash is the single DSP source of truth (D13, no C++).
No schematic-exact coefficient tables / GPL code may be copied (D7/D45/D55).

---

## 0. Cross-cutting gaps (biggest realism levers, apply to all four)

These structural limits dominate the per-model differences; fixing any one
helps every model more than re-tuning constants.

1. **No oversampling around the nonlinearities → aliasing "digital fizz."**
   Original finding: all waveshaping (OD clip, every DIST clip, amp waveshaper)
   happened at 48 kHz. A static nonlinearity generates harmonics far above Nyquist that
   fold back as *inharmonic* aliasing — the metallic/fizzy edge that makes
   high-gain patches sound "digital" rather than like a real pedal/amp. Real
   analog circuits have no aliasing. **Implemented since then:** Metal/RAT/Big
   Muff gained 4x oversampling in D88-D90 and the base sample rate moved to
   96 kHz in D98. Remaining oversampling/new-stage ideas still need separate
   timing and bench acceptance.

2. **Memoryless waveshapers + one-pole filters → no frequency-dependent or
   dynamic clipping.** Real clipping interacts with reactive parts (feedback
   caps, Miller capacitance, tube grid conduction, bias shift, power-supply
   sag). Current clips are static `asymSoftClip` / `hardClip` with fixed
   one-pole pre/post filters. Missing: bias drift, sag/compression under load,
   and frequency-dependent saturation (bass distorts differently from treble).

3. **Tone controls are one-pole LPF/tilt approximations, not the real passive
   tone-stack transfer functions.** The defining EQ shapes — the TS ~720 Hz
   mid hump, the Big Muff mid *notch*, the Fender/Vox/Marshall stacks' very
   different scoop/peak curves — are 2nd-order resonant shapes a one-pole tilt
   cannot make. This is why models in the same family sound "samey."

4. **Per-model differentiation is by knee/gain constants only, not by clip
   *shape*.** Op-amp soft clip, Si diodes, Ge diodes, LEDs, MOSFETs, and tube
   grid conduction differ in **knee hardness and harmonic order**, not just at
   what level they engage. Today all OD models share one `asymSoftClip` curve
   (only knees differ); all the harder DIST pedals share `hardClip`. A
   per-model "hardness" parameter (curve exponent) would separate them far more
   convincingly than more knee retuning.

5. **Cab is a 4-tap pseudo-IR, not a real impulse response.** 4 taps can do a
   gentle tilt + one body bump; it cannot reproduce the comb-filtering, cone-
   breakup peaks (~1–4 kHz), and sharp >5 kHz rolloff that *are* a guitar cab.
   **A real short IR (128–256 taps) via BRAM convolution is the biggest cab
   realism gain** and the project already uses BRAM (Reverb), so the pattern
   exists.

6. **Mono only.** No stereo cab/mic, no dual-mic blend, no room. Out of scope
   for tone-match but worth noting for "in the room" realism.

---

## 1. Overdrive (dedicated OD effect — `Overdrive.hs`)

Structure: `mul(drive) → boost → asymSoftClip(kneeP,kneeN) → tone tilt → level
(softClipK safety)`. Per-model **only** the four constant tables differ:
`odDriveK`, `odKneeP`, `odKneeN`, `odSafetyKnee`. One shared clip shape, one
shared one-pole tone tilt for all six.

| Model | Real character | Current DSP | Gap → how to close |
| --- | --- | --- | --- |
| **TS9 / TS808** (0) | Op-amp soft clip *inside* the feedback loop + the signature ~720 Hz **mid hump** and a firm input low-cut. The mid hump is the whole identity. | `odDriveK 4`, near-symmetric soft knees (2.95M/2.85M), generic tone tilt. | **Missing the mid hump + input low-cut entirely** (those live only in the DIST `tube_screamer`, not here). Add a mid-band pre-emphasis (band-pass-shaped boost) + stronger input HPF; keep soft symmetric clip. |
| **OD-1** (1) | 3-diode **asymmetric** clip (2 vs 1) → strong even harmonics; simpler/cruder than TS. | `odDriveK 5`, asym 2.55M/1.75M. | Direction correct (asym captured). Could add a touch of upper-mid grit; otherwise reasonable. |
| **BD-2** (2) | JFET + diode hybrid; transparent until pushed then "tube-like," bright, dynamic. | D62-tuned: `k 7`, strong asym 2.4M/1.9M, extra headroom. | Good asym/even-harmonic colour. Gap: real BD-2 is notably **brighter** and more dynamic — add a brighter post-tilt and more pick-dynamic range (the static clip flattens dynamics). |
| **Jan Ray** (3) | Low-gain "transparent," TS-derived but higher headroom, flat-ish mids, slight low-mid warmth. | `k 2`, near-transparent 3.6M/3.45M. | Close. Add a slight low-mid warmth tilt; currently a bit featureless. |
| **OCD** (4) | **MOSFET** clipping → harder knee, amp-like, open, upper-mid honk; HP/LP voicing switch. | `k 7`, 2.45M/2.15M soft-clip approximation. | Soft clip misses the **harder MOSFET knee** and the upper-mid honk → per-model clip *hardness* + an upper-mid peak. |
| **Klon / CENTAUR** (5) | **Clean-blend**: mixes an unclipped clean path with a germanium hard-clipped path. Its transparency *is* the parallel clean signal. | `k 4`, single soft-clip path 3.1M/2.9M — **no clean blend**. | Biggest single-model gap: add the **parallel clean + clipped blend** (the Klon's core mechanism). Without it this is just another soft OD. |

OD-wide: per-model clip *shape* (hardness exponent) and per-model tone shaping
(not one shared tilt) would separate the six far more than further knee tuning.

---

## 2. Distortion pedalboard (`Distortion.hs`, 7 pedals)

Each pedal is its own multi-stage block (HPF → drive → clip → tone/LPF →
level). Exact stages/constants are in `Distortion.hs` and summarised in
`REAL_PEDAL_VOICING_TARGETS.md`.

| Pedal | Real character | Current DSP | Gap → how to close |
| --- | --- | --- | --- |
| **Clean Boost** | Transparent EP-style volume push; clips only when hot. | gain `256+drive*4` + soft safety. | Fine. Minor: very high drive can clip — already noted. |
| **Tube Screamer** | Input low-cut, op-amp soft clip, **~720 Hz mid hump**, post-LPF. The mid hump is the sound. | HPF + asym soft clip + one-pole post-LPF. | Documented gap: **mid hump washed out** (one-pole LPF can't make a resonant mid peak) + low-cut gentle. Add a band-pass mid emphasis (biquad) for the hump. |
| **RAT** | LM308 op-amp huge gain + **Si diode hard clip to ground** + passive "filter" LPF. | HPF → drive → hard clip (drive-dep threshold) → LPF → tone. | Closest of the bunch (hard clip matches). Gap: aliasing at high gain (oversampling); the exact op-amp gain curve. |
| **DS-1** | Transistor boost + op-amp + **asymmetric Si diode *hard* clip** + scooped tone stack. | HPF → drive → **soft** clip 2.4M/2.0M → tone. | Documented gap: real DS-1 is **diode hard clip** → harder/edgier than the soft approximation; also missing the scooped tone-stack shape. Use a harder asymmetric clip + scoop. |
| **Big Muff** | 4 transistor stages, **two cascaded diode clip stages**, and the signature **mid-scoop notch** tone network. | pre-gain → 2 cascaded soft clips → dark one-pole LPF → level. | Sustain captured; **mid-scoop notch missing** (the Muff's identity) — a one-pole LPF only darkens, it can't notch the mids. Add a mid-notch (biquad) tone. |
| **Fuzz Face** | 2-transistor (Ge/Si), massive **input-impedance interaction**, bias starving, **cleans up with guitar volume**, very touch-sensitive, asymmetric, Ge sputter/gate at low input. | pre-gain → asym soft clip 1.9M/1.4M → tone. | Asymmetry captured; **dynamic bias/impedance interaction + volume cleanup + Ge sputter missing** (documented). These need an input-level-dependent bias term, not just a static clip. |
| **Metal (MT-2)** | Two high-gain stages + **parametric mid EQ** (the famous scoop/boost) + tight low-cut. | HPF → high gain → hard clip → post-LPF. | Tight/hard captured; **the parametric mid character is missing** (fixed one-pole tone). Add a sweepable mid band; oversample to kill ice-pick alias fizz. |

DIST-wide: same two levers as OD — oversampling (RAT/DS-1/Metal/Muff benefit
most) and real resonant tone stacks (TS hump, Muff notch, DS-1/Metal scoop).

---

## 3. Amp Sim (`Amp.hs`, 6 models)

Structure (verified from `Amp.hs`): `input HPF → drive (shared gain
128+INPUT_GAIN*9, ~1..19×) → asym-clip stage 1 (ampWaveshapeFrame) → per-model
pre-LPF darken → second gain + asym-clip stage 2 (ampSecondStageFrame) →
3-band tone (difference-filter low/mid/high, per-band gains + per-model treble
trim) → power softClipK 3.4M → resonance+presence shelves (softClipK 3.4M,
per-model presence trim) → master softClipK 3.3M`. So it is **two cascaded
asymmetric soft-clip stages**, not one.

Per-model differentiation is **not** a per-model pre-gain or a fixed per-model
knee. Pre-gain is the *same* formula for every model (the INPUT_GAIN knob).
Models differ via the `ampCharForModel` intensity that feeds *computed* knees
plus several per-model trim tables (exact values in `Amp.hs` /
`AMP_MODEL_RESEARCH_D55.md`):
- `ampCharForModel` = 18 / 78 / 166 / 208 / 220 / 246 (JC→TriAmp)
- knees: `posKnee = 4_900_000 - char*7_000 (- driveDelta)`,
  `negKnee = 4_350_000 - char*6_200 (- driveDelta)` → higher char = earlier,
  harder, more asymmetric clip
- `ampModelDarken` 0/3/3/18/10/26, `ampPreLpfDriveDarken` 6/8/12/20/20/30,
  `ampSecondStageDriveBonus` 22/30/42/62/74/88, treble trim 0/2/2/9/8/14,
  per-model presence-trim divisors. DRV MODE (binary) shrinks knees further +
  adds the second-stage bonus + extra darken.

| Model | char | Real character | Gap → how to close |
| --- | --- | --- | --- |
| **JC-120** (0) | 18 | Roland solid-state: ultra-clean, huge headroom, slightly scooped, glassy. | Clean captured (low char = barely clips). Gap: the always-on asym waveshaper still colours a signal the real JC clean channel leaves hi-fi; a true-clean path at char≈0 would be more faithful. (Chorus out of scope.) |
| **Twin Reverb** (1) | 78 | Fender blackface: clean, **scooped mids**, big bass, sparkly top. | The blackface **mid scoop** is a specific FMV passive-stack shape; the difference-filter 3-band can tilt but not make that resonant scoop → real Fender tone stack (biquad). |
| **AC30** (2) | 166 | Vox Top Boost: **chimey upper-mid peak**, class-A **early breakup**, no NFB → loose, sag/compression. | Early breakup captured (high char, early knee). Missing the **chime peak (upper-mid resonance)** + **cathode-bias sag/compression** → add an upper-mid peak + dynamic sag. |
| **Rockerverb** (3) | 208 | Orange: thick low-mids, smooth high-gain. | Thick/dark captured (high darken 18, rounded treble trim 9). Reasonable; could add a low-mid body resonance. |
| **JCM800** (4) | 220 | Marshall: **mid-forward crunch**, Marshall FMV stack, presence, power-amp crunch/sag. | Mid-forward + presence captured (D67 retune). The **Marshall stack mid shape + power-amp sag/dynamic NFB** are static approximations → real Marshall stack + sag. |
| **TriAmp Mk3** (5) | 246 | H&K modern: very tight, high-gain, cascaded smoothness, tight low-cut. | Tightest/darkest (darken 26, treble trim 14, max presence trim). Add a tighter pre-gain low-cut; watch alias fizz at max gain (oversampling). |

Amp-wide levers (highest impact first): **(a) oversample the two clip stages**
(anti-alias high-gain models — chars 166–246 alias most); **(b) real
per-family tone stacks** (Fender vs Vox vs Marshall are fundamentally different
resonant curves, not one difference-filter 3-band with different gains);
**(c) power-amp sag + dynamic, frequency-dependent presence/resonance NFB**
instead of the current static shelves; **(d) bias-shift compression** for touch
response. Note D55/D58 history: per-model *proportional* (`ch*factor`)
multiplier deltas added DSP48 instances and the P&R shift caused a bypass-path
saturation noise — i.e. amp changes that add multipliers are timing-sensitive
on this island (relevant to oversampling/biquad cost).

---

## 4. Cab IR (`Cab.hs`, 3 models)

Structure (verified from `Cab.hs`): a **4-tap FIR** `[direct c0, early c1,
body c2, tail c3]` per model (`cabProductsFrame`), then a nonlinear
**speaker-compression** stage (`cabSatFrame`: per-model body-resonance
`softClipK` + presence `softClipK`), a **fizz-subtraction** stage (`cabIrFrame`:
subtracts an HF residual `input - mainDark`, per-model fraction), and a
final speaker-knee + dry/wet mix (`cabLevelMixFrame`, `cabSpeakerKnee`
5.6M/4.0M/2.8M). `AIR` picks one of 3 capped tap sets. So it is a bit more
than a bare FIR — but the *frequency response* is still set by only 4 taps.
Real tap sets (`cabCoeff`, AIR=mid): open `82/114/42/18`, british `46/106/76/32`,
closed `18/70/96/80` — i.e. open = bright direct-dominant, closed =
dark body-dominant.

| Model | Real character | Current DSP | Gap → how to close |
| --- | --- | --- | --- |
| **1x12 Open Back** | Extended but loose lows (leak out the back), smooth mids, airy. | brightest direct tap, some air. | 4 taps can't render the open-back low-end *looseness* or the cone-breakup texture → real IR. |
| **2x12 British** | Mid-forward, chime, Celestion peak ~3 kHz. | mid blend. | The Celestion presence peak + the comb-filter character are absent → real IR. |
| **4x12 Closed** | Big low-mid thump, pronounced ~3–5 kHz presence peak, **sharp >5 kHz rolloff**, strong cone breakup. | lowest direct tap, strongest body, darkest. | Directionally right (darkest/thickest) but the **presence peak + sharp rolloff + breakup peaks** need many more taps. |

Cab-wide: the 4-tap approach is the weakest link in the whole chain for
realism. **Replace with a real short IR (128–256-tap) BRAM convolution** —
this single change would (a) make the three models genuinely distinct, (b) tame
high-gain fizz far better than the current taps, (c) give the "speaker box"
feel that 4 taps fundamentally cannot. AIR as a high-shelf is a fine mic-
distance proxy; a mic-position/dual-mic blend would be the next step.

---

## 5. Prioritized recommendations (impact vs FPGA cost)

Ranked by realism-per-effort as of 2026-06-01. **Historical menu:** several
items are now implemented or partially implemented; see D81-D90 and D121-D131.

| # | Change | Impact | Cost / risk |
| --- | --- | --- | --- |
| 1 | **Real short-IR cab convolution (BRAM, 128–256 taps)** | Very high (cab + tames all high-gain fizz + model distinctness) | Medium: BRAM convolution MAC chain; BRAM available (Reverb). Adds DSP/timing. |
| 2 | **2×–4× oversample the clip/waveshaper stages** | Very high (kills digital fizz on every OD/DIST/AMP) | Partially implemented: Metal/RAT/Big Muff are 4x oversampled, base fs is now 96 kHz, and the island is 33.33 MHz. Remaining clip/amp oversampling still needs D109 CDC/timing/bench review. |
| 3 | **Per-family resonant tone stacks (biquads): TS hump, Muff notch, Fender/Vox/Marshall stacks** | High (fixes "samey" models; restores signature EQ) | Medium: biquads add DSP + state; one shared biquad reused per stage keeps it bounded. |
| 4 | **Per-model clip *hardness* (curve exponent), not just knee** | Medium-high (separates diode/MOSFET/op-amp/tube character) | Low-medium: constants + one shaping op; cheapest big differentiator. |
| 5 | **Klon clean-blend + Fuzz Face / amp dynamic bias-sag** | Medium (nails two iconic, currently-missing behaviours) | Low-medium: a parallel blend (Klon) and an input-level bias term. |
| 6 | **Constant re-tune within current structure** (knees, alphas, mid emphasis) | Low-medium (incremental) | Low: the path the project has used so far (D62/D67/D68…); diminishing returns vs items 1–4. |

### Sequencing note
Items 1–3 add DSP to an island that is already at the WNS edge. A realistic
order is: first recover/!budget timing headroom (the D75 island gave margin;
phys_opt in D78 helped), then land **item 4** (cheap, high differentiation) and
**item 5** (cheap, iconic), then attempt **item 1 (cab IR)** as its own phase
with a fresh timing review, and treat **item 2 (oversampling)** as a larger
research phase of its own. Each is a separate bitstream + WNS-vs-baseline +
bench-audio gate (the bitcrusher history says静的タイミングだけでは不十分 —
always bench-audition).

---

## Out of scope / not done
- No DSP changes, no Clash edits, no rebuild — analysis only.
- Exact current constants are in the cited `.hs` files; this doc does not
  duplicate them (and must not drift from them).
- Stereo / chorus / room modelling not considered beyond a mention.
