{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Distortion where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

-- ---- Legacy distortion stage -----------------------------------------
-- Restored to its pre-refactor shape so the existing
-- set_guitar_effects(distortion_on=True, distortion=, distortion_tone=,
-- distortion_level=) API keeps working untouched. The legacy stage is
-- automatically bypassed when any new pedal-mask bit is set, so that
-- exclusive=True at the Python level really is exclusive.

distortionLegacyOn :: Frame -> Bool
distortionLegacyOn f = flag2 (fGate f) && not (anyDistPedalOn f)

distortionDriveMultiplyFrame :: Frame -> Frame
distortionDriveMultiplyFrame f =
  f
    { fAccL = if on then mulU12 (monoSample f) driveGain else 0
    , fAccR = 0
    , fAcc2L = resize threshold
    }
 where
  on = distortionLegacyOn f
  amount = ctrlC (fDist f)
  driveGain = resize (256 + (resize amount * 8 :: Unsigned 11)) :: Unsigned 12
  rawThreshold = 8_388_607 - (resize (asSigned9 amount) * 24_000) :: Signed 25
  clampedThreshold = if rawThreshold < 1_800_000 then 1_800_000 else rawThreshold
  threshold = resize clampedThreshold :: Sample

distortionDriveBoostFrame :: Frame -> Frame
distortionDriveBoostFrame f =
  setMonoWet (if on then satShift8 (fAccL f) else monoSample f) f
 where
  on = distortionLegacyOn f

distortionDriveClipFrame :: Frame -> Frame
distortionDriveClipFrame f =
  setMonoSample (if on then hardClip (monoWet f) threshold else monoSample f) f
 where
  on = distortionLegacyOn f
  threshold = resize (fAcc2L f) :: Sample

distortionToneMultiplyFrame :: Sample -> Frame -> Frame
distortionToneMultiplyFrame prev f =
  f
    { fAccL = if on then mulU8 (monoSample f) tone else 0
    , fAccR = 0
    , fAcc2L = if on then mulU8 prev toneInv else 0
    , fAcc2R = 0
    }
 where
  on = distortionLegacyOn f
  tone = ctrlA (fDist f)
  toneInv = 255 - tone

distortionToneBlendFrame :: Frame -> Frame
distortionToneBlendFrame f =
  setMonoWet (if on then tone else monoSample f) f
 where
  on = distortionLegacyOn f
  tone = satShift8 (fAccL f + fAcc2L f)

distortionLevelFrame :: Frame -> Frame
distortionLevelFrame f =
  setMonoSample (if on then out else monoSample f) f
 where
  on = distortionLegacyOn f
  level = ctrlB (fDist f)
  out = satShift7 (mulU8 (monoWet f) level)

-- ---- Pedal-style distortion stages -----------------------------------
-- Each pedal is a small, independently enabled pipeline section. The
-- Frame moves through the same physical stages whether the pedal is on
-- or off; when off, every frame transform leaves fL/fR untouched, so
-- the chain is bit-exact bypass.
--
-- Implemented in this build: clean_boost, tube_screamer, ds1,
-- big_muff, fuzz_face, metal_distortion. rat_style is intentionally a
-- no-op here because the existing RAT stage upstream covers it. Bit 7
-- of the pedal mask remains reserved for an 8th pedal slot.

-- ---- clean_boost (3 stages: mul, shift, level+safety) ---------------

cleanBoostMulFrame :: Frame -> Frame
cleanBoostMulFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = cleanBoostOn f
  drive = ctrlC (fDist f)
  -- Real-pedal voicing pass: lower the boost ceiling from ~5x to ~4x
  -- (1.0x at drive=0, ~4x at drive=255) so the clean booster stays
  -- mostly clean unless really pushed.
  gain = resize (256 + (resize drive * 3 :: Unsigned 11)) :: Unsigned 12

cleanBoostShiftFrame :: Frame -> Frame
cleanBoostShiftFrame f =
  setMonoSample (if on then satShift8 (fAccL f) else monoSample f) f
 where
  on = cleanBoostOn f

cleanBoostLevelFrame :: Frame -> Frame
cleanBoostLevelFrame f =
  setMonoSample (if on then softClipK safetyKnee afterLevel else monoSample f) f
 where
  on = cleanBoostOn f
  level = ctrlB (fDist f)
  afterLevel = satShift7 (mulU8 (monoSample f) level)
  -- Real-pedal voicing pass: lower the safety knee from ~4.2M to ~3.2M
  -- so the clean booster catches peaks before they reach the saturator.
  safetyKnee = 3_200_000 :: Sample

-- ---- tube_screamer (5 stages: HPF, mul, clip, post-LPF, level) -------

tubeScreamerHpfFrame :: Sample -> Frame -> Frame
tubeScreamerHpfFrame prevLp f =
  (if on then setMonoSample hp else setMonoSample x) (setMonoEqLow lp f)
 where
  on = tubeScreamerOn f
  -- Real-pedal voicing pass: tighten the input low cut. Range bumped
  -- from 2..9 to 3..18 so the bass that hits the clip stage drops with
  -- TIGHT, contributing to the TS-style mid bump.
  alpha = 3 + (distTight (fOd f) `shiftR` 4)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x
  hp = satWide (resize x - resize lp :: Wide)

tubeScreamerMulFrame :: Frame -> Frame
tubeScreamerMulFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = tubeScreamerOn f
  drive = ctrlC (fDist f)
  -- Real-pedal voicing pass: lower the maximum drive so even at
  -- DRIVE=100 the TS still sounds like an overdrive (not a fuzz).
  -- Q8 gain: 1x..~6.97x (was 1x..~9x).
  gain = resize (256 + (resize drive * 6 :: Unsigned 12)) :: Unsigned 12

tubeScreamerClipFrame :: Frame -> Frame
tubeScreamerClipFrame f =
  setMonoSample (if on then asymSoftClip kneeP kneeN boosted else monoSample f) f
 where
  on = tubeScreamerOn f
  boosted = satShift8 (fAccL f)
  -- Real-pedal voicing pass: lower the asym clip knees so the soft
  -- clip engages earlier and a touch more asymmetrically (TS-style
  -- diode-to-ground feedback character).
  kneeP = 2_900_000 :: Sample
  kneeN = 2_500_000 :: Sample

tubeScreamerPostLpfFrame :: Sample -> Frame -> Frame
tubeScreamerPostLpfFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = tubeScreamerOn f
  tone = ctrlA (fDist f)
  -- Real-pedal voicing pass: shift the post-LPF range darker. Range
  -- 64..191 (was 96..223) emphasises the mid band and rolls off the
  -- top end at every TONE setting, so even at TONE=100 the TS does
  -- not sound piercing under high-gain stacking.
  alpha = 64 + (tone `shiftR` 1)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

tubeScreamerLevelFrame :: Frame -> Frame
tubeScreamerLevelFrame f =
  setMonoSample (if on then softClip afterLevel else monoSample f) f
 where
  on = tubeScreamerOn f
  level = ctrlB (fDist f)
  afterLevel = satShift7 (mulU8 (monoSample f) level)

-- ---- metal_distortion (5 stages: tight HPF, mul, hard clip,
--                        post-LPF, level) -----------------------------

metalHpfFrame :: Sample -> Frame -> Frame
metalHpfFrame prevLp f =
  (if on then setMonoSample hp else setMonoSample x) (setMonoEqLow lp f)
 where
  on = metalDistortionOn f
  -- Real-pedal voicing pass: tighter low cut. Range bumped from
  -- 4..19 to 6..37 so TIGHT actually tightens the low end for
  -- modern-metal-style palm-mute response.
  alpha = 6 + (distTight (fOd f) `shiftR` 3)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x
  hp = satWide (resize x - resize lp :: Wide)

metalMulFrame :: Frame -> Frame
metalMulFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = metalDistortionOn f
  drive = ctrlC (fDist f)
  -- Real-pedal voicing pass: lower the maximum drive from ~22x to
  -- ~18.95x so the wave does not crash so close to a square at full
  -- DRIVE -- still plenty of saturation, just less ear-fatigue.
  gain = resize (768 + (resize drive * 12 :: Unsigned 12)) :: Unsigned 12

metalClipFrame :: Frame -> Frame
metalClipFrame f =
  setMonoSample (if on then hardClip boosted threshold else monoSample f) f
 where
  on = metalDistortionOn f
  drive = ctrlC (fDist f)
  driveS = resize (asSigned9 drive) :: Signed 25
  -- Real-pedal voicing pass: raise the threshold floor from 1.2M to
  -- 1.5M so the hard clip keeps a touch more headroom at full DRIVE
  -- (less square-wave, more crunchy saturation).
  rawT = 3_500_000 - driveS * 5_000 :: Signed 25
  threshold = resize (if rawT < 1_500_000 then 1_500_000 else rawT) :: Sample
  boosted = satShift8 (fAccL f)

metalPostLpfFrame :: Sample -> Frame -> Frame
metalPostLpfFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = metalDistortionOn f
  tone = ctrlA (fDist f)
  -- Real-pedal voicing pass: shift the post-LPF range darker. Range
  -- 48..175 (was 64..192) keeps fizz off the top end at every TONE.
  alpha = 48 + (tone `shiftR` 1)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

metalLevelFrame :: Frame -> Frame
metalLevelFrame f =
  setMonoSample (if on then softClip afterLevel else monoSample f) f
 where
  on = metalDistortionOn f
  level = ctrlB (fDist f)
  afterLevel = satShift7 (mulU8 (monoSample f) level)

-- ---- ds1 (BOSS DS-1 style; 5 stages: HPF, mul, asym hard/soft hybrid
--                clip, post LPF, level+safety) ------------------------
--
-- Voiced for a brighter, edgier crunch than tube_screamer: the input
-- HPF tightens with TIGHT, the asym soft clip uses lower knees so the
-- saturation hits earlier, and the post LPF starts brighter so the top
-- end stays present even at moderate TONE. Reference: BOSS DS-1 only
-- by name and parameter idea; no schematics, no reference source code.

ds1HpfFrame :: Sample -> Frame -> Frame
ds1HpfFrame prevLp f =
  (if on then setMonoSample hp else setMonoSample x) (setMonoEqLow lp f)
 where
  on = ds1On f
  -- Moderate input low cut; TIGHT range 4..23 (between TS and metal).
  alpha = 4 + (distTight (fOd f) `shiftR` 4)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x
  hp = satWide (resize x - resize lp :: Wide)

ds1MulFrame :: Frame -> Frame
ds1MulFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = ds1On f
  drive = ctrlC (fDist f)
  -- Q8 gain ~1x..~9x. A bit more push than TS, less than metal.
  gain = resize (256 + (resize drive * 8 :: Unsigned 12)) :: Unsigned 12

ds1ClipFrame :: Frame -> Frame
ds1ClipFrame f =
  setMonoSample (if on then asymSoftClip kneeP kneeN boosted else monoSample f) f
 where
  on = ds1On f
  boosted = satShift8 (fAccL f)
  -- Lower knees than TS for a harder edge but still soft (DS-1 has
  -- diode-pair hard clip; we approximate with asym soft to keep
  -- timing comparable to the existing pedals).
  kneeP = 2_400_000 :: Sample
  kneeN = 2_000_000 :: Sample

ds1ToneFrame :: Sample -> Frame -> Frame
ds1ToneFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = ds1On f
  tone = ctrlA (fDist f)
  -- Brighter than TS; range 96..223 -> top end stays present at every
  -- TONE setting but never reaches full pass-through.
  alpha = 96 + (tone `shiftR` 1)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

ds1LevelFrame :: Frame -> Frame
ds1LevelFrame f =
  setMonoSample (if on then softClipK safetyKnee afterLevel else monoSample f) f
 where
  on = ds1On f
  level = ctrlB (fDist f)
  afterLevel = satShift7 (mulU8 (monoSample f) level)
  -- Output safety: the level stage soft-clips before reaching the
  -- post-pedal pipeline so a misuse of LEVEL cannot slam the saturator.
  safetyKnee = 3_000_000 :: Sample

-- ---- big_muff (Big Muff Pi style; 5 stages: pre-gain, clip1, clip2,
--                tone scoop, level+safety) ----------------------------
--
-- Voiced for thick fuzz/distortion: heavier pre gain than DS-1, two
-- cascaded soft clip stages for sustaining wall-of-sound saturation,
-- a darker tone LPF to keep fizz off the top end. Reference:
-- Electro-Harmonix Big Muff Pi only by name and parameter idea; no
-- schematics, no reference source code.

bigMuffPreFrame :: Frame -> Frame
bigMuffPreFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = bigMuffOn f
  drive = ctrlC (fDist f)
  -- Q8 gain ~1.5x..~13x. Big Muff has lots of pre-gain; floor 384 so
  -- even drive=0 already saturates lightly through the cascaded clips.
  gain = resize (384 + (resize drive * 12 :: Unsigned 12)) :: Unsigned 12

bigMuffClip1Frame :: Frame -> Frame
bigMuffClip1Frame f =
  setMonoSample (if on then softClipK kneeFirst boosted else monoSample f) f
 where
  on = bigMuffOn f
  boosted = satShift8 (fAccL f)
  -- First clip stage: medium knee, soft slope to keep some sustain.
  kneeFirst = 2_700_000 :: Sample

bigMuffClip2Frame :: Frame -> Frame
bigMuffClip2Frame f =
  setMonoSample (if on then softClipK kneeSecond afterMore else monoSample f) f
 where
  on = bigMuffOn f
  -- Second pass through a lighter (~0.75x via Q8 192) gain ahead of a
  -- tighter knee. Cascaded soft clips give the Muff its characteristic
  -- thick saturation without a hard wall.
  afterMore = satShift8 (mulU8 (monoSample f) 192)
  kneeSecond = 2_000_000 :: Sample

bigMuffToneFrame :: Sample -> Frame -> Frame
bigMuffToneFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = bigMuffOn f
  tone = ctrlA (fDist f)
  -- Darker tone curve: alpha range 56..183 keeps top-end fizz off the
  -- output even at TONE=100 (still brighter than TS at high TONE).
  alpha = 56 + (tone `shiftR` 1)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

bigMuffLevelFrame :: Frame -> Frame
bigMuffLevelFrame f =
  setMonoSample (if on then softClipK safetyKnee afterLevel else monoSample f) f
 where
  on = bigMuffOn f
  level = ctrlB (fDist f)
  afterLevel = satShift7 (mulU8 (monoSample f) level)
  -- Output safety knee, slightly tighter than DS-1 because Muff drives
  -- a hotter signal into this stage.
  safetyKnee = 2_900_000 :: Sample

-- ---- fuzz_face (Fuzz Face style; 4 stages: pre-gain, asym clip,
--                tone, level+safety) ----------------------------------
--
-- Voiced for raw, asymmetric fuzz: the pre stage already has a hot
-- floor so even DRIVE=0 produces some breakup, the clip stage uses
-- aggressively low asymmetric knees so the negative half compresses
-- harder than the positive half, and the tone LPF maps to a
-- "round vs. bright" axis since real Fuzz Faces typically have no
-- tone control. Reference: Dallas Arbiter / Dunlop Fuzz Face only by
-- name and parameter idea; no schematics, no reference source code.

fuzzFacePreFrame :: Frame -> Frame
fuzzFacePreFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = fuzzFaceOn f
  drive = ctrlC (fDist f)
  -- Q8 gain ~2x..~10x. Floor 512 so the fuzz is sensitive to input
  -- level even at drive=0 (Fuzz Faces are notoriously touch-sensitive).
  gain = resize (512 + (resize drive * 9 :: Unsigned 12)) :: Unsigned 12

fuzzFaceClipFrame :: Frame -> Frame
fuzzFaceClipFrame f =
  setMonoSample (if on then asymSoftClip kneeP kneeN boosted else monoSample f) f
 where
  on = fuzzFaceOn f
  boosted = satShift8 (fAccL f)
  -- Strong asymmetry: the negative half compresses harder, giving the
  -- broken-up germanium-style waveform shape.
  kneeP = 1_900_000 :: Sample
  kneeN = 1_400_000 :: Sample

fuzzFaceToneFrame :: Sample -> Frame -> Frame
fuzzFaceToneFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = fuzzFaceOn f
  tone = ctrlA (fDist f)
  -- "Round vs. bright": alpha range 72..199 -> TONE=0 is round and
  -- woolly, TONE=100 brightens up but still rolls off the very top.
  alpha = 72 + (tone `shiftR` 1)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

fuzzFaceLevelFrame :: Frame -> Frame
fuzzFaceLevelFrame f =
  setMonoSample (if on then softClipK safetyKnee afterLevel else monoSample f) f
 where
  on = fuzzFaceOn f
  level = ctrlB (fDist f)
  afterLevel = satShift7 (mulU8 (monoSample f) level)
  -- Output safety knee tighter than DS-1 / Big Muff because the fuzz
  -- stage produces hotter peaks.
  safetyKnee = 2_800_000 :: Sample

ratHighpassFrame :: Sample -> Sample -> Frame -> Frame
ratHighpassFrame prevIn prevOut f =
  setMonoWet (if on then highpass x prevIn prevOut else x) (setMonoDry x f)
 where
  on = flag4 (fGate f)
  x = monoSample f
  highpass x prevIn prevOut =
    satWide (resize x - resize prevIn + ((resize prevOut :: Wide) * 254 `shiftR` 8))

ratDriveMultiplyFrame :: Frame -> Frame
ratDriveMultiplyFrame f =
  f{fAccL = if on then mulU12 (monoWet f) driveGain else 0, fAccR = 0}
 where
  on = flag4 (fGate f)
  driveGain = resize (512 + (resize (ctrlC (fRat f)) * 14 :: Unsigned 12)) :: Unsigned 12

ratDriveBoostFrame :: Frame -> Frame
ratDriveBoostFrame f =
  setMonoWet (if on then satShift8 (fAccL f) else monoSample f) f
 where
  on = flag4 (fGate f)

ratOpAmpLowpassFrame :: Sample -> Frame -> Frame
ratOpAmpLowpassFrame prev f =
  setMonoWet (if on then low else monoSample f) f
 where
  on = flag4 (fGate f)
  alpha = 192 - resize (ctrlC (fRat f) `shiftR` 1) :: Unsigned 8
  low = onePoleU8 alpha prev (monoWet f)

ratClipFrame :: Frame -> Frame
ratClipFrame f =
  setMonoWet (if on then hardClip (monoWet f) threshold else monoSample f) f
 where
  on = flag4 (fGate f)
  amount = ctrlC (fRat f)
  -- Real-pedal voicing pass: lower the clamp floor so the hard clip
  -- engages more aggressively at high DRIVE. Floor was 3.75M; at
  -- 2.5M the clip stage saturates harder, giving the RAT more "rude"
  -- character at the top of the DRIVE knob.
  rawThreshold = 6_291_456 - (resize (asSigned9 amount) * 9_000) :: Signed 25
  clampedThreshold = if rawThreshold < 2_500_000 then 2_500_000 else rawThreshold
  threshold = resize clampedThreshold :: Sample

ratPostLowpassFrame :: Sample -> Frame -> Frame
-- Real-pedal voicing pass: alpha lowered from 192 to 176 so a touch
-- more high-frequency content is rolled off after the hard clip,
-- matching the darker top end of a real RAT.
ratPostLowpassFrame prev f =
  setMonoWet (if on then onePoleU8 176 prev (monoWet f) else monoSample f) f
 where
  on = flag4 (fGate f)

ratToneFrame :: Sample -> Frame -> Frame
ratToneFrame prev f =
  setMonoWet (if on then onePoleU8 alpha prev (monoWet f) else monoSample f) f
 where
  on = flag4 (fGate f)
  dark = resize ((resize (ctrlA (fRat f)) * 3 :: Unsigned 10) `shiftR` 2) :: Unsigned 8
  -- Real-pedal voicing pass: shift the FILTER (TONE) range so even
  -- fully bright still has some upper roll-off (alpha base 200 vs 224).
  alpha = 200 - dark

ratLevelFrame :: Frame -> Frame
ratLevelFrame f =
  setMonoWet (if on then out else monoSample f) f
 where
  on = flag4 (fGate f)
  level = ctrlB (fRat f)
  out = satShift7 (mulU8 (monoWet f) level)

ratMixFrame :: Frame -> Frame
ratMixFrame f =
  setMonoSample (if on then softClip mixed else monoSample f) f
 where
  on = flag4 (fGate f)
  mix = ctrlD (fRat f)
  invMix = 255 - mix
  mixed = satShift8 (mulU8 (monoDry f) invMix + mulU8 (monoWet f) mix)
