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
    , fAcc3L = 0
    , fAcc3R = 0
    , fEqLowL = 0
    , fEqLowR = 0
    }
 where
  on = flag7 (fGate f)
  model = ctrlC (fCab f)
  air = ctrlD (fCab f)
  c0 = cabCoeff model air 0
  c1 = cabCoeff model air 1
  c2 = cabCoeff model air 2
  c3 = cabCoeff model air 3
  early = mulS10 (monoSample f) c0 + mulS10 d1 c1
  body = mulS10 d2 c2 + mulS10 d3 c3

cabSatFrame :: Frame -> Frame
cabSatFrame f =
  f
    { fAccL = fAccL f
    , fAcc2L = fAcc2L f
    , fAcc3L = if on then bodyRes else 0
    , fEqLowL = if on then presenceAmount else 0
    , fEqLowR = 0
    }
 where
  on = flag7 (fGate f)
  model = ctrlC (fCab f)
  modelSel :: Unsigned 2
  modelSel = resize (model `shiftR` 6)
  bodySample = satShift8 (fAcc2L f)
  bodyClipped = softClipK (cabBodyResKnee modelSel) bodySample
  bodyRes = case modelSel of
    0 -> resize bodyClipped `shiftL` 5
    1 -> resize bodyClipped `shiftL` 6
    _ -> resize bodyClipped `shiftL` 7
  earlySample = satShift8 (fAccL f)
  presenceClipped = softClipK (cabPresenceKnee modelSel) earlySample
  presenceAmount = case modelSel of
    0 -> 0
    _ -> presenceClipped `shiftR` 4

cabIrFrame :: Frame -> Frame
cabIrFrame f =
  setMonoWet (if on then wet else monoSample f) f
 where
  on = flag7 (fGate f)
  model = ctrlC (fCab f)
  modelSel :: Unsigned 2
  modelSel = resize (model `shiftR` 6)
  bodyExtra = case modelSel of
    0 -> fAcc2L f `shiftR` 3
    1 -> fAcc2L f
    _ -> 0
  mainDark = satShift8 (fAccL f + fAcc2L f + fAcc3L f + bodyExtra)
  presenceS = fEqLowL f
  hfResWide :: Wide
  hfResWide = resize (monoSample f) - resize mainDark
  hfResSat = satWide hfResWide
  fizzSub = case modelSel of
    0 -> hfResSat `shiftR` 3
    1 -> hfResSat `shiftR` 3
    _ -> (hfResSat `shiftR` 3) + (hfResSat `shiftR` 4)
  blendWide :: Wide
  blendWide = resize mainDark + resize presenceS - resize fizzSub
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

-- 15-tap symmetric linear-phase speaker-rolloff FIR (realism item 1 / R4,
-- step A). An ADDITIVE post-stage on the cab output that sharpens the >5 kHz
-- rolloff (tames high-gain fizz, deepens per-model separation) WITHOUT
-- touching the accepted D71 nonlinear cab core (cabProductsFrame / cabSat /
-- cabIr / cabLevelMix all unchanged). Coefficients are hand-designed per
-- model (lowpass + gentle presence, inverse-FFT of a magnitude target; sum =
-- 256 => unity DC; NOT a captured commercial IR, D7). Symmetric, so it folds
-- to 8 mulS10. `hist` = [x[n-1] .. x[n-14]] (cab output history). Bit-exact
-- bypass when the cab is off. The full 128-256-tap BRAM convolution (the real
-- IR) is the planned step B; this short FIR is the low-risk first step.
--
-- Per-model magnitude (designed): open 1x12 brightest (~-5.7 dB @ 8 kHz),
-- british 2x12 mid (~-9.3 dB), closed 4x12 darkest/sharpest (~-11.8 dB @
-- 8 kHz, -26 dB @ 12 kHz).
cabSpeakerFirCoeff :: Unsigned 8 -> Vec 8 (Signed 10)
cabSpeakerFirCoeff model = case model `shiftR` 6 of
  0 -> 0 :> 0 :> (-1) :> (-2) :> 2 :> 20 :> 62 :> 94 :> Nil       -- open 1x12
  1 -> 0 :> (-1) :> (-2) :> 0 :> 8 :> 27 :> 57 :> 78 :> Nil       -- british 2x12
  _ -> 0 :> (-1) :> (-2) :> 1 :> 11 :> 30 :> 55 :> 68 :> Nil      -- closed 4x12

-- The FIR is split into two pipeline stages (it is feedforward, so it
-- pipelines freely -- unlike the biquads' feedback). A single combinational
-- 15-tap sum was too deep for the 50 MHz island (WNS -1.1 ns). Stage 1
-- computes all 8 folded products from ONE history snapshot into three Wide
-- partial sums (fAccL/fAcc2L/fAcc3L); stage 2 combines + scales. The folded
-- pair sum (a+b)*c maps onto the DSP48 pre-adder, so each pair is one DSP.
cabSpeakerFirProductsFrame :: Vec 14 Sample -> Frame -> Frame
cabSpeakerFirProductsFrame hist f =
  f { fAccL = if on then p0 else 0, fAccR = 0
    , fAcc2L = if on then p1 else 0, fAcc2R = 0
    , fAcc3L = if on then p2 else 0, fAcc3R = 0 }
 where
  on = flag7 (fGate f)
  x = monoSample f
  c = cabSpeakerFirCoeff (ctrlC (fCab f))
  pairMul a b g = (resize a + resize b :: Wide) * resize g
  p0 = pairMul x          (hist !! 13) (c !! 0)
         + pairMul (hist !! 0) (hist !! 12) (c !! 1)
         + pairMul (hist !! 1) (hist !! 11) (c !! 2)
  p1 = pairMul (hist !! 2) (hist !! 10) (c !! 3)
         + pairMul (hist !! 3) (hist !! 9)  (c !! 4)
         + pairMul (hist !! 4) (hist !! 8)  (c !! 5)
  p2 = pairMul (hist !! 5) (hist !! 7)  (c !! 6)
         + (resize (hist !! 6) * resize (c !! 7) :: Wide)

cabSpeakerFirMixFrame :: Frame -> Frame
cabSpeakerFirMixFrame f =
  setMonoSample (if on then satShift8 (fAccL f + fAcc2L f + fAcc3L f) else monoSample f) f
 where
  on = flag7 (fGate f)

cabSpeakerFirHistNext :: Vec 14 Sample -> Maybe Frame -> Vec 14 Sample
cabSpeakerFirHistNext hist Nothing = hist
cabSpeakerFirHistNext hist (Just f) = monoSample f +>> hist
