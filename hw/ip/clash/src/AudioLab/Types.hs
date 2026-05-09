{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Types where

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

isActive :: Maybe Frame -> Bool
isActive Nothing = False
isActive (Just _) = True

mapPipe :: (Frame -> Frame) -> Maybe Frame -> Maybe Frame
mapPipe _ Nothing = Nothing
mapPipe f (Just x) = Just (f x)

monoSample :: Frame -> Sample
monoSample = fL

monoDry :: Frame -> Sample
monoDry = fDryL

monoWet :: Frame -> Sample
monoWet = fWetL

monoFb :: Frame -> Sample
monoFb = fFbL

monoEqLow :: Frame -> Sample
monoEqLow = fEqLowL

monoEqMid :: Frame -> Sample
monoEqMid = fEqMidL

monoEqHigh :: Frame -> Sample
monoEqHigh = fEqHighL

monoEqHighLp :: Frame -> Sample
monoEqHighLp = fEqHighLpL

setMonoSample :: Sample -> Frame -> Frame
setMonoSample x f = f{fL = x, fR = x}

setMonoDry :: Sample -> Frame -> Frame
setMonoDry x f = f{fDryL = x, fDryR = x}

setMonoWet :: Sample -> Frame -> Frame
setMonoWet x f = f{fWetL = x, fWetR = x}

setMonoFb :: Sample -> Frame -> Frame
setMonoFb x f = f{fFbL = x, fFbR = x}

setMonoEqLow :: Sample -> Frame -> Frame
setMonoEqLow x f = f{fEqLowL = x, fEqLowR = x}

setMonoEqMid :: Sample -> Frame -> Frame
setMonoEqMid x f = f{fEqMidL = x, fEqMidR = x}

setMonoEqHigh :: Sample -> Frame -> Frame
setMonoEqHigh x f = f{fEqHighL = x, fEqHighR = x}

setMonoEqHighLp :: Sample -> Frame -> Frame
setMonoEqHighLp x f = f{fEqHighLpL = x, fEqHighLpR = x}

setMonoAcc :: Wide -> Frame -> Frame
setMonoAcc x f = f{fAccL = x, fAccR = 0}

setMonoAcc2 :: Wide -> Frame -> Frame
setMonoAcc2 x f = f{fAcc2L = x, fAcc2R = 0}

setMonoAcc3 :: Wide -> Frame -> Frame
setMonoAcc3 x f = f{fAcc3L = x, fAcc3R = 0}
