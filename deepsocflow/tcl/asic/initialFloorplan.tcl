# Floorplan 0.75 change
floorPlan -r 0.40 0.75 10.0 10.0 10.0 10.0

timeDesign -preplace -prefix preplace

globalNetConnect VDD -type pgpin -pin VDD -inst * -autoTie
globalNetConnect VSS -type pgpin -pin VSS -inst * -autoTie

setAddRingMode  -stacked_via_top_layer M8 -stacked_via_bottom_layer M1
addRing -spacing {top 2 bottom 2 left 2 right 2} -width {top 3 bottom 3 left 3 right 3}  -layer {top M9 bottom M9 left M8 right M8} -center 1 -type core_rings -nets {VSS  VDD}

sroute -nets {VDD VSS} -connect {padPin padRing} -layerChangeRange { M1(1) AP(10) } -blockPinTarget nearestTarget -padPinPortConnect {allPort allGeom} -padPinTarget nearestTarget -allowJogging 1 -crossoverViaLayerRange { M1(1) AP(10) } -allowLayerChange 1 -padPinWidth 6 -targetViaLayerRange { M1(1) AP(10) }

setAddStripeMode -ignore_block_check false -break_at none -route_over_rows_only false -rows_without_stripes_only false -extend_to_closest_target none -stop_at_last_wire_for_area false -partial_set_thru_domain false -ignore_nondefault_domains false -trim_antenna_back_to_shape none -spacing_type edge_to_edge -spacing_from_block 0 -stripe_min_length stripe_width -stacked_via_top_layer M9 -stacked_via_bottom_layer M4 -via_using_exact_crossover_size false -split_vias false -orthogonal_only true -allow_jog { padcore_ring  block_ring } -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape   }
addStripe -nets {VSS VDD} -layer M9 -direction vertical -width 2 -spacing 2 -set_to_set_distance 20 -start_from left -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit M9 -padcore_ring_bottom_layer_limit M1 -block_ring_top_layer_limit M9 -block_ring_bottom_layer_limit M1 -use_wire_group 0 -snap_wire_center_to_grid None

deselect_obj -all 
select_obj [ list PIXELS_RAM_genblk1_0__RAME WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_0__RAMW WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_1__RAMW WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_2__RAMW WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_3__RAMW WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_4__RAMW WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_5__RAMW WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_6__RAMW WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_7__RAMW WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_8__RAMW WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_9__RAMW WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_10__RAMW WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_11__RAMW WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_0__RAMW WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_1__RAMW WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_2__RAMW WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_3__RAMW WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_4__RAMW WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_5__RAMW WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_6__RAMW WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_7__RAMW WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_8__RAMW WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_9__RAMW WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_10__RAMW WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_11__RAMW]
setAddStripeMode -ignore_block_check false -break_at none -route_over_rows_only false -rows_without_stripes_only false -extend_to_closest_target stripe
addStripe -nets {VDD VSS} -layer M5 -direction horizontal -width 1 -spacing 0.5 -set_to_set_distance 15 -start_from left -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit AP -padcore_ring_bottom_layer_limit M1 -block_ring_top_layer_limit AP -block_ring_bottom_layer_limit M1 -use_wire_group 0 -snap_wire_center_to_grid None
deselect_obj -all 


sroute -connect {padPin padRing} -layerChangeRange { M1(1) AP(10) } -blockPinTarget nearestTarget -padPinPortConnect {allPort allGeom} -padPinTarget nearestTarget -allowJogging 1 -crossoverViaLayerRange { M1(1) AP(10) } -nets { VDD VSS } -allowLayerChange 1 -padPinWidth 6 -targetViaLayerRange { M1(1) AP(10) }

sroute -connect {blockPin corePin floatingStripe} -layerChangeRange { M1(1) AP(10) } -blockPinTarget nearestTarget -padPinPortConnect {allPort oneGeom} -padPinTarget nearestTarget -corePinTarget firstAfterRowEnd -floatingStripeTarget {blockRing padRing ring stripe ringPin blockPin followpin} -allowJogging 1 -crossoverViaLayerRange { M1(1) AP(10) } -nets { VDD VSS } -allowLayerChange 1 -blockPin useLef -targetViaLayerRange { M1(1) AP(10) }


