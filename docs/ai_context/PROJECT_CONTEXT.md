# Project context

## What this repository is

Audio-Lab-PYNQ (a.k.a. FPGA_GuitarEffecter) is a real-time guitar effect
chain. In the current deployed build, line-level audio enters and exits through
the Digilent Pmod I2S2 module on PMOD JB: the CS5343 ADC feeds the Zynq-7000
PL through `i2s_to_stream_0`, a Clash-generated DSP block processes the
samples, and the CS4344 DAC plays the result. The ADAU1761 onboard codec is
still configured by Python for I2C/ADC-HPF health checks and `sdata_o` debug
visibility, but its BCLK/LRCLK/SDATA_I pins are not the active DSP source in
the Pmod build. The PS-side Python and Jupyter layers route audio, configure
the codec/status IPs, and control effect parameters via AXI GPIO.

## Toolchain

| Component | Version |
| --- | --- |
| Vivado | 2019.1 |
| Clash | 1.8.1 (clash-prelude pinned to the matching package id) |
| GHC | 8.10.7 |
| PYNQ image | 2020.1 series, Python 3.6 |
| Board | PYNQ-Z2 (xc7z020clg400-1) + Digilent Pmod I2S2 active audio on PMOD JB; ADAU1761 codec configured for health/debug |

## Top-level layout

| Path | Role |
| --- | --- |
| `hw/Pynq-Z2/block_design.tcl` | Vivado block design (off-limits unless the user explicitly approves edits). |
| `hw/Pynq-Z2/audio_lab.xdc` | Pin / clock constraints. |
| `hw/Pynq-Z2/create_project.tcl` | Vivado batch entry point. |
| `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` | Built artefacts shipped to PYNQ. |
| `hw/Pynq-Z2/pmod_i2s2_integration.tcl` | Sourced by `create_project.tcl` to add the current PMOD JB Pmod I2S2 path, reroute `i2s_to_stream_0` onto the Pmod ADC/clocks, instantiate `pmod_master_0` plus `pmod_status_0`, and map the status/control slave at `0x43D20000`. |
| `hw/Pynq-Z2/audio_lab_pmod_i2s2.xdc` | PMOD JB constraints for Pmod I2S2 D/A and A/D sides (`JB1..JB4`, `JB7..JB10`). |
| `hw/Pynq-Z2/wah_integration.tcl` | Sourced after `pmod_i2s2_integration.tcl` to add `axi_gpio_wah` at `0x43D30000` (bumps `NUM_MI` 19->20, M19) and wire it to `clash_lowpass_fir_0/wah_control` (D72/D73). `block_design.tcl` not edited. |
| `hw/Pynq-Z2/xadc_integration.tcl` + `xadc_a0.xdc` | Sourced after `wah_integration.tcl` to add the `xadc_wiz_a0` XADC Wizard at `0x43D40000` (bumps `NUM_MI` 20->21, M20) reading Arduino A0 = VAUX1 on E17/D18 for the FP02M pedal (D76). `block_design.tcl` not edited. |
| `hw/Pynq-Z2/footswitch_integration.tcl` | Sourced after `xadc_integration.tcl` and before `island_integration.tcl` to add `axi_footswitch_input` at `0x43D50000` (bumps `NUM_MI` 21->22, M21), with `fsw0_i` / `fsw1_i` / `fsw2_i` on RP pins 11 / 12 / 35. `block_design.tcl` not edited. |
| `hw/Pynq-Z2/island_integration.tcl` | Sourced last to build the D75 DSP clock-domain island: enables `FCLK_CLK1 = 50 MHz`, adds `rst_island_50M`, inserts `axis_clock_converter` `cc_dsp_in` (100->50) / `cc_dsp_out` (50->100) around the DSP AXIS, and moves `clash_lowpass_fir_0/clk` + `aresetn` onto FCLK1. `block_design.tcl` not edited. |
| `audio_lab_pynq/fp02m.py` | ZOOM FP02M expression-pedal layer: `Fp02mCalibration` (JSON load/save), `Fp02mXadcMmioReader` (reads `xadc_wiz_a0` reg `0x244` = VAUX1 via AXI MMIO), `Fp02mPositionMapper` (raw->u8 with invert / deadband / EMA / "C" anti-log taper), `Fp02mWahController`. The pedal is the sole `position_raw` writer (D74/D76). |
| `hw/ip/clash/src/LowPassFir.hs` | The full PL DSP pipeline. Real source of truth for every effect. |
| `hw/ip/clash/vhdl/LowPassFir/` | Clash-generated VHDL plus packaged Vivado IP. |
| `hw/ip/pmod_i2s2/src/pmod_i2s2_master.v` | FPGA-master I2S engine for the active Pmod I2S2 path. Generates 12.288 MHz MCLK, 3.072 MHz BCLK, 48 kHz LRCK, supports modes 0 tone / 1 loopback / 2 DSP / 3 mute, and mirrors mode-2 RIGHT slot to both DAC channels via `mode2_right_snapshot` (D50). |
| `hw/ip/pmod_i2s2/src/axi_pmod_i2s2_status.v` | AXI-Lite status/control slave (`pmod_status_0` @ `0x43D20000`): VERSION `0x00480001`, STATUS, FRAME_COUNT, NONZERO_COUNT, SDOUT_XCOUNT, CLIP_COUNT, LAST/PEAK sample registers, MODE, CLEAR. |
| `hw/ip/fx_gain/` | Legacy HLS gain IP (instantiated but not stream-connected). |
| `audio_lab_pynq/AudioLabOverlay.py` | Python facade: overlay loading, AXIS routing, GPIO writes. |
| `audio_lab_pynq/AudioCodec.py` | ADAU1761 register driver and config sequence. |
| `audio_lab_pynq/diagnostics.py` | Phase-1 input/output diagnostics. |
| `audio_lab_pynq/hdmi_backend.py` | Direct MMIO HDMI framebuffer backend for the integrated AudioLab HDMI path; avoids PYNQ's base-overlay video driver. |
| `audio_lab_pynq/encoder_input.py` | Low-level driver for the Phase 7F `axi_encoder_input` PL IP (3 rotary encoders, `enc_in_0/s_axi` at `0x43D10000`). Decodes `STATUS` / `DELTA_PACKED` / `COUNT*` into `EncoderEvent` instances and exposes `configure(...)` for debounce / reverse / swap. PYNQ Python 3.6-safe (no dataclasses / future annotations). |
| `audio_lab_pynq/encoder_ui.py` | `EncoderUiController` maps `EncoderEvent` instances into compact-v2 `AppState` mutations. Phase 7G+ adds the `applier=` / `live_apply=` / `skip_rat=` kwargs so encoder 1 short flips the effect, encoder 1 long calls safe-bypass, encoder 3 rotate runs a throttled apply, and encoder 3 short always force-applies. Legacy `mirror=` / `bridge=` fall-through is preserved when no applier is supplied. |
| `audio_lab_pynq/encoder_effect_apply.py` | Phase 7G+ `EncoderEffectApplier`: the only Python object allowed to translate compact-v2 `AppState` into `AudioLabOverlay` writes from the encoder runtime. Uses `set_noise_suppressor_settings`, `set_compressor_settings`, and `set_guitar_effects(**kwargs)` only — no raw GPIO writes. Default throttle 100 ms; `skip_rat=True` excludes pedal-mask bit 2 from cycling / live apply. Tracks `apply_count` / `error_count` / `last_apply_ok` / `last_apply_message` / `unsupported` for the GUI status strip and resource print. See `DECISIONS.md` D37. |
| `audio_lab_pynq/footswitch_input.py` | Low-level driver for the D78 `axi_footswitch_input` PL IP (`fsw_in_0/s_axi` at `0x43D50000`). Decodes latched press events from three latching 3PDT footswitches and exposes `configure(...)` for debounce / clear-on-read. |
| `audio_lab_pynq/footswitch_control.py` | `FootswitchController`: FS1 toggles the bound effect through `EncoderEffectApplier.apply_effect_on_off`, FS2/FS3 step chain presets through `AudioLabOverlay.apply_chain_preset` and mirror the preset into compact-v2 `AppState`. Five FS1 stomps within 3 s rebind the target to the currently selected GUI effect. |
| `audio_lab_pynq/hdmi_effect_state_mirror.py` | One-way notebook -> overlay -> HDMI GUI state mirror plus the `HdmiEffectStateMirror` class. After the post-Phase-6I split (`DECISIONS.md` D26), this file is a thin re-export shim over `audio_lab_pynq/hdmi_state/`; the constant tables (pedal / amp / cab model names + labels + aliases, SELECTED FX categories, dropdown short labels), the normalisation helpers, the GUI knob layout, and the `ResourceSampler` live in per-effect submodules under `audio_lab_pynq/hdmi_state/`. Every external import path (`from audio_lab_pynq.hdmi_effect_state_mirror import X`) is preserved. |
| `audio_lab_pynq/hdmi_state/` | Per-effect / per-theme submodules used by `hdmi_effect_state_mirror`. `pedals.py` / `amps.py` / `cabs.py` carry the model names + labels + aliases for each category; `selected_fx.py` holds the SELECTED FX classification + dropdown chip plumbing; `knobs.py` holds `GUI_EFFECT_KNOBS` (the 8-slot per-effect knob layout); `resource_sampler.py` holds the `/proc`-based `ResourceSampler` + `STATIC_PL_UTILIZATION`; `common.py` holds the shared `_clamp_percent` / `_model_key` / `_normalize_index_or_name` helpers. |
| `audio_lab_pynq/notebooks/` | Jupyter notebooks installed onto the board. Includes the HDMI runtime entries `HdmiGui.ipynb` (live loop, resource monitor) and `HdmiGuiShow.ipynb` (one-shot single-cell renderer with `download=False` smart-attach so the rgb2dvi PLL at the Phase 6I `40 MHz` lower edge survives cell re-runs). Phase 7G+ adds `EncoderGuiSmoke.ipynb`. D49/D50 adds `PmodI2S2EffectControlOneCell.ipynb` (single-cell ipywidgets UI for Pmod mode 2) and `PmodI2S2HdmiGuiOneCell.ipynb` (spawns `scripts/run_encoder_hdmi_gui.py --pmod-mode dsp --wah-pedal`; footswitch polling is default-on). |
| `hw/ip/encoder_input/src/axi_encoder_input.v` | Verilog AXI-Lite slave for the Phase 7F rotary-encoder input IP (3 channels, 2-stage sync + debounce + quadrature decode + signed delta + event latch). Module-reference instantiated as `enc_in_0`. |
| `hw/ip/footswitch_input/src/axi_footswitch_input.v` | Verilog AXI-Lite slave for the D78 3-channel 3PDT footswitch input IP (2-stage sync + debounce + press-event latch on either debounced edge). Module-reference instantiated as `fsw_in_0`. |
| `hw/Pynq-Z2/encoder_integration.tcl` | Sourced after `hdmi_integration.tcl` to bump `ps7_0_axi_periph/NUM_MI` to 18, instantiate `axi_encoder_input` at `0x43D10000`, and wire the 9 RPi-header ports. |
| `scripts/run_encoder_hdmi_gui.py` | Standalone notebook-less Phase 7G+ runtime: AudioLabOverlay attach + HDMI backend start + EncoderInput + EncoderUiController + EncoderEffectApplier + FP02M pedal polling + footswitch polling + dirty-flag render loop. CLI flags `--live-apply` / `--no-live-apply` / `--apply-interval-ms` / `--value-step` / `--skip-rat` / `--include-rat` / `--no-audio-apply` / `--dry-run` / `--pmod-mode` / `--wah-pedal` / `--footswitch` / `--no-footswitch` / `--poll-hz-active` / `--poll-hz-idle` / `--idle-threshold-s` / `--max-render-fps` / `--status-interval-s` plus the `--reverse-encN` / `--swap-encN` / `--debounce-ms` encoder CONFIG overrides. |
| `scripts/test_pmod_i2s2.py` / `scripts/pmod_i2s2_mode.py` / `scripts/pmod_i2s2_capture_probe.py` | On-board Pmod I2S2 smoke/status helpers for modes `tone` / `loopback` / `dsp` / `mute`, MODE/CLEAR/status MMIO, and rolling ADC counter probes. |
| `GUI/pynq_multi_fx_gui.py` | 800x480 compact-v2 HDMI GUI renderer (`render_frame_800x480_compact_v2`). After the post-Phase-6I split (`DECISIONS.md` D26), this is a thin re-export shim over `GUI/compact_v2/`; the actual palette / themes / `AppState` / render functions / `hit_test_compact_v2` live in `GUI/compact_v2/{knobs,state,layout,renderer,hit_test}.py`. Every `from pynq_multi_fx_gui import X` import (including `AppState`, `EFFECT_KNOBS`, `render_frame_800x480_compact_v2`, `compact_v2_panel_boxes`, `hit_test_compact_v2`, etc.) keeps working unchanged. After the Phase 6H (1).py spec port (`d7ea0ab`), `EFFECT_KNOBS` is keyed by title-case `EFFECTS` names, `AppState` uses `all_knob_values`, and PEDAL / AMP / CAB draw the model dropdown inline. The 1280x720 reference renderer / Tk desktop preview / `run_pynq_hdmi()` were removed in `DECISIONS.md` D24. |
| `GUI/compact_v2/` | Per-theme split of the compact-v2 GUI: `knobs.py` (per-effect knob layout + model tables + chain preset names), `state.py` (`AppState` + `save_state_json` / `load_state_json`), `layout.py` (palette + themes + `COMPACT_V2_LAYOUT` + `compact_v2_panel_boxes`), `renderer.py` (NumPy / Pillow render primitives + `RenderCache` + every `render_frame_800x480_*` builder), `hit_test.py` (`hit_test_compact_v2`). |
| `GUI/audio_lab_gui_bridge.py` | Dry-run-first bridge from GUI `AppState` to existing `AudioLabOverlay` control APIs. |
| `scripts/deploy_to_pynq.sh` | One-shot deploy: rsync, install/refresh package, mirror bit/hwh into PYNQ overlays registry, install notebooks, import sanity check. |
| `scripts/audio_diagnostics.py` | CLI wrapper for diagnostics. |
| `scripts/test_hdmi_800x480_frame.py` | 5-inch LCD smoke: compact 800x480 GUI at framebuffer `x=0,y=0`. Originally written for the Phase 5C `1280x720` signal; the same script also works against the Phase 6I `800x600` SVGA framebuffer because the renderer still emits an 800x480 frame and the backend composes it at `(0,0)`. |
| `audio_lab_pynq/control_maps.py` | Pack / unpack / clamp helpers for AXI GPIO control words. Single source of truth for byte encoding. Per-effect word builders live here (`noise_suppressor_word` / `compressor_word` / `wah_word` / `reverb_word` / `eq_word` / `rat_word` / `cab_word`, D77); `guitar_effect_control_words` delegates to them. |
| `audio_lab_pynq/knob_tapers.py` | D80 Python-only control realism layer. Converts GUI / encoder / preset **physical knob positions** to the existing linear overlay percent API for gain/drive and tone-style knobs; level/mix/makeup/EQ stay linear. |
| `audio_lab_pynq/pmod_i2s2_status.py` | Single source for the `axi_pmod_i2s2_status` (`0x43D20000`) register map, the `MODE_INT` table (`tone`/`loopback`/`dsp`/`mute`), `sign24`, and `find_status_mmio(overlay=None)` IP discovery. Used by `pmod_i2s2_mode.py` and `run_encoder_hdmi_gui.py` (D77). |
| `audio_lab_pynq/effect_defaults.py` | Per-effect default parameter dicts (re-exported as `AudioLabOverlay.DISTORTION_DEFAULTS` etc.). |
| `audio_lab_pynq/effect_presets.py` | Notebook + API presets (Noise Suppressor / Distortion / Safe Bypass / Chain Presets). D80 values are user-facing knob positions; write paths taper them at the boundary. |
| `tests/` | Local Python tests for the control layer. The earlier C++ DSP prototypes were removed; the source of truth for DSP is `hw/ip/clash/src/LowPassFir.hs`. |

## Operational facts

- ADAU1761 ADC digital HPF is enabled by default in `config_codec()`.
  After init, `R19_ADC_CONTROL == 0x23`. The HPF is a ~2 Hz DC blocker, not
  a 20–40 Hz guitar low-cut.
- Current deployed audio I/O is Pmod I2S2 mode 2, not the onboard ADAU
  analog path. `pmod_i2s2_integration.tcl` deletes the old `bclk_1` /
  `lrclk_1` / `sdata_i_1` loads and drives `i2s_to_stream_0` from
  `pmod_master_0/dsp_bclk_o`, `pmod_master_0/dsp_lrck_o`, and
  `ext_pmod_i2s2_ad_sdout_i`. `i2s_to_stream_0/so` feeds
  `pmod_master_0/dsp_dac_sdin_i` and still fans out to ADAU `sdata_o`
  G18 for debug visibility. Mode 2 output is mono RIGHT-to-both-channels
  via `mode2_right_snapshot` (D50).
- The current accepted deployed bitstream baseline is **D79**
  (`audio_lab.bit` md5 `f0cb0276f27187d72476a2e773dd9a6e`, `.hwh`
  `5fa0b84e9fe852c68629c651f94e4a9d`). It keeps the D75 50 MHz DSP
  island, D76 FP02M XADC path, and D78 footswitch IP, then adds D79
  Overdrive model-realism changes. Routed island WNS is `-0.496 ns`;
  the 100 MHz audio fabric is clean at `+0.532 ns / 0 fail`; user bench
  confirmed all_off clean / no bitcrusher.
- The DSP runs in a **50 MHz clock-domain island** (D75). Only
  `clash_lowpass_fir_0` is clocked by `FCLK_CLK1 = 50 MHz`; the rest of the
  fabric (AXI / DMA / `i2s_to_stream` / Pmod / HDMI) stays on
  `FCLK_CLK0 = 100 MHz`, bridged by two `axis_clock_converter`
  (`cc_dsp_in` / `cc_dsp_out`) added in `island_integration.tcl`. The 50 MHz
  island is what closed the DS-1 distortion timing (WNS -10.387 -> -0.706 ns
  at D75; -0.368 ns at D76; -0.173 ns at D78 with phys_opt; -0.496 ns at
  D79 after Klon clean-blend). Sample rate is 48 kHz. The control-word CDC
  (`syncCtrl` in `LowPassFir.hs`) and `paceCount` removal in `Pipeline.hs`
  are load-bearing -- see `DSP_ISLAND_CLOCK_DESIGN.md` and `DECISIONS.md` D75.
- The Overdrive section has six selectable models on
  `axi_gpio_overdrive.ctrlD[2:0]`. D79 makes clip hardness model-specific
  (`asymSoftClipSoft` / legacy medium / `asymSoftClipMed` / hard sibling)
  and gives model 5 (CENTAUR/Klon) a parallel clean-blend in the level stage.
  No GPIO, API, `topEntity`, or `block_design.tcl` change.
- The distortion section is built on a **pedal-mask design** (commit
  `baa97ff`, with the reserved-pedal implementation landed on
  `feature/add-reserved-distortion-pedals`, commit `c8f8d8c`).
  `gate_control` bit 2 is the section master; each bit of
  `distortion_control.ctrlD` enables one pedal. `clean_boost`,
  `tube_screamer`, `ds1`, `big_muff`, `fuzz_face`, and `metal` are
  implemented in Clash; `rat` maps onto the existing RAT stage. Bit 7
  remains the only reserved pedal slot. See
  `DISTORTION_REFACTOR_PLAN.md` and `DECISIONS.md` D6 / D9.
- The noise stage is a **BOSS NS-2 / NS-1X-style noise suppressor** on
  a dedicated `axi_gpio_noise_suppressor` IP at `0x43CC0000` (branch
  `feature/noise-suppressor-gpio-ui`). THRESHOLD / DECAY / DAMP / mode
  bytes drive an envelope follower + smoothed-gain block in Clash;
  the legacy hard noise gate is replaced. Enable still rides on
  `gate_control` bit 0 (`noise_gate_on`). RNNoise / FFT / spectral
  methods are intentionally **not** used. See
  `DSP_EFFECT_CHAIN.md` Noise Suppressor section and `DECISIONS.md`
  D11.
- The Wah is a **Cry Baby GCB-95-style resonant band-pass** on a dedicated
  `axi_gpio_wah` IP at `0x43D30000` (D72; retuned in D73). POSITION / Q /
  VOLUME ride `ctrlA..C`; `ctrlD` bit 7 is the enable and bits[6:0] are
  BIAS. It sits between the Compressor and the Overdrive in the Clash
  pipeline. The chain is now 9 GUI effects: Noise Suppressor -> Compressor
  -> Wah -> Overdrive -> Distortion -> RAT/Pedals -> Amp -> Cab -> EQ ->
  Reverb. See `WAH_EFFECT_INTEGRATION_PLAN.md` and `DECISIONS.md` D72 / D73.
- The **ZOOM FP02M expression pedal** can drive Wah POSITION (D76). It is
  read from Arduino A0 = XADC VAUX1 through the `xadc_wiz_a0` Wizard
  (`0x43D40000`) via **AXI MMIO** (register `0x244`), mapped by
  `audio_lab_pynq/fp02m.py`. The pedal is the sole `position_raw` writer;
  Q / VOLUME / BIAS stay GUI / encoder driven. Calibration lives at
  `/root/.config/audio_lab/fp02m_calibration.json` on the board. See
  `FP02M_PEDAL_INTEGRATION.md`, `XADC_INTEGRATION_DESIGN.md`, `DECISIONS.md` D76.
- The **3PDT footswitch path** is live in the D78+ bitstream. Three latching
  footswitches on RP pins 11 / 12 / 35 feed `axi_footswitch_input`
  (`0x43D50000`): FS1 toggles the bound GUI effect, FS2 advances the chain
  preset, and FS3 steps back. The IP lives on the 100 MHz fabric and was
  added by `footswitch_integration.tcl`; `block_design.tcl` is not edited.
- AXI GPIOs in the design are output-only; the Python side keeps a cache
  of the last word written to each GPIO so that read-modify-write on
  byte-fields is possible.
- PYNQ-Z2 board is reachable on the lab LAN at **192.168.1.9**, user
  `xilinx`, with passwordless `sudo` and SSH key auth set up.
- The integrated HDMI GUI path uses VESA SVGA `800x600 @ 60 Hz /
  40 MHz` in the deployed `audio_lab.bit` (Phase 6I, `DECISIONS.md`
  D25). `audio_lab_pynq/hdmi_backend.py` defaults to `DEFAULT_WIDTH=800`,
  `DEFAULT_HEIGHT=600`. The 800x480 compact-v2 GUI composes at
  framebuffer `(0,0)` so visible rows `0..479` carry the UI and rows
  `480..599` stay black. Earlier Phase 5A/5C established the
  `1280x720` baseline with the same top-left `x=0,y=0,w=800,h=480`
  visible region; Phase 6I replaced the on-the-wire signal while
  keeping that visible-region convention. Do not use
  `Overlay("base.bit")` or `run_pynq_hdmi()` for live AudioLab HDMI.
- Deploy target on the board:
  - Repo / package source: `/home/xilinx/Audio-Lab-PYNQ/`
  - Notebooks (Jupyter root): `/home/xilinx/jupyter_notebooks/audio_lab/`
  - Jupyter URL: `http://192.168.1.9:9090/tree`
- Notebooks shipped with the pedal-mask build:
  `InputDebug.ipynb`, `GuitarEffectsChain.ipynb`,
  `GuitarEffectSwitcher.ipynb` (now with a Distortion Pedalboard
  section), `DistortionModelsDebug.ipynb` (rewritten for the
  pedal-mask API), and `GuitarPedalboardOneCell.ipynb` (new — a
  one-cell ipywidgets UI for the whole chain).
- The old untracked `HDMI/` experiment tree was removed after repo-wide
  reference checks showed it was not used by the current deploy,
  tests, or HDMI runtime scripts. The active GUI code is `GUI/`.

## Key principles for new work

- **GPIO design is fixed.** The address map and the per-byte / per-bit
  meaning in `GPIO_CONTROL_MAP.md` is treated as a contract. New
  effects land on documented `reserved` slots; renaming or moving
  bytes is forbidden. See `DECISIONS.md` D12.
- Reuse the existing AXI GPIO topology by claiming spare bytes / bits.
  Adding a new `axi_gpio_*` IP requires a `block_design.tcl` change and
  is off the table by default. Shipped exceptions are documented by ADR:
  `axi_gpio_noise_suppressor` (D11), `axi_gpio_compressor` (D14),
  `axi_gpio_wah` (D72), `xadc_wiz_a0` (D76), and
  `axi_footswitch_input` (D78). The additive-IP pattern is to source a
  dedicated `*_integration.tcl` from `create_project.tcl` and leave
  `block_design.tcl` byte-for-byte unchanged.
- The single source of truth for DSP behaviour is
  `hw/ip/clash/src/LowPassFir.hs`. The earlier C++ prototypes under
  `src/effects/` were removed (`DECISIONS.md` D13); new effect work
  goes Python API + UI reservation -> Clash stage -> (rare) new GPIO.
- Never break the bit-bypass property: every effect stage must produce
  output equal to its input when its enable bit is clear, sample-exact.
- The current Vivado build already runs with negative slack
  (see `TIMING_AND_FPGA_NOTES.md`; D79 WNS `-0.496 ns`), so new logic must
  be carefully pipelined and bench-listened for bypass artifacts.
- Read [`EFFECT_ADDING_GUIDE.md`](EFFECT_ADDING_GUIDE.md) before
  touching `LowPassFir.hs`, `block_design.tcl`, or any
  `axi_gpio_*` topology.
