#################################
#       Clock Constraints       #
#################################
# Create Clocks
create_clock -period $design(clock_period_list) -name $design(clock_list) [get_ports $design(clock_port_list)]
set_clock_uncertainty $design(CLOCK_UNCERTAINTY) $design(clock_list)




#################################
#       IO Constraints          #
#################################
set_input_delay -clock $design(CLK_NAME) $design(INPUT_DELAY) \
        [remove_from_collection [all_inputs] $design(CLK_PORT)]
set_output_delay -clock $design(CLK_NAME) $design(OUTPUT_DELAY) [all_outputs]


set tech(SDC_LOAD_VALUE) [lindex [get_db [get_lib_pins $tech(SDC_LOAD_PIN)] .capacitance] 0]


set_load                $tech(SDC_LOAD_VALUE)                      [all_outputs]
set_input_transition    $design(INPUT_TRANSITION)                  [all_inputs]
set_driving_cell        -lib_cell $tech(SDC_DRIVING_CELL)          [all_inputs]




