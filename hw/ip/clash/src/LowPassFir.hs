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

flag0, flag1, flag2, flag3, flag5 :: Ctrl -> Bool
flag0 c = slice d0 d0 c == (1 :: BitVector 1)
flag1 c = slice d1 d1 c == (1 :: BitVector 1)
flag2 c = slice d2 d2 c == (1 :: BitVector 1)
flag3 c = slice d3 d3 c == (1 :: BitVector 1)
flag5 c = slice d5 d5 c == (1 :: BitVector 1)

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

makeInput :: Ctrl -> Ctrl -> Ctrl -> Ctrl -> Ctrl -> BitVector 48 -> Bool -> Bool -> Maybe Frame
makeInput gateControl odControl distControl eqControl reverbControl samples validIn lastIn =
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

gateFrame :: Frame -> Frame
gateFrame f =
  f{fL = if mute then 0 else fL f, fR = if mute then 0 else fR f}
 where
  threshold = resize (asSigned9 (ctrlB (fGate f))) `shiftL` 15 :: Sample
  mute = flag0 (fGate f) && abs24 (fL f) < threshold && abs24 (fR f) < threshold

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
  -> Signal AudioDomain (BitVector 48)
  -> Signal AudioDomain Bool
  -> Signal AudioDomain Bool
  -> Signal AudioDomain Bool
  -> ( Signal AudioDomain (BitVector 48)
     , Signal AudioDomain Bool
     , Signal AudioDomain Bool
     , Signal AudioDomain Bool
     )
topEntity clk rst gateControl odControl distControl eqControl _delayControl reverbControl samples validIn lastIn readyOut =
  withClockResetEnable clk rst enableGen $
    fxPipeline gateControl odControl distControl eqControl reverbControl samples validIn lastIn readyOut

fxPipeline
  :: HiddenClockResetEnable AudioDomain
  => Signal AudioDomain Ctrl
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
fxPipeline gateControl odControl distControl eqControl reverbControl samples validIn lastIn readyOut =
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
        <*> reverbControl
        <*> samples
        <*> acceptedIn
        <*> lastIn

  gatePipe = register Nothing (mapPipe gateFrame <$> inPipe)
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

  eqLowPrevL = register 0 (frameOr fEqLowL <$> eqLowPrevL <*> eqFilterPipe)
  eqLowPrevR = register 0 (frameOr fEqLowR <$> eqLowPrevR <*> eqFilterPipe)
  eqHighPrevL = register 0 (frameOr fEqHighLpL <$> eqHighPrevL <*> eqFilterPipe)
  eqHighPrevR = register 0 (frameOr fEqHighLpR <$> eqHighPrevR <*> eqFilterPipe)
  eqFilterPipe =
    register Nothing $
      mapPipe <$> (eqFilterFrame <$> eqLowPrevL <*> eqLowPrevR <*> eqHighPrevL <*> eqHighPrevR) <*> distTonePipe
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
