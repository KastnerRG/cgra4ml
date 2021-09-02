/*
Parameters of the system. Written from build.tcl
*/

`define UNITS    4  
`define GROUPS   2 
`define COPIES   1 
`define MEMBERS  12
`define DW_FACTOR_1 3
`define OUTPUT_MODE "LRELU"

`define FREQ_HIGH     200
`define FREQ_RATIO    4

`define CORES              2
`define UNITS_EDGES        6
`define IM_IN_S_DATA_WORDS 32

`define WORD_WIDTH          8         
`define WORD_WIDTH_ACC      32    
`define KH_MAX              3            
`define KW_MAX              3            

`define TKEEP_WIDTH_IM_IN 32
`define BITS_KW           2          
`define BITS_KH           2          
`define BITS_IM_COLS      9     
`define BITS_IM_ROWS      8     
`define BITS_IM_CIN       10      
`define BITS_IM_BLOCKS    6   
`define BITS_MEMBERS      4     
`define BITS_KW2          1         
`define BITS_KH2          1         

`define DEBUG_CONFIG_WIDTH_W_ROT   81  
`define DEBUG_CONFIG_WIDTH_IM_PIPE 6
`define DEBUG_CONFIG_WIDTH_LRELU   23  
`define DEBUG_CONFIG_WIDTH_MAXPOOL 1
`define DEBUG_CONFIG_WIDTH         113        

/*
  IMAGE TUSER INDICES
*/
`define TUSER_WIDTH_IM_SHIFT_IN   4 
`define TUSER_WIDTH_IM_SHIFT_OUT  4

`define IM_CIN_MAX       1024      
`define IM_BLOCKS_MAX    64   
`define IM_COLS_MAX      384     
`define LRELU_ALPHA      11878     
`define LRELU_BEATS_MAX  9

`define S_WEIGHTS_WIDTH_HF  32
`define S_WEIGHTS_WIDTH_LF  128
`define M_DATA_WIDTH_HF_CONV    3072   
`define M_DATA_WIDTH_HF_CONV_DW 256
`define M_DATA_WIDTH_LF_CONV_DW 1024
`define M_DATA_WIDTH_HF_LRELU   64  
`define M_DATA_WIDTH_LF_LRELU   256  
`define M_DATA_WIDTH_HF_MAXPOOL 96
`define M_DATA_WIDTH_HF_MAX_DW1 96
`define M_DATA_WIDTH_LF_MAXPOOL 512
`define M_DATA_WIDTH_LF         256
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
`define I_WEIGHTS_IS_COLS_1_K2     2   
`define I_WEIGHTS_IS_CONFIG        3      
`define I_WEIGHTS_IS_CIN_LAST      4    
`define I_WEIGHTS_KW2              5        
`define TUSER_WIDTH_WEIGHTS_OUT    6  
/*
  CONV TUSER INDICES
*/
`define I_IS_NOT_MAX         0       
`define I_IS_MAX             1           
`define I_KH2                2      
`define I_IS_LRELU           3         
`define I_IS_TOP_BLOCK       4     
`define I_IS_BOTTOM_BLOCK    5  
`define I_IS_COLS_1_K2       6     
`define I_IS_CONFIG          7        
`define I_IS_CIN_LAST        8      
`define I_KW2                9        
`define TUSER_WIDTH_CONV_IN  10
/*
  LRELU & MAXPOOL TUSER INDICES
*/
`define I_CLR                6

`define TUSER_WIDTH_MAXPOOL_IN     3    
`define TUSER_WIDTH_LRELU_FMA_1_IN 4
`define TUSER_WIDTH_LRELU_IN       8      
`define IS_CONV_DW_SLICE           0

/*
  Macro functions
*/
`define BEATS_CONFIG(KH,KW) 1+ 2*(2/KW + 2%KW) + 2*KH
`define CEIL(N,D) N/D + (N%D != 0)

