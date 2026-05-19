set proj_name "audio_lab"
set origin_dir "."
set board_repo_paths [list /home/doi20/board_files /home/doi20/vivado-board-repo]
set_param board.repoPaths $board_repo_paths

set iprepo_dir $origin_dir/../ip

# Locate the Digilent vivado-library IP repo for the HDMI TX (rgb2dvi).
# Prefer $DIGILENT_VIVADO_LIBRARY when set; else fall back to the stable
# local path outside this repository. The library is intentionally NOT
# copied or submoduled into the AudioLab tree.
if {[info exists ::env(DIGILENT_VIVADO_LIBRARY)]} {
    set digilent_vivado_library $::env(DIGILENT_VIVADO_LIBRARY)
} else {
    set digilent_vivado_library "/home/doi20/digilent-vivado-library"
}
set digilent_ip_repo "$digilent_vivado_library/ip"
if {![file isdirectory $digilent_ip_repo]} {
    error "Digilent vivado-library not found at $digilent_ip_repo. Set DIGILENT_VIVADO_LIBRARY or clone Digilent/vivado-library to /home/doi20/digilent-vivado-library."
}
if {![file exists "$digilent_ip_repo/rgb2dvi/component.xml"]} {
    error "Digilent rgb2dvi IP component.xml missing under $digilent_ip_repo. Re-clone Digilent/vivado-library or fix DIGILENT_VIVADO_LIBRARY."
}

# Create project
create_project ${proj_name} ./${proj_name} -part xc7z020clg400-1
set_property board_part tul.com.tw:pynq-z2:part0:1.0 [current_project]
set_property ip_repo_paths [list $iprepo_dir $digilent_ip_repo] [current_project]
set_property target_language VHDL [current_project]
update_ip_catalog

# Add constraints file. audio_lab.xdc carries the universally-present
# constraints (ADAU1761 codec, HDMI TX, encoder pins). The PMOD JB pin
# constraints live in a per-variant XDC because Vivado 2019.1 does NOT
# accept `if` in .xdc -- guarded pin assignments are silently dropped,
# leading to "IO placement infeasible" at impl_1.
add_files -fileset constrs_1 -norecurse $origin_dir/audio_lab.xdc
if {[info exists ::env(PMOD_I2S2_ENABLE)] && $::env(PMOD_I2S2_ENABLE) == 1} {
    puts "create_project: PMOD_I2S2_ENABLE=1 -- using audio_lab_pmod_i2s2.xdc for PMOD JB pin constraints"
    add_files -fileset constrs_1 -norecurse $origin_dir/audio_lab_pmod_i2s2.xdc
} else {
    add_files -fileset constrs_1 -norecurse $origin_dir/audio_lab_pcm.xdc
}

# Phase 7F/7G: add the rotary-encoder input RTL as a regular source before
# the block design references it via `create_bd_cell -type module -reference
# axi_encoder_input` inside encoder_integration.tcl.
add_files -norecurse $origin_dir/../ip/encoder_input/src/axi_encoder_input.v
# Phase 7C: add the PCM5102 DAC-only tone RTL similarly before
# pcm5102_dac_integration.tcl references it via create_bd_cell -type module.
# (Phase 7E retires the tone module from the block design but keeps the
# source in the project as a known-good free-running reference.)
add_files -norecurse $origin_dir/../ip/pcm5102_dac_tone/src/pcm5102_dac_tone.v
# Phase 7E: add the trivial pcm5102_audio_out pass-through that mirrors the
# ADAU1761 I2S DAC interface onto the PMOD JB external-DAC pins.
add_files -norecurse $origin_dir/../ip/pcm5102_audio_out/src/pcm5102_audio_out.v
# Phase 7D: add the tiny pcm1808_input_select 2:1 wire mux that picks
# between ADAU1761 sdata_i and the new external PCM1808 DOUT as the feed
# to i2s_to_stream_0/si.
add_files -norecurse $origin_dir/../ip/pcm1808_adc_input/src/pcm1808_input_select.v
# Phase Pmod-1/2/3: add the Pmod I2S2 master + AXI-Lite status slave
# RTL ahead of pmod_i2s2_integration.tcl. They are only instantiated when
# this build variant is selected (PMOD_I2S2_ENABLE=1, see below); the
# sources_1 add_files itself is unconditional so future re-builds without
# the variant can still elaborate the project.
add_files -norecurse $origin_dir/../ip/pmod_i2s2/src/pmod_i2s2_master.v
add_files -norecurse $origin_dir/../ip/pmod_i2s2/src/axi_pmod_i2s2_status.v
update_compile_order -fileset sources_1

# Generate block design
source ./block_design.tcl
# Phase 4: extend the block design with the HDMI framebuffer output path.
# The audio path / GPIOs / DSP block / addresses below 0x43CE0000 stay untouched.
source ./hdmi_integration.tcl
# Phase 7F/7G: extend with the rotary-encoder input IP (AXI-Lite at 0x43D10000).
# The audio path, DSP block, existing GPIOs, and HDMI integration are not
# touched. The encoder IP simply adds M17 on ps7_0_axi_periph.
source ./encoder_integration.tcl
# Phase Pmod-1/2/3 build variant select. Set PMOD_I2S2_ENABLE to 1 in the
# environment to source the Pmod I2S2 integration tcl and SKIP the existing
# PCM5102 / PCM1808 scripts; PMOD JB then belongs to the Digilent Pmod I2S2
# board (CS4344 DAC + CS5343 ADC) and the PCM5102 / PCM1808 jumper wiring
# must be physically removed before powering. Default (variable absent or
# 0) keeps the Phase 7D close-out behaviour (PCM5102 mirror + PCM1808 mux
# falling back to ADAU).
if {[info exists ::env(PMOD_I2S2_ENABLE)] && $::env(PMOD_I2S2_ENABLE) == 1} {
    puts "create_project: PMOD_I2S2_ENABLE=1 -- sourcing pmod_i2s2_integration.tcl, skipping pcm5102 / pcm1808"
    source ./pmod_i2s2_integration.tcl
} else {
    # Phase 7C: extend with the PCM5102 external DAC bring-up (4 top-level
    # I2S pins on PMOD JB driven by a dedicated 12.288 MHz MMCM and a small
    # RTL tone generator). No AXI-Lite. Existing audio / HDMI / encoder /
    # GPIO untouched.
    source ./pcm5102_dac_integration.tcl
    # Phase 7D: extend with the PCM1808 external ADC bring-up. Inserts a 2:1
    # wire mux on the i2s_to_stream_0/si input so the existing AXIS DSP chain
    # can be fed from either the ADAU1761 ADC (sdata_i) or the new PCM1808
    # DOUT (ext_adc_dout_i on JB4 / T10). Build-time default picks PCM1808.
    # No AXI-Lite, no GPIO, no block_design.tcl direct edit.
    source ./pcm1808_adc_integration.tcl
}
make_wrapper -files [get_files ./${proj_name}/${proj_name}.srcs/sources_1/bd/block_design/block_design.bd] -top
add_files -norecurse ./${proj_name}/${proj_name}.srcs/sources_1/bd/block_design/hdl/block_design_wrapper.vhd
update_compile_order -fileset sources_1

# Phase 7F: explicitly generate the block-design IP synthesis targets so
# launch_runs picks up every per-IP OOC synth. On a clean project tree
# (audio_lab.cache wiped) launch_runs impl_1 alone leaves the IPs as
# black boxes and opt_design fails with DRC INBB-3. Calling
# generate_target {synthesis} on the .bd file forces all per-IP HDL +
# OOC run definitions to be created before synth_1 / impl_1 fan out.
generate_target {synthesis} \
    [get_files ./${proj_name}/${proj_name}.srcs/sources_1/bd/block_design/block_design.bd]

# Compile: explicit synth_1 then impl_1 makes the OOC IP synth fan-out
# unambiguous (each tier's wait_on_run blocks until every dependency
# finishes). The previous "launch_runs impl_1 -to_step write_bitstream"
# one-shot relied on a populated audio_lab.cache from a prior build.
launch_runs synth_1 -jobs 2
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1

# Collect bitstream and hwh files
if {![file exists ./bitstreams/]} {
	file mkdir ./bitstreams/
}
file copy -force ./${proj_name}/${proj_name}.runs/impl_1/block_design_wrapper.bit ./bitstreams/${proj_name}.bit
file copy -force ./${proj_name}/${proj_name}.srcs/sources_1/bd/block_design/hw_handoff/block_design.hwh ./bitstreams/${proj_name}.hwh
