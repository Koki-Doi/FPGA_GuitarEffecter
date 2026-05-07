# Audio recording analysis

Last updated: 2026-05-07 (audio-analysis-driven voicing fixes).

This note records the quantitative recording-analysis pass that drove the
2026-05-07 voicing fixes. It is not a complete listening verdict; it is a
measurement aid used to decide where the existing DSP stages should move.

## Recordings analysed

- Bypass
- NoiseSuppressor
- Compressor
- Overdrive
- DS-1
- AmpSim
- Cabinet
- Reverb

## Views inspected

- Short-time RMS trend
- Mean frequency spectrum
- Absolute high-frequency energy
- First 5 seconds noise floor
- Attack waveform
- Difference waveform vs Bypass
- Difference spectrum vs Bypass
- High-frequency energy change vs Bypass
- Spectrogram

## Findings

### AmpSim

AmpSim carried too much upper fizz / air above roughly 5 kHz. In the
recordings this made the stage lean toward a direct-line, scratchy top end,
especially when treble and presence were high. The risk was that Amp-only use
could become painful, and high-gain pedals feeding the amp could be squared and
brightened a second time.

Action: lower the Amp input-gain ceiling, darken the post-clip pre-LPF range,
cap the treble / presence contribution, and move the power / resonance /
master safety knees slightly earlier. Preserve the BMT / presence control
feel; do not add an amp model selector or a new GPIO.

### Cabinet

Cabinet already moved in the right direction: high end was lower than bypass
and lower than AmpSim. It was still not strong enough as a post-distortion
speaker simulator for DS-1 / RAT / Big Muff / Fuzz / Metal, and the three
model choices were closer together than their labels implied.

Action: keep the existing 4-tap cabinet FIR but rebalance the coefficient
table. Model 0 remains the lighter 1x12 open-back style, model 1 is the
balanced 2x12 combo style, and model 2 pushes the most energy into delayed
body taps so the highest fizz is damped hardest. Cap `air` so `air=100` does
not become a raw direct tap again.

### Overdrive

Overdrive measured very close to Bypass. RMS and spectrum changes were small,
which means the stage either did not reach the clip knee often enough at the
recorded input level or the drive curve was too conservative for the current
presets.

Action: raise the Overdrive drive mapping moderately, lower the asymmetric
clip knees, and add an output safety `softClipK` in the existing level stage.
This should make Drive 30..50 visibly different from Bypass while staying far
below DS-1 / RAT / Metal gain.

### Compressor

Compressor crest factor was close to Bypass in this recording set. That points
to the effective threshold being too high for the material and/or the ratio /
response combination not entering gain reduction soon enough.

Action: lower the effective threshold mapping, widen the soft-knee start,
increase reduction slope modestly, and make the response step slightly more
reactive. Keep the makeup range unchanged so the existing 45..60 preset safety
contract remains valid.

### DS-1 / Distortion Pedalboard

DS-1 was functioning as a distortion: RMS rose and peak/crest dropped. The
main risk was not that DS-1 itself was absent, but that weak Amp/Cab voicing
left its top end too raw.

Action: leave DS-1 and the wider distortion pedalboard mostly unchanged. Use
the stronger Amp/Cab roll-off, especially Cab model 2, to make DS-1 / RAT /
Big Muff / Fuzz / Metal sit naturally.

## Scope decisions

- `LowPassFir.hs` was changed only inside existing stages.
- No new AXI GPIO was added.
- `hw/Pynq-Z2/block_design.tcl` was not changed.
- `topEntity` ports were not changed.
- Python API method names and Notebook UI structure were not changed.
- No commercial amp / cabinet IR / pedal circuit coefficients were copied.
- No GPL DSP source was copied or ported.

## Implemented fix summary

- AmpSim: `ampDriveMultiplyFrame`, `ampPreLowpassFrame`,
  `ampToneProductsFrame` / `ampTrebleGain`, `ampPowerFrame`,
  `ampResPresenceProductsFrame` / `ampResPresenceMixFrame`, and
  `ampMasterFrame` were retuned to reduce high-end fizz and keep
  treble / presence / MASTER from overdriving the post-amp chain.
- Cabinet: `cabCoeff` was rebuilt for clearer model separation. Model 0
  is the lighter 1x12-style choice, model 1 is the balanced 2x12-style
  choice, and model 2 is the darkest 4x12-style choice for high-gain
  pedals. `cabLevelMixFrame` keeps the existing `softClip`; a lower
  `softClipK 3_400_000` trial was rejected because routed WNS reached
  -9.891 ns.
- Overdrive: `overdriveDriveMultiplyFrame`,
  `overdriveDriveClipFrame`, and `overdriveLevelFrame` now produce a
  clearer light-crunch change at moderate DRIVE while keeping output
  safety.
- Compressor: `compThresholdSample`, `compEnvNext`,
  `compTargetGain`, and `compGainNext` now start compression earlier
  and react slightly faster without changing the makeup range.
- Presets: DS-1 Crunch now uses Cab model 2 with capped `air`; Safe
  Bypass, Compressor makeup 45..60, and Distortion level <= 35 safety
  contracts remain intact.
- Python API and Notebook UI were not changed.
- `scripts/analyze_effect_recordings.py` was added so future recording
  sets can regenerate the nine analysis views.

## Build / deploy result

- VHDL regenerated, IP repackaged, Vivado bit/hwh rebuilt.
- Final deployed timing: WNS = -8.731 ns, TNS = -13665.555 ns,
  WHS = +0.051 ns, THS = 0.000 ns.
- Previous deployed WNS baseline was -7.917 ns, so this pass regressed
  setup WNS by 0.814 ns while staying inside the accepted deploy band.
- PYNQ deploy completed with `PYNQ_HOST=192.168.1.8
  bash scripts/deploy_to_pynq.sh`.
- Smoke test confirmed ADC HPF default-on (`R19_ADC_CONTROL = 0x23`),
  Compressor / Noise Suppressor GPIO presence, Overdrive and Compressor
  sanity writes, and all chain presets applying successfully.

## Caveats

- The visualization pass used downsampling for some plots to reduce runtime.
- High-frequency assessment focused mainly on 5 kHz and above. The lightweight
  visualization band was approximately 5 kHz to 7.5 kHz.
- These plots are quantitative support for a voicing direction. They do not
  replace a listening test through the deployed PYNQ-Z2 chain.

## Re-analysis script

`scripts/analyze_effect_recordings.py` can regenerate the nine comparison
views from a directory of WAV files:

```sh
python3 scripts/analyze_effect_recordings.py recordings_dir analysis_out
```

The script uses simple optional decimation via `--analysis-sr` to keep long
files manageable. Plot labels are English to avoid depending on Japanese font
availability in headless matplotlib environments.

## 2026-05-07 follow-up: Amp Simulator named models

Re-listening to the same recordings showed that high-gain pedals into the
amp produced a second top-end brightening at the `amp_character` settings
that worked well for clean material. Splitting the character byte into four
bands (one per named amp model) lets the post-clip pre-LPF darken slightly
more for the higher-gain bands without making the `amp_character` knob
discontinuous.

Action: introduce an `ampModelSel :: Unsigned 8 -> Unsigned 2` quantiser in
`LowPassFir.hs` and bias `ampPreLowpassFrame`'s alpha by `0 / 2 / 8 / 16`
across the four bands. Add an `AMP_MODELS` table and `set_amp_model` /
`get_amp_model_names` / `amp_model_to_character` convenience helpers in
Python. No new GPIO, no `topEntity` port change, no `block_design.tcl`
change. The existing audio-analysis darken cap on the post-clip pre-LPF is
preserved; the model-specific darken sits on top. See `DECISIONS.md` D18.
