module dummy_accumulator #(
    parameter ACCUMULATOR_DELAY,
    parameter DATA_WIDTH,
    parameter TUSER_WIDTH
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

    output wire [DATA_WIDTH-1 : 0]   data_out;
    output wire                     valid_out;
    output wire                      last_out;
    output wire [TUSER_WIDTH-1 : 0]  user_out;

    wire clear;

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
        .data_out       (clear)
    );
    
    wire                     acc_hold_m_valid;
    wire [DATA_WIDTH-1  : 0] acc_hold_m_data ;
    wire                     acc_hold_m_last ;
    wire [TUSER_WIDTH-1 : 0] acc_hold_m_user ;

    reg [DATA_WIDTH-1  : 0] acc_data_in;

    always @(*) begin
        if (clear)
            if (valid_in)
                acc_data_in <= data_in;
            else
                acc_data_in <= 0;
        else 
            if (valid_in)
                acc_data_in <= data_in + acc_hold_m_data;
            else
                acc_data_in <= acc_hold_m_data;
    end

    n_delay_stream #(
        .N(1),
        .DATA_WIDTH(DATA_WIDTH),
        .TUSER_WIDTH(TUSER_WIDTH)
    )
    dummy_accumulator_1
    (
        .aclk       (aclk),
        .aclken     (aclken),
        .aresetn    (aresetn),

        .valid_in   (valid_in ),
        .data_in    (acc_data_in),
        .keep_in    (1),
        .last_in    (last_in ),
        .user_in    (user_in ),

        .valid_out  (acc_hold_m_valid    ),
        .data_out   (acc_hold_m_data     ),
        .keep_out   (),
        .last_out   (acc_hold_m_last     ),
        .user_out   (acc_hold_m_user     )
    );      
    
    n_delay_stream #(
        .N(ACCUMULATOR_DELAY-1),
        .DATA_WIDTH(DATA_WIDTH),
        .TUSER_WIDTH(TUSER_WIDTH)
    )
    dummy_accumulator_N_1
    (
        .aclk       (aclk),
        .aclken     (aclken),
        .aresetn    (aresetn),

        .valid_in   (acc_hold_m_valid    ),
        .data_in    (acc_hold_m_data     ),
        .keep_in    (1),
        .last_in    (acc_hold_m_last     ),
        .user_in    (acc_hold_m_user     ),

        .valid_out  (valid_out),
        .data_out   (data_out ),
        .keep_out   (),
        .last_out   (last_out ),
        .user_out   (user_out )
    );

endmodule

module dummy_multiplier #(
    parameter MULTIPLIER_DELAY,
    parameter DATA_WIDTH,
    parameter TUSER_WIDTH
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

    wire                    mul_valid_in ;
    wire [DATA_WIDTH-1:0]   mul_data_in  ;

    assign mul_valid_in = valid_in_1 && valid_in_2;
    assign mul_data_in  = {DATA_WIDTH{mul_valid_in}} & (data_in_1 * data_in_2);

    n_delay_stream #(
        .N(MULTIPLIER_DELAY),
        .DATA_WIDTH(DATA_WIDTH),
        .TUSER_WIDTH(TUSER_WIDTH)
    )
    dummy_multiplier
    (
        .aclk       (aclk),
        .aclken     (aclken),
        .aresetn    (aresetn),

        .valid_in   (mul_valid_in),
        .data_in    (mul_data_in),
        .keep_in    (1),
        .last_in    (last_in_1),
        .user_in    (user_in_1),

        .valid_out  (valid_out),
        .data_out   (data_out),
        .keep_out   (),
        .last_out   (last_out),
        .user_out   (user_out)
    );

endmodule