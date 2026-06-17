{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Distortion.Pedals where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types
import AudioLab.Effects.Distortion.Common

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
  afterLevel = distLevelRaw (monoSample f) level   -- refactor C: shared kernel
  -- High safety knee so Clean Boost only catches exceptional peaks.
  safetyKnee = 3_800_000 :: Sample

-- ---- tube_screamer (5 stages: HPF, mul, clip, post-LPF, level) -------

tubeScreamerHpfFrame :: Sample -> Frame -> Frame
tubeScreamerHpfFrame prevLp f =
  (if on then setMonoSample hp else setMonoSample x) (setMonoEqLow lp f)
 where
  on = tubeScreamerOn f
  -- Stronger low cut into the clip stage for a TS-style mid focus.
  -- 96 kHz: bilinear-refit (was 4 + tight>>4) to hold the same HPF corner Hz.
  alpha = 2 + (distTight (fOd f) `shiftR` 5)
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
  -- 96 kHz RBJ coeffs (720 Hz, Q 0.8, +6 dB); was 17036/-31323/14422/31323/15075 @48k.
  acc =
    mulS16 x 16717
      + mulS16 x1 (-32063)
      + mulS16 x2 15382
      + mulS16 y1 32063
      - mulS16 y2 15715 :: Wide
  y = satShift14 acc

tubeScreamerMulFrame :: Frame -> Frame
tubeScreamerMulFrame f =
  f { fAccL = if on then mulU12 (monoSample f) gain else 0
    , fAccR = 0 }
 where
  on = tubeScreamerOn f
  drive = ctrlC (fDist f)
  -- Smooth drive ceiling; this should stay overdrive-like, not fuzz-like.
  gain = pedalDriveGain 256 5 drive    -- refactor C: shared kernel

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
  -- 96 kHz: bilinear-refit (was 56 + tone>>1) to hold the same LPF corner Hz.
  alpha = 30 + (tone `shiftR` 2)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

tubeScreamerLevelFrame :: Frame -> Frame
tubeScreamerLevelFrame f =
  setMonoSample (if on then softClip afterLevel else monoSample f) f
 where
  on = tubeScreamerOn f
  level = ctrlB (fDist f)
  afterLevel = distLevelRaw (monoSample f) level   -- refactor C: shared kernel

-- ---- metal_distortion (5 stages: tight HPF, mul, hard clip,
--                        post-LPF, level) -----------------------------

metalHpfFrame :: Sample -> Frame -> Frame
metalHpfFrame prevLp f =
  (if on then setMonoSample hp else setMonoSample x) (setMonoEqLow lp f)
 where
  on = metalDistortionOn f
  -- Low-end restoration (re-collation: absolute-low measure showed Metal -18.7 dB
  -- low-vs-mid = far too thin). The old base 4 + tight>>4 put the HPF corner near
  -- ~650 Hz, gutting the 150-650 Hz body; a real MT-2 only rolls off below
  -- ~150 Hz. Lower to 1 + tight>>6 (~120 Hz corner) so the low-mid chunk returns.
  alpha = 1 + (distTight (fOd f) `shiftR` 6)
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
  gain = pedalDriveGain 768 13 drive   -- refactor C: shared kernel

-- 4x oversampled hard clip (realism item 2 / R5) for Metal MT-2, the worst
-- aliaser. A static 48 kHz hard clip generates harmonics far above Nyquist
-- that fold back as inharmonic "digital fizz"; running the clip at 4x and
-- steeply decimating pushes those products out before the fold (offline:
-- ~-12 dB inharmonic energy vs 1x; 2x only reaches ~-6 dB because >48 kHz
-- harmonics still fold).
--
-- Structure (DSP only in the decimation FIR): linear-interp upsample 4x (the
-- input is already band-limited, so linear interp's images are negligible --
-- offline-confirmed equal to a full anti-image FIR -- and the 0/1/4/1/2/3/4
-- weights are shifts/adds, no multiply) -> hard clip the 4 sub-samples ->
-- 15-tap symmetric anti-alias decimation FIR over the 192 kHz clipped stream
-- (Q9, sum=512 = unity DC, -7.5 dB @ 24 kHz / -48 dB @ 48 kHz; folds to 8
-- multiplies). The clipped sub-sample history lives in a Vec 12 pipeline
-- register. The FIR is split products/mix (a FIR is feedforward, pipelines
-- freely; the D87 lesson) to keep the 50 MHz island path short. Bit-exact
-- bypass when the pedal is off.
metalClipThreshold :: Frame -> Sample
metalClipThreshold f = resize (if rawT < 600_000 then 600_000 else rawT) :: Sample
 where
  driveS = resize (asSigned9 (ctrlC (fDist f))) :: Signed 25
  -- Lower threshold = harder/denser clip. "完全飽和" pass (2026-06-17): floor
  -- 1.05M -> 600k + steeper slope (2.3M->1.7M, *7000->*8500) so the os4x hard
  -- clip flattens almost the whole waveform = MAXIMUM saturation density at all
  -- playing levels (a real MT-2 is a high-gain monster). This is the os4x
  -- (4x-oversampled) clip, so the extra harmonics are ANTI-ALIASED (no base-rate
  -- fizz); the post-LPF below shapes them.
  rawT = 1_700_000 - driveS * 8_500 :: Signed 25

-- ---- Shared 4x oversampled-hard-clip helpers (realism item 2 / R5) --------
-- Reused by every oversampled clip (Metal D88, RAT D89, ...). The clip itself
-- and its threshold are pedal-specific; these helpers are the generic
-- upsample / decimation machinery.

-- ---- Metal 4x oversampled clip (D88) --------------------------------------

metalClipProductsFrame :: Sample -> Vec 12 Sample -> Frame -> Frame
metalClipProductsFrame x1 hist f =
  f { fAccL = if on then s0 else 0, fAccR = 0
    , fAcc2L = if on then s1 else 0, fAcc2R = 0
    , fAcc3L = if on then s2 else 0, fAcc3R = 0 }
 where
  on = metalDistortionOn f
  (q0, q1, q2, q3) = os4xSubSamples (metalClipThreshold f) x1 (satShift7 (fAccL f))
  (s0, s1, s2) = os4xDecimProducts q0 q1 q2 q3 hist

metalClipMixFrame :: Frame -> Frame
metalClipMixFrame f =
  setMonoSample (if on then satShift9 (fAccL f + fAcc2L f + fAcc3L f) else monoSample f) f
 where
  on = metalDistortionOn f

metalClipHistNext :: Vec 12 Sample -> Sample -> Maybe Frame -> Vec 12 Sample
metalClipHistNext hist _ Nothing = hist
metalClipHistNext hist x1 (Just f) = os4xHistShift q0 q1 q2 q3 hist
 where
  (q0, q1, q2, q3) = os4xSubSamples (metalClipThreshold f) x1 (satShift7 (fAccL f))

metalPostLpfFrame :: Sample -> Frame -> Frame
metalPostLpfFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = metalDistortionOn f
  tone = ctrlA (fDist f)
  -- Post-LPF: dark MT-2 voicing, but base 8 (~1 kHz) filtered out the saturation
  -- EDGE too (dist_eval: THD plateaued at 17% despite crest 2.3 = hard-clipped).
  -- "完全飽和" pass (2026-06-17): with the clip floor dropped to 600k the dense
  -- clip generates far more harmonics; open the post-LPF base 15 -> 22 (~2.7 kHz
  -- corner) so the 3rd/5th harmonic actually reach the output = AUDIBLY more
  -- saturated/aggressive (the THD ceiling rises off the old ~19% post-LPF cap).
  -- Still rolls off the >4-5 kHz ice-pick, and the 4x oversampling keeps
  -- alias-fizz down, so it is "fully saturated MT-2", brighter than the previous
  -- dark voicing (an intentional trade for more 歪; lower the TONE knob to darken).
  alpha = 38 + (tone `shiftR` 2)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

metalLevelFrame :: Frame -> Frame
metalLevelFrame f =
  setMonoSample (if on then softClip afterLevel else monoSample f) f
 where
  on = metalDistortionOn f
  level = ctrlB (fDist f)
  afterLevel = distLevelRaw (monoSample f) level   -- refactor C: shared kernel

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
  -- Lighter input low cut: the real DS-1 keeps a ~100 Hz low-mid bump. The D129
  -- base-1 still cut the 100 Hz region (HPF corner ~240 Hz, low-vs-mid -6.6 dB);
  -- tight>>6 drops the corner to ~120 Hz so the bottom is retained.
  alpha = 1 + (distTight (fOd f) `shiftR` 6)
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
  gain = pedalDriveGain 256 9 drive    -- refactor C: shared kernel

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
  -- 96 kHz: bilinear-refit (was 104 + tone>>1) to hold the same LPF corner Hz.
  alpha = 59 + (tone `shiftR` 1)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

ds1LevelFrame :: Frame -> Frame
ds1LevelFrame f =
  setMonoSample (if on then softClipK safetyKnee afterLevel else monoSample f) f
 where
  on = ds1On f
  level = ctrlB (fDist f)
  afterLevel = distLevelRaw (monoSample f) level   -- refactor C: shared kernel
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
  gain = pedalDriveGain 448 11 drive   -- refactor C: shared kernel

-- Big Muff 4x oversampled clip cascade (realism item 2 / R5, D90). The two
-- cascaded soft clips (clip1 -> *208 -> clip2) generate fizz that aliases at
-- 48 kHz; run the whole cascade at 4x and decimate. Same os4x machinery as
-- Metal/RAT, but the per-sub-sample nonlinearity is the soft-clip *cascade*
-- (bigMuffOsCascade), not a single hard clip. Knees are the same as the old
-- two-stage clip1/clip2 (2.4M then 1.85M, with the *208 inter-stage gain), so
-- the voicing is preserved; only aliasing is reduced. Bit-exact bypass off.
bigMuffOsCascade :: Sample -> Sample
bigMuffOsCascade x =
  -- Sustain/saturation pass (dist_eval found sustain 1.00x = NO sustain; a real
  -- Big Muff is THE sustainer). Lower both clip knees so a decaying note stays
  -- clipped to the ceiling far longer (= the note "holds") AND the saturation is
  -- denser. Inter-stage *208 (~0.8x) kept. (knees were 2_400_000 / 1_850_000.)
  softClipK 1_250_000 (satShift8 (mulU8 (softClipK 1_500_000 x) 208))

bigMuffOsSubSamples :: Sample -> Sample -> (Sample, Sample, Sample, Sample)
bigMuffOsSubSamples x1 xn =
  (bigMuffOsCascade p0, bigMuffOsCascade p1, bigMuffOsCascade p2, bigMuffOsCascade p3)
 where
  (p0, p1, p2, p3) = os4xInterp x1 xn

-- The deep soft-clip cascade (clip1 -> *208 -> clip2) lives ONLY in the
-- history-update path below (which ends at the Vec register -- no FIR after
-- it), and the products stage reads all 15 FIR taps from the 16-deep history
-- (no cascade in the products path). This keeps the cascade multiply and the
-- FIR multiply in SEPARATE register-to-register paths -- a single combined
-- stage measured WNS -6.244 ns (two muls + two clips in series). The FIR
-- output lags the cascade by one frame group (harmless latency).
bigMuffClipProductsFrame :: Vec 16 Sample -> Frame -> Frame
bigMuffClipProductsFrame hist f =
  f { fAccL = if on then s0 else 0, fAccR = 0
    , fAcc2L = if on then s1 else 0, fAcc2R = 0
    , fAcc3L = if on then s2 else 0, fAcc3R = 0 }
 where
  on = bigMuffOn f
  -- 15-tap symmetric decimation FIR over history[0..14] (newest-first);
  -- pairs (0,14)..(6,8), center 7. Coeffs [-2,-3,-4,5,29,68,104,118].
  -- refactor E: shared FixedPoint.foldTap (was a local `pm a b g = (a+b)*g`)
  s0 = foldTap (hist !! 0) (hist !! 14) (-2) + foldTap (hist !! 1) (hist !! 13) (-3) + foldTap (hist !! 2) (hist !! 12) (-4)
  s1 = foldTap (hist !! 3) (hist !! 11) 5 + foldTap (hist !! 4) (hist !! 10) 29 + foldTap (hist !! 5) (hist !! 9) 68
  s2 = foldTap (hist !! 6) (hist !! 8) 104 + (resize (hist !! 7) * 118 :: Wide)

bigMuffClipMixFrame :: Frame -> Frame
bigMuffClipMixFrame f =
  setMonoSample (if on then satShift9 (fAccL f + fAcc2L f + fAcc3L f) else monoSample f) f
 where
  on = bigMuffOn f

bigMuffClipHistNext :: Vec 16 Sample -> Sample -> Maybe Frame -> Vec 16 Sample
bigMuffClipHistNext hist _ Nothing = hist
bigMuffClipHistNext hist x1 (Just f) = os4xHistShift q0 q1 q2 q3 hist
 where
  (q0, q1, q2, q3) = bigMuffOsSubSamples x1 (satShift8 (fAccL f))

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
-- D126: the scoop biquad is now ALSO shared with DS-1, with a coeff mux.
-- The real BOSS DS-1 has a SHALLOW ~3 dB mid scoop (500 Hz-2 kHz) that our DS-1
-- lacked (measured as a rising tilt, no dip). DS-1 runs upstream of this stage,
-- so (like metal, D121) its output reaches here as monoSample -- adding ds1 to
-- the gate applies a scoop with NO new biquad. But DS-1's scoop is much
-- shallower / higher than the Big Muff's deep -10 dB @ 700 Hz, so when ds1 is
-- the active pedal we select a -3 dB @ 1000 Hz Q0.7 coeff set instead. When
-- bigMuff/metal is active the ORIGINAL coeffs are used (byte-identical, so the
-- D90/D121 voicing is preserved). Bypass-exact when all three are off.
-- Re-collation vs the SPECIFIC real pedals (EQ curve, not just clipping):
--   * Metal (Boss MT-2): the real Metal Zone BOOSTS its mids (narrow peak ~800 Hz)
--     and rolls off hard above 1 kHz -- it does NOT scoop. Sharing the Big Muff
--     -10 dB scoop made our Metal sound nothing like an MT-2 (bright + scooped).
--     Metal now gets a +5 dB @ 800 Hz Q0.9 BOOST here (and a darker post-LPF).
--   * DS-1: the real scoop is ~500 Hz (Big-Muff-style tone network), deeper than
--     our old -6 dB @ 1000 Hz; moved to -8 dB @ 500 Hz Q0.7.
--   * Big Muff: unchanged (-10 dB @ 700 Hz).
-- Priority metal -> ds1 -> bigMuff (single pedal active at a time).
bigMuffScoopFfCoeff :: Frame -> (Signed 16, Signed 16, Signed 16)
bigMuffScoopFfCoeff f
  | metalDistortionOn f = (16656, -32025, 15413)   -- Metal MT-2 : +5 dB @ 800 Hz BOOST (was scoop)
  | ds1On f             = (16032, -31581, 15566)   -- DS-1 : -8 dB @ 500 Hz Q0.7 (was -6 @ 1000)
  | otherwise           = (15625, -30482, 14923)   -- Big Muff : -10 dB @ 1000 Hz (re-collation:
                                                   -- the real Big Muff tone-middle notch is ~1 kHz,
                                                   -- not 700 Hz -- moves the scoop up to match)

bigMuffScoopFbCoeff :: Frame -> (Signed 16, Signed 16)
bigMuffScoopFbCoeff f
  | metalDistortionOn f = (32025, 15685)           -- Metal MT-2 boost (na1, a2)
  | ds1On f             = (31581, 15214)           -- DS-1 -8 @ 500 Hz (na1, a2)
  | otherwise           = (30482, 14163)           -- Big Muff -10 @ 1000 Hz (na1, a2)

bigMuffScoopFeedforwardFrame :: Sample -> Sample -> Frame -> Frame
bigMuffScoopFeedforwardFrame x1 x2 f =
  setMonoAcc3 (if on then ff else 0) f
 where
  on = bigMuffOn f || metalDistortionOn f || ds1On f
  x = monoSample f
  (b0, b1, b2) = bigMuffScoopFfCoeff f
  ff = mulS16 x b0 + mulS16 x1 b1 + mulS16 x2 b2 :: Wide

bigMuffScoopRecursiveFrame :: Sample -> Sample -> Frame -> Frame
bigMuffScoopRecursiveFrame y1 y2 f =
  setMonoSample (if on then y else monoSample f) f
 where
  on = bigMuffOn f || metalDistortionOn f || ds1On f   -- shared scoop (see FF note)
  (na1, a2) = bigMuffScoopFbCoeff f
  -- fAcc3L holds the FF sum; -a1 = +na1.
  y = satShift14 (fAcc3L f + mulS16 y1 na1 - mulS16 y2 a2)

bigMuffToneFrame :: Sample -> Frame -> Frame
bigMuffToneFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = bigMuffOn f
  tone = ctrlA (fDist f)
  -- Darker tone curve keeps top-end fizz off the output.
  -- 96 kHz: bilinear-refit (was 48 + tone>>1) to hold the same LPF corner Hz.
  alpha = 25 + (tone `shiftR` 2)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

bigMuffLevelFrame :: Frame -> Frame
bigMuffLevelFrame f =
  setMonoSample (if on then softClipK safetyKnee afterLevel else monoSample f) f
 where
  on = bigMuffOn f
  level = ctrlB (fDist f)
  afterLevel = distLevelRaw (monoSample f) level   -- refactor C: shared kernel
  -- Output safety knee leaves sustain but avoids level-stage collapse.
  safetyKnee = 3_100_000 :: Sample

-- ---- fuzz_face (Fuzz Face style; 6 stages: pre-gain, asym clip,
--                mid-hump biquad, tone, level+safety) ------------------
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
  gain = pedalDriveGain 448 8 drive    -- refactor C: shared kernel

-- Fuzz Face dynamic bias envelope (realism item 5b / R2). A peak-follower on
-- the post-pre-gain ("boosted") level, same shape as the Compressor /
-- NoiseSuppressor envelopes (instant attack, linear release, reset to 0 when
-- the pedal is off so OFF stays bit-exact). The clip stage uses it to drift
-- the knees with the playing level -- the level-dependent behaviour a static
-- waveshaper lacks. No multiply (abs + shift + compare only), so no new DSP.
-- 96 kHz: halved (was 4096) so the bias envelope release TIME is unchanged.
ffBiasReleaseStep :: Sample
ffBiasReleaseStep = 2048

fuzzFaceBiasEnvNext :: Sample -> Maybe Frame -> Sample
fuzzFaceBiasEnvNext = peakFollower fuzzFaceOn level (\_ _ -> ffBiasReleaseStep)
 where
  level f = abs24 (satShift8 (fAccL f))

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
  -- Sustain/saturation pass (dist_eval: sustain only 1.12x, THD max 34%): lower
  -- knees so a real-Fuzz-Face note holds + saturates more (cleanup via the bias
  -- envelope is preserved -- biasShift still opens the knees at low playing level).
  kneeP = 1_250_000 - biasShift :: Sample
  kneeN = 700_000 + (biasShift `shiftR` 1) :: Sample

-- Broad Fuzz-Face transistor / pickup-loading voice peak. The previous
-- Fuzz Face curve was intentionally warm but almost flat, so it passed the
-- old low-vs-mid target while still missing the "vocal" mid focus players
-- expect from a real two-transistor fuzz into a guitar pickup. This post-clip
-- peaking biquad adds a broad +3 dB hump around 900 Hz before the round tone
-- LPF. It is a designed RBJ target curve at 96 kHz, not a copied schematic or
-- VST coefficient table. Pipeline-split like the Big Muff / amp biquads so the
-- feedback path closes with only two multiplies.
fuzzFaceMidFeedforwardFrame :: Sample -> Sample -> Frame -> Frame
fuzzFaceMidFeedforwardFrame x1 x2 f =
  setMonoAcc3 (if on then ff else 0) f
 where
  on = fuzzFaceOn f
  x = monoSample f
  ff =
    mulS16 x 16632
      + mulS16 x1 (-31511)
      + mulS16 x2 14933 :: Wide

fuzzFaceMidRecursiveFrame :: Sample -> Sample -> Frame -> Frame
fuzzFaceMidRecursiveFrame y1 y2 f =
  setMonoSample (if on then y else monoSample f) f
 where
  on = fuzzFaceOn f
  -- a1 = -31511, a2 = 15181; fAcc3L holds the feedforward sum.
  y = satShift14 (fAcc3L f + mulS16 y1 31511 - mulS16 y2 15181)

fuzzFaceToneFrame :: Sample -> Frame -> Frame
fuzzFaceToneFrame prevLp f =
  (if on then setMonoSample lp else setMonoSample x) (setMonoEqHighLp lp f)
 where
  on = fuzzFaceOn f
  tone = ctrlA (fDist f)
  -- "Round vs. bright", still rolling off the very top. The new mid-hump stage
  -- boosts the 900 Hz fundamental region, so the post tone LPF is opened a bit
  -- to keep the transistor fuzz edge / THD visible without adding >5 kHz fizz.
  alpha = 46 + (tone `shiftR` 1)
  x = monoSample f
  lp = onePoleU8 alpha prevLp x

fuzzFaceLevelFrame :: Frame -> Frame
fuzzFaceLevelFrame f =
  setMonoSample (if on then softClipK safetyKnee afterLevel else monoSample f) f
 where
  on = fuzzFaceOn f
  level = ctrlB (fDist f)
  afterLevel = distLevelRaw (monoSample f) level   -- refactor C: shared kernel
  -- Output safety knee avoids gated collapse at high LEVEL.
  safetyKnee = 3_000_000 :: Sample
