{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Cab where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

-- D152 (chord HF "汚い/ブツブツ" fix): the dirty chord top is in-band
-- intermodulation from the cab's saturation/cone nonlinearity clipping large
-- chords (oversampling proven useless -- it is NOT aliasing). Raise the cab
-- saturation HEADROOM (moderate) so moderate-large chords stay below the knees
-- and generate less IMD; this cleans the clean amps' rig top ~+6 dB. softClipK =
-- compare + shift, so this is constant-only (no new DSP). Pairs with the D152
-- cab-presence pull-back below.
-- D153: the cabSpeakerKnee is the FINAL output soft-clip = the cab's peak
-- LIMITER. D152 raised it (for chord headroom) but that removed the peak
-- limiting, so the clean amps came out too hot = 音割れ on the board. Restore it
-- to the D151 values (peak ceiling back) -- the chord-IMD headroom is kept on the
-- EARLY cab stages (cabBodyResKnee / cabPresenceKnee, still raised below) where
-- the IMD is actually generated, so the chord stays clean while the output level
-- returns to the safe D151 ceiling.
cabSpeakerKnee :: Unsigned 2 -> Sample
cabSpeakerKnee 0 = 5_600_000   -- D153: back to D151 (D152 was 6.5M)
cabSpeakerKnee 1 = 4_000_000   -- D153: back to D151 (D152 was 5.2M)
cabSpeakerKnee _ = 2_800_000   -- D153: back to D151 (D152 was 3.9M)

cabBodyResKnee :: Unsigned 2 -> Sample
cabBodyResKnee 0 = 3_000_000   -- D152: 2.4M -> 3.0M
cabBodyResKnee 1 = 2_300_000   -- D152: 1.6M -> 2.3M
cabBodyResKnee _ = 1_800_000   -- D152: 1.2M -> 1.8M

cabPresenceKnee :: Unsigned 2 -> Sample
cabPresenceKnee 0 = 4_600_000   -- D152: 3.6M -> 4.6M
cabPresenceKnee 1 = 4_000_000   -- D152: 3.0M -> 4.0M
cabPresenceKnee _ = 3_300_000   -- D152: 2.4M -> 3.3M

cabAirSel :: Unsigned 8 -> Unsigned 2
cabAirSel air = if air < 86 then 0 else if air < 171 then 1 else 2

cabCoeff :: Unsigned 8 -> Unsigned 8 -> Unsigned 2 -> Signed 10
cabCoeff model air index =
  case modelSel of
    0 -> openBack index
    1 -> british index
    _ -> closedBack index
 where
  modelSel = model `shiftR` 6
  airSel :: Unsigned 2
  airSel = cabAirSel air
  openBack i =
    case airSel of
      0 -> case i of
        0 -> 58
        1 -> 112
        2 -> 62
        _ -> 24
      1 -> case i of
        0 -> 82
        1 -> 114
        2 -> 42
        _ -> 18
      _ -> case i of
        0 -> 112
        1 -> 108
        2 -> 24
        _ -> 12
  british i =
    case airSel of
      0 -> case i of
        0 -> 22
        1 -> 102
        2 -> 94
        _ -> 42
      1 -> case i of
        0 -> 46
        1 -> 106
        2 -> 76
        _ -> 32
      _ -> case i of
        0 -> 72
        1 -> 110
        2 -> 56
        _ -> 22
  closedBack i =
    case airSel of
      0 -> case i of
        0 -> 4
        1 -> 62
        2 -> 108
        _ -> 90
      1 -> case i of
        0 -> 18
        1 -> 70
        2 -> 96
        _ -> 80
      _ -> case i of
        0 -> 42
        1 -> 76
        2 -> 82
        _ -> 64

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
  airSel = cabAirSel (ctrlD (fCab f))
  modelSel :: Unsigned 2
  modelSel = resize (model `shiftR` 6)
  -- Non-IR mic/body voicing: real close-mic guitar cabs carry more low-mid
  -- wood/cone body than the short early-reflection core produced. Add a
  -- model-specific body tap before the speaker FIR. This is not convolution
  -- and does not use captured IR data; it reuses the existing body accumulator.
  bodyExtra = case modelSel of
    0 -> fAcc2L f `shiftR` 2
    1 -> fAcc2L f + (fAcc2L f `shiftR` 1)
    _ -> fAcc2L f `shiftR` 1
  mainDark = satShift8 (fAccL f + fAcc2L f + fAcc3L f + bodyExtra)
  presenceS = fEqLowL f
  hfResWide :: Wide
  hfResWide = resize (monoSample f) - resize mainDark
  hfResSat = satWide hfResWide
  fizzSub = case modelSel of
    0 -> case airSel of
      0 -> hfResSat `shiftR` 2
      1 -> hfResSat `shiftR` 3
      _ -> hfResSat `shiftR` 4
    1 -> case airSel of
      0 -> (hfResSat `shiftR` 2) + (hfResSat `shiftR` 4)
      1 -> hfResSat `shiftR` 3
      _ -> hfResSat `shiftR` 4
    _ -> case airSel of
      0 -> (hfResSat `shiftR` 2) + (hfResSat `shiftR` 3)
      1 -> (hfResSat `shiftR` 3) + (hfResSat `shiftR` 4)
      _ -> hfResSat `shiftR` 3
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

-- 31-tap symmetric linear-phase speaker-rolloff FIR (realism item 1 / R4,
-- step B1 -- the "real-IR cab" rolloff lever). An ADDITIVE post-stage on the cab
-- output that sharpens the >5 kHz rolloff into the real-4x12 -12..-24 dB/oct band
-- WITHOUT touching the accepted D71 nonlinear cab core (cabProductsFrame /
-- cabSat / cabIr / cabLevelMix) OR the per-model presence biquad below.
--
-- B1 / Option Y (tools/dsp_sim/cab_ir.py + docs/ai_context/CAB_IR_R4_STEP_B_PLAN.md):
-- the FIR supplies ONLY the sharp rolloff (flat passband, no presence bump); the
-- EXISTING presence biquad keeps making the 2-4 kHz cone-breakup peak. That is
-- why 31 taps suffice (resolving the rolloff needs few taps; only resolving the
-- Q~1 peak would need ~95 -- and the biquad already does the peak). Offline this
-- moves the 5-12 kHz rolloff open -11.3 -> -13.0, british -9.5 -> -19.5, closed
-- -11.3 -> -26.6 dB/oct, all three cab targets PASS (cab_ir.py --rolloff-only
-- --taps 31 --check). The full 128-tap BRAM convolution (step B2) is deferred.
--
-- Coefficients are the folded HALF (c0..c15, c15 = centre) of the per-model
-- 31-tap windowed-sinc kernels, hand-designed magnitude targets (NOT captured
-- commercial IRs, D7), Signed 16, unity-DC sum 2^16 (=> mix shift >> 16).
-- Symmetric, so it folds to 16 DSP48 MACs (15 pre-adder pairs + 1 centre).
-- `hist` = [x[n-1] .. x[n-30]] (cab output history). Bit-exact bypass when the
-- cab is off. 96 kHz design (cab_ir.py FS=96000). Re-emit with
-- `cab_ir.py --rolloff-only --taps 31 --emit-clash`, do not hand-edit.
cabSpeakerFirCoeff :: Unsigned 8 -> Vec 16 (Signed 16)
cabSpeakerFirCoeff model = case model `shiftR` 6 of
  -- open 1x12 (sum 65537)
  0 ->   (-6) :> (-17) :> (-39) :> (-82) :> (-145) :> (-221) :> (-271) :> (-228)
      :> 26 :> 634 :> 1738 :> 3366 :> 5417 :> 7546 :> 9527 :> 11047 :> Nil
  -- british 2x12 (sum 65537)
  1 ->   (-46) :> (-64) :> (-96) :> (-137) :> (-169) :> (-156) :> (-46) :> 223
      :> 720 :> 1504 :> 2600 :> 3962 :> 5457 :> 6853 :> 7926 :> 8475 :> Nil
  -- closed 4x12 (sum 65538)
  _ ->   (-62) :> (-70) :> (-83) :> (-87) :> (-54) :> 55 :> 284 :> 675
      :> 1262 :> 2054 :> 3026 :> 4108 :> 5188 :> 6125 :> 6797 :> 7102 :> Nil

-- The FIR is split into two pipeline stages (it is feedforward, so it
-- pipelines freely -- unlike the biquads' feedback). A single combinational
-- 31-tap sum would be far too deep. Stage 1 computes all 16 folded products
-- from ONE history snapshot into the SIX available Wide partial-sum fields
-- (<= 3 products each = the SAME add depth as the accepted 15-tap stage); stage
-- 2 combines (balanced tree) + scales. The folded pair sum (a+b)*c maps onto
-- the DSP48 pre-adder, so each pair is one DSP. Folded pairs: tap_k pairs with
-- tap_(30-k) for k=0..14 (tap0 = x, tap_j = hist!!(j-1)); centre = tap15 =
-- hist!!14.
cabSpeakerFirProductsFrame :: Vec 30 Sample -> Frame -> Frame
cabSpeakerFirProductsFrame hist f =
  f { fAccL  = if on then p0 else 0, fAccR  = if on then p1 else 0
    , fAcc2L = if on then p2 else 0, fAcc2R = if on then p3 else 0
    , fAcc3L = if on then p4 else 0, fAcc3R = if on then p5 else 0 }
 where
  on = flag7 (fGate f)
  x = monoSample f
  c = cabSpeakerFirCoeff (ctrlC (fCab f))
  pm = foldTap16   -- (a+b)*g, Signed 16 coeff, one DSP48 pre-adder MAC
  p0 = pm x           (hist !! 29) (c !! 0)
         + pm (hist !! 0)  (hist !! 28) (c !! 1)
         + pm (hist !! 1)  (hist !! 27) (c !! 2)
  p1 = pm (hist !! 2)  (hist !! 26) (c !! 3)
         + pm (hist !! 3)  (hist !! 25) (c !! 4)
         + pm (hist !! 4)  (hist !! 24) (c !! 5)
  p2 = pm (hist !! 5)  (hist !! 23) (c !! 6)
         + pm (hist !! 6)  (hist !! 22) (c !! 7)
         + pm (hist !! 7)  (hist !! 21) (c !! 8)
  p3 = pm (hist !! 8)  (hist !! 20) (c !! 9)
         + pm (hist !! 9)  (hist !! 19) (c !! 10)
         + pm (hist !! 10) (hist !! 18) (c !! 11)
  p4 = pm (hist !! 11) (hist !! 17) (c !! 12)
         + pm (hist !! 12) (hist !! 16) (c !! 13)
  p5 = pm (hist !! 13) (hist !! 15) (c !! 14)
         + mulS16 (hist !! 14) (c !! 15)

cabSpeakerFirMixFrame :: Frame -> Frame
cabSpeakerFirMixFrame f =
  setMonoSample (if on then out else monoSample f) f
 where
  on = flag7 (fGate f)
  out = satShift16 (((fAccL f + fAccR f) + (fAcc2L f + fAcc2R f))
                    + (fAcc3L f + fAcc3R f))

cabSpeakerFirHistNext :: Vec 30 Sample -> Maybe Frame -> Vec 30 Sample
cabSpeakerFirHistNext hist Nothing = hist
cabSpeakerFirHistNext hist (Just f) = monoSample f +>> hist

-- ---- Cone-breakup presence-peak biquad (voicing) ----------------------
-- A real guitar speaker has a broad presence peak ~2-4 kHz (cone breakup) on
-- top of its rolloff -- the brightening "honk" that makes a cab cut through.
-- The 15-tap speaker FIR is far too short to resolve a peak at 2.8 kHz at
-- 96 kHz (its main lobe is ~6 kHz wide), so this is a dedicated 2nd-order
-- peaking biquad: RBJ, f0 = 2800 Hz, Q = 1.0, +3.5 dB, UNITY at DC and Nyquist
-- by construction so it adds ONLY the presence peak (does not touch the FIR's
-- DC level or >5 kHz rolloff). Hand-designed target curve (NOT a captured IR,
-- D7), same policy as the TS / bigMuff biquads.
-- Direct-form-I, Q14 (a0 normalised to 2^14). Split into a feedforward stage
-- (b0*x + b1*x1 + b2*x2 into fAcc3L, no feedback -- pipelines freely) and a
-- recursive stage (-a1*y1 - a2*y2, two multiplies, short feedback path), the
-- D82/D83 timing form used by every island biquad. Runs after the speaker FIR;
-- fAcc3L is free at that point (the FIR mix already consumed it). Bit-exact
-- bypass when the cab is off.
--
-- D123: the presence biquad is now PER-MODEL (coeff-only mux, same structure)
-- to give the three cabs distinct presence identities. The step-4 measurement
-- (REALISM_CAB_MEASUREMENT.md) showed all three peaked at the SAME 2806 Hz
-- (shared coeffs) -- no model separation. RBJ peaking, 96 kHz, Q14:
--   open 1x12   3400 Hz, Q 0.8, +4.5 dB  (brighter / airier, higher center)
--   british 2x12 2800 Hz, Q 1.0, +5.0 dB (mid-forward identity)
--   closed 4x12 2300 Hz, Q 1.2, +5.5 dB  (lower / thicker presence honk)
-- b1 == a1 for RBJ peaking, so na1 = -b1; only b0/b1/b2 + a2 differ per model.
-- D151 raised these +3.0/+3.5/+4.0 -> +6.0/+6.5/+7.0 dB for rig brightness ("amp の
-- 高音成分が足りない"). D152 PULLS BACK to +4.5/+5.0/+5.5 dB: the D151 peak sat right
-- in the 2-4 kHz where a distorted chord's in-band intermod is densest, so it
-- amplified the chord IMD = the "和音の高音が汚い / 大入力でブツブツ". Pulling it back
-- ~1.5 dB cuts that IMD amplification while keeping most of D151's brightness
-- (still +1.5 dB over the pre-D151 baseline). f0/Q unchanged; D149 rolloff FIR
-- untouched. Coeffs from the RBJ peaking formula.
cabPresenceFFCoeff :: Unsigned 8 -> (Signed 16, Signed 16, Signed 16)
cabPresenceFFCoeff model = case model `shiftR` 6 of
  0 -> (17454, -28885, 12161)
  1 -> (17200, -30159, 13473)
  _ -> (17014, -30987, 14327)

cabPresenceFBCoeff :: Unsigned 8 -> (Signed 16, Signed 16)
cabPresenceFBCoeff model = case model `shiftR` 6 of
  0 -> (28885, 13231)
  1 -> (30159, 14288)
  _ -> (30987, 14957)
-- NB: the cab presence peak + the cab sat headroom (above) are the rig levers;
-- the amp-side HF shelf / TREBLE / PRESENCE move a rig's 2-4 kHz <1 dB.

cabPresenceFeedforwardFrame :: Sample -> Sample -> Frame -> Frame
cabPresenceFeedforwardFrame x1 x2 f =
  setMonoAcc3 (if on then ff else 0) f
 where
  on = flag7 (fGate f)
  x = monoSample f
  (b0, b1, b2) = cabPresenceFFCoeff (ctrlC (fCab f))
  ff = mulS16 x b0 + mulS16 x1 b1 + mulS16 x2 b2 :: Wide

cabPresenceRecursiveFrame :: Sample -> Sample -> Frame -> Frame
cabPresenceRecursiveFrame y1 y2 f =
  setMonoSample (if on then y else monoSample f) f
 where
  on = flag7 (fGate f)
  -- na1 = -a1 (positive), a2; fAcc3L holds the FF sum.
  (na1, a2) = cabPresenceFBCoeff (ctrlC (fCab f))
  y = satShift14 (fAcc3L f + mulS16 y1 na1 - mulS16 y2 a2)

-- ---- Cab-output micro-modulation (D96, digital-sound #11) --------------
-- A perfectly static spectrum is a "digital" tell; real speakers / air / tubes
-- have tiny constant movement. A VERY small LFO-modulated fractional delay on
-- the cab output adds organic micro-detune ("analog wobble") without an audible
-- chorus. Pure modulated delay (vibrato) at ~2-3 Hz, +-6 samples (~1-2 cents) into
-- a 128-deep line (96 kHz; was +-3 / 64-deep at 48 kHz), linear-interpolated.
-- Gated on cab-on (flag7) so the all_off
-- bypass is bit-exact (the LFO + line still advance, harmlessly). The depth is
-- deliberately tiny; cabModDepthQ4 / cabModLfoStep are the bench-tunable knobs.
-- 96 kHz: LFO step halved (3 -> 2, ~2.9 Hz; closest integer to the 1.5 ideal),
-- and the center tap + modulation depth double (in samples) so the delay TIME
-- and the vibrato cents are preserved at 2x fs.
cabModLfoStep :: Unsigned 16
cabModLfoStep = 2            -- ~2.9 Hz at 96 kHz (96000 * 2 / 65536)

cabModCenterQ4 :: Unsigned 16
cabModCenterQ4 = 1024        -- center read = tap 64, in Q4 sub-samples (64 << 4)

cabModDepthQ4 :: Unsigned 16
cabModDepthQ4 = 192          -- peak-to-peak, Q4 (192/16 = 12 samples p-p = +-6 = +-62.5 us)

cabModLfoNext :: Unsigned 16 -> Maybe Frame -> Unsigned 16
cabModLfoNext ph Nothing = ph
cabModLfoNext ph (Just _) = ph + cabModLfoStep

cabModDelayNext :: Vec 128 Sample -> Maybe Frame -> Vec 128 Sample
cabModDelayNext line Nothing = line
cabModDelayNext line (Just f) = monoSample f +>> line

cabModFrame :: Unsigned 16 -> Vec 128 Sample -> Frame -> Frame
cabModFrame ph line f =
  setMonoSample (if on then out else monoSample f) f
 where
  on = flag7 (fGate f)
  -- Triangle 0..0x7FFF..0 from the 16-bit phase.
  lower = ph .&. 0x7FFF
  tri = if testBit ph 15 then 0x7FFF - lower else lower :: Unsigned 16
  -- Fractional read position in Q4 sub-samples, centered on cabModCenterQ4.
  modOffQ4 = resize ((resize tri * resize cabModDepthQ4 :: Unsigned 32) `shiftR` 15) :: Unsigned 16
  readPosQ4 = cabModCenterQ4 - (cabModDepthQ4 `shiftR` 1) + modOffQ4
  idxA = fromIntegral (readPosQ4 `shiftR` 4) :: Int
  fracU = readPosQ4 .&. 0xF
  tapA = line !! idxA
  tapB = line !! (idxA + 1)
  -- Linear interpolation: tapA + (tapB - tapA) * frac / 16.
  delta = resize tapB - resize tapA :: Signed 31
  fracS = fromIntegral fracU :: Signed 31
  interp = (delta * fracS) `shiftR` 4
  out = satWide (resize tapA + resize interp :: Wide)
