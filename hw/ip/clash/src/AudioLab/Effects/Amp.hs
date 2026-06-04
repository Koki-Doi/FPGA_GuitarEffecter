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
  0 -> 18    -- JC-120        : high-headroom solid-state clean
  1 -> 78    -- Twin Reverb   : glassy tube clean
  2 -> 166   -- AC30          : earlier chime breakup
  3 -> 208   -- Rockerverb    : thick dark saturation
  4 -> 220   -- JCM800        : classic rock cascaded drive
  5 -> 246   -- TriAmp Mk3    : modern high-gain peak
  _ -> 18    -- 6/7 reserved -> safe (JC-120)

-- | Per-model post-clip pre-LPF darken (Clean-mode baseline). Larger =
-- darker / less fizz. Indexed by ``ampModelIdxF`` directly.
ampModelDarken :: Unsigned 3 -> Unsigned 8
ampModelDarken idx = case idx of
  0 ->  0    -- JC-120: bright SS feel, no darken
  1 ->  3    -- Twin: bright but slightly rounded
  2 ->  3    -- AC30: keep upper-mid chime
  3 -> 18    -- Rockerverb: darker low-mid thickness
  4 -> 10    -- JCM800: tame fizz, keep upper-mid bark
  5 -> 26    -- TriAmp Mk3: tight modern fizz control
  _ ->  0

-- | Per-model extra darken to add only in Drive mode. Stacked on top of
-- ``ampModelDarken`` so each model's Drive-mode tone is darker than
-- its own Clean-mode tone (otherwise harder clipping just brightens).
-- D69: Drive-mode-only retune. Keep Clean mode unchanged, but absorb
-- the extra harmonics from the stronger Drive-mode knee deltas.
ampPreLpfDriveDarken :: Unsigned 3 -> Unsigned 8
ampPreLpfDriveDarken idx = case idx of
  0 ->  6    -- JC-120: light fizz guard
  1 ->  8    -- Twin: glassy tube breakup
  2 -> 12    -- AC30: jangly crunch
  3 -> 20    -- Rockerverb: thick saturation without excess fizz
  4 -> 20    -- JCM800: classic-rock drive, controlled top
  5 -> 30    -- TriAmp Mk3: modern HG, kill fizz
  _ ->  6

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
ampEmphShift = 3       -- one-pole corner (~ a few kHz at 48 kHz); gentle

ampEmphAmount :: Int
ampEmphAmount = 1      -- cut/restore 1/2^amount of the HF band (half)

ampPreEmphFrame :: Sample -> Frame -> Frame
ampPreEmphFrame prevLp f =
  setMonoWet (if on then xpre else monoWet f) (setMonoEqLow lp f)
 where
  on = flag6 (fGate f) && ampModelIdxF f /= 0
  x = monoWet f
  lp = prevLp + resize (((resize x - resize prevLp) :: Signed 25) `shiftR` ampEmphShift)
  h = satWide (resize x - resize lp :: Wide)
  xpre = satWide (resize x - (resize h `shiftR` ampEmphAmount) :: Wide)

ampDeEmphFrame :: Sample -> Frame -> Frame
ampDeEmphFrame prevLp f =
  setMonoWet (if on then xpost else monoWet f) (setMonoEqLow lp f)
 where
  on = flag6 (fGate f) && ampModelIdxF f /= 0
  x = monoWet f
  lp = prevLp + resize (((resize x - resize prevLp) :: Signed 25) `shiftR` ampEmphShift)
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
  posKnee = resize (4_900_000 - ch * 7_000 - posDriveDelta - hystS) :: Sample
  negKnee = resize (4_350_000 - ch * 6_200 - negDriveDelta + hystS) :: Sample
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

-- Per-amp-family resonant tone-stack biquad (realism item 3 / R3, D83).
-- The existing 3-band difference EQ (ampToneFilterFrame / ampToneBandFrame
-- below) can tilt the bands but cannot make a resonant scoop/peak, so amp
-- families that are defined by a resonant stack (Fender blackface mid scoop,
-- Vox AC30 chime, Marshall mid) all sound similar. This ONE shared peaking
-- biquad, with coefficients muxed by ampModelIdxF, adds that resonant shape.
-- Filled families (all hand-designed target curves, NOT schematic tables,
-- D7/D45): Fender blackface mid scoop (JC-120 idx 0 + Twin idx 1, -5 dB @
-- 400 Hz, D83), Vox AC30 chime (idx 2, +4 dB @ 2200 Hz, D84), Marshall JCM800
-- mid (idx 4, +4 dB @ 650 Hz, D84). Rockerverb (idx 3) and TriAmp (idx 5) stay
-- FLAT (b0 = 2^14, rest 0 -> exact unity passthrough, byte-identical). All
-- families share this ONE biquad via the coefficient mux -- do NOT instantiate
-- a second biquad (D58 lesson). Pipeline-split like D82 (feedforward
-- precomputed a stage earlier, recursive stage closes the loop with two
-- multiplies) so the single-cycle feedback path stays short on the
-- timing-tight island.
ampScoopFeedforwardCoeffs :: Unsigned 3 -> (Signed 16, Signed 16, Signed 16)
ampScoopFeedforwardCoeffs idx = case idx of
  0 -> (16044, -31169, 15169)   -- JC-120 : Fender-style clean scoop (-5 dB @ 400 Hz)
  1 -> (16044, -31169, 15169)   -- Twin   : blackface mid scoop      (-5 dB @ 400 Hz)
  2 -> (17355, -28234, 12091)   -- AC30   : Vox chime upper-mid peak  (+4 dB @ 2200 Hz)
  4 -> (16772, -31328, 14670)   -- JCM800 : Marshall mid peak         (+4 dB @ 650 Hz)
  _ -> (16384, 0, 0)            -- Rockerverb(3)/TriAmp(5) : flat (unity, b0 = 2^14)

ampScoopFeedbackCoeffs :: Unsigned 3 -> (Signed 16, Signed 16)
ampScoopFeedbackCoeffs idx = case idx of
  0 -> (-31169, 14828)
  1 -> (-31169, 14828)
  2 -> (-28234, 13062)
  4 -> (-31328, 15057)
  _ -> (0, 0)                   -- Rockerverb(3)/TriAmp(5) : flat (no feedback)

ampToneScoopFeedforwardFrame :: Sample -> Sample -> Frame -> Frame
ampToneScoopFeedforwardFrame x1 x2 f =
  setMonoAcc (if on then ff else 0) f
 where
  on = flag6 (fGate f)
  (b0, b1, b2) = ampScoopFeedforwardCoeffs (ampModelIdxF f)
  x = monoWet f
  ff = mulS16 x b0 + mulS16 x1 b1 + mulS16 x2 b2 :: Wide

ampToneScoopRecursiveFrame :: Sample -> Sample -> Frame -> Frame
ampToneScoopRecursiveFrame y1 y2 f =
  setMonoWet (if on then y else monoWet f) f
 where
  on = flag6 (fGate f)
  (a1, a2) = ampScoopFeedbackCoeffs (ampModelIdxF f)
  -- fAccL already holds the feedforward sum; y = satShift14(FF - a1*y1 - a2*y2).
  y = satShift14 (fAccL f - mulS16 y1 a1 - mulS16 y2 a2)

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
    1 ->  2                 -- Twin    : glassy, not piercing
    2 ->  2                 -- AC30    : keep chime
    3 ->  9                 -- Rockerv : rounded
    4 ->  8                 -- JCM800  : bark, slight trim
    5 -> 14                 -- TriAmp  : controlled high
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
    1 -> presenceByte `shiftR` 5 -- Twin    : glassy but controlled
    2 -> presenceByte `shiftR` 6 -- AC30    : jangly presence
    3 -> presenceByte `shiftR` 3 -- Rockerv : darker and thicker
    4 -> presenceByte `shiftR` 4 -- JCM800  : tight low + strong presence trim
    5 -> presenceByte `shiftR` 3 -- TriAmp  : maximum trim, modern voicing
    _ -> 0
  high = satWide (resize (monoWet f) - resize (monoEqHighLp f))

satShift9Wide :: Wide -> Wide
satShift9Wide = resize . satShift9

satShift10Wide :: Wide -> Wide
satShift10Wide = resize . satShift10

-- Power-amp sag envelope (realism item 5b / R2, part 2). A slow peak-follower
-- of the master-input level (same shape as the Compressor / NoiseSuppressor /
-- Fuzz-bias envelopes: instant attack, slow linear release for the
-- "recovers-after-the-transient" sag character, reset to 0 when the amp is
-- off so bypass stays bit-exact). No multiply (abs + compare + subtract).
ampSagReleaseStep :: Sample
ampSagReleaseStep = 1024

ampSagEnvNext :: Sample -> Maybe Frame -> Sample
ampSagEnvNext env Nothing = env
ampSagEnvNext env (Just f)
  | not (flag6 (fGate f))     = 0
  | level > env               = level
  | env > ampSagReleaseStep   = env - ampSagReleaseStep
  | otherwise                 = 0
 where
  level = abs24 (monoWet f)

ampMasterFrame :: Sample -> Frame -> Frame
ampMasterFrame env f =
  setMonoSample (if on then out else monoSample f) f
 where
  on = flag6 (fGate f)
  level = ctrlB (fAmp f)
  idx = ampModelIdxF f
  -- Power-amp sag: loud passages pull the master level down a touch, then it
  -- recovers as the envelope releases. Bounded to at most half the level (no
  -- choke) and DISABLED for JC-120 (idx 0, solid-state = stiff supply, no
  -- sag). Reuses the existing master multiply -> no new DSP. sagRaw takes bits
  -- 22..17 of the (non-negative) envelope = a 0..63 magnitude.
  sagRaw0 = resize (unpack (slice d22 d17 (pack env)) :: Unsigned 6) :: Unsigned 8
  -- Per-model sag depth. AC30 (idx 2) is class-A with cathode-bias sag and
  -- early compression, so its supply sags ~1.5x deeper than the other tube
  -- amps (shift+add, no DSP). Every other model keeps sagRaw0 byte-for-byte.
  sagRaw = case idx of
    2 -> sagRaw0 + (sagRaw0 `shiftR` 1)   -- AC30: deeper class-A sag
    _ -> sagRaw0
  sagCap = level `shiftR` 1
  sagByte = if idx == 0 then 0 else min sagRaw sagCap
  effLevel = level - sagByte
  out = softClipK 3_300_000 (satShift7 (mulU8 (monoWet f) effLevel))

-- ---- Output-transformer emulation (D94, DIGITAL_SOUND_REDUCTION.md #9) --
-- A real tube amp's output transformer is a big part of "amp warmth" that the
-- current clip -> tone -> cab chain misses entirely: the iron core SATURATES on
-- low-frequency energy (bass notes / power chords push the core and
-- compress/round, adding low-order harmonics), while the highs pass roughly
-- linearly. The audible tell is "the low end blooms and compresses on loud
-- chords". This sits after the power-amp master, before the cab (transformer =
-- the power-amp's iron; cab = the speaker -- both are distinct, both were
-- missing).
--
-- Minimal model (shift-only, NO new DSP): split the low band with a one-pole
-- lowpass (`prev + (x-prev)>>shift`, ~120 Hz corner at 48 kHz), soft-clip ONLY
-- the low band (softClipK = compare+shift, no multiply), and recombine with the
-- untouched high band. So loud lows bloom/compress while treble stays linear.
-- Gated on amp-on (bit-exact bypass when off) AND skipped for JC-120 (idx 0,
-- solid-state = NO output transformer, same exclusion as the D86 sag). The
-- lowpass state is stashed in the reuse-safe fEqLowL (the cab's first stage
-- re-initialises fEqLowL = 0, so the stash never leaks). The HF bandwidth droop
-- of a real transformer is left to the cab rolloff + the D93 emphasis for now;
-- this phase is just the LF core saturation (the defining character).
ampTransformerLfShift :: Int
ampTransformerLfShift = 6      -- one-pole LF split corner ~120 Hz at 48 kHz

ampTransformerKnee :: Sample
ampTransformerKnee = 5_200_000 -- LF core-saturation knee (loud lows bloom/compress)

ampTransformerFrame :: Sample -> Frame -> Frame
ampTransformerFrame prevLp f =
  setMonoSample (if on then out else monoSample f) (setMonoEqLow lp f)
 where
  on = flag6 (fGate f) && ampModelIdxF f /= 0
  x = monoSample f
  lp = prevLp + resize (((resize x - resize prevLp) :: Signed 25) `shiftR` ampTransformerLfShift)
  high = satWide (resize x - resize lp :: Wide)
  lowSat = softClipK ampTransformerKnee lp
  out = satWide (resize lowSat + resize high :: Wide)

-- Transformer HF bandwidth droop (D96, #9 continuation). A real output
-- transformer cannot pass the top octave -- its limited bandwidth rounds the
-- treble, a characteristic "iron" softness. A gentle one-pole high-cut on the
-- transformer output: take the HF band `h = x - lp` (lp = one-pole lowpass,
-- ~3.8 kHz corner) and subtract a fraction (`h >> ampTransformerHfDroop`) so the
-- top is shelved down a touch. Shift-only -> NO new DSP. Same amp-on + skip-
-- JC-120 gate as the LF stage; its own one-pole state stashed in the reuse-safe
-- fEqLowL (overwritten by the cab's first stage). Runs right after the LF
-- saturation stage so the two transformer behaviours (LF bloom + HF droop) are
-- complete. ampTransformerHfShift / ampTransformerHfDroop are bench-tunable.
ampTransformerHfShift :: Int
ampTransformerHfShift = 1      -- one-pole HF corner ~3.8 kHz at 48 kHz

ampTransformerHfDroop :: Int
ampTransformerHfDroop = 3      -- subtract 1/2^n of the HF band (gentle ~-1.2 dB shelf)

ampTransformerHfFrame :: Sample -> Frame -> Frame
ampTransformerHfFrame prevLp f =
  setMonoSample (if on then out else monoSample f) (setMonoEqLow lp f)
 where
  on = flag6 (fGate f) && ampModelIdxF f /= 0
  x = monoSample f
  lp = prevLp + resize (((resize x - resize prevLp) :: Signed 25) `shiftR` ampTransformerHfShift)
  h = satWide (resize x - resize lp :: Wide)            -- HF band
  out = satWide (resize x - (resize h `shiftR` ampTransformerHfDroop) :: Wide)
