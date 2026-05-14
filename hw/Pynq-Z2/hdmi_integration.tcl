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
#        clk_wiz_hdmi      - 100 MHz -> 74.25 MHz pixel clock
#        rst_video_0       - proc_sys_reset for the pixel-clock domain
#        axi_vdma_hdmi     - framebuffer MM2S, 32-bit memory, 24-bit stream
#        v_tc_hdmi         - 1280x720@60 video timing generator
#        v_axi4s_vid_out_hdmi - AXI4-Stream video -> parallel video
#        rgb2dvi_hdmi      - Digilent TMDS encoder (kClkRange=3 / 720p)
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

puts "HDMI: starting Phase 4 integration on [current_bd_design]"

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
# 4. clk_wiz_hdmi: 100 MHz FCLK_CLK0 -> 74.25 MHz pixel clock
#    rgb2dvi makes its own 5x serial clock internally (kGenerateSerialClk=true),
#    so this clk_wiz only needs one output.
# -----------------------------------------------------------------------------
set clk_wiz_hdmi [create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_hdmi]
set_property -dict [list \
    CONFIG.PRIMITIVE {MMCM} \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {74.250} \
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
# 7. v_tc_hdmi: CEA-861 1280x720@60 progressive timing
#    Pixel clock 74.25 MHz; Htotal 1650; Vtotal 750.
#    Hblanking: HFP 110, HSync 40, HBP 220; HSync active high.
#    Vblanking: VFP 5,  VSync 5,  VBP 20;  VSync active high.
# -----------------------------------------------------------------------------
set v_tc_hdmi [create_bd_cell -type ip -vlnv xilinx.com:ip:v_tc:6.1 v_tc_hdmi]
set_property -dict [list \
    CONFIG.enable_generation       {true} \
    CONFIG.enable_detection        {false} \
    CONFIG.GEN_F0_VSYNC_HSTART     {1390} \
    CONFIG.GEN_F0_VSYNC_HEND       {1390} \
    CONFIG.GEN_F0_VFRAME_SIZE      {750} \
    CONFIG.GEN_F0_VSYNC_VSTART     {725} \
    CONFIG.GEN_F0_VSYNC_VEND       {730} \
    CONFIG.GEN_F1_VSYNC_HSTART     {1390} \
    CONFIG.GEN_F1_VSYNC_HEND       {1390} \
    CONFIG.GEN_F1_VFRAME_SIZE      {750} \
    CONFIG.GEN_F1_VSYNC_VSTART     {725} \
    CONFIG.GEN_F1_VSYNC_VEND       {730} \
    CONFIG.GEN_HACTIVE_SIZE        {1280} \
    CONFIG.GEN_HFRAME_SIZE         {1650} \
    CONFIG.GEN_HSYNC_START         {1390} \
    CONFIG.GEN_HSYNC_END           {1430} \
    CONFIG.GEN_VACTIVE_SIZE        {720} \
    CONFIG.GEN_CHROMA_PARITY       {0} \
    CONFIG.GEN_HSYNC_POLARITY      {High} \
    CONFIG.GEN_VSYNC_POLARITY      {High} \
    CONFIG.GEN_VIDEO_FORMAT        {RGB} \
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
# 9. rgb2dvi_hdmi: Digilent TMDS encoder, 720p band, internal serial clock
# -----------------------------------------------------------------------------
set rgb2dvi_hdmi [create_bd_cell -type ip -vlnv digilentinc.com:ip:rgb2dvi:1.4 rgb2dvi_hdmi]
set_property -dict [list \
    CONFIG.kClkRange         {3} \
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
puts "HDMI: Phase 4 integration applied. validate_bd_design passed."
