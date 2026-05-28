{-# LANGUAGE NumericUnderscores #-}
{-# LANGUAGE ScopedTypeVariables #-}

module AudioLab.Effects.Wah where

import Clash.Prelude

import AudioLab.Control
import AudioLab.FixedPoint
import AudioLab.Types

-- ---- Wah (POSITION / Q / VOLUME / BIAS) ------------------------------
--
-- Resonant band-pass wah on its own GPIO. Sits between the Compressor
-- output and the Overdrive input -- the classic "pre-distortion" wah
-- position. Driven by the dedicated wah_control GPIO carried in fWah:
--
--   fWah ctrlA = wahPositionByte   (pedal sweep position, 0..255; FP02M
--                                   feed will land here later)
--   fWah ctrlB = wahQByte          (resonance / sharpness, 0..255;
--                                   higher = narrower / more vocal)
--   fWah ctrlC = wahVolumeByte     (ON-gain compensation, 0..255;
--                                   byte 128 ~= unity, byte 255 ~= +6 dB)
--   fWah ctrlD bit 7      = wahEnable
--   fWah ctrlD bits[6:0]  = wahBiasByte (0..127, 64 = centred)
--
-- Value-preserving bypass with added pipeline latency when wahEnable is
-- clear: the wahApplyFrame branch returns the input frame unchanged
-- sample-for-sample, but the surrounding register-stage chain
-- (wahPosSmooth, wahFByteR, wahQBandR, wahLow, wahBand, wahApplyPipe)
-- still costs a few extra pipeline cycles vs the pre-D72 baseline.
-- Latency-aligned diff checks against the D71.2 build will show the
-- same sample values offset by that latency; sample-by-sample diff
-- against the same wall-clock buffer will NOT be bit-identical.
-- State registers (posSmooth, fByteR, qBandR, low, band) are
-- pipeline-level so idle Nothing cycles preserve the SVF state and
-- the smoothed pedal position; Just-frame cycles with wahOn=False
-- zero the SVF state (low / band / qBandR / fByteR) so OFF -> ON has
-- no stale energy.
--
-- Topology: Chamberlin parallel-update state-variable filter where
--
--   high(n) = in - low(n-1) - qBandR(n-1)              (no multiply)
--   band(n) = band(n-1) + fByteR(n-1) * high(n)
--   low(n)  = low(n-1)  + fByteR(n-1) * band(n-1)
--   wahOut  = band(n)                                  (BPF output)
--   final   = applyVolume(wahOut, volume_byte)
--
-- Pipeline budget: each state register update is one DSP + small
-- adders so Vivado can place the multipliers independently. The
-- positionToFByte and the q*band products are pre-registered into
-- `wahFByteR` and `wahQBandR` so the band/low updates never see two
-- multiplies in series (which is what regressed WNS by ~9.5 ns when
-- the chain was fused into a single combinational block in the first
-- D72 build).

-- ---- Field accessors -------------------------------------------------

wahPositionByte :: Ctrl -> Unsigned 8
wahPositionByte = ctrlA

wahQByte :: Ctrl -> Unsigned 8
wahQByte = ctrlB

wahVolumeByte :: Ctrl -> Unsigned 8
wahVolumeByte = ctrlC

wahEnableBiasByte :: Ctrl -> Unsigned 8
wahEnableBiasByte = ctrlD

wahEnabled :: Ctrl -> Bool
wahEnabled c = testBit (wahEnableBiasByte c) 7

wahBiasByte :: Ctrl -> Unsigned 8
wahBiasByte c = wahEnableBiasByte c .&. 0x7F

wahOn :: Frame -> Bool
wahOn f = wahEnabled (fWah f)

-- ---- Coefficient mapping (D73 Cry Baby GCB-95 retune) -----------------
--
-- Position-to-f mapping target (fs = 48 kHz), centred on the GCB-95
-- mechanical sweep range so the effect lands closer to the classic
-- Cry Baby vocal voicing than the wider initial D72 mapping:
--
--   pos 0   -> ~450 Hz   (f_coef ~0.0589 -> f_byte ~15)
--   pos 64  -> ~700 Hz   (f_coef ~0.0916 -> f_byte ~24)
--   pos 128 -> ~1100 Hz  (f_coef ~0.1437 -> f_byte ~37)
--   pos 192 -> ~1600 Hz  (f_coef ~0.2088 -> f_byte ~53)
--   pos 255 -> ~2200 Hz  (f_coef ~0.2865 -> f_byte ~73)
--
-- f_byte is a u8 where 256 == f_coef 1.0; the SVF update shifts
-- right by 8 so mulU8 x f_byte / 256 gives f_coef * x. Four-segment
-- piecewise linear fit between the anchor points. All multiplications
-- use a wider Unsigned 16 intermediate so the arithmetic does not wrap.
--
-- D72 baseline anchors were 12/20/33/53/80 (~350/600/1000/1600/2400 Hz)
-- -- wider range, less Cry Baby-like. D73 narrows heel a bit (450 Hz
-- vs 350), keeps the mid the same (1600 Hz at pos 192), and lowers
-- toe (2200 vs 2400) so the upper end stays in the vocal "wah / yeah"
-- formant region rather than tipping into ice-picky 2.4 kHz territory.
basePositionToFByte :: Unsigned 8 -> Unsigned 8
basePositionToFByte pos = resize wide
 where
  pos16 :: Unsigned 16
  pos16 = resize pos
  wide  :: Unsigned 16
  wide
    | pos < 64  = 15 + ((pos16              * 9)  `shiftR` 6)
    | pos < 128 = 24 + (((pos16 - 64)       * 13) `shiftR` 6)
    | pos < 192 = 37 + (((pos16 - 128)      * 16) `shiftR` 6)
    | otherwise = 53 + (((pos16 - 192)      * 20) `shiftR` 6)

-- Bias modulates the position->freq mapping. Centre at byte 64 (the
-- ctrlD bits[6:0] mid-point), so bias bytes 0/64/127 produce roughly
-- 0.0x/1.0x/+2.0x scaling of the base f_byte. Range is clamped to
-- [4, 200] so neither end of the sweep can collapse to DC or push
-- past Nyquist.
positionToFByte :: Unsigned 8 -> Unsigned 8 -> Unsigned 8
positionToFByte pos biasByte = clamp adjusted
 where
  base       :: Unsigned 8
  base       = basePositionToFByte pos
  baseSigned :: Signed 18
  baseSigned = resize (asSigned9 base)
  biasSigned :: Signed 18
  biasSigned = (resize (asSigned9 biasByte) :: Signed 18) - 64
  offset     :: Signed 18
  offset     = (baseSigned * biasSigned) `shiftR` 6
  adjusted   :: Signed 18
  adjusted   = baseSigned + offset
  clamp x
    | x < 4     = 4
    | x > 200   = 200
    | otherwise = fromIntegral x

-- Q UI byte -> SVF damping byte (q_coef encoded as u8, 256 == 1.0).
-- Spec: higher wahQByte = narrower / sharper peak = LESS damping = LOWER
-- q_coef. We invert and floor to 16 so the BPF cannot run away.
--   qByte 0   -> q_coef ~0.500 (wide / mild)
--   qByte 128 -> q_coef ~0.250 (medium)
--   qByte 255 -> q_coef ~0.063 (sharp / vocal; floor)
qCoefByte :: Unsigned 8 -> Unsigned 8
qCoefByte qByte
  | raw < 16  = 16
  | otherwise = raw
 where
  raw = 128 - (qByte `shiftR` 1)

-- Volume byte -> Q8 makeup factor (Unsigned 10) in [128, ~510]. D73
-- spec re-aligns the curve so that UI 50 % (byte 128) is unity and
-- UI 100 % (byte 255) is +6 dB (2.0x). Two-segment piecewise linear:
--   byte 0   -> factor 128  (~0.5x, -6 dB taper)
--   byte 128 -> factor 256  (1.0x  unity)
--   byte 255 -> factor 510  (~2.0x, +6 dB boost cap)
-- The output saturating multiply uses satShift8 (mulU10 sample factor)
-- so out-of-range materials clip rather than wrap; the cap of ~2.0x
-- means a unity-peak input cannot overflow Signed 24 by more than 1
-- bit, which the satWide() inside satShift8 covers.
--
-- D72 used a single segment with factor in [64, ~256] which made
-- byte 128 land at ~0.625x (~-4 dB) -- the GUI VOLUME=50 was NOT
-- unity, contradicting the spec. D73 fixes that and also widens the
-- top end up to +6 dB so Cry Baby 95Q "Volume Boost" style ON-gain
-- compensation is reachable.
wahVolumeFactor :: Unsigned 8 -> Unsigned 10
wahVolumeFactor volByte
  | volByte <= 128 = 128 + (resize volByte :: Unsigned 10)
  | otherwise      = let d = volByte - 128
                     in 256 + ((resize d :: Unsigned 10) `shiftL` 1)

-- ---- Position smoothing ----------------------------------------------
--
-- Zipper-noise filter. Target = wahPositionByte(fWah). Smoothed value
-- moves toward the target by 1/16 of the gap per audio frame. With a
-- single-byte step this is ~0.3 ms convergence per encoder tick, and
-- a 64-byte jump settles in ~20 ms -- audibly smooth for hand sweeps
-- without adding noticeable latency. Off-cycle (wah disabled) snaps
-- to target so a re-enable starts from the visible pedal position.
wahPosSmoothNext :: Unsigned 8 -> Maybe Frame -> Unsigned 8
wahPosSmoothNext prev Nothing = prev
wahPosSmoothNext prev (Just f)
  | not (wahOn f) = target
  | otherwise     = stepped
 where
  target      = wahPositionByte (fWah f)
  prevSigned  = resize (asSigned9 prev)   :: Signed 11
  tgtSigned   = resize (asSigned9 target) :: Signed 11
  delta       = tgtSigned - prevSigned
  stepDelta   = delta `shiftR` 4
  candidate   = prevSigned + stepDelta
  -- If delta is non-zero but the shift collapses it to 0, nudge by 1
  -- so the smoother actually reaches the target instead of stalling.
  nudged
    | stepDelta == 0 && delta > 0 = candidate + 1
    | stepDelta == 0 && delta < 0 = candidate - 1
    | otherwise                   = candidate
  clamped
    | nudged < 0   = 0
    | nudged > 255 = 255
    | otherwise    = nudged
  stepped     = fromIntegral clamped :: Unsigned 8

-- ---- Pre-registered coefficient / product stages ---------------------
--
-- Each of these consumes one DSP at most. They feed the band / low
-- updates with already-registered values so the band/low combinational
-- chains never see two multiplies in series. Just-frame cycles with
-- wahOn=False zero the registers so OFF -> ON does not surface stale
-- coefficients or SVF energy at re-enable time.

-- Frequency byte register: positionToFByte(posSmooth, biasByte).
-- Off cycles preserve the value (idle Nothing); Just-frame with
-- wahOn=False snaps to 0 so re-enable starts clean.
wahFByteRNext :: Unsigned 8 -> Unsigned 8 -> Maybe Frame -> Unsigned 8
wahFByteRNext prev _ Nothing = prev
wahFByteRNext _ posSmooth (Just f)
  | not (wahOn f) = 0
  | otherwise     = positionToFByte posSmooth (wahBiasByte (fWah f))

-- Q*band product register: satShift8(mulU8 oldBand qCoefByte). One DSP
-- + saturating shift; the result is later subtracted from the input in
-- the band update with no extra multiply in that stage.
wahQBandRNext :: Sample -> Sample -> Maybe Frame -> Sample
wahQBandRNext prev _ Nothing = prev
wahQBandRNext _ oldBand (Just f)
  | not (wahOn f) = 0
  | otherwise     = satShift8 (mulU8 oldBand qByte)
 where
  qByte = qCoefByte (wahQByte (fWah f))

-- ---- SVF state update ------------------------------------------------
--
-- Parallel Chamberlin SVF. Both state regs read the OLD low/band, so
-- they can register at the same clock edge without depending on each
-- other's new value. fByte and qBand are pre-registered (1-cycle lag)
-- so the combinational chain in each state update is at most one
-- multiply.
--
-- D73 explicitly zeros the SVF state (low / band) when a Just frame
-- arrives with wahOn=False. Combined with wahFByteRNext / wahQBandRNext
-- doing the same, this guarantees that an OFF -> ON transition starts
-- from rest -- no decayed-but-non-zero filter ring surfacing as a pop
-- on re-enable.

-- band(n) = satWide (band(n-1) + f * high(n))
--   high(n) = input(n) - low(n-1) - qBandR(n-1)        (no multiply)
--   f * high uses the registered fByteR (1-cycle lag)
wahBandNext :: Sample -> Sample -> Sample -> Unsigned 8 -> Maybe Frame -> Sample
wahBandNext oldBand _ _ _ Nothing = oldBand
wahBandNext oldBand oldLow qBandR fByteR (Just f)
  | not (wahOn f) = 0
  | otherwise     = result
 where
  inputW   :: Wide
  inputW   = resize (monoSample f)
  lowW     :: Wide
  lowW     = resize oldLow
  qBandW   :: Wide
  qBandW   = resize qBandR
  high     :: Sample
  high     = satWide (inputW - lowW - qBandW)
  fHigh    = mulU8 high fByteR
  inc      = satShift8 fHigh
  bandW    :: Wide
  bandW    = resize oldBand
  incW     :: Wide
  incW     = resize inc
  result   = satWide (bandW + incW)

-- low(n) = satWide (low(n-1) + f * band(n-1))   (parallel update)
--   uses registered fByteR; no other multiply.
wahLowNext :: Sample -> Sample -> Unsigned 8 -> Maybe Frame -> Sample
wahLowNext oldLow _ _ Nothing = oldLow
wahLowNext oldLow oldBand fByteR (Just f)
  | not (wahOn f) = 0
  | otherwise     = result
 where
  fBand    = mulU8 oldBand fByteR
  inc      = satShift8 fBand
  lowW     :: Wide
  lowW     = resize oldLow
  incW     :: Wide
  incW     = resize inc
  result   = satWide (lowW + incW)

-- ---- Apply stage -----------------------------------------------------
--
-- One register stage of multiply + saturating shift, same arithmetic
-- shape as compMakeupFrame but with a wider Unsigned 10 factor so the
-- D73 +6 dB volume boost fits without wrap. Value-preserving bypass
-- (output sample == input sample) when the wah is disabled. Uses the
-- REGISTERED `wahBand` state (the value written one clock earlier),
-- which costs a single-sample group delay that is inaudible for a
-- guitar wah.
wahApplyFrame :: Sample -> Frame -> Frame
wahApplyFrame band f
  | not (wahOn f) = f
  | otherwise     = setMonoSample wahed f
 where
  factor :: Unsigned 10
  factor = wahVolumeFactor (wahVolumeByte (fWah f))
  wahed  = satShift8 (mulU10 band factor)
