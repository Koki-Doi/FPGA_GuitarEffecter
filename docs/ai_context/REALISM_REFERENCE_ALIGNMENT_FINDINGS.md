# Reference alignment findings (executing REAL_HARDWARE_REFERENCE_ALIGNMENT_PLAN.md)

Status: **historical findings, implemented across D126-D131** (updated
2026-06-15). This document executed the measurement matrix + reference-to-target
step of `REAL_HARDWARE_REFERENCE_ALIGNMENT_PLAN.md` using the user-supplied
links. It is no longer "NO implementation": D126/D127 implemented the first
OD-1 / DS-1 / RAT / JCM800 alignment pass, D128-D130 continued Amp and
OD/DS/RAT re-collation, and D131 added DIST low-end / saturation / sustain plus
distortion-eval tooling. These findings are historical inputs to later passes;
the current canonical baseline is **D135** (`765323b`, bit
`533d586901dc3669285a49c6d82bab9f`). D144's chord-detune candidate was
bench-rejected and rolled back to D135.

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

### OD-1 (`Overdrive.hs` model 1) — RESOLVED: user chose OD-1 (2026-06-14)

**CORRECTION** (an earlier draft of this doc wrongly said OD-1 is symmetric): the
BOSS OD-1 uses **ASYMMETRIC clipping** (the 2+1 diode arrangement = even harmonics)
and has **NO tone control**. The symmetric clipper is the Tube Screamer. OD-1 and
SD-1 share the asymmetric clipper; the SD-1 just adds the tone control (which is
what produces the SD-1's moving 500-1500 Hz mid peak). So:

- Current model 1: **FLAT** pre-clip biquad; asym knees 2.55M/1.75M (strong asym);
  measured THD 20.9%, odd/even +6.8 (= asymmetric, even harmonics present, mild).
- **Against the OD-1 target this is already well-aligned**: asymmetric soft clip
  (correct), mild gain (correct), no tone-control moving peak (correct — OD-1 has
  no tone control). The SD-1 mid-peak candidate is **DROPPED** (not OD-1).
- **Only optional refinement**: the real OD-1 is not dead-flat — it has a *gentle*
  mid focus (~700-900 Hz), much milder than the TS9's +6 dB hump. Our model 1 is
  dead flat. An OPTIONAL low-impact tweak is a gentle mid peak (pre-computed
  below). This is cosmetic; the OD-1's identity is the asym clip, which we have.
- **Recommendation**: model 1 is essentially on-target for OD-1. Apply the gentle
  mid focus only if a bench wants it more mid-voiced; otherwise leave model 1
  unchanged (no bitstream cost).

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
| ~~1~~ | ~~Decide OD-1 vs SD-1~~ — **RESOLVED: OD-1.** Model 1 already aligned (asym clip); SD-1 mid-peak dropped. | User decision 2026-06-14. | done |
| 1 | **DS-1 shallow ~-3 dB mid scoop ~1 kHz** (now the top DSP candidate) | GPV/boss.info 3 dB scoop 500-2k; measured DS-1 has NO scoop (rising tilt). | Medium (own biquad stage on the tight DS-1 island; affects level/harshness). |
| 2 | **RAT drive-dependent darkening + FILTER 0..100 corner check** | LM308 slew rolloff >1 kHz with gain; FILTER bottoms ~475 Hz. | Low (coeff-only in existing frames). |
| 3 | **OD-1 optional gentle mid focus** (+2.5 dB @ 850 Hz) | OD-1 is mildly mid-voiced, model 1 is flat. Cosmetic. | Low; only if bench wants it. |
| 4 | **BD-2 flat-noon / treble-max tone + 700 Hz input rolloff** | pedalpcb: noon flat, bright from TONE, 700 Hz rolloff, -6 dB>1k. | Low (tone-law only; measured on-target so optional). |
| 5 | **Marshall bright-cap lift + transformer LF compression check** (amp) | JTM45 bright cap + lower plate V. | High (amp history; one model at a time). |

## Hard constraints reaffirmed (plan ground rules)

No new GPIO / topEntity port / `block_design.tcl` edit / C++ / NN inference /
exact WDF / imported ChowCentaur source. Any DSP edit still needs Clash regen +
Vivado + timing + deploy + programmatic smoke + **user ear-bench**. A model that
measures on-target stays untouched unless a bench reports a specific audible gap.

## Ready implementation spec (when authorized — NOT YET IMPLEMENTED)

Pre-computed 96 kHz RBJ Q14 coefficients so the top candidates are one edit away
once the user authorizes. NOT applied; no bitstream built. All bypass-exact
(unity outside the shaped band by construction).

### Rank 2 — OD-1 (Overdrive model 1): RESOLVED, optional gentle mid focus only

User chose **OD-1**. Model 1's asymmetric clip is already correct, so the SD-1
mid-peak (and the symmetric-clip alternative) are BOTH off the table. The only
optional tweak is a *gentle* mid focus (the OD-1 is mildly mid-voiced, not flat).
Format matches `odMidFeedforwardCoeffs (b0,b1,b2)` / `odMidFeedbackCoeffs (a1,a2)`:

- **+2.5 dB @ 850 Hz, Q 0.7** (gentle): `odMidFeedforwardCoeffs 1 = (16566,
  -31629, 15113)`; `odMidFeedbackCoeffs 1 = (-31629, 15294)`.
- **+2.0 dB @ 900 Hz, Q 0.6** (even gentler): ff `(16562, -31341, 14834)`,
  fb `(-31341, 15011)`.

Much milder than the TS9 +6 dB @ 720 Hz so OD-1 stays distinct from TS9. Apply
only if a bench wants model 1 more mid-voiced; otherwise leave model 1 flat
(it is on-target for OD-1 as-is). The asym knees (2.55M/1.75M) stay unchanged.

(The SD-1 coefficients are removed: SD-1 is not the chosen target.)

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

## D126 — pedal alignment pass IMPLEMENTED (deployed, bench PENDING)

User authorized "全部一気に" (do all the pedal candidates at once). D126 bundles
three measurement+reference-backed pedal changes (BD-2 left alone = on-target;
amp split out to its own isolated bench per the hard rule). All coeff/mux-only on
existing stages, bypass bit-exact, timing fully MET (WNS **+1.057**, island
+3.142, CDC pair +2.017/+6.476):

1. **OD-1 (model 1) gentle mid focus**: filled the model-1 row of the existing
   OD pre-clip biquad mux with +2.5 dB @ 850 Hz. Measured net peak +1.9 @ 877 Hz
   (was flat). Asym clip unchanged (OD-1 identity preserved).
2. **DS-1 mid scoop**: widened the existing Big Muff/Metal scoop biquad gate to
   include `ds1On`, with a coeff mux: DS-1 uses **-6 dB @ 1000 Hz Q0.7** (the
   Big Muff/Metal -10 dB @ 700 Hz coeffs are byte-identical, so those models are
   unchanged). NO new pipeline stage. Measured net dip ~-2.4 dB @ ~1 kHz (was a
   rising tilt with no scoop) = the real DS-1's "almost 3 dB" 500 Hz-2 kHz scoop.
   (-6 dB pre-figure because the DS-1's bright rising tilt buries a -3 dB notch.)
3. **RAT slew darkening**: `ratPostLowpassFrame` alpha is now DRIVE-dependent
   (`106 - drive>>2`) so high GAIN rolls off the top (LM308 slew). Measured 8 kHz
   net at drive 10/55/100 = -6.4 / -11.6 / -22.3 dB (drive 0 = byte-identical to
   D124). Tames high-gain fizz like the analog circuit.

bit/hwh md5 `a4db4b7b0f19c1a3aa37133b1eda35c6` / `9b33b40c56eea99cf40a3816c833f5ae`.
Deployed to PYNQ-Z2; 2 board sites md5-matched; PL-smoke OK. **Bench PENDING.**
Branch `feature/od1-ds1scoop-rat-realism`. Rollback to D125 via
`git checkout 4b2236e -- hw/Pynq-Z2/bitstreams/` + redeploy. **The amp (Marshall)
work is D127, a SEPARATE bitstream for an isolated amp bench (hard rule).**

## Next concrete step (when implementation is authorized)

OD-1 is resolved (model 1 already aligned — no change required). The next
measurement-backed DSP candidate is now **the DS-1 mid scoop** (rank 1): add a
DS-1-only `-3 dB @ 1000 Hz` peaking biquad (own ff+rec stage like bigMuffScoop,
coeffs in the spec above), measure the net scoop + THD in `tools/dsp_sim`, check
timing on the DS-1 island path, then Vivado build + deploy + ear-bench. One
candidate per bitstream/bench; everything else stays measure-first.
