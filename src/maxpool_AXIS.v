`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 07/12/2019 07:26:45 PM
// Design Name: Maxpool AXIS
// Module Name: maxpool_AXIS.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description:  AXI stream wrapper for maxpool block
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module maxpool_AXIS(
    aclk,
    aresetn,
    m_axis_tready,
    s_axis_tvalid,
    s_axis_tlast,
    max_mode,
    s_axis_tdata,

    m_axis_tvalid,
    s_axis_tready,
    m_axis_tdata,
    m_axis_tlast
    );

    // Parameters
    parameter DATA_WIDTH   = 16;
    parameter CONV_UNITS   = 8;
    parameter CONV_CORES   = 1;


    // IO definition
    input                               aresetn;     
    input                               aclk;      
    input                               max_mode;   // 0: note maxpool ; 1: maxpool  
    input                               m_axis_tready;    
    input                               s_axis_tvalid;   
    input                               s_axis_tlast; 
    input [(DATA_WIDTH*CONV_CORES)-1:0] s_axis_tdata; 
    
    
    output                             m_axis_tvalid;
    output                             s_axis_tready;
    output                             m_axis_tlast;
    output [DATA_WIDTH*CONV_CORES-1:0] m_axis_tdata;




    // DUT instantiation


    maxpool_block #(
        .DATA_WIDTH(DATA_WIDTH),
        .CONV_UNITS(CONV_UNITS),
        .CONV_CORES(CONV_CORES)
    )MAXPOOL_BLOCK(
        .clk(aclk),
        .rstn(aresetn),
        .r_rdy(m_axis_tready),
        .l_valid(s_axis_tvalid),
        .T_last_in(s_axis_tlast),
        .mode(max_mode),
        .d_in(s_axis_tdata),
        .r_valid(m_axis_tvalid),
        .l_rdy(s_axis_tready),
        .T_out(m_axis_tdata),
        .T_last_out(m_axis_tlast)
    );


endmodule