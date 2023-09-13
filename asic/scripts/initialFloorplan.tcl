# Floorplan
floorPlan -r 0.33 0.85 10.0 10.0 10.0 10.0

timeDesign -preplace -prefix preplace

globalNetConnect VDD -type pgpin -pin VDD -inst * 
globalNetConnect VSS -type pgpin -pin VSS -inst * 

addRing -spacing {top 2 bottom 2 left 2 right 2} -width {top 3 bottom 3 left 3 right 3}  -layer {top M1 bottom M1 left M2 right M2} -center 1 -type core_rings -nets {VSS  VDD}

#setAddStripeMode -break_at {block_ring}
setAddStripeMode -ignore_block_check false -break_at none -route_over_rows_only false -rows_without_stripes_only false -extend_to_closest_target none -stop_at_last_wire_for_area false -partial_set_thru_domain false -ignore_nondefault_domains false -trim_antenna_back_to_shape none -spacing_type edge_to_edge -spacing_from_block 0 -stripe_min_length stripe_width -stacked_via_top_layer M8 -stacked_via_bottom_layer M1 -via_using_exact_crossover_size false -split_vias false -orthogonal_only true -allow_jog { padcore_ring  block_ring } -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape   }

addStripe -nets {VSS VDD} -layer M4 -direction vertical -width 1.8 -spacing 1.8 -number_of_sets 100 -start_from left -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit M8 -padcore_ring_bottom_layer_limit M1 -block_ring_top_layer_limit M8 -block_ring_bottom_layer_limit M1 -use_wire_group 0 -snap_wire_center_to_grid None

### Note: Change the number of strip  by looking at the layout #########
#addStripe -number_of_sets 2  -spacing 6 -layer M4 -width 2 -nets { VSS VDD }
#################################################

#addStripe -nets {VDD VSS} -layer M4 -direction vertical -width 1.8 -spacing 1.8 -number_of_sets 50 -start_from left -start 80 -stop 180 

sroute

