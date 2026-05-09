{-# LANGUAGE NumericUnderscores #-}

module AudioLab.FixedPoint where

import Clash.Prelude

import AudioLab.Types

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
gateUnity :: GateGain
gateUnity = 4_095

gateAttackStep :: GateGain
gateAttackStep = 512

gateReleaseStep :: GateGain
gateReleaseStep = 4

maxAbsFrame :: Frame -> Sample
maxAbsFrame f = abs24 (monoSample f)
