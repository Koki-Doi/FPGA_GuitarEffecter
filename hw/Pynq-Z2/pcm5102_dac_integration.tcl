# Phase 7E PCM5102 external-DAC integration for the AudioLab block design.
#
# Sourced from create_project.tcl AFTER encoder_integration.tcl. The original
# Phase 7C free-running tone generator (pcm5102_dac_tone) is no longer
# instantiated; this script now drops the trivial pcm5102_audio_out
# pass-through module that mirrors the existing ADAU1761 I2S DAC interface
# onto the four PMOD JB pins. PCM5102 therefore receives bit-for-bit the
# same processed audio the ADAU1761 DAC receives (parallel output;
# DECISIONS.md D39). The Phase 7C clk_wiz_audio_ext (100 MHz -> 12.288 MHz
# exact) is kept and still drives PMOD JB1 (PCM5102 SCK) so the same MCLK
# can later feed PCM1808 SCKI in Phase 7D.
#
# Untouched by this script (same as Phase 7C):
#   - ADAU1761 audio path (mclk / bclk / lrclk / sdata_i / sdata_o /
#     i2s_to_stream_0 / clash_lowpass_fir_0 / axis_switch_* / axi_dma_0).
#     The pass-through *taps* the bclk input port, the lrclk input port,
#     and i2s_to_stream_0/so as additional sinks; no existing net source
#     or sink is rewired.
#   - HDMI integration (VDMA, v_tc, rgb2dvi)
#   - Rotary encoder integration (axi_encoder_input at 0x43D10000)
#   - GPIO control map (axi_gpio_*) and addresses
#   - ps7_0_axi_periph (NUM_MI not bumped -- pass-through needs no AXI-Lite)
#
# Clock math (verified, Phase 7C):
#   CLKIN  = 100 MHz from FCLK_CLK0
#   M_F    = 48.000   (CLKFBOUT_MULT_F)
#   D      = 5        (DIVCLK_DIVIDE)
#   VCO    = 100 * 48 / 5         = 960 MHz       (in xc7z020-1 600-1200 MHz)
#   CLKOUT0 divider = 78.125 (1/8 step)
#   CLKOUT0 = 960 / 78.125         = 12.288 MHz   <-- EXACT MCLK to PCM5102 SCK
#
# PCM5102 BCK/LCK actually come from the ADAU1761 I2S BCLK (~3.072 MHz from
# ADAU's PLL) and LRCLK (~48 kHz). The 12.288 MHz MCLK is therefore not
# bit-true synchronous to ADAU BCLK, but the 256:1 ratio sits inside the
# PCM510x internal-PLL lock window. If the chip ever fails to lock, the
# fallback is to drop ext_audio_mclk_o to a constant low (PCM5102 then
# switches to its internal PLL).

current_bd_design [get_bd_designs block_design]
current_bd_instance /

puts "PCM5102: starting Phase 7E DSP-output integration on [current_bd_design]"

# -----------------------------------------------------------------------------
# 1. New clk_wiz dedicated to the external audio MCLK (identical to Phase 7C).
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
# 2. Top-level ports for the four PCM5102 signals (LVCMOS33 in audio_lab.xdc).
# -----------------------------------------------------------------------------
create_bd_port -dir O ext_audio_mclk_o
create_bd_port -dir O ext_audio_bclk_o
create_bd_port -dir O ext_audio_lrclk_o
create_bd_port -dir O ext_dac_din_o

# -----------------------------------------------------------------------------
# 3. pcm5102_audio_out as a module reference (raw Verilog source added by
#    create_project.tcl before this script runs). Replaces the Phase 7C
#    free-running tone module pcm5102_dac_tone (file kept in repo as a
#    debug reference; not instantiated any more).
# -----------------------------------------------------------------------------
set pcm5102_out_0 [create_bd_cell -type module -reference pcm5102_audio_out pcm5102_out_0]

# MCLK: 12.288 MHz from the dedicated wizard.
connect_bd_net [get_bd_pins clk_wiz_audio_ext/clk_out1] \
               [get_bd_pins $pcm5102_out_0/mclk_12m288_i]

# BCLK / LRCLK: tap the existing ADAU1761 I2S clocks. Both ports are
# top-level INPUTS on the AudioLab block design (the ADAU codec is the
# I2S master). Adding the new sink to the same net is a pure fanout --
# no existing driver / sink relationship is touched.
connect_bd_net [get_bd_ports bclk]  [get_bd_pins $pcm5102_out_0/adau_bclk_i]
connect_bd_net [get_bd_ports lrclk] [get_bd_pins $pcm5102_out_0/adau_lrclk_i]

# DIN: tap i2s_to_stream_0/so, which already drives the ADAU sdata_o
# top-level output port. The PCM5102 therefore sees exactly the same
# serial DAC bitstream that the ADAU DAC pin sees.
connect_bd_net [get_bd_pins i2s_to_stream_0/so] \
               [get_bd_pins $pcm5102_out_0/adau_sdata_o_i]

# -----------------------------------------------------------------------------
# 4. Module outputs -> top-level ports
# -----------------------------------------------------------------------------
connect_bd_net [get_bd_pins $pcm5102_out_0/ext_audio_mclk_o]  [get_bd_ports ext_audio_mclk_o]
connect_bd_net [get_bd_pins $pcm5102_out_0/ext_audio_bclk_o]  [get_bd_ports ext_audio_bclk_o]
connect_bd_net [get_bd_pins $pcm5102_out_0/ext_audio_lrclk_o] [get_bd_ports ext_audio_lrclk_o]
connect_bd_net [get_bd_pins $pcm5102_out_0/ext_dac_din_o]     [get_bd_ports ext_dac_din_o]

# -----------------------------------------------------------------------------
# 5. Validate + save
# -----------------------------------------------------------------------------
validate_bd_design
save_bd_design
puts "PCM5102: pcm5102_audio_out (Phase 7E pass-through) added; ADAU bclk/lrclk/sdata_o mirrored to PMOD JB. validate_bd_design passed."
