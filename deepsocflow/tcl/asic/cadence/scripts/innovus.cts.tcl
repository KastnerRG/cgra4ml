# CTS Stage
# ---------
krg_start_stage "clock_tree_synthesis" yes

# Load Clock Tree Configuration
# -----------------------------
reset_ccopt_config
source $design(clock_tree_spec)

set_db opt_new_inst_prefix "cts_opt_inst_"
set_db opt_new_net_prefix  "cts_opt_net_"
# ccopt_design -report_dir "$design(reports_dir)/pnr/4_clock_tree_synthesis/ccopt_design"
clock_opt_design -report_dir "$design(reports_dir)/pnr/4_clock_tree_synthesis/ccopt_design"

# Reporting & Save
# ----------------
if {$timing_lib_type == "ccs_ocv"} {
    set_db timing_analysis_engine             statistical
}
krg_create_stage_reports -write_db yes -check_drc yes -report_timing yes -check_connectivity yes
if {$timing_lib_type == "ccs_ocv"} {
    set_db timing_analysis_engine             static
}

# Open the clock tree debugger and check Clock Tree
#gui_open_ctd

# Post CTS Hold Fixing
# --------------------
krg_start_stage "5_post_cts_hold"
opt_design -post_cts -hold 

# Reporting & Save
if {$timing_lib_type == "ccs_ocv"} {
    set_db timing_analysis_engine             statistical
}
krg_create_stage_reports -write_db yes -check_drc yes -report_timing yes -check_connectivity yes
if {$timing_lib_type == "ccs_ocv"} {
    set_db timing_analysis_engine             static
}

# Screenshot of the floorplan
gui_fit
write_to_gif $design(pnr_reports)/screenshots/3_CTS.gif

# Stamp the stage for runtime and memory information
# --------------------------------------------------
time_info -table $runtype -stamp "init_design"

# Screenshot of the floorplan
gui_fit
write_to_gif $design(pnr_reports)/screenshots/1_Floorplan.gif
write_db