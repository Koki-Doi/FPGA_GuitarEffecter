# Distortion `asymSoftClip` knee-only retune research (D64)

Research date: 2026-05-24. Branch: `feature/retune-distortion-asymsoftclip-constants`.

This document is the source-of-truth research note for the D64 retake.
**Scope is strictly limited to retuning the `kneeP` / `kneeN` numeric
constants of the existing `asymSoftClip` invocations inside
`hw/ip/clash/src/AudioLab/Effects/Distortion.hs`.** Per the D63 evidence,
adding new helper invocations, swapping helper functions, or chaining
clip helpers in cascade -- even with no DSP48E1 / register / BRAM
delta -- is a structural change in the Vivado-P&R sense and leaks
audible artifacts onto the safe-bypass path and unrelated effect paths.

## Inventory: every `asymSoftClip` invocation in Distortion.hs

Grep of `hw/ip/clash/src/AudioLab/Effects/Distortion.hs` shows **three**
`asymSoftClip` call sites; every other clip in the file uses `hardClip`,
`softClipK`, or no clip at all and is therefore OUT OF SCOPE for D64
(the constraint forbids adding asymSoftClip to pedals that do not
already have it):

| # | Function | Line | Pedal | Current `kneeP` | Current `kneeN` | Current P-N gap |
| - | -------- | ---- | ----- | --------------- | --------------- | --------------- |
| 1 | `tubeScreamerClipFrame` | 148 | Ibanez TS9 (distortion pedal mask bit 1, `tube_screamer`) | 2_900_000 | 2_500_000 | 400k |
| 2 | `ds1ClipFrame`          | 274 | BOSS DS-1 (distortion pedal mask bit 3, `ds1`)             | 2_400_000 | 2_000_000 | 400k |
| 3 | `fuzzFaceClipFrame`     | 394 | Dallas-Arbiter Fuzz Face (distortion pedal mask bit 5, `fuzz_face`) | 1_900_000 | 1_400_000 | 500k |

Pedals that do NOT use `asymSoftClip` and therefore are **byte-exact
preserved** by D64:

| Pedal | Helper used | Line(s) | Notes |
| ----- | ----------- | ------- | ----- |
| Legacy distortion | `hardClip` | 44 | Pre-pedal-mask path, kept for back-compat |
| `clean_boost` | `softClipK` (output safety) | 110 | No clip stage proper, just an output limiter |
| `metal_distortion` | `hardClip` (clip stage), `hardClip` (level) | 210, 458 | True hard clip already; not a candidate |
| `ds1` level safety | `softClipK` | 298 | Output safety only |
| `big_muff` | `softClipK` (clip1, clip2), `softClipK` (level safety) | 329, 338, 361 | Two-stage soft-knee compression at the safety end of `softClipK` -- structurally already two helpers, but they have always been there (pre-D64), so they are not "new" |
| `fuzz_face` level safety | `softClipK` | 417 | Output safety only |
| RAT (legacy) / `clean_boost` extras | various | -- | Out of scope |

The constraint forbids adding `asymSoftClip` (or any new clip helper)
to any pedal that does not currently use it, so RAT / metal /
`big_muff` / `clean_boost` are out of scope by construction even
though they are distortions in the broad sense.

## Sources

Per-pedal circuit references used to direction the knee retune:

| # | Source | URL | Credibility | What we used it for |
| - | ------ | --- | ----------- | ------------------- |
| TS9.1 | ElectroSmash -- Ibanez Tube Screamer Circuit Analysis | https://www.electrosmash.com/tube-screamer-analysis | Very high. The reference TS analysis. | Diode-pair (D1/D2) anti-parallel topology -> SYMMETRIC clipping by construction; asymmetry only appears via the feedback HPF phase shift (a frequency-domain artefact, not a DC-domain knee artefact); 51 pF C4 across the diodes softens corners; with DRIVE at max even 60 mV in would reach 6 V without the clip diodes. |
| TS9.2 | stompboxelectronics -- An Analysis of the Ibanez TS-9 Clipping Circuit | https://stompboxelectronics.com/2023/04/03/an-analysis-of-the-ibanez-ts-9-clipping-circuit/ | High. Independent analysis. | Confirmation that removing either D1 or D2 produces asymmetric clipping (i.e. stock TS9 with both diodes IS symmetric); soft-clip threshold ~ 1x diode forward voltage. |
| DS1.* | ElectroSmash -- Boss DS-1 Distortion Analysis | https://www.electrosmash.com/boss-ds1-analysis | Very high (same source as D63). | D4/D5 back-to-back to AC ground -> SYMMETRIC hard knee clipping; asymmetry in real DS-1 comes from the Q2 booster pre-stage (NOT the op-amp clip). Implication: the FPGA `asymSoftClip` for DS-1 should be closer to symmetric than the current `400k` P-N gap suggests. |
| FF.1 | ElectroSmash -- Fuzz Face Analysis | https://www.electrosmash.com/fuzz-face | Very high. The reference Fuzz Face analysis. | Two-stage BJT amplifier with shunt-series feedback delivers "soft asymmetrical clipping that changes to hard clipping in both semi-cycles under the fuzz pot action". The asymmetric clipping is "important for the musical quality of this device". Q1 bias point is critical; germanium variant amplifies the asymmetry further. |
| FF.2 | ElectroSmash -- You can Build the Perfect Germanium Fuzz Face | https://www.electrosmash.com/germanium-fuzz | High. Per-component sibling article. | Germanium has high leakage and inconsistent gain, which deepens the asymmetric clipping; silicon Fuzz Face (BC108C / BC109C / BC183L family) is harsher but still asymmetric. |

Forum / mod / Reddit / Tumblr posts encountered during the search but
not cited above were treated as anecdotal and were not used to set any
coefficient.

## Per-pedal target direction (constants only, no helper change)

### TS9 (`tubeScreamerClipFrame`)

- Real circuit: SYMMETRIC by design (D1/D2 anti-parallel). The
  current `kneeP=2_900_000 / kneeN=2_500_000` (400k gap, 16% asym) is
  more asymmetric than the real pedal.
- Direction: reduce P-N gap toward symmetric. Keep both knees
  relatively high so TS still sounds smooth and "late" -- TS-style
  diode-to-ground soft clipping engages well after the initial
  dynamic range, not from the first millivolt.
- Proposed: `kneeP = 2_900_000` (unchanged) / `kneeN = 2_700_000`
  (+8 %, gap narrowed from 400k to 200k).
- Why not bigger move: TS9 is the most-played overdrive in the
  six-Overdrive lineup; aggressive change would re-shape a familiar
  reference. The smaller move keeps the TS musical signature
  intact while pulling the knee asymmetry back in line with the
  documented circuit.

### DS-1 (`ds1ClipFrame`)

- Real circuit: op-amp output D4/D5 SYMMETRIC hard clip. Asymmetric
  even-harmonic content in the real DS-1 comes from the upstream Q2
  transistor booster, not from the op-amp clip itself. The current
  `kneeP=2_400_000 / kneeN=2_000_000` (400k gap, 17 % asym) keeps
  the asymmetry in the wrong place (clip stage instead of pre-stage).
- D63 attempted to fix this with a two-helper cascade
  (`asymSoftClip` for Q2 + `asymHardClip` for the op-amp diodes) and
  failed the bench audition with a bit-crusher-like bypass artifact
  plus leak to other distortion pedals; per the D61 v2 / D62 / D63
  evidence the cascade is a structural change that triggers
  P&R-induced bypass regression even at unchanged DSP/BRAM/register
  count. D64 sticks to a single-helper retune.
- Direction: tighten the knees toward nearly symmetric to better
  match the op-amp diode clip's character; lower the average level
  slightly so DS-1 clips a little earlier than TS9 (matching the
  documented "DS-1 has audible breakup below mid-drive" finding).
- Proposed: `kneeP = 2_200_000` (-8 %) / `kneeN = 2_100_000` (+5 %,
  gap narrowed from 400k to 100k, P-N gap reduced 75 %).
- Why this is safer than D63: a single-helper invocation with two
  different numeric constants is exactly what D62 demonstrated to be
  safe on the BD-2 path -- the existing arithmetic operators stay
  byte-for-byte the same, only the operands change.

### Fuzz Face (`fuzzFaceClipFrame`)

- Real circuit: pronounced asymmetric soft clip from the BJT pair
  with feedback, where one half-cycle saturates Q2 to its rail
  (~+4.5 V) while the other half drives Q1's bias toward cut-off.
  Per ElectroSmash, the asymmetric clipping is THE musical signature
  of the Fuzz Face. The current `kneeP=1_900_000 / kneeN=1_400_000`
  (500k gap, 26 % asym) is already in the right direction but on
  the conservative end of "Fuzz-Face-ness".
- Direction: widen the P-N gap further to push the Fuzz Face
  identity (broken-up germanium-style waveform asymmetry) while
  staying inside the ±25 % per-knee budget.
- Proposed: `kneeP = 2_000_000` (+5 %) / `kneeN = 1_200_000` (-14 %,
  gap widened from 500k to 800k, P-N asym from 26 % to 40 %).
- Why this is safer than D63: same single-helper-invocation pattern
  as DS-1 above; only operands change.

## Summary of proposed numeric changes

| Pedal | `kneeP` (old -> new) | `kneeN` (old -> new) | P-N gap (old -> new) | Per-knee delta | Direction |
| ----- | -------------------- | -------------------- | -------------------- | -------------- | --------- |
| TS9 (`tubeScreamerClipFrame`) | 2_900_000 -> **2_900_000** (no change) | 2_500_000 -> **2_700_000** | 400k -> **200k** | P +0 %, N +8 % | More symmetric (matches real circuit), keep smooth/late clip |
| DS-1 (`ds1ClipFrame`) | 2_400_000 -> **2_200_000** | 2_000_000 -> **2_100_000** | 400k -> **100k** | P -8 %, N +5 % | Nearly symmetric, slightly earlier clip (op-amp diode pair feel) |
| Fuzz Face (`fuzzFaceClipFrame`) | 1_900_000 -> **2_000_000** | 1_400_000 -> **1_200_000** | 500k -> **800k** | P +5 %, N -14 % | More asymmetric (germanium broken-up waveform signature) |

Net change in `Distortion.hs`: **6 numeric constants edited (3 × P +
3 × N).** No new helper invocation. No helper swap. No cascade. No
`Pipeline.hs` edit. No DSP48E1 / BRAM / register count change.

## What D64 does NOT do (deferred / out of scope)

- Big Muff Pi style ~500 Hz mid-scoop in `ds1ToneFrame` (would need
  helper restructure -- structural change per D63 evidence).
- Pre-clip Q2-style booster soft asymmetric stage for DS-1
  (cascade with main clip = structural per D63 evidence).
- Replacing `asymSoftClip` with `asymHardClip` for DS-1 (helper
  swap = structural per D63 evidence).
- Touching `softClipK` or `hardClip` invocations for the other
  pedals (out of scope per D64 task spec).
- Touching `Pipeline.hs`, `Overdrive.hs`, `Amp.hs`, `Compressor.hs`,
  or any other DSP source file outside `Distortion.hs`.
- Touching DRIVE coefficients, TONE alpha, LEVEL safety, HPF/LPF
  alpha, or any non-clip numeric parameter in these stages.
- Adding `if model == X` muxing or any new operand source to the
  existing `asymSoftClip` invocations.

If D64 succeeds, future work can incrementally retake individual
pedals' fidelity using the same constants-only pattern. If D64
fails the bench audition (HF noise / bit-crusher artifact / leak
to other effects), the immediate fallback is to roll back to D62
exactly as the D63 rollback did, keeping this research note in
git history as the post-mortem reference.

## Validation plan (D64 bench audition)

1. Programmatic smoke: Pmod mode 2 safe-clean, FRAME_COUNT delta
   ~144000 / 3 s, CLIP_COUNT delta `0`, ADC HPF True, MUTE 3.
2. Audition cycle (CLAUDE.md spec connection, no Pmod direct
   loopback):
   - **all_off bypass** must sound *identical to D62* by ear. Any HF
     noise / bit-crusher artifact here is a P&R regression and the
     build is rejected (same gate as D62 and D63).
   - **TS9 D20 / D50 / D80**: should sound subtly smoother in the
     negative half compared to D62 (P-N gap reduced from 400k to
     200k), still recognisable as TS-style mid-hump overdrive.
   - **DS-1 D20 / D50 / D80**: should sound a touch harder /
     earlier-clipping than D62, with the asymmetric edge largely
     removed (the gap reduction is the load-bearing change).
   - **Fuzz Face D20 / D50 / D80**: should sound noticeably more
     asymmetric / "broken-up" than D62, with the negative half
     compressing earlier (the widened gap is the load-bearing
     change).
   - **RAT / metal / big_muff / clean_boost**: must sound byte-exact
     identical to D62 (these pedals do NOT use `asymSoftClip`, so
     their Clash code is unchanged; the D63 evidence showed even
     "byte-exact" non-clip helpers can audibly leak if the build
     P&R shifts, so confirming this is the dispositive check that
     D64's edit did NOT trigger the cross-effect leak).
   - **BD-2 / OD-1 / Centaur / Jan Ray / OCD / TS9 (Overdrive
     model)**: byte-exact (these are in `Overdrive.hs`, not
     `Distortion.hs`; should not change).
3. Macroscopic numbers do not gate audio per the D58 / D59 / D60 /
   D61 / D62 / D63 cumulative lesson; the bench ear on safe-bypass
   and on every other effect that shares the axis_switch path is
   the dispositive sensor.
