# Reducing round-trip latency — sources and methods, ranked

This doc investigates the **input-to-output (round-trip) latency** of the live
Pmod I2S2 mode-2 audio path (guitar -> CS5343 ADC -> DSP -> CS4344 DAC -> amp)
and ranks the ways to reduce it. Companion to `AUDIO_SIGNAL_PATH.md` (the path),
`DSP_ISLAND_CLOCK_DESIGN.md` (the island clock), and `DIGITAL_SOUND_REDUCTION.md`
(the 96 kHz lever is shared with that work).

**Headline finding:** the latency is already low and is **dominated by the codec
ADC + DAC digital-filter group delay (fixed hardware), NOT the DSP.** The whole
Clash DSP pipeline adds only ~3 us (~0.15 samples). So most "make the DSP
shorter" ideas have negligible payoff; the one real lever is the **sample rate**.

## Latency budget (estimated at 48 kHz; 1 sample = 20.83 us)

| Stage | Estimate | Reducible? | Notes |
| --- | --- | --- | --- |
| **CS5343 ADC group delay** | ~0.2-0.5 ms (datasheet group delay, ~tens of samples) | only via fs or a different codec | The ADC decimation filter. Fixed by the part + sample rate. The dominant contributor with the DAC. |
| I2S framing in (i2s_to_stream) | ~1 sample (~21 us) | no (protocol) | One stereo frame to assemble a sample. |
| `axis_data_fifo_0` (FIFO_DEPTH=16) | a few samples steady-state (~tens of us) | hard (block_design.tcl) | Decouples the AXIS switch/DMA from the DSP; in continuous 1-sample flow it stays near-empty, so the contribution is small, not the full 16. |
| `cc_dsp_in` AXIS clock converter (100->33 MHz) | a few cycles | no (CDC needed) | Small FIFO in the clock-domain crossing. |
| **Clash DSP pipeline** | **~106 register stages ≈ 3.2 us @ 33 MHz ≈ 0.15 sample** | marginally | 106 `register Nothing` data stages. Streams 1 sample/cycle; a sample traverses in ~106 island cycles, far under one 48 kHz period. **Essentially not a latency factor.** |
| `cc_dsp_out` AXIS clock converter (33->100 MHz) | a few cycles | no | |
| D50 `mode2_right_snapshot` | ~1 frame (~21 us) | yes, but needs a bug fix | The mode-2 mono RIGHT-slot mirror deliberately delays one frame to dodge the i2s_to_stream LEFT-extraction bug + i2sOut race (CLAUDE.md D50). |
| I2S framing out + **CS4344 DAC group delay** | ~1 sample + ~0.2-0.5 ms | only via fs / codec | The DAC interpolation filter group delay -- the other dominant contributor. |
| **Estimated round-trip total** | **~0.7-1.5 ms** | — | Dominated by the two codec group delays (~0.4-1.0 ms combined). |

> The codec group-delay numbers are typical-datasheet estimates; **measure on the
> bench** (procedure below) before trusting them. The structural conclusion (DSP
> ~3 us, codecs dominate) holds regardless of the exact codec figure.

## Why the DSP is NOT the problem

The DSP island runs at 33 MHz but only accepts one valid sample per 48 kHz period
(the AXIS `acceptedIn = validIn && acceptReady` handshake; `paceCount` removed,
D75). Between samples the ~106-stage pipeline shifts ~690 times with idle
`Nothing` frames. A valid sample propagates through ~106 stages in ~106 island
cycles ≈ **3.2 us**, i.e. ~0.15 of a sample period. So even though the chain is
deep (NS, Comp, Wah, OD, 6 distortion pedals, Amp, Cab, EQ, Reverb), its latency
is a rounding error next to the codecs. **Pruning stages, merging stages, or
raising the island clock all save only microseconds and are not worth the risk**
(and we deliberately *lowered* the island to 33 MHz for timing -- raising it back
fights `DSP_ISLAND_CLOCK_DESIGN.md`).

## Ranked reduction methods

### 1. Sample rate 48 -> 96 kHz  [BIGGEST lever, HIGH cost — shared with the 96 kHz project]

> **STATUS (D98, 2026-06-05): DONE -- deployed + bench-audio ACCEPTED ("合格").**
> Branch `feature/96khz-conversion` (merged to main). Pmod BCLK MCLK/4 -> MCLK/2
> (codec double-speed, MCLK still 128fs); DSP island clock unchanged. Whole-chain
> re-voicing done (7 biquads recomputed, one-poles +1 shift / bilinear re-fit,
> envelope/LFO time-constants halved, delay lines doubled, cab FIR redesigned).
> The 4x oversampler decimation FIRs are ratio-based so they needed NO change.
> Island WNS +3.141 / fabric +0.587, DSP 135 (no new multipliers), BRAM 6.
> Codec locks at 96 kHz (correct pitch), re-voiced chain auditions clean. bit
> `18df313f` (rollback D97 `ad771d7c` / `/tmp/d97_backup`). See `DECISIONS.md`
> D98. **This was the only real round-trip latency lever, now realised: codec
> group delay (the dominant term) is ~halved.**


- **Why.** Codec group delay scales with the sample period: doubling fs roughly
  **halves the codec group delay in milliseconds** (the dominant term) AND halves
  every per-sample time (framing, FIFO, snapshot). This is the only change that
  meaningfully cuts the dominant contributor. It also reduces aliasing (the
  digital-sound silver bullet) -- same project.
- **Cost.** The Pmod-master divider change is small (MCLK stays 12.288 MHz =
  128fs double-speed; BCLK ÷4->÷2; LRCK 48k->96k; no block_design.tcl, no new
  MMCM). The catch is the **whole-chain re-voicing** (every fs-dependent constant
  -- one-pole corners, biquad coeffs, envelope/LFO/reverb rates, the 4x
  oversamplers) and verifying the codec locks in double-speed mode. See the
  feasibility write-up referenced in `DIGITAL_SOUND_REDUCTION.md` / the 96 kHz
  discussion. Not a quick win, but it is the one with real payoff.
- **Payoff.** ~0.4-0.5 ms off the round trip (half the codec delay), plus the
  aliasing benefit.

### 2. Confirm/minimise the live-path FIFO buffering  [LOW cost, SMALL payoff]

- `axis_data_fifo_0` is FIFO_DEPTH=16. In steady 1-sample-in/1-sample-out flow it
  should stay near-empty (so its real contribution is a few samples, not 16). But
  **measure the actual occupancy**; if the DMA/switch arbitration lets it back up,
  it could add up to ~333 us. Reducing the depth or its fill would need a
  `block_design.tcl` change (off-limits by default) -- so first *measure* whether
  it matters before proposing that.

### 3. Remove the D50 mode-2 one-frame snapshot delay  [LOW priority, ~21 us]

- The `mode2_right_snapshot` mono mirror costs ~1 frame (~21 us). Removing it
  requires fixing the underlying `i2s_to_stream` LEFT-extraction bug + the
  `i2sOut` setup race that the snapshot works around (CLAUDE.md D50) -- a real RTL
  fix for a ~1-sample gain. Only worth it if a true stereo / lowest-latency mode
  is being built anyway.

### 4. Codec low-latency filter mode  [likely NOT available]

- Some codecs expose a "fast roll-off / low-latency" digital-filter mode with
  shorter group delay. The CS5343/CS4344 are **hardware-mode** parts (no I2C, fixed
  filters) -- there is no register to select a low-latency filter. The on-board
  ADAU1761 *is* configurable but is **not** in the live audio path (kept for
  I2C/HPF health checks only). So this is not actionable without a codec/path
  change. (If a future build moved the live path to a configurable codec, this
  becomes a real option.)

### 5. Prune dead DSP pipeline stages  [NEGLIGIBLE — do not bother for latency]

- The legacy distortion pipeline and other always-instantiated stages add depth
  even when off, but the whole DSP is ~3 us; halving it saves ~1.5 us. Not worth
  the regression risk. (Pruning may still be worth it for *area/timing*, never for
  latency.)

## How to actually measure round-trip latency (do this first)

Static estimates are not enough (the D74/D78 "bench it" lesson applies). Measure:

1. **Loopback impulse, dual-capture.** Feed a single click / impulse into the
   guitar input; capture both the ADC-side and DAC-side simultaneously. The
   sample offset between the input impulse and its appearance at the output = the
   true round-trip latency. `scripts/pmod_i2s2_capture_probe.py` and the
   DMA capture path are the in-FPGA hooks; a 2-channel scope/audio-interface on
   the Pmod JB ADC-in vs DAC-out pins is the most reliable external method.
2. **Set the DSP to all_off** (clean passthrough) so you measure the path, not an
   effect's own group delay; then re-measure with the Amp/Cab on to see the
   added DSP filtering group delay (still small, but real for the resonant
   filters).
3. Repeat at 48 kHz and (if the 96 kHz build exists) 96 kHz to confirm the
   sample-rate payoff.

## Recommendation

The round-trip latency is **already in the ~1 ms range and is codec-bound**, so
there is no cheap DSP-side win. The honest options are:

- **If latency must drop:** do the **96 kHz** project (method 1) -- it is the only
  lever with real payoff, and it doubles as the best anti-aliasing move. Treat it
  as a deliberate, phased project (prove the codec locks at 96 kHz first, then
  re-tune the fs-dependent constants), not a tweak.
- **Otherwise:** first **measure** the real round trip (and the FIFO occupancy);
  if it is already ~1 ms and stable, leave the path alone -- the DSP is not the
  bottleneck and shaving microseconds is not worth the risk.
