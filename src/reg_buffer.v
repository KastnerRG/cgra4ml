`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: Register buffer
// Module Name: reg_buffer.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: Delays a signal by the given parameter.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module reg_buffer(
    clk,
    rstn,
    d_in,
    en,

    d_out
    );
    
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DELAY  = 2;

    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    input  clk;
    input  rstn;
    input  d_in;
    input  en;

    output d_out;



    ////////////////////////////////////// Wires and registers /////////////////////////////////////////
    reg [DELAY-1:0] temp_reg = 0;
    wire [DELAY-1:0] temp_wire;


    ///////////////////////////////////////// Assignments ////////////////////////////////////////////
    assign temp_wire = {temp_reg[DELAY-2:0],d_in};
    assign d_out     = temp_reg[DELAY-1];

    always@(posedge clk, negedge rstn)
    begin
        if (~rstn) begin
            temp_reg <= 0;
        end else begin
            if (en) begin
                temp_reg <= temp_wire;
            end else begin
                temp_reg <= temp_reg;
            end
        end
    end



endmodule