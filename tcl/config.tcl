set PROJ_FOLDER projects/$PROJ_NAME
set HDL_DIR src_hdl
set TB_DIR testbench
set WAVE_DIR wave

set XILINX 1

set UNITS   4
set GROUPS  2
set COPIES  2
set MEMBERS 12
set FREQ_HIGH   200
set FREQ_RATIO  4
# set OUTPUT_MODE "CONV"
# set OUTPUT_MODE "LRELU"
set OUTPUT_MODE "MAXPOOL"

set FREQ_LITE   50
set DW_FACTOR_1 3 
set LRELU_BEATS_MAX  9
set IS_CONV_DW_SLICE 0

set WORD_WIDTH       8
set WORD_WIDTH_ACC   32
set S_WEIGHTS_WIDTH_HF  32

set KW_MAX        3
set KH_MAX        3
set IM_COLS_MAX   384
set IM_ROWS_MAX   256
set IM_CIN_MAX    1024
set LRELU_ALPHA   11878

set LATENCY_MULTIPLIER    3
set LATENCY_ACCUMULATOR   1
set LATENCY_FMA_1         16
set LATENCY_FMA_2         15
set LATENCY_FIXED_2_FLOAT  6
set LATENCY_BRAM           3
set LATENCY_CYCLIC_REG     0
set LATENCY_FLOAT_UPSIZE   2
set LATENCY_FLOAT_DOWNSIZE 3

set BITS_EXP_CONFIG 5
set BITS_FRA_CONFIG 10
set BITS_EXP_FMA_1  8
set BITS_FRA_FMA_1  23
set BITS_EXP_FMA_2  5 
set BITS_FRA_FMA_2  10


set FREQ_LOW           [expr $FREQ_HIGH.0/$FREQ_RATIO.0]
set IM_BLOCKS_MAX      [expr int($IM_ROWS_MAX / $UNITS)]
set UNITS_EDGES        [expr $UNITS + $KH_MAX      -1]
set CORES              [expr $GROUPS * $COPIES]
set BITS_KW            [expr int(ceil(log($KW_MAX      )/log(2)))]
set BITS_KH            [expr int(ceil(log($KH_MAX      )/log(2)))]
set BITS_IM_COLS       [expr int(ceil(log($IM_COLS_MAX)/log(2)))]
set BITS_IM_ROWS       [expr int(ceil(log($IM_ROWS_MAX)/log(2)))]
set BITS_IM_CIN        [expr int(ceil(log($IM_CIN_MAX)/log(2)))]
set BITS_IM_BLOCKS     [expr int(ceil(log($IM_ROWS_MAX/$UNITS)/log(2)))]
set BITS_MEMBERS       [expr int(ceil(log($MEMBERS)/log(2)))]
set BITS_KW2           [expr int(ceil(log(($KW_MAX      +1)/2)/log(2)))]
set BITS_KH2           [expr int(ceil(log(($KH_MAX      +1)/2)/log(2)))]

set S_WEIGHTS_WIDTH_LF [expr 8 * 2**int(ceil(log($S_WEIGHTS_WIDTH_HF * $FREQ_RATIO / 8)/log(2)))]

set M_DATA_WIDTH_HF_CONV    [expr int($COPIES * $GROUPS * $MEMBERS * $UNITS * $WORD_WIDTH_ACC)]
set M_DATA_WIDTH_HF_CONV_DW [expr int($COPIES * $GROUPS * $UNITS * $WORD_WIDTH_ACC)]
set M_DATA_WIDTH_HF_LRELU   [expr int($COPIES * $GROUPS * $UNITS * $WORD_WIDTH)]
set M_DATA_WIDTH_HF_MAXPOOL [expr int($GROUPS * $COPIES * $UNITS_EDGES * $WORD_WIDTH)]
set M_DATA_WIDTH_HF_MAX_DW1 [expr int($GROUPS * $UNITS_EDGES * $WORD_WIDTH)]

set M_DATA_WIDTH_LF_CONV_DW [expr min(1024, 8 * 2**int(ceil(log($M_DATA_WIDTH_HF_CONV_DW * $FREQ_RATIO / 8)/log(2))))]
set M_DATA_WIDTH_LF_LRELU   [expr min(1024, 8 * 2**int(ceil(log($M_DATA_WIDTH_HF_LRELU   * $FREQ_RATIO / 8)/log(2))))]
set M_DATA_WIDTH_LF_MAXPOOL [expr min(1024, 8 * 2**int(ceil(log($M_DATA_WIDTH_HF_MAX_DW1 * $FREQ_RATIO / 8)/log(2))))]

switch $OUTPUT_MODE {
  "CONV"    {set M_DATA_WIDTH_LF $M_DATA_WIDTH_LF_CONV_DW}
  "LRELU"   {set M_DATA_WIDTH_LF $M_DATA_WIDTH_LF_LRELU  }
  "MAXPOOL" {set M_DATA_WIDTH_LF $M_DATA_WIDTH_LF_MAXPOOL}
}

set IM_IN_S_DATA_WORDS   [expr 2**int(ceil(log($UNITS_EDGES * $FREQ_RATIO)/log(2)))]
set WORD_WIDTH_LRELU_1   [expr 1 + $BITS_EXP_FMA_1 + $BITS_FRA_FMA_1]
set WORD_WIDTH_LRELU_2   [expr 1 + $BITS_EXP_FMA_2 + $BITS_FRA_FMA_2]
set WORD_WIDTH_LRELU_OUT $WORD_WIDTH
set TKEEP_WIDTH_IM_IN    [expr $WORD_WIDTH * $IM_IN_S_DATA_WORDS /8]

set BITS_FMA_1 [expr $BITS_FRA_FMA_1 + $BITS_EXP_FMA_1 + 1]
set BITS_FMA_2 [expr $BITS_FRA_FMA_2 + $BITS_EXP_FMA_2 + 1]

# IMAGE TUSER INDICES
set I_IS_NOT_MAX       0
set I_IS_MAX           [expr $I_IS_NOT_MAX + 1]
set I_IS_LRELU         [expr $I_IS_MAX     + 1]
set I_KH2              [expr $I_IS_LRELU   + 1]
set TUSER_WIDTH_IM_SHIFT_IN  [expr $I_KH2  + $BITS_KH2]
set TUSER_WIDTH_IM_SHIFT_OUT [expr $I_KH2  + $BITS_KH2]

# WEIGHTS TUSER INDICES
set I_WEIGHTS_IS_TOP_BLOCK     0
set I_WEIGHTS_IS_BOTTOM_BLOCK  [expr $I_WEIGHTS_IS_TOP_BLOCK    + 1]
set I_WEIGHTS_IS_COLS_1_K2     [expr $I_WEIGHTS_IS_BOTTOM_BLOCK + 1]
set I_WEIGHTS_IS_CONFIG        [expr $I_WEIGHTS_IS_COLS_1_K2    + 1]
set I_WEIGHTS_IS_CIN_LAST      [expr $I_WEIGHTS_IS_CONFIG       + 1] 
set I_WEIGHTS_KW2              [expr $I_WEIGHTS_IS_CIN_LAST     + 1] 
set TUSER_WIDTH_WEIGHTS_OUT    [expr $I_WEIGHTS_KW2     + $BITS_KW2]

# PIPE TUSER INDICES
set I_IS_NOT_MAX      0
set I_IS_MAX          [expr $I_IS_NOT_MAX      + 1]
set I_KH2             [expr $I_IS_MAX          + 1]
set I_IS_LRELU        [expr $I_KH2     + $BITS_KH2]
set I_IS_TOP_BLOCK    [expr $I_IS_LRELU        + 1]
set I_IS_BOTTOM_BLOCK [expr $I_IS_TOP_BLOCK    + 1]
set I_IS_COLS_1_K2    [expr $I_IS_BOTTOM_BLOCK + 1]
set I_IS_CONFIG       [expr $I_IS_COLS_1_K2    + 1]
set I_IS_CIN_LAST     [expr $I_IS_CONFIG       + 1]
set I_KW2             [expr $I_IS_CIN_LAST     + 1]

set I_CLR             [expr $I_IS_BOTTOM_BLOCK + 1]

set TUSER_WIDTH_MAXPOOL_IN     [expr $BITS_KH2      + $I_KH2]
set TUSER_WIDTH_LRELU_IN       [expr $BITS_KW       + $I_CLR]
set TUSER_WIDTH_LRELU_FMA_1_IN [expr 1         + $I_IS_LRELU]
set TUSER_WIDTH_CONV_IN        [expr $BITS_KW2      + $I_KW2]

set DEBUG_CONFIG_WIDTH_W_ROT   [expr 1 + 2*$BITS_KW2 + 3*($BITS_KH2      + $BITS_IM_CIN + $BITS_IM_COLS + $BITS_IM_BLOCKS)]
set DEBUG_CONFIG_WIDTH_IM_PIPE [expr 3 + 2 + $BITS_KH2      + 0]
set DEBUG_CONFIG_WIDTH_LRELU   [expr 3 + 4 + $BITS_FMA_2]
set DEBUG_CONFIG_WIDTH_MAXPOOL 1
set DEBUG_CONFIG_WIDTH         [expr $DEBUG_CONFIG_WIDTH_MAXPOOL + $DEBUG_CONFIG_WIDTH_LRELU + 2*$BITS_KH2      + $DEBUG_CONFIG_WIDTH_IM_PIPE + $DEBUG_CONFIG_WIDTH_W_ROT]

# ************ IP PARAMETERS ************

set M_BYTES_axis_dw_weights_clk    [expr "$S_WEIGHTS_WIDTH_HF / 8"]
set S_BYTES_axis_dw_weights_clk    [expr "$S_WEIGHTS_WIDTH_LF / 8"]
set DATA_BYTES_axis_clk_weights    [expr "$S_WEIGHTS_WIDTH_LF / 8"]
set DATA_BYTES_axis_clk_image      $IM_IN_S_DATA_WORDS
set DATA_BYTES_axis_clk_conv_dw    [expr "$M_DATA_WIDTH_LF_CONV_DW / 8"]
set DATA_BYTES_axis_clk_lrelu      [expr "$M_DATA_WIDTH_LF_LRELU / 8"]
set DATA_BYTES_axis_clk_maxpool    [expr "$M_DATA_WIDTH_LF_MAXPOOL / 8"]

set S_BYTES_axis_dw_image_input $IM_IN_S_DATA_WORDS
set M_BYTES_axis_dw_image_input [expr "($UNITS_EDGES * $WORD_WIDTH   ) / 8"]
set TLAST_axis_dw_image_input 1
set TKEEP_axis_dw_image_input 1

set DATA_BYTES_axis_reg_slice_image_pipe [expr "$UNITS"]
set TLAST_axis_reg_slice_image_pipe 0
set TKEEP_axis_reg_slice_image_pipe 0
set TUSER_WIDTH_axis_reg_slice_image_pipe $TUSER_WIDTH_IM_SHIFT_OUT

set R_WIDTH_bram_weights [expr "$WORD_WIDTH   * $CORES * $MEMBERS"]
set R_DEPTH_bram_weights [expr "$KH_MAX       * $IM_CIN_MAX + ($LRELU_BEATS_MAX-1)"]
set W_WIDTH_bram_weights [expr "$R_WIDTH_bram_weights"]
set W_DEPTH_bram_weights [expr "$R_WIDTH_bram_weights * $R_DEPTH_bram_weights / $W_WIDTH_bram_weights"]

set S_BYTES_axis_dw_weights_input [expr "$S_WEIGHTS_WIDTH_HF / 8"]
set M_BYTES_axis_dw_weights_input [expr "$W_WIDTH_bram_weights / 8"]
set TLAST_axis_dw_weights_input 1
set TKEEP_axis_dw_weights_input 1

set DATA_BYTES_slice_conv [expr "$WORD_WIDTH_ACC * $UNITS /8"]
set TLAST_slice_conv 0
set TKEEP_slice_conv 0
set TUSER_WIDTH_slice_conv 0

set DATA_BYTES_slice_conv_semi_active [expr "$WORD_WIDTH_ACC * $UNITS /8"]
set TLAST_slice_conv_semi_active 0
set TKEEP_slice_conv_semi_active 1
set TUSER_WIDTH_slice_conv_semi_active [expr "$TUSER_WIDTH_LRELU_IN"]

set DATA_BYTES_slice_conv_active [expr "$WORD_WIDTH_ACC * $UNITS /8"]
set TLAST_slice_conv_active 1
set TKEEP_slice_conv_active 1
set TUSER_WIDTH_slice_conv_active [expr "$TUSER_WIDTH_LRELU_IN"]

set S_BYTES_axis_dw_conv [expr "$M_DATA_WIDTH_HF_CONV_DW/8"]
set M_BYTES_axis_dw_conv [expr "$M_DATA_WIDTH_LF_CONV_DW/8"]
set TLAST_axis_dw_conv 1
set TKEEP_axis_dw_conv 1

set S_BYTES_axis_dw_lrelu_1_active [expr "$DW_FACTOR_1 * $WORD_WIDTH_ACC / 8"]
set M_BYTES_axis_dw_lrelu_1_active [expr "$WORD_WIDTH_ACC / 8"]
set TUSER_WIDTH_axis_dw_lrelu_1_active $TUSER_WIDTH_LRELU_IN
set TLAST_axis_dw_lrelu_1_active 1
set TKEEP_axis_dw_lrelu_1_active 1

set TUSER_WIDTH_axis_dw_lrelu_1 0
set TLAST_axis_dw_lrelu_1 0
set TKEEP_axis_dw_lrelu_1 1

if ([expr $DW_FACTOR_1 != 1]) {
  set S_BYTES_axis_dw_lrelu_2 [expr "($MEMBERS/$DW_FACTOR_1) * $WORD_WIDTH_ACC / 8"]
  set M_BYTES_axis_dw_lrelu_2 [expr "$WORD_WIDTH_ACC / 8"]
  set TUSER_WIDTH_axis_dw_lrelu_2_active $TUSER_WIDTH_LRELU_IN
  set TLAST_axis_dw_lrelu_2_active 1
  set TKEEP_axis_dw_lrelu_2_active 1

  set TUSER_WIDTH_axis_dw_lrelu_2 0
  set TLAST_axis_dw_lrelu_2 0
  set TKEEP_axis_dw_lrelu_2 1
} else {
  set S_BYTES_axis_dw_lrelu_2 [expr "$MEMBERS * $WORD_WIDTH_ACC / 8"]
  set M_BYTES_axis_dw_lrelu_2 [expr "$WORD_WIDTH_ACC / 8"]
  set TUSER_WIDTH_axis_dw_lrelu_2_active $TUSER_WIDTH_LRELU_IN
  set TLAST_axis_dw_lrelu_2_active 1
  set TKEEP_axis_dw_lrelu_2_active 1

  set TUSER_WIDTH_axis_dw_lrelu_2 0
  set TLAST_axis_dw_lrelu_2 0
  set TKEEP_axis_dw_lrelu_2 1
}

set DATA_BYTES_axis_reg_slice_lrelu_dw [expr "$UNITS * $WORD_WIDTH_ACC / 8"]
set TID_WIDTH_axis_reg_slice_lrelu_dw $TUSER_WIDTH_LRELU_IN
set TUSER_WIDTH_axis_reg_slice_lrelu_dw 0
set TLAST_axis_reg_slice_lrelu_dw_active 1
set TKEEP_axis_reg_slice_lrelu_dw 0

set TLAST_axis_reg_slice_lrelu_dw 0
set TKEEP_axis_reg_slice_lrelu_dw 0

set DATA_BYTES_axis_reg_slice_lrelu  [expr "$GROUPS * $COPIES * $UNITS * $WORD_WIDTH    / 8"]
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

set S_BYTES_axis_dw_max_1 [expr "$M_DATA_WIDTH_HF_MAXPOOL / 8"]
set M_BYTES_axis_dw_max_1 [expr "$M_DATA_WIDTH_HF_MAX_DW1 / 8"]
set TLAST_axis_dw_max_1 1
set TKEEP_axis_dw_max_1 1

set S_BYTES_axis_dw_max_2 [expr "$M_DATA_WIDTH_HF_MAX_DW1/8"]
set M_BYTES_axis_dw_max_2 [expr "$M_DATA_WIDTH_LF/8"]
set TLAST_axis_dw_max_2 1
set TKEEP_axis_dw_max_2 1

set DATA_BYTES_axis_reg_slice_maxpool [expr "$GROUPS*$UNITS*$COPIES*$WORD_WIDTH / 8"]
set TLAST_axis_reg_slice_maxpool 1
set TKEEP_axis_reg_slice_maxpool 1

# **********    STORE PARAMS    *************


set file_param [open $HDL_DIR/params.v w]

if ($XILINX) {
  puts $file_param "`define XILINX   $XILINX"
}

puts $file_param "/*
Parameters of the system. Written from build.tcl
*/

`define UNITS    $UNITS  
`define GROUPS   $GROUPS 
`define COPIES   $COPIES 
`define MEMBERS  $MEMBERS
`define DW_FACTOR_1 $DW_FACTOR_1
`define OUTPUT_MODE \"$OUTPUT_MODE\"

`define FREQ_HIGH     $FREQ_HIGH
`define FREQ_RATIO    $FREQ_RATIO

`define CORES              $CORES
`define UNITS_EDGES        $UNITS_EDGES
`define IM_IN_S_DATA_WORDS $IM_IN_S_DATA_WORDS

`define WORD_WIDTH          $WORD_WIDTH         
`define WORD_WIDTH_ACC      $WORD_WIDTH_ACC    
`define KH_MAX              $KH_MAX            
`define KW_MAX              $KW_MAX            

`define TKEEP_WIDTH_IM_IN $TKEEP_WIDTH_IM_IN
`define BITS_KW           $BITS_KW          
`define BITS_KH           $BITS_KH          
`define BITS_IM_COLS      $BITS_IM_COLS     
`define BITS_IM_ROWS      $BITS_IM_ROWS     
`define BITS_IM_CIN       $BITS_IM_CIN      
`define BITS_IM_BLOCKS    $BITS_IM_BLOCKS   
`define BITS_MEMBERS      $BITS_MEMBERS     
`define BITS_KW2          $BITS_KW2         
`define BITS_KH2          $BITS_KH2         

`define DEBUG_CONFIG_WIDTH_W_ROT   $DEBUG_CONFIG_WIDTH_W_ROT  
`define DEBUG_CONFIG_WIDTH_IM_PIPE $DEBUG_CONFIG_WIDTH_IM_PIPE
`define DEBUG_CONFIG_WIDTH_LRELU   $DEBUG_CONFIG_WIDTH_LRELU  
`define DEBUG_CONFIG_WIDTH_MAXPOOL $DEBUG_CONFIG_WIDTH_MAXPOOL
`define DEBUG_CONFIG_WIDTH         $DEBUG_CONFIG_WIDTH        

/*
  IMAGE TUSER INDICES
*/
`define TUSER_WIDTH_IM_SHIFT_IN   $TUSER_WIDTH_IM_SHIFT_IN 
`define TUSER_WIDTH_IM_SHIFT_OUT  $TUSER_WIDTH_IM_SHIFT_OUT

`define IM_CIN_MAX       $IM_CIN_MAX      
`define IM_BLOCKS_MAX    $IM_BLOCKS_MAX   
`define IM_COLS_MAX      $IM_COLS_MAX     
`define LRELU_ALPHA      $LRELU_ALPHA     
`define LRELU_BEATS_MAX  $LRELU_BEATS_MAX

`define S_WEIGHTS_WIDTH_HF  $S_WEIGHTS_WIDTH_HF
`define S_WEIGHTS_WIDTH_LF  $S_WEIGHTS_WIDTH_LF
`define M_DATA_WIDTH_HF_CONV    $M_DATA_WIDTH_HF_CONV   
`define M_DATA_WIDTH_HF_CONV_DW $M_DATA_WIDTH_HF_CONV_DW
`define M_DATA_WIDTH_LF_CONV_DW $M_DATA_WIDTH_LF_CONV_DW
`define M_DATA_WIDTH_HF_LRELU   $M_DATA_WIDTH_HF_LRELU  
`define M_DATA_WIDTH_LF_LRELU   $M_DATA_WIDTH_LF_LRELU  
`define M_DATA_WIDTH_HF_MAXPOOL $M_DATA_WIDTH_HF_MAXPOOL
`define M_DATA_WIDTH_HF_MAX_DW1 $M_DATA_WIDTH_HF_MAX_DW1
`define M_DATA_WIDTH_LF_MAXPOOL $M_DATA_WIDTH_LF_MAXPOOL
`define M_DATA_WIDTH_LF         $M_DATA_WIDTH_LF
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
`define LATENCY_CYCLIC_REG    $LATENCY_CYCLIC_REG         
`define LATENCY_FLOAT_UPSIZE   $LATENCY_FLOAT_UPSIZE   
`define LATENCY_FLOAT_DOWNSIZE $LATENCY_FLOAT_DOWNSIZE   
`define LATENCY_ACCUMULATOR   $LATENCY_ACCUMULATOR    
`define LATENCY_MULTIPLIER    $LATENCY_MULTIPLIER     
/*
  WEIGHTS TUSER INDICES
*/
`define I_WEIGHTS_IS_TOP_BLOCK     $I_WEIGHTS_IS_TOP_BLOCK   
`define I_WEIGHTS_IS_BOTTOM_BLOCK  $I_WEIGHTS_IS_BOTTOM_BLOCK
`define I_WEIGHTS_IS_COLS_1_K2     $I_WEIGHTS_IS_COLS_1_K2   
`define I_WEIGHTS_IS_CONFIG        $I_WEIGHTS_IS_CONFIG      
`define I_WEIGHTS_IS_CIN_LAST      $I_WEIGHTS_IS_CIN_LAST    
`define I_WEIGHTS_KW2              $I_WEIGHTS_KW2        
`define TUSER_WIDTH_WEIGHTS_OUT    $TUSER_WIDTH_WEIGHTS_OUT  
/*
  CONV TUSER INDICES
*/
`define I_IS_NOT_MAX         $I_IS_NOT_MAX       
`define I_IS_MAX             $I_IS_MAX           
`define I_KH2                $I_KH2      
`define I_IS_LRELU           $I_IS_LRELU         
`define I_IS_TOP_BLOCK       $I_IS_TOP_BLOCK     
`define I_IS_BOTTOM_BLOCK    $I_IS_BOTTOM_BLOCK  
`define I_IS_COLS_1_K2       $I_IS_COLS_1_K2     
`define I_IS_CONFIG          $I_IS_CONFIG        
`define I_IS_CIN_LAST        $I_IS_CIN_LAST      
`define I_KW2                $I_KW2        
`define TUSER_WIDTH_CONV_IN  $TUSER_WIDTH_CONV_IN
/*
  LRELU & MAXPOOL TUSER INDICES
*/
`define I_CLR                $I_CLR

`define TUSER_WIDTH_MAXPOOL_IN     $TUSER_WIDTH_MAXPOOL_IN    
`define TUSER_WIDTH_LRELU_FMA_1_IN $TUSER_WIDTH_LRELU_FMA_1_IN
`define TUSER_WIDTH_LRELU_IN       $TUSER_WIDTH_LRELU_IN      
`define IS_CONV_DW_SLICE           $IS_CONV_DW_SLICE

/*
  Macro functions
*/
`define BEATS_CONFIG(KH,KW) 1+ 2*(2/KW + 2%KW) + 2*KH
`define CEIL(N,D) N/D + (N%D != 0)

/*
  IP Parameters
*/

`define S_BYTES_axis_dw_weights_clk    $S_BYTES_axis_dw_weights_clk 
`define M_BYTES_axis_dw_weights_clk    $M_BYTES_axis_dw_weights_clk 
`define DATA_BYTES_axis_clk_weights    $DATA_BYTES_axis_clk_weights    
`define DATA_BYTES_axis_clk_image      $DATA_BYTES_axis_clk_image      
`define DATA_BYTES_axis_clk_conv_dw    $DATA_BYTES_axis_clk_conv_dw    
`define DATA_BYTES_axis_clk_lrelu      $DATA_BYTES_axis_clk_lrelu      
`define DATA_BYTES_axis_clk_maxpool    $DATA_BYTES_axis_clk_maxpool    

`define S_BYTES_axis_dw_image_input    $S_BYTES_axis_dw_image_input 
`define M_BYTES_axis_dw_image_input    $M_BYTES_axis_dw_image_input 
`define TLAST_axis_dw_image_input      $TLAST_axis_dw_image_input   
`define TKEEP_axis_dw_image_input      $TKEEP_axis_dw_image_input   

`define DATA_BYTES_axis_reg_slice_image_pipe  $DATA_BYTES_axis_reg_slice_image_pipe 
`define TLAST_axis_reg_slice_image_pipe       $TLAST_axis_reg_slice_image_pipe      
`define TKEEP_axis_reg_slice_image_pipe       $TKEEP_axis_reg_slice_image_pipe      
`define TUSER_WIDTH_axis_reg_slice_image_pipe $TUSER_WIDTH_axis_reg_slice_image_pipe

`define R_WIDTH_bram_weights $R_WIDTH_bram_weights 
`define R_DEPTH_bram_weights $R_DEPTH_bram_weights 
`define W_WIDTH_bram_weights $W_WIDTH_bram_weights 
`define W_DEPTH_bram_weights $W_DEPTH_bram_weights 

`define S_BYTES_axis_dw_weights_input $S_BYTES_axis_dw_weights_input 
`define M_BYTES_axis_dw_weights_input $M_BYTES_axis_dw_weights_input 
`define TLAST_axis_dw_weights_input   $TLAST_axis_dw_weights_input   
`define TKEEP_axis_dw_weights_input   $TKEEP_axis_dw_weights_input   

`define DATA_BYTES_slice_conv  $DATA_BYTES_slice_conv  
`define TLAST_slice_conv       $TLAST_slice_conv       
`define TKEEP_slice_conv       $TKEEP_slice_conv       
`define TUSER_WIDTH_slice_conv $TUSER_WIDTH_slice_conv 

`define DATA_BYTES_slice_conv_semi_active  $DATA_BYTES_slice_conv_semi_active   
`define TLAST_slice_conv_semi_active       $TLAST_slice_conv_semi_active       
`define TKEEP_slice_conv_semi_active       $TKEEP_slice_conv_semi_active        
`define TUSER_WIDTH_slice_conv_semi_active $TUSER_WIDTH_slice_conv_semi_active  

`define DATA_BYTES_slice_conv_active  $DATA_BYTES_slice_conv_active  
`define TLAST_slice_conv_active       $TLAST_slice_conv_active     
`define TKEEP_slice_conv_active       $TKEEP_slice_conv_active     
`define TUSER_WIDTH_slice_conv_active $TUSER_WIDTH_slice_conv_active 

`define S_BYTES_axis_dw_conv $S_BYTES_axis_dw_conv 
`define M_BYTES_axis_dw_conv $M_BYTES_axis_dw_conv 
`define TLAST_axis_dw_conv   $TLAST_axis_dw_conv   
`define TKEEP_axis_dw_conv   $TKEEP_axis_dw_conv   

`define S_BYTES_axis_dw_lrelu_1_active     $S_BYTES_axis_dw_lrelu_1_active     
`define M_BYTES_axis_dw_lrelu_1_active     $M_BYTES_axis_dw_lrelu_1_active     
`define TUSER_WIDTH_axis_dw_lrelu_1_active $TUSER_WIDTH_axis_dw_lrelu_1_active 
`define TLAST_axis_dw_lrelu_1_active       $TLAST_axis_dw_lrelu_1_active       
`define TKEEP_axis_dw_lrelu_1_active       $TKEEP_axis_dw_lrelu_1_active       

`define TUSER_WIDTH_axis_dw_lrelu_1 $TUSER_WIDTH_axis_dw_lrelu_1 
`define TLAST_axis_dw_lrelu_1       $TLAST_axis_dw_lrelu_1       
`define TKEEP_axis_dw_lrelu_1       $TKEEP_axis_dw_lrelu_1       

`define S_BYTES_axis_dw_lrelu_2            $S_BYTES_axis_dw_lrelu_2            
`define M_BYTES_axis_dw_lrelu_2            $M_BYTES_axis_dw_lrelu_2            
`define TUSER_WIDTH_axis_dw_lrelu_2_active $TUSER_WIDTH_axis_dw_lrelu_2_active  
`define TLAST_axis_dw_lrelu_2_active       $TLAST_axis_dw_lrelu_2_active       
`define TKEEP_axis_dw_lrelu_2_active       $TKEEP_axis_dw_lrelu_2_active       

`define TUSER_WIDTH_axis_dw_lrelu_2 $TUSER_WIDTH_axis_dw_lrelu_2 
`define TLAST_axis_dw_lrelu_2       $TLAST_axis_dw_lrelu_2       
`define TKEEP_axis_dw_lrelu_2       $TKEEP_axis_dw_lrelu_2       

`define DATA_BYTES_axis_reg_slice_lrelu_dw   $DATA_BYTES_axis_reg_slice_lrelu_dw    
`define TID_WIDTH_axis_reg_slice_lrelu_dw    $TID_WIDTH_axis_reg_slice_lrelu_dw     
`define TUSER_WIDTH_axis_reg_slice_lrelu_dw  $TUSER_WIDTH_axis_reg_slice_lrelu_dw  
`define TLAST_axis_reg_slice_lrelu_dw_active $TLAST_axis_reg_slice_lrelu_dw_active  
`define TKEEP_axis_reg_slice_lrelu_dw        $TKEEP_axis_reg_slice_lrelu_dw        

`define TLAST_axis_reg_slice_lrelu_dw $TLAST_axis_reg_slice_lrelu_dw        
`define TKEEP_axis_reg_slice_lrelu_dw $TKEEP_axis_reg_slice_lrelu_dw        

`define DATA_BYTES_axis_reg_slice_lrelu  $DATA_BYTES_axis_reg_slice_lrelu  
`define TLAST_axis_reg_slice_lrelu       $TLAST_axis_reg_slice_lrelu       
`define TKEEP_axis_reg_slice_lrelu       $TKEEP_axis_reg_slice_lrelu       
`define TUSER_WIDTH_axis_reg_slice_lrelu $TUSER_WIDTH_axis_reg_slice_lrelu 

`define TUSER_WIDTH_float_to_fixed_active $TUSER_WIDTH_float_to_fixed_active

`define BITS_FRA_IN_mod_float_downsize  $BITS_FRA_IN_mod_float_downsize 
`define BITS_EXP_IN_mod_float_downsize  $BITS_EXP_IN_mod_float_downsize 
`define BITS_FRA_OUT_mod_float_downsize $BITS_FRA_OUT_mod_float_downsize 
`define BITS_EXP_OUT_mod_float_downsize $BITS_EXP_OUT_mod_float_downsize 
`define LATENCY_mod_float_downsize      $LATENCY_mod_float_downsize     

`define BITS_FRA_IN_mod_float_upsize  $BITS_FRA_IN_mod_float_upsize 
`define BITS_EXP_IN_mod_float_upsize  $BITS_EXP_IN_mod_float_upsize 
`define BITS_FRA_OUT_mod_float_upsize $BITS_FRA_OUT_mod_float_upsize
`define BITS_EXP_OUT_mod_float_upsize $BITS_EXP_OUT_mod_float_upsize
`define LATENCY_mod_float_upsize      $LATENCY_mod_float_upsize     

`define S_BYTES_axis_dw_lrelu $S_BYTES_axis_dw_lrelu
`define M_BYTES_axis_dw_lrelu $M_BYTES_axis_dw_lrelu
`define TLAST_axis_dw_lrelu   $TLAST_axis_dw_lrelu  
`define TKEEP_axis_dw_lrelu   $TKEEP_axis_dw_lrelu  

`define S_BYTES_axis_dw_max_1 $S_BYTES_axis_dw_max_1
`define M_BYTES_axis_dw_max_1 $M_BYTES_axis_dw_max_1
`define TLAST_axis_dw_max_1   $TLAST_axis_dw_max_1  
`define TKEEP_axis_dw_max_1   $TKEEP_axis_dw_max_1  

`define S_BYTES_axis_dw_max_2 $S_BYTES_axis_dw_max_2
`define M_BYTES_axis_dw_max_2 $M_BYTES_axis_dw_max_2
`define TLAST_axis_dw_max_2   $TLAST_axis_dw_max_2  
`define TKEEP_axis_dw_max_2   $TKEEP_axis_dw_max_2  

`define DATA_BYTES_axis_reg_slice_maxpool $DATA_BYTES_axis_reg_slice_maxpool
`define TLAST_axis_reg_slice_maxpool      $TLAST_axis_reg_slice_maxpool     
`define TKEEP_axis_reg_slice_maxpool      $TKEEP_axis_reg_slice_maxpool     

"
close $file_param
