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
