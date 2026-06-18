{-# LANGUAGE NumericUnderscores #-}

module AudioLab.Effects.Amp.Tone where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types
import AudioLab.Effects.Amp.Models

-- Per-amp-family resonant tone-stack biquad (realism item 3 / R3, D83).
-- The existing 3-band difference EQ (ampToneFilterFrame / ampToneBandFrame
-- below) can tilt the bands but cannot make a resonant scoop/peak, so amp
-- families that are defined by a resonant stack (Fender blackface mid scoop,
-- Vox AC30 chime, Marshall mid) all sound similar. This ONE shared peaking
-- biquad, with coefficients muxed by ampModelIdxF, adds that resonant shape.
-- Filled families (all hand-designed target curves, NOT schematic tables,
-- D7/D45): Fender blackface mid scoop (JC-120 idx 0 + Twin idx 1, -5 dB @
-- 400 Hz, D83), Vox AC30 chime (idx 2, +4 dB @ 2200 Hz, D84), Marshall JCM800
-- mid (idx 4, +4 dB @ 650 Hz, D84). Rockerverb (idx 3) and TriAmp (idx 5) stay
-- FLAT (b0 = 2^14, rest 0 -> exact unity passthrough, byte-identical). All
-- families share this ONE biquad via the coefficient mux -- do NOT instantiate
-- a second biquad (D58 lesson). Pipeline-split like D82 (feedforward
-- precomputed a stage earlier, recursive stage closes the loop with two
-- multiplies) so the single-cycle feedback path stays short on the
-- timing-tight island.
-- 96 kHz RBJ coeffs (48 kHz values noted per line).
ampScoopFeedforwardCoeffs :: Unsigned 3 -> (Signed 16, Signed 16, Signed 16)
ampScoopFeedforwardCoeffs idx = case idx of
  0 -> (16384, 0, 0)            -- JC-120 : FLAT (re-collation: a real Roland Jazz Chorus is a full-range SS amp with NO scoop; D122's residual -2 dB @ 400 Hz still mildly scooped it. Unity = flat. Still distinct from Twin's -5 dB scoop.)
  1 -> (16210, -31960, 15761)   -- Twin   : blackface mid scoop -5 dB @ 400 Hz
  2 -> (17221, -30270, 13395)   -- AC30   : stronger Vox chime +5 dB @ 2300 Hz
  3 -> (16453, -32427, 15980)   -- Rockerverb : thick low-mid +3 dB @ 300 Hz (voicing: was flat)
  4 -> (16583, -32152, 15598)   -- JCM800 : stronger Marshall mid +4.5 dB @ 650 Hz
  5 -> (16064, -31446, 15421)   -- TriAmp : modern scoop -6 dB @ 750 Hz (voicing: was flat; deeper to survive power-amp compression)
  _ -> (16384, 0, 0)            -- reserved 6/7 : flat (unity, b0 = 2^14)

ampScoopFeedbackCoeffs :: Unsigned 3 -> (Signed 16, Signed 16)
ampScoopFeedbackCoeffs idx = case idx of
  0 -> (0, 0)                   -- JC-120 FLAT (no feedback -> unity passthrough, SS full-range)
  1 -> (-31960, 15587)          -- Twin (48k: -31169/14828)
  2 -> (-30270, 14232)          -- AC30 stronger chime
  3 -> (-32427, 16049)          -- Rockerverb low-mid
  4 -> (-32152, 15797)          -- JCM800 stronger Marshall mid
  5 -> (-31446, 15100)          -- TriAmp scoop (-6 dB @ 750)
  _ -> (0, 0)                   -- reserved 6/7 : flat (no feedback)

ampToneScoopFeedforwardFrame :: Sample -> Sample -> Frame -> Frame
ampToneScoopFeedforwardFrame x1 x2 f =
  setMonoAcc (if on then ff else 0) f
 where
  on = flag6 (fGate f)
  (b0, b1, b2) = ampScoopFeedforwardCoeffs (ampModelIdxF f)
  x = monoWet f
  ff = mulS16 x b0 + mulS16 x1 b1 + mulS16 x2 b2 :: Wide

ampToneScoopRecursiveFrame :: Sample -> Sample -> Frame -> Frame
ampToneScoopRecursiveFrame y1 y2 f =
  setMonoWet (if on then y else monoWet f) f
 where
  on = flag6 (fGate f)
  (a1, a2) = ampScoopFeedbackCoeffs (ampModelIdxF f)
  -- fAccL already holds the feedforward sum; y = satShift14(FF - a1*y1 - a2*y2).
  y = satShift14 (fAccL f - mulS16 y1 a1 - mulS16 y2 a2)

ampToneFilterFrame :: Sample -> Sample -> Frame -> Frame
ampToneFilterFrame prevLow prevHighLp f =
  f
    { fEqLowL = low
    , fEqLowR = low
    , fEqHighLpL = highLp
    , fEqHighLpR = highLp
    }
 where
  x = monoWet f
  -- 96 kHz: shift 6 / 3 keeps the tone-stack crossover corners.
  low = onePoleShift 6 prevLow x
  highLp = onePoleShift 3 prevHighLp x

ampToneBandFrame :: Frame -> Frame
ampToneBandFrame f =
  f
    { fEqMidL = mid
    , fEqMidR = mid
    , fEqHighL = high
    , fEqHighR = high
    }
 where
  mid = satWide (resize (monoEqHighLp f) - resize (monoEqLow f))
  high = satWide (resize (monoWet f) - resize (monoEqHighLp f))

ampToneGain :: Unsigned 8 -> Unsigned 8
ampToneGain x = 64 + (x `shiftR` 1)

ampMidGain :: Unsigned 8 -> Unsigned 8
ampMidGain x = 51 + (x - (x `shiftR` 2))

ampTrebleGain :: Unsigned 3 -> Unsigned 8 -> Unsigned 8
ampTrebleGain idx x = base - modelTrim
 where
  -- Keep the 2..4 kHz bite from the tone stack, but avoid restoring as
  -- much raw 8..16 kHz fizz when TREBLE is near 100.
  -- HF-restore (2026-06-16/17, "音がこもる/高域不足"): the amp input HP was a DEAD
  -- first-difference that added ~+6 dB/oct of HF; fixing it to a live one-pole
  -- (the bass fix) removed that, leaving the high band (a differentiator) summed
  -- at gain ~84 < 128 = ATTENUATED = muffled. Raise the floor so the high band
  -- sits above unity (brighter neutral). Floor 64 -> 145 fixed the muffle but a
  -- HIGH floor COMPRESSES the TREBLE/PRESENCE knob range (knobcheck cycle 2:
  -- TREBLE +0.9, PRESENCE -0.0 = barely audible). So back to floor 110 (still
  -- above unity = not muffled) and move the rest of the brightness to the
  -- baseAlpha broadband brighten (96 -> 102), which is BEFORE the tone stack so
  -- it does NOT compress the knob range. The `- x>>3 - x>>4` shaping + the cab
  -- >5 kHz rolloff keep 8-16 kHz fizz down.
  base = 110 + ((x - (x `shiftR` 3) - (x `shiftR` 4)) `shiftR` 1)
  modelTrim = case idx of
    0 ->  0 :: Unsigned 8   -- JC-120  : full bright
    1 ->  2                 -- Twin    : glassy, not piercing
    2 ->  1                 -- AC30    : chime + top sparkle (was 2; less 2-4k trim)
    3 ->  9                 -- Rockerv : rounded
    4 ->  8                 -- JCM800  : bark, slight trim (reverted to 8 -- presence is the D128 knob)
    5 -> 14                 -- TriAmp  : controlled high
    _ ->  0

ampToneProductsFrame :: Frame -> Frame
ampToneProductsFrame f =
  f
    { fAccL = if on then mulU8 (monoEqLow f) (ampToneGain (ctrlA (fAmpTone f))) else 0
    , fAccR = 0
    , fAcc2L = if on then mulU8 (monoEqMid f) (ampMidGain (ctrlB (fAmpTone f))) else 0
    , fAcc2R = 0
    , fAcc3L = if on then mulU8 (monoEqHigh f) (ampTrebleGain idx (ctrlC (fAmpTone f))) else 0
    , fAcc3R = 0
    }
 where
  on = flag6 (fGate f)
  idx = ampModelIdxF f

ampToneMixFrame :: Frame -> Frame
ampToneMixFrame f =
  setMonoWet (if on then satShift7 acc else monoSample f) f
 where
  on = flag6 (fGate f)
  acc = fAccL f + fAcc2L f + fAcc3L f

ampPowerFrame :: Frame -> Frame
ampPowerFrame f =
  setMonoWet (if on then softClipK (ampPowerKnee 3_400_000 (ampModelIdxF f)) (monoWet f) else monoSample f) f
 where
  on = flag6 (fGate f)

ampResPresenceFilterFrame :: Sample -> Sample -> Frame -> Frame
ampResPresenceFilterFrame prevRes prevPresence f =
  f
    { fEqLowL = res
    , fEqLowR = res
    , fEqHighLpL = presenceLp
    , fEqHighLpR = presenceLp
    }
 where
  x = monoWet f
  -- Lowpass for the resonance band (speaker low-end resonance ~80-120 Hz).
  -- Was shift 9 (~30 Hz corner) -- BELOW the guitar low-E (82 Hz), so the band
  -- held almost no signal and the RESONANCE knob was DEAD (knobcheck +0.0 even
  -- after raising the mix gain). shift 7 (~120 Hz corner) puts the band ON the
  -- speaker-resonance region so RESONANCE actually moves the low-end thump.
  -- 96 kHz: presence stays shift 4.
  res = onePoleShift 7 prevRes x
  presenceLp = onePoleShift 4 prevPresence x

ampResPresenceMixFrame :: Frame -> Frame
ampResPresenceMixFrame f =
  setMonoWet (if on then softClipK (ampPowerKnee 3_400_000 (ampModelIdxF f)) wet else monoSample f) f
 where
  on = flag6 (fGate f)
  -- D132 knob-visibility pass: after the D121-D131 HF/bass re-voicing,
  -- knobcheck again showed PRESENCE/RESONANCE below the 1 dB audibility floor
  -- at the JCM800 drive op-point. Keep the existing products and safety clip,
  -- but sum both shelves one bit hotter. This is a shift-only change: no new
  -- stage, multiplier, GPIO, or topology.
  wet = satWide (fAccL f + satShift7Wide (fAcc2L f) + satShift7Wide (fAcc3L f))

ampResPresenceProductsFrame :: Frame -> Frame
ampResPresenceProductsFrame f =
  f
    { fEqHighL = high
    , fEqHighR = high
    , fAccL = if on then resize (monoWet f) else 0
    , fAccR = 0
    , fAcc2L = if on then mulU8 (monoEqLow f) resonance else 0
    , fAcc2R = 0
    , fAcc3L = if on then mulU8 high presence else 0
    , fAcc3R = 0
    }
 where
  on = flag6 (fGate f)
  resonance = ctrlD (fAmp f) - (ctrlD (fAmp f) `shiftR` 2)
  presence = basePresence - presenceTrim + presenceBoost
  presenceByte = ctrlC (fAmp f)
  idx = ampModelIdxF f
  basePresence = presenceByte - (presenceByte `shiftR` 2) - (presenceByte `shiftR` 3)
  -- Per-model presence trim. Larger right-shift = smaller subtraction =
  -- brighter presence. JC-120 keeps the full presence; TriAmp Mk3
  -- shaves the most.
  presenceTrim = case idx of
    0 -> 0 :: Unsigned 8         -- JC-120  : full
    1 -> presenceByte `shiftR` 5 -- Twin    : glassy but controlled
    2 -> presenceByte `shiftR` 6 -- AC30    : jangly presence
    3 -> presenceByte `shiftR` 3 -- Rockerv : darker and thicker
    4 -> presenceByte `shiftR` 5 -- JCM800  : 2..3 kHz presence sheen (was >>4;
                                 -- less trim = brighter presence, the real
                                 -- JCM800 presence control our model under-did)
    5 -> presenceByte `shiftR` 3 -- TriAmp  : maximum trim, modern voicing
    _ -> 0
  -- Extra model-local negative-feedback presence. The shared tone-stack biquad
  -- supplies the AC30/JCM800 mid feature, but the real amps also have a sharper
  -- 2-4 kHz bite that was still understated once the cab rolloff was engaged.
  -- Shift-only boost keeps this inside the existing presence product stage.
  presenceBoost = case idx of
    2 -> presenceByte `shiftR` 4 -- AC30: extra chime edge
    4 -> presenceByte `shiftR` 4 -- JCM800: Marshall bite
    _ -> 0
  high = satWide (resize (monoWet f) - resize (monoEqHighLp f))

satShift8Wide :: Wide -> Wide
satShift8Wide = resize . satShift8

satShift7Wide :: Wide -> Wide
satShift7Wide = resize . satShift7

satShift9Wide :: Wide -> Wide
satShift9Wide = resize . satShift9

satShift10Wide :: Wide -> Wide
satShift10Wide = resize . satShift10

-- Power-amp sag envelope (realism item 5b / R2, part 2). A slow peak-follower
-- of the master-input level (same shape as the Compressor / NoiseSuppressor /
-- Fuzz-bias envelopes: instant attack, slow linear release for the
-- "recovers-after-the-transient" sag character, reset to 0 when the amp is
-- off so bypass stays bit-exact). No multiply (abs + compare + subtract).
-- 96 kHz: halved (was 1024) so the sag recovery TIME is unchanged at 2x fs.
ampSagReleaseStep :: Sample
ampSagReleaseStep = 512

ampSagEnvNext :: Sample -> Maybe Frame -> Sample
ampSagEnvNext = peakFollower (flag6 . fGate) level (\_ _ -> ampSagReleaseStep)
 where
  level f = abs24 (monoWet f)

ampMasterFrame :: Sample -> Frame -> Frame
ampMasterFrame env f =
  setMonoSample (if on then out else monoSample f) f
 where
  on = flag6 (fGate f)
  level = ctrlB (fAmp f)
  idx = ampModelIdxF f
  -- Power-amp sag: loud passages pull the master level down a touch, then it
  -- recovers as the envelope releases. Bounded to at most half the level (no
  -- choke) and DISABLED for JC-120 (idx 0, solid-state = stiff supply, no
  -- sag). Reuses the existing master multiply -> no new DSP. sagRaw takes bits
  -- 22..17 of the (non-negative) envelope = a 0..63 magnitude.
  sagRaw0 = resize (unpack (slice d22 d17 (pack env)) :: Unsigned 6) :: Unsigned 8
  -- Per-model sag depth. AC30 (idx 2) is class-A with cathode-bias sag and
  -- early compression, so its supply sags ~1.5x deeper than the other tube
  -- amps (shift+add, no DSP). Every other model keeps sagRaw0 byte-for-byte.
  sagRaw = case idx of
    2 -> sagRaw0 + (sagRaw0 `shiftR` 1)   -- AC30: deeper class-A sag
    _ -> sagRaw0
  sagCap = level `shiftR` 1
  sagByte = if idx == 0 then 0 else min sagRaw sagCap
  effLevel = level - sagByte
  out = softClipK (ampPowerKnee 3_300_000 idx) (satShift7 (mulU8 (monoWet f) effLevel))

-- ---- Output-transformer emulation (D94, DIGITAL_SOUND_REDUCTION.md #9) --
-- A real tube amp's output transformer is a big part of "amp warmth" that the
-- current clip -> tone -> cab chain misses entirely: the iron core SATURATES on
-- low-frequency energy (bass notes / power chords push the core and
-- compress/round, adding low-order harmonics), while the highs pass roughly
-- linearly. The audible tell is "the low end blooms and compresses on loud
-- chords". This sits after the power-amp master, before the cab (transformer =
-- the power-amp's iron; cab = the speaker -- both are distinct, both were
-- missing).
--
-- Minimal model (shift-only, NO new DSP): split the low band with a one-pole
-- lowpass (`prev + (x-prev)>>shift`, ~120 Hz corner at 48 kHz), soft-clip ONLY
-- the low band (softClipK = compare+shift, no multiply), and recombine with the
-- untouched high band. So loud lows bloom/compress while treble stays linear.
-- Gated on amp-on (bit-exact bypass when off) AND skipped for JC-120 (idx 0,
-- solid-state = NO output transformer, same exclusion as the D86 sag). The
-- lowpass state is stashed in the reuse-safe fEqLowL (the cab's first stage
-- re-initialises fEqLowL = 0, so the stash never leaks). The HF bandwidth droop
-- of a real transformer is left to the cab rolloff + the D93 emphasis for now;
-- this phase is just the LF core saturation (the defining character).
ampTransformerLfShift :: Int
ampTransformerLfShift = 7      -- 96 kHz: +1 (was 6) keeps the ~120 Hz LF split corner

ampTransformerKnee :: Sample
ampTransformerKnee = 5_200_000 -- LF core-saturation knee (loud lows bloom/compress)

ampTransformerFrame :: Sample -> Frame -> Frame
ampTransformerFrame prevLp f =
  setMonoSample (if on then out else monoSample f) (setMonoEqLow lp f)
 where
  on = flag6 (fGate f) && ampModelIdxF f /= 0
  x = monoSample f
  lp = onePoleShift ampTransformerLfShift prevLp x
  high = satWide (resize x - resize lp :: Wide)
  lowSat = softClipK ampTransformerKnee lp
  out = satWide (resize lowSat + resize high :: Wide)

-- Transformer HF bandwidth droop (D96, #9 continuation). A real output
-- transformer cannot pass the top octave -- its limited bandwidth rounds the
-- treble, a characteristic "iron" softness. A gentle one-pole high-cut on the
-- transformer output: take the HF band `h = x - lp` (lp = one-pole lowpass,
-- ~3.8 kHz corner) and subtract a fraction (`h >> ampTransformerHfDroop`) so the
-- top is shelved down a touch. Shift-only -> NO new DSP. Same amp-on + skip-
-- JC-120 gate as the LF stage; its own one-pole state stashed in the reuse-safe
-- fEqLowL (overwritten by the cab's first stage). Runs right after the LF
-- saturation stage so the two transformer behaviours (LF bloom + HF droop) are
-- complete. ampTransformerHfShift / ampTransformerHfDroop are bench-tunable.
ampTransformerHfShift :: Int
ampTransformerHfShift = 2      -- 96 kHz: +1 (was 1) keeps the ~3.8 kHz HF corner

ampTransformerHfDroop :: Int
ampTransformerHfDroop = 6      -- subtract 1/2^n of the HF band. Was 3 (~-1.2 dB);
                               -- raised to 6 (~-0.3 dB) as part of the 2026-06-16
                               -- HF-restore -- the droop was tuned for the bright
                               -- dead-HP input, now over-darkens the top.

ampTransformerHfFrame :: Sample -> Frame -> Frame
ampTransformerHfFrame prevLp f =
  setMonoSample (if on then out else monoSample f) (setMonoEqLow lp f)
 where
  on = flag6 (fGate f) && ampModelIdxF f /= 0
  x = monoSample f
  lp = onePoleShift ampTransformerHfShift prevLp x
  h = satWide (resize x - resize lp :: Wide)            -- HF band
  out = satWide (resize x - (resize h `shiftR` ampTransformerHfDroop) :: Wide)

-- Transformer low-end resonance bump (D97, #9 final sub-item). A real output
-- transformer's primary inductance + reflected load make a gentle low-frequency
-- resonance (a slight bass bump ~110 Hz) on top of the LF saturation. A fixed
-- peaking biquad, single-stage (the island has +3.2 ns margin so a 5-mul biquad
-- does not need the D82/D83 split). Hand-designed Q14 target f0 = 110 Hz,
-- Q = 0.8, +2.0 dB (verified DC ~+2.6 dB skirt / +2.0 dB @ 110 / unity at 500 Hz+
-- / pole 0.984 stable). Conservative (a "bump", not a boost) to avoid sub-bass
-- mud on a guitar. Same amp-on + skip-JC-120 gate; x1/x2/y1/y2 are pipeline
-- state. Sits on the transformer output, after the HF droop, before the cab.
-- Coeffs bench-tunable (raise f0 / lower gain if it muds).
ampXfmrResFrame :: Sample -> Sample -> Sample -> Sample -> Frame -> Frame
ampXfmrResFrame x1 x2 y1 y2 f =
  setMonoSample (if on then y else x) f
 where
  on = flag6 (fGate f) && ampModelIdxF f /= 0
  x = monoSample f
  -- 96 kHz RBJ coeffs (110 Hz, Q 0.8, +2 dB); was 16418/-32504/16090/32504/16123 @48k.
  acc =
    mulS16 x 16401
      + mulS16 x1 (-32636)
      + mulS16 x2 16236
      + mulS16 y1 32636
      - mulS16 y2 16253 :: Wide
  y = satShift14 acc

-- Multiband (3-band) mid-focused saturation (D97, digital-sound #12). The D93
-- pre/de-emphasis is a single-band crude version; real circuits clip the bands
-- differently. Split into low / mid / high with two one-pole lowpasses, saturate
-- ONLY the mid band (where the musical amp "grind/body" lives) with a moderate
-- knee, and pass low + high through (lows are handled by the transformer LF
-- saturation; highs stay clean to avoid fizz). Shift-only (one-poles + softClipK)
-- -> NO new DSP. Gated amp-on + skip-JC-120. Two one-pole states stashed in the
-- reuse-safe fEqLowL (low/mid split) and fEqHighLpL (mid/high split) -- both are
-- free between the amp master and the cab (the cab re-inits fEqLowL and never
-- touches fEqHighLpL; the EQ stage overwrites fEqHighLpL downstream). Sits right
-- after the amp master, before the transformer. ampMidSatKnee is bench-tunable
-- (lower = more mid grind).
amp3BandLowShift :: Int
amp3BandLowShift = 6      -- 96 kHz: +1 (was 5) keeps the ~240 Hz low/mid split

amp3BandHighShift :: Int
amp3BandHighShift = 3     -- 96 kHz: +1 (was 2) keeps the ~1.9 kHz mid/high split

ampMidSatKnee :: Sample
ampMidSatKnee = 4_000_000 -- mid-band grind knee (lower = more mid saturation)

ampMultibandSatFrame :: Sample -> Sample -> Frame -> Frame
ampMultibandSatFrame prevLp1 prevLp2 f =
  setMonoSample (if on then out else monoSample f)
    (setMonoEqHighLp lp2 (setMonoEqLow lp1 f))
 where
  on = flag6 (fGate f) && ampModelIdxF f /= 0
  x = monoSample f
  lp1 = onePoleShift amp3BandLowShift prevLp1 x
  lp2 = onePoleShift amp3BandHighShift prevLp2 x
  low = lp1
  mid = satWide (resize lp2 - resize lp1 :: Wide)
  high = satWide (resize x - resize lp2 :: Wide)
  midSat = softClipK ampMidSatKnee mid
  out = satWide (resize low + resize midSat + resize high :: Wide)
