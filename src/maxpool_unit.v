`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 14/12/2019 10:59:45 AM
// Design Name: Max pool unit
// Module Name: maxpool_unit.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: Unit for performing max pool function
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module maxpool_unit(
    clk,
    rstn,
    comp_en,
    S_buff_en,
    G_en,
    sel,
    d_in,

    T_out
    );
    
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DATA_WIDTH  = 16;
    parameter CONV_UNITS  = 8;     // Convolution units in a core
  
    localparam OUT_SIZE = CONV_UNITS/2;

    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    input                  clk;
    input                  rstn;
    input                  comp_en;
    input                  S_buff_en;
    input                  G_en;
    input [1:0]            sel;
    input [DATA_WIDTH-1:0] d_in;

    output [DATA_WIDTH-1:0] T_out;

    
    ////////////////////////////////////// Wires and registers //////////////////////////////////////
    reg [DATA_WIDTH-1:0] comp_B;
    reg [DATA_WIDTH-1:0] T = 0;
    
    wire [DATA_WIDTH-1:0] G_wire;
    wire [DATA_WIDTH-1:0] S_final;

    ///////////////////////////////////////// Assignments ///////////////////////////////////////////
    // assign T_out = mode ? G_wire : d_in;
    assign T_out = G_wire;

    ///////////////////////////////////////////// Instantiation /////////////////////////////////////
    
    // Comparator // without latency
    // comparator #(
    //     .DATA_WIDTH(DATA_WIDTH)
    // ) COMPARATOR (
    //     .clk(clk),
    //     .rstn(rstn),
    //     .G_en(G_en),
    //     .in_A(d_in),
    //     .in_B(comp_B),
    //     .G_out(G_wire)
    // );

    // Comparator
    comparator #(  // with a latency
        .DATA_WIDTH(DATA_WIDTH)
    ) COMPARATOR (
        .clk(clk),
        .rstn(rstn),
        .G_en(G_en),
        .comp_en(comp_en),
        .in_A(d_in),
        .in_B(comp_B),
        .G_out(G_wire)
    );


    // S_buffer
    reg_array_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .DELAY(OUT_SIZE-1)
    ) S_BUFFER (
        .clk(clk),
        .rstn(rstn),
        .d_in(G_wire),
        .en(S_buff_en),
        .d_out(S_final)
    );

    ///////////////////////////////////////////// Code //////////////////////////////////////////////

    // Main Mux
    // always @(*) 
    // begin
    //     case (sel)
    //         2'd0   : comp_B <= 0;       // Passing 0. Useful if you are doing ReLU. Not LReLU. Not adding this to the current design
    //         2'd1   : comp_B <= d_in;    // Replaces T register
    //         2'd2   : comp_B <= S_final; // Compares with the last shift reg
    //         2'd3   : comp_B <= G_wire;  // Compare with the output
    //         default: comp_B <= 0; 
    //     endcase    
    // end

    always @(*) 
    begin
        case (sel)
            2'd0   : comp_B <= d_in;    // Replaces T register    
            2'd1   : comp_B <= S_final; // Compares with the last shift reg
            2'd2   : comp_B <= G_wire;  // Compare with the output
            2'd3   : comp_B <= 0;       // Passing 0. Useful if you are doing ReLU. Not LReLU. Not adding this to the current design
            default: comp_B <= 0; 
        endcase    
    end

endmodule