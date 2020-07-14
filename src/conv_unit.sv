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
    parameter DATA_WIDTH   = 16,
    parameter KERNEL_W_MAX = 3,
    parameter TUSER_WIDTH  = 5,
    parameter ACCUMULATOR_DELAY = 21
)(
    aclk,
    aclken,
    aresetn,

    s_valid,       
    s_data_pixels, 
    s_data_weights,
    s_data_bias,   
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
    input  wire                      s_last                               ;
    input  wire [TUSER_WIDTH - 1: 0] s_user                               ;

    output wire                      m_valid                             ;
    output wire [DATA_WIDTH  - 1: 0] m_data        [KERNEL_W_MAX - 1 : 0];
    output wire                      m_last                              ;
    output wire [TUSER_WIDTH - 1: 0] m_user                              ;


    /*
    ENABLE SIGNALS
    */
    wire    mux_sel     [KERNEL_W_MAX - 1 : 0];
    wire    clken_mul;
    wire    is_1x1;

    assign  clken_mul = mux_sel[0] && aclken;
    assign  is_1x1    = s_user[0];

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
        
        .s_valid    ({KERNEL_W_MAX{s_valid}}),
        .s_data     (buffer_s_data_pixels),
        .s_last     ({KERNEL_W_MAX{s_last}}),
        .s_user     (buffer_s_user_pixels),

        .m_tvalid   (buffer_m_valid_pixels),
        .m_tdata    (buffer_m_data_pixels),
        .m_tlast    (buffer_m_last_pixels),
        .m_tuser    (buffer_m_user_pixels)
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
        
        .s_valid    ({KERNEL_W_MAX{s_valid}}),
        .s_data     (s_data_weights),
        .s_last     ({KERNEL_W_MAX{0}}),
        .s_user     ({KERNEL_W_MAX{0}}),

        .m_tvalid   (buffer_m_valid_weights),
        .m_tdata    (buffer_m_data_weights),
        .m_tlast    (),
        .m_tuser    ()
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
        .is_1x1     (0),
        
        .s_valid    ({1{s_valid}}),
        .s_data     (buffer_s_data_bias),
        .s_last     ({1{0}}),
        .s_user     ({1{s_user}}),

        .m_tvalid   (buffer_m_valid_bias),
        .m_tdata    (buffer_m_data_bias),
        // .m_tlast    (buffer_m_last_pixels),
        .m_tuser    (buffer_m_user_bias)
    );

    /*
    --------------------------------------------------------------------------
    */



    wire   [DATA_WIDTH - 1 : 0] mul_s_data          [KERNEL_W_MAX - 1 : 0];

    wire   [DATA_WIDTH - 1 : 0] mul_m_data          [KERNEL_W_MAX - 1 : 0];
    wire                        mul_m_valid         [KERNEL_W_MAX - 1 : 0];
    wire                        mul_m_last          [KERNEL_W_MAX - 1 : 0];
    wire   [TUSER_WIDTH - 1: 0] mul_m_user          [TUSER_WIDTH  - 1 : 0];
    
    wire   [DATA_WIDTH - 1 : 0] acc_s_data  [KERNEL_W_MAX - 1 : 0];
    wire                        acc_s_valid [KERNEL_W_MAX - 1 : 0];
    wire                        acc_s_last  [KERNEL_W_MAX - 1 : 0];
    wire   [TUSER_WIDTH - 1: 0] acc_s_user  [TUSER_WIDTH  - 1 : 0];


    wire   [DATA_WIDTH - 1 : 0] acc_m_data  [KERNEL_W_MAX - 1 : 0];
    wire                        acc_m_valid [KERNEL_W_MAX - 1 : 0];
    wire                        acc_m_last  [KERNEL_W_MAX - 1 : 0];
    wire   [TUSER_WIDTH - 1: 0] acc_m_user  [TUSER_WIDTH  - 1 : 0];


    wire   [DATA_WIDTH - 1 : 0] mux_s2_data [KERNEL_W_MAX - 1 : 0];
    wire                        mux_s2_valid[KERNEL_W_MAX - 1 : 0];
    wire   [TUSER_WIDTH - 1: 0] mux_s2_user [TUSER_WIDTH  - 1 : 0];


    genvar i;
    generate
        for (i=0; i < KERNEL_W_MAX; i++) begin : multipliers_gen

            floating_point_multiplier multiplier (
                .aclk                   (aclk),   
                .aclken                 (clken_mul),                               
                .aresetn                (aresetn),
                
                .s_axis_a_tvalid        (buffer_m_valid_pixels  [i]),            
                .s_axis_a_tdata         (buffer_m_data_pixels   [i]),              
                .s_axis_a_tlast         (buffer_m_last_pixels   [i]),              

                .s_axis_b_tvalid        (buffer_m_valid_weights [i]),            
                .s_axis_b_tdata         (buffer_m_data_weights  [i]),
                
                .m_axis_result_tvalid   (mul_m_valid    [i]),
                .m_axis_result_tdata    (mul_m_data     [i]),    
                .m_axis_result_tlast    (mul_m_last     [i])     
            );
        end

        for (i=0; i < KERNEL_W_MAX; i++) begin : accumulators_gen

            floating_point_accumulator accumulator (
                .aclk                   (aclk),
                .aclken                 (aclken),
                .aresetn                (aresetn),

                .s_axis_a_tvalid        (acc_s_valid    [i]),
                .s_axis_a_tdata         (acc_s_data     [i]),    
                .s_axis_a_tlast         (acc_s_last     [i]),     

                .m_axis_result_tvalid   (acc_m_valid    [i]), 
                .m_axis_result_tdata    (acc_m_data     [i]),  
                .m_axis_result_tlast    (acc_m_last     [i])   
            );
        end

        for (i=0; i < KERNEL_W_MAX; i++) begin : sel_regs_gen

            wire   update_tlast;
            assign update_tlast = acc_s_valid[i] && aclken;
            
            register #(
                .WORD_WIDTH     (DATA_WIDTH),
                .RESET_VALUE    (0)
            )
            sel_registers
            (
                .clock          (aclk),
                .clock_enable   (update_tlast),
                .resetn         (aresetn),
                .data_in        (mul_m_last [i]),
                .data_out       (mux_sel    [i])
            );
        end

        for (i=0; i < KERNEL_W_MAX; i++) begin : mux_gen

            axis_mux #(
                .DATA_WIDTH(DATA_WIDTH),
                .TUSER_WIDTH(TUSER_WIDTH)
            )
            mux
            (
                .sel                (mux_sel        [i]),

                .S0_AXIS_tdata      (mul_m_data     [i]),
                .S0_AXIS_tvalid     (mul_m_valid    [i]),
                .S0_AXIS_tready     (0                 ),
                .S0_AXIS_tkeep      (0                 ),
                .S0_AXIS_tlast      (mul_m_last     [i]),
                .S0_AXIS_tuser      (mul_m_user     [i]),

                .S1_AXIS_tdata      (mux_s2_data    [i]), 
                .S1_AXIS_tvalid     (mux_s2_valid   [i]),
                .S1_AXIS_tready     (0                 ),
                .S1_AXIS_tkeep      (0                 ),
                .S1_AXIS_tlast      (0                 ),
                .S1_AXIS_tuser      (mux_s2_user    [i]),

                .M_AXIS_tdata       (acc_s_data     [i]),
                .M_AXIS_tvalid      (acc_s_valid    [i]),
                .M_AXIS_tready      (                  ),
                .M_AXIS_tkeep       (                  ),
                .M_AXIS_tlast       (acc_s_last     [i]),
                .M_AXIS_tuser       (acc_m_user     [i])
            );
        end

        assign mux_s2_data   [0]    = buffer_m_data_bias    [0];
        assign mux_s2_valid  [0]    = buffer_m_valid_bias   [0];
        assign mux_s2_user   [0]    = buffer_m_user_bias    [0];

        for (i=1; i < KERNEL_W_MAX; i++) begin : acc_to_mux

            assign mux_s2_data   [i]    = acc_m_data    [i-1];
            assign mux_s2_valid  [i]    = acc_m_valid   [i-1];
            assign mux_s2_user  [i]     = acc_m_user    [i-1];

        end

    endgenerate
    
endmodule

