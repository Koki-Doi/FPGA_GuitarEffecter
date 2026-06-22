{-# LANGUAGE NumericUnderscores #-}

-- | tube_screamer pedal stages (split out of Distortion/Pedals.hs, refactor K).
module AudioLab.Effects.Distortion.Pedals.TubeScreamer where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types
import AudioLab.Effects.Distortion.Common

-- ---- tube_screamer (5 stages: HPF, mul, clip, post-LPF, level) -------

tubeScreamerHpfFrame :: Sample -> Frame -> Frame
tubeScreamerHpfFrame prevLp f =
  (if on then setMonoSample hp else setMonoSample x) (setMonoEqLow lp f)
 where
  on = tubeScreamerOn f
  -- Stronger low cut into the clip stage for a TS-style mid focus.
  -- 96 kHz: bilinear-refit (was 4 + tight>>4) to hold the same HPF corner Hz.
  alpha = 2 + (distTight (fOd f) `shiftR` 5)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x
  hp = satWide (resize x - resize lp :: Wide)

-- ~720 Hz mid-hump peaking biquad (realism item 3 / R3). Pre-clip mid
-- emphasis is what gives the Tube Screamer its signature mid-focused drive:
-- the boosted ~720 Hz band is pushed harder into the clip stage than the rest
-- of the spectrum, so the saturation is mid-weighted rather than full-range.
-- Direct-form-I with Q14 fixed coefficients, hand-designed for f0 = 720 Hz,
-- fs = 48 kHz, Q = 0.8, +6 dB peak (a chosen target curve, NOT a
-- schematic-derived table -- same inspired-by policy as the rest of the
-- chain, D7/D45). The coefficients are unity at DC and Nyquist by
-- construction, so the spectrum outside the hump is essentially unchanged.
--   y[n]*2^14 = b0*x + b1*x1 + b2*x2 - a1*y1 - a2*y2  (a0 normalised to 2^14)
--   b0=17036  b1=-31323  b2=14422  ;  a1=-31323  a2=15075  -> -a1 = +31323
-- x1/x2/y1/y2 are pipeline-level state (threaded in Pipeline.hs) so idle
-- Nothing cycles preserve the filter memory. Bit-exact bypass when the pedal
-- is off (output = input). The five multiplies are computed in parallel and
-- summed in an adder tree (no serial multiply chain -- the D79/Wah timing
-- lesson on this island).
tubeScreamerMidFrame :: Sample -> Sample -> Sample -> Sample -> Frame -> Frame
tubeScreamerMidFrame x1 x2 y1 y2 f =
  setMonoSample (if on then y else x) f
 where
  on = tubeScreamerOn f
  x = monoSample f
  -- 96 kHz RBJ coeffs (720 Hz, Q 0.8, +6 dB); was 17036/-31323/14422/31323/15075 @48k.
  acc =
    mulS16 x 16717
      + mulS16 x1 (-32063)
      + mulS16 x2 15382
      + mulS16 y1 32063
      - mulS16 y2 15715 :: Wide
  y = satShift14 acc

tubeScreamerMulFrame :: Frame -> Frame
tubeScreamerMulFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = tubeScreamerOn f
  drive = ctrlC (fDist f)
  -- Smooth drive ceiling; this should stay overdrive-like, not fuzz-like.
  gain = pedalDriveGain 256 5 drive    -- refactor C: shared kernel

tubeScreamerClipFrame :: Frame -> Frame
tubeScreamerClipFrame f =
  setMonoSample (if on then asymSoftClip kneeP kneeN boosted else monoSample f) f
 where
  on = tubeScreamerOn f
  boosted = satShift8 (fAccL f)
  -- Near-symmetric soft knees keep the TS smoother than DS-1.
  kneeP = 3_000_000 :: Sample
  kneeN = 2_850_000 :: Sample

tubeScreamerPostLpfFrame :: Sample -> Frame -> Frame
tubeScreamerPostLpfFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = tubeScreamerOn f
  tone = ctrlA (fDist f)
  -- Darker post-LPF emphasises the mid band and avoids piercing highs.
  -- 96 kHz: bilinear-refit (was 56 + tone>>1) to hold the same LPF corner Hz.
  alpha = 30 + (tone `shiftR` 2)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

tubeScreamerLevelFrame :: Frame -> Frame
tubeScreamerLevelFrame f =
  setMonoSample (if on then softClip afterLevel else monoSample f) f
 where
  on = tubeScreamerOn f
  level = ctrlB (fDist f)
  afterLevel = distLevelRaw (monoSample f) level   -- refactor C: shared kernel
