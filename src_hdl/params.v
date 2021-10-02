`define XILINX   1
/*
Parameters of the system. Written from build.tcl
*/

`define UNITS    7  
`define GROUPS   2 
`define COPIES   2 
`define MEMBERS  12
`define DW_FACTOR_1 3
`define OUTPUT_MODE "CONV"
`define KSM_COMBS_EXPR (((((((k==1 & s==1 & m==1)) | (k==3 & s==1 & m==1)) | (k==3 & s==1 & m==2)) | (k==5 & s==1 & m==1)) | (k==7 & s==2 & m==1)) | (k==11 & s==4 & m==1))
`define KS_COMBS_EXPR (((((((k==1 & s==1)) | (k==3 & s==1)) | (k==3 & s==1)) | (k==5 & s==1)) | (k==7 & s==2)) | (k==11 & s==4))

`define FREQ_HIGH     200
`define FREQ_RATIO    1

`define UNITS_EDGES        17
`define IM_SHIFT_REGS      16

`define WORD_WIDTH          8         
`define WORD_WIDTH_ACC      32    
`define KH_MAX              11            
`define KW_MAX              11            
`define SH_MAX              4            
`define SW_MAX              4            

`define BITS_KW           4          
`define BITS_KH           4          
`define BITS_SW           2          
`define BITS_SH           2          
`define BITS_IM_COLS      9     
`define BITS_IM_ROWS      8     
`define BITS_IM_CIN       10      
`define BITS_IM_BLOCKS    6   
`define BITS_IM_SHIFT     2   
`define BITS_IM_SHIFT_REGS 5   
`define BITS_MEMBERS      4     
`define BITS_KW2          3         
`define BITS_KH2          3         

`define DEBUG_CONFIG_WIDTH_W_ROT   91  
`define DEBUG_CONFIG_WIDTH_IM_PIPE 8
`define DEBUG_CONFIG_WIDTH_LRELU   23  
`define DEBUG_CONFIG_WIDTH_MAXPOOL 1
`define DEBUG_CONFIG_WIDTH         129        

/*
  IMAGE TUSER INDICES
*/
`define TUSER_WIDTH_PIXELS   3 
`define TUSER_WIDTH_IM_SHIFT_IN   6 
`define TUSER_WIDTH_IM_SHIFT_OUT  3

`define IM_CIN_MAX       1024      
`define IM_BLOCKS_MAX    36   
`define IM_COLS_MAX      384     
`define LRELU_ALPHA      11878     
`define LRELU_BEATS_MAX  9
`define BRAM_WEIGHTS_DEPTH  1024     

`define S_WEIGHTS_WIDTH_HF  64
`define S_WEIGHTS_WIDTH_LF  64
`define S_PIXELS_WIDTH_LF   64
`define M_DATA_WIDTH_HF_CONV    10752   
`define M_DATA_WIDTH_HF_CONV_DW 896
`define M_DATA_WIDTH_LF_CONV_DW 1024
`define M_DATA_WIDTH_HF_LRELU   224  
`define M_DATA_WIDTH_LF_LRELU   256  
`define M_DATA_WIDTH_HF_MAXPOOL 544
`define M_DATA_WIDTH_HF_MAX_DW1 272
`define M_DATA_WIDTH_LF_MAXPOOL 512
`define M_DATA_WIDTH_LF         1024
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
`define I_WEIGHTS_IS_TOP_BLOCK     5   
`define I_WEIGHTS_IS_BOTTOM_BLOCK  6
`define I_WEIGHTS_IS_COLS_1_K2     7   
`define I_WEIGHTS_IS_CONFIG        8      
`define I_WEIGHTS_IS_CIN_LAST      9    
`define I_WEIGHTS_IS_W_FIRST       10    
`define I_WEIGHTS_KW2              0        
`define I_WEIGHTS_SW_1             3      
`define I_WEIGHTS_IS_COL_VALID     11      
`define I_WEIGHTS_IS_SUM_START     12      
`define TUSER_WIDTH_WEIGHTS_OUT    13  
/*
  CONV TUSER INDICES
*/
`define I_IS_NOT_MAX         0       
`define I_IS_MAX             1           
`define I_IS_LRELU           2         
`define I_KH2                3      
`define I_SH_1               4    

`define I_KW2                3        
`define I_SW_1               6    
`define I_IS_TOP_BLOCK       8     
`define I_IS_BOTTOM_BLOCK    9  
`define I_IS_COLS_1_K2       10     
`define I_IS_CONFIG          11        
`define I_IS_CIN_LAST        12      
`define I_IS_W_FIRST         13      
`define I_IS_COL_VALID       14      
`define I_IS_SUM_START       15      
`define TUSER_WIDTH_CONV_IN  16
/*
  LRELU & MAXPOOL TUSER INDICES
*/
`define I_CLR                10

`define TUSER_WIDTH_MAXPOOL_IN     6    
`define TUSER_WIDTH_LRELU_FMA_1_IN 3
`define TUSER_WIDTH_LRELU_IN       14      
`define IS_CONV_DW_SLICE           0

/*
  Macro functions
*/
`define BEATS_CONFIG(KH,KW) 1+ 2*(2/KW + 2%KW) + 2*KH
`define CEIL(N,D) N/D + (N%D != 0)

/*
  IP Parameters
*/

`define S_BYTES_axis_dw_weights_clk    8 
`define M_BYTES_axis_dw_weights_clk    8 
`define DATA_BYTES_axis_clk_weights    8    
`define DATA_BYTES_axis_clk_image      8      
`define DATA_BYTES_axis_clk_conv_dw    128    
`define DATA_BYTES_axis_clk_lrelu      32      
`define DATA_BYTES_axis_clk_maxpool    64    

`define S_BYTES_axis_dw_image_input    8 
`define M_BYTES_axis_dw_image_input    17 
`define TLAST_axis_dw_image_input      1   
`define TKEEP_axis_dw_image_input      1   

`define DATA_BYTES_axis_reg_slice_image_pipe  7 
`define TLAST_axis_reg_slice_image_pipe       0      
`define TKEEP_axis_reg_slice_image_pipe       0      
`define TUSER_WIDTH_axis_reg_slice_image_pipe 3

`define R_WIDTH_bram_weights 384 
`define R_DEPTH_bram_weights 1024 
`define W_WIDTH_bram_weights 384 
`define W_DEPTH_bram_weights 1024 

`define S_BYTES_axis_dw_weights_input 8 
`define M_BYTES_axis_dw_weights_input 48 
`define TLAST_axis_dw_weights_input   1   
`define TKEEP_axis_dw_weights_input   1   

`define DATA_BYTES_slice_conv  28  
`define TLAST_slice_conv       0       
`define TKEEP_slice_conv       0       
`define TUSER_WIDTH_slice_conv 0 

`define DATA_BYTES_slice_conv_semi_active  28   
`define TLAST_slice_conv_semi_active       0       
`define TKEEP_slice_conv_semi_active       1        
`define TUSER_WIDTH_slice_conv_semi_active 14  

`define DATA_BYTES_slice_conv_active  28  
`define TLAST_slice_conv_active       1     
`define TKEEP_slice_conv_active       1     
`define TUSER_WIDTH_slice_conv_active 14 

`define S_BYTES_axis_dw_conv 112 
`define M_BYTES_axis_dw_conv 128 
`define TLAST_axis_dw_conv   1   
`define TKEEP_axis_dw_conv   1   

`define S_BYTES_axis_dw_lrelu_1_active     12     
`define M_BYTES_axis_dw_lrelu_1_active     4     
`define TUSER_WIDTH_axis_dw_lrelu_1_active 14 
`define TLAST_axis_dw_lrelu_1_active       1       
`define TKEEP_axis_dw_lrelu_1_active       1       

`define TUSER_WIDTH_axis_dw_lrelu_1 0 
`define TLAST_axis_dw_lrelu_1       0       
`define TKEEP_axis_dw_lrelu_1       1       

`define S_BYTES_axis_dw_lrelu_2            16            
`define M_BYTES_axis_dw_lrelu_2            4            
`define TUSER_WIDTH_axis_dw_lrelu_2_active 14  
`define TLAST_axis_dw_lrelu_2_active       1       
`define TKEEP_axis_dw_lrelu_2_active       1       

`define TUSER_WIDTH_axis_dw_lrelu_2 0 
`define TLAST_axis_dw_lrelu_2       0       
`define TKEEP_axis_dw_lrelu_2       1       

`define DATA_BYTES_axis_reg_slice_lrelu_dw   28    
`define TID_WIDTH_axis_reg_slice_lrelu_dw    14     
`define TUSER_WIDTH_axis_reg_slice_lrelu_dw  0  
`define TLAST_axis_reg_slice_lrelu_dw_active 1  
`define TKEEP_axis_reg_slice_lrelu_dw        0        

`define TLAST_axis_reg_slice_lrelu_dw 0        
`define TKEEP_axis_reg_slice_lrelu_dw 0        

`define DATA_BYTES_axis_reg_slice_lrelu  28  
`define TLAST_axis_reg_slice_lrelu       1       
`define TKEEP_axis_reg_slice_lrelu       0       
`define TUSER_WIDTH_axis_reg_slice_lrelu 6 

`define TUSER_WIDTH_float_to_fixed_active 6

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

`define S_BYTES_axis_dw_lrelu 28
`define M_BYTES_axis_dw_lrelu 32
`define TLAST_axis_dw_lrelu   1  
`define TKEEP_axis_dw_lrelu   1  

`define S_BYTES_axis_dw_max_1 68
`define M_BYTES_axis_dw_max_1 34
`define TLAST_axis_dw_max_1   1  
`define TKEEP_axis_dw_max_1   1  

`define S_BYTES_axis_dw_max_2 34
`define M_BYTES_axis_dw_max_2 128
`define TLAST_axis_dw_max_2   1  
`define TKEEP_axis_dw_max_2   1  

`define DATA_BYTES_axis_reg_slice_maxpool 28
`define TLAST_axis_reg_slice_maxpool      1     
`define TKEEP_axis_reg_slice_maxpool      1     


