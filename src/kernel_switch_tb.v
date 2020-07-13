`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: kernel switch test bench
// Module Name: kernel_switch_tb.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: Used to multiplex correct kernel to the inputs of the core
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module kernel_switch_tb();
    
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DATA_WIDTH = 16;

    parameter CLK_PERIOD = 10;
    

    ///////////////////////////////////// Wires and Register ////////////////////////////////////////////
    reg                  clk  = 0;
    reg [1:0]            sel  = 0;
    reg [DATA_WIDTH-1:0] K1   = 0;
    reg [DATA_WIDTH-1:0] K2   = 0;
    reg [DATA_WIDTH-1:0] K3   = 0;
    reg [DATA_WIDTH-1:0] K4   = 0;
    reg [DATA_WIDTH-1:0] K5   = 0;
    reg [DATA_WIDTH-1:0] K6   = 0;
    reg [DATA_WIDTH-1:0] K7   = 0;
    reg [DATA_WIDTH-1:0] K8   = 0;
    reg [DATA_WIDTH-1:0] K9   = 0;
    reg [DATA_WIDTH-1:0] bias = 0;

    wire [DATA_WIDTH-1:0] L_kernel;
    wire [DATA_WIDTH-1:0] M_kernel;
    wire [DATA_WIDTH-1:0] R_kernel;

    ///////////////////////////////////// DUT Instantiations ////////////////////////////////////////////
    kernel_switch #(
        .DATA_WIDTH(DATA_WIDTH)
    ) DUT (
        .sel(sel),
        .K1(K1),
        .K2(K2),
        .K3(K3),
        .K4(K4),
        .K5(K5),
        .K6(K6),
        .K7(K7),
        .K8(K8),
        .K9(K9),
        .bias(bias),
        .L_kernel(L_kernel),
        .M_kernel(M_kernel),
        .R_kernel(R_kernel)
    );

    ///////////////////////////////////////////// Code ////////////////////////////////////////////
    always
    begin
        #(CLK_PERIOD/2);
        clk <= ~clk;
    end
    initial
    begin
        @(posedge clk);
        repeat(4);
            K1   <= 16'd15360;
            K2   <= 16'd16384;
            K3   <= 16'd16896;
            K4   <= 16'd17408;
            K5   <= 16'd17664;
            K6   <= 16'd17920;
            K7   <= 16'd18176;
            K8   <= 16'd18432;
            K9   <= 16'd18560;
            bias <= 16'd18688;
        @(posedge clk);
        sel <= 2'd1;
        @(posedge clk);
        sel <= 2'd2;
        @(posedge clk);
        sel <= 2'd3;
        // @(posedge clk);
        // x_in <= {16'd51456,16'd51328,16'd51200,16'd50944,16'd50688,16'd50432,16'd50176,16'd49664,16'd49152,16'd48128};
        // sel <= 2'd0;
        // @(posedge clk);
        // sel <= 2'd1;
        // @(posedge clk);
        // sel <= 2'd2;
        // @(posedge clk);
        // sel <= 2'd3;
    end
endmodule