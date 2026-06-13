{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Amp.Models where

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
  0 -> 18    -- JC-120        : high-headroom solid-state clean
  1 -> 78    -- Twin Reverb   : glassy tube clean
  2 -> 166   -- AC30          : earlier chime breakup
  3 -> 208   -- Rockerverb    : thick dark saturation
  4 -> 220   -- JCM800        : classic rock cascaded drive
  5 -> 246   -- TriAmp Mk3    : modern high-gain peak
  _ -> 18    -- 6/7 reserved -> safe (JC-120)

-- | Per-model post-clip pre-LPF darken (Clean-mode baseline). Larger =
-- darker / less fizz. Indexed by ``ampModelIdxF`` directly.
-- 96 kHz: the ampPreLowpass base/darken tables are recomputed (bilinear) so the
-- post-clip LPF corner Hz per model is unchanged when fs doubles. baseAlpha is
-- now 80+(char>>2) (was 128+...); the per-model darken values absorb the
-- difference between that base and each model's bilinear-target alpha.
ampModelDarken :: Unsigned 3 -> Unsigned 8
ampModelDarken idx = case idx of
  0 ->  6    -- JC-120: bright SS feel (48k: 0)
  1 -> 12    -- Twin: bright but slightly rounded (48k: 3)
  2 -> 17    -- AC30: keep upper-mid chime (48k: 3)
  3 -> 31    -- Rockerverb: darker low-mid thickness (48k: 18)
  4 -> 25    -- JCM800: tame fizz, keep upper-mid bark (48k: 10)
  5 -> 39    -- TriAmp Mk3: tight modern fizz control (48k: 26)
  _ ->  6

-- | Per-model extra darken to add only in Drive mode. Stacked on top of
-- ``ampModelDarken`` so each model's Drive-mode tone is darker than
-- its own Clean-mode tone (otherwise harder clipping just brightens).
-- D69: Drive-mode-only retune. Keep Clean mode unchanged, but absorb
-- the extra harmonics from the stronger Drive-mode knee deltas.
-- 96 kHz: drive-mode extra darken halved (bilinear) per model (48k values noted).
ampPreLpfDriveDarken :: Unsigned 3 -> Unsigned 8
ampPreLpfDriveDarken idx = case idx of
  0 ->  4    -- JC-120: light fizz guard (48k: 6)
  1 ->  6    -- Twin: glassy tube breakup (48k: 8)
  2 -> 10    -- AC30: jangly crunch (48k: 12)
  3 -> 16    -- Rockerverb: thick saturation without excess fizz (48k: 20)
  4 -> 16    -- JCM800: classic-rock drive, controlled top (48k: 20)
  5 -> 23    -- TriAmp Mk3: modern HG, kill fizz (48k: 30)
  _ ->  4

-- | Per-model second-stage gain bonus in Drive mode.
-- D69: raised only in Drive mode so the second clipper gets a real
-- saturation push instead of a master-volume lift. Stays a simple
-- per-model adder (no DSP cost).
ampSecondStageDriveBonus :: Unsigned 3 -> Unsigned 9
ampSecondStageDriveBonus idx = case idx of
  0 -> 22    -- JC-120: hard-edged light drive
  1 -> 30    -- Twin: breakup / light OD
  2 -> 42    -- AC30: clear crunch
  3 -> 62    -- Rockerverb: thick push
  4 -> 74    -- JCM800: classic-rock cascaded crunch
  5 -> 88    -- TriAmp Mk3: strongest modern HG sustain
  _ -> 22

-- | Per-model positive-side asym-clip knee delta in Drive mode.
-- Signed 25 fits the existing arithmetic in ``ampAsymClip``.
--
-- D69 keeps the D58.2 **per-model fixed scalar** shape (no runtime ch
-- dependency), but raises the values to approximate the requested
-- Drive-mode factors evaluated against each model's current
-- ``ampCharForModel`` value. The previous D58 attempt at proportional
-- ``ch * factor`` deltas added four new multiplier
-- instantiations (DSP48E1 count 83 -> 87), and the resulting Vivado
-- P&R shift introduced an audible high-frequency saturation noise on
-- the ADC -> DAC bypass path (Amp OFF + safe bypass still glitched
-- under the D58 bit, even though the affected stage was nominally
-- dead code). The fixed-scalar form lands at the same DSP count as
-- D55/D68 (83), while still giving a stronger Drive-mode knee shrink.
ampDrivePosDelta :: Unsigned 3 -> Signed 25
ampDrivePosDelta idx = case idx of
  0 ->  16_200   -- JC-120       : 18 * 900
  1 ->  85_800   -- Twin Reverb  : 78 * 1100
  2 -> 232_400   -- AC30         : 166 * 1400
  3 -> 374_400   -- Rockerverb   : 208 * 1800
  4 -> 462_000   -- JCM800       : 220 * 2100
  5 -> 615_000   -- TriAmp Mk3   : 246 * 2500
  _ ->  16_200

-- | Per-model negative-side asym-clip knee delta in Drive mode.
-- Slightly smaller than ``ampDrivePosDelta`` so the asymmetric
-- character (negKnee was already 550 k below posKnee in D55) is
-- preserved.
ampDriveNegDelta :: Unsigned 3 -> Signed 25
ampDriveNegDelta idx = case idx of
  0 ->  13_500   -- JC-120       : 18 * 750
  1 ->  74_100   -- Twin Reverb  : 78 * 950
  2 -> 199_200   -- AC30         : 166 * 1200
  3 -> 322_400   -- Rockerverb   : 208 * 1550
  4 -> 407_000   -- JCM800       : 220 * 1850
  5 -> 541_200   -- TriAmp Mk3   : 246 * 2200
  _ ->  13_500

