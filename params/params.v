
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
    `define LRELU_ALPHA      11878     
    `define LRELU_BEATS_MAX  9

    `define LATENCY_ACCUMULATOR   1    
    `define LATENCY_MULTIPLIER    1     

    `define S_WEIGHTS_WIDTH_LF  64
    `define S_PIXELS_WIDTH_LF   64
    `define M_OUTPUT_WIDTH_LF   64

    `define BITS_EXP_CONFIG       5      
    `define BITS_FRA_CONFIG       10      
    `define BITS_EXP_FMA_1        8       
    `define BITS_FRA_FMA_1        23       
    `define BITS_EXP_FMA_2        5       
    `define BITS_FRA_FMA_2        10       
    `define LATENCY_FMA_1         16        
    `define LATENCY_FMA_2         15        
    `define LATENCY_FIXED_2_FLOAT 6
    `define LATENCY_BRAM          2         
    `define LATENCY_CYCLIC_REG    0         
    `define LATENCY_FLOAT_UPSIZE   2   
    `define LATENCY_FLOAT_DOWNSIZE 3   


    // Calculated

    `define IM_BLOCKS_MAX    `IM_ROWS_MAX / `ROWS    
    `define UNITS_EDGES        `ROWS  + `KH_MAX -1
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


    `define M_DATA_WIDTH_HF_CONV     `COLS    * `ROWS  * `WORD_WIDTH_ACC
    `define M_DATA_WIDTH_HF_CONV_DW  `ROWS  * `WORD_WIDTH_ACC
    `define M_DATA_WIDTH_HF_LRELU    `ROWS  * `WORD_WIDTH
    `define M_DATA_WIDTH_HF_MAXPOOL  `UNITS_EDGES * `WORD_WIDTH
    `define M_DATA_WIDTH_HF_MAX_DW1  `UNITS_EDGES * `WORD_WIDTH
    `define M_DATA_WIDTH_LF_CONV_DW  8 * $clog2(`M_DATA_WIDTH_HF_CONV_DW * `FREQ_RATIO / 8) /* max 1024 */
    `define M_DATA_WIDTH_LF_LRELU    8 * $clog2(`M_DATA_WIDTH_HF_LRELU   * `FREQ_RATIO / 8) /* max 1024 */
    `define M_DATA_WIDTH_LF_MAXPOOL  8 * $clog2(`M_DATA_WIDTH_HF_MAX_DW1 * `FREQ_RATIO / 8) /* max 1024 */
    `define M_DATA_WIDTH_LF         `OUTPUT_MODE=="CONV" ? `M_DATA_WIDTH_LF_CONV_DW : `OUTPUT_MODE=="LRELU" ? `M_DATA_WIDTH_LF_LRELU : `OUTPUT_MODE=="MAXPOOL" ? `M_DATA_WIDTH_LF_MAXPOOL : 0

    `define DEBUG_CONFIG_WIDTH_W_ROT   1 + 2*`BITS_KW2 + 3*(`BITS_KH2      + `BITS_IM_CIN + `BITS_IM_COLS + `BITS_IM_BLOCKS)
    `define DEBUG_CONFIG_WIDTH_IM_PIPE 3 + 2 + `BITS_KH2      + 0
    `define DEBUG_CONFIG_WIDTH_LRELU   3 + 4 + `BITS_FRA_FMA_2 + `BITS_EXP_FMA_2 + 1
    `define DEBUG_CONFIG_WIDTH_MAXPOOL 1
    `define DEBUG_CONFIG_WIDTH         `DEBUG_CONFIG_WIDTH_MAXPOOL + `DEBUG_CONFIG_WIDTH_LRELU + 2*`BITS_KH2      + `DEBUG_CONFIG_WIDTH_IM_PIPE + `DEBUG_CONFIG_WIDTH_W_ROT


    // IMAGE TUSER INDICES
    `define I_IS_NOT_MAX       0
    `define I_IS_MAX            `I_IS_NOT_MAX + 1
    `define I_IS_LRELU          `I_IS_MAX     + 1
    `define I_KH2               `I_IS_LRELU   + 1
    `define I_SH_1              `I_KH2        + 1
    `define TUSER_WIDTH_PIXELS  `I_IS_LRELU   + 1

    // WEIGHTS TUSER INDICES
    `define I_WEIGHTS_KW2              0
    `define I_WEIGHTS_SW_1              `I_WEIGHTS_KW2     + `BITS_KW2
    `define I_WEIGHTS_IS_TOP_BLOCK      `I_WEIGHTS_SW_1    + `BITS_SW 
    `define I_WEIGHTS_IS_BOTTOM_BLOCK   `I_WEIGHTS_IS_TOP_BLOCK    + 1
    `define I_WEIGHTS_IS_COLS_1_K2      `I_WEIGHTS_IS_BOTTOM_BLOCK + 1
    `define I_WEIGHTS_IS_CONFIG         `I_WEIGHTS_IS_COLS_1_K2    + 1
    `define I_WEIGHTS_IS_CIN_LAST       `I_WEIGHTS_IS_CONFIG       + 1 
    `define I_WEIGHTS_IS_W_FIRST        `I_WEIGHTS_IS_CIN_LAST     + 1 
    `define I_WEIGHTS_IS_COL_VALID      `I_WEIGHTS_IS_W_FIRST      + 1 
    `define I_WEIGHTS_IS_SUM_START      `I_WEIGHTS_IS_COL_VALID    + 1 
    `define TUSER_WIDTH_WEIGHTS_OUT     `I_WEIGHTS_IS_SUM_START    + 1

    // PIPE TUSER INDICES
    `define I_IS_NOT_MAX      0
    `define I_KW2              `I_IS_LRELU        + 1
    `define I_SW_1             `I_KW2     + `BITS_KW2
    `define I_IS_CONFIG        `I_SW_1    + `BITS_SW 
    `define I_IS_TOP_BLOCK     `I_IS_CONFIG       + 1
    `define I_IS_BOTTOM_BLOCK  `I_IS_TOP_BLOCK    + 1
    `define I_IS_COLS_1_K2     `I_IS_BOTTOM_BLOCK + 1
    `define I_IS_CIN_LAST      `I_IS_COLS_1_K2    + 1
    `define I_IS_W_FIRST       `I_IS_CIN_LAST     + 1
    `define I_IS_COL_VALID     `I_IS_W_FIRST      + 1
    `define I_IS_SUM_START     `I_IS_COL_VALID    + 1

    `define I_CLR              `I_IS_BOTTOM_BLOCK + 1

    `define TUSER_WIDTH_MAXPOOL_IN      `BITS_KW2      + `I_KW2
    `define TUSER_WIDTH_LRELU_IN        `BITS_KW       + `I_CLR
    `define TUSER_CONV_DW_BASE          1 + `I_IS_BOTTOM_BLOCK 
    `define TUSER_CONV_DW_IN            `COLS   *`BITS_KW + `BITS_OUT_SHIFT + `BITS_MEMBERS + `TUSER_CONV_DW_BASE
    `define TUSER_WIDTH_LRELU_FMA_1_IN  1         + `I_IS_LRELU
    `define TUSER_WIDTH_CONV_IN         `I_IS_SUM_START     + 1


    `define TUSER_WIDTH_PIXELS        `I_IS_LRELU   + 1 
    `define TUSER_WIDTH_IM_SHIFT_IN   `I_SH_1 + `BITS_SH 
    `define TUSER_WIDTH_IM_SHIFT_OUT  `I_IS_LRELU + 1
    