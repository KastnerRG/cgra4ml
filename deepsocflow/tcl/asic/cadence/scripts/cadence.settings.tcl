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

    # HDL & SDC debug Settings
    set_db hdl_language v2001            -quiet
    set_db detailed_sdc_messages         true ; # helps read_sdc

    # Retime Settings
    set_db retime_reg_naming_suffix      __retimed_reg
    set_db retime_async_reset            true

    # Innovus Executable Settings
    set_db innovus_executable            $env(INNOVUS)   ; # Set path to innovus executable to used by syn_opt -spatial

    # Conformal Lint Settings
    set_db  hdl_array_naming_style %s\[%d\] ; # generates <signal>_reg[<bit_width>] format

    # Low Power Settings
    if {$low_power_enabled == "yes"} {
        set opt_leak_to_dyn_ratio        0.5  ; # 0.0 to 1.0
        set design_power_effort          high ; # low|medium|high  

        set_db qos_report_power true 
        set_db time_recovery_arcs true
        set_db timing_use_ecsm_pin_capacitance true
        set_db dp_area_mode true 

        #set_db  lp_clock_gating_prefix <string>
        set_db lp_insert_clock_gating    true
        #set_db  lp_power_unit mW 
        #set_db  lp_toggle_rate_unit /ns 
        set_db   hdl_track_filename_row_col true

    }
    
    # DFM & DFT settings
    if {$design(HAS_SCAN) == "no"} {
        set_db use_scan_seqs_for_non_dft false
        #set_db "design:$DESIGN" .lp_clock_gating_test_signal <test_signal_object> 
        set_db / .optimize_yield true 
        read_dfm <yeild coefficient file.>
    }

    # Synthesis and ispatial settings
    set syn_generic_effort            high    ; # low|medium|high
    set syn_mapping_effort            high    ; # low|medium|high
    set syn_optimize_effort           extreme ; # low|medium|high|extreme
    set opt_spatial_effort            extreme ; # legacy|standard|extreme 
    set congestion_effort             medium  ; # low|medium|high

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