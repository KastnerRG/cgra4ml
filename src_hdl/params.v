/*
Parameters of the system. Written from build.tcl
*/

`define UNITS    4  
`define GROUPS   2 
`define COPIES   2 
`define MEMBERS  12
`define DW_FACTOR_1 3

`define CORES              4
`define UNITS_EDGES        6
`define IM_IN_S_DATA_WORDS 8

`define WORD_WIDTH          8         
`define WORD_WIDTH_ACC      32    
`define KERNEL_H_MAX        3      
`define KERNEL_W_MAX        3      
`define BEATS_CONFIG_3X3_1  8
`define BEATS_CONFIG_1X1_1  4

`define BITS_KERNEL_H     2
`define BITS_KERNEL_W     2
`define TKEEP_WIDTH_IM_IN 8
`define BITS_CONFIG_COUNT 4

`define DEBUG_CONFIG_WIDTH_W_ROT   86  
`define DEBUG_CONFIG_WIDTH_IM_PIPE 15
`define DEBUG_CONFIG_WIDTH_LRELU   23  
`define DEBUG_CONFIG_WIDTH_MAXPOOL 1
`define DEBUG_CONFIG_WIDTH         129        

/*
  IMAGE TUSER INDICES
*/
`define I_IMAGE_IS_NOT_MAX        0      
`define I_IMAGE_IS_MAX            1          
`define I_IMAGE_IS_LRELU          2        
`define I_IMAGE_KERNEL_H_1        3       
`define TUSER_WIDTH_IM_SHIFT_IN   5 
`define TUSER_WIDTH_IM_SHIFT_OUT  3

`define IM_CIN_MAX       1024      
`define IM_BLOCKS_MAX    64   
`define IM_COLS_MAX      384     
`define S_WEIGHTS_WIDTH 32
`define M_DATA_WIDTH     128
`define LRELU_ALPHA      11878     
/*
  LATENCIES & float widths
*/
`define BITS_EXP_CONFIG       5      
`define BITS_FRA_CONFIG       10      
`define BITS_EXP_FMA_1        8       
`define BITS_FRA_FMA_1        23       
`define BITS_EXP_FMA_2        5       
`define BITS_FRA_FMA_2        10       
`define LATENCY_FMA_1         16        
`define LATENCY_FMA_2         15        
`define LATENCY_FIXED_2_FLOAT 6
`define LATENCY_BRAM          3         
`define LATENCY_CYCLIC_REG    0         
`define LATENCY_FLOAT_UPSIZE   2   
`define LATENCY_FLOAT_DOWNSIZE 3   
`define LATENCY_ACCUMULATOR   2    
`define LATENCY_MULTIPLIER    3     
/*
  WEIGHTS TUSER INDICES
*/
`define I_WEIGHTS_IS_TOP_BLOCK     0   
`define I_WEIGHTS_IS_BOTTOM_BLOCK  1
`define I_WEIGHTS_IS_1X1           2         
`define I_WEIGHTS_IS_COLS_1_K2     3   
`define I_WEIGHTS_IS_CONFIG        4      
`define I_WEIGHTS_IS_CIN_LAST      5    
`define I_WEIGHTS_KERNEL_W_1       6      
`define TUSER_WIDTH_WEIGHTS_OUT    8  
/*
  CONV TUSER INDICES
*/
`define I_IS_NOT_MAX         0       
`define I_IS_MAX             1           
`define I_IS_1X1             2           
`define I_IS_LRELU           3         
`define I_IS_TOP_BLOCK       4     
`define I_IS_BOTTOM_BLOCK    5  
`define I_IS_COLS_1_K2       6     
`define I_IS_CONFIG          7        
`define I_IS_CIN_LAST        8      
`define I_KERNEL_W_1         9        
`define TUSER_WIDTH_CONV_IN  11
/*
  LRELU & MAXPOOL TUSER INDICES
*/
`define I_IS_LEFT_COL        6 
`define I_IS_RIGHT_COL       7

`define TUSER_WIDTH_MAXPOOL_IN     3    
`define TUSER_WIDTH_LRELU_FMA_1_IN 4
`define TUSER_WIDTH_LRELU_IN       8      
`define IS_CONV_DW_SLICE           0

