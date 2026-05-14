# HDMI block_design.tcl patch plan (Phase 4 implemented reference)

Date: 2026-05-14

Status: **IMPLEMENTED IN PHASE 4.** This file began as the Phase 3
design-only patch plan. Phase 4 implemented the HDMI pieces in the
separate helper `hw/Pynq-Z2/hdmi_integration.tcl`, which is sourced by
`hw/Pynq-Z2/create_project.tcl` after the existing audio
`block_design.tcl`. The plan remains as the architectural reference and
is now aligned with the built RGB888 / 24-bit VDMA path.

Refer to `HDMI_GUI_PHASE3_VIVADO_DESIGN_PROPOSAL.md` for context on
why Option B (`axi_vdma` + `v_tc` + `v_axi4s_vid_out` + `rgb2dvi`) is
the recommended target.

## 1. Top-level port additions

In the "Create ports" section of `block_design.tcl`, add the HDMI TX
output pads:

```tcl
set hdmi_tx_clk_p   [ create_bd_port -dir O hdmi_tx_clk_p ]
set hdmi_tx_clk_n   [ create_bd_port -dir O hdmi_tx_clk_n ]
set hdmi_tx_data_p  [ create_bd_port -dir O -from 2 -to 0 hdmi_tx_data_p ]
set hdmi_tx_data_n  [ create_bd_port -dir O -from 2 -to 0 hdmi_tx_data_n ]
```

Match the port names to the Digilent `rgb2dvi` IP's TMDS port names
(some revisions name them `TMDS_Clk_p` / `TMDS_Data_p[2:0]`; align the
port and the constraint together).

## 2. PS7 changes

Inside the existing `set_property -dict [...] $processing_system7_0`
block, flip the HP0 enable:

```tcl
   CONFIG.PCW_USE_S_AXI_HP0 {1} \
```

The rest of the PS7 properties (FCLK0 = 100 MHz, GP0 enabled, MIO
mappings, codec_address, IIC_1) stay exactly as today. Do NOT turn on
FCLK1/2/3 to keep clock topology stable.

Add the new clock and reset hookups:

```tcl
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
               [get_bd_pins processing_system7_0/S_AXI_HP0_ACLK]
```

(The actual `connect_bd_net` for `processing_system7_0_FCLK_CLK0`
already enumerates every audio-domain client; append
`S_AXI_HP0_ACLK` to that long list rather than creating a new net.)

## 3. New IP instances

After the existing `axi_gpio_compressor` block, add (in this order to
keep the tcl readable):

```tcl
  # Create instance: clk_wiz_hdmi (single pixel clock; rgb2dvi makes its own serial clock)
  set clk_wiz_hdmi [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_hdmi ]
  set_property -dict [ list \
   CONFIG.PRIMITIVE {MMCM} \
   CONFIG.PRIM_IN_FREQ {100.000} \
   CONFIG.CLKOUT1_USED {true} \
   CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {74.250} \
   CONFIG.CLKOUT2_USED {false} \
   CONFIG.USE_RESET {true} \
   CONFIG.RESET_PORT {resetn} \
   CONFIG.RESET_TYPE {ACTIVE_LOW} \
 ] $clk_wiz_hdmi

  # Create instance: rst_video_0
  set rst_video_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_video_0 ]

  # Create instance: axi_vdma_hdmi
  set axi_vdma_hdmi [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_vdma:6.3 axi_vdma_hdmi ]
  set_property -dict [ list \
   CONFIG.c_m_axi_mm2s_data_width {32} \
   CONFIG.c_m_axis_mm2s_tdata_width {24} \
   CONFIG.c_include_s2mm {0} \
   CONFIG.c_num_fstores {3} \
 ] $axi_vdma_hdmi

  # The Python renderer input is RGB888, but the DDR framebuffer is
  # written as packed GBR888. That feeds VDMA byte0/1/2 into
  # vid_pData[7:0]/[15:8]/[23:16], matching Digilent rgb2dvi's
  # [23:16]=R, [15:8]=B, [7:0]=G mapping without an extra color
  # converter.

  # Create instance: v_tc_hdmi (Vivado 2019.1 local catalog ships v_tc 6.1)
  set v_tc_hdmi [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_tc:6.1 v_tc_hdmi ]
  set_property -dict [ list \
   CONFIG.enable_generation {true} \
   CONFIG.enable_detection {false} \
 ] $v_tc_hdmi

  # Create instance: v_axi4s_vid_out_hdmi
  set v_axi4s_vid_out_hdmi [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_axi4s_vid_out:4.0 v_axi4s_vid_out_hdmi ]
  set_property -dict [ list \
   CONFIG.C_HAS_ASYNC_CLK {1} \
 ] $v_axi4s_vid_out_hdmi

  # Create instance: rgb2dvi_hdmi (Digilent IP repo required;
  # kGenerateSerialClk=true keeps the IP's internal PLL,
  # kClkRange=3 is the < 80 MHz / 720p band that matches 74.25 MHz pixel clock,
  # kRstActiveHigh=false aligns with proc_sys_reset peripheral_aresetn)
  set rgb2dvi_hdmi [ create_bd_cell -type ip -vlnv digilentinc.com:ip:rgb2dvi:1.4 rgb2dvi_hdmi ]
  set_property -dict [ list \
   CONFIG.kClkRange {3} \
   CONFIG.kRstActiveHigh {false} \
   CONFIG.kGenerateSerialClk {true} \
 ] $rgb2dvi_hdmi
```

Exact VLNVs (`axi_vdma:6.3`, `v_tc:6.1`, `v_axi4s_vid_out:4.0`,
`rgb2dvi:1.4`) need a single Vivado 2019.1 IP catalog check in
Phase 4 — versions may have shifted in the local install.

## 4. Connections

Audio-side `axi_smc` already has `NUM_SI=2` (`axi_dma_0` MM2S +
S2MM). Add a new SmartConnect that routes VDMA into `S_AXI_HP0`:

```tcl
  # New SmartConnect for HDMI VDMA -> HP0
  set axi_smc_hdmi [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc_hdmi ]
  set_property -dict [ list \
   CONFIG.NUM_SI {1} \
   CONFIG.NUM_MI {1} \
 ] $axi_smc_hdmi

  connect_bd_intf_net [get_bd_intf_pins axi_vdma_hdmi/M_AXI_MM2S]   [get_bd_intf_pins axi_smc_hdmi/S00_AXI]
  connect_bd_intf_net [get_bd_intf_pins axi_smc_hdmi/M00_AXI]       [get_bd_intf_pins processing_system7_0/S_AXI_HP0]
```

Connect AXI-Lite control:

```tcl
  set_property -dict [ list CONFIG.NUM_MI {17} ] $ps7_0_axi_periph

  connect_bd_intf_net [get_bd_intf_pins ps7_0_axi_periph/M15_AXI]   [get_bd_intf_pins axi_vdma_hdmi/S_AXI_LITE]
  connect_bd_intf_net [get_bd_intf_pins ps7_0_axi_periph/M16_AXI]   [get_bd_intf_pins v_tc_hdmi/ctrl]
```

Connect video data path:

```tcl
  connect_bd_intf_net [get_bd_intf_pins axi_vdma_hdmi/M_AXIS_MM2S]  [get_bd_intf_pins v_axi4s_vid_out_hdmi/video_in]
  connect_bd_intf_net [get_bd_intf_pins v_tc_hdmi/vtiming_out]      [get_bd_intf_pins v_axi4s_vid_out_hdmi/vtiming_in]
  connect_bd_net      [get_bd_pins      v_axi4s_vid_out_hdmi/vid_io_out] \
                      [get_bd_pins      rgb2dvi_hdmi/vid_pData]
  # (vid_io_out is structured -- the actual sub-pins map to vid_pData / vid_pHSync / vid_pVSync / vid_pVDE)
```

Connect clocks and resets:

```tcl
  # pixel domain (serial clock is generated inside rgb2dvi)
  connect_bd_net [get_bd_pins clk_wiz_hdmi/clk_out1] \
                 [get_bd_pins v_axi4s_vid_out_hdmi/vid_io_out_clk] \
                 [get_bd_pins v_tc_hdmi/clk] \
                 [get_bd_pins rgb2dvi_hdmi/PixelClk]
  # FCLK side
  connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
                 [get_bd_pins axi_vdma_hdmi/s_axi_lite_aclk] \
                 [get_bd_pins axi_vdma_hdmi/m_axi_mm2s_aclk] \
                 [get_bd_pins axi_vdma_hdmi/m_axis_mm2s_aclk] \
                 [get_bd_pins axi_smc_hdmi/aclk] \
                 [get_bd_pins v_tc_hdmi/s_axi_aclk] \
                 [get_bd_pins clk_wiz_hdmi/clk_in1]
  # resets
  connect_bd_net [get_bd_pins rst_ps7_0_100M/peripheral_aresetn] \
                 [get_bd_pins axi_vdma_hdmi/axi_resetn] \
                 [get_bd_pins axi_smc_hdmi/aresetn] \
                 [get_bd_pins v_tc_hdmi/s_axi_aresetn]
  connect_bd_net [get_bd_pins clk_wiz_hdmi/locked] \
                 [get_bd_pins rst_video_0/dcm_locked]
  connect_bd_net [get_bd_pins rst_ps7_0_100M/peripheral_aresetn] \
                 [get_bd_pins rst_video_0/ext_reset_in]
  connect_bd_net [get_bd_pins rst_video_0/peripheral_aresetn] \
                 [get_bd_pins v_axi4s_vid_out_hdmi/aresetn]
  connect_bd_net [get_bd_pins rst_video_0/peripheral_aresetn] \
                 [get_bd_pins rgb2dvi_hdmi/aRst_n]
```

TMDS pad routing (exact sub-pin names depend on `rgb2dvi` revision;
check the IP's interface in Vivado 2019.1):

```tcl
  connect_bd_net [get_bd_pins rgb2dvi_hdmi/TMDS_Clk_p]     [get_bd_ports hdmi_tx_clk_p]
  connect_bd_net [get_bd_pins rgb2dvi_hdmi/TMDS_Clk_n]     [get_bd_ports hdmi_tx_clk_n]
  connect_bd_net [get_bd_pins rgb2dvi_hdmi/TMDS_Data_p]    [get_bd_ports hdmi_tx_data_p]
  connect_bd_net [get_bd_pins rgb2dvi_hdmi/TMDS_Data_n]    [get_bd_ports hdmi_tx_data_n]
```

## 5. Address map additions

Inside the "Create address segments" section, after
`SEG_axi_gpio_compressor_Reg`:

```tcl
  create_bd_addr_seg -range 0x00010000 -offset 0x43CE0000 \
    [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs axi_vdma_hdmi/S_AXI_LITE/Reg] \
    SEG_axi_vdma_hdmi_Reg

  create_bd_addr_seg -range 0x00010000 -offset 0x43CF0000 \
    [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs v_tc_hdmi/CTRL/Reg] \
    SEG_v_tc_hdmi_Reg

  create_bd_addr_seg -range 0x40000000 -offset 0x00000000 \
    [get_bd_addr_spaces axi_vdma_hdmi/Data_MM2S] \
    [get_bd_addr_segs processing_system7_0/S_AXI_HP0/HP0_DDR_LOWOCM] \
    SEG_processing_system7_0_HP0_DDR_LOWOCM
```

Do NOT change any of the existing `0x43C0_0000`..`0x43CD_0000`
address segments. Do NOT shuffle the existing `SEG_*` names.

## 6. Constraints (`hw/Pynq-Z2/audio_lab.xdc`) — new section

Add at the bottom of the existing constraints file:

```tcl
# HDMI TX (PYNQ-Z2 HDMI OUT)
# Pin locations are taken from the TUL PYNQ-Z2 board file
# /home/doi20/board_files/XilinxBoardStore/boards/TUL/pynq-z2/1.0/part0_pins.xml
# Keep only PACKAGE_PIN constraints here. Digilent rgb2dvi instantiates
# OBUFDS outputs and sets its own TMDS_33 IOSTANDARD; adding LVCMOS33 to
# these differential top-level ports makes Vivado placement fail.
set_property PACKAGE_PIN L16 [get_ports hdmi_tx_clk_p]
set_property PACKAGE_PIN L17 [get_ports hdmi_tx_clk_n]

set_property PACKAGE_PIN K17 [get_ports {hdmi_tx_data_p[0]}]
set_property PACKAGE_PIN K18 [get_ports {hdmi_tx_data_n[0]}]

set_property PACKAGE_PIN K19 [get_ports {hdmi_tx_data_p[1]}]
set_property PACKAGE_PIN J19 [get_ports {hdmi_tx_data_n[1]}]

set_property PACKAGE_PIN J18 [get_ports {hdmi_tx_data_p[2]}]
set_property PACKAGE_PIN H18 [get_ports {hdmi_tx_data_n[2]}]

# Cross-domain false paths between audio AXI clock (FCLK_CLK0) and the
# new pixel-clock domain. rgb2dvi's internally generated 5x serial clock
# stays inside the rgb2dvi PLL and is constrained by the IP-provided
# OOC XDC; no false_path entry is needed for it here.
set_false_path -from [get_clocks clk_fpga_0] -to [get_clocks -of_objects [get_pins clk_wiz_hdmi/inst/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins clk_wiz_hdmi/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks clk_fpga_0]
```

Pin assignments above come directly from the PYNQ-Z2 board file. The
prior Phase 3 draft incorrectly used `H16/H17/D19/D20/C20/B20/B19/A20`
under IOSTANDARD `TMDS_33`, which is the pin layout for a different
Digilent board (Arty Z7 / Zybo Z7); on PYNQ-Z2 those pins drive
different signals, so the original draft would not have worked.

## 7. Validation steps in Phase 4

1. `vivado -mode batch -source create_project.tcl` completes through
   `write_bitstream completed successfully`.
2. `report_clocks` shows `clk_fpga_0`, `clk_out1_clk_wiz_hdmi`,
   `clk_out2_clk_wiz_hdmi`, and the existing 24 MHz `mclk` clock.
3. `report_timing_summary` shows WNS / TNS / WHS / THS per clock
   domain. Audio domain WNS must not drop materially below
   `-8.5 ns`.
4. `hwh` exposes `axi_vdma_hdmi`, `v_tc_hdmi`, and
   `rgb2dvi_hdmi` as overlay attributes.
5. PYNQ-side smoke: `AudioLabOverlay()` loads once, then
   `hasattr(overlay, 'axi_vdma_hdmi')` returns True.

## 8. What this plan does NOT change

- No edits to `hw/ip/clash/` (`LowPassFir.hs`, `AudioLab/*`).
- No changes to the Clash IP repackage (no new `topEntity` ports).
- No changes to `axi_gpio_*` instances, addresses, or
  `ctrlA`-`ctrlD` semantics.
- No changes to `i2s_to_stream_0`, `axis_data_fifo_0`, the two
  subset converters, or `clash_lowpass_fir_0` connections.
- No changes to `axi_dma_0` (the audio DMA), `axi_smc`, or
  `clk_wiz_0` (the 24 MHz `mclk` generator).
- No changes to `fx_gain_0` placement or address.
- No new GPIO. No legacy `axi_gpio_delay` rename or removal.
