# Phase 7C PCM5102 DAC-only bring-up integration for the AudioLab block design.
#
# Sourced from create_project.tcl AFTER encoder_integration.tcl. Adds a single
# extra clock wizard (clk_wiz_audio_ext) that turns the PS 100 MHz FCLK_CLK0
# into an EXACT 12.288 MHz audio master clock, then drops the small RTL module
# `pcm5102_dac_tone` on top of it as a module reference. The module emits a
# constant 1 kHz / 24-bit / quarter-scale sine to both stereo channels.
#
# Untouched by this script:
#   - ADAU1761 audio path (existing mclk / bclk / lrclk / sdata_i / sdata_o /
#     i2s_to_stream_0 / clash_lowpass_fir_0 / axis_switch_* / axi_dma_0)
#   - HDMI integration (VDMA, v_tc, rgb2dvi)
#   - Rotary encoder integration (axi_encoder_input at 0x43D10000)
#   - GPIO control map (axi_gpio_*)
#   - ps7_0_axi_periph (no NUM_MI bump -- PCM5102 bring-up needs no AXI-Lite)
#
# Clock math (verified):
#   CLKIN  = 100 MHz from FCLK_CLK0
#   M_F    = 48.000   (CLKFBOUT_MULT_F)
#   D      = 5        (DIVCLK_DIVIDE)
#   VCO    = 100 * 48 / 5         = 960 MHz       (in xc7z020-1 600-1200 MHz)
#   CLKOUT0 divider = 78.125 (1/8 step)
#   CLKOUT0 = 960 / 78.125         = 12.288 MHz   <-- EXACT
#   BCLK    = MCLK / 4              =  3.072 MHz   (in RTL)
#   LRCLK   = BCLK / 64             =  48.000 kHz  (in RTL)

current_bd_design [get_bd_designs block_design]
current_bd_instance /

puts "PCM5102: starting Phase 7C DAC bring-up on [current_bd_design]"

# -----------------------------------------------------------------------------
# 1. New clk_wiz dedicated to the external audio path.
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

# Drive the wizard from the 100 MHz PS clock and reset it from the same
# peripheral aresetn used by every other peripheral in the design.
connect_bd_net [get_bd_pins clk_wiz_audio_ext/clk_in1] \
               [get_bd_pins processing_system7_0/FCLK_CLK0]
connect_bd_net [get_bd_pins clk_wiz_audio_ext/resetn]  \
               [get_bd_pins rst_ps7_0_100M/peripheral_aresetn]

# -----------------------------------------------------------------------------
# 2. Top-level ports for the four PCM5102 signals (LVCMOS33 in audio_lab.xdc).
# -----------------------------------------------------------------------------
create_bd_port -dir O ext_audio_mclk_o
create_bd_port -dir O ext_audio_bclk_o
create_bd_port -dir O ext_audio_lrclk_o
create_bd_port -dir O ext_dac_din_o

# -----------------------------------------------------------------------------
# 3. pcm5102_dac_tone as a module reference (raw Verilog source added by
#    create_project.tcl before this script runs).
# -----------------------------------------------------------------------------
set pcm5102_dac_0 [create_bd_cell -type module -reference pcm5102_dac_tone pcm5102_dac_0]

# Clock: 12.288 MHz from the new wizard
connect_bd_net [get_bd_pins clk_wiz_audio_ext/clk_out1] \
               [get_bd_pins $pcm5102_dac_0/clk_12m288_i]

# Reset: active-low. Use clk_wiz_audio_ext/locked AND'ed with the peripheral
# aresetn would be safer, but a single peripheral_aresetn matches the pattern
# used by every other module here and keeps the integration minimal.
connect_bd_net [get_bd_pins rst_ps7_0_100M/peripheral_aresetn] \
               [get_bd_pins $pcm5102_dac_0/resetn_i]

# -----------------------------------------------------------------------------
# 4. Module outputs -> top-level ports
# -----------------------------------------------------------------------------
connect_bd_net [get_bd_pins $pcm5102_dac_0/ext_audio_mclk_o]  [get_bd_ports ext_audio_mclk_o]
connect_bd_net [get_bd_pins $pcm5102_dac_0/ext_audio_bclk_o]  [get_bd_ports ext_audio_bclk_o]
connect_bd_net [get_bd_pins $pcm5102_dac_0/ext_audio_lrclk_o] [get_bd_ports ext_audio_lrclk_o]
connect_bd_net [get_bd_pins $pcm5102_dac_0/ext_dac_din_o]     [get_bd_ports ext_dac_din_o]

# -----------------------------------------------------------------------------
# 5. Validate + save
# -----------------------------------------------------------------------------
validate_bd_design
save_bd_design
puts "PCM5102: pcm5102_dac_tone added on a dedicated 12.288 MHz MMCM. validate_bd_design passed."
