{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Cab where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

cabSpeakerKnee :: Unsigned 2 -> Sample
cabSpeakerKnee 0 = 5_200_000
cabSpeakerKnee 1 = 4_200_000
cabSpeakerKnee _ = 3_400_000

cabBodyResKnee :: Unsigned 2 -> Sample
cabBodyResKnee 0 = 2_200_000
cabBodyResKnee 1 = 1_800_000
cabBodyResKnee _ = 1_400_000

cabCoeff :: Unsigned 8 -> Unsigned 8 -> Unsigned 2 -> Signed 10
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
        0 -> 76
        1 -> 112
        2 -> 46
        _ -> 18
      1 -> case i of
        0 -> 88
        1 -> 106
        2 -> 36
        _ -> 14
      _ -> case i of
        0 -> 100
        1 -> 100
        2 -> 28
        _ -> 12
  british i =
    case airSel of
      0 -> case i of
        0 -> 48
        1 -> 104
        2 -> 82
        _ -> 28
      1 -> case i of
        0 -> 56
        1 -> 100
        2 -> 76
        _ -> 24
      _ -> case i of
        0 -> 64
        1 -> 96
        2 -> 70
        _ -> 20
  closedBack i =
    case airSel of
      0 -> case i of
        0 -> 20
        1 -> 68
        2 -> 104
        _ -> 88
      1 -> case i of
        0 -> 28
        1 -> 72
        2 -> 100
        _ -> 78
      _ -> case i of
        0 -> 36
        1 -> 76
        2 -> 96
        _ -> 68

cabProductsFrame ::
  Sample -> Sample -> Sample ->
  Frame -> Frame
cabProductsFrame d1 d2 d3 f =
  f
    { fAccL = if on then early else 0
    , fAccR = 0
    , fAcc2L = if on then body else 0
    , fAcc2R = 0
    , fAcc3L = if on then bodyRes else 0
    , fAcc3R = 0
    }
 where
  on = flag7 (fGate f)
  model = ctrlC (fCab f)
  air = ctrlD (fCab f)
  modelSel :: Unsigned 2
  modelSel = resize (model `shiftR` 6)
  c0 = cabCoeff model air 0
  c1 = cabCoeff model air 1
  c2 = cabCoeff model air 2
  c3 = cabCoeff model air 3
  early = mulS10 (monoSample f) c0 + mulS10 d1 c1
  body = mulS10 d2 c2 + mulS10 d3 c3
  bodySample = satShift8 body
  bodyClipped = softClipK (cabBodyResKnee modelSel) bodySample
  bodyRes = case modelSel of
    0 -> resize bodyClipped `shiftL` 5
    1 -> resize bodyClipped `shiftL` 6
    _ -> resize bodyClipped `shiftL` 7

cabIrFrame :: Frame -> Frame
cabIrFrame f =
  setMonoWet (if on then wet else monoSample f) f
 where
  on = flag7 (fGate f)
  wet = satShift8 (fAccL f + fAcc2L f + fAcc3L f)

cabLevelMixFrame :: Frame -> Frame
cabLevelMixFrame f =
  setMonoSample (if on then softClipK (cabSpeakerKnee modelSel) mixed else monoSample f) f
 where
  on = flag7 (fGate f)
  model = ctrlC (fCab f)
  modelSel :: Unsigned 2
  modelSel = resize (model `shiftR` 6)
  mix = ctrlA (fCab f)
  invMix = 255 - mix
  level = ctrlB (fCab f)
  wet = satShift7 (mulU8 (monoWet f) level)
  mixed = satShift8 (mulU8 (monoSample f) invMix + mulU8 wet mix)
