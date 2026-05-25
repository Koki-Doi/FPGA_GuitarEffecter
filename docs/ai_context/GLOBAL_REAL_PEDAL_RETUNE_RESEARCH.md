# Global Real Pedal Retune Research

Research date: 2026-05-25.
Experiment branch: `feature/global-amp-dist-od-real-pedal-retune-20260525-192457`.
Baseline commit: `882a1cfe928a0aabdd02aefa4a8c6c80b0fd7e36`
(`Retune JCM800 amp model constants only`).

This document is the implementation-prep research note for one bulk,
high-risk retune of existing Amp / Distortion / Overdrive constants.
The user explicitly allows a one-branch bulk experiment, but the rollback
target is the D67 JCM800 accepted baseline above.

Implementation was intentionally deferred until after this research note
and the pre-implementation plan were reviewed. The accepted D68 edit
surface was limited to:

- `hw/ip/clash/src/AudioLab/Effects/Amp.hs`
- `hw/ip/clash/src/AudioLab/Effects/Distortion.hs`
- `hw/ip/clash/src/AudioLab/Effects/Overdrive.hs`

No model index, GPIO bit, AXI address, helper, pipeline, state register,
IIR, `LowPassFir.hs`, `Pipeline.hs`, Pmod RTL, HDMI, GUI, or
`block_design.tcl` change is part of this plan.

Accepted deployment result: bit/hwh md5
`cabb9bca3fbcc41f06f8b9fe8301cff1` /
`299485480dcc46aa0c679cef8f1a048a`, routed WNS `-7.333 ns`,
TNS `-9235.637 ns`, WHS `+0.051 ns`, THS `0.000 ns`, LUT `19842`,
FF `22246`, BRAM `6`, DSP `83`. Self-loopback smoke passed with no
`QUANT!` / `STAIR!` flags, and the user reported external bench PASS
for all_off bypass and all existing Amp / Distortion / Overdrive models.

## Sources

Primary product / manufacturer sources:

- Roland JC-120 official page:
  https://www.roland.com/us/products/jc-120/
- Fender `65 Twin Reverb official page:
  https://www.fender.com/products/65-twin-reverb/
- Vox AC30 Custom official page:
  https://voxamps.com/en-gb/product/ac30-custom/
- Orange Rockerverb 100 MKIII official page and manual:
  https://orangeamps.com/en-us/products/rockerverb-100-mkiii
  https://orangeamps.com/manuals/rockerverb-mkiii-manual/
- Marshall JCM800 2203 official page:
  https://www.marshall.com/us/en/product/jcm800-2203-vintage-reissue-head
- Hughes & Kettner TriAmp Mark 3 official page:
  https://hughes-and-kettner.com/product/triamp-mark-3/
- Ibanez TS9 official page:
  https://www.ibanez.com/eu/products/detail/ts9_99.html
- BOSS DS-1 official page:
  https://www.boss.info/ca/products/ds-1/
- BOSS MT-2 official page:
  https://www.boss.info/ca/products/mt-2/
- BOSS BD-2 official page:
  https://www.boss.info/ca/products/bd-2/
- BOSS BOX-40 / OD-1 official history:
  https://www.boss.info/us/products/box-40/
- Electro-Harmonix Big Muff Pi official page:
  https://www.ehx.com/products/big-muff-pi/
- Fulltone OCD V2 official page:
  https://www.fulltoneusa.com/products/ocd-v2

Circuit / analysis sources:

- ElectroSmash Tube Screamer analysis:
  https://www.electrosmash.com/tube-screamer-analysis
- ElectroSmash DS-1 analysis:
  https://www.electrosmash.com/boss-ds1-analysis
- ElectroSmash Big Muff Pi analysis:
  https://www.electrosmash.com/big-muff-pi-analysis
- ElectroSmash Fuzz Face analysis:
  https://www.electrosmash.com/fuzz-face
- ElectroSmash ProCo RAT analysis:
  https://www.electrosmash.com/proco-rat
- ElectroSmash MXR MicroAmp analysis:
  https://www.electrosmash.com/mxr-microamp
- ElectroSmash Klon Centaur analysis:
  https://www.electrosmash.com/klon-centaur-analysis
- Fenderguru Twin Reverb / AB763 notes:
  https://fenderguru.com/amps/twin-reverb/
- Rob Robinette AB763 analysis:
  https://robrobinette.com/How_The_AB763_Deluxe_Reverb_Works.htm
- Delicious Audio Jan Ray summary:
  https://delicious-audio.com/vemuram-jan-ray-overdrive/
- Existing project research retained as local context:
  `AMP_MODEL_RESEARCH_D55.md`, `BD2_MODEL_RESEARCH.md`,
  `DS1_MODEL_RESEARCH.md`,
  `DISTORTION_ASYMSOFTCLIP_RETUNE_RESEARCH.md`.

Lower-confidence material:

- Retail summaries, magazine reviews, and forum posts were used only to
  cross-check character words such as "transparent", "scooped", "thick",
  "tight", and "open". They are not used as coefficient authority.

## Existing Model Inventory

### Amp

The live Amp model field is `axi_gpio_amp_tone.ctrlD[2:0]`.

| Index | Model | Existing status |
| ---: | --- | --- |
| 0 | `JC-120` | active |
| 1 | `Twin Reverb` | active |
| 2 | `AC30` | active |
| 3 | `Rockerverb` | active |
| 4 | `JCM800` | active, D67 accepted retune |
| 5 | `TriAmp Mk3` | active |
| 6, 7 | reserved | Clash fallback to `JC-120` |

### Distortion

The live Distortion pedal mask is `axi_gpio_distortion.ctrlD`.
`rat` maps onto the existing RAT stage through the Python gate bit.
The legacy distortion stage is also present when the section master is
on and no pedal-mask bit is set.

| Bit / path | Model | Existing status |
| --- | --- | --- |
| legacy | `legacy distortion` | active when no pedal mask is set |
| bit 0 | `clean_boost` | active |
| bit 1 | `tube_screamer` | active |
| bit 2 | `rat` | active via existing RAT stage |
| bit 3 | `ds1` | active, D66 accepted knee retune |
| bit 4 | `big_muff` | active |
| bit 5 | `fuzz_face` | active |
| bit 6 | `metal` | active |
| bit 7 | reserved | no model added |

### Overdrive

The live Overdrive model field is `axi_gpio_overdrive.ctrlD[2:0]`.

| Index | Model | Existing status |
| ---: | --- | --- |
| 0 | `ts9` | active |
| 1 | `od1` | active |
| 2 | `bd2` | active, D62 accepted retune |
| 3 | `jan_ray` | active |
| 4 | `ocd` | active |
| 5 | `centaur` | active |
| 6, 7 | reserved | Clash fallback to `ts9` |

## Amp Current Values And Candidates

The Amp retune edits only existing per-model table entries and
per-model constants in `Amp.hs`.

### Current Values

| Model | `ampCharForModel` | `ampModelDarken` | `ampPreLpfDriveDarken` | `ampSecondStageDriveBonus` | `ampDrivePosDelta` | `ampDriveNegDelta` | `ampTrebleTrim` | `presenceTrim` |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| JC-120 | 26 | 0 | 5 | 14 | 13_000 | 11_000 | 0 | 0 |
| Twin Reverb | 89 | 2 | 7 | 18 | 58_000 | 50_000 | 1 | `presenceByte >> 6` |
| AC30 | 153 | 4 | 10 | 28 | 130_000 | 113_000 | 3 | `presenceByte >> 5` |
| Rockerverb | 200 | 12 | 16 | 42 | 210_000 | 180_000 | 6 | `presenceByte >> 4` |
| JCM800 | 220 | 10 | 13 | 54 | 264_000 | 200_000 | 8 | `presenceByte >> 4` |
| TriAmp Mk3 | 240 | 28 | 24 | 56 | 336_000 | 300_000 | 12 | `presenceByte >> 3` |

### Candidate Values

| Model | `ampCharForModel` | `ampModelDarken` | `ampPreLpfDriveDarken` | `ampSecondStageDriveBonus` | `ampDrivePosDelta` | `ampDriveNegDelta` | `ampTrebleTrim` | `presenceTrim` |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| JC-120 | 18 | 0 | 3 | 8 | 6_000 | 5_000 | 0 | 0 |
| Twin Reverb | 78 | 3 | 8 | 14 | 38_000 | 34_000 | 2 | `presenceByte >> 5` |
| AC30 | 166 | 3 | 8 | 34 | 155_000 | 132_000 | 2 | `presenceByte >> 6` |
| Rockerverb | 208 | 18 | 22 | 48 | 240_000 | 220_000 | 9 | `presenceByte >> 3` |
| JCM800 | 220 | 10 | 13 | 54 | 264_000 | 200_000 | 8 | `presenceByte >> 4` |
| TriAmp Mk3 | 246 | 26 | 30 | 68 | 400_000 | 360_000 | 14 | `presenceByte >> 3` |

### Amp Intent

| Model | Target | Differentiation |
| --- | --- | --- |
| JC-120 | Cleaner, brighter, lower drive, high headroom, tighter low feel. | Lowest character and drive deltas; no extra dark top; no tube bloom. |
| Twin Reverb | Glassy clean with tube edge, scooped/bright but less painful than JC. | More rounded than JC, less breakup than AC30, slightly more presence trim. |
| AC30 | Chime, upper-mid, jangly earlier breakup, light low end. | More drive than Twin, brighter than Rockerverb/JCM800, less hard than JCM800. |
| Rockerverb | Thick, darker, low-mid, smooth gain. | Darker and thicker than JCM800; less tight/modern than TriAmp. |
| JCM800 | Preserve D67 success: tight, upper-mid, fast attack, cold-clipper feel. | Candidate leaves D67 constants unchanged. |
| TriAmp Mk3 | Modern high gain, tight, saturated, aggressive, fizz-controlled. | More saturation than JCM800, tighter and brighter than Rockerverb, top controlled. |

## Distortion Current Values And Candidates

The Distortion retune edits only constants inside existing helper calls
and existing gain / filter formulas in `Distortion.hs`. No helper is
added, removed, swapped, or cascaded.

### Current Values

| Path | Current constants |
| --- | --- |
| legacy distortion | `driveGain = 256 + amount * 8`; `rawThreshold = 8_388_607 - amount * 24_000`; floor `1_800_000` |
| clean boost | `gain = 256 + drive * 3`; `safetyKnee = 3_200_000` |
| tube screamer | HPF `3 + tight >> 4`; gain `256 + drive * 6`; knees `2_900_000 / 2_500_000`; post LPF `64 + tone >> 1` |
| DS-1 | HPF `4 + tight >> 4`; gain `256 + drive * 8`; knees `1_900_000 / 1_900_000`; tone LPF `96 + tone >> 1`; safety `3_000_000` |
| Big Muff | gain `384 + drive * 12`; clip knees `2_700_000`, `2_000_000`; second gain `192`; tone LPF `56 + tone >> 1`; safety `2_900_000` |
| Fuzz Face | gain `512 + drive * 9`; knees `1_900_000 / 1_400_000`; tone LPF `72 + tone >> 1`; safety `2_800_000` |
| Metal | HPF `6 + tight >> 3`; gain `768 + drive * 12`; threshold `3_500_000 - drive * 5_000`, floor `1_500_000`; post LPF `48 + tone >> 1` |
| RAT | HPF feedback `254`; gain `512 + drive * 14`; op-amp LPF `192 - drive >> 1`; threshold `6_291_456 - drive * 9_000`, floor `2_500_000`; post LPF `176`; filter base `200` |

### Candidate Values

| Path | Candidate constants |
| --- | --- |
| legacy distortion | `driveGain = 256 + amount * 9`; `rawThreshold = 8_388_607 - amount * 28_000`; floor `1_600_000` |
| clean boost | `gain = 256 + drive * 2`; `safetyKnee = 3_800_000` |
| tube screamer | HPF `4 + tight >> 4`; gain `256 + drive * 5`; knees `3_000_000 / 2_850_000`; post LPF `56 + tone >> 1` |
| DS-1 | HPF `5 + tight >> 4`; gain `256 + drive * 9`; knees `1_900_000 / 1_900_000`; tone LPF `104 + tone >> 1`; safety `3_000_000` |
| Big Muff | gain `448 + drive * 11`; clip knees `2_400_000`, `1_850_000`; second gain `208`; tone LPF `48 + tone >> 1`; safety `3_100_000` |
| Fuzz Face | gain `448 + drive * 8`; knees `2_100_000 / 1_150_000`; tone LPF `80 + tone >> 1`; safety `3_000_000` |
| Metal | HPF `8 + tight >> 3`; gain `768 + drive * 13`; threshold `3_300_000 - drive * 6_000`, floor `1_250_000`; post LPF `40 + tone >> 1` |
| RAT | HPF feedback `255`; gain `640 + drive * 12`; op-amp LPF `184 - drive >> 1`; threshold `6_000_000 - drive * 8_500`, floor `2_200_000`; post LPF `168`; filter base `192` |

### Distortion Intent

| Path | Target | Differentiation |
| --- | --- | --- |
| legacy distortion | Harder generic clipping for the old API path. | Rougher than clean boost / TS, simpler than RAT. |
| clean boost | Mostly clean level push, high safety headroom. | Least tone change and least intrinsic distortion in the section. |
| tube screamer | Smooth, symmetric-leaning, low-cut, mid-forward, not too early clipping. | Lower gain and later knees than DS-1 / Metal / Muff; tighter input than clean boost. |
| DS-1 | Hard-edged, symmetric, cutting. | Keeps D66 symmetric knees; gain and tone move it harder/brighter without cascade. |
| Big Muff | Compressed, sustaining, thick, fuzz-distortion. | Two existing clip stages stay; hotter floor and darker post tone separate it from DS-1/RAT. |
| Fuzz Face | Asymmetric, broken-up, cleanup-capable. | Lower pre-gain than current plus stronger knee split; not a gated modern fuzz. |
| Metal | Tight, aggressive high gain with controlled fizz. | Most gain and tightest low cut; darker post LPF to avoid harsh top. |
| RAT | Fat, rough op-amp hard clip with older voice. | Fatter and darker than DS-1; less modern and less tight than Metal. |

## Overdrive Current Values And Candidates

The Overdrive retune edits only the existing model lookup tables in
`Overdrive.hs`: `odDriveK`, `odKneeP`, `odKneeN`, and `odSafetyKnee`.
BD-2 D62 is preserved.

### Current Values

| Index | Model | `odDriveK` | `odKneeP` | `odKneeN` | `odSafetyKnee` |
| ---: | --- | ---: | ---: | ---: | ---: |
| 0 | TS9 | 5 | 2_700_000 | 2_300_000 | 3_200_000 |
| 1 | OD-1 | 4 | 2_600_000 | 2_100_000 | 3_000_000 |
| 2 | BD-2 | 7 | 2_400_000 | 1_900_000 | 3_400_000 |
| 3 | Jan Ray | 3 | 3_200_000 | 3_000_000 | 3_400_000 |
| 4 | OCD | 7 | 2_300_000 | 1_900_000 | 3_500_000 |
| 5 | Centaur | 5 | 2_800_000 | 2_600_000 | 3_400_000 |

### Candidate Values

| Index | Model | `odDriveK` | `odKneeP` | `odKneeN` | `odSafetyKnee` |
| ---: | --- | ---: | ---: | ---: | ---: |
| 0 | TS9 | 4 | 2_950_000 | 2_850_000 | 3_350_000 |
| 1 | OD-1 | 5 | 2_550_000 | 1_750_000 | 3_050_000 |
| 2 | BD-2 | 7 | 2_400_000 | 1_900_000 | 3_400_000 |
| 3 | Jan Ray | 2 | 3_600_000 | 3_450_000 | 3_700_000 |
| 4 | OCD | 7 | 2_450_000 | 2_150_000 | 3_750_000 |
| 5 | Centaur | 4 | 3_100_000 | 2_900_000 | 3_650_000 |

### Overdrive Intent

| Model | Target | Differentiation |
| --- | --- | --- |
| TS9 | Smooth, mid-hump feel, symmetric-leaning, low gain. | Less gain and later knees than OD-1 / BD-2 / OCD. |
| OD-1 | Asymmetric, warm, rougher early BOSS OD. | More asymmetric and more immediate than TS9, less wide than BD-2. |
| BD-2 | Preserve D62 success: early breakup, asymmetry, touch response. | Candidate leaves D62 constants unchanged. |
| Jan Ray | Transparent, low gain, wide range, low compression. | Lowest drive and highest knees/headroom in the OD table. |
| OCD | Open, dynamic, hard-clipping-leaning, thick but ordered. | Same drive ceiling as BD-2, less asymmetry, later knees, and more output headroom. |
| Centaur | Clean-blend-like smooth drive, low-mid body, stable at gain. | Higher knees and lower gain than OCD, smoother than OD-1/BD-2. |

## Items Not Changed

- `LowPassFir.hs`: unchanged because this pass is table/constant-only.
- `AudioLab/Pipeline.hs`: unchanged; no new register or state.
- `hw/Pynq-Z2/block_design.tcl`: unchanged; no block-design approval was
  requested or granted.
- GPIO mapping / model index / control bits / AXI addresses: unchanged.
- Pmod I2S2 RTL, HDMI, GUI, notebooks, Python control mapping: unchanged.
- Helper inventory: unchanged; no helper add, helper swap, or helper
  cascade.
- New DSP / BRAM / register topology: none planned.
- BD-2 D62 constants: preserved.
- JCM800 D67 constants: preserved.
- Reserved model slots and pedal bit 7: untouched.

## Why This Should Not Add DSP

Every candidate changes a literal constant, a table entry, or a numeric
operand already feeding an existing operation. The planned patch does
not introduce new `mulU8`, `mulU9`, `mulU12`, `onePoleU8`, `hardClip`,
`softClipK`, `asymSoftClip`, `asymHardClip`, register, field, or
pipeline node. The generated VHDL will still need a full Vivado build,
because constant changes can still perturb placement and routing.

## Rollback

Rollback is defined in
`docs/ai_context/GLOBAL_RETUNE_ROLLBACK_PLAN.md`.

Reject rollback target:

- commit `882a1cfe928a0aabdd02aefa4a8c6c80b0fd7e36`
- bit md5 `70b5dc7d972510c26fbb3b1014aa06eb`
- hwh md5 `dc42290dc7fb46d7486068cc1d11032a`

Reject restores only these implementation/build artefacts from the
baseline commit:

- `hw/ip/clash/src/AudioLab/Effects/Amp.hs`
- `hw/ip/clash/src/AudioLab/Effects/Distortion.hs`
- `hw/ip/clash/src/AudioLab/Effects/Overdrive.hs`
- `hw/ip/clash/vhdl/LowPassFir/`
- `hw/Pynq-Z2/bitstreams/audio_lab.bit`
- `hw/Pynq-Z2/bitstreams/audio_lab.hwh`

Research docs and rejected-record docs may remain, but rejected source,
VHDL, bit, and hwh must not be committed.
