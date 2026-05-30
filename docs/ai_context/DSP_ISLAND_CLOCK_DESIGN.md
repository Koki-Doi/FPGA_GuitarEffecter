# DSP island clock-domain design (D75)

This is the design record for the **DSP clock-domain island** that brought
the routed WNS from `-10.387 ns` (D72/D73) to `-0.706 ns` while keeping the
live audio path, GUI, and HDMI fully healthy. It is the accepted baseline
as of 2026-05-31.

## Problem

The `fxPipeline` DSP (`clash_lowpass_fir_0`) had grown (Wah, Compressor,
Noise Suppressor, six distortion pedals, Amp, Cab, EQ, Reverb) until its
worst path could not close at 100 MHz: a 45-logic-level arithmetic chain
(CARRY4×36) inside the DS-1 distortion section, Data Path ~20.1 ns vs the
10 ns period. Everything else in the design (AXI, DMA, I2S, Pmod, HDMI)
closes fine at 100 MHz; only the DSP was the offender.

Approaches that did **not** work (see `TIMING_AND_FPGA_NOTES.md` history):
- **Stage-splitting** the DS-1 chain: WNS unchanged (route-dominated, the
  worst path is "Frame register -> DSP", not the clip depth).
- **Frame-width reduction** (1067->731 bits, dropping the write-only R-side
  fields): WNS slightly worse, not better.
- **Global FCLK0 = 50 MHz**: WNS improved to -4.6 ns BUT the I2S / Pmod
  clock-domain crossings (built assuming the 100 MHz fabric) corrupted —
  the bypass path buzzed continuously. Lowering the *whole* fabric clock
  breaks the existing CDCs.

## Solution: run only the DSP at 50 MHz, keep everything else at 100 MHz

`hw/Pynq-Z2/island_integration.tcl` (additive, sourced from
`create_project.tcl` after `wah_integration.tcl`; `block_design.tcl` is NOT
edited — same pattern as hdmi/encoder/pmod/wah):

1. **FCLK_CLK1 = 50 MHz** enabled on the PS (FCLK0 stays 100 MHz):
   `PCW_EN_CLK1_PORT 1`, `PCW_FPGA_FCLK1_ENABLE 1`, `PCW_FCLK_CLK1_BUF TRUE`,
   `PCW_FPGA1_PERIPHERAL_FREQMHZ 50`, divisors `5 / 4` (1000 MHz IO PLL).
2. **`rst_island_50M`** (`proc_sys_reset`) for the 50 MHz domain.
3. **`cc_dsp_in` / `cc_dsp_out`** (`axis_clock_converter`) around the DSP:
   `axis_data_fifo_0/M_AXIS -> cc_dsp_in (100->50) -> clash/axis_in`, and
   `clash/axis_out -> cc_dsp_out (50->100) -> axis_switch_sink/S01_AXIS`.
4. **clash moved onto FCLK_CLK1** (clk + aresetn detached from the 100 MHz
   nets via `disconnect_bd_net`, reconnected to FCLK_CLK1 / rst_island_50M).

Because the fabric clock is unchanged, the I2S / Pmod / HDMI CDCs are byte
-for-byte the same as D72 — that is the whole point versus the rejected
global-50 MHz build.

## Two supporting changes (both required)

- **paceCount removed** (`AudioLab/Pipeline.hs`): `acceptReady = readyOut`.
  The 16-cycle `paceCount` was the only frequency-dependent term in the
  AXIS handshake (it paced DMA bursts at 100 MHz). On the island it is
  dropped so the DSP runs on pure `readyOut` flow control.
- **Control-word CDC synchroniser** (`LowPassFir.hs` `syncCtrl`): the 12
  control words (`gate_control` … `wah_control`) cross from the 100 MHz
  GPIO domain into the 50 MHz DSP. Without synchronisation, an effect/knob
  write flips several of the 32 bits and the 50 MHz side can latch a
  transient mixed value for one sample → **audible click on every
  effect/knob change**. `syncCtrl` = two metastability FFs + a 2-cycle
  stability filter (adopt a word only once it has held steady), which is
  safe because these words are quasi-static. **This is mandatory** — bypass
  was clean without it, but switching clicked until it was added.

## clock_groups (WNS final polish)

`hw/Pynq-Z2/audio_lab.xdc` replaces the old bclk-only `set_false_path` with
a full `set_clock_groups -asynchronous` over all seven domains:
`clk_fpga_0` (100), `clk_fpga_1` (50, island), `clk` (48 MHz Pmod),
`bclk` (3 MHz I2S), `clk_out1_…clk_wiz_0_0` (24 MHz mclk),
`…audio_ext_0` (12.288), `…hdmi_0` (40 MHz pixel). They are all independent
domains crossed only through synchronised CDCs, so declaring them async is
correct and removes the spurious inter-clock paths — notably the
`rst_ps7_0_100M -> pmod_master` reset (`clk_fpga_0 -> audio_ext`) that was
the -4.2 ns worst path. After this, WNS = -0.706 ns (worst is now an
intra-`clk_fpga_0` AXI-Lite GPIO write, which is harmless and was always
present under the DSP path).

**Known harmless warning**: `CRITICAL WARNING [Vivado 12-4739] … No valid
object(s) found` on each `get_clocks` in the `set_clock_groups` line. The
BD-generated clocks (PS/MMCM) are not defined at top-level synth elaboration
time, so the constraint can't bind there; Vivado re-evaluates it at impl
where the clocks exist and it applies (confirmed: the worst path moved from
the inter-clock pmod reset to the intra-clock AXI GPIO write). To silence it
later, move the `set_clock_groups` into an implementation-scoped constraint.

## Results

| Metric | D73 (prev baseline) | D75 (island) |
| --- | --- | --- |
| WNS | -10.910 ns | **-0.706 ns** |
| WHS / THS | +0.022 / 0 | +0.052 / 0 |
| LUT / FF / BRAM | 20920 / 22672 / 6 | 21286 / 23968 / 6 |
| bit / hwh md5 | d1343291 / aad985fe | `4a0b3dae` / `347d3e55` |

Bench (external instrument, Pmod mode 2 ADC→DSP→DAC): all_off bypass clean,
no click on effect/knob switching, pitch correct (sample rate intact), every
effect works, GUI + HDMI healthy. User verdict: 完璧.

XADC (D74) is dropped from this build (`create_project.tcl` xadc lines
commented) because it put a bitcrusher artifact on the ADC path — see
`project_fresh_make_not_d72_xadc_d73` and `D74_XADC_NOISE_INVESTIGATION.md`.

## Rollback

D73 (`d1343291` / `aad985fe`, WNS -10.910) and D72 (`eacc4f35` / `eaa88898`)
remain recoverable from git history; both are full-100 MHz builds without
the island. To revert: restore those bit/hwh, redeploy 5-site, power-cycle.
