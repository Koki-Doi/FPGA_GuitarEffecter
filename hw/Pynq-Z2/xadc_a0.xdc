###################################################
## XADC Arduino A0 analog input (D74).
##
## A0 on the PYNQ-Z2 reaches the Zynq XADC as auxiliary channel VAUX1,
## whose dedicated analog pins are VAUXP1 = E17 and VAUXN1 = D18 (bank 35).
## The Arduino "arduino_a0 = Y11" board entry is the DIGITAL view of the
## header pin and is NOT XADC-capable, so the analog feed uses E17/D18.
##
## These ports are created by xadc_integration.tcl exporting the
## xadc_wiz_a0 Vaux1 interface to the top level (Vaux1_v_p / Vaux1_v_n).
## Loaded via add_files in create_project.tcl alongside audio_lab.xdc.
###################################################

set_property PACKAGE_PIN E17 [get_ports Vaux1_v_p]
set_property IOSTANDARD LVCMOS33 [get_ports Vaux1_v_p]
set_property PACKAGE_PIN D18 [get_ports Vaux1_v_n]
set_property IOSTANDARD LVCMOS33 [get_ports Vaux1_v_n]
