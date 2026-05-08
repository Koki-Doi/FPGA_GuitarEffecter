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
import AudioLab.FixedPoint
import AudioLab.Types

frameOr :: (Frame -> Sample) -> Sample -> Maybe Frame -> Sample
frameOr _ old Nothing = old
frameOr f _ (Just x) = f x

delayNext :: Sample -> Sample -> Maybe Frame -> Sample
delayNext old incoming pipe = if isActive pipe then incoming else old
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
  -> Signal AudioDomain (BitVector 48)
  -> Signal AudioDomain Bool
  -> Signal AudioDomain Bool
  -> Signal AudioDomain Bool
  -> ( Signal AudioDomain (BitVector 48)
     , Signal AudioDomain Bool
     , Signal AudioDomain Bool
     , Signal AudioDomain Bool
     )
fxPipeline gateControl odControl distControl eqControl ratControl ampControl ampToneControl cabControl reverbControl nsControl compControl samples validIn lastIn readyOut =
  pipeline
 where
  pipeline =
    ( oData <$> outReg
    , oValid <$> outReg
    , oLast <$> outReg
    , readyOut
    )

  acceptedIn = (&&) <$> validIn <*> readyOut

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

  -- Compressor pipeline. Sits between the noise suppressor and the
  -- overdrive: tightens picking before the gain stages. Same shape as
  -- the noise suppressor (one envelope-input register stage, two
  -- feedback registers, one apply stage) plus a separate makeup
  -- multiply stage so each register stage holds a single multiply.
  -- Bit-exact bypass when the enable bit (fComp ctrlD bit 7) is clear.
  compLevelPipe = register Nothing (mapPipe gateLevelFrame <$> nsPipe)
  compEnv = register 0 (compEnvNext <$> compEnv <*> compLevelPipe)
  compGain = register gateUnity (compGainNext <$> compGain <*> compEnv <*> compLevelPipe)
  compApplyPipe = register Nothing (mapPipe <$> (compApplyFrame <$> compGain) <*> compLevelPipe)
  compMakeupPipe = register Nothing (mapPipe compMakeupFrame <$> compApplyPipe)

  odDriveMulPipe = register Nothing (mapPipe overdriveDriveMultiplyFrame <$> compMakeupPipe)
  odDriveBoostPipe = register Nothing (mapPipe overdriveDriveBoostFrame <$> odDriveMulPipe)
  odDrivePipe = register Nothing (mapPipe overdriveDriveClipFrame <$> odDriveBoostPipe)

  odTonePrevL = register 0 (frameOr fWetL <$> odTonePrevL <*> odToneBlendPipe)
  odTonePrevR = register 0 (frameOr fWetR <$> odTonePrevR <*> odToneBlendPipe)
  odToneMulPipe = register Nothing (mapPipe <$> (overdriveToneMultiplyFrame <$> odTonePrevL <*> odTonePrevR) <*> odDrivePipe)
  odToneBlendPipe = register Nothing (mapPipe overdriveToneBlendFrame <$> odToneMulPipe)
  odTonePipe = register Nothing (mapPipe overdriveLevelFrame <$> odToneBlendPipe)

  -- Legacy distortion pipeline. Restored to its pre-refactor shape.
  -- Each stage is gated by `distortionLegacyOn`, which folds in the
  -- "any new pedal mask bit set?" check so that exclusive=True at the
  -- Python level really is exclusive.
  distDriveMulPipe = register Nothing (mapPipe distortionDriveMultiplyFrame <$> odTonePipe)
  distDriveBoostPipe = register Nothing (mapPipe distortionDriveBoostFrame <$> distDriveMulPipe)
  distDrivePipe = register Nothing (mapPipe distortionDriveClipFrame <$> distDriveBoostPipe)

  distTonePrevL = register 0 (frameOr fWetL <$> distTonePrevL <*> distToneBlendPipe)
  distTonePrevR = register 0 (frameOr fWetR <$> distTonePrevR <*> distToneBlendPipe)
  distToneMulPipe = register Nothing (mapPipe <$> (distortionToneMultiplyFrame <$> distTonePrevL <*> distTonePrevR) <*> distDrivePipe)
  distToneBlendPipe = register Nothing (mapPipe distortionToneBlendFrame <$> distToneMulPipe)
  distTonePipe = register Nothing (mapPipe distortionLevelFrame <$> distToneBlendPipe)

  ratHpInPrevL = register 0 (frameOr fDryL <$> ratHpInPrevL <*> ratHighpassPipe)
  ratHpInPrevR = register 0 (frameOr fDryR <$> ratHpInPrevR <*> ratHighpassPipe)
  ratHpOutPrevL = register 0 (frameOr fWetL <$> ratHpOutPrevL <*> ratHighpassPipe)
  ratHpOutPrevR = register 0 (frameOr fWetR <$> ratHpOutPrevR <*> ratHighpassPipe)
  ratHighpassPipe =
    register Nothing $
      mapPipe <$> (ratHighpassFrame <$> ratHpInPrevL <*> ratHpInPrevR <*> ratHpOutPrevL <*> ratHpOutPrevR) <*> distTonePipe
  ratDriveMulPipe = register Nothing (mapPipe ratDriveMultiplyFrame <$> ratHighpassPipe)
  ratDriveBoostPipe = register Nothing (mapPipe ratDriveBoostFrame <$> ratDriveMulPipe)

  ratOpAmpPrevL = register 0 (frameOr fWetL <$> ratOpAmpPrevL <*> ratOpAmpPipe)
  ratOpAmpPrevR = register 0 (frameOr fWetR <$> ratOpAmpPrevR <*> ratOpAmpPipe)
  ratOpAmpPipe = register Nothing (mapPipe <$> (ratOpAmpLowpassFrame <$> ratOpAmpPrevL <*> ratOpAmpPrevR) <*> ratDriveBoostPipe)
  ratClipPipe = register Nothing (mapPipe ratClipFrame <$> ratOpAmpPipe)

  ratPostPrevL = register 0 (frameOr fWetL <$> ratPostPrevL <*> ratPostPipe)
  ratPostPrevR = register 0 (frameOr fWetR <$> ratPostPrevR <*> ratPostPipe)
  ratPostPipe = register Nothing (mapPipe <$> (ratPostLowpassFrame <$> ratPostPrevL <*> ratPostPrevR) <*> ratClipPipe)

  ratTonePrevL = register 0 (frameOr fWetL <$> ratTonePrevL <*> ratTonePipe)
  ratTonePrevR = register 0 (frameOr fWetR <$> ratTonePrevR <*> ratTonePipe)
  ratTonePipe = register Nothing (mapPipe <$> (ratToneFrame <$> ratTonePrevL <*> ratTonePrevR) <*> ratPostPipe)
  ratLevelPipe = register Nothing (mapPipe ratLevelFrame <$> ratTonePipe)
  ratMixPipe = register Nothing (mapPipe ratMixFrame <$> ratLevelPipe)

  -- ---- New per-pedal distortion pipeline. Each section below is a
  -- small, independent register chain with a single enable bit. When
  -- the pedal is off, every stage is bit-exact bypass.

  -- clean_boost (3 stages)
  cleanBoostMulPipe = register Nothing (mapPipe cleanBoostMulFrame <$> ratMixPipe)
  cleanBoostShiftPipe = register Nothing (mapPipe cleanBoostShiftFrame <$> cleanBoostMulPipe)
  cleanBoostLevelPipe = register Nothing (mapPipe cleanBoostLevelFrame <$> cleanBoostShiftPipe)

  -- tube_screamer (5 stages with HPF + post-LPF state)
  tsHpfLpPrevL = register 0 (frameOr fEqLowL <$> tsHpfLpPrevL <*> tsHpfPipe)
  tsHpfLpPrevR = register 0 (frameOr fEqLowR <$> tsHpfLpPrevR <*> tsHpfPipe)
  tsHpfPipe =
    register Nothing $
      mapPipe <$> (tubeScreamerHpfFrame <$> tsHpfLpPrevL <*> tsHpfLpPrevR) <*> cleanBoostLevelPipe
  tsMulPipe = register Nothing (mapPipe tubeScreamerMulFrame <$> tsHpfPipe)
  tsClipPipe = register Nothing (mapPipe tubeScreamerClipFrame <$> tsMulPipe)
  tsPostLpPrevL = register 0 (frameOr fEqHighLpL <$> tsPostLpPrevL <*> tsPostLpfPipe)
  tsPostLpPrevR = register 0 (frameOr fEqHighLpR <$> tsPostLpPrevR <*> tsPostLpfPipe)
  tsPostLpfPipe =
    register Nothing $
      mapPipe <$> (tubeScreamerPostLpfFrame <$> tsPostLpPrevL <*> tsPostLpPrevR) <*> tsClipPipe
  tsLevelPipe = register Nothing (mapPipe tubeScreamerLevelFrame <$> tsPostLpfPipe)

  -- metal_distortion (5 stages with HPF + post-LPF state)
  metalHpfLpPrevL = register 0 (frameOr fEqLowL <$> metalHpfLpPrevL <*> metalHpfPipe)
  metalHpfLpPrevR = register 0 (frameOr fEqLowR <$> metalHpfLpPrevR <*> metalHpfPipe)
  metalHpfPipe =
    register Nothing $
      mapPipe <$> (metalHpfFrame <$> metalHpfLpPrevL <*> metalHpfLpPrevR) <*> tsLevelPipe
  metalMulPipe = register Nothing (mapPipe metalMulFrame <$> metalHpfPipe)
  metalClipPipe = register Nothing (mapPipe metalClipFrame <$> metalMulPipe)
  metalPostLpPrevL = register 0 (frameOr fEqHighLpL <$> metalPostLpPrevL <*> metalPostLpfPipe)
  metalPostLpPrevR = register 0 (frameOr fEqHighLpR <$> metalPostLpPrevR <*> metalPostLpfPipe)
  metalPostLpfPipe =
    register Nothing $
      mapPipe <$> (metalPostLpfFrame <$> metalPostLpPrevL <*> metalPostLpPrevR) <*> metalClipPipe
  metalLevelPipe = register Nothing (mapPipe metalLevelFrame <$> metalPostLpfPipe)

  -- ds1 (5 stages with HPF + post-LPF state)
  ds1HpfLpPrevL = register 0 (frameOr fEqLowL <$> ds1HpfLpPrevL <*> ds1HpfPipe)
  ds1HpfLpPrevR = register 0 (frameOr fEqLowR <$> ds1HpfLpPrevR <*> ds1HpfPipe)
  ds1HpfPipe =
    register Nothing $
      mapPipe <$> (ds1HpfFrame <$> ds1HpfLpPrevL <*> ds1HpfLpPrevR) <*> metalLevelPipe
  ds1MulPipe = register Nothing (mapPipe ds1MulFrame <$> ds1HpfPipe)
  ds1ClipPipe = register Nothing (mapPipe ds1ClipFrame <$> ds1MulPipe)
  ds1TonePrevL = register 0 (frameOr fEqHighLpL <$> ds1TonePrevL <*> ds1TonePipe)
  ds1TonePrevR = register 0 (frameOr fEqHighLpR <$> ds1TonePrevR <*> ds1TonePipe)
  ds1TonePipe =
    register Nothing $
      mapPipe <$> (ds1ToneFrame <$> ds1TonePrevL <*> ds1TonePrevR) <*> ds1ClipPipe
  ds1LevelPipe = register Nothing (mapPipe ds1LevelFrame <$> ds1TonePipe)

  -- big_muff (5 stages: pre, clip1, clip2, tone+state, level)
  bigMuffPrePipe = register Nothing (mapPipe bigMuffPreFrame <$> ds1LevelPipe)
  bigMuffClip1Pipe = register Nothing (mapPipe bigMuffClip1Frame <$> bigMuffPrePipe)
  bigMuffClip2Pipe = register Nothing (mapPipe bigMuffClip2Frame <$> bigMuffClip1Pipe)
  bigMuffTonePrevL = register 0 (frameOr fEqHighLpL <$> bigMuffTonePrevL <*> bigMuffTonePipe)
  bigMuffTonePrevR = register 0 (frameOr fEqHighLpR <$> bigMuffTonePrevR <*> bigMuffTonePipe)
  bigMuffTonePipe =
    register Nothing $
      mapPipe <$> (bigMuffToneFrame <$> bigMuffTonePrevL <*> bigMuffTonePrevR) <*> bigMuffClip2Pipe
  bigMuffLevelPipe = register Nothing (mapPipe bigMuffLevelFrame <$> bigMuffTonePipe)

  -- fuzz_face (4 stages: pre, asym clip, tone+state, level)
  fuzzFacePrePipe = register Nothing (mapPipe fuzzFacePreFrame <$> bigMuffLevelPipe)
  fuzzFaceClipPipe = register Nothing (mapPipe fuzzFaceClipFrame <$> fuzzFacePrePipe)
  fuzzFaceTonePrevL = register 0 (frameOr fEqHighLpL <$> fuzzFaceTonePrevL <*> fuzzFaceTonePipe)
  fuzzFaceTonePrevR = register 0 (frameOr fEqHighLpR <$> fuzzFaceTonePrevR <*> fuzzFaceTonePipe)
  fuzzFaceTonePipe =
    register Nothing $
      mapPipe <$> (fuzzFaceToneFrame <$> fuzzFaceTonePrevL <*> fuzzFaceTonePrevR) <*> fuzzFaceClipPipe
  fuzzFaceLevelPipe = register Nothing (mapPipe fuzzFaceLevelFrame <$> fuzzFaceTonePipe)

  -- Output of the new pedal section feeds the rest of the chain.
  distortionPedalsPipe = fuzzFaceLevelPipe

  ampHpInPrevL = register 0 (frameOr fDryL <$> ampHpInPrevL <*> ampHighpassPipe)
  ampHpInPrevR = register 0 (frameOr fDryR <$> ampHpInPrevR <*> ampHighpassPipe)
  ampHpOutPrevL = register 0 (frameOr fWetL <$> ampHpOutPrevL <*> ampHighpassPipe)
  ampHpOutPrevR = register 0 (frameOr fWetR <$> ampHpOutPrevR <*> ampHighpassPipe)
  ampHighpassPipe =
    register Nothing $
      mapPipe <$> (ampHighpassFrame <$> ampHpInPrevL <*> ampHpInPrevR <*> ampHpOutPrevL <*> ampHpOutPrevR) <*> distortionPedalsPipe
  ampDriveMulPipe = register Nothing (mapPipe ampDriveMultiplyFrame <$> ampHighpassPipe)
  ampDriveBoostPipe = register Nothing (mapPipe ampDriveBoostFrame <$> ampDriveMulPipe)
  ampShapePipe = register Nothing (mapPipe ampWaveshapeFrame <$> ampDriveBoostPipe)

  ampPreLpPrevL = register 0 (frameOr fWetL <$> ampPreLpPrevL <*> ampPreLowpassPipe)
  ampPreLpPrevR = register 0 (frameOr fWetR <$> ampPreLpPrevR <*> ampPreLowpassPipe)
  ampPreLowpassPipe = register Nothing (mapPipe <$> (ampPreLowpassFrame <$> ampPreLpPrevL <*> ampPreLpPrevR) <*> ampShapePipe)
  ampStage2MulPipe = register Nothing (mapPipe ampSecondStageMultiplyFrame <$> ampPreLowpassPipe)
  ampStage2Pipe = register Nothing (mapPipe ampSecondStageFrame <$> ampStage2MulPipe)

  ampToneLowPrevL = register 0 (frameOr fEqLowL <$> ampToneLowPrevL <*> ampToneFilterPipe)
  ampToneLowPrevR = register 0 (frameOr fEqLowR <$> ampToneLowPrevR <*> ampToneFilterPipe)
  ampToneHighPrevL = register 0 (frameOr fEqHighLpL <$> ampToneHighPrevL <*> ampToneFilterPipe)
  ampToneHighPrevR = register 0 (frameOr fEqHighLpR <$> ampToneHighPrevR <*> ampToneFilterPipe)
  ampToneFilterPipe =
    register Nothing $
      mapPipe <$> (ampToneFilterFrame <$> ampToneLowPrevL <*> ampToneLowPrevR <*> ampToneHighPrevL <*> ampToneHighPrevR) <*> ampStage2Pipe
  ampToneBandPipe = register Nothing (mapPipe ampToneBandFrame <$> ampToneFilterPipe)
  ampToneProductsPipe = register Nothing (mapPipe ampToneProductsFrame <$> ampToneBandPipe)
  ampToneMixPipe = register Nothing (mapPipe ampToneMixFrame <$> ampToneProductsPipe)
  ampPowerPipe = register Nothing (mapPipe ampPowerFrame <$> ampToneMixPipe)

  ampResPrevL = register 0 (frameOr fEqLowL <$> ampResPrevL <*> ampResPresenceFilterPipe)
  ampResPrevR = register 0 (frameOr fEqLowR <$> ampResPrevR <*> ampResPresenceFilterPipe)
  ampPresencePrevL = register 0 (frameOr fEqHighLpL <$> ampPresencePrevL <*> ampResPresenceFilterPipe)
  ampPresencePrevR = register 0 (frameOr fEqHighLpR <$> ampPresencePrevR <*> ampResPresenceFilterPipe)
  ampResPresenceFilterPipe =
    register Nothing $
      mapPipe <$> (ampResPresenceFilterFrame <$> ampResPrevL <*> ampResPrevR <*> ampPresencePrevL <*> ampPresencePrevR) <*> ampPowerPipe
  ampResPresenceProductsPipe = register Nothing (mapPipe ampResPresenceProductsFrame <$> ampResPresenceFilterPipe)
  ampResPresencePipe = register Nothing (mapPipe ampResPresenceMixFrame <$> ampResPresenceProductsPipe)
  ampMasterPipe = register Nothing (mapPipe ampMasterFrame <$> ampResPresencePipe)

  cabD1L = register 0 (delayNext <$> cabD1L <*> (frameOr fL 0 <$> ampMasterPipe) <*> ampMasterPipe)
  cabD1R = register 0 (delayNext <$> cabD1R <*> (frameOr fR 0 <$> ampMasterPipe) <*> ampMasterPipe)
  cabD2L = register 0 (delayNext <$> cabD2L <*> cabD1L <*> ampMasterPipe)
  cabD2R = register 0 (delayNext <$> cabD2R <*> cabD1R <*> ampMasterPipe)
  cabD3L = register 0 (delayNext <$> cabD3L <*> cabD2L <*> ampMasterPipe)
  cabD3R = register 0 (delayNext <$> cabD3R <*> cabD2R <*> ampMasterPipe)
  cabProductsPipe =
    register Nothing $
      mapPipe <$> (cabProductsFrame <$> cabD1L <*> cabD2L <*> cabD3L <*> cabD1R <*> cabD2R <*> cabD3R) <*> ampMasterPipe
  cabIrPipe = register Nothing (mapPipe cabIrFrame <$> cabProductsPipe)
  cabMixPipe = register Nothing (mapPipe cabLevelMixFrame <$> cabIrPipe)

  eqLowPrevL = register 0 (frameOr fEqLowL <$> eqLowPrevL <*> eqFilterPipe)
  eqLowPrevR = register 0 (frameOr fEqLowR <$> eqLowPrevR <*> eqFilterPipe)
  eqHighPrevL = register 0 (frameOr fEqHighLpL <$> eqHighPrevL <*> eqFilterPipe)
  eqHighPrevR = register 0 (frameOr fEqHighLpR <$> eqHighPrevR <*> eqFilterPipe)
  eqFilterPipe =
    register Nothing $
      mapPipe <$> (eqFilterFrame <$> eqLowPrevL <*> eqLowPrevR <*> eqHighPrevL <*> eqHighPrevR) <*> cabMixPipe
  eqBandPipe = register Nothing (mapPipe eqBandFrame <$> eqFilterPipe)
  eqProductsPipe = register Nothing (mapPipe eqProductsFrame <$> eqBandPipe)
  eqMixPipe = register Nothing (mapPipe eqMixFrame <$> eqProductsPipe)

  reverbAddr = register 0 (addrNext <$> reverbAddr <*> eqMixPipe)
  addrPipe = register Nothing (attachAddr <$> reverbAddr <*> eqMixPipe)
  reverbL = blockRam zeroReverb reverbAddr (writeReverbL <$> outPipe)
  reverbR = blockRam zeroReverb reverbAddr (writeReverbR <$> outPipe)

  reverbTonePrevL = register 0 (frameOr fWetL <$> reverbTonePrevL <*> reverbToneBlendPipe)
  reverbTonePrevR = register 0 (frameOr fWetR <$> reverbTonePrevR <*> reverbToneBlendPipe)
  reverbToneProductsPipe =
    register Nothing $
      reverbToneProductsFrame
        <$> reverbL
        <*> reverbR
        <*> reverbTonePrevL
        <*> reverbTonePrevR
        <*> addrPipe
  reverbToneBlendPipe = register Nothing (mapPipe reverbToneBlendFrame <$> reverbToneProductsPipe)
  reverbFeedbackProductsPipe = register Nothing (mapPipe reverbFeedbackProductsFrame <$> reverbToneBlendPipe)
  reverbFeedbackPipe = register Nothing (mapPipe reverbFeedbackFrame <$> reverbFeedbackProductsPipe)
  reverbMixProductsPipe = register Nothing (mapPipe reverbMixProductsFrame <$> reverbFeedbackPipe)
  outPipe = register Nothing (mapPipe reverbMixFrame <$> reverbMixProductsPipe)
  outReg = register emptyAxisOut (nextAxisOut <$> outReg <*> outPipe <*> readyOut)
