# Reference alignment findings (executing REAL_HARDWARE_REFERENCE_ALIGNMENT_PLAN.md)

Status: **reference -> measurable-target translation done, measurement vs target
documented, NO implementation** (2026-06-14). Executes the measurement matrix +
reference-to-target step of `REAL_HARDWARE_REFERENCE_ALIGNMENT_PLAN.md` using the
user-supplied links. Current canonical baseline = **D125** (`3382ed56`).

Method: each user link was fetched and reduced to concrete circuit numbers
(Hz / dB / gain / clip voltage), then compared against the actual current Clash
constants (read from `Overdrive.hs`, `Distortion/Pedals.hs`, `Distortion/Rat.hs`,
`Amp.hs`) and the offline measurements (`REALISM_OD_DIST_MEASUREMENT.md` +
tone-sweep net curves run for this pass). No GPL code / schematic coefficient
tables copied — public measurements + topology only (per plan ground rules).

## Extracted real-hardware targets (from the supplied links)

| Pedal | Concrete facts extracted |
| --- | --- |
| **RAT** (cushychicken LTSpice) | LM308 gain `1 + Rgain/(560\|\|47) ~= 2300x (~67 dB)`. Si diodes D2/D3 hard-clip to **±0.65 V**. Mid emphasis ~**1 kHz**; LM308 **slew-rate rolls off >1 kHz progressively as gain rises** (high drive is NOT a full-band square). FILTER pot (R17) is a passive LPF whose corner moves DOWN to **475 Hz** fully clockwise (max ~32 kHz fully CCW). Input HP is AFTER the diodes (C10/R10), not before gain. |
| **TS9 / TS808** (cushychicken + known RC) | Emitter-follower buffer; op-amp non-inverting gain `1 + 500k_drive/(51k\|4.7k)`; **0.047 µF + 4.7 k feedback HP ~720 Hz bass-cut before clipping** = the mid focus; symmetric soft-clip diode pair in the feedback; `0.047 µF/4.7 k` snubber rolls off **>~12 kHz**; TONE = passive LPF after clipping. |
| **BD-2** (pedalpcb breadboard pt1 + GPV) | 1st gain stage: **R5/C4 bass rolloff starting 700 Hz**, **peaks 2-3 kHz**, max **~40 dB (100x)**. **Stock ground-clip diodes are essentially inactive** (stage saturates before diodes conduct -> distortion is FET/op-amp saturation). 2nd stage **~40 dB, flat 100 Hz-6 kHz**. A network **cuts treble >1 kHz by 6 dB before TONE**. TONE: **min = mid-focus ~750 Hz; noon ~flat (only -3 dB @ 100 Hz); max = treble-booster rising slope**. Even + odd harmonics; clean at low GAIN -> strong overtones at high GAIN. C mode (BD-2w) = +3 dB 200-900 Hz. |
| **SD-1** (GPV; the supplied "OD-1" link is actually SD-1) | **Asymmetric clip** (top half taller/different shape) -> even harmonics + octave the TS lacks. **Mid peak MOVES with TONE: ~500 Hz (min) -> ~1000 Hz (noon) -> ~1500 Hz (max)**; significant mid boost with rolled highs+lows at all settings. EQ otherwise similar to TS. |
| **DS-1** (GPV + boss.info) | Distortion even at min DIST; **op-amp + diode HARD clip**; **odd harmonics ~2x the even**. At 10:30 tone: **~3 dB mid scoop 500 Hz-2 kHz + ~3 dB bass dip 50-300 Hz**. Min tone: **peak ~500 Hz then 6 dB/oct rolloff >1 kHz**. TONE = **tilt EQ (flat ~10:30), max tone extremely bright** (arguably too bright on the real unit). |
| **Centaur/Klon** (ChowCentaur) | Dual path: **always-present clean blend + germanium soft-clipped path**; GAIN raises the clipped proportion; transparent (low THD) with a treble/tilt tone; the transparency IS the parallel clean signal. |
| **Fender Bassman 5F6-A** (DAFx-16 WDF) | 12AY7 dual-channel preamp -> 12AX7 voltage amp (**gain -20.7 max**) -> 12AX7 cathode follower (**~0.984**, decouples the tone stack) -> **tone stack as a separate linear block** (Fender mid-scoop network). **Grid current -> asymmetric clipping -> strong even harmonics** ("models that ignore grid current can't reproduce an overdriven preamp"); positive excursions flatten first. Open-back 4x10 Jensen. |
| **Marshall JTM45 / DDSP amp** (arxiv 2408.11405 + DAFx) | JTM45 vs Bassman: **higher-gain 12AX7**, **extra bright-cap CB2 -> more bright-channel treble boost**, **plate V 325->310 (more compression/sag)**, **closed-back 4x12 Celestion**. DDSP grey-box: **Wiener-Hammerstein preamp (linear -> static NL -> linear)** with **state-dependent (dynamic-bias) asymmetric NL**, **tone stack right after preamp (low-shelf + peak + high-shelf)**, **push-pull power amp + presence + global NFB**, **output transformer with hysteresis memory + LF bandpass compression**. |

## Per-model: current DSP vs target vs gap

### RAT (`Distortion/Rat.hs`, post-D124)

- Current: live one-pole input HP ~150 Hz (D124); `driveGain = 640 + ctrlC*12`
  (~2.5x..~5x post `>>8`); 4x-oversampled hard clip, `ratClipThreshold =
  6_000_000 - amount*8500` (min 2.2M); `ratOpAmpLowpass alpha = 120 - drive-dep`;
  `ratPostLowpass` FIXED `onePoleU8 106`; `ratTone alpha = 128 - ctrlA>>1`.
- Measured (D124): mid-forward peak ~720 Hz, THD ~24% @ drive 55, FILTER works
  (tilt -5.3/-10.0/-39.3 at FILTER 0/50/100).
- **Gaps vs target**: (1) the op-amp LPF / post-LPF is only weakly drive-dependent;
  the real LM308 **darkens MORE as gain rises** (slew limit) — our high-drive tone
  does not darken enough, risking fizz the real RAT avoids. (2) FILTER fully-up
  corner should bottom near **~475 Hz**; verify `ratTone` min corner reaches that
  region (currently `alpha=128-127=1` ~ very dark, likely OK, measure to confirm).
- **Candidate (low risk, coeff-only)**: make `ratOpAmpLowpassFrame` /
  `ratPostLowpassFrame` alpha **drive-dependent** (more drive -> lower corner) to
  emulate LM308 slew darkening; keep FILTER law, just calibrate the min corner.
  Plan rank 4.

### TS9 (`Overdrive.hs` model 0)

- Current: `+6 dB @ 720 Hz Q0.8` pre-clip biquad; `asymSoftClipSoft`
  near-symmetric knees (2.95M/2.85M); `odDriveK 4`.
- Measured: peak +5.3 @ 720 Hz, THD 24% odd-dominant. **On-target** vs the
  720 Hz/soft-symmetric target.
- Gap (minor): OD model 0 has **no explicit input HP** (the 720 Hz bass-cut is
  approximated by the peak biquad, not a true low-cut). Real TS cuts lows before
  clip. Low priority; the pedalboard `tube_screamer` has the real HP if needed.

### BD-2 (`Overdrive.hs` model 2)

- Current: `+3.5 dB @ 2300 Hz Q0.7` pre-clip biquad; strong asym
  (kneeP 2.4M / kneeN 1.9M = 500k gap -> most even-harmonic of the lineup);
  hardness 1; `odDriveK 7` (~40 dB-class, matches the two ~40 dB stages).
- Reference reconciliation: the **fixed 2300 Hz peak correctly models the real
  1st-stage 2-3 kHz peak** that shapes what gets clipped, and the strong asym
  matches the FET/op-amp even-harmonic character. **GOOD alignment.**
- **Gap**: real BD-2 **NOON is ~flat** (only -3 dB @ 100 Hz) and the brightness
  is delivered by **TONE max (a rising treble slope)**, not baked in; our biquad
  applies the 2300 Hz lift unconditionally so BD-2 is always bright. Also the
  real **-6 dB >1 kHz pre-TONE** network + the 700 Hz bass rolloff are not modeled.
- **Candidate (low risk)**: leave the pre-clip 2300 Hz peak (it drives the clip
  correctly); optionally add a gentle ~700 Hz input bass rolloff and let the OD
  TONE control span flat-noon -> bright-max. Plan rank 5 (only if bench flags it).

### OD-1 vs SD-1 (`Overdrive.hs` model 1) — DECISION NEEDED

- Current: **FLAT** pre-clip biquad (no mid peak); asym knees 2.55M/1.75M (strong
  asym -> even harmonics, odd/even +6.8 measured = asymmetric, "mild").
- The supplied link is **SD-1**, whose defining trait is a **mid peak that MOVES
  500 -> 1000 -> 1500 Hz with TONE**. Our model 1 has NO mid peak at all.
- **If target = SD-1**: biggest gap in the whole OD lineup. Candidate: fill the
  model-1 row of the EXISTING `odMidFeedforward/FeedbackCoeffs` mux with a mid
  peak. **Low-risk first step = fixed +mid peak ~1 kHz**; the true **tone-dependent
  moving peak (500-1500 Hz)** is a larger change (tone-indexed coeff mux). Plan
  rank 2.
- **If target = OD-1** (the actual OD-1 predates SD-1, has SYMMETRIC clipping):
  then our strong asym (1.75M neg) is wrong-direction and model 1 should be more
  symmetric + stay flat. **The user must pick OD-1 or SD-1** (plan rank 1) — the
  two imply opposite changes.

### DS-1 (`Distortion/Pedals.hs` ds1*)

- Current: `asymSoftClip` SYMMETRIC knees 1.9M/1.9M (SOFT, not hard); no mid
  scoop; `ds1Tone alpha = 59 + tone>>1` (LPF, brighter than TS); `odDriveK 9`.
- Measured: THD 22% odd-dominant, bright. On-target for "aggressive + HPF in",
  but the **reference DS-1 has a ~3 dB mid scoop 500 Hz-2 kHz** our model lacks,
  and uses **hard** clip (we use soft = a known compromise).
- **Candidate (medium)**: add a **shallow ~-3 dB scoop biquad centered ~1 kHz**
  (broad, Q~0.7) on the DS-1 path. NOTE the Big Muff/Metal already share a
  -10 dB @ 700 Hz scoop biquad — DS-1's is **shallower and higher-centered**, so
  it likely needs its OWN coeff row, not the shared deep notch. Tone-as-tilt and
  hard-clip conversion are separate, larger candidates (measure independently).
  Plan rank 3 (only if bench says DS-1 too flat/soft).

### Klon (`Overdrive.hs` model 5)

- Current: clean-blend (floor 64, cap so clean never < ~6%), germanium knees,
  hardness 1. Measured THD 3% transparent. **On-target** vs the dual-path target.
  No change. Do not import ChowCentaur code.

### Amp (Fender + Marshall) — last phase, measure-only here

- Current `Amp.hs`: per-model ampScoop biquads (JC-120 -2 dB@400, Twin -5@400,
  AC30 +4@2200, JCM800 +4@650, Rockerverb +3@300, TriAmp -6@750 — D122),
  cascaded always-on soft clips, power sag (tube-only), transformer LF/HF,
  multiband saturation, input differentiator HP.
- Reference alignment (architecture, not a rewrite):
  - **Fender**: the WDF paper confirms the wanted structure = preamp NL ->
    cathode follower -> **separate tone stack** -> power amp; grid-current
    **asymmetric clip -> even harmonics**. Our amp already has asym clip +
    separate scoop biquads. For Fender models prioritize **mid-scoop accuracy +
    clean headroom** over more clipping (D122 JC-120/Twin already accepted).
  - **Marshall**: JTM45/DDSP says higher gain + **bright-cap treble boost** +
    **lower plate V = more compression/sag** + closed-back 4x12. Our JCM800 has
    the mid push; a measured candidate is a small **bright-channel treble lift**
    and confirming the **transformer LF compression** on JCM800/TriAmp. The
    DDSP "dynamic-bias state-dependent NL" maps to our existing fuzz-style
    dynamic-bias idea — a small **bias-memory** on the amp is the interpretable
    way to add feel WITHOUT a neural net.
- **Constraint**: amp has heavy bench-rejection history (sag removal/static-trim
  rejected). Touch one model at a time, only after Cab/OD/Dist/dynamics are
  stable, and only with explicit user direction (plan rank 6, high risk).

## Tone-sweep confirmation (measured, drive 60, net peak vs bypass)

| model | TONE 0 | TONE 50 | TONE 100 | vs real-HW |
| --- | --- | --- | --- | --- |
| **OD-1/SD-1 (m1)** | +1.0 @200 | **+0.0 (no peak)** | +0.0 @3276 | **FLAT — no mid peak at any tone.** SD-1 needs a moving 500-1500 Hz peak -> biggest OD gap (confirms rank 2). |
| **BD-2 (m2)** | +1.0 @200 | +2.3 @2197 | +2.4 @2197 | Peak at 2197 Hz (= the 2-3 kHz 1st-stage peak), darkens at low TONE. Roughly aligned; real min-tone focus is ~750 Hz (minor). |
| **TS9 (m0)** | +1.0 @200 | +3.9 @663 | +3.8 @663 | Peak ~663 Hz (= 720 Hz hump target), darkens at low TONE. On-target. |

(net peak amplitudes here read lower than the gap-32 harmonic pass because this is
a fast gap-8 / 16-tone confirmation run; the relative which-model-has-a-peak-where
pattern is what matters. Model 1 reading +0.0 = literally no resonant peak.)

The measurement confirms the reference-derived priority: **Overdrive model 1 is
flat and has no mid character**, so if it is meant to be SD-1 it is the clearest
gap in the drive lineup.

### DS-1 scoop + RAT FILTER (measured)

- **DS-1 (tone 50, drive 65), net 400-2200 Hz**: 452:-1.7, 564:-0.8, 703:-0.1,
  877:+0.4, 1094:+0.7, 1365:+1.0, 1703:+1.1, 2124:+1.1 — a gentle **rising tilt,
  NO mid scoop** (the band minimum -1.7 is just the low edge). The real DS-1's
  **~3 dB scoop in 500 Hz-2 kHz is absent** -> confirms rank 3 (add a shallow
  ~-3 dB scoop ~1 kHz; it must be its OWN coeff row, not the Big Muff/Metal deep
  -10 dB @ 700 Hz notch).
- **RAT FILTER**: treble at 8 kHz sits ~-9 dB (vs peak) at FILTER low and ~-26 dB
  at FILTER high, so the FILTER clearly rolls off treble and the corner moves
  down as expected. NOTE: this quick check used out-of-range filter bytes
  (128/255 both clamp), so the precise "does the corner reach ~475 Hz fully up"
  question needs a proper FILTER 0..100 sweep before promoting rank 4. The
  treble-rolls-off-with-gain (LM308 slew) trait is the more certain rank-4 gap.

## Updated candidate ranking (measurement + reference backed)

| Rank | Candidate | Evidence | Risk |
| --- | --- | --- | --- |
| 1 | **Decide OD-1 vs SD-1** for Overdrive model 1 | Opposite changes (asym+moving-peak vs symmetric+flat); supplied link is SD-1. | None until chosen (doc/label). |
| 2 | **Model-1 mid peak** (if SD-1): fixed +mid ~1 kHz first, moving 500-1500 Hz later | GPV SD-1 moving peak; model 1 is flat now. | Low (reuse OD biquad mux). |
| 3 | **DS-1 shallow ~-3 dB mid scoop ~1 kHz** | GPV/boss.info 3 dB scoop 500-2k; model lacks it. | Medium (own coeff row; affects level/harshness). |
| 4 | **RAT drive-dependent darkening + FILTER 475 Hz calibration** | LM308 slew rolloff >1 kHz with gain; FILTER bottoms 475 Hz. | Low (coeff-only in existing frames). |
| 5 | **BD-2 flat-noon / treble-max tone + 700 Hz input rolloff** | pedalpcb: noon flat, bright from TONE, 700 Hz rolloff, -6 dB>1k. | Low (tone-law only; measured on-target so optional). |
| 6 | **Marshall bright-cap lift + transformer LF compression check** (amp) | JTM45 bright cap + lower plate V. | High (amp history; one model at a time). |

## Hard constraints reaffirmed (plan ground rules)

No new GPIO / topEntity port / `block_design.tcl` edit / C++ / NN inference /
exact WDF / imported ChowCentaur source. Any DSP edit still needs Clash regen +
Vivado + timing + deploy + programmatic smoke + **user ear-bench**. A model that
measures on-target stays untouched unless a bench reports a specific audible gap.

## Ready implementation spec (when authorized — NOT YET IMPLEMENTED)

Pre-computed 96 kHz RBJ Q14 coefficients so the top candidates are one edit away
once the user authorizes. NOT applied; no bitstream built. All bypass-exact
(unity outside the shaped band by construction).

### Rank 2 — SD-1 (Overdrive model 1) mid peak

Format matches `odMidFeedforwardCoeffs (b0,b1,b2)` and `odMidFeedbackCoeffs
(a1,a2)` (where stored `a1 = b1`, the negative value; the recursive frame does
`- mulS16 y1 a1`). Lowest-risk = the FIXED noon peak (one coeff row, like the
D121 OCD addition):

- **Fixed +5 dB @ 1000 Hz, Q 0.7**: `odMidFeedforwardCoeffs 1 = (16816, -31591,
  14843)`; `odMidFeedbackCoeffs 1 = (-31591, 15275)`.
- Optional later **tone-dependent moving peak** (matches the real SD-1
  500->1000->1500 Hz sweep; needs a tone-indexed coeff mux, bigger change):
  - low  (+5 dB @ 500 Hz,  Q 0.8): ff `(16577, -32256, 15697)`, fb `(-32256, 15889)`
  - high (+5 dB @ 1500 Hz, Q 0.8): ff `(16944, -31178, 14385)`, fb `(-31178, 14945)`

NOTE: if the user instead says model 1 is **OD-1** (not SD-1), do the OPPOSITE —
keep it flat and make the clip more SYMMETRIC (raise `odKneeN 1` from 1_750_000
toward `odKneeP`), since the true OD-1 uses a symmetric clipper. Decide first.

### Rank 3 — DS-1 shallow mid scoop

DS-1 lives in `Distortion/Pedals.hs` (pedal-mask path), not the OD mux, so this
needs its OWN feedforward+recursive biquad stage (same split shape as
`bigMuffScoopFeedforwardFrame`/`bigMuffScoopRecursiveFrame`, but DS-1-only gate
and shallower/higher coeffs — do NOT reuse the Big Muff -10 dB @ 700 Hz notch):

- **-3 dB @ 1000 Hz, Q 0.7**: feedforward `ff = mulS16 x 16132 + mulS16 x1
  (-30978) + mulS16 x2 14912`; recursive `y = satShift14 (fAcc3L f + mulS16 y1
  30978 - mulS16 y2 14660)`.

Adding a new biquad stage costs Pipeline state + DSP; measure timing on the DS-1
island path (the tight one) before committing — a peaking biquad is cheap (the
D121 cab/OD adds cost ~nothing) but DS-1 shares the critical path.

## Next concrete step (when implementation is authorized)

The single highest-value, measurement-backed first move is **rank 1 -> rank 2**:
confirm model 1 should be SD-1, then drop the fixed `+5 dB @ 1000 Hz` row above
into the existing Overdrive pre-clip biquad mux (model 1), measure the harmonic +
net curve in `tools/dsp_sim`, then Vivado build + deploy + ear-bench. Everything
else stays measure-first; one candidate per bitstream/bench.
