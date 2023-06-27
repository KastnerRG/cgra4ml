
    // Written from param_tests.py

    `define ROWS                8                 	// PE rows, constrained by resources
    `define COLS                24                 	// PE cols, constrained by resources
    `define X_BITS              8               	// Bits per word in input
    `define K_BITS              8               	// Bits per word in input
    `define Y_BITS              32               	// Bits per word in output of conv

    `define KH_MAX              11               	// max of kernel height, across layers
    `define KW_MAX              11               	// max of kernel width, across layers
    `define XH_MAX              32               	// max of input image height, across layers
    `define XW_MAX              32               	// max of input image width, across layers
    `define XN_MAX              4               	// max of input batch size, across layers
    `define CI_MAX              1024               	// max of input channels, across layers
    `define CONFIG_BEATS        1         	// constant, for now
    `define RAM_WEIGHTS_DEPTH  2049   	// CONFIG_BEATS + max(KW * CI), across layers
    `define RAM_EDGES_DEPTH     672      	// max (KW * CI * XW), across layers when KW != 1

    `define DELAY_ACC    1                               	// constant, for now
    `define DELAY_MUL    2                               	// constant, for now 
    `define DELAY_W_RAM  2                               	// constant, for now 

    `define S_WEIGHTS_WIDTH_LF  64              	// constant (64), for now
    `define S_PIXELS_WIDTH_LF   64              	// constant (64), for now
    `define M_OUTPUT_WIDTH_LF   64             	// constant (64), for now
    