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
-- | Per-model amp voicing consolidated into ONE record (refactor G, 2026-06-17):
-- a model's voicing scalars live in ONE AmpModel literal per model instead of
-- six parallel `case idx of` tables that every realism pass had to edit in
-- lockstep. The original per-field functions are kept below as thin projections
-- so every consumer (Clip.hs / Tone.hs) is byte-for-byte unchanged; the values
-- are identical (verified by the all-6-amp-model golden regression). Reserved
-- 6/7 -> JC-120. NOTE `ampPowerKnee` stays a separate function -- it is
-- base-parameterised (returns the caller's `base` for the high-gain models), not
-- a pure per-model scalar.
data AmpModel = AmpModel
  { amChar          :: Unsigned 8   -- ampCharForModel
  , amDarken        :: Unsigned 8   -- ampModelDarken (Clean pre-LPF)
  , amDriveDarken   :: Unsigned 8   -- ampPreLpfDriveDarken (Drive extra)
  , amSecondBonus   :: Unsigned 9   -- ampSecondStageDriveBonus
  , amDrivePos      :: Signed 25    -- ampDrivePosDelta
  , amDriveNeg      :: Signed 25    -- ampDriveNegDelta
  }

ampModel :: Unsigned 3 -> AmpModel
ampModel idx = case idx of
  --              char darken driveDk 2ndBonus  drivePos  driveNeg
  -- 2026-06-17 "clean vs drive 差を明確に": Drive-mode saturation pushed up on
  -- every tube model (the asym-clip knee deltas shrink the Drive knee further,
  -- and the second-stage bonus drives the second clipper harder + a touch
  -- louder). Combined with the larger Clean-mode headroom (ampCleanKneeBonus /
  -- ampCleanPowerBonus, Clean only) this opens a clear Clean->Drive step:
  -- Clean stays clean, Drive is obviously driven. CDC pair had +6.1 ns margin
  -- so the bigger deltas stay placement-safe. JC (idx 0) does not use these
  -- (its SS knee is in Clip.hs); its values are inert.
  0 -> AmpModel    18    6      4       22        16_200    13_500   -- JC-120 (asym-clip unused)
  1 -> AmpModel    78   12      6       46       120_000   104_000   -- Twin Reverb
  2 -> AmpModel   166    6     10       70       330_000   285_000   -- AC30
  3 -> AmpModel   208   31     16      112       520_000   450_000   -- Rockerverb
  4 -> AmpModel   220   16     16      112       640_000   570_000   -- JCM800
  5 -> AmpModel   246   39     23      150       850_000   760_000   -- TriAmp Mk3
  _ -> AmpModel    18    6      4       22        16_200    13_500   -- 6/7 -> JC-120

-- Thin projections (byte-identical to the old per-model tables). The detailed
-- per-value rationale stays in the comment blocks above each projection below.
ampCharForModel :: Unsigned 3 -> Unsigned 8
ampCharForModel = amChar . ampModel

-- | Per-model power-stage soft-clip ceiling ("クリーン用パワーヘッドルーム",
-- 2026-06-17). The power / resonance / master softClipK stages model power-amp
-- compression at a shared ~3.3-3.4M knee, which makes even the CLEAN amps break
-- up at a hot input (the ear-bench "クリーンでも歪む"). A real clean amp has huge
-- headroom: JC-120 is solid-state (no power-amp sag), Twin blackface is a big
-- clean platform. Raise their power knee so they stay clean to a much hotter
-- signal; the high-gain models KEEP their `base` knee (their power amp SHOULD
-- compress/sag). `base` is each stage's existing gain-model value so those amps
-- stay byte-identical. Constant/mux only (softClipK = compare+shift, no new DSP).
ampPowerKnee :: Sample -> Unsigned 3 -> Sample
ampPowerKnee base idx = case idx of
  0 -> 6_800_000   -- JC-120 : SS, huge clean headroom (waveshape clean-knee is 7.5M)
  1 -> 4_600_000   -- Twin   : blackface clean platform, more headroom
  2 -> base + 300_000 -- AC30 : still early, but enough headroom for Clean-mode target
  _ -> base        -- Rockerverb/JCM800/TriAmp : keep power-amp compression

-- | Per-model CLEAN-mode (drive_mode 0) extra waveshaper-knee headroom
-- ("クリーンチャンネルでも歪みすぎ" fix, 2026-06-17). Before this, only JC-120
-- (idx 0) had real clean headroom (its own 7.5M symmetric knee); every other
-- model ran ``ampAsymClip`` at its full per-model character intensity even in
-- Clean mode, so "Clean" was just "Drive minus the drive-knee delta" and broke
-- up at a realistic guitar level (Twin 17% / AC30 29% / Marshall 32-36% THD at
-- 0.20 FS in the offline sweep). This bonus is ADDED to both clip knees ONLY
-- when drive_mode is 0 (Clean); Drive mode passes 0 here, so the Drive voicing
-- and every drive-knee delta stay byte-for-byte unchanged. Per the user's
-- "preserve model character" choice the values are graded: Twin gets the most
-- (blackface clean platform -> nearly hi-fi clean), AC30 keeps some class-A
-- early breakup (small bonus), and the high-gain Marshall/Rockerverb/TriAmp
-- clean channels become usable-clean but still break up when pushed.
-- Signed 25 fits the existing ``ampAsymClip`` knee arithmetic; constant/mux
-- only (the knee is a compare+shift, no new multiply / DSP).
-- 2026-06-17 "clean vs drive 差を明確に": clean-mode headroom raised further so
-- the Clean channel is genuinely clean at a playing level on every model (the
-- gain models were still ~11-15% THD at 0.15 FS), which -- together with the
-- hotter Drive voicing -- makes the Clean/Drive step obvious. AC30 keeps a
-- little class-A early breakup (smaller bonus) per the "preserve character"
-- choice.
ampCleanKneeBonus :: Unsigned 3 -> Signed 25
ampCleanKneeBonus idx = case idx of
  0 -> 0           -- JC-120 : unused (model 0 takes the dedicated SS clean path)
  1 -> 2_300_000   -- Twin   : blackface clean platform, near hi-fi clean
  2 -> 1_400_000   -- AC30   : class-A, keep a little early chime breakup
  3 -> 2_800_000   -- Rockerverb : clean channel genuinely clean (highest-gain pre)
  4 -> 2_300_000   -- JCM800 : clean channel genuinely clean
  5 -> 2_000_000   -- TriAmp : clean channel genuinely clean
  _ -> 0           -- 6/7 -> JC-120 fallback

-- | Per-model CLEAN-mode (drive_mode 0) extra POWER / RESONANCE / MASTER
-- soft-clip headroom (same "クリーンチャンネルでも歪みすぎ" fix, 2026-06-17). The
-- waveshaper clean bonus (``ampCleanKneeBonus``) only un-clips the pre-tone-stack
-- shaper; for AC30 and the high-gain Marshall/Rockerverb/TriAmp the CLEAN signal
-- is then re-clipped by the shared power / resonance-mix / master ``softClipK``
-- ceilings (~3.3-3.4M), which is the real clean-breakup limiter at a realistic
-- playing level once the shaper is clean. This bonus is ADDED to those ceilings
-- ONLY in Clean mode (Drive passes 0), so the Drive-mode power-amp
-- compression / sag is byte-for-byte unchanged. JC-120 / Twin already have a
-- high clean power knee from ``ampPowerKnee`` and stay clean, so they take 0 here.
-- Graded to the user's "preserve model character" choice: AC30 keeps some class-A
-- early breakup, the high-gain trio become usable-clean but compress when pushed.
-- 2026-06-18 "tube 系のサステーンが聞き取りづらい": the power / resonance-mix /
-- master softClipK is the power-amp compression that SUSTAINS notes (the loud
-- attack soft-clips, the decaying tail recovers -> the tail blooms up relative
-- to the attack = audible sustain). The D136/D137 clean-power bonus had pushed
-- these knees so high that the tube amps stopped compressing in Clean mode, so
-- the clean sustain dropped to ~1.35-1.5x. Pull the bonus back ~half: the power
-- softClipK is a SOFT knee so this restores sustain/bloom with only a mild THD
-- rise (still clean -- the clean TONE is held by the waveshaper clean bonus,
-- ampCleanKneeBonus, which is unchanged). JC (SS) / Twin (boosted into its 4.6M
-- knee) stay at 0.
ampCleanPowerBonus :: Unsigned 3 -> Sample
ampCleanPowerBonus idx = case idx of
  0 -> 0           -- JC-120 : SS clean knee handled in Clip.hs
  1 -> 0           -- Twin   : 4.6M power knee + the +3.5 dB boost drives it for sustain
  2 -> 800_000     -- AC30   : more class-A power compression / sustain
  3 -> 2_200_000   -- Rockerverb : restore power-amp sustain, still clean tone
  4 -> 1_800_000   -- JCM800 : restore power-amp sustain, still clean tone
  5 -> 1_600_000   -- TriAmp : restore power-amp sustain, still clean tone
  _ -> 0           -- 6/7 -> JC-120 fallback

-- | Per-model post-clip pre-LPF darken (Clean-mode baseline). Larger =
-- darker / less fizz. Indexed by ``ampModelIdxF`` directly.
-- 96 kHz: the ampPreLowpass base/darken tables are recomputed (bilinear) so the
-- post-clip LPF corner Hz per model is unchanged when fs doubles. baseAlpha is
-- now 80+(char>>2) (was 128+...); the per-model darken values absorb the
-- difference between that base and each model's bilinear-target alpha.
ampModelDarken :: Unsigned 3 -> Unsigned 8
ampModelDarken = amDarken . ampModel

-- | Per-model extra darken to add only in Drive mode. Stacked on top of
-- ``ampModelDarken`` so each model's Drive-mode tone is darker than
-- its own Clean-mode tone (otherwise harder clipping just brightens).
-- D69: Drive-mode-only retune. Keep Clean mode unchanged, but absorb
-- the extra harmonics from the stronger Drive-mode knee deltas.
-- 96 kHz: drive-mode extra darken halved (bilinear) per model (48k values noted).
ampPreLpfDriveDarken :: Unsigned 3 -> Unsigned 8
ampPreLpfDriveDarken = amDriveDarken . ampModel

-- | Per-model second-stage gain bonus in Drive mode.
-- D69: raised only in Drive mode so the second clipper gets a real
-- saturation push instead of a master-volume lift. Stays a simple
-- per-model adder (no DSP cost).
-- Drive vs Clean separation pass (moderate / placement-safe re-tune). The drive
-- increase now rides ONLY on this second-stage gain bonus -- the knee-delta and
-- pre-LPF-darken tables were reverted to D127, because the aggressive version
-- pushed the CDC pair to the tightest slack in project history and the safe-
-- bypass knife-edge re-appeared (bypass hiss). This is a small Unsigned 9 field
-- (low placement risk) raised in Drive mode so Drive is clearly hotter than
-- Clean and the high-gain pair (Rockerverb idx 3, TriAmp idx 5) saturates most.
-- JC-120 (idx 0) is clean SS (asym-clip unused).
ampSecondStageDriveBonus :: Unsigned 3 -> Unsigned 9
ampSecondStageDriveBonus = amSecondBonus . ampModel

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
ampDrivePosDelta = amDrivePos . ampModel

-- | Per-model negative-side asym-clip knee delta in Drive mode.
-- Slightly smaller than ``ampDrivePosDelta`` so the asymmetric
-- character (negKnee was already 550 k below posKnee in D55) is
-- preserved.
ampDriveNegDelta :: Unsigned 3 -> Signed 25
ampDriveNegDelta = amDriveNeg . ampModel
