# Placement Stage
# ---------------
krg_start_stage "placement" yes

krg_global_placement_settings
krg_detailed_placement_settings

set_multi_cpu_usage -local_cpu 1
place_opt_design -expanded_views \
                 -report_prefix [format "%02d" $this_run(stage_count)]_$this_run(stage)_ \
                 -report_dir $design(reports_pnr_dir) \
                 -num_paths 100 \
                 -timing_debug_report
set_multi_cpu_usage -local_cpu max


# Reporting & Save
check_place ;#> $design(pnr_reports)/3_placement/placement_report.rpt

place_detail -eco true

# Congestion Analysis
route_early_global
report_congestion -overflow
report_congestion -3d -hotspot

# Add Tie Cells
add_tieoffs -lib_cell "$tech(TIE_HIGH_CELL) $tech(TIE_LOW_CELL)" -prefix $tech(TIE_PREFIX)

set_db add_tieoffs_cells "$tech(TIE_HIGH_CELL) $tech(TIE_LOW_CELL)"
check_tieoffs ;#-out_file $design(pnr_reports)/3_placement/tieoffs_report.rpt

krg_define_cost_groups
time_design -pre_cts -expanded_views
report_constraints -early 
foreach cg $design(cost_groups) {
    report_timing -early -max_paths 100 -group $cg > ${cg}.setup.timing.rpt
}
 
report_timing_summary -checks setup -groups $design(cost_groups)

# Fix DRV
set_multi_cpu_usage -local_cpu 1
opt_design -pre_cts -drv 

set_db opt_useful_skew true
opt_design -pre_cts -incremental
set_multi_cpu_usage -local_cpu max

# krg_create_stage_reports -write_db yes -check_drc yes

# # Screenshot of the floorplan
# gui_fit
# write_to_gif $design(pnr_reports)/screenshots/2_Placement.gif

# # Stamp the stage for runtime and memory information
# # --------------------------------------------------
# time_info -table $runtype -stamp "init_design"

# # Screenshot of the floorplan
# gui_fit
# write_to_gif $design(pnr_reports)/screenshots/1_Floorplan.gif
# write_db

# check_design -type place


###### To-Do:Early Clock Flow ######
###### To-Do:Add Spare Cells ######