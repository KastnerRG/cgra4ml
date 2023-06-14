create_clock -name clk -period $clock_cycle [get_ports aclk]
set_false_path -from [get_ports "aresetn"]

set_input_delay -clock [get_clocks clk] -add_delay -max $io_delay [all_inputs]
set_output_delay -clock [get_clocks clk] -add_delay -max $io_delay [all_outputs]
 
