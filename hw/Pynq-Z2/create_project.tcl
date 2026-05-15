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

# Generate block design
source ./block_design.tcl
# Phase 4: extend the block design with the HDMI framebuffer output path.
# The audio path / GPIOs / DSP block / addresses below 0x43CE0000 stay untouched.
source ./hdmi_integration.tcl
make_wrapper -files [get_files ./${proj_name}/${proj_name}.srcs/sources_1/bd/block_design/block_design.bd] -top
add_files -norecurse ./${proj_name}/${proj_name}.srcs/sources_1/bd/block_design/hdl/block_design_wrapper.vhd
update_compile_order -fileset sources_1

# Compile
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1

# Collect bitstream and hwh files
if {![file exists ./bitstreams/]} {
	file mkdir ./bitstreams/
}
file copy -force ./${proj_name}/${proj_name}.runs/impl_1/block_design_wrapper.bit ./bitstreams/${proj_name}.bit
file copy -force ./${proj_name}/${proj_name}.srcs/sources_1/bd/block_design/hw_handoff/block_design.hwh ./bitstreams/${proj_name}.hwh
