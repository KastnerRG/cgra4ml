##############################################################################
# Project   : DeepSoCFlow CGRA4ML
# Script    : genus.tcl
# Purpose   : Cadence Genus RTL Synthesis flow script for Genus 23.1
##############################################################################
# Author    : Ravidu Munasinghe <raviduhm@gmail.com>
# Org       : Kastner Research Group | ENTC UoM
# Created   : 2026-05-14
# Modified  : 2026-06-11
##############################################################################
# Version   : 1.1
# Status    : In Progress
##############################################################################
#
# Description:
#   Top-level flat synthesis script for the axi_cgra4ml design using
#   Cadence Genus. Loads project config, runs elaboration, synthesis,
#   and generates timing/area reports.
#
#   This script have two major flows. Very first flow should be a 
#   rtl_floorplanning flow and use netlist to create a good floorplan in 
#   innovus move back to genus and use that floorplan to do genus ispatial 
#   synthesis. This synthesis produces PPA which is very closely correlates 
#   with innovus results.
#
##############################################################################
# TODO: 
#   Major Revisions
#   [ ] Add SOCV libs support
#   [ ] Add Low power optimization support
#   [ ] Add DFT support
#   [ ] Add Conformal Support - Debugging features like non-equivalences
#   [ ] Add Hierarchical synthesis support
#   [ ] Add Joules integration
#   [ ] Add Midas safety integration
#   [ ] Add Structured Datapath Support
#   Minor Revisions
#   [X] Add Unified Metrics
#   [ ] Add suppress messages feature
#   [ ] Reload Databases and SDC procs
#   [ ] Datapath Optimization settings
#   [ ] Early Clock flow settings
#   [ ] Ultra Optimization settings
#   [ ] PBS MiM flow
##############################################################################
# Suggestions: 
# If you need Best Area results at the expense of timing
# Use det_db dp_analytical_opt off|standard(default)|extreme.

# You can use report_timing after cost_group step to identify any potential paths for furthur grouping independently.
# Use this selectively to set different effort levels for different cost groups after setting cost_groups.
# Use set_path_adjust -delay -200 -from [all_register] to [all_register] -name pa_r2r]
# Use delete_obj [get_db exceptions pa_*] before any report_timing.

# group instances if you need to create a hierarchy.
# group -name CRITICAL_GROUP [get_db "inst:I1 inst:I2"]

# use report_ungroup_modules to findout how many modules already ungrouped.

# use report_sequential -deleted to find out sequential elements deleted during optimization.

# Do this before syn_generic if timing met do this to ease LEC verification
# set rt_modules {module:<design_name>/<module name1> module:<design_name>/<module name2> module:<design_name>/<module name3>}
# foreach mod $rt_modules {
#   set_db $mod .retime true 
#   ####Uncomment to prevent registers from being moved across the module boundaries (also best for LEC)
#   ##set_db $mod .retime_hard_region true
#   ####Uncomment to minimize issues with Conformal LEC
#   ##set_db $mod .boundary_opto false
# }
# ####Setting 'retime' attribute on the top-level as shown below 
# ####is not recommended due to possible verification/ECO issues unless for very small designs
# ##set_db "design:$DESIGN" .retime true   

# ####set dont_retime on registers which should not be retimed
# set dont_rt_flops "inst:<path_to_myflop1> inst:<path_to_myflop2> inst:<path_to_myflop3> ..."
# foreach rtf $rt_flops {
#   set_db $rtf .dont_retime true
# }

# report_qor maybe slower in large scale MMMC use -no_power option
# Use -power option to get both dynamic and leakage power in dominent view report_gates

# write_netlist -lec
# this is not required if you arent doing any retiming

# If you need external metric to add to unified metric
# use define_metric and set_metric. Use furthur information from userguide

# Low Power
# set_db "design:$DESIGN" .lp_clock_gating_cell [vfind /lib* -lib_cell <cg_libcell_name>]
##############################################################################
# Usage: 
#   genus -lic_startup Genus_Synthesis \
#         -lic_startup_options "Genus_Low_Power_Opt Genus_Physical_Opt" \
#         -abort_on_error -files genus.tcl
#!Also change the genus_run_counter variable each time you run a genus script!
##############################################################################

#################################################################
#           Define the names of the top level design            #
#              and variables specific to this run               #
#################################################################

set genus_run_counter   [expr {[info exists env(GENUS_RUN_COUNTER)] ? $env(GENUS_RUN_COUNTER) : 0}]
set design(TOPLEVEL)    "axi_cgra4ml"
set runtype             "synthesis"
set debug_file          "debug.genus.txt"

#################################################################
#                     Load Basic Settings                       #
#################################################################
# Load General Procedures
source /work/cgra4ml/deepsocflow/tcl/asic/scripts/cadence.procedures.tcl -quiet
krg_start_stage "Loading_basic_settings" no

# Load the specific definitions for this project
source /work/cgra4ml/deepsocflow/run/work/config_hw.tcl -quiet
source /work/cgra4ml/deepsocflow/tcl/asic/inputs/cadence.$design(TOPLEVEL).defines -quiet

# Load general settings
source $design(scripts_dir)/cadence.settings.tcl -quiet

# Load the library paths and definitions for this technology
source $design(libraries_dir)/cadence.libraries.$TECHNOLOGY.tcl -quiet
source $design(libraries_dir)/cadence.libraries.$SC_TECHNOLOGY.tcl -quiet
source $design(libraries_dir)/cadence.srams.$TECHNOLOGY.tcl -quiet
source $design(libraries_dir)/cadence.srams.$SC_TECHNOLOGY.tcl -quiet
if {$design(FULLCHIP_OR_MACRO) == "FULLCHIP"} {
    source $design(libraries_dir)/cadence.libraries.$IO_TECHNOLOGY.tcl -quiet
}

# krg_message "Suppressing the following messages that are design specific"
# krg_message "$design(DESIGN_SUPPRESS_MESSAGES_GENUS)"
# suppress_messages $design(DESIGN_SUPPRESS_MESSAGES_GENUS)

#################################################################
#                 Print Values to debug file                    #
#################################################################
set var_list {runtype phys_synth_type}
set dic_list {env tech tech_files design}
krg_print_debug_data w $debug_file $var_list $dic_list

# Stamp the stage for runtime and memory information
time_info -table $runtype -stamp $this_run(stage)

#################################################################
#                       Read MMMC                               #
#################################################################
krg_start_stage "init_libraries" no

# krg_message      "Suppressing the following messages that are reported due to the library definitions"
# krg_message      "$tech(LIB_SUPPRESS_MESSAGES_GENUS)"
# suppress_messages $tech(LIB_SUPPRESS_MESSAGES_GENUS)

# Load MMMC File
# --------------
if {$timing_lib_type == "nldm"} {
    krg_message "Loading MMMC File with NLDM Libs"
    read_mmmc $design(mmmc_nldm_view_file)
} else {
    krg_message "Loading MMMC File with CCS & OCV Libs"
    read_mmmc $design(mmmc_ocv_view_file)
}

#################################################################
#                    SDC File Generation                        #
#################################################################
krg_create_sdc_file

#################################################################
#                      Read LEF files                           #
#################################################################
# Suppress messages
krg_message      "Suppressing the following messages that are reported due to the LEF definitions"
krg_message      "$tech(LEF_SUPPRESS_MESSAGES_GENUS)"
suppress_messages $tech(LEF_SUPPRESS_MESSAGES_GENUS)

# Read LEFs
# ---------
krg_message         "Loading the library abstracts"
read_physical -lef  $tech_files(ALL_LEFS)

# Stamp the stage for runtime and memory information
time_info -table $runtype -stamp $this_run(stage)

#################################################################
#                      Read RTL files                           #
#################################################################
krg_start_stage "read_rtl" no

set_db init_hdl_search_path $design(hdl_search_paths)
read_hdl -language sv    -f $design(read_svh_hdl_list)
read_hdl -language sv    -f $design(read_sv_hdl_list)
read_hdl -language v2001 -f $design(read_v_hdl_list)

# Get SRAMs instances
# -------------------
set design(SRAM_LIST_FULL) [get_db insts -if {.cell.base_name =~ *sram*}]

# Stamp the stage for runtime and memory information
time_info -table $runtype -stamp $this_run(stage)

#################################################################
#                  Elaborate and Init Design                    #
#################################################################
# Elaborate
# ---------
krg_start_stage "elaborate" yes
push_snapshot_stack
elaborate $design(TOPLEVEL)
pop_snapshot_stack
create_snapshot -categories all -label $this_run(stage) 

uniquify  $design(TOPLEVEL)

# Check Design
# ------------
check_design -all > $design(reports_dir)/[format "%02d" $this_run(stage_count)]_check_design_post_elab.rpt
if {[check_design -status]} {
    puts "krgINFO: ############### There is an issure with check design. You better look at it! ###############"
}

# Stamp the stage for runtime and memory information
time_info -table $runtype -stamp $this_run(stage)

# Init Design
# -----------
krg_message "Running init_design in an MMMC flow"
init_design

# Check Timing
# ------------
krg_message "Checking timing intent (lint) after init_design"
check_timing_intent > $design(reports_dir)/[format "%02d" $this_run(stage_count)]_check_sdc_post_elab.rpt

# Save elaborated design
# ----------------------
krg_create_stage_reports -report_datapath yes
# Stamp the stage for runtime and memory information
time_info -table $runtype -stamp "init_design"

#################################################################
#                          Synthesize                           #
#################################################################
krg_start_stage "pre_synthesis"

# Loading Innovus Golden Floorplan
# --------------------------------
if {$phys_synth_type == "floorplan"} {
    krg_message "Loading the Golden floorplan DEF from innovus" medium

    redirect $design(reports_dir)/read_def.floorplan.rpt -tee -msg {read_def $design(floorplan_def)} 

    check_floorplan -spatial > $design(reports_dir)/check_floorplan.rpt

    # Stamp the stage for runtime and memory information
    time_info -table $runtype -stamp "$this_run(stage)_load_floorplan"
}

# Define OCV Methodology for Timing Analysis
# ------------------------------------------
# if {$timing_lib_type == "ccs_ocv"} {
#     phys_enable_ocv -native_aocv -design $design(TOPLEVEL)
# }

# Define cost groups (reg2reg, in2reg, reg2out, in2out)
# -----------------------------------------------------
krg_default_cost_groups
krg_report_timing $design(synthesis_reports)


# Set Retime
# ----------
set_db design:${design(TOPLEVEL)} .retime true

# Physical Flow Attributes
# ------------------------
set_db design_process_node      $PROCESS_NODE
set_db number_of_routing_layers $METAL_LAYERS
set_db design_tech_node         $TECH_NODE


if {$phys_synth_type == "floorplan"} {
    # Set Synthesis Efforts and Other Settings
    krg_set_synthesis_efforts

    # Add multibits settings
    krg_set_multibit_settings

    if {$low_power_enabled == "yes"} {
        krg_set_low_power_settings
    }
    # Stamp the stage for runtime and memory information
    time_info -table $runtype -stamp "$this_run(stage)_settings"

    # Synthesize to generics gates
    krg_start_stage "syn_generic_ispatial_flow"
    push_snapshot_stack
    syn_generic -physical
    pop_snapshot_stack
    create_snapshot -categories all -label $this_run(stage) 
    # Stamp the stage for runtime and memory information
    time_info -table $runtype -stamp "$this_run(stage)_syn_generic"

    # Create Reports and Snapshot
    krg_create_stage_reports -report_datapath yes -report_summary yes
    # Stamp the stage for runtime and memory information
    time_info -table $runtype -stamp "$this_run(stage)_syn_generic_reports"

    # Map technology
    krg_start_stage "syn_mapping_ispatial_flow"
    push_snapshot_stack
    syn_map -physical
    pop_snapshot_stack
    create_snapshot -categories all -label $this_run(stage) 
    # Stamp the stage for runtime and memory information
    time_info -table $runtype -stamp "$this_run(stage)_syn_map"

    # Create Reports and Snapshot
    krg_create_stage_reports -report_datapath yes -report_summary yes
    # Stamp the stage for runtime and memory information
    time_info -table $runtype -stamp "$this_run(stage)_syn_map_reports"

    # Conformal LEC verification
    write_do_lec -golden_design rtl -revised_design fv_map \
    -logfile design(conformal_dir)/rtl2fvmap.lec.log > design(conformal_dir)/rtl2fvmap.lec.tcl

    # Stamp the stage for runtime and memory information
    time_info -table $runtype -stamp "$this_run(stage)_conformal_map"

    # Post synthesis optimization
    krg_start_stage "syn_opt_ispatial_flow"
    push_snapshot_stack
    syn_opt -spatial
    pop_snapshot_stack
    create_snapshot -categories all -label $this_run(stage) 
    # Stamp the stage for runtime and memory information
    time_info -table $runtype -stamp "$this_run(stage)_syn_opt"

} else {
    # Set Synthesis Efforts and Other Settings
    krg_set_synthesis_efforts

    # Add multibits settings
    krg_set_multibit_settings

    if {$low_power_enabled == "yes"} {
        krg_set_low_power_settings
    }
    # Stamp the stage for runtime and memory information
    time_info -table $runtype -stamp "$this_run(stage)_settings"

    # Synthesize to generics gates
    krg_start_stage "syn_generic_ispatial_flow"
    push_snapshot_stack
    syn_generic -physical
    pop_snapshot_stack
    create_snapshot -categories all -label $this_run(stage) 
    # Stamp the stage for runtime and memory information
    time_info -table $runtype -stamp "$this_run(stage)_syn_generic"

    # Create Reports and Snapshot
    krg_create_stage_reports -report_datapath yes -report_summary yes
    # Stamp the stage for runtime and memory information
    time_info -table $runtype -stamp "$this_run(stage)_syn_generic_reports"

    # Map technology
    krg_start_stage "syn_mapping_ispatial_flow"
    push_snapshot_stack
    syn_map -physical
    pop_snapshot_stack
    create_snapshot -categories all -label $this_run(stage) 
    # Stamp the stage for runtime and memory information
    time_info -table $runtype -stamp "$this_run(stage)_syn_map"

    # Create Reports and Snapshot
    krg_create_stage_reports -report_datapath yes -report_summary yes
    # Stamp the stage for runtime and memory information
    time_info -table $runtype -stamp "$this_run(stage)_syn_map_reports"

    # Stamp the stage for runtime and memory information
    time_info -table $runtype -stamp "$this_run(stage)_conformal_map"

    # Predict Floorplan
    krg_set_predict_floorplan_settings
    predict_floorplan

    # Post synthesis optimization
    krg_start_stage "syn_opt_ispatial_flow" no
    push_snapshot_stack
    syn_opt -spatial
    pop_snapshot_stack
    create_snapshot -categories all -label $this_run(stage) 
    # Stamp the stage for runtime and memory information
    time_info -table $runtype -stamp "$this_run(stage)_syn_opt"

}

#################################################################
#                     Post Synthesis Reports                    #
#################################################################
# Create Reports and Snapshot
krg_create_stage_reports \
    -write_db           yes \
    -write_snapshot     yes \
    -report_setup       yes \
    -report_hold        yes \
    -check_drc          yes \
    -check_connectivity yes \
    -report_datapath    yes \
    -report_qor         yes \
    -report_gates       yes \
    -report_area        yes \
    -check_design_rules    yes \
    -report_summary        yes \
    -report_multibit       yes \
    -report_ple            yes 

# Stamp the stage for runtime and memory information
time_info -table $runtype -stamp "$this_run(stage)_syn_opt_reports"

#################################################################
#                     Exporting the Design                      #
#################################################################
if {$phys_synth_type == "floorplan"} {
    krg_start_stage "export_post_synth_design_ispatial"

    # Write out Netlist for simulation, lec or pnr
    # --------------------------------------------
    krg_message "Writing the post synthesis lec netlist to $design(postsyn_netlist_ispatial)"
    write_netlist -lec $design(TOPLEVEL) > $design(postsyn_lec_netlist_ispatial)
    write_do_lec -golden_design fv_map -revised_design $design(postsyn_lec_netlist_ispatial) \
    -logfile $design(conformal_dir)/fvmap2netlist.lec.log > $design(conformal_dir)/fvmap2netlist.lec.tcl

    krg_message "Writing the post synthesis netlist to $design(postsyn_netlist_rtl_flow)"
    write_netlist $design(TOPLEVEL) -depth 0 > $design(postsyn_netlist_rtl_flow)

    # Write out SDC for pnr
    # ---------------------
    krg_message "Writing the post synthesis SDC constraint file"
    write_sdc $design(postsyn_sdc_rtl_flow) 

    # Write out SDF for backannotation simulation
    # -------------------------------------------
    krg_message "Writing the post synthesis SDF annotation file"
    write_sdf > $design(postsyn_sdf_ispatial)

} else {
    krg_start_stage "export_post_synth_rtl_floorplanning"

    # Write out a netlist for simulation or Innovus
    # ---------------------------------------------
    krg_message "Writing the post synthesis netlist to $design(postsyn_netlist_rtl_flow)"
    write_netlist $design(TOPLEVEL) -depth 0 > $design(postsyn_netlist_rtl_flow)

    # Write out SDC for pnr
    # ---------------------
    krg_message "Writing the post synthesis SDC constraint file"
    write_sdc > $design(postsyn_sdc_rtl_flow) 

    # Write out SDF for backannotation simulation
    # -------------------------------------------
    krg_message "Writing the post synthesis SDF"
    write_sdf > $design(postsyn_sdf_rtl_flow)

}

# Stamp the stage for runtime and memory information
time_info -table $runtype -stamp "export_post_synth"

#################################################################
#                  Debugging Genus Messages                     #
#################################################################
report_messages -all                > design(workdir)/$design(TOPLEVEL)_messages_all.rpt
report_messages -include_suppressed > design(workdir)/$design(TOPLEVEL)_messages_include_suppressed.rpt
report_messages -errors             > design(workdir)/$design(TOPLEVEL)_messages_errors.rpt
report_messages -warnings           > design(workdir)/$design(TOPLEVEL)_messages_warnings.rpt
report_messages -info               > design(workdir)/$design(TOPLEVEL)_messages_info.rpt

write_metric -format jason -out_file $design(compare_dir)/$design(TOPLEVEL)_genus_run_[format "%02d" $genus_run_counter]
krg_message "!!!!!!!!!!!!!!!!!!! Genus Synthesis Successful !!!!!!!!!!!!!!!!!!!!!" medium
