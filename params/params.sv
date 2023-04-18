
    // Written from param_tests.py

    `define SRAM_TYPE   "RAW"  
    `define MAC_TYPE    "RAW"  

    `define ROWS     8  
    `define COLS     24
    `define DW_FACTOR_1 3
    `define OUTPUT_MODE "CONV"
    `define KSM_COMBS_EXPR 1
    `define KS_COMBS_EXPR 1
    `define BRAM_WEIGHTS_DEPTH  1024     

    `define FREQ_HIGH     200
    `define FREQ_RATIO    1

    `define WORD_WIDTH          8         
    `define WORD_WIDTH_ACC      32    
    `define KH_MAX              3            
    `define KW_MAX              3            
    `define SH_MAX              2            
    `define SW_MAX              2            
    `define IM_ROWS_MAX         256
    `define IM_CIN_MAX          1024      
    `define IM_COLS_MAX         384     

    `define LATENCY_ACCUMULATOR   1    
    `define LATENCY_MULTIPLIER    1     
    `define LATENCY_BRAM          2     

    `define S_WEIGHTS_WIDTH_LF  64
    `define S_PIXELS_WIDTH_LF   64
    `define M_OUTPUT_WIDTH_LF   64


    // Calculated

    `define IM_BLOCKS_MAX    `IM_ROWS_MAX / `ROWS    
    `define ROWS_SHIFT        `ROWS  + `KH_MAX -1
    `define OUT_SHIFT_MAX      `COLS   /3
    `define IM_SHIFT_MAX       4   /* max( ceil(k/s)-1 )*/
    `define IM_SHIFT_REGS      `ROWS  + `IM_SHIFT_MAX

    `define BITS_KW            $clog2( `KW_MAX             )         
    `define BITS_KH            $clog2( `KH_MAX             )         
    `define BITS_SW            $clog2( `SW_MAX             )         
    `define BITS_SH            $clog2( `SH_MAX             )         
    `define BITS_IM_COLS       $clog2( `IM_COLS_MAX        )    
    `define BITS_IM_ROWS       $clog2( `IM_ROWS_MAX        )    
    `define BITS_IM_CIN        $clog2( `IM_CIN_MAX         )      
    `define BITS_IM_BLOCKS     $clog2( `IM_ROWS_MAX/`ROWS  )  
    `define BITS_IM_SHIFT      $clog2( `IM_SHIFT_MAX       )  
    `define BITS_IM_SHIFT_REGS $clog2( `IM_SHIFT_REGS+1    )  
    `define BITS_WEIGHTS_ADDR  $clog2( `BRAM_WEIGHTS_DEPTH )   
    `define BITS_MEMBERS       $clog2( `COLS               )    
    `define BITS_KW2           $clog2((`KW_MAX+1)/2        )        
    `define BITS_KH2           $clog2((`KH_MAX+1)/2        )        
    `define BITS_OUT_SHIFT     $clog2( `OUT_SHIFT_MAX      )        


    `define M_DATA_WIDTH_HF_CONV     `COLS  * `ROWS  * `WORD_WIDTH_ACC
    `define M_DATA_WIDTH_HF_CONV_DW  `ROWS  * `WORD_WIDTH_ACC
    `define M_DATA_WIDTH_HF_LRELU    `ROWS  * `WORD_WIDTH
    `define M_DATA_WIDTH_HF_MAX_DW1  `ROWS_SHIFT * `WORD_WIDTH
    `define M_DATA_WIDTH_LF_CONV_DW  8 * $clog2(`M_DATA_WIDTH_HF_CONV_DW * `FREQ_RATIO / 8) /* max 1024 */
    `define M_DATA_WIDTH_LF_LRELU    8 * $clog2(`M_DATA_WIDTH_HF_LRELU   * `FREQ_RATIO / 8) /* max 1024 */
    `define M_DATA_WIDTH_LF         `OUTPUT_MODE=="CONV" ? `M_DATA_WIDTH_LF_CONV_DW : `OUTPUT_MODE=="LRELU" ? `M_DATA_WIDTH_LF_LRELU : 0
    
    `ifndef VERILOG
    `ifndef STRUCT 
    `define STRUCT
    typedef struct packed {
        logic                 is_not_max;
        logic                 is_max;
        logic                 is_lrelu;
        logic [`BITS_KW2-1:0] kw2 ;
        logic [`BITS_SW -1:0] sw_1;
        logic                 is_config;
        logic                 is_top_block;
        logic                 is_bot_block;
        logic                 is_col_1_k2;
        logic                 is_cin_last;
        logic                 is_w_first;
        logic                 is_col_valid;
        logic                 is_sum_start;
    } tuser_st;
    `endif
    `endif
    `define TUSER_WIDTH `BITS_KW2 + `BITS_SW + 11
    