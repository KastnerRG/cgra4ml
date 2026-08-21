# CTS Stage
# ---------
krg_start_stage "clock_tree_synthesis" yes

check_design -type cts

# Load Clock Tree Configuration
# -----------------------------
reset_ccopt_config
source $design(clock_tree_spec)

krg_clock_tree_synthesis_settings
krg_routing_settings

# check_cts_config PODv2 error

# ccopt_design -report_dir "$design(reports_dir)/pnr/4_clock_tree_synthesis/ccopt_design"
set_multi_cpu_usage -local_cpu 1
clock_opt_design ;#-report_dir "$design(reports_dir)/pnr/4_clock_tree_synthesis/ccopt_design"
set_multi_cpu_usage -local_cpu max

report_clock_trees
report_cts_cell_name_info
check_design -type cts
# # Reporting & Save
# # ----------------
# if {$timing_lib_type == "ccs_ocv"} {
#     set_db timing_analysis_engine             statistical
# }
# krg_create_stage_reports -write_db yes -check_drc yes -report_timing yes -check_connectivity yes
# if {$timing_lib_type == "ccs_ocv"} {
#     set_db timing_analysis_engine             static
# }

# Open the clock tree debugger and check Clock Tree
#gui_open_ctd

# Post CTS Hold Fixing
# --------------------
krg_start_stage "5_post_cts_hold"
set_multi_cpu_usage -local_cpu 1
opt_design -post_cts -drv
opt_design -post_cts
opt_design -post_cts -hold 
set_multi_cpu_usage -local_cpu max

report_timing_summary -checks setup -groups $design(cost_groups)
report_timing_summary -checks hold -groups $design(cost_groups)
report_constraints -early 
report_constraints -late

# check_design -type cts
# # Reporting & Save
# if {$timing_lib_type == "ccs_ocv"} {
#     set_db timing_analysis_engine             statistical
# }
# krg_create_stage_reports -write_db yes -check_drc yes -report_timing yes -check_connectivity yes
# if {$timing_lib_type == "ccs_ocv"} {
#     set_db timing_analysis_engine             static
# }

# # Screenshot of the floorplan
# gui_fit
# write_to_gif $design(pnr_reports)/screenshots/3_CTS.gif

# # Stamp the stage for runtime and memory information
# # --------------------------------------------------
# time_info -table $runtype -stamp "init_design"

# # Screenshot of the floorplan
# gui_fit
# write_to_gif $design(pnr_reports)/screenshots/1_Floorplan.gif
# write_db