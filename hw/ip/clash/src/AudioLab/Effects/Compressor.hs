{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Compressor where

import Clash.Prelude
import GHC.Generics (Generic)

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

data CompTarget = CompTarget
  { ctOn :: Bool
  , ctTarget :: GateGain
  , ctStep :: GateGain
  }
  deriving (Generic, NFDataX)

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
compEnvNext = peakFollower compOn maxAbsFrame release
 where
  -- 96 kHz: release steps halve (>>9, and the response shifts deepen by one)
  -- so the release TIME (ms) is unchanged when the sample rate doubles.
  release env f = responseStep + envStep
   where
    responseByte = compResponseByte (fComp f)
    envStep = resize (((resize env :: Signed 25) `shiftR` 9) + 1) :: Sample
    responseStep =
      let distance = (255 :: Unsigned 8) - responseByte
          raw = (distance `shiftR` 5) + (distance `shiftR` 7)
      in if raw == 0 then 1 else resize (asSigned9 raw) :: Sample

-- Stage 2a: target gain + smoothing step, registered as Maybe CompTarget.
-- Nothing cycles (idle pipeline slots between valid I2S frames) produce
-- Nothing so the downstream smoother holds the previous gain -- no
-- spurious reset to unity between valid samples.
compTargetNext :: Sample -> Maybe Frame -> Maybe CompTarget
compTargetNext _ Nothing = Nothing
compTargetNext env (Just f) = Just (CompTarget on target step)
 where
  on = compOn f
  threshold      = compThresholdSample (fComp f)
  softThreshold  = threshold - (threshold `shiftR` 3)
  excess         = env - softThreshold
  -- D125 Dyna/Ross sustain: the old (>>12 + >>14) mapped the envelope excess
  -- into excessU12 so weakly that the gain reduction stayed ~0.1..2.6 dB and
  -- the RATIO knob barely moved it (10..90 -> -0.1..-0.6 dB). (>>10 + >>11) is
  -- ~4.8x more sensitive, so reduction = excessU12 * ratio/256 now reaches
  -- ~8..12 dB on loud material AND the RATIO knob spans mild->heavy clearly.
  -- This is the static compression curve (NOT a time constant), so it is
  -- fs-independent. Light presets (low RATIO) stay light.
  excessShifted  = (excess `shiftR` 10) + (excess `shiftR` 11)
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
  target
    | not on               = gateUnity
    | env <= softThreshold = gateUnity
    | reduction >= gateUnity = 0
    | otherwise            = gateUnity - reduction
  responseByte = compResponseByte (fComp f)
  responseDistance = (255 :: Unsigned 8) - responseByte
  -- 96 kHz: per-sample smoothing step halves (>>4/>>6 was >>3/>>5) so the gain
  -- smoothing TIME is unchanged at 2x fs.
  raw = (responseDistance `shiftR` 4) + (responseDistance `shiftR` 6)
  step = if raw == 0 then 1 else resize raw :: GateGain

-- Stage 2b: gain smoother. Nothing holds gain unchanged; Just steps
-- toward the registered target.
compGainSmooth :: GateGain -> Maybe CompTarget -> GateGain
compGainSmooth gain Nothing = gain
compGainSmooth gain (Just (CompTarget on target step))
  | not on    = gateUnity
  | gain < target =
      if target - gain < step then target else gain + step
  | gain > target =
      if gain - target < step then target else gain - step
  | otherwise = gain

-- Stage 4 apply: one register stage of multiply + saturating shift.
-- Same arithmetic shape as nsApplyFrame so timing remains comparable.
-- Bit-exact bypass when the compressor is off.
compApplyFrame :: GateGain -> Frame -> Frame
compApplyFrame gain f
  | not (compOn f) = f
  | otherwise      = setMonoSample (applyComp (monoSample f)) f
 where
  applyComp x = satShift12 (mulU12 x gain)

-- Stage 5 makeup gain: post-compression Q8 gain that maps makeup u7
-- 0/64/127 -> 192/256/319 (Q8). 0->0.75x, 50->1.0x, 100->~1.25x. Kept
-- conservative so a Compressor preset cannot blow the rest of the
-- chain into clipping. Bit-exact bypass when the compressor is off.
compMakeupFrame :: Frame -> Frame
compMakeupFrame f
  | not (compOn f) = f
  | otherwise      = setMonoSample (applyMakeup (monoSample f)) f
 where
  factor :: Unsigned 9
  factor = 192 + resize (compMakeupU7 (fComp f))
  applyMakeup x = satShift8 (mulU9 x factor)
