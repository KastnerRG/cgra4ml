module n_delay #(
    parameter N,
    parameter WORD_WIDTH,
    parameter LOCAL = 0
)(
    clk,
    resetn,
    clken,
    data_in,
    data_out
);

    input  wire                     clk;
    input  wire                     clken;
    input  wire                     resetn;
    input  wire [WORD_WIDTH-1 : 0]  data_in;
    output wire [WORD_WIDTH-1 : 0]  data_out;

    wire        [WORD_WIDTH-1 : 0]  data        [(N+1)-1:   0];

    assign data     [0] = data_in;
    assign data_out     = data[(N+1)-1];

    genvar i;
    generate
        for (i=0 ; i < N; i++) begin: delay_reg_gen
            register
            #(
                .WORD_WIDTH     (WORD_WIDTH),
                .RESET_VALUE    (0),
                .LOCAL          (LOCAL)
            )
            m_data_reg
            (
                .clock          (clk),
                .clock_enable   (clken),
                .resetn         (resetn),
                .data_in        (data[i]),
                .data_out       (data[i+1])
            );
        end
    endgenerate

endmodule