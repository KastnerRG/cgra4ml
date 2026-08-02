# Pre Routing
# -----------
krg_start_stage "6_pre_route"

# Get rid of the M2 stripe blockages that are no longer needed and cause annoying DRC violations
delete_route_blockages -type routes


set_db route_design_with_timing_driven                  true
set_db route_design_detail_use_multi_cut_via_effort     medium
if {$timing_lib_type == "ccs_ocv"} {
    set_db route_design_with_si_driven                  true
    set_db delaycal_enable_si                           true
} else {
    set_db route_design_with_si_driven                  false
    set_db delaycal_enable_si                           false
}


set_db opt_new_inst_prefix "route_opt_inst_"
set_db opt_new_net_prefix "route_opt_net_"
route_opt_design

# Reporting & Save
if {$timing_lib_type == "ccs_ocv"} {
    set_db timing_analysis_engine             statistical
}
krg_create_stage_reports -write_db yes -check_drc yes -report_timing yes -check_connectivity yes -report_hold yes
if {$timing_lib_type == "ccs_ocv"} {
    set_db timing_analysis_engine             static
}

# Post Route Optimization
# -----------------------
krg_start_stage "7_post_route_opt"
opt_design -post_route -setup -hold

set_db route_design_with_timing_driven                  false
set_db route_design_detail_post_route_spread_wire       true
set_db route_design_detail_use_multi_cut_via_effort     high
if {$timing_lib_type == "ccs_ocv"} {
    set_db route_design_with_si_driven                  false
    set_db delaycal_enable_si                           false
}
route_design -wire_opt
route_design -via_opt
set_db route_design_detail_post_route_spread_wire       false
set_db route_design_with_timing_driven                  true
if {$timing_lib_type == "ccs_ocv"} {
    set_db route_design_with_si_driven                  true
    set_db delaycal_enable_si                           true
}

# Add Filler Cells with DRC errors
add_fillers -base_cells $tech(FILL_CELLS) -prefix $tech(FILL_CELL_PREFIX) \
            -check_different_cells true -check_drc -check_min_hole true \
            -check_via_enclosure true -fill_gap
# Clean DRC errors
add_fillers -base_cells $tech(FILL_CELLS) -prefix $tech(FILL_CELL_PREFIX) \
            -check_different_cells true -check_drc -check_min_hole true \
            -check_via_enclosure true -fill_gap -fix_drc
route_eco -fix_drc

# Reporting & Save
if {$timing_lib_type == "ccs_ocv"} {
    set_db timing_analysis_engine             statistical
}
krg_create_stage_reports -write_db yes -check_drc yes -report_timing yes -check_connectivity yes -report_hold yes
if {$timing_lib_type == "ccs_ocv"} {
    set_db timing_analysis_engine             static
}

# Stamp the stage for runtime and memory information
# --------------------------------------------------
time_info -table $runtype -stamp "init_design"

# Screenshot of the floorplan
gui_fit
write_to_gif $design(pnr_reports)/screenshots/4_Post_Route.gif

# Screenshot of the floorplan
gui_fit
write_to_gif $design(pnr_reports)/screenshots/1_Floorplan.gif
write_db