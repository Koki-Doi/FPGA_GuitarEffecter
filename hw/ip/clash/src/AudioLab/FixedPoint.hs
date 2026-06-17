{-# LANGUAGE NumericUnderscores #-}

module AudioLab.FixedPoint where

import Clash.Prelude

import AudioLab.Types

asSigned9 :: Unsigned 8 -> Signed 9
asSigned9 x = unpack ((0 :: BitVector 1) ++# pack x)

asSigned10 :: Unsigned 9 -> Signed 10
asSigned10 x = unpack ((0 :: BitVector 1) ++# pack x)

asSigned11 :: Unsigned 10 -> Signed 11
asSigned11 x = unpack ((0 :: BitVector 1) ++# pack x)

asSigned13 :: Unsigned 12 -> Signed 13
asSigned13 x = unpack ((0 :: BitVector 1) ++# pack x)

abs24 :: Sample -> Sample
abs24 x =
  if x == minBound
    then maxBound
    else if x < 0 then negate x else x

mulU8 :: Sample -> Unsigned 8 -> Wide
mulU8 x gain = resize x * resize (asSigned9 gain)

mulU9 :: Sample -> Unsigned 9 -> Wide
mulU9 x gain = resize x * resize (asSigned10 gain)

mulU10 :: Sample -> Unsigned 10 -> Wide
mulU10 x gain = resize x * resize (asSigned11 gain)

mulU12 :: Sample -> Unsigned 12 -> Wide
mulU12 x gain = resize x * resize (asSigned13 gain)

mulS10 :: Sample -> Signed 10 -> Wide
mulS10 x gain = resize x * resize gain

-- | Sample * Signed 16 -> Wide. Higher coefficient precision than mulS10,
-- needed by the resonant biquad tone stages (realism item 3): a peaking /
-- notch biquad at a low normalised frequency (e.g. the ~720 Hz Tube Screamer
-- mid hump at 48 kHz) has feedforward/feedback coefficients near +-2 whose
-- DC gain depends on tiny differences -- Q8 (mulS10) rounding collapses the
-- passband, Q14 coefficients (range ~+-2 * 16384 < 32768) preserve it.
mulS16 :: Sample -> Signed 16 -> Wide
mulS16 x gain = resize x * resize gain

satWide :: Wide -> Sample
satWide x
  | x > 8_388_607 = maxBound
  | x < (-8_388_608) = minBound
  | otherwise = resize x

satShift7 :: Wide -> Sample
satShift7 = satWide . (`shiftR` 7)

satShift8 :: Wide -> Sample
satShift8 = satWide . (`shiftR` 8)

satShift9 :: Wide -> Sample
satShift9 = satWide . (`shiftR` 9)

satShift10 :: Wide -> Sample
satShift10 = satWide . (`shiftR` 10)

satShift12 :: Wide -> Sample
satShift12 = satWide . (`shiftR` 12)

-- | Q14 accumulator scale-back for the biquad tone stages (mulS16 coeffs).
satShift14 :: Wide -> Sample
satShift14 = satWide . (`shiftR` 14)

softClip :: Sample -> Sample
softClip x
  | x > knee = resize (resize knee + (((resize x :: Signed 25) - resize knee) `shiftR` 2) :: Signed 25)
  | x < negate knee = resize (resize (negate knee) + (((resize x :: Signed 25) + resize knee) `shiftR` 2) :: Signed 25)
  | otherwise = x
 where
  knee = 4_194_304 :: Sample

hardClip :: Sample -> Sample -> Sample
hardClip x threshold
  | x > threshold = threshold
  | x < negate threshold = negate threshold
  | otherwise = x

onePoleU8 :: Unsigned 8 -> Sample -> Sample -> Sample
onePoleU8 alpha prev x = satShift8 (mulU8 x alpha + mulU8 prev (255 - alpha))

-- | Shift-coefficient one-pole lowpass: @prev + (x - prev) >> n@ with a
-- Signed 25 intermediate (matches the inlined idiom used across the tone /
-- emphasis / transformer / multiband stages exactly). The corner frequency is
-- ~ fs / (2*pi*2^n); larger @n@ = lower corner. fs re-voicing is a single @n@
-- change per call. Bit-exact replacement for the previously inlined form.
onePoleShift :: Int -> Sample -> Sample -> Sample
onePoleShift n prev x =
  prev + resize (((resize x - resize prev) :: Signed 25) `shiftR` n)

-- (refactor H, 2026-06-17) Removed the dead `onePoleHighpass coef shift ...`.
-- It was a FOOTGUN: `prevOut * coef `shiftR` shift` parses as
-- `prevOut * (coef >> shift)` (shiftR binds tighter than *), which rounded to 0
-- for every shipped coef, so the "one-pole" silently degenerated to `x - prevIn`
-- and it repeatedly misled the docs ("amp HP live at 298 Hz" when it was the
-- dead first difference). The two live highpass callers (amp `ampHighpassFrame`,
-- RAT `ratHighpassFrame`) inline an EXPLICIT `(prevOut*coef) `shiftR` shift` for a
-- real pole, so this helper had zero call sites. If a future stage wants a bare
-- first difference, write `satWide (resize x - resize prevIn)` inline (honest).

-- | Symmetric folded-FIR tap: @(a + b) * g@ in Wide. The shared kernel for the
-- symmetric-FIR pair-sum-then-multiply used by the os4x decimation FIR, the Big
-- Muff oversampled-clip decimation, and the cab speaker FIR (refactor E; was
-- copied as a local `pm` / `pairMul` in each). Centre taps still use `mulS10`.
foldTap :: Sample -> Sample -> Signed 10 -> Wide
foldTap a b g = (resize a + resize b) * resize g

-- | Symmetric soft clip with a tunable knee. Below knee it is identity;
-- above the knee the sample is compressed by 1/4 slope.
softClipK :: Sample -> Sample -> Sample
softClipK knee x
  | x > knee = resize (resize knee + (((resize x :: Signed 25) - resize knee) `shiftR` 2) :: Signed 25)
  | x < negKnee = resize (resize negKnee + (((resize x :: Signed 25) - resize negKnee) `shiftR` 2) :: Signed 25)
  | otherwise = x
 where
  negKnee = negate knee

-- | Asymmetric soft clip. The negative half uses a steeper compression
-- (1/8 slope) than the positive half (1/4 slope). Generates even-harmonic
-- content for tube-style overdrive.
asymSoftClip :: Sample -> Sample -> Sample -> Sample
asymSoftClip kneeP kneeN x
  | x > kneeP = resize (resize kneeP + (((resize x :: Signed 25) - resize kneeP) `shiftR` 2) :: Signed 25)
  | x < negKneeN = resize (resize negKneeN + (((resize x :: Signed 25) - resize negKneeN) `shiftR` 3) :: Signed 25)
  | otherwise = x
 where
  negKneeN = negate kneeN

-- | Per-model clip hardness siblings (realism item 4). Same asymmetric
-- soft-clip shape as 'asymSoftClip' but with different compile-time-constant
-- compression shifts, so each synthesises as fixed wiring. A per-model mux
-- (see Overdrive.odClipHardness) selects one; the slope above the knee is
-- 1 / 2^shift, so a smaller shift = harder knee (more odd harmonics, closer
-- to a diode/MOSFET clip) and a larger shift = softer (gentle op-amp-style).
--
--   asymSoftClipSoft : pos>>3 neg>>4  -- softest (TS9 / Jan Ray / Klon)
--   asymSoftClip     : pos>>2 neg>>3  -- medium  (OD-1 / BD-2, the legacy shape)
--   asymSoftClipMed  : pos>>1 neg>>2  -- harder  (OCD MOSFET knee)
--   asymSoftClipHard : pos>>1 neg>>1  -- hardest (reserved for near-hard clip)
asymSoftClipSoft :: Sample -> Sample -> Sample -> Sample
asymSoftClipSoft kneeP kneeN x
  | x > kneeP = resize (resize kneeP + (((resize x :: Signed 25) - resize kneeP) `shiftR` 3) :: Signed 25)
  | x < negKneeN = resize (resize negKneeN + (((resize x :: Signed 25) - resize negKneeN) `shiftR` 4) :: Signed 25)
  | otherwise = x
 where
  negKneeN = negate kneeN

asymSoftClipMed :: Sample -> Sample -> Sample -> Sample
asymSoftClipMed kneeP kneeN x
  | x > kneeP = resize (resize kneeP + (((resize x :: Signed 25) - resize kneeP) `shiftR` 1) :: Signed 25)
  | x < negKneeN = resize (resize negKneeN + (((resize x :: Signed 25) - resize negKneeN) `shiftR` 2) :: Signed 25)
  | otherwise = x
 where
  negKneeN = negate kneeN

asymSoftClipHard :: Sample -> Sample -> Sample -> Sample
asymSoftClipHard kneeP kneeN x
  | x > kneeP = resize (resize kneeP + (((resize x :: Signed 25) - resize kneeP) `shiftR` 1) :: Signed 25)
  | x < negKneeN = resize (resize negKneeN + (((resize x :: Signed 25) - resize negKneeN) `shiftR` 1) :: Signed 25)
  | otherwise = x
 where
  negKneeN = negate kneeN

-- | Hard clip with independent positive/negative thresholds. Used by
-- bias-shifted fuzz models where the waveform centre is offset.
asymHardClip :: Sample -> Sample -> Sample -> Sample
asymHardClip kneeP kneeN x
  | x > kneeP = kneeP
  | x < negKneeN = negKneeN
  | otherwise = x
 where
  negKneeN = negate kneeN
gateUnity :: GateGain
gateUnity = 4_095

-- 96 kHz: per-sample gain-ramp steps halve so the attack/release TIME (ms)
-- is unchanged when the sample rate doubles (512/4 at 48 kHz -> 256/2).
gateAttackStep :: GateGain
gateAttackStep = 256

gateReleaseStep :: GateGain
gateReleaseStep = 2

maxAbsFrame :: Frame -> Sample
maxAbsFrame f = abs24 (monoSample f)

-- | Peak-follower envelope shared by the Compressor / NoiseSuppressor / legacy
-- gate / Fuzz-Face-bias / amp-sag stages: instant attack, linear release by
-- @releaseOf env f@ per sample, reset to 0 when @enabled f@ is false (so a
-- re-enable starts clean), holds on idle (Nothing) cycles. The three function
-- arguments capture every per-stage difference (enable predicate, level source,
-- release-step formula). The guard order is identical to the previously inlined
-- versions, so this is a bit-exact replacement. (Release-step time constants are
-- still fs-dependent and were halved for 96 kHz inside each call site's formula.)
peakFollower
  :: (Frame -> Bool)              -- ^ enabled?
  -> (Frame -> Sample)           -- ^ level source
  -> (Sample -> Frame -> Sample) -- ^ release step from (current env, frame)
  -> Sample -> Maybe Frame -> Sample
peakFollower _ _ _ env Nothing = env
peakFollower enabled levelOf releaseOf env (Just f)
  | not (enabled f)   = 0
  | level > env       = level
  | env > releaseStep = env - releaseStep
  | otherwise         = 0
 where
  level = levelOf f
  releaseStep = releaseOf env f
