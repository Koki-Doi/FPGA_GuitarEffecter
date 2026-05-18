# Setup bclk
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets bclk_IBUF]
create_clock -add -name bclk -period 325 -waveform {0 162.5} [get_ports bclk]

## Ignore inter clock paths in timing analysis
set_false_path -from [get_clocks bclk] -to [get_clocks clk_fpga_0]
set_false_path -from [get_clocks clk_fpga_0] -to [get_clocks bclk]

## Audio

## Masater clock
set_property PACKAGE_PIN U5 [get_ports {mclk}]
set_property IOSTANDARD LVCMOS33 [get_ports {mclk}]

## Chip address bits
set_property PACKAGE_PIN M17 [get_ports {codec_address[0]}]  
set_property IOSTANDARD LVCMOS33 [get_ports {codec_address[0]}]

set_property PACKAGE_PIN M18 [get_ports {codec_address[1]}]  
set_property IOSTANDARD LVCMOS33 [get_ports {codec_address[1]}]

## I2C interface
set_property PACKAGE_PIN U9 [get_ports {IIC_1_scl_io}]
set_property PULLUP true [get_ports {IIC_1_scl_io}]  
set_property IOSTANDARD LVCMOS33 [get_ports {IIC_1_scl_io}]

set_property PACKAGE_PIN T9 [get_ports {IIC_1_sda_io}]
set_property PULLUP true [get_ports {IIC_1_sda_io}]  
set_property IOSTANDARD LVCMOS33 [get_ports {IIC_1_sda_io}]

## Aud DIN
set_property PACKAGE_PIN F17 [get_ports {sdata_i}]  
set_property IOSTANDARD LVCMOS33 [get_ports {sdata_i}]

## AUD DOUT
set_property PACKAGE_PIN G18 [get_ports {sdata_o}]  
set_property IOSTANDARD LVCMOS33 [get_ports {sdata_o}]

## AUD  BCLK
set_property PACKAGE_PIN R18 [get_ports {bclk}]  
set_property IOSTANDARD LVCMOS33 [get_ports {bclk}] 


## AUD LRCLK
set_property PACKAGE_PIN T17 [get_ports {lrclk}]  
set_property IOSTANDARD LVCMOS33 [get_ports {lrclk}] 

###################################################
## 24 mhz clock to audio chip
#set_property PACKAGE_PIN AB2 [get_ports {AC_MCLK}]
#set_property IOSTANDARD LVCMOS33 [get_ports {AC_MCLK}]


## I2S transfers audio samples
## i2s bit clock to ADAU1761
#set_property PACKAGE_PIN Y8 [get_ports {AC_GPIO0}]
#set_property IOSTANDARD LVCMOS33 [get_ports {AC_GPIO0}]

## i2s bit clock from ADAU1761
#set_property PACKAGE_PIN AA7 [get_ports {AC_GPIO1}]
#set_property IOSTANDARD LVCMOS33 [get_ports {AC_GPIO1}]

## i2s bit clock from ADAU1761
#set_property PACKAGE_PIN AA6 [get_ports {AC_GPIO2}]
#set_property IOSTANDARD LVCMOS33 [get_ports {AC_GPIO2}]

## i2s l/r 48 khz toggling signal from ADAU1761 (sample clock)
#set_property PACKAGE_PIN Y6 [get_ports {AC_GPIO3}]
#set_property IOSTANDARD LVCMOS33 [get_ports {AC_GPIO3}]


## I2C Data Interface to ADAU1761 (for configuration)
#set_property PACKAGE_PIN AB4 [get_ports {AC_SCK}]
#set_property IOSTANDARD LVCMOS33 [get_ports {AC_SCK}]

#set_property PACKAGE_PIN AB5 [get_ports {AC_SDA}]
#set_property IOSTANDARD LVCMOS33 [get_ports {AC_SDA}]

#set_property PACKAGE_PIN AB1 [get_ports {AC_ADR0}]
#set_property IOSTANDARD LVCMOS33 [get_ports {AC_ADR0}]

#set_property PACKAGE_PIN Y5 [get_ports {AC_ADR1}]
#set_property IOSTANDARD LVCMOS33 [get_ports {AC_ADR1}]


#AC_MCLK      : out   STD_LOGIC                      -- 24 Mhz for ADAU1761

#AC_ADR0      : out   STD_LOGIC                      -- I2C contol signals to ADAU1761, for configuration
#AC_ADR1      : out   STD_LOGIC
#AC_SCK       : out   STD_LOGIC
#AC_SDA       : inout STD_LOGIC

#AC_GPIO0     : out   STD_LOGIC                      -- I2S MISO
#AC_GPIO1     : in    STD_LOGIC                      -- I2S MOSI
#AC_GPIO2     : in    STD_LOGIC                      -- I2S_bclk
#AC_GPIO3     : in    STD_LOGIC                      -- I2S_LR


###################################################
## HDMI TX (PYNQ-Z2 HDMI OUT)
##
## Pin locations come from the TUL PYNQ-Z2 board file
## (/home/doi20/board_files/XilinxBoardStore/boards/TUL/pynq-z2/1.0/part0_pins.xml).
## Do not set IOSTANDARD here: Digilent rgb2dvi instantiates OBUFDS with
## its own TMDS_33 IOSTANDARD, and adding LVCMOS33 to these differential
## top-level ports makes Vivado placement fail.
###################################################
set_property PACKAGE_PIN L16 [get_ports {hdmi_tx_clk_p}]
set_property PACKAGE_PIN L17 [get_ports {hdmi_tx_clk_n}]

set_property PACKAGE_PIN K17 [get_ports {hdmi_tx_data_p[0]}]
set_property PACKAGE_PIN K18 [get_ports {hdmi_tx_data_n[0]}]

set_property PACKAGE_PIN K19 [get_ports {hdmi_tx_data_p[1]}]
set_property PACKAGE_PIN J19 [get_ports {hdmi_tx_data_n[1]}]

set_property PACKAGE_PIN J18 [get_ports {hdmi_tx_data_p[2]}]
set_property PACKAGE_PIN H18 [get_ports {hdmi_tx_data_n[2]}]

###################################################
## Phase 7F/7G: 3 rotary encoder modules on the Raspberry Pi header.
##
## Module silkscreen = CLK / DT / SW / + / GND. + is wired to PYNQ-Z2 3.3V
## ONLY (5V would lift the module pull-ups onto PL pins; see DECISIONS.md D31).
## All nine signals are LVCMOS33 inputs on RPi header pins that do not share
## with PMOD JA (see IO_PIN_RESERVATION.md section 4.6).
## PMOD JA and PMOD JB are intentionally NOT used here -- they stay reserved
## for the planned external PCM1808/PCM5102 codec path (DECISIONS.md D28).
##
## PULLUP is left at the default. The encoder modules ship with onboard
## pull-ups; if a specific module lacks them, add `set_property PULLUP true`
## below per pin instead of rewiring the board.
###################################################
set_property PACKAGE_PIN F19 [get_ports {enc0_clk_i}]
set_property IOSTANDARD LVCMOS33 [get_ports {enc0_clk_i}]
set_property PACKAGE_PIN V10 [get_ports {enc0_dt_i}]
set_property IOSTANDARD LVCMOS33 [get_ports {enc0_dt_i}]
set_property PACKAGE_PIN V8  [get_ports {enc0_sw_i}]
set_property IOSTANDARD LVCMOS33 [get_ports {enc0_sw_i}]

set_property PACKAGE_PIN W10 [get_ports {enc1_clk_i}]
set_property IOSTANDARD LVCMOS33 [get_ports {enc1_clk_i}]
set_property PACKAGE_PIN B20 [get_ports {enc1_dt_i}]
set_property IOSTANDARD LVCMOS33 [get_ports {enc1_dt_i}]
set_property PACKAGE_PIN W8  [get_ports {enc1_sw_i}]
set_property IOSTANDARD LVCMOS33 [get_ports {enc1_sw_i}]

set_property PACKAGE_PIN V6  [get_ports {enc2_clk_i}]
set_property IOSTANDARD LVCMOS33 [get_ports {enc2_clk_i}]
set_property PACKAGE_PIN Y6  [get_ports {enc2_dt_i}]
set_property IOSTANDARD LVCMOS33 [get_ports {enc2_dt_i}]
set_property PACKAGE_PIN B19 [get_ports {enc2_sw_i}]
set_property IOSTANDARD LVCMOS33 [get_ports {enc2_sw_i}]

###################################################
## Phase 7C: PCM5102 (external DAC) bring-up on PMOD JB.
##
## Wiring (DECISIONS.md D38, IO_PIN_RESERVATION.md 4A.1):
##   JB1 (W14)  EXT_AUDIO_MCLK  -> PCM5102 SCK   (12.288 MHz)
##   JB2 (Y14)  EXT_AUDIO_BCLK  -> PCM5102 BCK   ( 3.072 MHz)
##   JB3 (T11)  EXT_AUDIO_LRCLK -> PCM5102 LCK   (48 kHz)
##   JB7 (V16)  EXT_DAC_DIN     -> PCM5102 DIN   (24-bit I2S)
##
## PCM1808 (ADC) pins are NOT added yet -- Phase 7D.
## All four pins are LVCMOS33 outputs, no PULLUP. PMOD JA stays free.
###################################################
set_property PACKAGE_PIN W14 [get_ports {ext_audio_mclk_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_audio_mclk_o}]

set_property PACKAGE_PIN Y14 [get_ports {ext_audio_bclk_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_audio_bclk_o}]

set_property PACKAGE_PIN T11 [get_ports {ext_audio_lrclk_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_audio_lrclk_o}]

set_property PACKAGE_PIN V16 [get_ports {ext_dac_din_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_dac_din_o}]

###################################################
## Phase 7D: PCM1808 (external ADC) bring-up on PMOD JB4.
##
## Wiring (DECISIONS.md D41, IO_PIN_RESERVATION.md 4A.1):
##   JB1 (W14)  EXT_AUDIO_MCLK  -> PCM1808 SCKI  (12.288 MHz)   *physically
##                                                               disconnected
##                                                               from PCM5102 SCK*
##   JB2 (Y14)  EXT_AUDIO_BCLK  -> PCM1808 BCK + PCM5102 BCK    (= ADAU BCLK)
##   JB3 (T11)  EXT_AUDIO_LRCLK -> PCM1808 LRCK + PCM5102 LCK   (= ADAU LRCLK)
##   JB4 (T10)  EXT_ADC_DOUT    <- PCM1808 DOUT                 (new input pin)
##   JB7 (V16)  EXT_DAC_DIN     -> PCM5102 DIN                  (unchanged)
##
## PCM1808 mode pins (FMT / MD0 / MD1) are NOT wired -- the module is
## strapped to I2S slave mode on the board. LVCMOS33 input, no pull.
## *Do not* drive 5V on this pin -- PCM1808 module VCC must be at the
## level its onboard regulator expects to feed a 3.3V DOUT.
###################################################
set_property PACKAGE_PIN T10 [get_ports {ext_adc_dout_i}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_adc_dout_i}]

###################################################
## Phase 7D follow-up (DECISIONS.md D42): PCM1808 SCKI on dedicated JB8.
##
## JB1 stays at constant 0 (D40 SCK-low fix preserved structurally).
## PCM1808 SCKI = 12.288 MHz from clk_wiz_audio_ext, routed to JB8 / W16
## so the FPGA-side guarantee no longer depends on the user's physical
## isolation of PCM5102 SCK from JB1.
###################################################
set_property PACKAGE_PIN W16 [get_ports {ext_pcm1808_sckie_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {ext_pcm1808_sckie_o}]
