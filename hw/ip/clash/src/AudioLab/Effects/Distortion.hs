-- Re-export shim (D104 module split). The distortion section is split into
-- Common (shared pedal/os4x kernels), Legacy (the legacy distortion stage),
-- Pedals (the 6 distortion-pedalboard pedals), and Rat (the dedicated RAT).
-- Pipeline.hs imports `AudioLab.Effects.Distortion` and gets everything here.
module AudioLab.Effects.Distortion
  ( module AudioLab.Effects.Distortion.Common
  , module AudioLab.Effects.Distortion.Legacy
  , module AudioLab.Effects.Distortion.Pedals
  , module AudioLab.Effects.Distortion.Rat
  ) where

import AudioLab.Effects.Distortion.Common
import AudioLab.Effects.Distortion.Legacy
import AudioLab.Effects.Distortion.Pedals
import AudioLab.Effects.Distortion.Rat
