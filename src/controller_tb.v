`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: Controller test bench
// Module Name: controller_tb.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: test bench
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module controller_tb();
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DATA_WIDTH = 16;
    parameter CONV_UNITS = 8;
    parameter CLK_PERIOD = 10;

    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    reg        clk        = 0;
    reg        rstn       = 1;
    reg        r_rdy      = 0;
    reg        l_valid    = 0;
    reg [31:0] ch_in      = 32'd3;
    reg [31:0] im_width   = 32'd384;
    reg [31:0] num_blocks = 32'd32;
    reg        mode       = 0;

    wire [1:0] sel;
    wire [1:0] A_sel;
    wire       T_sel;
    wire       T_en;
    wire       r_valid;
    wire       MA_en;
    wire       l_rdy;
    wire       finished;
    wire       buff_en;
    // wire [1:0] T_STATE;



    ///////////////////////////////////// DUT Instantiations ////////////////////////////////////////////
    controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .CONV_UNITS(CONV_UNITS)
    ) CONTROLLER_DUT(
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
    ///////////////////////////////////////////// Code ////////////////////////////////////////////
    always
    begin
        #(CLK_PERIOD/2);
        clk <= ~clk;
    end

    initial
    begin
        @(posedge clk);
        rstn   <= 0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        rstn   <= 1;
        @(posedge clk);  
        
        r_rdy <= 1;
        // @(negedge start_T);
        @(posedge clk);
        mode    <= 0;
        l_valid <= 1;
        @(posedge finished);
        l_valid <= 0;
        @(posedge clk);
        mode    <= 1;
        l_valid <= 1;
        @(posedge finished);
        l_valid <= 0;
        // @(posedge clk);
        // @(posedge clk);
        // @(posedge clk);
        // @(posedge clk);
        // r_rdy      <= 1;
        // l_valid    <= 1;
        // @(posedge clk);
        
        // @(posedge clk);
        // @(posedge clk);
        


        
    end
    
    // task initiate_start;
    //     input [31:0] ref;
    // begin
    //     start_T <= 1;
    //     SHIFT_REF_1 <= ref;
    //     @(posedge clk);
    //     while (T_STATE != 2'd1) begin
    //         @(posedge clk);
    //     end
    //     start_T <= 0;
    // end
    // endtask

endmodule