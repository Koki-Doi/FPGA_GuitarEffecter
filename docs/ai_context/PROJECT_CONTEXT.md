# Project context

## What this repository is

Audio-Lab-PYNQ (a.k.a. FPGA_GuitarEffecter) is a real-time guitar effect
chain. A guitar plugged into the Line-in jack of a PYNQ-Z2 board is digitised
by the ADAU1761 codec, processed in the Zynq-7000 PL by a Clash-generated
DSP block, and returned to the same codec for headphone / line output. The
PS-side Python and Jupyter layers route audio, configure the codec, and
control effect parameters via AXI GPIO.

## Toolchain

| Component | Version |
| --- | --- |
| Vivado | 2019.1 |
| Clash | 1.8.1 (clash-prelude pinned to the matching package id) |
| GHC | 8.10.7 |
| PYNQ image | 2020.1 series, Python 3.6 |
| Board | PYNQ-Z2 (xc7z020clg400-1, ADAU1761 codec) |

## Top-level layout

| Path | Role |
| --- | --- |
| `hw/Pynq-Z2/block_design.tcl` | Vivado block design (off-limits unless the user explicitly approves edits). |
| `hw/Pynq-Z2/audio_lab.xdc` | Pin / clock constraints. |
| `hw/Pynq-Z2/create_project.tcl` | Vivado batch entry point. |
| `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` | Built artefacts shipped to PYNQ. |
| `hw/ip/clash/src/LowPassFir.hs` | The full PL DSP pipeline. Real source of truth for every effect. |
| `hw/ip/clash/vhdl/LowPassFir/` | Clash-generated VHDL plus packaged Vivado IP. |
| `hw/ip/fx_gain/` | Legacy HLS gain IP (instantiated but not stream-connected). |
| `audio_lab_pynq/AudioLabOverlay.py` | Python facade: overlay loading, AXIS routing, GPIO writes. |
| `audio_lab_pynq/AudioCodec.py` | ADAU1761 register driver and config sequence. |
| `audio_lab_pynq/diagnostics.py` | Phase-1 input/output diagnostics. |
| `audio_lab_pynq/hdmi_backend.py` | Direct MMIO HDMI framebuffer backend for the integrated AudioLab HDMI path; avoids PYNQ's base-overlay video driver. |
| `audio_lab_pynq/encoder_input.py` | Low-level driver for the Phase 7F `axi_encoder_input` PL IP (3 rotary encoders, `enc_in_0/s_axi` at `0x43D10000`). Decodes `STATUS` / `DELTA_PACKED` / `COUNT*` into `EncoderEvent` instances and exposes `configure(...)` for debounce / reverse / swap. PYNQ Python 3.6-safe (no dataclasses / future annotations). |
| `audio_lab_pynq/encoder_ui.py` | `EncoderUiController` maps `EncoderEvent` instances into compact-v2 `AppState` mutations. Phase 7G+ adds the `applier=` / `live_apply=` / `skip_rat=` kwargs so encoder 1 short flips the effect, encoder 1 long calls safe-bypass, encoder 3 rotate runs a throttled apply, and encoder 3 short always force-applies. Legacy `mirror=` / `bridge=` fall-through is preserved when no applier is supplied. |
| `audio_lab_pynq/encoder_effect_apply.py` | Phase 7G+ `EncoderEffectApplier`: the only Python object allowed to translate compact-v2 `AppState` into `AudioLabOverlay` writes from the encoder runtime. Uses `set_noise_suppressor_settings`, `set_compressor_settings`, and `set_guitar_effects(**kwargs)` only — no raw GPIO writes. Default throttle 100 ms; `skip_rat=True` excludes pedal-mask bit 2 from cycling / live apply. Tracks `apply_count` / `error_count` / `last_apply_ok` / `last_apply_message` / `unsupported` for the GUI status strip and resource print. See `DECISIONS.md` D37. |
| `audio_lab_pynq/hdmi_effect_state_mirror.py` | One-way notebook -> overlay -> HDMI GUI state mirror plus the `HdmiEffectStateMirror` class. After the post-Phase-6I split (`DECISIONS.md` D26), this file is a thin re-export shim over `audio_lab_pynq/hdmi_state/`; the constant tables (pedal / amp / cab model names + labels + aliases, SELECTED FX categories, dropdown short labels), the normalisation helpers, the GUI knob layout, and the `ResourceSampler` live in per-effect submodules under `audio_lab_pynq/hdmi_state/`. Every external import path (`from audio_lab_pynq.hdmi_effect_state_mirror import X`) is preserved. |
| `audio_lab_pynq/hdmi_state/` | Per-effect / per-theme submodules used by `hdmi_effect_state_mirror`. `pedals.py` / `amps.py` / `cabs.py` carry the model names + labels + aliases for each category; `selected_fx.py` holds the SELECTED FX classification + dropdown chip plumbing; `knobs.py` holds `GUI_EFFECT_KNOBS` (the 8-slot per-effect knob layout); `resource_sampler.py` holds the `/proc`-based `ResourceSampler` + `STATIC_PL_UTILIZATION`; `common.py` holds the shared `_clamp_percent` / `_model_key` / `_normalize_index_or_name` helpers. |
| `audio_lab_pynq/notebooks/` | Jupyter notebooks installed onto the board. Includes the HDMI runtime entries `HdmiGui.ipynb` (live loop, resource monitor) and `HdmiGuiShow.ipynb` (one-shot single-cell renderer with `download=False` smart-attach so the rgb2dvi PLL at the Phase 6I `40 MHz` lower edge survives cell re-runs). Phase 7G+ adds `EncoderGuiSmoke.ipynb` (single-cell dirty-flag loop with live apply + resource monitor, RAT excluded by default). |
| `hw/ip/encoder_input/src/axi_encoder_input.v` | Verilog AXI-Lite slave for the Phase 7F rotary-encoder input IP (3 channels, 2-stage sync + debounce + quadrature decode + signed delta + event latch). Module-reference instantiated as `enc_in_0`. |
| `hw/Pynq-Z2/encoder_integration.tcl` | Sourced after `hdmi_integration.tcl` to bump `ps7_0_axi_periph/NUM_MI` to 18, instantiate `axi_encoder_input` at `0x43D10000`, and wire the 9 RPi-header ports. |
| `scripts/run_encoder_hdmi_gui.py` | Standalone notebook-less Phase 7G+ runtime: AudioLabOverlay attach + HDMI backend start + EncoderInput + EncoderUiController + EncoderEffectApplier + dirty-flag render loop. CLI flags `--live-apply` / `--no-live-apply` / `--apply-interval-ms` / `--value-step` / `--skip-rat` / `--include-rat` / `--no-audio-apply` / `--dry-run` / `--poll-hz-active` / `--poll-hz-idle` / `--idle-threshold-s` / `--max-render-fps` / `--status-interval-s` plus the `--reverse-encN` / `--swap-encN` / `--debounce-ms` encoder CONFIG overrides. |
| `GUI/pynq_multi_fx_gui.py` | 800x480 compact-v2 HDMI GUI renderer (`render_frame_800x480_compact_v2`). After the post-Phase-6I split (`DECISIONS.md` D26), this is a thin re-export shim over `GUI/compact_v2/`; the actual palette / themes / `AppState` / render functions / `hit_test_compact_v2` live in `GUI/compact_v2/{knobs,state,layout,renderer,hit_test}.py`. Every `from pynq_multi_fx_gui import X` import (including `AppState`, `EFFECT_KNOBS`, `render_frame_800x480_compact_v2`, `compact_v2_panel_boxes`, `hit_test_compact_v2`, etc.) keeps working unchanged. After the Phase 6H (1).py spec port (`d7ea0ab`), `EFFECT_KNOBS` is keyed by title-case `EFFECTS` names, `AppState` uses `all_knob_values`, and PEDAL / AMP / CAB draw the model dropdown inline. The 1280x720 reference renderer / Tk desktop preview / `run_pynq_hdmi()` were removed in `DECISIONS.md` D24. |
| `GUI/compact_v2/` | Per-theme split of the compact-v2 GUI: `knobs.py` (per-effect knob layout + model tables + chain preset names), `state.py` (`AppState` + `save_state_json` / `load_state_json`), `layout.py` (palette + themes + `COMPACT_V2_LAYOUT` + `compact_v2_panel_boxes`), `renderer.py` (NumPy / Pillow render primitives + `RenderCache` + every `render_frame_800x480_*` builder), `hit_test.py` (`hit_test_compact_v2`). |
| `GUI/audio_lab_gui_bridge.py` | Dry-run-first bridge from GUI `AppState` to existing `AudioLabOverlay` control APIs. |
| `scripts/deploy_to_pynq.sh` | One-shot deploy: rsync, install package, install notebooks. |
| `scripts/audio_diagnostics.py` | CLI wrapper for diagnostics. |
| `scripts/test_hdmi_800x480_frame.py` | 5-inch LCD smoke: compact 800x480 GUI at framebuffer `x=0,y=0`. Originally written for the Phase 5C `1280x720` signal; the same script also works against the Phase 6I `800x600` SVGA framebuffer because the renderer still emits an 800x480 frame and the backend composes it at `(0,0)`. |
| `audio_lab_pynq/control_maps.py` | Pack / unpack / clamp helpers for AXI GPIO control words. Single source of truth for byte encoding. |
| `audio_lab_pynq/effect_defaults.py` | Per-effect default parameter dicts (re-exported as `AudioLabOverlay.DISTORTION_DEFAULTS` etc.). |
| `audio_lab_pynq/effect_presets.py` | Notebook + API presets (Noise Suppressor / Distortion / Safe Bypass). |
| `tests/` | Local Python tests for the control layer. The earlier C++ DSP prototypes were removed; the source of truth for DSP is `hw/ip/clash/src/LowPassFir.hs`. |

## Operational facts

- ADAU1761 ADC digital HPF is enabled by default in `config_codec()`.
  After init, `R19_ADC_CONTROL == 0x23`. The HPF is a ~2 Hz DC blocker, not
  a 20–40 Hz guitar low-cut.
- The DSP pipeline runs on the FCLK0 100 MHz domain (`AudioDomain` in
  Clash). Sample rate is 48 kHz, so the PL has ~2080 clock cycles per
  audio frame for a single channel pair.
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
  is off the table by default. The noise-suppressor work
  (`axi_gpio_noise_suppressor`) is the one shipped exception, approved
  case-by-case; see `DECISIONS.md` D11 and `BUILD_AND_DEPLOY.md` for
  the recipe.
- The single source of truth for DSP behaviour is
  `hw/ip/clash/src/LowPassFir.hs`. The earlier C++ prototypes under
  `src/effects/` were removed (`DECISIONS.md` D13); new effect work
  goes Python API + UI reservation -> Clash stage -> (rare) new GPIO.
- Never break the bit-bypass property: every effect stage must produce
  output equal to its input when its enable bit is clear, sample-exact.
- The current Vivado build already runs with negative slack
  (see `TIMING_AND_FPGA_NOTES.md`); new logic must be carefully
  pipelined so it does not make timing dramatically worse.
- Read [`EFFECT_ADDING_GUIDE.md`](EFFECT_ADDING_GUIDE.md) before
  touching `LowPassFir.hs`, `block_design.tcl`, or any
  `axi_gpio_*` topology.
