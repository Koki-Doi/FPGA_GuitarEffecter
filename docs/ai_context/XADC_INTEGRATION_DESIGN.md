# XADC Wizard integration (ACCEPTED + committed on the D75 island; D76 baseline)

Status: **accepted on bench and committed** as part of **D76**
(2026-05-31). The D74 build (below) had been deployed but held out of git
because of a bitcrusher on the ADC path; that defect was later proven to
be the D74 100 MHz audio-AXIS P&R degradation, **not** the XADC. On the
D75 50 MHz DSP island the same XADC re-add closes timing cleanly and the
bitcrusher does not recur, so D76 re-enabled it and accepted it on the
bench. `create_project.tcl` now sources `xadc_integration.tcl` after
`wah_integration.tcl` and **before** `island_integration.tcl`, and adds
`xadc_a0.xdc`. The PL `xadc_wiz_a0 @ 0x43D40000` reads Arduino A0 via
**AXI MMIO** (not IIO -- see below) and drives Wah POSITION through the
FP02M layer. D76 routed timing: overall WNS `-0.368 ns` (100 MHz audio
fabric WNS `+0.614 ns`, 0 failing; the only 22 failures are intra-50 MHz
DSP DS-1 arithmetic); bit/hwh md5 `9fdecae0c7d7cf3c59422cec2b30368f` /
`a9fd74082482aa1b074fc3c31ccd6283`, deployed 5-site. See `DECISIONS.md`
D76, `DSP_ISLAND_CLOCK_DESIGN.md`, and `FP02M_PEDAL_INTEGRATION.md`.

The "Build result (2026-05-29)" section below is the original D74 build
record (committed-baseline = D72/D73 at that time), retained for history.

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

## Read path after build -- MMIO, NOT IIO (load-bearing)

**Confirmed on the board:** the PL `xadc_wiz_a0` does **not** appear in the
Linux IIO tree. `/sys/bus/iio/devices/iio:device0` (driver `xadc`) is the
**PS-XADC** and still shows only the eight internal rails after the D74 bit
is loaded -- it is a separate access path from the PL XADC Wizard, and PYNQ
does not auto-generate a device-tree node for a custom PL `xadc_wiz`. So
`Fp02mA0Reader` (IIO) stays unavailable for VAUX1.

The working path is **AXI MMIO** via `Fp02mXadcMmioReader`:

- Read the `xadc_wiz_a0` status registers through `overlay.xadc_wiz_a0`
  (a PYNQ `DefaultIP`), only **after** the overlay is loaded (PL MMIO
  before a successful `download=True` crashes the kernel -- user-memory
  `project_pynq_mmio_before_overlay_kills_kernel`).
- Register map (xadc_wiz v3.3, AXI base + 0x200 mirrors the DRP space;
  each value is a 12-bit code in the top 12 bits of the 16-bit word):
  `0x200` TEMP, `0x204` VCCINT, **`0x244` VAUX1 = A0**. `read_raw()`
  returns `(reg >> 4) & 0xFFF` (0..4095); `read_voltage()` =
  `raw/4096 * 3.3`. Calibration absorbs the exact scale.
- `available()` sanity-checks VCCINT (0x204) is in a plausible band so a
  stale / unprogrammed PL reads as unavailable rather than feeding garbage
  to the Wah.

Bench confirmation (A0 floating): `TEMP` 12-bit `2702` (~59 C die),
`VCCINT` 12-bit `1395` (~1.02 V -- both sane), `VAUX1` raw `~8` (~0.006 V,
correct for an open input). `probe_fp02m_a0.py --mmio` returns raw values
(not unavailable).

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

## Build result (2026-05-29)

- `create_project.tcl` sources `xadc_integration.tcl` after
  `wah_integration.tcl` and `add_files` `xadc_a0.xdc`. `block_design.tcl`
  untouched; `clash_lowpass_fir_0` unchanged (DSP voicing byte-identical).
- `validate_bd_design` passed (only a benign BD 41-927 aclk-property
  warning). `write_bitstream completed successfully`, 0 Errors.
- Routed timing: WNS `-11.361 ns`, TNS `-11083.667 ns`, WHS `+0.051 ns`,
  THS `0.000 ns`; setup failing endpoints `3565 / 61840`. Delta vs D73
  (`-10.910 ns`) is `-0.451 ns` -- inside the accepted band. Worst path
  `clash_lowpass_fir_0/U0/ds1_7_reg[784]/C -> ...psdsp/D` (DS-1 distortion,
  same section as D73); no Wah or XADC net in the worst path.
- Utilization: LUT `21123` (+203 vs D73), FF `22863` (+191), BRAM `6`
  (unchanged), DSP `89` (unchanged) -- the XADC adds ~200 LUT / ~190 FF,
  no DSP / BRAM.
- bit/hwh md5 `dd3fc09994902abcf34f8819d054205b` /
  `ef094d0e1a6158a94fc75bb297adfa6b`. HWH contains `xadc_wiz_a0` and
  `axi_gpio_wah`. Deployed 5-site (board bit md5 matches). bit/hwh are
  **not committed** until bench audition passes (D74 gate).
