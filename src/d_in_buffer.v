`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: Data in buffer
// Module Name: d_in_buffer.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: A module to accept and hold the data to process
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module d_in_buffer(
    clk,
    rstn,
    buff_en,
    x_in,

    x_out
);
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DATA_WIDTH = 16;
    parameter CONV_UNITS = 8;

    localparam IN_SIZE   = CONV_UNITS+2;
    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    input                  clk;
    input                  buff_en;
    input                  rstn;
    input [(DATA_WIDTH*IN_SIZE)-1:0] x_in;

    output reg [(DATA_WIDTH*IN_SIZE)-1:0] x_out;

    //////////////////////////////////////////// Code /////////////////////////////////////////////////
    always@(posedge clk, negedge rstn)
    begin
        if (~rstn) begin
            x_out <= 0;
        end else begin
            if (buff_en) begin
                x_out <= x_in;
            end else begin
                x_out <= x_out;
            end
        end
    end

endmodule