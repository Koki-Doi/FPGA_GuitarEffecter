# XADC Wizard integration design (PROPOSAL -- NOT built)

Status: **design only.** No Vivado run, no bit/hwh change, `create_project.tcl`
does **not** source the proposal tcl yet. Building this requires a separate
explicit approval (PL change + timing review). See `DECISIONS.md` D74 and
`FP02M_PEDAL_INTEGRATION.md` section 1.

## Why

The FP02M expression pedal feeds Wah POSITION from Arduino **A0**. A0 is a
Zynq XADC **VAUX** channel routed through the PL. The deployed overlay has
no XADC IP, so A0 cannot be read (the PS-XADC IIO device exposes only
on-chip rails). To read A0 we must add an AXI XADC Wizard to the PL.

## A0 channel mapping (PYNQ-Z2, fixed by the board)

| Arduino | Zynq pin | XADC channel |
| --- | --- | --- |
| **A0** | **Y11** (AD1P) / Y12 (AD1N) | **VAUX1** |
| A1 | W11 | VAUX9 |
| A2 | V11 | VAUX6 |
| A3 | T5  | VAUX15 |
| A4 | U10 | VAUX5 |
| A5 | U5  | VAUX13 |

Source: `IO_PIN_RESERVATION.md` (arduino_a0 = Y11) and the reference
`PYNQ_Z2-Audio/sources/AXIS_audio.tcl` XADC config (Vaux1/5/6/9/13/15).
Only **VAUX1** is needed for A0.

## Additive integration (follows the wah_integration.tcl pattern)

- Add `hw/Pynq-Z2/xadc_integration.tcl`, sourced from `create_project.tcl`
  **after** `wah_integration.tcl` (do NOT edit `block_design.tcl`).
- Instantiate `xadc_wiz` in AXI4-Lite mode, single-channel continuous (or
  channel-sequencer) sampling **VAUX1** only, unipolar, no averaging
  necessary (the RC filter + Python smoothing handle noise).
- Bump `ps7_0_axi_periph/NUM_MI` (currently 20 after the wah GPIO; this
  adds M20_AXI) and assign a fresh address segment that does not collide
  with the existing map. Existing map tops out at `axi_gpio_wah`
  `0x43D30000`; propose `xadc_wiz` at **`0x43D40000`** (64 KiB), well
  clear of every current segment.
- Connect the `Vaux1` `diff_analog_io` interface to a new top-level
  external port pair; constrain VAUXP1/VAUXN1 to Y11/Y12 in a new
  `hw/Pynq-Z2/xadc_a0.xdc` `add_files`-d from `create_project.tcl`
  (per the XDC-`if`-not-supported memory, no conditional pins).
- Clock the XADC `s_axi_aclk` from the existing 100 MHz PS AXI clock; DRP
  clock from the same domain (xadc_wiz handles internal division).

## Read path after build

Two equivalent options; the Python `Fp02mA0Reader` already prefers IIO:

1. **IIO (preferred):** the `xadc_wiz` exposes the VAUX1 sample to the
   Linux `xadc` driver as a new non-rail channel
   (`/sys/bus/iio/devices/iio:device0/in_voltage*_vaux1_raw`). The reader
   auto-discovers it (any `in_voltage*` channel that is not one of the
   eight internal rails). 16-bit raw; volts = raw * scale / 1000; A0 volts
   = xadc volts * 3.3 (PYNQ-Z2 anti-alias divider). Calibration absorbs
   the exact scale, so the reader only needs raw counts.
2. **MMIO fallback:** read the xadc_wiz VAUX1 data register at
   `0x43D40000 + offset` via `pynq.MMIO`. Only after the overlay is
   loaded (PL MMIO before a successful `download=True` crashes the
   kernel -- see user-memory `project_pynq_mmio_before_overlay_kills_kernel`).

## Diff / risk for the future Vivado rebuild

- **Files added:** `hw/Pynq-Z2/xadc_integration.tcl`,
  `hw/Pynq-Z2/xadc_a0.xdc`; one `source` + one `add_files` line in
  `create_project.tcl`. `block_design.tcl` untouched.
- **Address:** new `0x43D40000` segment; no collision with the fixed map.
- **Timing risk:** xadc_wiz is small (a few hundred LUT/FF, the DRP
  state machine, no DSP, no BRAM). Expected delta is minor, but WNS must
  be re-checked vs the D73 baseline (`-10.910 ns`) and must not regress
  significantly per CLAUDE.md. The XADC analog front-end is asynchronous
  to the audio clock and does not touch the DSP chain combinational paths.
- **Audio impact:** none expected -- the XADC sits on its own AXI slave;
  the Clash `clash_lowpass_fir_0` top entity is **not** modified (no new
  port), so the DSP voicing is byte-identical.
- **5-site bit/hwh sync** required on deploy (per CLAUDE.md HDMI note).
- **Acceptance gate:** Vivado `write_bitstream` 0 Errors; WNS not
  significantly worse than D73; `diagnose_pmod_loopback.py` PASS; A0 probe
  reads a moving value on pedal sweep; bench audio unchanged on all_off.

## Proposal artifact

`hw/Pynq-Z2/xadc_integration.tcl` is committed as a **proposal** with a
guard header; it is intentionally NOT sourced by `create_project.tcl`.
Wiring it in + running Vivado is the deferred step.
