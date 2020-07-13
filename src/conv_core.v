`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: Convolution core
// Module Name: conv_core.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: A core containing multiple convolution units to process parallel image rows
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module conv_core(
    clk,
    rstn,
    x_in,
    dv_in,
    MA_en,
    kernel_sel,
    A_sel,
    T_sel,
    T_en,
    K1,
    K2,
    K3,
    K4,
    K5,
    K6,
    K7,
    K8,
    K9,
    bias,
    buff_en,

    T_out
    );
    
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DATA_WIDTH  = 16;
    parameter TOTAL_UNITS = 8;

    ////////////////////////////////////// Port declaration ////////////////////////////////////////////

    input                                clk;
    input                                rstn;
    input                                MA_en;
    input                                T_en;
    input                                dv_in;
    input                                T_sel;
    input                                buff_en;
    input [1:0]                          A_sel;
    input [1:0]                          kernel_sel;
    input [DATA_WIDTH-1:0]               K1;
    input [DATA_WIDTH-1:0]               K2;
    input [DATA_WIDTH-1:0]               K3;
    input [DATA_WIDTH-1:0]               K4;
    input [DATA_WIDTH-1:0]               K5;
    input [DATA_WIDTH-1:0]               K6;
    input [DATA_WIDTH-1:0]               K7;
    input [DATA_WIDTH-1:0]               K8;
    input [DATA_WIDTH-1:0]               K9;
    input [(DATA_WIDTH*3)-1:0]           bias;
    input [(DATA_WIDTH*TOTAL_UNITS)-1:0] x_in;

    output [DATA_WIDTH-1:0] T_out;


    ////////////////////////////////////// Wires and registers /////////////////////////////////////////
    wire [DATA_WIDTH-1:0] L_kernel;
    wire [DATA_WIDTH-1:0] M_kernel;
    wire [DATA_WIDTH-1:0] R_kernel;

    wire [(DATA_WIDTH*(TOTAL_UNITS+1))-1:0] T1_wire;
    wire [(DATA_WIDTH*(TOTAL_UNITS+1))-1:0] T2_wire;
    wire [(DATA_WIDTH*(TOTAL_UNITS+1))-1:0] T3_wire;

    wire [DATA_WIDTH-1:0]    buff_K1;
    wire [DATA_WIDTH-1:0]    buff_K2;
    wire [DATA_WIDTH-1:0]    buff_K3;
    wire [DATA_WIDTH-1:0]    buff_K4;
    wire [DATA_WIDTH-1:0]    buff_K5;
    wire [DATA_WIDTH-1:0]    buff_K6;
    wire [DATA_WIDTH-1:0]    buff_K7;
    wire [DATA_WIDTH-1:0]    buff_K8;
    wire [DATA_WIDTH-1:0]    buff_K9;
    // wire [DATA_WIDTH-1:0]    buff_bias;

    // wire [(DATA_WIDTH*10)-1:0] x_in_k;
    // wire [(DATA_WIDTH*10)-1:0] x_out_k;


    ///////////////////////////////////////// Assignments ////////////////////////////////////////////
    assign T_out                                                              = T1_wire[DATA_WIDTH-1:0];

    assign T1_wire[(DATA_WIDTH*(TOTAL_UNITS+1))-1:(DATA_WIDTH*(TOTAL_UNITS))] = T2_wire[DATA_WIDTH-1:0];
    assign T2_wire[(DATA_WIDTH*(TOTAL_UNITS+1))-1:(DATA_WIDTH*(TOTAL_UNITS))] = T3_wire[DATA_WIDTH-1:0];

    assign T3_wire[(DATA_WIDTH*(TOTAL_UNITS+1))-1:(DATA_WIDTH*(TOTAL_UNITS))] = 0;
   
    //////////////////////////////////////// Instantiations //////////////////////////////////////////
    // Kernel switch
    kernel_switch #(
        .DATA_WIDTH(DATA_WIDTH)
    )KERNEL_SWITCH(
        .sel(kernel_sel),
        .K1(buff_K1),
        .K2(buff_K2),
        .K3(buff_K3),
        .K4(buff_K4),
        .K5(buff_K5),
        .K6(buff_K6),
        .K7(buff_K7),
        .K8(buff_K8),
        .K9(buff_K9),
        .bias(bias), // bias not bufferd hold throughout the convolution
        .L_kernel(L_kernel),
        .M_kernel(M_kernel),
        .R_kernel(R_kernel)
    );


    kernel_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .UNITS(9)
    )KERNEL_BUFFER(
        .clk(clk),
        .rstn(rstn),
        .buff_en(buff_en),
        .x_in({K9,K8,K7,K6,K5,K4,K3,K2,K1}),
        .x_out({buff_K9,buff_K8,buff_K7,buff_K6,buff_K5,buff_K4,buff_K3,buff_K2,buff_K1})
    );


    
    // Conv units
    genvar i;
    generate
        for (i=0; i<TOTAL_UNITS; i=i+1) begin : generate_units // <-- example block name
            conv_unit #(
                .DATA_WIDTH(DATA_WIDTH)
            ) CONV_UNITS (
                .clk(clk),
                .rstn(rstn),
                .MA_en(MA_en),
                .T_en(T_en),
                .A_sel(A_sel),
                .T_sel(T_sel),
                .dv_in(dv_in),
                .bias(bias[31:16]), // used only in 3x3 convolution
                .d_in(x_in[(DATA_WIDTH*(i+1))-1:DATA_WIDTH*i]),
                .L_k_in(L_kernel),
                .M_k_in(M_kernel),
                .R_k_in(R_kernel),
                .T1_in(T1_wire[(DATA_WIDTH*(i+2))-1:DATA_WIDTH*(i+1)]),
                .T2_in(T2_wire[(DATA_WIDTH*(i+2))-1:DATA_WIDTH*(i+1)]),
                .T3_in(T3_wire[(DATA_WIDTH*(i+2))-1:DATA_WIDTH*(i+1)]),
                .T1_out(T1_wire[(DATA_WIDTH*(i+1))-1:DATA_WIDTH*i]),
                .T2_out(T2_wire[(DATA_WIDTH*(i+1))-1:DATA_WIDTH*i]),
                .T3_out(T3_wire[(DATA_WIDTH*(i+1))-1:DATA_WIDTH*i])
            );
        end 
    endgenerate


endmodule