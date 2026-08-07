# Create Floorplan
# ----------------
krg_start_stage "floorplan" yes

krg_floorplan_settings

# Aspect Ratio | Core Utilization | Core Spacing
# ----------------------------------------------
create_floorplan -site $krg_iu_vars(sam_tech,std_cell_site) -core_density_size $design(floorplan_ratio) $design(floorplan_utilization) {*}$design(floorplan_space_to_core)
# create a proc to check die corners are multiples of manufactureing grids
# Add Tracks
# ----------
krg_iu_add_tracks

# Snap Floorplan
# --------------
snap_floorplan -all

# Create Single Row Site
# ----------------------
krg_iu_create_single_row_site
krg_iu_create_double_row_site

# Relative Floorplan
# ------------------
delete_relative_floorplan -all
create_relative_floorplan -ref_type core_boundary -orient MY -horizontal_edge_separate {1  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[3].BRAM_BRAM_sam5_sp_sram_weight -ref axi_cgra4ml
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[2].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[3].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[1].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[2].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[0].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[1].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[5].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[4].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[6].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[5].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[7].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[6].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[9].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[8].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[10].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[9].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[11].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[10].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[13].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[12].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[14].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[13].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[15].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[14].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[17].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[16].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[18].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[17].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[19].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[18].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[21].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[20].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[22].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[21].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[23].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[22].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  1} -vertical_edge_separate {2  8  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[4].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[0].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  1} -vertical_edge_separate {2  8  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[8].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[4].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  1} -vertical_edge_separate {2  8  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[12].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[8].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  1} -vertical_edge_separate {2  8  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[16].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[12].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  1} -vertical_edge_separate {2  8  0} -place ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[20].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[16].BRAM_BRAM_sam5_sp_sram_weight

create_relative_floorplan -ref_type core_boundary -orient MY -horizontal_edge_separate {3  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[3].BRAM_BRAM_sam5_sp_sram_weight -ref axi_cgra4ml
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[2].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[3].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[1].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[2].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[0].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[1].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[5].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[4].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[6].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[5].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[7].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[6].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[9].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[8].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[10].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[9].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[11].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[10].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[13].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[12].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[14].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[13].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[15].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[14].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[17].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[16].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[18].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[17].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[19].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[18].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[21].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[20].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[22].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[21].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {3  0  1} -vertical_edge_separate {0  0  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[23].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[22].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  1} -vertical_edge_separate {2  8  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[4].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[0].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  1} -vertical_edge_separate {2  8  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[8].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[4].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  1} -vertical_edge_separate {2  8  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[12].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[8].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  1} -vertical_edge_separate {2  8  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[16].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[12].BRAM_BRAM_sam5_sp_sram_weight
create_relative_floorplan -ref_type object -orient MY -horizontal_edge_separate {1  0  1} -vertical_edge_separate {2  8  0} -place ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[20].BRAM_BRAM_sam5_sp_sram_weight -ref ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[16].BRAM_BRAM_sam5_sp_sram_weight

create_relative_floorplan -ref_type core_boundary -orient R0 -horizontal_edge_separate {1  0  1} -vertical_edge_separate {2  0  2} -place ENGINE_PIXELS_RAM_sam5_sp_sram_edge -ref axi_cgra4ml

create_relative_floorplan -ref_type core_boundary -orient R0 -horizontal_edge_separate {3  0  3} -vertical_edge_separate {2  0  2} -place CONTROLLER_sdp_ram_g[2].ram_i_sam5_2p_sram_dma -ref axi_cgra4ml
create_relative_floorplan -ref_type object -orient R0 -horizontal_edge_separate {1  0  3} -vertical_edge_separate {2  0  2}  -place CONTROLLER_sdp_ram_g[1].ram_i_sam5_2p_sram_dma -ref CONTROLLER_sdp_ram_g[2].ram_i_sam5_2p_sram_dma
create_relative_floorplan -ref_type object -orient R0 -horizontal_edge_separate {1  0  3} -vertical_edge_separate {2  0  2}  -place CONTROLLER_sdp_ram_g[0].ram_i_sam5_2p_sram_dma -ref CONTROLLER_sdp_ram_g[1].ram_i_sam5_2p_sram_dma
create_relative_floorplan -ref_type object -orient R0 -horizontal_edge_separate {1  0  1} -vertical_edge_separate {0  -8  2} -place CONTROLLER_sdp_ram_g[3].ram_i_sam5_2p_sram_dma -ref CONTROLLER_sdp_ram_g[2].ram_i_sam5_2p_sram_dma
create_relative_floorplan -ref_type object -orient R0 -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0}  -place CONTROLLER_sdp_ram_g[4].ram_i_sam5_2p_sram_dma -ref CONTROLLER_sdp_ram_g[3].ram_i_sam5_2p_sram_dma
create_relative_floorplan -ref_type object -orient R0 -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0}  -place CONTROLLER_sdp_ram_g[5].ram_i_sam5_2p_sram_dma -ref CONTROLLER_sdp_ram_g[4].ram_i_sam5_2p_sram_dma
create_relative_floorplan -ref_type object -orient R0 -horizontal_edge_separate {1  0  1} -vertical_edge_separate {0  -8  2} -place CONTROLLER_sdp_ram_g[6].ram_i_sam5_2p_sram_dma -ref CONTROLLER_sdp_ram_g[3].ram_i_sam5_2p_sram_dma
create_relative_floorplan -ref_type object -orient R0 -horizontal_edge_separate {1  0  3} -vertical_edge_separate {0  0  0}  -place CONTROLLER_sdp_ram_g[7].ram_i_sam5_2p_sram_dma -ref CONTROLLER_sdp_ram_g[6].ram_i_sam5_2p_sram_dma

# Cut Rows around Hard/Memory Macros
# Place and Route Halos
# ----------------------------------
krg_iu_cut_rows_macros

# Pin Placement
# -------------
# Set up pads (for fullchip) or pins (for macro)
if {$design(FULLCHIP_OR_MACRO) == "FULLCHIP"} {
        # # Connect pads to IO and CORE voltages
        # #       -netlist_override is needed, since GENUS connects these pins to UNCONNECTED during synthesis
        # connect_global_net $design(io_vdd)      -pin $tech(IO_VDDIO)    -hinst i_${design(IO_MODULE)} -netlist_override
        # connect_global_net $design(io_gnd)      -pin $tech(IO_GNDIO)    -hinst i_${design(IO_MODULE)} -netlist_override
        # connect_global_net $design(digital_vdd) -pin $tech(IO_VDDCORE)  -hinst i_${design(IO_MODULE)} -netlist_override
        # connect_global_net $design(digital_gnd) -pin $tech(IO_GNDCORE)  -hinst i_${design(IO_MODULE)} -netlist_override
        # # Reload the IO file after resizing the floorplan
        # read_io_file $design(io_file)
        # # Add IO Fillers
        # add_io_fillers -cells $tech(IO_FILLERS) -prefix IOFILLER
        # # Connect Pad Rings
        # route_special -connect {pad_ring} -nets "$design(digital_gnd) $design(digital_vdd) \
        #                         $design(io_gnd) $design(io_vdd)"
} elseif {$design(FULLCHIP_OR_MACRO) == "MACRO"} {
        set_db assign_pins_edit_in_batch true
        edit_pin -layer D11 -edge 1 -fix_overlap 1 -spread_type edge \
                -offset_start $design(CLK_PIN_START_OFFSET) \
                -pin $design(CLOCK_PIN) -pin_width $design(pin_width_d11)
        edit_pin -spread_direction clockwise -spread_type edge \
                -offset_start $design(LEFT_PINS_START_OFFSET) \
                -offset_end   $design(LEFT_PINS_END_OFFSET) \
                -layer D8 -edge 0 -fix_overlap 1 -spacing 1 -unit track \
                -pin $design(LEFT_INPUT_PINS) -pin_width $design(pin_width_d8)
        edit_pin -spread_direction clockwise -spread_type edge \
                -offset_start $design(TOP_PINS_START_OFFSET) \
                -offset_end   $design(TOP_PINS_END_OFFSET) \
                -layer D9 -edge 1 -fix_overlap 1 -spacing 1 -unit track \
                -pin $design(TOP_INPUT_PINS) -pin_width $design(pin_width_d9)
        edit_pin -spread_direction clockwise -spread_type edge \
                -offset_start $design(RIGHT_PINS_START_OFFSET) \
                -offset_end   $design(RIGHT_PINS_END_OFFSET) \
                -layer D8 -edge 2 -fix_overlap 1 -spacing 1 -unit track \
                -pin $design(RIGHT_INPUT_PINS) -pin_width $design(pin_width_d8)
        edit_pin -spread_direction clockwise -spread_type edge \
                -offset_start $design(BOTTOM_PINS_START_OFFSET) \
                -offset_end   $design(BOTTOM_PINS_END_OFFSET) \
                -layer D9 -edge 3 -fix_overlap 1 -spacing 1 -unit track \
                -pin $design(BOTTOM_OUTPUT_PINS) -pin_width $design(pin_width_d9)   
        set_db assign_pins_edit_in_batch false 
}

# check_drc for pins

# update the gui
# --------------
gui_redraw

# Stamp the stage for runtime and memory information
# --------------------------------------------------
time_info -table $runtype -stamp "floorplan"

# # Power Grid Generation
# # ---------------------
# source /work/cgra4ml/deepsocflow/tcl/asic/cadence/scripts/innovus.power_grid.tcl -quiet

# # Add Endcaps
# # -----------
# krg_iu_insert_boundary_cells

# # Add Well Taps
# # -------------
# add_well_taps -cell $tech(FILLTIE_CELL) -checker_board -prefix $krg_iu_vars(sam_tech,filltie_prefix) \
#               -cell_interval [expr 2 * [expr $design(WELLTAP_RULE)]]
# check_well_taps -max_distance $design(WELLTAP_RULE)

# # Check Floorplan
# # ---------------
# krg_iu_check_floorplan

# # Post Floorplan and Power Grid
# # -----------------------------
# krg_start_stage "floorplan" yes

# # Check DRCs
# # ---------------
# krg_check_drc

# # Export floorplan DEF
# # This can be used for loading the floorplan in subsequent runs
# #   And also as a basis for physically-aware synthesis
# write_def -floorplan -no_std_cells "$design(floorplan_def)"

# # Save the design
# # ---------------
# write_db $design(dbs_pnr_dir)/floorplan.db -no_wait

# # # Screenshot of the floorplan
# # ---------------------------
# gui_fit
# gui_create_floorplan_snapshot -dir $design(compare_dir)
#                               -name ${design(TOPLEVEL)}_floorplan_stage_innovus_run_[format "%02d" $innovus_run_counter]

# # Stamp the stage for runtime and memory information
# # --------------------------------------------------
# time_info -table $runtype -stamp "post_floorplan_and_power_grid"
# check_floorplan_space
# check_design -type place
# krg_create_stage_reports -write_db yes -check_drc yes 
