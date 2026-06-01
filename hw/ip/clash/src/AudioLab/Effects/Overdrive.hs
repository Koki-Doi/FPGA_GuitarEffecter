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
--   2 BOSS / BD-2        -- two-cascaded-op-amp character via aggressive
--                          asymmetric clipping; D62 retuned the BD-2
--                          per-model constants only (no structural
--                          change) after D61's pipeline-state attempt
--                          re-broke the bypass path. See
--                          docs/ai_context/BD2_MODEL_RESEARCH.md D62
--                          section for the source-by-source rationale.
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
  0 -> 4
  1 -> 5
  2 -> 7   -- BD-2: D62, raised from 6 to match the two-cascaded ~40 dB op-amp
           -- character documented in BD2_MODEL_RESEARCH.md. Matches OCD's
           -- ceiling but BD-2's tighter asym knees keep the texture distinct.
  3 -> 2
  4 -> 7
  5 -> 4
  _ -> 4

-- | Per-model positive-half soft-clip knee. Smaller values clip earlier
-- (more saturation at moderate DRIVE); larger values keep the signal
-- transparent. The clip stage is the existing `asymSoftClip`; only the
-- knee constants change per model.
odKneeP :: Unsigned 3 -> Sample
odKneeP m = case m of
  0 -> 2_950_000   -- TS9: smoother, near-symmetric
  1 -> 2_550_000   -- OD-1: slightly earlier
  2 -> 2_400_000   -- BD-2: D62, aggressive (was 3_000_000). Real BD-2 has
                   -- audible breakup well below mid-drive per source [4]
                   -- breadboard measurement; "transparent" was the wrong
                   -- characterisation. Now sits between OCD (2_300_000)
                   -- and OD-1 (2_600_000) but pairs with a much smaller
                   -- N knee for strong even-harmonic asymmetry.
  3 -> 3_600_000   -- Jan Ray: transparent
  4 -> 2_450_000   -- OCD: open hard-clip-leaning drive
  5 -> 3_100_000   -- CENTAUR: smooth, clean-blend-like
  _ -> 2_950_000

-- | Per-model negative-half soft-clip knee. `kneeN < kneeP` adds even
-- harmonics; tighter asymmetry == more obvious second-harmonic
-- "tube" colour.
odKneeN :: Unsigned 3 -> Sample
odKneeN m = case m of
  0 -> 2_850_000   -- TS9: near-symmetric
  1 -> 1_750_000   -- OD-1: stronger asym
  2 -> 1_900_000   -- BD-2: D62, strong asym (was 2_700_000). The BD-2 op-amps
                   -- run from a single supply with the rail offset documented
                   -- in source [1]; the resulting saturation is asymmetric.
                   -- P/N gap is now 500k (vs OCD's 400k, OD-1's 500k) so
                   -- BD-2 carries the most pronounced even-harmonic colour
                   -- in the six-model lineup, matching the "tube-like"
                   -- breakup the real pedal is known for.
  3 -> 3_450_000   -- Jan Ray: barely asymmetric
  4 -> 2_150_000   -- OCD: firm but more open than BD-2
  5 -> 2_900_000   -- CENTAUR: gentle asym
  _ -> 2_850_000

-- | Per-model output safety knee. Caps the level stage so a hot LEVEL
-- knob cannot slam the downstream amp / pedal stages. Higher = more
-- headroom (more transparent), lower = harder ceiling.
odSafetyKnee :: Unsigned 3 -> Sample
odSafetyKnee m = case m of
  0 -> 3_350_000   -- TS9
  1 -> 3_050_000   -- OD-1: tighter
  2 -> 3_400_000   -- BD-2: more headroom
  3 -> 3_700_000   -- Jan Ray: transparent
  4 -> 3_750_000   -- OCD: high headroom
  5 -> 3_650_000   -- CENTAUR: smooth
  _ -> 3_350_000

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

-- | Per-model clip hardness class (realism item 4, D-pending). Selects the
-- compression slope of the asymmetric soft clip per model so the six models
-- differ in knee *hardness* (harmonic order), not just at what level they
-- engage. Real op-amp clip (TS9) is soft; MOSFET (OCD) is harder; the
-- germanium/clean-blend Klon stays smooth (its grit comes from the clean
-- blend, item 5a). 0=softest .. 3=hardest; see FixedPoint asymSoftClip*.
odClipHardness :: Unsigned 3 -> Unsigned 2
odClipHardness m = case m of
  0 -> 0   -- TS9      : op-amp soft clip
  1 -> 1   -- OD-1     : medium (legacy 2/3 shape)
  2 -> 1   -- BD-2     : medium, keep even-harmonic asym
  3 -> 0   -- Jan Ray  : transparent / softest
  4 -> 2   -- OCD      : harder MOSFET-style knee
  5 -> 0   -- CENTAUR  : smooth (clean-blend voiced)
  _ -> 0

-- | Klon / CENTAUR clean-blend weight (realism item 5a). The real Klon mixes
-- an unclipped clean path with a germanium hard-clipped path; its
-- "transparency" is the parallel clean signal, and turning GAIN up raises the
-- clipped proportion. `blend` is the clipped-path weight (0..255), rising with
-- DRIVE; the clean weight is `255 - blend`. Floor ~64 so even DRIVE=0 has a
-- little grit; capped below 255 (drive*3>>2 maxes at 255 only at drive=255,
-- and the +64 floor with the Unsigned 8 wrap is avoided by the cap below) so a
-- slice of clean always remains. Only model 5 uses this.
odCleanBlend :: Unsigned 8 -> Unsigned 8
odCleanBlend drive = 64 + resize (min 191 (resize drive * 3 `shiftR` 2) :: Unsigned 9)

-- True when this Overdrive model uses the parallel clean-blend (Klon only).
odUsesCleanBlend :: Unsigned 3 -> Bool
odUsesCleanBlend m = m == 5

-- Per-model asymmetric soft clip. The knee constants (odKneeP/odKneeN) set
-- where it engages; odClipHardness now also sets the compression slope per
-- model. A 4:1 result mux of fixed-shift siblings -- no barrel shifter, no
-- new DSP. Bit-exact bypass preserved (the `on` guard is unchanged).
--
-- Item 5a: for the Klon model (5) we stash the *pre-clip clean* sample into
-- fAcc3L so the level stage can blend it back in. fAcc3L is unused by the
-- Overdrive tone stages (they write fAccL / fAcc2L), so it survives untouched
-- through toneMul -> toneBlend -> level. For every other model fAcc3L stays 0
-- and the level stage ignores it, so their output is byte-identical.
overdriveDriveClipFrame :: Frame -> Frame
overdriveDriveClipFrame f =
  setMonoSample (if on then clipped else monoSample f)
    f{fAcc3L = if on && odUsesCleanBlend model then resize x else 0, fAcc3R = 0}
 where
  on = flag1 (fGate f)
  model = overdriveModel (fOd f)
  kneeP = odKneeP model
  kneeN = odKneeN model
  x = monoWet f
  clipped = case odClipHardness model of
    0 -> asymSoftClipSoft kneeP kneeN x
    1 -> asymSoftClip     kneeP kneeN x
    2 -> asymSoftClipMed  kneeP kneeN x
    _ -> asymSoftClipHard kneeP kneeN x

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

-- Item 5a: for the Klon model the level input is a blend of the processed
-- (clipped + tone) wet and the stashed pre-clip clean (fAcc3L). A single
-- weighted sum reuses the existing mulU8 path; for every other model
-- `wetForLevel = monoWet f` exactly as before, so they are byte-identical.
overdriveLevelFrame :: Frame -> Frame
overdriveLevelFrame f =
  setMonoSample (if on then out else monoSample f) f
 where
  on = flag1 (fGate f)
  level = ctrlB (fOd f)
  model = overdriveModel (fOd f)
  drive = ctrlC (fOd f)
  blend = odCleanBlend drive
  cleanWeight = 255 - blend
  clean = resize (fAcc3L f) :: Sample
  blendedWet = satShift8 (mulU8 (monoWet f) blend + mulU8 clean cleanWeight)
  wetForLevel = if odUsesCleanBlend model then blendedWet else monoWet f
  out = softClipK safetyKnee (satShift7 (mulU8 wetForLevel level))
  safetyKnee = odSafetyKnee model
