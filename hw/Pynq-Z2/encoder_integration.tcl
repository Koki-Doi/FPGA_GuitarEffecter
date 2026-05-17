# Phase 7F/7G encoder integration extension for the AudioLab block design.
#
# This script is sourced from create_project.tcl AFTER hdmi_integration.tcl.
# It assumes:
#   - The AudioLab block design already exists and is open and named
#     "block_design".
#   - hdmi_integration.tcl has already bumped ps7_0_axi_periph/NUM_MI to 17
#     (M15=axi_vdma_hdmi, M16=v_tc_hdmi).
#   - The Verilog source `hw/ip/encoder_input/src/axi_encoder_input.v` has
#     already been added to sources_1 (create_project.tcl does this before
#     calling block_design.tcl).
#
# What it does:
#   1. Bumps ps7_0_axi_periph from NUM_MI=17 to NUM_MI=18 (adds M17).
#   2. Adds nine top-level input ports for the 3 rotary encoders
#      (enc{0..2}_clk_i / dt_i / sw_i), all LVCMOS33 on the RPi header.
#   3. Adds the `axi_encoder_input` IP as a block-design module reference.
#   4. Connects the encoder's AXI-Lite slave to ps7_0_axi_periph/M17_AXI,
#      and clock/reset to FCLK_CLK0 / rst_ps7_0_100M like every other AXI
#      peripheral in this design.
#   5. Connects the nine top-level ports to the encoder IP inputs.
#   6. Maps an AXI-Lite address segment at 0x43D10000 / 0x10000.
#      This deliberately skips the HDMI VDMA (0x43CE0000) and VTC (0x43CF0000)
#      ranges and the 0x43D00000 slot reserved for a future HDMI / rgb2dvi
#      control surface (see DECISIONS.md D32).
#   7. validate_bd_design + save_bd_design.
#
# Audio / DSP / GPIO / HDMI: untouched. No bytes of the GPIO_CONTROL_MAP.md
# contract change.

current_bd_design [get_bd_designs block_design]
current_bd_instance /

set ENC_AXI_OFFSET 0x43D10000
set ENC_AXI_RANGE  0x00010000

puts "ENC: starting Phase 7F/7G encoder integration at $ENC_AXI_OFFSET / $ENC_AXI_RANGE on [current_bd_design]"

# -----------------------------------------------------------------------------
# 1. Expand ps7_0_axi_periph from NUM_MI=17 to NUM_MI=18 (adds M17)
# -----------------------------------------------------------------------------
set_property -dict [list CONFIG.NUM_MI {18}] [get_bd_cells ps7_0_axi_periph]

# -----------------------------------------------------------------------------
# 2. Top-level encoder input ports (LVCMOS33 in audio_lab.xdc)
# -----------------------------------------------------------------------------
create_bd_port -dir I enc0_clk_i
create_bd_port -dir I enc0_dt_i
create_bd_port -dir I enc0_sw_i
create_bd_port -dir I enc1_clk_i
create_bd_port -dir I enc1_dt_i
create_bd_port -dir I enc1_sw_i
create_bd_port -dir I enc2_clk_i
create_bd_port -dir I enc2_dt_i
create_bd_port -dir I enc2_sw_i

# -----------------------------------------------------------------------------
# 3. axi_encoder_input as a module reference (raw Verilog source added by
#    create_project.tcl). No IP catalog packaging needed.
# -----------------------------------------------------------------------------
set enc_in_0 [create_bd_cell -type module -reference axi_encoder_input enc_in_0]

# -----------------------------------------------------------------------------
# 4. AXI-Lite from ps7_0_axi_periph/M17 to the encoder slave
# -----------------------------------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins ps7_0_axi_periph/M17_AXI] \
                    [get_bd_intf_pins $enc_in_0/s_axi]

# Clock + reset from the existing 100 MHz peripheral domain
connect_bd_net [get_bd_pins ps7_0_axi_periph/M17_ACLK]    \
               [get_bd_pins processing_system7_0/FCLK_CLK0]
connect_bd_net [get_bd_pins ps7_0_axi_periph/M17_ARESETN] \
               [get_bd_pins rst_ps7_0_100M/peripheral_aresetn]

connect_bd_net [get_bd_pins $enc_in_0/s_axi_aclk]    \
               [get_bd_pins processing_system7_0/FCLK_CLK0]
connect_bd_net [get_bd_pins $enc_in_0/s_axi_aresetn] \
               [get_bd_pins rst_ps7_0_100M/peripheral_aresetn]

# -----------------------------------------------------------------------------
# 5. External pins -> encoder IP
# -----------------------------------------------------------------------------
connect_bd_net [get_bd_ports enc0_clk_i] [get_bd_pins $enc_in_0/enc0_clk_i]
connect_bd_net [get_bd_ports enc0_dt_i]  [get_bd_pins $enc_in_0/enc0_dt_i]
connect_bd_net [get_bd_ports enc0_sw_i]  [get_bd_pins $enc_in_0/enc0_sw_i]
connect_bd_net [get_bd_ports enc1_clk_i] [get_bd_pins $enc_in_0/enc1_clk_i]
connect_bd_net [get_bd_ports enc1_dt_i]  [get_bd_pins $enc_in_0/enc1_dt_i]
connect_bd_net [get_bd_ports enc1_sw_i]  [get_bd_pins $enc_in_0/enc1_sw_i]
connect_bd_net [get_bd_ports enc2_clk_i] [get_bd_pins $enc_in_0/enc2_clk_i]
connect_bd_net [get_bd_ports enc2_dt_i]  [get_bd_pins $enc_in_0/enc2_dt_i]
connect_bd_net [get_bd_ports enc2_sw_i]  [get_bd_pins $enc_in_0/enc2_sw_i]

# -----------------------------------------------------------------------------
# 6. Address segment outside HDMI VDMA/VTC range
# -----------------------------------------------------------------------------
create_bd_addr_seg -range $ENC_AXI_RANGE -offset $ENC_AXI_OFFSET \
    [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs $enc_in_0/s_axi/reg0] \
    SEG_enc_in_0_Reg

# -----------------------------------------------------------------------------
# 7. Validate + save
# -----------------------------------------------------------------------------
validate_bd_design
save_bd_design
puts "ENC: encoder_input added at $ENC_AXI_OFFSET. validate_bd_design passed."
