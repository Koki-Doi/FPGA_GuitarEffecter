# Phase Pmod-1/2/3 Pmod I2S2 bring-up integration for the AudioLab block design.
#
# Sourced from create_project.tcl in the `pmod-i2s2-bringup` build variant
# AFTER encoder_integration.tcl. This variant intentionally does NOT source
# pcm5102_dac_integration.tcl or pcm1808_adc_integration.tcl -- PMOD JB is
# dedicated to Digilent Pmod I2S2 (CS4344 DAC + CS5343 ADC) and the existing
# PCM5102 / PCM1808 jumper wiring must be physically removed before
# powering the board.
#
# What this script does:
#   1. Builds the clk_wiz_audio_ext MMCM (100 MHz -> 12.288 MHz exact) -- same
#      math the Phase 7C pcm5102_dac_integration.tcl uses. This variant
#      cannot rely on pcm5102_dac_integration.tcl to create the MMCM because
#      that script is not sourced in this build.
#   2. Bumps ps7_0_axi_periph from NUM_MI=18 to NUM_MI=19 (adds M18) so the
#      pmod_i2s2 status register block can sit on AXI-Lite. M17 stays the
#      encoder. The HDMI VDMA (0x43CE0000) / VTC (0x43CF0000) / reserved
#      0x43D00000 / encoder (0x43D10000) slots are preserved.
#   3. Adds eight top-level Pmod I2S2 ports on PMOD JB:
#        ext_pmod_i2s2_da_mclk_o   JB1  W14   (D/A side)
#        ext_pmod_i2s2_da_lrck_o   JB2  Y14
#        ext_pmod_i2s2_da_sclk_o   JB3  T11
#        ext_pmod_i2s2_da_sdin_o   JB4  T10
#        ext_pmod_i2s2_ad_mclk_o   JB7  V16   (A/D side)
#        ext_pmod_i2s2_ad_lrck_o   JB8  W16
#        ext_pmod_i2s2_ad_sclk_o   JB9  V12
#        ext_pmod_i2s2_ad_sdout_i  JB10 W13   <- only INPUT
#   4. Instantiates `pmod_i2s2_master` and `axi_pmod_i2s2_status` as block-
#      design module references. The master's MCLK input is wired to
#      clk_wiz_audio_ext/clk_out1. The 11 status output buses go straight to
#      the AXI-Lite slave's matching input buses (the slave does the CDC).
#   5. Connects the status slave's AXI-Lite to ps7_0_axi_periph/M18_AXI and
#      maps an AXI-Lite address segment at 0x43D20000 / 0x10000.
#   6. validate_bd_design + save_bd_design.
#
# What this script does NOT touch:
#   - ADAU1761 audio path (mclk / bclk / lrclk / sdata_i / sdata_o /
#     i2s_to_stream_0 / clash_lowpass_fir_0 / axis_switch_* / axi_dma_0).
#   - HDMI integration (VDMA, v_tc, rgb2dvi)
#   - Rotary encoder integration (axi_encoder_input at 0x43D10000)
#   - GPIO control map (axi_gpio_*) and addresses
#   - LowPassFir.hs / topEntity / DSP coefficients
#
# Address map after this script runs:
#   M00..M14  : existing AudioLab GPIO + DMA control
#   M15       : axi_vdma_hdmi  @ 0x43CE0000
#   M16       : v_tc_hdmi      @ 0x43CF0000
#   M17       : axi_encoder    @ 0x43D10000
#   M18       : axi_pmod_i2s2_status @ 0x43D20000  (new)
#
# Clock math for clk_wiz_audio_ext (verified by Phase 7C):
#   CLKIN=100 MHz, M_F=48.0, D=5 -> VCO=960 MHz
#   CLKOUT0 divider = 78.125 -> 12.288 MHz exact

current_bd_design [get_bd_designs block_design]
current_bd_instance /

set PMOD_AXI_OFFSET 0x43D20000
set PMOD_AXI_RANGE  0x00010000

puts "PMOD_I2S2: starting Phase Pmod-1/2/3 bring-up integration at $PMOD_AXI_OFFSET / $PMOD_AXI_RANGE on [current_bd_design]"

# -----------------------------------------------------------------------------
# 1. clk_wiz_audio_ext MMCM (100 MHz -> 12.288 MHz exact). Identical config to
#    the one pcm5102_dac_integration.tcl built in Phase 7C, but recreated here
#    so this build variant does not require the PCM5102 / PCM1808 scripts.
# -----------------------------------------------------------------------------
set clk_wiz_audio_ext [create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_audio_ext]
set_property -dict [list \
    CONFIG.PRIMITIVE              {MMCM}             \
    CONFIG.PRIM_SOURCE            {Global_buffer}    \
    CONFIG.PRIM_IN_FREQ           {100.000}          \
    CONFIG.CLKOUT1_USED           {true}             \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {12.288}       \
    CONFIG.USE_LOCKED             {true}             \
    CONFIG.USE_RESET              {true}             \
    CONFIG.RESET_PORT             {resetn}           \
    CONFIG.RESET_TYPE             {ACTIVE_LOW}       \
    CONFIG.CLKIN1_JITTER_PS       {100.0}            \
    CONFIG.MMCM_DIVCLK_DIVIDE     {5}                \
    CONFIG.MMCM_CLKFBOUT_MULT_F   {48.000}           \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F  {78.125}           \
    CONFIG.CLKOUT1_JITTER         {280.0}            \
    CONFIG.CLKOUT1_PHASE_ERROR    {200.0}            \
] $clk_wiz_audio_ext

connect_bd_net [get_bd_pins clk_wiz_audio_ext/clk_in1] \
               [get_bd_pins processing_system7_0/FCLK_CLK0]
connect_bd_net [get_bd_pins clk_wiz_audio_ext/resetn]  \
               [get_bd_pins rst_ps7_0_100M/peripheral_aresetn]

# -----------------------------------------------------------------------------
# 2. Expand ps7_0_axi_periph from NUM_MI=18 to NUM_MI=19 (adds M18 for the
#    pmod_i2s2 status slave). Encoder integration left it at 18.
# -----------------------------------------------------------------------------
set_property -dict [list CONFIG.NUM_MI {19}] [get_bd_cells ps7_0_axi_periph]

# -----------------------------------------------------------------------------
# 3. Pmod I2S2 top-level ports on PMOD JB (LVCMOS33 in audio_lab.xdc).
# -----------------------------------------------------------------------------
create_bd_port -dir O ext_pmod_i2s2_da_mclk_o
create_bd_port -dir O ext_pmod_i2s2_da_lrck_o
create_bd_port -dir O ext_pmod_i2s2_da_sclk_o
create_bd_port -dir O ext_pmod_i2s2_da_sdin_o
create_bd_port -dir O ext_pmod_i2s2_ad_mclk_o
create_bd_port -dir O ext_pmod_i2s2_ad_lrck_o
create_bd_port -dir O ext_pmod_i2s2_ad_sclk_o
create_bd_port -dir I ext_pmod_i2s2_ad_sdout_i

# -----------------------------------------------------------------------------
# 4. pmod_i2s2_master + axi_pmod_i2s2_status as module references.
#    Raw Verilog sources are added to sources_1 by create_project.tcl
#    BEFORE this script runs.
# -----------------------------------------------------------------------------
set pmod_master_0 [create_bd_cell -type module -reference pmod_i2s2_master pmod_master_0]
set pmod_status_0 [create_bd_cell -type module -reference axi_pmod_i2s2_status pmod_status_0]

# Master MCLK + reset
connect_bd_net [get_bd_pins clk_wiz_audio_ext/clk_out1] \
               [get_bd_pins $pmod_master_0/clk_12m288_i]
connect_bd_net [get_bd_pins rst_ps7_0_100M/peripheral_aresetn] \
               [get_bd_pins $pmod_master_0/resetn_i]

# Pmod I2S2 external pins
connect_bd_net [get_bd_pins $pmod_master_0/ext_pmod_i2s2_da_mclk_o]  [get_bd_ports ext_pmod_i2s2_da_mclk_o]
connect_bd_net [get_bd_pins $pmod_master_0/ext_pmod_i2s2_da_lrck_o]  [get_bd_ports ext_pmod_i2s2_da_lrck_o]
connect_bd_net [get_bd_pins $pmod_master_0/ext_pmod_i2s2_da_sclk_o]  [get_bd_ports ext_pmod_i2s2_da_sclk_o]
connect_bd_net [get_bd_pins $pmod_master_0/ext_pmod_i2s2_da_sdin_o]  [get_bd_ports ext_pmod_i2s2_da_sdin_o]
connect_bd_net [get_bd_pins $pmod_master_0/ext_pmod_i2s2_ad_mclk_o]  [get_bd_ports ext_pmod_i2s2_ad_mclk_o]
connect_bd_net [get_bd_pins $pmod_master_0/ext_pmod_i2s2_ad_lrck_o]  [get_bd_ports ext_pmod_i2s2_ad_lrck_o]
connect_bd_net [get_bd_pins $pmod_master_0/ext_pmod_i2s2_ad_sclk_o]  [get_bd_ports ext_pmod_i2s2_ad_sclk_o]
connect_bd_net [get_bd_ports ext_pmod_i2s2_ad_sdout_i]               [get_bd_pins $pmod_master_0/ext_pmod_i2s2_ad_sdout_i]

# Master -> status slave (all 11 buses, plain wires)
connect_bd_net [get_bd_pins $pmod_master_0/frame_count_o]            [get_bd_pins $pmod_status_0/frame_count_i]
connect_bd_net [get_bd_pins $pmod_master_0/nonzero_count_o]          [get_bd_pins $pmod_status_0/nonzero_count_i]
connect_bd_net [get_bd_pins $pmod_master_0/sdout_transition_count_o] [get_bd_pins $pmod_status_0/sdout_transition_count_i]
connect_bd_net [get_bd_pins $pmod_master_0/clip_count_o]             [get_bd_pins $pmod_status_0/clip_count_i]
connect_bd_net [get_bd_pins $pmod_master_0/last_left_o]              [get_bd_pins $pmod_status_0/last_left_i]
connect_bd_net [get_bd_pins $pmod_master_0/last_right_o]             [get_bd_pins $pmod_status_0/last_right_i]
connect_bd_net [get_bd_pins $pmod_master_0/peak_abs_left_o]          [get_bd_pins $pmod_status_0/peak_abs_left_i]
connect_bd_net [get_bd_pins $pmod_master_0/peak_abs_right_o]         [get_bd_pins $pmod_status_0/peak_abs_right_i]
connect_bd_net [get_bd_pins $pmod_master_0/lrclk_seen_o]             [get_bd_pins $pmod_status_0/lrclk_seen_i]
connect_bd_net [get_bd_pins $pmod_master_0/bclk_seen_o]              [get_bd_pins $pmod_status_0/bclk_seen_i]
connect_bd_net [get_bd_pins $pmod_master_0/sdout_alive_o]            [get_bd_pins $pmod_status_0/sdout_alive_i]

# Status slave -> master (control)
connect_bd_net [get_bd_pins $pmod_status_0/cfg_mode_o]               [get_bd_pins $pmod_master_0/cfg_mode_i]
connect_bd_net [get_bd_pins $pmod_status_0/cfg_clear_toggle_o]       [get_bd_pins $pmod_master_0/cfg_clear_toggle_i]

# -----------------------------------------------------------------------------
# 5. AXI-Lite from ps7_0_axi_periph/M18 to the status slave (clock + reset
#    from the 100 MHz peripheral domain, same as every other AXI peripheral).
# -----------------------------------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins ps7_0_axi_periph/M18_AXI] \
                    [get_bd_intf_pins $pmod_status_0/s_axi]

connect_bd_net [get_bd_pins ps7_0_axi_periph/M18_ACLK]    \
               [get_bd_pins processing_system7_0/FCLK_CLK0]
connect_bd_net [get_bd_pins ps7_0_axi_periph/M18_ARESETN] \
               [get_bd_pins rst_ps7_0_100M/peripheral_aresetn]

connect_bd_net [get_bd_pins $pmod_status_0/s_axi_aclk]    \
               [get_bd_pins processing_system7_0/FCLK_CLK0]
connect_bd_net [get_bd_pins $pmod_status_0/s_axi_aresetn] \
               [get_bd_pins rst_ps7_0_100M/peripheral_aresetn]

# -----------------------------------------------------------------------------
# 6. Address segment at 0x43D20000 (above encoder at 0x43D10000).
# -----------------------------------------------------------------------------
create_bd_addr_seg -range $PMOD_AXI_RANGE -offset $PMOD_AXI_OFFSET \
    [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs $pmod_status_0/s_axi/reg0] \
    SEG_pmod_status_0_Reg

# -----------------------------------------------------------------------------
# 7. Validate + save
# -----------------------------------------------------------------------------
validate_bd_design
save_bd_design
puts "PMOD_I2S2: pmod_i2s2_master + axi_pmod_i2s2_status added at $PMOD_AXI_OFFSET. validate_bd_design passed."
