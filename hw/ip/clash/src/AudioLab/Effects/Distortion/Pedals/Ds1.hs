{-# LANGUAGE NumericUnderscores #-}

-- | ds1 (BOSS DS-1 style) pedal stages (split out of Distortion/Pedals.hs,
-- refactor K). The shared mid-scoop biquad that DS-1 also drives lives in the
-- BigMuff module (priority metal -> ds1 -> bigMuff, single pedal at a time).
module AudioLab.Effects.Distortion.Pedals.Ds1 where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types
import AudioLab.Effects.Distortion.Common

-- ---- ds1 (BOSS DS-1 style; 5 stages: HPF, mul, asym hard/soft hybrid
--                clip, post LPF, level+safety) ------------------------
--
-- Voiced for a brighter, edgier crunch than tube_screamer: the input
-- HPF tightens with TIGHT, the asym soft clip uses lower knees so the
-- saturation hits earlier, and the post LPF starts brighter so the top
-- end stays present even at moderate TONE. Reference: BOSS DS-1 only
-- by name and parameter idea; no schematics, no reference source code.

ds1HpfFrame :: Sample -> Frame -> Frame
ds1HpfFrame prevLp f =
  (if on then setMonoSample hp else setMonoSample x) (setMonoEqLow lp f)
 where
  on = ds1On f
  -- Lighter input low cut: the real DS-1 keeps a ~100 Hz low-mid bump. The D129
  -- base-1 still cut the 100 Hz region (HPF corner ~240 Hz, low-vs-mid -6.6 dB);
  -- tight>>6 drops the corner to ~120 Hz so the bottom is retained.
  alpha = 1 + (distTight (fOd f) `shiftR` 6)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x
  hp = satWide (resize x - resize lp :: Wide)

ds1MulFrame :: Frame -> Frame
ds1MulFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = ds1On f
  drive = ctrlC (fDist f)
  -- More push than TS and intentionally harder-edged.
  gain = pedalDriveGain 256 9 drive    -- refactor C: shared kernel

ds1ClipFrame :: Frame -> Frame
ds1ClipFrame f =
  setMonoSample (if on then symSoftClipMed kneeP kneeN boosted else monoSample f) f
 where
  on = ds1On f
  boosted = satShift8 (fAccL f)
  -- Lower knees than TS for a harder edge but still soft (DS-1 has
  -- diode-pair hard clip; we approximate with soft clip to keep
  -- timing comparable to the existing pedals).
  -- D150 chord-IMD fix: the old asymSoftClip (pos>>2 neg>>3) added even-order
  -- sum/difference tones that made DS-1 chords sound detuned. The diode pair in
  -- a real DS-1 is SYMMETRIC, so use symSoftClipMed (pos>>2 neg>>2) -- odd-order
  -- IMD only -- and raise the knee slightly so a hard-strummed chord clips a bit
  -- later (less mud) while single-note grit/aggression is preserved.
  kneeP = 2_150_000 :: Sample   -- was 1_900_000
  kneeN = 2_150_000 :: Sample   -- was 1_900_000

ds1ToneFrame :: Sample -> Frame -> Frame
ds1ToneFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = ds1On f
  tone = ctrlA (fDist f)
  -- Brighter than TS; cutting top end without full pass-through.
  -- 96 kHz: bilinear-refit (was 104 + tone>>1) to hold the same LPF corner Hz.
  alpha = 59 + (tone `shiftR` 1)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

ds1LevelFrame :: Frame -> Frame
ds1LevelFrame f =
  setMonoSample (if on then softClipK safetyKnee afterLevel else monoSample f) f
 where
  on = ds1On f
  level = ctrlB (fDist f)
  afterLevel = distLevelRaw (monoSample f) level   -- refactor C: shared kernel
  -- Output safety: the level stage soft-clips before reaching the
  -- post-pedal pipeline so a misuse of LEVEL cannot slam the saturator.
  safetyKnee = 3_000_000 :: Sample
