{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Axis where

import Clash.Prelude

import AudioLab.Types

unpackChan :: BitVector 48 -> (Sample, Sample)
unpackChan bv = (unpack (slice d23 d0 bv), unpack (slice d47 d24 bv))

packChan :: Sample -> Sample -> BitVector 48
packChan left right = pack right ++# pack left
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
