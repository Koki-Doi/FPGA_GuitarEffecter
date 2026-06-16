# Realism: all-effects offline-sim survey + sim strengthening (2026-06-16)

Status: **sim strengthened (4 new measurement axes), all tone effects re-surveyed
on the D131 baseline (`fdab62d5`); the remaining gaps vs real hardware are
located and prioritized.** Sim-only -- NO Clash/Tcl/XDC/bitstream change, deployed
baseline unchanged. Triggered by the user: "まだエフェクトが実機から離れている。
シミュレーションを強化して、全エフェクトを調査し、どこが違うかを調べてください。"

The previous harness could only A/B a voicing it already knew to look at. The gap
the user is hearing was partly INVISIBLE to it: it measured each effect in
ISOLATION (so the amp looked fine until you remember a real amp is always into a
speaker), it had no real-hardware target for the amp/cab at all, and it scored
distortion by THD/EQ only (so "歪が足りない" / "wrong clip feel" never produced a
FAIL). This pass closes those blind spots, then re-runs everything.

## What was strengthened (`tools/dsp_sim/`, sim-only)

1. **Realistic RIG chain measurement** (`measure.py` `rig_*` configs). A guitar
   amp is ALWAYS heard through a speaker; amp-alone is misleadingly bright
   because the amp tone-stack "high" band is a `monoWet - lowpass` **+6 dB/oct
   differentiator** with no speaker rolloff. `rig_N` routes amp model N -> cab
   (pipeline order amp -> cab) so the amp is measured AS HEARD. This is the
   single biggest blind spot fix.
2. **HF-slope / brightness metric** (`measure.py` `hf_slope`, the `HFslp`
   column). Treble slope dB/octave 2-9 kHz. A real amp+cab ROLLS OFF (negative;
   the speaker is a lowpass); a rising/positive slope = bare differentiator EQ =
   "digital/buzzy". The single number that separates "sounds like a rig" from
   "sounds like a buzzy DI".
3. **Amp + Cab real-hardware targets** (`targets.py` `rig_*` / `cab` + the `hf`
   field; `measure.py --check` now covers them). Previously `--check` only knew
   OD/DIST. Amps are targeted on the RIG, not amp-alone.
4. **Distortion-CHARACTER targets + auto-check** (`targets.py` `CLIP_TARGETS` +
   `compare_clip`; `dist_eval.py --check`). PASS/FAIL on the robust axes: THD
   floor ("does it distort enough" = the 歪 check), sustain, and Fuzz cleanup.
   An under-driving Metal now FAILs automatically instead of being eyeballed.
5. **Metric rigor: crest demoted to informational.** The first cut FAILed on
   clip TYPE via crest at a hot input; the harmonic cross-check (`harmonics.py`,
   odd/even + h3..h7) proved crest is CONFOUNDED by each pedal's post-clip LPF
   (a hard square through a bright LPF rings = high crest that mimics soft). So
   `compare_clip` now gates on THD/sustain/cleanup and only REPORTS crest --
   "a metric that mis-measures is worse than none".

## Survey method

Multitone net curve (`measure.py --batch/--check`, 40 Hz-9 kHz, 30 log bins,
LINEAR 0.05) for frequency shaping + the new rig/HFslp; `dist_eval.py
--batch/--check` (1 kHz drive sweep -36..-6 dBFS, decaying-pluck sustain, two-tone
grit) for distortion character; `harmonics.py` for the per-model harmonic series.
Bypass stays bit-exact (offline knife-edge invariant). All on the EXACT Clash
topEntity, gap=8.

## Results

### Overdrive (6) -- EQ all on-target

`measure.py --check`: **6/6 PASS** (TS9 +4.9@720, OD-1 +3.4@800, BD-2 +1.2@2300,
JanRay +1.0@350, OCD +3.5@1300, Klon +3.4@1000). HFslp -1.0..-1.9/oct (rolled off,
not buzzy). The D129 OD re-collation holds. No clip-character target set for OD
(they are intentionally low/medium-gain transparent pedals); harmonics already
on-target from D124.

### Distortion (7) -- EQ on-target, but 3 fail the new CHARACTER check

`measure.py --check` (EQ): **7/7 PASS** (the D131 mid features + bass balance hold:
TS +7.1@720, DS-1 scoop -1.6@500, BigMuff scoop -5.3@1000 + lows +8.1, Metal
+6.5@800 + lows -11.9, RAT +2.1@1000, ...).

`dist_eval.py --check` (CHARACTER): **6/7 PASS, 1 FAIL** -- and the harmonic
cross-check that corrected the metric (see below). The ONE real, validated gap is
**Metal under-saturation**:

| pedal | THD@-6 | h3 (dB rel fund) | sustain | verdict | note |
| --- | --- | --- | --- | --- | --- |
| CleanBoost | 3% | - | 1.00 | PASS | transparent, correct |
| TubeScreamer | 20-29% | -14.7 | 1.06 | PASS | moderate op-amp soft clip, correct |
| DS-1 | 34-51% | **-10.2** | 1.46 | PASS | strong ASYMMETRIC clip (h2 -22.9 = Si-diode asym) + strongest h3 of all -- a correct hard-ish diode pedal |
| BigMuff | 69-78% | **-4.2** | 2.04 | PASS | huge saturation + sustainer, correct |
| FuzzFace | 34% | - | 1.80 | PASS | squares + cleans up (4->34%) + sustains, correct |
| Metal | **18%** | **-15.9** | 2.03 | **FAIL** | THD plateaus at 18% AND the weakest odd harmonic of any high-gain pedal -- "歪が足りない" CONFIRMED |
| RAT | 22-26% | -13.4 | 1.44 | PASS | symmetric hard clip (odd/even +77 dB), correct |

**Metric correction (a sim-rigor fix this session):** the first clip-character
check FAILed DS-1 ("too soft", crest 5.6) and TS ("too hard", crest 1.7). The
harmonic cross-check (`harmonics.py`) DISPROVED both: DS-1 has the **strongest h3
(-10.2 dB)** of every pedal -- it is genuinely hard, its high crest is post-LPF
ring (a hard square through DS-1's BRIGHT post-LPF overshoots = high crest that
mimics softness); TS is a legitimately moderate op-amp clip. **crest at a hot
input is confounded by each pedal's post-clip LPF and is NOT a reliable hard/soft
discriminator** -- it is now INFORMATIONAL in `compare_clip`, with PASS/FAIL on the
robust axes (THD floor, sustain, cleanup). Only **Metal** genuinely under-distorts
(confirmed by BOTH THD 18% and h3 -15.9), and that is a gain-path limit, not a
clip-shape one: the Metal drive gain saturates the Unsigned-12 path (`768 +
drive*13`, ~16x ceiling at full drive) so it cannot reach MT-2 saturation without
the gain-staging restructure (a NEW-STAGE item) -- opening the dark post-LPF would
add THD but brighten it away from the dark MT-2 voicing, so it is deferred, not
band-aided.

### Amp (6) -- alone is a +6 dB/oct differentiator; the rig is bass-light

Amp-ALONE (`amp_0..5`) all measure **+14..+20 dB rising tilt to 9 kHz, HFslp
+1.9..+3.8/oct, THIN + BRIGHT** -- the differentiator high band with no speaker.
This is NOT how the amp is heard, which is why amp-alone never looked wrong.

Amp INTO cab (`rig_*`, `measure.py --check`): **0/3 PASS** -- the real findings:

| rig | mid | low_vs_mid | HFslp | verdict | gap |
| --- | --- | --- | --- | --- | --- |
| JC120>cab | peak +14@2435 | **-22.8** | -1.8/oct | FAIL | bass-light; a +14 dB 2.4 kHz spike on a "clean" amp |
| AC30>cab | chime +14.5@2500 OK | **-18.9** | -3.7/oct | FAIL | chime present, but bass-light |
| JCM800>cab | **no peak @650** (-0.3) | **-21.4** | -2.0/oct | FAIL | the Marshall 650 Hz mid push is MASKED by the cab's shared 2935 Hz presence peak; bass-light |

Two amp gaps: **(A)** the whole rig is **bass-light** (low_vs_mid -19..-23 dB vs a
real mic'd cab's near-unity low-mid thump) -- the persistent "低音が足りない", and
it survives the cab, so the prime suspect is the amp input HPF (~298 Hz, D101) +
no cab low-end body. **(B)** the **cab's single shared 2935 Hz presence peak
overwrites each amp's own upper-mid voicing** (JCM800's 650 Hz mid vanishes), so
the amp models converge in the presence region. HFslp is correctly negative (the
cab does tame the differentiator) -- the treble axis is fine; the LOW end and the
amp/cab presence interaction are the gaps.

### Cab (3) -- on-target for what 4 taps can do

`measure.py --check`: **PASS** (presence peak +2.0@3000, HFslp -5.5/oct rolled
off). The 4-tap FIR cannot make the SHARP >5 kHz rolloff of a real cab (-5.5/oct
2-9 kHz vs a real 4x12's ~-12..-24 dB/oct above 5 kHz) and has only ONE shared
presence peak across models (see amp finding B). A real short IR (128-256-tap
BRAM convolution) remains the biggest single cab realism lever (MODEL_REALISM_GAP
item 1).

### Dynamics / time / mod (Reverb / Compressor / NS / Wah / EQ)

`knobcheck.py --all` (per-band dB change 25->75). The PRIMARY knobs all work and
localise correctly -- these effects were bench-accepted (Wah/NS D125, Comp RATIO
D125, Reverb via `reverb.py`) and the survey confirms it:

- **EQ** LOW/MID/HIGH localise cleanly (+8.0@80 / +6.7@500 / +7.6@8k). Correct.
- **Reverb** DECAY +9 broadband, TONE tilts treble (+9.2@8k), MIX -5 overall. Correct.
- **Compressor** RATIO +9.5 in the mids (the D125 sustain fix), THRESHOLD -18..-21
  (gain reduction), MAKEUP flat +2.2. Correct.
- **Wah** POSITION/BIAS sweep the resonance hard (+17@3k / -14@500), Q +1.5@1k,
  VOLUME flat +6. Correct.
- **Amp** BASS->low (+3.6@80), MIDDLE->mid (+3.1@500), TREBLE->high (+2.6@8k),
  MASTER/INPUT_GAIN flat level. Correct.

**Barely-audible knobs (minor realism gaps):** amp **RESONANCE** -- **FIXED this
session** (was ±0.0 = dead; its lowpass corner was ~30 Hz, BELOW the guitar low-E,
so the band held no signal; raised to ~120 Hz + mix gain so it now moves +3.8 dB
@80 Hz). Remaining weak/coarse: cab **AIR** (3-step bucketed, only changes at the
86/171 boundaries -- coarse, not truly dead), NS **DECAY/DAMP** (the per-band LEVEL
metric does not capture release-TIME changes -- likely a metric blind spot, NS was
bench-accepted), amp **PRESENCE** (+1.3, weak even after D128), comp **RESPONSE**
(+0.1, weak). All low priority vs the tone gaps.

## Where the models differ from real hardware -- prioritized

Ranked by how far off + how much the user would hear it, AFTER the harmonic
cross-check removed the two false positives:

1. **Distortion saturation depth -- Metal (歪が足りない).** PARTLY ADDRESSED this
   session (drive doubled + harder clip = saturates at playing levels). The
   hot-input THD ceiling (~19%) remains, capped by the Unsigned-12 gain path
   (`768 + drive*13`, ~16x) + the dark post-LPF. FULL MT-2 THD still needs the
   **gain-staging restructure** (NEW-STAGE: wider gain word / 2nd drive stage) --
   a separate phase with its own placement/CDC budget.
2. **Whole-rig bass-light (低音が足りない).** FIXED this session -- the root was
   NOT the ~298 Hz HPF the memory recorded (that D101 live-pole was lost in the
   D99 rollback); the amp HP was actually a DEAD first-difference differentiator.
   Restored to a live ~150 Hz one-pole: rig low_vs_mid -22 -> -7..-9 dB. (D100's
   ~90 Hz was rejected as too bassy; ~150 Hz is the middle ground -- ear-bench
   confirms.)
3. **Cab is a 4-tap pseudo-IR.** One shared presence peak (masks amp mids) + no
   sharp >5 kHz rolloff. A real short-IR BRAM convolution is the biggest cab
   lever but a large new-stage phase.
4. **Amp per-model mid masked by the cab presence peak.** Either make the cab
   presence peak per-amp-aware, or move the amp's own mid voicing where the cab
   does not flatten it. New-stage / structural.
5. **Weak/coarse knobs (low priority):** cab AIR (3-step bucketed), amp PRESENCE +
   comp RESPONSE (weak). NS DECAY/DAMP read as ~0 but that is a metric blind spot
   (release-TIME, not band level). Cheap constant/shift work, minor.

**NOT a gap (corrected):** DS-1 "too soft" + TS "too hard" were crest-metric
FALSE positives -- the harmonic series shows DS-1 is the hardest-h3 pedal of all
and TS is a correct moderate soft clip. Do NOT re-tune their clip shape.

Confirmed CORRECT (no change): all 6 OD EQ, all 7 DIST EQ + bass balance,
CleanBoost/BigMuff/FuzzFace/RAT character, amp+cab treble rolloff, cab presence +
rolloff direction.

## Fixes applied this session (Clash source -- "全部やって", offline-verified, building)

Three offline-verified DSP fixes, ALL placement-safe (shifts/constants on
EXISTING stages -- NO new multiply/DSP48, so the D109 CDC margin is preserved):

1. **Amp input HP: dead first-difference -> live one-pole, SHIFT-ONLY (低音不足)**
   (`Amp/Clip.hs`). `ampHighpassFrame` used `onePoleHighpass 509 9`, which Haskell
   parses as `prevOut * (509>>9)` = `prevOut * 0` = a DEAD pole = a bare
   `x - prevIn` first-difference (+6 dB/oct differentiator) that cut the low-E
   ~-45 dB -- the root of the bass-light rig (low_vs_mid -22 dB). Made the pole
   LIVE but SHIFT-ONLY: `prevOut - (prevOut>>7) - (prevOut>>9)` = prevOut*0.9902 =
   the coef-507 pole (~150 Hz), NO multiply. (A first build used the multiply
   idiom `(prevOut*507)>>9` like D124 RAT -- it built timing-clean WNS +0.694 but
   the new DSP48 shifted placement and tightened the D109 DSP-out->DAC CDC pair to
   **+1.079 ns** = knife-edge risk; the shift-only form is bit-identical audio
   with no DSP48 = CDC margin kept.) Offline: rig low_vs_mid **-22.8 -> -7.4
   (JC120), -18.9 -> -7.3 (AC30, now PASS), -21.4 -> -9.2 (JCM800)**; HF slope
   stays negative (cab rolloff intact). Side effect: it also UN-MASKS each amp's
   mid (JCM800 650 Hz +3.9, was -0.3 = gap #4 partly fixed).
2. **Amp RESONANCE made effective** (`Amp/Tone.hs`). The resonance band's lowpass
   was `onePoleShift 9` (~30 Hz, below the low-E -> no signal -> knob DEAD); raised
   to `onePoleShift 7` (~120 Hz speaker-resonance region) + mix gain
   `satShift10Wide -> satShift8Wide`. Offline: RESONANCE 0->100 now moves +3.8 dB
   @80 Hz (was +0.0).
3. **Metal saturation (歪が足りない)** (`Distortion/Pedals.hs`). Doubled the clip
   drive (`satShift8 -> satShift7` into the os4x clip) + lowered the clip floor
   (1.25M -> 1.05M, steeper slope) so it saturates earlier/denser at normal
   playing levels: dist_eval drive curve **-36 dBFS 1% -> 11% THD, -30 12% -> 16%**.
   The hot-input THD ceiling stays ~19% -- intrinsic to the dark MT-2 post-LPF
   (h3 @3 kHz is rolled off; reaching 45% needs a ~5 kHz corner = fizzy/not-MT-2),
   so the post-LPF stays dark (base 13 -> 15). Full MT-2 THD still wants the
   gain-staging restructure (#1 below), but playing-level saturation is now up.

Bypass stays bit-exact (gated stages). dist_eval --check now **7/7 PASS**,
measure --check **15/17** (the 2 marginal FAILs are JC120's cab presence peak on a
clean amp + JCM800 low_vs_mid -9.2 vs -8).

**BUILT + DEPLOYED + PL-smoked (2026-06-16), PENDING ear-bench.** bit/hwh md5
`044735eb5642927aa7b55bac463b498e` / `0540424f95395d6fb91cc4590b4b5bfa`. Timing
MET: WNS **+0.658**, WHS +0.016, all constraints met, route errors 0. D109 CDC
pair `clk_fpga_0->clk` **+1.322** / `clk->clk_fpga_0` +6.864 -- TIGHT (the
shift-only amp HP avoided the +1.079 the multiply gave, but the cumulative
island-logic shift still lands at +1.322; this is within the historically
ACCEPTED range -- D130 was bypass-CLEAN at the tighter +1.251, D125 at +1.491 --
but it is at the D128-aggressive level that once hissed, so **ear-bench the
safe-bypass for hiss FIRST**). Deployed to PYNQ-Z2 192.168.1.9, board sites
md5-matched, PL-smoke PASS (mode-2 DSP, 96.1 kHz, engine alive). Goldens NOT yet
re-blessed (they still track D131; the amp/metal configs intentionally differ --
re-bless with `tests/test_dsp_sim_regression.py --regen` AFTER bench acceptance).
**Rollback to D131 (`fdab62d5`): `git checkout 37114b9 -- hw/Pynq-Z2/bitstreams/`
+ redeploy.**

Reverted (offline-disproven): the DS-1 / TS clip-shape swaps -- the harmonic
cross-check showed both were correct, so the source is back to D131 for those.

Still deferred (true new-stage, beyond a safe constant change): full MT-2 THD via
a gain-staging restructure, real-IR cab convolution, per-amp cab presence.

## Reproduce

```sh
tools/dsp_sim/build_sim.sh                       # once
python3 tools/dsp_sim/measure.py --check         # EQ + rig + cab vs targets
python3 tools/dsp_sim/measure.py --batch         # full table incl. rig_* + HFslp
python3 tools/dsp_sim/dist_eval.py --check       # distortion CHARACTER PASS/FAIL
python3 tools/dsp_sim/measure.py --config rig_4  # JCM800 into cab, full curve
```
