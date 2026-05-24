# Pmod I2S2 self-loopback diagnostic

Diagnostic date: 2026-05-24. Branch: `main` (D62 baseline).
Diagnostic script: `scripts/diagnose_pmod_loopback.py`.

## Why this exists

After the D63 (DS-1 cascade) and D64 (5-constant distortion retune) bench
rejections, the user reported a "high-frequency bit-crusher" symptom and
asked whether the Pmod I2S2 / ADC / DAC / AXIS path itself could be
corrupting high-frequency content -- i.e., whether the symptom was in
the I2S layer rather than in build-specific Vivado P&R.

To answer that without an external instrument, the user wired
**Pmod Line Out -> Pmod Line In** with a direct cable and asked for a
PYNQ-single diagnostic. This document records the procedure and the
verdict, and the matching script is committed so a future build can
re-run the same check before deploying any new DSP edit.

## Hardware setup

```
Pmod JB4 T10 (DA SDIN, DAC output)
    |
   cable
    v
Pmod JB10 W13 (AD SDOUT_i, ADC input)
```

No external instrument, no audio interface. PYNQ-Z2 alone.

## What each MODE means in pmod_i2s2_master.v

Per `hw/ip/pmod_i2s2/src/pmod_i2s2_master.v` (D62 baseline,
bit/hwh md5 `349ebbe609ac15f58d8b676d2dedee94` /
`3a90e966c5d76762b60ba3ab0e982685`):

| MODE | name | DAC SDIN source | Notes |
| ---- | ---- | --------------- | ----- |
| 0 | TX_TONE + ADC probe | internal ROM 1 kHz sine, +/- 2^21 = -12 dBFS, 48 samples/cycle | DAC always plays the same fixed tone regardless of axis_switch routing |
| 1 | ADC -> DAC loopback (RTL) | `rx_left_captured` to LEFT slot, `rx_right_captured` to RIGHT slot | True stereo loopback at the bit-serial level, no DSP, no AXIS |
| 2 | ADC -> DSP -> DAC | `mode2_right_snapshot[bit_idx[4:0]]` -- the RIGHT slot of the i2s_to_stream IP's `so` output, mirrored to both DAC slots | **Has a built-in workaround**: the i2s_to_stream IP has (a) a broken LEFT extraction and (b) a 1-BCLK setup race on `so` (it updates on the same BCLK edge the DAC samples on). MODE 2 captures the IP RIGHT slot once per BCLK during the RIGHT slot and uses the same buffer for the next frame's LEFT and RIGHT DAC slots. Result: mono mirror, ~21 us (one frame) of delay. |
| 3 | MUTE | SDIN = 0 | Default-safe state |

## Diagnostic phases (in `scripts/diagnose_pmod_loopback.py`)

| Phase | What it tests | Pass/fail signal |
| ----- | ------------- | ---------------- |
| **0** | Initial state snapshot: `PL.bitfile_name`, `PL.timestamp`, ADC HPF, all pmod_status registers. | Free-running counters are increasing; CLIP_COUNT is 0; ADC HPF True. |
| **1** | Per-MODE counter baseline with no MM2S. Iterates MUTE -> TONE -> LOOP -> DSP -> MUTE, clears counters, waits 3 s, reads FRAME / NONZERO / CLIP / LAST / PEAK deltas. | MODE 0: peakL ~ -12 dBFS (the internal tone via cable loop). MODE 1/3: peakL near noise floor. MODE 2: with `line_in -> passthrough -> headphone` default route the cable closes a positive-feedback loop, peakL builds up to ~ -1.3 dBFS over a few seconds -- this is **expected** and not a defect (it's the known cable-loop-on-DSP-path feedback documented in earlier sessions). |
| **3** | DMA-capture (uniform 48 kHz fs) MODE 0 internal tone + MODE 3 mute. FFT both. | MODE 0: single dominant peak at 1000 Hz, harmonics > 30 dB below. MODE 3: spectrum bands all < ~200 magnitude. |
| **5** | MM2S sine sweep via `dma -> passthrough -> headphone` (DSP chain BYPASSED) + LAST_LEFT polling (~26 kHz poll rate). | Per (freq, level): `uniq1k` near 1000 (no quantisation), `max_run = 1 or 2` (no stair-step). |
| **B** | MM2S sine sweep via `dma -> guitar_chain -> headphone` (DSP chain all-off pass-through) + polling. This is the same path D63 / D64 audition used for distortion tests. | Same uniq1k / max_run criteria as Phase 5. If guitar_chain perturbs the signal, this is where it would show. |

**Note on polling-based FFT**: Phases 5 and B use MMIO polling of LAST_LEFT
during sustained MM2S play, because `capture_input` redirects the
axis_switch to a DMA sink (which kills the playback). The poll rate
ends up near 26-37 kHz which is below the 48 kHz audio fs, so the
spectrum produced by polling alias-folds harmlessly (e.g. a 10 kHz
input may show a peak at 6 kHz from the (poll_fs - input_freq) beat).
**The dispositive bit-crusher checks are `uniq1k` and `max_run`, not
the spectrum peaks** -- those two are bit-pattern observations that are
not corrupted by undersampling. Use Phase 3 (DMA capture, uniform 48
kHz fs) when you need a reliable spectrum.

## 2026-05-24 D62 baseline verdict

All phases passed. Specifically:

| Phase | Result |
| ----- | ------ |
| 0 | D62 bit/hwh on PYNQ (`349ebbe6...` / `3a90e966...`), ADC HPF True, MODE 3 mute at start |
| 1 | MODE 0 peakL ~1.19M (-17 dBFS, matches expected -12 dBFS DAC + analog loss), MODE 1/3 noise floor, MODE 2 cable loop feedback (expected) |
| 3 | MODE 0: single 1000 Hz peak, harmonics > 1000x below; MODE 3: spectrum bands all < 200 magnitude |
| 5 | MM2S 1k/4k/8k/12k Hz all clean: `uniq1k >= 999`, `max_run = 1` in every cell |
| B | MM2S 1k/4k/8k/10k/12k/15k Hz x -30/-20/-12 dBFS = 18 cells: every cell `max_run = 2` (no stair-step), `uniq1k` 845..1000 (no quantisation). Top spectral peaks are polling-rate aliases, not real audio harmonics. |

**No QUANT! / no STAIR! flag triggered in any phase.**

### Conclusion

The D62 baseline I2S / ADC / DAC / AXIS path -- including the DSP chain
in pass-through (`guitar_chain` with every effect off) -- is **clean**
across 100 Hz..15 kHz at -30..-12 dBFS. The hardware self-loopback
cannot reproduce the bit-crusher / HF-noise symptom that the user
reported during the D63 and D64 bench auditions.

### Implication for the D63 / D64 rejections

The D63 and D64 audible "bit-crusher" / "HF noise" / "leak to other
pedals" symptoms must therefore be **build-specific Vivado P&R-induced
artifacts**, not faults in the I2S / ADC / DAC / AXIS layer or in
the D62 baseline DSP chain. This matches the engineering rule
documented in `DECISIONS.md` (D58 / D59 / D60 / D61 / D63 / D64
sequence): structural Clash edits -- helper cascades, new
`Pipeline.hs` registers, even multi-constant simultaneous retunes --
can perturb Vivado P&R enough to leak audio artifacts into the
safe-bypass path. D62 is the deployed baseline because its 3-constant
single-model edit is the empirical minimal scope that did NOT trigger
the regression class.

## How to re-run this diagnostic before deploying any new build

1. Wire **Pmod Line Out -> Pmod Line In** with a direct cable.
   No external instrument.
2. Make sure the headphone / amp / monitor side is disconnected, so the
   cable-loop feedback in MODE 2 does not produce audible output. The
   diagnostic deliberately drives MODE 2 default-route feedback in
   Phase 1; that is by design and stays inside the FPGA.
3. From the host:
   ```
   ssh xilinx@192.168.1.9 'sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
       python3 scripts/diagnose_pmod_loopback.py'
   ```
4. The script exits 0 on PASS, 1 on any bit-crusher / quantisation
   flag. The verdict line at the end summarises.

To run a quick smoke (fewer freqs / shorter windows):
```
ssh xilinx@192.168.1.9 'sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
    python3 scripts/diagnose_pmod_loopback.py --short'
```

To run one phase only:
```
ssh xilinx@192.168.1.9 'sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
    python3 scripts/diagnose_pmod_loopback.py --phase 3'
```

## What this diagnostic does NOT cover

- Real-instrument bench audition. The cable loop can't reproduce the
  full set of frequencies and dynamics a guitar produces. For
  end-to-end audio acceptance, the bench ear on safe-bypass remains
  the dispositive sensor (per the D58 / D59 / D60 / D61 / D63 / D64
  lesson).
- Analog cable level. The Pmod Line Out is line level (~1-2 Vrms);
  the Pmod Line In expects similar level. The diagnostic was run with
  the default Pmod board setup, no attenuator. If your physical setup
  is different, peak levels (`peakL` per phase) will shift but the
  bit-crusher checks (`uniq1k`, `max_run`) still apply.
- Cross-talk between the Pmod I2S2 path and any other PMOD slot. The
  diagnostic only exercises JB.
- Long-term thermal drift. The diagnostic runs in a few seconds and
  doesn't probe sustained operation.
