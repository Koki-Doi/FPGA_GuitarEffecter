{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Overdrive where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

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
