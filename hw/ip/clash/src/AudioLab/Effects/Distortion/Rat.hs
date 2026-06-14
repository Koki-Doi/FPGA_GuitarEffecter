{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Distortion.Rat where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types
import AudioLab.Effects.Distortion.Common

ratHighpassFrame :: Sample -> Sample -> Frame -> Frame
ratHighpassFrame prevIn prevOut f =
  setMonoWet (if on then highpass x prevIn prevOut else x) (setMonoDry x f)
 where
  on = flag4 (fGate f)
  x = monoSample f
  -- D124: LIVE one-pole highpass (~150 Hz at 96 kHz). The old `onePoleHighpass
  -- 511 9` call rounded the feedback pole to 0 (511>>9 = 0 -> first difference
  -- x - prevIn), which attenuated the passband ~24 dB at 1 kHz, so the signal
  -- entering the drive + hard clip was tiny and the RAT NEVER distorted
  -- (measured THD 0% even at max drive). Inline correct-precedence form
  -- (prevOut*coef)>>9 so ONLY the RAT pole goes live; the shared
  -- onePoleHighpass and its other (intentionally-dead-pole) callers are
  -- untouched. coef 507/512 = 0.9902 -> ~150 Hz.
  highpass x prevIn prevOut =
    satWide (resize x - resize prevIn + ((resize prevOut * 507) `shiftR` 9 :: Wide))

ratDriveMultiplyFrame :: Frame -> Frame
ratDriveMultiplyFrame f =
  f{fAccL = if on then mulU12 (monoWet f) driveGain else 0, fAccR = 0}
 where
  on = flag4 (fGate f)
  driveGain = resize (640 + (resize (ctrlC (fRat f)) * 12 :: Unsigned 12)) :: Unsigned 12

ratDriveBoostFrame :: Frame -> Frame
ratDriveBoostFrame f =
  setMonoWet (if on then satShift8 (fAccL f) else monoSample f) f
 where
  on = flag4 (fGate f)

ratOpAmpLowpassFrame :: Sample -> Frame -> Frame
ratOpAmpLowpassFrame prev f =
  setMonoWet (if on then low else monoSample f) f
 where
  on = flag4 (fGate f)
  -- 96 kHz: bilinear-refit (was 184 - drive>>1) to hold the op-amp LPF corner.
  alpha = 120 - resize ((ctrlC (fRat f) `shiftR` 2) + (ctrlC (fRat f) `shiftR` 3)) :: Unsigned 8
  low = onePoleU8 alpha prev (monoWet f)

-- RAT 4x oversampled hard clip (realism item 2 / R5, D89). Same DSP-free
-- upsample + 15-tap decimation as Metal (D88) via the shared os4x helpers;
-- the RAT op-amp + Si-diode hard clip is a strong aliaser. Clip input/output
-- is monoWet; threshold from ctrlC (fRat). Split products/mix; bit-exact
-- bypass when the RAT is off.
ratClipThreshold :: Frame -> Sample
ratClipThreshold f = resize clampedThreshold :: Sample
 where
  amount = ctrlC (fRat f)
  rawThreshold = 6_000_000 - (resize (asSigned9 amount) * 8_500) :: Signed 25
  clampedThreshold = if rawThreshold < 2_200_000 then 2_200_000 else rawThreshold

ratClipProductsFrame :: Sample -> Vec 12 Sample -> Frame -> Frame
ratClipProductsFrame x1 hist f =
  f { fAccL = if on then s0 else 0, fAccR = 0
    , fAcc2L = if on then s1 else 0, fAcc2R = 0
    , fAcc3L = if on then s2 else 0, fAcc3R = 0 }
 where
  on = flag4 (fGate f)
  (q0, q1, q2, q3) = os4xSubSamples (ratClipThreshold f) x1 (monoWet f)
  (s0, s1, s2) = os4xDecimProducts q0 q1 q2 q3 hist

ratClipMixFrame :: Frame -> Frame
ratClipMixFrame f =
  setMonoWet (if on then satShift9 (fAccL f + fAcc2L f + fAcc3L f) else monoSample f) f
 where
  on = flag4 (fGate f)

ratClipHistNext :: Vec 12 Sample -> Sample -> Maybe Frame -> Vec 12 Sample
ratClipHistNext hist _ Nothing = hist
ratClipHistNext hist x1 (Just f) = os4xHistShift q0 q1 q2 q3 hist
 where
  (q0, q1, q2, q3) = os4xSubSamples (ratClipThreshold f) x1 (monoWet f)

ratPostLowpassFrame :: Sample -> Frame -> Frame
-- Global real-pedal pass: roll off more high-frequency content after the
-- hard clip, matching the darker top end of a real RAT.
-- 96 kHz: 106 (was 168) holds the same post-clip LPF corner Hz at 2x fs.
-- D126: DRIVE-DEPENDENT darkening to model the LM308's slew-rate limit -- on a
-- real RAT, higher GAIN progressively rolls off the top end (the op-amp can't
-- slew the high-frequency content of a high-gain square), so high drive is NOT
-- an unlimited full-band square. alpha lowers (darker) as DRIVE rises:
-- drive 0 -> 106 (= the accepted D124 corner, byte-identical at low drive),
-- drive 255 -> 106-63 = 43 (noticeably darker). This tames high-gain fizz the
-- way the analog circuit does.
ratPostLowpassFrame prev f =
  setMonoWet (if on then onePoleU8 alpha prev (monoWet f) else monoSample f) f
 where
  on = flag4 (fGate f)
  alpha = 106 - (ctrlC (fRat f) `shiftR` 2)

ratToneFrame :: Sample -> Frame -> Frame
ratToneFrame prev f =
  setMonoWet (if on then onePoleU8 alpha prev (monoWet f) else monoSample f) f
 where
  on = flag4 (fGate f)
  -- Darker FILTER base so fully bright still has upper roll-off.
  -- 96 kHz: bilinear-refit (was 192 - (toneA*3)>>2) to hold the tone LPF corner.
  alpha = 128 - (ctrlA (fRat f) `shiftR` 1)

ratLevelFrame :: Frame -> Frame
ratLevelFrame f =
  setMonoWet (if on then out else monoSample f) f
 where
  on = flag4 (fGate f)
  level = ctrlB (fRat f)
  out = satShift7 (mulU8 (monoWet f) level)

ratMixFrame :: Frame -> Frame
ratMixFrame f =
  setMonoSample (if on then softClip mixed else monoSample f) f
 where
  on = flag4 (fGate f)
  mix = ctrlD (fRat f)
  invMix = 255 - mix
  mixed = satShift8 (mulU8 (monoDry f) invMix + mulU8 (monoWet f) mix)
