##################################################################
#  Run genus -lic_startup Genus_Synthesis                        #
#  -lic_startup_options "Genus_Low_Power_Opt Genus_Physical_Opt" #
#  -abort_on_error -files genus.tcl                              #
##################################################################

#################################################################
#           Define the names of the top level design            #
#              and variables specific to this run               #
#################################################################

set design(TOPLEVEL) "axi_cgra4ml"
set runtype          "synthesis"
set debug_file       "debug.genus.txt"

#################################################################
#                     Load Basic Settings                       #
#################################################################
time_info ........................... -stamp $stage -report > filename
report_runtime $stage > filename
# Load General Procedures
source ../../../tcl/asic/scripts/cadence.procedures.tcl -quiet

krg_start_stage "loading_basic_settings" no

# Load the specific definitions for this project
source ../config_hw.tcl -quiet
source ../../tcl/asic/inputs/cadence.$design(TOPLEVEL).defines -quiet

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

krg_message "Suppressing the following messages that are design specific"
krg_message "$design(DESIGN_SUPPRESS_MESSAGES_GENUS)"
suppress_messages $design(DESIGN_SUPPRESS_MESSAGES_GENUS)

#################################################################
#                 Print Values to debug file                    #
#################################################################
set var_list {runtype phys_synth_type}
set dic_list {paths tech tech_files design}
krg_print_debug_data w $debug_file "after everything was loaded" $var_list $dic_list

#################################################################
#                       Read MMMC                               #
#################################################################
krg_start_stage "init_libraries" no

# Suppress messages
krg_message      "Suppressing the following messages that are reported due to the library definitions"
krg_message      "$tech(LIB_SUPPRESS_MESSAGES_GENUS)"
suppress_messages $tech(LIB_SUPPRESS_MESSAGES_GENUS)

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

#################################################################
#                  Elaborate and Init Design                    #
#################################################################
# If you need Best Area results at the expense of timing
# Use det_db dp_analytical_opt off|standard(default)|extreme

# Elaborate
# ---------
krg_start_stage "elaborate" yes
elaborate $design(TOPLEVEL)
uniquify  $design(TOPLEVEL)

# Check Design
# ------------
check_design -unresolved
check_design -all > $design(synthesis_reports)/01_check_design_post_elab.rpt
if {[check_design -status]} {
    puts "krgINFO: ############### There is an issure with check design. You better look at it! ###############"
}
adddd report_dp

# Init Design
# -----------
krg_message "Running init_design in an MMMC flow"
init_design

# Check Timing
# ------------
krg_message "Checking timing intent (lint) after init_design"
check_timing_intent > $design(synthesis_reports)/01_check_timing_post_elab.rpt

# Save elaborated design
# ----------------------
krg_create_stage_reports -write_db yes -write_snapshot no

#################################################################
#                    For iSpatial Flow	                        #
#################################################################
if {$phys_synth_type == "floorplan"} {
    # You need to read a .def file for the floorplan to enable physical synthesis
    krg_message "Loading the floorplan DEF"
    redirect  -tee -msg {read_def $design(floorplan_def)} 
    write proc to extract 3 slides phys variables
    check_floorplan -spatial > .......
}

#################################################################
#                          Synthesize                           #
#################################################################
krg_start_stage "pre_synthesis"

# Define OCV Methodology for Timing Analysis
# ------------------------------------------
if {$timing_lib_type == "ccs_ocv"} {
    phys_enable_ocv -native_aocv -design $design(TOPLEVEL)
}

# Define cost groups (reg2reg, in2reg, reg2out, in2out)
# -----------------------------------------------------
krg_default_cost_groups

# Use this selectively to set different effort levels for different cost groups.
# Use set_path_adjust -delay -200 -from [all_register] to [all_register] -name pa_r2r]
# Use delete_obj [get_db exceptions pa_*] before any report_timing.
krg_report_timing $design(synthesis_reports)

# group instances if you need to create a hierarchy.
# group -name CRITICAL_GROUP [get_db "inst:I1 inst:I2"]

# use report_ungroup_modules to findout how many modules already ungrouped.

# use report_sequential -deleted to find out sequential elements deleted during optimization.

# Set Retime
set_db design:${design(TOPLEVEL)} .retime true
#####################################################################################
#### Retime
#####################################################################################

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
# # Enable verification flow 
# set_db / .retime_verification_flow true 

# Physical Flow Attributes
# ------------------------
set_db design_process_node      $PROCESS_NODE
set_db number_of_routing_layers $METAL_LAYERS
set_db design_tech_node         $TECH_NODE


if {$phys_synth_type == "floorplan"} {
    # Set Synthesis Efforts
    set_db syn_generic_effort           $syn_generic_effort 
    set_db syn_map_effort               $syn_mapping_effort    
    set_db syn_opt_effort               $syn_optimize_effort 

    # Set Spatial Efforts
    set_db opt_spatial_effort           $opt_spatial_effort 
    set_db congestion_effort            $congestion_effort 
    set_db opt_leakage_to_dynamic_ratio $opt_leak_to_dyn_ratio
    set_db opt

    if {$low_power_enabled == "yes"} {
        set_db design_power_effort      $design_power_effort
    }

    # Synthesize to generics and place generics in floorplan
    krg_start_stage "syn_generic_ispatial_flow"
    syn_generic -physical

    # Map technology
    krg_start_stage "3_technology_mapping_ispatial_flow"
    syn_map -physical
    krg_report_timing $design(synthesis_reports)

    # Post synthesis optimization
    krg_start_stage "4_post_syn_opt_ispatial_flow"
    syn_opt -physical

} else {
    # Set Synthesis Efforts
    set_db syn_generic_effort           high    ; # low|medium|high
    set_db syn_map_effort               high    ; # low|medium|high
    set_db syn_opt_effort               extreme ; # low|medium|high|extreme

    # Synthesize to generics and place generics in floorplan
    krg_start_stage "syn_generic_rtl_flow"
    syn_generic 
time_info GENERIC
write_snapshot -outdir $_REPORTS_PATH -tag generic
report_summary -directory $_REPORTS_PATH
report_dp > $_REPORTS_PATH/generic/${DESIGN}_datapath.rpt

    # Map technology
    krg_start_stage "3_technology_mapping_rtl_flow"
    syn_map 
    krg_report_timing $design(synthesis_reports)
write_snapshot -outdir $_REPORTS_PATH -tag map
report_summary -directory $_REPORTS_PATH
time_info MAPPED
report_dp > $_REPORTS_PATH/map/${DESIGN}_datapath.rpt
    write_do_lec -golden_design rtl -revised_design fv_map -logfile ${_LOG_PATH}/rtl2intermediate.lec.log > ${_OUTPUTS_PATH}/rtl2intermediatesynmap.lec.tcl

    # Post synthesis optimization
    krg_start_stage "4_post_syn_opt_rtl_flow"
    
# set_db / .invs_temp_dir ${_OUTPUTS_PATH}/genus_invs_pred 
# syn_opt -spatial
# ## generate reports to save the encounter stats
# write_snapshot -innovus -outdir $_REPORTS_PATH -tag syn_opt_physical 
# report_summary -outdir $_REPORTS_PATH
}

#################################################################
#                     Post Synthesis Reports                    #
#################################################################
# Report QoR maybe slower in large scale MMMC use -no_power option
# Use -power option to get both dynamic and leakage power in dominent view report_gates
krg_report_timing $design(synthesis_reports)
set post_synth_reports [list \
    report_area \
    report_gates \
    report_hierarchy \
    report_design_rules \
    report_dp \
    report_qor \
]
foreach rpt $post_synth_reports {
    krg_message "$rpt" medium
    $rpt
    $rpt > "$design(synthesis_reports)/$this_run(stage)/${rpt}.rpt"
}

report_dp > $_REPORTS_PATH/${DESIGN}_datapath_incr.rpt
report messages > $_REPORTS_PATH/${DESIGN}_messages.rpt
report_gates -yield > $_REPORTS_PATH/${DESIGN}_gates_yeild.rpt
#################################################################
#                     Exporting the Design                      #
#################################################################
if {$phys_synth_type == "floorplan"} {
    krg_start_stage "export_post_synth_design_ispatial"

    # Write out a database for loading in Innovus/Voltus/Tempus
    # ---------------------------------------------------------
    krg_message "Exporting the design Database to $design(postsyn_db_base_name_ispatial)"
    write_db -common $design(postsyn_db_ispatial)

    # Write out a netlist for simulation or Innovus
    # ---------------------------------------------
    krg_message "Writing the post synthesis netlist to $design(postsyn_netlist_ispatial)"
    write_netlist -lec $design(TOPLEVEL) -depth 0 > $design(postsyn_netlist_ispatial)
    write_do_lec -golden_design fv_map -revised_design $design(postsyn_netlist_ispatial) -logfile ${_LOG_PATH}/rtl2intermediate.lec.log > ${_OUTPUTS_PATH}/rtl2intermediatesynmap.lec.tcl

    write_sdc
    # Write out SDF for backannotation simulation
    # -------------------------------------------
    krg_message "Writing the post synthesis SDF"
    write_sdf > $design(postsyn_sdf_ispatial)
} else {
    krg_start_stage "export_post_synth_rtl_floorplanning"

    # Write out a database for loading in Innovus/Voltus/Tempus
    # ---------------------------------------------------------
    krg_message "Exporting the design Database to $design(postsyn_db_base_name_rtl_flow)"
    write_db -common $design(postsyn_db_rtl_flow)

    # Write out a netlist for simulation or Innovus
    # ---------------------------------------------
    krg_message "Writing the post synthesis netlist to $design(postsyn_netlist_rtl_flow)"
    write_netlist $design(TOPLEVEL) -depth 0 > $design(postsyn_netlist_rtl_flow)

    # Write out SDF for backannotation simulation
    # -------------------------------------------
    krg_message "Writing the post synthesis SDF"
    write_sdf > $design(postsyn_sdf_rtl_flow)
}


######################################################################################################
## Final: write Innovus file set (verilog, SDC, config, etc.)
######################################################################################################

# write_snapshot -innovus -outdir $_REPORTS_PATH -tag final_physical 
# report_summary -directory $_REPORTS_PATH

## write_hdl  > ${_OUTPUTS_PATH}/${DESIGN}_m.v
## write_script > ${_OUTPUTS_PATH}/${DESIGN}_m.script
## write_sdc > ${_OUTPUTS_PATH}/${DESIGN}_m.sdc

krg_message "!!!!!!!!!!!!!!!!!!! Genus Synthesis Successful !!!!!!!!!!!!!!!!!!!!!"
