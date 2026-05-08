{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Reverb where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

advanceAddr :: ReverbAddr -> ReverbAddr
advanceAddr addr = if addr == maxBound then 0 else addr + 1
attachAddr :: ReverbAddr -> Maybe Frame -> Maybe Frame
attachAddr _ Nothing = Nothing
attachAddr addr (Just f) = Just f{fAddr = addr, fDryL = fL f, fDryR = fR f}

addrNext :: ReverbAddr -> Maybe Frame -> ReverbAddr
addrNext addr pipe = if isActive pipe then advanceAddr addr else addr

reverbToneProductsFrame :: Sample -> Sample -> Sample -> Sample -> Maybe Frame -> Maybe Frame
-- Real-pedal voicing pass: scale the tone byte by 7/8 so the maximum
-- bright setting is ~224 instead of 255. This keeps a small slice
-- (~12.5%) of the previous tap mixed in at every TONE setting,
-- providing some high-frequency damping in the recirculation path so
-- long tails do not turn metallic.
reverbToneProductsFrame tapL tapR prevL prevR = mapPipe applyTone
 where
  applyTone f =
    let tone       = ctrlB (fReverb f)
        toneScaled = tone - (tone `shiftR` 3)
        invTone    = 255 - toneScaled
    in f
      { fAccL = mulU8 tapL toneScaled
      , fAccR = mulU8 tapR toneScaled
      , fAcc2L = mulU8 prevL invTone
      , fAcc2R = mulU8 prevR invTone
      }

reverbToneBlendFrame :: Frame -> Frame
reverbToneBlendFrame f =
  f{fWetL = satShift8 (fAccL f + fAcc2L f), fWetR = satShift8 (fAccR f + fAcc2R f)}

reverbFeedbackProductsFrame :: Frame -> Frame
reverbFeedbackProductsFrame f =
  f{fAcc3L = if on then mulU8 (fWetL f) (ctrlA (fReverb f)) else 0, fAcc3R = if on then mulU8 (fWetR f) (ctrlA (fReverb f)) else 0}
 where
  on = flag5 (fGate f)

reverbFeedbackFrame :: Frame -> Frame
reverbFeedbackFrame f =
  f{fFbL = if on then feedbackL else 0, fFbR = if on then feedbackR else 0}
 where
  on = flag5 (fGate f)
  feedbackL = satWide ((resize (fDryL f) `shiftR` 1) + (fAcc3L f `shiftR` 8))
  feedbackR = satWide ((resize (fDryR f) `shiftR` 1) + (fAcc3R f `shiftR` 8))

reverbMixProductsFrame :: Frame -> Frame
reverbMixProductsFrame f =
  f
    { fAccL = if on then mulU9 (fDryL f) invMixGain else 0
    , fAccR = if on then mulU9 (fDryR f) invMixGain else 0
    , fAcc2L = if on then mulU8 (fWetL f) mixGain else 0
    , fAcc2R = if on then mulU8 (fWetR f) mixGain else 0
    }
 where
  on = flag5 (fGate f)
  mixGain = ctrlC (fReverb f)
  invMixGain = 256 - resize mixGain :: Unsigned 9

reverbMixFrame :: Frame -> Frame
reverbMixFrame f =
  f{fL = if on then mixedL else fDryL f, fR = if on then mixedR else fDryR f}
 where
  on = flag5 (fGate f)
  mixedL = satShift8 (fAccL f + fAcc2L f)
  mixedR = satShift8 (fAccR f + fAcc2R f)

writeReverbL :: Maybe Frame -> Maybe (ReverbAddr, Sample)
writeReverbL Nothing = Nothing
writeReverbL (Just f) = Just (fAddr f, fFbL f)

writeReverbR :: Maybe Frame -> Maybe (ReverbAddr, Sample)
writeReverbR Nothing = Nothing
writeReverbR (Just f) = Just (fAddr f, fFbR f)
