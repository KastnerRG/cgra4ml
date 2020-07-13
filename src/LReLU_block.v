`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 14/12/2019 10:59:45 AM
// Design Name: Leaky Relu unit
// Module Name: LReLU_block.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: AXI steam leaky relu module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module LReLU_block(
    clk,
    rstn,
    en,
    r_rdy,
    l_valid,
    d_in,
    T_last_in,

    l_rdy,
    r_valid,
    d_out,
    T_last_out
    );
    
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DATA_WIDTH  = 16;
    parameter LReLU_UNITS  = 1; // not CONV_UNITS

    localparam neg_COEF = 16'd11878;  // 0.1 
    localparam pos_COEF = 16'd15360;  // 1 

    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    input                  clk;
    input                  rstn;
    input                  en;
    input                  r_rdy;
    input                  l_valid;
    input                  T_last_in;
    input [(DATA_WIDTH * LReLU_UNITS)-1:0] d_in;

    output                  l_rdy;
    output reg              r_valid = 0;
    output reg              T_last_out = 0;
    output [(DATA_WIDTH * LReLU_UNITS)-1:0] d_out;

    
    ////////////////////////////////////// Wires and registers //////////////////////////////////////
    wire [DATA_WIDTH-1:0] coef [0:LReLU_UNITS-1]; // UN|..|U3|U2|U1|U0

    wire [DATA_WIDTH-1:0] d_in_array [0:LReLU_UNITS-1];  // UN|..|U3|U2|U1|U0
    wire [DATA_WIDTH-1:0] d_out_array [0:LReLU_UNITS-1]; // UN|..|U3|U2|U1|U0
    
    wire LReLU_en;
    ///////////////////////////////////////// Assignments ///////////////////////////////////////////
    genvar i;        
    generate        
        for (i = 0; i < LReLU_UNITS ; i = i+1) begin : unroll
            assign d_in_array[i] = d_in[(DATA_WIDTH*(i+1))-1:DATA_WIDTH * i];    
            assign d_out[(DATA_WIDTH*(i+1))-1:DATA_WIDTH*i] = d_out_array[i];
            assign coef[i] = en?((d_in_array[i][DATA_WIDTH-1]) ? neg_COEF : pos_COEF):pos_COEF; // Changing coefficient of the multiplier

            // Instantiating the Multiplier units
            floating_point_0 LReLU_inst (
                .aclk(clk),                       // input wire aclk
                .aclken(LReLU_en),                // input wire aclken
                .aresetn(rstn),                   // input wire aresetn
                .s_axis_a_tvalid(1'b1),          // input wire s_axis_a_tvalid
                .s_axis_a_tdata(d_in_array[i]),          // input wire [15 : 0] s_axis_a_tdata
                .s_axis_b_tvalid(1'b1),          // input wire s_axis_b_tvalid
                .s_axis_b_tdata(coef[i]),            // input wire [15 : 0] s_axis_b_tdata
                // .m_axis_result_tvalid(L_mul_dv),  // output wire m_axis_result_tvalid
                .m_axis_result_tdata(d_out_array[i])       // output wire [15 : 0] m_axis_result_tdata
            );
        end    
    endgenerate 
    
    
    
    assign LReLU_en = l_valid & r_rdy;
    assign l_rdy    = r_rdy;


    ///////////////////////////////////////////// Code //////////////////////////////////////////////
    
    // r_valid handler
    always @(posedge clk,negedge rstn) begin
        if (~rstn) begin
            r_valid    <= 0;
            T_last_out <= 0;
        end else begin
            if (r_rdy) begin
                r_valid    <= l_valid;
                T_last_out <= T_last_in;
            end else begin
                r_valid    <= r_valid;
                T_last_out <= T_last_out;
            end
        end
    end





endmodule