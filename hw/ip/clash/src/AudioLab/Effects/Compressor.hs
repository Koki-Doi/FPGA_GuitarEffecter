{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Compressor where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

-- ---- Compressor (THRESHOLD / RATIO / RESPONSE / MAKEUP) --------------
--
-- Stereo-linked feed-forward peak compressor on its own GPIO. Sits
-- between the noise suppressor and the overdrive: tightens picking and
-- evens out level before the gain stages. Driven by the dedicated
-- compressor_control GPIO carried in fComp:
--
--   fComp ctrlA = compThreshold       (envelope-compare level, byte 0..255)
--   fComp ctrlB = compRatio           (compression strength,   byte 0..255)
--   fComp ctrlC = compResponse        (smoothing time,         byte 0..255)
--   fComp ctrlD bit7      = compEnable
--   fComp ctrlD bits[6:0] = compMakeup (Q7-style 0..127, ~0.75x..1.25x)
--
-- Bit-exact bypass when compEnable is clear. Same shape as the noise
-- suppressor so timing is comparable: one envelope-input register stage
-- (reusing gateLevelFrame), two feedback registers (envelope + smoothed
-- gain), one apply stage, one makeup stage.

compThresholdByte :: Ctrl -> Unsigned 8
compThresholdByte = ctrlA

compRatioByte :: Ctrl -> Unsigned 8
compRatioByte = ctrlB

compResponseByte :: Ctrl -> Unsigned 8
compResponseByte = ctrlC

compEnableMakeupByte :: Ctrl -> Unsigned 8
compEnableMakeupByte = ctrlD

compEnabled :: Ctrl -> Bool
compEnabled c = testBit (compEnableMakeupByte c) 7

compMakeupU7 :: Ctrl -> Unsigned 8
compMakeupU7 c = compEnableMakeupByte c .&. 0x7F

compOn :: Frame -> Bool
compOn f = compEnabled (fComp f)

-- Same scaling family as gateThreshold / nsThreshold, but the recording-
-- analysis pass lowers the effective compare point slightly so the
-- existing light presets actually enter gain reduction on guitar-level
-- material instead of tracking almost like bypass.
compThresholdSample :: Ctrl -> Sample
compThresholdSample c = base - (base `shiftR` 3)
 where
  base = resize (asSigned9 (compThresholdByte c)) `shiftL` 13

-- Constant Sample equivalents of gateUnity, used to clamp the reduction
-- term before converting to GateGain. Kept as named constants to make
-- the synthesiser-visible width explicit.
unitySample :: Sample
unitySample = 4_095

unityU24 :: Unsigned 24
unityU24 = 4_095

-- Convert a Sample known to be in [0, gateUnity] to GateGain (Unsigned 12).
-- Caller must clamp the input first; this is just a bit-slice.
sampleToGateGain :: Sample -> GateGain
sampleToGateGain s = unpack (slice d11 d0 (pack s))

-- Stage 1 envelope: peak follower. Attack is instantaneous; release
-- speed is controlled by compResponse. response=0 is the fastest /
-- tightest, response=255 is the slowest / most sustaining. Bypassed
-- (env -> 0) when the compressor is off so a re-enable starts clean.
compEnvNext :: Sample -> Maybe Frame -> Sample
compEnvNext env Nothing = env
compEnvNext env (Just f)
  | not (compOn f)        = 0
  | level > env           = level
  | env > releaseStep     = env - releaseStep
  | otherwise             = 0
 where
  level = maxAbsFrame f
  responseByte = compResponseByte (fComp f)
  envStep = resize (((resize env :: Signed 25) `shiftR` 8) + 1) :: Sample
  responseStep =
    let distance = (255 :: Unsigned 8) - responseByte
        raw = (distance `shiftR` 4) + (distance `shiftR` 6)
    in if raw == 0 then 1 else resize (asSigned9 raw) :: Sample
  releaseStep = responseStep + envStep

-- Stage 2 target gain (lives inside the gain-smoother, not its own
-- pipeline stage). unity when env <= softThreshold; otherwise reduced
-- linearly with the excess and the ratio. ratio=0 -> almost no
-- compression; ratio=255 -> strong reduction.
--
-- Real-pedal voicing pass: introduced a small soft-knee offset and a
-- gentler per-dB reduction slope so the engagement is more gradual.
-- Recording analysis then showed the live presets barely changed crest
-- factor, so this widens the knee and adds a modest amount of reduction
-- slope back without returning to the abrupt hard-knee feel.
--
--   * softThreshold = threshold - (threshold >> 3) -- ~12% below the
--     user threshold, so engagement starts earlier
--     instead of as a brick wall at exactly threshold.
--   * excessShifted = (excess >> 12) + (excess >> 14), about 1.25x the
--     previous reduction slope. Combined with the ratio byte this is
--     audible at ratio=25..45 while still avoiding over-compression.
compTargetGain :: Frame -> Sample -> GateGain
compTargetGain f env
  | not (compOn f)         = gateUnity
  | env <= softThreshold   = gateUnity
  | reduction >= gateUnity = 0
  | otherwise              = gateUnity - reduction
 where
  threshold      = compThresholdSample (fComp f)
  softThreshold  = threshold - (threshold `shiftR` 3)
  excess         = env - softThreshold
  excessShifted  = (excess `shiftR` 12) + (excess `shiftR` 14)
  excessClamped
    | excessShifted < 0           = 0 :: Sample
    | excessShifted > unitySample = unitySample
    | otherwise                   = excessShifted
  excessU12 :: GateGain
  excessU12 = sampleToGateGain excessClamped
  ratioByte = compRatioByte (fComp f)
  prod24 :: Unsigned 24
  prod24 = (resize excessU12 :: Unsigned 24)
         * (resize ratioByte :: Unsigned 24)
  reduction24 = prod24 `shiftR` 8 :: Unsigned 24
  reduction
    | reduction24 >= unityU24 = gateUnity
    | otherwise               = resize reduction24

-- Stage 3 gain smoother: a single integer step per sample toward the
-- target. Both attack and release use the same step, controlled by
-- compResponse (faster at low values, slower at high values).
compGainNext :: GateGain -> Sample -> Maybe Frame -> GateGain
compGainNext gain _ Nothing = gain
compGainNext gain env (Just f)
  | not (compOn f) = gateUnity
  | gain < target =
      if target - gain < step then target else gain + step
  | gain > target =
      if gain - target < step then target else gain - step
  | otherwise     = gain
 where
  target = compTargetGain f env
  responseByte = compResponseByte (fComp f)
  responseDistance = (255 :: Unsigned 8) - responseByte
  raw = (responseDistance `shiftR` 3) + (responseDistance `shiftR` 5)
  step = if raw == 0 then 1 else resize raw :: GateGain

-- Stage 4 apply: one register stage of multiply + saturating shift.
-- Same arithmetic shape as nsApplyFrame so timing remains comparable.
-- Bit-exact bypass when the compressor is off.
compApplyFrame :: GateGain -> Frame -> Frame
compApplyFrame gain f
  | not (compOn f) = f
  | otherwise      = f{fL = applyComp (fL f), fR = applyComp (fR f)}
 where
  applyComp x = satShift12 (mulU12 x gain)

-- Stage 5 makeup gain: post-compression Q8 gain that maps makeup u7
-- 0/64/127 -> 192/256/319 (Q8). 0->0.75x, 50->1.0x, 100->~1.25x. Kept
-- conservative so a Compressor preset cannot blow the rest of the
-- chain into clipping. Bit-exact bypass when the compressor is off.
compMakeupFrame :: Frame -> Frame
compMakeupFrame f
  | not (compOn f) = f
  | otherwise      = f{fL = applyMakeup (fL f), fR = applyMakeup (fR f)}
 where
  factor :: Unsigned 9
  factor = 192 + resize (compMakeupU7 (fComp f))
  applyMakeup x = satShift8 (mulU9 x factor)
