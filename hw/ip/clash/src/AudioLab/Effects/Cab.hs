{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Cab where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

cabCoeff :: Unsigned 8 -> Unsigned 8 -> Unsigned 2 -> Signed 10
-- Audio-analysis voicing pass: keep the existing 4-tap cabinet stage
-- but make model separation and >5 kHz roll-off stronger. Model 0 is
-- lighter/open-back, model 1 is the balanced combo, and model 2 pushes
-- weight into delayed taps so high-gain fizz is damped hardest. AIR
-- restores only capped direct-tap content; it never becomes raw line.
cabCoeff model air index =
  case modelSel of
    0 -> openBack index
    1 -> british index
    _ -> closedBack index
 where
  modelSel = model `shiftR` 6
  airSel :: Unsigned 2
  airSel = if air < 86 then 0 else if air < 171 then 1 else 2
  openBack i =
    case airSel of
      0 -> case i of
        0 -> 70
        1 -> 86
        2 -> 58
        _ -> 14
      1 -> case i of
        0 -> 78
        1 -> 82
        2 -> 54
        _ -> 12
      _ -> case i of
        0 -> 86
        1 -> 78
        2 -> 48
        _ -> 8
  british i =
    case airSel of
      0 -> case i of
        0 -> 62
        1 -> 86
        2 -> 78
        _ -> 34
      1 -> case i of
        0 -> 68
        1 -> 84
        2 -> 74
        _ -> 30
      _ -> case i of
        0 -> 74
        1 -> 82
        2 -> 68
        _ -> 24
  closedBack i =
    case airSel of
      0 -> case i of
        0 -> 44
        1 -> 78
        2 -> 96
        _ -> 82
      1 -> case i of
        0 -> 50
        1 -> 82
        2 -> 94
        _ -> 70
      _ -> case i of
        0 -> 56
        1 -> 86
        2 -> 90
        _ -> 60

cabProductsFrame ::
  Sample -> Sample -> Sample ->
  Sample -> Sample -> Sample ->
  Frame -> Frame
cabProductsFrame d1L d2L d3L d1R d2R d3R f =
  f
    { fAccL = if on then earlyL else 0
    , fAccR = if on then earlyR else 0
    , fAcc2L = if on then bodyL else 0
    , fAcc2R = if on then bodyR else 0
    , fAcc3L = 0
    , fAcc3R = 0
    }
 where
  on = flag7 (fGate f)
  model = ctrlC (fCab f)
  air = ctrlD (fCab f)
  c0 = cabCoeff model air 0
  c1 = cabCoeff model air 1
  c2 = cabCoeff model air 2
  c3 = cabCoeff model air 3
  earlyL = mulS10 (fL f) c0 + mulS10 d1L c1
  earlyR = mulS10 (fR f) c0 + mulS10 d1R c1
  bodyL = mulS10 d2L c2 + mulS10 d3L c3
  bodyR = mulS10 d2R c2 + mulS10 d3R c3

cabIrFrame :: Frame -> Frame
cabIrFrame f =
  f{fWetL = if on then wetL else fL f, fWetR = if on then wetR else fR f}
 where
  on = flag7 (fGate f)
  wetL = satShift8 (fAccL f + fAcc2L f + fAcc3L f)
  wetR = satShift8 (fAccR f + fAcc2R f + fAcc3R f)

cabLevelMixFrame :: Frame -> Frame
cabLevelMixFrame f =
  f{fL = if on then softClip mixedL else fL f, fR = if on then softClip mixedR else fR f}
 where
  on = flag7 (fGate f)
  mix = ctrlA (fCab f)
  invMix = 255 - mix
  level = ctrlB (fCab f)
  wetL = satShift7 (mulU8 (fWetL f) level)
  wetR = satShift7 (mulU8 (fWetR f) level)
  mixedL = satShift8 (mulU8 (fL f) invMix + mulU8 wetL mix)
  mixedR = satShift8 (mulU8 (fR f) invMix + mulU8 wetR mix)
