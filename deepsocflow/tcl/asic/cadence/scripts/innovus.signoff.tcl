# SignOff Stage
# -------------
krg_start_stage "signoff" yes

# Input & Output Port Naming
# --------------------------
bitblast_ports $design(TOPLEVEL)

# Write out a netlist for gls simulation
# ---------------------------------------------
krg_message "Writing the post route netlist to $design(postroute_netlist)"
write_netlist -top_module $design(TOPLEVEL) -top_module_first -flat $design(postroute_netlist)

# Write out SDF for backannotation simulation
# -------------------------------------------
krg_message "Writing the post route SDF to $design(postroute_sdf)"
write_sdf -version 3.0 -min_view bc_analysis_view -typical_view tc_analysis_view -max_view wc_analysis_view $design(postroute_sdf) 

# Add Via Fill
# ------------
add_via_fill

# Add Metal Fill
# --------------
add_metal_fill

# Screenshot of the floorplan
# --------------------------
gui_fit
write_to_gif $design(pnr_reports)/screenshots/5_Final_Layout.gif

# Stamp the stage for runtime and memory information
# --------------------------------------------------
time_info -table $runtype -stamp "signoff"