set PROJ_NAME lrelu
set PROJ_FOLDER lrelu
set SOURCE_FOLDER ../src_hdl

set UNITS   2
set GROUPS  1
set COPIES  1
set MEMBERS 4

set WORD_WIDTH       8
set WORD_WIDTH_ACC   32
set S_WEIGHTS_WIDTH  32

set BEATS_CONFIG_3X3 21
set BEATS_CONFIG_1X1 13

set KERNEL_W_MAX  3
set KERNEL_H_MAX  3
set IM_COLS_MAX   384
set IM_ROWS_MAX   256
set IM_CIN_MAX    1024
set LRELU_ALPHA   11878

set LATENCY_MULTIPLIER    3
set LATENCY_ACCUMULATOR   2
set LATENCY_FMA_1         16
set LATENCY_FMA_2         15
set LATENCY_FIXED_2_FLOAT  6
set LATENCY_BRAM           2
set LATENCY_FLOAT_UPSIZE   2
set LATENCY_FLOAT_DOWNSIZE 3

set BITS_EXP_CONFIG 5
set BITS_FRA_CONFIG 10
set BITS_EXP_FMA_1  8
set BITS_FRA_FMA_1  23
set BITS_EXP_FMA_2  5 
set BITS_FRA_FMA_2  10

set IM_BLOCKS_MAX      [expr int($IM_ROWS_MAX / $UNITS)]
set UNITS_EDGES        [expr $UNITS + $KERNEL_H_MAX-1]
set CORES              [expr $MEMBERS * $GROUPS * $COPIES]
set BITS_KERNEL_W      [expr int(ceil(log($KERNEL_W_MAX)/log(2)))]
set BITS_KERNEL_H      [expr int(ceil(log($KERNEL_H_MAX)/log(2)))]
set BITS_IM_COLS       [expr int(ceil(log($IM_COLS_MAX)/log(2)))]
set BITS_IM_ROWS       [expr int(ceil(log($IM_ROWS_MAX)/log(2)))]
set BITS_IM_CIN        [expr int(ceil(log($IM_CIN_MAX)/log(2)))]
set BITS_IM_BLOCKS     [expr int(ceil(log($IM_ROWS_MAX/$UNITS)/log(2)))]
set BITS_CONFIG_COUNT  [expr int(ceil(log($BEATS_CONFIG_3X3)/log(2)))]
set M_DATA_WIDTH       [expr $WORD_WIDTH * 2**int(ceil(log($GROUPS * $UNITS_EDGES)/log(2)))]

set IM_IN_S_DATA_WORDS   [expr 2**int(ceil(log($UNITS_EDGES)/log(2)))]
set WORD_WIDTH_LRELU_1   [expr 1 + $BITS_EXP_FMA_1 + $BITS_FRA_FMA_1]
set WORD_WIDTH_LRELU_2   [expr 1 + $BITS_EXP_FMA_2 + $BITS_FRA_FMA_2]
set WORD_WIDTH_LRELU_OUT $WORD_WIDTH
set TKEEP_WIDTH_IM_IN    [expr $WORD_WIDTH * 2**int(ceil(log($UNITS_EDGES)/log(2))) /8]

set BEATS_CONFIG_3X3_1 [expr $BEATS_CONFIG_3X3-1]
set BEATS_CONFIG_1X1_1 [expr $BEATS_CONFIG_1X1-1]

set BITS_FMA_1 [expr $BITS_FRA_FMA_1 + $BITS_EXP_FMA_1 + 1]
set BITS_FMA_2 [expr $BITS_FRA_FMA_2 + $BITS_EXP_FMA_2 + 1]

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

set DEBUG_CONFIG_WIDTH_W_ROT   [expr 1 + 2*$BITS_KERNEL_W + 3*($BITS_KERNEL_H + $BITS_IM_CIN + $BITS_IM_COLS + $BITS_IM_BLOCKS)]
set DEBUG_CONFIG_WIDTH_IM_PIPE [expr 3 + 2 + $BITS_KERNEL_H + $BITS_CONFIG_COUNT + $BITS_CONFIG_COUNT]
set DEBUG_CONFIG_WIDTH_LRELU   [expr 3 + 4 + $BITS_FMA_2]
set DEBUG_CONFIG_WIDTH_MAXPOOL 1
set DEBUG_CONFIG_WIDTH         [expr $DEBUG_CONFIG_WIDTH_MAXPOOL + $DEBUG_CONFIG_WIDTH_LRELU + 2*$BITS_KERNEL_H + $DEBUG_CONFIG_WIDTH_IM_PIPE + $DEBUG_CONFIG_WIDTH_W_ROT]

#********** STORE PARAMS *************

set file_param [open $SOURCE_FOLDER/params.v w]
puts $file_param "/*
Parameters of the system. Written from build.tcl
*/

`define UNITS    $UNITS  
`define GROUPS   $GROUPS 
`define COPIES   $COPIES 
`define MEMBERS  $MEMBERS

`define CORES              $CORES
`define UNITS_EDGES        $UNITS_EDGES
`define IM_IN_S_DATA_WORDS $IM_IN_S_DATA_WORDS

`define WORD_WIDTH          $WORD_WIDTH         
`define WORD_WIDTH_ACC      $WORD_WIDTH_ACC    
`define KERNEL_H_MAX        $KERNEL_H_MAX      
`define KERNEL_W_MAX        $KERNEL_W_MAX      
`define BEATS_CONFIG_3X3_1  $BEATS_CONFIG_3X3_1
`define BEATS_CONFIG_1X1_1  $BEATS_CONFIG_1X1_1

`define BITS_KERNEL_H     $BITS_KERNEL_H
`define BITS_KERNEL_W     $BITS_KERNEL_W
`define TKEEP_WIDTH_IM_IN $TKEEP_WIDTH_IM_IN
`define BITS_CONFIG_COUNT $BITS_CONFIG_COUNT

`define DEBUG_CONFIG_WIDTH_W_ROT   $DEBUG_CONFIG_WIDTH_W_ROT  
`define DEBUG_CONFIG_WIDTH_IM_PIPE $DEBUG_CONFIG_WIDTH_IM_PIPE
`define DEBUG_CONFIG_WIDTH_LRELU   $DEBUG_CONFIG_WIDTH_LRELU  
`define DEBUG_CONFIG_WIDTH_MAXPOOL $DEBUG_CONFIG_WIDTH_MAXPOOL
`define DEBUG_CONFIG_WIDTH         $DEBUG_CONFIG_WIDTH        

/*
  IMAGE TUSER INDICES
*/
`define I_IMAGE_IS_NOT_MAX        $I_IMAGE_IS_NOT_MAX      
`define I_IMAGE_IS_MAX            $I_IMAGE_IS_MAX          
`define I_IMAGE_IS_LRELU          $I_IMAGE_IS_LRELU        
`define I_IMAGE_KERNEL_H_1        $I_IMAGE_KERNEL_H_1       
`define TUSER_WIDTH_IM_SHIFT_IN   $TUSER_WIDTH_IM_SHIFT_IN 
`define TUSER_WIDTH_IM_SHIFT_OUT  $TUSER_WIDTH_IM_SHIFT_OUT

`define IM_CIN_MAX       $IM_CIN_MAX      
`define IM_BLOCKS_MAX    $IM_BLOCKS_MAX   
`define IM_COLS_MAX      $IM_COLS_MAX     
`define S_WEIGHTS_WIDTH $S_WEIGHTS_WIDTH
`define M_DATA_WIDTH     $M_DATA_WIDTH
`define LRELU_ALPHA      $LRELU_ALPHA     
/*
  LATENCIES & float widths
*/
`define BITS_EXP_CONFIG       $BITS_EXP_CONFIG      
`define BITS_FRA_CONFIG       $BITS_FRA_CONFIG      
`define BITS_EXP_FMA_1        $BITS_EXP_FMA_1       
`define BITS_FRA_FMA_1        $BITS_FRA_FMA_1       
`define BITS_EXP_FMA_2        $BITS_EXP_FMA_2       
`define BITS_FRA_FMA_2        $BITS_FRA_FMA_2       
`define LATENCY_FMA_1         $LATENCY_FMA_1        
`define LATENCY_FMA_2         $LATENCY_FMA_2        
`define LATENCY_FIXED_2_FLOAT $LATENCY_FIXED_2_FLOAT
`define LATENCY_BRAM          $LATENCY_BRAM         
`define LATENCY_ACCUMULATOR   $LATENCY_ACCUMULATOR    
`define LATENCY_MULTIPLIER    $LATENCY_MULTIPLIER     
/*
  WEIGHTS TUSER INDICES
*/
`define I_WEIGHTS_IS_TOP_BLOCK     $I_WEIGHTS_IS_TOP_BLOCK   
`define I_WEIGHTS_IS_BOTTOM_BLOCK  $I_WEIGHTS_IS_BOTTOM_BLOCK
`define I_WEIGHTS_IS_1X1           $I_WEIGHTS_IS_1X1         
`define I_WEIGHTS_IS_COLS_1_K2     $I_WEIGHTS_IS_COLS_1_K2   
`define I_WEIGHTS_IS_CONFIG        $I_WEIGHTS_IS_CONFIG      
`define I_WEIGHTS_IS_CIN_LAST      $I_WEIGHTS_IS_CIN_LAST    
`define I_WEIGHTS_KERNEL_W_1       $I_WEIGHTS_KERNEL_W_1      
`define TUSER_WIDTH_WEIGHTS_OUT    $TUSER_WIDTH_WEIGHTS_OUT  
/*
  CONV TUSER INDICES
*/
`define I_IS_NOT_MAX         $I_IS_NOT_MAX       
`define I_IS_MAX             $I_IS_MAX           
`define I_IS_1X1             $I_IS_1X1           
`define I_IS_LRELU           $I_IS_LRELU         
`define I_IS_TOP_BLOCK       $I_IS_TOP_BLOCK     
`define I_IS_BOTTOM_BLOCK    $I_IS_BOTTOM_BLOCK  
`define I_IS_COLS_1_K2       $I_IS_COLS_1_K2     
`define I_IS_CONFIG          $I_IS_CONFIG        
`define I_IS_CIN_LAST        $I_IS_CIN_LAST      
`define I_KERNEL_W_1         $I_KERNEL_W_1        
`define TUSER_WIDTH_CONV_IN  $TUSER_WIDTH_CONV_IN
/*
  LRELU & MAXPOOL TUSER INDICES
*/
`define I_IS_LEFT_COL        $I_IS_LEFT_COL 
`define I_IS_RIGHT_COL       $I_IS_RIGHT_COL

`define TUSER_WIDTH_MAXPOOL_IN     $TUSER_WIDTH_MAXPOOL_IN    
`define TUSER_WIDTH_LRELU_FMA_1_IN $TUSER_WIDTH_LRELU_FMA_1_IN
`define TUSER_WIDTH_LRELU_IN       $TUSER_WIDTH_LRELU_IN      
"
close $file_param


# create project
create_project $PROJ_NAME ./$PROJ_FOLDER -part xc7z045ffg900-2
set_property board_part xilinx.com:zc706:part0:1.4 [current_project]


set IP_NAMES [list ]

#*********** LRELU **********#

set IP_NAME "axis_dw_lrelu_active"
lappend IP_NAMES $IP_NAME
set S_BYTES [expr "$MEMBERS * $GROUPS * $UNITS * $WORD_WIDTH_ACC / 8"]
set M_BYTES [expr "$GROUPS * $UNITS * $WORD_WIDTH_ACC / 8"]
set TID_WIDTH $TUSER_WIDTH_LRELU_IN
set T_LAST 1
set T_KEEP 0
create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES CONFIG.M_TDATA_NUM_BYTES $M_BYTES CONFIG.TID_WIDTH $TID_WIDTH CONFIG.HAS_TLAST $T_LAST CONFIG.HAS_TKEEP $T_KEEP] [get_ips $IP_NAME]

set IP_NAME "axis_dw_lrelu"
lappend IP_NAMES $IP_NAME
set S_BYTES [expr "$MEMBERS * $GROUPS * $UNITS * $WORD_WIDTH_ACC / 8"]
set M_BYTES [expr "$GROUPS * $UNITS * $WORD_WIDTH_ACC / 8"]
set T_LAST 0
set T_KEEP 0
create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES $S_BYTES CONFIG.M_TDATA_NUM_BYTES $M_BYTES CONFIG.HAS_TLAST $T_LAST CONFIG.HAS_TKEEP $T_KEEP] [get_ips $IP_NAME]

set IP_NAME "axis_reg_slice_lrelu_dw"
lappend IP_NAMES $IP_NAME
set DATA_BYTES [expr "$COPIES * $GROUPS * $UNITS * $WORD_WIDTH_ACC / 8"]
set TUSER_WIDTH $TUSER_WIDTH_LRELU_IN
set T_LAST 1
set T_KEEP 0
create_ip -name axis_register_slice -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
set_property -dict [list CONFIG.TDATA_NUM_BYTES $DATA_BYTES CONFIG.TUSER_WIDTH $TUSER_WIDTH CONFIG.HAS_TKEEP $T_KEEP CONFIG.HAS_TLAST $T_LAST CONFIG.REG_CONFIG {16}] [get_ips $IP_NAME]

set IP_NAME "axis_reg_slice_lrelu"
lappend IP_NAMES $IP_NAME
set DATA_BYTES [expr "$GROUPS * $COPIES * $UNITS * $WORD_WIDTH    / 8"]
set T_LAST 0
set T_KEEP 0
set TUSER_WIDTH $TUSER_WIDTH_MAXPOOL_IN
create_ip -name axis_register_slice -vendor xilinx.com -library ip -version 1.1 -module_name $IP_NAME
set_property -dict [list  CONFIG.TDATA_NUM_BYTES $DATA_BYTES CONFIG.TUSER_WIDTH $TUSER_WIDTH CONFIG.HAS_TKEEP $T_KEEP CONFIG.HAS_TLAST $T_LAST] [get_ips $IP_NAME]

set IP_NAME "fixed_to_float_active"
lappend IP_NAMES $IP_NAME
set TUSER_WIDTH $TUSER_WIDTH_LRELU_IN
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list CONFIG.Operation_Type {Fixed_to_float} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $WORD_WIDTH_ACC CONFIG.Flow_Control {NonBlocking} CONFIG.C_A_Fraction_Width {0} CONFIG.Result_Precision_Type {Custom} CONFIG.C_Result_Exponent_Width $BITS_EXP_FMA_1 CONFIG.C_Result_Fraction_Width [expr $BITS_FRA_FMA_1 + 1] CONFIG.C_Accum_Msb {32} CONFIG.C_Accum_Lsb {-31} CONFIG.C_Accum_Input_Msb {32} CONFIG.C_Mult_Usage {No_Usage} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Latency $LATENCY_FIXED_2_FLOAT CONFIG.C_Rate {1} CONFIG.Has_ACLKEN {true} CONFIG.Has_A_TUSER {true} CONFIG.A_TUSER_Width $TUSER_WIDTH ] [get_ips $IP_NAME]

set IP_NAME "fixed_to_float"
lappend IP_NAMES $IP_NAME
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list CONFIG.Operation_Type {Fixed_to_float} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $WORD_WIDTH_ACC CONFIG.Flow_Control {NonBlocking} CONFIG.C_A_Fraction_Width {0} CONFIG.Result_Precision_Type {Custom} CONFIG.C_Result_Exponent_Width $BITS_EXP_FMA_1 CONFIG.C_Result_Fraction_Width [expr $BITS_FRA_FMA_1 + 1] CONFIG.C_Mult_Usage {No_Usage} CONFIG.Has_RESULT_TREADY {false}  CONFIG.C_Latency $LATENCY_FIXED_2_FLOAT CONFIG.C_Rate {1} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} ] [get_ips $IP_NAME]

set IP_NAME "fma_1_active"
lappend IP_NAMES $IP_NAME
set LATENCY $LATENCY_FMA_1
set TUSER_WIDTH $TUSER_WIDTH_LRELU_FMA_1_IN
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list  CONFIG.Operation_Type {FMA} CONFIG.Add_Sub_Value {Add} CONFIG.C_Mult_Usage {Medium_Usage} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $BITS_EXP_FMA_1 CONFIG.C_A_Fraction_Width [expr $BITS_FRA_FMA_1 + 1] CONFIG.Result_Precision_Type {Custom} CONFIG.C_Result_Exponent_Width $BITS_EXP_FMA_1 CONFIG.C_Result_Fraction_Width [expr $BITS_FRA_FMA_1 + 1] CONFIG.Has_RESULT_TREADY {false} CONFIG.Maximum_Latency {false} CONFIG.C_Latency $LATENCY CONFIG.C_Rate {1} CONFIG.Has_A_TLAST {false} CONFIG.Has_A_TUSER {true} CONFIG.A_TUSER_Width $TUSER_WIDTH ] [get_ips $IP_NAME]

set IP_NAME "fma_1"
lappend IP_NAMES $IP_NAME
set LATENCY $LATENCY_FMA_1
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list  CONFIG.Operation_Type {FMA} CONFIG.Add_Sub_Value {Add} CONFIG.C_Mult_Usage {Medium_Usage} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $BITS_EXP_FMA_1 CONFIG.C_A_Fraction_Width [expr $BITS_FRA_FMA_1 + 1] CONFIG.Result_Precision_Type {Custom} CONFIG.C_Result_Exponent_Width $BITS_EXP_FMA_1 CONFIG.C_Result_Fraction_Width [expr $BITS_FRA_FMA_1 + 1] CONFIG.Has_RESULT_TREADY {false} CONFIG.Maximum_Latency {false} CONFIG.C_Latency $LATENCY CONFIG.C_Rate {1}] [get_ips $IP_NAME]

set IP_NAME "fma_2_active"
lappend IP_NAMES $IP_NAME
set LATENCY $LATENCY_FMA_2
set TUSER_WIDTH $TUSER_WIDTH_MAXPOOL_IN
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list  CONFIG.Operation_Type {FMA} CONFIG.Add_Sub_Value {Add} CONFIG.C_Mult_Usage {Medium_Usage} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $BITS_EXP_FMA_2 CONFIG.C_A_Fraction_Width [expr $BITS_FRA_FMA_2 + 1] CONFIG.Result_Precision_Type {Custom} CONFIG.C_Result_Exponent_Width $BITS_EXP_FMA_2 CONFIG.C_Result_Fraction_Width [expr $BITS_FRA_FMA_2 + 1] CONFIG.Has_RESULT_TREADY {false} CONFIG.Maximum_Latency {false} CONFIG.C_Latency $LATENCY CONFIG.C_Rate {1} CONFIG.Has_A_TUSER {true} CONFIG.A_TUSER_Width $TUSER_WIDTH ] [get_ips $IP_NAME]

set IP_NAME "fma_2"
lappend IP_NAMES $IP_NAME
set LATENCY $LATENCY_FMA_2
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list  CONFIG.Operation_Type {FMA} CONFIG.Add_Sub_Value {Add} CONFIG.C_Mult_Usage {Medium_Usage} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $BITS_EXP_FMA_2 CONFIG.C_A_Fraction_Width [expr $BITS_FRA_FMA_2 + 1] CONFIG.Result_Precision_Type {Custom} CONFIG.C_Result_Exponent_Width $BITS_EXP_FMA_2 CONFIG.C_Result_Fraction_Width [expr $BITS_FRA_FMA_2 + 1] CONFIG.Has_RESULT_TREADY {false} CONFIG.Maximum_Latency {false} CONFIG.C_Latency $LATENCY CONFIG.C_Rate {1}] [get_ips $IP_NAME]


set IP_NAME "float_to_fixed_active"
lappend IP_NAMES $IP_NAME
set TUSER_WIDTH $TUSER_WIDTH_MAXPOOL_IN
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list  CONFIG.Operation_Type {Float_to_fixed} CONFIG.C_Mult_Usage {No_Usage} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $BITS_EXP_FMA_2 CONFIG.C_A_Fraction_Width [expr $BITS_FRA_FMA_2 + 1] CONFIG.C_Result_Exponent_Width $WORD_WIDTH CONFIG.C_Result_Fraction_Width {0} CONFIG.Result_Precision_Type {Custom} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Latency {5} CONFIG.C_Rate {1} CONFIG.Has_A_TUSER {true} CONFIG.A_TUSER_Width $TUSER_WIDTH ] [get_ips $IP_NAME]

set IP_NAME "float_to_fixed"
lappend IP_NAMES $IP_NAME
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list  CONFIG.Operation_Type {Float_to_fixed} CONFIG.C_Mult_Usage {No_Usage} CONFIG.Flow_Control {NonBlocking} CONFIG.Has_ACLKEN {true} CONFIG.Has_ARESETn {false} CONFIG.A_Precision_Type {Custom} CONFIG.C_A_Exponent_Width $BITS_EXP_FMA_2 CONFIG.C_A_Fraction_Width [expr $BITS_FRA_FMA_2 + 1] CONFIG.C_Result_Exponent_Width $WORD_WIDTH CONFIG.C_Result_Fraction_Width {0} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Latency {5} CONFIG.C_Rate {1}] [get_ips $IP_NAME]

set IP_NAME "bram_lrelu"
lappend IP_NAMES $IP_NAME
set R_WIDTH 16
set R_DEPTH [expr "$MEMBERS * $KERNEL_W_MAX"]
set W_WIDTH [expr "$MEMBERS * $WORD_WIDTH   "]
set W_DEPTH [expr "$R_WIDTH * $R_DEPTH / $W_WIDTH"]
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name $IP_NAME
set_property -dict [list CONFIG.Algorithm {Minimum_Area} CONFIG.Write_Width_A $W_WIDTH CONFIG.Write_Depth_A $W_DEPTH CONFIG.Read_Width_A $R_WIDTH CONFIG.Operating_Mode_A {NO_CHANGE} CONFIG.Write_Width_B $W_WIDTH CONFIG.Read_Width_B $W_WIDTH CONFIG.Register_PortA_Output_of_Memory_Core {true}] [get_ips $IP_NAME]

set IP_NAME "bram_lrelu_edge"
lappend IP_NAMES $IP_NAME
set R_WIDTH 16
set R_DEPTH [expr "$MEMBERS"]
set W_WIDTH [expr "$MEMBERS * $WORD_WIDTH   "]
set W_DEPTH [expr "$R_WIDTH * $R_DEPTH / $W_WIDTH"]
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name $IP_NAME
set_property -dict [list CONFIG.Algorithm {Minimum_Area} CONFIG.Write_Width_A $W_WIDTH CONFIG.Write_Depth_A $W_DEPTH CONFIG.Read_Width_A $R_WIDTH CONFIG.Operating_Mode_A {NO_CHANGE} CONFIG.Write_Width_B $W_WIDTH CONFIG.Read_Width_B $W_WIDTH CONFIG.Register_PortA_Output_of_Memory_Core {true}] [get_ips $IP_NAME]

set IP_NAME "mod_float_downsize"
lappend IP_NAMES $IP_NAME
set BITS_FRA_IN [expr $BITS_FRA_FMA_1 + 1]
set BITS_EXP_IN $BITS_EXP_FMA_1
set BITS_FRA_OUT [expr $BITS_FRA_FMA_2 + 1]
set BITS_EXP_OUT $BITS_EXP_FMA_2
set LATENCY $LATENCY_FLOAT_DOWNSIZE
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list CONFIG.Operation_Type {Float_to_float} CONFIG.A_Precision_Type {Custom} CONFIG.Result_Precision_Type {Custom} CONFIG.C_Result_Exponent_Width $BITS_EXP_OUT CONFIG.C_Result_Fraction_Width $BITS_FRA_OUT CONFIG.Flow_Control {NonBlocking} CONFIG.Maximum_Latency {false} CONFIG.C_Latency $LATENCY CONFIG.C_A_Exponent_Width $BITS_EXP_IN CONFIG.C_A_Fraction_Width $BITS_FRA_IN CONFIG.C_Mult_Usage {No_Usage} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Rate {1} CONFIG.Has_ACLKEN {true}] [get_ips $IP_NAME]

set IP_NAME "mod_float_upsize"
lappend IP_NAMES $IP_NAME
set BITS_FRA_IN [expr $BITS_FRA_FMA_2 + 1]
set BITS_EXP_IN $BITS_EXP_FMA_2
set BITS_FRA_OUT [expr $BITS_FRA_FMA_1 + 1]
set BITS_EXP_OUT $BITS_EXP_FMA_1
set LATENCY $LATENCY_FLOAT_UPSIZE
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name $IP_NAME
set_property -dict [list CONFIG.Operation_Type {Float_to_float} CONFIG.A_Precision_Type {Custom} CONFIG.Result_Precision_Type {Custom} CONFIG.C_Result_Exponent_Width $BITS_EXP_OUT CONFIG.C_Result_Fraction_Width $BITS_FRA_OUT CONFIG.Flow_Control {NonBlocking} CONFIG.Maximum_Latency {false} CONFIG.C_Latency $LATENCY CONFIG.C_A_Exponent_Width $BITS_EXP_IN CONFIG.C_A_Fraction_Width $BITS_FRA_IN CONFIG.C_Mult_Usage {No_Usage} CONFIG.Has_RESULT_TREADY {false} CONFIG.C_Rate {1} CONFIG.Has_ACLKEN {true}] [get_ips $IP_NAME]

# Generate IP output products

foreach IP_NAME $IP_NAMES {
  generate_target {instantiation_template} [get_files  $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/$IP_NAME/$IP_NAME.xci]
  set_property generate_synth_checkpoint 0 [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/$IP_NAME/$IP_NAME.xci]
  export_ip_user_files -of_objects [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/$IP_NAME/$IP_NAME.xci] -no_script -sync -force -quiet
  export_simulation -of_objects [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/$IP_NAME/$IP_NAME.xci] -directory $PROJ_FOLDER/$PROJ_NAME.ip_user_files/sim_scripts -ip_user_files_dir $PROJ_FOLDER/$PROJ_NAME.ip_user_files -ipstatic_source_dir $PROJ_FOLDER/$PROJ_NAME.ip_user_files/ipstatic -lib_map_path [list {modelsim=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/modelsim} {questa=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/questa} {riviera=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/riviera} {activehdl=$PROJ_FOLDER/$PROJ_NAME.cache/compile_simlib/activehdl}] -use_ip_compiled_libs -force -quiet
  generate_target Simulation [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/$IP_NAME/$IP_NAME.xci]
}

add_files -norecurse {
  ../src_hdl/n_delay_stream.sv 
  ../src_hdl/always_valid_cyclic_bram.sv 
  ../src_hdl/lrelu_engine.sv 
  ../src_hdl/axis_lrelu_engine_tb.sv 
  ../src_hdl/axis_lrelu_engine.v 
  ../src_hdl/register.v 
  ../src_hdl/n_delay.sv 
  ../src_hdl/params.v}

set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 -norecurse ../wave/axis_lrelu_engine_tb_behav.wcfg

set_property top axis_lrelu_engine [current_fileset]
set_property top axis_lrelu_engine_tb [get_filesets sim_1]
