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

    v_s_valid,
    v_s_data,
    v_s_last,
    v_s_user,

    v_m_tvalid,
    v_m_tdata,
    v_m_tlast,
    v_m_tuser
);

    input  wire aclk;
    input  wire aclken;
    input  wire aresetn;
    input  wire is_1x1;

    input  wire [STEPS               - 1: 0] v_s_valid;
    input  wire [STEPS * DATA_WIDTH  - 1: 0] v_s_data;
    input  wire [STEPS               - 1: 0] v_s_last;
    input  wire [STEPS * TUSER_WIDTH - 1: 0] v_s_user;

    output wire [STEPS               - 1: 0] v_m_tvalid;
    output wire [STEPS * DATA_WIDTH  - 1: 0] v_m_tdata;
    output wire [STEPS               - 1: 0] v_m_tlast;
    output wire [STEPS * TUSER_WIDTH - 1: 0] v_m_tuser;



    
    // N-delay'i slaves

    wire                      s_valid   [STEPS-1 : 0];
    wire [DATA_WIDTH  - 1: 0] s_data    [STEPS-1 : 0];
    wire                      s_last    [STEPS-1 : 0];
    wire [TUSER_WIDTH - 1: 0] s_user    [STEPS-1 : 0];
    
    // N-delay'i master

    wire                      delay_m_valid   [STEPS-1 : 0];
    wire [DATA_WIDTH  - 1: 0] delay_m_data    [STEPS-1 : 0];
    wire                      delay_m_last    [STEPS-1 : 0];
    wire [TUSER_WIDTH - 1: 0] delay_m_user    [STEPS-1 : 0];

    // Hold'i slave

    wire                      hold_s_valid   [STEPS-1 : 0];
    wire [DATA_WIDTH  - 1: 0] hold_s_data    [STEPS-1 : 0];
    wire                      hold_s_last    [STEPS-1 : 0];
    wire [TUSER_WIDTH - 1: 0] hold_s_user    [STEPS-1 : 0];

    // Hold'i master
    
    wire                      m_valid   [STEPS-1 : 0];
    wire [DATA_WIDTH  - 1: 0] m_data    [STEPS-1 : 0];
    wire                      m_last    [STEPS-1 : 0];
    wire [TUSER_WIDTH - 1: 0] m_user    [STEPS-1 : 0];

    genvar i;
    generate

        // Direct connections for i = 0

        assign hold_s_valid[0] = s_valid [0];
        assign hold_s_data [0] = s_data  [0];
        assign hold_s_last [0] = s_last  [0];
        assign hold_s_user [0] = s_user  [0];

        // DELAYS for i > 0: i * (ACCUMULATOR_DELAY-1)

        for (i=1 ;  i < STEPS;  i = i+1) begin : delays_gen
            n_delay #(
                .N          (i * (ACCUMULATOR_DELAY-1)),
                .DATA_WIDTH (1)   
            )
            delay_valid
            (
                .clk        (aclk),
                .resetn     (aresetn),
                .clken      (aclken),
                .data_in    (s_valid        [i]),
                .data_out   (delay_m_valid  [i])
            );

            n_delay #(
                .N          (i * (ACCUMULATOR_DELAY-1)),
                .DATA_WIDTH (DATA_WIDTH)   
            )
            delay_data
            (
                .clk        (aclk),
                .resetn     (aresetn),
                .clken      (aclken),
                .data_in    (s_data         [i]),
                .data_out   (delay_m_data   [i])
            );

            n_delay #(
                .N          (i * (ACCUMULATOR_DELAY-1)),
                .DATA_WIDTH (1)   
            )
            delay_last
            (
                .clk        (aclk),
                .resetn     (aresetn),
                .clken      (aclken),
                .data_in    (s_last         [i]),
                .data_out   (delay_m_last   [i])
            );

            n_delay #(
                .N          (i * (ACCUMULATOR_DELAY-1)),
                .DATA_WIDTH (TUSER_WIDTH)   
            )
            delay_user
            (
                .clk        (aclk),
                .resetn     (aresetn),
                .clken      (aclken),
                .data_in    (s_user         [i]),
                .data_out   (delay_m_user   [i])
            );
        end

        // Muxes for i > 0

        for (i=1 ;  i < STEPS;  i = i+1) begin : hold_muxes_gen

            assign hold_s_valid[i] = (is_1x1==0) ? delay_m_valid [i] : s_valid [i];
            assign hold_s_data [i] = (is_1x1==0) ? delay_m_data  [i] : s_data  [i];
            assign hold_s_last [i] = (is_1x1==0) ? delay_m_last  [i] : s_last  [i];
            assign hold_s_user [i] = (is_1x1==0) ? delay_m_user  [i] : s_user  [i];

        end

        // Hold registers for all i

        for (i=0 ;  i < STEPS;  i = i+1) begin : hold_regs_gen
            register #(
                .WORD_WIDTH     (1),
                .RESET_VALUE    (0)
            )
            hold_valid
            (
                .clock          (aclk),
                .clock_enable   (aclken),
                .resetn         (aresetn),
                .data_in        (hold_s_valid   [i]),
                .data_out       (m_valid        [i])
            );

            register #(
                .WORD_WIDTH     (DATA_WIDTH),
                .RESET_VALUE    (0)
            )
            hold_data
            (
                .clock          (aclk),
                .clock_enable   (aclken),
                .resetn         (aresetn),
                .data_in        (hold_s_data    [i]),
                .data_out       (m_data         [i])
            );

            register #(
                .WORD_WIDTH     (1),
                .RESET_VALUE    (0)
            )
            hold_last
            (
                .clock          (aclk),
                .clock_enable   (aclken),
                .resetn         (aresetn),
                .data_in        (hold_s_last    [i]),
                .data_out       (m_last         [i])
            );

            register #(
                .WORD_WIDTH     (TUSER_WIDTH),
                .RESET_VALUE    (0)
            )
            hold_user
            (
                .clock          (aclk),
                .clock_enable   (aclken),
                .resetn         (aresetn),
                .data_in        (hold_s_user    [i]),
                .data_out       (m_user         [i])
            );
        end
    endgenerate



endmodule