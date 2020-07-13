`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: Register buffer
// Module Name: reg_array_buffer.v
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

module reg_array_buffer(
    clk,
    rstn,
    d_in,
    en,

    d_out
    );
    
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DELAY      = 2;
    parameter DATA_WIDTH = 2;

    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    input  clk;
    input  rstn;
    input  [DATA_WIDTH-1:0] d_in;
    input  en;

    output [DATA_WIDTH-1:0] d_out;

    genvar i;
    for (i = 0; i<DATA_WIDTH; i= i+1) begin: REG_BUFF_GEN
        reg_buffer #(
            .DELAY(DELAY)
        )dv_buffer(
            .clk(clk),
            .rstn(rstn),// maybe use a different signal to reset ();
            .d_in(d_in[i]),
            .en(en),
            .d_out(d_out[i])
    );
    end


endmodule