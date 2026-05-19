# Pmod I2S2 bring-up integration for the AudioLab block design
# (DECISIONS.md D48).
#
# Sourced from create_project.tcl AFTER encoder_integration.tcl.
# PMOD JB is dedicated to the Digilent Pmod I2S2 module (CS4344 DAC +
# CS5343 ADC); the legacy PCM5102 / PCM1808 integration tcls are NOT
# sourced in the deployed build (their source files stay in the repo
# under hw/Pynq-Z2/ and hw/ip/ as archival reference only).
#
# What this script does:
#   1. Builds the clk_wiz_audio_ext MMCM (100 MHz -> 12.288 MHz exact) --
#      same math the retired Phase 7C pcm5102_dac_integration.tcl used.
#      The MMCM lives entirely in this script; nothing else creates it.
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
# 4b. Reroute the AudioLab DSP I2S converter (`i2s_to_stream_0`) onto the
#     Pmod-generated BCLK / LRCK / SDATA clock tree. This makes the existing
#     AXIS DSP chain process Pmod ADC samples and emit a Pmod-DAC-compatible
#     bit-serial stream, enabling `cfg_mode == 2'd2` (ADC -> DSP -> DAC).
#
# Original block_design.tcl wiring (kept in repo as the baseline):
#   bclk_1   : top-level `bclk`  (R18, ADAU PLL) -> i2s_to_stream_0/bclk
#                                                + proc_sys_reset_0/slowest_sync_clk
#   lrclk_1  : top-level `lrclk` (T17, ADAU PLL) -> i2s_to_stream_0/lrclk
#   sdata_i_1: top-level `sdata_i` (F17, ADAU)   -> i2s_to_stream_0/si
#
# After rewiring (this script):
#   pmod_master_0/dsp_bclk_o (= bclk_int, 3.072 MHz from clk_wiz_audio_ext / 4)
#                                              -> i2s_to_stream_0/bclk
#                                              + proc_sys_reset_0/slowest_sync_clk
#   pmod_master_0/dsp_lrck_o (= lrck_int, 48 kHz from bclk_int / 64)
#                                              -> i2s_to_stream_0/lrclk
#   top-level `ext_pmod_i2s2_ad_sdout_i` (W13, Pmod ADC SDOUT)
#                                              -> i2s_to_stream_0/si
#   i2s_to_stream_0/so (already wired to top-level `sdata_o` on G18 for the
#                       ADAU DAC backward-visibility) gets one extra sink:
#                                              -> pmod_master_0/dsp_dac_sdin_i
#
# The ADAU1761 top-level ports (`bclk`, `lrclk`, `sdata_i`, `sdata_o`) stay
# in `audio_lab.xdc` but `bclk` / `lrclk` / `sdata_i` are no longer loaded
# by anything inside the design. `sdata_o` keeps receiving the
# i2s_to_stream_0/so bit-serial output for visibility (ADAU DAC will play a
# Pmod-clocked stream; not a usable audio path any more). ADAU1761 I2C
# config stays intact via the codec_address / IIC_1 ports, so the codec is
# still alive and `ADC HPF True` smoke continues to work.
# -----------------------------------------------------------------------------
delete_bd_objs [get_bd_nets bclk_1]
delete_bd_objs [get_bd_nets lrclk_1]
delete_bd_objs [get_bd_nets sdata_i_1]

# Pmod BCLK -> i2s_to_stream_0/bclk + proc_sys_reset_0/slowest_sync_clk
connect_bd_net [get_bd_pins $pmod_master_0/dsp_bclk_o] \
               [get_bd_pins i2s_to_stream_0/bclk] \
               [get_bd_pins proc_sys_reset_0/slowest_sync_clk]

# Pmod LRCK -> i2s_to_stream_0/lrclk
connect_bd_net [get_bd_pins $pmod_master_0/dsp_lrck_o] \
               [get_bd_pins i2s_to_stream_0/lrclk]

# Pmod ADC SDOUT (top-level input port) -> i2s_to_stream_0/si.
# Same top-level port still goes to pmod_master_0/ext_pmod_i2s2_ad_sdout_i
# (driven above), this just adds a second sink to the existing net.
connect_bd_net [get_bd_ports ext_pmod_i2s2_ad_sdout_i] \
               [get_bd_pins i2s_to_stream_0/si]

# DSP DAC bit-serial output -> pmod_master_0/dsp_dac_sdin_i. The existing
# net `i2s_to_stream_0_so` already drives the ADAU sdata_o top-level port;
# we just append the new sink.
connect_bd_net [get_bd_pins i2s_to_stream_0/so] \
               [get_bd_pins $pmod_master_0/dsp_dac_sdin_i]

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
