# HDMI GUI Phase 6H Native 800x480 Timing

Date: 2026-05-16

## Reason

Phase 6F and Phase 6G proved that the Python side was no longer placing
the 800x480 GUI to the right:

- Renderer frame shape: `(480, 800, 3)`.
- Phase 6G strong UI detector: `estimated_main_panel_left_x=4..24`,
  depending on whether visual origin ticks are enabled.
- HDMIBackend placement: `manual`, `offset_x=0`, `offset_y=0`,
  `dst_x0=0`, `dst_y0=0`.
- Framebuffer probe: GUI data only in x `0..799`, y `0..479`;
  `outside_800x480_sum=0`.
- VDMA error bits: none.

The real 5-inch LCD still showed a left blank region with the 720p
signal, so Phase 6H treats the remaining shift as an LCD receiver /
scaler / active-area interpretation problem and changes only the HDMI
output path inside the AudioLab overlay.

## Changed Timing

Previous deployed HDMI path:

- Active: `1280x720`.
- Pixel clock: `74.250 MHz`.
- VTC totals: H `1650`, V `750`.
- VDMA: HSIZE `3840`, STRIDE `3840`, VSIZE `720`.
- Framebuffer: `1280 * 720 * 3 = 2764800` bytes.

Native 800x480 timing deployed in this phase:

- Active: `800x480`.
- Pixel clock: `40.000 MHz`.
- Horizontal: front porch `40`, sync `128`, back porch `88`,
  total `1056`.
- Vertical: front porch `13`, sync `3`, back porch `132`,
  total `628`.
- Frame rate: approximately `60.3 Hz`.
- VTC sync start/end: H `840..968`, V `493..496`.
- Sync polarity: kept positive, matching the prior HDMI path.
- `rgb2dvi_hdmi`: `kClkRange=3`.

The first candidate from the Phase 5B/6H prompt, `33.333 MHz` with
H total `928` and V total `525`, was not deployable with the unmodified
Digilent `rgb2dvi` v1.4 IP in this project. Vivado rejected
`kClkRange=4`, and with `kClkRange=3` the internal PLLE2 VCO was
`666.667 MHz`, below the valid `800..1600 MHz` range. The 40 MHz
timing keeps the generated PLL VCO inside range without touching
`rgb2dvi` source.

## Files

- `hw/Pynq-Z2/hdmi_integration.tcl`
  - Defines the native timing variables.
  - Keeps the 720p settings in comments for rollback.
  - Changes only the HDMI extension path sourced by
    `create_project.tcl`.
- `audio_lab_pynq/hdmi_backend.py`
  - Native framebuffer defaults changed to `800x480`.
  - 800x480 frames use a direct native copy path.
  - Smaller frames still compose into the native framebuffer.
  - Runtime status reports active size, framebuffer size, VDMA HSIZE /
    STRIDE / VSIZE, clipping, and copy metadata.
- `scripts/test_hdmi_actual_ui_origin_visual.py`
  - Phase string updated for the native 800x480 visual test.
  - Framebuffer probe handles the absence of an x=800 column.
- `scripts/test_hdmi_800x480_origin_guard.py`
  - Native 800-wide framebuffer probe support.

No `LowPassFir.hs`, `topEntity`, DSP pipeline, codec path, existing GPIO
address/name/ctrlA-D semantics, or audio AXI stream topology was
changed.

## Build

Command:

```sh
cd /home/doi20/Desktop/Audio-Lab-PYNQ/hw/Pynq-Z2
vivado -mode batch -notrace -nojournal -nolog -source create_project.tcl \
  2>&1 | tee /tmp/phase6h_vivado_build_retry2.log
```

Result:

- Vivado 2019.1 build: success.
- Bitstream: `hw/Pynq-Z2/bitstreams/audio_lab.bit`.
- HWH: `hw/Pynq-Z2/bitstreams/audio_lab.hwh`.
- Routed timing summary:
  - WNS `-8.138 ns`
  - TNS `-6405.865 ns`
  - WHS `+0.040 ns`
  - THS `0.000 ns`
- Baseline before native timing:
  - WNS `-8.163 ns`
  - TNS `-6599.061 ns`
  - WHS `+0.051 ns`
  - THS `0.000 ns`
- Utilization after place:
  - LUT `18634`
  - Registers `20846`
  - BRAM Tile `9`
  - DSP `83`

The final WNS is slightly better than the previous HDMI baseline. DSP
count stayed at `83`.

## HWH Evidence

`audio_lab.hwh` contains:

- `clk_wiz_hdmi` `CLKOUT1_REQUESTED_OUT_FREQ=40.000`.
- `clk_wiz_hdmi/clk_out1` frequency `40000000`.
- `rgb2dvi_hdmi` `kClkRange=3`.
- `v_tc_hdmi`
  - `GEN_HACTIVE_SIZE=800`
  - `GEN_VACTIVE_SIZE=480`
  - `GEN_HFRAME_SIZE=1056`
  - `GEN_F0_VFRAME_SIZE=628`
  - `GEN_HSYNC_START=840`
  - `GEN_HSYNC_END=968`
  - `GEN_F0_VSYNC_VSTART=493`
  - `GEN_F0_VSYNC_VEND=496`

## PYNQ Deploy And Smoke

PYNQ rollback backup:

```text
/home/xilinx/Audio-Lab-PYNQ/backups/phase6h_720p/audio_lab.bit
/home/xilinx/Audio-Lab-PYNQ/backups/phase6h_720p/audio_lab.hwh
```

Local rollback backup:

```text
/tmp/fpga_guitar_effecter_backup/phase6h_build_20260516_144952/
```

Deploy command:

```sh
bash scripts/deploy_to_pynq.sh
```

Smoke result:

- `AudioLabOverlay()` loaded.
- ADC HPF: `True`.
- `R19_ADC_CONTROL=0x23`.
- `axi_vdma_hdmi` present in `overlay.ip_dict`.
- `v_tc_hdmi` present in `overlay.ip_dict`.

PYNQ's standard `AxiVDMA` attribute driver still fails if accessed
directly because this MM2S-only VDMA instance has no connected
`mm2s_introut`. This is the known Phase 4 caveat. The HDMI backend uses
direct `pynq.MMIO` handles from `ip_dict` and does not depend on the
standard PYNQ VDMA driver.

## PYNQ HDMI Results

Native actual UI visual:

- Command:
  `python3 scripts/test_hdmi_actual_ui_origin_visual.py --hold-seconds 60 --selected-fx CAB`
- Result: PASS.
- Active/framebuffer size: `800x480`.
- Framebuffer size: `1152000` bytes.
- VDMA HSIZE/STRIDE/VSIZE: `2400 / 2400 / 480`.
- `dst_x0=0`, `dst_y0=0`.
- `fit_mode=native`.
- `native_passthrough=True`.
- `clipped=False`.
- `compose_s=0.0`.
- `framebuffer_copy_s=0.086868 s`.
- VDMA raw status: `0x00010000`.
- VDMA error bits: none.
- VTC control: `0x00000006`.
- VTC generated HSync register: `0x03c80348`.
- Framebuffer probe: `nonzero_bbox=[0,799,0,479]`,
  `outside_800x480_sum=0`, x=0 / x=10 / x=20 / x=40 / x=799 columns
  nonzero, x=800 out of range as expected for native mode.

Model UI test:

- Command:
  `python3 scripts/test_hdmi_model_selection_ui.py --hold-seconds-per-step 1 --final-hold-seconds 10`
- Result: PASS.
- PEDAL / AMP / CAB dropdown visible as expected.
- REVERB / COMPRESSOR / NOISE SUPPRESSOR / SAFE BYPASS / PRESET
  dropdown hidden as expected.
- VDMA error bits: none.
- Representative timing: render `0.218..0.507 s`, compose `0.0 s`,
  framebuffer copy about `0.086 s`.

Realtime pedalboard test:

- Command:
  `python3 scripts/test_hdmi_realtime_pedalboard_controls.py --hold-seconds-per-step 1 --final-hold-seconds 10`
- Result: PASS.
- Actual DSP control API calls remained live.
- Final resource sample: render `0.228619 s`, compose `0.0 s`,
  framebuffer copy `0.086180 s`, total update `0.315178 s`.
- VDMA raw status: `0x00011000`.
- VDMA error bits: none.
- VTC control: `0x00000006`.

LCD left-blank visual confirmation still requires human observation of
the 5-inch panel. The native visual test displayed the `X0` / `X799`
actual UI marker screen for 60 seconds so the LCD can be checked
directly.

## Rollback Plan

If native 800x480 does not display correctly on the panel:

1. Restore the PYNQ backup:
   ```sh
   ssh xilinx@192.168.1.9 '
     cd /home/xilinx/Audio-Lab-PYNQ &&
     cp -a backups/phase6h_720p/audio_lab.bit hw/Pynq-Z2/bitstreams/audio_lab.bit &&
     cp -a backups/phase6h_720p/audio_lab.hwh hw/Pynq-Z2/bitstreams/audio_lab.hwh
   '
   ```
2. Re-run `bash scripts/deploy_to_pynq.sh` from a local tree that has
   the 720p bit/hwh restored or copy the backup into the installed
   `audio_lab_pynq/bitstreams/` directory on PYNQ.
3. Do not discard the native timing patch. Keep it as the Phase 6H
   record.
4. Next timing candidates:
   - alternate 800x480 porch/sync totals,
   - sync polarity changes,
   - true 33.3 MHz only if `rgb2dvi` clocking is modified or replaced,
   - 720p fallback with a documented LCD crop workaround.

## Open Items

- Confirm by eye whether the 5-inch LCD now starts the GUI at the left
  edge and whether the previous left blank region is gone.
- If the panel rejects the 40 MHz 800x480 mode, use the rollback plan
  and try the alternate timing candidates in a separate phase.
