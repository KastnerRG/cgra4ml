# Create Power Grid
# -----------------
krg_start_stage "power_grid" yes

# Connect Global Net
# ------------------
# Connect standard cells and macros to VDD and GND
connect_global_net $design(digital_gnd) -type pg_pin -pin_base_name $tech(STANDARD_CELL_GND) -all -verbose
connect_global_net $design(digital_vdd) -type pg_pin -pin_base_name $tech(STANDARD_CELL_VDD) -all -verbose
# Connect tie cells
connect_global_net $design(digital_vdd) -type tie_hi -all -verbose
connect_global_net $design(digital_gnd) -type tie_lo -all -verbose

# Add Power Grid
# --------------
# Set Power Grid Rings Settings
krg_power_grid_rings_settings
# Add Core Rings
add_rings -nets $design(core_ring_nets) -type core_rings -follow core -exclude_selected 1 \
          -layer $design(core_ring_layers) \
          -width $design(core_ring_width) \
          -spacing $design(core_ring_spacing) \
          -offset $design(core_ring_offset) \
          -center 0 -threshold 0 -jog_distance 0 -snap_wire_center_to_grid grid
# Add Block Rings
# Top SRAM Weights Ring
select_obj "ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[0].BRAM_BRAM_sam5_sp_sram_weight \
            ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[4].BRAM_BRAM_sam5_sp_sram_weight \
            ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[8].BRAM_BRAM_sam5_sp_sram_weight \
            ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[12].BRAM_BRAM_sam5_sp_sram_weight \
            ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[16].BRAM_BRAM_sam5_sp_sram_weight \
            ENGINE_WEIGHTS_ROTATOR/i0[0].col_RAM[20].BRAM_BRAM_sam5_sp_sram_weight"
add_rings -nets $design(block_ring_nets) -type block_rings -around selected \
          -layer $design(block_ring_layers) \
          -width $design(block_ring_width) \
          -spacing $design(block_ring_spacing) \
          -offset $design(block_ring_offset) \
          -center 0 -extend_corners {rt bl } -skip_side {top left } \
          -threshold 0 -jog_distance 0 -snap_wire_center_to_grid grid
deselect_obj -all
# Bottom SRAM Weights Ring
select_obj "ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[0].BRAM_BRAM_sam5_sp_sram_weight \
            ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[4].BRAM_BRAM_sam5_sp_sram_weight \
            ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[8].BRAM_BRAM_sam5_sp_sram_weight \
            ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[12].BRAM_BRAM_sam5_sp_sram_weight \
            ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[16].BRAM_BRAM_sam5_sp_sram_weight \
            ENGINE_WEIGHTS_ROTATOR/i0[1].col_RAM[20].BRAM_BRAM_sam5_sp_sram_weight"
add_rings -nets $design(block_ring_nets) -type block_rings -around selected \
          -layer $design(block_ring_layers) \
          -width $design(block_ring_width) \
          -spacing $design(block_ring_spacing) \
          -offset $design(block_ring_offset) \
          -center 0 -extend_corners {tl rb } -skip_side {bottom left } \
          -threshold 0 -jog_distance 0 -snap_wire_center_to_grid grid
deselect_obj -all
# SRAM Edge Ring
select_obj "ENGINE_PIXELS_RAM_sam5_sp_sram_edge"
add_rings -nets $design(block_ring_nets) -type block_rings -around selected \
          -layer $design(block_ring_layers) \
          -width $design(block_ring_width) \
          -spacing $design(block_ring_spacing) \
          -offset $design(block_ring_offset) \
          -center 0 -extend_corners {br lt } -skip_side {top right } \
          -threshold 0 -jog_distance 0 -snap_wire_center_to_grid grid
deselect_obj -all
# SRAM DMA Ring
select_obj "CONTROLLER_sdp_ram_g[0].ram_i_sam5_2p_sram_dma \
            CONTROLLER_sdp_ram_g[5].ram_i_sam5_2p_sram_dma \
            CONTROLLER_sdp_ram_g[7].ram_i_sam5_2p_sram_dma"
add_rings -nets $design(block_ring_nets) -type block_rings -around selected \
          -layer $design(block_ring_layers) \
          -width $design(block_ring_width) \
          -spacing $design(block_ring_spacing) \
          -offset $design(block_ring_offset) \
          -center 0 -extend_corners {tr lb } -skip_side {right bottom } \
          -threshold 0 -jog_distance 0 -snap_wire_center_to_grid grid
deselect_obj -all

# Set Power Grid SRAM Stripes Settings
krg_power_grid_sram_stripes_settings

# Add Stripes for SRAMs
krg_select_srams_weights 0 0
krg_add_stripes_to_selected_sram $design(sram_stripes_interval)
krg_select_srams_weights 0 4
krg_add_stripes_to_selected_sram $design(sram_stripes_interval)
krg_select_srams_weights 0 8
krg_add_stripes_to_selected_sram $design(sram_stripes_interval)
krg_select_srams_weights 0 12
krg_add_stripes_to_selected_sram $design(sram_stripes_interval)
krg_select_srams_weights 0 16
krg_add_stripes_to_selected_sram $design(sram_stripes_interval)
krg_select_srams_weights 0 20
krg_add_stripes_to_selected_sram $design(sram_stripes_interval)

krg_select_srams_weights 1 0
krg_add_stripes_to_selected_sram $design(sram_stripes_interval)
krg_select_srams_weights 1 4
krg_add_stripes_to_selected_sram $design(sram_stripes_interval)
krg_select_srams_weights 1 8
krg_add_stripes_to_selected_sram $design(sram_stripes_interval)
krg_select_srams_weights 1 12
krg_add_stripes_to_selected_sram $design(sram_stripes_interval)
krg_select_srams_weights 1 16
krg_add_stripes_to_selected_sram $design(sram_stripes_interval)
krg_select_srams_weights 1 20
krg_add_stripes_to_selected_sram $design(sram_stripes_interval)

krg_select_srams_edge
krg_add_stripes_to_selected_sram $design(sram_stripes_interval)

krg_select_srams_dma 0
krg_add_stripes_to_selected_sram $design(sram_stripes_interval_dma)
krg_select_srams_dma 3
krg_add_stripes_to_selected_sram $design(sram_stripes_interval_dma)     
krg_select_srams_dma_last
krg_add_stripes_to_selected_sram $design(sram_stripes_interval_dma)

# Set Power Grid Standard Cell Stripes Settings
krg_power_grid_std_cell_stripes_settings

# Add Stripes for Standard Cells
add_stripes -nets $design(M14_stripes_nets) -layer $krg_iu_vars(layer_name,14) -direction vertical \
            -width $design(M14_stripes_width) \
            -spacing $design(M14_stripes_spacing) \
            -set_to_set_distance $design(M14_stripes_interval) \
            -area {22.2695 174.0765 365.18475 133.58325} \
            -start_from left -switch_layer_over_obs false -max_same_layer_jog_length 2 \
            -pad_core_ring_top_layer_limit $krg_iu_vars(layer_name,14) \
            -pad_core_ring_bottom_layer_limit $krg_iu_vars(layer_name,1) \
            -block_ring_top_layer_limit $krg_iu_vars(layer_name,14) \
            -block_ring_bottom_layer_limit $krg_iu_vars(layer_name,1) \
            -use_wire_group 0 -snap_wire_center_to_grid grid

add_stripes -nets $design(M13_stripes_nets) -layer $krg_iu_vars(layer_name,13) -direction horizontal \
            -width $design(M13_stripes_width) \
            -spacing $design(M13_stripes_spacing) \
            -set_to_set_distance $design(M13_stripes_interval) \
            -area {206.86025 28.155 292.589 256.15725} \
            -start_from left -switch_layer_over_obs false -max_same_layer_jog_length 2 \
            -pad_core_ring_top_layer_limit $krg_iu_vars(layer_name,13) \
            -pad_core_ring_bottom_layer_limit $krg_iu_vars(layer_name,1) \
            -block_ring_top_layer_limit $krg_iu_vars(layer_name,13) \
            -block_ring_bottom_layer_limit $krg_iu_vars(layer_name,1) \
            -use_wire_group 0 -snap_wire_center_to_grid grid

# Connect Dangling Stripes to the Core Ring
krg_power_grid_floating_stripe_route_special_settings
route_special -connect floating_stripe -layer_change_range { [list $krg_iu_vars(layer_name,1)(1) $krg_iu_vars(layer_name,14)(14)] } \
              -block_pin_target nearest_target \
              -floating_stripe_target {block_ring ring stripe} \
              -allow_jogging 1 \
              -crossover_via_layer_range { [list $krg_iu_vars(layer_name,1)(1) $krg_iu_vars(layer_name,14)(14)] } \
              -nets $design(core_ring_nets) -allow_layer_change 1 \
              -target_via_layer_range { [list $krg_iu_vars(layer_name,1)(1) $krg_iu_vars(layer_name,14)(14)] } \
              -detailed_log

# Connect Follow Pins to the Core Ring
krg_power_grid_M1_stripes_settings
route_special -connect core_pin \
              -core_pin_target none \
              -core_pin_check_stdcell_geometry \
              -allow_jogging 0 \
              -allow_layer_change 0

krg_power_grid_M3_stripes_settings
add_stripes -nets $design(M3_stripes_nets) \
            -layer $design(M3_stripes_layers) \
            -direction horizontal \
            -width $design(M3_stripes_width) \
            -spacing $design(M3_stripes_spacing) \
            -set_to_set_distance $design(M3_stripes_interval) \
            -start_from bottom \
            -start_offset $design(M3_stripes_start_offset) \
            -stop_offset $design(M3_stripes_stop_offset) \
            -switch_layer_over_obs false -max_same_layer_jog_length 2 \
            -pad_core_ring_top_layer_limit LB \
            -pad_core_ring_bottom_layer_limit M1 \
            -block_ring_top_layer_limit LB \
            -block_ring_bottom_layer_limit M1 \
            -use_wire_group 0 -snap_wire_center_to_grid grid

# Connect pads to the Core Ring
# if {$design(FULLCHIP_OR_MACRO) == "FULLCHIP"} {
#     route_special -connect {pad_pin} \
#     -layer_change_range { [list $krg_iu_vars(layer_name,1)(1) $krg_iu_vars(layer_name,14)(14)] } \
#     -block_pin_target {nearest_target} \
#     -core_pin_target {first_after_row_end} \
#     -allow_jogging 1 \
#     -crossover_via_layer_range { [list $krg_iu_vars(layer_name,1)(1) $krg_iu_vars(layer_name,14)(14)] } \
#     -nets $design(core_ring_nets) \
#     -allow_layer_change 1\
#     -target_via_layer_range { [list $krg_iu_vars(layer_name,1)(1) $krg_iu_vars(layer_name,14)(14)] }
# }

# Add Stapling Support for Advanced Nodes
krg_power_grid_M3_stripes_settings
add_stripes -nets $design(M2_stapling_nets) \
            -stapling $design(M2_stapling_parameters) \
            -layer $design(M2_stapling_layers) \
            -direction vertical \
            -width $design(M2_stapling_width) \
            -set_to_set_distance $design(M2_stapling_interval) \
            -snap_wire_center_to_grid grid

krg_iu_preplace_power_stitch_insertion

# Check DRCs for Power Grid
krg_check_drc

# Reporting & Save
check_connectivity -check_pg_ports -type special -out_file $design(reports_pnr_dir)/[format "%02d" $this_run(stage_count)]_$this_run(stage)_power_connectivity.rpt

###### To-Do:Power Analysis and Rail Analysis ######