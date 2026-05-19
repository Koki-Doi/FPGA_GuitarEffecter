###################################################
## Phase Pmod-1/2/3 Digilent Pmod I2S2 (CS4344 DAC + CS5343 ADC)
## pin constraints on PMOD JB. This is the active PMOD JB external
## audio path (DECISIONS.md D48); `create_project.tcl` always loads
## this file. The PCM5102 / PCM1808 alternative (`audio_lab_pcm.xdc`)
## is archival only and is NOT loaded. The eight top-level ports
## are created by `pmod_i2s2_integration.tcl`.
##
## Wiring (PMOD_I2S2_INTEGRATION_PLAN.md section 10,
## DECISIONS.md D45 / D48):
##   JB1  (W14)  ext_pmod_i2s2_da_mclk_o   -> Pmod I2S2 J1 Pin  1  D/A MCLK
##   JB2  (Y14)  ext_pmod_i2s2_da_lrck_o   -> Pmod I2S2 J1 Pin  2  D/A LRCK
##   JB3  (T11)  ext_pmod_i2s2_da_sclk_o   -> Pmod I2S2 J1 Pin  3  D/A SCLK
##   JB4  (T10)  ext_pmod_i2s2_da_sdin_o   -> Pmod I2S2 J1 Pin  4  D/A SDIN
##   JB7  (V16)  ext_pmod_i2s2_ad_mclk_o   -> Pmod I2S2 J1 Pin  7  A/D MCLK
##   JB8  (W16)  ext_pmod_i2s2_ad_lrck_o   -> Pmod I2S2 J1 Pin  8  A/D LRCK
##   JB9  (V12)  ext_pmod_i2s2_ad_sclk_o   -> Pmod I2S2 J1 Pin  9  A/D SCLK
##   JB10 (W13)  ext_pmod_i2s2_ad_sdout_i  <- Pmod I2S2 J1 Pin 10  A/D SDOUT
##
## JB11 = GND (Pin 5/11), JB12 = 3.3V (Pin 6/12) -- supplied by the
## PYNQ-Z2 board. ALL eight signals are LVCMOS33, no PULLUP. Any
## previously-attached PCM5102 / PCM1808 jumper wiring must be
## physically removed before powering on; PMOD JB is dedicated to
## the Pmod I2S2 module.
###################################################
set_property PACKAGE_PIN W14 [get_ports {ext_pmod_i2s2_da_mclk_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_pmod_i2s2_da_mclk_o}]

set_property PACKAGE_PIN Y14 [get_ports {ext_pmod_i2s2_da_lrck_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_pmod_i2s2_da_lrck_o}]

set_property PACKAGE_PIN T11 [get_ports {ext_pmod_i2s2_da_sclk_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_pmod_i2s2_da_sclk_o}]

set_property PACKAGE_PIN T10 [get_ports {ext_pmod_i2s2_da_sdin_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_pmod_i2s2_da_sdin_o}]

set_property PACKAGE_PIN V16 [get_ports {ext_pmod_i2s2_ad_mclk_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_pmod_i2s2_ad_mclk_o}]

set_property PACKAGE_PIN W16 [get_ports {ext_pmod_i2s2_ad_lrck_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_pmod_i2s2_ad_lrck_o}]

set_property PACKAGE_PIN V12 [get_ports {ext_pmod_i2s2_ad_sclk_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_pmod_i2s2_ad_sclk_o}]

set_property PACKAGE_PIN W13 [get_ports {ext_pmod_i2s2_ad_sdout_i}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_pmod_i2s2_ad_sdout_i}]
