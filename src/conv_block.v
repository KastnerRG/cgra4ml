`include "system_parameters.v"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 07/12/2019 07:26:45 PM
// Design Name: convolution block
// Module Name: conv_block.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: A wrapper for the x convolution cores + controller. 
//              Used as a standalone AXI stream unit with CONV_CORES convolution cores each having CONV_UNITS convolution units.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////// Illustration ////////////////////////////////////
/*
                         ___________________
                        |      _______      | 
                        |     |       |     |
                        |     |       |     |
              +---------|---->| Core1 |-----|--->T_out[DATA_WIDTH-1:0]
              |         |     |       |     |
              |         |     |_______|     |
              |         |       Type1       |
              |         |      _______      |
              |         |     |       |     |
              |         |     |       |     |
        +-----^---------|---->| Core2 |-----|--->T_out[2*DATA_WIDTH-1:DATA_WIDTH]
        |     |         |     |       |     |
        |     |         |     |_______|     |
        |     |         |       Type2       |
        |     |         |___________________| 
        |     |              
X_in[Type2|Type1]
        |     |          ___________________
        |     |         |      _______      | 
        |     |         |     |       |     |
        |     |         |     |       |     |
        |     +---------|---->| Core3 |-----|--->T_out[3*DATA_WIDTH-1:DATA_WIDTH*2]
        |               |     |       |     |
        |               |     |_______|     |
        |               |       Type1       |
        |               |      _______      |
        |               |     |       |     |
        |               |     |       |     |
        +---------------|---->| Core4 |-----|--->T_out[4*DATA_WIDTH-1:DATA_WIDTH*3]
                        |     |       |     |
                        |     |_______|     |
                        |       Type2       |
                        |___________________| 


*/
//////////////////////////////////////////////////////////////////////////////////

module conv_block(
    rstn,
    clk,
    conv_mode,
    max_mode,
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
    T_out,
    max_mode_out,
    T_last
);

    //////////////////////////////////////// Parameters //////////////////////////////////////////

    parameter DATA_WIDTH = 16;
    parameter CONV_UNITS = 8; // convolution units in each conv core
    parameter CONV_PAIRS = 1; // pairs of convolutional cores

    localparam CONV_CORES = 2*CONV_PAIRS; // actual convoltuion cores


    //////////////////////////////////////// Port declarations //////////////////////////////////////////

    input                                       rstn;      // active low reset
    input                                       clk;       
    input                                       conv_mode;      // conv mode 0: 3x3 ; 1: 1x1 
    input                                       max_mode;      // conv mode 0: 3x3 ; 1: 1x1 
    input                                       r_rdy;     
    input                                       l_valid;   
    input [`CH_IN_COUNTER_WIDTH-1:0]             ch_in;     // = 32'd3; 
    input [`IM_WIDTH_COUNTER_WIDTH-1:0]          im_width;  // = 32'd384;
    input [`NUM_BLKS_COUNTER_WIDTH-1:0]          num_blocks;// = 32'd32;
    input [(CONV_CORES*DATA_WIDTH*3)-1:0]       BIAS ;     //   biases {core n [K3|K2|K1]} , ..... , {core 2 [K3|K2|K1]} , {core 1 [K3|K2|K1]}
    input [(2 * DATA_WIDTH*(CONV_UNITS+2))-1:0] X_IN;      //   {core type2 [R10|R9|R8|R7|R6|R5|R4|R3|R2|R1]} , {core type1 [R10|R9|R8|R7|R6|R5|R4|R3|R2|R1]}
    input [(CONV_CORES*DATA_WIDTH*9)-1:0]       KERNEL;    //   { core n [K9|K8|K7|K6|K5|K4|K3|K2|K1]} , .... , { core 1 [K9|K8|K7|K6|K5|K4|K3|K2|K1]}

    
    output                                 r_valid;
    output                                 l_rdy;
    output                                 finished;
    output                                 T_last;
    output [(DATA_WIDTH * CONV_CORES)-1:0] T_out;          // {core n T_out} , ..... , {core 1 T_out}
    output reg                              max_mode_out = 1;

    //////////////////////////////////////// wires and registers //////////////////////////////////////////

    wire [1:0] sel;
    wire [1:0] A_sel;
    wire       T_sel;
    wire       T_en;
    wire       MA_en;
    wire       buff_en; // data buffer signal
    wire       bias_buff_en; // bias,configuration buffer signal

    // wire [(DATA_WIDTH*(CONV_UNITS+2))-1:0] x_buff_in;
    wire [(DATA_WIDTH*(CONV_UNITS+2))-1:0] x_buff_out_1;
    wire [(DATA_WIDTH*(CONV_UNITS+2))-1:0] x_buff_out_2;
    wire [(DATA_WIDTH*CONV_UNITS)-1:0]     x_out_d_switch_1;
    wire [(DATA_WIDTH*CONV_UNITS)-1:0]     x_out_d_switch_2;
    wire [(CONV_CORES*DATA_WIDTH*3)-1:0]   BIAS_buff_out;
    wire [DATA_WIDTH-1:0] KERNEL_3x3 [0:(9*CONV_CORES)-1] ; // without bias
    wire [(3*DATA_WIDTH)-1:0] BIAS_ARRAY [0:CONV_CORES-1];  // buffered before this assigning to this

    reg [`CH_IN_COUNTER_WIDTH-1:0]    ch_in_reg      = 3;     
    reg [`IM_WIDTH_COUNTER_WIDTH-1:0] im_width_reg   = 384; 
    reg [`NUM_BLKS_COUNTER_WIDTH-1:0] num_blocks_reg = 32;
    reg                               conv_mode_reg  = 0;
    reg                               max_mode_reg   = 1;
    

    //////////////////////////////////////// Assignments //////////////////////////////////////////
    
    genvar i;
    generate
        for (i=0; i< (9*CONV_CORES); i=i+1) begin : map_kernel
            assign KERNEL_3x3[i] = KERNEL[(DATA_WIDTH*(i+1))-1:DATA_WIDTH*i];
        end
    endgenerate

    genvar j;
    generate
        for (j=0; j<CONV_CORES ; j=j+1) begin : map_bias
            assign BIAS_ARRAY[j] = BIAS_buff_out[(DATA_WIDTH*3*(j+1))-1:(DATA_WIDTH*3)*j];
        end
    endgenerate


    

    //////////////////////////////////////// Instantiations //////////////////////////////////////////

    // store current layer's configuration
    always @(posedge clk ,negedge rstn) begin 
        if (~rstn) begin
            ch_in_reg      <= 3;     
            im_width_reg   <= 384; 
            num_blocks_reg <= 32;
            conv_mode_reg  <= 0;
            max_mode_reg   <= 1;
        end else begin
            if (bias_buff_en) begin
                ch_in_reg      <= ch_in;
                im_width_reg   <= im_width;
                num_blocks_reg <= num_blocks;
                conv_mode_reg  <= conv_mode;
                max_mode_reg   <= max_mode;
            end else begin
                ch_in_reg      <= ch_in_reg;
                im_width_reg   <= im_width_reg;
                num_blocks_reg <= num_blocks_reg;
                conv_mode_reg  <= conv_mode_reg;
                max_mode_reg   <= max_mode_reg;
                
            end
        end
    end

    // copy the maxpool status of current layer tied data for tranmitting
    always @(posedge clk ,negedge rstn) 
    begin
        if (~rstn) begin
            max_mode_out <= 1;
        end else begin
            if (T_sel) begin
                max_mode_out <= max_mode_reg;
            end else begin
                max_mode_out <= max_mode_out;
            end
        end    
    end


    controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .CONV_UNITS(CONV_UNITS)
    )CONTROLLER_INST(
        .clk(clk),
        .rstn(rstn),
        .r_rdy(r_rdy),
        .l_valid(l_valid),
        .ch_in(ch_in_reg),
        .im_width(im_width_reg),
        .num_blocks(num_blocks_reg),
        .mode(conv_mode_reg),
        .sel(sel),
        .A_sel(A_sel),
        .T_sel(T_sel),
        .T_en(T_en),
        .r_valid(r_valid),
        .MA_en(MA_en),
        .l_rdy(l_rdy),
        .buff_en(buff_en),
        .bias_buff_en(bias_buff_en),
        .finished(finished),
        .T_last(T_last)
    );


    // Used to register set of biases throughout a convolution
    kernel_buffer #(  
        .DATA_WIDTH(DATA_WIDTH),
        .UNITS(CONV_CORES*3)
    )BIAS_BUFFER(
        .clk(clk),
        .rstn(rstn),
        .buff_en(bias_buff_en),
        .x_in(BIAS),
        .x_out(BIAS_buff_out)
    );


    d_in_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .CONV_UNITS(CONV_UNITS)
    )D_IN_BUFF_1(
        .clk(clk),
        .rstn(rstn),
        .buff_en(buff_en),
        .x_in(X_IN[(DATA_WIDTH*(CONV_UNITS+2))-1:0]),
        .x_out(x_buff_out_1)
    );

    d_in_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .CONV_UNITS(CONV_UNITS)
    )D_IN_BUFF_2(
        .clk(clk),
        .rstn(rstn),
        .buff_en(buff_en),
        .x_in(X_IN[(2 * DATA_WIDTH*(CONV_UNITS+2))-1:(DATA_WIDTH*(CONV_UNITS+2))]),
        .x_out(x_buff_out_2)
    );

    data_switch #(
        .DATA_WIDTH(DATA_WIDTH),
        .CONV_UNITS(CONV_UNITS)
    )DATA_SWITCH_1(
        .sel(sel),
        .x_in(x_buff_out_1),
        .x_out(x_out_d_switch_1)
    );

    data_switch #(
        .DATA_WIDTH(DATA_WIDTH),
        .CONV_UNITS(CONV_UNITS)
    )DATA_SWITCH_2(
        .sel(sel),
        .x_in(x_buff_out_2),
        .x_out(x_out_d_switch_2)
    );
    

    // generating paris of cores
    genvar k;
    generate
        for (k = 0; k<CONV_PAIRS ; k = k + 1) begin : core_inst
            conv_core #(
                .DATA_WIDTH(DATA_WIDTH),
                .TOTAL_UNITS(CONV_UNITS)
            )CONV_CORE_TYPE_1(
                .clk(clk),
                .rstn(rstn),
                .x_in(x_out_d_switch_1),
                .dv_in(1'b1),
                .MA_en(MA_en),
                .kernel_sel(sel),
                .A_sel(A_sel),
                .T_sel(T_sel),
                .T_en(T_en),
                .K1(KERNEL_3x3[(9*2*k)+0]),
                .K2(KERNEL_3x3[(9*2*k)+1]),
                .K3(KERNEL_3x3[(9*2*k)+2]),
                .K4(KERNEL_3x3[(9*2*k)+3]),
                .K5(KERNEL_3x3[(9*2*k)+4]),
                .K6(KERNEL_3x3[(9*2*k)+5]),
                .K7(KERNEL_3x3[(9*2*k)+6]),
                .K8(KERNEL_3x3[(9*2*k)+7]),
                .K9(KERNEL_3x3[(9*2*k)+8]),
                .bias(BIAS_ARRAY[2*k]),
                .buff_en(buff_en),
                .T_out(T_out[((2*k+1)*DATA_WIDTH)-1:2*k*DATA_WIDTH])
            );


            conv_core #(
                .DATA_WIDTH(DATA_WIDTH),
                .TOTAL_UNITS(CONV_UNITS)
            )CONV_CORE_TYPE_2(
                .clk(clk),
                .rstn(rstn),
                .x_in(x_out_d_switch_2),
                .dv_in(1'b1),
                .MA_en(MA_en),
                .kernel_sel(sel),
                .A_sel(A_sel),
                .T_sel(T_sel),
                .T_en(T_en),
                .K1(KERNEL_3x3[(9*(2*k+1))+0]),
                .K2(KERNEL_3x3[(9*(2*k+1))+1]),
                .K3(KERNEL_3x3[(9*(2*k+1))+2]),
                .K4(KERNEL_3x3[(9*(2*k+1))+3]),
                .K5(KERNEL_3x3[(9*(2*k+1))+4]),
                .K6(KERNEL_3x3[(9*(2*k+1))+5]),
                .K7(KERNEL_3x3[(9*(2*k+1))+6]),
                .K8(KERNEL_3x3[(9*(2*k+1))+7]),
                .K9(KERNEL_3x3[(9*(2*k+1))+8]),
                .bias(BIAS_ARRAY[2*k+1]),
                .buff_en(buff_en),
                .T_out(T_out[((2*k+2)*DATA_WIDTH)-1:(2*k+1)*DATA_WIDTH])
            );
        end
    endgenerate
    



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




endmodule