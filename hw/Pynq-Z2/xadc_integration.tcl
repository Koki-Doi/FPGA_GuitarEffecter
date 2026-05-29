# XADC Wizard integration extension for the AudioLab block design.
#
# *** PROPOSAL -- NOT YET APPROVED / NOT YET BUILT ***
#
# This script is intentionally NOT sourced by create_project.tcl. It is the
# concrete artifact behind docs/ai_context/XADC_INTEGRATION_DESIGN.md, kept
# in-tree so the future Vivado rebuild is a review-and-source step rather
# than a from-scratch write. Building it is a separate, explicitly-approved
# step (PL change + timing review per CLAUDE.md). To prevent an accidental
# Vivado run from picking it up, it hard-errors unless the operator opts in:
#
#     set ::env(XADC_INTEGRATION_APPROVED) 1   ;# only when approved
#
if {![info exists ::env(XADC_INTEGRATION_APPROVED)] || \
        $::env(XADC_INTEGRATION_APPROVED) ne "1"} {
    error "xadc_integration.tcl is a PROPOSAL and is not approved to run. \
See docs/ai_context/XADC_INTEGRATION_DESIGN.md. Set \
env(XADC_INTEGRATION_APPROVED)=1 only after explicit approval."
}
#
# Purpose: add an AXI XADC Wizard reading Arduino A0 (= VAUX1, Zynq Y11/Y12)
# so the FP02M expression pedal can drive Wah POSITION. block_design.tcl is
# NOT edited; clash_lowpass_fir_0 is NOT modified (no new Clash port, DSP
# voicing byte-identical). Pairs with hw/Pynq-Z2/xadc_a0.xdc (VAUXP1/VAUXN1
# -> Y11/Y12 constraint), add_files-d from create_project.tcl when approved.
#
# AXI master allocation (post XADC integration):
#   M00..M19  : existing (see wah_integration.tcl; M19 = axi_gpio_wah).
#   M20       : xadc_wiz_a0             @ 0x43D40000  (new, this script)

current_bd_design [get_bd_designs block_design]
current_bd_instance /

set XADC_AXI_OFFSET 0x43D40000
set XADC_AXI_RANGE  0x00010000

puts "XADC: starting A0 (VAUX1) XADC integration at $XADC_AXI_OFFSET on [current_bd_design]"

# 1. Expand ps7_0_axi_periph from NUM_MI=20 to NUM_MI=21 (adds M20)
set_property -dict [list CONFIG.NUM_MI {21}] [get_bd_cells ps7_0_axi_periph]

# 2. xadc_wiz in AXI4-Lite mode, single VAUX1 channel, unipolar.
set xadc [create_bd_cell -type ip -vlnv xilinx.com:ip:xadc_wiz xadc_wiz_a0]
set_property -dict [list \
    CONFIG.INTERFACE_SELECTION {Enable_AXI} \
    CONFIG.XADC_STARUP_SELECTION {channel_sequencer} \
    CONFIG.CHANNEL_ENABLE_VAUXP1_VAUXN1 {true} \
    CONFIG.AVERAGE_ENABLE_VAUXP1_VAUXN1 {true} \
    CONFIG.SEQUENCER_MODE {Continuous} \
    CONFIG.OT_ALARM {false} \
    CONFIG.USER_TEMP_ALARM {false} \
    CONFIG.VCCINT_ALARM {false} \
    CONFIG.VCCAUX_ALARM {false} \
    CONFIG.ENABLE_VCCPINT_ALARM {false} \
    CONFIG.ENABLE_VCCPAUX_ALARM {false} \
    CONFIG.ENABLE_VCCDDRO_ALARM {false} \
    CONFIG.ENABLE_RESET {false} \
] $xadc

# 3. AXI-Lite from ps7_0_axi_periph/M20 to the XADC slave
connect_bd_intf_net [get_bd_intf_pins ps7_0_axi_periph/M20_AXI] \
                    [get_bd_intf_pins xadc_wiz_a0/s_axi_lite]
connect_bd_net [get_bd_pins ps7_0_axi_periph/M20_ACLK]    \
               [get_bd_pins processing_system7_0/FCLK_CLK0]
connect_bd_net [get_bd_pins ps7_0_axi_periph/M20_ARESETN] \
               [get_bd_pins rst_ps7_0_100M/peripheral_aresetn]
connect_bd_net [get_bd_pins xadc_wiz_a0/s_axi_aclk]    \
               [get_bd_pins processing_system7_0/FCLK_CLK0]
connect_bd_net [get_bd_pins xadc_wiz_a0/s_axi_aresetn] \
               [get_bd_pins rst_ps7_0_100M/peripheral_aresetn]

# 4. Expose the VAUX1 differential analog interface as an external port.
#    The XDC (xadc_a0.xdc) constrains VAUXP1/VAUXN1 to Y11/Y12.
make_bd_intf_pins_external [get_bd_intf_pins xadc_wiz_a0/Vaux1]
set_property name Vaux1 [get_bd_intf_ports Vaux1_0]

# 5. Address segment at 0x43D40000
create_bd_addr_seg -range $XADC_AXI_RANGE -offset $XADC_AXI_OFFSET \
    [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs xadc_wiz_a0/s_axi_lite/Reg] \
    SEG_xadc_wiz_a0_Reg

# 6. Validate + save
validate_bd_design
save_bd_design
puts "XADC: xadc_wiz_a0 added at $XADC_AXI_OFFSET (VAUX1 / A0). validate_bd_design passed."
