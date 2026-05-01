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

makeInput :: Ctrl -> Ctrl -> Ctrl -> Ctrl -> Ctrl -> Ctrl -> Ctrl -> Ctrl -> Ctrl -> BitVector 48 -> Bool -> Bool -> Maybe Frame
makeInput gateControl odControl distControl eqControl ratControl ampControl ampToneControl cabControl reverbControl samples validIn lastIn =
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

overdriveDriveMultiplyFrame :: Frame -> Frame
overdriveDriveMultiplyFrame f =
  f{fAccL = if on then mulU12 (fL f) driveGain else 0, fAccR = if on then mulU12 (fR f) driveGain else 0}
 where
  on = flag1 (fGate f)
  driveGain = resize (256 + (resize (ctrlC (fOd f)) * 4 :: Unsigned 10)) :: Unsigned 12

overdriveDriveBoostFrame :: Frame -> Frame
overdriveDriveBoostFrame f =
  f{fWetL = if on then satShift8 (fAccL f) else fL f, fWetR = if on then satShift8 (fAccR f) else fR f}
 where
  on = flag1 (fGate f)

overdriveDriveClipFrame :: Frame -> Frame
overdriveDriveClipFrame f =
  f{fL = if on then softClip (fWetL f) else fL f, fR = if on then softClip (fWetR f) else fR f}
 where
  on = flag1 (fGate f)

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
  left = satShift7 (mulU8 (fWetL f) level)
  right = satShift7 (mulU8 (fWetR f) level)

distortionDriveMultiplyFrame :: Frame -> Frame
distortionDriveMultiplyFrame f =
  f
    { fAccL = if on then mulU12 (fL f) driveGain else 0
    , fAccR = if on then mulU12 (fR f) driveGain else 0
    , fAcc2L = resize threshold
    }
 where
  on = flag2 (fGate f)
  amount = ctrlC (fDist f)
  driveGain = resize (256 + (resize amount * 8 :: Unsigned 11)) :: Unsigned 12
  rawThreshold = 8_388_607 - (resize (asSigned9 amount) * 24_000) :: Signed 25
  clampedThreshold = if rawThreshold < 1_800_000 then 1_800_000 else rawThreshold
  threshold = resize clampedThreshold :: Sample

distortionDriveBoostFrame :: Frame -> Frame
distortionDriveBoostFrame f =
  f{fWetL = if on then satShift8 (fAccL f) else fL f, fWetR = if on then satShift8 (fAccR f) else fR f}
 where
  on = flag2 (fGate f)

distortionDriveClipFrame :: Frame -> Frame
distortionDriveClipFrame f =
  f{fL = if on then hardClip (fWetL f) threshold else fL f, fR = if on then hardClip (fWetR f) threshold else fR f}
 where
  on = flag2 (fGate f)
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
  on = flag2 (fGate f)
  tone = ctrlA (fDist f)
  toneInv = 255 - tone

distortionToneBlendFrame :: Frame -> Frame
distortionToneBlendFrame f =
  f
    { fWetL = if on then toneL else fL f
    , fWetR = if on then toneR else fR f
    }
 where
  on = flag2 (fGate f)
  toneL = satShift8 (fAccL f + fAcc2L f)
  toneR = satShift8 (fAccR f + fAcc2R f)

distortionLevelFrame :: Frame -> Frame
distortionLevelFrame f =
  f{fL = if on then left else fL f, fR = if on then right else fR f}
 where
  on = flag2 (fGate f)
  level = ctrlB (fDist f)
  left = satShift7 (mulU8 (fWetL f) level)
  right = satShift7 (mulU8 (fWetR f) level)

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
  rawThreshold = 6_291_456 - (resize (asSigned9 amount) * 9_000) :: Signed 25
  clampedThreshold = if rawThreshold < 3_750_000 then 3_750_000 else rawThreshold
  threshold = resize clampedThreshold :: Sample

ratPostLowpassFrame :: Sample -> Sample -> Frame -> Frame
ratPostLowpassFrame prevL prevR f =
  f{fWetL = if on then onePoleU8 192 prevL (fWetL f) else fL f, fWetR = if on then onePoleU8 192 prevR (fWetR f) else fR f}
 where
  on = flag4 (fGate f)

ratToneFrame :: Sample -> Sample -> Frame -> Frame
ratToneFrame prevL prevR f =
  f{fWetL = if on then onePoleU8 alpha prevL (fWetL f) else fL f, fWetR = if on then onePoleU8 alpha prevR (fWetR f) else fR f}
 where
  on = flag4 (fGate f)
  dark = resize ((resize (ctrlA (fRat f)) * 3 :: Unsigned 10) `shiftR` 2) :: Unsigned 8
  alpha = 224 - dark

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
    satWide (resize x - resize prevIn + ((resize prevOut :: Wide) * 254 `shiftR` 8))

ampDriveMultiplyFrame :: Frame -> Frame
ampDriveMultiplyFrame f =
  f{fAccL = if on then mulU12 (fWetL f) gain else 0, fAccR = if on then mulU12 (fWetR f) gain else 0}
 where
  on = flag6 (fGate f)
  -- 1.0x to about 31x using Q7-style post shift.
  gain = resize (128 + (resize (ctrlA (fAmp f)) * 15 :: Unsigned 12)) :: Unsigned 12

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
  positiveKnee = resize (5_200_000 - ch * 8_500) :: Sample
  negativeKnee = resize (4_700_000 - ch * 7_000) :: Sample

ampWaveshapeFrame :: Frame -> Frame
ampWaveshapeFrame f =
  f{fWetL = if on then ampAsymClip character (fWetL f) else fL f, fWetR = if on then ampAsymClip character (fWetR f) else fR f}
 where
  on = flag6 (fGate f)
  character = ctrlD (fAmpTone f)

ampPreLowpassFrame :: Sample -> Sample -> Frame -> Frame
ampPreLowpassFrame prevL prevR f =
  f{fWetL = if on then onePoleU8 alpha prevL (fWetL f) else fL f, fWetR = if on then onePoleU8 alpha prevR (fWetR f) else fR f}
 where
  on = flag6 (fGate f)
  -- Higher character keeps more edge; lower character smooths more.
  alpha = 160 + (ctrlD (fAmpTone f) `shiftR` 2)

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

ampToneProductsFrame :: Frame -> Frame
ampToneProductsFrame f =
  f
    { fAccL = if on then mulU8 (fEqLowL f) (ampToneGain (ctrlA (fAmpTone f))) else 0
    , fAccR = if on then mulU8 (fEqLowR f) (ampToneGain (ctrlA (fAmpTone f))) else 0
    , fAcc2L = if on then mulU8 (fEqMidL f) (ampToneGain (ctrlB (fAmpTone f))) else 0
    , fAcc2R = if on then mulU8 (fEqMidR f) (ampToneGain (ctrlB (fAmpTone f))) else 0
    , fAcc3L = if on then mulU8 (fEqHighL f) (ampToneGain (ctrlC (fAmpTone f))) else 0
    , fAcc3R = if on then mulU8 (fEqHighR f) (ampToneGain (ctrlC (fAmpTone f))) else 0
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
  f{fWetL = if on then softClip (fWetL f) else fL f, fWetR = if on then softClip (fWetR f) else fR f}
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
  f{fWetL = if on then softClip wetL else fL f, fWetR = if on then softClip wetR else fR f}
 where
  on = flag6 (fGate f)
  resonance = ctrlD (fAmp f)
  presence = ctrlC (fAmp f)
  highL = satWide (resize (fWetL f) - resize (fEqHighLpL f))
  highR = satWide (resize (fWetR f) - resize (fEqHighLpR f))
  wetL = satWide (resize (fWetL f) + resize (satShift10 (mulU8 (fEqLowL f) resonance)) + resize (satShift9 (mulU8 highL presence)))
  wetR = satWide (resize (fWetR f) + resize (satShift10 (mulU8 (fEqLowR f) resonance)) + resize (satShift9 (mulU8 highR presence)))

ampMasterFrame :: Frame -> Frame
ampMasterFrame f =
  f{fL = if on then left else fL f, fR = if on then right else fR f}
 where
  on = flag6 (fGate f)
  level = ctrlB (fAmp f)
  left = softClip (satShift7 (mulU8 (fWetL f) level))
  right = softClip (satShift7 (mulU8 (fWetR f) level))

cabIrFrame :: Sample -> Sample -> Sample -> Sample -> Sample -> Sample -> Frame -> Frame
cabIrFrame d1L d2L d3L d1R d2R d3R f =
  f{fWetL = if on then wetL else fL f, fWetR = if on then wetR else fR f}
 where
  on = flag7 (fGate f)
  -- Fixed short guitar-cabinet IR approximation: direct sound plus three decaying taps.
  wetL = satShift8 (mulU8 (fL f) 112 + mulU8 d1L 80 + mulU8 d2L 48 + mulU8 d3L 24)
  wetR = satShift8 (mulU8 (fR f) 112 + mulU8 d1R 80 + mulU8 d2R 48 + mulU8 d3R 24)

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
eqMixFrame f =
  f{fL = if on then satShift7 accL else fL f, fR = if on then satShift7 accR else fR f}
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
reverbToneProductsFrame tapL tapR prevL prevR = mapPipe applyTone
 where
  applyTone f =
    f
      { fAccL = mulU8 tapL (ctrlB (fReverb f))
      , fAccR = mulU8 tapR (ctrlB (fReverb f))
      , fAcc2L = mulU8 prevL (255 - ctrlB (fReverb f))
      , fAcc2R = mulU8 prevR (255 - ctrlB (fReverb f))
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
  -> Signal AudioDomain (BitVector 48)
  -> Signal AudioDomain Bool
  -> Signal AudioDomain Bool
  -> Signal AudioDomain Bool
  -> ( Signal AudioDomain (BitVector 48)
     , Signal AudioDomain Bool
     , Signal AudioDomain Bool
     , Signal AudioDomain Bool
     )
topEntity clk rst gateControl odControl distControl eqControl ratControl ampControl ampToneControl cabControl reverbControl samples validIn lastIn readyOut =
  withClockResetEnable clk rst enableGen $
    fxPipeline gateControl odControl distControl eqControl ratControl ampControl ampToneControl cabControl reverbControl samples validIn lastIn readyOut

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
  -> Signal AudioDomain (BitVector 48)
  -> Signal AudioDomain Bool
  -> Signal AudioDomain Bool
  -> Signal AudioDomain Bool
  -> ( Signal AudioDomain (BitVector 48)
     , Signal AudioDomain Bool
     , Signal AudioDomain Bool
     , Signal AudioDomain Bool
     )
fxPipeline gateControl odControl distControl eqControl ratControl ampControl ampToneControl cabControl reverbControl samples validIn lastIn readyOut =
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
        <*> samples
        <*> acceptedIn
        <*> lastIn

  gateLevelPipe = register Nothing (mapPipe gateLevelFrame <$> inPipe)
  gateEnv = register 0 (gateEnvNext <$> gateEnv <*> gateLevelPipe)
  gateOpen = register True (gateOpenNext <$> gateOpen <*> gateEnv <*> gateLevelPipe)
  gateGain = register gateUnity (gateGainNext <$> gateGain <*> gateOpen <*> gateLevelPipe)
  gatePipe = register Nothing (mapPipe <$> (gateFrame <$> gateGain) <*> gateLevelPipe)
  odDriveMulPipe = register Nothing (mapPipe overdriveDriveMultiplyFrame <$> gatePipe)
  odDriveBoostPipe = register Nothing (mapPipe overdriveDriveBoostFrame <$> odDriveMulPipe)
  odDrivePipe = register Nothing (mapPipe overdriveDriveClipFrame <$> odDriveBoostPipe)

  odTonePrevL = register 0 (frameOr fWetL <$> odTonePrevL <*> odToneBlendPipe)
  odTonePrevR = register 0 (frameOr fWetR <$> odTonePrevR <*> odToneBlendPipe)
  odToneMulPipe = register Nothing (mapPipe <$> (overdriveToneMultiplyFrame <$> odTonePrevL <*> odTonePrevR) <*> odDrivePipe)
  odToneBlendPipe = register Nothing (mapPipe overdriveToneBlendFrame <$> odToneMulPipe)
  odTonePipe = register Nothing (mapPipe overdriveLevelFrame <$> odToneBlendPipe)

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

  ampHpInPrevL = register 0 (frameOr fDryL <$> ampHpInPrevL <*> ampHighpassPipe)
  ampHpInPrevR = register 0 (frameOr fDryR <$> ampHpInPrevR <*> ampHighpassPipe)
  ampHpOutPrevL = register 0 (frameOr fWetL <$> ampHpOutPrevL <*> ampHighpassPipe)
  ampHpOutPrevR = register 0 (frameOr fWetR <$> ampHpOutPrevR <*> ampHighpassPipe)
  ampHighpassPipe =
    register Nothing $
      mapPipe <$> (ampHighpassFrame <$> ampHpInPrevL <*> ampHpInPrevR <*> ampHpOutPrevL <*> ampHpOutPrevR) <*> ratMixPipe
  ampDriveMulPipe = register Nothing (mapPipe ampDriveMultiplyFrame <$> ampHighpassPipe)
  ampDriveBoostPipe = register Nothing (mapPipe ampDriveBoostFrame <$> ampDriveMulPipe)
  ampShapePipe = register Nothing (mapPipe ampWaveshapeFrame <$> ampDriveBoostPipe)

  ampPreLpPrevL = register 0 (frameOr fWetL <$> ampPreLpPrevL <*> ampPreLowpassPipe)
  ampPreLpPrevR = register 0 (frameOr fWetR <$> ampPreLpPrevR <*> ampPreLowpassPipe)
  ampPreLowpassPipe = register Nothing (mapPipe <$> (ampPreLowpassFrame <$> ampPreLpPrevL <*> ampPreLpPrevR) <*> ampShapePipe)

  ampToneLowPrevL = register 0 (frameOr fEqLowL <$> ampToneLowPrevL <*> ampToneFilterPipe)
  ampToneLowPrevR = register 0 (frameOr fEqLowR <$> ampToneLowPrevR <*> ampToneFilterPipe)
  ampToneHighPrevL = register 0 (frameOr fEqHighLpL <$> ampToneHighPrevL <*> ampToneFilterPipe)
  ampToneHighPrevR = register 0 (frameOr fEqHighLpR <$> ampToneHighPrevR <*> ampToneFilterPipe)
  ampToneFilterPipe =
    register Nothing $
      mapPipe <$> (ampToneFilterFrame <$> ampToneLowPrevL <*> ampToneLowPrevR <*> ampToneHighPrevL <*> ampToneHighPrevR) <*> ampPreLowpassPipe
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
  ampResPresencePipe = register Nothing (mapPipe ampResPresenceMixFrame <$> ampResPresenceFilterPipe)
  ampMasterPipe = register Nothing (mapPipe ampMasterFrame <$> ampResPresencePipe)

  cabD1L = register 0 (delayNext <$> cabD1L <*> (frameOr fL 0 <$> ampMasterPipe) <*> ampMasterPipe)
  cabD1R = register 0 (delayNext <$> cabD1R <*> (frameOr fR 0 <$> ampMasterPipe) <*> ampMasterPipe)
  cabD2L = register 0 (delayNext <$> cabD2L <*> cabD1L <*> ampMasterPipe)
  cabD2R = register 0 (delayNext <$> cabD2R <*> cabD1R <*> ampMasterPipe)
  cabD3L = register 0 (delayNext <$> cabD3L <*> cabD2L <*> ampMasterPipe)
  cabD3R = register 0 (delayNext <$> cabD3R <*> cabD2R <*> ampMasterPipe)
  cabIrPipe =
    register Nothing $
      mapPipe <$> (cabIrFrame <$> cabD1L <*> cabD2L <*> cabD3L <*> cabD1R <*> cabD2R <*> cabD3R) <*> ampMasterPipe
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
