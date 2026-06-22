{-# LANGUAGE NumericUnderscores #-}

-- | big_muff (Big Muff Pi style) pedal stages (split out of
-- Distortion/Pedals.hs, refactor K). Also hosts the shared mid-scoop biquad
-- (bigMuffScoop*) that Metal and DS-1 drive via a coeff mux (priority
-- metal -> ds1 -> bigMuff, single pedal active at a time).
module AudioLab.Effects.Distortion.Pedals.BigMuff where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types
import AudioLab.Effects.Distortion.Common

-- ---- big_muff (Big Muff Pi style; 5 stages: pre-gain, clip1, clip2,
--                tone scoop, level+safety) ----------------------------
--
-- Voiced for thick fuzz/distortion: heavier pre gain than DS-1, two
-- cascaded soft clip stages for sustaining wall-of-sound saturation,
-- a darker tone LPF to keep fizz off the top end. Reference:
-- Electro-Harmonix Big Muff Pi only by name and parameter idea; no
-- schematics, no reference source code.

bigMuffPreFrame :: Frame -> Frame
bigMuffPreFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = bigMuffOn f
  drive = ctrlC (fDist f)
  -- Hot floor and broad sustain, but keep the ceiling below Metal.
  gain = pedalDriveGain 448 11 drive   -- refactor C: shared kernel

-- Big Muff 4x oversampled clip cascade (realism item 2 / R5, D90). The two
-- cascaded soft clips (clip1 -> *208 -> clip2) generate fizz that aliases at
-- 48 kHz; run the whole cascade at 4x and decimate. Same os4x machinery as
-- Metal/RAT, but the per-sub-sample nonlinearity is the soft-clip *cascade*
-- (bigMuffOsCascade), not a single hard clip. Knees are the same as the old
-- two-stage clip1/clip2 (2.4M then 1.85M, with the *208 inter-stage gain), so
-- the voicing is preserved; only aliasing is reduced. Bit-exact bypass off.
bigMuffOsCascade :: Sample -> Sample
bigMuffOsCascade x =
  -- Sustain/saturation pass (dist_eval found sustain 1.00x = NO sustain; a real
  -- Big Muff is THE sustainer). Lower both clip knees so a decaying note stays
  -- clipped to the ceiling far longer (= the note "holds") AND the saturation is
  -- denser. Inter-stage *208 (~0.8x) kept. (knees were 2_400_000 / 1_850_000.)
  softClipK 1_250_000 (satShift8 (mulU8 (softClipK 1_500_000 x) 208))

bigMuffOsSubSamples :: Sample -> Sample -> (Sample, Sample, Sample, Sample)
bigMuffOsSubSamples x1 xn =
  (bigMuffOsCascade p0, bigMuffOsCascade p1, bigMuffOsCascade p2, bigMuffOsCascade p3)
 where
  (p0, p1, p2, p3) = os4xInterp x1 xn

-- The deep soft-clip cascade (clip1 -> *208 -> clip2) lives ONLY in the
-- history-update path below (which ends at the Vec register -- no FIR after
-- it), and the products stage reads all 15 FIR taps from the 16-deep history
-- (no cascade in the products path). This keeps the cascade multiply and the
-- FIR multiply in SEPARATE register-to-register paths -- a single combined
-- stage measured WNS -6.244 ns (two muls + two clips in series). The FIR
-- output lags the cascade by one frame group (harmless latency).
bigMuffClipProductsFrame :: Vec 16 Sample -> Frame -> Frame
bigMuffClipProductsFrame hist f =
  f { fAccL = if on then s0 else 0, fAccR = 0
    , fAcc2L = if on then s1 else 0, fAcc2R = 0
    , fAcc3L = if on then s2 else 0, fAcc3R = 0 }
 where
  on = bigMuffOn f
  -- 15-tap symmetric decimation FIR over history[0..14] (newest-first);
  -- pairs (0,14)..(6,8), center 7. Coeffs [-2,-3,-4,5,29,68,104,118].
  -- refactor E: shared FixedPoint.foldTap (was a local `pm a b g = (a+b)*g`)
  s0 = foldTap (hist !! 0) (hist !! 14) (-2) + foldTap (hist !! 1) (hist !! 13) (-3) + foldTap (hist !! 2) (hist !! 12) (-4)
  s1 = foldTap (hist !! 3) (hist !! 11) 5 + foldTap (hist !! 4) (hist !! 10) 29 + foldTap (hist !! 5) (hist !! 9) 68
  s2 = foldTap (hist !! 6) (hist !! 8) 104 + (resize (hist !! 7) * 118 :: Wide)

bigMuffClipMixFrame :: Frame -> Frame
bigMuffClipMixFrame f =
  setMonoSample (if on then satShift9 (fAccL f + fAcc2L f + fAcc3L f) else monoSample f) f
 where
  on = bigMuffOn f

bigMuffClipHistNext :: Vec 16 Sample -> Sample -> Maybe Frame -> Vec 16 Sample
bigMuffClipHistNext hist _ Nothing = hist
bigMuffClipHistNext hist x1 (Just f) = os4xHistShift q0 q1 q2 q3 hist
 where
  (q0, q1, q2, q3) = bigMuffOsSubSamples x1 (satShift8 (fAccL f))

-- ~700 Hz mid-scoop NOTCH biquad (realism item 3 / R3, D82), split into a
-- feedforward stage + a recursive stage. The Big Muff's defining tone-network
-- character is a deep mid *scoop* -- a one-pole LPF (bigMuffToneFrame below)
-- can only darken, it cannot notch the mids. This post-clip peaking biquad
-- with NEGATIVE gain carves the scoop out of the saturated signal.
-- Direct-form-I, Q14 fixed coefficients, hand-designed for f0 = 700 Hz,
-- fs = 48 kHz, Q = 0.8, -10 dB dip (a chosen target curve, NOT a
-- schematic-derived table -- same policy as the TS mid hump, D7/D45). Unity
-- at DC and Nyquist by construction so only the mids are scooped.
--   y[n]*2^14 = b0*x + b1*x1 + b2*x2 - a1*y1 - a2*y2  (a0 normalised to 2^14)
--   b0=15350  b1=-29618  b2=14393  ;  a1=-29618  a2=13359  -> -a1 = +29618
--
-- TIMING SPLIT (D82): the single-stage 5-multiply form measured island
-- WNS -0.659 ns (the biquad feedback path was near-critical and pressured the
-- DS-1 P&R). The IIR feedback loop CANNOT be naively pipelined (it would
-- change the transfer function), so instead the FEEDFORWARD sum
-- (b0*x + b1*x1 + b2*x2, no feedback) is precomputed one stage earlier into
-- fAcc3L; the recursive stage then closes the loop with only TWO multiplies
-- (-a1*y1 - a2*y2), shortening the single-cycle feedback path. The math is
-- identical to the single-stage form (same coefficients, same response).
-- x1/x2 are a 2-tap delay of the stage input, y1/y2 of the recursive output;
-- bit-exact bypass when the pedal is off (output = input).
-- D126: the scoop biquad is now ALSO shared with DS-1, with a coeff mux.
-- The real BOSS DS-1 has a SHALLOW ~3 dB mid scoop (500 Hz-2 kHz) that our DS-1
-- lacked (measured as a rising tilt, no dip). DS-1 runs upstream of this stage,
-- so (like metal, D121) its output reaches here as monoSample -- adding ds1 to
-- the gate applies a scoop with NO new biquad. But DS-1's scoop is much
-- shallower / higher than the Big Muff's deep -10 dB @ 700 Hz, so when ds1 is
-- the active pedal we select a -3 dB @ 1000 Hz Q0.7 coeff set instead. When
-- bigMuff/metal is active the ORIGINAL coeffs are used (byte-identical, so the
-- D90/D121 voicing is preserved). Bypass-exact when all three are off.
-- Re-collation vs the SPECIFIC real pedals (EQ curve, not just clipping):
--   * Metal (Boss MT-2): the real Metal Zone BOOSTS its mids (narrow peak ~800 Hz)
--     and rolls off hard above 1 kHz -- it does NOT scoop. Sharing the Big Muff
--     -10 dB scoop made our Metal sound nothing like an MT-2 (bright + scooped).
--     Metal now gets a +5 dB @ 800 Hz Q0.9 BOOST here (and a darker post-LPF).
--   * DS-1: the real scoop is ~500 Hz (Big-Muff-style tone network), deeper than
--     our old -6 dB @ 1000 Hz; moved to -8 dB @ 500 Hz Q0.7.
--   * Big Muff: unchanged (-10 dB @ 700 Hz).
-- Priority metal -> ds1 -> bigMuff (single pedal active at a time).
bigMuffScoopFfCoeff :: Frame -> (Signed 16, Signed 16, Signed 16)
bigMuffScoopFfCoeff f
  | metalDistortionOn f = (16656, -32025, 15413)   -- Metal MT-2 : +5 dB @ 800 Hz BOOST (was scoop)
  | ds1On f             = (16032, -31581, 15566)   -- DS-1 : -8 dB @ 500 Hz Q0.7 (was -6 @ 1000)
  | otherwise           = (15625, -30482, 14923)   -- Big Muff : -10 dB @ 1000 Hz (re-collation:
                                                   -- the real Big Muff tone-middle notch is ~1 kHz,
                                                   -- not 700 Hz -- moves the scoop up to match)

bigMuffScoopFbCoeff :: Frame -> (Signed 16, Signed 16)
bigMuffScoopFbCoeff f
  | metalDistortionOn f = (32025, 15685)           -- Metal MT-2 boost (na1, a2)
  | ds1On f             = (31581, 15214)           -- DS-1 -8 @ 500 Hz (na1, a2)
  | otherwise           = (30482, 14163)           -- Big Muff -10 @ 1000 Hz (na1, a2)

bigMuffScoopFeedforwardFrame :: Sample -> Sample -> Frame -> Frame
bigMuffScoopFeedforwardFrame x1 x2 f =
  setMonoAcc3 (if on then ff else 0) f
 where
  on = bigMuffOn f || metalDistortionOn f || ds1On f
  x = monoSample f
  (b0, b1, b2) = bigMuffScoopFfCoeff f
  ff = mulS16 x b0 + mulS16 x1 b1 + mulS16 x2 b2 :: Wide

bigMuffScoopRecursiveFrame :: Sample -> Sample -> Frame -> Frame
bigMuffScoopRecursiveFrame y1 y2 f =
  setMonoSample (if on then y else monoSample f) f
 where
  on = bigMuffOn f || metalDistortionOn f || ds1On f   -- shared scoop (see FF note)
  (na1, a2) = bigMuffScoopFbCoeff f
  -- fAcc3L holds the FF sum; -a1 = +na1.
  y = satShift14 (fAcc3L f + mulS16 y1 na1 - mulS16 y2 a2)

bigMuffToneFrame :: Sample -> Frame -> Frame
bigMuffToneFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = bigMuffOn f
  tone = ctrlA (fDist f)
  -- Darker tone curve keeps top-end fizz off the output.
  -- 96 kHz: bilinear-refit (was 48 + tone>>1) to hold the same LPF corner Hz.
  alpha = 25 + (tone `shiftR` 2)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

bigMuffLevelFrame :: Frame -> Frame
bigMuffLevelFrame f =
  setMonoSample (if on then softClipK safetyKnee afterLevel else monoSample f) f
 where
  on = bigMuffOn f
  level = ctrlB (fDist f)
  afterLevel = distLevelRaw (monoSample f) level   -- refactor C: shared kernel
  -- Output safety knee leaves sustain but avoids level-stage collapse.
  safetyKnee = 3_100_000 :: Sample
