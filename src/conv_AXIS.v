`include "system_parameters.v"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 07/12/2019 07:26:45 PM
// Design Name: Convolution block AXIS
// Module Name: conv_AXIS.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: AXI stream wrapper for conv_block module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module conv_AXIS(
    aresetn,
    aclk,
    conv_mode,
    max_mode,
    s_axis_tdata_x_in,
    s_axis_tdata_kernels,
    m_axis_tready,
    s_axis_tvalid,
    ch_in,
    im_width,
    num_blocks,
    s_axis_tdata_bias,

    s_axis_tready,
    m_axis_tvalid,
    conv_finished,
    m_axis_tdata,
    max_mode_out,
    m_axis_tlast
);

    //////////////////////////////////////// Parameters //////////////////////////////////////////
    // parameter DATA_WIDTH = 16;
    // parameter CONV_UNITS = 8; // convolution units in each conv core
    // parameter CONV_PAIRS = 1; // pairs of convolutional cores

    // parameter CONV_CORES = 2*CONV_PAIRS; // actual convoltuion cores

    //////////////////////////////////////// Port declarations //////////////////////////////////////////

    input                                       aresetn;      
    input                                       aclk;       
    input                                       conv_mode;              // conv mode 0: 3x3 ; 1: 1x1 
    input                                       max_mode;
    input                                       m_axis_tready;      
    input                                       s_axis_tvalid;      
    input [`CH_IN_COUNTER_WIDTH-1:0]            ch_in;                  // = 32'd3; 
    input [`IM_WIDTH_COUNTER_WIDTH-1:0]         im_width;               // = 32'd384;
    input [`NUM_BLKS_COUNTER_WIDTH-1:0]         num_blocks;             // = 32'd32;
    input [(`CONV_CORES*`DATA_WIDTH*3)-1:0]       s_axis_tdata_bias ;     //   biases {core n [K3|K2|K1]} , ..... , {core 2 [K3|K2|K1]} , {core 1 [K3|K2|K1]}
    input [(2 * `DATA_WIDTH*(`CONV_UNITS+2))-1:0] s_axis_tdata_x_in;      //   {core type2 [R10|R9|R8|R7|R6|R5|R4|R3|R2|R1]} , {core type1 [R10|R9|R8|R7|R6|R5|R4|R3|R2|R1]}
    input [(`CONV_CORES*`DATA_WIDTH*9)-1:0]       s_axis_tdata_kernels;   //   { core n [K9|K8|K7|K6|K5|K4|K3|K2|K1]} , .... , { core 1 [K9|K8|K7|K6|K5|K4|K3|K2|K1]}

    
    output                                   m_axis_tvalid;
    output                                   s_axis_tready;
    output                                   conv_finished;
    output                                   m_axis_tlast;
    output                                   max_mode_out;
    output [(`DATA_WIDTH * `CONV_CORES)-1:0] m_axis_tdata;          // {core n T_out} , ..... , {core 1 T_out}
    
    
    
    //////////////////////////////////////// Instantiation //////////////////////////////////////////



    conv_block #(
        .DATA_WIDTH(`DATA_WIDTH),
        .CONV_UNITS(`CONV_UNITS),
        .CONV_PAIRS(`CONV_PAIRS)
    )CONV_BLOCK_DUT(
        .rstn(aresetn),
        .clk(aclk),
        .conv_mode(conv_mode),
        .max_mode(max_mode),
        .X_IN(s_axis_tdata_x_in),
        .KERNEL(s_axis_tdata_kernels),
        .r_rdy(m_axis_tready),
        .l_valid(s_axis_tvalid),
        .ch_in(ch_in),
        .im_width(im_width),
        .num_blocks(num_blocks),
        .BIAS(s_axis_tdata_bias),
        .l_rdy(s_axis_tready),
        .r_valid(m_axis_tvalid),
        .finished(conv_finished),
        .T_out(m_axis_tdata),
        .max_mode_out(max_mode_out),
        .T_last(m_axis_tlast)
    );



endmodule