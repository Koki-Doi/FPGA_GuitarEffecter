{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Control where

import Clash.Prelude

import AudioLab.Types

ctrlA :: Ctrl -> Unsigned 8
ctrlA c = unpack (slice d7 d0 c)

ctrlB :: Ctrl -> Unsigned 8
ctrlB c = unpack (slice d15 d8 c)

ctrlC :: Ctrl -> Unsigned 8
ctrlC c = unpack (slice d23 d16 c)

ctrlD :: Ctrl -> Unsigned 8
ctrlD c = unpack (slice d31 d24 c)

flag0, flag1, flag2, flag3, flag4, flag5, flag6, flag7 :: Ctrl -> Bool
flag0 c = slice d0 d0 c == (1 :: BitVector 1)
flag1 c = slice d1 d1 c == (1 :: BitVector 1)
flag2 c = slice d2 d2 c == (1 :: BitVector 1)
flag3 c = slice d3 d3 c == (1 :: BitVector 1)
flag4 c = slice d4 d4 c == (1 :: BitVector 1)
flag5 c = slice d5 d5 c == (1 :: BitVector 1)
flag6 c = slice d6 d6 c == (1 :: BitVector 1)
flag7 c = slice d7 d7 c == (1 :: BitVector 1)
-- ---- Distortion-section field accessors ------------------------------

-- | Bias parameter lives in gate_control bits[23:16] (ctrlC). Centred
-- at 128: 0..127 shift negative, 129..255 shift positive. Reserved for
-- bias-using pedals; not consumed by the active stages of this build.
distBias :: Ctrl -> Unsigned 8
distBias = ctrlC

-- | Wet/dry mix lives in gate_control bits[31:24] (ctrlD). 255 = fully
-- wet, 0 = fully dry. Reserved for pedals that expose a wet/dry blend;
-- not consumed by the active stages of this build.
distMix :: Ctrl -> Unsigned 8
distMix = ctrlD

-- | Tight (low-cut amount) lives in overdrive_control bits[31:24]
-- (ctrlD). Higher values raise the input HPF corner, tightening the
-- low end ahead of clip-style pedals.
distTight :: Ctrl -> Unsigned 8
distTight = ctrlD

-- | Distortion-section pedal enable mask lives in
-- distortion_control bits[31:24] (ctrlD).
--
--   bit 0 : clean_boost
--   bit 1 : tube_screamer
--   bit 2 : rat_style    (mapped onto the existing RAT stage; this bit
--                         is recorded for completeness but the audio
--                         path is gated by gate_control bit 4 instead).
--   bit 3 : ds1_style    (BOSS DS-1 style; small dedicated stage)
--   bit 4 : big_muff     (Big Muff Pi style; small dedicated stage)
--   bit 5 : fuzz_face    (Fuzz Face style; small dedicated stage)
--   bit 6 : metal
--   bit 7 : reserved
distPedalMask :: Ctrl -> Unsigned 8
distPedalMask = ctrlD

-- | Distortion section master is the existing flag2 of gate_control,
-- shared with the legacy distortion stage so that the pre-existing
-- API (distortion_on=True) keeps working.
distMasterOn :: Frame -> Bool
distMasterOn f = flag2 (fGate f)

-- | Cheap "any pedal-mask bit set" — exactly one OR-reduction tree.
-- Used to gate the legacy distortion off when any new pedal is in
-- use, so that exclusive=True at the Python level stays exclusive.
anyDistPedalOn :: Frame -> Bool
anyDistPedalOn f = distPedalMask (fDist f) /= 0

cleanBoostOn :: Frame -> Bool
cleanBoostOn f = distMasterOn f && testBit (distPedalMask (fDist f)) 0

tubeScreamerOn :: Frame -> Bool
tubeScreamerOn f = distMasterOn f && testBit (distPedalMask (fDist f)) 1

metalDistortionOn :: Frame -> Bool
metalDistortionOn f = distMasterOn f && testBit (distPedalMask (fDist f)) 6

ds1On :: Frame -> Bool
ds1On f = distMasterOn f && testBit (distPedalMask (fDist f)) 3

bigMuffOn :: Frame -> Bool
bigMuffOn f = distMasterOn f && testBit (distPedalMask (fDist f)) 4

fuzzFaceOn :: Frame -> Bool
fuzzFaceOn f = distMasterOn f && testBit (distPedalMask (fDist f)) 5
