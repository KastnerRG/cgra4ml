##############################################################################
# Project   : DeepSoCFlow CGRA4ML
# Script    : innovus.tcl
# Purpose   : Cadence Innovus Place-and-Route flow script for Innovus 23.1
##############################################################################
# Author    : Ravidu Munasinghe <raviduhm@gmail.com>
# Org       : Kastner Research Group | ENTC UoM
# Created   : 2026-05-14
# Modified  : 2026-07-06
##############################################################################
# Version   : 1.0
# Status    : In Progress
##############################################################################
#
# Description:
#   Top-level flat P&R script for the axi_cgra4ml design using Cadence
#   Innovus. Loads project config, runs floorplanning, placement, clock
#   tree synthesis, routing, and generates timing/area reports.
#
#   This script supports two major flows. The first flow is an
#   rtl_floorplanning flow that uses the post-synthesis netlist to create
#   a good floorplan and exports a DEF for physically-aware synthesis.
#   The second flow uses a pre-existing floorplan DEF to run full P&R.
#
##############################################################################
# TODO:
#   Major Revisions
#   [ ] Add Innovus Synthesis support
#   [ ] Add SOCV libs support
#   [ ] Add Low power optimization support
#   [ ] Add DFT support
#   [ ] Add Conformal Support - Debugging features like non-equivalences
#   [ ] Add Hierarchical P&R support
#   [ ] Add Joules integration
#   [ ] Add Midas safety integration
#   [ ] Add I/O Pad support for fullchip
#   Minor Revisions
#   [ ] Add Distributed Processing
#   [ ] Add Unified Metrics - Snapshots
#   [ ] Add suppress messages feature
#   [ ] Reload Databases
##############################################################################
# Usage:
#   Direct:
#     innovus -stylus -abort_on_error -files innovus.tcl
#
#   Recommended (via innovus.sh):
#     bash ./innovus.sh --run <n> [--genus-run <n>] [--phys-synth-type <type>]
#                         [--no-abort] [--overwrite]
#
#   Run-specific variables (set via environment or innovus.sh):
#     INNOVUS_RUN_COUNTER  - P&R run index; work dir is innovus_run_<nn> (default: 0)
#     GENUS_RUN_COUNTER    - Genus run for synthesis netlist/DB paths (default: 0)
#     INNOVUS_STAGE        - Stage entry point for reload/debug (default: full_flow)
#                            full_flow, post_initial, post_floorplan, post_placement,
#                            post_cts, post_route, post_signoff
#     PHYS_SYNTH_TYPE      - lef (RTL floorplan) or floorplan (iSpatial DEF flow)
#
#   Examples:
#     bash ./innovus.sh --run 1
#     bash ./innovus.sh --run 1 --genus-run 6
#     bash ./innovus.sh --run 1 --phys-synth-type floorplan --genus-run 6
##############################################################################

#################################################################
#           Define the names of the top level design            #
#              and variables specific to this run               #
#################################################################

gui_set_ui main -geometry "1920x1020+0+0"
enable_metrics -on

set innovus_run_counter  [expr {[info exists env(INNOVUS_RUN_COUNTER)] ? $env(INNOVUS_RUN_COUNTER) : 1}]
# set genus_run_counter    [expr {[info exists env(GENUS_RUN_COUNTER)] ? $env(GENUS_RUN_COUNTER) : 1}]
set genus_run_counter    6
set innovus_stage_reload [expr {[info exists env(INNOVUS_STAGE)] ? $env(INNOVUS_STAGE) : "full_flow"}]
set phys_synth_type      [expr {[info exists env(PHYS_SYNTH_TYPE)] ? $env(PHYS_SYNTH_TYPE) : "lef"}] ; # "lef"       - only read lef - RTL Floorplaning Flow with iSpatial
                                                                                                      # "floorplan" - read in DEF - iSpatial Flow
set design(TOPLEVEL)    "axi_cgra4ml"
set runtype             "pnr"
set debug_file          "debug.innovus.txt"

################################################################
#            Load Defines and Technology Definitions           #
################################################################
# Load general procedures
source /work/cgra4ml/deepsocflow/tcl/asic/cadence/scripts/innovus.procedures.tcl -quiet
krg_start_stage "loading_basic_settings" no

# Load the specific definitions for this project
source /work/cgra4ml/run/work/config_hw.tcl -quiet
source /work/cgra4ml/deepsocflow/tcl/asic/cadence/inputs/cadence.$design(TOPLEVEL).defines -quiet

# Load the library paths and definitions for this technology
source $design(libraries_dir)/cadence.libraries.$TECHNOLOGY.tcl -quiet
source $design(libraries_dir)/cadence.libraries.$SC_TECHNOLOGY.tcl -quiet
source $design(libraries_dir)/cadence.srams.$SC_TECHNOLOGY.tcl -quiet
source $design(libraries_dir)/cadence.srams.$TECHNOLOGY.tcl -quiet
if {$design(FULLCHIP_OR_MACRO) == "FULLCHIP"} {
    source $design(libraries_dir)/cadence.libraries.$IO_TECHNOLOGY.tcl -quiet
}

# Load Innovus Tech Implementation procs from foundary
# Copyright Restricted. Not available on git repo.
# Adopted from Cadence Artisan Technology PDKs
source $paths(PDK_AIM)/TECH_Procs/lef/innovus_implementation_procs.tcl
source $paths(PDK_AIM)/TECH_Procs/lef/$METAL_STACK/innovus_implemetation_variable_define_procs.tcl
source $paths(PDK_AIM)/TECH_Procs/lef/$METAL_STACK/${tech(STANDARD_CELL_ARCH)}_innovus_implementation_variable_define_procs.tcl

# Set up tech, metal_stack variables
krg_iu_tech_define_default_vars
krg_iu_tech_define_user_vars
krg_iu_tech_define_sc7p5mcpp60_vars

# Load general settings
source $design(scripts_dir)/cadence.settings.tcl -quiet

# krg_message "Suppressing the following messages that are design specific" medium
# krg_message "$design(DESIGN_SUPPRESS_MESSAGES_INNOVUS)"
# suppress_messages $design(DESIGN_SUPPRESS_MESSAGES_INNOVUS)

#################################################################
#                 Print Values to debug file                    #
#################################################################
set var_list {runtype phys_synth_type}
set dic_list {env tech tech_files design}
krg_print_debug_data w $debug_file $var_list $dic_list

#################################################################
#                    SDC File Generation                        #
#################################################################
krg_create_sdc_file
# Stamp the stage for runtime and memory information
time_info -table $runtype -stamp "loading_basic_settings"

#################################################################
#                 Initial Design Initialization                 #
#################################################################
if {$innovus_stage_reload == "full_flow"} {
    source /work/cgra4ml/deepsocflow/tcl/asic/cadence/scripts/innovus.init.tcl -quiet
} elseif {$innovus_stage_reload == "post_initial"} {
    # Load the database
    # -----------------
    read_db $design(dbs_pnr_dir)/init_design.db
    # Stamp the stage for runtime and memory information
    # --------------------------------------------------
    time_info -table $runtype -stamp "init_design"
}

#################################################################
#                       Floorplan Stage                         #
#################################################################
if {$innovus_stage_reload == "full_flow"} {
    source /work/cgra4ml/deepsocflow/tcl/asic/cadence/inputs/cadence.$design(TOPLEVEL).floorplan.defines -quiet
    source /work/cgra4ml/deepsocflow/tcl/asic/cadence/scripts/innovus.floorplan.tcl -quiet
} elseif {$innovus_stage_reload == "post_floorplan"} {
    # Load the database
    # -----------------
    read_db $design(dbs_pnr_dir)/floorplan.db
    # Stamp the stage for runtime and memory information
    # --------------------------------------------------
    time_info -table $runtype -stamp "floorplan"
}

#################################################################
#                       Placement Stage                         #
#################################################################
if {$innovus_stage_reload == "full_flow"} {
    source /work/cgra4ml/deepsocflow/tcl/asic/cadence/scripts/innovus.placement.tcl -quiet
} elseif {$innovus_stage_reload == "post_placement"} {
    # Load the database
    # -----------------
    read_db $design(dbs_pnr_dir)/placement.db
    # Stamp the stage for runtime and memory information
    # --------------------------------------------------
    time_info -table $runtype -stamp "placement"
}

#################################################################
#                         CTS Stage                             #
#################################################################
if {$innovus_stage_reload == "full_flow"} {
    source /work/cgra4ml/deepsocflow/tcl/asic/cadence/scripts/innovus.cts.tcl -quiet
} elseif {$innovus_stage_reload == "post_cts"} {
    # Load the database
    # -----------------
    read_db $design(dbs_pnr_dir)/cts.db
    # Stamp the stage for runtime and memory information
    # --------------------------------------------------
    time_info -table $runtype -stamp "cts"
}

# #################################################################
# #                        Route Stage                            #
# #################################################################
# if {$innovus_stage_reload == "full_flow"} {
#     source /work/cgra4ml/deepsocflow/tcl/asic/cadence/scripts/innovus.route.tcl -quiet
# } elseif {$innovus_stage_reload == "post_route"} {
#     # Load the database
#     # -----------------
#     read_db $design(dbs_pnr_dir)/route.db
#     # Stamp the stage for runtime and memory information
#     # --------------------------------------------------
#     time_info -table $runtype -stamp "route"
# }

# #################################################################
# #                        SignOff Stage                          #
# #################################################################
# if {$innovus_stage_reload == "full_flow"} {
#     source /work/cgra4ml/deepsocflow/tcl/asic/cadence/scripts/innovus.signoff.tcl -quiet
# } elseif {$innovus_stage_reload == "post_signoff"} {
#     # Load the database
#     # -----------------
#     read_db $design(dbs_pnr_dir)/signoff.db
#     # Stamp the stage for runtime and memory information
#     # --------------------------------------------------
#     time_info -table $runtype -stamp "signoff"
# }

# # Stamp the stage for runtime and memory information
# # --------------------------------------------------
# add_functions for time_infos

# krg_message "!!!!!!!!!!!!!!!!!!! Innovus PnR Successful !!!!!!!!!!!!!!!!!!!!!" medium
