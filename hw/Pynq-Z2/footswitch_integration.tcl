# Footswitch input integration extension for the AudioLab block design.
#
# This script is sourced from create_project.tcl AFTER xadc_integration.tcl
# and BEFORE island_integration.tcl. It assumes:
#   - The AudioLab block design already exists and is open and named
#     "block_design".
#   - xadc_integration.tcl has already bumped ps7_0_axi_periph/NUM_MI to 21
#     (M19=wah, M20=xadc_wiz_a0). 0x43D00000 stays reserved per DECISIONS.md
#     D32.
#   - The Verilog source `hw/ip/footswitch_input/src/axi_footswitch_input.v`
#     has already been added to sources_1 (create_project.tcl does this
#     before calling block_design.tcl), so the module-reference cell
#     resolves.
#
# What it does:
#   1. Bumps ps7_0_axi_periph from NUM_MI=21 to NUM_MI=22 (adds M21).
#   2. Adds three top-level input ports for the 3 footswitches
#      (fsw{0..2}_i), all LVCMOS33 on the RPi header (PULLUP true).
#   3. Adds the `axi_footswitch_input` IP as a block-design module reference.
#   4. Connects the footswitch AXI-Lite slave to ps7_0_axi_periph/M21_AXI,
#      and clock/reset to FCLK_CLK0 / rst_ps7_0_100M like every other AXI
#      peripheral in this design (100 MHz fabric -- NOT the 50 MHz DSP
#      island).
#   5. Connects the three top-level ports to the footswitch IP inputs.
#   6. Maps an AXI-Lite address segment at 0x43D50000 / 0x10000 (the next
#      free slot above xadc_wiz_a0 @ 0x43D40000).
#   7. validate_bd_design + save_bd_design.
#
# Audio / DSP / GPIO / HDMI / encoder / pmod_i2s2 / wah / xadc: untouched.
# No bytes of the GPIO_CONTROL_MAP.md contract change. The DSP island
# (D75/D76) is unaffected -- this IP lives on FCLK_CLK0.
#
# AXI master allocation (post footswitch integration):
#   M00..M13  : audio_lab base block design.
#   M14       : axi_gpio_compressor       @ 0x43CD0000  (base block design)
#   M15       : axi_vdma_hdmi             @ 0x43CE0000  (hdmi)
#   M16       : v_tc_hdmi                 @ 0x43CF0000  (hdmi)
#   ---       : reserved                  @ 0x43D00000  (D32 future)
#   M17       : axi_encoder               @ 0x43D10000  (encoder)
#   M18       : axi_pmod_i2s2_status      @ 0x43D20000  (pmod_i2s2)
#   M19       : axi_gpio_wah              @ 0x43D30000  (wah)
#   M20       : xadc_wiz_a0               @ 0x43D40000  (xadc)
#   M21       : axi_footswitch_input      @ 0x43D50000  (new)

current_bd_design [get_bd_designs block_design]
current_bd_instance /

set FSW_AXI_OFFSET 0x43D50000
set FSW_AXI_RANGE  0x00010000

puts "FSW: starting footswitch integration at $FSW_AXI_OFFSET / $FSW_AXI_RANGE on [current_bd_design]"

# -----------------------------------------------------------------------------
# 1. Expand ps7_0_axi_periph from NUM_MI=21 to NUM_MI=22 (adds M21)
# -----------------------------------------------------------------------------
set_property -dict [list CONFIG.NUM_MI {22}] [get_bd_cells ps7_0_axi_periph]

# -----------------------------------------------------------------------------
# 2. Top-level footswitch input ports (LVCMOS33 + PULLUP in audio_lab.xdc)
# -----------------------------------------------------------------------------
create_bd_port -dir I fsw0_i
create_bd_port -dir I fsw1_i
create_bd_port -dir I fsw2_i

# -----------------------------------------------------------------------------
# 3. axi_footswitch_input as a module reference (raw Verilog source added by
#    create_project.tcl). No IP catalog packaging needed.
# -----------------------------------------------------------------------------
set fsw_in_0 [create_bd_cell -type module -reference axi_footswitch_input fsw_in_0]

# -----------------------------------------------------------------------------
# 4. AXI-Lite from ps7_0_axi_periph/M21 to the footswitch slave
# -----------------------------------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins ps7_0_axi_periph/M21_AXI] \
                    [get_bd_intf_pins $fsw_in_0/s_axi]

# Clock + reset from the existing 100 MHz peripheral domain
connect_bd_net [get_bd_pins ps7_0_axi_periph/M21_ACLK]    \
               [get_bd_pins processing_system7_0/FCLK_CLK0]
connect_bd_net [get_bd_pins ps7_0_axi_periph/M21_ARESETN] \
               [get_bd_pins rst_ps7_0_100M/peripheral_aresetn]

connect_bd_net [get_bd_pins $fsw_in_0/s_axi_aclk]    \
               [get_bd_pins processing_system7_0/FCLK_CLK0]
connect_bd_net [get_bd_pins $fsw_in_0/s_axi_aresetn] \
               [get_bd_pins rst_ps7_0_100M/peripheral_aresetn]

# -----------------------------------------------------------------------------
# 5. External pins -> footswitch IP
# -----------------------------------------------------------------------------
connect_bd_net [get_bd_ports fsw0_i] [get_bd_pins $fsw_in_0/fsw0_i]
connect_bd_net [get_bd_ports fsw1_i] [get_bd_pins $fsw_in_0/fsw1_i]
connect_bd_net [get_bd_ports fsw2_i] [get_bd_pins $fsw_in_0/fsw2_i]

# -----------------------------------------------------------------------------
# 6. Address segment at 0x43D50000
# -----------------------------------------------------------------------------
create_bd_addr_seg -range $FSW_AXI_RANGE -offset $FSW_AXI_OFFSET \
    [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs $fsw_in_0/s_axi/reg0] \
    SEG_fsw_in_0_Reg

# -----------------------------------------------------------------------------
# 7. Validate + save
# -----------------------------------------------------------------------------
validate_bd_design
save_bd_design
puts "FSW: axi_footswitch_input added at $FSW_AXI_OFFSET. validate_bd_design passed."
