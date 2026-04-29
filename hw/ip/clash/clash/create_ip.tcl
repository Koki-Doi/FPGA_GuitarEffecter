set_param board.repoPaths [list "$::env(HOME)/vivado/boards/board_files"]
# Config
set ip_prj_name  "tmp_vivado_ip"
set ip_version   1
#set src_dirs     ["./vhdl/Filters" "./vhdl/ADAU1761"]
set prj_name     "tmp_vivado"

set src_dir [lindex $argv 0]

# Create dummy project
create_project -f ${prj_name} ./${prj_name} -part xc7z020clg400-1 
set _bp_list [get_board_parts -quiet *pynq-z2*]
if {[llength $_bp_list] > 0} {
  set _bp [lindex $_bp_list 0]
  puts "INFO: Using board_part: $_bp"
  set_property board_part $_bp [current_project]
} else {
  puts "WARN: No PYNQ-Z2 board_part detected; using -part only."
}
set_property target_language VHDL [current_project]

# Infer IP core
ipx::infer_core -vendor cramsay.co.uk -library cramsay -taxonomy /UserIP ${src_dir}
ipx::edit_ip_in_project -upgrade true -name ${ip_prj_name} -directory ./${ip_prj_name} ${src_dir}/component.xml
update_compile_order -fileset sources_1
ipx::current_core ${src_dir}/component.xml
set_property core_revision ${ip_version} [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::move_temp_component_back -component [ipx::current_core]
close_project -delete
