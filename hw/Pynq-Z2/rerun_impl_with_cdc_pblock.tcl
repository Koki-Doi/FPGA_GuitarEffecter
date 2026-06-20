# Re-run implementation from the existing synth_1 result after adding the
# D146 audio-output CDC pblock.  This deliberately does not reuse placement or
# routing from the baseline DCP: the pblock must prove that a fresh placement
# can keep the crossing compact.
#
# Default candidate build (also refreshes bitstreams/audio_lab.{bit,hwh}):
#   vivado -mode batch -notrace -source rerun_impl_with_cdc_pblock.tcl
#
# Independent acceptance variant (archives without replacing the deployed
# candidate files):
#   vivado -mode batch -notrace -source rerun_impl_with_cdc_pblock.tcl \
#     -tclargs d146_b_explore Explore Default

if {$argc == 0} {
    set variant_label d146_pblock
    set place_directive Default
    set route_directive Default
    set refresh_candidate_bitstreams true
} elseif {$argc == 3} {
    set variant_label [lindex $argv 0]
    set place_directive [lindex $argv 1]
    set route_directive [lindex $argv 2]
    set refresh_candidate_bitstreams false
} else {
    error "usage: rerun_impl_with_cdc_pblock.tcl ?<label> <place-directive> <route-directive>?"
}

if {![regexp {^[A-Za-z0-9_.-]+$} $variant_label]} {
    error "variant label contains unsupported characters: $variant_label"
}

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

set impl_run [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE $place_directive $impl_run
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE $route_directive $impl_run

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "impl_1 did not complete: [get_property STATUS [get_runs impl_1]]"
}

open_run impl_1

set rpt_dir ./timing_reports/$variant_label
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

set source_pattern {block_design_i/axis_switch_sink/inst/gen_transfer_mux?0?.axisc_transfer_mux_0/axisc_register_slice_0/gen_AB_reg_slice.*}
set target_pattern {block_design_i/i2s_to_stream_0/U0/ADAU1761_topEntity_trueDualPortBlockRamWrapper_ccase_scrut/*}
set source_cells [get_cells -hierarchical -quiet -filter \
    "IS_PRIMITIVE == 1 && NAME =~ $source_pattern"]
set target_cells [get_cells -hierarchical -quiet -filter \
    "IS_PRIMITIVE == 1 && NAME =~ $target_pattern"]
set fp [open $rpt_dir/cdc_placement.tsv w]
puts $fp "cell\tref\tloc\tbel"
foreach cell [lsort -unique [concat $source_cells $target_cells]] {
    puts $fp [join [list \
        $cell \
        [get_property REF_NAME $cell] \
        [get_property LOC $cell] \
        [get_property BEL $cell]] "\t"]
}
close $fp

set artifact_dir $rpt_dir/artifacts
file mkdir $artifact_dir
write_checkpoint -force $artifact_dir/block_design_wrapper_routed.dcp
file copy -force \
    ./${proj_name}/${proj_name}.runs/impl_1/block_design_wrapper.bit \
    $artifact_dir/${proj_name}.bit
file copy -force \
    ./${proj_name}/${proj_name}.srcs/sources_1/bd/block_design/hw_handoff/block_design.hwh \
    $artifact_dir/${proj_name}.hwh

set fp [open $artifact_dir/build_manifest.txt w]
puts $fp "variant=$variant_label"
puts $fp "place_directive=$place_directive"
puts $fp "route_directive=$route_directive"
puts $fp "pblock_grid_ranges=[get_property GRID_RANGES $pblock]"
puts $fp "pblock_assigned_cells=[llength [get_cells -quiet -of_objects $pblock]]"
puts $fp "source_primitives=[llength $source_cells]"
puts $fp "target_primitives=[llength $target_cells]"
close $fp

close_design

if {$refresh_candidate_bitstreams} {
    file mkdir ./bitstreams
    file copy -force \
        ./${proj_name}/${proj_name}.runs/impl_1/block_design_wrapper.bit \
        ./bitstreams/${proj_name}.bit
    file copy -force \
        ./${proj_name}/${proj_name}.srcs/sources_1/bd/block_design/hw_handoff/block_design.hwh \
        ./bitstreams/${proj_name}.hwh
}
