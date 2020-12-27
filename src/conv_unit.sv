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

                * ACTIVE & PASSIVE
                    - If IS_ACTIVE is set to 1, 
                        - unit is generated as an ACTIVE controller
                        - unit computes and drives: mux_sel, clken_mul, clken_acc, mux_s2_valid, acc_s_valid, acc_s_last, shift_sel
                        - out_* are driven, in_* are disconnected (Z)
                    - Else
                        - unit is generated as PASSIVE controlee
                        - unit receives: mux_sel, clken_mul, clken_acc, mux_s2_valid, acc_s_valid, acc_s_last, shift_sel 
                            from in_*. out_* are disconnected (Z)

                * Limitations
                    - Freezes if not: 3 CIN + 1 > 2(A-1)-1; CIN_min = 12 for A = 19
                    - Output order is messed up for 1x1 if CIN > (kw-1)*(A-1)-2
                    - Output order of last kw/2 cols of 3x3 is reversed
                    - When 1x1 and CIN = 1
                        - Identity operation. Expected input = output
                        - Alternating values will be lost due to masking of valid_last

Dependencies: * Floating point IP
                    - name : floating_point_multiplier
              * Floating point IP
                    - name : 

Revision:
Revision 0.01 - File Created
Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////*/

module conv_unit # (
    parameter IS_ACTIVE         ,
    parameter WORD_WIDTH_IN     ,
    parameter WORD_WIDTH_OUT    ,
    parameter KERNEL_W_MAX      ,
    parameter TUSER_WIDTH       ,
    parameter MULTIPLIER_DELAY  ,
    parameter ACCUMULATOR_DELAY ,
    parameter INDEX_IS_1x1      ,
    parameter INDEX_IS_MAX      ,
    parameter INDEX_IS_RELU     ,
    parameter INDEX_IS_COLS_1_K2 
)(
    // Common signals for ACTIVE and PASSIVE
    aclk                    ,
    aclken                  ,
    aresetn                 ,

    s_step_pixels_data      ,
    s_step_weights_valid    ,
    s_step_weights_data     ,
    
    m_data                  ,

    // Signals for ACTIVE only. out_* are 'z for PASSIVE, hence disconnected. inputs will be disconnected during elaboration.
    start                   ,
    kernel_w_1              ,

    s_step_pixels_last      ,
    s_step_pixels_user      ,

    s_ready                 ,
    m_valid                 ,
    m_last                  ,
    m_user                  ,

    out_mux_sel             ,
    out_clken_mul           ,
    out_clken_acc           ,
    out_mux_s2_valid        ,
    out_acc_s_valid         ,
    out_acc_s_last          ,
    out_shift_sel           ,

    // Signals for PASSIVE only. in_* are 'z for ACIVE
    in_mux_sel              ,
    in_clken_mul            ,
    in_clken_acc            ,
    in_mux_s2_valid         ,
    in_acc_s_valid          ,
    in_acc_s_last           ,
    in_shift_sel

);
    localparam KERNEL_W_WIDTH       = $clog2(KERNEL_W_MAX   + 1);

    input  logic aclk   ;
    input  logic aclken ;               
    input  logic aresetn;
    input  logic start  ;

    output logic s_ready;
    input  logic s_step_weights_valid [KERNEL_W_MAX-1: 0];
    input  logic s_step_pixels_last   [KERNEL_W_MAX-1: 0];
    input  logic [WORD_WIDTH_IN  - 1: 0] s_step_pixels_data  [KERNEL_W_MAX - 1 : 0];
    input  logic [WORD_WIDTH_IN  - 1: 0] s_step_weights_data [KERNEL_W_MAX - 1 : 0];
    input  logic [TUSER_WIDTH    - 1: 0] s_step_pixels_user  [KERNEL_W_MAX - 1 : 0];


    input  logic [KERNEL_W_WIDTH-1:0] kernel_w_1;

    output logic [WORD_WIDTH_OUT-1: 0] m_data;
    output logic [TUSER_WIDTH   -1: 0] m_user;
    output logic m_valid;
    output logic m_last ;

    output logic out_clken_mul                     ;
    output logic [KERNEL_W_MAX-1 : 1] out_mux_sel  ;
    output logic [KERNEL_W_MAX-1 : 0] out_clken_acc;
    output logic out_mux_s2_valid [KERNEL_W_MAX-1: 1];
    output logic out_acc_s_valid  [KERNEL_W_MAX-1: 0];
    output logic out_acc_s_last   [KERNEL_W_MAX-1: 0];
    output logic out_shift_sel    [KERNEL_W_MAX-2: 0];

    input  logic in_clken_mul;
    input  logic [KERNEL_W_MAX-1 : 1] in_mux_sel  ;
    input  logic [KERNEL_W_MAX-1 : 0] in_clken_acc;
    input  logic in_mux_s2_valid [KERNEL_W_MAX-1: 1];
    input  logic in_acc_s_valid  [KERNEL_W_MAX-1: 0];
    input  logic in_acc_s_last   [KERNEL_W_MAX-1: 0];
    input  logic in_shift_sel    [KERNEL_W_MAX-2: 0];


    /*
    ENABLE SIGNALS
    */
    logic    [KERNEL_W_MAX - 1 : 1] mux_sel      ;
    logic                           mux_sel_none ;
    logic    [KERNEL_W_MAX - 1 : 0] clken_acc    ;
    logic                           clken_mul    ;

    generate
        if (IS_ACTIVE) begin
            assign mux_sel_none     = !(|mux_sel)       ;
            assign clken_mul        = aclken &&  mux_sel_none;
            assign clken_acc[0]     = clken_mul         ;
            assign s_ready          = clken_mul         ;

            assign out_clken_mul    = clken_mul         ;
            assign out_clken_acc[0] = clken_acc[0]      ;
        end
        else begin
            assign clken_mul        = in_clken_mul      ;
            assign clken_acc[0]     = in_clken_acc[0]   ;
        end
    endgenerate

    logic   mul_m_valid [KERNEL_W_MAX - 1 : 0];
    logic   mul_m_last  [KERNEL_W_MAX - 1 : 0];
    logic   [WORD_WIDTH_IN-1: 0] mul_m_data [KERNEL_W_MAX - 1 : 0];
    logic   [TUSER_WIDTH - 1: 0] mul_m_user [KERNEL_W_MAX - 1 : 0];
    
    logic   acc_s_valid [KERNEL_W_MAX - 1 : 0];
    logic   acc_s_last  [KERNEL_W_MAX - 1 : 0];
    logic   [WORD_WIDTH_OUT-1: 0] acc_s_data  [KERNEL_W_MAX - 1 : 0];
    logic   [TUSER_WIDTH   -1: 0] acc_s_user  [KERNEL_W_MAX - 1 : 0];

    logic   acc_m_valid             [KERNEL_W_MAX - 1 : 0];
    logic   acc_m_last              [KERNEL_W_MAX - 1 : 0];
    logic   acc_m_valid_last        [KERNEL_W_MAX - 1 : 0];
    logic   acc_m_valid_last_masked [KERNEL_W_MAX - 1 : 0];
    logic   [WORD_WIDTH_OUT-1: 0] acc_m_data [KERNEL_W_MAX - 1 : 0];
    logic   [TUSER_WIDTH   -1: 0] acc_m_user [KERNEL_W_MAX - 1 : 0];

    logic   mux_s2_valid [KERNEL_W_MAX - 1 : 1];
    logic   mux_m_valid  [KERNEL_W_MAX - 1 : 1];
    logic   [WORD_WIDTH_OUT-1:0] mux_s2_data [KERNEL_W_MAX - 1 : 1];
    logic   [TUSER_WIDTH - 1: 0] mux_s2_user [KERNEL_W_MAX - 1 : 1];

    logic   mask_partial [KERNEL_W_MAX - 1 : 1];
    logic   mask_full    [KERNEL_W_MAX - 1 : 0];

    generate
        if(IS_ACTIVE) begin
            pad_filter # (
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
        end
    endgenerate

    genvar i;
    generate

        for (i=0; i < KERNEL_W_MAX; i++) begin : multipliers_gen

            if (IS_ACTIVE) begin
                    fixed_point_multiplier_wrapper #(
                        .MULTIPLIER_DELAY   (MULTIPLIER_DELAY),
                        .WORD_WIDTH         (WORD_WIDTH_IN   ),
                        .TUSER_WIDTH        (TUSER_WIDTH     )
                    )
                    fixed_point_multiplier
                    (
                        .aclk         (aclk),
                        .aclken       (clken_mul),
                        .aresetn      (aresetn),
                        .valid_in_1   (s_step_weights_valid     [i]),
                        .data_in_1    (s_step_pixels_data       [i]),
                        .last_in_1    (s_step_pixels_last       [i]),
                        .user_in_1    (s_step_pixels_user       [i]),
                        .valid_in_2   (s_step_weights_valid     [i]),
                        .data_in_2    (s_step_weights_data      [i]),
                        .valid_out    (mul_m_valid              [i]),
                        .data_out     (mul_m_data               [i]),
                        .last_out     (mul_m_last               [i]),
                        .user_out     (mul_m_user               [i])
                    );
            end
            else begin
                    fixed_point_multiplier_wrapper #(
                        .MULTIPLIER_DELAY   (MULTIPLIER_DELAY ),
                        .WORD_WIDTH         (WORD_WIDTH_IN    ),
                        .TUSER_WIDTH        (TUSER_WIDTH      )
                    )
                    fixed_point_multiplier
                    (
                        .aclk         (aclk),
                        .aclken       (clken_mul),
                        .aresetn      (aresetn),
                        .valid_in_1   (s_step_weights_valid     [i]),
                        .data_in_1    (s_step_pixels_data       [i]),
                        .valid_in_2   (s_step_weights_valid     [i]),
                        .data_in_2    (s_step_weights_data      [i]),
                        .valid_out    (mul_m_valid              [i]),
                        .data_out     (mul_m_data               [i])
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

            if (IS_ACTIVE) begin
                assign clken_acc[i]    = aclken && (mux_sel_none || mux_sel[i]);
                assign out_clken_acc[i]= clken_acc[i];
            end
            else begin
                assign clken_acc[i]    = in_clken_acc[i];
            end

        end

        for (i=0; i < KERNEL_W_MAX; i++) begin : accumulators_gen

            assign acc_m_valid_last         [i] = acc_m_valid [i] & acc_m_last [i];

            if (IS_ACTIVE) begin
                    fixed_point_accumulator_wrapper #(
                        .ACCUMULATOR_DELAY  (ACCUMULATOR_DELAY),
                        .WORD_WIDTH         (WORD_WIDTH_OUT   ),
                        .TUSER_WIDTH        (TUSER_WIDTH      )
                    )
                    fixed_point_accumulator
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
                    fixed_point_accumulator_wrapper #(
                        .ACCUMULATOR_DELAY  (ACCUMULATOR_DELAY),
                        .WORD_WIDTH         (WORD_WIDTH_OUT   ),
                        .TUSER_WIDTH        (TUSER_WIDTH      )
                    )
                    fixed_point_accumulator
                    (
                        .aclk       (aclk              ),
                        .aclken     (clken_acc      [i]),
                        .aresetn    (aresetn           ),
                        .valid_in   (acc_s_valid    [i]),
                        .data_in    (acc_s_data     [i]),
                        .last_in    (acc_s_last     [i]),
                        .valid_out  (acc_m_valid    [i]),
                        .data_out   (acc_m_data     [i]),
                        .last_out   (acc_m_last     [i])
                    );
            end
        end

        /*
        Directly connect Mul_0 to Acc_0
        */
        if (IS_ACTIVE) begin
            assign acc_s_valid      [0] = mul_m_valid   [0] && mux_sel_none;
            assign acc_s_data       [0] = mul_m_data    [0]                ;
            assign acc_s_last       [0] = mul_m_last    [0]                ;
            assign acc_s_user       [0] = mul_m_user    [0]                ;

            assign out_acc_s_valid  [0] = acc_s_valid   [0]                ;
            assign out_acc_s_last   [0] = acc_s_last    [0]                ;
        end
        else begin
            assign acc_s_valid      [0] = in_acc_s_valid[0]                ;
            assign acc_s_data       [0] = mul_m_data    [0]                ;
            assign acc_s_last       [0] = in_acc_s_last [0]                ;
            assign acc_s_last       [0] = mul_m_last    [0]                ;
        end

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
        if (IS_ACTIVE) begin

            assign out_mux_sel = mux_sel;

            for (i=1; i < KERNEL_W_MAX; i++) begin : sel_regs_gen

                logic selected_valid = (mux_sel[i]==0) ? mul_m_valid [i] : acc_m_valid_last[i-1];
                logic update_switch  = aclken && selected_valid;

                logic sel_in         = mul_m_last [i] && (!mul_m_user[i][INDEX_IS_1x1]);
                
                register #(
                    .WORD_WIDTH     (1),
                    .RESET_VALUE    (0)
                )
                sel_registers
                (
                    .clock          (aclk          ),
                    .clock_enable   (update_switch ),
                    .resetn         (aresetn       ),
                    .data_in        (sel_in        ),
                    .data_out       (mux_sel    [i])
                );
            end
        end
        else begin
            assign mux_sel = in_mux_sel;
        end

        // MUX inputs

        for (i=1; i < KERNEL_W_MAX; i++) begin : mul_s2

            if(IS_ACTIVE) begin
                assign mux_s2_valid     [i] = acc_m_valid_last  [i-1] && mask_partial[i];
                assign out_mux_s2_valid [i] = mux_s2_valid[i]                           ;
            end
            else begin
                assign mux_s2_valid     [i] = in_mux_s2_valid[i]     ;
            end

            assign mux_s2_data          [i] = acc_m_data        [i-1];
            assign mux_s2_user          [i] = acc_m_user        [i-1];

        end

        // Muxes
        if(IS_ACTIVE)
            for (i=1; i < KERNEL_W_MAX; i++) begin : mux_gen

                assign acc_s_valid [i]    = mux_m_valid[i] && (mux_sel[i] || mux_sel_none);
                
                assign out_acc_s_valid[i] = acc_s_valid[i];
                assign out_acc_s_last [i] = acc_s_last [i];

                axis_mux #(
                    .DATA_WIDTH   (WORD_WIDTH_OUT),
                    .TUSER_WIDTH  (TUSER_WIDTH)
                )
                mux
                (
                    .sel                (mux_sel        [i]),

                    .S0_AXIS_tdata      (WORD_WIDTH_OUT'(signed'(mul_m_data [i]))),
                    .S0_AXIS_tvalid     (mul_m_valid    [i]),
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
        else begin
            for (i=1; i < KERNEL_W_MAX; i++) begin : mux_gen

                assign acc_s_valid[i] = in_acc_s_valid[i];
                assign acc_s_last [i] = in_acc_s_last [i];

                axis_mux #(
                    .DATA_WIDTH (WORD_WIDTH_OUT),
                    .TUSER_WIDTH(TUSER_WIDTH)
                )
                mux
                (
                    .sel                (mux_sel        [i]),

                    .S0_AXIS_tdata      (WORD_WIDTH_OUT'(signed'(mul_m_data [i]))),
                    .S0_AXIS_tvalid     (mul_m_valid    [i]),

                    .S1_AXIS_tvalid     (mux_s2_valid   [i]),
                    .S1_AXIS_tdata      (mux_s2_data    [i]), 

                    .M_AXIS_tvalid      (mux_m_valid    [i]),
                    .M_AXIS_tdata       (acc_s_data     [i])
                );
            end
        end

    endgenerate



    /*
    SHIFT REGISTERS

    * KW_MAX number of shift registers are chained. 
    * Values are shifted from shift_reg[KW_MAX-1] -> ... -> shift_reg[1] -> shift_reg[0]
    * Conv_unit output is given by shift_reg[0]

    * Muxing
        - Input of shift registers are the muxed result of acc_m[i] and shift_out[i+1]
        - Priority is given to shifting. 
            - If shift_out[i+1] is high, input is taken from there.
            - Else, input is taken from acc_m[i]
        - Because, if two acc_m[1] and acc_m[2] are released together, as in A=2 (default fixed point), 
            acc_m[1] stays for two clocks until it's value goes into acc_m[2]
        - So, the clock sequence goes as follows:
            - acc_m[0] == 0 ; shift[0] == 0        ; acc_m[1] == 1 ; shift[1] == 0         ; acc_m[2] == 1  ; shift[2] == 0
            - acc_m[0] == 0 ; shift[0] == 0        ; acc_m[1] == 1 ; shift[1] == acc_m[1]  ; acc_m[2] == 0  ; shift[2] == acc_m[2]
            - acc_m[0] == 0 ; shift[0] == acc_m[1] ; acc_m[1] == 0 ; shift[1] == acc_m[2]  ; acc_m[2] == 0  ; shift[2] == 0

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
    logic                        shift_sel              [KERNEL_W_MAX - 2 : 0];

    logic                        shift_in_valid         [KERNEL_W_MAX - 1 : 0];
    logic   [WORD_WIDTH_OUT-1:0] shift_in_data          [KERNEL_W_MAX - 1 : 0];
    logic                        shift_in_last          [KERNEL_W_MAX - 1 : 0];
    logic   [TUSER_WIDTH - 1: 0] shift_in_user          [TUSER_WIDTH  - 1 : 0];

    logic                        shift_out_valid        [KERNEL_W_MAX - 1 : 0];
    logic   [WORD_WIDTH_OUT-1:0] shift_out_data         [KERNEL_W_MAX - 1 : 0];
    logic                        shift_out_last         [KERNEL_W_MAX - 1 : 0];
    logic   [TUSER_WIDTH - 1: 0] shift_out_user         [KERNEL_W_MAX - 1 : 0];

    generate
        /*
            MASKED VALID LAST
                - Full mask from pad filter is applied
                - Delayed by one clock, ANDed with not
                    - To ensure this stays HIGH only for one clock
                    - Else, when acc_m_valid_last_masked stays high for two clocks 
                        (when acc[1] waits to get accepted into acc[2]),
                        m_valid stays high for two clocks and same data is read twice.
                    - Valid data never comes consecutively in any acc:
                        - in any NxN, shift_buffer delays data by N, so valids are N*CIN clocks apart
                        - In 1x1, when CIN > 1, valids are CIN clocks apart
                        - If 1x1 and CIN = 1, it is not convolution - it is identity operation
                            - This will fail there
        */
        if (IS_ACTIVE)
            for (i=0; i < KERNEL_W_MAX  ; i++) begin : valid_masked_gen
                
                logic   acc_m_valid_last_masked_delayed;
                assign  acc_m_valid_last_masked  [i] = acc_m_valid_last[i] & mask_full[i] & !acc_m_valid_last_masked_delayed;

                register #(
                    .WORD_WIDTH     (1),
                    .RESET_VALUE    (0)
                )
                sel_registers
                (
                    .clock          (aclk                           ),
                    .clock_enable   (aclken                         ),
                    .resetn         (aresetn                        ),
                    .data_in        (acc_m_valid_last_masked    [i] ),
                    .data_out       (acc_m_valid_last_masked_delayed)
                );
            end

        if (IS_ACTIVE) begin
            
            assign out_shift_sel = shift_sel;

            for (i=0; i < KERNEL_W_MAX-1; i++) begin : shift_sel_gen

                assign shift_sel      [i] = shift_out_valid  [i+1]; //-------GET THIS OUT

                assign shift_in_valid [i] = shift_sel  [i] ? shift_out_valid [i+1] : acc_m_valid_last_masked [i];
                assign shift_in_data  [i] = shift_sel  [i] ? shift_out_data  [i+1] : acc_m_data              [i];
                assign shift_in_last  [i] = shift_sel  [i] ? shift_out_last  [i+1] : acc_m_valid_last_masked [i];
                assign shift_in_user  [i] = shift_sel  [i] ? shift_out_user  [i+1] : acc_m_user              [i];
            end

            assign     shift_in_valid [KERNEL_W_MAX - 1] = acc_m_valid_last_masked [KERNEL_W_MAX - 1];
            assign     shift_in_data  [KERNEL_W_MAX - 1] = acc_m_data              [KERNEL_W_MAX - 1];
            assign     shift_in_last  [KERNEL_W_MAX - 1] = acc_m_valid_last_masked [KERNEL_W_MAX - 1];
            assign     shift_in_user  [KERNEL_W_MAX - 1] = acc_m_user              [KERNEL_W_MAX - 1];

            for (i=0; i < KERNEL_W_MAX; i++) begin : shift_reg_gen

                n_delay_stream #(
                    .N           (1                 ),
                    .WORD_WIDTH  (WORD_WIDTH_OUT    ),
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
            assign m_valid = shift_out_valid [0];
            assign m_data  = shift_out_data  [0];
            assign m_last  = shift_out_last  [0];
            assign m_user  = shift_out_user  [0];
        end
        else begin

            assign shift_sel = in_shift_sel;

            for (i=0; i < KERNEL_W_MAX-1; i++) begin : shift_sel_gen
                assign shift_in_data  [i] = shift_sel  [i] ? shift_out_data  [i+1] : acc_m_data  [i];
            end
            
            for (i=0; i < KERNEL_W_MAX; i++) begin : shift_reg_gen
                register #(
                        .WORD_WIDTH     (WORD_WIDTH_OUT),
                        .RESET_VALUE    (0)
                )
                SHIFT_REG
                (
                    .clock          (aclk               ),
                    .clock_enable   (aclken             ),
                    .resetn         (aresetn            ),
                    .data_in        (shift_in_data   [i]),
                    .data_out       (shift_out_data  [i])
                );
            end

            assign     shift_in_data  [KERNEL_W_MAX - 1] = acc_m_data      [KERNEL_W_MAX - 1];
            assign     m_data                            = shift_out_data  [0]               ;
        end
    endgenerate     

endmodule

