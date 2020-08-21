module fixed_point_accumulator_wrapper #(
    parameter DATA_WIDTH,
    parameter TUSER_WIDTH,
    parameter ACCUMULATOR_DELAY = 2
)(
    aclk,
    aclken,
    aresetn,

    valid_in,
    data_in,
    last_in,
    user_in,

    valid_out,
    data_out,
    last_out,
    user_out
);

    localparam TKEEP_WIDTH = DATA_WIDTH/8;

    input  wire                     aclk;
    input  wire                     aresetn;
    input  wire                     aclken;

    input  wire [DATA_WIDTH-1 : 0]  data_in;
    input  wire                     valid_in;
    input  wire                     last_in;
    input  wire [TUSER_WIDTH-1 : 0] user_in;

    output wire [DATA_WIDTH-1 : 0]  data_out;
    output wire                     valid_out;
    output wire                     last_out;
    output wire [TUSER_WIDTH-1 : 0] user_out;

    wire first_bypass;

    register #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (0)
    )
    acc_tlast_delay
    (
        .clock          (aclk),
        .clock_enable   (valid_in),
        .resetn         (aresetn),
        .data_in        (last_in),
        .data_out       (first_bypass)
    );

    // AND the input with valid such that invalid inputs are zeroed and accumulated
    fixed_point_accumulator accumulator (
        .B      (data_in & {DATA_WIDTH{valid_in}}),  // input wire [15 : 0] B
        .CLK    (aclk                            ),  // input wire CLK
        .CE     (aclken                          ),  // input wire CE
        .BYPASS (first_bypass                    ),  // input wire BYPASS
        .Q      (data_out                        )   // output wire [15 : 0] Q
    );    
    
    n_delay_stream #(
        .N              (ACCUMULATOR_DELAY),
        .DATA_WIDTH     (DATA_WIDTH       ),
        .TUSER_WIDTH    (TUSER_WIDTH      )
    )
    delay_others
    (
        .aclk       (aclk     ),
        .aclken     (aclken   ),
        .aresetn    (aresetn  ),

        .valid_in   (valid_in ),
        .last_in    (last_in  ),
        .user_in    (user_in  ),

        .valid_out  (valid_out),
        .last_out   (last_out ),
        .user_out   (user_out )
    );

endmodule

module fixed_point_multiplier_wrapper #(
    parameter DATA_WIDTH,
    parameter TUSER_WIDTH,
    parameter MULTIPLIER_DELAY = 3
)(
    aclk,
    aclken,
    aresetn,

    valid_in_1,
    data_in_1,
    last_in_1,
    user_in_1,

    valid_in_2,
    data_in_2,

    valid_out,
    data_out,
    last_out,
    user_out
);

    localparam TKEEP_WIDTH = DATA_WIDTH/8;

    input  wire                     aclk;
    input  wire                     aresetn;
    input  wire                     aclken;

    input  wire [DATA_WIDTH-1 : 0]  data_in_1;
    input  wire                     valid_in_1;
    input  wire                     last_in_1;
    input  wire [TUSER_WIDTH-1 : 0] user_in_1;

    input  wire [DATA_WIDTH-1 : 0]  data_in_2;
    input  wire                     valid_in_2;

    output wire [DATA_WIDTH-1 : 0]  data_out;
    output wire                     valid_out;
    output wire                     last_out;
    output wire [TUSER_WIDTH-1 : 0] user_out;


    wire                            mul_valid_in ;
    wire [DATA_WIDTH-1:0]           mul_data_in  ;

    assign mul_valid_in = valid_in_1 && valid_in_2;

    fixed_point_multiplier multiplier (
    .CLK    (aclk     ),      // input wire CLK
    .A      (data_in_1),      // input wire [15 : 0] A
    .B      (data_in_2),      // input wire [15 : 0] B
    .CE     (aclken   ),      // input wire CE
    .P      (data_out )       // output wire [15 : 0] P
    );

    n_delay_stream #(
        .N          (MULTIPLIER_DELAY),
        .DATA_WIDTH (DATA_WIDTH      ),
        .TUSER_WIDTH(TUSER_WIDTH     )
    )
    delay_others
    (
        .aclk       (aclk),
        .aclken     (aclken),
        .aresetn    (aresetn),

        .valid_in   (mul_valid_in),
        .last_in    (last_in_1),
        .user_in    (user_in_1),

        .valid_out  (valid_out),
        .last_out   (last_out),
        .user_out   (user_out)
    );


endmodule