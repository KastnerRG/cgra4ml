
set design_name dnn_engine

set_app_var link_library [list ../asic/pdk/tsmc28/db/sc12mcpp140z_cln28ht_base_svt_c35_ffg_cbestt_min_0p99v_m40c.db ../asic/pdk/tsmc28/db/sc12mcpp140z_cln28ht_base_svt_c35_ssg_cworstt_max_0p81v_125c.db ../asic/srams/sram_weights/sram_weights_ffg_cbestt_1p05v_1p05v_125c.db ../asic/srams/sram_edges/sram_edges_ffg_cbestt_1p05v_1p05v_125c.db]
create_lib tsmc65lp -technology ../asic/pdk/tsmc28/tf/sc12mcpp140z_tech.tf -ref_libs [list ../asic/pdk/tsmc28/lef/sc12mcpp140z_cln28ht_base_svt_c35.lef ../asic/srams/sram_weights/sram_weights.lef ../asic/srams/sram_edges/sram_edges.lef]

read_parasitic_tech -name typical -tlup ../asic/pdk/tsmc28/tluplus/typical.tluplus -layermap ../asic/pdk/tsmc28/tluplus/tluplus.map
read_parasitic_tech -name rcbest -tlup ../asic/pdk/tsmc28/tluplus/rcbest.tluplus -layermap ../asic/pdk/tsmc28/tluplus/tluplus.map
read_parasitic_tech -name rcworst -tlup ../asic/pdk/tsmc28/tluplus/rcworst.tluplus -layermap ../asic/pdk/tsmc28/tluplus/tluplus.map

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

source ../../deepsocflow/tcl/asic/pinPlacement.tcl

set_domain_supply_net TOP -primary_power_net VDD -primary_ground_net VSS

set_parasitic_parameters -early_spec rcbest -early_temperature -40 -late_spec rcworst -late_temperature 125
current_corner default
set_operating_conditions -max_library sc12mcpp140z_cln28ht_base_svt_c35_ffg_cbestt_min_0p99v_m40c -max ffg_cbestt_min_0p99v_m40c -min_library sc12mcpp140z_cln28ht_base_svt_c35_ssg_cworstt_max_0p81v_125c -min ssg_cworstt_max_0p81v_125c
current_corner default

set_parasitic_parameters -early_spec rcbest -early_temperature -40 -late_spec rcworst -late_temperature 125
current_corner default
set_operating_conditions -max_library sc12mcpp140z_cln28ht_base_svt_c35_ffg_cbestt_min_0p99v_m40c -max ffg_cbestt_min_0p99v_m40c -min_library sc12mcpp140z_cln28ht_base_svt_c35_ssg_cworstt_max_0p81v_125c -min ssg_cworstt_max_0p81v_125c
current_mode default

set_voltage 0.99 -min 0.81 -corner [current_corner] -object_list [get_supply_nets VDD]
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


read_sdc ../asic/outputs/$design_name.out.sdc
update_timing

source ../../deepsocflow/tcl/asic/placeMemories.tcl

source ../../deepsocflow/tcl/asic/powerPlan.tcl

create_placement
legalize_placement -cells [get_cells *]

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
update_timing -full
optimize_routes -max_detail_route_iterations 200
route_opt

report_timing -max_path 1000 -nworst 1000 > ../asic/reports/${design_name}.post_route.timing.rpt
report_utilization > ../asic/reports/${design_name}.post_route.utilization.rpt
report_power > ../asic/reports/${design_name}.post_route.power.rpt
save_lib -all

check_routes -report_all_open_nets true 

check_design -checks timing > ../asic/reports/check_timing.log

write_verilog -include {all} ../asic/outputs/${design_name}.pnr.v

write_sdf ../asic/outputs/${design_name}_typical.sdf

