###################################################
## ARCHIVAL ONLY (DECISIONS.md D48): Phase 7C / 7D / 7E external PCM5102
## DAC + PCM1808 ADC pin constraints on PMOD JB. The Pmod I2S2 module is
## now the active external audio path (PMOD_I2S2_INTEGRATION_PLAN.md
## section 17, `audio_lab_pmod_i2s2.xdc`), so this file is intentionally
## NOT loaded by `create_project.tcl` any more. It is kept in the repo
## as historical reference for the pin layout used by `audio_lab.bit`
## from the Phase 7D close-out era (commit f502373 family).
##
## Re-enabling the PCM5102 / PCM1808 path would require: bringing
## `pcm5102_dac_integration.tcl` + `pcm1808_adc_integration.tcl` back
## into `create_project.tcl`, re-adding the matching `add_files` for
## the RTL under `hw/ip/pcm5102_*` / `hw/ip/pcm1808_*`, and loading
## this XDC alongside `audio_lab.xdc`. Pmod I2S2 must then be removed
## (see `audio_lab_pmod_i2s2.xdc`) since they share PMOD JB pins.
##
## Wiring (DECISIONS.md D38 / D40 / D41 / D42, IO_PIN_RESERVATION.md 4A.1):
##   JB1 (W14)  ext_audio_mclk_o     = constant 0          (PCM5102 SCK GND)
##   JB2 (Y14)  ext_audio_bclk_o     -> PCM1808 BCK + PCM5102 BCK  (ADAU BCLK)
##   JB3 (T11)  ext_audio_lrclk_o    -> PCM1808 LRCK + PCM5102 LCK (ADAU LRCLK)
##   JB4 (T10)  ext_adc_dout_i       <- PCM1808 DOUT       (input pin)
##   JB7 (V16)  ext_dac_din_o        -> PCM5102 DIN
##   JB8 (W16)  ext_pcm1808_sckie_o  -> PCM1808 SCKI       (12.288 MHz)
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
