# Footswitch integration (FX toggle + preset stepping)

Three guitar-pedal **3PDT** footswitches on the Raspberry Pi header, read
by a new PL IP `axi_footswitch_input`. This is an **input** path that lives
outside the `GPIO_CONTROL_MAP.md` effect-output ledger, same as the rotary
encoder IP (`ENCODER_INPUT_MAP.md`). See `DECISIONS.md` D78.

> Status: **ACCEPTED and merged** as D78 (`feat(#D78)` 813029b + merge
> aa4080f). The D78 accepted bit md5 is `45e78763...`; D79 later supersedes
> it as the deployed baseline while keeping this footswitch IP. Bench audio
> is CLEAN after the phys_opt fix (see "Bitcrusher" below), and the user
> wired the final RP pins 11/12/35 and confirmed FS1 FX toggle plus FS2/FS3
> preset stepping on the final bit. The IP remains live in the current D155
> baseline; the DSP island was later lowered from the D78-era 50 MHz to
> 33.33 MHz, while this input IP stays on the 100 MHz fabric.

## Roles (fixed by wiring / XDC)

| Channel | Port | Role |
| --- | --- | --- |
| 0 | `fsw0_i` | FX toggle (toggle the bound effect on/off) |
| 1 | `fsw1_i` | Preset next (advance one chain preset) |
| 2 | `fsw2_i` | Preset prev (step back one chain preset) |

## Why a bit rebuild is unavoidable

The D76 bitstream has no spare **input** path: the encoder IP's 9 inputs
are all encoder-owned and every effect GPIO is output-only. Reading new
physical pins therefore needs a Vivado rebuild no matter what. The pins
were already reserved for footswitches in `IO_PIN_RESERVATION.md`
section 4A.3.

## Hardware

### Pins (Raspberry Pi 40-pin header -- exact physical positions)

The footswitches land on the spare RP GPIO reserved in
IO_PIN_RESERVATION.md section 4A.3. The physical connector pin numbers were
resolved from the **official PYNQ-Z2 master XDC schematic net names**
(`Sch=rpio_NN_r`), where `NN` is the Raspberry Pi BCM GPIO number (verified:
`rpio_02/03` = the I2C SDA1/SCL1 GPIO2/3, `rpio_sd/sc` = Y16/Y17 = the
HAT-ID EEPROM pins). The package pin -> schematic name -> BCM GPIO ->
physical pin chain is authoritative, not inferred.

| Signal | Package | Sch net | BCM GPIO | **RP header physical pin** |
| --- | --- | --- | --- | --- |
| `fsw0_i` (FX toggle)   | `U7`  | `rpio_17_r` | GPIO17 | **pin 11** |
| `fsw1_i` (preset next) | `C20` | `rpio_18_r` | GPIO18 | **pin 12** |
| `fsw2_i` (preset prev) | `Y8`  | `rpio_19_r` | GPIO19 | **pin 35** |

GND: any RP header GND pin (`6 / 9 / 14 / 20 / 25 / 30 / 34 / 39`). FS1/FS2
(pins 11/12) are adjacent; nearest GND is pin 9 or 14. FS3 (pin 35) is on
the far end; nearest GND is pin 34 or 39. 3.3V is pin 1 / 17 (not needed --
the internal PULLUP holds the open throw high). 5V is pin 2 / 4 -- **never
wire there** (`DECISIONS.md` D31).

All `LVCMOS33` with `PULLUP true`. Wiring per switch: **common -> the RP
signal pin (11 / 12 / 35), one throw -> a GND pin, the other throw left
open**. Open = 1, grounded = 0. The 3PDT is alternate-action (latching) so
each stomp flips the level; `axi_footswitch_input` latches one `press_event`
per edge (either direction).

> Caution: the RP header silk's BCM "GPIOxx" labels (and the v1.0 reference
> manual) are an easy source of off-by-one wiring errors -- count physical
> pin positions (pin 1 = the corner-marked pad; odd pins 1,3,..,39 on one
> row, even 2,4,..,40 on the other). To double-check on the loaded bit,
> ground a pin and watch `FootswitchInput.read_levels()` flip the matching
> channel (ch0=FS1, ch1=FS2, ch2=FS3). A first attempt mislabeled `Y8` as
> "GPIO17"; it is `rpio_19` = GPIO19 = pin 35.

### 3PDT is a latching switch (load-bearing design point)

A true-bypass 3PDT is an *alternate-action* (latching) switch: each stomp
flips the contact, so the debounced logic level toggles 0<->1 on every
press. The IP latches one `press_event` on **either** edge of the
debounced level -- the absolute level is irrelevant. This differs from the
encoder SW path (a momentary active-low button that latches only on the
falling edge).

Power-up: `level_seen` resets to 1 (the pulled-up "open" position). If a
switch boots in the grounded position one phantom event may latch; the
Python driver clears events once on attach (`from_overlay(clear_on_attach=
True)`) to absorb it.

## RTL: `hw/ip/footswitch_input/src/axi_footswitch_input.v`

Self-contained Verilog module reference (no IP packaging), mirroring
`axi_encoder_input.v`: 1 ms tick divided from the 100 MHz AXI clock; per
channel a 2-FF synchroniser -> debounce counter (`CONFIG.debounce_ms`
stable ms samples) -> dual-edge `press_event` latch (clear-on-read).

### AXI register map (base `0x43D50000`, size `0x10000`)

| Offset | Name | Access | Layout |
| --- | --- | --- | --- |
| `0x00` | `STATUS` | R (clear-on-read) | bits[2:0]=press_event, bits[10:8]=debounced level |
| `0x18` | `CONFIG` | R/W | bits[7:0]=debounce_ms (default 5), bit[8]=clear_on_read (default 1) |
| `0x1C` | `CLEAR_EVENTS` | W | write 1 to press_event bit positions to clear |
| `0x20` | `VERSION` | R | `0x00F50001` |

Default CONFIG word: `0x00000105`.

## Block-design integration

`hw/Pynq-Z2/footswitch_integration.tcl` (additive, modeled on
`encoder_integration.tcl`):

1. `ps7_0_axi_periph` NUM_MI 21 -> 22 (adds M21).
2. 3 top-level input ports `fsw{0,1,2}_i`.
3. `fsw_in_0` module-reference cell (`axi_footswitch_input`).
4. AXI-Lite from M21, clock/reset from `FCLK_CLK0` / `rst_ps7_0_100M`
   (100 MHz fabric -- **not** the 50 MHz DSP island).
5. Wire the 3 ports to the IP.
6. Address segment `0x43D50000 / 0x10000`.

`create_project.tcl` adds the RTL via `add_files` (before `block_design.tcl`)
and `source ./footswitch_integration.tcl` **after** `xadc_integration.tcl`
and **before** `island_integration.tcl`. `block_design.tcl` is not edited;
`clash_lowpass_fir_0` is unchanged so the DSP voicing is byte-identical and
no Clash/Vivado DSP regeneration is needed. XDC: 3 pins added to
`audio_lab.xdc` with `PULLUP true`.

### AXI master allocation (post footswitch)

```
M17 : axi_encoder            @ 0x43D10000
M18 : axi_pmod_i2s2_status   @ 0x43D20000
M19 : axi_gpio_wah           @ 0x43D30000
M20 : xadc_wiz_a0            @ 0x43D40000
M21 : axi_footswitch_input   @ 0x43D50000   (new)
```

## Python layer

* `audio_lab_pynq/footswitch_input.py` -- low-level driver (mirrors
  `encoder_input.py`). `FootswitchInput.from_overlay(overlay)` discovers
  the IP (`axi_footswitch_input_0` / `fsw_in_0` / `fsw_in_0/s_axi` / ...),
  flushes the power-up phantom event, and exposes `read_version`,
  `read_levels`, `configure`, `clear_events`, and `poll()` ->
  `[FootswitchEvent(kind="press", channel)]`.
* `audio_lab_pynq/footswitch_control.py` --
  `FootswitchController.tick(footswitch)` dispatches events:
  * **FS1 (FX toggle):** flips `AppState.effect_on[target]` and writes only
    that one enable via `EncoderEffectApplier.apply_effect_on_off` (the same
    single translation layer the encoder uses; preserves any curated preset
    voicing). **Rebind:** 5 presses within 3 s rebinds `footswitch_fx_target`
    to `AppState.selected_effect`, leaving the old target's on/off unchanged.
  * **FS2/FS3 (preset step):** `preset_idx ±1` (wraps over all
    `CHAIN_PRESETS`), calls `AudioLabOverlay.apply_chain_preset(name)` for
    the audio, then mirrors the preset into `AppState` via
    `apply_chain_preset_to_state` so the HDMI GUI follows. EQ presets
    (0..200, 100 unity) are halved into the GUI 0..100 (50 unity) knob;
    Cab MODEL rides `cab_model_idx`; distortion pedal name maps to
    `dist_model_idx`. Amp/OD model index and amp drive mode are not carried
    by the legacy presets and are left unchanged (display-side limitation).
* `GUI/compact_v2/state.py` -- new persisted field
  `footswitch_fx_target: int = 5` (Amp Sim). The legacy mock `fs_states` /
  `fs_selected` are unrelated and untouched.

## Runtime

`scripts/run_encoder_hdmi_gui.py` builds `FootswitchInput` +
`FootswitchController` after the encoder/applier and polls them
non-blocking in the main loop, right next to the FP02M pedal poll, so every
overlay write stays single-threaded (no GPIO race). The render thread picks
up footswitch changes through the existing `effect_on` / knob signature
plus the added `preset_name` / `footswitch_fx_target` signature fields.

CLI flags:

* `--footswitch` / `--no-footswitch` -- enable/disable (default on; silently
  no-ops if the IP is absent on an older bit).
* `--footswitch-debounce-ms N` -- override the IP debounce window.
* `--footswitch-debug` -- print a `[footswitch]` line per event.

## Tests

| File | Scope |
| --- | --- |
| `tests/test_footswitch_input_decode.py` | STATUS decode, poll -> press events, configure round-trip, clear_events word, from_overlay clear-on-attach. |
| `tests/test_footswitch_control.py` | FX single-press toggle, 2-press return, 5/3s rebind, slow presses don't rebind, rebind press doesn't toggle, preset next/prev wrap + apply + mirror, preset->state mapping (pedal/cab/EQ scale). |

```
python3 -m unittest -v \
  tests.test_footswitch_input_decode tests.test_footswitch_control
```

## Bitcrusher root-cause + the phys_opt fix (load-bearing)

Adding the footswitch AXI master (M21) on `ps7_0_axi_periph` perturbed the
place-and-route of the **50 MHz DSP island** and pushed the DS-1 distortion
CARRY4 arithmetic chain (`clash_lowpass_fir_0/.../ds1_*`) from the D76
baseline (clk_fpga_1 WNS **-0.368 ns**) to **~-0.75 ns**. That produced an
audible **bitcrusher on the ADC -> DSP -> DAC path** -- the same D74-class
artifact -- even though the 100 MHz audio fabric (clk_fpga_0) still closed
with margin and the pin choice was irrelevant (both the RP-pin `199d25ea`
and PMOD-JA `e610dc58` builds bitcrushed). Confirmed by an A/B: rolling the
board back to D76 made the noise vanish; D76 stayed clean.

**Fix:** enable post-place + post-route `phys_opt_design` (AggressiveExplore)
on `impl_1` in `create_project.tcl`:

```tcl
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
```

Result on the accepted bit `45e78763`: clk_fpga_1 (DSP island) WNS
**-0.173 ns** (better than D76's -0.368), clk_fpga_0 (audio fabric)
**+0.683 ns / 0 failing**, overall WNS -0.173, WHS +0.014. **Bench audio
verified CLEAN by the user.** Lesson: an additive AXI master can degrade the
DSP-island timing enough to bitcrush even when static timing on the audio
fabric looks fine; phys_opt recovers the arithmetic slack.

## Build / deploy result (done)

1. `write_bitstream completed successfully` / 0 Errors. bit/hwh md5
   `45e78763` / `aa12a661`.
2. Routed timing better than D76 (above). The two pre-phys_opt bits
   (`199d25ea`, `e610dc58`) bitcrush and are rejected.
3. bit/hwh synced to the 5 sites (here via direct `scp` + `sudo cp` to avoid
   the `deploy_to_pynq.sh` notebook-install step, which zeroed the 15
   `/home/xilinx/jupyter_notebooks/audio_lab/*.ipynb` on a prior run -- those
   were repaired from the board repo copies).
4. On board: `fsw_in_0` present, `VERSION=0x00F50001`, RP-pin pull-ups read
   (1,1,1) before wiring, ADC HPF True, audio clean. The controller logic
   (FS1 toggle / FS2-FS3 preset / 5x rebind / all 3 channels) was
   bench-validated on the interim PMOD-JA bit, then the user wired the final
   RP pins 11/12/35 and confirmed FS1 / FS2 / FS3 function on the accepted
   RP-pin bit.

## Rollback

To remove the feature from a future build, remove the three hardware-source
pieces (`hw/ip/footswitch_input/src/axi_footswitch_input.v`,
`hw/Pynq-Z2/footswitch_integration.tcl`, the `audio_lab.xdc` footswitch
block) and revert the two `create_project.tcl` additions, then rebuild on
top of the desired current Clash source. The historical no-footswitch
rollback baseline is D76; the Python layer is bit-independent and can stay.
