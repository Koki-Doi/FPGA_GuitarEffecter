{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Cab where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

cabSpeakerKnee :: Unsigned 2 -> Sample
cabSpeakerKnee 0 = 5_600_000
cabSpeakerKnee 1 = 4_000_000
cabSpeakerKnee _ = 2_800_000

cabBodyResKnee :: Unsigned 2 -> Sample
cabBodyResKnee 0 = 2_400_000
cabBodyResKnee 1 = 1_600_000
cabBodyResKnee _ = 1_200_000

cabPresenceKnee :: Unsigned 2 -> Sample
cabPresenceKnee 0 = 3_600_000
cabPresenceKnee 1 = 3_000_000
cabPresenceKnee _ = 2_400_000

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
        0 -> 72
        1 -> 116
        2 -> 48
        _ -> 20
      1 -> case i of
        0 -> 82
        1 -> 114
        2 -> 42
        _ -> 18
      _ -> case i of
        0 -> 90
        1 -> 116
        2 -> 34
        _ -> 16
  british i =
    case airSel of
      0 -> case i of
        0 -> 36
        1 -> 108
        2 -> 82
        _ -> 34
      1 -> case i of
        0 -> 46
        1 -> 106
        2 -> 76
        _ -> 32
      _ -> case i of
        0 -> 54
        1 -> 106
        2 -> 70
        _ -> 30
  closedBack i =
    case airSel of
      0 -> case i of
        0 -> 10
        1 -> 68
        2 -> 100
        _ -> 86
      1 -> case i of
        0 -> 18
        1 -> 70
        2 -> 96
        _ -> 80
      _ -> case i of
        0 -> 26
        1 -> 72
        2 -> 92
        _ -> 74

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
    , fEqLowL = if on then presenceAmount else 0
    , fEqLowR = 0
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
  earlySample = satShift8 early
  presenceClipped = softClipK (cabPresenceKnee modelSel) earlySample
  presenceAmount = case modelSel of
    0 -> (presenceClipped `shiftR` 2) + (presenceClipped `shiftR` 4)
    1 -> 0
    _ -> presenceClipped `shiftR` 3

cabIrFrame :: Frame -> Frame
cabIrFrame f =
  setMonoWet (if on then wet else monoSample f) f
 where
  on = flag7 (fGate f)
  model = ctrlC (fCab f)
  modelSel :: Unsigned 2
  modelSel = resize (model `shiftR` 6)
  mainSat = satShift8 (fAccL f + fAcc2L f + fAcc3L f)
  bodySat = satShift8 (fAcc2L f)
  presenceS = fEqLowL f
  hfResWide :: Wide
  hfResWide = resize (monoSample f) - resize mainSat
  hfResSat = satWide hfResWide
  bodyAdd = case modelSel of
    0 -> 0
    1 -> bodySat `shiftR` 3
    _ -> 0
  fizzSub = case modelSel of
    0 -> hfResSat `shiftR` 3
    1 -> hfResSat `shiftR` 4
    _ -> hfResSat `shiftR` 4
  blendWide :: Wide
  blendWide = resize mainSat + resize bodyAdd + resize presenceS - resize fizzSub
  wet = satWide blendWide

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
