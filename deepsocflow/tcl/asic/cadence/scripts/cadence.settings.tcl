##############################################################################
# Project   : DeepSoCFlow CGRA4ML
# Script    : cadence.settings.tcl
# Purpose   : Tool-specific database settings for Genus, Innovus, and Voltus
##############################################################################
# Author    : Ravidu Munasinghe <raviduhm@gmail.com>
# Org       : Kastner Research Group | ENTC UoM
# Created   : 2026-05-14
# Modified  : 2026-06-14
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

    # Use Non-Scan Flops fro mapping, if you use krg_set_dft_dfm_settings proc then this setting will be true 
    set_db use_scan_seqs_for_non_dft false

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
    set_db innovus_executable            $env(innovus_exe) ; # Set path to innovus executable to used by syn_opt -spatial
    set_db invs_temp_dir                 $design(innovus_dir)
    exec bash -c "touch $design(workdir)/invs_postexport_report_script.tcl"
    set_db invs_postexport_report_script "$design(workdir)/invs_postexport_report_script.tcl"
    # This feature is not available for academic uses
    # exec bash -c "touch $design(workdir)/invs_postload_script.tcl"
    # set_db invs_postload_script          "$design(workdir)/invs_postload_script.tcl" 

    # Floorplan debug settings
    set_db message:PHYS-171 .severity    Error; # Components not present in netlist
    set_db message:PHYS-197 .severity    Error; # Large instance in netlist with no placement
    set_db fail_on_error_mesg            true
    set_db find_fuzzy_match              true
    
    # Conformal Lint Settings
    set_db retime_verification_flow            true 
    set_db verification_directory_naming_style $design(conformal_dir)/%s

    set_db hdl_track_filename_row_col      true ; # impacts runtime and memory
    
    # krg_set_predict_floorplan_settings
    proc krg_set_predict_floorplan_settings {} {
        set_db predict_floorplan_allow_core_reshape     true
        set_db predict_floorplan_allow_illegal_macro    false
        set_db predict_floorplan_keep_fences            false
        set_db predict_floorplan_enable_during_generic  true
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
    }
    
    # krg_set_dft_settings
    proc krg_set_dft_dfm_settings {} {
        global design
        set_db use_scan_seqs_for_non_dft true
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

    # Basic Settings
    set_multi_cpu_usage -local_cpu  max
    set_db design_process_node      $PROCESS_NODE
    set_db design_tech_node         $TECH_NODE
    set_db design_flow_effort       extreme

    ## Floorplan Settings
    ###############################
    proc krg_floorplan_settings {} {
        global krg_iu_vars
        set_db design_bottom_routing_layer  $krg_iu_vars(sam_tech,min_route_layer)
        set_db design_top_routing_layer     $krg_iu_vars(sam_tech,max_route_layer)
        
        # Site Settings
        if { $krg_iu_vars(sam_tech,sc_arch_name) == "sc6mcz" } {
            set_db floorplan_row_site_width odd
        } else {
            set_db floorplan_row_site_width even
        }
        set_db floorplan_row_site_height even

        set_db floorplan_snap_all_corners_to_grid  true
        set_db floorplan_snap_block_grid           finfet_manufacturing
        set_db floorplan_snap_constraint_grid      finfet_inst
        set_db floorplan_snap_core_grid            finfet_placement
        set_db floorplan_snap_die_grid             finfet_manufacturing
        set_db floorplan_snap_io_grid              finfet_manufacturing
        set_db floorplan_snap_place_blockage_grid  inst
    } 
    
    ## Power Grid Settings
    ###############################
    proc krg_power_grid_rings_settings {} {
        global krg_iu_vars

        set_db add_rings_avoid_short 1 
        set_db add_rings_target default 
        set_db add_rings_extend_over_row 1 
        set_db add_rings_ignore_rows 0 
        set_db add_rings_skip_shared_inner_ring none 
        set_db add_rings_stacked_via_top_layer $krg_iu_vars(layer_name,14) 
        set_db add_rings_stacked_via_bottom_layer $krg_iu_vars(layer_name,1) 
        set_db add_rings_via_using_exact_crossover_size 1 
        set_db add_rings_orthogonal_only true 
        set_db add_rings_skip_via_on_pin {  standardcell } 
        set_db add_rings_skip_via_on_wire_shape {  noshape }
    }

    proc krg_power_grid_rings_settings {} {
        global krg_iu_vars

        set_db add_rings_avoid_short 1 
        set_db add_rings_target default 
        set_db add_rings_extend_over_row 1 
        set_db add_rings_ignore_rows 0 
        set_db add_rings_skip_shared_inner_ring none 
        set_db add_rings_stacked_via_top_layer $krg_iu_vars(layer_name,14) 
        set_db add_rings_stacked_via_bottom_layer $krg_iu_vars(layer_name,1) 
        set_db add_rings_via_using_exact_crossover_size 1 
        set_db add_rings_orthogonal_only true 
        set_db add_rings_skip_via_on_pin {  standardcell } 
        set_db add_rings_skip_via_on_wire_shape {  noshape }
    }
    proc krg_upper_power_grid_M14_stripes_settings {} {
        global krg_iu_vars

        set_db add_stripes_ignore_block_check false
        set_db add_stripes_break_at none
        set_db add_stripes_route_over_rows_only false
        set_db add_stripes_rows_without_stripes_only false
        set_db add_stripes_extend_to_closest_target ring
        set_db add_stripes_stop_at_last_wire_for_area false
        set_db add_stripes_partial_set_through_domain false
        set_db add_stripes_ignore_non_default_domains false
        set_db add_stripes_trim_antenna_back_to_shape block_ring
        set_db add_stripes_spacing_type edge_to_edge
        set_db add_stripes_spacing_from_block 0
        set_db add_stripes_stripe_min_length stripe_width
        set_db add_stripes_stacked_via_top_layer $krg_iu_vars(layer_name,14)
        set_db add_stripes_stacked_via_bottom_layer $krg_iu_vars(layer_name,3)
        set_db add_stripes_via_using_exact_crossover_size false
        set_db add_stripes_split_vias true
        set_db add_stripes_orthogonal_only true
        set_db add_stripes_opt_stripe_for_routing_track shift
        set_db add_stripes_allow_jog { padcore_ring  block_ring }
        set_db add_stripes_skip_via_on_pin {  cover block  standardcell }
        set_db add_stripes_skip_via_on_wire_shape {  noshape   }
    }

    proc krg_upper_power_grid_M13_stripes_blocks_settings {} {
        global krg_iu_vars

        set_db add_stripes_ignore_block_check false
        set_db add_stripes_break_at none
        set_db add_stripes_route_over_rows_only false
        set_db add_stripes_rows_without_stripes_only false
        set_db add_stripes_extend_to_closest_target ring
        set_db add_stripes_stop_at_last_wire_for_area false
        set_db add_stripes_partial_set_through_domain false
        set_db add_stripes_ignore_non_default_domains false
        set_db add_stripes_trim_antenna_back_to_shape block_ring
        set_db add_stripes_spacing_type edge_to_edge
        set_db add_stripes_spacing_from_block 0
        set_db add_stripes_stripe_min_length stripe_width
        set_db add_stripes_stacked_via_top_layer $krg_iu_vars(layer_name,14)
        set_db add_stripes_stacked_via_bottom_layer $krg_iu_vars(layer_name,13)
        set_db add_stripes_via_using_exact_crossover_size false
        set_db add_stripes_split_vias true
        set_db add_stripes_orthogonal_only true
        set_db add_stripes_opt_stripe_for_routing_track shift
        set_db add_stripes_allow_jog { padcore_ring  block_ring }
        set_db add_stripes_skip_via_on_pin {  cover block  standardcell }
        set_db add_stripes_skip_via_on_wire_shape {  noshape   }
    }

    proc krg_upper_power_grid_M13_stripes_settings {} {
        global krg_iu_vars

        set_db add_stripes_ignore_block_check false
        set_db add_stripes_break_at none
        set_db add_stripes_route_over_rows_only false
        set_db add_stripes_rows_without_stripes_only false
        set_db add_stripes_extend_to_closest_target ring
        set_db add_stripes_stop_at_last_wire_for_area false
        set_db add_stripes_partial_set_through_domain false
        set_db add_stripes_ignore_non_default_domains false
        set_db add_stripes_trim_antenna_back_to_shape block_ring
        set_db add_stripes_spacing_type edge_to_edge
        set_db add_stripes_spacing_from_block 0
        set_db add_stripes_stripe_min_length stripe_width
        set_db add_stripes_stacked_via_top_layer $krg_iu_vars(layer_name,14)
        set_db add_stripes_stacked_via_bottom_layer $krg_iu_vars(layer_name,4)
        set_db add_stripes_via_using_exact_crossover_size false
        set_db add_stripes_split_vias true
        set_db add_stripes_orthogonal_only true
        set_db add_stripes_opt_stripe_for_routing_track shift
        set_db add_stripes_allow_jog { padcore_ring  block_ring }
        set_db add_stripes_skip_via_on_pin {  cover block  standardcell }
        set_db add_stripes_skip_via_on_wire_shape {  noshape   }
    }
    proc krg_lower_power_grid_block_rings_settings {} {
        global krg_iu_vars

        set_db add_rings_avoid_short 1 
        set_db add_rings_target core_ring 
        set_db add_rings_extend_over_row 1 
        set_db add_rings_ignore_rows 1 
        set_db add_rings_skip_shared_inner_ring none 
        set_db add_rings_stacked_via_top_layer $krg_iu_vars(layer_name,14) 
        set_db add_rings_stacked_via_bottom_layer $krg_iu_vars(layer_name,1) 
        set_db add_rings_via_using_exact_crossover_size 1 
        set_db add_rings_orthogonal_only true 
        set_db add_rings_skip_via_on_pin {  standardcell } 
        set_db add_rings_skip_via_on_wire_shape {  noshape }
    }

    proc krg_lower_power_grid_sram_stripes_settings {} {
        global krg_iu_vars

        set_db add_stripes_ignore_block_check false
        set_db add_stripes_break_at none
        set_db add_stripes_route_over_rows_only false
        set_db add_stripes_rows_without_stripes_only false
        set_db add_stripes_extend_to_closest_target { ring }
        set_db add_stripes_stop_at_last_wire_for_area false
        set_db add_stripes_partial_set_through_domain false
        set_db add_stripes_ignore_non_default_domains false
        set_db add_stripes_trim_antenna_back_to_shape none
        set_db add_stripes_spacing_type edge_to_edge
        set_db add_stripes_spacing_from_block 0
        set_db add_stripes_stripe_min_length stripe_width
        set_db add_stripes_stacked_via_top_layer $krg_iu_vars(layer_name,14)
        set_db add_stripes_stacked_via_bottom_layer $krg_iu_vars(layer_name,5)
        set_db add_stripes_via_using_exact_crossover_size false
        set_db add_stripes_split_vias true
        set_db add_stripes_orthogonal_only true
        set_db add_stripes_opt_stripe_for_routing_track shift
        set_db add_stripes_allow_jog { padcore_ring  block_ring }
        set_db add_stripes_skip_via_on_pin {  standardcell }
        set_db add_stripes_skip_via_on_wire_shape {  noshape   }
    }

    proc krg_lower__D5_power_grid_stripes_settings {} {
        global krg_iu_vars

        set_db add_stripes_ignore_block_check false
        set_db add_stripes_break_at none
        set_db add_stripes_route_over_rows_only false
        set_db add_stripes_rows_without_stripes_only true
        set_db add_stripes_extend_to_closest_target ring
        set_db add_stripes_stop_at_last_wire_for_area false
        set_db add_stripes_partial_set_through_domain false
        set_db add_stripes_ignore_non_default_domains false
        set_db add_stripes_trim_antenna_back_to_shape block_ring
        set_db add_stripes_spacing_type edge_to_edge
        set_db add_stripes_spacing_from_block 0
        set_db add_stripes_stripe_min_length stripe_width
        set_db add_stripes_stacked_via_top_layer $krg_iu_vars(layer_name,14)
        set_db add_stripes_stacked_via_bottom_layer $krg_iu_vars(layer_name,1)
        set_db add_stripes_via_using_exact_crossover_size false
        set_db add_stripes_split_vias true
        set_db add_stripes_orthogonal_only true
        set_db add_stripes_opt_stripe_for_routing_track shift
        set_db add_stripes_allow_jog { padcore_ring  block_ring }
        set_db add_stripes_skip_via_on_pin {  block  standardcell }
        set_db add_stripes_skip_via_on_wire_shape {  noshape   }
    }

    proc krg_lower_M4_power_grid_stripes_settings {} {
        global krg_iu_vars

        set_db add_stripes_ignore_block_check false
        set_db add_stripes_break_at none
        set_db add_stripes_route_over_rows_only false
        set_db add_stripes_rows_without_stripes_only true
        set_db add_stripes_extend_to_closest_target ring
        set_db add_stripes_stop_at_last_wire_for_area false
        set_db add_stripes_partial_set_through_domain false
        set_db add_stripes_ignore_non_default_domains false
        set_db add_stripes_trim_antenna_back_to_shape block_ring
        set_db add_stripes_spacing_type edge_to_edge
        set_db add_stripes_spacing_from_block 0
        set_db add_stripes_stripe_min_length stripe_width
        set_db add_stripes_stacked_via_top_layer $krg_iu_vars(layer_name,14)
        set_db add_stripes_stacked_via_bottom_layer $krg_iu_vars(layer_name,3)
        set_db add_stripes_via_using_exact_crossover_size false
        set_db add_stripes_split_vias true
        set_db add_stripes_orthogonal_only true
        set_db add_stripes_opt_stripe_for_routing_track shift
        set_db add_stripes_allow_jog { padcore_ring  block_ring }
        set_db add_stripes_skip_via_on_pin {  block  standardcell }
        set_db add_stripes_skip_via_on_wire_shape {  noshape   }
    }

    proc krg_power_grid_floating_stripe_route_special_settings {} {
        reset_db route_special_*
        set_db route_special_via_connect_to_shape { ring stripe blockring }
    }
    proc krg_power_grid_M1_stripes_settings {} {
        set_db route_special_via_connect_to_shape { noshape }
    }

    proc krg_power_grid_M3_stripes_settings {} {
        global krg_iu_vars
        
        set_db add_stripes_ignore_block_check false
        set_db add_stripes_break_at none
        set_db add_stripes_route_over_rows_only true
        set_db add_stripes_rows_without_stripes_only false
        set_db add_stripes_extend_to_closest_target none
        set_db add_stripes_stop_at_last_wire_for_area false
        set_db add_stripes_partial_set_through_domain false
        set_db add_stripes_ignore_non_default_domains false
        set_db add_stripes_trim_antenna_back_to_shape core_ring
        set_db add_stripes_spacing_type edge_to_edge
        set_db add_stripes_spacing_from_block 0
        set_db add_stripes_stripe_min_length stripe_width
        set_db add_stripes_stacked_via_top_layer $krg_iu_vars(layer_name,6)
        set_db add_stripes_stacked_via_bottom_layer $krg_iu_vars(layer_name,1)
        set_db add_stripes_via_using_exact_crossover_size false
        set_db add_stripes_split_vias true
        set_db add_stripes_orthogonal_only true
        set_db add_stripes_allow_jog none
        set_db add_stripes_skip_via_on_pin {  block }
        set_db add_stripes_skip_via_on_wire_shape {  noshape   }
    }

    ## Global Placement Settings
    ###############################
    proc krg_global_placement_settings {} {
        set_db place_global_clock_gate_aware false
        set_db place_global_clock_power_driven true
        set_db place_global_reorder_scan false 
        set_db place_global_ignore_scan true
        set_db place_global_timing_effort high
        set_db place_global_cong_effort auto
    }
    
    ## Detailed Placement Settings
    ###############################
    proc krg_detailed_placement_settings {} {
        set_db place_detail_activity_power_driven false
        set_db place_detail_swap_eeq_cells true
    }

    ## Placement Optimization Settings
    ###############################
    proc krg_placement_optimization_settings {} {
        set_db opt_fix_fanout_load true; # Force optimization to correct max_fanout violations
        set_db opt_new_inst_prefix "place_opt_inst_"
        set_db opt_new_net_prefix  "place_opt_net_"
    }

    #     # Add fill ties checker board
    #     set_db add_tieoffs_cells         "$tech(TIE_HIGH_CELL) $tech(TIE_LOW_CELL) "
    #     set_db add_tieoffs_prefix        $tech(TIE_PREFIX)
    #     set_db add_tieoffs_max_fanout    20
    #     set_db add_tieoffs_max_distance  250

    ## Timing Analysis OCV Settings
    ###############################

    proc krg_timing_analysis_aocv_settings {} {
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

    proc krg_timing_analysis_socv_settings {} {
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

    ## Clock Tree Synthesis Settings
    ###############################
    proc krg_clock_tree_synthesis_settings {} {
        set_db opt_new_inst_prefix "cts_opt_inst_"
        set_db opt_new_net_prefix  "cts_opt_net_"   
        set_db route_detail_post_route_spread_wire    false
        set_db opt_skew_ccopt extreme
    }
    # ## Routing Settings
    # ##################################
    # set_db route_design_concurrent_minimize_via_count_effort high
    # set_db route_design_antenna_diode_insertion              true
    # set_db route_design_antenna_cell_name                    $tech(ANTENNA_CELL)
    # ### don't use pin as a jumper - make one contact
    # set_db route_design_allow_pin_as_feedthru                false
    # ### don't taper to the output pin causing EM issues
    # set_db route_design_detail_no_taper_on_output_pin        true

    proc krg_routing_settings {} {
        global TECH_NODE

        set_db route_process_node           $TECH_NODE
 
        set_db add_route_vias_auto          false
        set_db add_route_vias_ndr_only      true

        set_db route_via_weight ""
        set_db route_via_weight "S*BAR* 200"
        set_db route_via_weight "V*_DFM 150"
        set_db route_via_weight "MD_*_DFM 150"
        set_db route_via_weight "S*_DFM 150"
        set_db route_via_weight "NR_VIA1_VxBAR_VV_* -1"

        set_db route_detail_post_route_spread_wire    false
        set_db route_detail_use_multi_cut_via_effort  high
        set_db route_detail_post_route_swap_via       true
        set_db route_with_si_driven                   true
        set_db route_allow_pin_as_feedthru            none

    } 

        #     set_db add_fillers_cells         $tech(FILL_CELLS)
    #     set_db add_fillers_check_drc     true
    #     set_db add_fillers_prefix        $tech(FILL_CELL_PREFIX)

}

###################################
# General Voltus Settings
###################################
if {$runtype == "power"} {}