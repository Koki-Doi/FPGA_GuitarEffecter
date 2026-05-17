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

# Add constraints file
add_files -fileset constrs_1 -norecurse $origin_dir/audio_lab.xdc

# Phase 7F/7G: add the rotary-encoder input RTL as a regular source before
# the block design references it via `create_bd_cell -type module -reference
# axi_encoder_input` inside encoder_integration.tcl.
add_files -norecurse $origin_dir/../ip/encoder_input/src/axi_encoder_input.v
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
