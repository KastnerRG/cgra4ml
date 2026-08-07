
# Initializing Design
# -------------------
krg_start_stage "init_design" yes

# Set Global Nets
# --------------
set_db init_ground_nets $design(all_ground_nets)
set_db init_power_nets  $design(all_power_nets)

# LIB message suppression
# -----------------------
# krg_message "Suppressing the following messages that are reported due to the LIB definitions"
# krg_message "$tech(LIB_SUPPRESS_MESSAGES_INNOVUS)"
# set_message -suppress -id $tech(LIB_SUPPRESS_MESSAGES_INNOVUS)

# Get SRAMs instances for SDC 
# ---------------------------
set design(DMA_SRAM_LIST) [get_db insts -if {.base_name =~ *sram_dma*}]

# MMMC Loading
# ------------
if {$timing_lib_type == "nldm"} {
    krg_message "Loading MMMC File with NLDM Libs"
    read_mmmc $design(mmmc_nldm_view_file)
} else {
    krg_message "Loading MMMC File with CCS & OCV Libs"
    read_mmmc $design(mmmc_ocv_view_file)
}

# LEF message suppression
# -----------------------
# krg_message "Suppressing the following messages that are reported due to the LEF definitions"
# krg_message "$tech(LEF_SUPPRESS_MESSAGES_INNOVUS)"
# set_message -suppress -id $tech(LEF_SUPPRESS_MESSAGES_INNOVUS)

# LEF Loading
# ------------
krg_message "Reading LEF abstracts"
read_physical -lef $tech_files(ALL_LEFS)

# Post Synthesis Netlist Loading
# ------------------------------
krg_message "Reading Synthesis Netlist"
if {$phys_synth_type == "floorplan"} {
	read_netlist $design(postsyn_netlist_ispatial)
} else {
	read_netlist $design(postsyn_netlist_rtl_flow)
}

# Import and initialize design
# ---------------------------
krg_message "Initializing Synthesis Design"
init_design

# Save the design
# ---------------
write_db $design(dbs_pnr_dir)/init_design.db -no_wait "init_design_[format "%02d" $innovus_run_counter]"

# Stamp the stage for runtime and memory information
# --------------------------------------------------
time_info -table $runtype -stamp "init_design"