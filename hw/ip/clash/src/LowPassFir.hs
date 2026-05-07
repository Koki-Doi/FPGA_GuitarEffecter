{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE NumericUnderscores #-}

module LowPassFir where

import Clash.Prelude
import GHC.Generics (Generic)

createDomain vXilinxSystem{vName = "AudioDomain", vResetKind = Asynchronous, vResetPolarity = ActiveLow}

type Sample = Signed 24
type Wide = Signed 48
type Ctrl = BitVector 32
type GateGain = Unsigned 12
type ReverbAddr = Index 1024
type ReverbMem = Vec 1024 Sample

data Frame = Frame
  { fL :: Sample
  , fR :: Sample
  , fLast :: Bool
  , fGate :: Ctrl
  , fOd :: Ctrl
  , fDist :: Ctrl
  , fEq :: Ctrl
  , fRat :: Ctrl
  , fAmp :: Ctrl
  , fAmpTone :: Ctrl
  , fCab :: Ctrl
  , fReverb :: Ctrl
  , fNs :: Ctrl
  , fComp :: Ctrl
  , fAddr :: ReverbAddr
  , fDryL :: Sample
  , fDryR :: Sample
  , fWetL :: Sample
  , fWetR :: Sample
  , fFbL :: Sample
  , fFbR :: Sample
  , fEqLowL :: Sample
  , fEqLowR :: Sample
  , fEqMidL :: Sample
  , fEqMidR :: Sample
  , fEqHighL :: Sample
  , fEqHighR :: Sample
  , fEqHighLpL :: Sample
  , fEqHighLpR :: Sample
  , fAccL :: Wide
  , fAccR :: Wide
  , fAcc2L :: Wide
  , fAcc2R :: Wide
  , fAcc3L :: Wide
  , fAcc3R :: Wide
  }
  deriving (Generic, NFDataX)

data AxisOut = AxisOut
  { oData :: BitVector 48
  , oValid :: Bool
  , oLast :: Bool
  }
  deriving (Generic, NFDataX)

emptyAxisOut :: AxisOut
emptyAxisOut = AxisOut{ oData = 0, oValid = False, oLast = False }

zeroReverb :: ReverbMem
zeroReverb = repeat 0

unpackChan :: BitVector 48 -> (Sample, Sample)
unpackChan bv = (unpack (slice d23 d0 bv), unpack (slice d47 d24 bv))

packChan :: Sample -> Sample -> BitVector 48
packChan left right = pack right ++# pack left

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

asSigned9 :: Unsigned 8 -> Signed 9
asSigned9 x = unpack ((0 :: BitVector 1) ++# pack x)

asSigned10 :: Unsigned 9 -> Signed 10
asSigned10 x = unpack ((0 :: BitVector 1) ++# pack x)

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

mulU12 :: Sample -> Unsigned 12 -> Wide
mulU12 x gain = resize x * resize (asSigned13 gain)

mulS10 :: Sample -> Signed 10 -> Wide
mulS10 x gain = resize x * resize gain

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

-- | Hard clip with independent positive/negative thresholds. Used by
-- bias-shifted fuzz models where the waveform centre is offset.
asymHardClip :: Sample -> Sample -> Sample -> Sample
asymHardClip kneeP kneeN x
  | x > kneeP = kneeP
  | x < negKneeN = negKneeN
  | otherwise = x
 where
  negKneeN = negate kneeN

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

advanceAddr :: ReverbAddr -> ReverbAddr
advanceAddr addr = if addr == maxBound then 0 else addr + 1

mapPipe :: (Frame -> Frame) -> Maybe Frame -> Maybe Frame
mapPipe _ Nothing = Nothing
mapPipe f (Just x) = Just (f x)

isActive :: Maybe Frame -> Bool
isActive Nothing = False
isActive (Just _) = True

frameOr :: (Frame -> Sample) -> Sample -> Maybe Frame -> Sample
frameOr _ old Nothing = old
frameOr f _ (Just x) = f x

delayNext :: Sample -> Sample -> Maybe Frame -> Sample
delayNext old incoming pipe = if isActive pipe then incoming else old

gateUnity :: GateGain
gateUnity = 4_095

gateAttackStep :: GateGain
gateAttackStep = 512

gateReleaseStep :: GateGain
gateReleaseStep = 4

maxAbsFrame :: Frame -> Sample
maxAbsFrame f = if left > right then left else right
 where
  left = abs24 (fL f)
  right = abs24 (fR f)

gateLevelFrame :: Frame -> Frame
gateLevelFrame f = f{fWetL = maxAbsFrame f}

gateThreshold :: Ctrl -> Sample
gateThreshold control = resize (asSigned9 (ctrlB control)) `shiftL` 13

gateOpenThreshold :: Sample -> Sample
gateOpenThreshold threshold =
  satWide (resize threshold + (resize threshold `shiftR` 1) + 65_536)

makeInput :: Ctrl -> Ctrl -> Ctrl -> Ctrl -> Ctrl -> Ctrl -> Ctrl -> Ctrl -> Ctrl -> Ctrl -> Ctrl -> BitVector 48 -> Bool -> Bool -> Maybe Frame
makeInput gateControl odControl distControl eqControl ratControl ampControl ampToneControl cabControl reverbControl noiseSuppressorControl compressorControl samples validIn lastIn =
  if validIn
    then
      let (left, right) = unpackChan samples
       in Just
            Frame
              { fL = left
              , fR = right
              , fLast = lastIn
              , fGate = gateControl
              , fOd = odControl
              , fDist = distControl
              , fEq = eqControl
              , fRat = ratControl
              , fAmp = ampControl
              , fAmpTone = ampToneControl
              , fCab = cabControl
              , fReverb = reverbControl
              , fNs = noiseSuppressorControl
              , fComp = compressorControl
              , fAddr = 0
              , fDryL = left
              , fDryR = right
              , fWetL = 0
              , fWetR = 0
              , fFbL = 0
              , fFbR = 0
              , fEqLowL = 0
              , fEqLowR = 0
              , fEqMidL = 0
              , fEqMidR = 0
              , fEqHighL = 0
              , fEqHighR = 0
              , fEqHighLpL = 0
              , fEqHighLpR = 0
              , fAccL = 0
              , fAccR = 0
              , fAcc2L = 0
              , fAcc2R = 0
              , fAcc3L = 0
              , fAcc3R = 0
              }
    else Nothing

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

overdriveDriveMultiplyFrame :: Frame -> Frame
overdriveDriveMultiplyFrame f =
  f{fAccL = if on then mulU12 (fL f) driveGain else 0, fAccR = if on then mulU12 (fR f) driveGain else 0}
 where
  on = flag1 (fGate f)
  -- Recording analysis showed the standalone Overdrive was too close to
  -- bypass at normal guitar levels. Raise the Q8 drive ceiling from ~5x
  -- to ~6x so DRIVE 30..50 reaches the clip knee, while the level stage
  -- below keeps output jumps controlled.
  driveGain = resize (256 + (resize (ctrlC (fOd f)) * 5 :: Unsigned 11)) :: Unsigned 12

overdriveDriveBoostFrame :: Frame -> Frame
overdriveDriveBoostFrame f =
  f{fWetL = if on then satShift8 (fAccL f) else fL f, fWetR = if on then satShift8 (fAccR f) else fR f}
 where
  on = flag1 (fGate f)

-- Real-pedal voicing pass: replace the symmetric softClip with an
-- asymmetric tube-style soft clip (lower knees, asymmetric slope) so
-- the overdrive picks up some even-harmonic content at moderate drive
-- without changing the combinational shape of the stage. Bit-exact
-- bypass when the overdrive flag is clear.
overdriveDriveClipFrame :: Frame -> Frame
overdriveDriveClipFrame f =
  f{fL = if on then asymSoftClip kneeP kneeN (fWetL f) else fL f, fR = if on then asymSoftClip kneeP kneeN (fWetR f) else fR f}
 where
  on = flag1 (fGate f)
  kneeP = 2_700_000 :: Sample
  kneeN = 2_300_000 :: Sample

overdriveToneMultiplyFrame :: Sample -> Sample -> Frame -> Frame
overdriveToneMultiplyFrame prevL prevR f =
  f
    { fAccL = if on then mulU8 (fL f) tone else 0
    , fAccR = if on then mulU8 (fR f) tone else 0
    , fAcc2L = if on then mulU8 prevL toneInv else 0
    , fAcc2R = if on then mulU8 prevR toneInv else 0
    }
 where
  on = flag1 (fGate f)
  tone = ctrlA (fOd f)
  toneInv = 255 - tone

overdriveToneBlendFrame :: Frame -> Frame
overdriveToneBlendFrame f =
  f
    { fWetL = if on then toneL else fL f
    , fWetR = if on then toneR else fR f
    }
 where
  on = flag1 (fGate f)
  toneL = satShift8 (fAccL f + fAcc2L f)
  toneR = satShift8 (fAccR f + fAcc2R f)

overdriveLevelFrame :: Frame -> Frame
overdriveLevelFrame f =
  f{fL = if on then left else fL f, fR = if on then right else fR f}
 where
  on = flag1 (fGate f)
  level = ctrlB (fOd f)
  left = softClipK safetyKnee (satShift7 (mulU8 (fWetL f) level))
  right = softClipK safetyKnee (satShift7 (mulU8 (fWetR f) level))
  safetyKnee = 3_200_000 :: Sample

-- ---- Legacy distortion stage -----------------------------------------
-- Restored to its pre-refactor shape so the existing
-- set_guitar_effects(distortion_on=True, distortion=, distortion_tone=,
-- distortion_level=) API keeps working untouched. The legacy stage is
-- automatically bypassed when any new pedal-mask bit is set, so that
-- exclusive=True at the Python level really is exclusive.

distortionLegacyOn :: Frame -> Bool
distortionLegacyOn f = flag2 (fGate f) && not (anyDistPedalOn f)

distortionDriveMultiplyFrame :: Frame -> Frame
distortionDriveMultiplyFrame f =
  f
    { fAccL = if on then mulU12 (fL f) driveGain else 0
    , fAccR = if on then mulU12 (fR f) driveGain else 0
    , fAcc2L = resize threshold
    }
 where
  on = distortionLegacyOn f
  amount = ctrlC (fDist f)
  driveGain = resize (256 + (resize amount * 8 :: Unsigned 11)) :: Unsigned 12
  rawThreshold = 8_388_607 - (resize (asSigned9 amount) * 24_000) :: Signed 25
  clampedThreshold = if rawThreshold < 1_800_000 then 1_800_000 else rawThreshold
  threshold = resize clampedThreshold :: Sample

distortionDriveBoostFrame :: Frame -> Frame
distortionDriveBoostFrame f =
  f { fWetL = if on then satShift8 (fAccL f) else fL f
    , fWetR = if on then satShift8 (fAccR f) else fR f }
 where
  on = distortionLegacyOn f

distortionDriveClipFrame :: Frame -> Frame
distortionDriveClipFrame f =
  f { fL = if on then hardClip (fWetL f) threshold else fL f
    , fR = if on then hardClip (fWetR f) threshold else fR f }
 where
  on = distortionLegacyOn f
  threshold = resize (fAcc2L f) :: Sample

distortionToneMultiplyFrame :: Sample -> Sample -> Frame -> Frame
distortionToneMultiplyFrame prevL prevR f =
  f
    { fAccL = if on then mulU8 (fL f) tone else 0
    , fAccR = if on then mulU8 (fR f) tone else 0
    , fAcc2L = if on then mulU8 prevL toneInv else 0
    , fAcc2R = if on then mulU8 prevR toneInv else 0
    }
 where
  on = distortionLegacyOn f
  tone = ctrlA (fDist f)
  toneInv = 255 - tone

distortionToneBlendFrame :: Frame -> Frame
distortionToneBlendFrame f =
  f { fWetL = if on then toneL else fL f
    , fWetR = if on then toneR else fR f }
 where
  on = distortionLegacyOn f
  toneL = satShift8 (fAccL f + fAcc2L f)
  toneR = satShift8 (fAccR f + fAcc2R f)

distortionLevelFrame :: Frame -> Frame
distortionLevelFrame f =
  f { fL = if on then left else fL f
    , fR = if on then right else fR f }
 where
  on = distortionLegacyOn f
  level = ctrlB (fDist f)
  left = satShift7 (mulU8 (fWetL f) level)
  right = satShift7 (mulU8 (fWetR f) level)

-- ---- Pedal-style distortion stages -----------------------------------
-- Each pedal is a small, independently enabled pipeline section. The
-- Frame moves through the same physical stages whether the pedal is on
-- or off; when off, every frame transform leaves fL/fR untouched, so
-- the chain is bit-exact bypass.
--
-- Implemented in this build: clean_boost, tube_screamer, ds1,
-- big_muff, fuzz_face, metal_distortion. rat_style is intentionally a
-- no-op here because the existing RAT stage upstream covers it. Bit 7
-- of the pedal mask remains reserved for an 8th pedal slot.

-- ---- clean_boost (3 stages: mul, shift, level+safety) ---------------

cleanBoostMulFrame :: Frame -> Frame
cleanBoostMulFrame f =
  f { fAccL = if on then mulU12 (fL f) gain else 0
    , fAccR = if on then mulU12 (fR f) gain else 0 }
 where
  on = cleanBoostOn f
  drive = ctrlC (fDist f)
  -- Real-pedal voicing pass: lower the boost ceiling from ~5x to ~4x
  -- (1.0x at drive=0, ~4x at drive=255) so the clean booster stays
  -- mostly clean unless really pushed.
  gain = resize (256 + (resize drive * 3 :: Unsigned 11)) :: Unsigned 12

cleanBoostShiftFrame :: Frame -> Frame
cleanBoostShiftFrame f =
  f { fL = if on then satShift8 (fAccL f) else fL f
    , fR = if on then satShift8 (fAccR f) else fR f }
 where
  on = cleanBoostOn f

cleanBoostLevelFrame :: Frame -> Frame
cleanBoostLevelFrame f =
  f { fL = if on then softClipK safetyKnee leftAfter else fL f
    , fR = if on then softClipK safetyKnee rightAfter else fR f }
 where
  on = cleanBoostOn f
  level = ctrlB (fDist f)
  leftAfter = satShift7 (mulU8 (fL f) level)
  rightAfter = satShift7 (mulU8 (fR f) level)
  -- Real-pedal voicing pass: lower the safety knee from ~4.2M to ~3.2M
  -- so the clean booster catches peaks before they reach the saturator.
  safetyKnee = 3_200_000 :: Sample

-- ---- tube_screamer (5 stages: HPF, mul, clip, post-LPF, level) -------

tubeScreamerHpfFrame :: Sample -> Sample -> Frame -> Frame
tubeScreamerHpfFrame prevLpL prevLpR f =
  f { fL = if on then hpL else fL f
    , fR = if on then hpR else fR f
    , fEqLowL = lpL
    , fEqLowR = lpR }
 where
  on = tubeScreamerOn f
  -- Real-pedal voicing pass: tighten the input low cut. Range bumped
  -- from 2..9 to 3..18 so the bass that hits the clip stage drops with
  -- TIGHT, contributing to the TS-style mid bump.
  alpha = 3 + (distTight (fOd f) `shiftR` 4)
  lpL = onePoleU8 alpha prevLpL (fL f)
  lpR = onePoleU8 alpha prevLpR (fR f)
  hpL = satWide (resize (fL f) - resize lpL :: Wide)
  hpR = satWide (resize (fR f) - resize lpR :: Wide)

tubeScreamerMulFrame :: Frame -> Frame
tubeScreamerMulFrame f =
  f { fAccL = if on then mulU12 (fL f) gain else 0
    , fAccR = if on then mulU12 (fR f) gain else 0 }
 where
  on = tubeScreamerOn f
  drive = ctrlC (fDist f)
  -- Real-pedal voicing pass: lower the maximum drive so even at
  -- DRIVE=100 the TS still sounds like an overdrive (not a fuzz).
  -- Q8 gain: 1x..~6.97x (was 1x..~9x).
  gain = resize (256 + (resize drive * 6 :: Unsigned 12)) :: Unsigned 12

tubeScreamerClipFrame :: Frame -> Frame
tubeScreamerClipFrame f =
  f { fL = if on then asymSoftClip kneeP kneeN boostedL else fL f
    , fR = if on then asymSoftClip kneeP kneeN boostedR else fR f }
 where
  on = tubeScreamerOn f
  boostedL = satShift8 (fAccL f)
  boostedR = satShift8 (fAccR f)
  -- Real-pedal voicing pass: lower the asym clip knees so the soft
  -- clip engages earlier and a touch more asymmetrically (TS-style
  -- diode-to-ground feedback character).
  kneeP = 2_900_000 :: Sample
  kneeN = 2_500_000 :: Sample

tubeScreamerPostLpfFrame :: Sample -> Sample -> Frame -> Frame
tubeScreamerPostLpfFrame prevLpL prevLpR f =
  f { fL = if on then lpL else fL f
    , fR = if on then lpR else fR f
    , fEqHighLpL = lpL
    , fEqHighLpR = lpR }
 where
  on = tubeScreamerOn f
  tone = ctrlA (fDist f)
  -- Real-pedal voicing pass: shift the post-LPF range darker. Range
  -- 64..191 (was 96..223) emphasises the mid band and rolls off the
  -- top end at every TONE setting, so even at TONE=100 the TS does
  -- not sound piercing under high-gain stacking.
  alpha = 64 + (tone `shiftR` 1)
  lpL = onePoleU8 alpha prevLpL (fL f)
  lpR = onePoleU8 alpha prevLpR (fR f)

tubeScreamerLevelFrame :: Frame -> Frame
tubeScreamerLevelFrame f =
  f { fL = if on then softClip leftAfter else fL f
    , fR = if on then softClip rightAfter else fR f }
 where
  on = tubeScreamerOn f
  level = ctrlB (fDist f)
  leftAfter = satShift7 (mulU8 (fL f) level)
  rightAfter = satShift7 (mulU8 (fR f) level)

-- ---- metal_distortion (5 stages: tight HPF, mul, hard clip,
--                        post-LPF, level) -----------------------------

metalHpfFrame :: Sample -> Sample -> Frame -> Frame
metalHpfFrame prevLpL prevLpR f =
  f { fL = if on then hpL else fL f
    , fR = if on then hpR else fR f
    , fEqLowL = lpL
    , fEqLowR = lpR }
 where
  on = metalDistortionOn f
  -- Real-pedal voicing pass: tighter low cut. Range bumped from
  -- 4..19 to 6..37 so TIGHT actually tightens the low end for
  -- modern-metal-style palm-mute response.
  alpha = 6 + (distTight (fOd f) `shiftR` 3)
  lpL = onePoleU8 alpha prevLpL (fL f)
  lpR = onePoleU8 alpha prevLpR (fR f)
  hpL = satWide (resize (fL f) - resize lpL :: Wide)
  hpR = satWide (resize (fR f) - resize lpR :: Wide)

metalMulFrame :: Frame -> Frame
metalMulFrame f =
  f { fAccL = if on then mulU12 (fL f) gain else 0
    , fAccR = if on then mulU12 (fR f) gain else 0 }
 where
  on = metalDistortionOn f
  drive = ctrlC (fDist f)
  -- Real-pedal voicing pass: lower the maximum drive from ~22x to
  -- ~18.95x so the wave does not crash so close to a square at full
  -- DRIVE -- still plenty of saturation, just less ear-fatigue.
  gain = resize (768 + (resize drive * 12 :: Unsigned 12)) :: Unsigned 12

metalClipFrame :: Frame -> Frame
metalClipFrame f =
  f { fL = if on then hardClip boostedL threshold else fL f
    , fR = if on then hardClip boostedR threshold else fR f }
 where
  on = metalDistortionOn f
  drive = ctrlC (fDist f)
  driveS = resize (asSigned9 drive) :: Signed 25
  -- Real-pedal voicing pass: raise the threshold floor from 1.2M to
  -- 1.5M so the hard clip keeps a touch more headroom at full DRIVE
  -- (less square-wave, more crunchy saturation).
  rawT = 3_500_000 - driveS * 5_000 :: Signed 25
  threshold = resize (if rawT < 1_500_000 then 1_500_000 else rawT) :: Sample
  boostedL = satShift8 (fAccL f)
  boostedR = satShift8 (fAccR f)

metalPostLpfFrame :: Sample -> Sample -> Frame -> Frame
metalPostLpfFrame prevLpL prevLpR f =
  f { fL = if on then lpL else fL f
    , fR = if on then lpR else fR f
    , fEqHighLpL = lpL
    , fEqHighLpR = lpR }
 where
  on = metalDistortionOn f
  tone = ctrlA (fDist f)
  -- Real-pedal voicing pass: shift the post-LPF range darker. Range
  -- 48..175 (was 64..192) keeps fizz off the top end at every TONE.
  alpha = 48 + (tone `shiftR` 1)
  lpL = onePoleU8 alpha prevLpL (fL f)
  lpR = onePoleU8 alpha prevLpR (fR f)

metalLevelFrame :: Frame -> Frame
metalLevelFrame f =
  f { fL = if on then softClip leftAfter else fL f
    , fR = if on then softClip rightAfter else fR f }
 where
  on = metalDistortionOn f
  level = ctrlB (fDist f)
  leftAfter = satShift7 (mulU8 (fL f) level)
  rightAfter = satShift7 (mulU8 (fR f) level)

-- ---- ds1 (BOSS DS-1 style; 5 stages: HPF, mul, asym hard/soft hybrid
--                clip, post LPF, level+safety) ------------------------
--
-- Voiced for a brighter, edgier crunch than tube_screamer: the input
-- HPF tightens with TIGHT, the asym soft clip uses lower knees so the
-- saturation hits earlier, and the post LPF starts brighter so the top
-- end stays present even at moderate TONE. Reference: BOSS DS-1 only
-- by name and parameter idea; no schematics, no reference source code.

ds1HpfFrame :: Sample -> Sample -> Frame -> Frame
ds1HpfFrame prevLpL prevLpR f =
  f { fL = if on then hpL else fL f
    , fR = if on then hpR else fR f
    , fEqLowL = lpL
    , fEqLowR = lpR }
 where
  on = ds1On f
  -- Moderate input low cut; TIGHT range 4..23 (between TS and metal).
  alpha = 4 + (distTight (fOd f) `shiftR` 4)
  lpL = onePoleU8 alpha prevLpL (fL f)
  lpR = onePoleU8 alpha prevLpR (fR f)
  hpL = satWide (resize (fL f) - resize lpL :: Wide)
  hpR = satWide (resize (fR f) - resize lpR :: Wide)

ds1MulFrame :: Frame -> Frame
ds1MulFrame f =
  f { fAccL = if on then mulU12 (fL f) gain else 0
    , fAccR = if on then mulU12 (fR f) gain else 0 }
 where
  on = ds1On f
  drive = ctrlC (fDist f)
  -- Q8 gain ~1x..~9x. A bit more push than TS, less than metal.
  gain = resize (256 + (resize drive * 8 :: Unsigned 12)) :: Unsigned 12

ds1ClipFrame :: Frame -> Frame
ds1ClipFrame f =
  f { fL = if on then asymSoftClip kneeP kneeN boostedL else fL f
    , fR = if on then asymSoftClip kneeP kneeN boostedR else fR f }
 where
  on = ds1On f
  boostedL = satShift8 (fAccL f)
  boostedR = satShift8 (fAccR f)
  -- Lower knees than TS for a harder edge but still soft (DS-1 has
  -- diode-pair hard clip; we approximate with asym soft to keep
  -- timing comparable to the existing pedals).
  kneeP = 2_400_000 :: Sample
  kneeN = 2_000_000 :: Sample

ds1ToneFrame :: Sample -> Sample -> Frame -> Frame
ds1ToneFrame prevLpL prevLpR f =
  f { fL = if on then lpL else fL f
    , fR = if on then lpR else fR f
    , fEqHighLpL = lpL
    , fEqHighLpR = lpR }
 where
  on = ds1On f
  tone = ctrlA (fDist f)
  -- Brighter than TS; range 96..223 -> top end stays present at every
  -- TONE setting but never reaches full pass-through.
  alpha = 96 + (tone `shiftR` 1)
  lpL = onePoleU8 alpha prevLpL (fL f)
  lpR = onePoleU8 alpha prevLpR (fR f)

ds1LevelFrame :: Frame -> Frame
ds1LevelFrame f =
  f { fL = if on then softClipK safetyKnee leftAfter else fL f
    , fR = if on then softClipK safetyKnee rightAfter else fR f }
 where
  on = ds1On f
  level = ctrlB (fDist f)
  leftAfter = satShift7 (mulU8 (fL f) level)
  rightAfter = satShift7 (mulU8 (fR f) level)
  -- Output safety: the level stage soft-clips before reaching the
  -- post-pedal pipeline so a misuse of LEVEL cannot slam the saturator.
  safetyKnee = 3_000_000 :: Sample

-- ---- big_muff (Big Muff Pi style; 5 stages: pre-gain, clip1, clip2,
--                tone scoop, level+safety) ----------------------------
--
-- Voiced for thick fuzz/distortion: heavier pre gain than DS-1, two
-- cascaded soft clip stages for sustaining wall-of-sound saturation,
-- a darker tone LPF to keep fizz off the top end. Reference:
-- Electro-Harmonix Big Muff Pi only by name and parameter idea; no
-- schematics, no reference source code.

bigMuffPreFrame :: Frame -> Frame
bigMuffPreFrame f =
  f { fAccL = if on then mulU12 (fL f) gain else 0
    , fAccR = if on then mulU12 (fR f) gain else 0 }
 where
  on = bigMuffOn f
  drive = ctrlC (fDist f)
  -- Q8 gain ~1.5x..~13x. Big Muff has lots of pre-gain; floor 384 so
  -- even drive=0 already saturates lightly through the cascaded clips.
  gain = resize (384 + (resize drive * 12 :: Unsigned 12)) :: Unsigned 12

bigMuffClip1Frame :: Frame -> Frame
bigMuffClip1Frame f =
  f { fL = if on then softClipK kneeFirst boostedL else fL f
    , fR = if on then softClipK kneeFirst boostedR else fR f }
 where
  on = bigMuffOn f
  boostedL = satShift8 (fAccL f)
  boostedR = satShift8 (fAccR f)
  -- First clip stage: medium knee, soft slope to keep some sustain.
  kneeFirst = 2_700_000 :: Sample

bigMuffClip2Frame :: Frame -> Frame
bigMuffClip2Frame f =
  f { fL = if on then softClipK kneeSecond afterMoreL else fL f
    , fR = if on then softClipK kneeSecond afterMoreR else fR f }
 where
  on = bigMuffOn f
  -- Second pass through a lighter (~0.75x via Q8 192) gain ahead of a
  -- tighter knee. Cascaded soft clips give the Muff its characteristic
  -- thick saturation without a hard wall.
  afterMoreL = satShift8 (mulU8 (fL f) 192)
  afterMoreR = satShift8 (mulU8 (fR f) 192)
  kneeSecond = 2_000_000 :: Sample

bigMuffToneFrame :: Sample -> Sample -> Frame -> Frame
bigMuffToneFrame prevLpL prevLpR f =
  f { fL = if on then lpL else fL f
    , fR = if on then lpR else fR f
    , fEqHighLpL = lpL
    , fEqHighLpR = lpR }
 where
  on = bigMuffOn f
  tone = ctrlA (fDist f)
  -- Darker tone curve: alpha range 56..183 keeps top-end fizz off the
  -- output even at TONE=100 (still brighter than TS at high TONE).
  alpha = 56 + (tone `shiftR` 1)
  lpL = onePoleU8 alpha prevLpL (fL f)
  lpR = onePoleU8 alpha prevLpR (fR f)

bigMuffLevelFrame :: Frame -> Frame
bigMuffLevelFrame f =
  f { fL = if on then softClipK safetyKnee leftAfter else fL f
    , fR = if on then softClipK safetyKnee rightAfter else fR f }
 where
  on = bigMuffOn f
  level = ctrlB (fDist f)
  leftAfter = satShift7 (mulU8 (fL f) level)
  rightAfter = satShift7 (mulU8 (fR f) level)
  -- Output safety knee, slightly tighter than DS-1 because Muff drives
  -- a hotter signal into this stage.
  safetyKnee = 2_900_000 :: Sample

-- ---- fuzz_face (Fuzz Face style; 4 stages: pre-gain, asym clip,
--                tone, level+safety) ----------------------------------
--
-- Voiced for raw, asymmetric fuzz: the pre stage already has a hot
-- floor so even DRIVE=0 produces some breakup, the clip stage uses
-- aggressively low asymmetric knees so the negative half compresses
-- harder than the positive half, and the tone LPF maps to a
-- "round vs. bright" axis since real Fuzz Faces typically have no
-- tone control. Reference: Dallas Arbiter / Dunlop Fuzz Face only by
-- name and parameter idea; no schematics, no reference source code.

fuzzFacePreFrame :: Frame -> Frame
fuzzFacePreFrame f =
  f { fAccL = if on then mulU12 (fL f) gain else 0
    , fAccR = if on then mulU12 (fR f) gain else 0 }
 where
  on = fuzzFaceOn f
  drive = ctrlC (fDist f)
  -- Q8 gain ~2x..~10x. Floor 512 so the fuzz is sensitive to input
  -- level even at drive=0 (Fuzz Faces are notoriously touch-sensitive).
  gain = resize (512 + (resize drive * 9 :: Unsigned 12)) :: Unsigned 12

fuzzFaceClipFrame :: Frame -> Frame
fuzzFaceClipFrame f =
  f { fL = if on then asymSoftClip kneeP kneeN boostedL else fL f
    , fR = if on then asymSoftClip kneeP kneeN boostedR else fR f }
 where
  on = fuzzFaceOn f
  boostedL = satShift8 (fAccL f)
  boostedR = satShift8 (fAccR f)
  -- Strong asymmetry: the negative half compresses harder, giving the
  -- broken-up germanium-style waveform shape.
  kneeP = 1_900_000 :: Sample
  kneeN = 1_400_000 :: Sample

fuzzFaceToneFrame :: Sample -> Sample -> Frame -> Frame
fuzzFaceToneFrame prevLpL prevLpR f =
  f { fL = if on then lpL else fL f
    , fR = if on then lpR else fR f
    , fEqHighLpL = lpL
    , fEqHighLpR = lpR }
 where
  on = fuzzFaceOn f
  tone = ctrlA (fDist f)
  -- "Round vs. bright": alpha range 72..199 -> TONE=0 is round and
  -- woolly, TONE=100 brightens up but still rolls off the very top.
  alpha = 72 + (tone `shiftR` 1)
  lpL = onePoleU8 alpha prevLpL (fL f)
  lpR = onePoleU8 alpha prevLpR (fR f)

fuzzFaceLevelFrame :: Frame -> Frame
fuzzFaceLevelFrame f =
  f { fL = if on then softClipK safetyKnee leftAfter else fL f
    , fR = if on then softClipK safetyKnee rightAfter else fR f }
 where
  on = fuzzFaceOn f
  level = ctrlB (fDist f)
  leftAfter = satShift7 (mulU8 (fL f) level)
  rightAfter = satShift7 (mulU8 (fR f) level)
  -- Output safety knee tighter than DS-1 / Big Muff because the fuzz
  -- stage produces hotter peaks.
  safetyKnee = 2_800_000 :: Sample

ratHighpassFrame :: Sample -> Sample -> Sample -> Sample -> Frame -> Frame
ratHighpassFrame prevInL prevInR prevOutL prevOutR f =
  f
    { fDryL = fL f
    , fDryR = fR f
    , fWetL = if on then highpass (fL f) prevInL prevOutL else fL f
    , fWetR = if on then highpass (fR f) prevInR prevOutR else fR f
    }
 where
  on = flag4 (fGate f)
  highpass x prevIn prevOut =
    satWide (resize x - resize prevIn + ((resize prevOut :: Wide) * 254 `shiftR` 8))

ratDriveMultiplyFrame :: Frame -> Frame
ratDriveMultiplyFrame f =
  f{fAccL = if on then mulU12 (fWetL f) driveGain else 0, fAccR = if on then mulU12 (fWetR f) driveGain else 0}
 where
  on = flag4 (fGate f)
  driveGain = resize (512 + (resize (ctrlC (fRat f)) * 14 :: Unsigned 12)) :: Unsigned 12

ratDriveBoostFrame :: Frame -> Frame
ratDriveBoostFrame f =
  f{fWetL = if on then satShift8 (fAccL f) else fL f, fWetR = if on then satShift8 (fAccR f) else fR f}
 where
  on = flag4 (fGate f)

ratOpAmpLowpassFrame :: Sample -> Sample -> Frame -> Frame
ratOpAmpLowpassFrame prevL prevR f =
  f{fWetL = if on then lowL else fL f, fWetR = if on then lowR else fR f}
 where
  on = flag4 (fGate f)
  alpha = 192 - resize (ctrlC (fRat f) `shiftR` 1) :: Unsigned 8
  lowL = onePoleU8 alpha prevL (fWetL f)
  lowR = onePoleU8 alpha prevR (fWetR f)

ratClipFrame :: Frame -> Frame
ratClipFrame f =
  f{fWetL = if on then hardClip (fWetL f) threshold else fL f, fWetR = if on then hardClip (fWetR f) threshold else fR f}
 where
  on = flag4 (fGate f)
  amount = ctrlC (fRat f)
  -- Real-pedal voicing pass: lower the clamp floor so the hard clip
  -- engages more aggressively at high DRIVE. Floor was 3.75M; at
  -- 2.5M the clip stage saturates harder, giving the RAT more "rude"
  -- character at the top of the DRIVE knob.
  rawThreshold = 6_291_456 - (resize (asSigned9 amount) * 9_000) :: Signed 25
  clampedThreshold = if rawThreshold < 2_500_000 then 2_500_000 else rawThreshold
  threshold = resize clampedThreshold :: Sample

ratPostLowpassFrame :: Sample -> Sample -> Frame -> Frame
-- Real-pedal voicing pass: alpha lowered from 192 to 176 so a touch
-- more high-frequency content is rolled off after the hard clip,
-- matching the darker top end of a real RAT.
ratPostLowpassFrame prevL prevR f =
  f{fWetL = if on then onePoleU8 176 prevL (fWetL f) else fL f, fWetR = if on then onePoleU8 176 prevR (fWetR f) else fR f}
 where
  on = flag4 (fGate f)

ratToneFrame :: Sample -> Sample -> Frame -> Frame
ratToneFrame prevL prevR f =
  f{fWetL = if on then onePoleU8 alpha prevL (fWetL f) else fL f, fWetR = if on then onePoleU8 alpha prevR (fWetR f) else fR f}
 where
  on = flag4 (fGate f)
  dark = resize ((resize (ctrlA (fRat f)) * 3 :: Unsigned 10) `shiftR` 2) :: Unsigned 8
  -- Real-pedal voicing pass: shift the FILTER (TONE) range so even
  -- fully bright still has some upper roll-off (alpha base 200 vs 224).
  alpha = 200 - dark

ratLevelFrame :: Frame -> Frame
ratLevelFrame f =
  f{fWetL = if on then left else fL f, fWetR = if on then right else fR f}
 where
  on = flag4 (fGate f)
  level = ctrlB (fRat f)
  left = satShift7 (mulU8 (fWetL f) level)
  right = satShift7 (mulU8 (fWetR f) level)

ratMixFrame :: Frame -> Frame
ratMixFrame f =
  f{fL = if on then softClip mixedL else fL f, fR = if on then softClip mixedR else fR f}
 where
  on = flag4 (fGate f)
  mix = ctrlD (fRat f)
  invMix = 255 - mix
  mixedL = satShift8 (mulU8 (fDryL f) invMix + mulU8 (fWetL f) mix)
  mixedR = satShift8 (mulU8 (fDryR f) invMix + mulU8 (fWetR f) mix)

ampHighpassFrame :: Sample -> Sample -> Sample -> Sample -> Frame -> Frame
ampHighpassFrame prevInL prevInR prevOutL prevOutR f =
  f
    { fDryL = fL f
    , fDryR = fR f
    , fWetL = if on then highpass (fL f) prevInL prevOutL else fL f
    , fWetR = if on then highpass (fR f) prevInR prevOutR else fR f
    }
 where
  on = flag6 (fGate f)
  highpass x prevIn prevOut =
    satWide (resize x - resize prevIn + ((resize prevOut :: Wide) * 253 `shiftR` 8))

ampDriveMultiplyFrame :: Frame -> Frame
ampDriveMultiplyFrame f =
  f{fAccL = if on then mulU12 (fWetL f) gain else 0, fAccR = if on then mulU12 (fWetR f) gain else 0}
 where
  on = flag6 (fGate f)
  -- 1.0x to about 19x using Q7-style post shift. The recording-analysis
  -- pass trims the ceiling again so Amp-only and post-pedal use do not
  -- create line-direct fizz before the cabinet stage.
  gain = resize (128 + (resize (ctrlA (fAmp f)) * 9 :: Unsigned 12)) :: Unsigned 12

ampDriveBoostFrame :: Frame -> Frame
ampDriveBoostFrame f =
  f{fWetL = if on then satShift7 (fAccL f) else fL f, fWetR = if on then satShift7 (fAccR f) else fR f}
 where
  on = flag6 (fGate f)

ampAsymClip :: Unsigned 8 -> Sample -> Sample
ampAsymClip character x
  | x > positiveKnee = satWide (resize (resize positiveKnee + (((resize x :: Signed 25) - resize positiveKnee) `shiftR` 2) :: Signed 25))
  | x < negate negativeKnee = satWide (resize (resize (negate negativeKnee) + (((resize x :: Signed 25) + resize negativeKnee) `shiftR` 3) :: Signed 25))
  | otherwise = x
 where
  ch = resize (asSigned9 character) :: Signed 25
  -- Lower knees at high character give a rougher, less symmetric preamp.
  positiveKnee = resize (4_900_000 - ch * 7_000) :: Sample
  negativeKnee = resize (4_350_000 - ch * 6_200) :: Sample

ampWaveshapeFrame :: Frame -> Frame
ampWaveshapeFrame f =
  f{fWetL = if on then ampAsymClip character (fWetL f) else fL f, fWetR = if on then ampAsymClip character (fWetR f) else fR f}
 where
  on = flag6 (fGate f)
  character = ctrlD (fAmpTone f)

-- | Quantise the amp character byte (0..255) into a 2-bit "amp model"
-- index that distinguishes four named voicings. Bands match the
-- Python AMP_MODELS table so the labelled character values
--   jc_clean = 10  -> byte  26 -> model 0
--   clean_combo = 35 -> byte  89 -> model 1
--   british_crunch = 60 -> byte 153 -> model 2
--   high_gain_stack = 85 -> byte 216 -> model 3
-- land in the centre of each band. Cheap: two compares, one mux per
-- step; the result is only consumed by the pre-LPF darken below, so
-- combinational depth elsewhere is unaffected.
ampModelSel :: Unsigned 8 -> Unsigned 2
ampModelSel x
  | x < 63    = 0
  | x < 126   = 1
  | x < 190   = 2
  | otherwise = 3

ampPreLowpassFrame :: Sample -> Sample -> Frame -> Frame
ampPreLowpassFrame prevL prevR f =
  f{fWetL = if on then onePoleU8 alpha prevL (fWetL f) else fL f, fWetR = if on then onePoleU8 alpha prevR (fWetR f) else fR f}
 where
  on = flag6 (fGate f)
  charByte = ctrlD (fAmpTone f)
  -- Higher character keeps edge, but the maximum alpha is capped lower
  -- than the previous voicing so high-gain settings shed more >5 kHz fizz.
  baseAlpha = 128 + (charByte `shiftR` 2)
  -- Per-amp-model extra darken on top of the audio-analysis pass.
  -- Model 0 (JC Clean) keeps the brightest edge; model 3
  -- (High Gain Stack) rolls off the most so high-gain pedals into the
  -- amp do not produce the second brightening that the audio-analysis
  -- recordings flagged. All four steps stay inside the safe alpha
  -- band (>=112) so the LPF never inverts.
  modelDarken = case ampModelSel charByte of
    0 ->  0 :: Unsigned 8
    1 ->  2
    2 ->  8
    _ -> 16
  alpha = baseAlpha - modelDarken

ampSecondStageMultiplyFrame :: Frame -> Frame
ampSecondStageMultiplyFrame f =
  f{fAccL = if on then mulU9 (fWetL f) gain else 0, fAccR = if on then mulU9 (fWetR f) gain else 0}
 where
  on = flag6 (fGate f)
  gain = resize (112 + (ctrlA (fAmp f) `shiftR` 3) + (ctrlD (fAmpTone f) `shiftR` 2)) :: Unsigned 9

ampSecondStageFrame :: Frame -> Frame
ampSecondStageFrame f =
  f{fWetL = if on then ampAsymClip character (satShift7 (fAccL f)) else fL f, fWetR = if on then ampAsymClip character (satShift7 (fAccR f)) else fR f}
 where
  on = flag6 (fGate f)
  -- Softer than the first clip stage; keeps low-gain response touch-sensitive.
  character = ctrlD (fAmpTone f) `shiftR` 1

ampToneFilterFrame :: Sample -> Sample -> Sample -> Sample -> Frame -> Frame
ampToneFilterFrame prevLowL prevLowR prevHighLpL prevHighLpR f =
  f
    { fEqLowL = lowL
    , fEqLowR = lowR
    , fEqHighLpL = highLpL
    , fEqHighLpR = highLpR
    }
 where
  left = fWetL f
  right = fWetR f
  lowL = prevLowL + resize (((resize left - resize prevLowL) :: Signed 25) `shiftR` 5)
  lowR = prevLowR + resize (((resize right - resize prevLowR) :: Signed 25) `shiftR` 5)
  highLpL = prevHighLpL + resize (((resize left - resize prevHighLpL) :: Signed 25) `shiftR` 2)
  highLpR = prevHighLpR + resize (((resize right - resize prevHighLpR) :: Signed 25) `shiftR` 2)

ampToneBandFrame :: Frame -> Frame
ampToneBandFrame f =
  f
    { fEqMidL = satWide (resize (fEqHighLpL f) - resize (fEqLowL f))
    , fEqMidR = satWide (resize (fEqHighLpR f) - resize (fEqLowR f))
    , fEqHighL = satWide (resize (fWetL f) - resize (fEqHighLpL f))
    , fEqHighR = satWide (resize (fWetR f) - resize (fEqHighLpR f))
    }

ampToneGain :: Unsigned 8 -> Unsigned 8
ampToneGain x = 64 + (x `shiftR` 1)

ampTrebleGain :: Unsigned 8 -> Unsigned 8
ampTrebleGain x = 64 + ((x - (x `shiftR` 3)) `shiftR` 1)

ampToneProductsFrame :: Frame -> Frame
ampToneProductsFrame f =
  f
    { fAccL = if on then mulU8 (fEqLowL f) (ampToneGain (ctrlA (fAmpTone f))) else 0
    , fAccR = if on then mulU8 (fEqLowR f) (ampToneGain (ctrlA (fAmpTone f))) else 0
    , fAcc2L = if on then mulU8 (fEqMidL f) (ampToneGain (ctrlB (fAmpTone f))) else 0
    , fAcc2R = if on then mulU8 (fEqMidR f) (ampToneGain (ctrlB (fAmpTone f))) else 0
    , fAcc3L = if on then mulU8 (fEqHighL f) (ampTrebleGain (ctrlC (fAmpTone f))) else 0
    , fAcc3R = if on then mulU8 (fEqHighR f) (ampTrebleGain (ctrlC (fAmpTone f))) else 0
    }
 where
  on = flag6 (fGate f)

ampToneMixFrame :: Frame -> Frame
ampToneMixFrame f =
  f{fWetL = if on then satShift7 accL else fL f, fWetR = if on then satShift7 accR else fR f}
 where
  on = flag6 (fGate f)
  accL = fAccL f + fAcc2L f + fAcc3L f
  accR = fAccR f + fAcc2R f + fAcc3R f

ampPowerFrame :: Frame -> Frame
ampPowerFrame f =
  f{fWetL = if on then softClipK 3_500_000 (fWetL f) else fL f, fWetR = if on then softClipK 3_500_000 (fWetR f) else fR f}
 where
  on = flag6 (fGate f)

ampResPresenceFilterFrame :: Sample -> Sample -> Sample -> Sample -> Frame -> Frame
ampResPresenceFilterFrame prevResL prevResR prevPresenceL prevPresenceR f =
  f
    { fEqLowL = resL
    , fEqLowR = resR
    , fEqHighLpL = presenceLpL
    , fEqHighLpR = presenceLpR
    }
 where
  left = fWetL f
  right = fWetR f
  -- Slow lowpass approximates resonance around the speaker low-end region.
  resL = prevResL + resize (((resize left - resize prevResL) :: Signed 25) `shiftR` 8)
  resR = prevResR + resize (((resize right - resize prevResR) :: Signed 25) `shiftR` 8)
  presenceLpL = prevPresenceL + resize (((resize left - resize prevPresenceL) :: Signed 25) `shiftR` 3)
  presenceLpR = prevPresenceR + resize (((resize right - resize prevPresenceR) :: Signed 25) `shiftR` 3)

ampResPresenceMixFrame :: Frame -> Frame
ampResPresenceMixFrame f =
  f{fWetL = if on then softClipK 3_500_000 wetL else fL f, fWetR = if on then softClipK 3_500_000 wetR else fR f}
 where
  on = flag6 (fGate f)
  wetL = satWide (fAccL f + satShift10Wide (fAcc2L f) + satShift9Wide (fAcc3L f))
  wetR = satWide (fAccR f + satShift10Wide (fAcc2R f) + satShift9Wide (fAcc3R f))

ampResPresenceProductsFrame :: Frame -> Frame
ampResPresenceProductsFrame f =
  f
    { fEqHighL = highL
    , fEqHighR = highR
    , fAccL = if on then resize (fWetL f) else 0
    , fAccR = if on then resize (fWetR f) else 0
    , fAcc2L = if on then mulU8 (fEqLowL f) resonance else 0
    , fAcc2R = if on then mulU8 (fEqLowR f) resonance else 0
    , fAcc3L = if on then mulU8 highL presence else 0
    , fAcc3R = if on then mulU8 highR presence else 0
    }
 where
  on = flag6 (fGate f)
  resonance = ctrlD (fAmp f) - (ctrlD (fAmp f) `shiftR` 2)
  presence = ctrlC (fAmp f) - (ctrlC (fAmp f) `shiftR` 2) - (ctrlC (fAmp f) `shiftR` 3)
  highL = satWide (resize (fWetL f) - resize (fEqHighLpL f))
  highR = satWide (resize (fWetR f) - resize (fEqHighLpR f))

satShift9Wide :: Wide -> Wide
satShift9Wide = resize . satShift9

satShift10Wide :: Wide -> Wide
satShift10Wide = resize . satShift10

ampMasterFrame :: Frame -> Frame
ampMasterFrame f =
  f{fL = if on then left else fL f, fR = if on then right else fR f}
 where
  on = flag6 (fGate f)
  level = ctrlB (fAmp f)
  left = softClipK 3_300_000 (satShift7 (mulU8 (fWetL f) level))
  right = softClipK 3_300_000 (satShift7 (mulU8 (fWetR f) level))

cabCoeff :: Unsigned 8 -> Unsigned 8 -> Unsigned 2 -> Signed 10
-- Audio-analysis voicing pass: keep the existing 4-tap cabinet stage
-- but make model separation and >5 kHz roll-off stronger. Model 0 is
-- lighter/open-back, model 1 is the balanced combo, and model 2 pushes
-- weight into delayed taps so high-gain fizz is damped hardest. AIR
-- restores only capped direct-tap content; it never becomes raw line.
cabCoeff model air index =
  case modelSel of
    0 -> openBack index
    1 -> british index
    _ -> closedBack index
 where
  modelSel = model `shiftR` 6
  airSel :: Unsigned 2
  airSel = if air < 86 then 0 else if air < 171 then 1 else 2
  openBack i =
    case airSel of
      0 -> case i of
        0 -> 70
        1 -> 86
        2 -> 58
        _ -> 14
      1 -> case i of
        0 -> 78
        1 -> 82
        2 -> 54
        _ -> 12
      _ -> case i of
        0 -> 86
        1 -> 78
        2 -> 48
        _ -> 8
  british i =
    case airSel of
      0 -> case i of
        0 -> 62
        1 -> 86
        2 -> 78
        _ -> 34
      1 -> case i of
        0 -> 68
        1 -> 84
        2 -> 74
        _ -> 30
      _ -> case i of
        0 -> 74
        1 -> 82
        2 -> 68
        _ -> 24
  closedBack i =
    case airSel of
      0 -> case i of
        0 -> 44
        1 -> 78
        2 -> 96
        _ -> 82
      1 -> case i of
        0 -> 50
        1 -> 82
        2 -> 94
        _ -> 70
      _ -> case i of
        0 -> 56
        1 -> 86
        2 -> 90
        _ -> 60

cabProductsFrame ::
  Sample -> Sample -> Sample ->
  Sample -> Sample -> Sample ->
  Frame -> Frame
cabProductsFrame d1L d2L d3L d1R d2R d3R f =
  f
    { fAccL = if on then earlyL else 0
    , fAccR = if on then earlyR else 0
    , fAcc2L = if on then bodyL else 0
    , fAcc2R = if on then bodyR else 0
    , fAcc3L = 0
    , fAcc3R = 0
    }
 where
  on = flag7 (fGate f)
  model = ctrlC (fCab f)
  air = ctrlD (fCab f)
  c0 = cabCoeff model air 0
  c1 = cabCoeff model air 1
  c2 = cabCoeff model air 2
  c3 = cabCoeff model air 3
  earlyL = mulS10 (fL f) c0 + mulS10 d1L c1
  earlyR = mulS10 (fR f) c0 + mulS10 d1R c1
  bodyL = mulS10 d2L c2 + mulS10 d3L c3
  bodyR = mulS10 d2R c2 + mulS10 d3R c3

cabIrFrame :: Frame -> Frame
cabIrFrame f =
  f{fWetL = if on then wetL else fL f, fWetR = if on then wetR else fR f}
 where
  on = flag7 (fGate f)
  wetL = satShift8 (fAccL f + fAcc2L f + fAcc3L f)
  wetR = satShift8 (fAccR f + fAcc2R f + fAcc3R f)

cabLevelMixFrame :: Frame -> Frame
cabLevelMixFrame f =
  f{fL = if on then softClip mixedL else fL f, fR = if on then softClip mixedR else fR f}
 where
  on = flag7 (fGate f)
  mix = ctrlA (fCab f)
  invMix = 255 - mix
  level = ctrlB (fCab f)
  wetL = satShift7 (mulU8 (fWetL f) level)
  wetR = satShift7 (mulU8 (fWetR f) level)
  mixedL = satShift8 (mulU8 (fL f) invMix + mulU8 wetL mix)
  mixedR = satShift8 (mulU8 (fR f) invMix + mulU8 wetR mix)

eqFilterFrame :: Sample -> Sample -> Sample -> Sample -> Frame -> Frame
eqFilterFrame prevLowL prevLowR prevHighLpL prevHighLpR f =
  f
    { fEqLowL = lowL
    , fEqLowR = lowR
    , fEqHighLpL = highLpL
    , fEqHighLpR = highLpR
    }
 where
  left = fL f
  right = fR f
  lowL = prevLowL + resize (((resize left - resize prevLowL) :: Signed 25) `shiftR` 5)
  lowR = prevLowR + resize (((resize right - resize prevLowR) :: Signed 25) `shiftR` 5)
  highLpL = prevHighLpL + resize (((resize left - resize prevHighLpL) :: Signed 25) `shiftR` 2)
  highLpR = prevHighLpR + resize (((resize right - resize prevHighLpR) :: Signed 25) `shiftR` 2)

eqBandFrame :: Frame -> Frame
eqBandFrame f =
  f
    { fEqMidL = satWide (resize (fEqHighLpL f) - resize (fEqLowL f))
    , fEqMidR = satWide (resize (fEqHighLpR f) - resize (fEqLowR f))
    , fEqHighL = satWide (resize (fL f) - resize (fEqHighLpL f))
    , fEqHighR = satWide (resize (fR f) - resize (fEqHighLpR f))
    }

eqProductsFrame :: Frame -> Frame
eqProductsFrame f =
  f
    { fAccL = if on then mulU8 (fEqLowL f) (ctrlA (fEq f)) else 0
    , fAccR = if on then mulU8 (fEqLowR f) (ctrlA (fEq f)) else 0
    , fAcc2L = if on then mulU8 (fEqMidL f) (ctrlB (fEq f)) else 0
    , fAcc2R = if on then mulU8 (fEqMidR f) (ctrlB (fEq f)) else 0
    , fAcc3L = if on then mulU8 (fEqHighL f) (ctrlC (fEq f)) else 0
    , fAcc3R = if on then mulU8 (fEqHighR f) (ctrlC (fEq f)) else 0
    }
 where
  on = flag3 (fGate f)

eqMixFrame :: Frame -> Frame
-- Real-pedal voicing pass: wrap the post-EQ sum in softClip so a
-- max-boost on all three bands saturates softly instead of slamming
-- the satShift7 saturator (audible hard clip). softClip is identity
-- below its knee, so neutral 128/128/128 EQ remains bit-exact (apart
-- from the standard satShift7 round-trip).
eqMixFrame f =
  f{fL = if on then softClip (satShift7 accL) else fL f, fR = if on then softClip (satShift7 accR) else fR f}
 where
  on = flag3 (fGate f)
  accL = fAccL f + fAcc2L f + fAcc3L f
  accR = fAccR f + fAcc2R f + fAcc3R f

attachAddr :: ReverbAddr -> Maybe Frame -> Maybe Frame
attachAddr _ Nothing = Nothing
attachAddr addr (Just f) = Just f{fAddr = addr, fDryL = fL f, fDryR = fR f}

addrNext :: ReverbAddr -> Maybe Frame -> ReverbAddr
addrNext addr pipe = if isActive pipe then advanceAddr addr else addr

reverbToneProductsFrame :: Sample -> Sample -> Sample -> Sample -> Maybe Frame -> Maybe Frame
-- Real-pedal voicing pass: scale the tone byte by 7/8 so the maximum
-- bright setting is ~224 instead of 255. This keeps a small slice
-- (~12.5%) of the previous tap mixed in at every TONE setting,
-- providing some high-frequency damping in the recirculation path so
-- long tails do not turn metallic.
reverbToneProductsFrame tapL tapR prevL prevR = mapPipe applyTone
 where
  applyTone f =
    let tone       = ctrlB (fReverb f)
        toneScaled = tone - (tone `shiftR` 3)
        invTone    = 255 - toneScaled
    in f
      { fAccL = mulU8 tapL toneScaled
      , fAccR = mulU8 tapR toneScaled
      , fAcc2L = mulU8 prevL invTone
      , fAcc2R = mulU8 prevR invTone
      }

reverbToneBlendFrame :: Frame -> Frame
reverbToneBlendFrame f =
  f{fWetL = satShift8 (fAccL f + fAcc2L f), fWetR = satShift8 (fAccR f + fAcc2R f)}

reverbFeedbackProductsFrame :: Frame -> Frame
reverbFeedbackProductsFrame f =
  f{fAcc3L = if on then mulU8 (fWetL f) (ctrlA (fReverb f)) else 0, fAcc3R = if on then mulU8 (fWetR f) (ctrlA (fReverb f)) else 0}
 where
  on = flag5 (fGate f)

reverbFeedbackFrame :: Frame -> Frame
reverbFeedbackFrame f =
  f{fFbL = if on then feedbackL else 0, fFbR = if on then feedbackR else 0}
 where
  on = flag5 (fGate f)
  feedbackL = satWide ((resize (fDryL f) `shiftR` 1) + (fAcc3L f `shiftR` 8))
  feedbackR = satWide ((resize (fDryR f) `shiftR` 1) + (fAcc3R f `shiftR` 8))

reverbMixProductsFrame :: Frame -> Frame
reverbMixProductsFrame f =
  f
    { fAccL = if on then mulU9 (fDryL f) invMixGain else 0
    , fAccR = if on then mulU9 (fDryR f) invMixGain else 0
    , fAcc2L = if on then mulU8 (fWetL f) mixGain else 0
    , fAcc2R = if on then mulU8 (fWetR f) mixGain else 0
    }
 where
  on = flag5 (fGate f)
  mixGain = ctrlC (fReverb f)
  invMixGain = 256 - resize mixGain :: Unsigned 9

reverbMixFrame :: Frame -> Frame
reverbMixFrame f =
  f{fL = if on then mixedL else fDryL f, fR = if on then mixedR else fDryR f}
 where
  on = flag5 (fGate f)
  mixedL = satShift8 (fAccL f + fAcc2L f)
  mixedR = satShift8 (fAccR f + fAcc2R f)

writeReverbL :: Maybe Frame -> Maybe (ReverbAddr, Sample)
writeReverbL Nothing = Nothing
writeReverbL (Just f) = Just (fAddr f, fFbL f)

writeReverbR :: Maybe Frame -> Maybe (ReverbAddr, Sample)
writeReverbR Nothing = Nothing
writeReverbR (Just f) = Just (fAddr f, fFbR f)

pipeData :: Maybe Frame -> BitVector 48
pipeData Nothing = 0
pipeData (Just f) = packChan (fL f) (fR f)

pipeLast :: Maybe Frame -> Bool
pipeLast Nothing = False
pipeLast (Just f) = fLast f

pipeOut :: Maybe Frame -> AxisOut
pipeOut pipe = AxisOut{ oData = pipeData pipe, oValid = isActive pipe, oLast = pipeLast pipe }

nextAxisOut :: AxisOut -> Maybe Frame -> Bool -> AxisOut
nextAxisOut old pipe readyOut =
  if loadNew
    then new
    else if consumed then emptyAxisOut else old
 where
  new = pipeOut pipe
  consumed = oValid old && readyOut
  loadNew = oValid new && (not (oValid old) || consumed)

{-# ANN topEntity
  (Synthesize
    { t_name   = "clash_lowpass_fir"
    , t_inputs = [ PortName "clk"
                 , PortName "aresetn"
                 , PortName "gate_control"
                 , PortName "overdrive_control"
                 , PortName "distortion_control"
                 , PortName "eq_control"
                 , PortName "delay_control"
                 , PortName "amp_control"
                 , PortName "amp_tone_control"
                 , PortName "cab_control"
                 , PortName "reverb_control"
                 , PortName "noise_suppressor_control"
                 , PortName "compressor_control"
                 , PortName "axis_in_tdata"
                 , PortName "axis_in_tvalid"
                 , PortName "axis_in_tlast"
                 , PortName "axis_out_tready"
                 ]
    , t_output = PortProduct "" [PortName "axis_out_tdata"
                                ,PortName "axis_out_tvalid"
                                ,PortName "axis_out_tlast"
                                ,PortName "axis_in_tready"
                                ]
    }) #-}
topEntity
  :: Clock AudioDomain
  -> Reset AudioDomain
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain (BitVector 48)
  -> Signal AudioDomain Bool
  -> Signal AudioDomain Bool
  -> Signal AudioDomain Bool
  -> ( Signal AudioDomain (BitVector 48)
     , Signal AudioDomain Bool
     , Signal AudioDomain Bool
     , Signal AudioDomain Bool
     )
topEntity clk rst gateControl odControl distControl eqControl ratControl ampControl ampToneControl cabControl reverbControl nsControl compControl samples validIn lastIn readyOut =
  withClockResetEnable clk rst enableGen $
    fxPipeline gateControl odControl distControl eqControl ratControl ampControl ampToneControl cabControl reverbControl nsControl compControl samples validIn lastIn readyOut

fxPipeline
  :: HiddenClockResetEnable AudioDomain
  => Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain (BitVector 48)
  -> Signal AudioDomain Bool
  -> Signal AudioDomain Bool
  -> Signal AudioDomain Bool
  -> ( Signal AudioDomain (BitVector 48)
     , Signal AudioDomain Bool
     , Signal AudioDomain Bool
     , Signal AudioDomain Bool
     )
fxPipeline gateControl odControl distControl eqControl ratControl ampControl ampToneControl cabControl reverbControl nsControl compControl samples validIn lastIn readyOut =
  pipeline
 where
  pipeline =
    ( oData <$> outReg
    , oValid <$> outReg
    , oLast <$> outReg
    , readyOut
    )

  acceptedIn = (&&) <$> validIn <*> readyOut

  inPipe =
    register Nothing $
      makeInput
        <$> gateControl
        <*> odControl
        <*> distControl
        <*> eqControl
        <*> ratControl
        <*> ampControl
        <*> ampToneControl
        <*> cabControl
        <*> reverbControl
        <*> nsControl
        <*> compControl
        <*> samples
        <*> acceptedIn
        <*> lastIn

  -- Noise Suppressor pipeline. Replaces the legacy hard gate. Same
  -- shape: one envelope-input register stage, two feedback registers
  -- (envelope + smoothed gain), one apply register stage. Driven by
  -- noise_suppressor_control (THRESHOLD / DECAY / DAMP / mode); enable
  -- still rides on flag0 (noise_gate_on) of fGate so the existing
  -- set_guitar_effects() API toggles it. Bit-exact bypass when the
  -- flag is clear. The legacy gate frame helpers above are retained
  -- but unused by the active pipeline; the synthesiser drops them.
  nsLevelPipe = register Nothing (mapPipe gateLevelFrame <$> inPipe)
  nsEnv = register 0 (nsEnvNext <$> nsEnv <*> nsLevelPipe)
  nsGain = register gateUnity (nsGainNext <$> nsGain <*> nsEnv <*> nsLevelPipe)
  nsPipe = register Nothing (mapPipe <$> (nsApplyFrame <$> nsGain) <*> nsLevelPipe)

  -- Compressor pipeline. Sits between the noise suppressor and the
  -- overdrive: tightens picking before the gain stages. Same shape as
  -- the noise suppressor (one envelope-input register stage, two
  -- feedback registers, one apply stage) plus a separate makeup
  -- multiply stage so each register stage holds a single multiply.
  -- Bit-exact bypass when the enable bit (fComp ctrlD bit 7) is clear.
  compLevelPipe = register Nothing (mapPipe gateLevelFrame <$> nsPipe)
  compEnv = register 0 (compEnvNext <$> compEnv <*> compLevelPipe)
  compGain = register gateUnity (compGainNext <$> compGain <*> compEnv <*> compLevelPipe)
  compApplyPipe = register Nothing (mapPipe <$> (compApplyFrame <$> compGain) <*> compLevelPipe)
  compMakeupPipe = register Nothing (mapPipe compMakeupFrame <$> compApplyPipe)

  odDriveMulPipe = register Nothing (mapPipe overdriveDriveMultiplyFrame <$> compMakeupPipe)
  odDriveBoostPipe = register Nothing (mapPipe overdriveDriveBoostFrame <$> odDriveMulPipe)
  odDrivePipe = register Nothing (mapPipe overdriveDriveClipFrame <$> odDriveBoostPipe)

  odTonePrevL = register 0 (frameOr fWetL <$> odTonePrevL <*> odToneBlendPipe)
  odTonePrevR = register 0 (frameOr fWetR <$> odTonePrevR <*> odToneBlendPipe)
  odToneMulPipe = register Nothing (mapPipe <$> (overdriveToneMultiplyFrame <$> odTonePrevL <*> odTonePrevR) <*> odDrivePipe)
  odToneBlendPipe = register Nothing (mapPipe overdriveToneBlendFrame <$> odToneMulPipe)
  odTonePipe = register Nothing (mapPipe overdriveLevelFrame <$> odToneBlendPipe)

  -- Legacy distortion pipeline. Restored to its pre-refactor shape.
  -- Each stage is gated by `distortionLegacyOn`, which folds in the
  -- "any new pedal mask bit set?" check so that exclusive=True at the
  -- Python level really is exclusive.
  distDriveMulPipe = register Nothing (mapPipe distortionDriveMultiplyFrame <$> odTonePipe)
  distDriveBoostPipe = register Nothing (mapPipe distortionDriveBoostFrame <$> distDriveMulPipe)
  distDrivePipe = register Nothing (mapPipe distortionDriveClipFrame <$> distDriveBoostPipe)

  distTonePrevL = register 0 (frameOr fWetL <$> distTonePrevL <*> distToneBlendPipe)
  distTonePrevR = register 0 (frameOr fWetR <$> distTonePrevR <*> distToneBlendPipe)
  distToneMulPipe = register Nothing (mapPipe <$> (distortionToneMultiplyFrame <$> distTonePrevL <*> distTonePrevR) <*> distDrivePipe)
  distToneBlendPipe = register Nothing (mapPipe distortionToneBlendFrame <$> distToneMulPipe)
  distTonePipe = register Nothing (mapPipe distortionLevelFrame <$> distToneBlendPipe)

  ratHpInPrevL = register 0 (frameOr fDryL <$> ratHpInPrevL <*> ratHighpassPipe)
  ratHpInPrevR = register 0 (frameOr fDryR <$> ratHpInPrevR <*> ratHighpassPipe)
  ratHpOutPrevL = register 0 (frameOr fWetL <$> ratHpOutPrevL <*> ratHighpassPipe)
  ratHpOutPrevR = register 0 (frameOr fWetR <$> ratHpOutPrevR <*> ratHighpassPipe)
  ratHighpassPipe =
    register Nothing $
      mapPipe <$> (ratHighpassFrame <$> ratHpInPrevL <*> ratHpInPrevR <*> ratHpOutPrevL <*> ratHpOutPrevR) <*> distTonePipe
  ratDriveMulPipe = register Nothing (mapPipe ratDriveMultiplyFrame <$> ratHighpassPipe)
  ratDriveBoostPipe = register Nothing (mapPipe ratDriveBoostFrame <$> ratDriveMulPipe)

  ratOpAmpPrevL = register 0 (frameOr fWetL <$> ratOpAmpPrevL <*> ratOpAmpPipe)
  ratOpAmpPrevR = register 0 (frameOr fWetR <$> ratOpAmpPrevR <*> ratOpAmpPipe)
  ratOpAmpPipe = register Nothing (mapPipe <$> (ratOpAmpLowpassFrame <$> ratOpAmpPrevL <*> ratOpAmpPrevR) <*> ratDriveBoostPipe)
  ratClipPipe = register Nothing (mapPipe ratClipFrame <$> ratOpAmpPipe)

  ratPostPrevL = register 0 (frameOr fWetL <$> ratPostPrevL <*> ratPostPipe)
  ratPostPrevR = register 0 (frameOr fWetR <$> ratPostPrevR <*> ratPostPipe)
  ratPostPipe = register Nothing (mapPipe <$> (ratPostLowpassFrame <$> ratPostPrevL <*> ratPostPrevR) <*> ratClipPipe)

  ratTonePrevL = register 0 (frameOr fWetL <$> ratTonePrevL <*> ratTonePipe)
  ratTonePrevR = register 0 (frameOr fWetR <$> ratTonePrevR <*> ratTonePipe)
  ratTonePipe = register Nothing (mapPipe <$> (ratToneFrame <$> ratTonePrevL <*> ratTonePrevR) <*> ratPostPipe)
  ratLevelPipe = register Nothing (mapPipe ratLevelFrame <$> ratTonePipe)
  ratMixPipe = register Nothing (mapPipe ratMixFrame <$> ratLevelPipe)

  -- ---- New per-pedal distortion pipeline. Each section below is a
  -- small, independent register chain with a single enable bit. When
  -- the pedal is off, every stage is bit-exact bypass.

  -- clean_boost (3 stages)
  cleanBoostMulPipe = register Nothing (mapPipe cleanBoostMulFrame <$> ratMixPipe)
  cleanBoostShiftPipe = register Nothing (mapPipe cleanBoostShiftFrame <$> cleanBoostMulPipe)
  cleanBoostLevelPipe = register Nothing (mapPipe cleanBoostLevelFrame <$> cleanBoostShiftPipe)

  -- tube_screamer (5 stages with HPF + post-LPF state)
  tsHpfLpPrevL = register 0 (frameOr fEqLowL <$> tsHpfLpPrevL <*> tsHpfPipe)
  tsHpfLpPrevR = register 0 (frameOr fEqLowR <$> tsHpfLpPrevR <*> tsHpfPipe)
  tsHpfPipe =
    register Nothing $
      mapPipe <$> (tubeScreamerHpfFrame <$> tsHpfLpPrevL <*> tsHpfLpPrevR) <*> cleanBoostLevelPipe
  tsMulPipe = register Nothing (mapPipe tubeScreamerMulFrame <$> tsHpfPipe)
  tsClipPipe = register Nothing (mapPipe tubeScreamerClipFrame <$> tsMulPipe)
  tsPostLpPrevL = register 0 (frameOr fEqHighLpL <$> tsPostLpPrevL <*> tsPostLpfPipe)
  tsPostLpPrevR = register 0 (frameOr fEqHighLpR <$> tsPostLpPrevR <*> tsPostLpfPipe)
  tsPostLpfPipe =
    register Nothing $
      mapPipe <$> (tubeScreamerPostLpfFrame <$> tsPostLpPrevL <*> tsPostLpPrevR) <*> tsClipPipe
  tsLevelPipe = register Nothing (mapPipe tubeScreamerLevelFrame <$> tsPostLpfPipe)

  -- metal_distortion (5 stages with HPF + post-LPF state)
  metalHpfLpPrevL = register 0 (frameOr fEqLowL <$> metalHpfLpPrevL <*> metalHpfPipe)
  metalHpfLpPrevR = register 0 (frameOr fEqLowR <$> metalHpfLpPrevR <*> metalHpfPipe)
  metalHpfPipe =
    register Nothing $
      mapPipe <$> (metalHpfFrame <$> metalHpfLpPrevL <*> metalHpfLpPrevR) <*> tsLevelPipe
  metalMulPipe = register Nothing (mapPipe metalMulFrame <$> metalHpfPipe)
  metalClipPipe = register Nothing (mapPipe metalClipFrame <$> metalMulPipe)
  metalPostLpPrevL = register 0 (frameOr fEqHighLpL <$> metalPostLpPrevL <*> metalPostLpfPipe)
  metalPostLpPrevR = register 0 (frameOr fEqHighLpR <$> metalPostLpPrevR <*> metalPostLpfPipe)
  metalPostLpfPipe =
    register Nothing $
      mapPipe <$> (metalPostLpfFrame <$> metalPostLpPrevL <*> metalPostLpPrevR) <*> metalClipPipe
  metalLevelPipe = register Nothing (mapPipe metalLevelFrame <$> metalPostLpfPipe)

  -- ds1 (5 stages with HPF + post-LPF state)
  ds1HpfLpPrevL = register 0 (frameOr fEqLowL <$> ds1HpfLpPrevL <*> ds1HpfPipe)
  ds1HpfLpPrevR = register 0 (frameOr fEqLowR <$> ds1HpfLpPrevR <*> ds1HpfPipe)
  ds1HpfPipe =
    register Nothing $
      mapPipe <$> (ds1HpfFrame <$> ds1HpfLpPrevL <*> ds1HpfLpPrevR) <*> metalLevelPipe
  ds1MulPipe = register Nothing (mapPipe ds1MulFrame <$> ds1HpfPipe)
  ds1ClipPipe = register Nothing (mapPipe ds1ClipFrame <$> ds1MulPipe)
  ds1TonePrevL = register 0 (frameOr fEqHighLpL <$> ds1TonePrevL <*> ds1TonePipe)
  ds1TonePrevR = register 0 (frameOr fEqHighLpR <$> ds1TonePrevR <*> ds1TonePipe)
  ds1TonePipe =
    register Nothing $
      mapPipe <$> (ds1ToneFrame <$> ds1TonePrevL <*> ds1TonePrevR) <*> ds1ClipPipe
  ds1LevelPipe = register Nothing (mapPipe ds1LevelFrame <$> ds1TonePipe)

  -- big_muff (5 stages: pre, clip1, clip2, tone+state, level)
  bigMuffPrePipe = register Nothing (mapPipe bigMuffPreFrame <$> ds1LevelPipe)
  bigMuffClip1Pipe = register Nothing (mapPipe bigMuffClip1Frame <$> bigMuffPrePipe)
  bigMuffClip2Pipe = register Nothing (mapPipe bigMuffClip2Frame <$> bigMuffClip1Pipe)
  bigMuffTonePrevL = register 0 (frameOr fEqHighLpL <$> bigMuffTonePrevL <*> bigMuffTonePipe)
  bigMuffTonePrevR = register 0 (frameOr fEqHighLpR <$> bigMuffTonePrevR <*> bigMuffTonePipe)
  bigMuffTonePipe =
    register Nothing $
      mapPipe <$> (bigMuffToneFrame <$> bigMuffTonePrevL <*> bigMuffTonePrevR) <*> bigMuffClip2Pipe
  bigMuffLevelPipe = register Nothing (mapPipe bigMuffLevelFrame <$> bigMuffTonePipe)

  -- fuzz_face (4 stages: pre, asym clip, tone+state, level)
  fuzzFacePrePipe = register Nothing (mapPipe fuzzFacePreFrame <$> bigMuffLevelPipe)
  fuzzFaceClipPipe = register Nothing (mapPipe fuzzFaceClipFrame <$> fuzzFacePrePipe)
  fuzzFaceTonePrevL = register 0 (frameOr fEqHighLpL <$> fuzzFaceTonePrevL <*> fuzzFaceTonePipe)
  fuzzFaceTonePrevR = register 0 (frameOr fEqHighLpR <$> fuzzFaceTonePrevR <*> fuzzFaceTonePipe)
  fuzzFaceTonePipe =
    register Nothing $
      mapPipe <$> (fuzzFaceToneFrame <$> fuzzFaceTonePrevL <*> fuzzFaceTonePrevR) <*> fuzzFaceClipPipe
  fuzzFaceLevelPipe = register Nothing (mapPipe fuzzFaceLevelFrame <$> fuzzFaceTonePipe)

  -- Output of the new pedal section feeds the rest of the chain.
  distortionPedalsPipe = fuzzFaceLevelPipe

  ampHpInPrevL = register 0 (frameOr fDryL <$> ampHpInPrevL <*> ampHighpassPipe)
  ampHpInPrevR = register 0 (frameOr fDryR <$> ampHpInPrevR <*> ampHighpassPipe)
  ampHpOutPrevL = register 0 (frameOr fWetL <$> ampHpOutPrevL <*> ampHighpassPipe)
  ampHpOutPrevR = register 0 (frameOr fWetR <$> ampHpOutPrevR <*> ampHighpassPipe)
  ampHighpassPipe =
    register Nothing $
      mapPipe <$> (ampHighpassFrame <$> ampHpInPrevL <*> ampHpInPrevR <*> ampHpOutPrevL <*> ampHpOutPrevR) <*> distortionPedalsPipe
  ampDriveMulPipe = register Nothing (mapPipe ampDriveMultiplyFrame <$> ampHighpassPipe)
  ampDriveBoostPipe = register Nothing (mapPipe ampDriveBoostFrame <$> ampDriveMulPipe)
  ampShapePipe = register Nothing (mapPipe ampWaveshapeFrame <$> ampDriveBoostPipe)

  ampPreLpPrevL = register 0 (frameOr fWetL <$> ampPreLpPrevL <*> ampPreLowpassPipe)
  ampPreLpPrevR = register 0 (frameOr fWetR <$> ampPreLpPrevR <*> ampPreLowpassPipe)
  ampPreLowpassPipe = register Nothing (mapPipe <$> (ampPreLowpassFrame <$> ampPreLpPrevL <*> ampPreLpPrevR) <*> ampShapePipe)
  ampStage2MulPipe = register Nothing (mapPipe ampSecondStageMultiplyFrame <$> ampPreLowpassPipe)
  ampStage2Pipe = register Nothing (mapPipe ampSecondStageFrame <$> ampStage2MulPipe)

  ampToneLowPrevL = register 0 (frameOr fEqLowL <$> ampToneLowPrevL <*> ampToneFilterPipe)
  ampToneLowPrevR = register 0 (frameOr fEqLowR <$> ampToneLowPrevR <*> ampToneFilterPipe)
  ampToneHighPrevL = register 0 (frameOr fEqHighLpL <$> ampToneHighPrevL <*> ampToneFilterPipe)
  ampToneHighPrevR = register 0 (frameOr fEqHighLpR <$> ampToneHighPrevR <*> ampToneFilterPipe)
  ampToneFilterPipe =
    register Nothing $
      mapPipe <$> (ampToneFilterFrame <$> ampToneLowPrevL <*> ampToneLowPrevR <*> ampToneHighPrevL <*> ampToneHighPrevR) <*> ampStage2Pipe
  ampToneBandPipe = register Nothing (mapPipe ampToneBandFrame <$> ampToneFilterPipe)
  ampToneProductsPipe = register Nothing (mapPipe ampToneProductsFrame <$> ampToneBandPipe)
  ampToneMixPipe = register Nothing (mapPipe ampToneMixFrame <$> ampToneProductsPipe)
  ampPowerPipe = register Nothing (mapPipe ampPowerFrame <$> ampToneMixPipe)

  ampResPrevL = register 0 (frameOr fEqLowL <$> ampResPrevL <*> ampResPresenceFilterPipe)
  ampResPrevR = register 0 (frameOr fEqLowR <$> ampResPrevR <*> ampResPresenceFilterPipe)
  ampPresencePrevL = register 0 (frameOr fEqHighLpL <$> ampPresencePrevL <*> ampResPresenceFilterPipe)
  ampPresencePrevR = register 0 (frameOr fEqHighLpR <$> ampPresencePrevR <*> ampResPresenceFilterPipe)
  ampResPresenceFilterPipe =
    register Nothing $
      mapPipe <$> (ampResPresenceFilterFrame <$> ampResPrevL <*> ampResPrevR <*> ampPresencePrevL <*> ampPresencePrevR) <*> ampPowerPipe
  ampResPresenceProductsPipe = register Nothing (mapPipe ampResPresenceProductsFrame <$> ampResPresenceFilterPipe)
  ampResPresencePipe = register Nothing (mapPipe ampResPresenceMixFrame <$> ampResPresenceProductsPipe)
  ampMasterPipe = register Nothing (mapPipe ampMasterFrame <$> ampResPresencePipe)

  cabD1L = register 0 (delayNext <$> cabD1L <*> (frameOr fL 0 <$> ampMasterPipe) <*> ampMasterPipe)
  cabD1R = register 0 (delayNext <$> cabD1R <*> (frameOr fR 0 <$> ampMasterPipe) <*> ampMasterPipe)
  cabD2L = register 0 (delayNext <$> cabD2L <*> cabD1L <*> ampMasterPipe)
  cabD2R = register 0 (delayNext <$> cabD2R <*> cabD1R <*> ampMasterPipe)
  cabD3L = register 0 (delayNext <$> cabD3L <*> cabD2L <*> ampMasterPipe)
  cabD3R = register 0 (delayNext <$> cabD3R <*> cabD2R <*> ampMasterPipe)
  cabProductsPipe =
    register Nothing $
      mapPipe <$> (cabProductsFrame <$> cabD1L <*> cabD2L <*> cabD3L <*> cabD1R <*> cabD2R <*> cabD3R) <*> ampMasterPipe
  cabIrPipe = register Nothing (mapPipe cabIrFrame <$> cabProductsPipe)
  cabMixPipe = register Nothing (mapPipe cabLevelMixFrame <$> cabIrPipe)

  eqLowPrevL = register 0 (frameOr fEqLowL <$> eqLowPrevL <*> eqFilterPipe)
  eqLowPrevR = register 0 (frameOr fEqLowR <$> eqLowPrevR <*> eqFilterPipe)
  eqHighPrevL = register 0 (frameOr fEqHighLpL <$> eqHighPrevL <*> eqFilterPipe)
  eqHighPrevR = register 0 (frameOr fEqHighLpR <$> eqHighPrevR <*> eqFilterPipe)
  eqFilterPipe =
    register Nothing $
      mapPipe <$> (eqFilterFrame <$> eqLowPrevL <*> eqLowPrevR <*> eqHighPrevL <*> eqHighPrevR) <*> cabMixPipe
  eqBandPipe = register Nothing (mapPipe eqBandFrame <$> eqFilterPipe)
  eqProductsPipe = register Nothing (mapPipe eqProductsFrame <$> eqBandPipe)
  eqMixPipe = register Nothing (mapPipe eqMixFrame <$> eqProductsPipe)

  reverbAddr = register 0 (addrNext <$> reverbAddr <*> eqMixPipe)
  addrPipe = register Nothing (attachAddr <$> reverbAddr <*> eqMixPipe)
  reverbL = blockRam zeroReverb reverbAddr (writeReverbL <$> outPipe)
  reverbR = blockRam zeroReverb reverbAddr (writeReverbR <$> outPipe)

  reverbTonePrevL = register 0 (frameOr fWetL <$> reverbTonePrevL <*> reverbToneBlendPipe)
  reverbTonePrevR = register 0 (frameOr fWetR <$> reverbTonePrevR <*> reverbToneBlendPipe)
  reverbToneProductsPipe =
    register Nothing $
      reverbToneProductsFrame
        <$> reverbL
        <*> reverbR
        <*> reverbTonePrevL
        <*> reverbTonePrevR
        <*> addrPipe
  reverbToneBlendPipe = register Nothing (mapPipe reverbToneBlendFrame <$> reverbToneProductsPipe)
  reverbFeedbackProductsPipe = register Nothing (mapPipe reverbFeedbackProductsFrame <$> reverbToneBlendPipe)
  reverbFeedbackPipe = register Nothing (mapPipe reverbFeedbackFrame <$> reverbFeedbackProductsPipe)
  reverbMixProductsPipe = register Nothing (mapPipe reverbMixProductsFrame <$> reverbFeedbackPipe)
  outPipe = register Nothing (mapPipe reverbMixFrame <$> reverbMixProductsPipe)
  outReg = register emptyAxisOut (nextAxisOut <$> outReg <*> outPipe <*> readyOut)
