# BOSS DS-1 Distortion — circuit research for the FPGA DSP model

Research date: 2026-05-24. Branch: `feature/improve-ds1-distortion-model`.

This document is the source-of-truth research note for the DS-1 Distortion
pedal stage (`distortion_pedal_mask` bit 3, Clash stages
`ds1HpfFrame` / `ds1MulFrame` / `ds1ClipFrame` / `ds1ToneFrame` /
`ds1LevelFrame` in `hw/ip/clash/src/AudioLab/Effects/Distortion.hs`). It is
the prerequisite for any coefficient or DSP-stage change to the DS-1 path.
It does NOT cover the other distortion pedals (`clean_boost`,
`tube_screamer`, `rat`, `big_muff`, `fuzz_face`, `metal`) — those stay
byte-exact.

Follows the same engineering rule established by D58 / D59 / D60 / D61 v2
(rejected, structural) and D62 (accepted, coefficient-only): **structural
changes in `Pipeline.hs` or new DSP48E1 multipliers tend to leak HF noise
onto the safe-bypass path via Vivado P&R shift; pure constant edits and
constant-LUT clip-helper swaps inside an existing stage are safe**. D63
therefore restricts itself to constant edits and clip-function swaps
inside the existing five DS-1 stages.

## Sources

| # | Source | URL | Credibility | What we used it for |
| - | ------ | --- | ----------- | ------------------- |
| 1 | ElectroSmash — Boss DS-1 Distortion Analysis | https://www.electrosmash.com/boss-ds1-analysis | Very high. Industry-reference circuit analysis with named designators, per-stage filter math, voltage / gain numbers, and signal-level waveforms. | Five-block topology, Q2 booster gain (+35 dB) and asymmetric soft clipping, op-amp variable gain (0..26.5 dB), back-to-back diode hard clipping at op-amp output, feedback LPF at 7.2 kHz (R14+C10) as the built-in "less grainy" fizz guard, tone-stack filter values (R16+C12, C11+R17), net tone-stage loss (-12 dB). |
| 2 | sonicfields.be — Boss DS-1 Tonestack | https://sonicfields.be/stompbox-blog/boss-ds1-tonestack.html | High. Single-author Big-Muff-style stompbox analysis. | Confirmation that the DS-1 tonestack is a Big Muff-style two-filter blend, ~500 Hz scoop at noon, "quite a big gap between the highs and lows" at noon. |
| 3 | Guitar Pedals Visualized — Boss DS-1 | https://guitarpedalsvisualized.wordpress.com/2022/03/24/boss-ds-1/ | High. Per-pedal frequency response visualisations. | Tone control shape at min / noon / max (cited indirectly via search summary). |
| 4 | electric-safari — DS-1 vs modded DS-1: frequency response | https://electric-safari.com/2019/07/08/ds-1-vs-modded-ds1-frequency-response/ | Medium. Mod-focused but the stock-vs-modded A/B exposes the stock response. | Stock DS-1 reference response curve baseline. |
| 5 | Néstor Nápoles López — MUMT 618: Implementation of Boss DS-1 | https://napulen.github.io/reports/mcgill/mumt618/ | Medium-high. Academic digital-modeling project report. | Sanity check on the kinds of simplification a published DS-1 digital model uses. |
| 6 | Boss Articles — All About the DS-1: The Benchmark BOSS Distortion | https://articles.boss.info/all-about-the-ds-1-the-benchmark-boss-distortion/ | Marketing / official. | Marketing-side characterisation only; not used to set any coefficient. |

Forum / mod / Reddit / Tumblr posts encountered during the search but not
cited above are explicitly treated as anecdotal and were not used to set
any coefficient.

## DS-1 stage block diagram (from [1])

```
guitar
  v
[ Input buffer + HPF C1+R2 fc=7.2 Hz ]        -- ~unity gain, just kills DC
  v
[ Q2 booster (2SC2240) ]                      -- +35 dB above ~3.3 kHz,
   R7=470k, R8=10k (collector),               -- two cascaded HPFs at
   R9=22 ohm (emitter), C4=250 pF feedback    -- C2+R4 (3.3 Hz) and
   Two cascaded HPFs (3.3 Hz / 33 Hz)         -- C3+R5 (33 Hz).
   SOFT ASYMMETRIC clipping from               -- 200 mVpp in -> 9 Vpp out.
   transistor saturation                       -- "cycles have slightly
                                                  different duration"
  v
[ Op-amp gain (NJM2904L) + diode hard clip ]  -- VR1 100k DRIVE control:
   Gv = 1 + (VR1 / R13) =                     -- 0..+26.5 dB
        1 + (100k / 4.7k) max
   D4 / D5 (1N4148) back-to-back to AC GND    -- ~+/- 0.7 V SYMMETRIC
   (+4.5 V virtual ground)                       hard knee clipping.
   Feedback HPF C8+R13+VR1: 72 Hz max-dist    -- pre-clip low-mid tighten
                            3 Hz min-dist        scaled by drive
   Feedback LPF R14+C10: 7.2 kHz fc           -- "makes the distortion
                                                  less grainy, rounder" --
                                                  this is the BUILT-IN
                                                  anti-fizz lid that
                                                  prevents 8 kHz+ harsh
                                                  on the real pedal.
  v
[ Big Muff style passive tone control VR3 ]   -- two interweaving filters:
   LPF R16+C12: fc = 234 Hz                   -- bass branch
   HPF C11+R17: fc = 1063 Hz                  -- treble branch
   VR3 (20k) blends them                      -- at noon: scoop at the
                                                  geometric mid
                                                  ~sqrt(234 * 1063) =
                                                  ~499 Hz, ~20 dB notch
                                                  depth, ~ -12 dB net
                                                  loss through stage
  v
[ Level control VR2 100k ]                    -- bleeds to AC GND
                                                  (extra loss; the FPGA
                                                  level stage already
                                                  has a safety knee)
  v
[ Q3 output buffer (2SC2240) ]                -- emitter follower, unity
                                                  output HPFs at 3.4 Hz
                                                  and 1.6 Hz
  v
amp / next pedal
```

## DS-1 personality — what defines "DS-1-ness"

Every coefficient choice in `Distortion.hs` for the `ds1` stages should be
traceable back to one of these:

1. **Op-amp output HARD clipping (D4/D5 to ground)** is the central DS-1
   sonic event. It is SYMMETRIC, has a hard knee (the diode forward-V is
   the knee), and squares the waveform at high drive. This is the
   single biggest sonic differentiator from TS9 (feedback soft clip),
   Big Muff (cascaded asym soft diode pairs), and BD-2 (cascaded
   discrete-op-amp soft clip). **The current FPGA DS-1 uses
   `asymSoftClip` here, which is the wrong helper choice** — the most
   load-bearing single change D63 can make is switching this to
   `asymHardClip` (already exported by `FixedPoint.hs`) with
   essentially symmetric knees.

2. **Q2 transistor booster soft asymmetric pre-clipping** (Q2's
   saturation produces uneven half-cycle durations per source [1]).
   This is what feeds the op-amp; the +35 dB gain plus mild asymmetric
   curvature pre-conditions the signal before the hard clip stage.
   On the FPGA path, the existing `ds1MulFrame` + `satShift8`
   accomplishes the gain; the *asymmetric soft-knee curvature* is what's
   missing if we want the full DS-1 cascade.

3. **Mid scoop ~500 Hz from Big Muff tone control** is the second-most
   distinctive DS-1 feature: bass and treble are both LOUDER than the
   mids at noon, ~20 dB notch depth. This is the inverse of TS9 (which
   has a mid hump). **The current FPGA DS-1 uses a single tone LPF,
   which produces NO scoop.** A genuine Big Muff blend (LPF and HPF
   mixed) would require two `mulU8` invocations (one per branch
   weight) -- which is the structural cost class D58 / D61 v2 proved
   risky. D63 leaves the tone stage's structure alone and documents
   this as a known limitation; a later D64+ should consider a
   shift-based blend (`out = (lp >> Nlo) + (hp >> Nhi)`) inside the
   existing tone stage, which costs zero DSP48E1.

4. **Feedback LPF at 7.2 kHz (R14+C10)** is the built-in anti-fizz lid
   on the real pedal -- it rolls off harmonics above ~7 kHz before the
   tone stack sees them, so the DS-1 stays bright but never reaches
   the ice-picky 8..16 kHz range that some hard-clipping distortions
   suffer at high TONE. The existing FPGA DS-1's `ds1ToneFrame` is a
   downstream LPF at variable corner (96..223 alpha range), which
   does some of the same work but is *driven by the user's TONE knob*
   rather than fixed. D63 narrows the `alpha` ceiling slightly so
   even at TONE=255 the model can't pass content above ~7 kHz at
   full level.

5. **Feedback HPF that tightens with DRIVE (72 Hz at max-drive, 3 Hz
   at min-drive per [1])** is what keeps the DS-1 from getting muddy
   when DRIVE is cranked. The existing `ds1HpfFrame` has a TIGHT-knob
   driven corner (`alpha = 4 + (TIGHT >> 4)`, range 4..23), which is
   the closest the FPGA model has to this behaviour. D63 keeps the
   structure but considers a slightly wider alpha ceiling for more
   audible pre-clip tightening at high TIGHT settings.

6. **Hard-rock voicing**: the tone-stack scoop + bright voicing makes
   the DS-1 a rhythm-rock and lead-rock workhorse, not a blues / jazz
   pedal. Adjustments that push the DS-1 *toward* TS-9 mid-hump
   behaviour are sonically wrong for this model and should be
   rejected.

## What we explicitly do NOT model

- **Diode reverse-leakage and temperature dependence** — out of scope
  for fixed-point integer DSP.
- **Q2 BJT model at the transistor-curve level** — too expensive; we
  approximate with a soft asym clip helper.
- **The exact output buffer HPFs (3.4 Hz, 1.6 Hz)** — below audio band
  perceptually; we let the existing chain's DC blocking handle it.
- **The level stage's mid-scoop reload-into-VR2** — combined into the
  existing `softClipK` safety knee.
- **DS-1W (Waza Craft) standard / custom mode switching** — this is
  the original DS-1, not the W variant.

## DSP-side blueprint (constants-only retake, D63)

Following the D62 rule -- no `Pipeline.hs` change, no new register, no
new `mulU8` / `mulU12` invocation -- D63 limits itself to:

1. **Helper swap inside `ds1ClipFrame`** (zero DSP48E1 cost):
   Replace `asymSoftClip` (smooth knee compression) with the existing
   `asymHardClip` (hard knee limiter, already exported from
   `FixedPoint.hs`). This is the load-bearing change -- the real
   DS-1's diode-pair clip is a hard knee, not a soft knee, and the
   existing `asymSoftClip` was a holdover from the time the stage was
   set up to "approximate hard clip with soft clip helper for timing
   reasons" (per the existing comment in the file).

2. **Two-stage clip inside `ds1ClipFrame`** (also zero DSP48E1 cost --
   both helpers are pure compare-add-shift, no multiplier): chain a
   Q2-emulating `asymSoftClip` *before* the `asymHardClip`. Soft P
   knee > Hard P knee so the Q2 stage only adds curvature on hot
   signal; the hard clip dominates the audible saturation at high
   DRIVE. Approximate Q2's asymmetry by setting the soft N knee
   slightly below the soft P knee (matches "cycles have slightly
   different duration" from source [1]).

3. **Pre-clip drive coefficient bump** in `ds1MulFrame`. Current
   coefficient is `gain = 256 + (drive * 8)` giving ~1x..~9x. Real
   DS-1's effective pre-op-amp gain stack is much higher (+35 dB Q2
   plus up to +26.5 dB op-amp = ~+61 dB total). The DSP can't reach
   that without saturating Sample width, but we can push slightly to
   match the "hard rock workhorse" character. Proposed: bump to
   `gain = 256 + (drive * 10)` for ~1x..~11x.

4. **Tone alpha range narrowing** in `ds1ToneFrame`. Current is
   `alpha = 96 + (tone >> 1)` -> 96..223. At TONE=255 the LPF is
   almost wide open, so 8..16 kHz content survives. The real DS-1's
   feedback LPF (R14+C10, fc=7.2 kHz) is *always* active. Proposed:
   narrow to `alpha = 80 + (tone >> 1)` -> 80..207, so TONE max still
   sounds bright but rolls off harder above ~6.5 kHz, matching the
   real pedal's built-in anti-fizz lid.

5. **HPF alpha range** in `ds1HpfFrame` -- the existing 4..23 range
   already gives a reasonable feedback-HPF emulation; D63 leaves
   this alone (any change here interacts with the upstream pedal
   ordering and isn't load-bearing for the DS-1 personality).

6. **`ds1LevelFrame` safety knee** stays at 3_000_000.

7. **Tone stack scoop (Big Muff style)** -- *not implemented in D63*.
   It would require either two `mulU8` invocations (DSP cost) or a
   shift-based blend (cheap but needs a code restructure inside the
   tone stage). Deferred to D64+ with the constraint kept clearly in
   mind that the structural change risks the bypass-path artifact.

### Proposed D63 constants (subject to bench A/B)

| Location | Old | New | Why |
| --- | --- | --- | --- |
| `ds1ClipFrame` clip helper | `asymSoftClip` | `asymHardClip` *after* a soft Q2 emulator | DS-1 op-amp diode-pair is a hard knee, not soft |
| `ds1ClipFrame` Q2 soft knees (new) | n/a | softP = 3_000_000, softN = 2_600_000 | Q2 booster soft asym, above the hard clip |
| `ds1ClipFrame` hard knees | softP=2_400_000, softN=2_000_000 | hardP = 2_200_000, hardN = 2_200_000 | Symmetric ±0.7 V op-amp clip |
| `ds1MulFrame` drive coefficient | `drive * 8` | `drive * 10` | More pre-clip push, matches DS-1 hard-rock voicing |
| `ds1ToneFrame` alpha base | `96` | `80` | Slightly darker TONE-max ceiling, emulates the 7.2 kHz feedback LPF |
| `ds1ToneFrame` alpha range | `tone >> 1` | `tone >> 1` (unchanged) | Same per-knob delta |
| `ds1HpfFrame` alpha | `4 + (TIGHT >> 4)` | unchanged | Already in-character |
| `ds1LevelFrame` safety knee | `3_000_000` | unchanged | Adequate, no change needed |

Net DSP48E1 cost vs D62 baseline: **0** (no new `mulU8` / `mulU12`).
Net pipeline depth change: **0** (no new register).
Net combinational depth change: small additive (two clip helpers
chained in `ds1ClipFrame` -- still all compare + shift + add, no
multiplier). WNS expected to track D62 closely.

## Validation plan (D63 bench audition)

After implementation + Clash regen + Vivado build + deploy:

1. **Programmatic smoke**: Pmod mode 2 safe-clean, FRAME_COUNT delta
   ~144000 / 3 s, CLIP_COUNT delta 0, ADC HPF True, MUTE 3.
2. **Audition cycle (CLAUDE.md spec connection, no Pmod direct
   loopback)** -- the D58/D59/D60/D61 regression guard:
   - all_off bypass: must sound *identical* to D62 by ear. Any HF
     noise difference here is a bypass-path P&R regression and the
     build is rejected (same gate as D62).
   - DS-1 disabled / other distortion pedals (clean_boost / tube_screamer
     / big_muff / fuzz_face / metal) and RAT: must sound identical to
     D62. The DS-1 changes are isolated to `ds1*Frame`; these other
     pedals must not change.
   - DS-1 Distortion 20 / 50 / 80 at Tone 50: should audibly
     progress from light crunch -> canonical DS-1 hard-clip -> heavy
     square-ish saturation that doesn't collapse.
   - DS-1 Tone 30 / 50 / 70 at Distortion 50: should show
     dark / standard / bright behaviour. TONE=70 should be bright
     without ice-pick (the new alpha base 80 narrows the ceiling).
   - DS-1 vs RAT vs BD-2 vs TS9: DS-1 should sound distinctly
     harder-edged and brighter than BD-2 and TS9, and less rough than
     RAT.
3. **Macroscopic numbers do not gate audio.** Per the D58 / D59 / D60 /
   D61 / D62 lesson, `CLIP_COUNT = 0` and `WNS within ~0.5 ns of D62`
   are **necessary but NOT sufficient**. The bench ear on safe-bypass
   plus the DS-1 audition is the dispositive sensor.

## Known limitation carried forward

D63 does NOT implement the ~500 Hz mid-scoop Big Muff tone control.
The current `ds1ToneFrame` is a single post-LPF that only changes how
much treble survives. This is a real DS-1-vs-FPGA discrepancy and the
DS-1 model in this build remains *brighter-on-average* than the real
pedal at the same TONE setting -- the real pedal has BASS as well as
TREBLE re-emphasised relative to mids, our FPGA model only has
TREBLE. Future work (D64+) can address this with a shift-based two-band
blend inside the existing `ds1ToneFrame`, costing zero DSP48E1 but
requiring an internal restructure of the stage; it must be
bench-validated against the same all_off regression guard before being
accepted. Documenting this here so the next iteration knows the
target.
