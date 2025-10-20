
#--------- Set Configurations
set_host_options -max_cores 8

#--------- Set TCL parameters
source config_hw.tcl
	
set metal_stack 1p13m_1x1xa1ya5y2yy2z
set ndm_design_library tsmc_7_cgra4ml.dlib

#--------- Set PATH parameters
set rtlPath 	"../../deepsocflow/rtl"
set reportPath 	"../asic/reports"
set outputPath 	"../asic/outputs"
set libraryPath "../asic/pdk/tsmc7/db"
set ndmrefPath 	"../asic/pdk/tsmc7/ndm"
set ndmtfPath 	"../asic/pdk/tsmc7/ndm/$metal_stack"
set tlupath		"../asic/pdk/tsmc7/synopsys_tluplus/$metal_stack"
set sramLibPath "../asic/srams"
set search_path [concat $search_path $libraryPath $sramLibPath/sram_weights $sramLibPath/sram_edges] 
set search_path [concat $search_path $rtlPath]

#--------- Set Timing and Other Parameters
set top_module dnn_engine

# Set Input and Output Capacitance Values from Std Cells
set tech(SDC_LOAD_PIN)      BUF_X1N_AH240TS_C11/A
set tech(SDC_DRIVING_CELL)  BUF_X1N_AH240TS_C11

######  Clocks
set design(MULTI_CLOCK_DESIGN) "no"

set design(CLK_NAME)    "CLK"
    set design(clock_list)  [list $design(CLK_NAME)]
set design(CLK_PORT)    "aclk"
    set design(clock_port_list) [list $design(CLK_PORT)]
set design(CLK_PERIOD)  2.0
    set design(clock_period_list) [list $design(CLK_PERIOD)]

######  Reset
set design(RST_PORT)    "aresetn"

# IO Constraints
set design(INPUT_DELAY)     [expr $design(CLK_PERIOD)/4.0]
set design(OUTPUT_DELAY)     [expr $design(CLK_PERIOD)/4.0]
set design(INPUT_TRANSITION)     [expr $design(CLK_PERIOD)/5.0] ; # Maximum Transition Time according Liberty Data sheet = min(20% of Clock, Max transition characterized on Table)

# Clock Constraints
set design(CLOCK_UNCERTAINTY)     0.125 ; # In ns for SDC (will appear in ps for get_db)

#--------- Set Libraries
set target_library "sch240mc_cln07ff41001_base_svt_c11_ssgnp_cworstccworstt_max_1p00v_125c.db"
set link_library "* $target_library  sram_edges_ssgnp_cworstccworstt_0p90v_0p90v_125c.db sram_weights_ssgnp_cworstccworstt_0p90v_0p90v_125c.db"

if {![file isdirectory $ndm_design_library]} {
	create_lib -ref_libs [list $ndmrefPath/sch240mc_cln07ff41001_base_svt_c11.ndm sram_weights.lef sram_edges.lef] -technology $ndmtfPath/sch240mc_tech.tf $ndm_design_library
} else {
	open_lib $ndm_design_library
}

set min_tlu_file "$tlupath/rcbest.tluplus" 
set max_tlu_file "$tlupath/rcworst.tluplus"
set prs_map_file "$tlupath/tluplus.map"
set_tlu_plus_files -max_tluplus $max_tlu_file -min_tluplus $min_tlu_file -tech2itf_map $prs_map_file

set enable_phys_lib_during_elab true

define_design_lib WORK -path .template

set_aspect_ratio 0.75
set_utilization 0.5
//das
# read RTL
analyze -format sverilog -lib WORK [glob ../../deepsocflow/rtl/defines.svh]

analyze -format verilog  -lib WORK [glob ../../deepsocflow/rtl/ext/*.v]
analyze -format sverilog -lib WORK [glob ../../deepsocflow/rtl/ext/*.sv]
analyze -format sverilog -lib WORK [glob ../../deepsocflow/rtl/*.sv]
analyze -format verilog  -lib -define TSMC7_SRAM WORK [glob ../../deepsocflow/rtl/*.v]

elaborate $top_module > ../asic/log/1.${top_module}_${FREQ}MHz_elaborate.log
current_design $top_module
check_design > ../asic/log/2.${top_module}_${FREQ}MHz_check_design.rpt

# Link Design
link
uniquify

#################################
#       Clock Constraints       #
#################################
# Create Clocks
create_clock -period $design(clock_period_list) -name $design(clock_list) [get_ports $design(clock_port_list)]
set_clock_uncertainty $design(CLOCK_UNCERTAINTY) $design(clock_list)

#################################
#       IO Constraints          #
#################################
set_input_delay -clock $design(CLK_NAME) $design(INPUT_DELAY) \
        [remove_from_collection [all_inputs] [list $design(CLK_PORT) $design(RST_PORT)]]
set_output_delay -clock $design(CLK_NAME) $design(OUTPUT_DELAY) [all_outputs]
set tech(SDC_LOAD_VALUE) [load_of $tech(SDC_LOAD_PIN)]
set_load                $tech(SDC_LOAD_VALUE)                      [all_outputs]
set_input_transition    $design(INPUT_TRANSITION)                  [all_inputs]
set_driving_cell        -lib_cell $tech(SDC_DRIVING_CELL)          [all_inputs]

#Compiler directives Synthesis
set compile_effort   "high"
set_app_var ungroup_keep_original_design true
set_app_var compile_enhanced_tns_optimization true
set_app_var compile_enhanced_tns_optimization_effort_level "high"
set_app_var compile_prefer_mux true

# Paths Groups
group_path -name INPUTS -from [all_inputs]
group_path -name OUTPUTS -to [all_outputs]
group_path -name COMBO -from [all_inputs] -to [all_outputs]

current_design $top_module

# Compile

compile_ultra -retime -spg -no_seq_output_inversion
compile_ultra -incremental

optimize_netlist -area 

ungroup -all -flatten

current_design $top_module
check_design > ../asic/log/3.${top_module}_${FREQ}MHz_check_design.rpt
report_constraint -all_violators > ../asic/reports/${top_module}_${FREQ}MHz_constraints_violations.rpt

# Write Out Design and Constraints - Hierarchical
current_design $top_module
define_name_rules verilog -preserve_struct_ports
change_names -rules verilog -hierarchy
write -format verilog -hier -output [format "../asic/outputs/%s%s" $top_module .out.v]
write_sdc ../asic/outputs/${top_module}.out.sdc
write_sdf ../asic/outputs/${top_module}.out.sdf
write_icc2_files -out cgra4ml_icc2_start

# Write Reports
update_timing
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

