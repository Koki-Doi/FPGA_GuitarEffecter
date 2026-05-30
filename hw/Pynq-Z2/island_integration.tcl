# DSP island clock-domain separation.
#
# The fxPipeline DSP (clash_lowpass_fir_0) is the only block that fails
# timing at 100 MHz (worst path inside the DS-1 distortion arithmetic,
# ~20 ns vs the 10 ns period). Run ONLY the DSP at 50 MHz (FCLK_CLK1)
# while every other block -- i2s_to_stream, axis_switch, axi_dma, the
# axi_gpio_* controls, pmod_master, and the HDMI path -- stays at
# 100 MHz (FCLK_CLK0). This is the key difference from the rejected
# full-50 MHz build: lowering the fabric clock globally corrupted the
# existing I2S / Pmod clock-domain crossings (audible bypass buzz). Here
# those CDCs are untouched; only the AXI-Stream into / out of the DSP
# crosses 100 <-> 50 MHz, through two axis_clock_converter instances.
#
# Sourced from create_project.tcl AFTER wah_integration.tcl (so the
# clash AXIS nets axis_data_fifo_0_M_AXIS and clash_lowpass_fir_0_axis_out
# already exist). block_design.tcl itself is not edited -- additive only,
# matching the hdmi / encoder / pmod / wah integration pattern.
#
# NOTE: the clash control-word inputs (axi_gpio_* gpio_io_o) still cross
# from the 100 MHz GPIO domain into the 50 MHz DSP without explicit
# synchronisers. They are quasi-static (only change on an effect-knob
# write), so safe-bypass (all controls fixed) is unaffected; if an
# effect-change zipper/glitch shows up later, add 2-FF synchronisers on
# those words.

current_bd_design [get_bd_designs block_design]
current_bd_instance /

puts "ISLAND: separating clash_lowpass_fir_0 onto FCLK_CLK1 = 50 MHz"

# 1. FCLK_CLK1 = 50 MHz (FCLK0 stays 100 MHz). 1000 MHz IO PLL / 5 / 4 = 50.
set_property -dict [list \
  CONFIG.PCW_EN_CLK1_PORT {1} \
  CONFIG.PCW_FPGA_FCLK1_ENABLE {1} \
  CONFIG.PCW_FCLK_CLK1_BUF {TRUE} \
  CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {50} \
  CONFIG.PCW_FCLK1_PERIPHERAL_DIVISOR0 {5} \
  CONFIG.PCW_FCLK1_PERIPHERAL_DIVISOR1 {4} \
] [get_bd_cells processing_system7_0]

# 2. proc_sys_reset for the 50 MHz island
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_island_50M
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK1]     [get_bd_pins rst_island_50M/slowest_sync_clk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins rst_island_50M/ext_reset_in]

# 3. AXIS clock converters around the DSP (100 <-> 50 MHz)
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 cc_dsp_in
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 cc_dsp_out

# 4. Move clash onto FCLK_CLK1 / island reset (detach from the 100 MHz nets)
disconnect_bd_net [get_bd_nets processing_system7_0_FCLK_CLK0]    [get_bd_pins clash_lowpass_fir_0/clk]
connect_bd_net    [get_bd_pins processing_system7_0/FCLK_CLK1]    [get_bd_pins clash_lowpass_fir_0/clk]
disconnect_bd_net [get_bd_nets rst_ps7_0_100M_peripheral_aresetn] [get_bd_pins clash_lowpass_fir_0/aresetn]
connect_bd_net    [get_bd_pins rst_island_50M/peripheral_aresetn] [get_bd_pins clash_lowpass_fir_0/aresetn]

# 5. Rewire AXIS: axis_data_fifo_0 -> cc_dsp_in -> clash -> cc_dsp_out -> axis_switch_sink/S01
delete_bd_objs [get_bd_intf_nets axis_data_fifo_0_M_AXIS]
delete_bd_objs [get_bd_intf_nets clash_lowpass_fir_0_axis_out]
connect_bd_intf_net [get_bd_intf_pins axis_data_fifo_0/M_AXIS]      [get_bd_intf_pins cc_dsp_in/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins cc_dsp_in/M_AXIS]             [get_bd_intf_pins clash_lowpass_fir_0/axis_in]
connect_bd_intf_net [get_bd_intf_pins clash_lowpass_fir_0/axis_out] [get_bd_intf_pins cc_dsp_out/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins cc_dsp_out/M_AXIS]            [get_bd_intf_pins axis_switch_sink/S01_AXIS]

# 6. Converter clocks/resets.
#    cc_dsp_in : slave = 100 MHz fabric (fifo side), master = 50 MHz DSP side
#    cc_dsp_out: slave = 50 MHz DSP side,           master = 100 MHz fabric (switch side)
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0]    [get_bd_pins cc_dsp_in/s_axis_aclk]
connect_bd_net [get_bd_pins rst_ps7_0_100M/peripheral_aresetn] [get_bd_pins cc_dsp_in/s_axis_aresetn]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK1]    [get_bd_pins cc_dsp_in/m_axis_aclk]
connect_bd_net [get_bd_pins rst_island_50M/peripheral_aresetn] [get_bd_pins cc_dsp_in/m_axis_aresetn]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK1]    [get_bd_pins cc_dsp_out/s_axis_aclk]
connect_bd_net [get_bd_pins rst_island_50M/peripheral_aresetn] [get_bd_pins cc_dsp_out/s_axis_aresetn]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0]    [get_bd_pins cc_dsp_out/m_axis_aclk]
connect_bd_net [get_bd_pins rst_ps7_0_100M/peripheral_aresetn] [get_bd_pins cc_dsp_out/m_axis_aresetn]

validate_bd_design
save_bd_design
puts "ISLAND: done (clash on FCLK_CLK1 50 MHz, AXIS via cc_dsp_in/out)"
