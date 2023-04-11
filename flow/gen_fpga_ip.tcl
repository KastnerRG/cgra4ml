
if {$SRAM_TYPE == "XILINX"} {

  set R_WIDTH_bram_weights [expr "$WORD_WIDTH  * $COPIES  * $GROUPS * $COLS   "]
  set R_DEPTH_bram_weights $BRAM_WEIGHTS_DEPTH
  set W_WIDTH_bram_weights [expr "$R_WIDTH_bram_weights"]
  set W_DEPTH_bram_weights [expr "$R_WIDTH_bram_weights * $R_DEPTH_bram_weights / $W_WIDTH_bram_weights"]

  set IP_NAME "bram_weights"
  lappend IP_NAMES $IP_NAME
  create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name $IP_NAME
  set_property -dict [list  CONFIG.Memory_Type {Simple_Dual_Port_RAM} CONFIG.Assume_Synchronous_Clk {true} CONFIG.Write_Width_A $W_WIDTH_bram_weights CONFIG.Write_Depth_A $W_DEPTH_bram_weights CONFIG.Read_Width_A $W_WIDTH_bram_weights CONFIG.Operating_Mode_A {NO_CHANGE} CONFIG.Write_Width_B $R_WIDTH_bram_weights CONFIG.Read_Width_B $R_WIDTH_bram_weights CONFIG.Operating_Mode_B {READ_FIRST} CONFIG.Enable_B {Use_ENB_Pin} CONFIG.Register_PortA_Output_of_Memory_Primitives {false} CONFIG.Register_PortB_Output_of_Memory_Primitives {true} CONFIG.Port_B_Clock {100} CONFIG.Port_B_Enable_Rate {100} CONFIG.Register_PortB_Output_of_Memory_Core {true} ] [get_ips $IP_NAME]
}

#*********** CLOCK CONVERTERS ********#

if {$XILINX && ($FREQ_RATIO !=1)} {

  set S_BYTES_axis_dw_weights_clk    [expr "$S_WEIGHTS_WIDTH_LF / 8"]
  set M_BYTES_axis_dw_weights_clk    [expr "$S_WEIGHTS_WIDTH_LF / 8"]
  set DATA_BYTES_axis_clk_weights    [expr "$S_WEIGHTS_WIDTH_LF / 8"]
  set DATA_BYTES_axis_clk_image      [expr "$S_PIXELS_WIDTH_LF  / 8"] 
  set DATA_BYTES_axis_clk_conv_dw    [expr "$M_DATA_WIDTH_LF_CONV_DW / 8"]
  set DATA_BYTES_axis_clk_lrelu      [expr "$M_DATA_WIDTH_LF_LRELU / 8"]
  set DATA_BYTES_axis_clk_maxpool    [expr "$M_DATA_WIDTH_LF_MAXPOOL / 8"]

  set IP_NAME "axis_clk_weights"
  lappend IP_NAMES $IP_NAME
  create_ip -name axis_clock_converter -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.TDATA_NUM_BYTES $DATA_BYTES_axis_clk_weights CONFIG.HAS_TKEEP 1 CONFIG.HAS_TLAST 1 CONFIG.IS_ACLK_ASYNC {1}] [get_ips $IP_NAME]

  set IP_NAME "axis_dw_weights_clk"
  lappend IP_NAMES $IP_NAME
  create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES_axis_dw_weights_clk CONFIG.M_TDATA_NUM_BYTES $M_BYTES_axis_dw_weights_clk CONFIG.HAS_TLAST 1 CONFIG.HAS_TKEEP 1] [get_ips $IP_NAME]

  set IP_NAME "axis_clk_image"
  lappend IP_NAMES $IP_NAME
  create_ip -name axis_clock_converter -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.TDATA_NUM_BYTES $DATA_BYTES_axis_clk_image CONFIG.HAS_TKEEP 1 CONFIG.HAS_TLAST 1 CONFIG.IS_ACLK_ASYNC {1}] [get_ips $IP_NAME]

  set IP_NAME "axis_clk_conv_dw"
  lappend IP_NAMES $IP_NAME
  create_ip -name axis_clock_converter -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.TDATA_NUM_BYTES $DATA_BYTES_axis_clk_conv_dw CONFIG.HAS_TKEEP 1 CONFIG.HAS_TLAST 1 CONFIG.IS_ACLK_ASYNC {1}] [get_ips $IP_NAME]

  set IP_NAME "axis_clk_lrelu"
  lappend IP_NAMES $IP_NAME
  create_ip -name axis_clock_converter -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.TDATA_NUM_BYTES $DATA_BYTES_axis_clk_lrelu CONFIG.HAS_TKEEP 1 CONFIG.HAS_TLAST 1 CONFIG.IS_ACLK_ASYNC {1}] [get_ips $IP_NAME]

  set IP_NAME "axis_clk_maxpool"
  lappend IP_NAMES $IP_NAME
  create_ip -name axis_clock_converter -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.TDATA_NUM_BYTES $DATA_BYTES_axis_clk_maxpool CONFIG.HAS_TKEEP 1 CONFIG.HAS_TLAST 1 CONFIG.IS_ACLK_ASYNC {1}] [get_ips $IP_NAME]
}
#*********** CONV_ENGINE **********#

if {$MAC_TYPE == "XILINX"} {
  set IP_NAME "multiplier"
  lappend IP_NAMES $IP_NAME
  create_ip -name mult_gen -vendor xilinx.com -library ip -version 12.0 -module_name $IP_NAME
  set_property -dict [list CONFIG.PortAWidth $WORD_WIDTH CONFIG.PortBWidth $WORD_WIDTH CONFIG.PipeStages $LATENCY_MULTIPLIER CONFIG.ClockEnable {true}] [get_ips $IP_NAME]

  set IP_NAME "accumulator"
  lappend IP_NAMES $IP_NAME
  create_ip -name c_accum -vendor xilinx.com -library ip -version 12.0 -module_name $IP_NAME
  set_property -dict [list CONFIG.Implementation {DSP48} CONFIG.Input_Width $WORD_WIDTH_ACC CONFIG.Output_Width $WORD_WIDTH_ACC CONFIG.Latency $LATENCY_ACCUMULATOR CONFIG.CE {true}] [get_ips $IP_NAME]
}

#*********** LRELU **********#

if {$OUTPUT_MODE == "LRELU" || $OUTPUT_MODE == "MAXPOOL"} {

  set DATA_BYTES_axis_reg_slice_lrelu_dw [expr "$ROWS  * $WORD_WIDTH_ACC / 8"]
  set TID_WIDTH_axis_reg_slice_lrelu_dw $TUSER_WIDTH_LRELU_IN
  set TUSER_WIDTH_axis_reg_slice_lrelu_dw 0
  set TLAST_axis_reg_slice_lrelu_dw_active 1
  set TKEEP_axis_reg_slice_lrelu_dw 0

  set TLAST_axis_reg_slice_lrelu_dw 0
  set TKEEP_axis_reg_slice_lrelu_dw 0

  set DATA_BYTES_axis_reg_slice_lrelu  [expr "$GROUPS * $COPIES * $ROWS  * $WORD_WIDTH    / 8"]
  set TLAST_axis_reg_slice_lrelu       1
  set TKEEP_axis_reg_slice_lrelu       0
  set TUSER_WIDTH_axis_reg_slice_lrelu $TUSER_WIDTH_MAXPOOL_IN

  set TUSER_WIDTH_float_to_fixed_active $TUSER_WIDTH_MAXPOOL_IN

  set BITS_FRA_IN_mod_float_downsize [expr $BITS_FRA_FMA_1 + 1]
  set BITS_EXP_IN_mod_float_downsize $BITS_EXP_FMA_1
  set BITS_FRA_OUT_mod_float_downsize [expr $BITS_FRA_FMA_2 + 1]
  set BITS_EXP_OUT_mod_float_downsize $BITS_EXP_FMA_2
  set LATENCY_mod_float_downsize $LATENCY_FLOAT_DOWNSIZE

  set BITS_FRA_IN_mod_float_upsize [expr $BITS_FRA_FMA_2 + 1]
  set BITS_EXP_IN_mod_float_upsize $BITS_EXP_FMA_2
  set BITS_FRA_OUT_mod_float_upsize [expr $BITS_FRA_FMA_1 + 1]
  set BITS_EXP_OUT_mod_float_upsize $BITS_EXP_FMA_1
  set LATENCY_mod_float_upsize $LATENCY_FLOAT_UPSIZE

  set S_BYTES_axis_dw_lrelu [expr "$M_DATA_WIDTH_HF_LRELU/8"]
  set M_BYTES_axis_dw_lrelu [expr "$M_DATA_WIDTH_LF_LRELU/8"]
  set TLAST_axis_dw_lrelu 1
  set TKEEP_axis_dw_lrelu 1

  set IP_NAME "axis_dw_lrelu_2_active"
  lappend IP_NAMES $IP_NAME
  create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES_axis_dw_lrelu_2 CONFIG.M_TDATA_NUM_BYTES $M_BYTES_axis_dw_lrelu_2 CONFIG.TUSER_BITS_PER_BYTE $TUSER_WIDTH_axis_dw_lrelu_2_active CONFIG.HAS_TLAST $TLAST_axis_dw_lrelu_2_active CONFIG.HAS_TKEEP $TKEEP_axis_dw_lrelu_2_active] [get_ips $IP_NAME]

  set IP_NAME "axis_dw_lrelu_2"
  lappend IP_NAMES $IP_NAME
  create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES_axis_dw_lrelu_2 CONFIG.M_TDATA_NUM_BYTES $M_BYTES_axis_dw_lrelu_2 CONFIG.TUSER_BITS_PER_BYTE $TUSER_WIDTH_axis_dw_lrelu_2 CONFIG.HAS_TLAST $TLAST_axis_dw_lrelu_2 CONFIG.HAS_TKEEP $TKEEP_axis_dw_lrelu_2] [get_ips $IP_NAME]

  set IP_NAME "axis_reg_slice_lrelu_dw_active"
  lappend IP_NAMES $IP_NAME
  create_ip -name axis_register_slice -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.TDATA_NUM_BYTES $DATA_BYTES_axis_reg_slice_lrelu_dw CONFIG.TID_WIDTH $TID_WIDTH_axis_reg_slice_lrelu_dw CONFIG.HAS_TKEEP $TKEEP_axis_reg_slice_lrelu_dw CONFIG.HAS_TLAST $TLAST_axis_reg_slice_lrelu_dw_active CONFIG.REG_CONFIG {16}] [get_ips $IP_NAME]

  set IP_NAME "axis_reg_slice_lrelu_dw"
  lappend IP_NAMES $IP_NAME
  create_ip -name axis_register_slice -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.TDATA_NUM_BYTES $DATA_BYTES_axis_reg_slice_lrelu_dw CONFIG.TUSER_WIDTH $TUSER_WIDTH_axis_reg_slice_lrelu_dw CONFIG.HAS_TKEEP $TKEEP_axis_reg_slice_lrelu_dw CONFIG.HAS_TLAST $TLAST_axis_reg_slice_lrelu_dw CONFIG.REG_CONFIG {16}] [get_ips $IP_NAME]

  set IP_NAME "axis_reg_slice_lrelu"
  lappend IP_NAMES $IP_NAME
  create_ip -name axis_register_slice -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
  set_property -dict [list  CONFIG.TDATA_NUM_BYTES $DATA_BYTES_axis_reg_slice_lrelu CONFIG.TUSER_WIDTH $TUSER_WIDTH_axis_reg_slice_lrelu CONFIG.HAS_TKEEP $TKEEP_axis_reg_slice_lrelu CONFIG.HAS_TLAST $TLAST_axis_reg_slice_lrelu] [get_ips $IP_NAME]

  set IP_NAME "fixed_to_float_active"
  lappend IP_NAMES $IP_NAME
  create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.Operation_Type {Fixed_to_float} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $WORD_WIDTH_ACC CONFIG.Flow_Control {NonBlocking} CONFIG.C_A_Fraction_Width {0} CONFIG.Result_Precision_Type {Custom} CONFIG.C_Result_Exponent_Width $BITS_EXP_FMA_1 CONFIG.C_Result_Fraction_Width [expr $BITS_FRA_FMA_1 + 1] CONFIG.C_Accum_Msb {32} CONFIG.C_Accum_Lsb {-31} CONFIG.C_Accum_Input_Msb {32} CONFIG.C_Mult_Usage {No_Usage} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Latency $LATENCY_FIXED_2_FLOAT CONFIG.C_Rate {1} CONFIG.Has_ACLKEN {true} CONFIG.Has_A_TUSER {true} CONFIG.A_TUSER_Width $TUSER_WIDTH_LRELU_IN CONFIG.Has_A_TLAST {true} CONFIG.RESULT_TLAST_Behv {Pass_A_TLAST}] [get_ips $IP_NAME]

  set IP_NAME "fixed_to_float"
  lappend IP_NAMES $IP_NAME
  create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.Operation_Type {Fixed_to_float} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $WORD_WIDTH_ACC CONFIG.Flow_Control {NonBlocking} CONFIG.C_A_Fraction_Width {0} CONFIG.Result_Precision_Type {Custom} CONFIG.C_Result_Exponent_Width $BITS_EXP_FMA_1 CONFIG.C_Result_Fraction_Width [expr $BITS_FRA_FMA_1 + 1] CONFIG.C_Mult_Usage {No_Usage} CONFIG.Has_RESULT_TREADY {false}  CONFIG.C_Latency $LATENCY_FIXED_2_FLOAT CONFIG.C_Rate {1} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} ] [get_ips $IP_NAME]

  set IP_NAME "fma_1_active"
  lappend IP_NAMES $IP_NAME
  create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
  set_property -dict [list  CONFIG.Operation_Type {FMA} CONFIG.Add_Sub_Value {Add} CONFIG.C_Mult_Usage {Medium_Usage} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $BITS_EXP_FMA_1 CONFIG.C_A_Fraction_Width [expr $BITS_FRA_FMA_1 + 1] CONFIG.Result_Precision_Type {Custom} CONFIG.C_Result_Exponent_Width $BITS_EXP_FMA_1 CONFIG.C_Result_Fraction_Width [expr $BITS_FRA_FMA_1 + 1] CONFIG.Has_RESULT_TREADY {false} CONFIG.Maximum_Latency {false} CONFIG.C_Latency $LATENCY_FMA_1 CONFIG.C_Rate {1} CONFIG.Has_A_TLAST {false} CONFIG.Has_A_TUSER {true} CONFIG.A_TUSER_Width $TUSER_WIDTH_LRELU_FMA_1_IN CONFIG.Has_A_TLAST {true} CONFIG.RESULT_TLAST_Behv {Pass_A_TLAST}] [get_ips $IP_NAME]

  set IP_NAME "fma_1"
  lappend IP_NAMES $IP_NAME
  create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
  set_property -dict [list  CONFIG.Operation_Type {FMA} CONFIG.Add_Sub_Value {Add} CONFIG.C_Mult_Usage {Medium_Usage} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $BITS_EXP_FMA_1 CONFIG.C_A_Fraction_Width [expr $BITS_FRA_FMA_1 + 1] CONFIG.Result_Precision_Type {Custom} CONFIG.C_Result_Exponent_Width $BITS_EXP_FMA_1 CONFIG.C_Result_Fraction_Width [expr $BITS_FRA_FMA_1 + 1] CONFIG.Has_RESULT_TREADY {false} CONFIG.Maximum_Latency {false} CONFIG.C_Latency $LATENCY_FMA_1 CONFIG.C_Rate {1}] [get_ips $IP_NAME]

  set IP_NAME "fma_2_active"
  lappend IP_NAMES $IP_NAME
  create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
  set_property -dict [list  CONFIG.Operation_Type {FMA} CONFIG.Add_Sub_Value {Add} CONFIG.C_Mult_Usage {Medium_Usage} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $BITS_EXP_FMA_2 CONFIG.C_A_Fraction_Width [expr $BITS_FRA_FMA_2 + 1] CONFIG.Result_Precision_Type {Custom} CONFIG.C_Result_Exponent_Width $BITS_EXP_FMA_2 CONFIG.C_Result_Fraction_Width [expr $BITS_FRA_FMA_2 + 1] CONFIG.Has_RESULT_TREADY {false} CONFIG.Maximum_Latency {false} CONFIG.C_Latency $LATENCY_FMA_2 CONFIG.C_Rate {1} CONFIG.Has_A_TUSER {true} CONFIG.A_TUSER_Width $TUSER_WIDTH_MAXPOOL_IN CONFIG.Has_A_TLAST {true} CONFIG.RESULT_TLAST_Behv {Pass_A_TLAST}] [get_ips $IP_NAME]

  set IP_NAME "fma_2"
  lappend IP_NAMES $IP_NAME
  create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
  set_property -dict [list  CONFIG.Operation_Type {FMA} CONFIG.Add_Sub_Value {Add} CONFIG.C_Mult_Usage {Medium_Usage} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $BITS_EXP_FMA_2 CONFIG.C_A_Fraction_Width [expr $BITS_FRA_FMA_2 + 1] CONFIG.Result_Precision_Type {Custom} CONFIG.C_Result_Exponent_Width $BITS_EXP_FMA_2 CONFIG.C_Result_Fraction_Width [expr $BITS_FRA_FMA_2 + 1] CONFIG.Has_RESULT_TREADY {false} CONFIG.Maximum_Latency {false} CONFIG.C_Latency $LATENCY_FMA_2 CONFIG.C_Rate {1}] [get_ips $IP_NAME]


  set IP_NAME "float_to_fixed_active"
  lappend IP_NAMES $IP_NAME
  create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
  set_property -dict [list  CONFIG.Operation_Type {Float_to_fixed} CONFIG.C_Mult_Usage {No_Usage} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $BITS_EXP_FMA_2 CONFIG.C_A_Fraction_Width [expr $BITS_FRA_FMA_2 + 1] CONFIG.C_Result_Exponent_Width $WORD_WIDTH CONFIG.C_Result_Fraction_Width {0} CONFIG.Result_Precision_Type {Custom} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Latency {5} CONFIG.C_Rate {1} CONFIG.Has_A_TUSER {true} CONFIG.A_TUSER_Width $TUSER_WIDTH_float_to_fixed_active CONFIG.Has_A_TLAST {true} CONFIG.RESULT_TLAST_Behv {Pass_A_TLAST}] [get_ips $IP_NAME]

  set IP_NAME "float_to_fixed"
  lappend IP_NAMES $IP_NAME
  create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
  set_property -dict [list  CONFIG.Operation_Type {Float_to_fixed} CONFIG.C_Mult_Usage {No_Usage} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $BITS_EXP_FMA_2 CONFIG.C_A_Fraction_Width [expr $BITS_FRA_FMA_2 + 1] CONFIG.C_Result_Exponent_Width $WORD_WIDTH CONFIG.C_Result_Fraction_Width {0} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Latency {5} CONFIG.C_Rate {1}] [get_ips $IP_NAME]

  set IP_NAME "mod_float_downsize"
  lappend IP_NAMES $IP_NAME
  create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.Operation_Type {Float_to_float} CONFIG.A_Precision_Type {Custom} CONFIG.Result_Precision_Type {Custom} CONFIG.C_Result_Exponent_Width $BITS_EXP_OUT_mod_float_downsize CONFIG.C_Result_Fraction_Width $BITS_FRA_OUT_mod_float_downsize CONFIG.Flow_Control {NonBlocking} CONFIG.Maximum_Latency {false} CONFIG.C_Latency $LATENCY_mod_float_downsize CONFIG.C_A_Exponent_Width $BITS_EXP_IN_mod_float_downsize CONFIG.C_A_Fraction_Width $BITS_FRA_IN_mod_float_downsize CONFIG.C_Mult_Usage {No_Usage} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Rate {1} CONFIG.Has_ACLKEN {true}] [get_ips $IP_NAME]

  set IP_NAME "mod_float_upsize"
  lappend IP_NAMES $IP_NAME
  create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.Operation_Type {Float_to_float} CONFIG.A_Precision_Type {Custom} CONFIG.Result_Precision_Type {Custom} CONFIG.C_Result_Exponent_Width $BITS_EXP_OUT_mod_float_upsize CONFIG.C_Result_Fraction_Width $BITS_FRA_OUT_mod_float_upsize CONFIG.Flow_Control {NonBlocking} CONFIG.Maximum_Latency {false} CONFIG.C_Latency $LATENCY_mod_float_upsize CONFIG.C_A_Exponent_Width $BITS_EXP_IN_mod_float_upsize CONFIG.C_A_Fraction_Width $BITS_FRA_IN_mod_float_upsize CONFIG.C_Mult_Usage {No_Usage} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Rate {1} CONFIG.Has_ACLKEN {true}] [get_ips $IP_NAME]

  set IP_NAME "axis_dw_lrelu"
  lappend IP_NAMES $IP_NAME
  create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES_axis_dw_lrelu CONFIG.M_TDATA_NUM_BYTES $M_BYTES_axis_dw_lrelu CONFIG.HAS_TLAST $TLAST_axis_dw_lrelu CONFIG.HAS_TKEEP $TKEEP_axis_dw_lrelu] [get_ips $IP_NAME]
}
#*********** MAXPOOL **********#

if {$OUTPUT_MODE == "MAXPOOL"} {

  set S_BYTES_axis_dw_max_1 [expr "$M_DATA_WIDTH_HF_MAXPOOL / 8"]
  set M_BYTES_axis_dw_max_1 [expr "$M_DATA_WIDTH_HF_MAX_DW1 / 8"]
  set TLAST_axis_dw_max_1 1
  set TKEEP_axis_dw_max_1 1

  set S_BYTES_axis_dw_max_2 [expr "$M_DATA_WIDTH_HF_MAX_DW1/8"]
  set M_BYTES_axis_dw_max_2 [expr "$M_DATA_WIDTH_LF/8"]
  set TLAST_axis_dw_max_2 1
  set TKEEP_axis_dw_max_2 1

  set DATA_BYTES_axis_reg_slice_maxpool [expr "$GROUPS*$ROWS *$COPIES*$WORD_WIDTH / 8"]
  set TLAST_axis_reg_slice_maxpool 1
  set TKEEP_axis_reg_slice_maxpool 1

  set IP_NAME "axis_reg_slice_maxpool"
  lappend IP_NAMES $IP_NAME
  create_ip -name axis_register_slice -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.TDATA_NUM_BYTES $DATA_BYTES_axis_reg_slice_maxpool CONFIG.HAS_TKEEP $TKEEP_axis_reg_slice_maxpool CONFIG.HAS_TLAST $TLAST_axis_reg_slice_maxpool] [get_ips $IP_NAME]

  set IP_NAME "axis_dw_max_1"
  lappend IP_NAMES $IP_NAME
  create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES_axis_dw_max_1 CONFIG.M_TDATA_NUM_BYTES $M_BYTES_axis_dw_max_1 CONFIG.HAS_TLAST $TLAST_axis_dw_max_1 CONFIG.HAS_TKEEP $TKEEP_axis_dw_max_1] [get_ips $IP_NAME]

  set IP_NAME "axis_dw_max_2"
  lappend IP_NAMES $IP_NAME
  create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
  set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES_axis_dw_max_2 CONFIG.M_TDATA_NUM_BYTES $M_BYTES_axis_dw_max_2 CONFIG.HAS_TLAST $TLAST_axis_dw_max_2 CONFIG.HAS_TKEEP $TKEEP_axis_dw_max_2] [get_ips $IP_NAME]
}