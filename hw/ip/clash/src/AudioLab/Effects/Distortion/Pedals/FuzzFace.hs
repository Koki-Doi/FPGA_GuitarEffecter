{-# LANGUAGE NumericUnderscores #-}

-- | fuzz_face (Fuzz Face style) pedal stages (split out of
-- Distortion/Pedals.hs, refactor K).
module AudioLab.Effects.Distortion.Pedals.FuzzFace where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types
import AudioLab.Effects.Distortion.Common

-- ---- fuzz_face (Fuzz Face style; 6 stages: pre-gain, asym clip,
--                mid-hump biquad, tone, level+safety) ------------------
--
-- Voiced for raw, asymmetric fuzz: the pre stage already has a hot
-- floor so even DRIVE=0 produces some breakup, the clip stage uses
-- aggressively low asymmetric knees so the negative half compresses
-- harder than the positive half, and the tone LPF maps to a
-- "round vs. bright" axis since real Fuzz Faces typically have no
-- tone control. Reference: Dallas Arbiter / Dunlop Fuzz Face only by
-- name and parameter idea; no schematics, no reference source code.

fuzzFacePreFrame :: Frame -> Frame
fuzzFacePreFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = fuzzFaceOn f
  drive = ctrlC (fDist f)
  -- Lower ceiling and hot asymmetry preserve cleanup without gating out.
  gain = pedalDriveGain 448 8 drive    -- refactor C: shared kernel

-- Fuzz Face dynamic bias envelope (realism item 5b / R2). A peak-follower on
-- the post-pre-gain ("boosted") level, same shape as the Compressor /
-- NoiseSuppressor envelopes (instant attack, linear release, reset to 0 when
-- the pedal is off so OFF stays bit-exact). The clip stage uses it to drift
-- the knees with the playing level -- the level-dependent behaviour a static
-- waveshaper lacks. No multiply (abs + shift + compare only), so no new DSP.
-- 96 kHz: halved (was 4096) so the bias envelope release TIME is unchanged.
ffBiasReleaseStep :: Sample
ffBiasReleaseStep = 2048

fuzzFaceBiasEnvNext :: Sample -> Maybe Frame -> Sample
fuzzFaceBiasEnvNext = peakFollower fuzzFaceOn level (\_ _ -> ffBiasReleaseStep)
 where
  level f = abs24 (satShift8 (fAccL f))

fuzzFaceClipFrame :: Sample -> Frame -> Frame
fuzzFaceClipFrame env f =
  setMonoSample (if on then asymSoftClip kneeP kneeN boosted else monoSample f) f
 where
  on = fuzzFaceOn f
  boosted = satShift8 (fAccL f)
  -- Dynamic bias (item 5b): the knees drift with the playing-level envelope.
  -- Soft playing / rolled-back guitar volume -> low env -> the base
  -- asymmetric Ge knees (cleaner, more open); hard picking -> high env ->
  -- knees pull together (harder, more symmetric compression / sputter under
  -- load). Bounded (biasShift capped) and clamped so kneeP never collapses;
  -- env = 0 on bypass keeps OFF bit-exact.
  rawShift = env `shiftR` 4
  biasShift = if rawShift > 500_000 then 500_000 else rawShift
  -- Base asymmetry: negative half compresses harder, positive keeps cleanup room.
  -- Sustain/saturation pass (dist_eval: sustain only 1.12x, THD max 34%): lower
  -- knees so a real-Fuzz-Face note holds + saturates more (cleanup via the bias
  -- envelope is preserved -- biasShift still opens the knees at low playing level).
  kneeP = 1_250_000 - biasShift :: Sample
  kneeN = 700_000 + (biasShift `shiftR` 1) :: Sample

-- Broad Fuzz-Face transistor / pickup-loading voice peak. The previous
-- Fuzz Face curve was intentionally warm but almost flat, so it passed the
-- old low-vs-mid target while still missing the "vocal" mid focus players
-- expect from a real two-transistor fuzz into a guitar pickup. This post-clip
-- peaking biquad adds a broad +3 dB hump around 900 Hz before the round tone
-- LPF. It is a designed RBJ target curve at 96 kHz, not a copied schematic or
-- VST coefficient table. Pipeline-split like the Big Muff / amp biquads so the
-- feedback path closes with only two multiplies.
fuzzFaceMidFeedforwardFrame :: Sample -> Sample -> Frame -> Frame
fuzzFaceMidFeedforwardFrame x1 x2 f =
  setMonoAcc3 (if on then ff else 0) f
 where
  on = fuzzFaceOn f
  x = monoSample f
  -- refactor B: shared FixedPoint.biquadFf
  ff = biquadFf x x1 x2 16632 (-31511) 14933

fuzzFaceMidRecursiveFrame :: Sample -> Sample -> Frame -> Frame
fuzzFaceMidRecursiveFrame y1 y2 f =
  setMonoSample (if on then y else monoSample f) f
 where
  on = fuzzFaceOn f
  -- a1 = -31511, a2 = 15181; fAcc3L holds the feedforward sum.
  -- refactor B: shared FixedPoint.biquadRec (na1 = 31511)
  y = biquadRec (fAcc3L f) y1 y2 31511 15181

fuzzFaceToneFrame :: Sample -> Frame -> Frame
fuzzFaceToneFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = fuzzFaceOn f
  tone = ctrlA (fDist f)
  -- "Round vs. bright", still rolling off the very top. The new mid-hump stage
  -- boosts the 900 Hz fundamental region, so the post tone LPF is opened a bit
  -- to keep the transistor fuzz edge / THD visible without adding >5 kHz fizz.
  alpha = 46 + (tone `shiftR` 1)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

fuzzFaceLevelFrame :: Frame -> Frame
fuzzFaceLevelFrame f =
  setMonoSample (if on then softClipK safetyKnee afterLevel else monoSample f) f
 where
  on = fuzzFaceOn f
  level = ctrlB (fDist f)
  afterLevel = distLevelRaw (monoSample f) level   -- refactor C: shared kernel
  -- Output safety knee avoids gated collapse at high LEVEL.
  safetyKnee = 3_000_000 :: Sample
