# Setup bclk. After DECISIONS.md D49, the ADAU1761 bclk (R18) is no
# longer loaded internally (the DSP I2S converter `i2s_to_stream_0`
# runs on Pmod-generated bclk_int via `pmod_i2s2_integration.tcl`),
# so `bclk_IBUF` may not exist any more. The -quiet wrappers prevent
# the otherwise spurious "set_property expects at least one object"
# critical warning. The `create_clock` and `set_false_path` lines stay
# because Vivado tolerates dangling clock definitions and the
# constraints still document the intent for any future rebuild that
# loads the ADAU bclk path again.
set_property -quiet CLOCK_DEDICATED_ROUTE FALSE [get_nets -quiet bclk_IBUF]
create_clock -add -name bclk -period 325 -waveform {0 162.5} [get_ports bclk]

## Asynchronous clock groups (supersedes the bclk-only false_path).
## These are all independent clock domains, crossed only through
## synchronised CDCs (i2s_to_stream BCLK<->fabric, axi_pmod_i2s2_status
## slave for the Pmod 48 MHz / audio_ext words, and the DSP-island
## axis_clock_converter for clk_fpga_0<->clk_fpga_1). Declaring them
## asynchronous removes the spurious inter-clock paths that STA would
## otherwise flag with a near-zero requirement -- notably the
## rst_ps7_0_100M -> pmod_master reset (clk_fpga_0 -> audio_ext) that was
## the -4.2 ns WNS worst path. -quiet tolerates a clock being absent in a
## future build variant.
##   clk_fpga_0  : 100 MHz fabric / AXI / DMA / GPIO / i2s_to_stream / pmod
##   clk_fpga_1  :  50 MHz DSP island (clash_lowpass_fir_0)
##   clk         :  48 MHz Pmod master internal
##   bclk        :   3 MHz I2S bit clock
##   clk_wiz_0   :  24 MHz codec mclk
##   audio_ext   :  12.288 MHz Pmod I2S master clock
##   clk_wiz_hdmi:  40 MHz HDMI pixel clock
set_clock_groups -asynchronous \
  -group [get_clocks -quiet clk_fpga_0] \
  -group [get_clocks -quiet clk_fpga_1] \
  -group [get_clocks -quiet clk] \
  -group [get_clocks -quiet bclk] \
  -group [get_clocks -quiet clk_out1_block_design_clk_wiz_0_0] \
  -group [get_clocks -quiet clk_out1_block_design_clk_wiz_audio_ext_0] \
  -group [get_clocks -quiet clk_out1_block_design_clk_wiz_hdmi_0]

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
## Footswitch feature: 3 guitar-pedal 3PDT footswitches on the Raspberry Pi
## header (user-requested). These use the spare RP GPIO reserved for
## footswitches in IO_PIN_RESERVATION.md section 4A.3
## (raspberry_pi_tri_i_15/16/17 = U7 / C20 / Y8); they do not share with PMOD
## JA/JB (section 4.6) or the encoder pins. The first RP build confirmed
## PULLUP true holds all three high when open (unwired read = 1,1,1).
##
##   fsw0_i = FX toggle    -> U7  = Sch rpio_17_r = GPIO17 = RP header pin 11
##   fsw1_i = preset next  -> C20 = Sch rpio_18_r = GPIO18 = RP header pin 12
##   fsw2_i = preset prev  -> Y8  = Sch rpio_19_r = GPIO19 = RP header pin 35
##
## Physical pin numbers verified from the official PYNQ-Z2 master XDC
## schematic net names (Sch=rpio_NN_r, NN = Raspberry Pi BCM GPIO number;
## cross-checked against rpio_02/03 = I2C GPIO2/3 and rpio_sd/sc = Y16/Y17).
## The RP header BCM "GPIOxx" silk / v1.0 manual are error-prone, so count
## physical pin positions (pin 1 = corner pad; odd 1..39 / even 2..40). To
## double-check on the loaded bit, ground a pin and watch
## FootswitchInput.read_levels() flip the channel (ch0=FS1/ch1=FS2/ch2=FS3).
##
## Wiring per switch: common -> the RP header signal pin, one throw -> a GND
## header pin, the other throw left open. PULLUP true makes the open position
## read high; the grounded position reads low. The 3PDT is an
## alternate-action (latching) switch, so each stomp flips the level;
## axi_footswitch_input latches one press_event per edge (either direction).
## Never wire these to 5V (DECISIONS.md D31).
###################################################
set_property PACKAGE_PIN U7  [get_ports {fsw0_i}]
set_property IOSTANDARD LVCMOS33 [get_ports {fsw0_i}]
set_property PULLUP true [get_ports {fsw0_i}]
set_property PACKAGE_PIN C20 [get_ports {fsw1_i}]
set_property IOSTANDARD LVCMOS33 [get_ports {fsw1_i}]
set_property PULLUP true [get_ports {fsw1_i}]
set_property PACKAGE_PIN Y8  [get_ports {fsw2_i}]
set_property IOSTANDARD LVCMOS33 [get_ports {fsw2_i}]
set_property PULLUP true [get_ports {fsw2_i}]

###################################################
## PMOD JB pin constraints live in `audio_lab_pmod_i2s2.xdc`. The
## Digilent Pmod I2S2 module (CS4344 DAC + CS5343 ADC) is the active
## external audio path on PMOD JB (`DECISIONS.md` D48); the legacy
## PCM5102 / PCM1808 constraint file (`audio_lab_pcm.xdc`) is kept in
## the repo as archival reference only and is NOT loaded by
## `create_project.tcl` any more.
##
## The split exists because Vivado 2019.1 does not support `if` in
## `.xdc` (the parser silently drops guarded pin assignments and the
## placer then fails with "IO placement infeasible"), so the simplest
## robust pattern is one file per variant + `add_files` selecting
## the right one in `create_project.tcl`.
###################################################
