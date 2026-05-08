{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Amp where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

ampHighpassFrame :: Sample -> Sample -> Sample -> Sample -> Frame -> Frame
ampHighpassFrame prevInL prevInR prevOutL prevOutR f =
  f
    { fDryL = fL f
    , fDryR = fR f
    , fWetL = if on then highpass (fL f) prevInL prevOutL else fL f
    , fWetR = if on then highpass (fR f) prevInR prevOutR else fR f
    }
 where
  on = flag6 (fGate f)
  highpass x prevIn prevOut =
    satWide (resize x - resize prevIn + ((resize prevOut :: Wide) * 253 `shiftR` 8))

ampDriveMultiplyFrame :: Frame -> Frame
ampDriveMultiplyFrame f =
  f{fAccL = if on then mulU12 (fWetL f) gain else 0, fAccR = if on then mulU12 (fWetR f) gain else 0}
 where
  on = flag6 (fGate f)
  -- 1.0x to about 19x using Q7-style post shift. The recording-analysis
  -- pass trims the ceiling again so Amp-only and post-pedal use do not
  -- create line-direct fizz before the cabinet stage.
  gain = resize (128 + (resize (ctrlA (fAmp f)) * 9 :: Unsigned 12)) :: Unsigned 12

ampDriveBoostFrame :: Frame -> Frame
ampDriveBoostFrame f =
  f{fWetL = if on then satShift7 (fAccL f) else fL f, fWetR = if on then satShift7 (fAccR f) else fR f}
 where
  on = flag6 (fGate f)

ampAsymClip :: Unsigned 8 -> Sample -> Sample
ampAsymClip character x
  | x > positiveKnee = satWide (resize (resize positiveKnee + (((resize x :: Signed 25) - resize positiveKnee) `shiftR` 2) :: Signed 25))
  | x < negate negativeKnee = satWide (resize (resize (negate negativeKnee) + (((resize x :: Signed 25) + resize negativeKnee) `shiftR` 3) :: Signed 25))
  | otherwise = x
 where
  ch = resize (asSigned9 character) :: Signed 25
  -- Lower knees at high character give a rougher, less symmetric preamp.
  positiveKnee = resize (4_900_000 - ch * 7_000) :: Sample
  negativeKnee = resize (4_350_000 - ch * 6_200) :: Sample

ampWaveshapeFrame :: Frame -> Frame
ampWaveshapeFrame f =
  f{fWetL = if on then ampAsymClip character (fWetL f) else fL f, fWetR = if on then ampAsymClip character (fWetR f) else fR f}
 where
  on = flag6 (fGate f)
  character = ctrlD (fAmpTone f)

-- | Quantise the amp character byte (0..255) into a 2-bit "amp model"
-- index that distinguishes four named voicings. Bands match the
-- Python AMP_MODELS table so the labelled character values
--   jc_clean = 10  -> byte  26 -> model 0
--   clean_combo = 35 -> byte  89 -> model 1
--   british_crunch = 60 -> byte 153 -> model 2
--   high_gain_stack = 85 -> byte 216 -> model 3
-- land in the centre of each band. Cheap: two compares, one mux per
-- step; the result is only consumed by the pre-LPF darken below, so
-- combinational depth elsewhere is unaffected.
ampModelSel :: Unsigned 8 -> Unsigned 2
ampModelSel x
  | x < 63    = 0
  | x < 126   = 1
  | x < 190   = 2
  | otherwise = 3

ampPreLowpassFrame :: Sample -> Sample -> Frame -> Frame
ampPreLowpassFrame prevL prevR f =
  f{fWetL = if on then onePoleU8 alpha prevL (fWetL f) else fL f, fWetR = if on then onePoleU8 alpha prevR (fWetR f) else fR f}
 where
  on = flag6 (fGate f)
  charByte = ctrlD (fAmpTone f)
  -- Higher character keeps edge, but the maximum alpha is capped lower
  -- than the previous voicing so high-gain settings shed more >5 kHz fizz.
  baseAlpha = 128 + (charByte `shiftR` 2)
  -- Fizz-control pass: extend the per-model darken gently so clipped
  -- high-gain voicings shed more 8..16 kHz content before the second
  -- stage, while clean bands keep enough direct edge.
  -- Model 0 (JC Clean) keeps the brightest edge; model 3
  -- (High Gain Stack) rolls off the most so high-gain pedals into the
  -- amp do not produce the second brightening that the audio-analysis
  -- recordings flagged. All four steps stay inside the safe alpha
  -- band (>=112) so the LPF never inverts.
  modelDarken = case ampModelSel charByte of
    0 ->  0 :: Unsigned 8
    1 ->  4
    2 -> 12
    _ -> 24
  alpha = baseAlpha - modelDarken

ampSecondStageMultiplyFrame :: Frame -> Frame
ampSecondStageMultiplyFrame f =
  f{fAccL = if on then mulU9 (fWetL f) gain else 0, fAccR = if on then mulU9 (fWetR f) gain else 0}
 where
  on = flag6 (fGate f)
  gain = resize (112 + (ctrlA (fAmp f) `shiftR` 3) + (ctrlD (fAmpTone f) `shiftR` 2)) :: Unsigned 9

ampSecondStageFrame :: Frame -> Frame
ampSecondStageFrame f =
  f{fWetL = if on then ampAsymClip character (satShift7 (fAccL f)) else fL f, fWetR = if on then ampAsymClip character (satShift7 (fAccR f)) else fR f}
 where
  on = flag6 (fGate f)
  -- Softer than the first clip stage; keeps low-gain response touch-sensitive.
  character = ctrlD (fAmpTone f) `shiftR` 1

ampToneFilterFrame :: Sample -> Sample -> Sample -> Sample -> Frame -> Frame
ampToneFilterFrame prevLowL prevLowR prevHighLpL prevHighLpR f =
  f
    { fEqLowL = lowL
    , fEqLowR = lowR
    , fEqHighLpL = highLpL
    , fEqHighLpR = highLpR
    }
 where
  left = fWetL f
  right = fWetR f
  lowL = prevLowL + resize (((resize left - resize prevLowL) :: Signed 25) `shiftR` 5)
  lowR = prevLowR + resize (((resize right - resize prevLowR) :: Signed 25) `shiftR` 5)
  highLpL = prevHighLpL + resize (((resize left - resize prevHighLpL) :: Signed 25) `shiftR` 2)
  highLpR = prevHighLpR + resize (((resize right - resize prevHighLpR) :: Signed 25) `shiftR` 2)

ampToneBandFrame :: Frame -> Frame
ampToneBandFrame f =
  f
    { fEqMidL = satWide (resize (fEqHighLpL f) - resize (fEqLowL f))
    , fEqMidR = satWide (resize (fEqHighLpR f) - resize (fEqLowR f))
    , fEqHighL = satWide (resize (fWetL f) - resize (fEqHighLpL f))
    , fEqHighR = satWide (resize (fWetR f) - resize (fEqHighLpR f))
    }

ampToneGain :: Unsigned 8 -> Unsigned 8
ampToneGain x = 64 + (x `shiftR` 1)

ampTrebleGain :: Unsigned 8 -> Unsigned 8 -> Unsigned 8
ampTrebleGain character x = base - modelTrim
 where
  -- Keep the 2..4 kHz bite from the tone stack, but avoid restoring as
  -- much raw 8..16 kHz fizz when TREBLE is near 100.
  base = 64 + ((x - (x `shiftR` 3) - (x `shiftR` 4)) `shiftR` 1)
  modelTrim = case ampModelSel character of
    0 -> 0 :: Unsigned 8
    1 -> 2
    2 -> 5
    _ -> 9

ampToneProductsFrame :: Frame -> Frame
ampToneProductsFrame f =
  f
    { fAccL = if on then mulU8 (fEqLowL f) (ampToneGain (ctrlA (fAmpTone f))) else 0
    , fAccR = if on then mulU8 (fEqLowR f) (ampToneGain (ctrlA (fAmpTone f))) else 0
    , fAcc2L = if on then mulU8 (fEqMidL f) (ampToneGain (ctrlB (fAmpTone f))) else 0
    , fAcc2R = if on then mulU8 (fEqMidR f) (ampToneGain (ctrlB (fAmpTone f))) else 0
    , fAcc3L = if on then mulU8 (fEqHighL f) (ampTrebleGain character (ctrlC (fAmpTone f))) else 0
    , fAcc3R = if on then mulU8 (fEqHighR f) (ampTrebleGain character (ctrlC (fAmpTone f))) else 0
    }
 where
  on = flag6 (fGate f)
  character = ctrlD (fAmpTone f)

ampToneMixFrame :: Frame -> Frame
ampToneMixFrame f =
  f{fWetL = if on then satShift7 accL else fL f, fWetR = if on then satShift7 accR else fR f}
 where
  on = flag6 (fGate f)
  accL = fAccL f + fAcc2L f + fAcc3L f
  accR = fAccR f + fAcc2R f + fAcc3R f

ampPowerFrame :: Frame -> Frame
ampPowerFrame f =
  f{fWetL = if on then softClipK 3_400_000 (fWetL f) else fL f, fWetR = if on then softClipK 3_400_000 (fWetR f) else fR f}
 where
  on = flag6 (fGate f)

ampResPresenceFilterFrame :: Sample -> Sample -> Sample -> Sample -> Frame -> Frame
ampResPresenceFilterFrame prevResL prevResR prevPresenceL prevPresenceR f =
  f
    { fEqLowL = resL
    , fEqLowR = resR
    , fEqHighLpL = presenceLpL
    , fEqHighLpR = presenceLpR
    }
 where
  left = fWetL f
  right = fWetR f
  -- Slow lowpass approximates resonance around the speaker low-end region.
  resL = prevResL + resize (((resize left - resize prevResL) :: Signed 25) `shiftR` 8)
  resR = prevResR + resize (((resize right - resize prevResR) :: Signed 25) `shiftR` 8)
  presenceLpL = prevPresenceL + resize (((resize left - resize prevPresenceL) :: Signed 25) `shiftR` 3)
  presenceLpR = prevPresenceR + resize (((resize right - resize prevPresenceR) :: Signed 25) `shiftR` 3)

ampResPresenceMixFrame :: Frame -> Frame
ampResPresenceMixFrame f =
  f{fWetL = if on then softClipK 3_400_000 wetL else fL f, fWetR = if on then softClipK 3_400_000 wetR else fR f}
 where
  on = flag6 (fGate f)
  wetL = satWide (fAccL f + satShift10Wide (fAcc2L f) + satShift9Wide (fAcc3L f))
  wetR = satWide (fAccR f + satShift10Wide (fAcc2R f) + satShift9Wide (fAcc3R f))

ampResPresenceProductsFrame :: Frame -> Frame
ampResPresenceProductsFrame f =
  f
    { fEqHighL = highL
    , fEqHighR = highR
    , fAccL = if on then resize (fWetL f) else 0
    , fAccR = if on then resize (fWetR f) else 0
    , fAcc2L = if on then mulU8 (fEqLowL f) resonance else 0
    , fAcc2R = if on then mulU8 (fEqLowR f) resonance else 0
    , fAcc3L = if on then mulU8 highL presence else 0
    , fAcc3R = if on then mulU8 highR presence else 0
    }
 where
  on = flag6 (fGate f)
  resonance = ctrlD (fAmp f) - (ctrlD (fAmp f) `shiftR` 2)
  presence = basePresence - presenceTrim
  presenceByte = ctrlC (fAmp f)
  character = ctrlD (fAmpTone f)
  basePresence = presenceByte - (presenceByte `shiftR` 2) - (presenceByte `shiftR` 3)
  presenceTrim = case ampModelSel character of
    0 -> 0 :: Unsigned 8
    1 -> presenceByte `shiftR` 5
    2 -> presenceByte `shiftR` 4
    _ -> presenceByte `shiftR` 3
  highL = satWide (resize (fWetL f) - resize (fEqHighLpL f))
  highR = satWide (resize (fWetR f) - resize (fEqHighLpR f))

satShift9Wide :: Wide -> Wide
satShift9Wide = resize . satShift9

satShift10Wide :: Wide -> Wide
satShift10Wide = resize . satShift10

ampMasterFrame :: Frame -> Frame
ampMasterFrame f =
  f{fL = if on then left else fL f, fR = if on then right else fR f}
 where
  on = flag6 (fGate f)
  level = ctrlB (fAmp f)
  left = softClipK 3_300_000 (satShift7 (mulU8 (fWetL f) level))
  right = softClipK 3_300_000 (satShift7 (mulU8 (fWetR f) level))
