# HDMI GUI Phase 5A output-side diagnosis

Date: 2026-05-15 JST

## Summary

Phase 5A changes the diagnosis direction for the 5-inch HDMI LCD. Phase
4D through Phase 4J tried Python-side fit modes, 800x480 logical
rendering, manual placement, negative offsets, and horizontal offset
sweeps while keeping the HDMI signal at 1280x720. The user observation
now points at the HDMI output side rather than another GUI offset:
800x480 logical content still appears with a left blank strip and the
right side clipped on the physical 5-inch panel.

The working interpretation is that the LCD is not mapping the full
1280x720 active video area onto its 800x480 panel in the way the Python
framebuffer code assumes. Phase 5A therefore stops chasing more offsets
and records the current HDMI timing / VDMA / `v_axi4s_vid_out` /
`rgb2dvi` / LCD viewport evidence.

No Vivado rebuild, no bit/hwh regeneration, no `block_design.tcl`,
`audio_lab.xdc`, `create_project.tcl`, Clash/DSP, `topEntity`, GPIO,
VDMA topology, or VTC timing change is made in Phase 5A.

## Dirty-state handling

Starting branch:
`feature/hdmi-gui-phase4-vivado-integration`

Latest committed baseline at start:
`8f1ff95 Restore 800x480 HDMI GUI compact layout baseline`

Before this diagnosis, the dirty tree was backed up to:

- `/tmp/fpga_guitar_effecter_backup/phase5a_before_output_diagnosis_dirty.patch`
- `/tmp/fpga_guitar_effecter_backup/phase5a_before_output_diagnosis_status.txt`

Because `git diff` does not include untracked file contents, the
untracked Phase 4J files were also copied to:

- `/tmp/fpga_guitar_effecter_backup/test_hdmi_800x480_horizontal_offsets.py`
- `/tmp/fpga_guitar_effecter_backup/HDMI_GUI_PHASE4J_HORIZONTAL_LEFT_SHIFT.md`

The Phase 4J horizontal offset sweep is treated as an interrupted,
uncommitted offset-side diagnostic that is useful as a log but
superseded by this output-side diagnosis. It is not a completed runtime
default selection.

At preflight, these Vivado / bitstream paths had no dirty status:

- `hw/Pynq-Z2/block_design.tcl`
- `hw/Pynq-Z2/audio_lab.xdc`
- `hw/Pynq-Z2/create_project.tcl`
- `hw/Pynq-Z2/bitstreams/audio_lab.bit`
- `hw/Pynq-Z2/bitstreams/audio_lab.hwh`

## Current 720p output path

The deployed HDMI path is still the Phase 4 integrated framebuffer path:

```text
PS DDR framebuffer
  -> axi_vdma_hdmi MM2S
  -> AXI4-Stream video
  -> v_axi4s_vid_out_hdmi
  -> native RGB / sync / active-video
  -> rgb2dvi_hdmi
  -> PYNQ-Z2 HDMI OUT TMDS pins
```

Important cells and addresses:

| IP | Current role | Address |
| --- | --- | --- |
| `axi_vdma_hdmi` | MM2S framebuffer scanout | `0x43CE0000` |
| `v_tc_hdmi` | 1280x720 timing generator | `0x43CF0000` |
| `v_axi4s_vid_out_hdmi` | AXI4-Stream video to native video | HWH-only |
| `rgb2dvi_hdmi` | Digilent TMDS encoder | HWH-only |
| `clk_wiz_hdmi` | 100 MHz FCLK0 to 74.25 MHz pixel clock | n/a |

Framebuffer and VDMA:

- active framebuffer: `1280x720`
- input frame format: RGB888 `numpy.ndarray`
- DDR format: packed `GBR888`
- stream format: 24-bit `vid_pData`, `[23:16]=R`, `[15:8]=B`, `[7:0]=G`
- VDMA memory data width: 32-bit
- VDMA stream width: 24-bit
- VDMA `HSIZE`: `3840` bytes
- VDMA `STRIDE`: `3840` bytes
- VDMA `VSIZE`: `720` lines
- framebuffer bytes copied per full update: `2,764,800`

Timing and clocks:

- intended mode: 1280x720 progressive, 60 Hz class
- pixel clock: `74.25 MHz`
- horizontal active: `1280`
- horizontal total: `1650`
- horizontal sync: start `1390`, end `1430`, polarity high
- vertical active: `720`
- vertical total: `750`
- HWH reports vertical sync start/end as `724` / `729`, polarity high
- HWH reports VTC video mode as `720p`
- `rgb2dvi_hdmi` uses `kGenerateSerialClk=true`
- current `rgb2dvi_hdmi` `kClkRange`: `3`

The deployed HWH should be treated as the source of truth for the bit
that is currently on the board. `hw/Pynq-Z2/hdmi_integration.tcl`
contains comments and requested VTC parameters for CEA-style 720p, but
the HWH reports the generated VTC values after Vivado/IP processing.
Any Phase 5B timing change must re-check the generated HWH, not only
the Tcl.

HDMI OUT pin constraints:

- `hdmi_tx_clk_p/n`: `L16` / `L17`
- `hdmi_tx_data_p/n[0]`: `K17` / `K18`
- `hdmi_tx_data_p/n[1]`: `K19` / `J19`
- `hdmi_tx_data_p/n[2]`: `J18` / `H18`
- `audio_lab.xdc` intentionally sets `PACKAGE_PIN` only for these HDMI
  TX pins. `rgb2dvi` owns the differential output primitives and
  `TMDS_33` settings internally.

## Output-side hypotheses

### Hypothesis A

The 1280x720 HDMI timing is internally healthy, but the 5-inch LCD's
controller scales or crops 720p input into its 800x480 panel with its
own viewport. The left blank strip and right clipping are then LCD-side
crop/shift artefacts, not Python placement errors.

### Hypothesis B

The VTC / `v_axi4s_vid_out` / `rgb2dvi` chain produces timing that is
valid enough for the LCD to lock, but one of active-video, blanking,
sync polarity, or data-enable interpretation does not match what the
LCD controller expects. The controller may be detecting the active
region offset incorrectly.

### Hypothesis C

The framebuffer format, VDMA line stride, and RGB888 byte order are
largely correct because the screen locks and previous tests showed no
VDMA internal/slave/decode errors. The remaining mismatch is likely
which part of the 1280x720 active area the LCD presents as visible.

### Hypothesis D

The LCD may advertise or tolerate 720p input but behave best when fed
native 800x480 timing. In that case the right next engineering move is
not another Python offset but a controlled Phase 5B experiment with
800x480 active timing, new pixel clock, and 800x480 framebuffer/VDMA
programming.

Phase 5A conclusion candidate: native 800x480 HDMI timing is worth a
separate Phase 5B implementation trial after approval.

## Output mapping script

New diagnostic script:

- `scripts/test_hdmi_output_mapping_720p.py`

Purpose:

- draw a full 1280x720 active-video coordinate pattern
- show outer borders and a 50 px grid
- label x/y coordinates (`0, 100, 200, ... 1280` and
  `0, 100, 200, ... 720`)
- label the active area as `1280x720 HDMI ACTIVE`
- show candidate 800x480 boxes:
  - `x=0,y=0,w=800,h=480`
  - `x=240,y=120,w=800,h=480`
  - `x=0,y=120,w=800,h=480`
  - `x=160,y=120,w=800,h=480`
- print VDMA/VTC status and VDMA error bits
- hold the frame so the user can read the physical LCD

The test does not compensate with offsets. The user should inspect the
LCD and report which x/y coordinate labels and which candidate boxes are
visible.

Board invocation:

```sh
ssh xilinx@192.168.1.9 '
  cd /home/xilinx/Audio-Lab-PYNQ &&
  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
    python3 scripts/test_hdmi_output_mapping_720p.py --hold-seconds 60
'
```

## EDID / DDC investigation

Local board-file findings:

- the PYNQ-Z2 board file exposes HDMI OUT TMDS pins and `hdmi_tx_hpd`
- it exposes `hdmi_in_ddc_scl` / `hdmi_in_ddc_sda` for HDMI IN DDC
- no HDMI OUT DDC SCL/SDA is constrained in `audio_lab.xdc`
- `IIC_1_scl_io` / `IIC_1_sda_io` in this design are on `U9` / `T9`,
  which the board file labels as audio I2C (`audio_sc_i` /
  `audio_sd_i`), not HDMI OUT DDC

Board-side read-only probes:

```text
/sys/class/drm:
card0
renderD128
version

/dev/i2c*:
/dev/i2c-0
/dev/i2c-1

i2cdetect -l:
i2c-1  Cadence I2C at e0005000
i2c-0  Cadence I2C at e0004000
```

No `/sys/class/drm/.../edid` file was found, and no DRM connector
status was available. This is expected for the PL HDMI output path,
which is not Linux DRM-managed. Phase 5A did not run any I2C writes or
blind DDC probing. EDID is therefore not currently available from this
software path.

## Phase 5A runtime result

Command:

```sh
ssh xilinx@192.168.1.9 '
  cd /home/xilinx/Audio-Lab-PYNQ &&
  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
    python3 scripts/test_hdmi_output_mapping_720p.py --hold-seconds 60
' 2>&1 | tee /tmp/hdmi_phase5a_output_mapping_720p.log
```

Result:

- script exit status: OK
- `AudioLabOverlay()` loaded exactly once
- no `base.bit`
- no `run_pynq_hdmi()`
- no second overlay
- ADC HPF: `true`
- `R19`: `0x23`
- legacy `axi_gpio_delay`: present
- `axi_gpio_delay_line`: absent
- `axi_vdma_hdmi` / `v_tc_hdmi`: present in `ip_dict`
- `rgb2dvi_hdmi` / `v_axi4s_vid_out_hdmi`: present in HWH
- output mapping draw time: `0.283 s`
- backend start time: `0.235 s`
- framebuffer physical address: `0x16900000`
- framebuffer size: `2,764,800` bytes
- framebuffer format: DDR `GBR888`
- VDMA `DMACR`: `0x00010001`
- VDMA `DMASR`: `0x00011000`
- VDMA `HSIZE`: `3840`
- VDMA `STRIDE`: `3840`
- VDMA `VSIZE`: `720`
- VDMA version register: `0x62000050`
- VTC control register: `0x00000006`
- VDMA error bits:
  - `dmainterr=false`
  - `dmaslverr=false`
  - `dmadecerr=false`
  - `halted=false`
  - `idle=false`

The board displayed the 720p output mapping frame for the 60-second
hold. Codex cannot visually inspect the LCD; the user must read and
report the visible x/y coordinate labels and candidate boxes from the
physical panel.

## Phase 5B conditions

Proceed to native 800x480 timing only after:

- the 720p mapping pattern confirms the LCD is not displaying the full
  1280x720 active area as expected, or the visible coordinates remain
  inconsistent with Python placement
- current bit/hwh are backed up
- Phase 5B edits are explicitly approved
- the implementation plan in
  `HDMI_GUI_PHASE5B_NATIVE_800X480_TIMING_PLAN.md` is followed
- Vivado rebuild output includes a fresh timing summary
- the resulting WNS is not significantly worse than the deployed
  Phase 4 HDMI baseline (`-8.163 ns`) and hold remains clean

## Rollback

Phase 5A itself is docs/script-only. Rollback is removing the new
mapping script and docs. For Phase 5B, rollback must restore the
previous `audio_lab.bit` / `audio_lab.hwh` pair and the 1280x720
`AudioLabHdmiBackend` defaults.
