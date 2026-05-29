# XADC Wizard integration extension for the AudioLab block design (D74).
#
# Sourced from create_project.tcl AFTER wah_integration.tcl. Adds an AXI
# XADC Wizard reading Arduino A0 so the FP02M expression pedal can drive
# Wah POSITION. A0 on the PYNQ-Z2 is the XADC auxiliary channel VAUX1
# (dedicated analog pins VAUXP1 = E17 / VAUXN1 = D18, bank 35); the
# Arduino "arduino_a0 = Y11" board entry is the DIGITAL view of the same
# header pin and is NOT XADC-capable, so the analog feed uses E17/D18 via
# hw/Pynq-Z2/xadc_a0.xdc.
#
# block_design.tcl is NOT edited. clash_lowpass_fir_0 is NOT modified (no
# new Clash port) so the DSP voicing is byte-identical. This is purely
# additive: ps7_0_axi_periph NUM_MI 20 -> 21 (adds M20), new xadc_wiz_a0
# AXI-Lite slave at 0x43D40000, and the Vaux1 analog interface exported as
# a top-level port.
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

# 2. xadc_wiz in AXI4-Lite mode, channel-sequencer continuous, VAUX1 only.
#    On-chip alarms disabled (we only want the external analog channel).
set xadc [create_bd_cell -type ip -vlnv xilinx.com:ip:xadc_wiz xadc_wiz_a0]
set_property -dict [list \
    CONFIG.INTERFACE_SELECTION {Enable_AXI} \
    CONFIG.XADC_STARUP_SELECTION {channel_sequencer} \
    CONFIG.SEQUENCER_MODE {Continuous} \
    CONFIG.CHANNEL_ENABLE_VAUXP1_VAUXN1 {true} \
    CONFIG.OT_ALARM {false} \
    CONFIG.USER_TEMP_ALARM {false} \
    CONFIG.VCCINT_ALARM {false} \
    CONFIG.VCCAUX_ALARM {false} \
    CONFIG.ENABLE_VCCPINT_ALARM {false} \
    CONFIG.ENABLE_VCCPAUX_ALARM {false} \
    CONFIG.ENABLE_VCCDDRO_ALARM {false} \
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

# 4. Export the VAUX1 differential analog interface as a top-level port.
#    The XDC (xadc_a0.xdc) constrains Vaux1_v_p / Vaux1_v_n to E17 / D18.
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
