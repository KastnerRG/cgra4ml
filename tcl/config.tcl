
if {$XILINX} {
  
  set UNITS   4
  set GROUPS  2
  set MEMBERS 12
  set KSM_COMBS_LIST {{1 1 1} {3 1 1} {3 1 2} {5 1 1} {7 2 1} {11 4 1}}

  set LATENCY_BRAM          3
  set LATENCY_MULTIPLIER    3
  set LATENCY_ACCUMULATOR   1

  set FREQ_HIGH        200
  set WORD_WIDTH       8
  set WORD_WIDTH_ACC   32
  set S_WEIGHTS_WIDTH_LF 64
  set S_PIXELS_WIDTH_LF  64
  set M_OUTPUT_WIDTH_LF  64

  set SRAM_TYPE "XILINX"
  set MAC_TYPE "RAW"
  set REG_TYPE "FPGA"

  set KW_MAX        3
  set KH_MAX        3
  set SW_MAX        2
  set SH_MAX        2
  set IM_COLS_MAX   384
  set IM_ROWS_MAX   256
  set IM_CIN_MAX    1024
  # BRAM_WEIGHTS_DEPTH = max(KH * CIN * SH + lrelu_beats-1)
  set BRAM_WEIGHTS_DEPTH  1024 

} else {
  
  set UNITS   14
  set GROUPS  1
  set MEMBERS 14
  set KSM_COMBS_LIST {{1 1 1} {3 1 1} {3 1 1} {5 1 1} {7 2 1} {11 4 1}}

  set LATENCY_BRAM          2
  set LATENCY_MULTIPLIER    0
  set LATENCY_ACCUMULATOR   1

  set FREQ_HIGH        800
  set WORD_WIDTH       16
  set WORD_WIDTH_ACC   24
  set S_WEIGHTS_WIDTH_LF 64
  set S_PIXELS_WIDTH_LF  64
  set M_OUTPUT_WIDTH_LF  64

  set SRAM_TYPE "XILINX"
  set MAC_TYPE "RAW"
  set REG_TYPE "ASIC"

  set KW_MAX        11
  set KH_MAX        11
  set SW_MAX        4
  set SH_MAX        4
  set IM_COLS_MAX   384
  set IM_ROWS_MAX   256
  set IM_CIN_MAX    1024
  # BRAM_WEIGHTS_DEPTH = max(KH * CIN * SH + lrelu_beats-1)
  set BRAM_WEIGHTS_DEPTH  1024 
}

# ********************************************************************

set FREQ_RATIO  1

set OUTPUT_MODE "CONV"
# set OUTPUT_MODE "LRELU"
# set OUTPUT_MODE "MAXPOOL"

set FREQ_LITE   50
set DW_FACTOR_1 3 
set LRELU_BEATS_MAX  9
set IS_CONV_DW_SLICE 0
set LRELU_ALPHA   11878

set LATENCY_FMA_1         16
set LATENCY_FMA_2         15
set LATENCY_FIXED_2_FLOAT  6
set LATENCY_CYCLIC_REG     0
set LATENCY_FLOAT_UPSIZE   2
set LATENCY_FLOAT_DOWNSIZE 3

set BITS_EXP_CONFIG 5
set BITS_FRA_CONFIG 10
set BITS_EXP_FMA_1  8
set BITS_FRA_FMA_1  23
set BITS_EXP_FMA_2  5 
set BITS_FRA_FMA_2  10

# * Prepare KSM
set KSM_COMBS_EXPR ""
set KS_COMBS_EXPR ""
set IM_SHIFT_REGS 0
set IM_SHIFT_MAX 0
set COPIES 1

foreach comb $KSM_COMBS_LIST {
  set k [lindex $comb  0]
  set s [lindex $comb  1]
  set m [lindex $comb  2]

  set j [expr $k + $s - 1]
  set f [expr int(ceil($k.0/$s))-1]

  # Create string macro
  set pair_str "(k==$k & s==$s & m==$m)"
  set comb_str "$KSM_COMBS_EXPR | $pair_str"
  if {[string trim $KSM_COMBS_EXPR] == ""} {set KSM_COMBS_EXPR $pair_str} else {set KSM_COMBS_EXPR $comb_str}
  set KSM_COMBS_EXPR "($KSM_COMBS_EXPR)"

  set pair_str "(k==$k & s==$s)"
  set comb_str "$KS_COMBS_EXPR | $pair_str"
  if {[string trim $KS_COMBS_EXPR] == ""} {set KS_COMBS_EXPR $pair_str} else {set KS_COMBS_EXPR $comb_str}
  set KS_COMBS_EXPR "($KS_COMBS_EXPR)"

  # Find max(m)
  if {[expr $COPIES < $m]} {set COPIES $m}

  # Find max(F)
  if {[expr $IM_SHIFT_MAX < $f]} {set IM_SHIFT_MAX $f}

  # Find reg number
  set num_reg_needed [expr $m * $UNITS + $f]
  if {[expr $IM_SHIFT_REGS < $num_reg_needed]} {set IM_SHIFT_REGS $num_reg_needed}
}
puts $KS_COMBS_EXPR
puts $KSM_COMBS_EXPR
puts $COPIES

set FREQ_LOW           [expr $FREQ_HIGH.0/$FREQ_RATIO.0]
set IM_BLOCKS_MAX      [expr int($IM_ROWS_MAX / $UNITS)]
set UNITS_EDGES        [expr $UNITS + $KH_MAX      -1]
set OUT_SHIFT_MAX      [expr $MEMBERS/3]
set BITS_KW            [expr int(ceil(log($KW_MAX      )/log(2)))]
set BITS_KH            [expr int(ceil(log($KH_MAX      )/log(2)))]
set BITS_SW            [expr int(ceil(log($SW_MAX      )/log(2)))]
set BITS_SH            [expr int(ceil(log($SH_MAX      )/log(2)))]
set BITS_IM_COLS       [expr int(ceil(log($IM_COLS_MAX)/log(2)))]
set BITS_IM_ROWS       [expr int(ceil(log($IM_ROWS_MAX)/log(2)))]
set BITS_IM_CIN        [expr int(ceil(log($IM_CIN_MAX)/log(2)))]
set BITS_IM_BLOCKS     [expr int(ceil(log($IM_ROWS_MAX/$UNITS)/log(2)))]
set BITS_IM_SHIFT      [expr int(ceil(log($IM_SHIFT_MAX)/log(2)))]
set BITS_IM_SHIFT_REGS [expr int(ceil(log($IM_SHIFT_REGS+1)/log(2)))]
set BITS_WEIGHTS_ADDR  [expr int(ceil(log($BRAM_WEIGHTS_DEPTH)/log(2)))]
set BITS_OUT_SHIFT     [expr int(ceil(log($OUT_SHIFT_MAX)/log(2)))]
set BITS_MEMBERS       [expr int(ceil(log($MEMBERS)/log(2)))]
set BITS_KW2           [expr int(ceil(log(($KW_MAX      +1)/2)/log(2)))]
set BITS_KH2           [expr int(ceil(log(($KH_MAX      +1)/2)/log(2)))]

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

set WORD_WIDTH_LRELU_1   [expr 1 + $BITS_EXP_FMA_1 + $BITS_FRA_FMA_1]
set WORD_WIDTH_LRELU_2   [expr 1 + $BITS_EXP_FMA_2 + $BITS_FRA_FMA_2]
set WORD_WIDTH_LRELU_OUT $WORD_WIDTH

set BITS_FMA_1 [expr $BITS_FRA_FMA_1 + $BITS_EXP_FMA_1 + 1]
set BITS_FMA_2 [expr $BITS_FRA_FMA_2 + $BITS_EXP_FMA_2 + 1]

# IMAGE TUSER INDICES
set I_IS_NOT_MAX       0
set I_IS_MAX           [expr $I_IS_NOT_MAX + 1]
set I_IS_LRELU         [expr $I_IS_MAX     + 1]
set I_KH2              [expr $I_IS_LRELU   + 1]
set I_SH_1             [expr $I_KH2        + 1]
set TUSER_WIDTH_PIXELS [expr $I_IS_LRELU   + 1]

# ----------------DELETE
set TUSER_WIDTH_IM_SHIFT_IN  [expr $I_SH_1+ $BITS_SH]
set TUSER_WIDTH_IM_SHIFT_OUT [expr $I_IS_LRELU + 1]

# WEIGHTS TUSER INDICES
set I_WEIGHTS_KW2              0
set I_WEIGHTS_SW_1             [expr $I_WEIGHTS_KW2     + $BITS_KW2]
set I_WEIGHTS_IS_TOP_BLOCK     [expr $I_WEIGHTS_SW_1    + $BITS_SW ]
set I_WEIGHTS_IS_BOTTOM_BLOCK  [expr $I_WEIGHTS_IS_TOP_BLOCK    + 1]
set I_WEIGHTS_IS_COLS_1_K2     [expr $I_WEIGHTS_IS_BOTTOM_BLOCK + 1]
set I_WEIGHTS_IS_CONFIG        [expr $I_WEIGHTS_IS_COLS_1_K2    + 1]
set I_WEIGHTS_IS_CIN_LAST      [expr $I_WEIGHTS_IS_CONFIG       + 1] 
set I_WEIGHTS_IS_W_FIRST       [expr $I_WEIGHTS_IS_CIN_LAST     + 1] 
set I_WEIGHTS_IS_COL_VALID     [expr $I_WEIGHTS_IS_W_FIRST      + 1] 
set I_WEIGHTS_IS_SUM_START     [expr $I_WEIGHTS_IS_COL_VALID    + 1] 
set TUSER_WIDTH_WEIGHTS_OUT    [expr $I_WEIGHTS_IS_SUM_START    + 1]

# PIPE TUSER INDICES
set I_IS_NOT_MAX      0
set I_IS_MAX          [expr $I_IS_NOT_MAX      + 1]
set I_IS_LRELU        [expr $I_IS_MAX          + 1]
set I_KW2             [expr $I_IS_LRELU        + 1]
set I_SW_1            [expr $I_KW2     + $BITS_KW2]
set I_IS_CONFIG       [expr $I_SW_1    + $BITS_SW ]
set I_IS_TOP_BLOCK    [expr $I_IS_CONFIG       + 1]
set I_IS_BOTTOM_BLOCK [expr $I_IS_TOP_BLOCK    + 1]
set I_IS_COLS_1_K2    [expr $I_IS_BOTTOM_BLOCK + 1]
set I_IS_CIN_LAST     [expr $I_IS_COLS_1_K2    + 1]
set I_IS_W_FIRST      [expr $I_IS_CIN_LAST     + 1]
set I_IS_COL_VALID    [expr $I_IS_W_FIRST      + 1]
set I_IS_SUM_START    [expr $I_IS_COL_VALID    + 1]

set I_CLR             [expr $I_IS_BOTTOM_BLOCK + 1]

set TUSER_WIDTH_MAXPOOL_IN     [expr $BITS_KW2      + $I_KW2]
set TUSER_WIDTH_LRELU_IN       [expr $BITS_KW       + $I_CLR]
set TUSER_CONV_DW_BASE         [expr 1 + $I_IS_BOTTOM_BLOCK ]
set TUSER_CONV_DW_IN           [expr $MEMBERS*$BITS_KW + $BITS_OUT_SHIFT + $BITS_MEMBERS + $TUSER_CONV_DW_BASE]
set TUSER_WIDTH_LRELU_FMA_1_IN [expr 1         + $I_IS_LRELU]
set TUSER_WIDTH_CONV_IN        [expr $I_IS_SUM_START     + 1]

set DEBUG_CONFIG_WIDTH_W_ROT   [expr 1 + 2*$BITS_KW2 + 3*($BITS_KH2      + $BITS_IM_CIN + $BITS_IM_COLS + $BITS_IM_BLOCKS)]
set DEBUG_CONFIG_WIDTH_IM_PIPE [expr 3 + 2 + $BITS_KH2      + 0]
set DEBUG_CONFIG_WIDTH_LRELU   [expr 3 + 4 + $BITS_FMA_2]
set DEBUG_CONFIG_WIDTH_MAXPOOL 1
set DEBUG_CONFIG_WIDTH         [expr $DEBUG_CONFIG_WIDTH_MAXPOOL + $DEBUG_CONFIG_WIDTH_LRELU + 2*$BITS_KH2      + $DEBUG_CONFIG_WIDTH_IM_PIPE + $DEBUG_CONFIG_WIDTH_W_ROT]

# **********    STORE PARAMS    *************


set file_param [open $RTL_DIR/include/params.v w]

if {$MAC_TYPE == "XILINX"} {
  puts $file_param "`define MAC_XILINX 1"
}
if {$REG_TYPE == "ASIC"} {
  puts $file_param "`define ASIC_REG 1"
}

puts $file_param "
`define SRAM_TYPE   \"$SRAM_TYPE\"  
`define MAC_TYPE    \"$MAC_TYPE\"  

`define UNITS    $UNITS  
`define GROUPS   $GROUPS 
`define COPIES   $COPIES 
`define MEMBERS  $MEMBERS
`define DW_FACTOR_1 $DW_FACTOR_1
`define OUTPUT_MODE \"$OUTPUT_MODE\"
`define KSM_COMBS_EXPR $KSM_COMBS_EXPR
`define KS_COMBS_EXPR $KS_COMBS_EXPR

`define FREQ_HIGH     $FREQ_HIGH
`define FREQ_RATIO    $FREQ_RATIO

`define UNITS_EDGES        $UNITS_EDGES
`define OUT_SHIFT_MAX      $OUT_SHIFT_MAX
`define IM_SHIFT_REGS      $IM_SHIFT_REGS

`define WORD_WIDTH          $WORD_WIDTH         
`define WORD_WIDTH_ACC      $WORD_WIDTH_ACC    
`define KH_MAX              $KH_MAX            
`define KW_MAX              $KW_MAX            
`define SH_MAX              $SH_MAX            
`define SW_MAX              $SW_MAX            

`define BITS_KW           $BITS_KW          
`define BITS_KH           $BITS_KH          
`define BITS_SW           $BITS_SW          
`define BITS_SH           $BITS_SH          
`define BITS_IM_COLS      $BITS_IM_COLS     
`define BITS_IM_ROWS      $BITS_IM_ROWS     
`define BITS_IM_CIN       $BITS_IM_CIN      
`define BITS_IM_BLOCKS    $BITS_IM_BLOCKS   
`define BITS_IM_SHIFT     $BITS_IM_SHIFT   
`define BITS_IM_SHIFT_REGS $BITS_IM_SHIFT_REGS   
`define BITS_WEIGHTS_ADDR  $BITS_WEIGHTS_ADDR   
`define BITS_MEMBERS      $BITS_MEMBERS     
`define BITS_KW2          $BITS_KW2         
`define BITS_KH2          $BITS_KH2         
`define BITS_OUT_SHIFT    $BITS_OUT_SHIFT         

`define DEBUG_CONFIG_WIDTH_W_ROT   $DEBUG_CONFIG_WIDTH_W_ROT  
`define DEBUG_CONFIG_WIDTH_IM_PIPE $DEBUG_CONFIG_WIDTH_IM_PIPE
`define DEBUG_CONFIG_WIDTH_LRELU   $DEBUG_CONFIG_WIDTH_LRELU  
`define DEBUG_CONFIG_WIDTH_MAXPOOL $DEBUG_CONFIG_WIDTH_MAXPOOL
`define DEBUG_CONFIG_WIDTH         $DEBUG_CONFIG_WIDTH        

/*
  IMAGE TUSER INDICES
*/
`define TUSER_WIDTH_PIXELS   $TUSER_WIDTH_PIXELS 
`define TUSER_WIDTH_IM_SHIFT_IN   $TUSER_WIDTH_IM_SHIFT_IN 
`define TUSER_WIDTH_IM_SHIFT_OUT  $TUSER_WIDTH_IM_SHIFT_OUT

`define IM_CIN_MAX       $IM_CIN_MAX      
`define IM_BLOCKS_MAX    $IM_BLOCKS_MAX   
`define IM_COLS_MAX      $IM_COLS_MAX     
`define LRELU_ALPHA      $LRELU_ALPHA     
`define LRELU_BEATS_MAX  $LRELU_BEATS_MAX
`define BRAM_WEIGHTS_DEPTH  $BRAM_WEIGHTS_DEPTH     

`define S_WEIGHTS_WIDTH_LF  $S_WEIGHTS_WIDTH_LF
`define S_PIXELS_WIDTH_LF   $S_PIXELS_WIDTH_LF
`define M_OUTPUT_WIDTH_LF   $M_OUTPUT_WIDTH_LF
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
`define I_WEIGHTS_IS_W_FIRST       $I_WEIGHTS_IS_W_FIRST    
`define I_WEIGHTS_KW2              $I_WEIGHTS_KW2        
`define I_WEIGHTS_SW_1             $I_WEIGHTS_SW_1      
`define I_WEIGHTS_IS_COL_VALID     $I_WEIGHTS_IS_COL_VALID      
`define I_WEIGHTS_IS_SUM_START     $I_WEIGHTS_IS_SUM_START      
`define TUSER_WIDTH_WEIGHTS_OUT    $TUSER_WIDTH_WEIGHTS_OUT  
/*
  CONV TUSER INDICES
*/
`define I_IS_NOT_MAX         $I_IS_NOT_MAX       
`define I_IS_MAX             $I_IS_MAX           
`define I_IS_LRELU           $I_IS_LRELU         
`define I_KH2                $I_KH2      
`define I_SH_1               $I_SH_1    

`define I_KW2                $I_KW2        
`define I_SW_1               $I_SW_1    
`define I_IS_CONFIG          $I_IS_CONFIG        
`define I_IS_TOP_BLOCK       $I_IS_TOP_BLOCK     
`define I_IS_BOTTOM_BLOCK    $I_IS_BOTTOM_BLOCK  
`define I_IS_COLS_1_K2       $I_IS_COLS_1_K2     
`define I_IS_CIN_LAST        $I_IS_CIN_LAST      
`define I_IS_W_FIRST         $I_IS_W_FIRST      
`define I_IS_COL_VALID       $I_IS_COL_VALID      
`define I_IS_SUM_START       $I_IS_SUM_START      
`define TUSER_WIDTH_CONV_IN  $TUSER_WIDTH_CONV_IN
/*
  LRELU & MAXPOOL TUSER INDICES
*/
`define I_CLR                $I_CLR

`define TUSER_WIDTH_MAXPOOL_IN     $TUSER_WIDTH_MAXPOOL_IN    
`define TUSER_WIDTH_LRELU_FMA_1_IN $TUSER_WIDTH_LRELU_FMA_1_IN
`define TUSER_CONV_DW_BASE         $TUSER_CONV_DW_BASE      
`define TUSER_CONV_DW_IN           $TUSER_CONV_DW_IN      
`define TUSER_WIDTH_LRELU_IN       $TUSER_WIDTH_LRELU_IN      
`define IS_CONV_DW_SLICE           $IS_CONV_DW_SLICE

/*
  Macro functions
*/
`define BEATS_CONFIG(KH,KW) 1+ 2*(2/KW + 2%KW) + 2*KH
`define CEIL(N,D) N/D + (N%D != 0)
"
close $file_param
