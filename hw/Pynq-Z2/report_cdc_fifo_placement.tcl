# Inspect the placement-sensitive clk_fpga_0 <-> clk audio crossing from a
# routed checkpoint.  Usage:
#
#   vivado -mode batch -notrace -source report_cdc_fifo_placement.tcl \
#     -tclargs <routed.dcp> <output-dir> [pblock.xdc]
#
# This script is read-only: it opens the checkpoint and writes reports without
# modifying the project or checkpoint.

if {$argc != 2 && $argc != 3} {
    error "usage: report_cdc_fifo_placement.tcl <routed.dcp> <output-dir> [pblock.xdc]"
}

set dcp_path [file normalize [lindex $argv 0]]
set out_dir [file normalize [lindex $argv 1]]
file mkdir $out_dir

open_checkpoint $dcp_path
if {$argc == 3} {
    source [file normalize [lindex $argv 2]]
}

set clk_fabric [get_clocks -quiet clk_fpga_0]
set clk_i2s [get_clocks -quiet clk]
if {[llength $clk_fabric] != 1 || [llength $clk_i2s] != 1} {
    error "expected exactly one clk_fpga_0 and one clk clock"
}

report_cdc -details -file [file join $out_dir report_cdc.rpt]
report_timing \
    -from $clk_fabric -to $clk_i2s \
    -delay_type max -max_paths 200 -nworst 1 -sort_by slack \
    -file [file join $out_dir timing_fabric_to_i2s.rpt]
report_timing \
    -from $clk_i2s -to $clk_fabric \
    -delay_type max -max_paths 200 -nworst 1 -sort_by slack \
    -file [file join $out_dir timing_i2s_to_fabric.rpt]

proc optional_property {name object} {
    if {[catch {get_property $name $object} value]} {
        return ""
    }
    return $value
}

proc write_path_inventory {path_collection output_path} {
    set fp [open $output_path w]
    puts $fp "slack\tdatapath_delay\tstart_cell\tstart_ref\tstart_loc\tstart_bel\tend_cell\tend_ref\tend_loc\tend_bel"
    foreach path $path_collection {
        set start_pin [get_property STARTPOINT_PIN $path]
        set end_pin [get_property ENDPOINT_PIN $path]
        set start_cell [get_cells -quiet -of_objects $start_pin]
        set end_cell [get_cells -quiet -of_objects $end_pin]
        puts $fp [join [list \
            [optional_property SLACK $path] \
            [optional_property DATAPATH_DELAY $path] \
            $start_cell \
            [optional_property REF_NAME $start_cell] \
            [optional_property LOC $start_cell] \
            [optional_property BEL $start_cell] \
            $end_cell \
            [optional_property REF_NAME $end_cell] \
            [optional_property LOC $end_cell] \
            [optional_property BEL $end_cell]] "\t"]
    }
    close $fp
}

set forward_paths [get_timing_paths \
    -from $clk_fabric -to $clk_i2s \
    -delay_type max -max_paths 200 -nworst 1 -sort_by slack]
set reverse_paths [get_timing_paths \
    -from $clk_i2s -to $clk_fabric \
    -delay_type max -max_paths 200 -nworst 1 -sort_by slack]

write_path_inventory $forward_paths [file join $out_dir paths_fabric_to_i2s.tsv]
write_path_inventory $reverse_paths [file join $out_dir paths_i2s_to_fabric.tsv]

set hierarchy_patterns [list \
    {block_design_i/i2s_to_stream_0/U0/*} \
    {block_design_i/axis_switch_sink/inst/*}]
set fp [open [file join $out_dir hierarchy_cells.tsv] w]
puts $fp "cell\tref\tloc\tbel"
foreach pattern $hierarchy_patterns {
    foreach cell [lsort [get_cells -hierarchical -quiet -filter "NAME =~ $pattern"]] {
        puts $fp [join [list \
            $cell \
            [optional_property REF_NAME $cell] \
            [optional_property LOC $cell] \
            [optional_property BEL $cell]] "\t"]
    }
}
close $fp

set pblock_source_pattern {block_design_i/axis_switch_sink/inst/gen_transfer_mux?0?.axisc_transfer_mux_0/axisc_register_slice_0/gen_AB_reg_slice.*}
set pblock_target_pattern {block_design_i/i2s_to_stream_0/U0/ADAU1761_topEntity_trueDualPortBlockRamWrapper_ccase_scrut/*}
set pblock_source_cells [get_cells -hierarchical -quiet -filter \
    "IS_PRIMITIVE == 1 && NAME =~ $pblock_source_pattern"]
set pblock_target_cells [get_cells -hierarchical -quiet -filter \
    "IS_PRIMITIVE == 1 && NAME =~ $pblock_target_pattern"]

# A stable, timestamp-free physical fingerprint for comparing independent
# implementation variants.  D146 acceptance requires multiple genuinely
# different placements, not merely .bit files with different headers.
set fp [open [file join $out_dir cdc_placement.tsv] w]
puts $fp "cell\tref\tloc\tbel"
foreach cell [lsort -unique [concat $pblock_source_cells $pblock_target_cells]] {
    puts $fp [join [list \
        $cell \
        [optional_property REF_NAME $cell] \
        [optional_property LOC $cell] \
        [optional_property BEL $cell]] "\t"]
}
close $fp

set fp [open [file join $out_dir pblock_selection.txt] w]
puts $fp "source_pattern=$pblock_source_pattern"
puts $fp "source_primitives=[llength $pblock_source_cells]"
puts $fp "target_pattern=$pblock_target_pattern"
puts $fp "target_primitives=[llength $pblock_target_cells]"
set pblock [get_pblocks -quiet pblock_audio_output_cdc]
puts $fp "pblock_present=[llength $pblock]"
if {[llength $pblock] == 1} {
    puts $fp "pblock_grid_ranges=[optional_property GRID_RANGES $pblock]"
    puts $fp "pblock_cells=[llength [get_cells -quiet -of_objects $pblock]]"
}
close $fp

close_design
