set PROJ_NAME support
set PROJ_FOLDER ./support
set SOURCE_FOLDER ../../src

create_project $PROJ_NAME $PROJ_FOLDER -part xc7z020clg484-1
set_property board_part xilinx.com:zc702:part0:1.4 [current_project]


# Add Design Sources

add_files -norecurse $SOURCE_FOLDER/axis_mux.sv
add_files -norecurse $SOURCE_FOLDER/axis_shell.sv
add_files -norecurse $SOURCE_FOLDER/axis_shift_buffer.sv
add_files -norecurse $SOURCE_FOLDER/axis_skid_reg.v
add_files -norecurse $SOURCE_FOLDER/n_delay.sv
add_files -norecurse $SOURCE_FOLDER/register.v
add_files -norecurse $SOURCE_FOLDER/axis_shift_buffer_tlast.sv

# Add Simulation Sources

add_files -fileset sim_1 -norecurse $SOURCE_FOLDER/axis_mux_tb.sv
add_files -fileset sim_1 -norecurse $SOURCE_FOLDER/axis_shell_tb.sv
add_files -fileset sim_1 -norecurse $SOURCE_FOLDER/axis_shift_buffer_tb.sv
add_files -fileset sim_1 -norecurse $SOURCE_FOLDER/axis_skid_reg_tb.v
add_files -fileset sim_1 -norecurse $SOURCE_FOLDER/n_delay_tb.sv
add_files -fileset sim_1 -norecurse $SOURCE_FOLDER/register_tb.v
add_files -fileset sim_1 -norecurse $SOURCE_FOLDER/axis_shift_buffer_tlast_tb.sv


# Generate IPs

create_ip -name axis_register_slice -vendor xilinx.com -library ip -version 1.1 -module_name axis_register_slice_0
set_property -dict [list CONFIG.REG_CONFIG {1} CONFIG.HAS_TLAST {1}] [get_ips axis_register_slice_0]