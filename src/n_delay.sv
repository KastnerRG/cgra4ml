module n_delay #(
    parameter N,
    parameter DATA_WIDTH
)(
    clk,
    resetn,
    clken,
    data_in,
    data_out
);

    input  wire                     clk;
    input  wire                     resetn;
    input  wire                     clken;
    input  wire [DATA_WIDTH-1 : 0]  data_in;
    output wire [DATA_WIDTH-1 : 0]  data_out;

    wire        [DATA_WIDTH-1 : 0]  data        [(N+1)-1:   0];

    assign data     [0] = data_in;
    assign data_out     = data[(N+1)-1];

    genvar i;
    generate
        for (i=0 ; i < N; i++) begin: delay_reg_gen
            register
            #(
                .WORD_WIDTH     (DATA_WIDTH),
                .RESET_VALUE    (0)
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