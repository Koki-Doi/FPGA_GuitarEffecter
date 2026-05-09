{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Eq where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

eqFilterFrame :: Sample -> Sample -> Frame -> Frame
eqFilterFrame prevLow prevHighLp f =
  f
    { fEqLowL = low
    , fEqLowR = low
    , fEqHighLpL = highLp
    , fEqHighLpR = highLp
    }
 where
  x = monoSample f
  low = prevLow + resize (((resize x - resize prevLow) :: Signed 25) `shiftR` 5)
  highLp = prevHighLp + resize (((resize x - resize prevHighLp) :: Signed 25) `shiftR` 2)

eqBandFrame :: Frame -> Frame
eqBandFrame f =
  f
    { fEqMidL = mid
    , fEqMidR = mid
    , fEqHighL = high
    , fEqHighR = high
    }
 where
  mid = satWide (resize (monoEqHighLp f) - resize (monoEqLow f))
  high = satWide (resize (monoSample f) - resize (monoEqHighLp f))

eqProductsFrame :: Frame -> Frame
eqProductsFrame f =
  f
    { fAccL = if on then mulU8 (monoEqLow f) (ctrlA (fEq f)) else 0
    , fAccR = 0
    , fAcc2L = if on then mulU8 (monoEqMid f) (ctrlB (fEq f)) else 0
    , fAcc2R = 0
    , fAcc3L = if on then mulU8 (monoEqHigh f) (ctrlC (fEq f)) else 0
    , fAcc3R = 0
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
  setMonoSample (if on then softClip (satShift7 acc) else monoSample f) f
 where
  on = flag3 (fGate f)
  acc = fAccL f + fAcc2L f + fAcc3L f
