# DSP offline simulation harness (Tier 1)

Runs the **exact Clash `topEntity` fixed-point pipeline** -- the same source
Vivado synthesises to the FPGA -- on the host CPU, so a voicing change can be
**A/B'd in seconds** instead of a 30-40 min Vivado build + ear bench. This is
the highest-leverage fix for the amp-voicing iteration loop (the D92-D120
churn): voice offline, listen + measure, and only spend a real bitstream build
on a candidate you already like.

## Files

| File | Role |
| --- | --- |
| `Sim.hs` | Haskell harness. Wires 12 constant control words + a gated sample stream through `LowPassFir.topEntity` and `sampleN`s the output. Bit-identical to the FPGA DSP. |
| `run_sim.py` | Orchestrator. Builds the 12 control words with the project's own `audio_lab_pynq/control_maps.py` (imported by file path -- no `pynq` needed), generates/reads a WAV, runs the sim, writes output WAVs + objective metrics. |

## Build (once, and after any DSP-source edit)

```sh
clash -O1 -ihw/ip/clash/src -itools/dsp_sim \
  -package-id clash-prelude-1.8.1-043657e64d575898396c414bafaea7f08fdd2ba6b4085ce0bd624cd91d00144c \
  tools/dsp_sim/Sim.hs -o tools/dsp_sim/dsp_sim -outputdir /tmp/dsp_sim_build
```

(`clash`, not `ghc` -- it enables the Clash default extensions, e.g.
`TemplateHaskell` for `createDomain`. No `--vhdl`, so it just builds an exe.)

## Run

```sh
# A/B bypass vs amp on a synth pluck, with metrics:
python3 tools/dsp_sim/run_sim.py --demo --seconds 0.5

# one config on your own clip:
python3 tools/dsp_sim/run_sim.py --preset amp --amp-model 4 --wav-in guitar.wav --out-dir /tmp/out
#   --amp-model 0..5 (JC-120/Twin/AC30/Rockerverb/JCM800/TriAmp), --drive-mode 0|1
#   --in-level (synth peak frac of FS, real guitar ~0.1-0.2), --gap, --fs
```

Outputs `input.wav`, `out_<tag>.wav` (16-bit) + a metrics line each.

## How it works

1. `control_maps.py` packs the high-level config into the 12 GPIO control
   words (gate / od / dist / eq / rat / amp / amp_tone / cab / reverb / ns /
   comp / wah) -- the *exact* encoding the board receives.
2. The mono guitar sample goes in the LEFT 24 bits of the 48-bit AXIS word
   (`AudioLab.Axis.makeInput` uses the LEFT channel); the processed output is
   read back from the LEFT 24 bits.
3. `sampleN` runs the pipeline; outputs are collected on the AXIS `oValid`
   cycles, one per input sample.

### ⚠️ The AXIS valid-gating gotcha (load-bearing)

On the FPGA the DSP island gets a **new valid sample only every ~347 island
cycles** (33 MHz island / 96 kHz audio) with `validIn` LOW in between, and the
recursive stages (biquads / wah SVF / envelopes) are `Maybe Frame`-gated and
**hold on idle cycles**. So the harness presents each sample as *one valid cycle
followed by `gap` idle cycles*. Feeding valid **back-to-back (`gap=0`)
mis-times the recursive feedback and the amp/biquads oscillate at Nyquist** --
which is NOT what the FPGA does. `gap>=8` is enough for the local recursions;
the default `32` is a safe margin; `gap>=106` (the pipeline depth) is
unconditionally safe but ~3x slower.

### Bypass is bit-exact (offline knife-edge regression)

With all effects off the output equals the input **sample-exact** (verified).
This is the safe-bypass / "knife-edge" invariant (the class that caused the
D102-D108 pain) -- now checkable offline, no build. `--demo` prints
`[bypass bit-exact == input: True]`.

## Metrics

`peak/rms dBFS`, `crest_dB` (dynamics; amp compression lowers it),
`level_stability_std_dB` (short-term-RMS spread; **pumping** -- the user's
"volume が変"), `centroid_Hz` (brightness; muffled = low), `clip_count`.

## Limitations (read before trusting a result)

- Simulates the **DSP island logic only**. It is exact for **voicing / tone /
  dynamics** (the constant-tuning that dominated D92-D120). It does **not**
  cover the codec / Pmod analog path, the clock-domain crossings, timing, or
  the bitstream P&R. **Bit-integrity (timing MET, CDC, on-hardware bypass) still
  needs a Vivado build + the bench.** Use this to pick a voicing fast, then
  build/bench the winner.
- Performance: ~3500 island-cycles/s (-O1). A 0.5 s clip at `gap=32` is a few
  minutes; use shorter clips, `--gap 8`, or `-O2` to speed up.

## Suggested next steps

- **Tier 2** builds directly on this: golden-vector + bypass-invariant
  regression tests (`gap>=8`) that run in CI without a build.
- Cross-check one render against the FPGA (same input + config) to confirm
  end-to-end fidelity beyond the bit-exact bypass already shown.
