
    // Written from param_tests.py

    `define ROWS     4  
    `define COLS     24
    `define BRAM_WEIGHTS_DEPTH  1024
    `define RAM_EDGES_DEPTH     256

    `define WORD_WIDTH          8         
    `define WORD_WIDTH_ACC      32    
    `define KH_MAX              3            
    `define KW_MAX              3            
    `define SH_MAX              2            
    `define SW_MAX              2            
    `define IM_ROWS_MAX         256
    `define IM_CIN_MAX          1024      
    `define IM_COLS_MAX         384     
    `define XN_MAX              8     
    `define CONFIG_BEATS        1     

    `define LATENCY_ACCUMULATOR   1    
    `define LATENCY_MULTIPLIER    1     
    `define LATENCY_BRAM          2     

    `define S_WEIGHTS_WIDTH_LF  64
    `define S_PIXELS_WIDTH_LF   64
    `define M_OUTPUT_WIDTH_LF   64
    