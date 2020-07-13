`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: convolution unit test bench
// Module Name: conv_unit_tb.v
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

module conv_unit_tb();
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DATA_WIDTH = 16;
    parameter CLK_PERIOD = 10;

    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    reg                  clk    = 0;
    reg                  rstn   = 1;
    reg                  MA_en  = 0;
    reg                  T_en   = 0;
    reg [1:0]            A_sel  = 0;
    reg                  T_sel  = 1;
    reg                  dv_in  = 0;
    reg [DATA_WIDTH-1:0] bias   = 0;
    reg [DATA_WIDTH-1:0] d_in   = 0;
    reg [DATA_WIDTH-1:0] L_k_in = 0;
    reg [DATA_WIDTH-1:0] M_k_in = 0;
    reg [DATA_WIDTH-1:0] R_k_in = 0;
    reg [DATA_WIDTH-1:0] T3_in  = 0;

    wire [DATA_WIDTH-1:0] T1_out;
    wire [DATA_WIDTH-1:0] T2_out;
    wire [DATA_WIDTH-1:0] T3_out;

    wire [DATA_WIDTH-1:0] T1_in;
    wire [DATA_WIDTH-1:0] T2_in;

    assign T1_in = T2_out;
    assign T2_in = T3_out;


    ///////////////////////////////////// DUT Instantiations ////////////////////////////////////////////
    conv_unit #(
        .DATA_WIDTH(DATA_WIDTH)
    ) DUT (
        .clk(clk),
        .rstn(rstn),
        .MA_en(MA_en),
        .T_en(T_en),
        .A_sel(A_sel),
        .T_sel(T_sel),
        .dv_in(dv_in),
        .bias(bias),
        .d_in(d_in),
        .L_k_in(L_k_in),
        .M_k_in(M_k_in),
        .R_k_in(R_k_in),
        .T1_in(T1_in),
        .T2_in(T2_in),
        .T3_in(T3_in),
        .T1_out(T1_out),
        .T2_out(T2_out),
        .T3_out(T3_out)
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
        @(posedge clk);      // clearing adder
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0;
        T_sel  <= 1;
        d_in   <= 16'd15360;
        L_k_in <= 16'd16384;
        M_k_in <= 16'd16384;
        R_k_in <= 16'd16384;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 0 // column 0
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd2; // passing 0 to adder input 2
        T_sel  <= 1;
        d_in   <= 16'd15360;
        L_k_in <= 16'd15360;
        M_k_in <= 16'd16384;
        R_k_in <= 16'd48128;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 1 // column 0
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd16896;
        L_k_in <= 16'd49664;
        M_k_in <= 16'd16384;
        R_k_in <= 16'd0;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 2 // column 0
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd16896;
        L_k_in <= 16'd49664;
        M_k_in <= 16'd50432;
        R_k_in <= 16'd49664;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 0 // column 0 //channel 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd18176;
        L_k_in <= 16'd48128;
        M_k_in <= 16'd49664;
        R_k_in <= 16'd50432;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 1 // column 0 //channel 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd17408;
        L_k_in <= 16'd48128;
        M_k_in <= 16'd17408;
        R_k_in <= 16'd15360;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 2 // column 0 //channel 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd49152;
        L_k_in <= 16'd15360;
        M_k_in <= 16'd16896;
        R_k_in <= 16'd17408;
        T3_in  <= 16'd0;








        @(posedge clk);      // sel = 0 // column 1
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd51328;
        L_k_in <= 16'd15360;
        M_k_in <= 16'd16384;
        R_k_in <= 16'd48128;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 1 // column 1
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd1; // shift
        T_sel  <= 1;
        d_in   <= 16'd17664;
        L_k_in <= 16'd49664;
        M_k_in <= 16'd16384;
        R_k_in <= 16'd0;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 2 // column 1
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd49664;
        L_k_in <= 16'd49664;
        M_k_in <= 16'd50432;
        R_k_in <= 16'd49664;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 0 // column 1 //channel 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd17408;
        L_k_in <= 16'd48128;
        M_k_in <= 16'd49664;
        R_k_in <= 16'd50432;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 1 // column 1 //channel 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd16384;
        L_k_in <= 16'd48128;
        M_k_in <= 16'd17408;
        R_k_in <= 16'd15360;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 2 // column 1 //channel 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd51456;
        L_k_in <= 16'd15360;
        M_k_in <= 16'd16896;
        R_k_in <= 16'd17408;
        T3_in  <= 16'd0;








        @(posedge clk);      // sel = 0 // column 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd48128;
        L_k_in <= 16'd15360;
        M_k_in <= 16'd16384;
        R_k_in <= 16'd48128;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 1 // column 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd1; // shift
        T_sel  <= 1;
        d_in   <= 16'd17408;
        L_k_in <= 16'd49664;
        M_k_in <= 16'd16384;
        R_k_in <= 16'd0;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 2 // column 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd17664;
        L_k_in <= 16'd49664;
        M_k_in <= 16'd50432;
        R_k_in <= 16'd49664;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 0 // column 2 //channel 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd16384;
        L_k_in <= 16'd48128;
        M_k_in <= 16'd49664;
        R_k_in <= 16'd50432;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 1 // column 2 //channel 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd51456;
        L_k_in <= 16'd48128;
        M_k_in <= 16'd17408;
        R_k_in <= 16'd15360;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 2 // column 2 //channel 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd15360;
        L_k_in <= 16'd15360;
        M_k_in <= 16'd16896;
        R_k_in <= 16'd17408;
        T3_in  <= 16'd0;








        // @(posedge clk);      // sel = 0 // column 3
        // bias   <= 16'd16384;
        // dv_in  <= 1;
        // MA_en  <= 1;
        // T_en   <= 0;
        // A_sel  <= 2'd0; // self add
        // T_sel  <= 1;
        // d_in   <= 16'd48128;
        // L_k_in <= 16'd15360;
        // M_k_in <= 16'd16384;
        // R_k_in <= 16'd48128;
        // T3_in  <= 16'd0;

        // @(posedge clk);      // sel = 1 // column 3
        // bias   <= 16'd16384;
        // dv_in  <= 1;
        // MA_en  <= 1;
        // T_en   <= 0;
        // A_sel  <= 2'd1; // shift
        // T_sel  <= 1;
        // d_in   <= 16'd17408;
        // L_k_in <= 16'd49664;
        // M_k_in <= 16'd16384;
        // R_k_in <= 16'd0;
        // T3_in  <= 16'd0;

        // @(posedge clk);      // sel = 2 // column 3
        // bias   <= 16'd16384;
        // dv_in  <= 1;
        // MA_en  <= 1;
        // T_en   <= 0;
        // A_sel  <= 2'd0; // self add
        // T_sel  <= 1;
        // d_in   <= 16'd17664;
        // L_k_in <= 16'd49664;
        // M_k_in <= 16'd50432;
        // R_k_in <= 16'd49664;
        // T3_in  <= 16'd0;

        // @(posedge clk);      // sel = 0 // column 3 //channel 2
        // bias   <= 16'd16384;
        // dv_in  <= 1;
        // MA_en  <= 1;
        // T_en   <= 0;
        // A_sel  <= 2'd0; // self add
        // T_sel  <= 1;
        // d_in   <= 16'd16384;
        // L_k_in <= 16'd48128;
        // M_k_in <= 16'd49664;
        // R_k_in <= 16'd50432;
        // T3_in  <= 16'd0;

        // @(posedge clk);      // sel = 1 // column 3 //channel 2
        // bias   <= 16'd16384;
        // dv_in  <= 1;
        // MA_en  <= 1;
        // T_en   <= 0;
        // A_sel  <= 2'd0; // self add
        // T_sel  <= 1;
        // d_in   <= 16'd51456;
        // L_k_in <= 16'd48128;
        // M_k_in <= 16'd17408;
        // R_k_in <= 16'd15360;
        // T3_in  <= 16'd0;

        // @(posedge clk);      // sel = 2 // column 3 //channel 2
        // bias   <= 16'd16384;
        // dv_in  <= 1;
        // MA_en  <= 1;
        // T_en   <= 0;
        // A_sel  <= 2'd0; // self add
        // T_sel  <= 1;
        // d_in   <= 16'd15360;
        // L_k_in <= 16'd15360;
        // M_k_in <= 16'd16896;
        // R_k_in <= 16'd17408;
        // T3_in  <= 16'd0;











    @(posedge clk);      // sel = 0 // column 3
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd50944;
        L_k_in <= 16'd15360;
        M_k_in <= 16'd16384;
        R_k_in <= 16'd48128;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 1 // column 3
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 1;    // copy
        A_sel  <= 2'd1; // shift
        T_sel  <= 1;    // copy
        d_in   <= 16'd49664;
        L_k_in <= 16'd49664;
        M_k_in <= 16'd16384;
        R_k_in <= 16'd0;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 2 // column 3
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd16384;
        L_k_in <= 16'd49664;
        M_k_in <= 16'd50432;
        R_k_in <= 16'd49664;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 0 // column 3 //channel 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd49152;
        L_k_in <= 16'd48128;
        M_k_in <= 16'd49664;
        R_k_in <= 16'd50432;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 1 // column 3 //channel 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd50176;
        L_k_in <= 16'd48128;
        M_k_in <= 16'd17408;
        R_k_in <= 16'd15360;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 2 // column 3 //channel 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd49664;
        L_k_in <= 16'd15360;
        M_k_in <= 16'd16896;
        R_k_in <= 16'd17408;
        T3_in  <= 16'd0;










    @(posedge clk);      // sel = 0 // column 4
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd50944;
        L_k_in <= 16'd15360;
        M_k_in <= 16'd16384;
        R_k_in <= 16'd48128;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 1 // column 4
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 1;    // copy
        A_sel  <= 2'd1; // shift
        T_sel  <= 1;    // copy
        d_in   <= 16'd49664;
        L_k_in <= 16'd49664;
        M_k_in <= 16'd16384;
        R_k_in <= 16'd0;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 2 // column 4
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd16384;
        L_k_in <= 16'd49664;
        M_k_in <= 16'd50432;
        R_k_in <= 16'd49664;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 0 // column 4 //channel 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd49152;
        L_k_in <= 16'd48128;
        M_k_in <= 16'd49664;
        R_k_in <= 16'd50432;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 1 // column 4 //channel 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd50176;
        L_k_in <= 16'd48128;
        M_k_in <= 16'd17408;
        R_k_in <= 16'd15360;
        T3_in  <= 16'd0;

        @(posedge clk);      // sel = 2 // column 4 //channel 2
        bias   <= 16'd16384;
        dv_in  <= 1;
        MA_en  <= 1;
        T_en   <= 0;
        A_sel  <= 2'd0; // self add
        T_sel  <= 1;
        d_in   <= 16'd49664;
        L_k_in <= 16'd15360;
        M_k_in <= 16'd16896;
        R_k_in <= 16'd17408;
        T3_in  <= 16'd0;
        


        
    end
endmodule