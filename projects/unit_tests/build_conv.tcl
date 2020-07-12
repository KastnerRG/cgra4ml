# create project
# create_project $PROJ_NAME $PROJ_FOLDER -part xc7z020clg484-1
# set_property board_part xilinx.com:zc702:part0:1.4 [current_project]
set PROJ_NAME conv
set PROJ_FOLDER ./conv
set SOURCE_FOLDER ../../src

create_project $PROJ_NAME $PROJ_FOLDER -part xc7z045ffg900-2
set_property board_part xilinx.com:zc706:part0:1.4 [current_project]

# Create Multiplier IP
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_0
set_property -dict [list CONFIG.Operation_Type {Multiply} CONFIG.A_Precision_Type {Half} CONFIG.Flow_Control {NonBlocking} CONFIG.Maximum_Latency {false} CONFIG.C_Latency {1} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {true} CONFIG.C_A_Exponent_Width {5} CONFIG.C_A_Fraction_Width {11} CONFIG.Result_Precision_Type {Half} CONFIG.C_Result_Exponent_Width {5} CONFIG.C_Result_Fraction_Width {11} CONFIG.C_Accum_Msb {32} CONFIG.C_Accum_Lsb {-24} CONFIG.C_Accum_Input_Msb {15} CONFIG.C_Mult_Usage {Full_Usage} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Rate {1}] [get_ips floating_point_0]
generate_target {instantiation_template} [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_0/floating_point_0.xci]

update_compile_order -fileset sources_1
set_property generate_synth_checkpoint false [get_files  $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_0/floating_point_0.xci]
generate_target all [get_files  $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_0/floating_point_0.xci]

export_ip_user_files -of_objects [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_0/floating_point_0.xci] -no_script -sync -force -quiet
export_simulation -of_objects [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_0/floating_point_0.xci] -directory $PROJ_FOLDER/$PROJ_NAME.ip_user_files/sim_scripts -ip_user_files_dir $PROJ_FOLDER/$PROJ_NAME.ip_user_files -ipstatic_source_dir $PROJ_FOLDER/$PROJ_NAME.ip_user_files/ipstatic -lib_map_path [list {modelsim=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/modelsim} {questa=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/questa} {ies=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/ies} {xcelium=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/xcelium} {vcs=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/vcs} {riviera=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet

# Create Adder IP

create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_1
set_property -dict [list CONFIG.Add_Sub_Value {Add} CONFIG.A_Precision_Type {Half} CONFIG.C_Mult_Usage {No_Usage} CONFIG.Flow_Control {NonBlocking} CONFIG.Maximum_Latency {false} CONFIG.C_Latency {1} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {true} CONFIG.C_A_Exponent_Width {5} CONFIG.C_A_Fraction_Width {11} CONFIG.Result_Precision_Type {Half} CONFIG.C_Result_Exponent_Width {5} CONFIG.C_Result_Fraction_Width {11} CONFIG.C_Accum_Msb {32} CONFIG.C_Accum_Lsb {-24} CONFIG.C_Accum_Input_Msb {15} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Rate {1}] [get_ips floating_point_1]
generate_target {instantiation_template} [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_1/floating_point_1.xci]

update_compile_order -fileset sources_1
set_property generate_synth_checkpoint false [get_files  $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_1/floating_point_1.xci]
generate_target all [get_files  $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_1/floating_point_1.xci]

export_ip_user_files -of_objects [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_1/floating_point_1.xci] -no_script -sync -force -quiet
export_simulation -of_objects [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_1/floating_point_1.xci] -directory $PROJ_FOLDER/$PROJ_NAME.ip_user_files/sim_scripts -ip_user_files_dir $PROJ_FOLDER/$PROJ_NAME.ip_user_files -ipstatic_source_dir $PROJ_FOLDER/$PROJ_NAME.ip_user_files/ipstatic -lib_map_path [list {modelsim=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/modelsim} {questa=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/questa} {ies=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/ies} {xcelium=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/xcelium} {vcs=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/vcs} {riviera=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet


# Add sources

add_files -norecurse $SOURCE_FOLDER/conv_core_wrapper.v
set_property top conv_core_wrapper [current_fileset]
add_files -norecurse $SOURCE_FOLDER/T_reg.v
add_files -norecurse $SOURCE_FOLDER/conv_unit.v
add_files -norecurse $SOURCE_FOLDER/kernel_switch.v
add_files -norecurse $SOURCE_FOLDER/conv_core.v
add_files -norecurse $SOURCE_FOLDER/controller.v
add_files -norecurse $SOURCE_FOLDER/data_switch.v
add_files -norecurse $SOURCE_FOLDER/d_in_buffer.v
add_files -norecurse $SOURCE_FOLDER/kernel_buffer.v
add_files -norecurse $SOURCE_FOLDER/reg_array_buffer.v
add_files -norecurse $SOURCE_FOLDER/reg_buffer.v
update_compile_order -fileset sources_1

# Add simulation sources
# set_property SOURCE_SET sources_1 [get_filesets sim_1]
# current_design rtl_1
# add_files -fileset sim_1 -norecurse $SOURCE_FOLDER/data_switch_tb.v
# update_compile_order -fileset sim_1
# set_property top data_switch_tb [get_filesets sim_1]
# set_property top_lib xil_defaultlib [get_filesets sim_1]
# update_compile_order -fileset sim_1

# create_fileset -simset kernel_switch_sim
# set_property SOURCE_SET sources_1 [get_filesets kernel_switch_sim]
# add_files -fileset kernel_switch_sim -norecurse $SOURCE_FOLDER/kernel_switch_tb.v
# current_fileset -simset [ get_filesets kernel_switch_sim ]
# update_compile_order -fileset kernel_switch_sim
# set_property top kernel_switch_tb [get_filesets kernel_switch_sim]
# set_property top_lib xil_defaultlib [get_filesets kernel_switch_sim]
# update_compile_order -fileset kernel_switch_sim

# create_fileset -simset T_reg_test
# set_property SOURCE_SET sources_1 [get_filesets T_reg_test]
# add_files -fileset T_reg_test -norecurse $SOURCE_FOLDER/T_reg_tb.v
# update_compile_order -fileset T_reg_test
# set_property top T_reg_tb [get_filesets T_reg_test]
# set_property top_lib xil_defaultlib [get_filesets T_reg_test]
# update_compile_order -fileset T_reg_test
# current_fileset -simset [ get_filesets T_reg_test ]