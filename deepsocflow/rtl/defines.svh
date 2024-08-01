    `include "config_hw.svh"

    `define BITS_KW2  $clog2((`KW_MAX+1)/2)
    
    `ifndef VERILOG
    `ifndef STRUCT 
    `define STRUCT
    typedef struct packed {
        logic [`BITS_KW2-1:0] kw2 ;
        logic                 is_config;
        logic                 is_cin_last;
        logic                 is_w_first_clk;
        logic                 is_w_first_kw2;
        logic                 is_w_last;
    } tuser_st;
    `endif
    `endif
    `define TUSER_WIDTH `BITS_KW2 + 5