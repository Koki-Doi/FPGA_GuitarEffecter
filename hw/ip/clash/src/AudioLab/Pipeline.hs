{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Pipeline where

import Clash.Prelude

import AudioLab.Axis
import AudioLab.Effects.Amp
import AudioLab.Effects.Cab
import AudioLab.Effects.Compressor
import AudioLab.Effects.Distortion
import AudioLab.Effects.Eq
import AudioLab.Effects.NoiseSuppressor
import AudioLab.Effects.Overdrive
import AudioLab.Effects.Reverb
import AudioLab.Effects.Wah
import AudioLab.FixedPoint
import AudioLab.Types

frameOr :: (Frame -> Sample) -> Sample -> Maybe Frame -> Sample
frameOr _ old Nothing = old
frameOr f _ (Just x) = f x

delayNext :: Sample -> Sample -> Maybe Frame -> Sample
delayNext old incoming pipe = if isActive pipe then incoming else old

nextPace :: Unsigned 4 -> Unsigned 4
nextPace n = if n == 0 then maxBound else n - 1

fxPipeline
  :: HiddenClockResetEnable AudioDomain
  => Signal AudioDomain Ctrl
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
fxPipeline gateControl odControl distControl eqControl ratControl ampControl ampToneControl cabControl reverbControl nsControl compControl wahControl samples validIn lastIn readyOut =
  pipeline
 where
  pipeline =
    ( oData <$> outReg
    , oValid <$> outReg
    , oLast <$> outReg
    , acceptReady
    )

  -- DSP island build: clash runs on FCLK_CLK1 = 50 MHz behind AXIS clock
  -- converters (see hw/Pynq-Z2/island_integration.tcl); everything else
  -- stays 100 MHz so the I2S/Pmod CDCs are untouched. The 16-cycle
  -- paceCount was the only frequency-dependent term in the AXIS handshake
  -- (it paced DMA bursts at 100 MHz); on the island it is removed so the
  -- DSP uses pure readyOut flow control. paceCount/paceReady/nextPace are
  -- now unused and the synthesiser drops them.
  paceCount = register (0 :: Unsigned 4) (nextPace <$> paceCount)
  paceReady = (== 0) <$> paceCount
  acceptReady = readyOut
  acceptedIn = (&&) <$> validIn <*> acceptReady

  inPipe =
    register Nothing $
      makeInput
        <$> gateControl
        <*> odControl
        <*> distControl
        <*> eqControl
        <*> ratControl
        <*> ampControl
        <*> ampToneControl
        <*> cabControl
        <*> reverbControl
        <*> nsControl
        <*> compControl
        <*> wahControl
        <*> samples
        <*> acceptedIn
        <*> lastIn

  -- Noise Suppressor pipeline. Replaces the legacy hard gate. Same
  -- shape: one envelope-input register stage, two feedback registers
  -- (envelope + smoothed gain), one apply register stage. Driven by
  -- noise_suppressor_control (THRESHOLD / DECAY / DAMP / mode); enable
  -- still rides on flag0 (noise_gate_on) of fGate so the existing
  -- set_guitar_effects() API toggles it. Bit-exact bypass when the
  -- flag is clear. The legacy gate frame helpers above are retained
  -- but unused by the active pipeline; the synthesiser drops them.
  nsLevelPipe = register Nothing (mapPipe gateLevelFrame <$> inPipe)
  nsEnv = register 0 (nsEnvNext <$> nsEnv <*> nsLevelPipe)
  nsGain = register gateUnity (nsGainNext <$> nsGain <*> nsEnv <*> nsLevelPipe)
  nsPipe = register Nothing (mapPipe <$> (nsApplyFrame <$> nsGain) <*> nsLevelPipe)

  -- Compressor pipeline. The target-gain computation (threshold decode +
  -- 24-bit multiply + clamp) is registered separately from the gain
  -- smoother (compare + step) via Maybe CompTarget. Nothing cycles pass
  -- through without resetting gain to unity.
  compLevelPipe = register Nothing (mapPipe gateLevelFrame <$> nsPipe)
  compEnv = register 0 (compEnvNext <$> compEnv <*> compLevelPipe)
  compTarget = register Nothing (compTargetNext <$> compEnv <*> compLevelPipe)
  compGain = register gateUnity (compGainSmooth <$> compGain <*> compTarget)
  compApplyPipe = register Nothing (mapPipe <$> (compApplyFrame <$> compGain) <*> compLevelPipe)
  compMakeupPipe = register Nothing (mapPipe compMakeupFrame <$> compApplyPipe)

  -- Wah pipeline. Resonant band-pass between Compressor and Overdrive
  -- (the classic pre-distortion wah position). Driven by wah_control
  -- (POSITION / Q / VOLUME / BIAS + enable). State registers
  -- (posSmooth, fByteR, qBandR, low, band) are pipeline-level so idle
  -- Nothing cycles preserve the SVF state and the smoothed pedal
  -- position. fByteR (= positionToFByte) and qBandR (= q * oldBand)
  -- are pre-registered so the band / low updates never see two
  -- multiplies in series -- this is the timing-friendly version of
  -- the parallel Chamberlin update. Bit-exact bypass when the wah
  -- enable bit is clear.
  wahPosSmooth = register 0 (wahPosSmoothNext <$> wahPosSmooth <*> compMakeupPipe)
  wahFByteR    = register 0 (wahFByteRNext <$> wahFByteR <*> wahPosSmooth <*> compMakeupPipe)
  wahQBandR    = register 0 (wahQBandRNext <$> wahQBandR <*> wahBand     <*> compMakeupPipe)
  wahBand      = register 0 (wahBandNext <$> wahBand <*> wahLow <*> wahQBandR <*> wahFByteR <*> compMakeupPipe)
  wahLow       = register 0 (wahLowNext  <$> wahLow  <*> wahBand <*> wahFByteR <*> compMakeupPipe)
  wahApplyPipe = register Nothing (mapPipe <$> (wahApplyFrame <$> wahBand) <*> compMakeupPipe)

  odDriveMulPipe = register Nothing (mapPipe overdriveDriveMultiplyFrame <$> wahApplyPipe)
  odDriveBoostPipe = register Nothing (mapPipe overdriveDriveBoostFrame <$> odDriveMulPipe)
  odDrivePipe = register Nothing (mapPipe overdriveDriveClipFrame <$> odDriveBoostPipe)

  odTonePrev = register 0 (frameOr monoWet <$> odTonePrev <*> odToneBlendPipe)
  odToneMulPipe = register Nothing (mapPipe <$> (overdriveToneMultiplyFrame <$> odTonePrev) <*> odDrivePipe)
  odToneBlendPipe = register Nothing (mapPipe overdriveToneBlendFrame <$> odToneMulPipe)
  odTonePipe = register Nothing (mapPipe overdriveLevelFrame <$> odToneBlendPipe)

  -- Legacy distortion pipeline. Restored to its pre-refactor shape.
  -- Each stage is gated by `distortionLegacyOn`, which folds in the
  -- "any new pedal mask bit set?" check so that exclusive=True at the
  -- Python level really is exclusive.
  distDriveMulPipe = register Nothing (mapPipe distortionDriveMultiplyFrame <$> odTonePipe)
  distDriveBoostPipe = register Nothing (mapPipe distortionDriveBoostFrame <$> distDriveMulPipe)
  distDrivePipe = register Nothing (mapPipe distortionDriveClipFrame <$> distDriveBoostPipe)

  distTonePrev = register 0 (frameOr monoWet <$> distTonePrev <*> distToneBlendPipe)
  distToneMulPipe = register Nothing (mapPipe <$> (distortionToneMultiplyFrame <$> distTonePrev) <*> distDrivePipe)
  distToneBlendPipe = register Nothing (mapPipe distortionToneBlendFrame <$> distToneMulPipe)
  distTonePipe = register Nothing (mapPipe distortionLevelFrame <$> distToneBlendPipe)

  ratHpInPrev = register 0 (frameOr monoDry <$> ratHpInPrev <*> ratHighpassPipe)
  ratHpOutPrev = register 0 (frameOr monoWet <$> ratHpOutPrev <*> ratHighpassPipe)
  ratHighpassPipe =
    register Nothing $
      mapPipe <$> (ratHighpassFrame <$> ratHpInPrev <*> ratHpOutPrev) <*> distTonePipe
  ratDriveMulPipe = register Nothing (mapPipe ratDriveMultiplyFrame <$> ratHighpassPipe)
  ratDriveBoostPipe = register Nothing (mapPipe ratDriveBoostFrame <$> ratDriveMulPipe)

  ratOpAmpPrev = register 0 (frameOr monoWet <$> ratOpAmpPrev <*> ratOpAmpPipe)
  ratOpAmpPipe = register Nothing (mapPipe <$> (ratOpAmpLowpassFrame <$> ratOpAmpPrev) <*> ratDriveBoostPipe)
  ratClipPipe = register Nothing (mapPipe ratClipFrame <$> ratOpAmpPipe)

  ratPostPrev = register 0 (frameOr monoWet <$> ratPostPrev <*> ratPostPipe)
  ratPostPipe = register Nothing (mapPipe <$> (ratPostLowpassFrame <$> ratPostPrev) <*> ratClipPipe)

  ratTonePrev = register 0 (frameOr monoWet <$> ratTonePrev <*> ratTonePipe)
  ratTonePipe = register Nothing (mapPipe <$> (ratToneFrame <$> ratTonePrev) <*> ratPostPipe)
  ratLevelPipe = register Nothing (mapPipe ratLevelFrame <$> ratTonePipe)
  ratMixPipe = register Nothing (mapPipe ratMixFrame <$> ratLevelPipe)

  -- ---- New per-pedal distortion pipeline. Each section below is a
  -- small, independent register chain with a single enable bit. When
  -- the pedal is off, every stage is bit-exact bypass.

  -- clean_boost (3 stages)
  cleanBoostMulPipe = register Nothing (mapPipe cleanBoostMulFrame <$> ratMixPipe)
  cleanBoostShiftPipe = register Nothing (mapPipe cleanBoostShiftFrame <$> cleanBoostMulPipe)
  cleanBoostLevelPipe = register Nothing (mapPipe cleanBoostLevelFrame <$> cleanBoostShiftPipe)

  -- tube_screamer (6 stages: HPF, ~720 Hz mid-hump biquad, mul, clip,
  -- post-LPF, level). The mid biquad (realism item 3) sits pre-clip so the
  -- boosted mid band drives the clip harder. Its x1/x2 are a 2-tap delay of
  -- the stage input and y1/y2 a 2-tap delay of the stage output -- the same
  -- pipeline-state idiom as the cab delay taps and the RAT prevIn/prevOut.
  tsHpfLpPrev = register 0 (frameOr monoEqLow <$> tsHpfLpPrev <*> tsHpfPipe)
  tsHpfPipe =
    register Nothing $
      mapPipe <$> (tubeScreamerHpfFrame <$> tsHpfLpPrev) <*> cleanBoostLevelPipe
  tsMidX1 = register 0 (delayNext <$> tsMidX1 <*> (frameOr monoSample 0 <$> tsHpfPipe) <*> tsHpfPipe)
  tsMidX2 = register 0 (delayNext <$> tsMidX2 <*> tsMidX1 <*> tsHpfPipe)
  tsMidY1 = register 0 (frameOr monoSample <$> tsMidY1 <*> tsMidPipe)
  tsMidY2 = register 0 (delayNext <$> tsMidY2 <*> tsMidY1 <*> tsMidPipe)
  tsMidPipe =
    register Nothing $
      mapPipe <$> (tubeScreamerMidFrame <$> tsMidX1 <*> tsMidX2 <*> tsMidY1 <*> tsMidY2) <*> tsHpfPipe
  tsMulPipe = register Nothing (mapPipe tubeScreamerMulFrame <$> tsMidPipe)
  tsClipPipe = register Nothing (mapPipe tubeScreamerClipFrame <$> tsMulPipe)
  tsPostLpPrev = register 0 (frameOr monoEqHighLp <$> tsPostLpPrev <*> tsPostLpfPipe)
  tsPostLpfPipe =
    register Nothing $
      mapPipe <$> (tubeScreamerPostLpfFrame <$> tsPostLpPrev) <*> tsClipPipe
  tsLevelPipe = register Nothing (mapPipe tubeScreamerLevelFrame <$> tsPostLpfPipe)

  -- metal_distortion (5 stages with HPF + post-LPF state)
  metalHpfLpPrev = register 0 (frameOr monoEqLow <$> metalHpfLpPrev <*> metalHpfPipe)
  metalHpfPipe =
    register Nothing $
      mapPipe <$> (metalHpfFrame <$> metalHpfLpPrev) <*> tsLevelPipe
  metalMulPipe = register Nothing (mapPipe metalMulFrame <$> metalHpfPipe)
  metalClipPipe = register Nothing (mapPipe metalClipFrame <$> metalMulPipe)
  metalPostLpPrev = register 0 (frameOr monoEqHighLp <$> metalPostLpPrev <*> metalPostLpfPipe)
  metalPostLpfPipe =
    register Nothing $
      mapPipe <$> (metalPostLpfFrame <$> metalPostLpPrev) <*> metalClipPipe
  metalLevelPipe = register Nothing (mapPipe metalLevelFrame <$> metalPostLpfPipe)

  -- ds1 (5 stages with HPF + post-LPF state)
  ds1HpfLpPrev = register 0 (frameOr monoEqLow <$> ds1HpfLpPrev <*> ds1HpfPipe)
  ds1HpfPipe =
    register Nothing $
      mapPipe <$> (ds1HpfFrame <$> ds1HpfLpPrev) <*> metalLevelPipe
  ds1MulPipe = register Nothing (mapPipe ds1MulFrame <$> ds1HpfPipe)
  ds1ClipPipe = register Nothing (mapPipe ds1ClipFrame <$> ds1MulPipe)
  ds1TonePrev = register 0 (frameOr monoEqHighLp <$> ds1TonePrev <*> ds1TonePipe)
  ds1TonePipe =
    register Nothing $
      mapPipe <$> (ds1ToneFrame <$> ds1TonePrev) <*> ds1ClipPipe
  ds1LevelPipe = register Nothing (mapPipe ds1LevelFrame <$> ds1TonePipe)

  -- big_muff (7 stages: pre, clip1, clip2, mid-scoop feedforward, mid-scoop
  -- recursive, tone+state, level). The ~700 Hz mid-scoop notch (realism item
  -- 3, D82) sits post-clip so it carves the scoop out of the saturated signal
  -- -- the Muff's defining tone-network shape a one-pole LPF cannot make. The
  -- biquad is split: the feedforward stage precomputes b0*x+b1*x1+b2*x2 into
  -- fAcc3L (no feedback, freely pipelined), the recursive stage closes the
  -- loop with only -a1*y1-a2*y2 (shorter single-cycle feedback path; the
  -- single-stage 5-mul form pressured the DS-1 P&R to WNS -0.659). x1/x2 are a
  -- 2-tap delay of the feedforward input, y1/y2 a 2-tap delay of the recursive
  -- output.
  bigMuffPrePipe = register Nothing (mapPipe bigMuffPreFrame <$> ds1LevelPipe)
  bigMuffClip1Pipe = register Nothing (mapPipe bigMuffClip1Frame <$> bigMuffPrePipe)
  bigMuffClip2Pipe = register Nothing (mapPipe bigMuffClip2Frame <$> bigMuffClip1Pipe)
  bmScoopX1 = register 0 (delayNext <$> bmScoopX1 <*> (frameOr monoSample 0 <$> bigMuffClip2Pipe) <*> bigMuffClip2Pipe)
  bmScoopX2 = register 0 (delayNext <$> bmScoopX2 <*> bmScoopX1 <*> bigMuffClip2Pipe)
  bigMuffScoopFfPipe =
    register Nothing $
      mapPipe <$> (bigMuffScoopFeedforwardFrame <$> bmScoopX1 <*> bmScoopX2) <*> bigMuffClip2Pipe
  bmScoopY1 = register 0 (frameOr monoSample <$> bmScoopY1 <*> bigMuffScoopRecPipe)
  bmScoopY2 = register 0 (delayNext <$> bmScoopY2 <*> bmScoopY1 <*> bigMuffScoopRecPipe)
  bigMuffScoopRecPipe =
    register Nothing $
      mapPipe <$> (bigMuffScoopRecursiveFrame <$> bmScoopY1 <*> bmScoopY2) <*> bigMuffScoopFfPipe
  bigMuffTonePrev = register 0 (frameOr monoEqHighLp <$> bigMuffTonePrev <*> bigMuffTonePipe)
  bigMuffTonePipe =
    register Nothing $
      mapPipe <$> (bigMuffToneFrame <$> bigMuffTonePrev) <*> bigMuffScoopRecPipe
  bigMuffLevelPipe = register Nothing (mapPipe bigMuffLevelFrame <$> bigMuffTonePipe)

  -- fuzz_face (4 stages: pre, asym clip, tone+state, level)
  fuzzFacePrePipe = register Nothing (mapPipe fuzzFacePreFrame <$> bigMuffLevelPipe)
  fuzzFaceClipPipe = register Nothing (mapPipe fuzzFaceClipFrame <$> fuzzFacePrePipe)
  fuzzFaceTonePrev = register 0 (frameOr monoEqHighLp <$> fuzzFaceTonePrev <*> fuzzFaceTonePipe)
  fuzzFaceTonePipe =
    register Nothing $
      mapPipe <$> (fuzzFaceToneFrame <$> fuzzFaceTonePrev) <*> fuzzFaceClipPipe
  fuzzFaceLevelPipe = register Nothing (mapPipe fuzzFaceLevelFrame <$> fuzzFaceTonePipe)

  -- Output of the new pedal section feeds the rest of the chain.
  distortionPedalsPipe = fuzzFaceLevelPipe

  ampHpInPrev = register 0 (frameOr monoDry <$> ampHpInPrev <*> ampHighpassPipe)
  ampHpOutPrev = register 0 (frameOr monoWet <$> ampHpOutPrev <*> ampHighpassPipe)
  ampHighpassPipe =
    register Nothing $
      mapPipe <$> (ampHighpassFrame <$> ampHpInPrev <*> ampHpOutPrev) <*> distortionPedalsPipe
  ampDriveMulPipe = register Nothing (mapPipe ampDriveMultiplyFrame <$> ampHighpassPipe)
  ampDriveBoostPipe = register Nothing (mapPipe ampDriveBoostFrame <$> ampDriveMulPipe)
  ampShapePipe = register Nothing (mapPipe ampWaveshapeFrame <$> ampDriveBoostPipe)

  ampPreLpPrev = register 0 (frameOr monoWet <$> ampPreLpPrev <*> ampPreLowpassPipe)
  ampPreLowpassPipe = register Nothing (mapPipe <$> (ampPreLowpassFrame <$> ampPreLpPrev) <*> ampShapePipe)
  ampStage2MulPipe = register Nothing (mapPipe ampSecondStageMultiplyFrame <$> ampPreLowpassPipe)
  ampStage2Pipe = register Nothing (mapPipe ampSecondStageFrame <$> ampStage2MulPipe)

  ampToneLowPrev = register 0 (frameOr monoEqLow <$> ampToneLowPrev <*> ampToneFilterPipe)
  ampToneHighPrev = register 0 (frameOr monoEqHighLp <$> ampToneHighPrev <*> ampToneFilterPipe)
  ampToneFilterPipe =
    register Nothing $
      mapPipe <$> (ampToneFilterFrame <$> ampToneLowPrev <*> ampToneHighPrev) <*> ampStage2Pipe
  ampToneBandPipe = register Nothing (mapPipe ampToneBandFrame <$> ampToneFilterPipe)
  ampToneProductsPipe = register Nothing (mapPipe ampToneProductsFrame <$> ampToneBandPipe)
  ampToneMixPipe = register Nothing (mapPipe ampToneMixFrame <$> ampToneProductsPipe)
  ampPowerPipe = register Nothing (mapPipe ampPowerFrame <$> ampToneMixPipe)

  ampResPrev = register 0 (frameOr monoEqLow <$> ampResPrev <*> ampResPresenceFilterPipe)
  ampPresencePrev = register 0 (frameOr monoEqHighLp <$> ampPresencePrev <*> ampResPresenceFilterPipe)
  ampResPresenceFilterPipe =
    register Nothing $
      mapPipe <$> (ampResPresenceFilterFrame <$> ampResPrev <*> ampPresencePrev) <*> ampPowerPipe
  ampResPresenceProductsPipe = register Nothing (mapPipe ampResPresenceProductsFrame <$> ampResPresenceFilterPipe)
  ampResPresencePipe = register Nothing (mapPipe ampResPresenceMixFrame <$> ampResPresenceProductsPipe)
  ampMasterPipe = register Nothing (mapPipe ampMasterFrame <$> ampResPresencePipe)

  cabD1 = register 0 (delayNext <$> cabD1 <*> (frameOr monoSample 0 <$> ampMasterPipe) <*> ampMasterPipe)
  cabD2 = register 0 (delayNext <$> cabD2 <*> cabD1 <*> ampMasterPipe)
  cabD3 = register 0 (delayNext <$> cabD3 <*> cabD2 <*> ampMasterPipe)
  cabProductsPipe =
    register Nothing $
      mapPipe <$> (cabProductsFrame <$> cabD1 <*> cabD2 <*> cabD3) <*> ampMasterPipe
  cabSatPipe = register Nothing (mapPipe cabSatFrame <$> cabProductsPipe)
  cabIrPipe = register Nothing (mapPipe cabIrFrame <$> cabSatPipe)
  cabMixPipe = register Nothing (mapPipe cabLevelMixFrame <$> cabIrPipe)

  eqLowPrev = register 0 (frameOr monoEqLow <$> eqLowPrev <*> eqFilterPipe)
  eqHighPrev = register 0 (frameOr monoEqHighLp <$> eqHighPrev <*> eqFilterPipe)
  eqFilterPipe =
    register Nothing $
      mapPipe <$> (eqFilterFrame <$> eqLowPrev <*> eqHighPrev) <*> cabMixPipe
  eqBandPipe = register Nothing (mapPipe eqBandFrame <$> eqFilterPipe)
  eqProductsPipe = register Nothing (mapPipe eqProductsFrame <$> eqBandPipe)
  eqMixPipe = register Nothing (mapPipe eqMixFrame <$> eqProductsPipe)

  reverbAddr = register 0 (addrNext <$> reverbAddr <*> eqMixPipe)
  addrPipe = register Nothing (attachAddr <$> reverbAddr <*> eqMixPipe)
  reverb = blockRam zeroReverb reverbAddr (writeReverb <$> outPipe)

  reverbTonePrev = register 0 (frameOr monoWet <$> reverbTonePrev <*> reverbToneBlendPipe)
  reverbToneProductsPipe =
    register Nothing $
      reverbToneProductsFrame
        <$> reverb
        <*> reverbTonePrev
        <*> addrPipe
  reverbToneBlendPipe = register Nothing (mapPipe reverbToneBlendFrame <$> reverbToneProductsPipe)
  reverbFeedbackProductsPipe = register Nothing (mapPipe reverbFeedbackProductsFrame <$> reverbToneBlendPipe)
  reverbFeedbackPipe = register Nothing (mapPipe reverbFeedbackFrame <$> reverbFeedbackProductsPipe)
  reverbMixProductsPipe = register Nothing (mapPipe reverbMixProductsFrame <$> reverbFeedbackPipe)
  outPipe = register Nothing (mapPipe reverbMixFrame <$> reverbMixProductsPipe)
  outReg = register emptyAxisOut (nextAxisOut <$> outReg <*> outPipe <*> readyOut)
