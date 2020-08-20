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
                * The first data beat of weights must contain bias in middle and others zero
                * The first data beat of pixels must contain ones

                * Indexing of datapaths goes 0, 1, 2,..,(kw-1) where datapath[0] accumulates leftmost
                    part of kernel and (kw-1) accumulates rightmost.
                * Snaking happens left -> right and full convolution output leaves from rightmost
                * datapath[0] has no muxes, accumulator directly connected to multiplier
                * muxes are indexed 1,2...(kw-1) to match rest of indexing

                * Limitations
                    - Output order is messed up for 1x1 if CIN > (kw-1)*(A-1)-2
                    - Output order of last kw/2 cols of 3x3 is reversed
                    - 3x3: CIN >= 6 for delays to sync up without error

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
    parameter IS_FIXED_POINT            ,
    parameter DATA_WIDTH                ,
    parameter KERNEL_W_MAX              ,
    parameter TUSER_WIDTH               ,
    parameter FIXED_ACCUMULATOR_DELAY   ,
    parameter FIXED_MULTIPLIER_DELAY    ,

    parameter INDEX_IS_1x1              ,
    parameter INDEX_IS_MAX              ,
    parameter INDEX_IS_RELU             ,
    parameter INDEX_IS_COLS_1_K2         
)(
    aclk,
    aclken,
    aresetn,

    start,
    kernel_w_1,

    s_ready            ,
    s_step_pixels_valid,
    s_step_pixels_data ,
    s_step_weights_data,
    s_step_pixels_last ,
    s_step_pixels_user ,
    
    m_valid,
    m_data,
    m_last,
    m_user

);
    localparam KERNEL_W_WIDTH       = $clog2(KERNEL_W_MAX   + 1);

    input  wire                      aclk;
    input  wire                      aclken;               
    input  wire                      aresetn;

    input  wire                      start;
    input  wire [KERNEL_W_WIDTH-1:0] kernel_w_1;

    output wire                      s_ready                                   ;
    input  wire                      s_step_pixels_valid [KERNEL_W_MAX - 1 : 0];
    input  wire [DATA_WIDTH  - 1: 0] s_step_pixels_data  [KERNEL_W_MAX - 1 : 0];
    input  wire [DATA_WIDTH  - 1: 0] s_step_weights_data [KERNEL_W_MAX - 1 : 0];
    input  wire                      s_step_pixels_last  [KERNEL_W_MAX - 1 : 0];
    input  wire [TUSER_WIDTH - 1: 0] s_step_pixels_user  [KERNEL_W_MAX - 1 : 0];

    output wire                      m_valid ;
    output wire [DATA_WIDTH  - 1: 0] m_data  ;
    output wire                      m_last  ;
    output wire [TUSER_WIDTH - 1: 0] m_user  ;


    /*
    ENABLE SIGNALS
    */
    wire    [KERNEL_W_MAX - 1 : 1] mux_sel;
    wire                           mux_sel_none;
    wire    [KERNEL_W_MAX - 1 : 0] clken_acc;
    wire                           clken_mul;

    assign  mux_sel_none = !(|mux_sel);
    assign  clken_mul    = aclken &&  mux_sel_none;
    assign  clken_acc[0] = clken_mul;

    assign  s_ready      = clken_mul;

    wire                        mul_m_valid             [KERNEL_W_MAX - 1 : 0];
    wire   [DATA_WIDTH - 1 : 0] mul_m_data              [KERNEL_W_MAX - 1 : 0];
    wire                        mul_m_last              [KERNEL_W_MAX - 1 : 0];
    wire   [TUSER_WIDTH - 1: 0] mul_m_user              [KERNEL_W_MAX - 1 : 0];
    
    wire                        acc_s_valid             [KERNEL_W_MAX - 1 : 0];
    wire   [DATA_WIDTH - 1 : 0] acc_s_data              [KERNEL_W_MAX - 1 : 0];
    wire                        acc_s_last              [KERNEL_W_MAX - 1 : 0];
    wire   [TUSER_WIDTH - 1: 0] acc_s_user              [KERNEL_W_MAX - 1 : 0];

    wire                        acc_m_valid             [KERNEL_W_MAX - 1 : 0];
    wire   [DATA_WIDTH - 1 : 0] acc_m_data              [KERNEL_W_MAX - 1 : 0];
    wire                        acc_m_last              [KERNEL_W_MAX - 1 : 0];
    wire                        acc_m_valid_last        [KERNEL_W_MAX - 1 : 0];
    wire                        acc_m_valid_last_masked [KERNEL_W_MAX - 1 : 0];
    wire   [TUSER_WIDTH - 1: 0] acc_m_user              [KERNEL_W_MAX - 1 : 0];

    wire                        mux_s2_valid            [KERNEL_W_MAX - 1 : 1];
    wire   [DATA_WIDTH - 1 : 0] mux_s2_data             [KERNEL_W_MAX - 1 : 1];
    wire   [TUSER_WIDTH - 1: 0] mux_s2_user             [KERNEL_W_MAX - 1 : 1];
    wire                        mux_m_valid             [KERNEL_W_MAX - 1 : 1];

    wire                        mask_partial            [KERNEL_W_MAX - 1 : 1];
    wire                        mask_full               [KERNEL_W_MAX - 1 : 0];


    pad_filter # (
        .DATA_WIDTH        (DATA_WIDTH        ),
        .KERNEL_W_MAX      (KERNEL_W_MAX      ),
        .TUSER_WIDTH       (TUSER_WIDTH       ),
        .INDEX_IS_COLS_1_K2(INDEX_IS_COLS_1_K2),
        .INDEX_IS_1x1      (INDEX_IS_1x1      )
    )
    pad_filter_dut
    (
        .aclk            (aclk              ),
        .aclken          (clken_acc         ),
        .aresetn         (aresetn           ),
        .start           (start             ),
        .kernel_w_1_in   (kernel_w_1        ),
        .valid_last      (acc_m_valid_last  ),
        .user            (acc_m_user        ),
        .mask_partial    (mask_partial      ),
        .mask_full       (mask_full         )
    );

    genvar i;
    generate

        for (i=0; i < KERNEL_W_MAX; i++) begin : multipliers_gen

            if (IS_FIXED_POINT) begin
                dummy_multiplier #(
                    .MULTIPLIER_DELAY   (FIXED_MULTIPLIER_DELAY),
                    .DATA_WIDTH         (DATA_WIDTH            ),
                    .TUSER_WIDTH        (TUSER_WIDTH           )
                )
                dummy_multiplier_unit
                (
                    .aclk         (aclk),
                    .aclken       (clken_mul),
                    .aresetn      (aresetn),
                    .valid_in_1   (s_step_pixels_valid      [i]),
                    .data_in_1    (s_step_pixels_data       [i]),
                    .last_in_1    (s_step_pixels_last       [i]),
                    .user_in_1    (s_step_pixels_user       [i]),
                    .valid_in_2   (s_step_pixels_valid      [i]),
                    .data_in_2    (s_step_weights_data      [i]),
                    .valid_out    (mul_m_valid              [i]),
                    .data_out     (mul_m_data               [i]),
                    .last_out     (mul_m_last               [i]),
                    .user_out     (mul_m_user               [i])
                );
            end
            else begin
                floating_point_multiplier multipler (
                    .aclk                   (aclk),                                            
                    .aclken                 (clken_mul),                                          
                    .aresetn                (aresetn),                                         
                    .s_axis_a_tvalid        (s_step_pixels_valid      [i]),                                 
                    .s_axis_a_tdata         (s_step_pixels_data       [i]),                                           
                    .s_axis_a_tlast         (s_step_pixels_last       [i]),                                  
                    .s_axis_a_tuser         (s_step_pixels_user       [i]),                                          
                    .s_axis_b_tvalid        (s_step_pixels_valid      [i]),                                 
                    .s_axis_b_tdata         (s_step_weights_data      [i]),                                           
                    .m_axis_result_tvalid   (mul_m_valid              [i]),                             
                    .m_axis_result_tdata    (mul_m_data               [i]),                                       
                    .m_axis_result_tlast    (mul_m_last               [i]),                               
                    .m_axis_result_tuser    (mul_m_user               [i])                                      
                );
            end
        end

        /* 
        CLKEN ACCUMULATOR

        * For datapath[0], keep accumulator enabled when "mux_sel_none"
        * Other datapaths, allow accumulator only if the sel bit of that datapath rises.
        * This ensures accumulators and multiplers are tied together, hence 
            delays being in sync for ANY cin >= 3. 
        */

        for (i=1; i < KERNEL_W_MAX; i++) begin : clken_acc_gen
            assign  clken_acc[i]    = aclken && (mux_sel_none || mux_sel[i]);
        end

        for (i=0; i < KERNEL_W_MAX; i++) begin : accumulators_gen

            assign acc_m_valid_last         [i] = acc_m_valid [i] & acc_m_last [i];
            assign acc_m_valid_last_masked  [i] = acc_m_valid_last[i] & mask_full[i];

            if (IS_FIXED_POINT) begin         
                dummy_accumulator #(
                    .ACCUMULATOR_DELAY  (FIXED_ACCUMULATOR_DELAY),
                    .DATA_WIDTH         (DATA_WIDTH             ),
                    .TUSER_WIDTH        (TUSER_WIDTH            )
                )
                dummy_accumulator_unit
                (
                    .aclk       (aclk),
                    .aclken     (clken_acc[i]),
                    .aresetn    (aresetn),
                    .valid_in   (acc_s_valid    [i]),
                    .data_in    (acc_s_data     [i]),
                    .last_in    (acc_s_last     [i]),
                    .user_in    (acc_s_user     [i]),
                    .valid_out  (acc_m_valid    [i]),
                    .data_out   (acc_m_data     [i]),
                    .last_out   (acc_m_last     [i]),
                    .user_out   (acc_m_user     [i])
                );
            end
            else begin
                floating_point_accumulator accumulator (
                    .aclk                   (aclk),                                 
                    .aclken                 (clken_acc[i]),                               
                    .aresetn                (aresetn),                              
                    .s_axis_a_tvalid        (acc_s_valid    [i]),                      
                    .s_axis_a_tdata         (acc_s_data     [i]),                                
                    .s_axis_a_tlast         (acc_s_last     [i]),                       
                    .s_axis_a_tuser         (acc_s_user     [i]),                               
                    .m_axis_result_tvalid   (acc_m_valid    [i]),                  
                    .m_axis_result_tdata    (acc_m_data     [i]),                            
                    .m_axis_result_tlast    (acc_m_last     [i]),                    
                    .m_axis_result_tuser    (acc_m_user     [i])                           
                );
            end
        end

        /*
        Directly connect Mul_0 to Acc_0
        */
        assign acc_s_valid[0] = mul_m_valid[0] && mux_sel_none;
        assign acc_s_data [0] = mul_m_data [0];
        assign acc_s_last [0] = mul_m_last [0];
        assign acc_s_user [0] = mul_m_user [0];

        /*
        SEL BITS

        * 1x1 : mux_sel   [i] = 0 ; permanently connecting mul to acc
        * nxm : mul_m_last[i] are delayed by one data beat
        * NOTE: sel_register is updated using the true acc_m_valid, not pad_filtered one

        * nxm : Delays inside step_buffer should sync perfectly, such that
          for every datapath[i] (except 0):

            1. last data from multiplier comes to mux_s1[i]
                * Directly goes into acc_s[i]
                * Clearing the accumulator with it
                * mul_m_last[i] that comes with it gets delayed (enters  mux_sel[i])

            2. On next data beat, last data from acc_s[i-1] comes into mux_s2[i]
                * mux_sel[i] is asserted, mux[i] allows mux_s2[i] into acc_s[i]
                * acc_s[i-1] enters acc_s[i], as 1st data of new accumulation
                    its tlast is not allowed passed
                * All multipliers are disabled
                * All accumulators, except [i] are disabled
                * acc_s[i] accepts acc_s[i-1]
                * "bias" has come to the mul_s[i] and waits
                    as multipler pipeline is disabled

            3. On next data_beat, mux_sel[i] is updated (deasserted)
                * BECAUSE selected_valid[i] = acc_m_valid_last[i-1] was asserted in prev clock
                * mux[i] allows mux_s1[i] into acc_s[i]
                * acc_s[i] accepts bias as 2nd data of new accumulation
                * all multipliers and other accumulators resume operation

            -  If last data from acc_m[i-1] doesn't follow last data of mul_s[i]:
                - mux_sel[i] will NOT be deasserted (updated)
                - multipliers and other accumulators will freeze forever
            - For this sync to happen:
                - datapath[i] should be delayed by DELAY clocks than datapath[i-1]
                - DELAY = (A-1) -1 = (A-2)
                    - When multipliers are frozen, each accumulator works 
                        one extra clock than its corresponding multiplier,
                        in (2), to accept other acc_s value. This means, the
                        relative delay of accumulator is (A-1) 
                        as seen by a multiplier
                    - If (A-1), both mul_s[i] and acc_s[i-1] will give tlast together
                    - (-1) ensures mul_s[i] comes first
                    
        */

        for (i=1; i < KERNEL_W_MAX; i++) begin : sel_regs_gen

            wire   update_switch, selected_valid;
            assign selected_valid = (mux_sel[i]==0) ? mul_m_valid [i] : acc_m_valid_last[i-1];
            assign update_switch  = aclken && selected_valid;

            
            wire   sel_in;
            assign sel_in = mul_m_last [i] && (!mul_m_user[i][INDEX_IS_1x1]);
            
            register #(
                .WORD_WIDTH     (1),
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

        for (i=1; i < KERNEL_W_MAX; i++) begin : mul_s2

            assign mux_s2_valid  [i]    = acc_m_valid_last  [i-1] && mask_partial[i];
            assign mux_s2_data   [i]    = acc_m_data        [i-1];
            assign mux_s2_user   [i]    = acc_m_user        [i-1];

        end

        // Muxes

        for (i=1; i < KERNEL_W_MAX; i++) begin : mux_gen

            assign acc_s_valid [i] = mux_m_valid[i] && (mux_sel[i] || mux_sel_none);

            axis_mux #(
                .DATA_WIDTH(DATA_WIDTH),
                .TUSER_WIDTH(TUSER_WIDTH)
            )
            mux
            (
                .sel                (mux_sel        [i]),

                .S0_AXIS_tvalid     (mul_m_valid    [i]),
                .S0_AXIS_tdata      (mul_m_data     [i]),
                .S0_AXIS_tlast      (mul_m_last     [i]),
                .S0_AXIS_tuser      (mul_m_user     [i]),

                .S1_AXIS_tvalid     (mux_s2_valid   [i]),
                .S1_AXIS_tdata      (mux_s2_data    [i]), 
                .S1_AXIS_tuser      (mux_s2_user    [i]),
                .S1_AXIS_tlast      (0                 ),   // Acc last is kept at zero

                .M_AXIS_tvalid      (mux_m_valid    [i]),
                .M_AXIS_tdata       (acc_s_data     [i]),
                .M_AXIS_tlast       (acc_s_last     [i]),
                .M_AXIS_tuser       (acc_s_user     [i])
            );
        end

    endgenerate



    /*
    SHIFT REGISTERS

    * KW_MAX number of shift registers are chained. 
    * Values are shifted from shift_reg[KW_MAX-1] -> ... -> shift_reg[1] -> shift_reg[0]
    * Conv_unit output is given by shift_reg[0]
    * Shift enable = aclk = m_ready of the AXIS outside.
        - whenever m_ready goes down, whole unit freezes, including shift regs.
        - if we use acc_clken or something else:
            when m_ready stays high, shift_clken might go low.
            this would result in valid staying high and data unchanged
            for multiple clocks as m_ready stays high. Downstream module
            will count it as multiple transactions as per AXIS protocol.

    n x m:

    * Middle cols:  - Only one datapath gives output, spaced ~CIN*KW delay apart.
                    - For any delay, outputs will come out one after the other, all is well
    * End cols   :  - (KW/2 + 1) datapaths give data out, spaced (A-2) delays apart
                    - But they come out in reversed order
    * Start cols :  - KW/2 cols are ignored
                    - So there is time for end_cols to come out

    1 x 1:

    * All datapaths give outputs
    * Order is messed up if CIN > i(A-1)-2
        - Can be solved by bypassing the (A-1) delay
        - But then back-to-back kernel change is not possible
    */
    wire                        shift_sel              [KERNEL_W_MAX - 2 : 0];

    wire                        shift_in_valid         [KERNEL_W_MAX - 1 : 0];
    wire   [DATA_WIDTH - 1 : 0] shift_in_data          [KERNEL_W_MAX - 1 : 0];
    wire                        shift_in_last          [KERNEL_W_MAX - 1 : 0];
    wire   [TUSER_WIDTH - 1: 0] shift_in_user          [TUSER_WIDTH  - 1 : 0];

    wire                        shift_out_valid        [KERNEL_W_MAX - 1 : 0];
    wire   [DATA_WIDTH - 1 : 0] shift_out_data         [KERNEL_W_MAX - 1 : 0];
    wire                        shift_out_last         [KERNEL_W_MAX - 1 : 0];
    wire   [TUSER_WIDTH - 1: 0] shift_out_user         [KERNEL_W_MAX - 1 : 0];

    generate
        for (i=0; i < KERNEL_W_MAX-1; i++) begin : shift_sel_gen

            assign shift_sel      [i] = acc_m_valid_last_masked[i]  ? acc_m_valid_last_masked [i] : shift_in_valid  [i+1];

            assign shift_in_valid [i] = shift_sel[i]                ? acc_m_valid_last_masked [i] : shift_out_valid [i+1];
            assign shift_in_data  [i] = shift_sel[i]                ? acc_m_data              [i] : shift_out_data  [i+1];
            assign shift_in_last  [i] = shift_sel[i]                ? acc_m_valid_last_masked [i] : shift_out_last  [i+1];
            assign shift_in_user  [i] = shift_sel[i]                ? acc_m_user              [i] : shift_out_user  [i+1];
        end

        assign     shift_in_valid [KERNEL_W_MAX - 1] = acc_m_valid_last_masked [KERNEL_W_MAX - 1]  ;
        assign     shift_in_data  [KERNEL_W_MAX - 1] = acc_m_data              [KERNEL_W_MAX - 1]  ;
        assign     shift_in_last  [KERNEL_W_MAX - 1] = acc_m_valid_last_masked [KERNEL_W_MAX - 1]  ;
        assign     shift_in_user  [KERNEL_W_MAX - 1] = acc_m_user              [KERNEL_W_MAX - 1]  ;

        for (i=0; i < KERNEL_W_MAX; i++) begin : shift_reg_gen

            n_delay_stream #(
                .N           (1                 ),
                .DATA_WIDTH  (DATA_WIDTH        ),
                .TUSER_WIDTH (TUSER_WIDTH       )
            )
            SHIFT_REG
            (
                .aclk       (aclk               ),
                .aclken     (aclken             ), // = m_ready of outside
                .aresetn    (aresetn            ),

                .valid_in   (shift_in_valid  [i]),
                .data_in    (shift_in_data   [i]),
                .last_in    (shift_in_last   [i]),
                .user_in    (shift_in_user   [i]),

                .valid_out  (shift_out_valid [i]),
                .data_out   (shift_out_data  [i]),
                .last_out   (shift_out_last  [i]),
                .user_out   (shift_out_user  [i])
            );
        end
    endgenerate

    assign m_valid = shift_out_valid [0];
    assign m_data  = shift_out_data  [0];
    assign m_last  = shift_out_last  [0];
    assign m_user  = shift_out_user  [0];

    
endmodule

