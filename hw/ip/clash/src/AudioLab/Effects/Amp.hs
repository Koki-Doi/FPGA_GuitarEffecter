{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Amp where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

-- ---------------------------------------------------------------------
-- D55 amp_tone.ctrlD layout:
--   bit  7   : ampDriveMode (0 = Clean, 1 = Drive)
--   bits 6..3: reserved (0)
--   bits 2..0: ampModelIdx (3-bit, 0..5 valid)
--                0 = JC-120
--                1 = Twin Reverb
--                2 = AC30
--                3 = Rockerverb
--                4 = JCM800
--                5 = TriAmp Mk3
--                6..7 reserved -> fall back to 0 (JC-120) for safety
--
-- Per-model voicing is driven by independent tables instead of a single
-- "character byte". See ``ampCharForModel`` (legacy character band
-- centre for the formulas that still consume an Unsigned 8 intensity),
-- ``ampModelDarken`` (post-clip pre-LPF darken), ``ampTrebleTrim``
-- (treble byte trim), ``ampPresenceShift`` (presence-trim divisor),
-- ``ampDrivePosDelta`` / ``ampDriveNegDelta`` (extra knee shrink in
-- Drive mode), ``ampPreLpfDriveDarken`` (extra alpha cut in Drive
-- mode) and ``ampSecondStageDriveBonus`` (Drive-mode bonus on the
-- second-stage gain). Coefficients are derived from
-- ``docs/ai_context/AMP_MODEL_RESEARCH_D55.md``.
-- ---------------------------------------------------------------------

-- | 3-bit amp model index decoded from ``amp_tone.ctrlD[2:0]``.
ampModelIdxF :: Frame -> Unsigned 3
ampModelIdxF f = unpack (slice d26 d24 (fAmpTone f))

ampDriveModeF :: Frame -> Bool
ampDriveModeF f = slice d31 d31 (fAmpTone f) == (1 :: BitVector 1)

-- | Centre character byte per amp model. The values come from the D52
-- band centres for the four pre-D55 models; the two new high-gain
-- voicings get higher intensities so the existing knee / alpha /
-- second-stage formulas (which take this byte as an 8-bit intensity)
-- give a stronger response on JCM800 / TriAmp Mk3 even before the
-- Drive-mode branch fires. Reserved indices (6, 7) fall back to the
-- JC-120 value so an unexpected write does not run clip_count away.
ampCharForModel :: Unsigned 3 -> Unsigned 8
ampCharForModel idx = case idx of
  0 -> 26    -- JC-120        : tightest clean
  1 -> 89    -- Twin Reverb   : big clean
  2 -> 153   -- AC30          : edge-of-breakup chime
  3 -> 200   -- Rockerverb    : thick saturated
  4 -> 220   -- JCM800        : classic rock cascaded drive
  5 -> 240   -- TriAmp Mk3    : modern high-gain peak
  _ -> 26    -- 6/7 reserved -> safe (JC-120)

-- | Per-model post-clip pre-LPF darken (Clean-mode baseline). Larger =
-- darker / less fizz. Indexed by ``ampModelIdxF`` directly.
ampModelDarken :: Unsigned 3 -> Unsigned 8
ampModelDarken idx = case idx of
  0 ->  0    -- JC-120: bright SS feel, no darken
  1 ->  2    -- Twin: bright but slightly rounded
  2 ->  4    -- AC30: keep upper-mid chime
  3 -> 12    -- Rockerverb: round the high, mid-rich
  4 -> 10    -- JCM800: tame fizz, keep upper-mid bark
  5 -> 28    -- TriAmp Mk3: maximum fizz cut for modern HG
  _ ->  0

-- | Per-model extra darken to add only in Drive mode. Stacked on top of
-- ``ampModelDarken`` so each model's Drive-mode tone is darker than
-- its own Clean-mode tone (otherwise harder clipping just brightens).
-- D58.2 (vs D55): +1..+4 to absorb the extra harmonics from the larger
-- Drive-mode knee deltas without re-introducing D57's pre-clip push.
ampPreLpfDriveDarken :: Unsigned 3 -> Unsigned 8
ampPreLpfDriveDarken idx = case idx of
  0 ->  5    -- JC-120: tiny extra in Drive
  1 ->  7    -- Twin: light breakup
  2 -> 10    -- AC30: jangly crunch
  3 -> 16    -- Rockerverb: thick saturation
  4 -> 16    -- JCM800: classic rock drive
  5 -> 24    -- TriAmp Mk3: modern HG, kill fizz
  _ ->  5

-- | Per-model second-stage gain bonus in Drive mode.
-- D58.2 (vs D55): lifted into 14..56 so each model's second-stage push
-- is audibly stronger than D55's 8..44, but the highest entry sits well
-- below the D57 overshoot. Stays a simple per-model adder (no DSP cost).
ampSecondStageDriveBonus :: Unsigned 3 -> Unsigned 9
ampSecondStageDriveBonus idx = case idx of
  0 -> 14    -- JC-120: light bonus, SS feel
  1 -> 18    -- Twin: light push
  2 -> 28    -- AC30: harmonic bloom
  3 -> 42    -- Rockerverb: thick push
  4 -> 48    -- JCM800: cascaded gain
  5 -> 56    -- TriAmp Mk3: modern HG sustain
  _ -> 14

-- | Per-model positive-side asym-clip knee delta in Drive mode.
-- Signed 25 fits the existing arithmetic in ``ampAsymClip``.
--
-- D58.2 uses **per-model fixed scalars** (no ch dependency) sized to
-- approximate D58's first-stage `ch * factor` evaluated at each model's
-- own ``ampCharForModel`` peak value. The previous D58 attempt at
-- proportional ``ch * factor`` deltas added four new multiplier
-- instantiations (DSP48E1 count 83 -> 87), and the resulting Vivado
-- P&R shift introduced an audible high-frequency saturation noise on
-- the ADC -> DAC bypass path (Amp OFF + safe bypass still glitched
-- under the D58 bit, even though the affected stage was nominally
-- dead code). The fixed-scalar form lands at the same DSP count as
-- D55 (83) so the bypass path P&R stays the same, while still giving
-- a Drive-mode knee shrink comparable to D58 at the first stage. The
-- second stage receives the same fixed value -- it ends up slightly
-- tighter than D58 on the high-gain voicings (D58 also halved its ch
-- there), but stays well above ``softClipK 3_300_000`` so the safety
-- clip is not over-tripped.
ampDrivePosDelta :: Unsigned 3 -> Signed 25
ampDrivePosDelta idx = case idx of
  0 ->  13_000   -- JC-120
  1 ->  58_000   -- Twin Reverb
  2 -> 130_000   -- AC30
  3 -> 210_000   -- Rockerverb
  4 -> 264_000   -- JCM800
  5 -> 336_000   -- TriAmp Mk3
  _ ->  13_000

-- | Per-model negative-side asym-clip knee delta in Drive mode.
-- Slightly smaller than ``ampDrivePosDelta`` so the asymmetric
-- character (negKnee was already 550 k below posKnee in D55) is
-- preserved.
ampDriveNegDelta :: Unsigned 3 -> Signed 25
ampDriveNegDelta idx = case idx of
  0 ->  11_000   -- JC-120
  1 ->  50_000   -- Twin Reverb
  2 -> 113_000   -- AC30
  3 -> 180_000   -- Rockerverb
  4 -> 231_000   -- JCM800
  5 -> 300_000   -- TriAmp Mk3
  _ ->  11_000

ampHighpassFrame :: Sample -> Sample -> Frame -> Frame
ampHighpassFrame prevIn prevOut f =
  setMonoWet (if on then highpass x prevIn prevOut else x) (setMonoDry x f)
 where
  on = flag6 (fGate f)
  x = monoSample f
  highpass x prevIn prevOut =
    satWide (resize x - resize prevIn + ((resize prevOut :: Wide) * 253 `shiftR` 8))

ampDriveMultiplyFrame :: Frame -> Frame
ampDriveMultiplyFrame f =
  f{fAccL = if on then mulU12 (monoWet f) gain else 0, fAccR = 0}
 where
  on = flag6 (fGate f)
  -- 1.0x to about 19x using Q7-style post shift. The recording-analysis
  -- pass trims the ceiling again so Amp-only and post-pedal use do not
  -- create line-direct fizz before the cabinet stage.
  gain = resize (128 + (resize (ctrlA (fAmp f)) * 9 :: Unsigned 12)) :: Unsigned 12

ampDriveBoostFrame :: Frame -> Frame
ampDriveBoostFrame f =
  setMonoWet (if on then satShift7 (fAccL f) else monoSample f) f
 where
  on = flag6 (fGate f)

-- | Soft asymmetric clip. ``intensity`` keeps the legacy character-byte
-- scale (per-model centre via ``ampCharForModel``) so each model's
-- Clean-mode knee character is preserved. When ``drive`` is True the
-- knees shrink by an additional per-model delta (``ampDrivePosDelta``
-- / ``ampDriveNegDelta``) so the same input clips earlier AND harder
-- -- a real DSP branch, not a volume difference. The legacy
-- ``intensity = 0`` case (used by the legacy ``amp_character``
-- fallback path with a low percent value) keeps the D52 knees
-- unchanged regardless of drive_mode so older notebooks see no
-- behavioural change.
ampAsymClip :: Unsigned 3 -> Unsigned 8 -> Bool -> Sample -> Sample
ampAsymClip modelIdx intensity drive x
  | x > posKnee =
      satWide (resize (resize posKnee + (((resize x :: Signed 25) - resize posKnee) `shiftR` posShift) :: Signed 25))
  | x < negate negKnee =
      satWide (resize (resize (negate negKnee) + (((resize x :: Signed 25) + resize negKnee) `shiftR` negShift) :: Signed 25))
  | otherwise = x
 where
  ch :: Signed 25
  ch = resize (asSigned9 intensity)
  -- Extra knee shrink in Drive mode, per-model (linear in the per-model
  -- delta so high-gain models cut deeper).
  posDriveDelta :: Signed 25
  posDriveDelta = if drive then ampDrivePosDelta modelIdx else 0
  negDriveDelta :: Signed 25
  negDriveDelta = if drive then ampDriveNegDelta modelIdx else 0
  posKnee = resize (4_900_000 - ch * 7_000 - posDriveDelta) :: Sample
  negKnee = resize (4_350_000 - ch * 6_200 - negDriveDelta) :: Sample
  posShift = 2 :: Int
  negShift = if drive then 2 else 3

ampWaveshapeFrame :: Frame -> Frame
ampWaveshapeFrame f =
  setMonoWet (if on then ampAsymClip idx intensity drive (monoWet f) else monoSample f) f
 where
  on = flag6 (fGate f)
  idx = ampModelIdxF f
  drive = ampDriveModeF f
  intensity = ampCharForModel idx

ampPreLowpassFrame :: Sample -> Frame -> Frame
ampPreLowpassFrame prev f =
  setMonoWet (if on then onePoleU8 alpha prev (monoWet f) else monoSample f) f
 where
  on = flag6 (fGate f)
  idx = ampModelIdxF f
  drive = ampDriveModeF f
  charByte = ampCharForModel idx
  -- Base alpha = 128 + (char >> 2) keeps the D52 voicing centres.
  baseAlpha = 128 + (charByte `shiftR` 2)
  -- Per-model post-clip darken (Clean-mode baseline).
  modelDarken = ampModelDarken idx
  -- Per-model Drive-mode extra darken (absorbs fizz from the harder clip).
  driveDarken = if drive then ampPreLpfDriveDarken idx else 0
  alpha = baseAlpha - modelDarken - driveDarken

ampSecondStageMultiplyFrame :: Frame -> Frame
ampSecondStageMultiplyFrame f =
  f{fAccL = if on then mulU9 (monoWet f) gain else 0, fAccR = 0}
 where
  on = flag6 (fGate f)
  idx = ampModelIdxF f
  drive = ampDriveModeF f
  charByte = ampCharForModel idx
  -- Per-model Drive-mode bonus on the second-stage gain. Combined with
  -- the harder asym-clip below it pushes more signal into the clipper
  -- instead of just raising output level.
  driveBonus :: Unsigned 9
  driveBonus = if drive then ampSecondStageDriveBonus idx else 0
  gain :: Unsigned 9
  gain = 112
       + resize (ctrlA (fAmp f) `shiftR` 3)
       + resize (charByte `shiftR` 2)
       + driveBonus

ampSecondStageFrame :: Frame -> Frame
ampSecondStageFrame f =
  setMonoWet (if on then ampAsymClip idx intensity drive (satShift7 (fAccL f)) else monoSample f) f
 where
  on = flag6 (fGate f)
  idx = ampModelIdxF f
  drive = ampDriveModeF f
  -- Softer than the first clip stage; keeps low-gain response
  -- touch-sensitive by halving the per-model intensity.
  intensity = ampCharForModel idx `shiftR` 1

ampToneFilterFrame :: Sample -> Sample -> Frame -> Frame
ampToneFilterFrame prevLow prevHighLp f =
  f
    { fEqLowL = low
    , fEqLowR = low
    , fEqHighLpL = highLp
    , fEqHighLpR = highLp
    }
 where
  x = monoWet f
  low = prevLow + resize (((resize x - resize prevLow) :: Signed 25) `shiftR` 5)
  highLp = prevHighLp + resize (((resize x - resize prevHighLp) :: Signed 25) `shiftR` 2)

ampToneBandFrame :: Frame -> Frame
ampToneBandFrame f =
  f
    { fEqMidL = mid
    , fEqMidR = mid
    , fEqHighL = high
    , fEqHighR = high
    }
 where
  mid = satWide (resize (monoEqHighLp f) - resize (monoEqLow f))
  high = satWide (resize (monoWet f) - resize (monoEqHighLp f))

ampToneGain :: Unsigned 8 -> Unsigned 8
ampToneGain x = 64 + (x `shiftR` 1)

ampTrebleGain :: Unsigned 3 -> Unsigned 8 -> Unsigned 8
ampTrebleGain idx x = base - modelTrim
 where
  -- Keep the 2..4 kHz bite from the tone stack, but avoid restoring as
  -- much raw 8..16 kHz fizz when TREBLE is near 100.
  base = 64 + ((x - (x `shiftR` 3) - (x `shiftR` 4)) `shiftR` 1)
  modelTrim = case idx of
    0 ->  0 :: Unsigned 8   -- JC-120  : full bright
    1 ->  1                 -- Twin    : barely trimmed
    2 ->  3                 -- AC30    : keep chime
    3 ->  6                 -- Rockerv : rounded
    4 ->  8                 -- JCM800  : bark, slight trim
    5 -> 12                 -- TriAmp  : controlled high
    _ ->  0

ampToneProductsFrame :: Frame -> Frame
ampToneProductsFrame f =
  f
    { fAccL = if on then mulU8 (monoEqLow f) (ampToneGain (ctrlA (fAmpTone f))) else 0
    , fAccR = 0
    , fAcc2L = if on then mulU8 (monoEqMid f) (ampToneGain (ctrlB (fAmpTone f))) else 0
    , fAcc2R = 0
    , fAcc3L = if on then mulU8 (monoEqHigh f) (ampTrebleGain idx (ctrlC (fAmpTone f))) else 0
    , fAcc3R = 0
    }
 where
  on = flag6 (fGate f)
  idx = ampModelIdxF f

ampToneMixFrame :: Frame -> Frame
ampToneMixFrame f =
  setMonoWet (if on then satShift7 acc else monoSample f) f
 where
  on = flag6 (fGate f)
  acc = fAccL f + fAcc2L f + fAcc3L f

ampPowerFrame :: Frame -> Frame
ampPowerFrame f =
  setMonoWet (if on then softClipK 3_400_000 (monoWet f) else monoSample f) f
 where
  on = flag6 (fGate f)

ampResPresenceFilterFrame :: Sample -> Sample -> Frame -> Frame
ampResPresenceFilterFrame prevRes prevPresence f =
  f
    { fEqLowL = res
    , fEqLowR = res
    , fEqHighLpL = presenceLp
    , fEqHighLpR = presenceLp
    }
 where
  x = monoWet f
  -- Slow lowpass approximates resonance around the speaker low-end region.
  res = prevRes + resize (((resize x - resize prevRes) :: Signed 25) `shiftR` 8)
  presenceLp = prevPresence + resize (((resize x - resize prevPresence) :: Signed 25) `shiftR` 3)

ampResPresenceMixFrame :: Frame -> Frame
ampResPresenceMixFrame f =
  setMonoWet (if on then softClipK 3_400_000 wet else monoSample f) f
 where
  on = flag6 (fGate f)
  wet = satWide (fAccL f + satShift10Wide (fAcc2L f) + satShift9Wide (fAcc3L f))

ampResPresenceProductsFrame :: Frame -> Frame
ampResPresenceProductsFrame f =
  f
    { fEqHighL = high
    , fEqHighR = high
    , fAccL = if on then resize (monoWet f) else 0
    , fAccR = 0
    , fAcc2L = if on then mulU8 (monoEqLow f) resonance else 0
    , fAcc2R = 0
    , fAcc3L = if on then mulU8 high presence else 0
    , fAcc3R = 0
    }
 where
  on = flag6 (fGate f)
  resonance = ctrlD (fAmp f) - (ctrlD (fAmp f) `shiftR` 2)
  presence = basePresence - presenceTrim
  presenceByte = ctrlC (fAmp f)
  idx = ampModelIdxF f
  basePresence = presenceByte - (presenceByte `shiftR` 2) - (presenceByte `shiftR` 3)
  -- Per-model presence trim. Larger right-shift = smaller subtraction =
  -- brighter presence. JC-120 keeps the full presence; TriAmp Mk3
  -- shaves the most.
  presenceTrim = case idx of
    0 -> 0 :: Unsigned 8         -- JC-120  : full
    1 -> presenceByte `shiftR` 6 -- Twin    : tiny shave
    2 -> presenceByte `shiftR` 5 -- AC30    : modest
    3 -> presenceByte `shiftR` 4 -- Rockerv : thicker
    4 -> presenceByte `shiftR` 4 -- JCM800  : tight low + strong presence trim
    5 -> presenceByte `shiftR` 3 -- TriAmp  : maximum trim, modern voicing
    _ -> 0
  high = satWide (resize (monoWet f) - resize (monoEqHighLp f))

satShift9Wide :: Wide -> Wide
satShift9Wide = resize . satShift9

satShift10Wide :: Wide -> Wide
satShift10Wide = resize . satShift10

ampMasterFrame :: Frame -> Frame
ampMasterFrame f =
  setMonoSample (if on then out else monoSample f) f
 where
  on = flag6 (fGate f)
  level = ctrlB (fAmp f)
  out = softClipK 3_300_000 (satShift7 (mulU8 (monoWet f) level))
