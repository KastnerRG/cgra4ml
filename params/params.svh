    `include "params_input.svh"

    `define RAM_EDGES_DEPTH    `IM_CIN_MAX * `IM_COLS_MAX * (`IM_ROWS_MAX/`ROWS-1)  // should be optimized
    `define BITS_KW2  $clog2((`KW_MAX+1)/2)
    `define BITS_SW   $clog2(`SW_MAX)
    
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
        logic                 is_w_first_clk;
        logic                 is_col_valid;
        logic                 is_sum_start;
        logic                 is_w_first_kw2;
        logic                 is_w_last;
    } tuser_st;
    `endif
    `endif
    `define TUSER_WIDTH `BITS_KW2 + `BITS_SW + 13