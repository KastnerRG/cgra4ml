#--------- Set TCL parameters
source config_hw.tcl

#--------- Set PATH parameters
set rtlPath "../../deepsocflow/rtl"
set reportPath "../asic/reports"
set outputPath "../asic/outputs"
set libraryPath "../asic/pdk/tsmc65lp/db"
set milkywaytechPath "../asic/pdk/tsmc65lp/milkyway"
set milkywaylibPath "../asic/pdk/tsmc65lp/milkyway/FRAM"
set rclibPath "../asic/pdk/tsmc65lp/tluplus"
set sramLibPath "../asic/srams"
set search_path [concat $search_path $libraryPath $sramLibPath/sram_edges $sramLibPath/sram_weights] 
set search_path [concat $search_path $milkywaytechPath $milkywaylibPath $rclibPath]
set search_path [concat $search_path $rtlPath]

#--------- Set Timing and Other Parameters
set top_module dnn_engine
set clock_cycle [expr 1000/$FREQ]
set io_delay [expr $clock_cycle/5]

#--------- Set Configurations
set_host_options -max_cores 4

#--------- Set Libraries
set target_library "sc12_cln65lp_base_rvt_ss_typical_max_1p08v_125c.db sram_edges_ss_1p08v_1p08v_125c.db sram_weights_ss_1p08v_1p08v_125c.db"
set link_library [concat "* $target_library"]
#set min_library "sc12_cln65lp_base_rvt_ss_typical_max_1p08v_125c.db" -min_version "sc12_cln65lp_base_rvt_ff_typical_min_1p10v_m40c.db"

#set mw_library ${top_module}_milkyway65lp
#create_mw_lib -technology "../asic/pdk/tsmc65lp/tf/sc12_tech.tf" -mw_reference_library "../asic/pdk/tsmc65lp/milkyway/" $mw_library
#open_mw_lib $mw_library
#check_library

#set min_tlu_file "../asic/pdk/tsmc65lp/tluplus/rcbest.tluplus" 
#set max_tlu_file "../asic/pdk/tsmc65lp/tluplus/rcworst.tluplus"
#set prs_map_file "../asic/pdk/tsmc65lp/tluplus/tluplus.map"
#set_tlu_plus_files -max_tluplus $max_tlu_file -min_tluplus $min_tlu_file -tech2itf_map $prs_map_file

#link_physical_library

#Compiler directives Analysis
set compile_no_new_cells_at_top_level false
set hdlin_auto_save_templates false
set wire_load_mode enclosed
set timing_use_enhanced_capacitance_modeling true
set verilogout_single_bit false

define_design_lib WORK -path .template
current_design $top_module
# read RTL
analyze -format sverilog -lib WORK [glob ../../deepsocflow/rtl/defines.svh]
analyze -format sverilog -lib WORK [glob ../asic/srams/ram_asic.sv]

analyze -format verilog -lib WORK [glob ../../deepsocflow/rtl/ext/*.v]
analyze -format sverilog -lib WORK [glob ../../deepsocflow/rtl/ext/*.sv]
analyze -format sverilog -lib WORK [glob ../../deepsocflow/rtl/*.sv]
analyze -format verilog -lib WORK [glob ../../deepsocflow/rtl/*.v]

elaborate $top_module > ../asic/log/1.${top_module}_${FREQ}MHz_elaborate.log
current_design $top_module
check_design > ../asic/log/2.${top_module}_${FREQ}MHz_check_design.rpt

# Link Design
link -force
uniquify

# SDC Constraints
create_clock -name aclk -period $clock_cycle [get_ports aclk]
set_false_path -from [get_ports "aresetn"]
set_input_delay -clock [get_clocks aclk] -add_delay -max $io_delay [all_inputs]
set_output_delay -clock [get_clocks aclk] -add_delay -max $io_delay [all_outputs]

#Compiler directives Synthesis
set compile_effort   "high"
set_app_var ungroup_keep_original_design true
set_register_merging [get_designs $top_module] false
set compile_seqmap_propagate_constants false
set compile_seqmap_propagate_high_effort false

# More constraints and setup before compile
#foreach_in_collection design [ get_designs "*" ] {
#	current_design $design
#	set_fix_multiple_port_nets -all
#}
current_design $top_module

# Compile
#compile -ungroup_all -map_effort high -incremental_mapping -area_effort high
compile_ultra -retime
compile_ultra -no_seq_output_inversion

ungroup -all -flatten

current_design $top_module
check_design > ../asic/log/3.${top_module}_${FREQ}MHz_check_design.rpt
report_constraint -all_violators > ../asic/reports/${top_module}_${FREQ}MHz_constraints_violations.rpt

# Write Out Design and Constraints - Hierarchical
current_design $top_module
change_names -rules verilog -hierarchy
write -format verilog -hier -output [format "../asic/outputs/%s%s" $top_module .out.v]
write_sdc ../asic/outputs/${top_module}.out.sdc
write_sdf ../asic/outputs/${top_module}.out.sdf

# Write Reports
redirect [format "%s%s%s%s%s" ../asic/reports/ $top_module _$FREQ MHz _ports.rpt] { report_port }
redirect [format "%s%s%s%s%s" ../asic/reports/ $top_module _$FREQ MHz _cells.rpt] { report_cell }
redirect [format "%s%s%s%s%s" ../asic/reports/ $top_module _$FREQ MHz _area.rpt] { report_area }
redirect -append [format "%s%s%s%s%s" ../asic/reports/ $top_module _$FREQ MHz _area_reference.rpt] { report_reference }
redirect [format "%s%s%s%s%s" ../asic/reports/ $top_module _$FREQ MHz _power.rpt] { report_power }
redirect [format "%s%s%s%s%s" ../asic/reports/ $top_module _$FREQ MHz _timing.rpt] \
  { report_timing -path full -max_paths 100 -nets -transition_time -capacitance -significant_digits 3 -nosplit}


set unmapped_designs [get_designs -filter "is_unmapped == true" $top_module]
if {  [sizeof_collection $unmapped_designs] != 0 } {
	echo "****************************************************"
	echo "* ERROR!!!! Compile finished with unmapped logic.  *"
	echo "****************************************************"
}

