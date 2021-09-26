`define XILINX   1
/*
Parameters of the system. Written from build.tcl
*/

`define UNITS    4  
`define GROUPS   2 
`define COPIES   2 
`define MEMBERS  12
`define DW_FACTOR_1 3
`define OUTPUT_MODE "CONV"

`define FREQ_HIGH     200
`define FREQ_RATIO    1

`define CORES              4
`define UNITS_EDGES        6
`define IM_IN_S_DATA_WORDS 8

`define WORD_WIDTH          8         
`define WORD_WIDTH_ACC      32    
`define KH_MAX              3            
`define KW_MAX              3            
`define SH_MAX              3            
`define SW_MAX              3            

`define TKEEP_WIDTH_IM_IN 8
`define BITS_KW           2          
`define BITS_KH           2          
`define BITS_SW           2          
`define BITS_SH           2          
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
`define TUSER_WIDTH_IM_SHIFT_IN   6 
`define TUSER_WIDTH_IM_SHIFT_OUT  3

`define IM_CIN_MAX       1024      
`define IM_BLOCKS_MAX    64   
`define IM_COLS_MAX      384     
`define LRELU_ALPHA      11878     
`define LRELU_BEATS_MAX  9

`define S_WEIGHTS_WIDTH_HF  32
`define S_WEIGHTS_WIDTH_LF  32
`define M_DATA_WIDTH_HF_CONV    6144   
`define M_DATA_WIDTH_HF_CONV_DW 512
`define M_DATA_WIDTH_LF_CONV_DW 512
`define M_DATA_WIDTH_HF_LRELU   128  
`define M_DATA_WIDTH_LF_LRELU   128  
`define M_DATA_WIDTH_HF_MAXPOOL 192
`define M_DATA_WIDTH_HF_MAX_DW1 96
`define M_DATA_WIDTH_LF_MAXPOOL 128
`define M_DATA_WIDTH_LF         512
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
`define I_WEIGHTS_IS_TOP_BLOCK     3   
`define I_WEIGHTS_IS_BOTTOM_BLOCK  4
`define I_WEIGHTS_IS_COLS_1_K2     5   
`define I_WEIGHTS_IS_CONFIG        6      
`define I_WEIGHTS_IS_CIN_LAST      7    
`define I_WEIGHTS_IS_W_FIRST       8    
`define I_WEIGHTS_KW2              0        
`define I_WEIGHTS_SW_1             1      
`define TUSER_WIDTH_WEIGHTS_OUT    9  
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
`define I_IS_TOP_BLOCK       6     
`define I_IS_BOTTOM_BLOCK    7  
`define I_IS_COLS_1_K2       8     
`define I_IS_CONFIG          9        
`define I_IS_CIN_LAST        10      
`define I_IS_W_FIRST         11      
`define TUSER_WIDTH_CONV_IN  12
/*
  LRELU & MAXPOOL TUSER INDICES
*/
`define I_CLR                8

`define TUSER_WIDTH_MAXPOOL_IN     4    
`define TUSER_WIDTH_LRELU_FMA_1_IN 3
`define TUSER_WIDTH_LRELU_IN       10      
`define IS_CONV_DW_SLICE           0

/*
  Macro functions
*/
`define BEATS_CONFIG(KH,KW) 1+ 2*(2/KW + 2%KW) + 2*KH
`define CEIL(N,D) N/D + (N%D != 0)

/*
  IP Parameters
*/

`define S_BYTES_axis_dw_weights_clk    4 
`define M_BYTES_axis_dw_weights_clk    4 
`define DATA_BYTES_axis_clk_weights    4    
`define DATA_BYTES_axis_clk_image      8      
`define DATA_BYTES_axis_clk_conv_dw    64    
`define DATA_BYTES_axis_clk_lrelu      16      
`define DATA_BYTES_axis_clk_maxpool    16    

`define S_BYTES_axis_dw_image_input    8 
`define M_BYTES_axis_dw_image_input    6 
`define TLAST_axis_dw_image_input      1   
`define TKEEP_axis_dw_image_input      1   

`define DATA_BYTES_axis_reg_slice_image_pipe  4 
`define TLAST_axis_reg_slice_image_pipe       0      
`define TKEEP_axis_reg_slice_image_pipe       0      
`define TUSER_WIDTH_axis_reg_slice_image_pipe 3

`define R_WIDTH_bram_weights 384 
`define R_DEPTH_bram_weights 3080 
`define W_WIDTH_bram_weights 384 
`define W_DEPTH_bram_weights 3080 

`define S_BYTES_axis_dw_weights_input 4 
`define M_BYTES_axis_dw_weights_input 48 
`define TLAST_axis_dw_weights_input   1   
`define TKEEP_axis_dw_weights_input   1   

`define DATA_BYTES_slice_conv  16  
`define TLAST_slice_conv       0       
`define TKEEP_slice_conv       0       
`define TUSER_WIDTH_slice_conv 0 

`define DATA_BYTES_slice_conv_semi_active  16   
`define TLAST_slice_conv_semi_active       0       
`define TKEEP_slice_conv_semi_active       1        
`define TUSER_WIDTH_slice_conv_semi_active 10  

`define DATA_BYTES_slice_conv_active  16  
`define TLAST_slice_conv_active       1     
`define TKEEP_slice_conv_active       1     
`define TUSER_WIDTH_slice_conv_active 10 

`define S_BYTES_axis_dw_conv 64 
`define M_BYTES_axis_dw_conv 64 
`define TLAST_axis_dw_conv   1   
`define TKEEP_axis_dw_conv   1   

`define S_BYTES_axis_dw_lrelu_1_active     12     
`define M_BYTES_axis_dw_lrelu_1_active     4     
`define TUSER_WIDTH_axis_dw_lrelu_1_active 10 
`define TLAST_axis_dw_lrelu_1_active       1       
`define TKEEP_axis_dw_lrelu_1_active       1       

`define TUSER_WIDTH_axis_dw_lrelu_1 0 
`define TLAST_axis_dw_lrelu_1       0       
`define TKEEP_axis_dw_lrelu_1       1       

`define S_BYTES_axis_dw_lrelu_2            16            
`define M_BYTES_axis_dw_lrelu_2            4            
`define TUSER_WIDTH_axis_dw_lrelu_2_active 10  
`define TLAST_axis_dw_lrelu_2_active       1       
`define TKEEP_axis_dw_lrelu_2_active       1       

`define TUSER_WIDTH_axis_dw_lrelu_2 0 
`define TLAST_axis_dw_lrelu_2       0       
`define TKEEP_axis_dw_lrelu_2       1       

`define DATA_BYTES_axis_reg_slice_lrelu_dw   16    
`define TID_WIDTH_axis_reg_slice_lrelu_dw    10     
`define TUSER_WIDTH_axis_reg_slice_lrelu_dw  0  
`define TLAST_axis_reg_slice_lrelu_dw_active 1  
`define TKEEP_axis_reg_slice_lrelu_dw        0        

`define TLAST_axis_reg_slice_lrelu_dw 0        
`define TKEEP_axis_reg_slice_lrelu_dw 0        

`define DATA_BYTES_axis_reg_slice_lrelu  16  
`define TLAST_axis_reg_slice_lrelu       1       
`define TKEEP_axis_reg_slice_lrelu       0       
`define TUSER_WIDTH_axis_reg_slice_lrelu 4 

`define TUSER_WIDTH_float_to_fixed_active 4

`define BITS_FRA_IN_mod_float_downsize  24 
`define BITS_EXP_IN_mod_float_downsize  8 
`define BITS_FRA_OUT_mod_float_downsize 11 
`define BITS_EXP_OUT_mod_float_downsize 5 
`define LATENCY_mod_float_downsize      3     

`define BITS_FRA_IN_mod_float_upsize  11 
`define BITS_EXP_IN_mod_float_upsize  5 
`define BITS_FRA_OUT_mod_float_upsize 24
`define BITS_EXP_OUT_mod_float_upsize 8
`define LATENCY_mod_float_upsize      2     

`define S_BYTES_axis_dw_lrelu 16
`define M_BYTES_axis_dw_lrelu 16
`define TLAST_axis_dw_lrelu   1  
`define TKEEP_axis_dw_lrelu   1  

`define S_BYTES_axis_dw_max_1 24
`define M_BYTES_axis_dw_max_1 12
`define TLAST_axis_dw_max_1   1  
`define TKEEP_axis_dw_max_1   1  

`define S_BYTES_axis_dw_max_2 12
`define M_BYTES_axis_dw_max_2 64
`define TLAST_axis_dw_max_2   1  
`define TKEEP_axis_dw_max_2   1  

`define DATA_BYTES_axis_reg_slice_maxpool 16
`define TLAST_axis_reg_slice_maxpool      1     
`define TKEEP_axis_reg_slice_maxpool      1     


