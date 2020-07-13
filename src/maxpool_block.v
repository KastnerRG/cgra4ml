`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 07/12/2019 07:26:45 PM
// Design Name: maxpool_block
// Module Name: maxpool_block.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: A wrapper for the maxpool units + controller. Can be used as a seperate AXIS module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module maxpool_block(
    clk,
    rstn,
    r_rdy,
    l_valid,
    T_last_in,
    mode,
    d_in,

    r_valid,
    l_rdy,
    T_out,
    T_last_out
);

    ////////////////////// Parameters //////////////////////////
    parameter DATA_WIDTH   = 16;
    parameter CONV_UNITS   = 8;
    parameter CONV_CORES   = 1;


    //////////////////// IO definition /////////////////////////
    input                                   rstn;     
    input                                   clk;      
    input                                   mode;     
    input                                   r_rdy;    
    input                                   l_valid;   
    input                                   T_last_in; 
    input [(DATA_WIDTH*CONV_CORES)-1:0]     d_in; 
    
    
    output                  r_valid;
    output                  l_rdy;
    output                  T_last_out;
    output [DATA_WIDTH*CONV_CORES-1:0] T_out;

    wire [1:0] sel;
    wire       comp_en;
    wire       S_buff_en;
    wire       G_en;


    // Instantiations


    controller_maxpool #(
        .DATA_WIDTH(DATA_WIDTH),
        .CONV_UNITS(CONV_UNITS)
    )CONTROLLER_MAX(
        .clk(clk),
        .rstn(rstn),
        .r_rdy(r_rdy),
        .l_valid(l_valid),
        .T_last_in(T_last_in),
        .mode(mode),
        .comp_en(comp_en),
        .S_buff_en(S_buff_en),
        .G_en(G_en),
        .sel(sel),
        .r_valid(r_valid),
        .l_rdy(l_rdy),
        .T_last_out(T_last_out)
    );



    genvar i;
    generate
        for (i=0; i<CONV_CORES; i=i+1) begin : max_pool_unit_population
            maxpool_unit #(
                .DATA_WIDTH(DATA_WIDTH),
                .CONV_UNITS(CONV_UNITS)
            )MAXPOOL_UNIT(
                .clk(clk),
                .rstn(rstn),
                .comp_en(comp_en),
                .S_buff_en(S_buff_en),
                .G_en(G_en),
                .sel(sel),
                .d_in(d_in[(DATA_WIDTH*(i+1))-1:DATA_WIDTH*i]),
                .T_out(T_out[(DATA_WIDTH*(i+1))-1:DATA_WIDTH*i])
            );
        end
    endgenerate
    




endmodule