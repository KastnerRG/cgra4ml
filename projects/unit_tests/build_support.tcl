set PROJ_NAME support
set PROJ_FOLDER support
set SOURCE_FOLDER ../../src
set WAVEFORM_FOLDER ../../wave

create_project support . -part xc7z020clg484-1
set_property board_part xilinx.com:zc702:part0:1.4 [current_project]

# Add Sources
add_files -fileset sim_1 -norecurse [glob $SOURCE_FOLDER/*_tb.sv]
add_files -fileset sim_1 -norecurse [glob $SOURCE_FOLDER/*_tb.v]
add_files -fileset sim_1 -norecurse [glob $WAVEFORM_FOLDER/*.wcfg]
add_files -norecurse [glob $SOURCE_FOLDER/*.sv]
add_files -norecurse [glob $SOURCE_FOLDER/*.v]

update_ip_catalog

#--------------- Generate IPs

# Float multiplier (6 clocks)
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_multiplier
set_property -dict [list CONFIG.Component_Name {floating_point_multiplier} CONFIG.Operation_Type {Multiply} CONFIG.A_Precision_Type {Half} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {true} CONFIG.Has_A_TLAST {true} CONFIG.Has_A_TUSER {true} CONFIG.A_TUSER_Width {4} CONFIG.C_A_Exponent_Width {5} CONFIG.C_A_Fraction_Width {11} CONFIG.Result_Precision_Type {Half} CONFIG.C_Result_Exponent_Width {5} CONFIG.C_Result_Fraction_Width {11} CONFIG.C_Accum_Msb {32} CONFIG.C_Accum_Lsb {-24} CONFIG.C_Accum_Input_Msb {15} CONFIG.C_Mult_Usage {Full_Usage} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Latency {6} CONFIG.C_Rate {1} CONFIG.RESULT_TLAST_Behv {Pass_A_TLAST}] [get_ips floating_point_multiplier]
generate_target {instantiation_template} [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_multiplier/floating_point_multiplier.xci]

# Float Accumulator (19----- clocks)
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_accumulator
set_property -dict [list CONFIG.Component_Name {floating_point_accumulator} CONFIG.Operation_Type {Accumulator} CONFIG.Add_Sub_Value {Add} CONFIG.A_Precision_Type {Half} CONFIG.C_Mult_Usage {No_Usage} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {true} CONFIG.Has_A_TUSER {true} CONFIG.A_TUSER_Width {4} CONFIG.C_A_Exponent_Width {5} CONFIG.C_A_Fraction_Width {11} CONFIG.Result_Precision_Type {Half} CONFIG.C_Result_Exponent_Width {5} CONFIG.C_Result_Fraction_Width {11} CONFIG.C_Accum_Msb {32} CONFIG.C_Accum_Lsb {-24} CONFIG.C_Accum_Input_Msb {15} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Latency {19} CONFIG.C_Rate {1} CONFIG.Has_A_TLAST {true} CONFIG.RESULT_TLAST_Behv {Pass_A_TLAST}] [get_ips floating_point_accumulator]
generate_target {instantiation_template} [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_accumulator/floating_point_accumulator.xci]

# Fixed Multiplier (3 clocks - optimum)
create_ip -name mult_gen -vendor xilinx.com -library ip -version 12.0 -module_name fixed_point_multiplier
set_property -dict [list CONFIG.Component_Name {fixed_point_multiplier} CONFIG.PortAWidth {16} CONFIG.PortBWidth {16} CONFIG.Multiplier_Construction {Use_Mults} CONFIG.Use_Custom_Output_Width {true} CONFIG.OutputWidthHigh {15} CONFIG.PipeStages {3} CONFIG.ClockEnable {true}] [get_ips fixed_point_multiplier]
generate_target {instantiation_template} [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/fixed_point_multiplier/fixed_point_multiplier.xci]

# Fixed Accumulator (2 clocks - auto)
create_ip -name c_accum -vendor xilinx.com -library ip -version 12.0 -module_name fixed_point_accumulator
set_property -dict [list CONFIG.Component_Name {fixed_point_accumulator} CONFIG.Implementation {DSP48} CONFIG.Latency_Configuration {Automatic} CONFIG.Latency {2} CONFIG.CE {true}] [get_ips fixed_point_accumulator]
generate_target {instantiation_template} [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/fixed_point_accumulator/fixed_point_accumulator.xci]

# Reg Slice for Buffer

create_ip -name axis_register_slice -vendor xilinx.com -library ip -version 1.1 -module_name axis_register_slice_data_buffer
set_property -dict [list CONFIG.TDATA_NUM_BYTES {20} CONFIG.Component_Name {axis_register_slice_data_buffer}] [get_ips axis_register_slice_data_buffer]
generate_target {instantiation_template} [get_files {{$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_register_slice_data_buffer/axis_register_slice_data_buffer.xci}}]
