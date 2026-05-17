# Encoder input implementation (Phase 7F/7G)

Concrete notes for the rotary-encoder PL IP + Python control layer
implemented for Phase 7F (PL) and Phase 7G (PS) of FPGA_GuitarEffecter.
Register-level details are in
[`ENCODER_INPUT_MAP.md`](ENCODER_INPUT_MAP.md); pin choices are in
[`IO_PIN_RESERVATION.md`](IO_PIN_RESERVATION.md).

## Why this design

* `DECISIONS.md` D30: PS-side polling of CLK/DT/SW would drop edges and
  CPU-burn the Jupyter kernel. The PL handles 2-stage sync + debounce +
  quadrature decode + signed delta + event latch; the PS only reads
  decoded results.
* `DECISIONS.md` D32: HDMI VDMA (`0x43CE0000`) and VTC (`0x43CF0000`)
  must not be reused. The encoder IP lives at `0x43D10000`, after
  skipping `0x43D00000` which is reserved for a possible HDMI / rgb2dvi
  control surface.
* `DECISIONS.md` D33 (new): the encoder IP is a separate AXI-Lite slave
  rather than another `axi_gpio_*`. AXI GPIO would force CLK/DT/SW to
  be read raw, defeating the whole point of doing PL-side debounce; and
  reuse of any existing `axi_gpio_*` byte would break the
  `GPIO_CONTROL_MAP.md` ledger.
* `DECISIONS.md` D34 (new): PMOD JB and PMOD JA stay reserved for the
  planned PCM1808 / PCM5102 external codec path. Encoders land on the
  Raspberry Pi header pins that do **not** physically share with PMOD
  JA (`raspberry_pi_tri_i_6..14`).

## Hardware

| Logical | Pin | RPi GPIO index | Module silk |
| --- | --- | --- | --- |
| `enc0_clk_i` | `F19` | `raspberry_pi_tri_i_6` | enc0 CLK |
| `enc0_dt_i`  | `V10` | `raspberry_pi_tri_i_7` | enc0 DT |
| `enc0_sw_i`  | `V8`  | `raspberry_pi_tri_i_8` | enc0 SW |
| `enc1_clk_i` | `W10` | `raspberry_pi_tri_i_9` | enc1 CLK |
| `enc1_dt_i`  | `B20` | `raspberry_pi_tri_i_10`| enc1 DT |
| `enc1_sw_i`  | `W8`  | `raspberry_pi_tri_i_11`| enc1 SW |
| `enc2_clk_i` | `V6`  | `raspberry_pi_tri_i_12`| enc2 CLK |
| `enc2_dt_i`  | `Y6`  | `raspberry_pi_tri_i_13`| enc2 DT |
| `enc2_sw_i`  | `B19` | `raspberry_pi_tri_i_14`| enc2 SW |

All nine are `LVCMOS33`. Each module's `+` pin is wired to the
PYNQ-Z2 **3.3V** rail (never 5V — `DECISIONS.md` D31 spells out the
PL-pin damage risk).

## Block design changes (incremental)

* `hw/Pynq-Z2/encoder_integration.tcl` (new) is sourced from
  `create_project.tcl` after `hdmi_integration.tcl`. It:
  1. Bumps `ps7_0_axi_periph/NUM_MI` from 17 to 18.
  2. Adds 9 top-level input ports.
  3. Adds `enc_in_0` as a Verilog **module reference** to
     `axi_encoder_input` (no IP packaging needed).
  4. Wires AXI-Lite from `M17`, clock from `FCLK_CLK0`, reset from
     `rst_ps7_0_100M/peripheral_aresetn`.
  5. Wires the 9 top-level ports to the IP inputs.
  6. Creates an address segment at `0x43D10000 / 0x10000`.
* `hw/Pynq-Z2/create_project.tcl` adds the Verilog source up-front
  (before `block_design.tcl`) via `add_files -norecurse` so the
  module-reference cell in step 5 resolves.
* `hw/Pynq-Z2/audio_lab.xdc` adds the 9 LVCMOS33 PACKAGE_PIN +
  IOSTANDARD entries listed above. PMOD JB / PMOD JA / HDMI / ADAU1761
  pins are untouched.
* `hw/Pynq-Z2/block_design.tcl`, `hw/Pynq-Z2/hdmi_integration.tcl`,
  `hw/ip/clash/src/LowPassFir.hs`, and `docs/ai_context/GPIO_CONTROL_MAP.md`
  are **not changed** by this work.

## RTL

`hw/ip/encoder_input/src/axi_encoder_input.v` is one self-contained
Verilog file with:

* 1 ms tick derived from the 100 MHz AXI clock (`/100,000`).
* Per channel: 2-stage synchroniser → debounce counter
  (`CONFIG.debounce_ms` × 1 ms-tick consecutive stable samples) →
  quadrature transition table → signed delta (s8 saturating) +
  absolute s32 counter + event latch.
* Per channel switch path: active-low normalisation (`sw_active_low`),
  rising-edge starts a press timer, falling-edge fires `short_press`
  if no `long_press` already fired, `long_press` fires when the timer
  reaches 500 ms.
* AXI4-Lite slave with reads on `STATUS`/`DELTA_PACKED`/`COUNT[012]`/
  `BUTTON_STATE`/`CONFIG`/`VERSION` and writes on `CONFIG`/
  `CLEAR_EVENTS`. Clear-on-read pulses are OR'd with explicit CLEAR
  writes (single sink for each rotate/short/long clear request).

## Python layer

* `audio_lab_pynq/encoder_input.py` — low-level. `EncoderInput`
  exposes register accessors plus a `poll()` that returns
  `EncoderEvent` instances. `EDGES_PER_DETENT = 4` and carry-on-poll
  means typical detented encoders emit one rotate event per click.
* `audio_lab_pynq/encoder_ui.py` —
  `EncoderUiController.handle_event()` maps events into AppState. It
  *never* writes a raw effect GPIO; `apply()` uses a dry-run/test mirror
  when one is supplied, otherwise falls back to `GUI/audio_lab_gui_bridge.py`
  and pushes state into `AudioLabOverlay.set_*` public APIs through the
  existing bridge.
* `GUI/compact_v2/state.py` — eight new `AppState` fields, all
  defaulted; `save_state_json` deliberately does **not** persist them.
* `GUI/compact_v2/renderer.py` — small status strip in the bottom-right
  of the 800×480 frame. The chain panel already highlights
  `selected_effect` so encoder 1 rotation is visible; the FX panel
  already highlights `selected_knob` so encoder 2 rotation is visible.

## Standalone runtime

`scripts/run_encoder_hdmi_gui.py` is a notebook-less Pip-Boy GUI loop:

```
sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
    scripts/run_encoder_hdmi_gui.py --fps 5
```

It loads `AudioLabOverlay`, starts the HDMI back end at 800×600,
builds AppState, creates the bridge-backed encoder controller,
attaches `EncoderInput`,
and runs a tight loop:

```
encoder.poll() -> EncoderUiController.handle_events(...)
                  -> AppState mutation
render_frame_800x480_compact_v2(state) -> backend.write_frame(...)
```

CLI flags include `--reverse-encN` / `--swap-encN` / `--debounce-ms`
to drive `CONFIG` without recompiling.

## Tests

| File | Scope |
| --- | --- |
| `tests/test_encoder_input_decode.py` | s8/s32 sign-extend, DELTA unpack, STATUS decode, `configure()` round-trip, `clear_events()` word, partial-edge carry, short/long press, synthetic release. |
| `tests/test_encoder_ui_controller.py` | enc1 rotate selects effect, enc1 short toggles `effect_on`, enc1 long safe-bypass round-trip, enc2 model-select toggle, enc3 value change + clamp, enc3 short triggers mirror or bridge apply. |
| `tests/test_compact_v2_encoder_state.py` | New AppState fields default, JSON round-trip ignores Phase 7G fields, renderer still produces an 800×480 frame with the new flags. |
| `scripts/test_encoder_input.py` | On-board manual smoke. |
| `scripts/test_hdmi_encoder_gui_control.py` | On-board GUI smoke with scripted or live events. |

Offline verification on the development host uses `python3 -m unittest`
because `pytest` is not required in this repository:

```
python3 -m unittest -v \
  tests.test_encoder_input_decode \
  tests.test_encoder_ui_controller \
  tests.test_compact_v2_encoder_state
```

The current Phase 7F/7G test set has 29 tests across those three files.

## Build result

The accepted local build is build3:

* Log:
  `/tmp/fpga_guitar_effecter_backup/phase7f7g_vivado_build3.log`.
* Result: `write_bitstream completed successfully`; local
  `hw/Pynq-Z2/bitstreams/audio_lab.bit` / `audio_lab.hwh` regenerated.
* Final routed timing: WNS `-8.395 ns`, TNS `-6609.224 ns`,
  WHS `+0.052 ns`, THS `0.000 ns`.
* Utilization after place: Slice LUTs `19095 (35.89%)`, Slice
  Registers `21259 (19.98%)`, Block RAM Tile `9 (6.43%)`,
  DSPs `83 (37.73%)`.
* HWH contains `enc_in_0` / `axi_encoder_input` at
  `0x43D10000..0x43D1FFFF`. HDMI VDMA/VTC remain at
  `0x43CE0000` / `0x43CF0000`, and existing effect GPIO addresses are
  unchanged.
* PYNQ deploy and physical encoder smoke are deferred until the three
  encoder modules are wired. A HWH/ip_dict presence check is not a
  substitute for physical rotate / press smoke (`DECISIONS.md` D35).

## Rollback

* `git checkout main -- hw/Pynq-Z2/audio_lab.xdc hw/Pynq-Z2/create_project.tcl`
  + delete `hw/Pynq-Z2/encoder_integration.tcl` to revert the build.
* Pre-build baseline bit/hwh is in
  `/tmp/fpga_guitar_effecter_backup/phase7f7g_baseline_bit/`.
* Pre-change Python state lives at
  `/tmp/fpga_guitar_effecter_backup/phase7f7g_before_encoder_impl.patch`.
* This work landed on the `feature/rotary-encoder-hdmi-gui-control`
  branch — `git switch main` returns to the Phase 7B head.

## Risks called out

* The encoder IP adds an AXI peripheral and an interconnect master
  port. Vivado timing is reviewed in the build report (see
  `CURRENT_STATE.md` and `TIMING_AND_FPGA_NOTES.md`); a regression
  beyond the historical `-7..-9 ns` deploy band is a hard stop.
* The encoder pins are 3.3V LVCMOS33; **never** wire the module `+` pin
  to 5V (would lift onboard pull-ups onto PL pins — likely PL damage,
  `DECISIONS.md` D31).
* The Verilog module reference flow needs the source file added to
  `sources_1` before `block_design.tcl` runs. `create_project.tcl` does
  this with a fixed `add_files` + `update_compile_order`.
