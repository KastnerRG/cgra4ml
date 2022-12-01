
`define SRAM_TYPE   "RAW"  
`define MAC_TYPE    "RAW"  

`define UNITS    8  
`define GROUPS   1 
`define COPIES   1 
`define MEMBERS  24
`define DW_FACTOR_1 3
`define OUTPUT_MODE "CONV"
`define KSM_COMBS_EXPR (((((((k==1 & s==1 & m==1)) | (k==3 & s==1 & m==1)) | (k==3 & s==1 & m==1)) | (k==5 & s==1 & m==1)) | (k==7 & s==2 & m==1)) | (k==11 & s==4 & m==1))
`define KS_COMBS_EXPR (((((((k==1 & s==1)) | (k==3 & s==1)) | (k==3 & s==1)) | (k==5 & s==1)) | (k==7 & s==2)) | (k==11 & s==4))

`define FREQ_HIGH     200
`define FREQ_RATIO    1

`define UNITS_EDGES        10
`define OUT_SHIFT_MAX      8
`define IM_SHIFT_REGS      12

`define WORD_WIDTH          8         
`define WORD_WIDTH_ACC      32    
`define KH_MAX              3            
`define KW_MAX              3            
`define SH_MAX              2            
`define SW_MAX              2            

`define BITS_KW           2          
`define BITS_KH           2          
`define BITS_SW           1          
`define BITS_SH           1          
`define BITS_IM_COLS      9     
`define BITS_IM_ROWS      8     
`define BITS_IM_CIN       10      
`define BITS_IM_BLOCKS    5   
`define BITS_IM_SHIFT     2   
`define BITS_IM_SHIFT_REGS 4   
`define BITS_WEIGHTS_ADDR  10   
`define BITS_MEMBERS      5     
`define BITS_KW2          1         
`define BITS_KH2          1         
`define BITS_OUT_SHIFT    3         

`define DEBUG_CONFIG_WIDTH_W_ROT   78  
`define DEBUG_CONFIG_WIDTH_IM_PIPE 6
`define DEBUG_CONFIG_WIDTH_LRELU   23  
`define DEBUG_CONFIG_WIDTH_MAXPOOL 1
`define DEBUG_CONFIG_WIDTH         110        

/*
  IMAGE TUSER INDICES
*/
`define TUSER_WIDTH_PIXELS   3 
`define TUSER_WIDTH_IM_SHIFT_IN   5 
`define TUSER_WIDTH_IM_SHIFT_OUT  3

`define IM_CIN_MAX       1024      
`define IM_BLOCKS_MAX    32   
`define IM_COLS_MAX      384     
`define LRELU_ALPHA      11878     
`define LRELU_BEATS_MAX  9
`define BRAM_WEIGHTS_DEPTH  1024     

`define S_WEIGHTS_WIDTH_LF  64
`define S_PIXELS_WIDTH_LF   64
`define M_OUTPUT_WIDTH_LF   64
`define M_DATA_WIDTH_HF_CONV    6144   
`define M_DATA_WIDTH_HF_CONV_DW 256
`define M_DATA_WIDTH_LF_CONV_DW 256
`define M_DATA_WIDTH_HF_LRELU   64  
`define M_DATA_WIDTH_LF_LRELU   64  
`define M_DATA_WIDTH_HF_MAXPOOL 80
`define M_DATA_WIDTH_HF_MAX_DW1 80
`define M_DATA_WIDTH_LF_MAXPOOL 128
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
`define LATENCY_ACCUMULATOR   1    
`define LATENCY_MULTIPLIER    3     
/*
  WEIGHTS TUSER INDICES
*/
`define I_WEIGHTS_IS_TOP_BLOCK     2   
`define I_WEIGHTS_IS_BOTTOM_BLOCK  3
`define I_WEIGHTS_IS_COLS_1_K2     4   
`define I_WEIGHTS_IS_CONFIG        5      
`define I_WEIGHTS_IS_CIN_LAST      6    
`define I_WEIGHTS_IS_W_FIRST       7    
`define I_WEIGHTS_KW2              0        
`define I_WEIGHTS_SW_1             1      
`define I_WEIGHTS_IS_COL_VALID     8      
`define I_WEIGHTS_IS_SUM_START     9      
`define TUSER_WIDTH_WEIGHTS_OUT    10  
/*
  CONV TUSER INDICES
*/
`define I_IS_NOT_MAX         0       
`define I_IS_MAX             1           
`define I_IS_LRELU           2         
`define I_KH2                3      
`define I_SH_1               4    

`define I_KW2                3        
`define I_SW_1               4    
`define I_IS_CONFIG          5        
`define I_IS_TOP_BLOCK       6     
`define I_IS_BOTTOM_BLOCK    7  
`define I_IS_COLS_1_K2       8     
`define I_IS_CIN_LAST        9      
`define I_IS_W_FIRST         10      
`define I_IS_COL_VALID       11      
`define I_IS_SUM_START       12      
`define TUSER_WIDTH_CONV_IN  13
/*
  LRELU & MAXPOOL TUSER INDICES
*/
`define I_CLR                8

`define TUSER_WIDTH_MAXPOOL_IN     4    
`define TUSER_WIDTH_LRELU_FMA_1_IN 3
`define TUSER_CONV_DW_BASE         8      
`define TUSER_CONV_DW_IN           64      
`define TUSER_WIDTH_LRELU_IN       10      
`define IS_CONV_DW_SLICE           0

/*
  Macro functions
*/
`define BEATS_CONFIG(KH,KW) 1+ 2*(2/KW + 2%KW) + 2*KH
`define CEIL(N,D) N/D + (N%D != 0)

