# Encoder input AXI register map

The Phase 7F/7G rotary-encoder PL IP lives **outside** the existing
`GPIO_CONTROL_MAP.md` contract: that file is the effect-output ledger
(every byte the Clash DSP consumes). The encoder IP is an **input** path
whose layout is event/delta-oriented, not the 4×byte `ctrlA..D`
unpacking used everywhere else. Keeping it on its own page avoids
confusion and protects the existing effect map from accidental drift
(`DECISIONS.md` D12 / D33).

Phase 7G+ (`DECISIONS.md` D37) adds a Python-only translation layer
(`audio_lab_pynq/encoder_effect_apply.py::EncoderEffectApplier`) that
converts decoded `EncoderEvent` instances into `AudioLabOverlay` public
setters. This file (register map) is unchanged by Phase 7G+; the
PS-side flow + GUI behaviour are documented in
[`ENCODER_INPUT_IMPLEMENTATION.md`](ENCODER_INPUT_IMPLEMENTATION.md)
and [`ENCODER_GUI_CONTROL_SPEC.md`](ENCODER_GUI_CONTROL_SPEC.md).

## IP basics

| Item | Value |
| --- | --- |
| Module | `axi_encoder_input` (Verilog, `hw/ip/encoder_input/src/axi_encoder_input.v`) |
| BD instance | `enc_in_0` (module reference) |
| AXI | AXI4-Lite slave, 32-bit data, 6-bit address |
| Base address | **`0x43D10000`**, size `0x10000` |
| Clock domain | `processing_system7_0/FCLK_CLK0` (100 MHz) |
| Reset | `rst_ps7_0_100M/peripheral_aresetn` |
| ps7_0_axi_periph | M17 (HDMI VDMA M15, HDMI VTC M16, encoder M17 — `NUM_MI=18`) |
| Top-level ports | `enc{0,1,2}_clk_i / dt_i / sw_i` (9 LVCMOS33 inputs on the RPi header) |

### Forbidden addresses (do not reuse)

| Range | Owner |
| --- | --- |
| `0x43C00000..0x43CD0000` | existing audio IPs (see `GPIO_CONTROL_MAP.md`) |
| `0x43CE0000` | `axi_vdma_hdmi` |
| `0x43CF0000` | `v_tc_hdmi` |
| `0x43D00000` | reserved for a future HDMI / rgb2dvi control surface |
| `0x43D10000` | **this IP** |

## Register table

| Offset | Name | Access | Layout |
| --- | --- | --- | --- |
| `0x00` | `STATUS` | R | bits[2:0]=rotate_event, bits[10:8]=short_press, bits[18:16]=long_press, bits[26:24]=sw_level (1 = pressed under default `sw_active_low`) |
| `0x04` | `DELTA_PACKED` | R (clear-on-read) | bits[7:0]=enc0 s8, bits[15:8]=enc1 s8, bits[23:16]=enc2 s8 |
| `0x08` | `COUNT0` | R | signed int32 absolute count, encoder 0 |
| `0x0C` | `COUNT1` | R | signed int32 absolute count, encoder 1 |
| `0x10` | `COUNT2` | R | signed int32 absolute count, encoder 2 |
| `0x14` | `BUTTON_STATE` | R | bits[2:0]=debounced SW level (same as `STATUS[26:24]`) |
| `0x18` | `CONFIG` | R/W | see below |
| `0x1C` | `CLEAR_EVENTS` | W | write 1 to STATUS bit positions to clear (bits[2:0] also clears DELTA) |
| `0x20` | `VERSION` | R | `0x00070001` |

### CONFIG bits

| Bit(s) | Field | Default | Meaning |
| --- | --- | --- | --- |
| `[7:0]` | `debounce_ms` | `5` | Consecutive 1 ms-tick samples required for the debounced signal to switch (1..255). |
| `[8]` | `clear_on_read_enable` | `1` | Reading `STATUS` clears all rotate/short/long latches; reading `DELTA_PACKED` clears all rotate latches and resets the accumulator. |
| `[9]` | `acceleration_enable` | `0` | Reserved; ignored in v1. |
| `[10]` | `enc0_reverse_direction` | `0` | Negate quadrature step for encoder 0. |
| `[11]` | `enc1_reverse_direction` | `0` | Same for encoder 1. |
| `[12]` | `enc2_reverse_direction` | `0` | Same for encoder 2. |
| `[13]` | `enc0_clk_dt_swap` | `0` | Internally swap A (CLK) and B (DT) for encoder 0 — corrects mirrored wiring without rerouting the cable. |
| `[14]` | `enc1_clk_dt_swap` | `0` | Same for encoder 1. |
| `[15]` | `enc2_clk_dt_swap` | `0` | Same for encoder 2. |
| `[16]` | `sw_active_low` | `1` | Default: SW input low = pressed. Clear if the module exposes a SW that pulls high on press. |

The default CONFIG word is **`0x00010105`**: `debounce_ms=5`,
`clear_on_read=1`, `sw_active_low=1`, no inversion or swap.

### Press timing

Long-press threshold is fixed at **500 ms** (`LONG_PRESS_MS` parameter
in the RTL). A short press fires on the SW falling edge if a long press
hasn't already fired. Release is not latched — the Python driver
synthesises `release` events from a `BUTTON_STATE` transition from
pressed to released.

## Python driver

`audio_lab_pynq/encoder_input.py` exposes:

* `EncoderInput.from_overlay(overlay)` — discovers the IP (tries
  `axi_encoder_input_0`, `enc_in_0`, `enc_in_0/s_axi`, then
  `axi_encoder_input`, and finally searches `ip_dict` for
  `encoder` / `enc_in` names). PYNQ 2020.1 exposes this Verilog
  module reference as `enc_in_0/s_axi`; the bare `enc_in_0` overlay
  attribute is only a hierarchy object and must not be treated as MMIO.
* `read_status() / read_delta_packed() / read_counts() /
  read_button_state() / read_config() / read_version()` — raw
  register reads.
* `write_config(value)` and `configure(...)` — set CONFIG by individual
  fields.
* `clear_events(...)` — explicit CLEAR_EVENTS write.
* `poll(timestamp=...)` — read STATUS + DELTA, decode into a list of
  `EncoderEvent(kind, encoder_id, delta, raw_delta, timestamp)`.
  When CONFIG `clear_on_read` is set (default), no further bookkeeping
  is needed.

`EDGES_PER_DETENT` is `4` by default, matching a typical detented
encoder. The driver carries leftover edges between polls so a slow
rotation that straddles two polls still produces one detent event.

## High-level controller

`audio_lab_pynq/encoder_ui.py::EncoderUiController` maps events onto
`GUI/compact_v2/state.py::AppState`:

| Encoder | rotate | short_press | long_press |
| --- | --- | --- | --- |
| 0 (left)   | `selected_effect` += delta | toggle `effect_on[selected_effect]` | safe-bypass round-trip (save→all off, again→restore) |
| 1 (centre) | `selected_knob` += delta, or model index when `model_select_mode` | toggle `model_select_mode` (only for PEDAL / AMP / CAB) | clear `model_select_mode` (reserved future) |
| 2 (right)  | `all_knob_values[name][selected_knob] += delta * value_step` | apply pending changes via bridge/mirror | reset focused knob to default |

`AppState` gains eight optional fields, all defaulted to make legacy
notebooks render identically:

* `focus_effect_index`, `focus_param_index`
* `edit_mode`, `model_select_mode`
* `value_dirty`, `apply_pending`
* `last_control_source` (`"notebook"` | `"encoder"`)
* `last_encoder_event`

The renderer (`GUI/compact_v2/renderer.py`) adds a small status strip
in the bottom-right of the 800×480 frame that lights up the matching
flags. The Pip-Boy compact layout and PEDAL / AMP / CAB inline model
dropdown rules (`DECISIONS.md` D24) are unchanged.

Live apply uses `GUI/audio_lab_gui_bridge.py` when an `AudioLabOverlay`
is available. Dry-run tests can still inject a mirror object with
`update_from_appstate(state)` / `update(state)`; no raw effect GPIO is
written from the encoder controller.

## Test surfaces

* Offline: `tests/test_encoder_input_decode.py`,
  `tests/test_encoder_ui_controller.py`,
  `tests/test_compact_v2_encoder_state.py`. No `pynq` install required;
  uses the `_pynq_mock` stub and runs under `python3 -m unittest`.
* On-board: `scripts/test_encoder_input.py` (manual rotate/press smoke,
  prints VERSION/CONFIG/COUNT and live events for a configurable
  duration) and `scripts/test_hdmi_encoder_gui_control.py` (synthesises
  encoder events, repaints the HDMI framebuffer, checks VDMA status).
* Standalone runtime: `scripts/run_encoder_hdmi_gui.py` (a
  notebook-less Pip-Boy GUI loop driven by the encoders).
* Jupyter smoke:
  `audio_lab_pynq/notebooks/EncoderGuiSmoke.ipynb`, installed on the
  board as
  `/home/xilinx/jupyter_notebooks/audio_lab/EncoderGuiSmoke.ipynb`.
  It checks `VERSION=0x00070001`, `CONFIG=0x00010105`, VTC
  `GEN_ACTSZ=0x02580320`, ADC HPF / `R19=0x23`, and provides live
  monitor plus reverse/swap/debounce controls.

## Current deployed observations

After deploy to `192.168.1.9`, the observed register and HWH state was:

| Item | Observed |
| --- | --- |
| `ip_dict` encoder key | `enc_in_0/s_axi` |
| `VERSION` | `0x00070001` |
| `CONFIG` | `0x00010105` |
| `COUNT0..2` idle read | `0 / 0 / 0` |
| `BUTTON_STATE` idle read | `0b000` |
| HDMI VTC `GEN_ACTSZ` | `0x02580320` |

The 60-second low-level smoke captured no rotate / switch events in
that SSH run, so direction, CLK/DT swap, switch polarity, and debounce
calibration are still open until all three physical encoders are
manually operated and recorded.
