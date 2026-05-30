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
                 , PortName "wah_control"
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
topEntity clk rst gateControl odControl distControl eqControl ratControl ampControl ampToneControl cabControl reverbControl nsControl compControl wahControl samples validIn lastIn readyOut =
  withClockResetEnable clk rst enableGen $
    fxPipeline
      (syncCtrl gateControl) (syncCtrl odControl) (syncCtrl distControl)
      (syncCtrl eqControl) (syncCtrl ratControl) (syncCtrl ampControl)
      (syncCtrl ampToneControl) (syncCtrl cabControl) (syncCtrl reverbControl)
      (syncCtrl nsControl) (syncCtrl compControl) (syncCtrl wahControl)
      samples validIn lastIn readyOut

-- Control-word CDC for the DSP island (GPIO 100 MHz -> DSP 50 MHz). The
-- 32-bit control words cross into the slower DSP domain without a
-- handshake; on an effect/knob change several bits flip and the 50 MHz
-- side can latch a transient mixed value for one sample (audible click).
-- Two FFs resolve metastability, then a 2-cycle stability filter rejects
-- the in-flight transition value and only adopts a word once it has held
-- steady for two DSP cycles -- safe because these control words are
-- quasi-static (they change only on a knob/effect write, never per sample).
syncCtrl :: HiddenClockResetEnable AudioDomain => Signal AudioDomain Ctrl -> Signal AudioDomain Ctrl
syncCtrl x = stable
 where
  ff2     = register 0 (register 0 x)
  ff2prev = register 0 ff2
  stable  = register 0 (mux (ff2 .==. ff2prev) ff2 stable)
