{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.NoiseSuppressor where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

gateLevelFrame :: Frame -> Frame
gateLevelFrame f = f{fWetL = maxAbsFrame f}

gateThreshold :: Ctrl -> Sample
gateThreshold control = resize (asSigned9 (ctrlB control)) `shiftL` 13

gateOpenThreshold :: Sample -> Sample
gateOpenThreshold threshold =
  satWide (resize threshold + (resize threshold `shiftR` 1) + 65_536)
gateEnvNext :: Sample -> Maybe Frame -> Sample
gateEnvNext env Nothing = env
gateEnvNext env (Just f)
 | not (flag0 (fGate f)) = 0
  | level > env = level
  | env > decay = env - decay
  | otherwise = 0
 where
  level = fWetL f
  decay = resize (((resize env :: Signed 25) `shiftR` 8) + 1) :: Sample

gateOpenNext :: Bool -> Sample -> Maybe Frame -> Bool
gateOpenNext open _ Nothing = open
gateOpenNext open env (Just f)
  | not (flag0 (fGate f)) = True
  | closeThreshold == 0 = True
  | env > openThreshold = True
  | env < closeThreshold = False
  | otherwise = open
 where
  closeThreshold = gateThreshold (fGate f)
  openThreshold = gateOpenThreshold closeThreshold

gateGainNext :: GateGain -> Bool -> Maybe Frame -> GateGain
gateGainNext gain _ Nothing = gain
gateGainNext gain open (Just f)
  | not (flag0 (fGate f)) = gateUnity
  | open = if gain > gateUnity - gateAttackStep then gateUnity else gain + gateAttackStep
  | gain < gateReleaseStep = 0
  | otherwise = gain - gateReleaseStep

gateFrame :: GateGain -> Frame -> Frame
gateFrame gain f
  | not (flag0 (fGate f)) = f
  | otherwise = f{fL = applyGateGain (fL f), fR = applyGateGain (fR f)}
 where
  applyGateGain x = satShift12 (mulU12 x gain)

-- ---- Noise Suppressor (THRESHOLD / DECAY / DAMP) ---------------------
--
-- Replaces the legacy hard noise gate in the active pipeline. Driven by
-- the dedicated noise_suppressor_control GPIO carried in fNs:
--
--   fNs ctrlA = nsThreshold   (envelope-compare level, byte 0..255)
--   fNs ctrlB = nsDecay       (close-ramp slowness,   byte 0..255)
--   fNs ctrlC = nsDamp        (closed-gain depth,     byte 0..255)
--   fNs ctrlD = nsMode        (reserved, 0 today)
--
-- The block is enabled by the same noise_gate_on flag (flag0 of fGate)
-- so existing set_guitar_effects(noise_gate_on=...) still toggles it.
-- When the flag is clear, every stage is bit-exact bypass.

nsThresholdByte :: Ctrl -> Unsigned 8
nsThresholdByte = ctrlA

nsDecayByte :: Ctrl -> Unsigned 8
nsDecayByte = ctrlB

nsDampByte :: Ctrl -> Unsigned 8
nsDampByte = ctrlC

nsModeByte :: Ctrl -> Unsigned 8
nsModeByte = ctrlD

-- Same scaling as the legacy gateThreshold helper, so that writing the
-- same threshold byte to the legacy GPIO and to the new GPIO yields the
-- same envelope compare level.
nsThresholdSample :: Ctrl -> Sample
nsThresholdSample c = resize (asSigned9 (nsThresholdByte c)) `shiftL` 13

-- closed_gain = ((255 - damp_byte)^2) >> 5 -- pre-computed mapping that
-- gives:
--   damp byte = 0   -> ~ 2032 / 4095  (about 50 % of unity)
--   damp byte = 127 -> ~  512 / 4095  (about 12.5 %)
--   damp byte = 255 -> 0              (full mute)
-- One Unsigned 8 x Unsigned 8 multiply, one shift -- cheap.
nsClosedGain :: Unsigned 8 -> GateGain
nsClosedGain damp =
  let inv8 = (255 :: Unsigned 8) - damp
      sq16 = (resize inv8 :: Unsigned 16) * (resize inv8 :: Unsigned 16)
  in resize (sq16 `shiftR` 5) :: GateGain

-- close_step = max(1, (255 - decay_byte) >> 2)
--   decay byte = 0   -> step 63  (full close in ~65 samples, ~1.4 ms)
--   decay byte = 127 -> step 32  (full close in ~128 samples, ~2.7 ms)
--   decay byte = 255 -> step 1   (full close in ~4096 samples, ~85 ms)
-- Linear ramp: simple, predictable, fits one register stage.
nsCloseStep :: Unsigned 8 -> GateGain
nsCloseStep d =
  let raw = ((255 :: Unsigned 8) - d) `shiftR` 2
  in if raw == 0 then 1 else resize raw :: GateGain

nsAttackStep :: GateGain
nsAttackStep = 512

-- Stage 1 envelope: peak follower, attack-instantaneous,
-- release ~ env >> 8 + 1 per sample (matches legacy gate envelope so
-- the new section feels familiar). Bypassed (env -> 0) when the
-- noise_gate_on flag is clear so a re-enable starts from a clean state.
nsEnvNext :: Sample -> Maybe Frame -> Sample
nsEnvNext env Nothing = env
nsEnvNext env (Just f)
  | not (flag0 (fGate f)) = 0
  | level > env           = level
  | env > releaseStep     = env - releaseStep
  | otherwise             = 0
 where
  level       = maxAbsFrame f
  releaseStep = resize (((resize env :: Signed 25) `shiftR` 8) + 1) :: Sample

-- Stage 2 target gain: open above threshold, damp-derived closed gain
-- below. Lives entirely inside the gain-smoother register; not its own
-- pipeline stage.
--
-- Real-pedal voicing pass: hysteresis around the threshold to avoid
-- chatter when the envelope hovers at the open/close boundary.
--   * env >= threshold     -> always open (target = unity)
--   * env <= closeT        -> always close (target = nsClosedGain)
--                             where closeT = threshold - threshold/4
--                             (~75% of the open threshold)
--   * env between the two  -> hold the previous target by inspecting
--                             the current gain register: if we are
--                             mostly-open (gain >= midGain) stay
--                             open, otherwise stay closed.
-- This mirrors the BOSS NS-2 style hysteresis without spending a new
-- pipeline register.
nsTargetGain :: Frame -> Sample -> GateGain -> GateGain
nsTargetGain f env curGain
  | not (flag0 (fGate f)) = gateUnity
  | env >= threshold      = gateUnity
  | env <= closeT         = closed
  | curGain >= midGain    = gateUnity
  | otherwise             = closed
 where
  threshold = nsThresholdSample (fNs f)
  closeT    = threshold - (threshold `shiftR` 2)
  closed    = nsClosedGain (nsDampByte (fNs f))
  midGain   = gateUnity `shiftR` 1

-- Stage 3 gain smoother: ramps the gain register toward the target.
-- Open is fast (nsAttackStep = 512, ~8 samples to unity) so we do not
-- chop transients; close is decay-controlled.
nsGainNext :: GateGain -> Sample -> Maybe Frame -> GateGain
nsGainNext gain _ Nothing = gain
nsGainNext gain env (Just f)
  | not (flag0 (fGate f)) = gateUnity
  | gain < target =
      if target - gain < nsAttackStep then target else gain + nsAttackStep
  | gain > target =
      let step = nsCloseStep (nsDecayByte (fNs f))
      in if gain - target < step then target else gain - step
  | otherwise = gain
 where
  target = nsTargetGain f env gain

-- Stage 4 apply: one register stage of multiply + saturating shift.
-- Same arithmetic as the legacy gateFrame so timing is comparable.
-- Bit-exact bypass when the noise_gate_on flag is clear.
nsApplyFrame :: GateGain -> Frame -> Frame
nsApplyFrame gain f
  | not (flag0 (fGate f)) = f
  | otherwise = f{fL = applyNs (fL f), fR = applyNs (fR f)}
 where
  applyNs x = satShift12 (mulU12 x gain)
