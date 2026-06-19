# Re-run implementation from the existing synth_1 result after adding the
# D146 audio-output CDC pblock.  This deliberately does not reuse placement or
# routing from the baseline DCP: the pblock must prove that a fresh placement
# can keep the crossing compact.

set proj_name audio_lab
set pblock_xdc [file normalize ./audio_lab_cdc_pblock.xdc]

open_project ./${proj_name}/${proj_name}.xpr

set pblock_file [get_files -quiet */audio_lab_cdc_pblock.xdc]
if {[llength $pblock_file] == 0} {
    add_files -fileset constrs_1 -norecurse $pblock_xdc
    set pblock_file [get_files -quiet */audio_lab_cdc_pblock.xdc]
}
if {[llength $pblock_file] != 1} {
    error "expected exactly one audio_lab_cdc_pblock.xdc, got [llength $pblock_file]"
}
set_property USED_IN_SYNTHESIS false $pblock_file
set_property USED_IN_IMPLEMENTATION true $pblock_file
set_property PROCESSING_ORDER LATE $pblock_file

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "impl_1 did not complete: [get_property STATUS [get_runs impl_1]]"
}

open_run impl_1

set rpt_dir ./timing_reports/d146_pblock
file mkdir $rpt_dir
report_timing_summary -file $rpt_dir/timing_summary.rpt
report_cdc -details -file $rpt_dir/report_cdc.rpt
report_route_status -file $rpt_dir/route_status.rpt
report_bus_skew -warn_on_violation -file $rpt_dir/bus_skew.rpt

set pblock [get_pblocks -quiet pblock_audio_output_cdc]
if {[llength $pblock] != 1} {
    error "D146 pblock missing after implementation"
}
set fp [open $rpt_dir/pblock_membership.txt w]
puts $fp "grid_ranges=[get_property GRID_RANGES $pblock]"
puts $fp "assigned_cells=[llength [get_cells -quiet -of_objects $pblock]]"
foreach cell [lsort [get_cells -quiet -of_objects $pblock]] {
    puts $fp $cell
}
close $fp

close_design

file mkdir ./bitstreams
file copy -force \
    ./${proj_name}/${proj_name}.runs/impl_1/block_design_wrapper.bit \
    ./bitstreams/${proj_name}.bit
file copy -force \
    ./${proj_name}/${proj_name}.srcs/sources_1/bd/block_design/hw_handoff/block_design.hwh \
    ./bitstreams/${proj_name}.hwh

