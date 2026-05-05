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
| `audio_lab_pynq/notebooks/` | Jupyter notebooks installed onto the board. |
| `scripts/deploy_to_pynq.sh` | One-shot deploy: rsync, install package, install notebooks. |
| `scripts/audio_diagnostics.py` | CLI wrapper for diagnostics. |
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
  `baa97ff`). `gate_control` bit 2 is the section master; each bit of
  `distortion_control.ctrlD` enables one pedal. `clean_boost`,
  `tube_screamer`, `metal` are implemented in Clash; `rat` maps onto
  the existing RAT stage; `ds1`, `big_muff`, `fuzz_face` are reserved
  bits with no FPGA stage yet. See `DISTORTION_REFACTOR_PLAN.md`.
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
- PYNQ-Z2 board is reachable on the lab LAN at **192.168.1.8**, user
  `xilinx`, with passwordless `sudo` and SSH key auth set up.
- Deploy target on the board:
  - Repo / package source: `/home/xilinx/Audio-Lab-PYNQ/`
  - Notebooks (Jupyter root): `/home/xilinx/jupyter_notebooks/audio_lab/`
  - Jupyter URL: `http://192.168.1.8:9090/tree`
- Notebooks shipped with the pedal-mask build:
  `InputDebug.ipynb`, `GuitarEffectsChain.ipynb`,
  `GuitarEffectSwitcher.ipynb` (now with a Distortion Pedalboard
  section), `DistortionModelsDebug.ipynb` (rewritten for the
  pedal-mask API), and `GuitarPedalboardOneCell.ipynb` (new — a
  one-cell ipywidgets UI for the whole chain).

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
