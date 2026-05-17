# Phase 7D PCM1808 external-ADC bring-up integration for the AudioLab block
# design.
#
# Sourced from create_project.tcl AFTER pcm5102_dac_integration.tcl. Inserts
# a tiny 2:1 wire mux (`pcm1808_input_select`) between the existing
# top-level `sdata_i` port (ADAU1761 ADC I2S serial-data input on F17) and
# a new top-level `ext_adc_dout_i` port (PCM1808 DOUT on JB4 / T10). The
# mux output drives the existing `i2s_to_stream_0/si` pin so the downstream
# AXIS DSP chain is bit-for-bit unchanged regardless of which ADC source
# is selected. Phase 7D bring-up ties `sel_external_i = 1` (PCM1808) via
# a single-bit `xlconstant`; flipping the constant value to 0 falls back
# to the ADAU1761 ADC path (build-time-only switch, runtime AXI control
# is deferred).
#
# Untouched by this script:
#   - ADAU1761 audio path (mclk / bclk / lrclk / sdata_o /
#     i2s_to_stream_0 / clash_lowpass_fir_0 / axis_switch_* / axi_dma_0).
#     The top-level `sdata_i` port stays as-is; only the net that drove
#     `i2s_to_stream_0/si` from it directly is broken and re-routed via
#     the new mux.
#   - PCM5102 DAC output path (pcm5102_out_0 / clk_wiz_audio_ext / the
#     four PMOD JB output ports). `pcm5102_audio_out.v` was updated in
#     this commit to re-pass the 12.288 MHz wizard output to JB1 -- the
#     user's Phase 7D board rewiring physically grounds PCM5102 SCK on
#     the module, so JB1 driving 12.288 MHz no longer affects PCM5102
#     and is reused as PCM1808 SCKI instead (DECISIONS.md D40 / D41).
#   - HDMI integration, encoder integration, GPIO_CONTROL_MAP, ps7_0
#     AXI peripheral count (no NUM_MI bump -- the mux is wire-only).
#
# Known caveat (deliberately accepted for the Phase 7D bring-up; see
# DECISIONS.md D41): the 12.288 MHz `clk_wiz_audio_ext` MCLK feeding
# PCM1808 SCKI is NOT bit-true synchronous to ADAU's PLL-sourced BCK.
# PCM1808 lacks a PCM510x-style "SCKI absent -> internal PLL from BCK"
# fallback, so async clocks may produce noisy / unlocked output. The
# decision is to ship and listen; if the bench shows the same kind of
# graininess Phase 7E PCM5102 had, the next step is to make the FPGA
# the I2S master and drive all three clocks from one source.

current_bd_design [get_bd_designs block_design]
current_bd_instance /

puts "PCM1808: starting Phase 7D ADC bring-up on [current_bd_design]"

# -----------------------------------------------------------------------------
# 1. New top-level input port for PCM1808 DOUT (LVCMOS33 in audio_lab.xdc).
# -----------------------------------------------------------------------------
create_bd_port -dir I ext_adc_dout_i

# -----------------------------------------------------------------------------
# 2. pcm1808_input_select as a module reference (raw Verilog source added by
#    create_project.tcl before this script runs). Drives `i2s_to_stream_0/si`.
# -----------------------------------------------------------------------------
set adc_sel_0 [create_bd_cell -type module -reference pcm1808_input_select adc_sel_0]

# -----------------------------------------------------------------------------
# 3. Break the existing direct `sdata_i -> i2s_to_stream_0/si` net so we can
#    re-route via the mux. The original net was created by block_design.tcl
#    as `sdata_i_1`.
# -----------------------------------------------------------------------------
delete_bd_objs [get_bd_nets sdata_i_1]

# ADAU sdata_i top-level port -> mux/adau_sdata_i
connect_bd_net -net sdata_i_1 [get_bd_ports sdata_i] \
                              [get_bd_pins $adc_sel_0/adau_sdata_i]

# PCM1808 DOUT top-level port -> mux/pcm1808_dout_i
connect_bd_net [get_bd_ports ext_adc_dout_i] \
               [get_bd_pins $adc_sel_0/pcm1808_dout_i]

# mux output -> i2s_to_stream_0/si (the AXIS serializer input)
connect_bd_net [get_bd_pins $adc_sel_0/sdata_to_dsp_o] \
               [get_bd_pins i2s_to_stream_0/si]

# -----------------------------------------------------------------------------
# 4. Build-time select. xlconstant width=1, value=1 -> Phase 7D bring-up
#    picks PCM1808. Flip CONST_VAL to {0} to fall back to ADAU1761.
# -----------------------------------------------------------------------------
set adc_sel_const [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 adc_sel_const]
set_property -dict [list \
    CONFIG.CONST_VAL   {1} \
    CONFIG.CONST_WIDTH {1} \
] $adc_sel_const
connect_bd_net [get_bd_pins $adc_sel_const/dout] \
               [get_bd_pins $adc_sel_0/sel_external_i]

# -----------------------------------------------------------------------------
# 5. Validate + save
# -----------------------------------------------------------------------------
validate_bd_design
save_bd_design
puts "PCM1808: pcm1808_input_select inserted (sel=PCM1808 by default). validate_bd_design passed."
