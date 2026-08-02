# Placement Stage
# ---------------
krg_start_stage "placement" yes

# Routing blockages       
# -----------------
proc uom_add_m2_stripe_blockage {} {
    global design m2_route_blockage_list
    # Add M2 routing blockages around vertical power stripes to prevent M2 routing DRCs near them
    deselect_routes
    set m1_name [get_db [lindex [get_db layers] 1] .name]
    set m2_name [get_db [lindex [get_db layers] 2] .name]
    set m7_name [get_db [lindex [get_db layers] 7] .name]
    set m2_route_blockage_list ""
    select_routes -shapes stripe -layer $m7_name -nets $design(M7_stripes_nets)
    foreach stripe [get_db selected] {
        lappend m2_route_blockage_list "M2_pwr_stripe_route_blk"
        create_route_blockage -name M2_pwr_stripe_route_blk \
        -layer "$m1_name $m2_name" \
        -spacing [expr 2*[get_db [lindex [get_db layers] 1] .min_spacing]] \
        -area [get_db $stripe .rect]
    }
    deselect_routes

# Add M2 routing blockages around vertical power stripes to prevent M2 routing DRCs near them
krg_add_m2_stripe_blockage

set_db place_global_cong_effort auto
set_db opt_new_inst_prefix "place_opt_inst_"
set_db opt_new_net_prefix  "place_opt_net_"
place_opt_design -report_dir "$design(reports_dir)/pnr/3_placement/place_opt_design"

# Add Tie Cells
add_tieoffs -lib_cell "$tech(TIE_HIGH_CELL) $tech(TIE_LOW_CELL)" -prefix $tech(TIE_PREFIX)

# Fix DRV
opt_design -pre_cts -drv 

# Reporting & Save
check_place > $design(pnr_reports)/3_placement/placement_report.rpt
krg_create_stage_reports -write_db yes -check_drc yes

# Screenshot of the floorplan
gui_fit
write_to_gif $design(pnr_reports)/screenshots/2_Placement.gif

# Stamp the stage for runtime and memory information
# --------------------------------------------------
time_info -table $runtype -stamp "init_design"

# Screenshot of the floorplan
gui_fit
write_to_gif $design(pnr_reports)/screenshots/1_Floorplan.gif
write_db