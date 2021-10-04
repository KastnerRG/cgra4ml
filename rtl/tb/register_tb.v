`timescale 1ns / 1ps

module register_tb();

    localparam CLK_PERIOD =100;
    localparam WORD_WIDTH = 8;
    localparam RESET_VALUE = 8;

    reg                     clock           = 0;
    reg                     clock_enable    = 1;
    reg                     resetn          = 1;
    
    reg     [WORD_WIDTH-1   :0] data_in     = 5;
    wire    [WORD_WIDTH-1   :0] data_out;


    register
    #(
        .WORD_WIDTH (WORD_WIDTH),
        .RESET_VALUE(RESET_VALUE)
    )
    register_dut
    (
        .clock(clock),
        .clock_enable(clock_enable),
        .resetn(resetn),
        .data_in(data_in),
        .data_out(data_out)
    );

    always begin
        #(CLK_PERIOD/2);
        clock <= ~clock;
    end

    initial begin
        @(posedge clock)
        #(CLK_PERIOD*3)
        @(posedge clock)

        data_in     <= 8;

        @(posedge clock)
        data_in     <= 9;

        @(posedge clock)
        data_in     <= 10;
        @(posedge clock)
        @(posedge clock)

        resetn       <= 0;
        data_in     <= 11;

        @(posedge clock)
        @(posedge clock)
        
        resetn       <= 1;

        @(posedge clock)
        data_in     <= 12;
        @(posedge clock)
        data_in     <= 13;

    end

endmodule