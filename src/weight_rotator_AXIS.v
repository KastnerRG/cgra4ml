`include "system_parameters.v"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: Weight rotator AXI stream
// Module Name: weight_rotator_AXIS.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: AXI stream wrapper for weight rotator to act as a standardalone AXI stream module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module weight_rotator_AXIS(
    aclk,
    aresetn,
    s_axis_tdata,
    s_axis_tvalid,
    m_axis_tready,
    write_depth,    // (K_size * CH_in +1{for bias line} -1) // give actual -1
    rotate_amount,  // (Width * BLKs -1) // give actual -1
    im_channels_in, // give actual -1
    im_width_in,    // give actual -1
    im_blocks_in,   // give actual -1
    conv_mode_in,   
    max_mode_in,        

    s_axis_tready,
    m_axis_tvalid,
    BIAS_out,
    im_channels_out,
    im_width_out,
    im_blocks_out,
    conv_mode_out,
    is_3x3,
    max_mode_out,
    m_axis_tdata
);


    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    
    input                               aclk;
    input                               aresetn;
    input [`BRAM_WIDTH-1:0]             s_axis_tdata;
    input                               s_axis_tvalid;
    input                               m_axis_tready;
    input [`ADDRS_WIDTH-1:0]            write_depth;
    input [`ROTATE_WIDTH-1:0]           rotate_amount;
    input [`CH_IN_COUNTER_WIDTH-1:0]    im_channels_in;
    input [`IM_WIDTH_COUNTER_WIDTH-1:0] im_width_in;
    input [`NUM_BLKS_COUNTER_WIDTH-1:0] im_blocks_in;
    input                               conv_mode_in;
    input                               max_mode_in;

    output                               s_axis_tready;
    output                               m_axis_tvalid;
    output [`BRAM_WIDTH-1:0]             m_axis_tdata;
    output [`BRAM_WIDTH-1:0]             BIAS_out;
    output [`CH_IN_COUNTER_WIDTH-1:0]    im_channels_out;
    output [`IM_WIDTH_COUNTER_WIDTH-1:0] im_width_out;
    output [`NUM_BLKS_COUNTER_WIDTH-1:0] im_blocks_out;
    output                               conv_mode_out;
    output                               is_3x3;
    output                               max_mode_out;

    /////////////////////////////////////  Instantiations ////////////////////////////////////////////
    
    weight_rotator #(
        .DATA_WIDTH(`DATA_WIDTH),
        .CONV_CORES(`CONV_CORES),
        .ADDRS_WIDTH(`ADDRS_WIDTH),
        .ROTATE_WIDTH(`ROTATE_WIDTH),
        .FIFO_DEPTH(`FIFO_DEPTH),
        .FIFO_COUNTER_WIDTH(`FIFO_COUNTER_WIDTH),
        .RAM_LATENCY(`RAM_LATENCY),
        .CH_IN_COUNTER_WIDTH(`CH_IN_COUNTER_WIDTH),
        .NUM_BLKS_COUNTER_WIDTH(`NUM_BLKS_COUNTER_WIDTH),
        .IM_WIDTH_COUNTER_WIDTH(`IM_WIDTH_COUNTER_WIDTH)
    ) WEIGHT_ROTATOR_INST(
        .clk(aclk),
        .rstn(aresetn),
        .din(s_axis_tdata),
        .l_valid(s_axis_tvalid),
        .r_rdy(m_axis_tready),
        .write_depth(write_depth),
        .rotate_amount(rotate_amount),
        .im_channels_in(im_channels_in),
        .im_width_in(im_width_in),
        .im_blocks_in(im_blocks_in),
        .conv_mode_in(conv_mode_in),
        .max_mode_in(max_mode_in),
        .l_rdy(s_axis_tready),
        .r_valid(m_axis_tvalid),
        .BIAS_out(BIAS_out),
        .im_channels_out(im_channels_out),
        .im_width_out(im_width_out),
        .im_blocks_out(im_blocks_out),
        .conv_mode_out(conv_mode_out),
        .is_3x3(is_3x3),
        .max_mode_out(max_mode_out),
        .dout(m_axis_tdata)
    );

endmodule