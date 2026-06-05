{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Distortion.Legacy where

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
  driveGain = resize (256 + (resize amount * 9 :: Unsigned 11)) :: Unsigned 12
  rawThreshold = 8_388_607 - (resize (asSigned9 amount) * 28_000) :: Signed 25
  clampedThreshold = if rawThreshold < 1_600_000 then 1_600_000 else rawThreshold
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

