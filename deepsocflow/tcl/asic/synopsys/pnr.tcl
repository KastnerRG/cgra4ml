
#--------- Set Configurations
set_host_options -max_cores 8
	
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

# Set Tie High and Tie Low cells
set tech(TIE_PREFIX)        TIEOFF_
set tech(TIE_HIGH_CELL)     TIEHI_X1N_AH240TS_C11
set tech(TIE_LOW_CELL)      TIELO_X1N_AH240TS_C11

# Set End Cap Cells, Fill Tie Cells
set tech(END_CAP_PREFIX)    ENDCAP_
set tech(END_CAP_CELL)      ENDCAPA5_AH240TS_C11 
set tech(FILL_TIE_PREFIX)   FILLTIE_ 
set tech(FILL_TIE_CELL)     ""

# Set Fill Cells
set tech(FILL_CELL_PREFIX)  FILLER_CELL_
set tech(FILL_CELLS)       "FILLSGCAP3_AH240TS_C11 FILLSGCAP4_AH240TS_C11 FILLSGCAP5_AH240TS_C11 FILLSGCAP6_AH240TS_C11 FILLSGCAP7_AH240TS_C11 FILLSGCAP8_AH240TS_C11 FILLSGCAP16_AH240TS_C11 FILLSGCAP32_AH240TS_C11 FILLSGCAP64_AH240TS_C11 FILLSGCAP128_AH240TS_C11"
# Set Antenna Cell
set tech(ANTENNA_CELL)      ANTENNA3_AH240TS_C11

# Set Clock Tree Specs 
set tech(CCOPT_DRIVING_PIN) {BUF_X1N_AH240TS_C11/A BUF_X1N_AH240TS_C11/Y}
# set tech(CLOCK_BUFFERS)     BUF_X1N_AH240TS_C11
# set tech(CLOKC_GATES)       
# set tech(CLOCK_INVERTERS)   
# set tech(CLOCK_LOGIC)       MXGL2
# set tech(CLOCK_DELAYS)      DLYCLK8

# Set Slew Rates from Documentation
# set tech(CLOCK_SLEW)        0.00108
# set tech(DATA_SLEW)         0.00108
# set tech(INPUT_SLEW)        0.00108

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
set design(CLOCK_MAX_TRANSITION)  0.250 ; # In ns for SDC (will appear in ps for get_db)
set design(CLOCK_MAX_FANOUT)      20
set design(CLOCK_MAX_CAPACITANCE) 0.100 ; # In pF for SDC (will appear in fF for get_db)

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
set typ_tlu_file "$tlupath/typical.tluplus"
set prs_map_file "$tlupath/tluplus.map"

read_parasitic_tech -name typical -tlup $typ_tlu_file -layermap $prs_map_file
read_parasitic_tech -name rcbest  -tlup $min_tlu_file -layermap $prs_map_file
read_parasitic_tech -name rcworst -tlup $max_tlu_file -layermap $prs_map_file


set_technology -node 7

read_verilog -library tsmc65lp -design dnn_engine -top dnn_engine ../asic/outputs/$design_name.out.v
link_block

initialize_floorplan -side_length {1000 600} -core_offset {30}

create_power_domain TOP
create_supply_port VDD
create_supply_net VDD -domain TOP
connect_supply_net VDD -port VDD

create_supply_port VSS
create_supply_net VSS -domain TOP
connect_supply_net VSS -port VSS

source ../../deepsocflow/tcl/asic/synopsys/pinPlacement.tcl

set_domain_supply_net TOP -primary_power_net VDD -primary_ground_net VSS

set_parasitic_parameters -early_spec rcbest -early_temperature -40 -late_spec rcworst -late_temperature 125
current_corner default
set_operating_conditions -max_library sc12mcpp140z_cln28ht_base_svt_c35_ffg_cbestt_min_0p99v_m40c -max ffg_cbestt_min_0p99v_m40c -min_library sc12mcpp140z_cln28ht_base_svt_c35_ssg_cworstt_max_0p81v_125c -min ssg_cworstt_max_0p81v_125c
current_corner default

set_voltage 1.00 -min 0.90 -corner [current_corner] -object_list [get_supply_nets VDD]
set_voltage 0.00 -corner [current_corner] -object_list [get_supply_nets VSS]

set_app_options -list {opt.timing.effort {ultra}}
set_app_options -list {clock_opt.place.effort {high}}
set_app_options -list {place_opt.flow.clock_aware_placement {true}}
set_app_options -list {place_opt.final_place.effort {high}}
set_app_options -name cts.compile.enable_global_route -value true
set_app_options -name clock_opt.flow.enable_ccd -value true
set_app_options -name ccd.hold_control_effort -value high
set_app_options -name clock_opt.flow.optimize_ndr -value true
set_app_options -name route.global.effort_level -value high
set_app_options -name place.coarse.congestion_driven_max_util -value 0.5
set_app_options -name compile.final_place.placement_congestion_effort -value high
set_app_options -name compile.initial_opto.placement_congestion_effort -value high


read_sdc ../asic/outputs/$design_name.out.sdc
update_timing

source ../../deepsocflow/tcl/asic/synopsys/placeMemories.tcl

source ../../deepsocflow/tcl/asic/synopsys/powerPlan.tcl

########################################################################
## write_floorplan and write_def
########################################################################
write_floorplan \
  -format icc2 \
  -def_version 5.8 \
  -force \
  -output ${BLOCK_OUTPUT_DIR}/${block_name}_write_floorplan \
  -read_def_options {-add_def_only_objects {all} -skip_pg_net_connections} \
  -exclude {scan_chains fills pg_metal_fills routing_rules} \
  -net_types {power ground} \
  -include_physical_status {fixed locked}

create_placement
legalize_placement -cells [get_cells *]
add_tie_cells -tie_high_lib_cells [get_lib_cells {cln28ht/TIEHI_X1M_A7PP140ZTS_C30}] -tie_low_lib_cells [get_lib_cells {cln28ht/TIELO_X1M_A7PP140ZTS_C30}]

save_lib -all

report_timing -max_path 1000 -nworst 1000 > ../asic/reports/${design_name}.pre_opt_placement.timing.rpt
check_mv_design > ../asic/reports/check_mv_design.log

report_utilization > ../asic/reports/${design_name}.pre_opt_placement.utilization.rpt

place_opt
save_lib -all

update_timing -full
report_timing -max_path 1000 -nworst 1000 > ../asic/reports/${design_name}.post_opt_placement.timing.rpt

check_clock_trees -clocks aclk
synthesize_clock_trees -clocks aclk
clock_opt
update_timing -full
report_timing -max_path 1000 -nworst 1000 > ../asic/reports/${design_name}.post_clock_opt_placement.timing.rpt
save_lib -all

route_auto
add_redundant_vias
update_timing -full
report_utilization > ../asic/reports/${design_name}.pre_route.utilization.rpt
optimize_routes -max_detail_route_iterations 200
route_opt
route_detail -incremental true -initial_drc_from_input true

report_timing -max_path 1000 -nworst 1000 > ../asic/reports/${design_name}.post_route.timing.rpt
report_utilization > ../asic/reports/${design_name}.post_route.utilization.rpt
report_power > ../asic/reports/${design_name}.post_route.power.rpt
save_lib -all

check_routes -report_all_open_nets true 

check_design -checks timing > ../asic/reports/check_timing.log

write_verilog -include {all} ../asic/outputs/${design_name}.pnr.v

write_sdf ../asic/outputs/${design_name}_typical.sdf

