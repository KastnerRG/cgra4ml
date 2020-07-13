`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 14/12/2019 10:59:45 AM
// Design Name: Comparator
// Module Name: comparator.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: Unit comparing and storing the maximum, given 2 floating numbers
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module comparator(
    clk,
    rstn,
    G_en, // acts as a data valid
    comp_en,
    in_A,
    in_B,

    G_out
    );
    
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DATA_WIDTH  = 16;

    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    input                  clk;
    input                  rstn;
    input                  G_en;
    input                  comp_en;
    input [DATA_WIDTH-1:0] in_A;
    input [DATA_WIDTH-1:0] in_B;

    output [DATA_WIDTH-1:0] G_out;

    
    ////////////////////////////////////// Wires and registers //////////////////////////////////////
    wire [7:0] A_greater_than_B; // only use the A_greater_than_B[0] bit : 1 A>B ; 0 otherwise
   
    reg [DATA_WIDTH-1:0] temp_A = 0;
    reg [DATA_WIDTH-1:0] temp_B = 0;

    ///////////////////////////////////////// Assignments ///////////////////////////////////////////
    // assign max = A_greater_than_B[0] ? in_A : in_B ;
    assign G_out = A_greater_than_B[0] ? temp_A : temp_B ;
    

    

    ///////////////////////////////////////////// Instantiation /////////////////////////////////////

    // Comparator
    // floating_point_2 COMP (
    //    .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    //    .s_axis_a_tdata(in_A),              // input wire [15 : 0] s_axis_a_tdata
    //    .s_axis_b_tvalid(1'b1),            // input wire s_axis_b_tvalid
    //    .s_axis_b_tdata(in_B),              // input wire [15 : 0] s_axis_b_tdata
    // //    .m_axis_result_tvalid(),  // output wire m_axis_result_tvalid
    //    .m_axis_result_tdata(A_greater_than_B)    // output wire [7 : 0] m_axis_result_tdata
    // );

    floating_point_4 COMP (
        .aclk(clk),                                  // input wire aclk
        .aclken(comp_en),                              // input wire aclken
        .aresetn(rstn),                            // input wire aresetn
        .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
        .s_axis_a_tdata(in_A),              // input wire [15 : 0] s_axis_a_tdata
        .s_axis_b_tvalid(1'b1),            // input wire s_axis_b_tvalid
        .s_axis_b_tdata(in_B),              // input wire [15 : 0] s_axis_b_tdata
        // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
        .m_axis_result_tdata(A_greater_than_B)    // output wire [7 : 0] m_axis_result_tdata
    );

    ///////////////////////////////////////////// Code //////////////////////////////////////////////

    always @(posedge clk ,negedge rstn) begin
        if (~rstn) begin
            temp_A <= 0;
            temp_B <= 0;
        end else begin
            if (G_en) begin
                temp_A <= in_A;
                temp_B <= in_B;
            end else begin
                temp_A <= temp_A;
                temp_B <= temp_B;
            end
        end
    end



endmodule