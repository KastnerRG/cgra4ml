`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: Data switch test bench
// Module Name: data_switch_tb.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: Used to multiplex correct data to the inputs of the core
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module data_switch_tb();
    
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DATA_WIDTH = 16;
    parameter CONV_UNITS = 8;

    localparam IN_SIZE   = CONV_UNITS+2;

    parameter CLK_PERIOD = 10;
    

    ///////////////////////////////////// Wires and Register ////////////////////////////////////////////
    reg                            clk  = 0;
    reg [1:0]                      sel  = 0;
    reg [(DATA_WIDTH*IN_SIZE)-1:0] x_in = 0;

    wire [(DATA_WIDTH*CONV_UNITS)-1:0] x_out;

    ///////////////////////////////////// DUT Instantiations ////////////////////////////////////////////
    data_switch #(
        .DATA_WIDTH(DATA_WIDTH),
        .CONV_UNITS(CONV_UNITS)
    ) DUT (
        .sel(sel),
        .x_in(x_in),
        .x_out(x_out)
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
        x_in <= {16'd18688,16'd18560,16'd18432,16'd18176,16'd17920,16'd17664,16'd17408,16'd16896,16'd16384,16'd15360};
        @(posedge clk);
        sel <= 2'd1;
        @(posedge clk);
        sel <= 2'd2;
        @(posedge clk);
        sel <= 2'd3;
        @(posedge clk);
        x_in <= {16'd51456,16'd51328,16'd51200,16'd50944,16'd50688,16'd50432,16'd50176,16'd49664,16'd49152,16'd48128};
        sel <= 2'd0;
        @(posedge clk);
        sel <= 2'd1;
        @(posedge clk);
        sel <= 2'd2;
        @(posedge clk);
        sel <= 2'd3;
    end
endmodule