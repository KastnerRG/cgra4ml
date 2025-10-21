set_macro_relative_location -target_object [get_cell {WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_RAMW}] -target_orientation R0 -target_corner tr -anchor_corner tr -offset {-25 -25} -offset_type fixed
set_macro_relative_location -target_object [get_cell {WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_RAMW}] -target_orientation R0 -target_corner br -anchor_corner br -offset {-25 25} -offset_type fixed
set_macro_relative_location -target_object [get_cell {PIXELS_RAM_RAME}] -target_orientation R180 -target_corner tl -anchor_corner tl -offset {25 -25} -offset_type fixed

create_macro_relative_location_placement

set_attribute -objects [get_cell {WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_RAMW}] -name physical_status -value fixed
set_attribute -objects [get_cell {WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_RAMW}] -name physical_status -value fixed
set_attribute -objects [get_cell {PIXELS_RAM_RAME}] -name physical_status -value fixed

create_keepout_margin -type hard -outer {4 4 4 4} [get_attribute [get_cells WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_RAMW] ref_block]
create_keepout_margin -type hard_macro -outer {4 4 4 4} [get_attribute [get_cells WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_RAMW] ref_block]
create_keepout_margin -type soft -outer {6 6 6 6} [get_attribute [get_cells WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_RAMW] ref_block];
create_keepout_margin -type hard -outer {4 4 4 4} [get_attribute [get_cells WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_RAMW] ref_block]
create_keepout_margin -type hard_macro -outer {4 4 4 4} [get_attribute [get_cells WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_RAMW] ref_block]
create_keepout_margin -type soft -outer {6 6 6 6} [get_attribute [get_cells WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_RAMW] ref_block];

create_keepout_margin -type hard -outer {4 4 4 4} [get_attribute [get_cells PIXELS_RAM_RAME] ref_block]
create_keepout_margin -type hard_macro -outer {4 4 4 4} [get_attribute [get_cells PIXELS_RAM_RAME] ref_block]
create_keepout_margin -type soft -outer {6 6 6 6} [get_attribute [get_cells PIXELS_RAM_RAME] ref_block];
