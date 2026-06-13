-- Re-export shim (D104 module split, re-applied on the D99 source). Amp is
-- split into Models (per-model tables + decoders), Clip (input HP -> drive
-- -> anti-alias emphasis -> waveshaper -> 2nd stage), and Tone (scoop
-- biquad, tone stack, power amp, resonance/presence, sag, master, output
-- transformer, multiband sat). Pipeline.hs imports `AudioLab.Effects.Amp`
-- and gets everything via the re-exports here. Pure code move.
module AudioLab.Effects.Amp
  ( module AudioLab.Effects.Amp.Models
  , module AudioLab.Effects.Amp.Clip
  , module AudioLab.Effects.Amp.Tone
  ) where

import AudioLab.Effects.Amp.Models
import AudioLab.Effects.Amp.Clip
import AudioLab.Effects.Amp.Tone
