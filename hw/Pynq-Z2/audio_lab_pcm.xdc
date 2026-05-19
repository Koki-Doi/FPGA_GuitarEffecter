###################################################
## Phase 7C / 7D / 7E external PCM5102 DAC + PCM1808 ADC pin constraints
## on PMOD JB. Added to constrs_1 only when create_project.tcl is invoked
## WITHOUT the PMOD_I2S2_ENABLE=1 build-variant switch (i.e. the default
## Phase 7D close-out path). The four PCM5102 ports + two PCM1808 ports
## are created by pcm5102_dac_integration.tcl + pcm1808_adc_integration.tcl.
##
## Wiring (DECISIONS.md D38 / D40 / D41 / D42, IO_PIN_RESERVATION.md 4A.1):
##   JB1 (W14)  ext_audio_mclk_o     = constant 0          (PCM5102 SCK GND)
##   JB2 (Y14)  ext_audio_bclk_o     -> PCM1808 BCK + PCM5102 BCK  (ADAU BCLK)
##   JB3 (T11)  ext_audio_lrclk_o    -> PCM1808 LRCK + PCM5102 LCK (ADAU LRCLK)
##   JB4 (T10)  ext_adc_dout_i       <- PCM1808 DOUT       (input pin)
##   JB7 (V16)  ext_dac_din_o        -> PCM5102 DIN
##   JB8 (W16)  ext_pcm1808_sckie_o  -> PCM1808 SCKI       (12.288 MHz)
##
## All pins LVCMOS33, no PULLUP. Pmod I2S2 evaluation requires the
## variant switch (see audio_lab_pmod_i2s2.xdc).
###################################################
set_property PACKAGE_PIN W14 [get_ports {ext_audio_mclk_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_audio_mclk_o}]

set_property PACKAGE_PIN Y14 [get_ports {ext_audio_bclk_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_audio_bclk_o}]

set_property PACKAGE_PIN T11 [get_ports {ext_audio_lrclk_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_audio_lrclk_o}]

set_property PACKAGE_PIN V16 [get_ports {ext_dac_din_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_dac_din_o}]

set_property PACKAGE_PIN T10 [get_ports {ext_adc_dout_i}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_adc_dout_i}]

set_property PACKAGE_PIN W16 [get_ports {ext_pcm1808_sckie_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_pcm1808_sckie_o}]
