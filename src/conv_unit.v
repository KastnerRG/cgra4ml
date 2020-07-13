`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: convolution unit
// Module Name: conv_unit.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: A convolution unit capable of performing a single convolution
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module conv_unit(
    clk,
    rstn,
    MA_en,
    // T1_en,
    // T2_en,
    // T3_en,
    T_en,
    A_sel,
    T_sel,
    dv_in,
    bias,
    d_in,
    L_k_in,
    M_k_in,
    R_k_in,
    T1_in,
    T2_in,
    T3_in,

    T1_out,
    T2_out,
    T3_out
    );

    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DATA_WIDTH = 16;

    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    input                  clk;
    input                  rstn;
    input                  MA_en;
    // input                  T1_en;
    // input                  T2_en;
    // input                  T3_en;
    input                  T_en;
    input                  T_sel;
    input                  dv_in;
    input [1:0]            A_sel;
    input [DATA_WIDTH-1:0] bias;
    input [DATA_WIDTH-1:0] d_in;
    input [DATA_WIDTH-1:0] L_k_in;
    input [DATA_WIDTH-1:0] M_k_in;
    input [DATA_WIDTH-1:0] R_k_in;
    input [DATA_WIDTH-1:0] T1_in;
    input [DATA_WIDTH-1:0] T2_in;
    input [DATA_WIDTH-1:0] T3_in;

    output [DATA_WIDTH-1:0] T1_out;
    output [DATA_WIDTH-1:0] T2_out;
    output [DATA_WIDTH-1:0] T3_out;

    ////////////////////////////////////// Wires and registers /////////////////////////////////////////
    wire [DATA_WIDTH-1:0] L_mult_out;
    wire [DATA_WIDTH-1:0] M_mult_out;
    wire [DATA_WIDTH-1:0] R_mult_out;

    wire [DATA_WIDTH-1:0] L_addr_out;
    wire [DATA_WIDTH-1:0] M_addr_out;
    wire [DATA_WIDTH-1:0] R_addr_out;

    reg [DATA_WIDTH-1:0] temp_L_addr_in;
    reg [DATA_WIDTH-1:0] temp_M_addr_in;
    reg [DATA_WIDTH-1:0] temp_R_addr_in;

    wire L_mul_dv;
    wire M_mul_dv;
    wire R_mul_dv;
    wire L_add_dv;
    wire M_add_dv;
    wire R_add_dv;


    ///////////////////////////////////////// Assignments ////////////////////////////////////////////
    always@(*)
    begin
        case(A_sel)
            2'd0    :
                begin
                    temp_L_addr_in <= L_addr_out;
                    temp_M_addr_in <= M_addr_out;
                    temp_R_addr_in <= R_addr_out;
                end 
            2'd1    :
                begin
                    temp_L_addr_in <= bias;
                    temp_M_addr_in <= L_addr_out;
                    temp_R_addr_in <= M_addr_out;
                end 
            2'd2    :
                begin
                    temp_L_addr_in <= 0;
                    temp_M_addr_in <= 0;
                    temp_R_addr_in <= 0;
                end 
            default : 
                begin
                    temp_L_addr_in <= 0;
                    temp_M_addr_in <= 0;
                    temp_R_addr_in <= 0;
                end 
        endcase
    end

   
    //////////////////////////////////////// Instantiations //////////////////////////////////////////
    // Multiplier Left
    floating_point_0 MUL_L (
        .aclk(clk),                                  // input wire aclk
        .aclken(MA_en),                              // input wire aclken
        .aresetn(rstn),                            // input wire aresetn
        .s_axis_a_tvalid(dv_in),            // input wire s_axis_a_tvalid
        .s_axis_a_tdata(d_in),              // input wire [15 : 0] s_axis_a_tdata
        .s_axis_b_tvalid(dv_in),            // input wire s_axis_b_tvalid
        .s_axis_b_tdata(L_k_in),              // input wire [15 : 0] s_axis_b_tdata
        .m_axis_result_tvalid(L_mul_dv),  // output wire m_axis_result_tvalid
        .m_axis_result_tdata(L_mult_out)    // output wire [15 : 0] m_axis_result_tdata
    );

    // Multiplier Mid
    floating_point_0 MUL_M (
        .aclk(clk),                                  // input wire aclk
        .aclken(MA_en),                              // input wire aclken
        .aresetn(rstn),                            // input wire aresetn
        .s_axis_a_tvalid(dv_in),            // input wire s_axis_a_tvalid
        .s_axis_a_tdata(d_in),              // input wire [15 : 0] s_axis_a_tdata
        .s_axis_b_tvalid(dv_in),            // input wire s_axis_b_tvalid
        .s_axis_b_tdata(M_k_in),              // input wire [15 : 0] s_axis_b_tdata
        .m_axis_result_tvalid(M_mul_dv),  // output wire m_axis_result_tvalid
        .m_axis_result_tdata(M_mult_out)    // output wire [15 : 0] m_axis_result_tdata
    );

    // Multiplier Right
    floating_point_0 MUL_R (
        .aclk(clk),                                  // input wire aclk
        .aclken(MA_en),                              // input wire aclken
        .aresetn(rstn),                            // input wire aresetn
        .s_axis_a_tvalid(dv_in),            // input wire s_axis_a_tvalid
        .s_axis_a_tdata(d_in),              // input wire [15 : 0] s_axis_a_tdata
        .s_axis_b_tvalid(dv_in),            // input wire s_axis_b_tvalid
        .s_axis_b_tdata(R_k_in),              // input wire [15 : 0] s_axis_b_tdata
        .m_axis_result_tvalid(R_mul_dv),  // output wire m_axis_result_tvalid
        .m_axis_result_tdata(R_mult_out)    // output wire [15 : 0] m_axis_result_tdata
    );


    // Addder Left
    floating_point_1 ADDR_L (
        .aclk(clk),                                  // input wire aclk
        .aclken(MA_en),                              // input wire aclken
        .aresetn(rstn),                            // input wire aresetn
        .s_axis_a_tvalid(L_mul_dv),            // input wire s_axis_a_tvalid
        .s_axis_a_tdata(L_mult_out),              // input wire [15 : 0] s_axis_a_tdata
        .s_axis_b_tvalid(L_mul_dv),            // input wire s_axis_b_tvalid
        .s_axis_b_tdata(temp_L_addr_in),              // input wire [15 : 0] s_axis_b_tdata
        .m_axis_result_tvalid(L_add_dv),  // output wire m_axis_result_tvalid
        .m_axis_result_tdata(L_addr_out)    // output wire [15 : 0] m_axis_result_tdata
    );

    // Addder Left
    floating_point_1 ADDR_M (
        .aclk(clk),                                  // input wire aclk
        .aclken(MA_en),                              // input wire aclken
        .aresetn(rstn),                            // input wire aresetn
        .s_axis_a_tvalid(M_mul_dv),            // input wire s_axis_a_tvalid
        .s_axis_a_tdata(M_mult_out),              // input wire [15 : 0] s_axis_a_tdata
        .s_axis_b_tvalid(M_mul_dv),            // input wire s_axis_b_tvalid
        .s_axis_b_tdata(temp_M_addr_in),              // input wire [15 : 0] s_axis_b_tdata
        .m_axis_result_tvalid(M_add_dv),  // output wire m_axis_result_tvalid
        .m_axis_result_tdata(M_addr_out)    // output wire [15 : 0] m_axis_result_tdata
    );

    // Addder Left
    floating_point_1 ADDR_R (
        .aclk(clk),                                  // input wire aclk
        .aclken(MA_en),                              // input wire aclken
        .aresetn(rstn),                            // input wire aresetn
        .s_axis_a_tvalid(R_mul_dv),            // input wire s_axis_a_tvalid
        .s_axis_a_tdata(R_mult_out),              // input wire [15 : 0] s_axis_a_tdata
        .s_axis_b_tvalid(R_mul_dv),            // input wire s_axis_b_tvalid
        .s_axis_b_tdata(temp_R_addr_in),              // input wire [15 : 0] s_axis_b_tdata
        .m_axis_result_tvalid(R_add_dv),  // output wire m_axis_result_tvalid
        .m_axis_result_tdata(R_addr_out)    // output wire [15 : 0] m_axis_result_tdata
    );


    // T1 register
    T_reg T1(
        .clk(clk),
        .en(T_en),
        .sel(T_sel), 
        .d_in_1(T1_in),
        .d_in_2(R_addr_out),
        .d_out(T1_out)
    );

    // T2 register
    T_reg T2(
        .clk(clk),
        .en(T_en),
        .sel(T_sel), 
        .d_in_1(T2_in),
        .d_in_2(M_addr_out),
        .d_out(T2_out)
    );

    // T3 register
    T_reg T3(
        .clk(clk),
        .en(T_en),
        .sel(T_sel), 
        .d_in_1(T3_in),
        .d_in_2(L_addr_out),
        .d_out(T3_out)
    );


endmodule