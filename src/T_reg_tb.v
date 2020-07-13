`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: T registers test bench
// Module Name: T_reg_tb.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: A special register that can be configured as a shift register and a storing register
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module T_reg_tb();
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DATA_WIDTH = 16;
    parameter CLK_PERIOD = 10;

    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    reg                  clk        = 0;
    reg                  en         = 0;
    reg                  T_sel      = 0;
    reg                  T_en       = 0;
    reg [DATA_WIDTH-1:0] L_addr_out = 0;
    reg [DATA_WIDTH-1:0] M_addr_out = 0;
    reg [DATA_WIDTH-1:0] R_addr_out = 0;

    wire [DATA_WIDTH-1:0] T1_in;
    wire [DATA_WIDTH-1:0] T1_out;
    wire [DATA_WIDTH-1:0] T2_in;
    reg  [DATA_WIDTH-1:0] T3_in = 0;

    ///////////////////////////////////// DUT Instantiations ////////////////////////////////////////////
    // T1 register
    T_reg T1(
        .clk(clk),
        .en(T_en),
        .sel(T_sel), 
        .d_in_1(T1_in),
        .d_in_2(L_addr_out),
        .d_out(T1_out)
    );

    // T2 register
    T_reg T2(
        .clk(clk),
        .en(T_en),
        .sel(T_sel), 
        .d_in_1(T2_in),
        .d_in_2(M_addr_out),
        .d_out(T1_in)
    );

    // T3 register
    T_reg T3(
        .clk(clk),
        .en(T_en),
        .sel(T_sel), 
        .d_in_1(T3_in),
        .d_in_2(R_addr_out),
        .d_out(T2_in)
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
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        T_en <= 1;
        {R_addr_out,M_addr_out,L_addr_out} <= {16'd16896,16'd16384,16'd15360};
        T_sel <= 1;
        // x_in <= {16'd18688,16'd18560,16'd18432,16'd18176,16'd17920,16'd17664,16'd17408,16'd16896,16'd16384,16'd15360};
        @(posedge clk);
        {R_addr_out,M_addr_out,L_addr_out} <= {16'd17920,16'd17664,16'd17408};
        T_sel <= 1;
        @(posedge clk);
        T_en <= 0;
        {R_addr_out,M_addr_out,L_addr_out} <= {16'd18560,16'd18432,16'd18176};
        @(posedge clk);
        T3_in <= 16'd24532;
        T_en  <= 1;
        T_sel <= 0;
        @(posedge clk);
        T_en <= 0;
        @(posedge clk);
        T_en <= 0;
        @(posedge clk);
        T_en <= 1;
    end
endmodule