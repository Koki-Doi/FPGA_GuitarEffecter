# Real-pedal voicing targets

This document records the "real-pedal" target style for each effect in
the live Audio-Lab-PYNQ chain and the DSP gap between the deployed
implementation and that target. The goal of this pass is to push the
existing effects closer to the recognised voicing of common pedals,
amps, and cabs **without** adding new GPIOs, new `topEntity` ports, or
new effect stages.

The references named below are inspirations for *algorithmic shape*
only (cf. `DECISIONS.md` D7 / D11 / D14): no commercial-pedal source
code, schematic-derived coefficient table, or GPL DSP code is copied
into this tree. Everything here is hand-rolled in Clash on top of the
existing pipeline.

---

## Noise Suppressor — BOSS NS-2 / NS-1X style (inspired)

| Field | Notes |
| --- | --- |
| Target style | NS-2 / NS-1X-style smoothed gate. Not a hard chopper; the closing ramp should follow the natural decay of the note. |
| Reference behaviour | At low DECAY the gate closes quickly (palm-mute style); at high DECAY the closing ramp is long enough to keep the tail of a note. DAMP controls the closed-gain depth. The threshold should not chatter on hover. |
| Current implementation | `nsLevelPipe -> nsEnv -> nsGain -> nsPipe`. Single threshold (no hysteresis); the gain register can chatter when the envelope hovers near `nsThresholdSample`. Open is fast (`nsAttackStep = 512`), close is decay-controlled. |
| Gap | Single threshold = chatter risk; closed gain at low DAMP can sound unnatural under high gain. |
| DSP change | `nsTargetGain` gains a hysteresis band: open requires `env >= threshold`, close only happens when `env <= threshold - threshold/4`; in between, the current gain register decides. Implemented as one extra comparison + one shift; no new register stage. |
| Risk | Slightly higher fan-out on `nsTargetGain` because it now reads `gain`. Combinational depth is unchanged (still one comparison-and-select). |
| Listening points | High Gain Tight should still close fully; Lead Sustain should not chop the tail of a note; sustained chord at the threshold should not "buzz" on/off. |

## Compressor — MXR Dyna Comp / BOSS CS-3 style (inspired)

| Field | Notes |
| --- | --- |
| Target style | Stereo-linked feed-forward peak compressor with a soft-ish engagement, evens picking and adds sustain without crushing transients. |
| Reference behaviour | At low ratio it should sound like "leveller", barely audible. At high ratio it tightens picking but should not turn the signal into a square wave. Engagement near threshold should be gradual, not a brick wall. |
| Current implementation | `compLevelPipe -> compEnv -> compGain -> compApplyPipe -> compMakeupPipe`. Effective threshold is now `7/8` of the byte-scaled threshold, soft knee begins at `threshold - threshold/8`, reduction uses `(excess >> 12) + (excess >> 14)`, and response steps add a small faster component. |
| Gap | Recording analysis showed the previous soft-knee pass was too subtle on the captured material: crest factor stayed close to Bypass. |
| DSP change | (a) Lower effective threshold by 12.5 %. (b) Widen the soft-knee start to `threshold - threshold/8`. (c) Increase reduction slope about 1.25x vs the previous `excess >> 12` pass. (d) Make envelope release and gain smoothing slightly more responsive. Makeup range stays unchanged. |
| Risk | The THRESHOLD knob engages earlier, so very low-threshold settings can sound more obviously compressed. Existing makeup remains capped, and no new register stage is added. |
| Listening points | Light Sustain and Funk Tight should keep the picking attack; Lead Sustain should sound smoother in engagement; Limiter-ish should still tame loud peaks but not turn quiet bits into mush. |

## Overdrive — generic tube-style overdrive (inspired)

| Field | Notes |
| --- | --- |
| Target style | A general-purpose tube-style overdrive: gentle, even-harmonic-rich saturation, useful for "always-on" crunch ahead of higher-gain pedals. |
| Reference behaviour | Soft clip with a slight asymmetry, so even harmonics show up at moderate drive. Should not get fizzy at high drive. |
| Current implementation | `overdriveDriveMultiplyFrame -> Boost -> Clip -> ToneMultiply -> ToneBlend -> Level`. Drive gain is now `256 + drive*5` (~1x..6x), clip uses `asymSoftClip 2_700_000 2_300_000`, and the level stage adds `softClipK 3_200_000` safety. |
| Gap | Recording analysis showed the previous Overdrive was numerically close to Bypass; the clip knee was not reached often enough at normal input level. |
| DSP change | Raise the drive curve moderately, lower the asymmetric knees, and keep level jumps controlled with an existing-stage safety clip. |
| Risk | DRIVE 70..100 will crunch more clearly than before. The output safety knee prevents a large RMS jump, and the stage remains much lighter than DS-1 / RAT / Metal. |
| Listening points | Light Crunch should sound a touch warmer; clean settings should not be audibly affected because the clip threshold is well above expected level. |

## Distortion: clean_boost — EP / clean-boost style (inspired)

| Field | Notes |
| --- | --- |
| Target style | Mostly-clean transparent boost. Pushes the level by a moderate amount; only saturates when the input is hot. |
| Reference behaviour | Useful as an "always-on" volume boost or a stack stage in front of an overdrive. Should not produce audible clipping by itself at moderate settings. |
| Current implementation | `cleanBoostMulFrame -> cleanBoostShiftFrame -> cleanBoostLevelFrame`. Drive Q8 = `256 + drive*4` (1×..5×) followed by `mulU8 level` and a `softClip` safety. |
| Gap | At drive=255 the boost goes up to 5× which is hotter than a typical clean booster and almost guarantees clipping at any reasonable LEVEL. |
| DSP change | Lower the drive curve to `256 + drive*3` (1×..4×). Replace the symmetric `softClip` in `cleanBoostLevelFrame` with `softClipK 3_200_000` — earlier knee, so the safety clip catches peaks before they hit the saturator. |
| Risk | None — slightly lower headroom usage at high drive; existing presets that ride at drive ≤ 50 are unaffected. |
| Listening points | Solo Boost preset should still feel "louder"; Clean Sustain should remain clean. |

## Distortion: tube_screamer — TS808 / TS9 style (inspired)

| Field | Notes |
| --- | --- |
| Target style | Tube-Screamer-style mid-bump overdrive: low cut at the input, soft asymmetric clip, post low-pass that emphasises the mid-band and rolls off fizz. |
| Reference behaviour | Tightens low end going in; sits forward in a band mix; even at full DRIVE, sounds like an overdrive, not a fuzz. |
| Current implementation | `tubeScreamerHpfFrame (alpha 2..9) -> Mul (1×..9×) -> asymSoftClip (3.5M / 2.8M) -> postLpf (alpha 96..223) -> Level + softClip`. Pre-HPF is very mild; clip knee is high; post-LPF can be fairly bright. |
| Gap | Low cut is too gentle (signal runs in with full bass), max drive is too hot, post-LPF leaves more high-end than a real TS would. The "mid-bump" character is washed out. |
| DSP change | (a) `tubeScreamerHpfFrame`: alpha `3 + (distTight >> 4)` (range 3..18) — stronger low cut. (b) `tubeScreamerMulFrame`: drive curve `256 + drive*6` (1×..6.97× vs. 1×..9×). (c) `tubeScreamerClipFrame`: asym knees `2_900_000 / 2_500_000` (lower → engages earlier and more asymmetric). (d) `tubeScreamerPostLpfFrame`: alpha `64 + (tone >> 1)` (range 64..191 vs. 96..223) — darker post filter at every TONE setting. |
| Risk | TONE knob now sweeps a darker range; this is intentional and matches the TS character. Lowering the drive multiplier means existing TS presets at drive≈45 are slightly less hot. |
| Listening points | Tube Screamer Lead should have a clearer mid-bump. Should not sound piercing at TONE=100. Should not sound like a fuzz at DRIVE=100. |

## Distortion: rat — ProCo RAT style (inspired)

| Field | Notes |
| --- | --- |
| Target style | RAT-style aggressive distortion: hard clipping, post LPF (FILTER) that sucks high frequencies as it is turned up, stays "rough" at high drive. |
| Reference behaviour | Distinctly more aggressive than a TS; hard-clipping character; FILTER controls high-end rolloff (lower = darker). |
| Current implementation | `ratHighpassFrame -> Drive (Q9 ~2×..16×) -> opamp LPF -> hardClip with drive-dep threshold (clamped at 3.75M) -> post LPF (alpha 192) -> tone (alpha 224 - dark)`. |
| Gap | Hard-clip threshold floor is high so the clip stage saturates less aggressively than expected. Post LPF / tone can run too bright. |
| DSP change | (a) `ratClipFrame`: lower threshold floor to `2_500_000` (was `3_750_000`) → more aggressive clip at high DRIVE. (b) `ratPostLowpassFrame`: alpha `176` (was `192`) → slightly more high-end roll-off. (c) `ratToneFrame`: alpha base `200 - dark` (was `224 - dark`) → tone fully bright is darker. |
| Risk | Existing RAT Rhythm preset becomes slightly grittier and slightly darker; still inside the safe-level band. |
| Listening points | RAT Rhythm should sound more "rude" at the same settings. FILTER (TONE) sweep should clearly darken without going dead. |

## Distortion: metal — modern high-gain / MT-2 style (inspired)

| Field | Notes |
| --- | --- |
| Target style | Modern high-gain / MT-2-style metal pedal: tight low end (controlled by TIGHT), strong saturation, post LPF that prevents "fizz" and ear-piercing highs. |
| Reference behaviour | Even at DRIVE=100, the low end stays tight and the highs stay below "ice-pick" frequencies. TIGHT control acts on the input low-cut. |
| Current implementation | `metalHpfFrame (alpha 4..19) -> Mul (Q8 3×..22×) -> hardClip (drive-dep, floor 1.2M) -> postLpf (alpha 64..192) -> Level + softClip`. |
| Gap | Pre-HPF tightening is too mild for "tight metal"; max drive is hot enough to turn the wave into a near-square; post-LPF can still get fizzy. |
| DSP change | (a) `metalHpfFrame`: alpha `6 + (distTight >> 3)` (range 6..37) — tighter low cut. (b) `metalMulFrame`: drive curve `768 + drive*12` (3×..18.95× vs. 3×..22×). (c) `metalClipFrame`: clamp threshold floor to `1_500_000` (was `1_200_000`) → keeps a touch more headroom at full drive (avoids square-wave). (d) `metalPostLpfFrame`: alpha `48 + (tone >> 1)` (range 48..175 vs. 64..192) — darker top end at every TONE. |
| Risk | Metal Tight preset becomes slightly tighter and a touch less ice-picky; level cap is unchanged. |
| Listening points | Metal Tight should feel more "chuggy" with the TIGHT slider. TONE=100 should not be ear-piercing. Sustained palm mutes should stay tight. |

## Distortion: ds1 — BOSS DS-1 style (inspired)

| Field | Notes |
| --- | --- |
| Target style | BOSS DS-1 style edgy crunch. Brighter than tube_screamer and a touch harder; useful for rhythm work where presence matters. |
| Reference behaviour | DRIVE turns up the saturation but the wave never fully squares; TONE keeps top-end presence at every setting; LEVEL is the safe-side knob. |
| Current implementation | `ds1HpfFrame -> ds1MulFrame -> ds1ClipFrame -> ds1ToneFrame -> ds1LevelFrame`. Input HPF alpha `4 + (distTight >> 4)` (range 4..23); drive Q8 `256 + drive*8` (1×..~9×); `asymSoftClip 2_400_000 2_000_000` (lower knees than TS); post-LPF alpha `96 + (tone >> 1)` (range 96..223, brighter than TS); `softClipK 3_000_000` safety on the level stage. |
| Gap (vs reference) | A real DS-1 uses diode-pair hard clipping; the soft-clip approximation makes the engagement softer than the original. |
| DSP change | New stages — already shipped. No further change planned for this voicing pass. |
| Risk | Five-stage block adds register depth; timing reviewed in `TIMING_AND_FPGA_NOTES.md`. |
| Listening points | DS-1 Crunch should feel brighter and a little harder than Tube Screamer Crunch at the same DRIVE / LEVEL. DS-1 Lead should still preserve note articulation at high DRIVE. |

## Distortion: big_muff — Electro-Harmonix Big Muff Pi style (inspired)

| Field | Notes |
| --- | --- |
| Target style | Big Muff Pi style thick fuzz. Sustaining wall-of-sound saturation, mid-scoopy tone, dark top end. Useful for sustaining lead lines and shoegaze textures. |
| Reference behaviour | Lots of pre-gain ahead of two cascaded soft-clip stages; tone control acts as a tilt between mid-scoop and bright. Not as tight as metal — wave should smear. |
| Current implementation | `bigMuffPreFrame -> bigMuffClip1Frame -> bigMuffClip2Frame -> bigMuffToneFrame -> bigMuffLevelFrame`. Pre-gain Q8 `384 + drive*12` (~1.5×..~13×); `softClipK 2_700_000` (medium knee); ~0.75× gain step + `softClipK 2_000_000` (tighter knee); tone LPF alpha `56 + (tone >> 1)` (range 56..183, darker); `softClipK 2_900_000` safety on the level stage. |
| Gap (vs reference) | The classic mid-scoop is approximated by the dark tone LPF; a real Muff has a more pronounced mid notch. We deliberately avoid copying the published tone-stack coefficients. |
| DSP change | New stages — already shipped. No further change planned for this voicing pass. |
| Risk | Two cascaded soft clips on a hot pre-gain can add ~6 dB of total saturation; `softClipK` safety on the level stage prevents it from slamming the chain. |
| Listening points | Big Muff Sustain should sing on long notes; Big Muff Wall should keep its low end without becoming muddy. The dark tone curve should keep fizz off the top. |

## Distortion: fuzz_face — Dallas Arbiter / Dunlop Fuzz Face style (inspired)

| Field | Notes |
| --- | --- |
| Target style | Fuzz Face style raw asymmetric breakup. Touch-sensitive at low DRIVE, broken up at high DRIVE, asymmetric on the negative half (germanium / silicon hybrid feel). |
| Reference behaviour | Even at DRIVE=0 there is some breakup (real Fuzz Faces are sensitive to input level); TONE acts as a "round vs. bright" axis since most real units have no tone control; LEVEL safe-side. |
| Current implementation | `fuzzFacePreFrame -> fuzzFaceClipFrame -> fuzzFaceToneFrame -> fuzzFaceLevelFrame`. Pre-gain Q8 `512 + drive*9` (~2×..~10×, hot floor); `asymSoftClip 1_900_000 1_400_000` (low / asymmetric knees, negative half compresses harder); tone LPF alpha `72 + (tone >> 1)` (range 72..199); `softClipK 2_800_000` safety. |
| Gap (vs reference) | We do not model guitar-volume cleanup behaviour explicitly (real Fuzz Faces clean up when the guitar volume rolls off due to impedance interaction); deliberately scoped out for now. |
| DSP change | New stages — already shipped. No further change planned for this voicing pass. |
| Risk | The asymmetric clip is the harshest of the new pedals; the level stage's `softClipK` is the last line of defence before the post-pedal pipeline. |
| Listening points | Fuzz Face / Fuzz Face Vintage should both feel touch-sensitive; TONE=0 should sound rounded, TONE=100 should brighten without going thin. Picking dynamics should still come through. |

## Amp simulator — generic guitar amp preamp (inspired)

| Field | Notes |
| --- | --- |
| Target style | Generic guitar-amp preamp: input HPF removes sub-low rumble before the gain stage, two soft-clipping stages with character control, BMT tone stack, slow lowpass for resonance, presence highshelf. |
| Reference behaviour | Should not be a hi-fi clean amp — should always have *some* colour, even at low gain. Should not blow up at MASTER=100. |
| Current implementation | `ampHighpassFrame -> Drive -> ampWaveshapeFrame (asym soft clip, character-controlled) -> preLpf -> Stage2 -> ampTone (BMT) -> Power -> Resonance/Presence -> Master`. The analysis pass trims input gain to ~19x, darkens pre-LPF alpha to `128..191`, caps treble with `ampTrebleGain`, caps presence to ~5/8 and resonance to ~3/4, and lowers power/resonance/master safety knees. |
| Gap | Recording analysis showed AmpSim alone still carried too much >5 kHz fizz / air and could sound line-direct when presence and treble were high. |
| DSP change | Implemented in-place: constants / helper choices only, no new register stage. Gain `128 + input_gain*9`, pre-LPF `128 + character/4`, power / resonance safety `softClipK 3_500_000`, master safety `softClipK 3_300_000`, presence `ctrlC * 5/8`. |
| Risk | The amp is darker at high treble/presence and less explosive at MASTER=100. Clean / crunch settings keep their controls but may need slightly more treble if used without Cab. |
| Listening points | Amp ON should add colour without turning clean presets into hi-fi direct. MASTER=100 should not blow the chain. CHARACTER sweep should remain audible. Metal / Big Muff / Fuzz should be less ice-picky through Amp ON. |

## Cab IR — speaker cabinet simulator (inspired)

| Field | Notes |
| --- | --- |
| Target style | A guitar speaker cabinet rolls off both ends — sub-low (~80 Hz) and high (~5 kHz) — and gives the line-direct sound a "speaker box" character. AIR controls the high-shelf "in-the-room" feel. |
| Reference behaviour | With Cab ON the line-direct fizz of the distortion stages should be tamed. Different model selections (open back / British / closed back) should feel audibly different. AIR up should add presence without ice-pick highs. |
| Current implementation | 4-tap convolution with per-model coefficient sets; `model = ctrlC (fCab f)` selects model 0/1/2 and `air = ctrlD (fCab f)` selects one of three capped AIR variants within that model. |
| Gap | Recording analysis showed Cabinet was directionally correct but still too weak above 5 kHz for DS-1 / RAT / Big Muff / Fuzz / Metal, and model 0/1/2 were not distinct enough. |
| DSP change | Implemented in-place by replacing the `cabCoeff` table again. Model 0 = 1x12 open back style with some air, model 1 = 2x12 combo style, model 2 = 4x12 closed back style with the lowest direct tap and strongest delayed-body taps. AIR increases direct tap only within a capped table. `cabLevelMixFrame` keeps the existing timing-friendly `softClip`; the high-rolloff change is in the tap table, not a new lower-knee post-Cab clip. |
| Risk | Model 2 is darker and thicker; Clean / Ambient should prefer model 0/1 when openness matters. Fixed coefficient changes add no new combinational topology. |
| Listening points | Cab model 0 should stay clear on Basic Clean / Light Crunch. Model 1 should keep TS/RAT present but less fizzy. Model 2 should make Metal / Big Muff / Fuzz Face less painful. AIR=100 should add presence but not ice-pick. |

## EQ — pedalboard post-EQ

| Field | Notes |
| --- | --- |
| Target style | Three-band pedalboard EQ: neutral at 128/128/128, useful boost / cut around it, no audible clipping when boosted to max. |
| Reference behaviour | low/mid/high knobs sweep their respective bands smoothly. Boost+boost+boost at max should not blow the chain. |
| Current implementation | `eqFilterFrame -> eqBandFrame -> eqProductsFrame -> eqMixFrame`. `eqMixFrame` uses `satShift7` only — no soft clip safety. |
| Gap | Boosting all three bands to 255 produces hard saturation in `satWide` (audible distortion). |
| DSP change | Wrap the `satShift7 accL` / `satShift7 accR` in `eqMixFrame` with `softClip` so high-boost saturates gracefully rather than hard-clipping at the EQ stage output. |
| Risk | One additional `softClip` per channel inside an existing register stage; combinational depth grows by one comparison + shift. Should sit comfortably inside the existing timing band. |
| Listening points | EQ at 128/128/128 should be bit-exact identical (softClip is identity below knee). EQ at 255/255/255 should saturate softly instead of hard. |

## Reverb — pedal reverb (inspired)

| Field | Notes |
| --- | --- |
| Target style | A pedal-style reverb (plate/spring/hall flavour, depending on tone): mix low and decay moderate is natural; tone bright should still have *some* high-frequency damping in the recirculation path; decay high should not run away. |
| Reference behaviour | A natural decaying reverb has the high frequencies fall off faster than the lows. Reverbs that don't damp highs sound metallic and "ringy". |
| Current implementation | BRAM tap delay → `reverbToneProductsFrame` (one-pole tone blend with previous tap) → feedback → mix. TONE byte (`ctrlB (fReverb)`) blends current tap with previous: TONE=255 → all tap, no damping. |
| Gap | At TONE=255 the high-frequency damping disappears entirely; sustained reverb tails sound metallic. |
| DSP change | In `reverbToneProductsFrame`, scale the tone byte: `toneScaled = toneByte - (toneByte >> 3)` (max 224, never reaches 255). Always at least ~12 % of the previous tap is mixed in, providing some high-frequency damping even at TONE=100. |
| Risk | TONE=100 is now a touch darker (intentional). All other settings essentially unchanged. |
| Listening points | Ambient Clean should keep its space without going metallic. Metal Tight reverb should not ring. DECAY sweep at TONE=100 should feel more natural. |

---

## What is **not** in scope this pass

- No new GPIO / no new control byte / no new `topEntity` port.
- No new effect stage (Clash pipeline shape unchanged; only the
  contents of existing stages move).
- `block_design.tcl` is untouched.
- C++ DSP prototypes are not revived (`DECISIONS.md` D13).
- `axi_gpio_eq.ctrlD` / `axi_gpio_noise_suppressor.ctrlD` reserved
  bytes / bits remain reserved; this pass does not consume them.
  Note: `axi_gpio_distortion.ctrlD[3..5]` (`ds1` / `big_muff` /
  `fuzz_face`) were promoted from reserved to implemented in the
  follow-up reserved-pedal implementation branch; bit 7 stays
  reserved.
- Notebook UI shape is unchanged. Existing chain presets keep working
  byte-for-byte (any change to preset constants is a small numeric
  re-tune, not a structural change).

## Acceptance criteria

- All ten chain presets apply cleanly and the smoke-test on the board
  reports the expected bytes.
- `tests/test_overlay_controls.py` passes.
- Vivado WNS stays in the accepted deploy band (latest audio-analysis
  voicing pass: `-8.731 ns` vs previous `-7.917 ns`); WHS / THS stay
  non-negative.
- ADC HPF default-on (`R19_ADC_CONTROL == 0x23`) is preserved.
- No reference-pedal source code, schematic-exact coefficient table,
  or GPL DSP code is added to the tree.
