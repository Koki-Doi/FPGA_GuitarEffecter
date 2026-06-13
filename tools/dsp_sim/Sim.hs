{-# LANGUAGE NumericUnderscores #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Offline DSP simulation harness (Tier 1).
--
-- Runs the EXACT Clash @topEntity@ fixed-point pipeline (the same source that
-- Vivado synthesises to the FPGA) on a host CPU, so a voicing change can be
-- A/B'd in seconds instead of a 30-40 min Vivado build + ear bench.
--
-- IMPORTANT: on the FPGA the DSP island receives a *gated* AXIS stream -- a new
-- valid sample only every ~347 island cycles (33 MHz island / 96 kHz audio),
-- with @validIn@ LOW in between. The recursive pipeline stages (biquads, SVF,
-- envelopes) are @Maybe Frame@-gated and HOLD on idle cycles. So a sample must
-- be presented as one valid cycle followed by @gap@ idle cycles; feeding valid
-- back-to-back mis-times the recursive feedback. @gap@ must be >= the pipeline
-- depth so each sample fully settles before the next enters.
--
-- Protocol (stdin, whitespace-separated integers):
--   * 12 control words (BitVector 32, decimal) in topEntity order:
--       gate od dist eq rat amp amp_tone cab reverb ns comp wah
--   * 1 flush count  (extra trailing idle cycles to drain the last sample)
--   * 1 gap          (idle cycles inserted after each valid sample)
--   * N input samples (Signed 24, the mono LEFT channel)
-- stdout: the N processed output samples (Signed 24, where oValid fired).
module Main (main) where

import Clash.Prelude
import qualified Prelude as P
import Prelude (IO, (<$>))

import LowPassFir (topEntity)
import AudioLab.Types
import AudioLab.Axis (packChan, unpackChan)

-- | Wire 12 constant control words + a *gated* sample stream through the real
-- DSP pipeline and return the processed mono output (the cycles where the AXIS
-- output is valid), aligned one-per-input-sample.
runDSP :: [Ctrl] -> Int -> Int -> [Sample] -> [Sample]
runDSP ctrls flush gap inSamples = P.drop (P.length valids P.- n) valids
 where
  n      = P.length inSamples
  -- The 1-cycle resetGen eats the FIRST presented valid sample, so prepend a
  -- few zero "warm-up" samples (the pipeline's correct silent initial state) to
  -- absorb the reset; the real outputs are then the LAST n valid cycles
  -- (trailing idle/flush produces no valids), which is robust to how many the
  -- reset swallowed.
  pad    = 4
  allS   = P.replicate pad 0 P.++ inSamples
  -- one valid cycle carrying the sample, then `gap` idle (validIn = False)
  slot s = (packChan s s, True) : P.replicate gap (packChan s s, False)
  framed = P.concatMap slot allS P.++ P.replicate (gap P.+ flush) (0, False)
  total  = P.length framed
  inSig  = fromList (P.map P.fst framed P.++ P.repeat 0)
  vSig   = fromList (P.map P.snd framed P.++ P.repeat False)
  c i    = pure (ctrls P.!! i) :: Signal AudioDomain Ctrl
  (outData, outValid, _, _) =
    topEntity clockGen resetGen
      (c 0) (c 1) (c 2) (c 3) (c 4) (c 5) (c 6) (c 7) (c 8) (c 9) (c 10) (c 11)
      inSig vSig (pure False) (pure True)
  pairs  = sampleN total (bundle (outData, outValid))
  valids = [ P.fst (unpackChan d) | (d, v) <- pairs, v ]

main :: IO ()
main = do
  toks <- (P.map P.read . P.words) <$> P.getContents :: IO [P.Integer]
  let ctrls   = P.map fromInteger (P.take 12 toks)   :: [Ctrl]
      flush   = P.fromInteger (toks P.!! 12)          :: Int
      gap     = P.fromInteger (toks P.!! 13)          :: Int
      samples = P.map fromInteger (P.drop 14 toks)    :: [Sample]
      outs    = runDSP ctrls flush gap samples
  P.putStr (P.unlines (P.map P.show outs))
