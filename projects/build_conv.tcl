set PROJ_NAME support
set PROJ_FOLDER unit_tests
set SOURCE_FOLDER ../src

set AXIS_FREQUENCY_MHZ   250
set WORD_WIDTH_IN        8
set WORD_WIDTH_CONV_OUT  25
set WORD_WIDTH_LRELU_1   32
set WORD_WIDTH_LRELU_2   16
set WORD_WIDTH_LRELU_OUT 8

set UNITS   2
set GROUPS  1
set COPIES  1
set MEMBERS 4

set BITS_CONV_CORE          [expr int(ceil(log($GROUPS * $COPIES * $MEMBERS)/log(2)))]
set TUSER_WIDTH_LRELU       [expr $BITS_CONV_CORE + 8]
set TUSER_WIDTH_LRELU_FMA_1 [expr $BITS_CONV_CORE + 4]
set TUSER_WIDTH_MAXPOOL     [expr $BITS_CONV_CORE + 3]

set KERNEL_W_MAX  3
set MAX_IM_WIDTH  384
set MAX_IM_HEIGHT 256
set MAX_CHANNELS  1024

set LATENCY_MULTIPIER 3
set LATENCY_ACCUMULATOR 2

# # create project
# create_project $PROJ_NAME ./$PROJ_FOLDER -part xc7z045ffg900-2
# set_property board_part xilinx.com:zc706:part0:1.4 [current_project]

# Create IPs
set IP_NAMES [list ]

set IP_NAME "multiplier"
lappend IP_NAMES $IP_NAME
set WIDTH $WORD_WIDTH_IN
set LATENCY $LATENCY_MULTIPIER
create_ip -name mult_gen -vendor xilinx.com -library ip -version 12.0 -module_name $IP_NAME
set_property -dict [list CONFIG.PortAWidth $WIDTH CONFIG.PortBWidth $WIDTH CONFIG.PipeStages $LATENCY CONFIG.ClockEnable {true}] [get_ips $IP_NAME]

set IP_NAME "accumulator"
lappend IP_NAMES $IP_NAME
set WIDTH $WORD_WIDTH_CONV_OUT
set LATENCY $LATENCY_ACCUMULATOR
create_ip -name c_accum -vendor xilinx.com -library ip -version 12.0 -module_name $IP_NAME
set_property -dict [list CONFIG.Implementation {DSP48} CONFIG.Input_Width $WIDTH CONFIG.Output_Width $WIDTH CONFIG.Latency $LATENCY CONFIG.CE {true}] [get_ips $IP_NAME]


# Generate IP output products

foreach IP_NAME $IP_NAMES {
  generate_target {instantiation_template} [get_files  $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/$IP_NAME/$IP_NAME.xci]
  set_property generate_synth_checkpoint 0 [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/$IP_NAME/$IP_NAME.xci]
  export_ip_user_files -of_objects [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/$IP_NAME/$IP_NAME.xci] -no_script -sync -force -quiet
  export_simulation -of_objects [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/$IP_NAME/$IP_NAME.xci] -directory $PROJ_FOLDER/$PROJ_NAME.ip_user_files/sim_scripts -ip_user_files_dir $PROJ_FOLDER/$PROJ_NAME.ip_user_files -ipstatic_source_dir $PROJ_FOLDER/$PROJ_NAME.ip_user_files/ipstatic -lib_map_path [list {modelsim=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/modelsim} {questa=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/questa} {riviera=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/riviera} {activehdl=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/activehdl}] -use_ip_compiled_libs -force -quiet
  generate_target Simulation [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/$IP_NAME/$IP_NAME.xci]
}