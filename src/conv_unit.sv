/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.

Create Date: 11/07/2020
Design Name: AXIS Convolution unit
Tool Versions: Vivado 2018.2
Description:    * Fully pipelined
                * Supports (n x m) convolution kernel
                * tuser
                    0 : is_1x1
                    1 : is_max
                    2 : is_relu
                    3 : block_last
                    4 : cin_first

Dependencies: * Floating point IP
                    - name : floating_point_multiplier
              * Floating point IP
                    - name : 

Revision:
Revision 0.01 - File Created
Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////*/

/*
    MODULE HIERARCHY

    - AXIS_CONV_ENGINE (Shell)
        - AXIS_reg_slice
        - CONV_ENGINE
            - CONV_BLOCK                x 2
                - CONV_CORE             x 16
                    - CONV_UNIT         x 8
                        - mul        x 3
                        - acc        x 3
                        - mux        x 3
                        - reg        x 3
                    - weights_buffer
                      (step_buffer)
                        - reg    x 1
                        - reg    x   (A-1) + 1
                        - reg    x 2*(A-1) + 1
                    - bias_buffer
                        - reg        x 1
                - pixels_buffer
                    - step_buffer    x 8
                            - reg    x 1
                            - reg    x   (A-1) + 1
                            - reg    x 2*(A-1) + 1

    - AXIS_Output_Pipe
        - Core converter
        - Engine converter
    */

module conv_unit # (
    parameter DATA_WIDTH            = 16,
    parameter KERNEL_W_MAX          = 3,
    parameter TUSER_WIDTH           = 5,
    parameter ACCUMULATOR_DELAY     = 21,
    parameter MULTIPLIER_DELAY      = 6,

    parameter INDEX_IS_1x1          = 0,
    parameter INDEX_IS_MAX          = 1,
    parameter INDEX_IS_RELU         = 2,
    parameter INDEX_IS_BLOCKS_2     = 3
)(
    aclk,
    aclken,
    aresetn,

    s_valid,       
    s_data_pixels, 
    s_data_weights,
    s_data_bias,   
    s_ready,
    s_last,        
    s_user,        

    m_valid,
    m_data,
    m_last,
    m_user

);

    input  wire                      aclk;
    input  wire                      aclken;               
    input  wire                      aresetn;

    input  wire                      s_valid                              ;
    input  wire [DATA_WIDTH  - 1: 0] s_data_pixels                        ;
    input  wire [DATA_WIDTH  - 1: 0] s_data_weights [KERNEL_W_MAX - 1 : 0];
    input  wire [DATA_WIDTH  - 1: 0] s_data_bias                          ;
    output wire                      s_ready                              ;
    input  wire                      s_last                               ;
    input  wire [TUSER_WIDTH - 1: 0] s_user                               ;

    output wire                      m_valid       [KERNEL_W_MAX - 1 : 0];
    output wire [DATA_WIDTH  - 1: 0] m_data        [KERNEL_W_MAX - 1 : 0];
    output wire                      m_last        [KERNEL_W_MAX - 1 : 0];
    output wire [TUSER_WIDTH - 1: 0] m_user        [KERNEL_W_MAX - 1 : 0];


    /*
    ENABLE SIGNALS
    */
    wire    [KERNEL_W_MAX - 1 : 0] mux_sel;
    wire                           mux_sel_any;
    wire                           clken_mul;
    wire                           is_1x1;

    assign  mux_sel_none = !(|mux_sel);
    assign  clken_mul    = mux_sel_none && aclken;

    assign  is_1x1       = s_user[IS_1x1_INDEX];
    assign  s_ready     = clken_mul;

    /*
    BUFFER UNIT------------------------------------------------------
    */
    // Pixel Buffer

    wire                      buffer_m_valid_pixels [KERNEL_W_MAX - 1 : 0];
    wire [DATA_WIDTH  - 1: 0] buffer_m_data_pixels  [KERNEL_W_MAX - 1 : 0];
    wire                      buffer_m_last_pixels  [KERNEL_W_MAX - 1 : 0];
    wire [TUSER_WIDTH - 1: 0] buffer_m_user_pixels  [KERNEL_W_MAX - 1 : 0];

    wire [DATA_WIDTH  - 1: 0] buffer_s_data_pixels  [KERNEL_W_MAX - 1 : 0];
    wire [TUSER_WIDTH - 1: 0] buffer_s_user_pixels  [KERNEL_W_MAX - 1 : 0];

    genvar k;
    generate
        for (k=0 ; k < KERNEL_W_MAX; k = k + 1) begin: repeat_pixels_gen
            assign buffer_s_data_pixels [k] = s_data_pixels;
            assign buffer_s_user_pixels [k] = s_user;
        end
    endgenerate

    step_buffer  #(
        .DATA_WIDTH       (DATA_WIDTH),
        .STEPS            (KERNEL_W_MAX),
        .ACCUMULATOR_DELAY(ACCUMULATOR_DELAY),
        .TUSER_WIDTH      (TUSER_WIDTH)
    )
    step_buffer_pixels
    (
        .aclk       (aclk),
        .aclken     (clken_mul),
        .aresetn    (aresetn),
        .is_1x1     (is_1x1),
        
        .s_valid    ('{KERNEL_W_MAX{s_valid}}),
        .s_data     (buffer_s_data_pixels),
        .s_last     ('{KERNEL_W_MAX{s_last}}),
        .s_user     (buffer_s_user_pixels),

        .m_valid   (buffer_m_valid_pixels),
        .m_data    (buffer_m_data_pixels),
        .m_last    (buffer_m_last_pixels),
        .m_user    (buffer_m_user_pixels)
    );

    // Weights Buffer

    wire                      buffer_m_valid_weights[KERNEL_W_MAX - 1 : 0];
    wire [DATA_WIDTH  - 1: 0] buffer_m_data_weights [KERNEL_W_MAX - 1 : 0];

    step_buffer  #(
        .DATA_WIDTH       (DATA_WIDTH),
        .STEPS            (KERNEL_W_MAX),
        .ACCUMULATOR_DELAY(ACCUMULATOR_DELAY),
        .TUSER_WIDTH      (TUSER_WIDTH)
    )
    step_buffer_weights
    (
        .aclk       (aclk),
        .aclken     (clken_mul),
        .aresetn    (aresetn),
        .is_1x1     (is_1x1),
        
        .s_valid    ('{KERNEL_W_MAX{s_valid}}),
        .s_data     (s_data_weights),
        .s_last     ('{KERNEL_W_MAX{0}}),
        .s_user     ('{KERNEL_W_MAX{0}}),

        .m_valid   (buffer_m_valid_weights),
        .m_data    (buffer_m_data_weights),
        .m_last    (),
        .m_user    ()
    );

    wire                       buffer_m_valid_bias   [0 : 0];
    wire [DATA_WIDTH   - 1: 0] buffer_m_data_bias    [0 : 0];
    wire [TUSER_WIDTH  - 1: 0] buffer_m_user_bias    [0 : 0];

    wire [DATA_WIDTH   - 1: 0] buffer_s_data_bias    [0 : 0];
    wire [TUSER_WIDTH  - 1: 0] buffer_s_user_bias    [0 : 0];

    assign buffer_s_data_bias[0] = s_data_bias;

    step_buffer  #(
        .DATA_WIDTH       (DATA_WIDTH),
        .STEPS            (1),
        .ACCUMULATOR_DELAY(ACCUMULATOR_DELAY),
        .TUSER_WIDTH      (TUSER_WIDTH)
    )
    step_buffer_bias
    (
        .aclk       (aclk),
        .aclken     (clken_mul),
        .aresetn    (aresetn),
        .is_1x1     (1'b0),
        
        .s_valid    ('{1{s_valid}}),
        .s_data     (buffer_s_data_bias),
        .s_last     ('{1{0}}),
        .s_user     ('{1{s_user}}),

        .m_valid   (buffer_m_valid_bias),
        .m_data    (buffer_m_data_bias),
        // .m_last    (buffer_m_last_pixels),
        .m_user    (buffer_m_user_bias)
    );

    /*
    --------------------------------------------------------------------------
    */


    wire                        mul_m_valid [KERNEL_W_MAX - 1 : 0];
    wire   [DATA_WIDTH - 1 : 0] mul_m_data  [KERNEL_W_MAX - 1 : 0];
    wire                        mul_m_last  [KERNEL_W_MAX - 1 : 0];
    wire   [TUSER_WIDTH - 1: 0] mul_m_user  [TUSER_WIDTH  - 1 : 0];
    
    wire                        acc_s_valid [KERNEL_W_MAX - 1 : 0];
    wire   [DATA_WIDTH - 1 : 0] acc_s_data  [KERNEL_W_MAX - 1 : 0];
    wire                        acc_s_last  [KERNEL_W_MAX - 1 : 0];
    wire   [TUSER_WIDTH - 1: 0] acc_s_user  [TUSER_WIDTH  - 1 : 0];


    wire                        acc_m_valid [KERNEL_W_MAX - 1 : 0];
    wire   [DATA_WIDTH - 1 : 0] acc_m_data  [KERNEL_W_MAX - 1 : 0];
    wire                        acc_m_last  [KERNEL_W_MAX - 1 : 0];
    wire   [TUSER_WIDTH - 1: 0] acc_m_user  [KERNEL_W_MAX - 1 : 0];


    wire                        mux_s2_valid[KERNEL_W_MAX - 1 : 0];
    wire   [DATA_WIDTH - 1 : 0] mux_s2_data [KERNEL_W_MAX - 1 : 0];
    wire   [TUSER_WIDTH - 1: 0] mux_s2_user [KERNEL_W_MAX - 1 : 0];
    wire                        mux_m_valid [KERNEL_W_MAX - 1 : 0];


    genvar i;
    generate

        // Bias Delay

        wire                       mul_1_delay_m_valid_bias   ;
        wire [DATA_WIDTH   - 1: 0] mul_1_delay_m_data_bias    ;
        wire [TUSER_WIDTH  - 1: 0] mul_1_delay_m_user_bias    ;

        wire                       mul_delay_m_valid_bias   ;
        wire [DATA_WIDTH   - 1: 0] mul_delay_m_data_bias    ;
        wire [TUSER_WIDTH  - 1: 0] mul_delay_m_user_bias    ;

        n_delay_stream #(
            .N (MULTIPLIER_DELAY-1),
            .DATA_WIDTH     (DATA_WIDTH),
            .TUSER_WIDTH    (TUSER_WIDTH)
        )
        bias_mul_1_hold
        (
            .aclk    (aclk),
            .aclken  (clken_mul),
            .aresetn (aresetn),

            .valid_in(buffer_m_valid_bias[0]),
            .data_in (buffer_m_data_bias[0]),
            .keep_in (0),
            .last_in (0),
            .user_in (buffer_m_user_bias[0]),

            .valid_out(mul_1_delay_m_valid_bias),
            .data_out(mul_1_delay_m_data_bias ),
            .keep_out(),
            .last_out(),
            .user_out(mul_1_delay_m_user_bias)
        );

        n_delay_stream #(
            .N (1),
            .DATA_WIDTH     (DATA_WIDTH),
            .TUSER_WIDTH    (TUSER_WIDTH)
        )
        bias_mul_hold_data_valid
        (
            .aclk    (aclk),
            .aclken  (clken_mul),
            .aresetn (aresetn),

            .valid_in(mul_1_delay_m_valid_bias),
            .data_in (mul_1_delay_m_data_bias),
            .keep_in (0),
            .last_in (0),
            .user_in (mul_1_delay_m_user_bias),

            .valid_out(mul_delay_m_valid_bias),
            .data_out (mul_delay_m_data_bias),
            .keep_out (),
            .last_out (),
            .user_out (mul_delay_m_user_bias)
        );

        for (i=0; i < KERNEL_W_MAX; i++) begin : multipliers_gen

            n_delay_stream #(
                .N(MULTIPLIER_DELAY),
                .DATA_WIDTH(DATA_WIDTH),
                .TUSER_WIDTH(TUSER_WIDTH)
            )
            dummy_multiplier
            (
                .aclk       (aclk),
                .aclken     (clken_mul),
                .aresetn    (aresetn),

                .valid_in   (buffer_m_valid_pixels  [i]),
                .data_in    (buffer_m_data_pixels   [i]),
                .keep_in    (1),
                .last_in    (buffer_m_last_pixels   [i]),
                .user_in    (buffer_m_user_pixels   [i]),

                .valid_out  (mul_m_valid    [i]),
                .data_out   (mul_m_data     [i]),
                .keep_out   (),
                .last_out   (mul_m_last     [i]),
                .user_out   (mul_m_user     [i])
            );

        end

        for (i=0; i < KERNEL_W_MAX; i++) begin : accumulators_gen

            n_delay_stream #(
                .N(ACCUMULATOR_DELAY),
                .DATA_WIDTH(DATA_WIDTH),
                .TUSER_WIDTH(TUSER_WIDTH)
            )
            dummy_accumulator
            (
                .aclk       (aclk),
                .aclken     (aclken),
                .aresetn    (aresetn),

                .valid_in   (acc_s_valid    [i]),
                .data_in    (acc_s_data     [i]),
                .keep_in    (1),
                .last_in    (acc_s_last     [i]),
                .user_in    (acc_s_user     [i]),

                .valid_out  (acc_m_valid    [i]),
                .data_out   (acc_m_data     [i]),
                .keep_out   (),
                .last_out   (acc_m_last     [i]),
                .user_out   (acc_m_user     [i])
            );
            
        end

        /*
        SEL BITS
        */

        // SEL[0]
        wire update_switch_0;
        assign update_switch_0 = aclken && mul_1_delay_m_valid_bias;

        register #(
            .WORD_WIDTH     (DATA_WIDTH),
            .RESET_VALUE    (0)
        )
        bias_mul_is_first
        (
            .clock          (aclk                                        ),
            .clock_enable   (update_switch_0                             ),
            .resetn         (aresetn                                     ),
            .data_in        (mul_1_delay_m_user_bias [IS_CIN_FIRST_INDEX]),
            .data_out       (mux_sel                 [0]                 )
        );

        //SEL[1,2]

        for (i=1; i < KERNEL_W_MAX; i++) begin : sel_regs_gen

            wire   update_switch;
            assign update_switch = acc_s_valid[i] && aclken;
            
            wire  sel_in;
            assign sel_in = mul_m_last [i];
            
            register #(
                .WORD_WIDTH     (DATA_WIDTH),
                .RESET_VALUE    (0)
            )
            sel_registers
            (
                .clock          (aclk),
                .clock_enable   (update_switch),
                .resetn         (aresetn),
                .data_in        (sel_in        ),
                .data_out       (mux_sel    [i])
            );
        end

        // MUX inputs

        assign mux_s2_valid  [0]    = mul_delay_m_valid_bias   ;
        assign mux_s2_data   [0]    = mul_delay_m_data_bias    ;
        assign mux_s2_user   [0]    = mul_delay_m_user_bias    ;

        for (i=1; i < KERNEL_W_MAX; i++) begin : mul_s2

            assign mux_s2_valid  [i]    = acc_m_valid   [i-1] && acc_m_tlast  [i-1];
            assign mux_s2_data   [i]    = acc_m_data    [i-1];
            assign mux_s2_user   [i]    = acc_m_user    [i-1];

        end

        // Muxes

        for (i=0; i < KERNEL_W_MAX; i++) begin : mux_gen

            assign acc_s_valid [i] = mux_m_valid[i] && (mux_sel[i] || mux_sel_none);

            axis_mux #(
                .DATA_WIDTH(DATA_WIDTH),
                .TUSER_WIDTH(TUSER_WIDTH)
            )
            mux
            (
                .sel                (mux_sel        [i]),

                .S0_AXIS_tvalid     (mul_m_valid    [i]),
                .S0_AXIS_tready     (                  ),
                .S0_AXIS_tdata      (mul_m_data     [i]),
                .S0_AXIS_tkeep      (0                 ),
                .S0_AXIS_tlast      (mul_m_last     [i]),
                .S0_AXIS_tuser      (mul_m_user     [i]),

                .S1_AXIS_tvalid     (mux_s2_valid   [i]),
                .S1_AXIS_tready     (                  ),
                .S1_AXIS_tdata      (mux_s2_data    [i]), 
                .S1_AXIS_tkeep      (0                 ),
                .S1_AXIS_tlast      (0                 ),
                .S1_AXIS_tuser      (mux_s2_user    [i]),

                .M_AXIS_tvalid      (mux_m_valid    [i]),
                .M_AXIS_tready      (1                 ),
                .M_AXIS_tdata       (acc_s_data     [i]),
                .M_AXIS_tkeep       (                  ),
                .M_AXIS_tlast       (acc_s_last     [i]),
                .M_AXIS_tuser       (acc_m_user     [i])
            );
        end

    endgenerate

    assign m_valid = acc_m_valid;
    assign m_data  = acc_m_data ;
    assign m_last  = acc_m_last ;
    assign m_user  = acc_m_user ;
    
endmodule

