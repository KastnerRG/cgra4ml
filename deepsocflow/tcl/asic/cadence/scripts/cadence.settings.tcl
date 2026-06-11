##############################################################################
# Project   : DeepSoCFlow CGRA4ML
# Script    : cadence.settings.tcl
# Purpose   : Tool-specific database settings for Genus, Innovus, and Voltus
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
#   Centralized settings file sourced by all Cadence EDA flow scripts.
#   Applies set_db attributes for synthesis (Genus), place-and-route
#   (Innovus), and power analysis (Voltus) based on the $runtype variable.
#   Procedure definitions for grouped settings are co-located here under
#   the krg_ prefix.
#
##############################################################################
# Sections:
#   [synthesis] General Genus settings
#               (HDL, retime, Innovus exec, floorplan debug, conformal lint)
#               krg_set_predict_floorplan_settings - iSpatial floorplan prediction
#               krg_set_low_power_settings         - Low power flow attributes
#               krg_set_dft_dfm_settings           - DFT/DFM scan and yield settings
#               krg_set_multibit_settings          - Multibit cell mapping settings
#               krg_set_synthesis_efforts          - syn/map/opt + iSpatial effort levels
#                                                    (generic, map, opt, spatial, congestion,
#                                                     leakage ratio, merge_flops, restructuring)
#   [pnr]       General Innovus settings
#               OCV timing analysis (ccs_ocv), floorplan, global placement, routing
#   [power]     General Voltus settings  [PLACEHOLDER - empty]
##############################################################################
# TODO:
# [ ] Add low-power enabled check before sourcing krg_set_low_power_settings
# [ ] Add HAS_SCAN conditional call for krg_set_dft_dfm_settings
# [ ] Complete Innovus settings
# [ ] Complete Voltus power settings
# Suggestions:
# Remove multibits flops if timing is critical.

# Apply this if you want best QoR but runtime will be affected
# set_db iopt_ultra_optimization true
##############################################################################
# Usage:
#   source cadence.settings.tcl -quiet in genus.tcl
#   Requires $runtype, $design, $tech, $env(INNOVUS) to be set beforehand
##############################################################################

###################################
# General Genus Settings
###################################
set_db source_verbose true ; #Sourcing files will be re.

# Attributes that only Genus understands...
if {$runtype == "synthesis"} {
    # Genus Settings
    set_db information_level             9 ; # The log file will rep.
    set_db hdl_max_loop_limit            100000
    set_db max_cpus_per_server           8
    set_db lp_power_unit mW 

    # Library and Lef Settings
    set_db error_on_lib_lef_pin_inconsistency true

    # HDL & SDC debug Settings
    set_db gen_module_prefix             GEN_MOD_
    set_db hdl_language v2001            -quiet
    set_db detailed_sdc_messages         true ; # helps read_sdc

    # To use timing recovery arc for async reset
    set_db time_recovery_arcs            true

    # Retime Settings
    set_db retime_reg_naming_suffix      __retimed_reg
    set_db retime_async_reset            true
    set_db retime_effort_level           high ; # low|medium|high  

    # Innovus Executable Settings
    set_db innovus_executable            $env(INNOVUS) ; # Set path to innovus executable to used by syn_opt -spatial
    set_db invs_temp_dir                 $design(innovus_dir)
    set_db invs_postexport_report_script "design(workdir)/invs_postexport_report_script.tcl"

    # Floorplan debug settings
    set_db message:PHYS-171 .severity    Error; # Components not present in netlist
    set_db message:PHYS-197 .severity    Error; # Large instance in netlist with no placement
    set_db fail_on_error_mesg            true
    set_db find_fuzzy_match              true
    
    # Conformal Lint Settings
    set_db retime_verification_flow            true 
    set_db verification_directory_naming_style $design(conformal_dir)/%s

    # krg_set_predict_floorplan_settings
    proc krg_set_predict_floorplan_settings {} {
        set_db predict_floorplan_allow_core_reshape     true
        set_db predict_floorplan_allow_illegal_macro    false
        set_db predict_floorplan_enable_during_generic  false
        set_db predict_floorplan_keep_fences            true
    }

    # krg_set_low_power_settings
    proc krg_set_low_power_settings {} {
        set_db design_power_effort             high ; # low|medium|high

        set_db qos_report_power                true
        set_db time_recovery_arcs              true
        set_db timing_use_ecsm_pin_capacitance true
        set_db dp_area_mode                    true

        set_db lp_clock_gating_prefix          lp_clk_gate
        set_db lp_insert_clock_gating          true
        set_db lp_toggle_rate_unit             /ns
        set_db hdl_track_filename_row_col      true ; # impacts runtime and memory
    }
    
    # krg_set_dft_settings
    proc krg_set_dft_dfm_settings {} {
        global design
        set_db use_scan_seqs_for_non_dft false
        #set_db "design:$design(TOPLEVEL)" .lp_clock_gating_test_signal <test_signal_object>
        set_db / .optimize_yield true
        read_dfm <yeild coefficient file.>
    }

    # krg_set_multibit_settings
    proc krg_set_multibit_settings {} {
        set_db use_multibit_cells            true
        set_db multibit_aware_seq_mapping    true
        set_db multibit_mapping_effort_level high
    }
    
    # krg_set_synthesis_efforts
    proc krg_set_synthesis_efforts {} {
        # Synthesis and iSpatial settings
        set_db syn_generic_effort           high    ; # low|medium|high
        set_db syn_map_effort               high    ; # low|medium|high
        set_db syn_opt_effort               extreme ; # low|medium|high|extreme

        set_db opt_spatial_effort           extreme
        set_db congestion_effort            medium
        set_db opt_leakage_to_dynamic_ratio 0.5
        set_db opt_spatial_merge_flops      true
        set_db opt_spatial_restructuring    true
    }
}

###################################
# General Innovus Settings
###################################
if {$runtype == "pnr"} {

    ## Basic Settings
    ###########################
    set_multi_cpu_usage -local_cpu  8
    set_db design_process_node      28
    #set_db design_tech_node         N7

    ## Timing Analysis OCV Settings
    ###############################
    if {$timing_lib_type == "ccs_ocv"} {
        set_db timing_analysis_type               ocv
        set_db timing_analysis_engine             static
        set_db timing_analysis_cppr               both
        set_db timing_analysis_aocv               true
        set_db timing_enable_aocv_slack_based     true
        set_db timing_aocv_analysis_mode          launch_capture
        set_db timing_extract_model_aocv_mode     path_based
        set_db delaycal_equivalent_waveform_type  moments 
        set_db delaycal_equivalent_waveform_model propagation
        set_db timing_derate_aocv_dynamic_delays  false
        set_db timing_enable_si_cppr              true
        set_db timing_library_read_ccs_noise_data true
        set_db timing_aocv_derate_mode            aocv_multiplicative
    }

    ## Floorplan Settings
    ###############################
    set_db add_endcaps_right_edge    $tech(END_CAP_CELL)
    set_db add_endcaps_left_edge     $tech(END_CAP_CELL)
    set_db add_tieoffs_cells         "$tech(TIE_HIGH_CELL) $tech(TIE_LOW_CELL) "
    set_db add_tieoffs_prefix        $tech(TIE_PREFIX)
    set_db add_tieoffs_max_fanout    20
    set_db add_tieoffs_max_distance  250
    set_db add_fillers_cells         $tech(FILL_CELLS)
    set_db add_fillers_check_drc     true
    set_db add_fillers_prefix        $tech(FILL_CELL_PREFIX)
    
    ## Global Placement Settings
    ###############################
    set_db opt_fix_fanout_load true; # Force optimization to correct max_fanout violations

    ## Routing Settings
    ##################################
    set_db route_design_concurrent_minimize_via_count_effort high
    set_db route_design_antenna_diode_insertion              true
    set_db route_design_antenna_cell_name                    $tech(ANTENNA_CELL)
    ### don't use pin as a jumper - make one contact
    set_db route_design_allow_pin_as_feedthru                false
    ### don't taper to the output pin causing EM issues
    set_db route_design_detail_no_taper_on_output_pin        true
}

###################################
# General Voltus Settings
###################################
if {$runtype == "power"} {}