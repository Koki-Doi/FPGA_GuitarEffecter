# Build the Comp+Cab v2 timing candidate with one implementation strategy.
#
# Environment:
#   AUDIO_LAB_REPO_ROOT       repository root; defaults to current directory
#   AUDIO_LAB_STRATEGY_TAG    report/build tag, e.g. default
#   AUDIO_LAB_IMPL_STRATEGY   optional Vivado implementation strategy
#   AUDIO_LAB_PHYS_OPT        1 to enable phys_opt_design step
#   AUDIO_LAB_PHYS_OPT_DIRECTIVE optional phys_opt_design directive
#   AUDIO_LAB_BOARD_REPO_PATHS optional ':' separated Vivado board repo paths
#   AUDIO_LAB_BUILD_ROOT      generated project root; defaults to /tmp
#   AUDIO_LAB_REPORT_ROOT     report root; defaults to hw/Pynq-Z2/timing_reports/comp_cab_v2

proc env_or {name default_value} {
    if {[info exists ::env($name)] && $::env($name) ne ""} {
        return $::env($name)
    }
    return $default_value
}

set repo_root [file normalize [env_or AUDIO_LAB_REPO_ROOT [pwd]]]
set origin_dir [file join $repo_root hw Pynq-Z2]
set iprepo_dir [file join $repo_root hw ip]
set strategy_tag [env_or AUDIO_LAB_STRATEGY_TAG default]
set build_root [file normalize [env_or AUDIO_LAB_BUILD_ROOT /tmp/audio_lab_timing_strategy_comp_cab_v2]]
set report_root [file normalize [env_or AUDIO_LAB_REPORT_ROOT [file join $origin_dir timing_reports comp_cab_v2]]]
set proj_name "audio_lab_${strategy_tag}"
set proj_dir [file join $build_root $strategy_tag $proj_name]
set rpt_dir [file join $report_root $strategy_tag]

file delete -force [file join $build_root $strategy_tag]
file mkdir $rpt_dir

set board_repo_paths [env_or AUDIO_LAB_BOARD_REPO_PATHS ""]
if {$board_repo_paths ne ""} {
    set_param board.repoPaths [split $board_repo_paths ":"]
}

set digilent_vivado_library [env_or DIGILENT_VIVADO_LIBRARY ""]
if {$digilent_vivado_library eq ""} {
    error "DIGILENT_VIVADO_LIBRARY must point to a Digilent vivado-library checkout."
}
set digilent_ip_repo "$digilent_vivado_library/ip"
if {![file isdirectory $digilent_ip_repo]} {
    error "Digilent vivado-library not found at $digilent_ip_repo. Set DIGILENT_VIVADO_LIBRARY."
}
if {![file exists "$digilent_ip_repo/rgb2dvi/component.xml"]} {
    error "Digilent rgb2dvi IP component.xml missing under $digilent_ip_repo."
}

create_project $proj_name $proj_dir -part xc7z020clg400-1
set_property board_part tul.com.tw:pynq-z2:part0:1.0 [current_project]
set_property ip_repo_paths [list $iprepo_dir $digilent_ip_repo] [current_project]
set_property target_language VHDL [current_project]
update_ip_catalog

add_files -fileset constrs_1 -norecurse [file join $origin_dir audio_lab.xdc]
add_files -fileset constrs_1 -norecurse [file join $origin_dir audio_lab_pmod_i2s2.xdc]
add_files -norecurse [file join $repo_root hw ip encoder_input src axi_encoder_input.v]
add_files -norecurse [file join $repo_root hw ip pmod_i2s2 src pmod_i2s2_master.v]
add_files -norecurse [file join $repo_root hw ip pmod_i2s2 src axi_pmod_i2s2_status.v]
update_compile_order -fileset sources_1

source [file join $origin_dir block_design.tcl]
source [file join $origin_dir hdmi_integration.tcl]
source [file join $origin_dir encoder_integration.tcl]
source [file join $origin_dir pmod_i2s2_integration.tcl]

make_wrapper -files [get_files [file join $proj_dir ${proj_name}.srcs sources_1 bd block_design block_design.bd]] -top
add_files -norecurse [file join $proj_dir ${proj_name}.srcs sources_1 bd block_design hdl block_design_wrapper.vhd]
update_compile_order -fileset sources_1

generate_target {synthesis} \
    [get_files [file join $proj_dir ${proj_name}.srcs sources_1 bd block_design block_design.bd]]

set impl_strategy [env_or AUDIO_LAB_IMPL_STRATEGY ""]
if {$impl_strategy ne ""} {
    set_property strategy $impl_strategy [get_runs impl_1]
}

if {[env_or AUDIO_LAB_PHYS_OPT 0] eq "1"} {
    set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
    set phys_opt_directive [env_or AUDIO_LAB_PHYS_OPT_DIRECTIVE ""]
    if {$phys_opt_directive ne ""} {
        set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE $phys_opt_directive [get_runs impl_1]
    }
}

puts "=== strategy_tag: $strategy_tag ==="
puts "=== impl strategy: [get_property strategy [get_runs impl_1]] ==="
puts "=== phys_opt enabled: [get_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED [get_runs impl_1]] ==="
puts "=== phys_opt directive: [get_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE [get_runs impl_1]] ==="

launch_runs synth_1 -jobs 2
wait_on_run synth_1
puts "=== synth_1 status: [get_property STATUS [get_runs synth_1]] ==="

launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
puts "=== impl_1 status: [get_property STATUS [get_runs impl_1]] ==="

open_run impl_1

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
