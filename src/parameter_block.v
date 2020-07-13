`include "system_parameters.v"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R. Wickramasinghe
// 
// Create Date   : 11/02/2020 11:42:07 PM
// Design Name   : parameter block
// Module Name   : parameter_block.v
// Project Name  : FYP
// Target Devices: Xillinx Zynq 706
// Tool Versions : Vivado 2018.2
// Description   : Contains all the layer parameters to be given to the 
//                 weightrotator and the resto of the pipe. 
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module parameter_block(
	layer_number,

	write_depth,
	rotate_amount,
	im_blks,
	im_width,
	im_ch,
	conv_mode,
	max_mode,
	lrelu_en
);
	

	/////////////////////////////// Port Declaration ///////////////////////////////

	input [4:0] layer_number; // restring the value of this to 0-20

	output [`ADDRS_WIDTH-1:0]            write_depth;
	output [`ROTATE_WIDTH-1:0]           rotate_amount;
	output [`NUM_BLKS_COUNTER_WIDTH-1:0] im_blks;
	output [`IM_WIDTH_COUNTER_WIDTH-1:0] im_width;
	output [`CH_IN_COUNTER_WIDTH-1:0]    im_ch;
	output 								 conv_mode;
	output 								 max_mode;
	output 								 lrelu_en;

	////////////////////////////// Wires & Registers ///////////////////////////////
	wire [`PARAM_WIRE_WIDTH-1:0] PARAM_RAM [0:20];



	// Layer 1 parameters

	reg [`ADDRS_WIDTH-1:0]            l_1_write_depth   = 12'd6;
	reg [`ROTATE_WIDTH-1:0]           l_1_rotate_amount = 14'd6143;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_1_im_blks       = 5'd15;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_1_im_width      = 9'd383;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_1_im_ch         = 10'd3;
	reg                               l_1_conv_mode     = 1'd0;
	reg                               l_1_max_mode      = 1'd1;
	reg                               l_1_lrelu_en      = 1'd1;
	



	// Layer 2 parameters

	reg [`ADDRS_WIDTH-1:0]            l_2_write_depth   = 12'd48;
	reg [`ROTATE_WIDTH-1:0]           l_2_rotate_amount = 14'd1535;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_2_im_blks       = 5'd7;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_2_im_width      = 9'd191;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_2_im_ch         = 10'd31;
	reg                               l_2_conv_mode     = 1'd0;
	reg                               l_2_max_mode      = 1'd1;
	reg                               l_2_lrelu_en      = 1'd1;
	



	// Layer 3 parameters

	reg [`ADDRS_WIDTH-1:0]            l_3_write_depth   = 12'd192;
	reg [`ROTATE_WIDTH-1:0]           l_3_rotate_amount = 14'd767;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_3_im_blks       = 5'd7;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_3_im_width      = 9'd95;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_3_im_ch         = 10'd63;
	reg                               l_3_conv_mode     = 1'd0;
	reg                               l_3_max_mode      = 1'd0;
	reg                               l_3_lrelu_en      = 1'd1;
	



	// Layer 4 parameters

	reg [`ADDRS_WIDTH-1:0]            l_4_write_depth   = 12'd128;
	reg [`ROTATE_WIDTH-1:0]           l_4_rotate_amount = 14'd767;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_4_im_blks       = 5'd7;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_4_im_width      = 9'd95;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_4_im_ch         = 10'd127;
	reg                               l_4_conv_mode     = 1'd1;
	reg                               l_4_max_mode      = 1'd0;
	reg                               l_4_lrelu_en      = 1'd1;
	



	// Layer 5 parameters

	reg [`ADDRS_WIDTH-1:0]            l_5_write_depth   = 12'd96;
	reg [`ROTATE_WIDTH-1:0]           l_5_rotate_amount = 14'd383;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_5_im_blks       = 5'd3;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_5_im_width      = 9'd95;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_5_im_ch         = 10'd63;
	reg                               l_5_conv_mode     = 1'd0;
	reg                               l_5_max_mode      = 1'd1;
	reg                               l_5_lrelu_en      = 1'd1;
	



	// Layer 6 parameters

	reg [`ADDRS_WIDTH-1:0]            l_6_write_depth   = 12'd384;
	reg [`ROTATE_WIDTH-1:0]           l_6_rotate_amount = 14'd191;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_6_im_blks       = 5'd3;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_6_im_width      = 9'd47;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_6_im_ch         = 10'd127;
	reg                               l_6_conv_mode     = 1'd0;
	reg                               l_6_max_mode      = 1'd0;
	reg                               l_6_lrelu_en      = 1'd1;
	



	// Layer 7 parameters

	reg [`ADDRS_WIDTH-1:0]            l_7_write_depth   = 12'd256;
	reg [`ROTATE_WIDTH-1:0]           l_7_rotate_amount = 14'd191;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_7_im_blks       = 5'd3;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_7_im_width      = 9'd47;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_7_im_ch         = 10'd255;
	reg                               l_7_conv_mode     = 1'd1;
	reg                               l_7_max_mode      = 1'd0;
	reg                               l_7_lrelu_en      = 1'd1;
	



	// Layer 8 parameters

	reg [`ADDRS_WIDTH-1:0]            l_8_write_depth   = 12'd192;
	reg [`ROTATE_WIDTH-1:0]           l_8_rotate_amount = 14'd95;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_8_im_blks       = 5'd1;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_8_im_width      = 9'd47;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_8_im_ch         = 10'd127;
	reg                               l_8_conv_mode     = 1'd0;
	reg                               l_8_max_mode      = 1'd1;
	reg                               l_8_lrelu_en      = 1'd1;
	



	// Layer 9 parameters

	reg [`ADDRS_WIDTH-1:0]            l_9_write_depth   = 12'd768;
	reg [`ROTATE_WIDTH-1:0]           l_9_rotate_amount = 14'd47;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_9_im_blks       = 5'd1;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_9_im_width      = 9'd23;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_9_im_ch         = 10'd255;
	reg                               l_9_conv_mode     = 1'd0;
	reg                               l_9_max_mode      = 1'd0;
	reg                               l_9_lrelu_en      = 1'd1;
	



	// Layer 10 parameters

	reg [`ADDRS_WIDTH-1:0]            l_10_write_depth   = 12'd512;
	reg [`ROTATE_WIDTH-1:0]           l_10_rotate_amount = 14'd47;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_10_im_blks       = 5'd1;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_10_im_width      = 9'd23;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_10_im_ch         = 10'd511;
	reg                               l_10_conv_mode     = 1'd1;
	reg                               l_10_max_mode      = 1'd0;
	reg                               l_10_lrelu_en      = 1'd1;
	



	// Layer 11 parameters

	reg [`ADDRS_WIDTH-1:0]            l_11_write_depth   = 12'd768;
	reg [`ROTATE_WIDTH-1:0]           l_11_rotate_amount = 14'd47;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_11_im_blks       = 5'd1;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_11_im_width      = 9'd23;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_11_im_ch         = 10'd255;
	reg                               l_11_conv_mode     = 1'd0;
	reg                               l_11_max_mode      = 1'd0;
	reg                               l_11_lrelu_en      = 1'd1;
	



	// Layer 12 parameters

	reg [`ADDRS_WIDTH-1:0]            l_12_write_depth   = 12'd512;
	reg [`ROTATE_WIDTH-1:0]           l_12_rotate_amount = 14'd47;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_12_im_blks       = 5'd1;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_12_im_width      = 9'd23;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_12_im_ch         = 10'd511;
	reg                               l_12_conv_mode     = 1'd1;
	reg                               l_12_max_mode      = 1'd0;
	reg                               l_12_lrelu_en      = 1'd1;
	



	// Layer 13 parameters

	reg [`ADDRS_WIDTH-1:0]            l_13_write_depth   = 12'd384;
	reg [`ROTATE_WIDTH-1:0]           l_13_rotate_amount = 14'd23;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_13_im_blks       = 5'd0;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_13_im_width      = 9'd23;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_13_im_ch         = 10'd255;
	reg                               l_13_conv_mode     = 1'd0;
	reg                               l_13_max_mode      = 1'd1;
	reg                               l_13_lrelu_en      = 1'd1;
	



	// Layer 14 parameters

	reg [`ADDRS_WIDTH-1:0]            l_14_write_depth   = 12'd1536;
	reg [`ROTATE_WIDTH-1:0]           l_14_rotate_amount = 14'd11;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_14_im_blks       = 5'd0;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_14_im_width      = 9'd11;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_14_im_ch         = 10'd511;
	reg                               l_14_conv_mode     = 1'd0;
	reg                               l_14_max_mode      = 1'd0;
	reg                               l_14_lrelu_en      = 1'd1;
	



	// Layer 15 parameters

	reg [`ADDRS_WIDTH-1:0]            l_15_write_depth   = 12'd1024;
	reg [`ROTATE_WIDTH-1:0]           l_15_rotate_amount = 14'd11;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_15_im_blks       = 5'd0;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_15_im_width      = 9'd11;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_15_im_ch         = 10'd1023;
	reg                               l_15_conv_mode     = 1'd1;
	reg                               l_15_max_mode      = 1'd0;
	reg                               l_15_lrelu_en      = 1'd1;
	



	// Layer 16 parameters

	reg [`ADDRS_WIDTH-1:0]            l_16_write_depth   = 12'd1536;
	reg [`ROTATE_WIDTH-1:0]           l_16_rotate_amount = 14'd11;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_16_im_blks       = 5'd0;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_16_im_width      = 9'd11;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_16_im_ch         = 10'd511;
	reg                               l_16_conv_mode     = 1'd0;
	reg                               l_16_max_mode      = 1'd0;
	reg                               l_16_lrelu_en      = 1'd1;
	



	// Layer 17 parameters

	reg [`ADDRS_WIDTH-1:0]            l_17_write_depth   = 12'd1024;
	reg [`ROTATE_WIDTH-1:0]           l_17_rotate_amount = 14'd11;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_17_im_blks       = 5'd0;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_17_im_width      = 9'd11;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_17_im_ch         = 10'd1023;
	reg                               l_17_conv_mode     = 1'd1;
	reg                               l_17_max_mode      = 1'd0;
	reg                               l_17_lrelu_en      = 1'd1;
	



	// Layer 18 parameters

	reg [`ADDRS_WIDTH-1:0]            l_18_write_depth   = 12'd1536;
	reg [`ROTATE_WIDTH-1:0]           l_18_rotate_amount = 14'd11;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_18_im_blks       = 5'd0;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_18_im_width      = 9'd11;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_18_im_ch         = 10'd511;
	reg                               l_18_conv_mode     = 1'd0;
	reg                               l_18_max_mode      = 1'd0;
	reg                               l_18_lrelu_en      = 1'd1;
	



	// Layer 19 parameters

	reg [`ADDRS_WIDTH-1:0]            l_19_write_depth   = 12'd3072;
	reg [`ROTATE_WIDTH-1:0]           l_19_rotate_amount = 14'd11;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_19_im_blks       = 5'd0;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_19_im_width      = 9'd11;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_19_im_ch         = 10'd1023;
	reg                               l_19_conv_mode     = 1'd0;
	reg                               l_19_max_mode      = 1'd0;
	reg                               l_19_lrelu_en      = 1'd1;
	



	// Layer 20 parameters

	reg [`ADDRS_WIDTH-1:0]            l_20_write_depth   = 12'd3072;
	reg [`ROTATE_WIDTH-1:0]           l_20_rotate_amount = 14'd11;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_20_im_blks       = 5'd0;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_20_im_width      = 9'd11;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_20_im_ch         = 10'd1023;
	reg                               l_20_conv_mode     = 1'd0;
	reg                               l_20_max_mode      = 1'd0;
	reg                               l_20_lrelu_en      = 1'd1;
	



	// Layer 21 parameters

	reg [`ADDRS_WIDTH-1:0]            l_21_write_depth   = 12'd1024;
	reg [`ROTATE_WIDTH-1:0]           l_21_rotate_amount = 14'd11;
	reg [`NUM_BLKS_COUNTER_WIDTH-1:0] l_21_im_blks       = 5'd0;
	reg [`IM_WIDTH_COUNTER_WIDTH-1:0] l_21_im_width      = 9'd11;
	reg [`CH_IN_COUNTER_WIDTH-1:0]    l_21_im_ch         = 10'd1023;
	reg                               l_21_conv_mode     = 1'd1;
	reg                               l_21_max_mode      = 1'd0;
	reg                               l_21_lrelu_en      = 1'd0;
	


	/////////////////////////////////// Counters ///////////////////////////////////



	///////////////////////////////// Assignments //////////////////////////////////
	
	assign {write_depth,rotate_amount,im_blks,im_width,im_ch,conv_mode,max_mode,lrelu_en} = PARAM_RAM[layer_number];

	assign PARAM_RAM[0] = {l_1_write_depth,
						l_1_rotate_amount,
						l_1_im_blks,
						l_1_im_width,
						l_1_im_ch,
						l_1_conv_mode,
						l_1_max_mode,
						l_1_lrelu_en};

	assign PARAM_RAM[1] = {l_2_write_depth,
						l_2_rotate_amount,
						l_2_im_blks,
						l_2_im_width,
						l_2_im_ch,
						l_2_conv_mode,
						l_2_max_mode,
						l_2_lrelu_en};

	assign PARAM_RAM[2] = {l_3_write_depth,
						l_3_rotate_amount,
						l_3_im_blks,
						l_3_im_width,
						l_3_im_ch,
						l_3_conv_mode,
						l_3_max_mode,
						l_3_lrelu_en};

	assign PARAM_RAM[3] = {l_4_write_depth,
						l_4_rotate_amount,
						l_4_im_blks,
						l_4_im_width,
						l_4_im_ch,
						l_4_conv_mode,
						l_4_max_mode,
						l_4_lrelu_en};

	assign PARAM_RAM[4] = {l_5_write_depth,
						l_5_rotate_amount,
						l_5_im_blks,
						l_5_im_width,
						l_5_im_ch,
						l_5_conv_mode,
						l_5_max_mode,
						l_5_lrelu_en};

	assign PARAM_RAM[5] = {l_6_write_depth,
						l_6_rotate_amount,
						l_6_im_blks,
						l_6_im_width,
						l_6_im_ch,
						l_6_conv_mode,
						l_6_max_mode,
						l_6_lrelu_en};

	assign PARAM_RAM[6] = {l_7_write_depth,
						l_7_rotate_amount,
						l_7_im_blks,
						l_7_im_width,
						l_7_im_ch,
						l_7_conv_mode,
						l_7_max_mode,
						l_7_lrelu_en};

	assign PARAM_RAM[7] = {l_8_write_depth,
						l_8_rotate_amount,
						l_8_im_blks,
						l_8_im_width,
						l_8_im_ch,
						l_8_conv_mode,
						l_8_max_mode,
						l_8_lrelu_en};

	assign PARAM_RAM[8] = {l_9_write_depth,
						l_9_rotate_amount,
						l_9_im_blks,
						l_9_im_width,
						l_9_im_ch,
						l_9_conv_mode,
						l_9_max_mode,
						l_9_lrelu_en};

	assign PARAM_RAM[9] = {l_10_write_depth,
						l_10_rotate_amount,
						l_10_im_blks,
						l_10_im_width,
						l_10_im_ch,
						l_10_conv_mode,
						l_10_max_mode,
						l_10_lrelu_en};

	assign PARAM_RAM[10] = {l_11_write_depth,
						l_11_rotate_amount,
						l_11_im_blks,
						l_11_im_width,
						l_11_im_ch,
						l_11_conv_mode,
						l_11_max_mode,
						l_11_lrelu_en};

	assign PARAM_RAM[11] = {l_12_write_depth,
						l_12_rotate_amount,
						l_12_im_blks,
						l_12_im_width,
						l_12_im_ch,
						l_12_conv_mode,
						l_12_max_mode,
						l_12_lrelu_en};

	assign PARAM_RAM[12] = {l_13_write_depth,
						l_13_rotate_amount,
						l_13_im_blks,
						l_13_im_width,
						l_13_im_ch,
						l_13_conv_mode,
						l_13_max_mode,
						l_13_lrelu_en};

	assign PARAM_RAM[13] = {l_14_write_depth,
						l_14_rotate_amount,
						l_14_im_blks,
						l_14_im_width,
						l_14_im_ch,
						l_14_conv_mode,
						l_14_max_mode,
						l_14_lrelu_en};

	assign PARAM_RAM[14] = {l_15_write_depth,
						l_15_rotate_amount,
						l_15_im_blks,
						l_15_im_width,
						l_15_im_ch,
						l_15_conv_mode,
						l_15_max_mode,
						l_15_lrelu_en};

	assign PARAM_RAM[15] = {l_16_write_depth,
						l_16_rotate_amount,
						l_16_im_blks,
						l_16_im_width,
						l_16_im_ch,
						l_16_conv_mode,
						l_16_max_mode,
						l_16_lrelu_en};

	assign PARAM_RAM[16] = {l_17_write_depth,
						l_17_rotate_amount,
						l_17_im_blks,
						l_17_im_width,
						l_17_im_ch,
						l_17_conv_mode,
						l_17_max_mode,
						l_17_lrelu_en};

	assign PARAM_RAM[17] = {l_18_write_depth,
						l_18_rotate_amount,
						l_18_im_blks,
						l_18_im_width,
						l_18_im_ch,
						l_18_conv_mode,
						l_18_max_mode,
						l_18_lrelu_en};

	assign PARAM_RAM[18] = {l_19_write_depth,
						l_19_rotate_amount,
						l_19_im_blks,
						l_19_im_width,
						l_19_im_ch,
						l_19_conv_mode,
						l_19_max_mode,
						l_19_lrelu_en};

	assign PARAM_RAM[19] = {l_20_write_depth,
						l_20_rotate_amount,
						l_20_im_blks,
						l_20_im_width,
						l_20_im_ch,
						l_20_conv_mode,
						l_20_max_mode,
						l_20_lrelu_en};

	assign PARAM_RAM[20] = {l_21_write_depth,
						l_21_rotate_amount,
						l_21_im_blks,
						l_21_im_width,
						l_21_im_ch,
						l_21_conv_mode,
						l_21_max_mode,
						l_21_lrelu_en};

	//////////////////////////////// Instantiations ////////////////////////////////



	////////////////////////////////// Main Code ///////////////////////////////////


endmodule