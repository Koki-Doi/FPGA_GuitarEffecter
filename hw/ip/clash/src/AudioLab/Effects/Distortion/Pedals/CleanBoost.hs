{-# LANGUAGE NumericUnderscores #-}

-- | clean_boost pedal stages (split out of Distortion/Pedals.hs, refactor K).
module AudioLab.Effects.Distortion.Pedals.CleanBoost where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types
import AudioLab.Effects.Distortion.Common

-- ---- clean_boost (3 stages: mul, shift, level+safety) ---------------

cleanBoostMulFrame :: Frame -> Frame
cleanBoostMulFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = cleanBoostOn f
  drive = ctrlC (fDist f)
  -- Global real-pedal pass: keep the boost mostly clean and let the
  -- level stage, not clipping, provide the push.
  gain = resize (256 + (resize drive * 2 :: Unsigned 11)) :: Unsigned 12

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
  afterLevel = distLevelRaw (monoSample f) level   -- refactor C: shared kernel
  -- High safety knee so Clean Boost only catches exceptional peaks.
  safetyKnee = 3_800_000 :: Sample
