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


#--------------- Generate IPs

# Register slice
create_ip -name axis_register_slice -vendor xilinx.com -library ip -version 1.1 -module_name axis_register_slice_0
set_property -dict [list CONFIG.REG_CONFIG {1} CONFIG.HAS_TLAST {1}] [get_ips axis_register_slice_0]

# Float multiplier
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_multiplier -dir {$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip}
set_property -dict [list CONFIG.Component_Name {floating_point_multiplier} CONFIG.Operation_Type {Multiply} CONFIG.A_Precision_Type {Half} CONFIG.C_Mult_Usage {Full_Usage} CONFIG.Axi_Optimize_Goal {Performance} CONFIG.Has_ARESETn {true} CONFIG.C_A_Exponent_Width {5} CONFIG.C_A_Fraction_Width {11} CONFIG.Result_Precision_Type {Half} CONFIG.C_Result_Exponent_Width {5} CONFIG.C_Result_Fraction_Width {11} CONFIG.C_Accum_Msb {32} CONFIG.C_Accum_Lsb {-24} CONFIG.C_Accum_Input_Msb {15} CONFIG.C_Latency {9} CONFIG.C_Rate {1} CONFIG.Has_A_TLAST {true} CONFIG.RESULT_TLAST_Behv {Pass_A_TLAST} CONFIG.Has_A_TUSER {true} CONFIG.A_TUSER_Width {4} CONFIG.Has_B_TUSER {false}] [get_ips floating_point_multiplier]
generate_target {instantiation_template} [get_files {{$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_multiplier/floating_point_multiplier.xci}}]

# Float Accumulator
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_accumulator -dir {$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip}
set_property -dict [list CONFIG.Component_Name {floating_point_accumulator} CONFIG.Operation_Type {Accumulator} CONFIG.Add_Sub_Value {Add} CONFIG.A_Precision_Type {Half} CONFIG.C_Mult_Usage {No_Usage} CONFIG.Axi_Optimize_Goal {Performance} CONFIG.Has_ARESETn {true} CONFIG.C_A_Exponent_Width {5} CONFIG.C_A_Fraction_Width {11} CONFIG.Result_Precision_Type {Half} CONFIG.C_Result_Exponent_Width {5} CONFIG.C_Result_Fraction_Width {11} CONFIG.C_Accum_Msb {32} CONFIG.C_Accum_Lsb {-24} CONFIG.C_Accum_Input_Msb {15} CONFIG.C_Latency {22} CONFIG.C_Rate {1} CONFIG.Has_A_TLAST {true} CONFIG.RESULT_TLAST_Behv {Pass_A_TLAST} CONFIG.Has_A_TUSER {true} CONFIG.A_TUSER_Width {4}] [get_ips floating_point_accumulator]
generate_target {instantiation_template} [get_files {{$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_accumulator/floating_point_accumulator.xci}}]

