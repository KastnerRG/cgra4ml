set_macro_relative_location -target_object [get_cell {WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_0__RAMW}] -target_orientation R180 -target_corner tr -anchor_corner tr -offset {-0.91 -0.15} -offset_type scalable
set_macro_relative_location -target_object [get_cell {WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_1__RAMW}] -target_orientation R180 -target_corner tr -anchor_corner tr -offset {-0.83 -0.15} -offset_type scalable
set_macro_relative_location -target_object [get_cell {PIXELS_RAM_genblk1_0__RAME}] -target_orientation R180 -target_corner tr -anchor_corner tr -offset {-0.5 -0.6} -offset_type scalable

create_macro_relative_location_placement

set_attribute -objects [get_cell {WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_0__RAMW}] -name physical_status -value fixed
set_attribute -objects [get_cell {WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_1__RAMW}] -name physical_status -value fixed
set_attribute -objects [get_cell {PIXELS_RAM_genblk1_0__RAME}] -name physical_status -value fixed

create_keepout_margin -type hard -outer {5 5 5 5} [get_attribute [get_cells PIXELS_RAM_genblk1_0__RAME] ref_block]
create_keepout_margin -type hard_macro -outer {5 5 5 5} [get_attribute [get_cells PIXELS_RAM_genblk1_0__RAME] ref_block]
create_keepout_margin -type soft -outer {8 8 8 8} [get_attribute [get_cells PIXELS_RAM_genblk1_0__RAME] ref_block];
create_keepout_margin -type hard -outer {5 5 5 5} [get_attribute [get_cells PIXELS_RAM_genblk1_0__RAME] ref_block]
create_keepout_margin -type hard_macro -outer {5 5 5 5} [get_attribute [get_cells PIXELS_RAM_genblk1_0__RAME] ref_block]
create_keepout_margin -type soft -outer {8 8 8 8} [get_attribute [get_cells PIXELS_RAM_genblk1_0__RAME] ref_block];

create_keepout_margin -type hard -outer {5 5 5 5} [get_attribute [get_cells PIXELS_RAM_genblk1_0__RAME] ref_block]
create_keepout_margin -type hard_macro -outer {5 5 5 5} [get_attribute [get_cells PIXELS_RAM_genblk1_0__RAME] ref_block]
create_keepout_margin -type soft -outer {8 8 8 8} [get_attribute [get_cells PIXELS_RAM_genblk1_0__RAME] ref_block];

