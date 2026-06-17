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
| `run_sim.py` | Orchestrator. Builds the 12 control words with the project's own `audio_lab_pynq/control_maps.py` (imported by file path -- no `pynq` needed), generates/reads a WAV, runs the sim, writes output WAVs + objective metrics (peak/rms/crest/level-stability/centroid/clip). |
| `measure.py` | **Frequency-shaping** measurement: an effect's net tone curve vs bypass (mid hump / scoop / low-cut / HF rolloff / notch). `--batch` sweeps every model in **parallel** (`--jobs`); `--absolute` keeps the true level (the bass-light / LOWvMID check, 40 Hz floor); `--check` auto-compares every model to its real-hardware target (`targets.py`, PASS/FAIL). Includes **`rig_*` chain configs (amp -> cab)** -- the amp's true voicing AS HEARD (amp-alone is misleadingly bright: its tone-stack high band is a +6 dB/oct differentiator with no speaker rolloff), and an **`HFslp` column** = treble slope dB/oct 2-9 kHz (real amp+cab ROLLS OFF = negative; a rising/+ slope = bare differentiator = "digital/buzzy"). The "is the voicing on target vs the real pedal/rig" check. |
| `dist_eval.py` | **Distortion CHARACTER** (what THD misses): DRIVE/gain (THD% + crest vs input level = saturation depth + cleanup), SUSTAIN (decay hold-time ratio = a Big Muff/Fuzz sustainer), GRIT/IMD (two-tone intermod + >5 kHz fizz). `--batch` over the dist pedals; **`--check`** auto-compares each pedal's clip TYPE (crest), THD floor, sustain, and Fuzz cleanup to its real-pedal target (PASS/FAIL), AND each amp's **CLEAN-mode THD at a 0.12 FS playing level** (per-model ceiling -- the "clean mode distorts" detector). |
| `dynamics_eval.py` | **Dynamics / time-domain / chain safety** target checks for areas not covered by static tone curves: Compressor input/ratio gain-reduction, Noise Suppressor close-vs-attack, Wah POSITION peak sweep, Reverb DECAY/TONE/MIX monotonicity, and representative multi-effect chain clipping/loudness. `--check` returns non-zero on failure. |
| `targets.py` | Machine-readable real-hardware voicing TARGETS: per model `mid` peak/scoop freq (`"any"` skips a cab-confounded rig mid) + `low_vs_mid` bass balance + `hf` treble-slope -- `hf=("range",lo,hi)` on the amp-ALONE models is the **MUFFLED(<lo) / HARSH(>hi) detector** (an amp head should have presence before the cab). Covers OD/DIST + amp-alone 0..5 + rig 0..5 + cab open/brit/closed. Plus `CLIP_TARGETS` (clip type / THD floor / sustain / cleanup) + `AMP_CLEAN` ceilings used by `dist_eval.py --check`. From the ElectroSmash analyses + the D121-D131 re-collations. |
| `harmonics.py` | **Harmonic / transfer** measurement on a single sine: fundamental, h2..h8, THD, odd/even ratio, alias/IMD energy. The OD/Distortion drive-character check. |
| `reverb.py` | **Time-domain decay** measurement: RT60 (Schroeder T20), tail tone (centroid), wet level, comb echo period; `--decay-sweep` / `--tone-sweep` prove a knob is real + monotonic. The reverb axis `measure.py`/`harmonics.py` (both steady-state) could not see. |
| `knobcheck.py` | **Per-band audio-change-per-knob** check across EVERY effect/knob: for each knob it renders two settings and reports how much the sound moves, broken down by frequency band (80/200/500/1k/3k/8k Hz) + overall, flagging "barely audible" knobs. The board-comparison artifact: "turn this knob, these bands should move by this much." |
| `metrics.py` | Shared numeric helpers (`rms_dbfs`, band balance, HF slope, centroid, peak / clip count) used by the measurement tools so target checks do not carry hand-copied math. |
| `signals.py` | Canonical, level-recorded test inputs (sine / log-sweep / two-tone / impulse / decaying-sine) so every retune A/Bs against the SAME stimulus. |
| `build_sim.sh` | One-line `-O1` build (see below). |
| `golden_vectors.json` + `tests/test_dsp_sim_regression.py` | Tier-2 regression: bypass bit-exact invariant + per-config sha256 goldens (opt-in `DSP_SIM_TESTS=1`). |

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

# frequency shaping (tone curve) of every model, in parallel:
python3 tools/dsp_sim/measure.py --batch                 # --jobs N to cap workers
python3 tools/dsp_sim/measure.py --check                 # PASS/FAIL vs real-hw targets
python3 tools/dsp_sim/measure.py --config ds1 --drive 65 # one effect, full curve
python3 tools/dsp_sim/measure.py --config rig_4          # JCM800 INTO cab (the real rig)

# harmonic / drive character on a 1 kHz sine:
python3 tools/dsp_sim/harmonics.py --config od_4 --drive 65

# distortion CHARACTER (clip type / THD / sustain), PASS/FAIL vs real pedals:
python3 tools/dsp_sim/dist_eval.py --batch
python3 tools/dsp_sim/dist_eval.py --check

# dynamics / time-domain / representative chain safety:
python3 tools/dsp_sim/dynamics_eval.py --check
python3 tools/dsp_sim/dynamics_eval.py --check --sections compressor,wah
python3 tools/dsp_sim/dynamics_eval.py --batch --sections chain

# reverb decay (time-domain) -- the knob-is-real check:
python3 tools/dsp_sim/reverb.py --decay-sweep            # RT60 vs DECAY (monotone?)
python3 tools/dsp_sim/reverb.py --tone-sweep             # tail brightness vs TONE
python3 tools/dsp_sim/reverb.py --decay 80 --tone 40 --mix 90

# how much does each knob move the sound, per frequency band:
python3 tools/dsp_sim/knobcheck.py --all                 # every effect/knob
python3 tools/dsp_sim/knobcheck.py --effect amp          # one effect
python3 tools/dsp_sim/knobcheck.py --effect eq --from 0 --to 100
```

`run_sim.py` outputs `input.wav`, `out_<tag>.wav` (16-bit) + a metrics line each;
the measurement tools print objective tables.

## Comparing against the real hardware

There is **no per-sample DMA capture** off the board (the Pmod ADC path is not on
AXIS -- `pmod_i2s2_capture_probe.py` only reads aggregate counters), so a
sample-exact sim-vs-board diff is not possible. What IS reproducible on the board
is **behaviour**: how much the sound moves when you turn a knob, and in which
band. `knobcheck.py` is built for exactly that comparison -- run it, then sweep
the same knob on the GUI/encoder and check the same bands move by a comparable
amount (a knob the sim moves 6 dB but is dead on the board, or vice-versa, is the
discrepancy to chase). Its inputs are fixed and level-recorded (from
`signals.py`) so the board can be driven the same way. The bypass bit-exact
invariant remains the one true end-to-end anchor.

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
which is NOT what the FPGA does. `gap>=8` is enough for every recursion to
settle: gap 8 is **bit-identical** to gap 16/32/106 (verified amp/rat/reverb,
`max|diff|=0`) -- a larger gap only burns time. **The default is therefore `8`**
(was 32, which produced the same bytes ~2.6x slower); `gap>=106` (the pipeline
depth) is the unconditional 1-sample-in-flight bound if a future stage ever
needs more settling.

### Bypass is bit-exact (offline knife-edge regression)

With all effects off the output equals the input **sample-exact** (verified).
This is the safe-bypass / "knife-edge" invariant (the class that caused the
D102-D108 pain) -- now checkable offline, no build. `--demo` prints
`[bypass bit-exact == input: True]`.

## Metrics

`peak/rms dBFS`, `crest_dB` (dynamics; amp compression lowers it),
`level_stability_std_dB` (short-term-RMS spread; **pumping** -- the user's
"volume が変"), `centroid_Hz` (brightness; muffled = low), `clip_count`.
`dynamics_eval.py --check` turns several of those raw measurements into hard
gates for previously under-measured behaviour: Compressor ratio/input response,
NS tail closure, Wah sweep span, Reverb monotonic controls, and full-chain
clipping/loudness.

## Limitations (read before trusting a result)

- Simulates the **DSP island logic only**. It is exact for **voicing / tone /
  dynamics** (the constant-tuning that dominated D92-D120). It does **not**
  cover the codec / Pmod analog path, the clock-domain crossings, timing, or
  the bitstream P&R. **Bit-integrity (timing MET, CDC, on-hardware bypass) still
  needs a Vivado build + the bench.** Use this to pick a voicing fast, then
  build/bench the winner.
- Performance (`-O1`): ~7500 island-cycles/s = **~830 audio-samples/s at the
  default `gap=8`** (~320/s at the old `gap=32`). So ~0.1 s of audio per second
  of wall-clock; a 0.5 s clip is ~60 s, a 1.5 s reverb tail ~3 min. Levers:
  keep `gap=8` (default), render the **shortest** clip that exercises the effect
  (e.g. `reverb.py --seconds 0.8`, plenty for an RT60), and run independent
  configs in **parallel** (`measure.py --batch --jobs N`, `reverb.py` sweeps --
  each config is its own subprocess, so N cores ≈ N×). **`-O2` is NOT worth it:**
  it makes the *runtime* only modestly faster but the *compile* pathologically
  slow (>10 min on `Pipeline`/`LowPassFir`), which defeats the rebuild-in-seconds
  point -- stay on `-O1` (`build_sim.sh`).

## Suggested next steps

- **FPGA cross-check** (the one fidelity gap left): capture the same input +
  config off the board (Pmod mode 2) and diff against the sim render, to confirm
  end-to-end fidelity beyond the bit-exact bypass already shown.
- Keep adding PASS/FAIL targets to `dynamics_eval.py` when a bench complaint is
  not reducible to EQ or distortion character. The intended gate stack before a
  voicing build is now `measure.py --check`, `dist_eval.py --check`,
  `dynamics_eval.py --check`, and the golden regression.
- Extend `measure.py --batch` / the goldens as new effect models land (re-bless
  after an INTENTIONAL voicing change with
  `python3 tests/test_dsp_sim_regression.py --regen`).
