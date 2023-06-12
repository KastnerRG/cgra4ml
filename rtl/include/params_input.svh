
    // Written from param_tests.py

    `define ROWS                4                 	// PE rows, constrained by resources
    `define COLS                24                 	// PE cols, constrained by resources
    `define WORD_WIDTH          8               	// Bits per word in input
    `define WORD_WIDTH_ACC      32                       	// Bits per word in output of conv

    `define KH_MAX              3               	// max of kernel height, across layers
    `define KW_MAX              3               	// max of kernel width, across layers
    `define SH_MAX              2               	// max of stride height, across layers
    `define SW_MAX              2               	// max of stride width, across layers
    `define XH_MAX              32               	// max of input image height, across layers
    `define XW_MAX              32               	// max of input image width, across layers
    `define XN_MAX              4               	// max of input batch size, across layers
    `define CI_MAX              1024               	// max of input channels, across layers
    `define CONFIG_BEATS        1         	// constant, for now
    `define BRAM_WEIGHTS_DEPTH  2049   	// CONFIG_BEATS + max(KW * CI), across layers
    `define RAM_EDGES_DEPTH     672      	// max (KW * CI * XW), across layers when KW != 1

    `define LATENCY_ACCUMULATOR   1                      	// constant, for now
    `define LATENCY_MULTIPLIER    2                      	// constant, for now 
    `define LATENCY_BRAM          2                      	// constant, for now 

    `define S_WEIGHTS_WIDTH_LF  64              	// constant (64), for now
    `define S_PIXELS_WIDTH_LF   64              	// constant (64), for now
    `define M_OUTPUT_WIDTH_LF   64                       	// constant (64), for now
    