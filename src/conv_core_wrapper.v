`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 07/12/2019 07:26:45 PM
// Design Name: conv_core_wrapper
// Module Name: conv_core_wrapper.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: A wrapper for the convolution core + controller. Used to test/denug the core on hardware. Not the final implementation of the core
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module conv_core_wrapper(
    rstn,
    clk,
    mode,
    X_IN,
    KERNEL,
    r_rdy,
    l_valid,
    ch_in,
    im_width,
    num_blocks,
    BIAS,

    l_rdy,
    r_valid,
    finished,
    T_out
);

    ////////////////////// Parameters //////////////////////////
    localparam DATA_WIDTH        = 16;
    localparam CONV_UNITS        = 8;


    //////////////////// IO definition /////////////////////////
    input                                   rstn;      // = 1;
    input                                   clk;       // = 0;
    input                                   mode;      // = 0;
    input                                   r_rdy;     // = 1;
    input                                   l_valid;   // = 0;
    input [31:0]                            ch_in;     // = 32'd3; 
    input [31:0]                            im_width;  // = 32'd384;
    input [31:0]                            num_blocks;// = 32'd32;
    input [(DATA_WIDTH*3)-1:0]              BIAS ; //  biases K1|K2|K3
    input [(DATA_WIDTH*(CONV_UNITS+2))-1:0] X_IN;   // R10|R9|R8|R7|R6|R5|R4|R3|R2|R1
    input [(DATA_WIDTH*9)-1:0]              KERNEL; // K9|K8|K7|K6|K5|K4|K3|K2|K1

    
    output                  r_valid;
    output                  l_rdy;
    output                  finished;
    output [DATA_WIDTH-1:0] T_out;

    wire [1:0] sel;
    wire [1:0] A_sel;
    wire       T_sel;
    wire       T_en;
    wire       MA_en;
    wire       buff_en;

    // wire [(DATA_WIDTH*(CONV_UNITS+2))-1:0] x_buff_in;
    wire [(DATA_WIDTH*(CONV_UNITS+2))-1:0] x_buff_out;
    wire [(DATA_WIDTH*CONV_UNITS)-1:0]     x_out_d_switch;
    wire [DATA_WIDTH-1:0] KERNEL_3x3 [0:8] ; // without bias
    
    genvar i;
    generate
        for (i=0; i<9; i=i+1) begin : map_kernel
            assign KERNEL_3x3[i] = KERNEL[(DATA_WIDTH*(i+1))-1:DATA_WIDTH*i];
        end
    endgenerate

    

    // wire [DATA_WIDTH-1:0]     K1;
    // wire [DATA_WIDTH-1:0]     K2;
    // wire [DATA_WIDTH-1:0]     K3;
    // wire [DATA_WIDTH-1:0]     K4;
    // wire [DATA_WIDTH-1:0]     K5;
    // wire [DATA_WIDTH-1:0]     K6;
    // wire [DATA_WIDTH-1:0]     K7;
    // wire [DATA_WIDTH-1:0]     K8;
    // wire [DATA_WIDTH-1:0]     K9;

    // wire [DATA_WIDTH-1:0]     bias;


    // wire [DATA_WIDTH-1:0] conv_out_1;
    // wire [DATA_WIDTH-1:0] conv_out_2;
    // wire [DATA_WIDTH-1:0] conv_out_3;
    // wire [DATA_WIDTH-1:0] conv_out_4;
    // wire [DATA_WIDTH-1:0] conv_out_5;
    // wire [DATA_WIDTH-1:0] conv_out_6;
    // wire [DATA_WIDTH-1:0] conv_out_7;
    // wire [DATA_WIDTH-1:0] conv_out_8;
    // wire [DATA_WIDTH-1:0] conv_out_9;
    // wire [DATA_WIDTH-1:0] conv_out_10;
    // wire [DATA_WIDTH-1:0] conv_out_11;
    // wire [DATA_WIDTH-1:0] conv_out_12;

    // wire [31:0] conv_out_1_32;
    // wire [31:0] conv_out_2_32;
    // wire [31:0] conv_out_3_32;
    // wire [31:0] conv_out_4_32;
    // wire [31:0] conv_out_5_32;
    // wire [31:0] conv_out_6_32;
    // wire [31:0] conv_out_7_32;
    // wire [31:0] conv_out_8_32;
    // wire [31:0] conv_out_9_32;
    // wire [31:0] conv_out_10_32;
    // wire [31:0] conv_out_11_32;
    // wire [31:0] conv_out_12_32;





    
    

    // Assignments
    // assign bias_in = BIAS;
    // assign w_in_t  = KERNEL_T[STATE_R+(CH_COUNT)*9]; 
    // assign w_in_m  = KERNEL_M[STATE_R+(CH_COUNT)*9]; 
    // assign w_in_b  = KERNEL_B[STATE_R+(CH_COUNT)*9]; 
    
    // assign conv_out_1 = conv_out[15:0];
    // assign conv_out_2 = conv_out[31:16];
    // assign conv_out_3 = conv_out[47:32];
    // assign conv_out_4 = conv_out[63:48];
    // assign conv_out_5 = conv_out[79:64];
    // assign conv_out_6 = conv_out[95:80];
    // assign conv_out_7 = conv_out[111:96];
    // assign conv_out_8 = conv_out[127:112];
    // assign conv_out_9 = conv_out[143:128];
    // assign conv_out_10 = conv_out[159:144];
    // assign conv_out_11 = conv_out[175:160];
    // assign conv_out_12 = conv_out[191:176];


    // DUT instantiation





    controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .CONV_UNITS(CONV_UNITS)
    )CONTROLLER_DUT(
        .clk(clk),
        .rstn(rstn),
        .r_rdy(r_rdy),
        .l_valid(l_valid),
        .ch_in(ch_in),
        .im_width(im_width),
        .num_blocks(num_blocks),
        .mode(mode),
        .sel(sel),
        .A_sel(A_sel),
        .T_sel(T_sel),
        .T_en(T_en),
        .r_valid(r_valid),
        .MA_en(MA_en),
        .l_rdy(l_rdy),
        .buff_en(buff_en),
        .finished(finished)
    );

    d_in_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .CONV_UNITS(CONV_UNITS)
    )D_IN_BUFF(
        .clk(clk),
        .rstn(rstn),
        .buff_en(buff_en),
        .x_in(X_IN),
        .x_out(x_buff_out)
    );

    data_switch #(
        .DATA_WIDTH(DATA_WIDTH),
        .CONV_UNITS(CONV_UNITS)
    )DATA_SWITCH(
        .sel(sel),
        .x_in(x_buff_out),
        .x_out(x_out_d_switch)
    );
    
    conv_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .TOTAL_UNITS(CONV_UNITS)
    )CONV_CORE(
        .clk(clk),
        .rstn(rstn),
        .x_in(x_out_d_switch),
        .dv_in(1'b1),
        .MA_en(MA_en),
        .kernel_sel(sel),
        .A_sel(A_sel),
        .T_sel(T_sel),
        .T_en(T_en),
        .K1(KERNEL_3x3[0]),
        .K2(KERNEL_3x3[1]),
        .K3(KERNEL_3x3[2]),
        .K4(KERNEL_3x3[3]),
        .K5(KERNEL_3x3[4]),
        .K6(KERNEL_3x3[5]),
        .K7(KERNEL_3x3[6]),
        .K8(KERNEL_3x3[7]),
        .K9(KERNEL_3x3[8]),
        .bias(BIAS),
        .buff_en(buff_en),
        .T_out(T_out)
    );



    // floating_point_2 Debug_1 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_1),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_1_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_2 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_2),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_2_32)    // output wire [31 : 0] m_axis_result_tdata
    // );
    // floating_point_2 Debug_3 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_3),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_3_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_4 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_4),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_4_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_5 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_5),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_5_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_6 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_6),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_6_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_7 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_7),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_7_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_8 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_8),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_8_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_9 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_9),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_9_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_10 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_10),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_10_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_11 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_11),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_11_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_12 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_12),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_12_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

endmodule