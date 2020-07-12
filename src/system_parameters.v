/*
Contains the parameters of the system
*/

// Main parameters

`define CONV_UNITS            8
`define CONV_PAIRS            1
`define CONV_CORES            2
`define RAM_LATENCY           2
`define LReLU_UNITS           2

// Register Widths

`define DATA_WIDTH             16
`define CH_IN_COUNTER_WIDTH    10
`define NUM_BLKS_COUNTER_WIDTH 5
`define IM_WIDTH_COUNTER_WIDTH 9
`define ADDRS_WIDTH            12
`define ROTATE_WIDTH           14
`define FIFO_DEPTH             4
`define BRAM_WIDTH             96
`define FIFO_COUNTER_WIDTH     2
`define c_SHIFT_COUNTER_WIDTH  3
`define PARAM_WIRE_WIDTH       53

// DMA Widths

`define WEIGHTS_DMA_WIDTH      128
`define IMAGE_DMA_WIDTH        256
`define OUTPUT_DMA_WIDTH       32
`define Nb                     32

// Output Pipe References

`define p_COUNT_3x3_ref       9
`define p_COUNT_3x3_max_ref   4
`define p_COUNT_1x1_ref       29
`define p_COUNT_1x1_max_ref   14
