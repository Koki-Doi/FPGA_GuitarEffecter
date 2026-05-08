{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Eq where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

eqFilterFrame :: Sample -> Sample -> Sample -> Sample -> Frame -> Frame
eqFilterFrame prevLowL prevLowR prevHighLpL prevHighLpR f =
  f
    { fEqLowL = lowL
    , fEqLowR = lowR
    , fEqHighLpL = highLpL
    , fEqHighLpR = highLpR
    }
 where
  left = fL f
  right = fR f
  lowL = prevLowL + resize (((resize left - resize prevLowL) :: Signed 25) `shiftR` 5)
  lowR = prevLowR + resize (((resize right - resize prevLowR) :: Signed 25) `shiftR` 5)
  highLpL = prevHighLpL + resize (((resize left - resize prevHighLpL) :: Signed 25) `shiftR` 2)
  highLpR = prevHighLpR + resize (((resize right - resize prevHighLpR) :: Signed 25) `shiftR` 2)

eqBandFrame :: Frame -> Frame
eqBandFrame f =
  f
    { fEqMidL = satWide (resize (fEqHighLpL f) - resize (fEqLowL f))
    , fEqMidR = satWide (resize (fEqHighLpR f) - resize (fEqLowR f))
    , fEqHighL = satWide (resize (fL f) - resize (fEqHighLpL f))
    , fEqHighR = satWide (resize (fR f) - resize (fEqHighLpR f))
    }

eqProductsFrame :: Frame -> Frame
eqProductsFrame f =
  f
    { fAccL = if on then mulU8 (fEqLowL f) (ctrlA (fEq f)) else 0
    , fAccR = if on then mulU8 (fEqLowR f) (ctrlA (fEq f)) else 0
    , fAcc2L = if on then mulU8 (fEqMidL f) (ctrlB (fEq f)) else 0
    , fAcc2R = if on then mulU8 (fEqMidR f) (ctrlB (fEq f)) else 0
    , fAcc3L = if on then mulU8 (fEqHighL f) (ctrlC (fEq f)) else 0
    , fAcc3R = if on then mulU8 (fEqHighR f) (ctrlC (fEq f)) else 0
    }
 where
  on = flag3 (fGate f)

eqMixFrame :: Frame -> Frame
-- Real-pedal voicing pass: wrap the post-EQ sum in softClip so a
-- max-boost on all three bands saturates softly instead of slamming
-- the satShift7 saturator (audible hard clip). softClip is identity
-- below its knee, so neutral 128/128/128 EQ remains bit-exact (apart
-- from the standard satShift7 round-trip).
eqMixFrame f =
  f{fL = if on then softClip (satShift7 accL) else fL f, fR = if on then softClip (satShift7 accR) else fR f}
 where
  on = flag3 (fGate f)
  accL = fAccL f + fAcc2L f + fAcc3L f
  accR = fAccR f + fAcc2R f + fAcc3R f
