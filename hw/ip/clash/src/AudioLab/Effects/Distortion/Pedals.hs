{-# LANGUAGE NumericUnderscores #-}

-- | Selectable distortion-pedal stages. Refactor K (2026-06-22) split the
-- per-pedal stages out of this single 583-line module into one module per pedal
-- under @Distortion/Pedals/@; this file is now a thin re-export shim so every
-- importer (@AudioLab.Effects.Distortion@ -> Pipeline) is unchanged. Pure
-- code-move: the per-pedal modules carry their stages verbatim, share only the
-- Common / FixedPoint / Control / Types helpers (no cross-pedal dependency), and
-- the BigMuff module hosts the mid-scoop biquad that Metal / DS-1 also drive via
-- a coeff mux (priority metal -> ds1 -> bigMuff).
module AudioLab.Effects.Distortion.Pedals
  ( module AudioLab.Effects.Distortion.Pedals.CleanBoost
  , module AudioLab.Effects.Distortion.Pedals.TubeScreamer
  , module AudioLab.Effects.Distortion.Pedals.Metal
  , module AudioLab.Effects.Distortion.Pedals.Ds1
  , module AudioLab.Effects.Distortion.Pedals.BigMuff
  , module AudioLab.Effects.Distortion.Pedals.FuzzFace
  ) where

import AudioLab.Effects.Distortion.Pedals.CleanBoost
import AudioLab.Effects.Distortion.Pedals.TubeScreamer
import AudioLab.Effects.Distortion.Pedals.Metal
import AudioLab.Effects.Distortion.Pedals.Ds1
import AudioLab.Effects.Distortion.Pedals.BigMuff
import AudioLab.Effects.Distortion.Pedals.FuzzFace
