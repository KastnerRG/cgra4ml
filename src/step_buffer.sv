module step_buffer  #(
    parameter DATA_WIDTH       ,
    parameter STEPS            ,
    parameter ACCUMULATOR_DELAY,
    parameter TUSER_WIDTH      
)(
    aclk,
    aclken,
    aresetn,

    is_1x1,

    s_valid,
    s_data,
    s_last,
    s_user,

    m_valid,
    m_data,
    m_last,
    m_user
);

    input  wire aclk;
    input  wire aclken;
    input  wire aresetn;
    input  wire is_1x1;
  
    // N-delay'i slaves

    input wire                      s_valid   [STEPS-1 : 0];
    input wire [DATA_WIDTH  - 1: 0] s_data    [STEPS-1 : 0];
    input wire                      s_last    [STEPS-1 : 0];
    input wire [TUSER_WIDTH - 1: 0] s_user    [STEPS-1 : 0];

    // Hold'i master
    
    output wire                      m_valid [STEPS-1 : 0];
    output wire [DATA_WIDTH  - 1: 0] m_data  [STEPS-1 : 0];
    output wire                      m_last  [STEPS-1 : 0];
    output wire [TUSER_WIDTH - 1: 0] m_user  [STEPS-1 : 0];
    
    // N-delay'i master

    wire                      delay_m_valid   [STEPS-1 : 0];
    wire [DATA_WIDTH  - 1: 0] delay_m_data    [STEPS-1 : 0];
    wire                      delay_m_last    [STEPS-1 : 0];
    wire [TUSER_WIDTH - 1: 0] delay_m_user    [STEPS-1 : 0];

    // Hold'i slave

    wire                      hold_s_valid   [STEPS-1 : 1];
    wire [DATA_WIDTH  - 1: 0] hold_s_data    [STEPS-1 : 1];
    wire                      hold_s_last    [STEPS-1 : 1];
    wire [TUSER_WIDTH - 1: 0] hold_s_user    [STEPS-1 : 1];



    genvar i;
    generate

        // DELAYS for i > 0:    i*(ACCUMULATOR_DELAY-1)-(i-1)-1 = i*(ACCUMULATOR_DELAY-2)

        for (i=1 ;  i < STEPS;  i = i+1) begin : delays_gen
            
            localparam DELAY = i * (ACCUMULATOR_DELAY-2);

            n_delay_stream #(
                .N              (DELAY),
                .DATA_WIDTH     (DATA_WIDTH),
                .TUSER_WIDTH    (TUSER_WIDTH)
            )
            n_delay_stream_unit
            (
                .aclk           (aclk),
                .aclken         (aclken),
                .aresetn        (aresetn),
                .valid_in       (s_valid        [i]),
                .data_in        (s_data         [i]),
                .last_in        (s_last         [i]),
                .user_in        (s_user         [i]),
                .valid_out      (delay_m_valid  [i]),
                .data_out       (delay_m_data   [i]),
                .last_out       (delay_m_last   [i]),
                .user_out       (delay_m_user   [i])
            );
        end

        // Muxes for i > 0

        for (i=1 ;  i < STEPS;  i = i+1) begin : hold_muxes_gen

            assign hold_s_valid [i] = (is_1x1==0) ? delay_m_valid [i] : s_valid [i];
            assign hold_s_data  [i] = (is_1x1==0) ? delay_m_data  [i] : s_data  [i];
            assign hold_s_last  [i] = (is_1x1==0) ? delay_m_last  [i] : s_last  [i];
            assign hold_s_user  [i] = (is_1x1==0) ? delay_m_user  [i] : s_user  [i];
        end

        // Hold regs for i > 0

        for (i=1 ;  i < STEPS;  i = i+1) begin : hold_regs_gen

            n_delay_stream #(
                .N              (1),
                .DATA_WIDTH     (DATA_WIDTH),
                .TUSER_WIDTH    (TUSER_WIDTH)
            )
            n_delay_stream_unit
            (
                .aclk           (aclk),
                .aclken         (aclken),
                .aresetn        (aresetn),
                .valid_in       (hold_s_valid   [i]),
                .data_in        (hold_s_data    [i]),
                .last_in        (hold_s_last    [i]),
                .user_in        (hold_s_user    [i]),
                .valid_out      (m_valid        [i]),
                .data_out       (m_data         [i]),
                .last_out       (m_last         [i]),
                .user_out       (m_user         [i])
            );

        end

        assign m_valid[0] = s_valid [0];
        assign m_data [0] = s_data  [0];
        assign m_last [0] = s_last  [0];
        assign m_user [0] = s_user  [0];

    endgenerate



endmodule