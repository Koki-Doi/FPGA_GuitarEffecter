# Real hardware reference alignment plan

Status: **plan executed through D131; retained as reference-to-target map**
(updated 2026-06-15). This note records how the supplied pedal / amp references
were translated into measurable targets before changing Clash, VHDL, Python,
GPIO, Tcl, or bitstreams.

This document is a companion to `REALISM_IMPROVEMENT_WORK_ORDER.md`,
`REALISM_TARGET_METRICS.md`, `REALISM_OD_DIST_MEASUREMENT.md`, and
`MODEL_REALISM_IMPLEMENTATION_GUIDE.md`. Treat it as the reference-to-target
translation layer: public measurements and circuit writeups become measurable
DSP targets first, and only then become implementation candidates.

**Executed output: `REALISM_REFERENCE_ALIGNMENT_FINDINGS.md` plus D126-D131**
(updated 2026-06-15) —
the supplied links were fetched and reduced to concrete circuit numbers
(RAT 2300x/±0.65 V/FILTER 475 Hz; TS 720 Hz feedback HP; BD-2 700 Hz rolloff /
2-3 kHz peak / inactive diodes / 40 dB stages; SD-1 moving mid peak 500-1500 Hz;
DS-1 3 dB scoop 500 Hz-2 kHz + tilt tone; Klon dual path; Fender grid-current
asym + separate tone stack; Marshall JTM45 bright cap + lower plate V), compared
against the actual current Clash constants, and turned into a measurement-backed
candidate ranking. D126/D127 implemented the first OD-1 / DS-1 / RAT / JCM800
alignment pass; D128-D131 continued the amp, OD/DS/RAT, and DIST realism line.
Read `CURRENT_STATE.md`, `BASELINES.md`, and `DECISIONS.md` D126-D145 for the
accepted bitstream history and later rejected chord/amp-clean experiments.

## Ground rules

- Do not clone reference repositories into this repo.
- Do not copy reference source code or schematic-derived coefficient tables.
  Use the references for topology, tone-shape targets, control law, and
  measurement expectations only.
- Keep the existing architecture: Overdrive uses the six-model
  `overdrive_control.ctrlD[2:0]` selector; Distortion uses the pedal-mask
  independent-stage design. Do not reintroduce the rejected large
  `model_select` mux.
- Prefer offline `tools/dsp_sim` measurement before any bitstream-cost work.
- A model that already measures on-target stays untouched unless the user
  bench reports a specific audible gap.
- Any future DSP edit under `hw/ip/clash/src/LowPassFir.hs` or
  `hw/ip/clash/src/AudioLab/` still requires Clash regeneration, Vivado
  rebuild, timing review, deploy, programmatic smoke, and user ear-bench.

## Baseline status

This plan was first measured against **D124** (RAT live-pole highpass fix,
bench-ACCEPTED, merged). The current canonical deployed baseline is **D135**
(merge `765323b`, bit `533d586901dc3669285a49c6d82bab9f`). Relevant D124
facts at the time of this plan:

- OD 6 models were measured on-target in `REALISM_OD_DIST_MEASUREMENT.md`.
- Distortion / Fuzz models were measured on-target after the RAT fix.
- RAT was the only failed model before D124 because the highpass pole was dead;
  D124 makes it distort and restores the FILTER behavior.
- The user still considers overall effect completeness low, so future voicing
  passes are expected. This doc narrows those passes to specific, measured
  gaps rather than broad rewrites.

## Source map

| Target | Source | Use |
| --- | --- | --- |
| BD-2 / BD-2w | `https://guitarpedalsvisualized.wordpress.com/2022/03/08/boss-bd-2w/` | Tone knob shapes, overtone / waveform behavior, S vs C mode distinctions. |
| BD-2 / BD-2w | `https://forum.pedalpcb.com/threads/this-week-on-the-breadboard-blues-driver-bd-2-bd-2w-part-1.7390/` | Stage topology, 700 Hz first-stage bass rolloff, 2-3 kHz first-stage peak, inactive stock diode clippers, second-stage bandwidth. |
| BD-2 / BD-2w | `https://forum.pedalpcb.com/threads/this-week-on-the-breadboard-blues-driver-bd-2-bd-2w-part-2.7404/` | BD-2w S/C switch interpretation: tight / fat changes are subtle, C mode is mostly a small level / low-mid shift. |
| BD-2 / BD-2w | `https://forum.pedalpcb.com/threads/this-week-on-the-breadboard-blues-driver-bd-2-bd-2w-part-3.7419/` | Mod reference for tighter bottom end, FAT behavior, and bass-boost alternatives. |
| BD-2 / BD-2w | `https://forum.pedalpcb.com/threads/this-week-on-the-breadboard-blues-driver-bd-2-bd-2w-part-4.7544/` | Summary of practical BD-2-style mod directions; use only as target-shape guidance. |
| TS808 / TS9 | `https://cushychicken.github.io/ltspice-tube-screamer/` | Circuit sectioning: buffer, clipping stage, tone / volume stage; clipping-stage frequency behavior and tone LPF behavior. |
| TS808 / TS9 | `http://www.geofex.com/Article_Folders/TStech/tsxtech.htm` | Classic Tube Screamer technology reference; use for topology / control law cross-check. |
| OD-1 request ambiguity | `https://guitarpedalsvisualized.wordpress.com/2022/03/18/boss-sd-1/` | The supplied link is SD-1, not OD-1. Use it only if the target is SD-1-style asymmetrical clipping and moving mid peak. |
| DS-1 | `https://guitarpedalsvisualized.wordpress.com/2022/03/24/boss-ds-1/` | Tone shape, lower-mid scoop, overtone / waveform behavior, tone knob range. |
| DS-1 | `https://articles.boss.info/all-about-the-ds-1-the-benchmark-boss-distortion/` | Official high-level character: transistor + op-amp hard-clipping design, tilt EQ, lower-mid dip. |
| Centaur / Klon | `https://github.com/jatinchowdhury18/KlonCentaur` | Modeling strategy reference: WDF / RNN / circuit models. For this FPGA project, only the clean + clipped path concept is directly actionable. |
| RAT | `https://cushychicken.github.io/ltspice-proco-rat/` | LM308 high gain, diode hard clip, 1 kHz emphasis, simple RC FILTER law. |
| Fender / Bassman / JTM45 | `https://www.dafx.de/paper-archive/2016/dafxpapers/37-DAFx-16_paper_53-PN.pdf` | WDF case study, triode / grid-current behavior, Bassman and JTM45 topology differences. |
| Marshall amp modeling | `https://arxiv.org/html/2408.11405v1` | Grey-box amp modeling structure: preamp, tone stack, power amp, output transformer; use as architecture guidance, not as an NN implementation target. |

## Reference-to-target translation

### BD-2

Target traits:

- Wide gain range: clean at low gain, strong overtones at high gain.
- Significant even-harmonic content at medium gain.
- First gain stage cuts low end around the lower mids and peaks around
  2-3 kHz.
- Tone at noon is close to flat above the bass rolloff; tone minimum becomes
  mid-focused near 750 Hz; tone maximum rises like a treble boost.
- Stock ground-clipping diodes should not be treated as the main distortion
  source.

D124 status:

- `Overdrive.hs` model 2 already has strong asymmetric knees and a 2.3 kHz
  pre-clip peaking biquad.
- D121 / D124 measurements classify BD-2 as on-target.

Next measurement before any edit:

- `drive = low / 60 / max`, `tone = 0 / 50 / 100`.
- Check THD growth, odd/even ratio, net peak frequency, and high-frequency
  slope.
- If a gap remains, adjust only the BD-2 coefficient row in the existing
  `odMidFeedforwardCoeffs` / `odMidFeedbackCoeffs` mux or the tone law. Avoid
  reviving the rejected D61 structural/IIR approach.

### TS808 / TS9

Target traits:

- Low-cut before clipping.
- Soft clipping inside the main gain path.
- Strong mid focus around the classic TS region.
- Tone control mainly changes high-frequency rolloff after clipping.

D124 status:

- Dedicated Overdrive TS9 and pedalboard `tube_screamer` both already have
  720 Hz style mid-hump targets.
- Use TS as a calibration anchor rather than a rewrite target.

Next measurement before any edit:

- Fixed 1 kHz sine harmonic profile at the reference drive point.
- Multitone net curve for low-cut and 720 Hz hump.
- Tone sweep should darken / brighten without turning TS into DS-1 or RAT.

### OD-1 vs SD-1 ambiguity

The requested label says `OD-1`, but the supplied visual reference is `SD-1`.
These should not be silently conflated.

If the target is OD-1:

- Keep the current Overdrive model 1 mostly asymmetry-led and simple.
- Use even-harmonic ratio as the primary target.
- Do not add a strong moving tone peak without a new OD-1-specific reference.

If the target is SD-1:

- Use the GPV SD-1 target: every tone setting remains mid-focused, with the
  peak moving roughly from lower mids to upper mids as TONE rises.
- Current model 1 is too flat for this interpretation.
- Candidate future edit: fill model 1 in the existing Overdrive pre-clip
  biquad mux with a modest tone-dependent or fixed mid peak. A fixed 1 kHz
  target is the lowest-risk first step; tone-dependent peak movement is a
  larger change.

Decision needed before implementation: whether Overdrive model 1 should remain
`OD-1` or be explicitly treated as `SD-1`.

### DS-1

Target traits:

- Distortion, not overdrive: already distorted even at low DIST settings.
- Hard-clipping character from transistor + op-amp design.
- No TS-style mid hump; instead a lower-mid scoop / dip is part of the sound.
- Tone control is closer to a low/high tilt than a simple treble cut.
- Tone max can be extremely bright, but the real circuit still has anti-fizz
  limits before the tone control.

D124 status:

- Pedal-mask `ds1` measures on-target in `REALISM_OD_DIST_MEASUREMENT.md`.
- The current Clash implementation still uses a soft-clip approximation, which
  is a known fidelity compromise.

Next measurement before any edit:

- At low / mid / high DIST, verify that THD is already present and does not
  grow like a clean overdrive.
- Measure scoop depth around 500 Hz-2 kHz and brightness at tone max.
- If the bench says DS-1 is too soft, the smallest candidate is a clip-helper
  retune inside `ds1ClipFrame`; a scoop / tilt implementation is a separate
  candidate and must be measured independently.

### Centaur / Klon

Target traits:

- The sound is not just a soft overdrive; it is a clipped path blended with an
  always-present clean path.
- Low-to-moderate THD at typical settings is acceptable and expected.
- Output level and transparent push matter as much as distortion amount.

D124 status:

- Overdrive model 5 already has the clean-blend path in `Overdrive.hs`.
- D124 measurement classifies Klon as transparent / on-target.

Next measurement before any edit:

- Sweep DRIVE and confirm the clean contribution never disappears.
- Check THD remains lower than DS-1 / RAT / Big Muff at comparable reference
  settings.
- Avoid importing WDF / RNN code from ChowCentaur. Use the project only as a
  modeling-strategy reference.

### RAT

Target traits:

- Very high op-amp gain.
- Silicon diode hard clipping.
- Mid-forward / 1 kHz emphasis.
- FILTER is a simple low-pass: increasing filter should progressively remove
  treble, down into a low corner region.
- LM308 slew / compensation behavior means high drive should not become an
  unlimited full-band square wave.

D124 status:

- The previous dead-pole highpass bug is fixed; RAT now distorts and FILTER
  works.
- D124 measurement shows mid-forward behavior and usable FILTER rolloff.

Next measurement before any edit:

- FILTER sweep at 0 / 50 / 100, with fixed DRIVE.
- Drive sweep for THD and non-harmonic / alias energy.
- If a gap remains, prefer `ratOpAmpLowpassFrame`, `ratClipThreshold`, or
  `ratToneFrame` coefficient retunes. Do not add a duplicate RAT pedal-mask
  stage; D8 maps pedal-mask RAT to the existing RAT stage.

### Fender / Bassman / Twin-family amp direction

Target traits from the DAFx Bassman / JTM45 case study:

- Multi-triode preamp behavior matters, but a full WDF is too expensive for
  this FPGA phase.
- Grid-current / bias behavior contributes asymmetric clipping and even-order
  harmonics.
- Tone stack can be treated as a distinct block from the nonlinear preamp.
- Fender-derived and Marshall-derived amps should differ in gain, bright
  shaping, and supply / loading character.

D124 status:

- Amp already has per-model scoop / peak biquads, cascaded soft clipping,
  sag, transformer LF/HF behavior, and multiband saturation.
- Amp history includes bench rejection around sag removal / static sag trim;
  do not revisit that direction without explicit user instruction.

Next measurement before any edit:

- Treat amp as the last phase after Cab / OD / Dist / dynamics are stable.
- Measure one amp model at a time.
- For Fender-like models, prioritize mid-scoop accuracy and clean headroom
  before extra clipping.

### Marshall amp direction

Target traits from the DDSP guitar amp paper:

- A useful grey-box model separates preamp, tone stack, power amp, and output
  transformer.
- Lightweight physical modules can approach black-box behavior with lower
  operations per sample.
- Dynamic bias / memory and transformer behavior are important, but full NN /
  GRU inference is not appropriate for this Clash design.

D124 status:

- Current Amp architecture already follows the separated-block idea more than
  a single black-box waveshaper.
- The practical translation is not "add a neural model"; it is to keep using
  bounded, interpretable blocks: pre/post filters, asymmetric clip, one-pole
  envelopes, model-specific biquad rows, and transformer approximations.

Next measurement before any edit:

- For JCM800 / TriAmp, check high-gain alias / fizz, mid focus, and transformer
  low-end compression.
- If extra realism is needed, prefer a small measured bias-memory or
  frequency-dependent clip adjustment over large new blocks.

## Measurement matrix

Run these before proposing a DSP candidate:

| Model | Inputs | Metrics |
| --- | --- | --- |
| BD-2 | 1 kHz sine, multitone, tone sweep | THD vs drive, odd/even ratio, 2-3 kHz peak, bass rolloff, tone slope. |
| TS9 / tube_screamer | 1 kHz sine, multitone | 720 Hz hump, low-cut, soft-clip harmonics, tone LPF range. |
| OD-1 / SD-1 | 1 kHz sine, multitone, tone sweep | Even harmonics, mid peak position, output loss / gain at low drive. |
| DS-1 | 1 kHz / 5 kHz sine, multitone | Low-drive THD, hard-clip odd harmonics, lower-mid scoop, tone tilt, non-harmonic energy. |
| Centaur | DRIVE sweep, multitone | Clean-path retention, low THD, output push, transparent EQ. |
| RAT | DRIVE sweep, FILTER sweep, 5 kHz sine | Hard-clip THD, 1 kHz / 720 Hz mid-forward peak, FILTER corner range, alias proxy. |
| Fender-family amp | DI phrase, multitone, 1 kHz sine | Clean headroom, mid scoop, even harmonics, level stability. |
| Marshall-family amp | DI phrase, palm mute, 5 kHz sine | Mid push, high-gain fizz, low-end tightness, transformer / sag behavior. |

## Candidate ranking

Do not implement all of these by default. Use measurements and bench reports to
promote one candidate at a time.

| Rank | Candidate | Why | Risk |
| --- | --- | --- | --- |
| 1 | Clarify OD-1 vs SD-1 target and rename / document model intent if needed | Prevents tuning toward the wrong pedal. | Python / GUI docs only if rename is chosen; DSP risk none until retune. |
| 2 | SD-1-style model 1 mid peak, if SD-1 is the desired target | Supplied source points to SD-1's moving mid peak and asym clipping. | Low-medium; can reuse existing OD biquad mux pattern. |
| 3 | DS-1 clip-helper / threshold retune, only if bench says too soft | Biggest DS-1 structural gap is hard clipping. | Medium; clip helper changes can alter level and harshness. |
| 4 | RAT FILTER law calibration | D124 fixed distortion; next likely gap is control feel. | Low; coefficient-only if kept in existing frames. |
| 5 | BD-2 tone law micro-retune | Existing model is already close; only do this for a measured tone mismatch. | Low; avoid structural changes. |
| 6 | Amp model-specific dynamic memory refinement | Could improve feel, but amp history is risky. | High; amp changes require isolated model-by-model bench. |

## Non-goals for this reference pass

- No new GPIO.
- No new `topEntity` ports.
- No `block_design.tcl` edit.
- No C++ prototype.
- No neural-network inference in the FPGA.
- No exact WDF implementation of the Bassman / JTM45 paper.
- No imported ChowCentaur source or trained model.
- No structural BD-2 retake without a new explicit direction.
