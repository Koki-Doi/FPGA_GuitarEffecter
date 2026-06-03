{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Distortion where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

-- ---- Legacy distortion stage -----------------------------------------
-- Restored to its pre-refactor shape so the existing
-- set_guitar_effects(distortion_on=True, distortion=, distortion_tone=,
-- distortion_level=) API keeps working untouched. The legacy stage is
-- automatically bypassed when any new pedal-mask bit is set, so that
-- exclusive=True at the Python level really is exclusive.

distortionLegacyOn :: Frame -> Bool
distortionLegacyOn f = flag2 (fGate f) && not (anyDistPedalOn f)

distortionDriveMultiplyFrame :: Frame -> Frame
distortionDriveMultiplyFrame f =
  f
    { fAccL = if on then mulU12 (monoSample f) driveGain else 0
    , fAccR = 0
    , fAcc2L = resize threshold
    }
 where
  on = distortionLegacyOn f
  amount = ctrlC (fDist f)
  driveGain = resize (256 + (resize amount * 9 :: Unsigned 11)) :: Unsigned 12
  rawThreshold = 8_388_607 - (resize (asSigned9 amount) * 28_000) :: Signed 25
  clampedThreshold = if rawThreshold < 1_600_000 then 1_600_000 else rawThreshold
  threshold = resize clampedThreshold :: Sample

distortionDriveBoostFrame :: Frame -> Frame
distortionDriveBoostFrame f =
  setMonoWet (if on then satShift8 (fAccL f) else monoSample f) f
 where
  on = distortionLegacyOn f

distortionDriveClipFrame :: Frame -> Frame
distortionDriveClipFrame f =
  setMonoSample (if on then hardClip (monoWet f) threshold else monoSample f) f
 where
  on = distortionLegacyOn f
  threshold = resize (fAcc2L f) :: Sample

distortionToneMultiplyFrame :: Sample -> Frame -> Frame
distortionToneMultiplyFrame prev f =
  f
    { fAccL = if on then mulU8 (monoSample f) tone else 0
    , fAccR = 0
    , fAcc2L = if on then mulU8 prev toneInv else 0
    , fAcc2R = 0
    }
 where
  on = distortionLegacyOn f
  tone = ctrlA (fDist f)
  toneInv = 255 - tone

distortionToneBlendFrame :: Frame -> Frame
distortionToneBlendFrame f =
  setMonoWet (if on then tone else monoSample f) f
 where
  on = distortionLegacyOn f
  tone = satShift8 (fAccL f + fAcc2L f)

distortionLevelFrame :: Frame -> Frame
distortionLevelFrame f =
  setMonoSample (if on then out else monoSample f) f
 where
  on = distortionLegacyOn f
  level = ctrlB (fDist f)
  out = satShift7 (mulU8 (monoWet f) level)

-- ---- Pedal-style distortion stages -----------------------------------
-- Each pedal is a small, independently enabled pipeline section. The
-- Frame moves through the same physical stages whether the pedal is on
-- or off; when off, every frame transform leaves fL/fR untouched, so
-- the chain is bit-exact bypass.
--
-- Implemented in this build: clean_boost, tube_screamer, ds1,
-- big_muff, fuzz_face, metal_distortion. rat_style is intentionally a
-- no-op here because the existing RAT stage upstream covers it. Bit 7
-- of the pedal mask remains reserved for an 8th pedal slot.

-- ---- clean_boost (3 stages: mul, shift, level+safety) ---------------

cleanBoostMulFrame :: Frame -> Frame
cleanBoostMulFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = cleanBoostOn f
  drive = ctrlC (fDist f)
  -- Global real-pedal pass: keep the boost mostly clean and let the
  -- level stage, not clipping, provide the push.
  gain = resize (256 + (resize drive * 2 :: Unsigned 11)) :: Unsigned 12

cleanBoostShiftFrame :: Frame -> Frame
cleanBoostShiftFrame f =
  setMonoSample (if on then satShift8 (fAccL f) else monoSample f) f
 where
  on = cleanBoostOn f

cleanBoostLevelFrame :: Frame -> Frame
cleanBoostLevelFrame f =
  setMonoSample (if on then softClipK safetyKnee afterLevel else monoSample f) f
 where
  on = cleanBoostOn f
  level = ctrlB (fDist f)
  afterLevel = satShift7 (mulU8 (monoSample f) level)
  -- High safety knee so Clean Boost only catches exceptional peaks.
  safetyKnee = 3_800_000 :: Sample

-- ---- tube_screamer (5 stages: HPF, mul, clip, post-LPF, level) -------

tubeScreamerHpfFrame :: Sample -> Frame -> Frame
tubeScreamerHpfFrame prevLp f =
  (if on then setMonoSample hp else setMonoSample x) (setMonoEqLow lp f)
 where
  on = tubeScreamerOn f
  -- Stronger low cut into the clip stage for a TS-style mid focus.
  alpha = 4 + (distTight (fOd f) `shiftR` 4)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x
  hp = satWide (resize x - resize lp :: Wide)

-- ~720 Hz mid-hump peaking biquad (realism item 3 / R3). Pre-clip mid
-- emphasis is what gives the Tube Screamer its signature mid-focused drive:
-- the boosted ~720 Hz band is pushed harder into the clip stage than the rest
-- of the spectrum, so the saturation is mid-weighted rather than full-range.
-- Direct-form-I with Q14 fixed coefficients, hand-designed for f0 = 720 Hz,
-- fs = 48 kHz, Q = 0.8, +6 dB peak (a chosen target curve, NOT a
-- schematic-derived table -- same inspired-by policy as the rest of the
-- chain, D7/D45). The coefficients are unity at DC and Nyquist by
-- construction, so the spectrum outside the hump is essentially unchanged.
--   y[n]*2^14 = b0*x + b1*x1 + b2*x2 - a1*y1 - a2*y2  (a0 normalised to 2^14)
--   b0=17036  b1=-31323  b2=14422  ;  a1=-31323  a2=15075  -> -a1 = +31323
-- x1/x2/y1/y2 are pipeline-level state (threaded in Pipeline.hs) so idle
-- Nothing cycles preserve the filter memory. Bit-exact bypass when the pedal
-- is off (output = input). The five multiplies are computed in parallel and
-- summed in an adder tree (no serial multiply chain -- the D79/Wah timing
-- lesson on this island).
tubeScreamerMidFrame :: Sample -> Sample -> Sample -> Sample -> Frame -> Frame
tubeScreamerMidFrame x1 x2 y1 y2 f =
  setMonoSample (if on then y else x) f
 where
  on = tubeScreamerOn f
  x = monoSample f
  acc =
    mulS16 x 17036
      + mulS16 x1 (-31323)
      + mulS16 x2 14422
      + mulS16 y1 31323
      - mulS16 y2 15075 :: Wide
  y = satShift14 acc

tubeScreamerMulFrame :: Frame -> Frame
tubeScreamerMulFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = tubeScreamerOn f
  drive = ctrlC (fDist f)
  -- Smooth drive ceiling; this should stay overdrive-like, not fuzz-like.
  gain = resize (256 + (resize drive * 5 :: Unsigned 12)) :: Unsigned 12

tubeScreamerClipFrame :: Frame -> Frame
tubeScreamerClipFrame f =
  setMonoSample (if on then asymSoftClip kneeP kneeN boosted else monoSample f) f
 where
  on = tubeScreamerOn f
  boosted = satShift8 (fAccL f)
  -- Near-symmetric soft knees keep the TS smoother than DS-1.
  kneeP = 3_000_000 :: Sample
  kneeN = 2_850_000 :: Sample

tubeScreamerPostLpfFrame :: Sample -> Frame -> Frame
tubeScreamerPostLpfFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = tubeScreamerOn f
  tone = ctrlA (fDist f)
  -- Darker post-LPF emphasises the mid band and avoids piercing highs.
  alpha = 56 + (tone `shiftR` 1)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

tubeScreamerLevelFrame :: Frame -> Frame
tubeScreamerLevelFrame f =
  setMonoSample (if on then softClip afterLevel else monoSample f) f
 where
  on = tubeScreamerOn f
  level = ctrlB (fDist f)
  afterLevel = satShift7 (mulU8 (monoSample f) level)

-- ---- metal_distortion (5 stages: tight HPF, mul, hard clip,
--                        post-LPF, level) -----------------------------

metalHpfFrame :: Sample -> Frame -> Frame
metalHpfFrame prevLp f =
  (if on then setMonoSample hp else setMonoSample x) (setMonoEqLow lp f)
 where
  on = metalDistortionOn f
  -- Tight low cut for modern-metal-style palm-mute response.
  alpha = 8 + (distTight (fOd f) `shiftR` 3)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x
  hp = satWide (resize x - resize lp :: Wide)

metalMulFrame :: Frame -> Frame
metalMulFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = metalDistortionOn f
  drive = ctrlC (fDist f)
  -- Higher drive within the existing Q12 gain path; threshold and LPF
  -- below keep the result aggressive without fizzing out.
  gain = resize (768 + (resize drive * 13 :: Unsigned 12)) :: Unsigned 12

metalClipFrame :: Frame -> Frame
metalClipFrame f =
  setMonoSample (if on then hardClip boosted threshold else monoSample f) f
 where
  on = metalDistortionOn f
  drive = ctrlC (fDist f)
  driveS = resize (asSigned9 drive) :: Signed 25
  -- Deeper hard clip than DS-1, held above the bit-crusher danger zone.
  rawT = 3_300_000 - driveS * 6_000 :: Signed 25
  threshold = resize (if rawT < 1_250_000 then 1_250_000 else rawT) :: Sample
  boosted = satShift8 (fAccL f)

metalPostLpfFrame :: Sample -> Frame -> Frame
metalPostLpfFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = metalDistortionOn f
  tone = ctrlA (fDist f)
  -- Dark post-LPF keeps the high-gain top end controlled.
  alpha = 40 + (tone `shiftR` 1)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

metalLevelFrame :: Frame -> Frame
metalLevelFrame f =
  setMonoSample (if on then softClip afterLevel else monoSample f) f
 where
  on = metalDistortionOn f
  level = ctrlB (fDist f)
  afterLevel = satShift7 (mulU8 (monoSample f) level)

-- ---- ds1 (BOSS DS-1 style; 5 stages: HPF, mul, asym hard/soft hybrid
--                clip, post LPF, level+safety) ------------------------
--
-- Voiced for a brighter, edgier crunch than tube_screamer: the input
-- HPF tightens with TIGHT, the asym soft clip uses lower knees so the
-- saturation hits earlier, and the post LPF starts brighter so the top
-- end stays present even at moderate TONE. Reference: BOSS DS-1 only
-- by name and parameter idea; no schematics, no reference source code.

ds1HpfFrame :: Sample -> Frame -> Frame
ds1HpfFrame prevLp f =
  (if on then setMonoSample hp else setMonoSample x) (setMonoEqLow lp f)
 where
  on = ds1On f
  -- Moderate input low cut; tighter than TS, looser than metal.
  alpha = 5 + (distTight (fOd f) `shiftR` 4)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x
  hp = satWide (resize x - resize lp :: Wide)

ds1MulFrame :: Frame -> Frame
ds1MulFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = ds1On f
  drive = ctrlC (fDist f)
  -- More push than TS and intentionally harder-edged.
  gain = resize (256 + (resize drive * 9 :: Unsigned 12)) :: Unsigned 12

ds1ClipFrame :: Frame -> Frame
ds1ClipFrame f =
  setMonoSample (if on then asymSoftClip kneeP kneeN boosted else monoSample f) f
 where
  on = ds1On f
  boosted = satShift8 (fAccL f)
  -- Lower knees than TS for a harder edge but still soft (DS-1 has
  -- diode-pair hard clip; we approximate with asym soft to keep
  -- timing comparable to the existing pedals).
  kneeP = 1_900_000 :: Sample
  kneeN = 1_900_000 :: Sample

ds1ToneFrame :: Sample -> Frame -> Frame
ds1ToneFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = ds1On f
  tone = ctrlA (fDist f)
  -- Brighter than TS; cutting top end without full pass-through.
  alpha = 104 + (tone `shiftR` 1)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

ds1LevelFrame :: Frame -> Frame
ds1LevelFrame f =
  setMonoSample (if on then softClipK safetyKnee afterLevel else monoSample f) f
 where
  on = ds1On f
  level = ctrlB (fDist f)
  afterLevel = satShift7 (mulU8 (monoSample f) level)
  -- Output safety: the level stage soft-clips before reaching the
  -- post-pedal pipeline so a misuse of LEVEL cannot slam the saturator.
  safetyKnee = 3_000_000 :: Sample

-- ---- big_muff (Big Muff Pi style; 5 stages: pre-gain, clip1, clip2,
--                tone scoop, level+safety) ----------------------------
--
-- Voiced for thick fuzz/distortion: heavier pre gain than DS-1, two
-- cascaded soft clip stages for sustaining wall-of-sound saturation,
-- a darker tone LPF to keep fizz off the top end. Reference:
-- Electro-Harmonix Big Muff Pi only by name and parameter idea; no
-- schematics, no reference source code.

bigMuffPreFrame :: Frame -> Frame
bigMuffPreFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = bigMuffOn f
  drive = ctrlC (fDist f)
  -- Hot floor and broad sustain, but keep the ceiling below Metal.
  gain = resize (448 + (resize drive * 11 :: Unsigned 12)) :: Unsigned 12

bigMuffClip1Frame :: Frame -> Frame
bigMuffClip1Frame f =
  setMonoSample (if on then softClipK kneeFirst boosted else monoSample f) f
 where
  on = bigMuffOn f
  boosted = satShift8 (fAccL f)
  -- First clip stage: earlier soft compression for sustain.
  kneeFirst = 2_400_000 :: Sample

bigMuffClip2Frame :: Frame -> Frame
bigMuffClip2Frame f =
  setMonoSample (if on then softClipK kneeSecond afterMore else monoSample f) f
 where
  on = bigMuffOn f
  -- Existing second clip stage: a little more push into a tighter knee
  -- for thicker sustain without adding another cascade.
  afterMore = satShift8 (mulU8 (monoSample f) 208)
  kneeSecond = 1_850_000 :: Sample

-- ~700 Hz mid-scoop NOTCH biquad (realism item 3 / R3, D82), split into a
-- feedforward stage + a recursive stage. The Big Muff's defining tone-network
-- character is a deep mid *scoop* -- a one-pole LPF (bigMuffToneFrame below)
-- can only darken, it cannot notch the mids. This post-clip peaking biquad
-- with NEGATIVE gain carves the scoop out of the saturated signal.
-- Direct-form-I, Q14 fixed coefficients, hand-designed for f0 = 700 Hz,
-- fs = 48 kHz, Q = 0.8, -10 dB dip (a chosen target curve, NOT a
-- schematic-derived table -- same policy as the TS mid hump, D7/D45). Unity
-- at DC and Nyquist by construction so only the mids are scooped.
--   y[n]*2^14 = b0*x + b1*x1 + b2*x2 - a1*y1 - a2*y2  (a0 normalised to 2^14)
--   b0=15350  b1=-29618  b2=14393  ;  a1=-29618  a2=13359  -> -a1 = +29618
--
-- TIMING SPLIT (D82): the single-stage 5-multiply form measured island
-- WNS -0.659 ns (the biquad feedback path was near-critical and pressured the
-- DS-1 P&R). The IIR feedback loop CANNOT be naively pipelined (it would
-- change the transfer function), so instead the FEEDFORWARD sum
-- (b0*x + b1*x1 + b2*x2, no feedback) is precomputed one stage earlier into
-- fAcc3L; the recursive stage then closes the loop with only TWO multiplies
-- (-a1*y1 - a2*y2), shortening the single-cycle feedback path. The math is
-- identical to the single-stage form (same coefficients, same response).
-- x1/x2 are a 2-tap delay of the stage input, y1/y2 of the recursive output;
-- bit-exact bypass when the pedal is off (output = input).
bigMuffScoopFeedforwardFrame :: Sample -> Sample -> Frame -> Frame
bigMuffScoopFeedforwardFrame x1 x2 f =
  setMonoAcc3 (if on then ff else 0) f
 where
  on = bigMuffOn f
  x = monoSample f
  ff = mulS16 x 15350 + mulS16 x1 (-29618) + mulS16 x2 14393 :: Wide

bigMuffScoopRecursiveFrame :: Sample -> Sample -> Frame -> Frame
bigMuffScoopRecursiveFrame y1 y2 f =
  setMonoSample (if on then y else monoSample f) f
 where
  on = bigMuffOn f
  -- -a1 = +29618, -a2 = -13359; fAcc3L already holds the feedforward sum.
  y = satShift14 (fAcc3L f + mulS16 y1 29618 - mulS16 y2 13359)

bigMuffToneFrame :: Sample -> Frame -> Frame
bigMuffToneFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = bigMuffOn f
  tone = ctrlA (fDist f)
  -- Darker tone curve keeps top-end fizz off the output.
  alpha = 48 + (tone `shiftR` 1)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

bigMuffLevelFrame :: Frame -> Frame
bigMuffLevelFrame f =
  setMonoSample (if on then softClipK safetyKnee afterLevel else monoSample f) f
 where
  on = bigMuffOn f
  level = ctrlB (fDist f)
  afterLevel = satShift7 (mulU8 (monoSample f) level)
  -- Output safety knee leaves sustain but avoids level-stage collapse.
  safetyKnee = 3_100_000 :: Sample

-- ---- fuzz_face (Fuzz Face style; 4 stages: pre-gain, asym clip,
--                tone, level+safety) ----------------------------------
--
-- Voiced for raw, asymmetric fuzz: the pre stage already has a hot
-- floor so even DRIVE=0 produces some breakup, the clip stage uses
-- aggressively low asymmetric knees so the negative half compresses
-- harder than the positive half, and the tone LPF maps to a
-- "round vs. bright" axis since real Fuzz Faces typically have no
-- tone control. Reference: Dallas Arbiter / Dunlop Fuzz Face only by
-- name and parameter idea; no schematics, no reference source code.

fuzzFacePreFrame :: Frame -> Frame
fuzzFacePreFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = fuzzFaceOn f
  drive = ctrlC (fDist f)
  -- Lower ceiling and hot asymmetry preserve cleanup without gating out.
  gain = resize (448 + (resize drive * 8 :: Unsigned 12)) :: Unsigned 12

-- Fuzz Face dynamic bias envelope (realism item 5b / R2). A peak-follower on
-- the post-pre-gain ("boosted") level, same shape as the Compressor /
-- NoiseSuppressor envelopes (instant attack, linear release, reset to 0 when
-- the pedal is off so OFF stays bit-exact). The clip stage uses it to drift
-- the knees with the playing level -- the level-dependent behaviour a static
-- waveshaper lacks. No multiply (abs + shift + compare only), so no new DSP.
ffBiasReleaseStep :: Sample
ffBiasReleaseStep = 4096

fuzzFaceBiasEnvNext :: Sample -> Maybe Frame -> Sample
fuzzFaceBiasEnvNext env Nothing = env
fuzzFaceBiasEnvNext env (Just f)
  | not (fuzzFaceOn f)        = 0
  | level > env               = level
  | env > ffBiasReleaseStep   = env - ffBiasReleaseStep
  | otherwise                 = 0
 where
  level = abs24 (satShift8 (fAccL f))

fuzzFaceClipFrame :: Sample -> Frame -> Frame
fuzzFaceClipFrame env f =
  setMonoSample (if on then asymSoftClip kneeP kneeN boosted else monoSample f) f
 where
  on = fuzzFaceOn f
  boosted = satShift8 (fAccL f)
  -- Dynamic bias (item 5b): the knees drift with the playing-level envelope.
  -- Soft playing / rolled-back guitar volume -> low env -> the base
  -- asymmetric Ge knees (cleaner, more open); hard picking -> high env ->
  -- knees pull together (harder, more symmetric compression / sputter under
  -- load). Bounded (biasShift capped) and clamped so kneeP never collapses;
  -- env = 0 on bypass keeps OFF bit-exact.
  rawShift = env `shiftR` 4
  biasShift = if rawShift > 500_000 then 500_000 else rawShift
  -- Base asymmetry: negative half compresses harder, positive keeps cleanup room.
  kneeP = 2_100_000 - biasShift :: Sample
  kneeN = 1_150_000 + (biasShift `shiftR` 1) :: Sample

fuzzFaceToneFrame :: Sample -> Frame -> Frame
fuzzFaceToneFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = fuzzFaceOn f
  tone = ctrlA (fDist f)
  -- "Round vs. bright", still rolling off the very top.
  alpha = 80 + (tone `shiftR` 1)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

fuzzFaceLevelFrame :: Frame -> Frame
fuzzFaceLevelFrame f =
  setMonoSample (if on then softClipK safetyKnee afterLevel else monoSample f) f
 where
  on = fuzzFaceOn f
  level = ctrlB (fDist f)
  afterLevel = satShift7 (mulU8 (monoSample f) level)
  -- Output safety knee avoids gated collapse at high LEVEL.
  safetyKnee = 3_000_000 :: Sample

ratHighpassFrame :: Sample -> Sample -> Frame -> Frame
ratHighpassFrame prevIn prevOut f =
  setMonoWet (if on then highpass x prevIn prevOut else x) (setMonoDry x f)
 where
  on = flag4 (fGate f)
  x = monoSample f
  highpass x prevIn prevOut =
    satWide (resize x - resize prevIn + ((resize prevOut :: Wide) * 255 `shiftR` 8))

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
  alpha = 184 - resize (ctrlC (fRat f) `shiftR` 1) :: Unsigned 8
  low = onePoleU8 alpha prev (monoWet f)

ratClipFrame :: Frame -> Frame
ratClipFrame f =
  setMonoWet (if on then hardClip (monoWet f) threshold else monoSample f) f
 where
  on = flag4 (fGate f)
  amount = ctrlC (fRat f)
  -- Fat old-op-amp hard clip; rougher than DS-1, less modern than Metal.
  rawThreshold = 6_000_000 - (resize (asSigned9 amount) * 8_500) :: Signed 25
  clampedThreshold = if rawThreshold < 2_200_000 then 2_200_000 else rawThreshold
  threshold = resize clampedThreshold :: Sample

ratPostLowpassFrame :: Sample -> Frame -> Frame
-- Global real-pedal pass: roll off more high-frequency content after the
-- hard clip, matching the darker top end of a real RAT.
ratPostLowpassFrame prev f =
  setMonoWet (if on then onePoleU8 168 prev (monoWet f) else monoSample f) f
 where
  on = flag4 (fGate f)

ratToneFrame :: Sample -> Frame -> Frame
ratToneFrame prev f =
  setMonoWet (if on then onePoleU8 alpha prev (monoWet f) else monoSample f) f
 where
  on = flag4 (fGate f)
  dark = resize ((resize (ctrlA (fRat f)) * 3 :: Unsigned 10) `shiftR` 2) :: Unsigned 8
  -- Darker FILTER base so fully bright still has upper roll-off.
  alpha = 192 - dark

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
