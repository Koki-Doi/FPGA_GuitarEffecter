# Realism preset loudness (work order step 11)

Status: **offline survey done; NOT edited (offline amp path unreliable) --
final matching is a board/ear task** (2026-06-15). Work order step 11: even out
the loudness of the reference chain presets so preset switching has no accidental
volume jump (Solo may be intentionally louder). Canonical baseline = D126+D127
(`7f3ac394`).

## Offline survey (indicative only)

Built each reference preset's 12 control words offline by replicating
`AudioLabOverlay.apply_chain_preset` (taper via `knob_tapers.taper_chain_preset_spec`,
then `control_maps` word builders), ran `run_sim.synth_guitar` (1.5 s, level 0.12,
~-18.5 dBFS peak), measured RMS/peak/crest. amp_model_idx fixed to 0 for all.

| preset (key) | rms dBFS | peak dBFS | crest |
| --- | --- | --- | --- |
| Safe Bypass | -28.9 | -18.5 | 10.3 |
| Clean (`Basic Clean`) | -52.3 | -34.0 | 18.2 |
| Crunch (`Light Crunch`) | -42.5 | -24.5 | 18.0 |
| High Gain (`Noise Controlled High Gain`) | -47.1 | -30.1 | 17.0 |
| Ambient (`Ambient Clean`) | -34.8 | -22.1 | 12.7 |
| Solo (`Solo Boost`) | -44.4 | -27.8 | 16.5 |

No preset clipped (clip_count 0 on all).

## Why these numbers are NOT trustworthy enough to edit on

1. **The amp-ON presets read ~15-24 dB below Safe Bypass and below the amp-OFF
   Ambient preset.** A real clean amp + cab does not attenuate 24 dB; `measure.py`
   drives the amp fine at input_gain 18 / master 60, so Clean at input_gain 37 /
   master 75 reading -52 dBFS is implausible -> the offline amp word-building is
   not faithful (amp model / character->drive-mode mapping cannot be reproduced
   without the real overlay).
2. **STRUCTURAL FINDING: the chain presets do NOT pin the OD or amp model index.**
   `CHAIN_PRESETS` `overdrive`/`amp` dicts have no `model`/`model_idx`; the OD
   model defaults to 0 and the amp model is whatever the GUI/encoder currently
   has selected. So **a preset's loudness depends on the user's selected amp/OD
   model, not on the preset alone** -- e.g. "Light Crunch" through JC-120 (idx 0)
   vs JCM800 (idx 4) is a different level. The offline survey is forced to fix
   amp_idx=0, which under-drives the crunch/high-gain presets.

Because of (1)+(2), editing `effect_presets.py` makeup/level to match these
offline numbers would risk tuning to a flawed model and regressing the board.

## What IS usable

- The presets were already designed loudness-conscious (comment in
  `effect_presets.py`: makeup held 45..60, distortion level < 35, conservative
  reverb mix) -- no preset clips, crest factors are sane (10-18 dB).
- The amp-OFF Ambient preset measuring much louder than the amp-ON presets is at
  least a flag to check on the board: switching Clean -> Ambient may jump up.

## Recommended step-11 procedure (board / ear -- no rebuild)

Preset loudness is a Python/control-layer change (edit `effect_presets.py`
makeup / amp master / cab level / reverb mix; redeploy with
`bash scripts/deploy_to_pynq.sh`; NO bitstream rebuild). Do it on the board:

1. Set a fixed playing level + a fixed amp model (e.g. play through one model so
   the comparison is apples-to-apples, since presets don't pin the model).
2. Apply each reference preset (`apply_chain_preset`) and note perceived loudness
   + any clipping on hard strums.
3. Adjust the quiet/loud outliers via `effect_presets.py`: raise a quiet preset's
   `amp.master` or `compressor.makeup` (stay <= 60 per the safety contract), or
   trim a loud one's `cab.level` / `reverb.mix`. Keep Solo intentionally hotter.
4. Redeploy (Python only) and re-check by ear. Iterate.

### Optional structural improvement

Pin the OD/amp `model` in each `CHAIN_PRESETS` entry so a preset's loudness
(and tone) is deterministic regardless of the GUI's current selection. This is a
Python design change (add `model` keys + have `apply_chain_preset` pass
`amp_model` / honor the OD model) -- it makes step 11 well-defined. Decide with
the user before doing it (changes preset behavior: a preset would force its model).

## Model pinning IMPLEMENTED (user chose option 1; Python-only, no rebuild)

`effect_presets.CHAIN_PRESET_MODELS` now pins every chain preset's amp + OD model
(JC-120 for clean, JCM800 for crunch/lead, TriAmp for high-gain, Rockerverb for
Big Muff, AC30 for fuzz, etc.); `AudioLabOverlay.apply_chain_preset` reads it by
name and passes `amp_model_idx` / `overdrive_model`. A preset's loudness + tone is
now deterministic regardless of the GUI's current model selection -- the
structural fix step 11 needed. No bitstream change.

### Loudness with pinned models (offline, synth guitar)

| preset | amp model | rms dBFS | vs Clean |
| --- | --- | --- | --- |
| Clean (`Basic Clean`) | 0 JC-120 | -52.3 | 0 |
| Crunch (`Light Crunch`) | 4 JCM800 | -36.2 | +16.1 |
| High Gain (`Noise Controlled HG`) | 5 TriAmp | -46.2 | +6.0 |
| Ambient (`Ambient Clean`) | 0 (amp off) | -34.8 | +17.5 |
| Solo (`Solo Boost`) | 4 JCM800 | -37.7 | +14.6 |

Pinning made the comparison deterministic but the spread WIDE: the JC-120 clean
preset reads ~15 dB quieter than the JCM800 crunch/lead presets. This is partly
real (a clean SS amp at master 75 has low output until cranked) and partly the
offline amp-path uncertainty. **A +15 dB correction is too drastic to apply blind
on the sim** -- closing it would need a big master / input_gain change that risks
the tone or the sim being wrong. So the level trim is NOT applied here; it is a
board/ear confirmation step.

## Recommended next step (board, Python-only)

1. Deploy the model pinning (`bash scripts/deploy_to_pynq.sh`; no rebuild).
2. On the board, switch Clean -> Crunch -> High Gain -> Ambient -> Solo at a fixed
   volume and note the perceived jumps (the sim flags Clean as the quiet outlier).
3. If confirmed, raise the quiet presets' `amp.master` / `compressor.makeup`
   (<= 60) or trim the loud ones, edit `effect_presets.py`, redeploy (Python only),
   re-check by ear. Keep Solo intentionally hotter.

## acceptance (step 11)

- Model pinning done (deterministic presets) -- the structural enabler.
- Offline loudness re-measured with pinned models; Clean flagged as the quiet
  outlier but the +15 dB correction left to board confirmation (not applied blind).
- Final level trim is a board/ear pass (Python-only, no rebuild).
