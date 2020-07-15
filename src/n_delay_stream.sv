module n_delay_stream #(
    parameter N,
    parameter DATA_WIDTH,
    parameter TUSER_WIDTH
)(
    aclk,
    aresetn,
    aclken,

    data_in,
    valid_in,
    last_in,
    keep_in,
    user_in,

    data_out,
    valid_out,
    last_out,
    keep_out,
    user_out
);

    localparam TKEEP_WIDTH = DATA_WIDTH/8;

    input  wire                     aclk;
    input  wire                     aresetn;
    input  wire                     aclken;

    input  wire [DATA_WIDTH-1 : 0]  data_in;
    input  wire                     valid_in;
    input  wire                     last_in;
    input  wire [TKEEP_WIDTH-1 : 0] keep_in;
    input  wire [TUSER_WIDTH-1 : 0] user_in;

    output wire [DATA_WIDTH-1 : 0]   data_out;
    output wire                     valid_out;
    output wire                      last_out;
    output wire [TKEEP_WIDTH-1 : 0]  keep_out;
    output wire [TUSER_WIDTH-1 : 0]  user_out;

    n_delay #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH)
    )
    delay_data
    (
        .clk(aclk),
        .resetn(aresetn),
        .clken(aclken),

        .data_in(data_in),
        .data_out(data_out)
    );

    n_delay #(
        .N(N),
        .DATA_WIDTH(1)
    )
    delay_valid
    (
        .clk(aclk),
        .resetn(aresetn),
        .clken(aclken),

        .data_in(valid_in),
        .data_out(valid_out)
    );

    n_delay #(
        .N(N),
        .DATA_WIDTH(1)
    )
    delay_last
    (
        .clk(aclk),
        .resetn(aresetn),
        .clken(aclken),

        .data_in(last_in),
        .data_out(last_out)
    );

    n_delay #(
        .N(N),
        .DATA_WIDTH(TKEEP_WIDTH)
    )
    delay_keep
    (
        .clk(aclk),
        .resetn(aresetn),
        .clken(aclken),

        .data_in(keep_in),
        .data_out(keep_out)
    );

    n_delay #(
        .N(N),
        .DATA_WIDTH(TUSER_WIDTH)
    )
    delay_user
    (
        .clk(aclk),
        .resetn(aresetn),
        .clken(aclken),

        .data_in(user_in),
        .data_out(user_out)
    );



endmodule