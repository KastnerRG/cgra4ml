`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: Weight rotator unit
// Module Name: weight_rotator.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: Stores kernels and rotate them inorder to supply weights for the conv cores
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module weight_rotator(
    clk,
    rstn,
    din,
    l_valid,
    r_rdy,
    write_depth,    // K_size * CH_in +1{for bias line}  (give this as 0 indexed. eg 3* 10 + 1 => 30 not 31) | give actual write_depth -1
    rotate_amount,  // Width * BLKs (should be given as 0 indexed ie: width * blks -1) | give actual roate_amount -1
    im_channels_in, // give actual -1
    im_width_in,    // give actual -1
    im_blocks_in,   // give actual -1
    conv_mode_in,   
    max_mode_in,

    l_rdy,
    r_valid,
    BIAS_out,
    im_channels_out,
    im_width_out,
    im_blocks_out,
    conv_mode_out,
    is_3x3,
    max_mode_out,
    dout
    );


    //***** NOTE *****//
    /*
        Note that the system is divided into 2 sections Left and Right. Therfore the signals are prefixed
        with L_ or R_ accordingly and the signals interconnecting these 2 sections are named according to
        the master of that signal.
                                                    ||       
                            _____L_singals____      ||        _____R_singals____
                                                    ||
                                                    ||
                                        ||====== L_singal =======>  
                                                    ||
                                        <======= R_singal ======||
                                                    ||
                                                    ||
                                                    ||
                                                    ||
    */

    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DATA_WIDTH   = 16;
    parameter CONV_CORES   = 1;
    parameter ADDRS_WIDTH  = 12; // $ceil($clog2[(maximum channels)1024*3 +1]) for block rams
    parameter ROTATE_WIDTH = 14; //($ceil ($clog2(max_im_height/conv_units * maxm_im_width)))

    parameter FIFO_DEPTH         = 4; 
    parameter FIFO_COUNTER_WIDTH = 2; // $clog2(DEPTH)

    parameter RAM_LATENCY = 2;

    parameter CH_IN_COUNTER_WIDTH    = 10;
    parameter NUM_BLKS_COUNTER_WIDTH = 5;
    parameter IM_WIDTH_COUNTER_WIDTH = 9;
    

    localparam IO_WIDTH    = CONV_CORES * 3 * DATA_WIDTH; 
    

    ////////////////////////////////////// Port declaration ////////////////////////////////////////////

    input                              clk;
    input                              rstn;
    input [IO_WIDTH-1:0]               din;
    input                              l_valid;
    input                              r_rdy;
    input [ADDRS_WIDTH-1:0]            write_depth;
    input [ROTATE_WIDTH-1:0]           rotate_amount;
    input [CH_IN_COUNTER_WIDTH-1:0]    im_channels_in;
    input [IM_WIDTH_COUNTER_WIDTH-1:0] im_width_in;
    input [NUM_BLKS_COUNTER_WIDTH-1:0] im_blocks_in;
    input                              conv_mode_in;
    input                              max_mode_in;

    output                              l_rdy;
    output                              r_valid;
    output [IO_WIDTH-1:0]               dout;
    output [IO_WIDTH-1:0]               BIAS_out;
    output [CH_IN_COUNTER_WIDTH-1:0]    im_channels_out;
    output [IM_WIDTH_COUNTER_WIDTH-1:0] im_width_out;
    output [NUM_BLKS_COUNTER_WIDTH-1:0] im_blocks_out;
    output                              conv_mode_out;
    output                              is_3x3;
    output                              max_mode_out;

    ////////////////////////////////////// Wires and registers /////////////////////////////////////////

    wire                fifo_l_rdy_a;
    wire                fifo_r_valid_a;
    wire                fifo_re_a;
    wire                fifo_we_a;
    wire                fifo_we_buff_a;
    wire                fifo_last_data_a;
    wire [IO_WIDTH-1:0] fifo_dout_a;

    wire                fifo_l_rdy_b;
    wire                fifo_r_valid_b;
    wire                fifo_re_b;
    wire                fifo_we_b;
    wire                fifo_we_buff_b;
    wire                fifo_last_data_b;
    wire [IO_WIDTH-1:0] fifo_dout_b;


    wire                   L_we_a;
    wire                   L_we_b;
    wire                   L_counter_en;
    wire [IO_WIDTH-1:0]    L_dout_a;
    wire [IO_WIDTH-1:0]    L_dout_b;
    wire [ADDRS_WIDTH-1:0] L_addrs_a;
    wire [ADDRS_WIDTH-1:0] L_addrs_b;
    // wire [IO_WIDTH-1:0]    L_BIAS_out; // biasses of the current reading RAM

    reg                    L_sel    = 0; // 0: write mode for RAM A and Read mode for RAM B ; 1: write mode for RAM B and Read mode for RAM A ;
    // reg [IO_WIDTH-1:0]     L_BIAS_A = 0;
    // reg [IO_WIDTH-1:0]     L_BIAS_B = 0;
    
    

    wire                  R_counter_en;
    wire                  R_last_data;

    reg                    R_sel                = 0;
    reg [ADDRS_WIDTH-1:0]  R_write_depth_reg    = 0; // to store how much valid lines in the current reading RAM
    reg [ROTATE_WIDTH-1:0] R_rotate_amount_reg  = 0; // to store how much to rotate the current reading RAM

    reg [CH_IN_COUNTER_WIDTH-1:0]    R_ch_in      = 0;
    reg [IM_WIDTH_COUNTER_WIDTH-1:0] R_im_width   = 0;
    reg [NUM_BLKS_COUNTER_WIDTH-1:0] R_num_blocks = 0;
    reg [IO_WIDTH-1:0]               R_BIAS       = 0;
    reg                              R_conv_mode  = 0;
    reg                              R_max_mode   = 1;


    ///////////////////////////////////////////// Counters ////////////////////////////////////////////
    reg [ADDRS_WIDTH-1:0]  L_addrs  = 0; // address of the current writing RAM
    reg [ADDRS_WIDTH-1:0]  R_addrs  = 0; // address of the current reading RAM
    reg [ROTATE_WIDTH-1:0] R_rotate = 0; // to count how many rotations were done

    ///////////////////////////////////////////// States ////////////////////////////////////////////
    
    localparam R_IDLE    = 1'd0;
    localparam R_ROTATE  = 1'd1;

    reg        R_STATE   = R_IDLE;

    ///////////////////////////////////////// Assignments ////////////////////////////////////////////
    // assign BIAS_out     = L_sel ? L_BIAS_A : L_BIAS_B; // routing the bias out corresponding to the current reading RAM
    
    
    
    assign L_counter_en = l_rdy & l_valid;
    assign l_rdy        = !((L_addrs == (write_depth)) & !R_last_data & r_valid);
    assign L_addrs_a    = L_sel ? R_addrs  : L_addrs;
    assign L_addrs_b    = L_sel ? L_addrs  : R_addrs;
    assign L_we_a       = !L_sel & (l_valid & l_rdy); // when both rams are busy make l_rdy down
    assign L_we_b       =  L_sel & (l_valid & l_rdy);


    assign R_counter_en = r_rdy & r_valid;
    assign dout         = L_sel ? fifo_dout_a    : fifo_dout_b;
    assign r_valid      = L_sel ? fifo_r_valid_a : fifo_r_valid_b; 
    assign fifo_re_a    = L_sel ? r_rdy : 0;
    assign fifo_re_b    = L_sel ? 0     : r_rdy;
    assign fifo_we_a    = L_sel ? (r_rdy & !(R_STATE == R_IDLE)) : (L_counter_en & (L_addrs<4));
    assign fifo_we_b    = L_sel ? (L_counter_en & (L_addrs<4))   : (r_rdy & !(R_STATE == R_IDLE)) ;
    assign R_last_data  = L_sel ? fifo_last_data_a : fifo_last_data_b ;
   
    assign BIAS_out        = R_BIAS;
    assign im_channels_out = R_ch_in;
    assign im_width_out    = R_im_width;
    assign im_blocks_out   = R_num_blocks;
    assign conv_mode_out   = R_conv_mode;
    assign max_mode_out    = R_max_mode;
    assign is_3x3          = ~conv_mode_out;
    //////////////////////////////////////// Instantiations //////////////////////////////////////////
    
    
    /* ****** IMPORTANT *******
        Recreate the RAMS when the number of cores are changed
    */
    // ------ block rams are active high reset sensitive
    
    // Block RAM A
    blk_mem_gen_0 RAM_A (
        .clka(clk),    // input wire clka
        .ena(1'b1),      // input wire ena
        .wea(L_we_a),      // input wire [0 : 0] wea
        .addra(L_addrs_a),  // input wire [11 : 0] addra
        .dina(din),    // input wire [47 : 0] dina
        .douta(L_dout_a)  // output wire [47 : 0] douta
    );

    reg_buffer #(
        .DELAY(RAM_LATENCY)
    )FIFO_WE_BUFF_A(
        .clk(clk),
        .rstn(rstn),
        .d_in(fifo_we_a),
        .en(1'b1),
        .d_out(fifo_we_buff_a)
    );

    FIFO #(
        .IN_WIDTH(IO_WIDTH),
        .DEPTH(FIFO_DEPTH),
        .COUNTER_WIDTH(FIFO_COUNTER_WIDTH)
    )FIFO_A(
        .clk(clk),
        .rstn(rstn),
        .din(L_dout_a),
        .we(fifo_we_buff_a),
        .re(fifo_re_a),
        .l_rdy(fifo_l_rdy_a),
        .r_valid(fifo_r_valid_a),
        // .almost_empty,
        .last_data(fifo_last_data_a),
        .dout(fifo_dout_a)
    );


    // Block RAM B
    blk_mem_gen_0 RAM_B (
        .clka(clk),    // input wire clka
        .ena(1'b1),      // input wire ena
        .wea(L_we_b),      // input wire [0 : 0] wea
        .addra(L_addrs_b),  // input wire [11 : 0] addra
        .dina(din),    // input wire [47 : 0] dina
        .douta(L_dout_b)  // output wire [47 : 0] douta
    );


    reg_buffer #(
        .DELAY(RAM_LATENCY)
    )FIFO_WE_BUFF_B(
        .clk(clk),
        .rstn(rstn),
        .d_in(fifo_we_b),
        .en(1'b1),
        .d_out(fifo_we_buff_b)
    );


    FIFO #(
        .IN_WIDTH(IO_WIDTH),
        .DEPTH(FIFO_DEPTH),
        .COUNTER_WIDTH(FIFO_COUNTER_WIDTH)
    )FIFO_B(
        .clk(clk),
        .rstn(rstn),
        .din(L_dout_b),
        .we(fifo_we_buff_b),
        .re(fifo_re_b),
        .l_rdy(fifo_l_rdy_b),
        .r_valid(fifo_r_valid_b),
        // .almost_empty,
        .last_data(fifo_last_data_b),
        .dout(fifo_dout_b)
    );

    
    
    


    //////////////////////////////////////// Main Code //////////////////////////////////////////

    // Bias copying
    // always @(posedge clk ,negedge rstn) begin
    //     if (~rstn) begin
    //         L_BIAS_A <= 0;
    //         L_BIAS_B <= 0;
    //     end else begin
    //         if ((L_addrs == 0) & (L_counter_en) & !L_sel) begin
    //             L_BIAS_A <= din;
    //         end else begin
    //             L_BIAS_A <= L_BIAS_A;
    //         end

    //         if ((L_addrs == 0) & (L_counter_en) & L_sel) begin
    //             L_BIAS_B <= din;
    //         end else begin
    //             L_BIAS_B <= L_BIAS_B;
    //         end
    //     end
    // end
 
    // L state machine
    always @(posedge clk , negedge rstn) begin
        if (~rstn) begin
            L_addrs             <= 0;
            L_sel               <= 0;
            R_write_depth_reg   <= 0;
            R_rotate_amount_reg <= 0;
            R_BIAS              <= 0;
            R_ch_in             <= 0;
            R_im_width          <= 0;
            R_num_blocks        <= 0;
            R_conv_mode         <= 0;
            R_max_mode          <= 1;
        end else begin
            if (L_counter_en) begin
                if (L_addrs < write_depth) begin  // increment writing address until the given depth
                    L_addrs             <= L_addrs + 1;  
                    L_sel               <= L_sel; 
                    R_write_depth_reg   <= R_write_depth_reg;
                    R_rotate_amount_reg <= R_rotate_amount_reg;
                    R_BIAS              <= R_BIAS;
                    R_ch_in             <= R_ch_in;
                    R_im_width          <= R_im_width;
                    R_num_blocks        <= R_num_blocks;
                    R_conv_mode         <= R_conv_mode;
                    R_max_mode          <= R_max_mode;
                end else begin                      // reset the writing address to 0 to write to the next RAM
                    L_addrs             <= 0;
                    L_sel               <= ~L_sel;
                    R_write_depth_reg   <= write_depth-1;
                    R_rotate_amount_reg <= rotate_amount;
                    R_BIAS              <= din;
                    R_ch_in             <= im_channels_in;
                    R_im_width          <= im_width_in;
                    R_num_blocks        <= im_blocks_in;
                    R_conv_mode         <= conv_mode_in;
                    R_max_mode          <= max_mode_in;
                end 
            end else begin
                L_addrs             <= L_addrs;
                L_sel               <= L_sel;
                R_write_depth_reg   <= R_write_depth_reg;
                R_rotate_amount_reg <= R_rotate_amount_reg;
                R_BIAS              <= R_BIAS;
                R_ch_in             <= R_ch_in;
                R_im_width          <= R_im_width;
                R_num_blocks        <= R_num_blocks;
                R_conv_mode         <= R_conv_mode;
                R_max_mode          <= R_max_mode;
            end

        end
    end


    

    // R state machine
    always @(posedge clk ,negedge rstn) begin
        if (~rstn) begin
            R_STATE      <= R_IDLE;
            R_rotate     <= 0;
            R_addrs      <= 3; // others are already in the FIFO
            R_sel        <= 0;
        end else begin
            case (R_STATE)
                R_IDLE: 
                    begin
                        R_rotate <= 0;
                        if (R_counter_en & (R_sel^L_sel)) begin // Start only when you are not still using the same RAM as before
                            R_STATE  <= R_ROTATE;
                            R_addrs  <= R_addrs + 1;
                            R_sel    <= L_sel;
                        end else begin
                            R_STATE <= R_STATE;
                            R_addrs <= 3; // others are already in the FIFO
                            R_sel   <= R_sel;
                        end
                    end
                R_ROTATE:
                    begin
                        R_sel   <= R_sel;
                        if (R_counter_en) begin
                            if (R_addrs == R_write_depth_reg) begin
                                if (R_rotate == R_rotate_amount_reg) begin
                                    R_addrs  <= 3;  // others are already in the FIFO
                                    R_rotate <= 0;
                                    R_STATE  <= R_IDLE;
                                end else begin
                                    R_addrs  <= 0;  
                                    R_rotate <= R_rotate + 1;
                                    R_STATE  <= R_STATE;
                                end
                            end else begin
                                R_addrs  <= R_addrs + 1;
                                R_STATE  <= R_STATE;
                                R_rotate <= R_rotate;
                            end
                        end else begin
                            R_STATE <= R_STATE;
                            R_addrs <= R_addrs;
                        end
                    end
            endcase
        end
    end






endmodule