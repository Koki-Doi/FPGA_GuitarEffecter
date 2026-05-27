open_project ./audio_lab/audio_lab.xpr
update_compile_order -fileset sources_1
# The Clash-emitted i2s_to_stream IP's dual-port BRAM wrapper was
# patched (D54) so Vivado 2019.1 can synthesize it from scratch.
# Reset the previously-failed runs and re-launch.
reset_run block_design_i2s_to_stream_0_0_synth_1
reset_run impl_1
launch_runs block_design_i2s_to_stream_0_0_synth_1 -jobs 2
wait_on_run block_design_i2s_to_stream_0_0_synth_1
puts "=== i2s synth status: [get_property STATUS [get_runs block_design_i2s_to_stream_0_0_synth_1]] ==="
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
puts "=== impl_1 status: [get_property STATUS [get_runs impl_1]] ==="

# ---- Post-implementation timing and utilization reports ----
open_run impl_1

set rpt_dir "./timing_reports"
if {![file exists $rpt_dir]} { file mkdir $rpt_dir }

report_timing_summary -file $rpt_dir/timing_summary.rpt
report_timing -max_paths 100 -sort_by group -file $rpt_dir/timing_by_group.rpt
report_timing -max_paths 100 -delay_type max -file $rpt_dir/timing_max_100.rpt
report_timing -from [get_clocks clk_fpga_0] -max_paths 100 -file $rpt_dir/timing_clk_fpga_0.rpt
report_utilization -file $rpt_dir/utilization.rpt
report_utilization -hierarchical -file $rpt_dir/utilization_hierarchical.rpt
report_high_fanout_nets -file $rpt_dir/high_fanout_nets.rpt
report_control_sets -file $rpt_dir/control_sets.rpt
report_design_analysis -timing -file $rpt_dir/design_analysis_timing.rpt

close_design

if {![file exists ./bitstreams/]} { file mkdir ./bitstreams/ }
if {[file exists ./audio_lab/audio_lab.runs/impl_1/block_design_wrapper.bit]} {
    file copy -force ./audio_lab/audio_lab.runs/impl_1/block_design_wrapper.bit ./bitstreams/audio_lab.bit
    file copy -force ./audio_lab/audio_lab.srcs/sources_1/bd/block_design/hw_handoff/block_design.hwh ./bitstreams/audio_lab.hwh
    puts "BIT/HWH copied to ./bitstreams/"
} else {
    puts "ERROR: impl_1 did not produce block_design_wrapper.bit"
}
