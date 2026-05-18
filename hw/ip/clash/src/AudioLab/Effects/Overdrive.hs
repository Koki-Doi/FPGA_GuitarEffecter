{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Overdrive where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

-- ---- Per-model coefficient tables (D45) ------------------------------
-- Six selectable Overdrive voicings replace the prior single "generic"
-- overdrive. Each model contributes only constants (no per-model
-- multiplier / no per-model clip helper / no per-model filter); the
-- audio path keeps the same 6-stage register pipeline shape as before
-- (mul -> boost -> clip -> toneMul -> toneBlend -> level). The
-- 6-way case below becomes a small constant LUT mux feeding the input
-- of an existing arithmetic op, which is the cheap pattern Vivado
-- already routes well; this is the opposite of the rejected
-- model_select attempt that put 8 parallel non-linear computations
-- behind one mux (TIMING_AND_FPGA_NOTES.md, May 4 -15.067 ns).
--
-- Model labels are inspired-by, not commercial circuit reproductions
-- (DECISIONS.md D45):
--   0 Ibanez / TS9       -- mid-focused, soft clip, low cut
--   1 BOSS / OD-1        -- simpler asym soft, slightly cruder
--   2 BOSS / BD-2        -- wider band, picky, late knee
--   3 Vemuram / Jan Ray  -- transparent low gain
--   4 Fulltone / OCD     -- MOSFET-style hard knee, high headroom
--   5 CENTAUR            -- smooth, dynamic, mid focused

-- | Per-model gain ceiling factor. The driveGain in the multiply stage
-- is `256 + (drive * odDriveK model)`, so model 3 (Jan Ray, k=3)
-- produces ~1x..~3.9x at DRIVE=255 while model 4 (OCD, k=7) reaches
-- ~1x..~7.97x. Each model's ceiling stays bounded so the post-shift
-- byte never saturates beyond Q8.
odDriveK :: Unsigned 3 -> Unsigned 11
odDriveK m = case m of
  0 -> 5
  1 -> 4
  2 -> 6
  3 -> 3
  4 -> 7
  5 -> 5
  _ -> 5

-- | Per-model positive-half soft-clip knee. Smaller values clip earlier
-- (more saturation at moderate DRIVE); larger values keep the signal
-- transparent. The clip stage is the existing `asymSoftClip`; only the
-- knee constants change per model.
odKneeP :: Unsigned 3 -> Sample
odKneeP m = case m of
  0 -> 2_700_000   -- TS9 (matches prior generic OD knees)
  1 -> 2_600_000   -- OD-1: slightly earlier
  2 -> 3_000_000   -- BD-2: later, more clean headroom
  3 -> 3_200_000   -- Jan Ray: transparent
  4 -> 2_300_000   -- OCD: aggressive
  5 -> 2_800_000   -- CENTAUR: smooth, midway
  _ -> 2_700_000

-- | Per-model negative-half soft-clip knee. `kneeN < kneeP` adds even
-- harmonics; tighter asymmetry == more obvious second-harmonic
-- "tube" colour.
odKneeN :: Unsigned 3 -> Sample
odKneeN m = case m of
  0 -> 2_300_000   -- TS9
  1 -> 2_100_000   -- OD-1: stronger asym
  2 -> 2_700_000   -- BD-2: nearly symmetric
  3 -> 3_000_000   -- Jan Ray: barely asymmetric
  4 -> 1_900_000   -- OCD: hard
  5 -> 2_600_000   -- CENTAUR: gentle asym
  _ -> 2_300_000

-- | Per-model output safety knee. Caps the level stage so a hot LEVEL
-- knob cannot slam the downstream amp / pedal stages. Higher = more
-- headroom (more transparent), lower = harder ceiling.
odSafetyKnee :: Unsigned 3 -> Sample
odSafetyKnee m = case m of
  0 -> 3_200_000   -- TS9
  1 -> 3_000_000   -- OD-1: tighter
  2 -> 3_400_000   -- BD-2: more headroom
  3 -> 3_400_000   -- Jan Ray: transparent
  4 -> 3_500_000   -- OCD: high headroom
  5 -> 3_400_000   -- CENTAUR: smooth
  _ -> 3_200_000

-- ---- Overdrive pipeline stages ---------------------------------------

overdriveDriveMultiplyFrame :: Frame -> Frame
overdriveDriveMultiplyFrame f =
  f{fAccL = if on then mulU12 (monoSample f) driveGain else 0, fAccR = 0}
 where
  on = flag1 (fGate f)
  drive = ctrlC (fOd f)
  model = overdriveModel (fOd f)
  -- Per-model gain ceiling. The case picks a small constant; the
  -- multiplier downstream is a single 24x12 DSP block, exactly as
  -- before. No parallel mux of arithmetic.
  k = resize (odDriveK model) :: Unsigned 11
  driveGain = resize (256 + (resize drive * k :: Unsigned 11)) :: Unsigned 12

overdriveDriveBoostFrame :: Frame -> Frame
overdriveDriveBoostFrame f =
  setMonoWet (if on then satShift8 (fAccL f) else monoSample f) f
 where
  on = flag1 (fGate f)

-- Per-model asymmetric soft clip. The shape of the stage is identical
-- to the prior generic Overdrive (single `asymSoftClip` call); only the
-- knee constants depend on the model select.
overdriveDriveClipFrame :: Frame -> Frame
overdriveDriveClipFrame f =
  setMonoSample (if on then asymSoftClip kneeP kneeN (monoWet f) else monoSample f) f
 where
  on = flag1 (fGate f)
  model = overdriveModel (fOd f)
  kneeP = odKneeP model
  kneeN = odKneeN model

overdriveToneMultiplyFrame :: Sample -> Frame -> Frame
overdriveToneMultiplyFrame prev f =
  f
    { fAccL = if on then mulU8 (monoSample f) tone else 0
    , fAccR = 0
    , fAcc2L = if on then mulU8 prev toneInv else 0
    , fAcc2R = 0
    }
 where
  on = flag1 (fGate f)
  tone = ctrlA (fOd f)
  toneInv = 255 - tone

overdriveToneBlendFrame :: Frame -> Frame
overdriveToneBlendFrame f =
  setMonoWet (if on then tone else monoSample f) f
 where
  on = flag1 (fGate f)
  tone = satShift8 (fAccL f + fAcc2L f)

overdriveLevelFrame :: Frame -> Frame
overdriveLevelFrame f =
  setMonoSample (if on then out else monoSample f) f
 where
  on = flag1 (fGate f)
  level = ctrlB (fOd f)
  model = overdriveModel (fOd f)
  out = softClipK safetyKnee (satShift7 (mulU8 (monoWet f) level))
  safetyKnee = odSafetyKnee model
