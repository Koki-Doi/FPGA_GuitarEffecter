{-# LANGUAGE NumericUnderscores #-}

-- | metal_distortion pedal stages (split out of Distortion/Pedals.hs, refactor
-- K). The os4x upsample / decimation machinery it uses lives in
-- AudioLab.Effects.Distortion.Common (shared with RAT / Big Muff).
module AudioLab.Effects.Distortion.Pedals.Metal where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types
import AudioLab.Effects.Distortion.Common

-- ---- metal_distortion (5 stages: tight HPF, mul, hard clip,
--                        post-LPF, level) -----------------------------

metalHpfFrame :: Sample -> Frame -> Frame
metalHpfFrame prevLp f =
  (if on then setMonoSample hp else setMonoSample x) (setMonoEqLow lp f)
 where
  on = metalDistortionOn f
  -- Low-end restoration (re-collation: absolute-low measure showed Metal -18.7 dB
  -- low-vs-mid = far too thin). The old base 4 + tight>>4 put the HPF corner near
  -- ~650 Hz, gutting the 150-650 Hz body; a real MT-2 only rolls off below
  -- ~150 Hz. Lower to 1 + tight>>6 (~120 Hz corner) so the low-mid chunk returns.
  alpha = 1 + (distTight (fOd f) `shiftR` 6)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x
  hp = satWide (resize x - resize lp :: Wide)

metalMulFrame :: Frame -> Frame
metalMulFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = metalDistortionOn f
  drive = ctrlC (fDist f)
  -- Higher drive within the existing Q12 gain path; threshold and LPF
  -- below keep the result aggressive without fizzing out.
  gain = pedalDriveGain 768 13 drive   -- refactor C: shared kernel

-- 4x oversampled hard clip (realism item 2 / R5) for Metal MT-2, the worst
-- aliaser. A static 48 kHz hard clip generates harmonics far above Nyquist
-- that fold back as inharmonic "digital fizz"; running the clip at 4x and
-- steeply decimating pushes those products out before the fold (offline:
-- ~-12 dB inharmonic energy vs 1x; 2x only reaches ~-6 dB because >48 kHz
-- harmonics still fold).
--
-- Structure (DSP only in the decimation FIR): linear-interp upsample 4x (the
-- input is already band-limited, so linear interp's images are negligible --
-- offline-confirmed equal to a full anti-image FIR -- and the 0/1/4/1/2/3/4
-- weights are shifts/adds, no multiply) -> hard clip the 4 sub-samples ->
-- 15-tap symmetric anti-alias decimation FIR over the 192 kHz clipped stream
-- (Q9, sum=512 = unity DC, -7.5 dB @ 24 kHz / -48 dB @ 48 kHz; folds to 8
-- multiplies). The clipped sub-sample history lives in a Vec 12 pipeline
-- register. The FIR is split products/mix (a FIR is feedforward, pipelines
-- freely; the D87 lesson) to keep the 50 MHz island path short. Bit-exact
-- bypass when the pedal is off.
metalClipThreshold :: Frame -> Sample
metalClipThreshold f = resize (if rawT < 600_000 then 600_000 else rawT) :: Sample
 where
  driveS = resize (asSigned9 (ctrlC (fDist f))) :: Signed 25
  -- Lower threshold = harder/denser clip. "完全飽和" pass (2026-06-17): floor
  -- 1.05M -> 600k + steeper slope (2.3M->1.7M, *7000->*8500) so the os4x hard
  -- clip flattens almost the whole waveform = MAXIMUM saturation density at all
  -- playing levels (a real MT-2 is a high-gain monster). This is the os4x
  -- (4x-oversampled) clip, so the extra harmonics are ANTI-ALIASED (no base-rate
  -- fizz); the post-LPF below shapes them.
  rawT = 1_700_000 - driveS * 8_500 :: Signed 25

-- ---- Metal 4x oversampled clip (D88) --------------------------------------

metalClipProductsFrame :: Sample -> Vec 12 Sample -> Frame -> Frame
metalClipProductsFrame x1 hist f =
  f { fAccL = if on then s0 else 0, fAccR = 0
    , fAcc2L = if on then s1 else 0, fAcc2R = 0
    , fAcc3L = if on then s2 else 0, fAcc3R = 0 }
 where
  on = metalDistortionOn f
  (q0, q1, q2, q3) = os4xSubSamples (metalClipThreshold f) x1 (satShift7 (fAccL f))
  (s0, s1, s2) = os4xDecimProducts q0 q1 q2 q3 hist

metalClipMixFrame :: Frame -> Frame
metalClipMixFrame f =
  setMonoSample (if on then satShift9 (fAccL f + fAcc2L f + fAcc3L f) else monoSample f) f
 where
  on = metalDistortionOn f

metalClipHistNext :: Vec 12 Sample -> Sample -> Maybe Frame -> Vec 12 Sample
metalClipHistNext hist _ Nothing = hist
metalClipHistNext hist x1 (Just f) = os4xHistShift q0 q1 q2 q3 hist
 where
  (q0, q1, q2, q3) = os4xSubSamples (metalClipThreshold f) x1 (satShift7 (fAccL f))

metalPostLpfFrame :: Sample -> Frame -> Frame
metalPostLpfFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = metalDistortionOn f
  tone = ctrlA (fDist f)
  -- Post-LPF: dark MT-2 voicing, but base 8 (~1 kHz) filtered out the saturation
  -- EDGE too (dist_eval: THD plateaued at 17% despite crest 2.3 = hard-clipped).
  -- "完全飽和" pass (2026-06-17): with the clip floor dropped to 600k the dense
  -- clip generates far more harmonics; open the post-LPF base 15 -> 22 (~2.7 kHz
  -- corner) so the 3rd/5th harmonic actually reach the output = AUDIBLY more
  -- saturated/aggressive (the THD ceiling rises off the old ~19% post-LPF cap).
  -- Still rolls off the >4-5 kHz ice-pick, and the 4x oversampling keeps
  -- alias-fizz down, so it is "fully saturated MT-2", brighter than the previous
  -- dark voicing (an intentional trade for more 歪; lower the TONE knob to darken).
  alpha = 38 + (tone `shiftR` 2)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

metalLevelFrame :: Frame -> Frame
metalLevelFrame f =
  setMonoSample (if on then softClip afterLevel else monoSample f) f
 where
  on = metalDistortionOn f
  level = ctrlB (fDist f)
  afterLevel = distLevelRaw (monoSample f) level   -- refactor C: shared kernel
