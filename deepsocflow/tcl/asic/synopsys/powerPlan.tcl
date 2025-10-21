# Setup TIE Cells
set_attribute [get_lib_cells */*TIE*] dont_touch false
set_lib_cell_purpose -include optimization [get_lib_cells */*TIE*]

# Connect VDD and VSS of Std_cells and Tie Cells
connect_pg_net -automatic

# Connect VDD and VSS of Macros
connect_pg_net -net {VDD} [get_pins -design [current_block] -quiet -physical_context {WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_RAMW/VDD}]
connect_pg_net -net {VSS} [get_pins -design [current_block] -quiet -physical_context {WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_RAMW/VSSE}]

connect_pg_net -net {VDD} [get_pins -design [current_block] -quiet -physical_context {WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_RAMW/VDD}]
connect_pg_net -net {VSS} [get_pins -design [current_block] -quiet -physical_context {WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_RAMW/VSSE}]

connect_pg_net -net {VDD} [get_pins -design [current_block] -quiet -physical_context {PIXELS_RAM_RAME/VDD}]
connect_pg_net -net {VSS} [get_pins -design [current_block] -quiet -physical_context {PIXELS_RAM_RAME/VSSE}]

# Create rails for macros
create_pg_ring_pattern sram_ring_patt -horizontal_layer M12 -horizontal_width {1} -horizontal_spacing {1} -vertical_layer M13 -vertical_width {1} -vertical_spacing {1}
set_pg_strategy sram_ring -macros { PIXELS_RAM_RAME \
	WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_RAMW \
	WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_RAMW} -pattern {{name : sram_ring_patt} {nets: {VDD VSS}}{offset: {4 4}}}

create_pg_macro_conn_pattern sram_pg_mesh -pin_conn_type long_pin -nets {VDD VSS} -direction horizontal -layers M4 -width 0.5 -spacing interleaving -pitch 5 -pin_layers {M4} -via_rule {{intersection : all}}
set_pg_strategy sram_pg_mesh -macros { PIXELS_RAM_RAME \
	WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_RAMW \
	WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_RAMW } -pattern {{name : sram_pg_mesh} {nets : {VDD VSS}}}
compile_pg -strategies {sram_ring sram_pg_mesh}

# Create Outer core ring
create_pg_ring_pattern ring_pattern -horizontal_layer M12 -horizontal_width {5} -horizontal_spacing {2} -vertical_layer M13 -vertical_width {5} -vertical_spacing {2}
set_pg_strategy core_ring -pattern {{name:ring_pattern} {nets: {VDD VSS}} {offset: {3 3}}} -core
compile_pg -strategies {core_ring}

# Create std cell rails 
create_pg_std_cell_conn_pattern std_rail_pattern -layers M0 -check_std_cell_drc true
set_pg_strategy std_pwr_rail -pattern {{name: std_rail_pattern}{nets: VDD VSS}} -core -extension {{{stop : first_target}}} -blockage {macros_with_keepout : PIXELS_RAM_RAME \
	WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_RAMW \
	WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_RAMW }
compile_pg -strategies {std_pwr_rail}

# Create Power Straps
create_pg_mesh_pattern power_straps_horizon -layers {{vertical_layer : M13} {width : 1} {spacing : interleaving} {pitch : 30} {offset : 5}}
set_pg_strategy Verticl_Straps -pattern {{name: power_straps_horizon}{nets: VDD VSS}} -core -extension {{{stop : first_target}}}

create_pg_mesh_pattern power_straps_verti -layers {{horizontal_layer : M12} {width : 1} {spacing : interleaving} {pitch : 30} {offset : 5}}
set_pg_strategy Horizon_Straps -pattern {{name: power_straps_verti}{nets: VDD VSS}} -core -extension {{{stop : first_target}}}

compile_pg -strategies {Verticl_Straps Horizon_Straps}

# Check Power DRCs
create_pg_vias -nets {VDD VSS} -from_layers M0 -to_layers M13 -drc no_check
check_pg_connectivity 
check_pg_drc -output ../asic/reports/${top_module}.power_drc_violations.rpt

# Create endcap cells
create_boundary_cells -left_boundary_cell [get_lib_cells {$tech(END_CAP_CELL)}] -right_boundary_cell [get_lib_cells {$tech(END_CAP_CELL)}] -prefix $tech(END_CAP_PREFIX) -separator "_"

# Create taps
create_tap_cells -distance 30 -lib_cell [get_lib_cells $tech(FILL_TIE_CELL)] -pattern stagger -prefix $tech(FILL_TIE_PREFIX) -separator "_"
