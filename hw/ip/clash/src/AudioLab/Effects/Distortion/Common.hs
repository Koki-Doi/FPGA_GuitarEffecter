{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Distortion.Common where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

-- ---- Shared distortion-pedal stage kernels ---------------------------
-- Bit-exact factoring of the per-pedal forms repeated across the six
-- distortion-pedalboard pedals (clean_boost / tube_screamer / metal / ds1 /
-- big_muff / fuzz_face). Only the per-pedal constants differ.

-- | Drive-multiply gain: @base + drive * k@ (Q at the Unsigned 12 mul scale).
-- The pedal multiply stages do @mulU12 (monoSample f) (pedalDriveGain base k
-- drive)@. (clean_boost used an Unsigned 11 intermediate for its 256 + drive*2;
-- the value never overflows Unsigned 11, so the Unsigned 12 form here is
-- numerically identical.)
pedalDriveGain :: Unsigned 12 -> Unsigned 12 -> Unsigned 8 -> Unsigned 12
pedalDriveGain base k drive = base + (resize drive * k)

-- | Output level: @satShift7 (sample * LEVEL byte)@, LEVEL = distortion_control
-- ctrlB. The per-pedal level stages wrap this in their own saturator
-- (softClip / softClipK with a per-pedal safety knee).
distLevelRaw :: Frame -> Sample
distLevelRaw f = satShift7 (mulU8 (monoSample f) (ctrlB (fDist f)))

-- ---- Shared 4x oversampled-hard-clip helpers (realism item 2 / R5) --------
-- Reused by every oversampled clip (Metal D88, RAT D89, ...). The clip itself
-- and its threshold are pedal-specific; these helpers are the generic
-- upsample / decimation machinery.

-- The 4 linear-interp 4x sub-sample points for the interval [x1 -> xn]
-- (chronological: p0 at x1, p3 near xn). Shifts/adds only, no multiply.
os4xInterp :: Sample -> Sample -> (Sample, Sample, Sample, Sample)
os4xInterp x1 xn = (x1, p1, p2, p3)
 where
  x1w = resize x1 :: Wide
  xnw = resize xn :: Wide
  p1 = satWide (((x1w `shiftL` 1) + x1w + xnw) `shiftR` 2)   -- (3*x1 + xn)/4
  p2 = satWide ((x1w + xnw) `shiftR` 1)                       -- (x1 + xn)/2
  p3 = satWide ((x1w + (xnw `shiftL` 1) + xnw) `shiftR` 2)    -- (x1 + 3*xn)/4

-- 4 hard-clipped sub-samples (Metal / RAT). Big Muff uses its own soft-clip
-- cascade variant (bigMuffOsSubSamples) over the same os4xInterp points.
os4xSubSamples :: Sample -> Sample -> Sample -> (Sample, Sample, Sample, Sample)
os4xSubSamples thr x1 xn = (hardClip p0 thr, hardClip p1 thr, hardClip p2 thr, hardClip p3 thr)
 where
  (p0, p1, p2, p3) = os4xInterp x1 xn

-- 15-tap symmetric anti-alias decimation FIR over the 192 kHz clipped stream
-- (taps newest-first q3 q2 q1 q0 hist0..hist10; coeffs
-- [-2,-3,-4,5,29,68,104,118,...] Q9 sum=512 = unity DC). Folded to 8
-- multiplies, returned as 3 Wide partial sums for the pipeline-split products
-- stage. Combine in the mix stage with `satShift9 (s0+s1+s2)`.
os4xDecimProducts ::
  Sample -> Sample -> Sample -> Sample -> Vec 12 Sample -> (Wide, Wide, Wide)
os4xDecimProducts q0 q1 q2 q3 hist = (s0, s1, s2)
 where
  s0 = foldTap q3 (hist !! 10) (-2) + foldTap q2 (hist !! 9) (-3) + foldTap q1 (hist !! 8) (-4)
  s1 = foldTap q0 (hist !! 7) 5 + foldTap (hist !! 0) (hist !! 6) 29 + foldTap (hist !! 1) (hist !! 5) 68
  s2 = foldTap (hist !! 2) (hist !! 4) 104 + mulS10 (hist !! 3) 118

os4xHistShift ::
  KnownNat n => Sample -> Sample -> Sample -> Sample -> Vec n Sample -> Vec n Sample
os4xHistShift q0 q1 q2 q3 hist = q3 +>> q2 +>> q1 +>> q0 +>> hist

