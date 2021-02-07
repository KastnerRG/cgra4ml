`timescale 1ns / 1ps

module n_delay_tb();
    parameter N = 5;
    parameter DATA_WIDTH = 8;
    parameter CLK_PERIOD = 10;

    reg                     clk     = 0;
    reg                     resetn  = 1;
    reg                     clken   = 0;
    reg  [DATA_WIDTH-1 : 0] data_in = 0;

    wire [DATA_WIDTH-1 : 0] data_out;

    n_delay #(
        .N(5),
        .DATA_WIDTH(DATA_WIDTH)
    )
    n_delay_dut
    (
        .clk(clk),
        .resetn(resetn),
        .clken(clken),
        .data_in(data_in),
        .data_out(data_out)
    );

    always begin
        #(CLK_PERIOD/2);
        clk <= ~clk;
    end

    integer n = 0;
    integer k = 0;

    initial begin
        for (n=0; n < 100; n=n+1) begin
            @(posedge clk);
            n <= n+1;

            if (n>5 && n<10) begin
                k       <= k + 1;
                data_in <= k;
                clken   <= 1;
            end
            else if (n>15 && n<20) begin
                k       <= k + 1;
                data_in <= k;
                clken   <= 0;
            end
            else if (n>25 && n<30) begin
                clken   <= 1;
            end
            else if (n>35 && n<100) begin
                k       <= k + 1;
                data_in <= k;
                clken   <= 1;
            end
            else begin
                clken   <= 0;
            end

        end
    end

endmodule