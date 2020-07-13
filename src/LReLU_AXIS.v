`include "system_parameters.v"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 14/12/2019 07:26:45 PM
// Design Name: LReLU AXIS
// Module Name: LReLU_AXIS.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: wrapper for LReLU_block in AXI stream format
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module LReLU_AXIS(
    aclk,
    aresetn,
    en,
    m_axis_tready,
    s_axis_tvalid,
    s_axis_tdata,
    s_axis_tlast,

    s_axis_tready,
    m_axis_tvalid,
    m_axis_tdata,
    m_axis_tlast
    );

    // parameter DATA_WIDTH  = 16;
    // parameter LReLU_UNITS  = 1; // not CONV_UNITS // for our design put this as 2 

    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    input                                 aclk;
    input                                 aresetn;
    input                                 en;
    input                                 m_axis_tready;
    input                                 s_axis_tvalid;
    input                                 s_axis_tlast;
    input [(`DATA_WIDTH * `LReLU_UNITS)-1:0] s_axis_tdata;

    output                                 s_axis_tready;
    output                                 m_axis_tvalid ;
    output                                 m_axis_tlast ;
    output [(`DATA_WIDTH * `LReLU_UNITS)-1:0] m_axis_tdata;


    // DUT instantiation
    LReLU_block #(
        .DATA_WIDTH(`DATA_WIDTH),
        .LReLU_UNITS(`LReLU_UNITS)
    ) DUT (
        .clk(aclk),
        .rstn(aresetn),
        .en(en),
        .r_rdy(m_axis_tready),
        .l_valid(s_axis_tvalid),
        .d_in(s_axis_tdata),
        .T_last_in(s_axis_tlast),
        .l_rdy(s_axis_tready),
        .r_valid(m_axis_tvalid),
        .d_out(m_axis_tdata),
        .T_last_out(m_axis_tlast)
    );


endmodule