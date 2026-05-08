{-# LANGUAGE NumericUnderscores #-}

module LowPassFir where

import Clash.Prelude

import AudioLab.Pipeline
import AudioLab.Types

{-# ANN topEntity
  (Synthesize
    { t_name   = "clash_lowpass_fir"
    , t_inputs = [ PortName "clk"
                 , PortName "aresetn"
                 , PortName "gate_control"
                 , PortName "overdrive_control"
                 , PortName "distortion_control"
                 , PortName "eq_control"
                 , PortName "delay_control"
                 , PortName "amp_control"
                 , PortName "amp_tone_control"
                 , PortName "cab_control"
                 , PortName "reverb_control"
                 , PortName "noise_suppressor_control"
                 , PortName "compressor_control"
                 , PortName "axis_in_tdata"
                 , PortName "axis_in_tvalid"
                 , PortName "axis_in_tlast"
                 , PortName "axis_out_tready"
                 ]
    , t_output = PortProduct "" [PortName "axis_out_tdata"
                                ,PortName "axis_out_tvalid"
                                ,PortName "axis_out_tlast"
                                ,PortName "axis_in_tready"
                                ]
    }) #-}
topEntity
  :: Clock AudioDomain
  -> Reset AudioDomain
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain Ctrl
  -> Signal AudioDomain (BitVector 48)
  -> Signal AudioDomain Bool
  -> Signal AudioDomain Bool
  -> Signal AudioDomain Bool
  -> ( Signal AudioDomain (BitVector 48)
     , Signal AudioDomain Bool
     , Signal AudioDomain Bool
     , Signal AudioDomain Bool
     )
topEntity clk rst gateControl odControl distControl eqControl ratControl ampControl ampToneControl cabControl reverbControl nsControl compControl samples validIn lastIn readyOut =
  withClockResetEnable clk rst enableGen $
    fxPipeline gateControl odControl distControl eqControl ratControl ampControl ampToneControl cabControl reverbControl nsControl compControl samples validIn lastIn readyOut
