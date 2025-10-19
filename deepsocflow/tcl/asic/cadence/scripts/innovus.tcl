##########################################################
###     MAKE SURE YOU RAN innovus -stylus !!!!!!!!     ###
###         get_common_ui_map legacy_command           ###
##########################################################
gui_set_ui main -geometry "1920x1020+0+0"

set design(TOPLEVEL) "dnn_engine"
set runtype "pnr"
set debug_file "debug.innovus.txt"

####################################################
# Starting Stage - Load defines and technology
####################################################
# Load general procedures
source ../../deepsocflow/tcl/asic/cadence/scripts/cadence.procedures.tcl -quiet

uom_start_stage "loading_basic_settings"

# Load the specific definitions for this project
source ../../deepsocflow/tcl/asic/cadence/inputs/cadence.$design(TOPLEVEL).defines -quiet

# Load the library paths and definitions for this technology files
source ../../deepsocflow/tcl/asic/cadence/libraries/cadence.libraries.$TECHNOLOGY.tcl -quiet
source ../../deepsocflow/tcl/asic/cadence/libraries/cadence.libraries.$SC_TECHNOLOGY.tcl -quiet
source ../../deepsocflow/tcl/asic/cadence/libraries/cadence.srams.$TECHNOLOGY.tcl -quiet
source ../../deepsocflow/tcl/asic/cadence/libraries/cadence.srams.$SC_TECHNOLOGY.tcl -quiet
if {$design(FULLCHIP_OR_MACRO) == "FULLCHIP"} {
    source $design(libraries_dir)/libraries.$IO_TECHNOLOGY.tcl -quiet
}

####################################################
# Print values to debug file
####################################################
set var_list {runtype}
set dic_list {paths_tech tech_files design}
uom_print_debug_data w $debug_file "after everything was loaded" $var_list $dic_list

####################################################
#               SDC File Generation                
####################################################
uom_create_sdc_file

####################################################
# Init Design
####################################################
enable_metrics -on
uom_start_stage "1_init_design"

# Global Nets
set_db init_ground_nets $design(all_ground_nets)
set_db init_power_nets  $design(all_power_nets)

# MMMC
uom_message "Suppressing the following messages that are reported due to the LIB definitions"
uom_message "$tech(LIB_SUPPRESS_MESSAGES_INNOVUS)"
set_message -suppress -id $tech(LIB_SUPPRESS_MESSAGES_INNOVUS)

if {$timing_lib_type == "nldm"} {
    uom_message "Loading MMMC File with NLDM Libs"
    read_mmmc $design(mmmc_nldm_view_file)
} else {
    uom_message "Loading MMMC File with CCS & OCV Libs"
    read_mmmc $design(mmmc_ocv_view_file)
}

# LEFs
uom_message "Suppressing the following messages that are reported due to the LEF definitions"
uom_message "$tech(LEF_SUPPRESS_MESSAGES_INNOVUS)"
set_message -suppress -id $tech(LEF_SUPPRESS_MESSAGES_INNOVUS)
uom_message "Reading LEF abstracts"
read_physical -lef $tech_files(ALL_LEFS)

# Post Synthesis Netlist
if {$phys_synth_type == "floorplan"} {
	read_netlist $design(postsyn_netlist_ispatial)
} else {
	read_netlist $design(postsyn_netlist_rtl_flow)
}

# Import and initialize design
init_design

# Load general settings
source ../../deepsocflow/tcl/asic/cadence/scripts/cadence.settings.tcl -quiet

# Create cost groups
uom_default_cost_groups

# Connect Global Net
# ------------------
# Connect standard cells to VDD and GND
connect_global_net $design(digital_gnd) -pin $tech(STANDARD_CELL_GND) -all -verbose
connect_global_net $design(digital_vdd) -pin $tech(STANDARD_CELL_VDD) -all -verbose
# Connect tie cells
connect_global_net $design(digital_vdd) -type tie_hi -all -verbose
connect_global_net $design(digital_gnd) -type tie_lo -all -verbose

if {$design(FULLCHIP_OR_MACRO) == "FULLCHIP"} {
    # Connect pads to IO and CORE voltages
    #       -netlist_override is needed, since GENUS connects these pins to UNCONNECTED during synthesis
    connect_global_net $design(io_vdd)      -pin $tech(IO_VDDIO)    -hinst i_${design(IO_MODULE)} -netlist_override
    connect_global_net $design(io_gnd)      -pin $tech(IO_GNDIO)    -hinst i_${design(IO_MODULE)} -netlist_override
    connect_global_net $design(digital_vdd) -pin $tech(IO_VDDCORE)  -hinst i_${design(IO_MODULE)} -netlist_override
    connect_global_net $design(digital_gnd) -pin $tech(IO_GNDCORE)  -hinst i_${design(IO_MODULE)} -netlist_override
}

# Reporting & Save
uom_create_stage_reports -write_db yes

# Show Unplaced Macros
set_preference ShowUnplacedInst 1

####################################################
# Floorplan
####################################################
uom_start_stage "2_floorplan"
source ../../deepsocflow/tcl/asic/cadence/inputs/cadence.$design(TOPLEVEL).floorplan.defines -quiet

if {$phys_synth_type == "floorplan"} {
    # You need to read a .def file for the floorplan to enable physical synthesis
    uom_message "Loading the floorplan DEF"
    read_def $design(floorplan_def)
} else {
    # Specify Floorplan
    create_floorplan -site $tech(STANDARD_CELL_SITE) -match_to_site \
        -core_density_size $design(floorplan_ratio) $design(floorplan_utilization) {*}$design(floorplan_space_to_core)
    gui_fit

    ####################################################
    # Place Pins/IO Pads
    ####################################################
    # Set up pads (for fullchip) or pins (for macro)
    if {$design(FULLCHIP_OR_MACRO) == "FULLCHIP"} {
        # Reload the IO file after resizing the floorplan
        read_io_file $design(io_file)
        # Add IO Fillers
        add_io_fillers -cells $tech(IO_FILLERS) -prefix IOFILLER
        # Connect Pad Rings
        route_special -connect {pad_ring} -nets "$design(digital_gnd) $design(digital_vdd) \
                                $design(io_gnd) $design(io_vdd)"
    } elseif {$design(FULLCHIP_OR_MACRO) == "MACRO"} {
        # Spread pins
        set pins_to_spread [get_db ports .name]
        edit_pin -spread_direction clockwise -spread_type center \
                -layer M5 -side Top -fix_overlap 1 -spacing 1 \
                -pin $design(CLOCK_PIN)
        edit_pin -spread_direction clockwise -spread_type center \
                -layer M3 -side Top -fix_overlap 1 -spacing 1 \
                -pin $design(TOP_INPUT_PINS)
        edit_pin -spread_direction clockwise -spread_type center \
                -layer M4 -side Left -fix_overlap 1 -spacing 1 \
                -pin $design(LEFT_INPUT_PINS)
        edit_pin -spread_direction clockwise -spread_type center \
                -layer M4 -side Right -fix_overlap 1 -spacing 1 \
                -pin $design(RIGHT_OUTPUT_PINS)       
    }
    gui_redraw

    ####################################################
    # Place Hard Macros
    ####################################################
    # Relative Floorplanning
    # ----------------------
    # Note that edges are as follows:
    #       0 - Bottom
    #       1 - Left
    #       2 - Top
    #       3 - Right
    #       Syntax: { ref_edge offset target_edge }
    delete_relative_floorplan -all

    # Place the SRAM WEIGHTS 0 macro 35u from the bottom and 25u from the left of the core boundry
    create_relative_floorplan -ref_type core_boundary -ref $design(TOPLEVEL) -place $design(SRAM_WEIGHTS_0) \
            -horizontal_edge_separate { 1 0 1 } -vertical_edge_separate { 3 0 3 } -orient R0

    # Place the SRAM WEIGHTS 1 macro 35u from the bottom and 25u from the left of the core boundry
    create_relative_floorplan -ref_type core_boundary -ref $design(TOPLEVEL) -place $design(SRAM_WEIGHTS_1) \
            -horizontal_edge_separate { 0 0 0 } -vertical_edge_separate { 3 0 3 } -orient R0

    # Place the SRAM EDGES macro 35u from the bottom and 25u from the left of the core boundry
    create_relative_floorplan -ref_type core_boundary -ref $design(TOPLEVEL) -place $design(SRAM_EDGES_0) \
            -horizontal_edge_separate { 1 0 1 } -vertical_edge_separate { 1 0 1 } -orient R180

    # Add halos around macros
    # NOTE: snap_to_site flag is important here. otherwise there will be a potential follow pins discontinuity
    create_place_halo -halo_deltas {4 4 4 4} -all_macros -snap_to_site
    create_route_halo -bottom_layer $design(MIN_ROUTE_LAYER) -space 4 -top_layer $design(MAX_ROUTE_LAYER_SRAM) -insts [list $design(SRAM_WEIGHTS_0) $design(SRAM_WEIGHTS_1) $design(SRAM_EDGES_0)]

    # Add Power Rings around Macros
    deselect_obj -all
    select_obj $design(SRAM_WEIGHTS_0)
    add_rings -around selected -type block_rings -nets "$design(digital_gnd) $design(digital_vdd)" \
            -layer $design(sram_ring_layers)  -width 1 -spacing 1

    deselect_obj -all
    select_obj $design(SRAM_WEIGHTS_1)
    add_rings -around selected -type block_rings -nets "$design(digital_gnd) $design(digital_vdd)" \
            -layer $design(sram_ring_layers)  -width 1 -spacing 1

    deselect_obj -all
    select_obj $design(SRAM_EDGES_0)
    add_rings -around selected -type block_rings -nets "$design(digital_gnd) $design(digital_vdd)" \
            -layer $design(sram_ring_layers)  -width 1 -spacing 1
            
    # Connect Power Pins of SRAMs
    route_special -connect {block_pin} -nets "$design(digital_gnd) $design(digital_vdd)" \
            -block_pin_layer_range {1 4} \
            -block_pin use_lef \
            -detailed_log

    ####################################################
    # Connect Power
    ####################################################
    # Create Core Ring
    add_rings -type core_rings -nets $design(core_ring_nets) -center 1 -follow core \
            -layer $design(core_ring_layers) -width $design(core_ring_width) -spacing $design(core_ring_spacing)

    # Connect Follow Pins
    route_special -connect {core_pin} -nets $design(core_ring_nets) -pad_pin_port_connect all_geom -detailed_log

    if {$design(FULLCHIP_OR_MACRO) == "FULLCHIP"} {
        # Connect pads to the rings
        route_special -connect {pad_pin} -nets $design(core_ring_nets) -pad_pin_port_connect all_geom -detailed_log
    }

    # Add End Caps
    add_endcaps -prefix $tech(END_CAP_PREFIX)

    # Add Well Taps
    add_well_taps -cell $tech(FILL_TIE_CELL) -checker_board -prefix $tech(FILL_TIE_PREFIX) \
            -cell_interval [expr 2 * $design(WELLTAP_RULE)]
    check_well_taps -max_distance $design(WELLTAP_RULE)

    # Add Stripes
    set_db add_stripes_ignore_block_check true
    set_db add_stripes_break_at none
    set_db add_stripes_route_over_rows_only false
    set_db add_stripes_rows_without_stripes_only false
    set_db add_stripes_extend_to_closest_target none
    set_db add_stripes_stop_at_last_wire_for_area false
    set_db add_stripes_ignore_non_default_domains true
    set_db add_stripes_trim_antenna_back_to_shape none
    set_db add_stripes_spacing_type edge_to_edge
    set_db add_stripes_spacing_from_block 0
    set_db add_stripes_stripe_min_length stripe_width
    set_db add_stripes_stacked_via_top_layer AP
    set_db add_stripes_stacked_via_bottom_layer M1
    set_db add_stripes_via_using_exact_crossover_size false
    set_db add_stripes_split_vias false
    set_db add_stripes_orthogonal_only true
    set_db add_stripes_allow_jog { block_ring }
    set_db add_stripes_skip_via_on_pin {  standardcell }
    set_db add_stripes_skip_via_on_wire_shape {  noshape   }
    add_stripes -nets {VDD GND} -layer M7 -direction vertical -width 1 -spacing 1 \
    -set_to_set_distance 30 -start_from left -start_offset 5.5 -stop_offset 0 \
    -switch_layer_over_obs false -max_same_layer_jog_length 2 -pad_core_ring_top_layer_limit AP \
    -pad_core_ring_bottom_layer_limit M1 -block_ring_top_layer_limit AP -block_ring_bottom_layer_limit M1 \
    -use_wire_group 0 -snap_wire_center_to_grid none

    set_db add_stripes_ignore_block_check true
    set_db add_stripes_break_at none
    set_db add_stripes_route_over_rows_only false
    set_db add_stripes_rows_without_stripes_only false
    set_db add_stripes_extend_to_closest_target {ring stripe}
    set_db add_stripes_stop_at_last_wire_for_area false
    set_db add_stripes_partial_set_through_domain true
    set_db add_stripes_ignore_non_default_domains false
    set_db add_stripes_trim_antenna_back_to_shape none
    set_db add_stripes_spacing_type edge_to_edge
    set_db add_stripes_spacing_from_block 0
    set_db add_stripes_stripe_min_length stripe_width
    set_db add_stripes_stacked_via_top_layer M9
    set_db add_stripes_stacked_via_bottom_layer M4
    set_db add_stripes_via_using_exact_crossover_size false
    set_db add_stripes_split_vias false
    set_db add_stripes_orthogonal_only true
    set_db add_stripes_allow_jog { block_ring }
    set_db add_stripes_skip_via_on_pin {  standardcell }
    set_db add_stripes_skip_via_on_wire_shape {  noshape   }
    add_stripes -nets {VDD GND} -layer M8 -direction horizontal -width 1 -spacing 1 \
    -set_to_set_distance 30 -over_power_domain 0 -start_from bottom -start_offset 5.5 \
    -stop_offset 0 -switch_layer_over_obs false -max_same_layer_jog_length 2 \
    -pad_core_ring_top_layer_limit M9 -pad_core_ring_bottom_layer_limit M1 -block_ring_top_layer_limit M9 \
    -block_ring_bottom_layer_limit M1 -use_wire_group 0 -snap_wire_center_to_grid none

    # Export floorplan DEF
    # This can be used for loading the floorplan in subsequent runs
    #   And also as a basis for physically-aware synthesis
    write_def -floorplan -no_std_cells "$design(floorplan_def)"
}

# Reporting & Save
check_connectivity -type special > $design(pnr_reports)/2_floorplan/power_connectivity.rpt
uom_create_stage_reports -write_db yes -check_drc yes 

# Screenshot of the floorplan
gui_fit
write_to_gif $design(pnr_reports)/screenshots/1_Floorplan.gif

####################################################
# Placement
####################################################
uom_start_stage "3_placement"

# Add M2 routing blockages around vertical power stripes to prevent M2 routing DRCs near them
#uom_add_m2_stripe_blockage

set_db place_global_cong_effort auto
set_db opt_new_inst_prefix "place_opt_inst_"
set_db opt_new_net_prefix  "place_opt_net_"
place_opt_design -report_dir "$design(reports_dir)/pnr/3_placement/place_opt_design"

# Add Tie Cells
add_tieoffs -lib_cell "$tech(TIE_HIGH_CELL) $tech(TIE_LOW_CELL)" -prefix $tech(TIE_PREFIX)

# Fix DRV
opt_design -pre_cts -drv 

# Reporting & Save
check_place > $design(pnr_reports)/3_placement/placement_report.rpt
uom_create_stage_reports -write_db yes -check_drc yes

# Screenshot of the floorplan
gui_fit
write_to_gif $design(pnr_reports)/screenshots/2_Placement.gif

####################################################
# Clock Tree Synthesis
####################################################
uom_start_stage "4_clock_tree_synthesis"

# Load Clock Tree Configuration
reset_ccopt_config
source $design(clock_tree_spec)

set_db opt_new_inst_prefix "cts_opt_inst_"
set_db opt_new_net_prefix  "cts_opt_net_"
# ccopt_design -report_dir "$design(reports_dir)/pnr/4_clock_tree_synthesis/ccopt_design"
clock_opt_design -report_dir "$design(reports_dir)/pnr/4_clock_tree_synthesis/ccopt_design"

# Reporting & Save
if {$timing_lib_type == "ccs_ocv"} {
    set_db timing_analysis_engine             statistical
}
uom_create_stage_reports -write_db yes -check_drc yes -report_timing yes -check_connectivity yes
if {$timing_lib_type == "ccs_ocv"} {
    set_db timing_analysis_engine             static
}

# Open the clock tree debugger and check Clock Tree
#gui_open_ctd

# Post CTS Hold Fixing
# --------------------
uom_start_stage "5_post_cts_hold"
opt_design -post_cts -hold 

# Reporting & Save
if {$timing_lib_type == "ccs_ocv"} {
    set_db timing_analysis_engine             statistical
}
uom_create_stage_reports -write_db yes -check_drc yes -report_timing yes -check_connectivity yes
if {$timing_lib_type == "ccs_ocv"} {
    set_db timing_analysis_engine             static
}

# Screenshot of the floorplan
gui_fit
write_to_gif $design(pnr_reports)/screenshots/3_CTS.gif

####################################################
# Route
####################################################
# Pre Routing
# -----------
uom_start_stage "6_pre_route"

# Get rid of the M2 stripe blockages that are no longer needed and cause annoying DRC violations
#delete_route_blockages -type routes


set_db route_design_with_timing_driven                  true
set_db route_design_detail_use_multi_cut_via_effort     medium
if {$timing_lib_type == "ccs_ocv"} {
    set_db route_design_with_si_driven                  true
    set_db delaycal_enable_si                           true
} else {
    set_db route_design_with_si_driven                  false
    set_db delaycal_enable_si                           false
}


set_db opt_new_inst_prefix "route_opt_inst_"
set_db opt_new_net_prefix "route_opt_net_"
route_opt_design

# Reporting & Save
if {$timing_lib_type == "ccs_ocv"} {
    set_db timing_analysis_engine             statistical
}
uom_create_stage_reports -write_db yes -check_drc yes -report_timing yes -check_connectivity yes -report_hold yes
if {$timing_lib_type == "ccs_ocv"} {
    set_db timing_analysis_engine             static
}

# Post Route Optimization
# -----------------------
uom_start_stage "7_post_route_opt"
opt_design -post_route -setup -hold

set_db route_design_with_timing_driven                  false
set_db route_design_detail_post_route_spread_wire       true
set_db route_design_detail_use_multi_cut_via_effort     high
if {$timing_lib_type == "ccs_ocv"} {
    set_db route_design_with_si_driven                  false
    set_db delaycal_enable_si                           false
}
route_design -wire_opt
route_design -via_opt
set_db route_design_detail_post_route_spread_wire       false
set_db route_design_with_timing_driven                  true
if {$timing_lib_type == "ccs_ocv"} {
    set_db route_design_with_si_driven                  true
    set_db delaycal_enable_si                           true
}

///das
# Add Filler Cells with DRC errors
add_fillers -base_cells $tech(FILL_CELLS) -prefix $tech(FILL_CELL_PREFIX) \
            -check_different_cells true -check_drc -check_min_hole true \
            -check_via_enclosure true -fill_gap
# Clean DRC errors
add_fillers -base_cells $tech(FILL_CELLS) -prefix $tech(FILL_CELL_PREFIX) \
            -check_different_cells true -check_drc -check_min_hole true \
            -check_via_enclosure true -fill_gap -fix_drc
route_eco -fix_drc

# Reporting & Save
if {$timing_lib_type == "ccs_ocv"} {
    set_db timing_analysis_engine             statistical
}
uom_create_stage_reports -write_db yes -check_drc yes -report_timing yes -check_connectivity yes -report_hold yes
if {$timing_lib_type == "ccs_ocv"} {
    set_db timing_analysis_engine             static
}

# Screenshot of the floorplan
gui_fit
write_to_gif $design(pnr_reports)/screenshots/4_Post_Route.gif

####################################################
# Export & SignOff
####################################################
uom_start_stage "8_signoff"

# Input & Output Port Naming
bitblast_ports $design(TOPLEVEL)

# Write out a netlist for gls simulation
# ---------------------------------------------
uom_message "Writing the post route netlist to $design(postroute_netlist)"
write_netlist -top_module $design(TOPLEVEL) -top_module_first -flat $design(postroute_netlist)

# Write out SDF for backannotation simulation
# -------------------------------------------
uom_message "Writing the post route SDF to $design(postroute_sdf)"
write_sdf -version 3.0 -min_view bc_analysis_view -typical_view tc_analysis_view -max_view wc_analysis_view $design(postroute_sdf) 

####################################################
# Metal & Via Fill
####################################################
///// das
# Add Via Fill
add_via_fill

# Add Metal Fil
add_metal_fill

# Screenshot of the floorplan
gui_fit
write_to_gif $design(pnr_reports)/screenshots/5_Final_Layout.gif