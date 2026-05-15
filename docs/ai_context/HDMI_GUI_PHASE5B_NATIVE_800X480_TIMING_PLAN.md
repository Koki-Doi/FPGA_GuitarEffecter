# HDMI GUI Phase 5B native 800x480 timing plan

Date: 2026-05-15 JST

## Goal

Phase 5B is a proposed, not-yet-approved Vivado rebuild experiment:
change the HDMI output from fixed 1280x720 timing to native-ish 800x480
timing for the 5-inch LCD. The goal is to remove the LCD controller's
720p crop/scale/shift ambiguity rather than hiding it with Python
offsets.

Do not implement this plan without explicit user approval. Phase 5A
does not rebuild bit/hwh.

## Current 720p baseline

The deployed Phase 4 HDMI path is:

- `clk_wiz_hdmi`: 100 MHz FCLK0 to 74.25 MHz pixel clock
- `axi_vdma_hdmi`: MM2S-only framebuffer reader
- `v_tc_hdmi`: 1280x720 timing generation
- `v_axi4s_vid_out_hdmi`: AXI4-Stream video to native video
- `rgb2dvi_hdmi`: Digilent TMDS encoder, internal 5x serial clock
- framebuffer: 1280x720 RGB888 input, packed to DDR `GBR888`
- VDMA: `HSIZE=3840`, `STRIDE=3840`, `VSIZE=720`
- VDMA control: `0x43CE0000`
- VTC control: `0x43CF0000`
- latest timing baseline: WNS `-8.163 ns`, WHS `+0.051 ns`

The current Python backend assumes `DEFAULT_WIDTH=1280`,
`DEFAULT_HEIGHT=720`, and full-frame copy size `2,764,800` bytes.

## Proposed 800x480 target

Target active region:

- HDMI active width: `800`
- HDMI active height: `480`
- framebuffer: `800x480`
- input format: RGB888 `numpy.ndarray`
- DDR format: packed `GBR888`
- VDMA `HSIZE`: `800 * 3 = 2400`
- VDMA `STRIDE`: `2400`
- VDMA `VSIZE`: `480`
- framebuffer copy size: `1,152,000` bytes

Copy-load comparison:

| Mode | Bytes per frame | Relative copy load |
| --- | ---: | ---: |
| 1280x720 RGB888 | `2,764,800` | `100%` |
| 800x480 RGB888 | `1,152,000` | `41.7%` |

The copy cost should fall to roughly 42% of the current full-frame path,
assuming the same Python slice-copy implementation and memory bandwidth.

## Timing selection

The exact 800x480 timing must come from one of these sources, in order:

1. EDID from the LCD controller, if a reliable read path is found.
2. The LCD / driver-board product specification.
3. A conservative generic 800x480@60 timing trial.

Phase 5A did not find a usable EDID path through Linux DRM, and the
current XDC does not connect HDMI OUT DDC. If no EDID/spec is available,
the first 800x480 build should be treated as an experiment, not a
guaranteed standard mode.

Candidate starting point from earlier Phase 3 planning:

- pixel clock around `33.75 MHz`
- active `800x480`
- progressive 60 Hz class
- `rgb2dvi` `kClkRange` should be revisited; the local Digilent source
  comments indicate lower pixel clocks may need `kClkRange=4`
  (`>=30 MHz`) rather than the current 720p `kClkRange=3`

Do not copy the current 720p blanking numbers. Recompute:

- horizontal frame size
- horizontal sync start/end
- horizontal blanking
- vertical frame size
- vertical sync start/end
- vertical blanking
- sync polarities

After Vivado generation, inspect the produced HWH because VTC parameters
may be normalized by the IP generator.

## Files to change in Phase 5B

Expected HDL/Vivado-side edits:

- `hw/Pynq-Z2/hdmi_integration.tcl`
  - change `clk_wiz_hdmi` requested pixel clock
  - change `v_tc_hdmi` generation parameters to 800x480
  - change `rgb2dvi_hdmi` `kClkRange` if required by the selected
    pixel clock
  - keep existing IP names and AXI addresses if possible
- do not edit `hw/Pynq-Z2/block_design.tcl` unless the user separately
  approves a block-design base change
- do not edit audio GPIO names, addresses, or `ctrlA`-`ctrlD` meanings
- do not edit Clash/DSP/`LowPassFir.hs`/`topEntity`

Expected Python edits:

- `audio_lab_pynq/hdmi_backend.py`
  - make HDMI width/height defaults 800x480 for the 800x480 bitstream,
    or add an explicit mode constant with no 720p fallback ambiguity
  - set VDMA `hsize_bytes=2400`, `stride_bytes=2400`,
    `vsize_lines=480`
  - keep RGB888 -> `GBR888` swizzle
  - update status strings and frame-size validation
- `scripts/test_hdmi_output_mapping_720p.py`
  - keep as archived Phase 5A diagnostic; do not use for 800x480
- add a new 800x480 native mapping test script, or update existing
  `scripts/test_hdmi_800x480_frame.py` to use direct native scanout
  without composing into a 1280x720 canvas
- update docs:
  - `CURRENT_STATE.md`
  - `HDMI_GUI_INTEGRATION_PLAN.md`
  - `TIMING_AND_FPGA_NOTES.md`
  - a Phase 5B result doc after build/test

## Build and deploy sequence

1. Back up the current deployed bit/hwh locally and on the board.
2. Confirm `git status --short` and ensure no unrelated dirty Vivado
   artifacts are present.
3. Make the 800x480 Tcl/Python edits.
4. Run local Python syntax/tests for the touched Python files.
5. Build with Vivado only after explicit approval:

   ```sh
   cd hw/Pynq-Z2
   make
   ```

6. Inspect timing:

   ```sh
   tail -200 /tmp/vivado_build.log | grep -E 'WNS|TNS|WHS|THS|CRITICAL WARNING'
   ```

7. Do not deploy if WNS is significantly worse than `-8.163 ns` or if
   hold is not clean.
8. Deploy only the accepted bit/hwh plus matching Python backend.
9. Run an 800x480 native mapping test and Safe Bypass smoke.
10. Have the user visually confirm LCD fit, color order, and viewport.

## Timing and integration risks

- 800x480 is less universal than CEA 720p. Some HDMI LCD controller
  boards accept it; others only scale from common CEA/VESA modes.
- `rgb2dvi` clock generation must be valid at the selected pixel clock.
  The current `kClkRange=3` was chosen for 74.25 MHz; lower clocks may
  need a different range.
- VTC generated parameters can differ from the requested Tcl values in
  the HWH. Always inspect HWH after build.
- A lower pixel clock reduces HDMI bandwidth but still changes clocking,
  reset, and timing constraints. A fresh timing summary is mandatory.
- Python code and bitstream must agree on framebuffer size. Running an
  800x480 backend against a 720p bitstream, or the reverse, is a
  test-invalid configuration.

## Rollback plan

Before any Phase 5B deploy:

- save current `hw/Pynq-Z2/bitstreams/audio_lab.bit`
- save current `hw/Pynq-Z2/bitstreams/audio_lab.hwh`
- save board-side `/home/xilinx/Audio-Lab-PYNQ/audio_lab_pynq/bitstreams/`
  copies if needed

Rollback steps:

1. Restore the 1280x720 `audio_lab.bit` / `audio_lab.hwh` pair.
2. Restore the 1280x720 `audio_lab_pynq/hdmi_backend.py`.
3. Re-run `scripts/test_hdmi_static_frame.py` or
   `scripts/test_hdmi_output_mapping_720p.py`.
4. Confirm `VDMACR=0x00010001`, no VDMA error bits, and VTC
   `vtc_ctl=0x00000006`.

## Phase 5B implementation prompt draft

```text
HDMI GUI Phase 5B: implement a native 800x480 HDMI timing trial for the
5-inch LCD.

Constraints:
- no git push/pull/fetch
- back up current bit/hwh before build
- do not touch Clash/DSP/LowPassFir.hs/topEntity
- do not change GPIO names/addresses/ctrlA-D semantics
- do not edit block_design.tcl unless explicitly approved
- update hdmi_integration.tcl, hdmi_backend.py, scripts, and docs only
- rebuild bit/hwh only after confirming the 800x480 timing values
- compare timing against WNS -8.163 ns / hold-clean baseline
- deploy only if timing is acceptable

Target:
- active 800x480
- framebuffer 800x480 RGB888 packed to DDR GBR888
- VDMA HSIZE=2400, STRIDE=2400, VSIZE=480
- pixel clock selected from EDID/spec if available, otherwise a
  documented 800x480@60 trial value
- rgb2dvi kClkRange adjusted for the selected pixel clock

Required output:
- timing summary
- bit/hwh backup paths
- PYNQ run log
- VDMA/VTC status
- user visual confirmation items
- rollback instructions
```
