# Phase 4 HDMI integration extension for the AudioLab block design.
#
# This script is sourced from create_project.tcl right after
# block_design.tcl finishes. It assumes the AudioLab block design
# already exists, is open, and is named "block_design". It does NOT
# touch any audio-domain IP, address, or net.
#
# What it does:
#   1. enables S_AXI_HP0 on the existing processing_system7_0
#   2. extends ps7_0_axi_periph from NUM_MI=15 to NUM_MI=17
#   3. adds new HDMI cells:
#        clk_wiz_hdmi      - 100 MHz -> selected pixel clock
#        rst_video_0       - proc_sys_reset for the pixel-clock domain
#        axi_vdma_hdmi     - framebuffer MM2S, 32-bit memory, 24-bit stream
#        v_tc_hdmi         - video timing generator (mode below)
#        v_axi4s_vid_out_hdmi - AXI4-Stream video -> parallel video
#        rgb2dvi_hdmi      - Digilent TMDS encoder (kClkRange=3 for 40-80 MHz)
#        axi_smc_hdmi      - SmartConnect from VDMA M_AXI_MM2S to PS HP0
#   4. wires clocks, resets, AXI-Lite, AXIS video, parallel video, TMDS
#   5. adds new top-level ports for HDMI TX (hdmi_tx_clk_p/n, data_p/n[2:0])
#   6. adds new address segments:
#        VDMA control      0x43CE0000 / 0x10000
#        VTC control       0x43CF0000 / 0x10000
#        HP0 DDR access    0x00000000 / 0x20000000 (for axi_vdma_hdmi Data_MM2S)
#   7. revalidates the block design and saves it.

current_bd_design [get_bd_designs block_design]
current_bd_instance /

# -----------------------------------------------------------------------------
# Phase 6I Candidate C2: VESA SVGA 800x600 @ 60 Hz.
#
# Rationale: rgb2dvi v1.4 kClkRange=3 needs PLLE2 VCO >= 800 MHz (~ pixel
# clock >= 40 MHz). The 5-inch LCD rejected the Phase 6H 40 MHz / 800x480
# hybrid timing (white screen). VESA SVGA 800x600 @ 60 Hz is a standard
# DMT mode that most HDMI receivers know, uses a 40 MHz pixel clock that
# fits the rgb2dvi band, and presents a familiar H/V total to the LCD's
# scaler. The 800x480 GUI is composed at framebuffer (0,0); the bottom
# 120 lines remain black.
#
# Rollback baselines for reference:
#   - 720p (working): active 1280x720, pixel 74.250 MHz,
#       H fp/sync/bp/total = 110/40/220/1650,
#       V fp/sync/bp/total =   5/ 5/ 20/ 750, rgb2dvi kClkRange=3.
#   - Phase 6H (rejected, white screen): active 800x480, pixel 40 MHz,
#       H fp/sync/bp/total = 40/128/ 88/1056,
#       V fp/sync/bp/total = 13/  3/132/ 628.
# -----------------------------------------------------------------------------
set HDMI_PHASE_LABEL "6I-C2-svga800x600"
set HDMI_ACTIVE_W 800
set HDMI_ACTIVE_H 600
set HDMI_H_FP 40
set HDMI_H_SYNC 128
set HDMI_H_BP 88
set HDMI_V_FP 1
set HDMI_V_SYNC 4
set HDMI_V_BP 23
set HDMI_H_TOTAL [expr {$HDMI_ACTIVE_W + $HDMI_H_FP + $HDMI_H_SYNC + $HDMI_H_BP}]
set HDMI_V_TOTAL [expr {$HDMI_ACTIVE_H + $HDMI_V_FP + $HDMI_V_SYNC + $HDMI_V_BP}]
set HDMI_HSYNC_START [expr {$HDMI_ACTIVE_W + $HDMI_H_FP}]
set HDMI_HSYNC_END [expr {$HDMI_HSYNC_START + $HDMI_H_SYNC}]
set HDMI_VSYNC_START [expr {$HDMI_ACTIVE_H + $HDMI_V_FP}]
set HDMI_VSYNC_END [expr {$HDMI_VSYNC_START + $HDMI_V_SYNC}]
set HDMI_PIXEL_CLOCK_MHZ 40.000
set HDMI_RGB2DVI_CLK_RANGE 3

puts "HDMI: starting Phase 6I integration ($HDMI_PHASE_LABEL) on [current_bd_design]"

# -----------------------------------------------------------------------------
# 1. Enable PS7 S_AXI_HP0 (currently off in the AudioLab design)
# -----------------------------------------------------------------------------
set_property -dict [list \
    CONFIG.PCW_USE_S_AXI_HP0 {1} \
] [get_bd_cells processing_system7_0]

# -----------------------------------------------------------------------------
# 2. Expand ps7_0_axi_periph from NUM_MI=15 to NUM_MI=17 (M15, M16)
# -----------------------------------------------------------------------------
set_property -dict [list CONFIG.NUM_MI {17}] [get_bd_cells ps7_0_axi_periph]

# -----------------------------------------------------------------------------
# 3. New top-level HDMI TX ports. audio_lab.xdc constrains only PACKAGE_PIN;
#    Digilent rgb2dvi owns the differential output IOSTANDARD through OBUFDS.
# -----------------------------------------------------------------------------
create_bd_port -dir O                  hdmi_tx_clk_p
create_bd_port -dir O                  hdmi_tx_clk_n
create_bd_port -dir O -from 2 -to 0    hdmi_tx_data_p
create_bd_port -dir O -from 2 -to 0    hdmi_tx_data_n

# -----------------------------------------------------------------------------
# 4. clk_wiz_hdmi: 100 MHz FCLK_CLK0 -> HDMI_PIXEL_CLOCK_MHZ pixel clock.
#    rgb2dvi makes its own 5x serial clock internally (kGenerateSerialClk=true),
#    so this clk_wiz only needs one output.
# -----------------------------------------------------------------------------
set clk_wiz_hdmi [create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_hdmi]
set_property -dict [list \
    CONFIG.PRIMITIVE {MMCM} \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $HDMI_PIXEL_CLOCK_MHZ \
    CONFIG.CLKOUT2_USED {false} \
    CONFIG.USE_RESET {true} \
    CONFIG.RESET_PORT {resetn} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
] $clk_wiz_hdmi

# -----------------------------------------------------------------------------
# 5. rst_video_0: proc_sys_reset gated by clk_wiz_hdmi/locked and ps7 reset
# -----------------------------------------------------------------------------
set rst_video_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_video_0]

# -----------------------------------------------------------------------------
# 6. axi_vdma_hdmi: MM2S only, 32-bit memory data, 24-bit stream, 3 fstores
#    The Python HDMI backend writes DDR as packed GBR888. With AXI byte 0
#    landing on TDATA[7:0], this matches rgb2dvi's vid_pData mapping:
#    [23:16]=R, [15:8]=B, [7:0]=G.
# -----------------------------------------------------------------------------
set axi_vdma_hdmi [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_vdma:6.3 axi_vdma_hdmi]
set_property -dict [list \
    CONFIG.c_include_sg {0} \
    CONFIG.c_include_s2mm {0} \
    CONFIG.c_m_axi_mm2s_data_width {32} \
    CONFIG.c_m_axis_mm2s_tdata_width {24} \
    CONFIG.c_num_fstores {3} \
    CONFIG.c_mm2s_linebuffer_depth {512} \
    CONFIG.c_mm2s_max_burst_length {16} \
] $axi_vdma_hdmi

# -----------------------------------------------------------------------------
# 7. v_tc_hdmi: progressive RGB timing using HDMI_* variables above.
#
#   IMPORTANT: the per-field GEN_* parameters are gated by VIDEO_MODE.
#   When VIDEO_MODE is left at a preset (e.g. 1280x720p) the individual
#   GEN_* values become disabled and silently ignored. Switch to Custom
#   in a separate set_property pass first so the GEN_* values stick.
# -----------------------------------------------------------------------------
set v_tc_hdmi [create_bd_cell -type ip -vlnv xilinx.com:ip:v_tc:6.1 v_tc_hdmi]
set_property -dict [list \
    CONFIG.enable_generation       {true} \
    CONFIG.enable_detection        {false} \
    CONFIG.VIDEO_MODE              {Custom} \
    CONFIG.GEN_VIDEO_FORMAT        {RGB} \
] $v_tc_hdmi
set_property -dict [list \
    CONFIG.GEN_F0_VSYNC_HSTART     $HDMI_HSYNC_START \
    CONFIG.GEN_F0_VSYNC_HEND       $HDMI_HSYNC_START \
    CONFIG.GEN_F0_VBLANK_HSTART    $HDMI_ACTIVE_W \
    CONFIG.GEN_F0_VBLANK_HEND      $HDMI_ACTIVE_W \
    CONFIG.GEN_F0_VFRAME_SIZE      $HDMI_V_TOTAL \
    CONFIG.GEN_F0_VSYNC_VSTART     $HDMI_VSYNC_START \
    CONFIG.GEN_F0_VSYNC_VEND       $HDMI_VSYNC_END \
    CONFIG.GEN_HACTIVE_SIZE        $HDMI_ACTIVE_W \
    CONFIG.GEN_HFRAME_SIZE         $HDMI_H_TOTAL \
    CONFIG.GEN_HSYNC_START         $HDMI_HSYNC_START \
    CONFIG.GEN_HSYNC_END           $HDMI_HSYNC_END \
    CONFIG.GEN_VACTIVE_SIZE        $HDMI_ACTIVE_H \
    CONFIG.GEN_HSYNC_POLARITY      {High} \
    CONFIG.GEN_VSYNC_POLARITY      {High} \
] $v_tc_hdmi

# -----------------------------------------------------------------------------
# 8. v_axi4s_vid_out_hdmi: 24-bit RGB, 1 pixel/clock, async stream/pixel clocks
# -----------------------------------------------------------------------------
set v_axi4s_vid_out_hdmi [create_bd_cell -type ip -vlnv xilinx.com:ip:v_axi4s_vid_out:4.0 v_axi4s_vid_out_hdmi]
set_property -dict [list \
    CONFIG.C_HAS_ASYNC_CLK   {1} \
    CONFIG.C_VTG_MASTER_SLAVE {1} \
] $v_axi4s_vid_out_hdmi

# -----------------------------------------------------------------------------
# 9. rgb2dvi_hdmi: Digilent TMDS encoder, kClkRange selected above,
#    internal serial clock.
# -----------------------------------------------------------------------------
set rgb2dvi_hdmi [create_bd_cell -type ip -vlnv digilentinc.com:ip:rgb2dvi:1.4 rgb2dvi_hdmi]
set_property -dict [list \
    CONFIG.kClkRange         $HDMI_RGB2DVI_CLK_RANGE \
    CONFIG.kRstActiveHigh    {false} \
    CONFIG.kGenerateSerialClk {true} \
] $rgb2dvi_hdmi

# -----------------------------------------------------------------------------
# 10. axi_smc_hdmi: 1 slave (VDMA MM2S) -> 1 master (PS S_AXI_HP0)
# -----------------------------------------------------------------------------
set axi_smc_hdmi [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc_hdmi]
set_property -dict [list \
    CONFIG.NUM_SI {1} \
    CONFIG.NUM_MI {1} \
] $axi_smc_hdmi

# -----------------------------------------------------------------------------
# 11. AXI / AXIS / parallel-video / TMDS connections
# -----------------------------------------------------------------------------

# AXI-Lite control (FCLK domain) -- VDMA M15, VTC M16
connect_bd_intf_net [get_bd_intf_pins ps7_0_axi_periph/M15_AXI] \
                    [get_bd_intf_pins axi_vdma_hdmi/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins ps7_0_axi_periph/M16_AXI] \
                    [get_bd_intf_pins v_tc_hdmi/ctrl]

# VDMA MM2S -> SmartConnect -> PS HP0 (framebuffer reads)
connect_bd_intf_net [get_bd_intf_pins axi_vdma_hdmi/M_AXI_MM2S] \
                    [get_bd_intf_pins axi_smc_hdmi/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc_hdmi/M00_AXI] \
                    [get_bd_intf_pins processing_system7_0/S_AXI_HP0]

# Video data path: VDMA -> v_axi4s_vid_out
connect_bd_intf_net [get_bd_intf_pins axi_vdma_hdmi/M_AXIS_MM2S] \
                    [get_bd_intf_pins v_axi4s_vid_out_hdmi/video_in]
# v_tc -> v_axi4s_vid_out (timing)
connect_bd_intf_net [get_bd_intf_pins v_tc_hdmi/vtiming_out] \
                    [get_bd_intf_pins v_axi4s_vid_out_hdmi/vtiming_in]
# v_axi4s_vid_out parallel video -> rgb2dvi RGB interface
connect_bd_intf_net [get_bd_intf_pins v_axi4s_vid_out_hdmi/vid_io_out] \
                    [get_bd_intf_pins rgb2dvi_hdmi/RGB]

# TMDS outputs -> top-level ports
connect_bd_net [get_bd_pins rgb2dvi_hdmi/TMDS_Clk_p]   [get_bd_ports hdmi_tx_clk_p]
connect_bd_net [get_bd_pins rgb2dvi_hdmi/TMDS_Clk_n]   [get_bd_ports hdmi_tx_clk_n]
connect_bd_net [get_bd_pins rgb2dvi_hdmi/TMDS_Data_p]  [get_bd_ports hdmi_tx_data_p]
connect_bd_net [get_bd_pins rgb2dvi_hdmi/TMDS_Data_n]  [get_bd_ports hdmi_tx_data_n]

# Clocks
# FCLK_CLK0 domain consumers
foreach pin {
    clk_wiz_hdmi/clk_in1
    axi_vdma_hdmi/s_axi_lite_aclk
    axi_vdma_hdmi/m_axi_mm2s_aclk
    axi_vdma_hdmi/m_axis_mm2s_aclk
    axi_smc_hdmi/aclk
    v_tc_hdmi/s_axi_aclk
    processing_system7_0/S_AXI_HP0_ACLK
    ps7_0_axi_periph/M15_ACLK
    ps7_0_axi_periph/M16_ACLK
    v_axi4s_vid_out_hdmi/aclk
} {
    connect_bd_net [get_bd_pins $pin] [get_bd_pins processing_system7_0/FCLK_CLK0]
}

# Pixel-clock domain consumers
foreach pin {
    v_tc_hdmi/clk
    v_axi4s_vid_out_hdmi/vid_io_out_clk
    rgb2dvi_hdmi/PixelClk
    rst_video_0/slowest_sync_clk
} {
    connect_bd_net [get_bd_pins $pin] [get_bd_pins clk_wiz_hdmi/clk_out1]
}

# FCLK-side resets (system reset is active-low)
foreach pin {
    axi_vdma_hdmi/axi_resetn
    axi_smc_hdmi/aresetn
    v_tc_hdmi/s_axi_aresetn
    ps7_0_axi_periph/M15_ARESETN
    ps7_0_axi_periph/M16_ARESETN
    v_axi4s_vid_out_hdmi/aresetn
    clk_wiz_hdmi/resetn
} {
    connect_bd_net [get_bd_pins $pin] [get_bd_pins rst_ps7_0_100M/peripheral_aresetn]
}

# Video-domain reset chain
connect_bd_net [get_bd_pins clk_wiz_hdmi/locked]                  [get_bd_pins rst_video_0/dcm_locked]
connect_bd_net [get_bd_pins rst_ps7_0_100M/peripheral_aresetn]    [get_bd_pins rst_video_0/ext_reset_in]
connect_bd_net [get_bd_pins rst_video_0/peripheral_aresetn]       [get_bd_pins rgb2dvi_hdmi/aRst_n]
connect_bd_net [get_bd_pins rst_video_0/peripheral_reset]         [get_bd_pins v_axi4s_vid_out_hdmi/vid_io_out_reset]

# -----------------------------------------------------------------------------
# 12. Address segments
# -----------------------------------------------------------------------------
create_bd_addr_seg -range 0x00010000 -offset 0x43CE0000 \
    [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs axi_vdma_hdmi/S_AXI_LITE/Reg] \
    SEG_axi_vdma_hdmi_Reg

create_bd_addr_seg -range 0x00010000 -offset 0x43CF0000 \
    [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs v_tc_hdmi/CTRL/Reg] \
    SEG_v_tc_hdmi_Reg

create_bd_addr_seg -range 0x20000000 -offset 0x00000000 \
    [get_bd_addr_spaces axi_vdma_hdmi/Data_MM2S] \
    [get_bd_addr_segs processing_system7_0/S_AXI_HP0/HP0_DDR_LOWOCM] \
    SEG_processing_system7_0_HP0_DDR_LOWOCM

# -----------------------------------------------------------------------------
# Final validate + save
# -----------------------------------------------------------------------------
validate_bd_design
save_bd_design
puts "HDMI: Phase 6I integration ($HDMI_PHASE_LABEL) applied. validate_bd_design passed."
