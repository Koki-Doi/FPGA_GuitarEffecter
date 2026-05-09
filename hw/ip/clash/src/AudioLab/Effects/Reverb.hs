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
attachAddr addr (Just f) = Just (setMonoDry (monoSample f) f{fAddr = addr})

addrNext :: ReverbAddr -> Maybe Frame -> ReverbAddr
addrNext addr pipe = if isActive pipe then advanceAddr addr else addr

reverbToneProductsFrame :: Sample -> Sample -> Maybe Frame -> Maybe Frame
-- Real-pedal voicing pass: scale the tone byte by 7/8 so the maximum
-- bright setting is ~224 instead of 255. This keeps a small slice
-- (~12.5%) of the previous tap mixed in at every TONE setting,
-- providing some high-frequency damping in the recirculation path so
-- long tails do not turn metallic.
reverbToneProductsFrame tap prev = mapPipe applyTone
 where
  applyTone f =
    let tone       = ctrlB (fReverb f)
        toneScaled = tone - (tone `shiftR` 3)
        invTone    = 255 - toneScaled
    in f
      { fAccL = mulU8 tap toneScaled
      , fAccR = 0
      , fAcc2L = mulU8 prev invTone
      , fAcc2R = 0
      }

reverbToneBlendFrame :: Frame -> Frame
reverbToneBlendFrame f =
  setMonoWet (satShift8 (fAccL f + fAcc2L f)) f

reverbFeedbackProductsFrame :: Frame -> Frame
reverbFeedbackProductsFrame f =
  f{fAcc3L = if on then mulU8 (monoWet f) (ctrlA (fReverb f)) else 0, fAcc3R = 0}
 where
  on = flag5 (fGate f)

reverbFeedbackFrame :: Frame -> Frame
reverbFeedbackFrame f =
  setMonoFb (if on then feedback else 0) f
 where
  on = flag5 (fGate f)
  feedback = satWide ((resize (monoDry f) `shiftR` 1) + (fAcc3L f `shiftR` 8))

reverbMixProductsFrame :: Frame -> Frame
reverbMixProductsFrame f =
  f
    { fAccL = if on then mulU9 (monoDry f) invMixGain else 0
    , fAccR = 0
    , fAcc2L = if on then mulU8 (monoWet f) mixGain else 0
    , fAcc2R = 0
    }
 where
  on = flag5 (fGate f)
  mixGain = ctrlC (fReverb f)
  invMixGain = 256 - resize mixGain :: Unsigned 9

reverbMixFrame :: Frame -> Frame
reverbMixFrame f =
  setMonoSample (if on then mixed else monoDry f) f
 where
  on = flag5 (fGate f)
  mixed = satShift8 (fAccL f + fAcc2L f)

writeReverb :: Maybe Frame -> Maybe (ReverbAddr, Sample)
writeReverb Nothing = Nothing
writeReverb (Just f) = Just (fAddr f, monoFb f)
