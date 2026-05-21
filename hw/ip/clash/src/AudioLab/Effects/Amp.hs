{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Amp where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

-- ---------------------------------------------------------------------
-- D54 amp_tone.ctrlD layout:
--   bit  7 : ampDriveMode (0 = Clean, 1 = Drive)
--   bits 6..2 : reserved (0)
--   bits 1..0 : ampModelIdx (0 = jc_clean, 1 = clean_combo,
--                            2 = british_crunch, 3 = high_gain_stack)
--
-- The legacy D52 "character byte" is gone: the user no longer dials
-- amp_character, the model index alone picks a centre voicing, and
-- the new drive_mode bit branches the clip/preLPF/gain stages
-- independently of the model. The four legacy "character" bytes
-- 26/89/153/216 are preserved as ``ampCharForModel`` so the existing
-- knee / alpha / treble-trim formulas keep their character bands.
-- ---------------------------------------------------------------------

ampModelIdxF :: Frame -> Unsigned 2
ampModelIdxF f = unpack (slice d25 d24 (fAmpTone f))

ampDriveModeF :: Frame -> Bool
ampDriveModeF f = slice d31 d31 (fAmpTone f) == (1 :: BitVector 1)

-- | Centre character byte per amp model (same band centres as D52).
ampCharForModel :: Unsigned 2 -> Unsigned 8
ampCharForModel idx = case idx of
  0 -> 26
  1 -> 89
  2 -> 153
  _ -> 216

ampHighpassFrame :: Sample -> Sample -> Frame -> Frame
ampHighpassFrame prevIn prevOut f =
  setMonoWet (if on then highpass x prevIn prevOut else x) (setMonoDry x f)
 where
  on = flag6 (fGate f)
  x = monoSample f
  highpass x prevIn prevOut =
    satWide (resize x - resize prevIn + ((resize prevOut :: Wide) * 253 `shiftR` 8))

ampDriveMultiplyFrame :: Frame -> Frame
ampDriveMultiplyFrame f =
  f{fAccL = if on then mulU12 (monoWet f) gain else 0, fAccR = 0}
 where
  on = flag6 (fGate f)
  -- 1.0x to about 19x using Q7-style post shift. The recording-analysis
  -- pass trims the ceiling again so Amp-only and post-pedal use do not
  -- create line-direct fizz before the cabinet stage.
  gain = resize (128 + (resize (ctrlA (fAmp f)) * 9 :: Unsigned 12)) :: Unsigned 12

ampDriveBoostFrame :: Frame -> Frame
ampDriveBoostFrame f =
  setMonoWet (if on then satShift7 (fAccL f) else monoSample f) f
 where
  on = flag6 (fGate f)

-- | Soft asymmetric clip. ``intensity`` keeps the existing knee scale
-- (driven by the per-model character byte) so Clean mode's clip
-- behaviour is identical to D52 / D53 for the labelled models. When
-- ``drive`` is True, the knees shrink by an additional model-aware
-- delta (and the negative-knee shift drops from 3 to 2) so the same
-- input clips earlier AND harder -- a real DSP branch, not a volume
-- difference. The legacy ``intensity = 0`` case (used by the legacy
-- ``amp_character`` fallback path with a low percent value) keeps the
-- D52 knees unchanged regardless of drive_mode so older notebooks see
-- no behavioural change.
ampAsymClip :: Unsigned 8 -> Bool -> Sample -> Sample
ampAsymClip intensity drive x
  | x > posKnee =
      satWide (resize (resize posKnee + (((resize x :: Signed 25) - resize posKnee) `shiftR` posShift) :: Signed 25))
  | x < negate negKnee =
      satWide (resize (resize (negate negKnee) + (((resize x :: Signed 25) + resize negKnee) `shiftR` negShift) :: Signed 25))
  | otherwise = x
 where
  ch :: Signed 25
  ch = resize (asSigned9 intensity)
  -- Extra knee shrink in Drive mode. Linear in the character byte so
  -- the high-gain model takes the largest cut.
  posDriveDelta :: Signed 25
  posDriveDelta = if drive then ch * 2_000 else 0
  negDriveDelta :: Signed 25
  negDriveDelta = if drive then ch * 1_800 else 0
  posKnee = resize (4_900_000 - ch * 7_000 - posDriveDelta) :: Sample
  negKnee = resize (4_350_000 - ch * 6_200 - negDriveDelta) :: Sample
  posShift = 2 :: Int
  negShift = if drive then 2 else 3

ampWaveshapeFrame :: Frame -> Frame
ampWaveshapeFrame f =
  setMonoWet (if on then ampAsymClip intensity drive (monoWet f) else monoSample f) f
 where
  on = flag6 (fGate f)
  idx = ampModelIdxF f
  drive = ampDriveModeF f
  intensity = ampCharForModel idx

ampPreLowpassFrame :: Sample -> Frame -> Frame
ampPreLowpassFrame prev f =
  setMonoWet (if on then onePoleU8 alpha prev (monoWet f) else monoSample f) f
 where
  on = flag6 (fGate f)
  idx = ampModelIdxF f
  drive = ampDriveModeF f
  charByte = ampCharForModel idx
  -- Base alpha = 128 + (char >> 2) keeps the D52 voicing centres.
  baseAlpha = 128 + (charByte `shiftR` 2)
  -- Per-model post-clip darken (same as D52, indexed by ampModelIdx
  -- directly instead of going through the ``ampModelSel`` byte
  -- quantiser).
  modelDarken = case idx of
    0 ->  0 :: Unsigned 8
    1 ->  4
    2 -> 12
    _ -> 24
  -- D54 Drive mode adds an extra alpha cut to absorb the new clip
  -- stage's high-frequency content (otherwise the harder clip would
  -- brighten the post-LPF signal again).
  driveDarken = if drive then 12 :: Unsigned 8 else 0
  alpha = baseAlpha - modelDarken - driveDarken

ampSecondStageMultiplyFrame :: Frame -> Frame
ampSecondStageMultiplyFrame f =
  f{fAccL = if on then mulU9 (monoWet f) gain else 0, fAccR = 0}
 where
  on = flag6 (fGate f)
  idx = ampModelIdxF f
  drive = ampDriveModeF f
  charByte = ampCharForModel idx
  -- D54 Drive mode adds a small fixed bonus to the second-stage gain;
  -- combined with the harder asym-clip below it pushes more signal
  -- into the clipper instead of just raising output level.
  driveBonus :: Unsigned 9
  driveBonus = if drive then 24 else 0
  gain :: Unsigned 9
  gain = 112
       + resize (ctrlA (fAmp f) `shiftR` 3)
       + resize (charByte `shiftR` 2)
       + driveBonus

ampSecondStageFrame :: Frame -> Frame
ampSecondStageFrame f =
  setMonoWet (if on then ampAsymClip intensity drive (satShift7 (fAccL f)) else monoSample f) f
 where
  on = flag6 (fGate f)
  idx = ampModelIdxF f
  drive = ampDriveModeF f
  -- Softer than the first clip stage; keeps low-gain response
  -- touch-sensitive by halving the per-model intensity.
  intensity = ampCharForModel idx `shiftR` 1

ampToneFilterFrame :: Sample -> Sample -> Frame -> Frame
ampToneFilterFrame prevLow prevHighLp f =
  f
    { fEqLowL = low
    , fEqLowR = low
    , fEqHighLpL = highLp
    , fEqHighLpR = highLp
    }
 where
  x = monoWet f
  low = prevLow + resize (((resize x - resize prevLow) :: Signed 25) `shiftR` 5)
  highLp = prevHighLp + resize (((resize x - resize prevHighLp) :: Signed 25) `shiftR` 2)

ampToneBandFrame :: Frame -> Frame
ampToneBandFrame f =
  f
    { fEqMidL = mid
    , fEqMidR = mid
    , fEqHighL = high
    , fEqHighR = high
    }
 where
  mid = satWide (resize (monoEqHighLp f) - resize (monoEqLow f))
  high = satWide (resize (monoWet f) - resize (monoEqHighLp f))

ampToneGain :: Unsigned 8 -> Unsigned 8
ampToneGain x = 64 + (x `shiftR` 1)

ampTrebleGain :: Unsigned 2 -> Unsigned 8 -> Unsigned 8
ampTrebleGain idx x = base - modelTrim
 where
  -- Keep the 2..4 kHz bite from the tone stack, but avoid restoring as
  -- much raw 8..16 kHz fizz when TREBLE is near 100.
  base = 64 + ((x - (x `shiftR` 3) - (x `shiftR` 4)) `shiftR` 1)
  modelTrim = case idx of
    0 -> 0 :: Unsigned 8
    1 -> 2
    2 -> 5
    _ -> 9

ampToneProductsFrame :: Frame -> Frame
ampToneProductsFrame f =
  f
    { fAccL = if on then mulU8 (monoEqLow f) (ampToneGain (ctrlA (fAmpTone f))) else 0
    , fAccR = 0
    , fAcc2L = if on then mulU8 (monoEqMid f) (ampToneGain (ctrlB (fAmpTone f))) else 0
    , fAcc2R = 0
    , fAcc3L = if on then mulU8 (monoEqHigh f) (ampTrebleGain idx (ctrlC (fAmpTone f))) else 0
    , fAcc3R = 0
    }
 where
  on = flag6 (fGate f)
  idx = ampModelIdxF f

ampToneMixFrame :: Frame -> Frame
ampToneMixFrame f =
  setMonoWet (if on then satShift7 acc else monoSample f) f
 where
  on = flag6 (fGate f)
  acc = fAccL f + fAcc2L f + fAcc3L f

ampPowerFrame :: Frame -> Frame
ampPowerFrame f =
  setMonoWet (if on then softClipK 3_400_000 (monoWet f) else monoSample f) f
 where
  on = flag6 (fGate f)

ampResPresenceFilterFrame :: Sample -> Sample -> Frame -> Frame
ampResPresenceFilterFrame prevRes prevPresence f =
  f
    { fEqLowL = res
    , fEqLowR = res
    , fEqHighLpL = presenceLp
    , fEqHighLpR = presenceLp
    }
 where
  x = monoWet f
  -- Slow lowpass approximates resonance around the speaker low-end region.
  res = prevRes + resize (((resize x - resize prevRes) :: Signed 25) `shiftR` 8)
  presenceLp = prevPresence + resize (((resize x - resize prevPresence) :: Signed 25) `shiftR` 3)

ampResPresenceMixFrame :: Frame -> Frame
ampResPresenceMixFrame f =
  setMonoWet (if on then softClipK 3_400_000 wet else monoSample f) f
 where
  on = flag6 (fGate f)
  wet = satWide (fAccL f + satShift10Wide (fAcc2L f) + satShift9Wide (fAcc3L f))

ampResPresenceProductsFrame :: Frame -> Frame
ampResPresenceProductsFrame f =
  f
    { fEqHighL = high
    , fEqHighR = high
    , fAccL = if on then resize (monoWet f) else 0
    , fAccR = 0
    , fAcc2L = if on then mulU8 (monoEqLow f) resonance else 0
    , fAcc2R = 0
    , fAcc3L = if on then mulU8 high presence else 0
    , fAcc3R = 0
    }
 where
  on = flag6 (fGate f)
  resonance = ctrlD (fAmp f) - (ctrlD (fAmp f) `shiftR` 2)
  presence = basePresence - presenceTrim
  presenceByte = ctrlC (fAmp f)
  idx = ampModelIdxF f
  basePresence = presenceByte - (presenceByte `shiftR` 2) - (presenceByte `shiftR` 3)
  presenceTrim = case idx of
    0 -> 0 :: Unsigned 8
    1 -> presenceByte `shiftR` 5
    2 -> presenceByte `shiftR` 4
    _ -> presenceByte `shiftR` 3
  high = satWide (resize (monoWet f) - resize (monoEqHighLp f))

satShift9Wide :: Wide -> Wide
satShift9Wide = resize . satShift9

satShift10Wide :: Wide -> Wide
satShift10Wide = resize . satShift10

ampMasterFrame :: Frame -> Frame
ampMasterFrame f =
  setMonoSample (if on then out else monoSample f) f
 where
  on = flag6 (fGate f)
  level = ctrlB (fAmp f)
  out = softClipK 3_300_000 (satShift7 (mulU8 (monoWet f) level))
