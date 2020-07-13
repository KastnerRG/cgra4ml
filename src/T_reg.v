`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: T registers
// Module Name: T_reg.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: A special register that can be configured as a shift register and a storing register
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module T_reg(
    clk,
    en,
    sel,    // sel=0 : shifting    sel=1 : storing
    d_in_1, // for shifting
    d_in_2, // for storing
    
    d_out
);
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DATA_WIDTH = 16;

    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    input                  clk;
    input                  en;
    input                  sel;
    input [DATA_WIDTH-1:0] d_in_1;
    input [DATA_WIDTH-1:0] d_in_2;

    output reg [DATA_WIDTH-1:0] d_out = 0;

    ////////////////////////////////////// Wires and registers /////////////////////////////////////////
    wire [DATA_WIDTH-1:0] temp_data;

    ///////////////////////////////////////// Assignments ////////////////////////////////////////////
    assign temp_data = sel?d_in_2:d_in_1;
    
    //////////////////////////////////////////// Code /////////////////////////////////////////////////
    always@(posedge clk)
    begin
        if(en) d_out <= temp_data;    
        else   d_out <= d_out;
    end

endmodule