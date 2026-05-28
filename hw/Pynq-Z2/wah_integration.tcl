# Wah effect integration extension for the AudioLab block design.
#
# This script is sourced from create_project.tcl AFTER hdmi_integration.tcl,
# encoder_integration.tcl, and pmod_i2s2_integration.tcl. It assumes:
#   - The AudioLab block design already exists and is open and named
#     "block_design".
#   - pmod_i2s2_integration.tcl has already bumped ps7_0_axi_periph/NUM_MI
#     to 19 (M14=compressor, M15=vdma_hdmi, M16=vtc_hdmi, M17=encoder,
#     M18=pmod_status). 0x43D00000 stays reserved per DECISIONS.md D32.
#   - clash_lowpass_fir IP has been regenerated with the new wah_control
#     port (LowPassFir.hs topEntity signature change), so the GPIO output
#     net has somewhere to land. The repackage step in create_ip.tcl picks
#     up the new port automatically from component.xml.
#
# What it does:
#   1. Bumps ps7_0_axi_periph from NUM_MI=19 to NUM_MI=20 (adds M19).
#   2. Adds the new axi_gpio_wah IP at the next free address slot
#      0x43D30000. Compressor sits at 0x43CD0000 / M14 in the base
#      block design and HDMI / encoder / pmod_i2s2 already occupy the
#      slots above it; this is the next contiguous slot above the
#      pmod_status_0 GPIO at 0x43D20000.
#   3. Configures the GPIO as a single-channel 32-bit all-output (same
#      shape as the existing axi_gpio_compressor / axi_gpio_noise_suppressor
#      IPs).
#   4. Connects the GPIO's AXI-Lite slave to ps7_0_axi_periph/M19_AXI,
#      and clock / reset to FCLK_CLK0 / rst_ps7_0_100M like every other
#      AXI peripheral in this design.
#   5. Wires axi_gpio_wah/gpio_io_o to clash_lowpass_fir_0/wah_control.
#   6. Maps an AXI-Lite address segment at 0x43D30000 / 0x10000.
#   7. validate_bd_design + save_bd_design.
#
# Audio / DSP / GPIO / HDMI / encoder / pmod_i2s2: untouched. No bytes of
# the GPIO_CONTROL_MAP.md contract change.
#
# AXI master allocation (post Wah integration):
#   M00..M13  : audio_lab base block design (gate / overdrive / dist /
#               eq / delay-RAT / amp / amp_tone / cab / reverb / dma /
#               compressor / noise_suppressor and the AXIS switches).
#   M14       : axi_gpio_compressor       @ 0x43CD0000  (base block design)
#   M15       : axi_vdma_hdmi             @ 0x43CE0000  (hdmi)
#   M16       : v_tc_hdmi                 @ 0x43CF0000  (hdmi)
#   ---       : reserved                  @ 0x43D00000  (D32 future)
#   M17       : axi_encoder               @ 0x43D10000  (encoder)
#   M18       : axi_pmod_i2s2_status      @ 0x43D20000  (pmod_i2s2)
#   M19       : axi_gpio_wah              @ 0x43D30000  (new)

current_bd_design [get_bd_designs block_design]
current_bd_instance /

set WAH_AXI_OFFSET 0x43D30000
set WAH_AXI_RANGE  0x00010000

puts "WAH: starting Wah integration at $WAH_AXI_OFFSET / $WAH_AXI_RANGE on [current_bd_design]"

# -----------------------------------------------------------------------------
# 1. Expand ps7_0_axi_periph from NUM_MI=19 to NUM_MI=20 (adds M19)
# -----------------------------------------------------------------------------
set_property -dict [list CONFIG.NUM_MI {20}] [get_bd_cells ps7_0_axi_periph]

# -----------------------------------------------------------------------------
# 2. axi_gpio_wah (single-channel 32-bit all-output, same shape as the
#    existing axi_gpio_compressor / axi_gpio_noise_suppressor IPs)
# -----------------------------------------------------------------------------
set axi_gpio_wah [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_wah]
set_property -dict [list \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_GPIO_WIDTH {32} \
    CONFIG.C_IS_DUAL {0} \
] $axi_gpio_wah

# -----------------------------------------------------------------------------
# 3. AXI-Lite from ps7_0_axi_periph/M19 to the wah GPIO slave
# -----------------------------------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins ps7_0_axi_periph/M19_AXI] \
                    [get_bd_intf_pins axi_gpio_wah/S_AXI]

# Clock + reset from the existing 100 MHz peripheral domain
connect_bd_net [get_bd_pins ps7_0_axi_periph/M19_ACLK]    \
               [get_bd_pins processing_system7_0/FCLK_CLK0]
connect_bd_net [get_bd_pins ps7_0_axi_periph/M19_ARESETN] \
               [get_bd_pins rst_ps7_0_100M/peripheral_aresetn]

connect_bd_net [get_bd_pins axi_gpio_wah/s_axi_aclk]    \
               [get_bd_pins processing_system7_0/FCLK_CLK0]
connect_bd_net [get_bd_pins axi_gpio_wah/s_axi_aresetn] \
               [get_bd_pins rst_ps7_0_100M/peripheral_aresetn]

# -----------------------------------------------------------------------------
# 4. GPIO output -> clash_lowpass_fir_0/wah_control
# -----------------------------------------------------------------------------
connect_bd_net [get_bd_pins axi_gpio_wah/gpio_io_o] \
               [get_bd_pins clash_lowpass_fir_0/wah_control]

# -----------------------------------------------------------------------------
# 5. Address segment at 0x43D30000
# -----------------------------------------------------------------------------
create_bd_addr_seg -range $WAH_AXI_RANGE -offset $WAH_AXI_OFFSET \
    [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs axi_gpio_wah/S_AXI/Reg] \
    SEG_axi_gpio_wah_Reg

# -----------------------------------------------------------------------------
# 6. Validate + save
# -----------------------------------------------------------------------------
validate_bd_design
save_bd_design
puts "WAH: axi_gpio_wah added at $WAH_AXI_OFFSET. validate_bd_design passed."
