#******************************** USER DEFINED PARAMETERS **********************************
set PROJ_NAME sys
set PROJ_FOLDER sys
set SOURCE_FOLDER ../src

set CONV_PAIRS          1 
set FREQUENCY_MHZ       85

set DATA_WIDTH          16
set CONV_UNITS          8
set MAX_IM_WIDTH        384
set MAX_IM_HEIGHT       256
set MAX_CHANNELS        1024
set RAM_LATENCY         2
set FIFO_DEPTH          4

set CONV_CORES              [expr $CONV_PAIRS * 2]
set MAX_NUM_BLKS            [expr int(ceil($MAX_IM_HEIGHT / $CONV_UNITS))]
set CH_IN_COUNTER_WIDTH     [expr int(ceil(log($MAX_CHANNELS)/log(2))) ]
set NUM_BLKS_COUNTER_WIDTH  [expr int(ceil(log($MAX_NUM_BLKS)/log(2))) ]
set IM_WIDTH_COUNTER_WIDTH  [expr int(ceil(log($MAX_IM_WIDTH)/log(2))) ]
set MEM_DEPTH               [expr "$MAX_CHANNELS * 3 + 1"]
set ADDRS_WIDTH             [expr int(ceil(log($MEM_DEPTH)/log(2))) ]
set ROTATE_WIDTH            [expr int(ceil(log($MAX_IM_WIDTH * $MAX_NUM_BLKS)/log(2)))]
set FIFO_COUNTER_WIDTH      [expr int(log($FIFO_DEPTH)/log(2))]
set BRAM_WIDTH              [expr $DATA_WIDTH * 3 * $CONV_CORES]
set c_SHIFT_COUNTER_WIDTH   [expr int(log($CONV_UNITS)/log(2))]
set PARAM_WIRE_WIDTH        [expr $CH_IN_COUNTER_WIDTH + $NUM_BLKS_COUNTER_WIDTH + $IM_WIDTH_COUNTER_WIDTH + $ADDRS_WIDTH + $ROTATE_WIDTH + 3]
set Nb                      [expr $CONV_CORES * $DATA_WIDTH]

set WEIGHTS_DMA_WIDTH       [expr min(1024, 2**int(ceil(log(3*$Nb)/log(2))))]
set LRELU_UNITS             [expr 2**int(min(3,max(1, ceil(log(4*$CONV_CORES/$DATA_WIDTH)/log(2)))))]
set OUTPUT_DMA_WIDTH        [expr $LRELU_UNITS * $DATA_WIDTH]
set IMAGE_DMA_WIDTH         [expr 2**int(ceil(log(($CONV_UNITS+2)*$DATA_WIDTH)/log(2)))]


set p_COUNT_3x3_ref         [expr     ($CONV_UNITS +2) * $CONV_CORES / (    $LRELU_UNITS) - 1];
set p_COUNT_3x3_max_ref     [expr     ($CONV_UNITS +2) * $CONV_CORES / (2 * $LRELU_UNITS) - 1];
set p_COUNT_1x1_ref         [expr 3 * ($CONV_UNITS +2) * $CONV_CORES / (    $LRELU_UNITS) - 1];
set p_COUNT_1x1_max_ref     [expr 3 * ($CONV_UNITS +2) * $CONV_CORES / (2 * $LRELU_UNITS) - 1];


#******************************** STORE PARAMETERS **********************************

set f0 [open $SOURCE_FOLDER/system_parameters.v w]
puts $f0 "/*\nContains the parameters of the system\n*/"

puts $f0 "\n// Main parameters\n"
puts $f0 "`define CONV_UNITS            $CONV_UNITS"
puts $f0 "`define CONV_PAIRS            $CONV_PAIRS"
puts $f0 "`define CONV_CORES            $CONV_CORES"
puts $f0 "`define RAM_LATENCY           $RAM_LATENCY"
puts $f0 "`define LReLU_UNITS           $LRELU_UNITS"


puts $f0 "\n// Register Widths\n"
puts $f0 "`define DATA_WIDTH             $DATA_WIDTH"
puts $f0 "`define CH_IN_COUNTER_WIDTH    $CH_IN_COUNTER_WIDTH"
puts $f0 "`define NUM_BLKS_COUNTER_WIDTH $NUM_BLKS_COUNTER_WIDTH"
puts $f0 "`define IM_WIDTH_COUNTER_WIDTH $IM_WIDTH_COUNTER_WIDTH"
puts $f0 "`define ADDRS_WIDTH            $ADDRS_WIDTH"
puts $f0 "`define ROTATE_WIDTH           $ROTATE_WIDTH"
puts $f0 "`define FIFO_DEPTH             $FIFO_DEPTH"
puts $f0 "`define BRAM_WIDTH             $BRAM_WIDTH"
puts $f0 "`define FIFO_COUNTER_WIDTH     $FIFO_COUNTER_WIDTH"
puts $f0 "`define c_SHIFT_COUNTER_WIDTH  $c_SHIFT_COUNTER_WIDTH"
puts $f0 "`define PARAM_WIRE_WIDTH       $PARAM_WIRE_WIDTH"

puts $f0 "\n// DMA Widths\n"
puts $f0 "`define WEIGHTS_DMA_WIDTH      $WEIGHTS_DMA_WIDTH"
puts $f0 "`define IMAGE_DMA_WIDTH        $IMAGE_DMA_WIDTH"
puts $f0 "`define OUTPUT_DMA_WIDTH       $OUTPUT_DMA_WIDTH"
puts $f0 "`define Nb                     $Nb"

puts $f0 "\n// Output Pipe References\n"
puts $f0 "`define p_COUNT_3x3_ref       $p_COUNT_3x3_ref"
puts $f0 "`define p_COUNT_3x3_max_ref   $p_COUNT_3x3_max_ref"
puts $f0 "`define p_COUNT_1x1_ref       $p_COUNT_1x1_ref"
puts $f0 "`define p_COUNT_1x1_max_ref   $p_COUNT_1x1_max_ref"

close $f0

# create project
create_project $PROJ_NAME ./$PROJ_FOLDER -part xc7z045ffg900-2
set_property board_part xilinx.com:zc706:part0:1.4 [current_project]

#******************************** CREATE IPS **********************************

############### IPs for CONVOLUTION UNIT

# Create Multiplier IP
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_0
set_property -dict [list CONFIG.Operation_Type {Multiply} CONFIG.A_Precision_Type {Half} CONFIG.Flow_Control {NonBlocking} CONFIG.Maximum_Latency {false} CONFIG.C_Latency {1} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {true} CONFIG.C_A_Exponent_Width {5} CONFIG.C_A_Fraction_Width {11} CONFIG.Result_Precision_Type {Half} CONFIG.C_Result_Exponent_Width {5} CONFIG.C_Result_Fraction_Width {11} CONFIG.C_Accum_Msb {32} CONFIG.C_Accum_Lsb {-24} CONFIG.C_Accum_Input_Msb {15} CONFIG.C_Mult_Usage {Full_Usage} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Rate {1}] [get_ips floating_point_0]
generate_target {instantiation_template} [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_0/floating_point_0.xci]
set_property generate_synth_checkpoint false [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_0/floating_point_0.xci]
generate_target all [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_0/floating_point_0.xci]
export_ip_user_files -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_0/floating_point_0.xci] -no_script -sync -force -quiet
export_simulation -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_0/floating_point_0.xci] -directory ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/sim_scripts -ip_user_files_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files -ipstatic_source_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/ipstatic -lib_map_path [list {modelsim=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/modelsim} {questa=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/questa} {ies=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/ies} {xcelium=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/xcelium} {vcs=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/vcs} {riviera=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet

# Create Adder IP
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_1
set_property -dict [list CONFIG.Add_Sub_Value {Add} CONFIG.A_Precision_Type {Half} CONFIG.C_Mult_Usage {No_Usage} CONFIG.Flow_Control {NonBlocking} CONFIG.Maximum_Latency {false} CONFIG.C_Latency {1} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {true} CONFIG.C_A_Exponent_Width {5} CONFIG.C_A_Fraction_Width {11} CONFIG.Result_Precision_Type {Half} CONFIG.C_Result_Exponent_Width {5} CONFIG.C_Result_Fraction_Width {11} CONFIG.C_Accum_Msb {32} CONFIG.C_Accum_Lsb {-24} CONFIG.C_Accum_Input_Msb {15} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Rate {1}] [get_ips floating_point_1]
generate_target {instantiation_template} [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_1/floating_point_1.xci]
set_property generate_synth_checkpoint false [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_1/floating_point_1.xci]
generate_target all [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_1/floating_point_1.xci]
export_ip_user_files -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_1/floating_point_1.xci] -no_script -sync -force -quiet
export_simulation -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_1/floating_point_1.xci] -directory ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/sim_scripts -ip_user_files_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files -ipstatic_source_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/ipstatic -lib_map_path [list {modelsim=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/modelsim} {questa=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/questa} {ies=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/ies} {xcelium=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/xcelium} {vcs=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/vcs} {riviera=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet


############### IPs for MAXPOOL UNIT
# Create Comparator IP (with latency 1)
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_4
set_property -dict [list CONFIG.Operation_Type {Compare} CONFIG.C_Compare_Operation {Greater_Than} CONFIG.A_Precision_Type {Half} CONFIG.Flow_Control {NonBlocking} CONFIG.Maximum_Latency {false} CONFIG.C_Latency {1} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {true} CONFIG.C_A_Exponent_Width {5} CONFIG.C_A_Fraction_Width {11} CONFIG.Result_Precision_Type {Custom} CONFIG.C_Result_Exponent_Width {1} CONFIG.C_Result_Fraction_Width {0} CONFIG.C_Accum_Msb {32} CONFIG.C_Accum_Lsb {-24} CONFIG.C_Accum_Input_Msb {15} CONFIG.C_Mult_Usage {No_Usage} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Rate {1}] [get_ips floating_point_4]
generate_target {instantiation_template} [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_4/floating_point_4.xci]
set_property generate_synth_checkpoint false [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_4/floating_point_4.xci]
generate_target all [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_4/floating_point_4.xci]
export_ip_user_files -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_4/floating_point_4.xci] -no_script -sync -force -quiet
export_simulation -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/floating_point_4/floating_point_4.xci] -directory ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/sim_scripts -ip_user_files_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files -ipstatic_source_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/ipstatic -lib_map_path [list {modelsim=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/modelsim} {questa=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/questa} {ies=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/ies} {xcelium=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/xcelium} {vcs=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/vcs} {riviera=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet

############### IPs for WEIGHTS ROTATOR
# Create Block RAM IP
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name blk_mem_gen_0
set_property -dict [list CONFIG.Write_Width_A "$BRAM_WIDTH" CONFIG.Write_Depth_A "$MEM_DEPTH" CONFIG.Read_Width_A "$BRAM_WIDTH" ] [get_ips blk_mem_gen_0] 
generate_target {instantiation_template} [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0.xci]

set_property generate_synth_checkpoint false [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0.xci]
generate_target all [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0.xci]
export_ip_user_files -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0.xci] -no_script -sync -force -quiet
export_simulation -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0.xci] -directory ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/sim_scripts -ip_user_files_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files -ipstatic_source_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/ipstatic -lib_map_path [list {modelsim=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/modelsim} {questa=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/questa} {ies=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/ies} {xcelium=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/xcelium} {vcs=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/vcs} {riviera=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet


############### IPs for INPUT PIPE

# Weights: DMA to 3N
#"axis_dw_dma_3n"
set IP_NAME "axis_dwidth_converter_0"
set S_BYTES [expr "$WEIGHTS_DMA_WIDTH / 8"]
set M_BYTES [expr "$CONV_CORES * 3 * $DATA_WIDTH / 8"]
set T_LAST 1

create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name axis_dwidth_converter_0
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES CONFIG.M_TDATA_NUM_BYTES $M_BYTES CONFIG.HAS_TLAST $T_LAST CONFIG.HAS_TKEEP {1} CONFIG.HAS_MI_TKEEP {1}] [get_ips axis_dwidth_converter_0]
generate_target {instantiation_template} [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_0/axis_dwidth_converter_0.xci]
update_compile_order -fileset sources_1
set_property generate_synth_checkpoint false [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_0/axis_dwidth_converter_0.xci]
generate_target all [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_0/axis_dwidth_converter_0.xci]
export_ip_user_files -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_0/axis_dwidth_converter_0.xci] -no_script -sync -force -quiet
export_simulation -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_0/axis_dwidth_converter_0.xci] -directory ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/sim_scripts -ip_user_files_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files -ipstatic_source_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/ipstatic -lib_map_path [list {modelsim=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/modelsim} {questa=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/questa} {ies=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/ies} {xcelium=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/xcelium} {vcs=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/vcs} {riviera=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet


# Weights: 3N to 9N
# "axis_dw_3n_9n"
set IP_NAME "axis_dwidth_converter_1"
set S_BYTES [expr "$CONV_CORES * 3 * $DATA_WIDTH / 8"]
set M_BYTES [expr "$CONV_CORES * 9 * $DATA_WIDTH / 8"]
set T_LAST 0

create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name axis_dwidth_converter_1
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES CONFIG.M_TDATA_NUM_BYTES $M_BYTES CONFIG.HAS_TLAST $T_LAST CONFIG.HAS_TKEEP {0} CONFIG.HAS_MI_TKEEP {1}] [get_ips axis_dwidth_converter_1]
generate_target {instantiation_template} [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_1/axis_dwidth_converter_1.xci]
update_compile_order -fileset sources_1
set_property generate_synth_checkpoint false [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_1/axis_dwidth_converter_1.xci]
generate_target all [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_1/axis_dwidth_converter_1.xci]
export_ip_user_files -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_1/axis_dwidth_converter_1.xci] -no_script -sync -force -quiet
export_simulation -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_1/axis_dwidth_converter_1.xci] -directory ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/sim_scripts -ip_user_files_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files -ipstatic_source_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/ipstatic -lib_map_path [list {modelsim=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/modelsim} {questa=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/questa} {ies=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/ies} {xcelium=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/xcelium} {vcs=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/vcs} {riviera=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet


# "axis_dw_3n_9n2"
set IP_NAME "axis_dwidth_converter_2"
set S_BYTES [expr "$CONV_CORES * 3 * $DATA_WIDTH / 8"]
set M_BYTES [expr "$CONV_CORES * 9 * $DATA_WIDTH / (8*2)"]
set T_LAST 0

create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name axis_dwidth_converter_2
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES CONFIG.M_TDATA_NUM_BYTES $M_BYTES CONFIG.HAS_TLAST $T_LAST CONFIG.HAS_TKEEP {0} CONFIG.HAS_MI_TKEEP {1}] [get_ips axis_dwidth_converter_2]
generate_target {instantiation_template} [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_2/axis_dwidth_converter_2.xci]
update_compile_order -fileset sources_1
set_property generate_synth_checkpoint false [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_2/axis_dwidth_converter_2.xci]
generate_target all [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_2/axis_dwidth_converter_2.xci]
export_ip_user_files -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_2/axis_dwidth_converter_2.xci] -no_script -sync -force -quiet
export_simulation -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_2/axis_dwidth_converter_2.xci] -directory ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/sim_scripts -ip_user_files_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files -ipstatic_source_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/ipstatic -lib_map_path [list {modelsim=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/modelsim} {questa=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/questa} {ies=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/ies} {xcelium=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/xcelium} {vcs=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/vcs} {riviera=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet


# Image: DMA to Conv 
# "axis_dw_10"
set IP_NAME "axis_dwidth_converter_3"
set S_BYTES [expr "$IMAGE_DMA_WIDTH / 8"]
set M_BYTES [expr "($CONV_UNITS+2) * $DATA_WIDTH / 8"] 
set T_LAST 1
create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name axis_dwidth_converter_3
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES CONFIG.M_TDATA_NUM_BYTES $M_BYTES CONFIG.HAS_TLAST $T_LAST CONFIG.HAS_TKEEP {1} CONFIG.HAS_MI_TKEEP {1}] [get_ips axis_dwidth_converter_3]
generate_target {instantiation_template} [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_3/axis_dwidth_converter_3.xci]
update_compile_order -fileset sources_1
set_property generate_synth_checkpoint false [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_3/axis_dwidth_converter_3.xci]
generate_target all [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_3/axis_dwidth_converter_3.xci]
export_ip_user_files -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_3/axis_dwidth_converter_3.xci] -no_script -sync -force -quiet
export_simulation -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_3/axis_dwidth_converter_3.xci] -directory ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/sim_scripts -ip_user_files_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files -ipstatic_source_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/ipstatic -lib_map_path [list {modelsim=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/modelsim} {questa=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/questa} {ies=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/ies} {xcelium=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/xcelium} {vcs=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/vcs} {riviera=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet


############### IPs for OUTPUT PIPE

#Output:  [1]N to [8]N
# "axis_dw_1_8"
set IP_NAME "axis_dwidth_converter_5"
set S_BYTES [expr "$DATA_WIDTH / 8"]
set M_BYTES [expr "$DATA_WIDTH * 8 /8"]
set T_LAST 0

create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name axis_dwidth_converter_5
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES CONFIG.M_TDATA_NUM_BYTES $M_BYTES CONFIG.HAS_TLAST $T_LAST CONFIG.HAS_TKEEP {0} CONFIG.HAS_MI_TKEEP {1}] [get_ips axis_dwidth_converter_5]
generate_target {instantiation_template} [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_5/axis_dwidth_converter_5.xci]
update_compile_order -fileset sources_1
set_property generate_synth_checkpoint false [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_5/axis_dwidth_converter_5.xci]
generate_target all [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_5/axis_dwidth_converter_5.xci]
export_ip_user_files -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_5/axis_dwidth_converter_5.xci] -no_script -sync -force -quiet
export_simulation -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_5/axis_dwidth_converter_5.xci] -directory ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/sim_scripts -ip_user_files_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files -ipstatic_source_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/ipstatic -lib_map_path [list {modelsim=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/modelsim} {questa=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/questa} {ies=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/ies} {xcelium=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/xcelium} {vcs=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/vcs} {riviera=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet

#Output:  [1]N to [8]N
# "axis_dw_1_4"
set IP_NAME "axis_dwidth_converter_6"
set S_BYTES [expr "$DATA_WIDTH / 8"]
set M_BYTES [expr "$DATA_WIDTH * 4 /8"]
set T_LAST 0

create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name axis_dwidth_converter_6
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES CONFIG.M_TDATA_NUM_BYTES $M_BYTES CONFIG.HAS_TLAST $T_LAST CONFIG.HAS_TKEEP {0} CONFIG.HAS_MI_TKEEP {1}] [get_ips axis_dwidth_converter_6]
generate_target {instantiation_template} [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_6/axis_dwidth_converter_6.xci]
update_compile_order -fileset sources_1
set_property generate_synth_checkpoint false [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_6/axis_dwidth_converter_6.xci]
generate_target all [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_6/axis_dwidth_converter_6.xci]
export_ip_user_files -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_6/axis_dwidth_converter_6.xci] -no_script -sync -force -quiet
export_simulation -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_6/axis_dwidth_converter_6.xci] -directory ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/sim_scripts -ip_user_files_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files -ipstatic_source_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/ipstatic -lib_map_path [list {modelsim=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/modelsim} {questa=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/questa} {ies=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/ies} {xcelium=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/xcelium} {vcs=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/vcs} {riviera=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet


# Output: [8]N to DMA
# "axis_dw_8n_dma"
set IP_NAME "axis_dwidth_converter_7"
set S_BYTES [expr "$DATA_WIDTH * ($CONV_UNITS+2) * $CONV_CORES /8"]
set M_BYTES [expr "$OUTPUT_DMA_WIDTH /8"]
set T_LAST 0

create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name axis_dwidth_converter_7
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES CONFIG.M_TDATA_NUM_BYTES $M_BYTES CONFIG.HAS_TLAST $T_LAST CONFIG.HAS_TKEEP {0} CONFIG.HAS_MI_TKEEP {1}] [get_ips axis_dwidth_converter_7]
generate_target {instantiation_template} [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_7/axis_dwidth_converter_7.xci]
update_compile_order -fileset sources_1
set_property generate_synth_checkpoint false [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_7/axis_dwidth_converter_7.xci]
generate_target all [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_7/axis_dwidth_converter_7.xci]
export_ip_user_files -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_7/axis_dwidth_converter_7.xci] -no_script -sync -force -quiet
export_simulation -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_7/axis_dwidth_converter_7.xci] -directory ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/sim_scripts -ip_user_files_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files -ipstatic_source_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/ipstatic -lib_map_path [list {modelsim=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/modelsim} {questa=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/questa} {ies=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/ies} {xcelium=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/xcelium} {vcs=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/vcs} {riviera=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet


# Output: [4]N to DMA
# "axis_dw_4n_dma"
set IP_NAME "axis_dwidth_converter_8"
set S_BYTES [expr "$DATA_WIDTH * ($CONV_UNITS+2) * $CONV_CORES /(8*2)"]
set M_BYTES [expr "$OUTPUT_DMA_WIDTH /8"]
set T_LAST 0

create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name axis_dwidth_converter_8
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES CONFIG.M_TDATA_NUM_BYTES $M_BYTES CONFIG.HAS_TLAST $T_LAST CONFIG.HAS_TKEEP {0} CONFIG.HAS_MI_TKEEP {1}] [get_ips axis_dwidth_converter_8]
generate_target {instantiation_template} [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_8/axis_dwidth_converter_8.xci]
update_compile_order -fileset sources_1
set_property generate_synth_checkpoint false [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_8/axis_dwidth_converter_8.xci]
generate_target all [get_files  ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_8/axis_dwidth_converter_8.xci]
export_ip_user_files -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_8/axis_dwidth_converter_8.xci] -no_script -sync -force -quiet
export_simulation -of_objects [get_files ./$PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/axis_dwidth_converter_8/axis_dwidth_converter_8.xci] -directory ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/sim_scripts -ip_user_files_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files -ipstatic_source_dir ./$PROJ_FOLDER/$PROJ_NAME.ip_user_files/ipstatic -lib_map_path [list {modelsim=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/modelsim} {questa=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/questa} {ies=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/ies} {xcelium=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/xcelium} {vcs=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/vcs} {riviera=./$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet


#**************************** Add RTL sources *******************************

##### CONVOLUTION
add_files -norecurse $SOURCE_FOLDER/T_reg.v
add_files -norecurse $SOURCE_FOLDER/reg_buffer.v
add_files -norecurse $SOURCE_FOLDER/reg_array_buffer.v
add_files -norecurse $SOURCE_FOLDER/kernel_switch.v
add_files -norecurse $SOURCE_FOLDER/conv_unit.v
add_files -norecurse $SOURCE_FOLDER/d_in_buffer.v
add_files -norecurse $SOURCE_FOLDER/kernel_buffer.v
add_files -norecurse $SOURCE_FOLDER/data_switch.v
add_files -norecurse $SOURCE_FOLDER/conv_core.v
add_files -norecurse $SOURCE_FOLDER/controller.v
add_files -norecurse $SOURCE_FOLDER/conv_block.v
add_files -norecurse $SOURCE_FOLDER/conv_AXIS.v

##### MAXPOOL & RELU
add_files -norecurse $SOURCE_FOLDER/comparator.v
add_files -norecurse $SOURCE_FOLDER/controller_maxpool.v
add_files -norecurse $SOURCE_FOLDER/LReLU_block.v
add_files -norecurse $SOURCE_FOLDER/maxpool_block.v
add_files -norecurse $SOURCE_FOLDER/maxpool_unit.v
add_files -norecurse $SOURCE_FOLDER/maxpool_AXIS.v
add_files -norecurse $SOURCE_FOLDER/LReLU_AXIS.v

##### WEIGHTS ROTATOR
add_files -norecurse $SOURCE_FOLDER/weight_rotator.v
add_files -norecurse $SOURCE_FOLDER/weight_rotator_AXIS.v
add_files -norecurse $SOURCE_FOLDER/FIFO.v

##### INPUT & OUTPUT PIPES
add_files -norecurse $SOURCE_FOLDER/input_pipe.v
add_files -norecurse $SOURCE_FOLDER/output_pipe.v
add_files -norecurse $SOURCE_FOLDER/full_pipe.v

##### PARAMETER BLOCK
add_files -norecurse $SOURCE_FOLDER/parameter_block.v

##### PARAMETERS FILE
add_files -norecurse $SOURCE_FOLDER/system_parameters.v
set_property file_type {Verilog Header} [get_files  $SOURCE_FOLDER/system_parameters.v]

# Simulation
create_fileset -simset pipe
set_property SOURCE_SET sources_1 [get_filesets pipe]
add_files -fileset pipe -norecurse $SOURCE_FOLDER/system_1_nmp_tb.v
current_fileset -simset [ get_filesets pipe ]
update_compile_order -fileset pipe
set_property top system_1_nmp_tb [get_filesets pipe]
set_property top_lib xil_defaultlib [get_filesets pipe]
update_compile_order -fileset pipe

##**** BLOCK DESIGN

create_bd_design "sys"

##### ZYNQ PS
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]
set_property -dict [list CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ "$FREQUENCY_MHZ" CONFIG.PCW_USE_M_AXI_GP1 {1} CONFIG.PCW_USE_FABRIC_INTERRUPT {1} CONFIG.PCW_EN_CLK1_PORT {1} CONFIG.PCW_IRQ_F2P_INTR {1} CONFIG.PCW_QSPI_PERIPHERAL_ENABLE {0} CONFIG.PCW_SD0_PERIPHERAL_ENABLE {0} CONFIG.PCW_TTC0_PERIPHERAL_ENABLE {0} CONFIG.PCW_USB0_PERIPHERAL_ENABLE {0} CONFIG.PCW_I2C0_PERIPHERAL_ENABLE {0} CONFIG.PCW_GPIO_MIO_GPIO_ENABLE {0}] [get_bd_cells processing_system7_0]
endgroup

##### MIG
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:mig_7series:4.1 mig_7series_0
apply_bd_automation -rule xilinx.com:bd_rule:mig_7series -config {Board_Interface "ddr3_sdram" }  [get_bd_cells mig_7series_0]
endgroup

##### DMAs
set IP_NAME "axi_dma_image_out"
set AXI4_WIDTH $OUTPUT_DMA_WIDTH
set BURST_SIZE "16"
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 $IP_NAME
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_length_width {26} CONFIG.c_sg_include_stscntrl_strm {0} CONFIG.c_include_mm2s {0} CONFIG.c_include_s2mm {1} CONFIG.c_m_axi_s2mm_data_width "$AXI4_WIDTH" CONFIG.c_include_s2mm_dre {1} CONFIG.c_s2mm_burst_size "$BURST_SIZE"] [get_bd_cells $IP_NAME]
endgroup

set IP_NAME "axi_dma_image_in_0"
set AXI4_WIDTH $IMAGE_DMA_WIDTH
set BURST_SIZE "16"
set AXIS_WIDTH $AXI4_WIDTH
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 $IP_NAME
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_length_width {26} CONFIG.c_sg_include_stscntrl_strm {0} CONFIG.c_include_s2mm {0} CONFIG.c_include_mm2s {1} CONFIG.c_m_axi_mm2s_data_width "$AXI4_WIDTH" CONFIG.c_m_axis_mm2s_tdata_width "$AXIS_WIDTH" CONFIG.c_mm2s_burst_size "$BURST_SIZE" CONFIG.c_include_mm2s_dre {1} ] [get_bd_cells $IP_NAME]
endgroup

set IP_NAME "axi_dma_image_in_1"
set AXI4_WIDTH $IMAGE_DMA_WIDTH
set BURST_SIZE "16"
set AXIS_WIDTH $AXI4_WIDTH
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 $IP_NAME
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_length_width {26} CONFIG.c_sg_include_stscntrl_strm {0} CONFIG.c_include_s2mm {0} CONFIG.c_include_mm2s {1} CONFIG.c_m_axi_mm2s_data_width "$AXI4_WIDTH" CONFIG.c_m_axis_mm2s_tdata_width "$AXIS_WIDTH" CONFIG.c_mm2s_burst_size "$BURST_SIZE" CONFIG.c_include_mm2s_dre {1} ] [get_bd_cells $IP_NAME]
endgroup

set IP_NAME "axi_dma_weights"
set AXI4_WIDTH $WEIGHTS_DMA_WIDTH
set BURST_SIZE "16"
set AXIS_WIDTH $AXI4_WIDTH
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 $IP_NAME
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_length_width {26} CONFIG.c_sg_include_stscntrl_strm {0} CONFIG.c_include_s2mm {0} CONFIG.c_include_mm2s {1} CONFIG.c_m_axi_mm2s_data_width "$AXI4_WIDTH" CONFIG.c_m_axis_mm2s_tdata_width "$AXIS_WIDTH" CONFIG.c_mm2s_burst_size "$BURST_SIZE" CONFIG.c_include_mm2s_dre {1} ] [get_bd_cells $IP_NAME]
endgroup


##### GPIOs

set IP_NAME "axi_gpio_rstn"
set WIDTH 1
set INPUT 0
set OUTPUT 1
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 $IP_NAME
set_property -dict [list CONFIG.C_GPIO_WIDTH "$WIDTH" CONFIG.C_ALL_OUTPUTS "$OUTPUT" CONFIG.C_ALL_INPUTS "$INPUT"] [get_bd_cells $IP_NAME]
endgroup

set IP_NAME "axi_gpio_layer_index"
set WIDTH 5
set INPUT 0
set OUTPUT 1
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 $IP_NAME
set_property -dict [list CONFIG.C_GPIO_WIDTH "$WIDTH" CONFIG.C_ALL_OUTPUTS "$OUTPUT" CONFIG.C_ALL_INPUTS "$INPUT"] [get_bd_cells $IP_NAME]
endgroup

# Interrupt
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
set_property name xlconcat_interrupt [get_bd_cells xlconcat_0]

##### CUSTOM MODULES
create_bd_cell -type module -reference full_pipe           full_pipe_0
create_bd_cell -type module -reference parameter_block parameter_block_0


##### CONNECTIONS

# AXI Stream
connect_bd_intf_net [get_bd_intf_pins axi_dma_weights/M_AXIS_MM2S] [get_bd_intf_pins full_pipe_0/IP_S_W_DMA_AXIS]
connect_bd_intf_net [get_bd_intf_pins axi_dma_image_in_0/M_AXIS_MM2S] [get_bd_intf_pins full_pipe_0/IP_S_IM_DMA_0_AXIS]
connect_bd_intf_net [get_bd_intf_pins axi_dma_image_in_1/M_AXIS_MM2S] [get_bd_intf_pins full_pipe_0/IP_S_IM_DMA_1_AXIS]
connect_bd_intf_net [get_bd_intf_pins full_pipe_0/LRELU_M_AXIS] [get_bd_intf_pins axi_dma_image_out/S_AXIS_S2MM]

# Parameters
connect_bd_net [get_bd_pins parameter_block_0/write_depth] [get_bd_pins full_pipe_0/WR_write_depth]
connect_bd_net [get_bd_pins parameter_block_0/rotate_amount] [get_bd_pins full_pipe_0/WR_rotate_amount]
connect_bd_net [get_bd_pins parameter_block_0/im_blks] [get_bd_pins full_pipe_0/WR_im_blocks_in]
connect_bd_net [get_bd_pins parameter_block_0/im_width] [get_bd_pins full_pipe_0/WR_im_width_in]
connect_bd_net [get_bd_pins parameter_block_0/im_ch] [get_bd_pins full_pipe_0/WR_im_channels_in]
connect_bd_net [get_bd_pins parameter_block_0/conv_mode] [get_bd_pins full_pipe_0/PIPES_conv_mode]
connect_bd_net [get_bd_pins parameter_block_0/max_mode] [get_bd_pins full_pipe_0/PIPES_is_maxpool]
connect_bd_net [get_bd_pins parameter_block_0/lrelu_en] [get_bd_pins full_pipe_0/lrelu_en]
connect_bd_net [get_bd_pins parameter_block_0/conv_mode] [get_bd_pins full_pipe_0/WR_conv_mode_in]
connect_bd_net [get_bd_pins parameter_block_0/max_mode] [get_bd_pins full_pipe_0/WR_max_mode_in]

# Interrupts
connect_bd_net [get_bd_pins axi_dma_weights/mm2s_introut] [get_bd_pins xlconcat_interrupt/In1]
connect_bd_net [get_bd_pins axi_dma_image_out/s2mm_introut] [get_bd_pins xlconcat_interrupt/In0]
connect_bd_net [get_bd_pins xlconcat_interrupt/dout] [get_bd_pins processing_system7_0/IRQ_F2P]


# # GPIOs
connect_bd_net [get_bd_pins parameter_block_0/layer_number] [get_bd_pins axi_gpio_layer_index/gpio_io_o]
connect_bd_net [get_bd_pins axi_gpio_rstn/gpio_io_o] [get_bd_pins full_pipe_0/aresetn]

# Automation
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/processing_system7_0/FCLK_CLK1 (125 MHz)} Clk_slave {/mig_7series_0/ui_clk (200 MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK1 (125 MHz)} Master {/processing_system7_0/M_AXI_GP1} Slave {/mig_7series_0/S_AXI} intc_ip {Auto} master_apm {0}}  [get_bd_intf_pins mig_7series_0/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {reset ( FPGA Reset ) } Manual_Source {New External Port (ACTIVE_HIGH)}}  [get_bd_pins mig_7series_0/sys_rst]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/processing_system7_0/FCLK_CLK0 (50 MHz)} Clk_slave {/processing_system7_0/FCLK_CLK0 (50 MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK0 (50 MHz)} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_dma_image_out/S_AXI_LITE} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins axi_dma_image_out/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/processing_system7_0/FCLK_CLK0 (50 MHz)} Clk_slave {/processing_system7_0/FCLK_CLK0 (50 MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK0 (50 MHz)} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_dma_image_in_0/S_AXI_LITE} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins axi_dma_image_in_0/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/processing_system7_0/FCLK_CLK0 (50 MHz)} Clk_slave {/processing_system7_0/FCLK_CLK0 (50 MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK0 (50 MHz)} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_dma_image_in_1/S_AXI_LITE} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins axi_dma_image_in_1/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/processing_system7_0/FCLK_CLK0 (50 MHz)} Clk_slave {/processing_system7_0/FCLK_CLK0 (50 MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK0 (50 MHz)} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_dma_weights/S_AXI_LITE} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins axi_dma_weights/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/processing_system7_0/FCLK_CLK0 (50 MHz)} Clk_slave {/processing_system7_0/FCLK_CLK1 (125 MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK0 (50 MHz)} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_gpio_rstn/S_AXI} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins axi_gpio_rstn/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/processing_system7_0/FCLK_CLK0 (50 MHz)} Clk_slave {/processing_system7_0/FCLK_CLK1 (125 MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK0 (50 MHz)} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_gpio_layer_index/S_AXI} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins axi_gpio_layer_index/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config {Clk "/processing_system7_0/FCLK_CLK1 ($FREQUENCY_MHZ MHz)" }  [get_bd_pins full_pipe_0/aclk]
endgroup

# MIG to DMAs
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/processing_system7_0/FCLK_CLK1 ($FREQUENCY_MHZ MHz)} Clk_slave {/mig_7series_0/ui_clk (200 MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK1 ($FREQUENCY_MHZ MHz)} Master {/axi_dma_image_out/M_AXI_S2MM} Slave {/mig_7series_0/S_AXI} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_dma_image_out/M_AXI_S2MM]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/processing_system7_0/FCLK_CLK1 ($FREQUENCY_MHZ MHz)} Clk_slave {/mig_7series_0/ui_clk (200 MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK1 ($FREQUENCY_MHZ MHz)} Master {/axi_dma_image_in_0/M_AXI_MM2S} Slave {/mig_7series_0/S_AXI} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_dma_image_in_0/M_AXI_MM2S]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/processing_system7_0/FCLK_CLK1 ($FREQUENCY_MHZ MHz)} Clk_slave {/mig_7series_0/ui_clk (200 MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK1 ($FREQUENCY_MHZ MHz)} Master {/axi_dma_image_in_1/M_AXI_MM2S} Slave {/mig_7series_0/S_AXI} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_dma_image_in_1/M_AXI_MM2S]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/processing_system7_0/FCLK_CLK1 ($FREQUENCY_MHZ MHz)} Clk_slave {/mig_7series_0/ui_clk (200 MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK1 ($FREQUENCY_MHZ MHz)} Master {/axi_dma_weights/M_AXI_MM2S} Slave {/mig_7series_0/S_AXI} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_dma_weights/M_AXI_MM2S]
endgroup

# Validate, Generate
validate_bd_design
make_wrapper -files [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/bd/sys/sys.bd] -top
add_files -norecurse $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/bd/sys/hdl/sys_wrapper.v
set_property top sys_wrapper [current_fileset]
generate_target all [get_files  $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/bd/sys/sys.bd]

# Runtime Optimize
set_property strategy Flow_RuntimeOptimized [get_runs synth_1]
set_property strategy Flow_RuntimeOptimized [get_runs impl_1]