set PROJ_NAME max
set PROJ_FOLDER max
set SOURCE_FOLDER ../src

set AXIS_FREQUENCY_MHZ   250
set WORD_WIDTH_IN        8
set WORD_WIDTH_CONV_OUT  32
set WORD_WIDTH_LRELU_1   32
set WORD_WIDTH_LRELU_2   16
set WORD_WIDTH_LRELU_OUT 8

set UNITS   4
set GROUPS  1
set COPIES  2
set MEMBERS 4

set WEIGHTS_DMA_BITS 32

set BEATS_CONFIG_3X3_1 21
set BEATS_CONFIG_1X1_1 13

set KERNEL_W_MAX  3
set KERNEL_H_MAX  3
set MAX_IM_WIDTH  384
set MAX_IM_HEIGHT 256
set MAX_CHANNELS  1024

set LATENCY_MULTIPIER 3
set LATENCY_ACCUMULATOR 2

set UNITS_EDGES        [expr $UNITS + $KERNEL_H_MAX-1]
set CORES              [expr $MEMBERS * $GROUPS * $COPIES]
set BITS_KERNEL_W      [expr int(ceil(log($KERNEL_W_MAX)/log(2)))]
set BITS_KERNEL_H      [expr int(ceil(log($KERNEL_H_MAX)/log(2)))]
set IM_IN_S_DATA_WORDS [expr 2**int(ceil(log($UNITS_EDGES)/log(2)))]

# IMAGE TUSER INDICES
set I_IMAGE_IS_NOT_MAX       0
set I_IMAGE_IS_MAX           [expr $I_IMAGE_IS_NOT_MAX + 1]
set I_IMAGE_IS_LRELU         [expr $I_IMAGE_IS_MAX     + 1]
set I_IMAGE_KERNEL_H_1       [expr $I_IMAGE_IS_LRELU   + 1] 
set TUSER_WIDTH_IM_SHIFT_IN  [expr $I_IMAGE_KERNEL_H_1 + $BITS_KERNEL_H]
set TUSER_WIDTH_IM_SHIFT_OUT [expr $I_IMAGE_IS_LRELU   + 1]

# WEIGHTS TUSER INDICES
set I_WEIGHTS_IS_TOP_BLOCK     0
set I_WEIGHTS_IS_BOTTOM_BLOCK  [expr $I_WEIGHTS_IS_TOP_BLOCK    + 1]
set I_WEIGHTS_IS_1X1           [expr $I_WEIGHTS_IS_BOTTOM_BLOCK + 1]
set I_WEIGHTS_IS_COLS_1_K2     [expr $I_WEIGHTS_IS_1X1          + 1]
set I_WEIGHTS_IS_CONFIG        [expr $I_WEIGHTS_IS_COLS_1_K2    + 1]
set I_WEIGHTS_IS_CIN_LAST      [expr $I_WEIGHTS_IS_CONFIG       + 1] 
set I_WEIGHTS_KERNEL_W_1       [expr $I_WEIGHTS_IS_CIN_LAST     + 1] 
set TUSER_WIDTH_WEIGHTS_OUT    [expr $I_WEIGHTS_KERNEL_W_1 + $BITS_KERNEL_W]

# PIPE TUSER INDICES
set I_IS_NOT_MAX      0
set I_IS_MAX          [expr $I_IS_NOT_MAX      + 1]
set I_IS_1X1          [expr $I_IS_MAX          + 1]
set I_IS_LRELU        [expr $I_IS_1X1          + 1]
set I_IS_TOP_BLOCK    [expr $I_IS_LRELU        + 1]
set I_IS_BOTTOM_BLOCK [expr $I_IS_TOP_BLOCK    + 1]
set I_IS_COLS_1_K2    [expr $I_IS_BOTTOM_BLOCK + 1]
set I_IS_CONFIG       [expr $I_IS_COLS_1_K2    + 1]
set I_IS_CIN_LAST     [expr $I_IS_CONFIG       + 1]
set I_KERNEL_W_1      [expr $I_IS_CIN_LAST     + 1]

set I_IS_LEFT_COL     [expr $I_IS_BOTTOM_BLOCK + 1]
set I_IS_RIGHT_COL    [expr $I_IS_LEFT_COL     + 1]

set TUSER_WIDTH_MAXPOOL_IN     [expr 1 + $I_IS_1X1      ]
set TUSER_WIDTH_LRELU_IN       [expr 1 + $I_IS_RIGHT_COL]
set TUSER_WIDTH_LRELU_FMA_1_IN [expr 1 + $I_IS_LRELU    ]
set TUSER_WIDTH_CONV_IN        [expr $BITS_KERNEL_W + $I_KERNEL_W_1]

set IP_NAMES [list ]


# create project
create_project $PROJ_NAME ./$PROJ_FOLDER -part xc7z045ffg900-2
set_property board_part xilinx.com:zc706:part0:1.4 [current_project]

#*********** MAXPOOL **********#

set IP_NAME "axis_reg_slice_maxpool"
lappend IP_NAMES $IP_NAME
set DATA_BYTES [expr "$GROUPS * $COPIES * $UNITS * $WORD_WIDTH_IN / 8"]
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