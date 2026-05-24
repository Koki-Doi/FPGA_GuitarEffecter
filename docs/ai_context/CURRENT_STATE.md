# Current state

Latest work: **2026-05-24 (D60 audio-rejected on bench for bypass-time high-frequency saturation noise; PYNQ board restored to D58.2 baseline; D60 source reverted in this commit):** The D60 Compressor target-gain split (control-only, no full-`Frame` carry; built on branch `wns-compressor-gain-pipeline`) was deployed to PYNQ-Z2 192.168.1.9 for a deliberate audio-listening check. Deploy procedure: `git checkout` of the D60 bit/hwh files into the work tree, `scripts/deploy_to_pynq.sh` mirrored the artifacts to all four board copies (md5 `078f39c78991f1b36e6bfd1806b830a5` / `48160ae4acdf3abb9d1abf14dd65cc6d` everywhere), the user cold-power-cycled the PYNQ-Z2, then `AudioLabOverlay(download=True)` was called explicitly to force a fresh PL program (`PL.timestamp` confirmed re-program). Deploy-time programmatic smoke PASSed: `ADC HPF True`, Pmod mode 2 readback `2`, `FRAME_COUNT delta = 144148..144154` across `all_off` / `comp_on_mild` / `comp_on_stronger` / `comp_off_again` 3 s windows, `CLIP_COUNT delta = 0` in every window, `set_compressor_settings(threshold/ratio/response/makeup/enabled)` readback consistent, GUI keep-mode + dsp-mode 20 s holds clean with `live=ON apply=OK` and no Python exceptions, LCD compact-v2 rendered correctly (rgb2dvi PLL re-locked cleanly post cold start), final mute=3 confirmed. **On-bench audio verification by ear FAILED: high-frequency saturation noise was audible even in safe-bypass (all `effect_on = False`, Pmod mode 2 ADC -> DSP -> DAC).** This is the same class of regression as D58 (`feature/amp-drive-mode-balanced-gain`) and D59 — a Vivado P&R-induced bypass-path artifact that the macroscopic timing summary and `CLIP_COUNT` do not flag, and that listening on safe bypass is the only known way to detect. PYNQ board was rolled back to D58.2 (bit/hwh md5 `1c9071b5f2e1eec63ef6abbcfcacbf02` / `21c1ca7a6ddd5c26fd39f8746abe28d8`) via `git checkout HEAD -- hw/Pynq-Z2/bitstreams/{audio_lab.bit,audio_lab.hwh}` + `scripts/deploy_to_pynq.sh` + explicit `AudioLabOverlay(download=True)` to force a fresh PL program (`PL.timestamp` updated); post-rollback Pmod mode 2 safe-clean smoke PASSed (`FRAME_COUNT delta = 144153`, `CLIP_COUNT delta = 0`, `ADC HPF True`, `VERSION 0x00480001`, final mute=3). **This commit also reverts `hw/ip/clash/src/AudioLab/Effects/Compressor.hs`, `hw/ip/clash/src/AudioLab/Pipeline.hs`, and the regenerated Clash artifacts under `hw/ip/clash/vhdl/LowPassFir/` back to the D58.2 baseline so the source tree matches the deployed bit.** D60 synthesis / timing record (WNS `-8.300 ns`, `+0.195 ns` better than D58.2; DSP `83`, BRAM `6`; local bit/hwh md5 `078f39c7...` / `48160ae4...`) is preserved in `DECISIONS.md` D60 and `TIMING_AND_FPGA_NOTES.md` so the attempt remains discoverable in history. **Both D59 (full-`Frame` carry through the target pipeline) and D60 (control-only split, audio frame left on the original `compLevelPipe -> compApplyPipe` path) are now audio-rejected for the same class of Vivado P&R artifact in the safe-bypass path.** Any future Compressor target-pipeline rework MUST treat a bench-listening change in the safe-bypass path as a blocking signal regardless of CLIP_COUNT / FRAME_COUNT / WNS / TNS / failing-endpoint count -- the bench ear is the only sensor that has caught this class of regression so far.

Superseded D60 attempt note (audio-rejected; source reverted; retained for history): **2026-05-23 (D60 Compressor target-gain split, control-only retake after D59 audio regression):** D60 kept the Compressor gain-calculation split without carrying the audio frame through the target path. `Compressor.hs` had `compTargetStage1` for threshold / soft-threshold comparison, excess calculation, and excess clamp, `compTargetStage2` for `excessU12 * ratioByte`, reduction shift/clamp, and target-gain calculation, and `compGainNext` for the existing smoothing/register update. `Pipeline.hs` registered only the control/target path (`compTargetStage1Pipe`, `compTargetPipe`); `compApplyPipe` still consumed the original `compLevelPipe` audio data path. No Compressor coefficients, threshold/ratio/response/makeup semantics, effect order, GPIO map, `topEntity` ports, DS-1 / Distortion, `Amp.hs`, GUI, Pmod I2S2, `block_design.tcl`, or Vivado strategy changed. Clash -> VHDL -> IP repackage -> Vivado full build PASS. D60 local timing: WNS `-8.300 ns`, TNS `-8836.632 ns`, failing setup endpoints `3181 / 60265`, WHS `+0.043 ns`, THS `0.000 ns`; DSP count stays `83`, BRAM stays `6`. Local bit/hwh md5 were `078f39c78991f1b36e6bfd1806b830a5` / `48160ae4acdf3abb9d1abf14dd65cc6d`. **D60 was subsequently deployed to PYNQ-Z2 and audio-rejected for bypass-time high-frequency saturation noise; see Latest work above for the rollback record.**

Superseded D59 note (audio-rejected; retained for history): **2026-05-23 (D59 Compressor gain target path pipeline split for WNS):** branch `wns-compressor-gain-pipeline` splits only the Compressor gain-calculation path. `Compressor.hs` now separates target calculation into `compTargetStage1` (threshold / soft-threshold comparison, excess calculation, excess clamp), `compTargetStage2` (`excessU12 * ratioByte`, reduction shift/clamp, target-gain calculation), and the existing `compGainNext` smoothing/register update. `Pipeline.hs` registers those target stages and carries the `Frame` through `compTargetPipe` / `compGainFramePipe` before `compApplyPipe`, preserving compressor-local control/frame alignment while adding the allowed sample-scale gain reaction latency. No Compressor coefficients, threshold/ratio/response/makeup semantics, effect order, GPIO map, `topEntity` ports, DS-1 / Distortion, `Amp.hs`, GUI, Pmod I2S2, `block_design.tcl`, or Vivado strategy changed. Clash -> VHDL -> IP repackage -> Vivado full build PASS; WNS improves vs D58.2 from `-8.495 ns` to `-8.138 ns` (`+0.357 ns`), TNS improves from `-9052.753 ns` to `-8756.266 ns`, failing setup endpoints drop `3224 / 60227 -> 2922 / 60321`, and hold remains clean (`WHS +0.052 ns`, `THS 0.000 ns`). DSP count stays `83`, BRAM stays `6`; registers rise by 254 as expected from the new pipeline registers. The top routed critical path has moved off Compressor and is now DS-1-side `ARG__7__2` -> `ds1_5_reg[...]`, which this task intentionally did not touch. bit/hwh md5 `a42358803798acc1e63ef5d4abd45b33` / `1ddd377d077401ccf60a9096d319ed52` deployed to PYNQ-Z2 192.168.1.9, with all five board copies md5-matching. Programmatic smoke PASS: `AudioLabOverlay()` loads the new bit, `ADC HPF True`, `R19_ADC_CONTROL 0x23`, `axi_gpio_compressor` present, compressor enable/disable word readback works, Pmod I2S2 mode 2 readback `2`, safe-clean 3 s `FRAME_COUNT delta = 144150`, `CLIP_COUNT delta = 0`, and final mode 3 mute readback `3`. `DECISIONS.md` D59 and `TIMING_AND_FPGA_NOTES.md` carry the timing/deploy record.

Last updated: **2026-05-23 (D58.2 Balanced Amp Drive Mode saturation -- fixed-scalar retake after the D58 bit caused a P&R-induced bypass regression; Vivado rebuild + deploy + programmatic smoke PASS, on-bench audio verification pending):** D58's `ch * factor` Drive-mode knee deltas added four DSP48E1 multipliers (DSP count `83 -> 87`) and the resulting Vivado P&R shift introduced an audible high-frequency saturation noise on the ADC -> DAC bypass path that the user heard even with Amp OFF and full safe bypass; the D58 bit (`feature/amp-drive-mode-balanced-gain`, commit `797467c`) was rolled back on the PYNQ to the D55 bit (sha `8df39b06...` / hwh `9fb470c7...`) to restore clean audio while keeping the D58 source commit on its branch for reference. D58.2 picks the same coefficient targets but re-shapes them so they cost no extra DSP: `ampDrivePosDelta` / `ampDriveNegDelta` switch back to the D55 `Unsigned 3 -> Signed 25` signature (per-model fixed scalars, no `ch` argument), with per-model values sized to approximate D58's first-stage `ch * factor` evaluated at each model's own `ampCharForModel` peak (JC-120 `13_000` / Twin `58_000` / AC30 `130_000` / Rockerverb `210_000` / JCM800 `264_000` / TriAmp Mk3 `336_000` for pos; `11_000` / `50_000` / `113_000` / `180_000` / `231_000` / `300_000` for neg). `ampSecondStageDriveBonus` keeps D58's `14..56` (simple per-model adder, no DSP), `ampPreLpfDriveDarken` keeps D58's `5..24` (simple per-model subtractor, no DSP). The `ampAsymClip` call sites revert to the D55 form (`ampDrivePosDelta modelIdx` -- no `ch` arg passed). D55 structure preserved verbatim everywhere else (six-model lineup, `ctrlD[7] = ampDriveMode` / `ctrlD[6:3] = 0` / `ctrlD[2:0] = ampModelIdx`, `softClipK 3_300_000 / 3_400_000` safety, second-stage `intensity = ampCharForModel idx >> 1`, six-entry `ampTrebleGain` / `presenceTrim`). D57's anti-patterns explicitly NOT adopted: no `ampInputDriveGainBonus`, no pre-clip push, no `ch * 5000+` knee multiplier, no full-intensity second-stage clip. Clash regenerated VHDL via `clash -package-id clash-prelude-1.8.1-...144c -isrc -fclash-hdldir /tmp/clash_d582 --vhdl src/LowPassFir.hs`; IP repackaged via `vivado -mode batch -source create_ip.tcl`. Vivado batch build PASS (`write_bitstream completed successfully`, 0 Errors). **DSP count back to `83 / 220 (37.73 %)` -- the same as D55 and four below D58's `87`**, which is the load-bearing metric for not retriggering the bypass-path P&R regression. WNS `-8.495 ns` vs D55 baseline `-8.231 ns` (regresses `0.264 ns`, still inside the historical `-7..-9 ns` deploy band and well above the `-9.5 ns` hard gate); WHS `+0.051 ns`; THS `0.000 ns` (hold clean); 3224 / 60227 failing setup endpoints (5.35 %). Utilization after place: Slice LUTs `19713` (`37.05 %`, -73 vs D55), Slice Registers `22110` (`20.78 %`, -50 vs D55), Block RAM Tile `6` (`4.29 %`, unchanged). bit/hwh `93f31348...` / `25991dc0...` deployed 5-site to PYNQ-Z2 192.168.1.9 (all five `/home/xilinx/.../bitstreams/`, `/usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams/`, `/usr/local/lib/python3.6/dist-packages/pynq/overlays/audio_lab/`, `/home/xilinx/jupyter_notebooks/audio_lab/bitstreams/`, `/home/xilinx/Audio-Lab-PYNQ/hw/Pynq-Z2/bitstreams/` sha-match the local build). Programmatic smoke PASS: `ADC HPF True`; six amp models `0..5` ctrlD readback OK across Clean + Drive (12 cases); Pmod I2S2 MODE writes `tone / loopback / dsp / mute` (0 / 1 / 2 / 3) all readback OK via `scripts/pmod_i2s2_mode.py`; **D58 regression guard -- safe bypass (`all effect_on = False`) + mode 2 DSP 3 s CLIP_COUNT delta `0` (FRAME_COUNT `+144150` -- exact 48 kHz cadence)**; Amp OFF (others default) 3 s CLIP_COUNT delta `0`; TriAmp Mk3 + Drive (full chain) 3 s CLIP_COUNT delta `0`; `scripts/run_encoder_hdmi_gui.py --live-apply --skip-rat --pmod-mode dsp` starts cleanly (`AudioLabOverlay loaded`, `HDMI backend started at 800x600`, `live=ON apply=OK`, no Python exceptions, initial render fires once on the signature change then idles per the dirty-flag policy). `python3 -m unittest -v tests.test_encoder_*` 91 tests PASS; `python3 tests/test_overlay_controls.py` PASS. **Audio verification by ear ("ブチブチしない", "Drive で D55 より歪む", "D57 より穏やか", "Amp OFF / safe bypass で D58 のような高音域飽和ノイズが消えた" -- the original D58 regression symptom) is pending the user's bench session.** GUI / `block_design.tcl` / HDMI timing / Encoder PL IP / Pmod I2S2 RTL / `GPIO_CONTROL_MAP` / `topEntity` ports untouched. Branch `feature/amp-drive-mode-balanced-gain-v2`. `DECISIONS.md` D58.2.**

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
**Pmod I2S2 mode 0 (TX tone + ADC probe) and mode 1 (ADC -> DAC direct loopback) are both reachable from `scripts/test_pmod_i2s2.py --mode tone | loopback`. The mode-1 path requires `--confirm-loopback` because the on-module Line Out ↔ Line In jumper plus the full-scale echo can feed back. `axi_pmod_i2s2_status.v` write FSM was reworked to the same shape `axi_encoder_input.v` uses (latch awaddr in the AW phase, commit in the W phase using the latched address), which fixed a same-cycle race where back-to-back MMIO writes (e.g. MODE=0 then CLEAR=1) committed the CLEAR write at the MODE address and silently flipped `cfg_mode_o`. No DSP integration: Pmod I2S2 ADC is NOT routed into the AudioLab AXIS chain; that is intentionally deferred.**

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
ADAU1761 codec init are all untouched. The ADAU1761 path is
still available through the existing ADAU DAC line out / headphone
out for users who need the on-board codec. `DECISIONS.md` D48.)

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
- **PL timing baseline**: WNS `-8.096 ns`, TNS `-6389.430 ns`,
  WHS `+0.040 ns`, THS `0.000 ns`; Slice LUTs `18618 (35.00%)`,
  Slice Registers `20846 (19.59%)`. Within the historical
  `-7..-9 ns` deploy band. See `TIMING_AND_FPGA_NOTES.md`.
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

1. **D44 follow-up RTL/Tcl pass** (`DECISIONS.md` D44, plan only).
   (a) `pcm1808_adc_integration.tcl` で `CONFIG.CONST_VAL` に応じて
   `ext_pcm1808_sckie_o` を `clk_wiz_audio_ext/clk_out1` か
   `xlconstant 0` に切替 (deploy bit が mux=ADAU の時 JB8 に不要な
   12.288 MHz を出さない)。(b) `pcm5102_audio_out.v` に build-time
   `MODE` パラメータで `processed audio / digital silence /
   -18 dBFS 1 kHz tone / ramp` を選べる selector を追加。Vivado
   rebuild + timing review が要る。PCM1808 復活時 (`CONST_VAL {1}`)
   は SCKI 復元を忘れない。
2. **PCM1808 ハードウェア診断 / 再投入** (`DECISIONS.md` D43)。新規
   module に差し替えて `hw/Pynq-Z2/pcm1808_adc_integration.tcl` の
   `CONFIG.CONST_VAL {0}` を `{1}` に戻し、bit/hwh rebuild + deploy、
   `scripts/test_pcm1808_adc_to_pcm5102.py --capture-adc` で
   `min/max/mean/RMS/peak_dBFS` を確認。pure 0 が続けば chip / analog
   前段の damage 仮説継続。
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
   recorded in `TIMING_AND_FPGA_NOTES.md` (Phase 7D close-out
   `-7.931 ns`); the audio path tolerates the current band in
   practice but the build is not formally clean. Worth a pass that
   splits any remaining deeper combinational stage and / or
   pipelines the cab or reverb tap address paths.
6. **UI / preset polish** in the notebooks. Possible adds:
   per-pedal default presets, an A/B compare cell, a quick-record
   cell that pairs the pedalboard with the existing diagnostic
   capture helpers.
7. **Diagnostic capture for distortion stages.** Re-use
   `diagnostics.capture_input` to log a clip waveform per pedal so
   we can compare voicings without ear fatigue.

## Things to be careful about

- Do **not** silently revert the ADC HPF default-on. `R19_ADC_CONTROL`
  must read back as `0x23` after `config_codec()`.
- Do **not** reintroduce a single function with a `case` over all
  seven pedals. That is exactly what regressed timing the first time;
  see `TIMING_AND_FPGA_NOTES.md`.
- Do **not** deploy a bitstream whose WNS is significantly worse than
  the current Phase 7D close-out build's WNS (`-7.931 ns`) without
  flagging the regression first. A -15 ns-class result remains a hard
  reject.
- Do **not** revive the legacy `gateGainNext` / `gateFrame` registers
  in the active pipeline. The active gain stage is the noise
  suppressor (`nsApplyFrame`); the legacy helpers are kept as Haskell
  source for backward compatibility but are not wired up.
- Do **not** drop the legacy `gate_control.ctrlB` write from
  `set_guitar_effects` -- older bitstreams without
  `axi_gpio_noise_suppressor` still rely on it.
- Do **not** silently replace the ADAU1761 path with PCM1808 / PCM5102.
  Phase 7 では外付け codec は別 I2S path として追加し (`DECISIONS.md`
  D27)、Phase 7C / 7E で PCM5102 は ADAU 並列出力、Phase 7D で PCM1808
  は build-time mux + JB8 SCKI (`DECISIONS.md` D38 / D39 / D41 / D42)
  に landing 済。既存 ADAU1761 経路 / DSP / GPIO map を破壊しない。
- Do **not** drive `pcm5102_audio_out.v` の `ext_audio_mclk_o` を 0 以外に
  する (`DECISIONS.md` D40 / D42)。PCM5102 SCK は GND-tied / internal-
  SYSCLK 固定。JB1 は構造的に常時 0。PCM1808 SCKI は JB8 / W16
  (`ext_pcm1808_sckie_o`) 経由でのみ供給する。
- Do **not** flip `pcm1808_adc_integration.tcl` の `CONFIG.CONST_VAL {0}`
  を勝手に `{1}` に戻す (`DECISIONS.md` D43)。PCM1808 module の analog
  前段ハードウェア診断が完了するまで mux=ADAU フォールバック維持。
- Do **not** allocate rotary encoder GPIO into the PMOD reserved for
  external audio. Audio が優先で、encoder は Raspberry Pi header 側へ
  逃がす (`DECISIONS.md` D28、`IO_PIN_RESERVATION.md`)。
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
- Do **not** allocate encoder pins to PMOD JB / PMOD JA. これらは
  外付け PCM1808 / PCM5102 codec 予約のまま温存 (`DECISIONS.md` D28 /
  D34)。encoder は Raspberry Pi header の JA 非共有 pin
  (`raspberry_pi_tri_i_6..14`) を使う。
- Do **not** push, pull, or fetch.
