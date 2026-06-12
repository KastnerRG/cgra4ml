#################################
#       Clock Constraints       #
#################################
# Create Clocks
create_clock -period $design(clock_period_list) -name $design(clock_list) [get_ports $design(clock_port_list)]
set_clock_uncertainty $design(CLOCK_UNCERTAINTY) $design(clock_list)
set_false_path -from [get_ports $design(RST_PORT)]
set_ideal_network [get_ports $design(clock_port_list)]


#################################
#       IO Constraints          #
#################################
set_input_delay -clock CLK 0.25 \
       [remove_from_collection [all_inputs] [list $design(CLK_PORT) $design(RST_PORT)]]
set_output_delay -clock $design(CLK_NAME) $design(OUTPUT_DELAY) [all_outputs]


set tech(SDC_LOAD_VALUE) [lindex [get_db [get_lib_pins $tech(SDC_LOAD_PIN)] .capacitance] 0]
set_load                $tech(SDC_LOAD_VALUE)                      [all_outputs]
set_input_transition    $design(INPUT_TRANSITION)                  [all_inputs]
set_driving_cell        -lib_cell $tech(SDC_DRIVING_CELL)          [all_inputs]


#################################
#       DRV Constraints         #
#################################
set_max_transition     $design(MAX_TRANSITION)               [current_design]


#################################
#      Design Constraints       #
#################################
foreach srams $design(DMA_SRAM_LIST) {  
    set_disable_timing $srams -from [get_db $srams .pins -if {.base_name == CLKA}] -to [get_db $srams .pins -if {.base_name == CLKB}]
    set_disable_timing $srams -from [get_db $srams .pins -if {.base_name == CLKA}] -to [get_db $srams .pins -if {.base_name == CLKB}] } 
