connect_pg_net -automatic

# Setup TIE Cells
set_attribute [get_lib_cells */*TIE*] dont_touch false
set_lib_cell_purpose -include optimization [get_lib_cells */*TIE*]

#rings to srams
#connect power to sram

# Create Outer core ring
create_pg_ring_pattern ring_pattern -horizontal_layer M8 -horizontal_width {3} -horizontal_spacing {2} -vertical_layer M7 -vertical_width {3} -vertical_spacing {2}
set_pg_strategy core_ring -pattern {{name:ring_pattern} {nets: {VDD VSS}}{offset: {3 3}}} -core
#connect follwo pins


#add vertical and horizontal strapes
#add end caps
#add welltaps
# Create endcap cells
create_boundary_cells -left_boundary_cell [get_lib_cells {cln28ht/ENDCAPTIE3_A7PP140ZTS_C30}] -right_boundary_cell [get_lib_cells {cln28ht/ENDCAPTIE3_A7PP140ZTS_C30}]

# Create taps
create_tap_cells -distance 132.0000 -lib_cell [get_lib_cells {cln28ht/FILLTIE5_A7PP140ZTS_C30}] -voltage_area DEFAULT_VA -offset 33.0000 -pattern stagger
create_tap_cells -distance 132.0000 -lib_cell [get_lib_cells {cln28ht/FILLTIE5_A7PP140ZTS_C30}] -voltage_area ACCEL -offset 33.0000 -pattern stagger



# Create vertical straps 
create_pg_mesh_pattern strap_pattern -layers {{{vertical_layer: M6} {width: 1} {pitch: 50} {spacing: interleaving} {trim: false}}}
set_pg_strategy M6_straps -pattern {{name: strap_pattern}{nets: VDD VSS}} -extension {{{stop : outermost_ring}}} -design_boundary

# Create std cell rails 
create_pg_std_cell_conn_pattern rail_pattern -layers M5 
set_pg_strategy M5_rails -pattern {{name: rail_pattern}{nets: VDD VSS}} -extension {{{stop : outermost_ring}}} -design_boundary

# Create rails for macros
create_pg_macro_conn_pattern sram_pg_mesh -pin_conn_type long_pin -nets {VDD VSS} -direction horizontal -layers M5 -width 0.64 -spacing interleaving -pitch 3 -pin_layers {M4} -via_rule {{intersection : all}}
set_pg_strategy sram_pg_mesh -macros { PIXELS_RAM_genblk1_0__RAME \
	  WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_0__RAMW \
	  WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_1__RAMW } -pattern {{name : sram_pg_mesh}{nets : {VDD VSS}}}

# Create Power Straps
create_pg_mesh_pattern power_straps_horizon -layers {{vertical_layer : M7} {width : 1} {spacing : interleaving} {pitch : 50} {trim : false}}
set_pg_strategy M7_straps -pattern {{name: power_straps_horizon}{nets: VDD VSS}} -extension {{{stop : outermost_ring}}} -design_boundary

create_pg_mesh_pattern power_straps_verti -layers {{horizontal_layer : M8} {width : 1} {spacing : interleaving} {pitch : 50} {trim : false}}
set_pg_strategy M8_mesh -pattern {{name: power_straps_verti}{nets: VDD VSS}} -extension {{{stop : outermost_ring}}} -design_boundary

# Compile all power strategies
compile_pg -strategies {core_ring M6_straps M5_rails M7_straps M8_mesh sram_pg_mesh}
create_pg_vias -nets {VDD VSS} -from_layers M1 -to_layers M7 -drc no_check
check_pg_connectivity 
check_pg_drc -output ../asic/reports/${design_name}.power_drc_violations.rpt

