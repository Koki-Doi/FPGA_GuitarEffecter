# Run one additional implementation strategy from an existing synthesized project.
#
# Environment:
#   AUDIO_LAB_PROJECT_XPR     required path to the base .xpr
#   AUDIO_LAB_STRATEGY_TAG    report/run tag
#   AUDIO_LAB_IMPL_STRATEGY   Vivado implementation strategy; defaults to Vivado Implementation Defaults
#   AUDIO_LAB_PHYS_OPT        1 to enable phys_opt_design step
#   AUDIO_LAB_PHYS_OPT_DIRECTIVE optional phys_opt_design directive
#   AUDIO_LAB_TO_STEP         implementation step to launch to; defaults to route_design
#   AUDIO_LAB_REPORT_ROOT     report root; defaults to hw/Pynq-Z2/timing_reports/comp_cab_v2

proc env_or {name default_value} {
    if {[info exists ::env($name)] && $::env($name) ne ""} {
        return $::env($name)
    }
    return $default_value
}

if {![info exists ::env(AUDIO_LAB_PROJECT_XPR)] || $::env(AUDIO_LAB_PROJECT_XPR) eq ""} {
    error "AUDIO_LAB_PROJECT_XPR is required"
}

set project_xpr [file normalize $::env(AUDIO_LAB_PROJECT_XPR)]
set repo_root [file normalize [env_or AUDIO_LAB_REPO_ROOT [pwd]]]
set origin_dir [file join $repo_root hw Pynq-Z2]
set strategy_tag [env_or AUDIO_LAB_STRATEGY_TAG impl_variant]
set report_root [file normalize [env_or AUDIO_LAB_REPORT_ROOT [file join $origin_dir timing_reports comp_cab_v2]]]
set rpt_dir [file join $report_root $strategy_tag]
set run_name "impl_${strategy_tag}"
set impl_strategy [env_or AUDIO_LAB_IMPL_STRATEGY "Vivado Implementation Defaults"]
set to_step [env_or AUDIO_LAB_TO_STEP route_design]

file mkdir $rpt_dir
open_project $project_xpr

set existing [get_runs -quiet $run_name]
if {$existing ne ""} {
    delete_run $run_name
}

create_run $run_name -parent_run synth_1 -flow {Vivado Implementation 2019} -strategy $impl_strategy

if {[env_or AUDIO_LAB_PHYS_OPT 0] eq "1"} {
    set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs $run_name]
    set phys_opt_directive [env_or AUDIO_LAB_PHYS_OPT_DIRECTIVE ""]
    if {$phys_opt_directive ne ""} {
        set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE $phys_opt_directive [get_runs $run_name]
    }
}

puts "=== strategy_tag: $strategy_tag ==="
puts "=== run_name: $run_name ==="
puts "=== impl strategy: [get_property strategy [get_runs $run_name]] ==="
puts "=== to step: $to_step ==="
puts "=== phys_opt enabled: [get_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED [get_runs $run_name]] ==="
puts "=== phys_opt directive: [get_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE [get_runs $run_name]] ==="

launch_runs $run_name -to_step $to_step -jobs 2
wait_on_run $run_name
puts "=== $run_name status: [get_property STATUS [get_runs $run_name]] ==="

open_run $run_name

report_timing_summary -file [file join $rpt_dir timing_summary.rpt]
report_timing -max_paths 100 -sort_by group -file [file join $rpt_dir timing_by_group.rpt]
report_timing -max_paths 100 -delay_type max -file [file join $rpt_dir timing_max_100.rpt]
report_timing -from [get_clocks clk_fpga_0] -max_paths 100 -file [file join $rpt_dir timing_clk_fpga_0.rpt]
report_utilization -file [file join $rpt_dir utilization.rpt]
report_utilization -hierarchical -file [file join $rpt_dir utilization_hierarchical.rpt]
report_high_fanout_nets -file [file join $rpt_dir high_fanout_nets.rpt]
report_control_sets -file [file join $rpt_dir control_sets.rpt]
report_design_analysis -timing -file [file join $rpt_dir design_analysis_timing.rpt]

close_design
close_project
