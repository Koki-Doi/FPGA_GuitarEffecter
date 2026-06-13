-- Re-export shim (D104 module split F, re-applied on the D99 source).
-- Distortion is split into Common (os4x oversampler helpers), Legacy (the
-- pre-pedal-mask distortion stage), Pedals (clean_boost / tube_screamer /
-- metal / ds1 / big_muff / fuzz_face), and Rat. Pedals + Rat import Common
-- for the shared os4x machinery. Pipeline.hs imports `AudioLab.Effects.
-- Distortion` and gets everything via the re-exports. Pure code move.
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
