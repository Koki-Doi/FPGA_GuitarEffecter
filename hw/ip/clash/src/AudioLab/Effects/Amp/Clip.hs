{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Amp.Clip where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types
import AudioLab.Effects.Amp.Models

ampHighpassFrame :: Sample -> Sample -> Frame -> Frame
ampHighpassFrame prevIn prevOut f =
  setMonoWet (if on then highpass x prevIn prevOut else x) (setMonoDry x f)
 where
  on = flag6 (fGate f)
  x = monoSample f
  -- Low-end restoration ("低音不足" pass). The old `onePoleHighpass 509 9` was a
  -- DEAD pole: Haskell parses `prevOut * 509 >> 9` as `prevOut * (509 >> 9)` =
  -- `prevOut * 0`, so the stage was a bare first difference `x - prevIn` -- a
  -- +6 dB/oct differentiator that cut the low-E ~-45 dB (rig measured
  -- low_vs_mid -22 dB = far too thin). Make the feedback pole LIVE, but
  -- SHIFT-ONLY (NO multiply): `prevOut - (prevOut>>7) - (prevOut>>9)` =
  -- prevOut * (1 - 1/128 - 1/512) = prevOut * 0.9902 = exactly the coef-507 pole
  -- (507/512), ~150 Hz corner. A multiply here (`prevOut*507`, the D124 RAT
  -- idiom) shifted the island placement and tightened the D109 DSP-out->DAC CDC
  -- pair to +1.079 ns (knife-edge risk); the shift-only form keeps the CDC
  -- margin (no new DSP48). Restores body below ~300 Hz; D100's ~90 Hz was
  -- bench-rejected as too bassy, ~150 Hz is the middle ground.
  highpass x prevIn prevOut =
    satWide (resize x - resize prevIn + (p - (p `shiftR` 7) - (p `shiftR` 9)))
   where
    p = resize prevOut :: Wide

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

-- ---- Anti-alias pre/de-emphasis around the amp clip stages -------------
-- "Digital sound" interim (DIGITAL_SOUND_REDUCTION.md): high-frequency content
-- driven into a static clipper generates harmonics above Nyquist that fold back
-- as inharmonic alias = the metallic / fizzy "digital" edge. The amp waveshaper
-- is on in nearly every patch and is NOT oversampled (unlike Metal/RAT/Big Muff,
-- D88-D90), so it is a broad always-present alias layer.
--
-- Cheap interim until full 4x oversampling lands (needs the 33 MHz headroom
-- phase): attenuate the highs going INTO the first clip (pre-emphasis) and
-- restore them after the second clip (de-emphasis). Fewer high harmonics are
-- generated above Nyquist, so less folds back -- a fraction of the benefit of
-- true oversampling for a fraction of the cost. NOT transparent (it reshapes the
-- clip's harmonic balance) -- a voiced interim; `ampEmphAmount` / `ampEmphShift`
-- are the bench-tunable knobs.
--
-- Shift-only: a one-pole lowpass (`prev + (x-prev)>>shift`, the ampToneFilter
-- idiom) gives the HF band `h = x - lp`; pre = x - h>>amount, de = x + h>>amount.
-- NO multiply -> NO new DSP (keeps the island off the timing edge). Gated on
-- amp-on (bit-exact bypass when the amp is off) AND skipped for JC-120 (idx 0)
-- so its D92 clean channel stays exact. The lowpass state is stashed in the
-- reuse-safe fEqLowL field (overwritten by ampToneFilterFrame downstream).
ampEmphShift :: Int
ampEmphShift = 4       -- 96 kHz: +1 (was 3) keeps the ~a-few-kHz corner at 2x fs

ampEmphAmount :: Int
ampEmphAmount = 1      -- cut/restore 1/2^amount of the HF band (half)

ampPreEmphFrame :: Sample -> Frame -> Frame
ampPreEmphFrame prevLp f =
  setMonoWet (if on then xpre else monoWet f) (setMonoEqLow lp f)
 where
  on = flag6 (fGate f) && ampModelIdxF f /= 0
  x = monoWet f
  lp = onePoleShift ampEmphShift prevLp x
  h = satWide (resize x - resize lp :: Wide)
  xpre = satWide (resize x - (resize h `shiftR` ampEmphAmount) :: Wide)

ampDeEmphFrame :: Sample -> Frame -> Frame
ampDeEmphFrame prevLp f =
  setMonoWet (if on then xpost else monoWet f) (setMonoEqLow lp f)
 where
  on = flag6 (fGate f) && ampModelIdxF f /= 0
  x = monoWet f
  lp = onePoleShift ampEmphShift prevLp x
  h = satWide (resize x - resize lp :: Wide)
  xpost = satWide (resize x + (resize h `shiftR` ampEmphAmount) :: Wide)

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
-- ``hyst`` is the per-sample hysteresis bias (realism #10, D95): a fraction of
-- this clip's PREVIOUS output, threaded as a pipeline register. It shifts the
-- knees with signal history so a rising edge clips slightly differently than a
-- falling one -- real tube/diode/magnetic transfer curves are NOT memoryless
-- (the curve traced going up differs from coming down), and that path
-- dependence is part of the "analog thickness" a static waveshaper lacks. When
-- the previous output was high-positive (hyst > 0) the positive knee lowers
-- (the clipper stays engaged -> sticky high) and the negative knee rises
-- (harder to clip negative); symmetric for hyst < 0. Bounded and STABLE: hyst
-- comes from a registered previous output, so there is no combinational loop,
-- and |hyst| stays a small fraction of the knee. ``hyst = 0`` reproduces the
-- pre-D95 memoryless clip exactly (so callers that pass 0 are byte-identical).
ampAsymClip :: Unsigned 3 -> Unsigned 8 -> Bool -> Sample -> Sample -> Sample
ampAsymClip modelIdx intensity drive hyst x
  | x > posKnee =
      satWide (resize (resize posKnee + (((resize x :: Signed 25) - resize posKnee) `shiftR` posShift) :: Signed 25))
  | x < negate negKnee =
      satWide (resize (resize (negate negKnee) + (((resize x :: Signed 25) + resize negKnee) `shiftR` negShift) :: Signed 25))
  | otherwise = x
 where
  ch :: Signed 25
  ch = resize (asSigned9 intensity)
  hystS :: Signed 25
  hystS = resize hyst
  -- Extra knee shrink in Drive mode, per-model (linear in the per-model
  -- delta so high-gain models cut deeper).
  posDriveDelta :: Signed 25
  posDriveDelta = if drive then ampDrivePosDelta modelIdx else 0
  negDriveDelta :: Signed 25
  negDriveDelta = if drive then ampDriveNegDelta modelIdx else 0
  -- Clean-mode (drive_mode 0) extra knee headroom, per model. Raises both knees
  -- so a clean amp stays clean to a hotter input; Drive mode passes 0 here so the
  -- Drive voicing is byte-for-byte unchanged. See ``ampCleanKneeBonus``.
  cleanBonus :: Signed 25
  cleanBonus = if drive then 0 else ampCleanKneeBonus modelIdx
  posKnee = resize (4_900_000 - ch * 7_000 - posDriveDelta + cleanBonus - hystS) :: Sample
  negKnee = resize (4_350_000 - ch * 6_200 - negDriveDelta + cleanBonus + hystS) :: Sample
  posShift = 2 :: Int
  negShift = if drive then 2 else 3

-- | Hysteresis bias from a previous clip output: a small signed fraction
-- (1/2^ampHystShift) of the prior output sample. Larger shift = subtler memory.
ampHystShift :: Int
ampHystShift = 4

ampHystBias :: Sample -> Sample
ampHystBias prevOut = prevOut `shiftR` ampHystShift

-- | JC-120 clean-channel ceiling. The real JC-120 is a solid-state, hi-fi
-- *clean* amp that does not clip in normal playing; the shared waveshaper
-- colours a signal it should leave clean. For model 0 we replace the asym
-- soft clip with a very-high-knee symmetric soft clip that only catches
-- extreme peaks (>~89 % FS) -- a clean channel with a safety ceiling, no
-- waveshaper colour in the normal range. No new DSP (softClipK is compare +
-- shift, like ampAsymClip). Only model 0 is affected; every other model keeps
-- ampAsymClip byte-for-byte.
ampJc120CleanKnee :: Sample
ampJc120CleanKnee = 7_500_000

-- ``prevOut`` is this stage's previous output (pipeline register), feeding the
-- D95 hysteresis. JC-120 (clean) and the amp-off bypass pass hyst = 0 implicitly
-- (they do not call ampAsymClip), so they stay byte-identical.
ampWaveshapeFrame :: Sample -> Frame -> Frame
ampWaveshapeFrame prevOut f =
  setMonoWet (if on then shaped else monoSample f) f
 where
  on = flag6 (fGate f)
  idx = ampModelIdxF f
  drive = ampDriveModeF f
  intensity = ampCharForModel idx
  hyst = ampHystBias prevOut
  shaped
    | idx == 0  = softClipK ampJc120CleanKnee (monoWet f)  -- JC-120: clean SS channel
    | otherwise = ampAsymClip idx intensity drive hyst (monoWet f)

ampPreLowpassFrame :: Sample -> Frame -> Frame
ampPreLowpassFrame prev f =
  setMonoWet (if on then onePoleU8 alpha prev (monoWet f) else monoSample f) f
 where
  on = flag6 (fGate f)
  idx = ampModelIdxF f
  drive = ampDriveModeF f
  charByte = ampCharForModel idx
  -- 96 kHz: base alpha 80 + (char >> 2) (was 128 + ...); the recomputed
  -- ampModelDarken / ampPreLpfDriveDarken tables hold each model's LPF corner Hz.
  -- HF-restore (2026-06-16/17): 80 -> 102 raises the post-clip LPF corner
  -- uniformly (broadband brighten) to recover the top lost when the amp input HP
  -- stopped being a bright differentiator (the bass fix). This is BEFORE the tone
  -- stack, so unlike a high ampTrebleGain floor it brightens WITHOUT compressing
  -- the TREBLE/PRESENCE knob range (cycle 2). Pairs with ampTrebleGain floor 110.
  baseAlpha = 102 + (charByte `shiftR` 2)
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

ampSecondStageFrame :: Sample -> Frame -> Frame
ampSecondStageFrame prevOut f =
  setMonoWet (if on then shaped else monoSample f) f
 where
  on = flag6 (fGate f)
  idx = ampModelIdxF f
  drive = ampDriveModeF f
  -- Softer than the first clip stage; keeps low-gain response
  -- touch-sensitive by halving the per-model intensity.
  intensity = ampCharForModel idx `shiftR` 1
  s2in = satShift7 (fAccL f)
  hyst = ampHystBias prevOut
  -- JC-120 stays clean here too (same high-knee ceiling as stage 1).
  shaped
    | idx == 0  = softClipK ampJc120CleanKnee s2in
    | otherwise = ampAsymClip idx intensity drive hyst s2in

