# Current state

Latest work: **2026-05-28 (D72 Wah effect added on a dedicated AXI GPIO; Clash + Vivado rebuilt; pending deploy / bench):** This pass adds a new resonant band-pass Wah effect on the branch `feature/wah-effect`. A new `axi_gpio_wah` IP is placed at `0x43D30000` via a separate `hw/Pynq-Z2/wah_integration.tcl` that is sourced from `create_project.tcl` after `pmod_i2s2_integration.tcl`; `block_design.tcl` itself is **not edited**, mirroring the additive pattern used by HDMI / encoder / Pmod_I2S2. The integration script bumps `ps7_0_axi_periph/NUM_MI` from 19 to 20 to expose `M19_AXI` for the new GPIO, then wires `axi_gpio_wah/gpio_io_o` to `clash_lowpass_fir_0/wah_control`. The Clash side adds a new `hw/ip/clash/src/AudioLab/Effects/Wah.hs` (Chamberlin parallel-update state-variable filter, fixed-point throughout, no Float/Double, no large table), a new `wah_control` topEntity port, a new `fWah :: Ctrl` field in the `Frame` record, and 5 new pipeline-level state registers (`wahPosSmooth`, `wahFByteR`, `wahQBandR`, `wahLow`, `wahBand`). The Wah is inserted between `compMakeupPipe` and `odDriveMulPipe` so the DSP chain order matches the spec: Noise Gate -> Compressor -> Wah -> Overdrive -> Distortion -> RAT / Pedals -> Amp -> Cab -> EQ -> Reverb. Bit-exact bypass when the enable bit is clear. **First Vivado pass exposed a timing regression** (WNS `-18.966 ns` vs the D71.2 baseline `-9.413 ns`, regression `-9.55 ns`); the worst path was `wahPosSmooth_reg[6]/C -> wahBand_reg[4]/D` with 34 logic levels including 3 DSP48E1 in series. Wah.hs was refactored to pre-register the position-to-fByte mapping and the q*oldBand product into separate `wahFByteR` and `wahQBandR` register stages so each subsequent state update consumes at most one DSP + small adders. After the refactor Vivado completed with `write_bitstream completed successfully` and `0 Errors`. Routed timing: WNS `-10.387 ns`, TNS `-12177.222 ns`, WHS `+0.052 ns`, THS `0.000 ns`; design summary failing endpoints `3877 / 61321`. Utilization: LUT `21023`, FF `22691`, BRAM `6`, DSP `89` (D71.2 baseline LUT `19956`, FF `22260`, BRAM `6`, DSP `83`; deltas LUT `+1067`, FF `+431`, BRAM `0`, DSP `+6`). WNS delta vs D71.2 is `-0.974 ns` -- within the range historically accepted in this project (D70 was `-1.302 ns` and was accepted as a deploy candidate). The new worst path is `ds1_7_reg[154]/C -> ARG__4__0__0_i_4_psdsp/D` inside the existing DS-1 distortion stage; the Wah state-register chains no longer appear in the top-100 paths, confirming the pipeline split worked. bit/hwh md5 are `eacc4f35bd81c3afcdbb808baa4c8d47` / `eaa888985c319841147d1ce73d6601b5`. The new bit/hwh are staged in `hw/Pynq-Z2/bitstreams/`. **Deploy + structural smoke PASS; external-instrument bench audition still pending**: `scripts/deploy_to_pynq.sh` deployed bit/hwh to all four board copies (`/home/xilinx/Audio-Lab-PYNQ/hw/Pynq-Z2/bitstreams/`, `/usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams/`, `/home/xilinx/jupyter_notebooks/audio_lab/bitstreams/`, `/usr/local/lib/python3.6/dist-packages/pynq/overlays/audio_lab/`) and the md5 of every board copy matches the local `hw/Pynq-Z2/bitstreams/audio_lab.bit` / `.hwh`. `AudioLabOverlay(download=True)` programmed the PL cleanly; ADC HPF reads `True` (R19 `0x23`), `hasattr(ovl, "axi_gpio_wah")` is `True`, and a round-trip `set_wah_settings(enabled=True, position=128, q=60, volume=50, bias=55)` produced `word=0xc6809980` with `position_byte=128`, `q_byte=153`, `volume_byte=128`, `bias_u7=70`, `enable_bias_byte=0xc6` -- all matching the spec. `set_wah_settings(enabled=False)` then produced `word=0x46809980` with the enable bit cleared but the bias / position / Q / VOLUME bytes preserved (cache-discipline OK). `scripts/diagnose_pmod_loopback.py` PASS across every phase: Phase 1 (MUTE / TONE / LOOP / DSP / MUTE on the Pmod modes) gave `clip_d = 0` everywhere with the expected `peakL` ranges; Phase 3 (MODE 0 DMA capture + FFT) shows a clean 1 kHz peak (`mag=7.06e9`) with harmonics > 1000x below, and MODE 3 mute is at the codec noise floor (`rms=10930`, `peak=990497`); Phase 5 (DSP-bypass MM2S sweep, 1k/4k/8k/12k at -12 dBFS) gave `uniq1k=1000 maxRun=1` for every cell -- no quantization; Phase B (DSP chain all-off, 1k/4k/8k/10k/12k/15k at -30 / -20 / -12 dBFS) gave `uniq1k` 996-1000 and `maxRun=2` for every cell -- no bit-crusher / STAIR! / QUANT! flag raised. **VERDICT: PASS (no bit-crusher / quantization signature in any phase).** D71.2 remains the rollback baseline until external-instrument bench audition (all_off bypass D69-clean, Wah OFF bit-exact bypass, Wah ON position 0/64/128/192/255 audibly sweeps centre frequency, Q 0/50/100 audibly changes peak width, VOLUME 50 ~= unity / 100 boosted without breakup, BIAS 0/50/100 audibly shifts range) confirms acceptance. Python side: new `audio_lab_pynq.control_maps.wah_word` packer plus `wah_position_byte` / `wah_q_byte` / `wah_volume_byte` / `wah_bias_to_u7` / `wah_enable_bias_byte` helpers; new `WAH_DEFAULTS` in `effect_defaults.py`; `AudioLabOverlay.set_wah_settings(...)` / `get_wah_settings()`; `set_guitar_effects(wah_enabled=, wah_position=, wah_q=, wah_volume=, wah_bias=, wah_source=)` delegation; new `EncoderEffectApplier._apply_wah` path. GUI side: compact-v2 `EFFECTS` adds `"Wah"` between `"Compressor"` and `"Overdrive"` (chain length 8 -> 9), `EFFECT_KNOBS["Wah"] = [POS, Q, VOL, BIAS]` (2x2 grid), `AppState.wah_source` field, FX panel renders `SOURCE: MANUAL` strip when WAH is selected (with hit_test grid_y0 shift to match), state JSON round-trip preserves `wah_source`. HDMI state mirror: `GUI_EFFECTS`/`GUI_EFFECT_KNOBS`/`EFFECT_INDEX_BY_SELECTED_FX`/`SELECTED_FX_ALIASES`/`CANONICAL_SELECTED_FX`/`METHOD_SELECTED_FX`/`GUITAR_KWARG_PREFIX_TO_SELECTED_FX`/`GUITAR_CATEGORY_PRIORITY` all gain `"WAH"` / `"Wah"` entries with the other effect indices shifted +1 above `"Compressor"`. Tests: 22 new Wah tests in `tests/test_overlay_controls.py` (byte / word / clamp / metadata / enable-bit / safe-bypass / set_guitar_effects forwarding / all-off bypass invariance / source-only no-byte-change / safe_bypass dict contains wah keys / effect_defaults exposes `WAH_DEFAULTS`), and 5 existing GUI-coupled tests updated to match the new 9-effect indexing. `python3 -m unittest discover -s tests` runs 92 tests with the same 3 failures + 1 error that exist on master (no new Wah-introduced failures). Reads of the existing `docs/ai_context/WAH_EFFECT_INTEGRATION_PLAN.md` (committed on this branch) record the approval scope. Acceptance gate: D71.2 remains the rollback baseline until the new bit passes (a) Vivado WNS not significantly worse than `-9.413 ns`, (b) `scripts/diagnose_pmod_loopback.py` PASS with no QUANT!/STAIR! and CLIP_COUNT 0, (c) bench audition: all_off bypass D69-clean, Wah OFF clean (bit-exact bypass), Wah ON sweep with position 0..255 audibly moves the BPF centre frequency, Q 0/50/100 audibly changes peak width, VOLUME 50 unity-ish and 100 boosted without breakup, BIAS 0/50/100 audibly shifts the sweep range.

Superseded D71 note (rollback baseline; retained for history): **2026-05-27 (D71 Cabinet multi-band pseudo-IR speaker character candidate deployed, self-loopback PASS, external bench pending):** This pass extends D70's cabinet simulator with a multi-band pseudo-IR blend for stronger speaker character and model separation, all within `hw/ip/clash/src/AudioLab/Effects/Cab.hs`. Changes: (1) FIR coefficient table redesigned with sums normalized to 256/260/264, stronger Nyquist rejection (model 0: -16, model 1: -24, model 2: -44 at air 0; D70 was -8/-2/-32), and widened early:body ratios (model 0: 2.76:1, model 1: 1.24:1, model 2: 0.42:1); (2) presence/cone breakup via new `softClipK(cabPresenceKnee)` on the saturated early component in `cabProductsFrame`, carried to `cabIrFrame` via `fEqLowL` transient field (per-model mix: open 25%, combo 12.5%, closed 12.5%); (3) fizz suppression in `cabIrFrame` via `input - mainSat` HF residual subtraction (per-model fraction: open 12.5%, combo 25%, closed 50%), creating effective H_eff(f) = H(f) + fraction*(H(f)-1) that deepens the FIR null near 12 kHz; (4) per-model mid-body emphasis in `cabIrFrame` (open 0%, combo 6.25%, closed 12.5%); (5) speaker compression knees widened to 5.6M/4.0M/2.8M (D70 was 5.2M/4.2M/3.4M); (6) body resonance knees retuned to 2.4M/1.6M/1.2M (D70 was 2.2M/1.8M/1.4M). No `Pipeline.hs`, `LowPassFir.hs`, `Amp.hs`, `Overdrive.hs`, `Distortion.hs`, `Compressor.hs`, GUI, HDMI, Encoder, Pmod RTL, or `block_design.tcl` change. No new GPIO, register, IIR, DSP48, or BRAM; one `softClipK` added (LUT-only). Clash VHDL was regenerated; Vivado completed with `write_bitstream completed successfully` and `0 Errors`. Routed timing: WNS `-9.413 ns`, TNS `-10233.182 ns`, WHS `+0.051 ns`, THS `0.000 ns`; design summary failing endpoints `3219 / 60414`. Utilization: LUT `19956`, FF `22260`, BRAM `6`, DSP `83`. WNS delta 0.000 ns vs D70 (incremental build reused D70 placement). bit/hwh md5 are `9a739f904aef0955b7e59837a2c33d41` / `f28f08674d25c65a48cd240ae31a578a` (after D71.2). D71.1 (fizz/presence/body fraction grid-search to match target dB curves) and D71.2 (body darkening to fix the 16-20 kHz non-monotonic bump + deepen 8 kHz rolloff; Air Mid: M0 -4.4 / M1 -4.7 / M2 -5.1 at 8 kHz, all models monotonically decrease through 20 kHz) are applied on top of the base D71 build. Python tests PASS, deploy-time board md5 checks, `AudioLabOverlay(download=True)`, ADC HPF True, and `scripts/diagnose_pmod_loopback.py` all passed with no QUANT! / STAIR! and CLIP_COUNT 0. **Bench pending**: all_off bypass must be D69-clean, Cab0/1/2 model difference must be clearly audible (Cab0 bright+light, Cab1 mid+chime, Cab2 thick+dark), high-gain fizz must be reduced, 5 kHz+ rolloff must be sharper than D70, low-end must not be muddy. D70 is the rollback baseline until bench result is reported.

Superseded D70 note (bench candidate superseded by D71; retained for history): **2026-05-26 (D70 Cabinet speaker character improvement candidate deployed, self-loopback PASS, external bench pending):** This pass improves the cabinet simulator in `hw/ip/clash/src/AudioLab/Effects/Cab.hs` with three changes: (1) FIR coefficient table redesign for stronger model separation and Nyquist rejection (model 0 direct:body ratio 2.9:1, model 2 ratio 0.46:1; Nyquist responses improved from 28/20/-20 to -8/-2/-32), (2) saturated body-resonance term in `fAcc3L` via `satShift8` -> `softClipK` -> `resize << N` providing speaker-cone compression without new DSP48, (3) per-model `softClipK` speaker knee in `cabLevelMixFrame` replacing the fixed `softClip` (open 5.2M / combo 4.2M / closed 3.4M). A secondary fix patches the missing D54 BRAM wrapper for `trueDualPortBlockRamWrapper_0.vhdl` enabling fresh Vivado builds after `make clean`. No `Pipeline.hs`, `LowPassFir.hs`, `Amp.hs`, `Overdrive.hs`, `Distortion.hs`, GUI, HDMI, Encoder, Pmod RTL, or `block_design.tcl` change. No new GPIO, register, IIR, DSP48, or BRAM. Clash VHDL was regenerated; Vivado completed with `write_bitstream completed successfully` and `0 Errors`. Routed timing: WNS `-9.413 ns`, TNS `-10233.182 ns`, WHS `+0.051 ns`, THS `0.000 ns`; design summary failing endpoints `3219 / 60414`. Utilization: LUT `19956`, FF `22260`, BRAM `6`, DSP `83`. WNS delta is -1.302 ns vs D69 (-8.111); the delta includes both the Cab combinational-logic addition and the i2s_to_stream BRAM wrapper change. bit/hwh md5 are `aab907a4e56260543dc48adb35a3f09f` / `f28f08674d25c65a48cd240ae31a578a`. Python tests 241 PASS, deploy-time board md5 checks, `AudioLabOverlay(download=True)`, ADC HPF True, and `scripts/diagnose_pmod_loopback.py` all passed with no QUANT! / STAIR! and CLIP_COUNT 0.

Latest work: **2026-05-26 (D69 Amp Drive Mode saturation candidate deployed, self-loopback PASS, external bench pending):** This pass strengthens only Amp Sim Drive Mode saturation in `hw/ip/clash/src/AudioLab/Effects/Amp.hs`. It changes only existing Drive-mode table constants: `ampPreLpfDriveDarken` becomes `6 / 8 / 12 / 20 / 20 / 30`, `ampSecondStageDriveBonus` becomes `22 / 30 / 42 / 62 / 74 / 88`, `ampDrivePosDelta` becomes `16_200 / 85_800 / 232_400 / 374_400 / 462_000 / 615_000`, and `ampDriveNegDelta` becomes `13_500 / 74_100 / 199_200 / 322_400 / 407_000 / 541_200` for JC-120 / Twin Reverb / AC30 / Rockerverb / JCM800 / TriAmp Mk3. The delta tables stay fixed scalars (`Unsigned 3 -> Signed 25`) rather than the abandoned runtime `ch * factor` multiplier shape, using the current `ampCharForModel` values `18 / 78 / 166 / 208 / 220 / 246`. Clean-mode tables, Amp OFF routing, `amp_model_idx`, `amp_drive_mode` bit allocation, all other effects, GUI / HDMI / Encoder, Pmod RTL, and `block_design.tcl` are unchanged. Clash VHDL was regenerated; Vivado completed with `write_bitstream completed successfully` and `0 Errors`. Routed timing: WNS `-8.111 ns`, TNS `-9246.014 ns`, WHS `+0.052 ns`, THS `0.000 ns`; design summary failing endpoints `3157 / 60278`. Utilization: LUT `19717`, FF `22156`, BRAM `6`, DSP `83`. bit/hwh md5 are `6a1834b7f66693f82663c2c8a2fda28b` / `927191b506c68588eaae286f4ccce112`. Python py_compile, 91 unittest cases, `tests/test_overlay_controls.py`, deploy-time board md5 checks, `AudioLabOverlay(download=True)`, ADC HPF True / R19 `0x23`, and `scripts/diagnose_pmod_loopback.py` all passed. The loopback smoke produced no `QUANT!` / `STAIR!` flags and CLIP_COUNT stayed `0`; additional DMA-sine Amp-state smoke at 1 kHz / `-12 dBFS` also reported `clip_d=0` for all_off passthrough, Amp OFF with Drive bits ignored, JC-120 Clean, JC-120 Drive, AC30 Drive, Rockerverb Drive, JCM800 Drive, and TriAmp Drive. **This is not accepted yet**: external-instrument bench still must confirm all_off bypass is D68-clean, Amp OFF is quiet, Clean Mode is not broken, Drive Mode is audibly stronger on all six models, TriAmp Mk3 does not break up into pops, and CLIP_COUNT remains normal. D68 remains the accepted rollback baseline until that bench result is reported.

Latest work: **2026-05-25 (D68 global Amp / Distortion / Overdrive real-pedal retune accepted, deployed, self-loopback PASS, external bench PASS):** Branch `feature/global-amp-dist-od-real-pedal-retune-20260525-192457` bulk-retuned existing constants only in `hw/ip/clash/src/AudioLab/Effects/Amp.hs`, `hw/ip/clash/src/AudioLab/Effects/Distortion.hs`, and `hw/ip/clash/src/AudioLab/Effects/Overdrive.hs` to spread the implemented models closer to their real-amp / real-pedal references. The work intentionally used a single high-risk experiment branch because the user explicitly allowed bulk change and required rollback to the D67 baseline (`882a1cfe928a0aabdd02aefa4a8c6c80b0fd7e36`). It did not add models, change model indices, change control mapping, change AXI addresses, edit `Pipeline.hs` / `LowPassFir.hs`, add registers, add IIRs, add helpers, add cascades, add DSP blocks, edit GUI / HDMI / Pmod RTL, or edit `block_design.tcl`. JCM800 D67 and BD-2 D62 successful entries were preserved. Clash VHDL was regenerated from the existing topology; Vivado completed with `write_bitstream completed successfully` and `0 Errors`. Routed timing: WNS `-7.333 ns`, TNS `-9235.637 ns`, WHS `+0.051 ns`, THS `0.000 ns`; design summary failing endpoints `3595 / 60350`, worst path `compLevelPipe_reg[638]/C -> compGain_reg[7]/D`. Utilization: LUT `19842`, FF `22246`, BRAM `6`, DSP `83`. bit/hwh md5 are `cabb9bca3fbcc41f06f8b9fe8301cff1` / `299485480dcc46aa0c679cef8f1a048a`. Python py_compile, 91 unittest cases, `tests/test_overlay_controls.py`, deploy-time board md5 checks, `AudioLabOverlay(download=True)`, ADC HPF True, MODE 3 mute, and `scripts/diagnose_pmod_loopback.py` all passed. The self-loopback smoke produced no `QUANT!` / `STAIR!` flags and CLIP_COUNT stayed `0`; it remains only a structural smoke check. The user then reported external-instrument bench PASS for all_off bypass, all Amp models, all Distortion models, and all Overdrive models, and requested merge to `main`. D68 is now the accepted deployed baseline; D67 is the immediate rollback baseline recorded in `docs/ai_context/GLOBAL_RETUNE_ROLLBACK_PLAN.md`, and D62 remains the deeper known-good rollback reference.

Superseded D67 note (previous baseline; retained for history) follows.

Latest work: **2026-05-25 (D67 JCM800 amp model constants-only retune accepted and deployed):** Branch `feature/jcm800-amp-model-retune` retunes ONLY the JCM800 entry (`amp_model_idx == 4`) in `hw/ip/clash/src/AudioLab/Effects/Amp.hs`. The functional source edit is three existing model-table constants: `ampPreLpfDriveDarken` `16 -> 13`, `ampSecondStageDriveBonus` `48 -> 54`, and `ampDriveNegDelta` `231_000 -> 200_000`; `ampDrivePosDelta` stays `264_000`, and the JCM800 `ampTrebleGain` / `presenceTrim` entries are unchanged. The goal is tighter / brighter / upper-mid-forward Marshall JCM800 2203-style Drive behavior without making the model TriAmp-like or changing volume alone. No JC-120 / Twin / AC30 / Rockerverb / TriAmp table entry changed, and no `Distortion.hs` / `Overdrive.hs` / `Compressor.hs` / `Pipeline.hs` / `LowPassFir.hs` / GUI / HDMI / Pmod RTL / block-design source was edited. No helper, helper swap, cascade, IIR, register, `mulU8`, or `mulU12` was added. Clash VHDL was regenerated, the Vivado bitstream was rebuilt, and the build completed with `write_bitstream completed successfully` and `0 Errors`. Routed timing: WNS `-8.204 ns`, TNS `-9300.746 ns`, WHS `+0.034 ns`, THS `0.000 ns`; design summary failing endpoints `3284 / 60261`, main `clk_fpga_0` setup group `2229 / 52745`, worst path `ARG__17/CLK -> ds1_5_reg[1032]/D`. Utilization: LUT `19836`, FF `22174`, BRAM `6`, DSP `83`. bit/hwh md5 are `70b5dc7d972510c26fbb3b1014aa06eb` / `dc42290dc7fb46d7486068cc1d11032a`. Python py_compile, 91 unittest cases, `tests/test_overlay_controls.py`, deploy-time board md5 checks, `AudioLabOverlay(download=True)`, ADC HPF True, MODE 3 mute, and `scripts/diagnose_pmod_loopback.py` all passed. The self-loopback smoke produced no QUANT! / STAIR! indicators and CLIP_COUNT stayed clean, but remains only a structural smoke check. On bench, all_off bypass was reported clean; after correcting the Pmod MODE register offset (`0x28`) and the amp GPIO address (`axi_gpio_amp` at `0x43C90000`), JCM800 Drive mode was auditioned with Amp ON / model 4 / gain max, and the user answered **Adopt & merge**. D67 is now the deployed source-control baseline; D66 is the immediate previous baseline and D62 remains the deeper rollback reference.

Superseded D66 note (previous baseline; retained for history): **2026-05-24 (D66 DS-1-only asymSoftClip knee retune accepted and deployed):** Branch `feature/ds1-only-asymsoftclip-retune` retuned ONLY the existing DS-1 `asymSoftClip` knees in `hw/ip/clash/src/AudioLab/Effects/Distortion.hs`: `kneeP` `2_400_000 -> 1_900_000`, `kneeN` `2_000_000 -> 1_900_000`. This made DS-1 fully symmetric and harder-edged while preserving the existing helper topology. No TS9 / RAT / Fuzz Face / Big Muff / Metal / clean boost / Overdrive / Amp / Compressor / Pipeline / LowPassFir / GUI / HDMI / Pmod RTL / block design source was edited. `asymSoftClip` call count remained `3`, `asymHardClip` remained `0`, and `mulU8` / `mulU12` counts remained `13` / `8`. Build / deploy / self-loopback smoke passed; routed timing was WNS `-8.016 ns`, TNS `-9648.033 ns`, WHS `+0.051 ns`, THS `0.000 ns`, LUT `19712`, FF `22160`, BRAM `6`, DSP `83`, bit/hwh md5 `52f0e9937993dca11272d561f6cf6b32` / `d75d38394a529ac3524e0a64f73bcd34`. D66 was superseded by D67.

Superseded D65 comparison note (diagnostic-only; retained for history): **2026-05-24 (Pmod I2S2 self-loopback diagnostic: D62 vs reproduced D64 A/B comparison -- both PASS the bit-pattern checks; D64 audible bit-crusher cannot be reproduced under cable-loop self-test conditions; PYNQ restored to D62 baseline; no D64 source / VHDL / bit / hwh committed):** Per a follow-up request after the initial D62-only diagnostic, the D64 5-constant retune (TS9 `kneeN` 2_500_000 -> 2_700_000, DS-1 `kneeP` 2_400_000 -> 2_200_000 + `kneeN` 2_000_000 -> 2_100_000, Fuzz Face `kneeP` 1_900_000 -> 2_000_000 + `kneeN` 1_400_000 -> 1_200_000) was temporarily restored, the Clash + Vivado bitstream were rebuilt (logical Vivado outcome matched the original D64 exactly: WNS `-7.903 ns`, DSP `83`, BRAM `6`; fresh bit md5 `0c31cf02db2011102bf07c3219264043` differs from the original D64 `ea647168...` only in bitstream metadata timestamps), deployed to PYNQ-Z2, put through the same `scripts/diagnose_pmod_loopback.py` self-loopback diagnostic, then immediately reverted to D62 and the diagnostic re-run to confirm restoration. **The cable-loop self-test cannot distinguish D62 from D64**: Phase 1 baseline peakL identical (MODE 0 1.18M on both, MODE 2 cable-loop feedback 7.14M vs 7.26M -- within noise), Phase 5 / Phase B per-cell `uniq1k` and `max_run` statistically indistinguishable (both bits: max_run = 2, uniq1k near 1000 every cell, zero QUANT! / STAIR! flags). The only divergence is the Phase 3 DMA-capture peak which is a route-change transient at capture start (steady-state RMS is comparable). **Implication**: the audible "bit-crusher" / "HF noise" symptoms the user reported during the D64 bench audition cannot be reproduced under the cable-loop self-test conditions. They must require either (a) external-instrument input richer than the MM2S sine sweep, (b) the user's analog monitoring path, or (c) bypass-path P&R artifacts that stay below the `uniq1k` / `max_run` thresholds the script catches. The D58 / D59 / D60 / D61 v2 / D63 / D64 cumulative rule continues to apply: the self-loopback diagnostic is a useful structural-breakage smoke check (helper count, register count, AXIS misalignment, gross quantisation) but it is NOT a substitute for the bench ear when the symptom is subtle. After the comparison, the D64 retune was reverted, the Vivado outputs were rolled back, and the PYNQ board was put back on D62 baseline (bit/hwh md5 `349ebbe609ac15f58d8b676d2dedee94` / `3a90e966c5d76762b60ba3ab0e982685`, PL freshly programmed via `AudioLabOverlay(download=True)`; post-rollback Pmod mode 2 safe-clean smoke PASS FRAME_COUNT delta 144151, CLIP_COUNT 0, ADC HPF True, MUTE 3). **This commit ships only documentation updates**: `docs/ai_context/PMOD_LOOPBACK_DIAGNOSTIC.md` gains a "D62 vs D64 A/B" section, `docs/ai_context/DECISIONS.md` D65 gets a follow-up note, and this `CURRENT_STATE.md` latest-work entry. No D64 bit / hwh / VHDL / DSP source touched in git. Previous superseded entries about D65 (initial diagnostic, D62-only) and D64 / D63 / D62 / D61 / D60 / D59 / D58.2 follow below for historical reference.

Superseded D65 initial-diagnostic note (D62-only verification; superseded by the D62 vs D64 A/B comparison above): **2026-05-24 (Pmod I2S2 self-loopback diagnostic added; D62 baseline I2S / ADC / DAC / AXIS / DSP-pass-through path verified clean; no Vivado / DSP source change):** After the D63 / D64 bench rejections raised the question "is the I2S layer itself bit-crushing high frequencies?", a PYNQ-single Pmod OUT -> IN cable-loop diagnostic was run on the deployed D62 baseline. The diagnostic is committed as `scripts/diagnose_pmod_loopback.py`; the full procedure and verdict are documented in `docs/ai_context/PMOD_LOOPBACK_DIAGNOSTIC.md`. Phases 0 / 1 / 3 / 5 / B exercise every MODE of `pmod_i2s2_master.v` (TX_TONE / RTL loopback / DSP path / MUTE) plus the axis_switch route via `dma -> passthrough -> headphone` and `dma -> guitar_chain -> headphone`, with MM2S sine sweep 100 Hz..15 kHz at -30..-12 dBFS. The bit-crusher / quantisation indicators (`uniq1k` = unique sample values in first 1000 polls; `max_run` = longest run of identical consecutive samples) **passed in every cell**: every MODE 0/1/2/3 baseline, every sweep frequency, every level. No QUANT! or STAIR! flag triggered anywhere. MODE 0 1 kHz DMA-captured FFT was clean (single dominant peak, harmonics > 1000x below). MODE 2 default-route cable-loop feedback is the only "loud" reading and that is the previously-known closed-loop oscillation, not an I2S artifact. **Verdict: the deployed D62 I2S / ADC / DAC / AXIS / DSP-pass-through path is clean across 100 Hz..15 kHz at -30..-12 dBFS. The D63 / D64 "bit-crusher" / "HF noise" symptoms the user heard during those bench auditions were therefore build-specific Vivado P&R-induced artifacts (per the D58 / D59 / D60 / D61 / D62 / D63 / D64 cumulative engineering rule), not faults in the hardware path.** No bit / hwh / VHDL / Clash / DSP source touched in this commit; only the diagnostic script + documentation ship. The script can be re-run before any future deploy as a sanity check (it returns exit code 0 on PASS, 1 on any quantisation flag). Previous superseded entries about D64 / D63 / D62 / D61 / D60 / D59 / D58.2 follow below for historical reference.

Superseded D64 attempt note (audio-rejected on bench; source reverted; retained for history): **2026-05-24 (D64 distortion-wide asymSoftClip knee-only retune rejected on bench for bypass-time HF regression; PYNQ board restored to D62 baseline; D64 source / VHDL / bit / hwh reverted in this commit; distortion retune research note retained; revised engineering rule):** D64 applied the strictest possible interpretation of the D58 / D59 / D60 / D61 / D62 / D63 cumulative lesson: change ONLY the `kneeP` / `kneeN` numeric constants of the three existing `asymSoftClip` invocations in `hw/ip/clash/src/AudioLab/Effects/Distortion.hs`, with no helper added, no helper swap, no helper cascade, no `Pipeline.hs` change, no DSP / BRAM / register count change, no `mulU8` / `mulU12` invocation count change. The actual edit was 5 numeric constants (TS9 `kneeN` 2_500_000 -> 2_700_000; DS-1 `kneeP` 2_400_000 -> 2_200_000, `kneeN` 2_000_000 -> 2_100_000; Fuzz Face `kneeP` 1_900_000 -> 2_000_000, `kneeN` 1_400_000 -> 1_200_000), with full per-pedal research grounded in ElectroSmash / stompboxelectronics references (kept on main in `docs/ai_context/DISTORTION_ASYMSOFTCLIP_RETUNE_RESEARCH.md`). Build was excellent: routed WNS `-7.903 ns` (+0.594 ns vs D62), WHS `+0.052 ns`, THS `0 ns`, failing endpoints `2038 / 52739`, Slice LUTs `19690` (-10 vs D62), Slice Registers `22304` (+24 vs D62), BRAM `6` (unchanged), DSPs `83` (unchanged). bit/hwh md5 `ea647168adda426d4d7d35656c7ca91f` / `a15147c3c5f832826f78c588c3a7551b` deployed 5-site. Deploy-time programmatic smoke PASS (FRAME_COUNT delta 144150, CLIP_COUNT 0, ADC HPF True, MUTE 3). **However bench audition revealed a NEW bypass HF regression vs D62 even though the change was 100% pure-numeric within already-existing helper invocations.** Per-pedal audition was a mixed picture: TS9 sounded more symmetric and smoother as intended (OK), Fuzz Face sounded clearly more asymmetric / broken-up as intended (OK), DS-1 moved in the right direction but the user wanted "harder / more symmetric" still. The bypass regression alone made the build non-deployable. **Revised engineering rule (load-bearing)**: D62 demonstrated that constants-only change CAN be safe -- but D64 demonstrates that this is only true at *very small* edit scope. The D62 "safe" outcome (3 constants in one Overdrive model) is now understood to have been load-bearing in itself; D64 touched 5 constants across 3 distortion pedals and triggered a P&R regression. The new rule is **"one model at a time, and as few constants as possible per build"**: TS9 / DS-1 / Fuzz Face should each be retuned in their own separate Vivado rebuild + bench cycle, not all at once. PYNQ rolled back to D62 (bit/hwh md5 `349ebbe609ac15f58d8b676d2dedee94` / `3a90e966c5d76762b60ba3ab0e982685`); post-rollback Pmod mode 2 safe-clean smoke PASS (FRAME_COUNT delta 144151, CLIP_COUNT 0, ADC HPF True, MUTE 3). **This commit also reverts `hw/ip/clash/src/AudioLab/Effects/Distortion.hs` and the regenerated Clash artifacts under `hw/ip/clash/vhdl/LowPassFir/` back to D62 so the source tree matches the deployed bit. No D64 bit / hwh is committed.** Only `docs/ai_context/DISTORTION_ASYMSOFTCLIP_RETUNE_RESEARCH.md` (new) plus updates to `CURRENT_STATE.md`, `DECISIONS.md`, and `TIMING_AND_FPGA_NOTES.md` ship in this commit. **Rule for next distortion retake**: ONE pedal at a time (e.g. TS9-only knee retune as a standalone build, then Fuzz Face as a separate build). Both directions (TS9 more-symmetric, Fuzz Face more-asymmetric) are bench-validated as audibly improvements in the D64 audition itself; the bypass regression was triggered by the *combination* of multiple simultaneous edits in the same build, not by any individual knee change. Previous superseded entries about D63 / D62 / D61 / D60 / D59 / D58.2 follow below for historical reference.

Superseded D63 attempt note (audio-rejected on bench; source reverted; retained for history): **2026-05-24 (D63 DS-1 Distortion fidelity attempt rejected on bench for bypass-time bit-crusher-like artifact + leak to other distortion pedals; PYNQ board restored to D62 baseline; D63 source / VHDL / bit / hwh reverted in this commit; DS-1 research note retained):** D63 aimed to improve the DS-1 distortion pedal stage by reproducing the real DS-1's documented two-saturation cascade: (a) Q2 transistor-booster soft asymmetric pre-clip emulation, (b) op-amp output back-to-back diode HARD SYMMETRIC clip emulation, (c) drive-coefficient bump in `ds1MulFrame` (`drive * 8 -> drive * 10`), (d) `ds1ToneFrame` alpha-base narrow (`96 -> 80`) for the always-on 7.2 kHz feedback-LPF behaviour. Research source-by-source notes are committed to `docs/ai_context/DS1_MODEL_RESEARCH.md` (kept on main as the lasting deliverable of the attempt -- the next DS-1 retake does not have to repeat the ElectroSmash / sonicfields / GuitarPedalsVisualized / electric-safari / MUMT 618 / Boss Articles literature search). Build + deploy + programmatic smoke all passed: routed WNS `-8.426 ns` (improved by `+0.071 ns` vs D62 `-8.497 ns`), TNS `-6452.238 ns`, WHS `+0.051 ns`, THS `0 ns`, failing endpoints `2127 / 52725`, Slice LUTs `19755` (+55 vs D62), Slice Registers `22195` (-85 vs D62), BRAM `6` (unchanged), **DSPs `83` (unchanged from D62)**. bit/hwh md5 `b9bb64260d0c9b2ed86f9543a8392359` / `6fb1210f60970118d80993035460342d` deployed 5-site. Deploy-time programmatic smoke PASS (Pmod mode 2 safe-clean: FRAME_COUNT delta `144154`, CLIP_COUNT delta `0`, ADC HPF True, MUTE 3). However on-bench audition (CLAUDE.md spec connection -- external source -> Pmod IN, Pmod OUT -> monitor, no Pmod direct loopback) FAILED on all four acceptance criteria: **(1) bypass all_off produced a bit-crusher-like artifact -- a new failure mode unlike the HF saturation noise D58 / D59 / D60 / D61 v2 produced, suggesting AXIS-stream sample quantisation / glitching rather than HF leakage; (2) DS-1 D20 / D50 / D80 sweep did NOT produce the intended light-crunch -> canonical-hard-clip -> heavy-square-ish progression; (3) DS-1 tone 30 / 50 / 70 was indistinguishable -- the sound was too anomalous to discriminate by ear; (4) RAT / TS9 / BD-2 sounded different from D62, i.e. the change LEAKED into other distortion pedals and the entire Overdrive section even though the source edits were confined to `ds1*Frame` only**. **Load-bearing engineering lesson**: D63 categorised the `asymSoftClip -> asymHardClip` cascade in `ds1ClipFrame` as a "zero-DSP helper swap, safe like D62's pure-constant retune". That categorisation is wrong. **Adding a second clip-helper invocation inside a single existing stage is a structural change in the Vivado-P&R sense**, even when DSP48E1 count, BRAM count, register count, and WNS all look fine. The cascade increases combinational depth and fan-out inside the stage; Vivado's downstream placement / routing of unrelated nets shifted enough to leak a perceptible audio artifact onto the safe-bypass path AND onto the other distortion pedals that share the same axis_switch path. The D58 / D59 / D60 / D61 v2 / D63 sample now strongly supports the stricter rule: **any change inside `LowPassFir.hs` or any DSP-effect module that adds *combinational logic* (not just constants in a LUT) MUST be assumed structural until proven otherwise by bench audition.** PYNQ rolled back to D62 (bit/hwh md5 `349ebbe609ac15f58d8b676d2dedee94` / `3a90e966c5d76762b60ba3ab0e982685`) via `git checkout HEAD -- hw/Pynq-Z2/bitstreams/{audio_lab.bit,audio_lab.hwh}` + `scripts/deploy_to_pynq.sh` + `AudioLabOverlay(download=True)`; post-rollback Pmod mode 2 safe-clean smoke PASS (FRAME_COUNT delta `144153`, CLIP_COUNT delta `0`, ADC HPF True, MUTE 3). **This commit also reverts `hw/ip/clash/src/AudioLab/Effects/Distortion.hs` and the regenerated Clash artifacts under `hw/ip/clash/vhdl/LowPassFir/` back to D62 so the source tree matches the deployed bit. No D63 bit / hwh is committed.** Only `docs/ai_context/DS1_MODEL_RESEARCH.md` (new) plus updates to `CURRENT_STATE.md`, `DECISIONS.md`, and `TIMING_AND_FPGA_NOTES.md` ship in this commit. **Rule for the next DS-1 retake (D63.1 or later)**: (a) at most ONE clip-helper invocation per existing stage (no cascade); (b) pure constant edits in the existing per-pedal tables and `if model == X then constA else constB` style mux on the *existing* helper invocation -- never an *additional* helper invocation; (c) if a coefficient-only `asymHardClip` swap (no cascade, just replacing the existing `asymSoftClip` call with `asymHardClip` keeping the knee constants) ALSO triggers the bypass artifact, DS-1 fidelity work in this section is permanently limited to per-knee constant retunes within the existing `asymSoftClip` invocation; (d) the Big Muff style ~500 Hz mid-scoop is explicitly NOT achievable inside this constraint and is deferred indefinitely until the bypass-path P&R sensitivity is better understood at the synthesis level. Previous superseded entries about D62 / D61 / D60 / D59 / D58.2 follow below for historical reference.

Superseded D62 attempt note (accepted on bench; baseline; retained for history): **2026-05-24 (D62 BD-2 Overdrive coefficient-only retune accepted on bench; bypass clean; D62 bit/hwh deployed):** Following the D61 v1 / v2 bench rejections, D62 applied the rule from `DECISIONS.md` D61 -- *no new register stage in `Pipeline.hs`, no new `mulU8` / `mulU12` on the OD path, BD-2 differentiation must come from per-model constant entries only*. The actual change is exactly three numeric edits in `Overdrive.hs` at `model == 2`: `odDriveK 2` 6 -> 7 (matches OCD's drive ceiling per the documented two-cascaded ~40 dB op-amp character), `odKneeP 2` 3_000_000 -> 2_400_000 (early-onset soft clip per the PedalPCB / Chuck D. Bones breadboard measurement that BD-2 has audible breakup well below mid-drive, not "transparent" as the prior value implied), and `odKneeN 2` 2_700_000 -> 1_900_000 (P/N gap widened from 300k to 500k -- the most pronounced even-harmonic asymmetry in the six-model lineup, matching the discrete-op-amp single-supply rail offset documented in source [1]). `odSafetyKnee 2` stays at 3_400_000. **Zero structural change**: no new arithmetic operator, no new register, no `Pipeline.hs` edit. Clash regen + Vivado batch build PASS (`write_bitstream completed successfully`, 0 Errors). Routed WNS `-8.497 ns` (vs D58.2 `-8.495 ns`, delta -0.002 ns -- noise floor, essentially identical), TNS `-5876.740 ns` (improved over D58.2's `-9052.753`), WHS `+0.053 ns`, THS `0 ns`, failing setup endpoints `2107 / 52730` (better than D58.2's `3224 / 60227`). Utilization: Slice LUTs `19700` (-13 vs D58.2's `19713`), Slice Registers `22280` (+170 vs D58.2's `22110`), BRAM `6` (unchanged), **DSPs `83` (unchanged from D58.2)**. The near-zero WNS delta is the load-bearing signal that the Vivado P&R outcome stays very close to D58.2's placement -- which D58 / D59 / D60 / D61 v2 collectively proved is the prerequisite for keeping the bypass path clean. bit/hwh md5 `349ebbe609ac15f58d8b676d2dedee94` / `3a90e966c5d76762b60ba3ab0e982685` deployed 5-site to PYNQ-Z2 192.168.1.9 via `scripts/deploy_to_pynq.sh`. Deploy-time programmatic smoke PASS (Pmod mode 2 safe-clean 3 s: FRAME_COUNT delta `144150` = exact 48 kHz cadence, CLIP_COUNT delta `0`, ADC HPF True, VERSION `0x00480001`, MUTE 3 readback). On-bench audition cycle (CLAUDE.md spec connection, external source -> Pmod IN, Pmod OUT -> monitor, no direct loopback) 10 cases x 15 s: **bypass all_off was as quiet as D58.2 by ear (the D58/D59/D60/D61 v2 class of bypass HF saturation noise did NOT reappear -- pure-constant-only changes do not trigger the artifact), BD-2 G20 / G50 / G80 audibly progressed with earlier-onset clip and stronger even-harmonic asymmetry than the D58.2 BD-2 (the D62 target character), and TS9 / OD-1 / Centaur sounded identical to D58.2 (BD-2-only edit, byte-exact preserved for the other five models)**. D62 is accepted; bit/hwh and source ship in this commit and become the new deployed baseline. `docs/ai_context/BD2_MODEL_RESEARCH.md` gains a "D62" section that records the load-bearing rationale per coefficient so the next BD-2 attempt has a reference point. **Confirmed by this commit: the BD-2 fidelity goal is reachable inside the D61 rule (constants-only, no Pipeline change), and D58 / D59 / D60 / D61 v2 were not "Vivado P&R is hopeless" but "Vivado P&R is unforgiving of structural changes; constant changes are safe".**

Superseded D61 attempt note (audio-rejected on bench; source reverted; retained for history): **2026-05-24 (D61 BD-2 Overdrive model fidelity rejected on bench for bypass-time high-frequency saturation noise; PYNQ board restored to D58.2 baseline; D61 source reverted in this commit; BD-2 research note retained):** The D61 attempt aimed to improve the Overdrive `BOSS / BD-2` model (index 2) by reproducing the pedal's documented two-cascaded-discrete-op-amp character: ~700 Hz pre-clip HPF, ~2..3 kHz upper-mid emphasis, first-stage mild asymmetric soft clip, ~5 kHz post-clip fizz guard. Research source-by-source notes were committed to `docs/ai_context/BD2_MODEL_RESEARCH.md` (kept on main as the lasting deliverable of the attempt). Two builds were taken to the bench, both audio-rejected. **D61 v1 (DSP 88, +5 vs D58.2)** used `onePoleU8` for the BD-2 pre/post one-pole IIRs (two `mulU8` each) and one `mulU8` for the upper-mid emphasis; routed WNS improved by +0.604 ns vs D58.2 but the DSP count delta put it in the same risk class as D58 (DSP 83 -> 87 -> bypass regression), so v1 was not even bench-listened. **D61 v2 (DSP 83, same as D58.2)** rewrote the same IIRs and the emphasis as shift-only leaky-integrator expressions (`y = prev + ((x - prev) >> N)`) plus a constant-LUT mux on the existing `asymSoftClip` in the boost stage, so no new DSP48E1 was introduced; routed WNS improved by +0.412 ns vs D58.2. v2 deploy-time programmatic smoke PASSed across the full audition cycle (FRAME_COUNT delta ~480k for 10 s, CLIP_COUNT delta = 0 for every case, no Python exceptions, GUI / LCD healthy). **BD-2 character itself was confirmed audibly correct**: G20 / G50 / G80 sweep audibly progressed from edge-of-breakup through canonical BD-2 overdrive to fuzzy/splatty, tone 30 / 50 / 70 produced the documented dark/flat/bright behaviour with no ice-pick at tone 70, and TS9 / OD-1 / Centaur references sounded identical to D58.2 (no leak to other models). However safe-bypass (every `effect_on = False`, Pmod mode 2 ADC -> DSP -> DAC) was **clearly noisier than D58.2 on the same A/B** — the same D58 / D59 / D60 class of Vivado P&R-induced bypass-path artifact that the macroscopic timing summary, CLIP_COUNT, FRAME_COUNT, and the rest of the programmatic smoke do not flag. Since a guitar pedal that adds noise on bypass is unacceptable regardless of how good the engaged tone is, D61 v2 was rejected. PYNQ rolled back to D58.2 (bit/hwh md5 `1c9071b5f2e1eec63ef6abbcfcacbf02` / `21c1ca7a6ddd5c26fd39f8746abe28d8`) via `git checkout HEAD -- hw/Pynq-Z2/bitstreams/{audio_lab.bit,audio_lab.hwh}` + `scripts/deploy_to_pynq.sh` + `AudioLabOverlay(download=True)`; post-rollback Pmod mode 2 safe-clean smoke PASS (FRAME_COUNT delta 144150, CLIP_COUNT delta 0, ADC HPF True, VERSION 0x00480001, MUTE 3). **This commit also reverts `hw/ip/clash/src/AudioLab/Effects/Overdrive.hs`, `hw/ip/clash/src/AudioLab/Pipeline.hs`, the regenerated Clash artifacts under `hw/ip/clash/vhdl/LowPassFir/`, and the local bit/hwh under `hw/Pynq-Z2/bitstreams/` back to D58.2 so the source tree matches the deployed bit.** Only `docs/ai_context/BD2_MODEL_RESEARCH.md` (new) plus updates to `CURRENT_STATE.md`, `DECISIONS.md`, and `TIMING_AND_FPGA_NOTES.md` ship in this commit. **Rule for the next BD-2 attempt: keep the existing 6-stage Overdrive pipeline byte-for-byte (no new register stage in `Pipeline.hs`, no new feedback state register); restrict BD-2 differentiation to the per-model constant-LUT entries already in `Overdrive.hs` (`odDriveK` / `odKneeP` / `odKneeN` / `odSafetyKnee`) and, if helpful, add new per-model constant tables that feed *existing* arithmetic operators in the same six stages. Any change that increases DSP48E1 count or adds a register feedback path inside `Pipeline.hs` must be assumed to leak into the bypass path until bench-listened.** Previous superseded entries about D60 / D59 / D58.2 follow below for historical reference.

Superseded D60 attempt note (audio-rejected on bench; source reverted; retained for history): **2026-05-24 (D60 audio-rejected on bench for bypass-time high-frequency saturation noise; PYNQ board restored to D58.2 baseline; D60 source reverted in this commit):** The D60 Compressor target-gain split (control-only, no full-`Frame` carry; built on branch `wns-compressor-gain-pipeline`) was deployed to PYNQ-Z2 192.168.1.9 for a deliberate audio-listening check. Deploy procedure: `git checkout` of the D60 bit/hwh files into the work tree, `scripts/deploy_to_pynq.sh` mirrored the artifacts to all four board copies (md5 `078f39c78991f1b36e6bfd1806b830a5` / `48160ae4acdf3abb9d1abf14dd65cc6d` everywhere), the user cold-power-cycled the PYNQ-Z2, then `AudioLabOverlay(download=True)` was called explicitly to force a fresh PL program (`PL.timestamp` confirmed re-program). Deploy-time programmatic smoke PASSed: `ADC HPF True`, Pmod mode 2 readback `2`, `FRAME_COUNT delta = 144148..144154` across `all_off` / `comp_on_mild` / `comp_on_stronger` / `comp_off_again` 3 s windows, `CLIP_COUNT delta = 0` in every window, `set_compressor_settings(threshold/ratio/response/makeup/enabled)` readback consistent, GUI keep-mode + dsp-mode 20 s holds clean with `live=ON apply=OK` and no Python exceptions, LCD compact-v2 rendered correctly (rgb2dvi PLL re-locked cleanly post cold start), final mute=3 confirmed. **On-bench audio verification by ear FAILED: high-frequency saturation noise was audible even in safe-bypass (all `effect_on = False`, Pmod mode 2 ADC -> DSP -> DAC).** This is the same class of regression as D58 (`feature/amp-drive-mode-balanced-gain`) and D59 — a Vivado P&R-induced bypass-path artifact that the macroscopic timing summary and `CLIP_COUNT` do not flag, and that listening on safe bypass is the only known way to detect. PYNQ board was rolled back to D58.2 (bit/hwh md5 `1c9071b5f2e1eec63ef6abbcfcacbf02` / `21c1ca7a6ddd5c26fd39f8746abe28d8`) via `git checkout HEAD -- hw/Pynq-Z2/bitstreams/{audio_lab.bit,audio_lab.hwh}` + `scripts/deploy_to_pynq.sh` + explicit `AudioLabOverlay(download=True)` to force a fresh PL program (`PL.timestamp` updated); post-rollback Pmod mode 2 safe-clean smoke PASSed (`FRAME_COUNT delta = 144153`, `CLIP_COUNT delta = 0`, `ADC HPF True`, `VERSION 0x00480001`, final mute=3). **This commit also reverts `hw/ip/clash/src/AudioLab/Effects/Compressor.hs`, `hw/ip/clash/src/AudioLab/Pipeline.hs`, and the regenerated Clash artifacts under `hw/ip/clash/vhdl/LowPassFir/` back to the D58.2 baseline so the source tree matches the deployed bit.** D60 synthesis / timing record (WNS `-8.300 ns`, `+0.195 ns` better than D58.2; DSP `83`, BRAM `6`; local bit/hwh md5 `078f39c7...` / `48160ae4...`) is preserved in `DECISIONS.md` D60 and `TIMING_AND_FPGA_NOTES.md` so the attempt remains discoverable in history. **Both D59 (full-`Frame` carry through the target pipeline) and D60 (control-only split, audio frame left on the original `compLevelPipe -> compApplyPipe` path) are now audio-rejected for the same class of Vivado P&R artifact in the safe-bypass path.** Any future Compressor target-pipeline rework MUST treat a bench-listening change in the safe-bypass path as a blocking signal regardless of CLIP_COUNT / FRAME_COUNT / WNS / TNS / failing-endpoint count -- the bench ear is the only sensor that has caught this class of regression so far.

Superseded D60 attempt note (audio-rejected; source reverted; retained for history): **2026-05-23 (D60 Compressor target-gain split, control-only retake after D59 audio regression):** D60 kept the Compressor gain-calculation split without carrying the audio frame through the target path. `Compressor.hs` had `compTargetStage1` for threshold / soft-threshold comparison, excess calculation, and excess clamp, `compTargetStage2` for `excessU12 * ratioByte`, reduction shift/clamp, and target-gain calculation, and `compGainNext` for the existing smoothing/register update. `Pipeline.hs` registered only the control/target path (`compTargetStage1Pipe`, `compTargetPipe`); `compApplyPipe` still consumed the original `compLevelPipe` audio data path. No Compressor coefficients, threshold/ratio/response/makeup semantics, effect order, GPIO map, `topEntity` ports, DS-1 / Distortion, `Amp.hs`, GUI, Pmod I2S2, `block_design.tcl`, or Vivado strategy changed. Clash -> VHDL -> IP repackage -> Vivado full build PASS. D60 local timing: WNS `-8.300 ns`, TNS `-8836.632 ns`, failing setup endpoints `3181 / 60265`, WHS `+0.043 ns`, THS `0.000 ns`; DSP count stays `83`, BRAM stays `6`. Local bit/hwh md5 were `078f39c78991f1b36e6bfd1806b830a5` / `48160ae4acdf3abb9d1abf14dd65cc6d`. **D60 was subsequently deployed to PYNQ-Z2 and audio-rejected for bypass-time high-frequency saturation noise; see Latest work above for the rollback record.**

Superseded D59 note (audio-rejected; retained for history): **2026-05-23 (D59 Compressor gain target path pipeline split for WNS):** branch `wns-compressor-gain-pipeline` splits only the Compressor gain-calculation path. `Compressor.hs` now separates target calculation into `compTargetStage1` (threshold / soft-threshold comparison, excess calculation, excess clamp), `compTargetStage2` (`excessU12 * ratioByte`, reduction shift/clamp, target-gain calculation), and the existing `compGainNext` smoothing/register update. `Pipeline.hs` registers those target stages and carries the `Frame` through `compTargetPipe` / `compGainFramePipe` before `compApplyPipe`, preserving compressor-local control/frame alignment while adding the allowed sample-scale gain reaction latency. No Compressor coefficients, threshold/ratio/response/makeup semantics, effect order, GPIO map, `topEntity` ports, DS-1 / Distortion, `Amp.hs`, GUI, Pmod I2S2, `block_design.tcl`, or Vivado strategy changed. Clash -> VHDL -> IP repackage -> Vivado full build PASS; WNS improves vs D58.2 from `-8.495 ns` to `-8.138 ns` (`+0.357 ns`), TNS improves from `-9052.753 ns` to `-8756.266 ns`, failing setup endpoints drop `3224 / 60227 -> 2922 / 60321`, and hold remains clean (`WHS +0.052 ns`, `THS 0.000 ns`). DSP count stays `83`, BRAM stays `6`; registers rise by 254 as expected from the new pipeline registers. The top routed critical path has moved off Compressor and is now DS-1-side `ARG__7__2` -> `ds1_5_reg[...]`, which this task intentionally did not touch. bit/hwh md5 `a42358803798acc1e63ef5d4abd45b33` / `1ddd377d077401ccf60a9096d319ed52` deployed to PYNQ-Z2 192.168.1.9, with all five board copies md5-matching. Programmatic smoke PASS: `AudioLabOverlay()` loads the new bit, `ADC HPF True`, `R19_ADC_CONTROL 0x23`, `axi_gpio_compressor` present, compressor enable/disable word readback works, Pmod I2S2 mode 2 readback `2`, safe-clean 3 s `FRAME_COUNT delta = 144150`, `CLIP_COUNT delta = 0`, and final mode 3 mute readback `3`. `DECISIONS.md` D59 and `TIMING_AND_FPGA_NOTES.md` carry the timing/deploy record.

Superseded D58.2 note (accepted before D62, retained for history): **2026-05-23 (D58.2 Balanced Amp Drive Mode saturation -- fixed-scalar retake after the D58 bit caused a P&R-induced bypass regression; Vivado rebuild + deploy + programmatic smoke PASS, on-bench audio verification pending):** D58's `ch * factor` Drive-mode knee deltas added four DSP48E1 multipliers (DSP count `83 -> 87`) and the resulting Vivado P&R shift introduced an audible high-frequency saturation noise on the ADC -> DAC bypass path that the user heard even with Amp OFF and full safe bypass; the D58 bit (`feature/amp-drive-mode-balanced-gain`, commit `797467c`) was rolled back on the PYNQ to the D55 bit (sha `8df39b06...` / hwh `9fb470c7...`) to restore clean audio while keeping the D58 source commit on its branch for reference. D58.2 picks the same coefficient targets but re-shapes them so they cost no extra DSP: `ampDrivePosDelta` / `ampDriveNegDelta` switch back to the D55 `Unsigned 3 -> Signed 25` signature (per-model fixed scalars, no `ch` argument), with per-model values sized to approximate D58's first-stage `ch * factor` evaluated at each model's own `ampCharForModel` peak (JC-120 `13_000` / Twin `58_000` / AC30 `130_000` / Rockerverb `210_000` / JCM800 `264_000` / TriAmp Mk3 `336_000` for pos; `11_000` / `50_000` / `113_000` / `180_000` / `231_000` / `300_000` for neg). `ampSecondStageDriveBonus` keeps D58's `14..56` (simple per-model adder, no DSP), `ampPreLpfDriveDarken` keeps D58's `5..24` (simple per-model subtractor, no DSP). The `ampAsymClip` call sites revert to the D55 form (`ampDrivePosDelta modelIdx` -- no `ch` arg passed). D55 structure preserved verbatim everywhere else (six-model lineup, `ctrlD[7] = ampDriveMode` / `ctrlD[6:3] = 0` / `ctrlD[2:0] = ampModelIdx`, `softClipK 3_300_000 / 3_400_000` safety, second-stage `intensity = ampCharForModel idx >> 1`, six-entry `ampTrebleGain` / `presenceTrim`). D57's anti-patterns explicitly NOT adopted: no `ampInputDriveGainBonus`, no pre-clip push, no `ch * 5000+` knee multiplier, no full-intensity second-stage clip. Clash regenerated VHDL via `clash -package-id clash-prelude-1.8.1-...144c -isrc -fclash-hdldir /tmp/clash_d582 --vhdl src/LowPassFir.hs`; IP repackaged via `vivado -mode batch -source create_ip.tcl`. Vivado batch build PASS (`write_bitstream completed successfully`, 0 Errors). **DSP count back to `83 / 220 (37.73 %)` -- the same as D55 and four below D58's `87`**, which is the load-bearing metric for not retriggering the bypass-path P&R regression. WNS `-8.495 ns` vs D55 baseline `-8.231 ns` (regresses `0.264 ns`, still inside the historical `-7..-9 ns` deploy band and well above the `-9.5 ns` hard gate); WHS `+0.051 ns`; THS `0.000 ns` (hold clean); 3224 / 60227 failing setup endpoints (5.35 %). Utilization after place: Slice LUTs `19713` (`37.05 %`, -73 vs D55), Slice Registers `22110` (`20.78 %`, -50 vs D55), Block RAM Tile `6` (`4.29 %`, unchanged). bit/hwh `93f31348...` / `25991dc0...` deployed 5-site to PYNQ-Z2 192.168.1.9 (all five `/home/xilinx/.../bitstreams/`, `/usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams/`, `/usr/local/lib/python3.6/dist-packages/pynq/overlays/audio_lab/`, `/home/xilinx/jupyter_notebooks/audio_lab/bitstreams/`, `/home/xilinx/Audio-Lab-PYNQ/hw/Pynq-Z2/bitstreams/` sha-match the local build). Programmatic smoke PASS: `ADC HPF True`; six amp models `0..5` ctrlD readback OK across Clean + Drive (12 cases); Pmod I2S2 MODE writes `tone / loopback / dsp / mute` (0 / 1 / 2 / 3) all readback OK via `scripts/pmod_i2s2_mode.py`; **D58 regression guard -- safe bypass (`all effect_on = False`) + mode 2 DSP 3 s CLIP_COUNT delta `0` (FRAME_COUNT `+144150` -- exact 48 kHz cadence)**; Amp OFF (others default) 3 s CLIP_COUNT delta `0`; TriAmp Mk3 + Drive (full chain) 3 s CLIP_COUNT delta `0`; `scripts/run_encoder_hdmi_gui.py --live-apply --skip-rat --pmod-mode dsp` starts cleanly (`AudioLabOverlay loaded`, `HDMI backend started at 800x600`, `live=ON apply=OK`, no Python exceptions, initial render fires once on the signature change then idles per the dirty-flag policy). `python3 -m unittest -v tests.test_encoder_*` 91 tests PASS; `python3 tests/test_overlay_controls.py` PASS. **Audio verification by ear ("ブチブチしない", "Drive で D55 より歪む", "D57 より穏やか", "Amp OFF / safe bypass で D58 のような高音域飽和ノイズが消えた" -- the original D58 regression symptom) is pending the user's bench session.** GUI / `block_design.tcl` / HDMI timing / Encoder PL IP / Pmod I2S2 RTL / `GPIO_CONTROL_MAP` / `topEntity` ports untouched. Branch `feature/amp-drive-mode-balanced-gain-v2`. `DECISIONS.md` D58.2.**

Previous-pass header (D55 Amp Sim model set replaced with six researched voicings, Vivado rebuild kicked off): The legacy 4-model D52 lineup (`jc_clean` / `clean_combo` / `british_crunch` / `high_gain_stack`) is retired. Six inspired-by voicings replace it: `0 = JC-120` / `1 = Twin Reverb` / `2 = AC30` / `3 = Rockerverb` / `4 = JCM800` / `5 = TriAmp Mk3`. Research notes / source URLs / DSP coefficient rationale live in `docs/ai_context/AMP_MODEL_RESEARCH_D55.md`. `axi_gpio_amp_tone.ctrlD` widens the model field from 2 bits to 3 bits: `ctrlD[7] = ampDriveMode`, `ctrlD[6:3] = 0` reserved, `ctrlD[2:0] = ampModelIdx` (0..5 valid; 6..7 -> Clash safety fallback to JC-120). Python writer: `AudioLabOverlay.amp_model_drive_byte(idx, drive)` with `AMP_MODEL_IDX_MASK = 0x07` and `AMP_MODEL_IDX_MAX = 5`. Per-model voicing tables in `Amp.hs` (`ampModelDarken` / `ampPreLpfDriveDarken` / `ampSecondStageDriveBonus` / `ampDrivePosDelta` / `ampDriveNegDelta` / 6-entry `ampTrebleGain` case / 6-entry `presenceTrim` case) replace the single shared character byte so each model has its own clip / LPF / second-stage profile -- not just a volume difference. `softClipK` output safety preserved (`3_300_000` / `3_400_000`). The D54 Clean/Drive bit remains a real DSP branch and is per-model in D55 (different knee delta / preLPF darken / second-stage bonus on each voicing). Compact-v2 GUI / HDMI mirror / encoder runtime / three notebooks updated; legacy snake_case helper names (`mirror.jc_clean()` etc.) preserved as back-compat aliases that route onto the closest D55 voicing. tests updated; `python3 tests/test_overlay_controls.py` PASS, `python3 -m unittest -v tests.test_encoder_*` PASS (90 + 3 new D55 tests). Branch `feature/replace-amp-models-six-pack-researched`. `DECISIONS.md` D55. Vivado batch rebuild kicked off; deploy + on-board smoke pending the next session.**

Previous-pass header (D54 Amp Sim Clean/Drive becomes a real Clash DSP branch, Vivado rebuild + deploy): Retires the D53 in-band character byte shift. `axi_gpio_amp_tone.ctrlD` is now a two-field bit-pack: `ctrlD[7] = ampDriveMode` (0=Clean, 1=Drive), `ctrlD[6:2] = 0` reserved, `ctrlD[1:0] = ampModelIdx` (0..3). Python composer: `AudioLabOverlay.amp_model_drive_byte(amp_model_idx, amp_drive_mode)`. The Clash `Amp.hs` now reads the two fields independently (`ampModelIdxF` / `ampDriveModeF` / `ampCharForModel`) and adds real Drive-mode branches: `ampAsymClip` shrinks knees further (linear in the per-model character byte) and drops the negative-side post-knee shift from `>> 3` to `>> 2` in Drive mode; `ampPreLowpassFrame` adds `-12` to alpha; `ampSecondStageMultiplyFrame` adds `+24` to the second-stage gain coefficient. Output safety (`softClipK 3_300_000` / `3_400_000`) kept so clip_count stays bounded under Drive. No new GPIO, no address change, no `block_design.tcl` / HDMI / encoder / Pmod I2S2 change. Clash regenerated VHDL; Vivado batch rebuild produced new `audio_lab.bit` / `audio_lab.hwh` (deployed to PYNQ-Z2 192.168.1.9 with five-copy sync). Compact-v2 GUI / encoder runtime / HDMI mirror / D53 Notebooks all pass `amp_model_idx + amp_drive_mode` through unchanged. Branch `feature/amp-clean-drive-dsp-mode`. `DECISIONS.md` D54.**

Previous-pass header (D53 Amp Sim model-only character + binary DRV MODE, pure Python): Amp Sim の 8 個目ノブを連続 `CHAR` から 0/1 の `DRV MODE` に置き換え。character byte は `amp_model_idx` のみから決まるようになり (`AudioLabOverlay.amp_character_byte_for_model`)、`amp_drive_mode=1` の場合は同じ Clash `ampModelSel` バンド内で `+30` シフトする (M0:26→56 / M1:89→119 / M2:153→183 / M3:216→246)。`amp_drive_mode=0` は D52 以前と byte-for-byte 同一なので bitstream / Vivado / Clash 変更なし。`axi_gpio_amp_tone.ctrlD` のアドレス・ビット幅・block_design は不変。`set_guitar_effects(amp_model_idx=…, amp_drive_mode=0|1)` API、`AppState.amp_drive_mode` 永続フィールド、encoder 2 の binary 0/1 toggle、HDMI GUI の 0/1 表示、`PmodI2S2EffectControlOneCell.ipynb` / `GuitarPedalboardOneCell.ipynb` の DRV MODE Dropdown、レガシー state.json マイグレーション (>=50% → 1)、新規テスト (`test_compact_v2_encoder_state` / `test_encoder_ui_controller` / `test_encoder_effect_apply` / `test_overlay_controls`) で 0 失敗。 `amp_character` percent kwarg は chain preset / 旧 Notebook 経路のフォールバックとして残置 (`amp_model_idx` が None のときのみ採用)。 branch `feature/amp-model-only-drive-mode`. `DECISIONS.md` D53.**

Previous-pass header (Pmod I2S2 HDMI GUI one-cell Notebook, pure Python): added `audio_lab_pynq/notebooks/PmodI2S2HdmiGuiOneCell.ipynb` — single-cell ipywidgets UI that spawns `scripts/run_encoder_hdmi_gui.py --live-apply --skip-rat --pmod-mode dsp` as a sudo subprocess so the existing HDMI GUI + rotary encoders drive the Pmod I2S2 mode-2 audio path (Pmod Line In → ADC → AudioLab DSP → DAC → Pmod Line Out). The runner gained one new option `--pmod-mode {keep,tone,loopback,dsp,mute}` (default `keep`, no behaviour change for existing callers) that writes `pmod_status_0` MODE at startup and MODE=3 (mute) at shutdown so SIGTERM / Ctrl+C leaves the speakers silent. The Notebook does NOT load `AudioLabOverlay` in its kernel — Start / Stop / Panic-Mute are SIGTERM-only, and Set DSP / Refresh status / Panic-fallback shell out to a new minimal helper `scripts/pmod_i2s2_mode.py --mode … | --read | --clear` that attaches via `pynq.Overlay(... download=False)` (no codec reconfig, no bit re-download). No RTL, no Tcl, no XDC, no bit/hwh rebuild, no `block_design.tcl` / `LowPassFir.hs` / `topEntity` / HDMI / encoder / `GPIO_CONTROL_MAP` change. Existing Notebooks and the original runner CLI surface unchanged. Branch `feature/pmod-i2s2-hdmi-gui-notebook`.**

Previous-pass header (D51 sluggish-GUI / missed-tap fix, 2026-05-20):
**`EncoderUiController.handle_event` now consumes the HW `short_press` latch on Encoder 0 as a fallback for the BUTTON_STATE level-edge path, with a tick-local `_enc0_toggle_consumed_this_tick` flag preventing double-toggle when both fire in the same tick. The standalone runner (`scripts/run_encoder_hdmi_gui.py`) defaults moved to `--poll-hz-active 30 / --poll-hz-idle 10 / --max-render-fps 20 / --apply-interval-ms 50`. The `EncoderGuiSmoke.ipynb` constants follow, and the loop body switched from `enc.poll() + handle_events()` to `controller.tick(enc, timestamp=...)` so Encoder 1 hold-rotate + the new short_press fallback both work from the notebook. Encoder 1 / Encoder 2 button events (short / long / click / release) remain no-ops; only Encoder 0 short_press becomes a sanctioned overlay trigger. Test suite: 32 / 32 PASS in `tests/test_encoder_ui_controller.py` after replacing the D47 `..._short_press_event_is_noop` test with the new toggle / no-double-toggle pair; adjacent encoder suites PASS. No RTL, no bit/hwh rebuild, no Tcl, no XDC, no `block_design.tcl` / `LowPassFir.hs` / `topEntity` / HDMI / `GPIO_CONTROL_MAP` change. `DECISIONS.md` D51.**

Previous-pass header (D50 mode 2 RIGHT-to-LEFT mirror; branch `feature/pmod-i2s2-dsp-clean-fix`):
**`pmod_i2s2_master.v` now contains a 32-bit `mode2_right_snapshot` register indexed by `slot_idx`. It captures `dsp_dac_sdin_i` on each `bclk_fall_pre` during the RIGHT slot (bit_idx[5]==1) and the mode-2 branch of the DAC SDIN mux replays the buffer in BOTH the LEFT and RIGHT slots. Works around two `i2s_to_stream` IP bugs that surfaced after D49: (1) i2sIn's LEFT extraction does not match Pmod-master's deserializer (DMA captures of axis_li_tdata show LEFT spiking near `-0 dBFS` and a big DC offset while RIGHT matches Pmod-master exactly; bit-prevalence shows LEFT bits 16..21 set ~half as often as RIGHT), (2) i2sOut updates `so` on BCLK rising edges with no setup margin so the DAC can latch the OLD bit. With the mirror the user hears mode-2 mono = chain RIGHT output in both ears with ~21 us one-frame delay, audio is clean by ear and Overdrive A/B audibly engages/disengages. WNS `-7.985 ns` (improves D49 baseline `-8.521 ns` by `0.536 ns`), inside historical -7..-9 ns band; WHS `+0.050 ns`, THS `0 ns`. Mode 0 / 1 / 3 paths in `pmod_i2s2_master.v` unchanged, `block_design.tcl` / `GPIO_CONTROL_MAP` / `LowPassFir.hs` / `topEntity` / HDMI / encoder / notebooks / compact-v2 GUI all untouched. `DECISIONS.md` D50.**

Previous-pass header (D49 follow-up Pmod I2S2 effect notebook; branch `feature/pmod-i2s2-effect-notebook`):
**one-cell ipywidgets UI for the Pmod I2S2 mode-2 path added at `audio_lab_pynq/notebooks/PmodI2S2EffectControlOneCell.ipynb`. The notebook loads `AudioLabOverlay`, finds the `pmod_status_0/s_axi` MMIO from `ip_dict`, forces `cfg_mode = 2` (DSP), and exposes Noise Suppressor / Compressor / Overdrive / Distortion (pedal-mask) / Amp Sim / Cab IR / EQ / Reverb behind toggles, sliders, dropdowns, plus an `Apply effects` button, an `All effects off`, a `Safe clean (mode 2)`, a `Panic / mute (mode 3)`, and mode buttons (mode 0 / 1 / 2 / 3; mode 1 requires a confirm checkbox). Status panel shows VERSION / STATUS / FRAME_COUNT / NONZERO_COUNT / SDOUT_XCOUNT / CLIP_COUNT / LAST_LEFT/RIGHT / PEAK_ABS_*` plus a dBFS column. Pure Python / docs change -- no RTL, no Tcl, no XDC, no bit/hwh rebuild, no deploy. Existing notebooks unchanged.**

Previous-pass header (D49 Pmod I2S2 ADC → AudioLab DSP → DAC, 2026-05-20):
**Pmod I2S2 mode 2 added, the existing AudioLab DSP chain (`i2s_to_stream_0` → axis_data_fifo / Clash effects → `i2s_to_stream_0/so`) is now driven by the Pmod-generated BCLK / LRCK / SDATA tree. `cfg_mode = 0` (tone), `1` (loopback), `2` (DSP), `3` (mute) are all reachable from `scripts/test_pmod_i2s2.py --mode tone | loopback | dsp | mute`. Mode 2 requires `--confirm-dsp`; with the on-module Line Out ↔ Line In jumper disconnected and a low-volume Line In source, Overdrive / Distortion / Amp / Cab / Reverb audibly change the Line Out. ADAU1761 codec stays alive via I2C but its R18 bclk / T17 lrclk / F17 sdata_i inputs are now unloaded internally (the `bclk_1` / `lrclk_1` / `sdata_i_1` block-design nets were retargeted in `pmod_i2s2_integration.tcl`). G18 sdata_o still receives the DSP serial output for debug visibility. `block_design.tcl`, `GPIO_CONTROL_MAP`, `LowPassFir.hs`, `topEntity`, HDMI, encoder PL IP, compact-v2 GUI, notebooks, encoder runtime untouched. `DECISIONS.md` D49.**

Previous-pass header (D48 follow-up Pmod I2S2 mode 1 loopback verified, 2026-05-20):
**Pmod I2S2 mode 0 (TX tone + ADC probe) and mode 1 (ADC -> DAC direct loopback) are both reachable from `scripts/test_pmod_i2s2.py --mode tone | loopback`. The mode-1 path requires `--confirm-loopback` because the on-module Line Out ↔ Line In jumper plus the full-scale echo can feed back. `axi_pmod_i2s2_status.v` write FSM was reworked to the same shape `axi_encoder_input.v` uses (latch awaddr in the AW phase, commit in the W phase using the latched address), which fixed a same-cycle race where back-to-back MMIO writes (e.g. MODE=0 then CLEAR=1) committed the CLEAR write at the MODE address and silently flipped `cfg_mode_o`. At this D48-only point there was no DSP integration yet; D49 superseded it by routing Pmod I2S2 ADC into the AudioLab AXIS chain as current mode 2.**

Previous-pass header (D48 retire PCM5102/PCM1808 PMOD JB path, 2026-05-19):
**Digilent Pmod I2S2 (CS4344 DAC + CS5343 ADC) is now the only external audio module on PMOD JB. The PCM5102 / PCM1808 bring-up path is retired**
(`create_project.tcl` always sources `pmod_i2s2_integration.tcl`
+ `audio_lab_pmod_i2s2.xdc`; `pcm5102_dac_integration.tcl`,
`pcm1808_adc_integration.tcl`, the PCM5102 / PCM1808 RTL under
`hw/ip/pcm5102_*` / `hw/ip/pcm1808_*`, and `audio_lab_pcm.xdc`
remain in the repo as archival reference only — they are not
added to `sources_1` and not sourced. No env var switch any more.
On the bench Pmod I2S2 is plugged directly into PMOD JB, the
on-module Line Out ↔ Line In 3.5 mm jumper is in place for ADC
validation, and the PCM5102 / PCM1808 jumper wiring has been
physically removed. New RTL:
`hw/ip/pmod_i2s2/src/pmod_i2s2_master.v` (FPGA-master I2S engine,
12.288 MHz → 3.072 MHz BCLK → 48 kHz LRCK, 24-bit MSB-first /
32-bit slot I2S Philips, internal 1 kHz sine ROM for TX, I2S
deserializer + status counters for RX, build / runtime mode 0 = TX
tone + ADC probe, mode 1 = ADC → DAC loopback) and
`hw/ip/pmod_i2s2/src/axi_pmod_i2s2_status.v` (AXI-Lite slave at
`0x43D20000` exposing VERSION / STATUS / FRAME_COUNT /
NONZERO_COUNT / SDOUT_XCOUNT / CLIP_COUNT / LAST_LEFT /
LAST_RIGHT / PEAK_ABS_* / MODE / CLEAR). Pin map (LVCMOS33,
`audio_lab_pmod_i2s2.xdc`): JB1 W14 → DA MCLK, JB2 Y14 → DA LRCK,
JB3 T11 → DA SCLK, JB4 T10 → DA SDIN, JB7 V16 → AD MCLK (fanout),
JB8 W16 → AD LRCK (fanout), JB9 V12 → AD SCLK (fanout),
JB10 W13 → AD SDOUT (input). Python smoke:
`scripts/test_pmod_i2s2.py` + `scripts/pmod_i2s2_capture_probe.py`
poll the status block and print PASS / WARN / FAIL based on
frame_count / peak_abs movement. `block_design.tcl`,
`GPIO_CONTROL_MAP`, `LowPassFir.hs`, `topEntity`, HDMI timing,
encoder PL IP, compact-v2 GUI, notebooks, encoder runtime, and
ADAU1761 codec init are all untouched. At D48 time the ADAU path was still
separate; D49 superseded that by routing the active DSP source/clock tree to
Pmod I2S2 mode 2, and D50 made mode 2's DAC output mono by mirroring the
IP RIGHT slot into both channels via `mode2_right_snapshot`. ADAU remains
alive for I2C/HPF/debug visibility only. `DECISIONS.md` D48 / D49 / D50.)

Previous-pass header (D47 encoder button-state controls, 2026-05-19):
**short/long-press classifications dropped from `EncoderUiController`; Encoder 0 button-down rising edge is the only press-driven action**
(Encoder 0 rotate = effect select, Encoder 0 button-down edge =
`effect_on[selected_effect]` toggle (PRESET-like slots are no-op).
Encoder 1 rotate without hold = knob select, with hold = model-index
cycle (Overdrive→`overdrive_model_idx`, Distortion→`dist_model_idx`
(skip RAT bit2), Amp→`amp_model_idx`, Cab→`cab_model_idx`); non-model
effects ignore hold+rotate. Encoder 2 rotate = knob value;
standalone press on Encoder 1 / Encoder 2 = no-op. `model_select_mode`
is no longer a persistent toggle — it mirrors the live Encoder 1
press state for the renderer hint. The runner calls
`controller.tick(encoder)` which reads `BUTTON_STATE` + events each
loop. `scripts/run_encoder_hdmi_gui.py` updated; notebook
intentionally untouched (the Phase 7G notebook smoke was unstable in
the previous session). Pure Python / docs change — no bit/hwh, no
RTL/XDC, no Clash regenerate, no `block_design.tcl` edit.
`DECISIONS.md` D47.)

Previous-pass header (D46 Overdrive model select, 2026-05-18):
**generic Overdrive retired; six selectable models (TS9 / OD-1 / BD-2 / Jan Ray / OCD / CENTAUR) ride on overdrive_control.ctrlD[2:0] alongside the existing distTight high 5 bits**
(The single-character Overdrive stage was retired in favour of six
inspired-by models. The 3-bit `overdriveModel` field lives in
`axi_gpio_overdrive.ctrlD[2:0]` (= word bits 26..24); the existing
`distTight` byte keeps its top 5 bits and the two coexist on the same
GPIO byte because every Clash consumer of `distTight` already uses
`>> 3` or `>> 4` and discards the low 3 bits. The Clash side
(`AudioLab/Effects/Overdrive.hs`) keeps the same 6-stage register
pipeline — only the constants per stage become per-model lookups
(`odDriveK / odKneeP / odKneeN / odSafetyKnee`), each a 6-way case
mux of constants fed into one existing arithmetic op. No new register
stage, no new multiplier, no `topEntity` port change,
`block_design.tcl` untouched, no new GPIO. Python: new
`set_overdrive_model` / `set_overdrive_settings(model=...)` API plus
an `overdrive_model=` kwarg on `set_guitar_effects`; default = 0
(TS9), invalid values clamp to 0. Compact-v2 GUI:
`OVERDRIVE_MODELS` table added, `AppState.overdrive_model_idx`
persisted, the [model ▼] dropdown chip now draws for OVERDRIVE too,
`hit_test_compact_v2` recognises OD prev/next. Encoder runtime:
`EncoderUiController` cycles `overdrive_model_idx` instead of
aliasing onto `dist_model_idx`; `EncoderEffectApplier` forwards the
new field as `overdrive_model=` so encoder edits land on the GPIO.
HDMI state mirror: new
`audio_lab_pynq/hdmi_state/overdrives.py` model table, the mirror
tracks `current_overdrive_model`, and `dropdown_label_for(...)`
accepts an `overdrive_label=` kwarg so notebook-driven HDMI renders
also show the model name. `DECISIONS.md` D46.

Previous-pass header (D45 Pmod I2S2 planning, 2026-05-18):
**Digilent Pmod I2S2 ordered as a stable external I2S I/O reference; design / phase / pin plan committed**
(no RTL / XDC / Tcl / Vivado / bit / hwh / Python / Notebook change;
deployed bit is still the Phase 7D close-out `f502373` series. See
`PMOD_I2S2_INTEGRATION_PLAN.md` and `DECISIONS.md` D45.)

Previous-pass header (Phase 7D close-out):
**Phase 7D close-out: PCM1808 mux flipped back to ADAU pending hardware diagnosis; SCKI moved off JB1 onto JB8**
(Phase 7D first attempt picked PCM1808 as the build-time ADC source via
the `pcm1808_input_select` mux and put PCM1808 SCKI back on JB1
12.288 MHz. On the bench this re-broke PCM5102 (audible graininess
from JB1's MCLK cross-coupling to PCM5102 SCK that was nominally
tied to GND on the module, DECISIONS.md D40 / D42). The fix: PCM1808
SCKI moved to a dedicated `ext_pcm1808_sckie_o` port on PMOD JB8 /
W16 (driven directly from `clk_wiz_audio_ext/clk_out1` in
`pcm1808_adc_integration.tcl`), and `pcm5102_audio_out.v` keeps
`ext_audio_mclk_o = 1'b0` so JB1 stays low structurally regardless
of any physical SCK wiring. PCM5102 now plays inject-sine cleanly.
PCM1808's `capture-adc` returns pure zeros even with smartphone
line-in connected and mode straps confirmed at I2S Philips slave
(MD0=MD1=FMT=GND); the chip is alive enough to clock out I2S
frames (finger-touch test grounds EMI to 0) but does not encode
analog input -- suspect chip / analog-front-end damage from the
earlier 3.3V-on-VCC misconnection that brown-out'd the PMOD rail.
The deployed Phase 7D bit therefore flips the build-time mux
constant back to **CONST_VAL=0 (ADAU)** so the input path is the
known-good Phase 7E ADAU-mirror configuration; flipping back to
PCM1808 needs only `CONFIG.CONST_VAL {1}` in
`pcm1808_adc_integration.tcl` and a rebuild. User confirmed:
ADAU Line In -> AudioLab DSP -> PCM5102 line out works on the bench
(minor audio-quality nits remain, deferred). PCM5102 SCK still GND
(D40 / D42 preserved). Follow-up diagnosis concluded that the first
non-physical improvement should be a build variant / option that drives
`ext_pcm1808_sckie_o` low when PCM1808 is not the active ADC source,
because the deployed mux=ADAU bit still emits 12.288 MHz on JB8 and
that pin sits adjacent to PCM5102 DIN on JB7. The second follow-up is a
PCM5102 debug output mode (`processed audio` / digital silence /
`-18 dBFS` 1 kHz tone / ramp) to separate DSP, I2S, and analog-output
faults before any further audio-path edits. HDMI / encoder /
GPIO_CONTROL_MAP / LowPassFir untouched in this planning pass.
DECISIONS.md D41 / D42 / D43 / D44.

Previous-pass header (Phase 7D first attempt):
**PCM1808 external ADC inserted as default input source via a build-time wire mux**
(new RTL `hw/ip/pcm1808_adc_input/src/pcm1808_input_select.v` is a 2:1
combinational mux between the existing ADAU1761 `sdata_i` port and the
new PCM1808 DOUT input port `ext_adc_dout_i` (JB4 / T10). The mux
output drives the existing `i2s_to_stream_0/si` pin, so the AXIS DSP
chain is bit-for-bit unchanged regardless of which ADC source is
selected. `sel_external_i` is tied to `1'b1` by an `xlconstant` in
`hw/Pynq-Z2/pcm1808_adc_integration.tcl` -- Phase 7D bring-up default
is PCM1808; flipping the constant to 0 and rebuilding falls back to
ADAU1761. The Phase 7E SCK-low compensation in `pcm5102_audio_out.v`
is reverted: `ext_audio_mclk_o` again carries the 12.288 MHz from
`clk_wiz_audio_ext`, but JB1 now drives **PCM1808 SCKI** -- PCM5102
SCK is physically hard-tied to GND on the module per the new Phase 7D
board rewiring, so the wizard output no longer affects PCM5102.
Output side untouched: ADAU1761 DAC and PCM5102 DAC still receive
the same `i2s_to_stream_0/so` bitstream in parallel. HDMI / encoder
integration / GPIO_CONTROL_MAP / LowPassFir DSP all untouched. bit/
hwh rebuilt, deploy PASS, on-board smoke
(`scripts/test_pcm1808_adc_to_pcm5102.py`) PASS. Known caveat
(DECISIONS.md D41): PCM1808 SCKI is NOT bit-true synchronous to BCK
(same async-clocks risk that hit PCM5102 in Phase 7E); PCM1808 lacks
a PCM510x-style internal-PLL fallback, so if the bench shows audible
graininess the next step is to make the FPGA the I2S master.

Previous-pass header (Phase 7E follow-up):
**PCM5102 SCK tied LOW to fix MCLK/BCK async jitter**
(initial Phase 7E `9f21546` mirrored ADAU1761 I2S onto PMOD JB while keeping
the Phase 7C 12.288 MHz `clk_wiz_audio_ext` driving PCM5102 SCK. On the
real board the resulting audio had audible graininess / periodic jitter
because the 12.288 MHz MCLK comes from the PS 100 MHz PLL and BCK comes
from the ADAU1761 PLL -- the two are not bit-true synchronous and
PCM510x external-SCK locking drifted in and out. `pcm5102_audio_out.v`
now drives `ext_audio_mclk_o = 1'b0`; PCM510x therefore enters its
internal-SYSCLK mode and derives sysclk from BCK alone. The
`clk_wiz_audio_ext` instance is left in `pcm5102_dac_integration.tcl`
for future PCM1808 SCKI use, but its output has no consumer in this bit
and gets optimised away during synth. Timing improved (WNS -8.004 ns
vs the earlier -8.724 ns) because the unused 12.288 MHz domain was
pruned. ADAU1761 ADC / DSP chain / HDMI / encoder all still untouched.
`DECISIONS.md` D40.

Previous-pass header (Phase 7E initial bring-up, jitter known):
**Phase 7E PCM5102 now carries the existing AudioLab DSP output (parallel to ADAU1761 DAC)**
(new RTL module `hw/ip/pcm5102_audio_out/src/pcm5102_audio_out.v` is a
trivial 4-signal pass-through that mirrors the existing ADAU1761 I2S
DAC interface onto the four PMOD JB pins: `JB2 BCK <- bclk` (input
port, R18), `JB3 LCK <- lrclk` (input port, T17), `JB7 DIN <-
i2s_to_stream_0/so` (same serial DAC data that drives ADAU `sdata_o`
at G18), and `JB1 MCLK <- clk_wiz_audio_ext/clk_out1` (12.288 MHz from
the Phase 7C MMCM). The Phase 7C free-running tone module
`pcm5102_dac_tone` is **no longer instantiated** by the block design
(file kept in repo as a known-good debug reference). PCM5102 therefore
now receives bit-for-bit the same processed audio the ADAU1761 DAC
receives -- both DACs stream in parallel and either can be used as
the listening source. **PCM1808 ADC is NOT implemented (Phase 7D
still pending).** ADAU1761 ADC path / DSP chain (`i2s_to_stream_0` /
`axis_data_fifo_0` / `clash_lowpass_fir_0` / `axis_switch_*` /
`axi_dma_0`) untouched. HDMI integration / encoder integration /
GPIO_CONTROL_MAP / LowPassFir DSP untouched. bit/hwh rebuilt, deploy
PASS, on-board smoke (`scripts/test_pcm5102_dsp_output.py`) PASS:
ADC HPF True, all required IPs intact, no overlay regression.
DECISIONS.md D39.

Previous-pass header (Phase 7C):
**Phase 7C PCM5102 external DAC bring-up landed (DAC-only)**
(new RTL module `hw/ip/pcm5102_dac_tone/src/pcm5102_dac_tone.v` is a
free-running I2S master that emits a 1 kHz / 24-bit / quarter-scale sine
to both stereo channels at 48 kHz fs. A new MMCM
(`clk_wiz_audio_ext`, `100 MHz -> 12.288 MHz exact` via
`DIVCLK_DIVIDE=5, MULT_F=48.0, CLKOUT0_DIVIDE_F=78.125, VCO=960 MHz`)
drives the module. The four signals come out of PMOD JB:
JB1 W14 MCLK / JB2 Y14 BCLK / JB3 T11 LRCLK / JB7 V16 DIN
(LVCMOS33, no PULLUP, added to `audio_lab.xdc`). New tcl
`hw/Pynq-Z2/pcm5102_dac_integration.tcl` sourced from
`create_project.tcl` after `encoder_integration.tcl`. NO AXI-Lite
slave, NO new GPIO, NO change to the ADAU1761 path, HDMI integration,
encoder integration, GPIO_CONTROL_MAP, or LowPassFir DSP. PCM1808
ADC is **NOT** implemented (Phase 7D). bit/hwh rebuilt and deployed.
Smoke `scripts/test_pcm5102_dac_tone.py` PASS on PYNQ (overlay loads,
all required existing IPs intact, encoder IP visible as
`enc_in_0/s_axi`, no overlay regression). LCD GUI / encoder GUI not
re-verified visually yet on this build but no Python or notebook
changed; only Python touched is the new smoke script. `DECISIONS.md`
D38.

Previous-pass header (revert era):
**GUI catalog / HDMI shim refactor reverted after LCD display regression**
(reverted three commits — `ee0bc93` *Avoid encoder GUI overlay redownload*,
`4d141a0` *Start encoder HDMI GUI with initial frame*, `bef00b2` *Refactor
GUI catalog and HDMI shims* — because `EncoderGuiSmoke.ipynb` stopped
showing the GUI on the LCD after the refactor landed. Baseline restored
is `6524d1f` *Docs sweep for Phase 7G+ encoder GUI live apply (D37)*
plus the three revert commits (`70f86df` / `93c1e0c` / `63b8cd9`).
No bit / hwh / RTL / XDC / block-design / Vivado / DSP change; only
Python + notebook + docs touched. The single-cell `EncoderGuiSmoke.ipynb`
shape (Encoder1/2/3 + AudioLabOverlay + EncoderInput + ResourceSampler +
`backend.stop`) is preserved. Next time the GUI catalog / HDMI shim
refactor is attempted, display verification on the LCD must be a gating
step at every commit boundary.

Previous-pass header (refactor era, now reverted):
**Phase 7G+ encoder GUI-first live apply added**
(new module `audio_lab_pynq/encoder_effect_apply.py` translates the
compact-v2 AppState into `AudioLabOverlay` public setters with a 100 ms
default throttle; `EncoderUiController` gained `applier=` / `live_apply=`
/ `skip_rat=` kwargs; `scripts/run_encoder_hdmi_gui.py` and the
single-cell `EncoderGuiSmoke.ipynb` were rewritten around the dirty-flag
loop with the new applier; RAT pedal-mask bit 2 is excluded from
encoder cycling and live apply by default — the Clash stage and the
notebook `HdmiEffectStateMirror` API remain untouched. Earlier baseline
commits `5332b7e` / `3afd9c4` / `e2ece2e` brought the Phase 6I C2 baseline up;
`d1c4e8e` thinned `set_guitar_effects` into a 6-helper facade;
`52c5ea4` extracted the 1727-line `hdmi_effect_state_mirror.py` into
the `audio_lab_pynq/hdmi_state/` subpackage; `5173baf` extracted the
1685-line `GUI/pynq_multi_fx_gui.py` into the `GUI/compact_v2/`
subpackage; `c7a8680` added the rotary encoder input IP and the
follow-up deploy smoke added the encoder Notebook and PYNQ Python 3.6
compatibility fixes. See `DECISIONS.md` D26 / D33 / D35).

**Planning-only addition (2026-05-18, post Phase 7D close-out)**:
Digilent **Pmod I2S2** (CS4344 stereo DAC + CS5343 stereo ADC on one
PMOD board) has been ordered and will be evaluated as a stable external
I2S I/O reference before any further PCM1808 work. The full design /
phase / pin / test plan lives in
`docs/ai_context/PMOD_I2S2_INTEGRATION_PLAN.md`. The **PMOD JB pin
mapping is now confirmed (2026-05-18)** against the Digilent Pmod I2S2
reference manual: Pin 1..4 = D/A MCLK / LRCK / SCLK / SDIN on
JB1..JB4, Pin 7..10 = A/D MCLK / LRCK / SCLK / SDOUT on JB7..JB10,
Pin 5/11 = GND, Pin 6/12 = VCC 3.3V. FPGA 側は 1 系統の MCLK / LRCK
/ BCLK を生成して D/A 側と A/D 側に fanout する方針 (async-clocks
を構造的に排除)。No RTL / XDC / Tcl / Vivado / bit/hwh / Python /
Notebook change has been made for this; deployed bit is still the
Phase 7D close-out `f502373` series. PCM5102 SCK = GND (D40 / D42),
PCM1808 mux = ADAU (D43), Phase 7D close-out WNS `-7.931 ns`. See
`DECISIONS.md` D45.

## Current load-bearing facts

- **HDMI signal**: VESA SVGA `800x600 @ 60 Hz`, pixel clock
  `40.000 MHz`, `H total 1056`, `V total 628`, `rgb2dvi kClkRange=3`
  (`DECISIONS.md` D25). Not 720p, not native 800x480.
- **Framebuffer**: `audio_lab_pynq/hdmi_backend.py` defaults to
  `DEFAULT_WIDTH=800`, `DEFAULT_HEIGHT=600`. The 800x480 compact-v2
  GUI composes at framebuffer `(0,0)` (top 480 rows = UI, bottom 120
  rows = black). VDMA: `HSIZE=2400, STRIDE=2400, VSIZE=600`.
- **GUI renderer**: `GUI/pynq_multi_fx_gui.py::render_frame_800x480_compact_v2`
  + the (1).py-spec `EFFECT_KNOBS` / `AppState.all_knob_values` /
  `hit_test_compact_v2()` API from Phase 6H port (`DECISIONS.md` D24).
  The renderer is split per-theme under `GUI/compact_v2/{knobs, state,
  layout, renderer, hit_test}.py`; `GUI/pynq_multi_fx_gui.py` is a
  120-line re-export shim. `DECISIONS.md` D26.
- **HDMI GUI state mirror**: `audio_lab_pynq/hdmi_effect_state_mirror.py`
  still exports `HdmiEffectStateMirror` and every public helper, but
  the constants / normalisation helpers / `ResourceSampler` live under
  `audio_lab_pynq/hdmi_state/{pedals, amps, cabs, selected_fx, knobs,
  resource_sampler, common}.py`. `DECISIONS.md` D26.
- **`set_guitar_effects()`**: thin facade over 6 private helpers
  (`_require_effect_gpios`, `_merge_cached_distortion_state`,
  `_merge_cached_noise_suppressor_state`, `_write_effect_gpios`,
  `_refresh_cached_words`, `_route_effect_chain`). Behaviour and return
  value byte-for-byte preserved from the pre-split implementation.
  `DECISIONS.md` D26.
- **Notebook runtime**: `audio_lab_pynq/notebooks/HdmiGui.ipynb`
  (live loop, resource monitor, `OFFSET_X` / `OFFSET_Y` calibration)
  and `audio_lab_pynq/notebooks/HdmiGuiShow.ipynb` (one-shot,
  smart-attach via `download=False` when bit already loaded —
  protects the rgb2dvi PLL at the 800 MHz VCO lower edge from
  re-`download=True` knock-outs in the same Jupyter session).
- **Latest PL timing baseline**: D67 WNS `-8.204 ns`, TNS
  `-9300.746 ns`, WHS `+0.034 ns`, THS `0.000 ns`; Slice LUTs
  `19836`, Slice Registers `22174`, BRAM `6`, DSPs `83`. The older
  Phase 6I HDMI-only timing baseline was WNS `-8.096 ns`; D67 is the
  current deployed bit/hwh baseline. See `TIMING_AND_FPGA_NOTES.md`.
- **Encoder GUI live apply (Phase 7G+)**: `EncoderEffectApplier` is the
  only Python object allowed to translate the compact-v2 `AppState`
  into `AudioLabOverlay` calls from the encoder runtime. It uses
  `set_noise_suppressor_settings`, `set_compressor_settings`, and a
  single `set_guitar_effects(**kwargs)` per push — no raw GPIO writes.
  Throttle defaults to 100 ms (`--apply-interval-ms`); encoder 3 short
  press always force-applies regardless of the throttle. RAT
  (`distortion_pedal_mask` bit 2) is suppressed when `skip_rat=True`
  (default); pass `--include-rat` to override. EQ knob values are
  mapped GUI 0..100 → overlay 0..200 (50 == unity). Cab `MODEL` knob
  is overridden by `AppState.cab_model_idx` (0..2). RAT remains
  available via `HdmiEffectStateMirror.rat()` from notebooks; only
  the encoder loop refuses to touch it.
- **Encoder GUI render loop**: `scripts/run_encoder_hdmi_gui.py` and
  `audio_lab_pynq/notebooks/EncoderGuiSmoke.ipynb` share a dirty-flag
  loop — poll at 10 Hz while events are arriving, drop to 4 Hz after
  1 s of silence, render only when the AppState signature changes, cap
  at 5 fps even under continuous rotation. Idle `proc_cpu` measured
  at ~0–1% on the deployed PYNQ-Z2 image during the dry-run smoke.

## Phase history (chronological)

Phase 4 integrated HDMI framebuffer deployed; Phase 4C profiled the
deployed bit; Phase 4D added LCD fit modes; Phase 4E tested the
800x480 logical GUI; Phase 4F added manual viewport calibration;
Phase 4G shipped compact-v2 + negative-offset placement; Phase 4H
added vertical safe margins + a layout-debug overlay; Phase 4I rolled
back Phase 4H's chassis push-down to the 4G baseline; Phase 4J's
horizontal-only negative-offset sweep was left uncommitted, superseded
by Phase 5A. Phase 5A started HDMI output-side diagnosis for the
5-inch 800x480 LCD; Phase 5C locked the user-confirmed
`x=0,y=0,w=800,h=480` viewport default on the PYNQ-Z2 at
`192.168.1.9`; the post-5C cleanup kept active `GUI/` and removed the
legacy untracked `HDMI/` tree. Phase 5D added the Pip-Boy-inspired
phosphor-green theme + soft scanline overlay on the (then) 1280x720
path. Phase 6F rechecked the recurring right-shift report (bbox /
backend / framebuffer all `(0,0)`); Phase 6G added strong-UI-bbox
diagnostics + an actual-UI visual test (intermediate renderer
x-tightening was rolled back). Phase 6H (`d7ea0ab`) ported the
compact-v2 renderer to the (1).py spec (single `EFFECT_KNOBS` dict,
inline PEDAL / AMP / CAB model dropdown, Phase 4G / 4I baseline
coordinates restored). The subsequent Phase 6H native 800x480 / 40 MHz
timing pass was **rejected** on the LCD (white screen) and never
committed. Phase 6I rolled back to 720p, swept candidate timings, and
deployed **VESA SVGA 800x600 @ 60 Hz / 40 MHz** as the working HDMI
signal — same H/V totals as the rejected Phase 6H, but with
SVGA-standard 800x600 active that the LCD's HDMI receiver actually
recognises. The Phase 5D / 6F references to a "1280x720 HDMI signal"
below this paragraph describe what was true at those phases; the
current signal is the Phase 6I SVGA 800x600 path.

Detailed CURRENT_STATE-flavoured snapshots from earlier phases were
moved out of this file to keep it short. Read them only when an old
phase is the load-bearing reference:

- `history/current_state/PHASE_6F_TO_6I_DETAIL.md` — dated 2026-05-16
  paragraphs for Phase 6F (recurrence check), Phase 6G (actual UI
  x-origin fix, partially rolled back), Phase 6H (1).py spec port +
  rejected native 800x480 timing, Phase 6I HDMI timing sweep with
  C2 SVGA 800x600 deployed.
- `history/current_state/HDMI_GUI_HISTORY.md` — Phase 4 / 4C / 4D /
  4E / 4F / 4G / 4H / 4I / 4J / 5A / 5C / 5D HDMI GUI snapshots and
  the original "HDMI GUI integration planning" prose, plus the
  Phase 1 / 2A / 2B / 2C / 2D / 3 render-bench / PYNQ-compat /
  bridge-plan / bridge-runtime / Vivado-design-proposal snapshots.
- `history/current_state/DSP_AND_VOICING_HISTORY.md` — internal mono
  DSP pipeline, LowPassFir behavior-preserving split, Amp Simulator
  fizz-control and named-model passes, audio-analysis voicing fixes,
  Amp/Cab real voicing, reserved-pedal implementation, real-pedal
  voicing pass, chain presets, compressor add, the earlier
  effect-chain refactor, plus the post-reserved-pedal Headline /
  Working tree / Live verification / Vivado timing / Notebooks
  snapshot.
- `history/current_state/PHASE_7_PLANNING_HISTORY.md` — Phase 7A
  (external codec + encoder planning), Phase 7B (module verification
  + candidate package pin docs), and the Phase 7F/7G encoder PL IP +
  Python driver + HDMI GUI control implementation log.

Per-phase plan / result memos for the HDMI arc are still in the
sibling `history/hdmi_phases/` directory; the snapshots above are
the CURRENT_STATE-flavoured prose of the same milestones.

## PYNQ-Z2 network identity

The lab board should be kept at a stable router DHCP reservation:

| Field | Value |
| --- | --- |
| Device name | `PYNQ-Z2` |
| eth0 MAC | `00:05:6B:02:CA:04` |
| Reserved IP | `192.168.1.9` |
| SSH | `ssh xilinx@192.168.1.9` |
| Jupyter | `http://192.168.1.9:9090/tree` |

Use `bash scripts/show_pynq_network_info.sh` to confirm hostname, IP,
and eth0 MAC from the board. The reservation itself must be created in
the router management UI; do not rely on ad-hoc IP scans as normal
operation, and do not write a static IP directly on the PYNQ for this
workflow. After changing the reservation, reboot the PYNQ-Z2 and run:

```sh
ssh xilinx@192.168.1.9 'hostname; ip -br addr; cat /sys/class/net/eth0/address'
bash scripts/deploy_to_pynq.sh
```

## What to do next

Open work, in roughly priority order:

1. **D67 / Pmod mode-2 post-deploy QA.** The current active audio path is
   Pmod I2S2 mode 2 (`ADC -> DSP -> DAC`) with D50 mono RIGHT-slot
   mirroring, the D62 BD-2 coefficient-only retune, the D66
   DS-1-only symmetric knee retune, and the D67 JCM800 constants-only
   retune. Continue bench
   listening with external source -> Pmod Line In and Pmod Line Out ->
   monitor; keep the on-module Line Out -> Line In jumper disconnected
   for mode 2.
2. **Pmod mode-2 mono workaround future improvement.** D50 intentionally
   mirrors `mode2_right_snapshot` into both DAC slots. A future fix can
   repair the `i2s_to_stream` LEFT extraction / `i2sOut` setup issues and
   restore true stereo, but until then mono RIGHT output is the current
   specification.
3. **物理 rotary encoder smoke** (`DECISIONS.md` D35)。3 ch すべての
   rotate / short / long / release を実操作で記録し、必要なら
   `--reverse-encN` / `--swap-encN` / `--debounce-ms` の最終設定を
   docs に反映する。
4. **8th pedal slot.** Bit 7 of `distortion_control.ctrlD` is the
   only remaining reserved pedal slot. If a future voicing wants
   in, it lands there as a new register-staged Clash block
   following the same shape as the new `ds1` / `big_muff` /
   `fuzz_face` stages.
5. **Drive WNS toward 0.** The deployed build is at the value
   recorded in `TIMING_AND_FPGA_NOTES.md` (D67 WNS `-8.204 ns`);
   the audio path tolerates the current band in practice but the
   build is not formally clean. Any timing work must preserve the
   safe-bypass bench result; D58 / D59 / D60 / D61 proved that better
   WNS alone is not sufficient if audio regresses.
6. **UI / preset polish** in the notebooks. Possible adds:
   per-pedal default presets, an A/B compare cell, a quick-record
   cell that pairs the pedalboard with the existing diagnostic
   capture helpers.
7. **Diagnostic capture for distortion stages.** Re-use
   `diagnostics.capture_input` to log a clip waveform per pedal so
   we can compare voicings without ear fatigue.
8. **PCM5102 / PCM1808 revival only if explicitly requested.** The old
   Phase 7C / 7E / 7D path is retired because PMOD JB is now owned by
   Pmod I2S2. Do not continue D44 / D43 PCM follow-ups as normal
   backlog without a new user-approved revival phase.

## Things to be careful about

- Do **not** silently revert the ADC HPF default-on. `R19_ADC_CONTROL`
  must read back as `0x23` after `config_codec()`.
- Do **not** reintroduce a single function with a `case` over all
  seven pedals. That is exactly what regressed timing the first time;
  see `TIMING_AND_FPGA_NOTES.md`.
- Do **not** deploy a bitstream whose WNS is significantly worse than
  the current D67 baseline (`-8.204 ns`) without flagging the regression
  first. A -15 ns-class result remains a hard reject, and any audible
  safe-bypass regression is a blocker even if WNS improves.
- Do **not** revive the legacy `gateGainNext` / `gateFrame` registers
  in the active pipeline. The active gain stage is the noise
  suppressor (`nsApplyFrame`); the legacy helpers are kept as Haskell
  source for backward compatibility but are not wired up.
- Do **not** drop the legacy `gate_control.ctrlB` write from
  `set_guitar_effects` -- older bitstreams without
  `axi_gpio_noise_suppressor` still rely on it.
- Do **not** silently revive the retired PCM1808 / PCM5102 path. PMOD JB
  is owned by Pmod I2S2 in the current build, and `create_project.tcl`
  sources `pmod_i2s2_integration.tcl`, not the PCM Tcl files. A PCM
  revival requires an explicit new phase, PMOD ownership decision,
  full rebuild, timing review, and deploy plan.
- Do **not** allocate rotary encoder GPIO into PMOD JB. PMOD JB is the
  active Pmod I2S2 audio connector; encoder remains on the Raspberry Pi
  header side (`DECISIONS.md` D28 / D34, `IO_PIN_RESERVATION.md`).
- Do **not** poll encoder A / B / SW from Python directly. PL 側で
  debounce + quadrature decode + event 化する (`DECISIONS.md` D30、
  `ENCODER_GUI_CONTROL_SPEC.md`)。
- Do **not** connect PCM1808 analog input directly to a guitar. 必要な
  analog front-end (高 impedance buffer / AC coupling / bias / gain /
  anti-alias LPF / clamp) は Phase 7E 以降。
- Do **not** wire the rotary encoder module `+` pin to 5V. 必ず
  PYNQ-Z2 **3.3V** rail を使う (`DECISIONS.md` D31)。基板上 pull-up が
  `+` 経由で `CLK / DT / SW` を 5V 化し、PL pin (3.3V LVCMOS33) を
  破損する可能性がある。
- Do **not** rename or move the `axi_encoder_input` IP base address.
  `0x43D10000` は `axi_vdma_hdmi` (`0x43CE0000`) / `v_tc_hdmi`
  (`0x43CF0000`) / `0x43D00000` (HDMI 拡張枠) を避けて選定済み
  (`DECISIONS.md` D32)。
- Do **not** merge encoder bits into existing `axi_gpio_*` IPs. encoder
  は独立 AXI-Lite IP として実装 (`DECISIONS.md` D33)。
  `GPIO_CONTROL_MAP.md` の `ctrlA..D` 4-byte 契約に encoder event /
  delta を混ぜない。
- Do **not** allocate encoder pins to PMOD JB / PMOD JA without a fresh
  pin-ownership review. Current encoder wiring uses Raspberry Pi header
  non-JA-shared pins (`raspberry_pi_tri_i_6..14`), and PMOD JB must stay
  dedicated to Pmod I2S2.
- Do **not** push, pull, or fetch.
