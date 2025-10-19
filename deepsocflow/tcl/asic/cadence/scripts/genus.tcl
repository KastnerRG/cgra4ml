#################################################################
#           DEFINE THE NAME OF THE TOPLEVEL DESIGN              #
#              and variables specific to this run               #
#################################################################
set design(TOPLEVEL) "dnn_engine"
set runtype "synthesis"
set debug_file "debug.genus.txt"

#################################################################
#                     Load Basic Settings                       #
#################################################################

# Load General Procedures
source ../../deepsocflow/tcl/asic/cadence/scripts/cadence.procedures.tcl -quiet

uom_start_stage "loading_basic_settings"

# Load the specific definitions for this project
source ../../deepsocflow/tcl/asic/cadence/inputs/cadence.$design(TOPLEVEL).defines -quiet

# Load general settings
source ../../deepsocflow/tcl/asic/cadence/scripts/cadence.settings.tcl -quiet

# Load the library paths and definitions for this technology
source ../../deepsocflow/tcl/asic/cadence/libraries/cadence.libraries.$TECHNOLOGY.tcl -quiet
source ../../deepsocflow/tcl/asic/cadence/libraries/cadence.libraries.$SC_TECHNOLOGY.tcl -quiet
source ../../deepsocflow/tcl/asic/cadence/libraries/cadence.srams.$TECHNOLOGY.tcl -quiet
source ../../deepsocflow/tcl/asic/cadence/libraries/cadence.srams.$SC_TECHNOLOGY.tcl -quiet

################## Add Check Library here later

if {$design(FULLCHIP_OR_MACRO) == "FULLCHIP"} {
    source ../../deepsocflow/tcl/asic/cadence/libraries/cadence.libraries.$IO_TECHNOLOGY.tcl -quiet
}

uom_message "Suppressing the following messages that are design specific"
uom_message "$design(DESIGN_SUPPRESS_MESSAGES_GENUS)"
suppress_messages $design(DESIGN_SUPPRESS_MESSAGES_GENUS)

#################################################################
#                 Print Values to debug file                    #
#################################################################
set var_list {runtype phys_synth_type}
set dic_list {paths tech tech_files design}
uom_print_debug_data w $debug_file "after everything was loaded" $var_list $dic_list

#################################################################
#                       Read MMMC                               #
#################################################################
uom_start_stage "init_libraries"

# Suppress messages
uom_message "Suppressing the following messages that are reported due to the library definitions"
uom_message "$tech(LIB_SUPPRESS_MESSAGES_GENUS)"
suppress_messages $tech(LIB_SUPPRESS_MESSAGES_GENUS)

# Load MMMC File
# --------------
if {$timing_lib_type == "nldm"} {
    uom_message "Loading MMMC File with NLDM Libs"
    read_mmmc $design(mmmc_nldm_view_file)
} else {
    uom_message "Loading MMMC File with CCS & OCV Libs"
    read_mmmc $design(mmmc_ocv_view_file)
}

#################################################################
#                    SDC File Generation                        #
#################################################################
uom_create_sdc_file

#################################################################
#                      Read LEF files                           #
#################################################################
# Suppress messages
uom_message "Suppressing the following messages that are reported due to the LEF definitions"
uom_message "$tech(LEF_SUPPRESS_MESSAGES_GENUS)"
suppress_messages $tech(LEF_SUPPRESS_MESSAGES_GENUS)

# Read LEFs
# ---------
uom_message "Loading the library abstracts"
read_physical -lef $tech_files(ALL_LEFS)

#################################################################
#                      Read RTL files                           #
#################################################################
uom_start_stage "read_rtl"

set_db   hdl_define           $SRAM_TECHNOLOGY
set_db   init_hdl_search_path $design(hdl_search_paths)
read_hdl -language sv    -f $design(read_svh_hdl_list)
read_hdl -language sv    -f $design(read_sv_hdl_list)
read_hdl -language v2001 -f $design(read_v_hdl_list)

#################################################################
#                  Elaborate and Init Design                    #
#################################################################
# Elaborate
# ---------
uom_start_stage "elaborate"
elaborate $design(TOPLEVEL)
uniquify $design(TOPLEVEL)

# Check Design
# ------------
uom_start_stage "1_post_elaboration_design"
uom_message "Checking design post elaboration"
check_design -unresolved
check_design -all > $design(synthesis_reports)/1_post_elaboration/check_design_post_elab.rpt
if {[check_design -status]} {
    puts "uomINFO: ############### There is an issure with check design. You better look at it! ###############"
}

# Init Design
# -----------
uom_message "Running init_design in an MMMC flow"
init_design

# Check Timing
# ------------
uom_message "Checking timing intent (lint) after init_design"
check_timing_intent > $design(synthesis_reports)/1_post_elaboration/check_timing_post_elab.rpt

# Save elaborated design
# ----------------------
write_design -base_name $design(dbs_dir)/synthesis/1_post_elaboration/$design(TOPLEVEL)

#################################################################
#                    For iSpatial Flow	                        #
#################################################################
if {$phys_synth_type == "floorplan"} {
    # You need to read a .def file for the floorplan to enable physical synthesis
    uom_message "Loading the floorplan DEF"
    read_def $design(floorplan_def)
}

#################################################################
#                          Synthesize                           #
#################################################################
uom_start_stage "2_pre_synthesis"

# Define OCV Methodology for Timing Analysis
# ------------------------------------------
if {$timing_lib_type == "ccs_ocv"} {
    phys_enable_ocv -native_aocv -design $design(TOPLEVEL)
}

# Define cost groups (reg2reg, in2reg, reg2out, in2out)
# -----------------------------------------------------
uom_default_cost_groups
uom_report_timing $design(synthesis_reports)

# Set Retime
set_db design:${design(TOPLEVEL)} .retime true

# Physical Flow Attributes
# ------------------------
set_db design_process_node      $TECH_NODE
set_db number_of_routing_layers $METAL_LAYERS
#set_db design_tech_node         N7


if {$phys_synth_type == "floorplan"} {
    # Set Synthesis Efforts
    set_db syn_generic_effort           high    ; # low|medium|high
    set_db syn_map_effort               high    ; # low|medium|high
    set_db syn_opt_effort               extreme ; # low|medium|high|extreme

    set_db opt_spatial_effort           extreme ; # legacy|standard|extreme
    set_db opt_leakage_to_dynamic_ratio 1.0
    set_db design_power_effort          high    ; # none|low|high

    # Synthesize to generics and place generics in floorplan
    uom_start_stage "syn_generic_ispatial_flow"
    syn_generic

    # Map technology
    uom_start_stage "3_technology_mapping_ispatial_flow"
    syn_map
    uom_report_timing $design(synthesis_reports)

    # Post synthesis optimization
    uom_start_stage "4_post_syn_opt_ispatial_flow"
    syn_opt

} else {
    # Set Synthesis Efforts
    set_db syn_generic_effort           high    ; # low|medium|high
    set_db syn_map_effort               high    ; # low|medium|high
    set_db syn_opt_effort               extreme ; # low|medium|high|extreme

    # Synthesize to generics and place generics in floorplan
    uom_start_stage "syn_generic_rtl_flow"
    syn_generic 

    # Map technology
    uom_start_stage "3_technology_mapping_rtl_flow"
    syn_map 
    uom_report_timing $design(synthesis_reports)

    # Post synthesis optimization
    uom_start_stage "4_post_syn_opt_rtl_flow"
    syn_opt
}

#################################################################
#                     Post Synthesis Reports                    #
#################################################################
uom_report_timing $design(synthesis_reports)
set post_synth_reports [list \
    report_area \
    report_gates \
    report_hierarchy \
    report_design_rules \
    report_dp \
    report_qor \
]
foreach rpt $post_synth_reports {
    uom_message "$rpt" medium
    $rpt
    $rpt > "$design(synthesis_reports)/$this_run(stage)/${rpt}.rpt"
}

#################################################################
#                     Exporting the Design                      #
#################################################################
if {$phys_synth_type == "floorplan"} {
    uom_start_stage "export_post_synth_design_ispatial"

    # Write out a database for loading in Innovus/Voltus/Tempus
    # ---------------------------------------------------------
    uom_message "Exporting the design Database to $design(postsyn_db_base_name_ispatial)"
    write_db -common $design(postsyn_db_ispatial)

    # Write out a netlist for simulation or Innovus
    # ---------------------------------------------
    uom_message "Writing the post synthesis netlist to $design(postsyn_netlist_ispatial)"
    write_netlist $design(TOPLEVEL) -depth 1 > $design(postsyn_netlist_ispatial)

    # Write out SDF for backannotation simulation
    # -------------------------------------------
    uom_message "Writing the post synthesis SDF"
    write_sdf > $design(postsyn_sdf_ispatial)
} else {
    uom_start_stage "export_post_synth_rtl_floorplanning"

    # Write out a database for loading in Innovus/Voltus/Tempus
    # ---------------------------------------------------------
    uom_message "Exporting the design Database to $design(postsyn_db_base_name_rtl_flow)"
    write_db -common $design(postsyn_db_rtl_flow)

    # Write out a netlist for simulation or Innovus
    # ---------------------------------------------
    uom_message "Writing the post synthesis netlist to $design(postsyn_netlist_rtl_flow)"
    write_netlist $design(TOPLEVEL) -depth 1 > $design(postsyn_netlist_rtl_flow)

    # Write out SDF for backannotation simulation
    # -------------------------------------------
    uom_message "Writing the post synthesis SDF"
    write_sdf > $design(postsyn_sdf_rtl_flow)
}
uom_message "!!!!!!!!!!!!!!!!!!! Genus Synthesis Successful !!!!!!!!!!!!!!!!!!!!!"
