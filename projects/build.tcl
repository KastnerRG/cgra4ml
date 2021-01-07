set PROJ_NAME support
set PROJ_FOLDER support
set SOURCE_FOLDER ../src

set AXIS_FREQUENCY_MHZ   250
set WORD_WIDTH           8
set WORD_WIDTH_CONV_OUT  32
set WORD_WIDTH_LRELU_1   32
set WORD_WIDTH_LRELU_2   16
set WORD_WIDTH_LRELU_OUT 8

set UNITS   3
set GROUPS  1
set COPIES  1
set MEMBERS 4

set TUSER_WIDTH_LRELU_IN       8
set TUSER_WIDTH_LRELU_FMA_1_IN 3
set TUSER_WIDTH_MAXPOOL_IN     2

set KERNEL_W_MAX  3
set MAX_IM_WIDTH  384
set MAX_IM_HEIGHT 256
set MAX_CHANNELS  1024

# # create project
# create_project $PROJ_NAME ./$PROJ_FOLDER -part xc7z045ffg900-2
# set_property board_part xilinx.com:zc706:part0:1.4 [current_project]

# Create IPs
set IP_NAMES [list ]


set IP_NAME "axis_dw_gum_gu_active"
lappend IP_NAMES $IP_NAME
set S_BYTES [expr "$MEMBERS * $GROUPS * $UNITS * $WORD_WIDTH_CONV_OUT / 8"]
set M_BYTES [expr "$GROUPS * $UNITS * $WORD_WIDTH_CONV_OUT / 8"]
set TID_WIDTH $TUSER_WIDTH_LRELU_IN
set T_LAST 1
set T_KEEP 0
create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES CONFIG.M_TDATA_NUM_BYTES $M_BYTES CONFIG.TID_WIDTH $TID_WIDTH CONFIG.HAS_TLAST $T_LAST CONFIG.HAS_TKEEP $T_KEEP] [get_ips $IP_NAME]

set IP_NAME "axis_dw_gum_gu"
lappend IP_NAMES $IP_NAME
set S_BYTES [expr "$MEMBERS * $GROUPS * $UNITS * $WORD_WIDTH_CONV_OUT / 8"]
set M_BYTES [expr "$GROUPS * $UNITS * $WORD_WIDTH_CONV_OUT / 8"]
set T_LAST 0
set T_KEEP 0
create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES CONFIG.M_TDATA_NUM_BYTES $M_BYTES CONFIG.HAS_TLAST $T_LAST CONFIG.HAS_TKEEP $T_KEEP] [get_ips $IP_NAME]

set IP_NAME "axis_reg_slice_lrelu"
lappend IP_NAMES $IP_NAME
set DATA_BYTES [expr "$GROUPS * $COPIES * $UNITS * $WORD_WIDTH / 8"]
set T_LAST 0
set T_KEEP 0
set TUSER_WIDTH $TUSER_WIDTH_MAXPOOL_IN
create_ip -name axis_register_slice -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
set_property -dict [list CONFIG.TDATA_NUM_BYTES $DATA_BYTES CONFIG.TUSER_WIDTH $TUSER_WIDTH CONFIG.HAS_TKEEP $T_KEEP CONFIG.HAS_TLAST $T_LAST] [get_ips $IP_NAME]

set IP_NAME "fixed_to_float_active"
lappend IP_NAMES $IP_NAME
set TUSER_WIDTH $TUSER_WIDTH_LRELU_IN
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list CONFIG.Operation_Type {Fixed_to_float} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $WORD_WIDTH_CONV_OUT CONFIG.Flow_Control {NonBlocking} CONFIG.C_A_Fraction_Width {0} CONFIG.Result_Precision_Type {Single} CONFIG.C_Result_Exponent_Width {8} CONFIG.C_Result_Fraction_Width {24} CONFIG.C_Accum_Msb {32} CONFIG.C_Accum_Lsb {-31} CONFIG.C_Accum_Input_Msb {32} CONFIG.C_Mult_Usage {No_Usage} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Latency {6} CONFIG.C_Rate {1} CONFIG.Has_ACLKEN {true} CONFIG.Has_A_TUSER {true} CONFIG.A_TUSER_Width $TUSER_WIDTH ] [get_ips $IP_NAME]

set IP_NAME "fixed_to_float"
lappend IP_NAMES $IP_NAME
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list CONFIG.Operation_Type {Fixed_to_float} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $WORD_WIDTH_CONV_OUT CONFIG.Flow_Control {NonBlocking} CONFIG.C_A_Fraction_Width {0} CONFIG.Result_Precision_Type {Single} CONFIG.C_Result_Exponent_Width {8} CONFIG.C_Result_Fraction_Width {24} CONFIG.C_Accum_Msb {32} CONFIG.C_Accum_Lsb {-31} CONFIG.C_Accum_Input_Msb {32} CONFIG.C_Mult_Usage {No_Usage} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Latency {6} CONFIG.C_Rate {1} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} ] [get_ips $IP_NAME]


set IP_NAME "float_32_ma_active"
lappend IP_NAMES $IP_NAME
set LATENCY 16
set TUSER_WIDTH $TUSER_WIDTH_LRELU_FMA_1_IN
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list  CONFIG.Operation_Type {FMA} CONFIG.Add_Sub_Value {Add} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.Has_A_TLAST {false} CONFIG.Has_A_TUSER {true} CONFIG.A_TUSER_Width $TUSER_WIDTH CONFIG.A_Precision_Type {Single} CONFIG.C_A_Exponent_Width {8} CONFIG.C_A_Fraction_Width {24} CONFIG.Result_Precision_Type {Single} CONFIG.C_Result_Exponent_Width {8} CONFIG.C_Result_Fraction_Width {24} CONFIG.C_Mult_Usage {Medium_Usage} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Latency $LATENCY CONFIG.C_Rate {1} CONFIG.RESULT_TLAST_Behv {Null}] [get_ips $IP_NAME]

set IP_NAME "float_32_ma"
lappend IP_NAMES $IP_NAME
set LATENCY 16
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list  CONFIG.Operation_Type {FMA} CONFIG.Add_Sub_Value {Add} CONFIG.C_Mult_Usage {Medium_Usage} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.A_Precision_Type {Single} CONFIG.C_A_Exponent_Width {8} CONFIG.C_A_Fraction_Width {24} CONFIG.Result_Precision_Type {Single} CONFIG.C_Result_Exponent_Width {8} CONFIG.C_Result_Fraction_Width {24} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Latency $LATENCY CONFIG.C_Rate {1}] [get_ips $IP_NAME]

set IP_NAME "float_16_ma_active"
lappend IP_NAMES $IP_NAME
set LATENCY 15
set TUSER_WIDTH $TUSER_WIDTH_MAXPOOL_IN
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list  CONFIG.Operation_Type {FMA} CONFIG.Add_Sub_Value {Add} CONFIG.A_Precision_Type {Half} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.C_A_Exponent_Width {5} CONFIG.Has_A_TUSER {true} CONFIG.A_TUSER_Width $TUSER_WIDTH CONFIG.C_A_Fraction_Width {11} CONFIG.Result_Precision_Type {Half} CONFIG.C_Result_Exponent_Width {5} CONFIG.C_Result_Fraction_Width {11} CONFIG.C_Accum_Msb {32} CONFIG.C_Accum_Lsb {-24} CONFIG.C_Accum_Input_Msb {15} CONFIG.C_Mult_Usage {Medium_Usage} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Latency $LATENCY CONFIG.C_Rate {1}] [get_ips $IP_NAME]

set IP_NAME "float_16_ma"
lappend IP_NAMES $IP_NAME
set LATENCY 15
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list  CONFIG.Operation_Type {FMA} CONFIG.Add_Sub_Value {Add} CONFIG.A_Precision_Type {Half} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.C_A_Exponent_Width {5} CONFIG.C_A_Fraction_Width {11} CONFIG.Result_Precision_Type {Half} CONFIG.C_Result_Exponent_Width {5} CONFIG.C_Result_Fraction_Width {11} CONFIG.C_Accum_Msb {32} CONFIG.C_Accum_Lsb {-24} CONFIG.C_Accum_Input_Msb {15} CONFIG.C_Mult_Usage {Medium_Usage} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Latency $LATENCY CONFIG.C_Rate {1}] [get_ips $IP_NAME]

set IP_NAME "float_to_fixed_active"
lappend IP_NAMES $IP_NAME
set TUSER_WIDTH $TUSER_WIDTH_MAXPOOL_IN
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list  CONFIG.Operation_Type {Float_to_fixed} CONFIG.A_Precision_Type {Half} CONFIG.C_Result_Exponent_Width {8} CONFIG.C_Result_Fraction_Width {0} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.Has_A_TUSER {true} CONFIG.A_TUSER_Width $TUSER_WIDTH CONFIG.C_A_Exponent_Width {5} CONFIG.C_A_Fraction_Width {11} CONFIG.Result_Precision_Type {Custom} CONFIG.C_Accum_Msb {32} CONFIG.C_Accum_Lsb {-24} CONFIG.C_Accum_Input_Msb {15} CONFIG.C_Mult_Usage {No_Usage} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Latency {5} CONFIG.C_Rate {1}] [get_ips $IP_NAME]

set IP_NAME "float_to_fixed"
lappend IP_NAMES $IP_NAME
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list  CONFIG.Operation_Type {Float_to_fixed} CONFIG.A_Precision_Type {Half} CONFIG.C_Result_Exponent_Width {8} CONFIG.C_Result_Fraction_Width {0} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.C_A_Exponent_Width {5} CONFIG.C_A_Fraction_Width {11} CONFIG.Result_Precision_Type {Custom} CONFIG.C_Accum_Msb {32} CONFIG.C_Accum_Lsb {-24} CONFIG.C_Accum_Input_Msb {15} CONFIG.C_Mult_Usage {No_Usage} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Latency {5} CONFIG.C_Rate {1}] [get_ips $IP_NAME]

set IP_NAME "bram_lrelu"
lappend IP_NAMES $IP_NAME
set R_WIDTH 16
set R_DEPTH [expr "$MEMBERS * $KERNEL_W_MAX"]
set W_WIDTH [expr "$MEMBERS * $WORD_WIDTH"]
set W_DEPTH [expr "$R_WIDTH * $R_DEPTH / $W_WIDTH"]
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name $IP_NAME
set_property -dict [list  CONFIG.Memory_Type {Simple_Dual_Port_RAM} CONFIG.Assume_Synchronous_Clk {true} CONFIG.Write_Width_A $W_WIDTH CONFIG.Write_Depth_A $W_DEPTH CONFIG.Read_Width_A $W_WIDTH CONFIG.Operating_Mode_A {NO_CHANGE} CONFIG.Write_Width_B $R_WIDTH CONFIG.Read_Width_B $R_WIDTH CONFIG.Operating_Mode_B {READ_FIRST} CONFIG.Enable_B {Use_ENB_Pin} CONFIG.Register_PortA_Output_of_Memory_Primitives {false} CONFIG.Register_PortB_Output_of_Memory_Primitives {true} CONFIG.Port_B_Clock {100} CONFIG.Port_B_Enable_Rate {100}] [get_ips $IP_NAME]

set IP_NAME "bram_lrelu_edge"
lappend IP_NAMES $IP_NAME
set R_WIDTH 16
set R_DEPTH [expr "$MEMBERS"]
set W_WIDTH [expr "$MEMBERS * $WORD_WIDTH"]
set W_DEPTH [expr "$R_WIDTH * $R_DEPTH / $W_WIDTH"]
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name $IP_NAME
set_property -dict [list  CONFIG.Memory_Type {Simple_Dual_Port_RAM} CONFIG.Assume_Synchronous_Clk {true} CONFIG.Write_Width_A $W_WIDTH CONFIG.Write_Depth_A $W_DEPTH CONFIG.Read_Width_A $W_WIDTH CONFIG.Operating_Mode_A {NO_CHANGE} CONFIG.Write_Width_B $R_WIDTH CONFIG.Read_Width_B $R_WIDTH CONFIG.Operating_Mode_B {READ_FIRST} CONFIG.Enable_B {Use_ENB_Pin} CONFIG.Register_PortA_Output_of_Memory_Primitives {false} CONFIG.Register_PortB_Output_of_Memory_Primitives {true} CONFIG.Port_B_Clock {100} CONFIG.Port_B_Enable_Rate {100}] [get_ips $IP_NAME]

set IP_NAME "axis_reg_slice_maxpool"
lappend IP_NAMES $IP_NAME
set DATA_BYTES [expr "$GROUPS * $COPIES * $UNITS * $WORD_WIDTH / 8"]
set T_LAST 1
set T_KEEP 1
create_ip -name axis_register_slice -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
set_property -dict [list CONFIG.TDATA_NUM_BYTES $DATA_BYTES CONFIG.HAS_TKEEP $T_KEEP CONFIG.HAS_TLAST $T_LAST] [get_ips $IP_NAME]

# Generate IP output products

foreach IP_NAME $IP_NAMES {
  generate_target {instantiation_template} [get_files  $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/$IP_NAME/$IP_NAME.xci]
  set_property generate_synth_checkpoint 0 [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/$IP_NAME/$IP_NAME.xci]
  export_ip_user_files -of_objects [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/$IP_NAME/$IP_NAME.xci] -no_script -sync -force -quiet
  export_simulation -of_objects [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/$IP_NAME/$IP_NAME.xci] -directory $PROJ_FOLDER/$PROJ_NAME.ip_user_files/sim_scripts -ip_user_files_dir $PROJ_FOLDER/$PROJ_NAME.ip_user_files -ipstatic_source_dir $PROJ_FOLDER/$PROJ_NAME.ip_user_files/ipstatic -lib_map_path [list {modelsim=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/modelsim} {questa=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/questa} {riviera=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/riviera} {activehdl=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/activehdl}] -use_ip_compiled_libs -force -quiet
  generate_target Simulation [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/$IP_NAME/$IP_NAME.xci]
}