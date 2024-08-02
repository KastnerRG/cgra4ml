
// Written from Hardware.export()
                    
`define OR_NEGEDGE(RSTN)    or negedge RSTN

`define ROWS                7           // PE rows, constrained by resources
`define COLS                96          // PE cols, constrained by resources
`define X_BITS              4           // Bits per word in input
`define K_BITS              4           // Bits per word in input
`define Y_BITS              20          // Bits per word in output of conv
`define Y_OUT_BITS          32          // Padded bits per word in output of conv

`define KH_MAX              9           // max of kernel height, across layers
`define KW_MAX              9           // max of kernel width, across layers
`define XH_MAX              512         // max of input image height, across layers
`define XW_MAX              512         // max of input image width, across layers
`define XN_MAX              64          // max of input batch size, across layers
`define CI_MAX              512         // max of input channels, across layers
`define MAX_N_BUNDLES       64          // max number of bundles in a network
`define CONFIG_BEATS        0           // constant, for now
`define RAM_WEIGHTS_DEPTH   512         // CONFIG_BEATS + max(KW * CI), across layers
`define RAM_EDGES_DEPTH     3584        // max (KW * CI * XW), across layers when KW != 1
`define W_BPT               32          // Width of output integer denoting bytes per transfer

`define DELAY_MUL           3            // constant, for now 
`define DELAY_W_RAM         2            // constant, for now 

`define AXI_WIDTH           128       
`define HEADER_WIDTH        64        
`define AXI_MAX_BURST_LEN   16        
`define CONFIG_BASEADDR     40'hB0000000  
