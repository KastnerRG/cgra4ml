module conv_engine (
    clk            ,
    clken          ,
    resetn         ,
    start          ,
    s_pixels_valid ,
    s_pixels_data  ,
    s_pixels_ready ,
    s_weights_valid,
    s_weights_data ,
    s_weights_ready,
    s_user         ,
    m_valid        ,
    m_data         ,
    m_last         ,
    m_user         
  );

  parameter  CORES   = 32 ;
  parameter  UNITS   = 8  ;
  parameter  WORD_WIDTH_IN  =  8 ; 
  parameter  WORD_WIDTH_OUT = 25 ; 
  parameter  ACCUMULATOR_DELAY  =  2 ;
  parameter  MULTIPLIER_DELAY   =  3 ;
  parameter  KERNEL_W_MAX   =  3 ; 
  parameter  KERNEL_H_MAX   =  3 ;   // odd number
  parameter  IM_CIN_MAX     = 1024;
  parameter  IM_COLS_MAX    = 1024;
  localparam BITS_IM_CIN    = $clog2(IM_CIN_MAX);
  localparam BITS_IM_COLS   = $clog2(IM_COLS_MAX);
  localparam BITS_CONV_CORES= $clog2(CORES);
  localparam BITS_KERNEL_W  = $clog2(KERNEL_W_MAX   + 1);
  localparam BITS_KERNEL_H  = $clog2(KERNEL_H_MAX   + 1);
  localparam UNITS_EDGES    = UNITS + (KERNEL_H_MAX-1);
  parameter  I_CONV_CORES         = 0;
  parameter  I_IM_CIN_1           = I_CONV_CORES + BITS_CONV_CORES+ 0;
  parameter  I_IM_COLS_1          = I_IM_CIN_1   + BITS_IM_CIN    + 0;
  parameter  I_KERNEL_W           = I_IM_COLS_1  + BITS_IM_COLS   + 0;
  parameter  I_KERNEL_H           = I_KERNEL_W   + BITS_KERNEL_W  + 0;
  parameter  I_OTHER              = I_KERNEL_H   + BITS_KERNEL_H;
  parameter  I_IS_1X1             = I_OTHER + 0;  
  parameter  I_MAXPOOL_IS_MAX     = I_OTHER + 1;
  parameter  I_MAXPOOL_IS_NOT_MAX = I_OTHER + 2;
  parameter  I_LRELU_IS_LRELU     = I_OTHER + 3;
  parameter  I_LRELU_IS_TOP       = I_OTHER + 4;
  parameter  I_LRELU_IS_BOTTOM    = I_OTHER + 5;
  parameter  I_LRELU_IS_LEFT      = I_OTHER + 6;
  parameter  I_LRELU_IS_RIGHT     = I_OTHER + 7;
  parameter  I_IS_COLS_1_K2       = I_OTHER + 8;  
  parameter  TUSER_WIDTH_CONV     = I_OTHER + 9;
  parameter  TUSER_WIDTH_LRELU    = BITS_CONV_CORES + 8;

  input  logic clk;
  input  logic clken;
  input  logic resetn;
  input  logic start;
  input  logic s_pixels_valid ;
  output logic s_pixels_ready ;
  input  logic s_weights_valid;
  output logic s_weights_ready;
  input  logic [TUSER_WIDTH_CONV-1:0] s_user;
  input  logic [WORD_WIDTH_IN   -1:0] s_pixels_data  [UNITS_EDGES-1: 0];
  input  logic [WORD_WIDTH_IN   -1:0] s_weights_data [CORES-1:0][KERNEL_W_MAX-1:0];                                                                        
  output logic m_valid;
  output logic m_last ;
  output logic [WORD_WIDTH_OUT   -1: 0] m_data       [CORES-1:0][UNITS-1:0];
  output logic [TUSER_WIDTH_LRELU-1: 0] m_user;

  logic [BITS_CONV_CORES-1:0] s_user_cores   ;
  logic [BITS_IM_CIN    -1:0] s_user_cin_1   ;
  logic [BITS_IM_COLS   -1:0] s_user_cols_1  ;
  logic [BITS_KERNEL_W  -1:0] s_user_kernel_w_1;
  logic [BITS_KERNEL_H  -1:0] s_user_kernel_h_1;

  logic conv_s_ready;

  /*
      SHIFT PIXELS BUFFER
  */
  
  logic [WORD_WIDTH_IN   -1:0] m_shift_pixels_data   [UNITS-1:0];
  logic                        m_shift_pixels_valid;
  logic                        m_shift_pixels_ready;
  logic                        m_shift_pixels_last ;
  logic [TUSER_WIDTH_CONV-1:0] m_shift_pixels_user ;

  axis_shift_buffer #(
    .WORD_WIDTH         (WORD_WIDTH_IN      ),
    .CONV_UNITS         (UNITS              ),
    .KERNEL_H_MAX       (KERNEL_H_MAX       ),
    .KERNEL_W_MAX       (KERNEL_W_MAX       ),
    .CIN_COUNTER_WIDTH  (BITS_IM_CIN        ),
    .COLS_COUNTER_WIDTH (BITS_IM_COLS       ),
    .TUSER_WIDTH        (TUSER_WIDTH_CONV   ),
    .INDEX_IS_1x1       (I_IS_1X1           ),
    .INDEX_IS_MAX       (I_MAXPOOL_IS_MAX   ),
    .INDEX_IS_RELU      (I_LRELU_IS_LRELU   ),
    .INDEX_IS_COLS_1_K2 (I_IS_COLS_1_K2     )
  )
  SHIFT_BUFFER
  (
    .aclk               (clk                  ),
    .aresetn            (resetn               ),
    .start              (start                ),
    .kernel_h_1_in      (s_user_kernel_w_1    ),
    .kernel_w_1_in      (s_user_kernel_h_1    ),
    .is_max             (s_user[I_MAXPOOL_IS_MAX]),
    .is_relu            (s_user[I_LRELU_IS_LRELU]),
    .cols_1             (s_user_cols_1        ),
    .cin_1              (s_user_cin_1         ),

    .S_AXIS_tdata       (s_pixels_data        ),
    .S_AXIS_tvalid      (s_pixels_valid       ),
    .S_AXIS_tready      (s_pixels_ready       ),

    .M_AXIS_tdata       (m_shift_pixels_data  ),
    .M_AXIS_tvalid      (m_shift_pixels_valid ),
    .M_AXIS_tready      (m_shift_pixels_ready ),
    .M_AXIS_tlast       (m_shift_pixels_last  ),
    .M_AXIS_tuser       (m_shift_pixels_user  )
  );

  /*
    SYNC WEIGHTS and PIXELS
  */

  logic conv_s_valid;

  assign conv_s_valid         = s_weights_valid & m_shift_pixels_valid;
  assign s_weights_ready      = conv_s_ready    & m_shift_pixels_valid;
  assign m_shift_pixels_ready = conv_s_ready    & s_weights_valid;


  logic m_step_weights_valid    [KERNEL_W_MAX-1: 0];
  logic [WORD_WIDTH_IN  - 1: 0] m_step_weights_data  [CORES-1:0][KERNEL_W_MAX-1: 0];

  logic m_step_pixels_valid [KERNEL_W_MAX-1: 0];
  logic m_step_pixels_last  [KERNEL_W_MAX-1: 0];
  logic [TUSER_WIDTH_CONV-1:0] s_step_pixels_repeated_user [KERNEL_W_MAX-1: 0];
  logic [TUSER_WIDTH_CONV-1:0] m_step_pixels_user          [KERNEL_W_MAX-1: 0];

  logic [WORD_WIDTH_IN-1:0] m_step_pixels_data          [UNITS-1: 0][KERNEL_W_MAX-1: 0];
  logic [WORD_WIDTH_IN-1:0] s_step_pixels_repeated_data [UNITS-1: 0][KERNEL_W_MAX-1: 0];

  logic mux_sel_none ;
  logic clken_mul;
  logic [KERNEL_W_MAX-1: 1] mux_sel  ;
  logic [KERNEL_W_MAX-1: 0] clken_acc;

  logic mul_m_valid [KERNEL_W_MAX-1: 0];
  logic mul_m_last  [KERNEL_W_MAX-1: 0];
  
  logic first_bypass[KERNEL_W_MAX-1: 0];
  logic acc_s_valid [KERNEL_W_MAX-1: 0];
  logic acc_s_last  [KERNEL_W_MAX-1: 0];

  logic acc_m_valid             [KERNEL_W_MAX-1: 0];
  logic acc_m_last              [KERNEL_W_MAX-1: 0];
  logic acc_m_valid_last        [KERNEL_W_MAX-1: 0];
  logic acc_m_valid_last_masked [KERNEL_W_MAX-1: 0];
  logic acc_m_valid_last_masked_delayed  [KERNEL_W_MAX-1: 0];

  logic selected_valid [KERNEL_W_MAX-1: 1]; 
  logic update_switch  [KERNEL_W_MAX-1: 1];
  logic sel_in         [KERNEL_W_MAX-1: 1];

  logic mux_s2_valid [KERNEL_W_MAX-1: 1];
  logic mux_m_valid  [KERNEL_W_MAX-1: 1];

  logic mask_partial [KERNEL_W_MAX-1: 1];
  logic mask_full    [KERNEL_W_MAX-1: 0];

  logic shift_sel    [KERNEL_W_MAX-2: 0];

  logic shift_in_valid  [KERNEL_W_MAX-1: 0];
  logic shift_in_last   [KERNEL_W_MAX-1: 0];
  logic shift_out_valid [KERNEL_W_MAX-1: 0];
  logic shift_out_last  [KERNEL_W_MAX-1: 0];

  logic [TUSER_WIDTH_CONV-1: 0] mul_m_user    [KERNEL_W_MAX-1: 0];
  logic [TUSER_WIDTH_CONV-1: 0] acc_s_user    [KERNEL_W_MAX-1: 0];
  logic [TUSER_WIDTH_CONV-1: 0] mux_s2_user   [KERNEL_W_MAX-1: 1];
  logic [TUSER_WIDTH_CONV-1: 0] acc_m_user    [KERNEL_W_MAX-1: 0];
  logic [TUSER_WIDTH_CONV-1: 0] shift_in_user [KERNEL_W_MAX-1: 0];
  logic [TUSER_WIDTH_CONV-1: 0] shift_out_user[KERNEL_W_MAX-1: 0];

  logic [WORD_WIDTH_IN*2-1:0] mul_m_data     [CORES-1:0][UNITS-1:0][KERNEL_W_MAX-1: 0];
  
  logic [WORD_WIDTH_OUT-1:0] acc_s_data      [CORES-1:0][UNITS-1:0][KERNEL_W_MAX-1: 0];
  logic [WORD_WIDTH_OUT-1:0] acc_m_data      [CORES-1:0][UNITS-1:0][KERNEL_W_MAX-1: 0];
  logic [WORD_WIDTH_OUT-1:0] mux_s2_data     [CORES-1:0][UNITS-1:0][KERNEL_W_MAX-1: 1];
  logic [WORD_WIDTH_OUT-1:0] shift_in_data   [CORES-1:0][UNITS-1:0][KERNEL_W_MAX-1: 0];
  logic [WORD_WIDTH_OUT-1:0] shift_out_data  [CORES-1:0][UNITS-1:0][KERNEL_W_MAX-1: 0];

  /*
    CONTROL PATHS
  */

  assign mux_sel_none = !(|mux_sel) ;
  assign clken_mul    = clken &&  mux_sel_none;
  assign conv_s_ready = clken_mul   ;
  assign clken_acc[0] = clken_mul   ;

  /*
    STEP BUFFER WEIGHTS
  */

  step_buffer  #(
    .WORD_WIDTH       (WORD_WIDTH_IN    ),
    .STEPS            (KERNEL_W_MAX     ),
    .ACCUMULATOR_DELAY(ACCUMULATOR_DELAY),
    .TUSER_WIDTH      (TUSER_WIDTH_CONV )
  )
  step_buffer_weights
  (
    .aclk       (clk),
    .aclken     (conv_s_ready),
    .aresetn    (resetn),
    .is_1x1     (m_shift_pixels_user[I_IS_1X1]),
    .s_valid    ('{KERNEL_W_MAX{s_weights_valid}}),
    .m_valid    (m_step_weights_valid)
  );

  /*
    STEP BUFFER PIXELS
  */

  generate
    for (genvar w=0 ; w < KERNEL_W_MAX; w++)
      assign s_step_pixels_repeated_user [w] = m_shift_pixels_user;
  endgenerate

  step_buffer  #(
    .WORD_WIDTH       (WORD_WIDTH_IN),
    .STEPS            (KERNEL_W_MAX),
    .ACCUMULATOR_DELAY(ACCUMULATOR_DELAY),
    .TUSER_WIDTH      (TUSER_WIDTH_CONV)
  )
  step_buffer_pixels_other
  (
    .aclk       (clk         ),
    .aclken     (conv_s_ready),
    .aresetn    (resetn      ),
    .is_1x1     (m_shift_pixels_user[I_IS_1X1]),

    .s_last     ('{KERNEL_W_MAX{m_shift_pixels_last}}  ),
    .s_user     (s_step_pixels_repeated_user           ),
    .m_valid    (m_step_pixels_valid                   ),
    .m_last     (m_step_pixels_last                    ),
    .m_user     (m_step_pixels_user                    )
  );

  /*
    CONTROL CHAINS
  */

  generate
    for (genvar w=0; w < KERNEL_W_MAX; w++) begin: w

      /*
        Multiplier Delay
      */

      n_delay_stream #(
        .N          (MULTIPLIER_DELAY),
        .WORD_WIDTH (WORD_WIDTH_IN   ),
        .TUSER_WIDTH(TUSER_WIDTH_CONV)
      ) mul_delay (
        .aclk       (clk),
        .aclken     (clken_mul),
        .aresetn    (resetn),

        .valid_in   (m_step_weights_valid [w]),
        .last_in    (m_step_pixels_last   [w]),
        .user_in    (m_step_pixels_user   [w]),

        .valid_out  (mul_m_valid [w]),
        .last_out   (mul_m_last  [w]),
        .user_out   (mul_m_user  [w])
      );

      /* 
        CLKEN ACCUMULATOR

        * For datapath[0], keep accumulator enabled when "mux_sel_none"
        * Other datapaths, allow accumulator only if the sel bit of that datapath rises.
        * This ensures accumulators and multiplers are tied together, hence 
            delays being in sync for ANY cin >= 3. 
      */
      if (w!=0) assign clken_acc[w] = clken && (mux_sel_none || mux_sel[w]);

      assign acc_m_valid_last[w] = acc_m_valid [w] & acc_m_last [w];

      register #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (0)
      ) acc_tlast_delay (
        .clock          (clk),
        .resetn         (resetn),
        .clock_enable   (clken_acc    [w]),
        .data_in        (acc_s_last   [w]),
        .data_out       (first_bypass [w])
      );

      n_delay_stream #(
        .N              (ACCUMULATOR_DELAY),
        .WORD_WIDTH     (WORD_WIDTH_IN    ),
        .TUSER_WIDTH    (TUSER_WIDTH_CONV )
      ) delay_others (
        .aclk       (clk   ),
        .aclken     (clken_acc   [w]),
        .aresetn    (resetn),

        .valid_in   (acc_s_valid [w]),
        .last_in    (acc_s_last  [w]),
        .user_in    (acc_s_user  [w]),

        .valid_out  (acc_m_valid [w]),
        .last_out   (acc_m_last  [w]),
        .user_out   (acc_m_user  [w])
      );

      /*
        Directly connect Mul_0 to Acc_0
      */
      assign acc_s_valid [0] = mul_m_valid [0] && mux_sel_none;
      
      assign acc_s_last  [0] = mul_m_last  [0];
      assign acc_s_user  [0] = mul_m_user  [0];

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
      
      if (w !=0 ) begin
        assign selected_valid [w] = (mux_sel[w]==0) ? mul_m_valid [w] : acc_m_valid_last[w-1];
        assign update_switch  [w] = clken && selected_valid [w];
        assign sel_in         [w] = mul_m_last [w] && (!mul_m_user[w][I_IS_1X1]);
        
        register #(
          .WORD_WIDTH     (1),
          .RESET_VALUE    (0)
        ) sel_registers (
          .clock          (clk    ),
          .resetn         (resetn),
          .clock_enable   (update_switch[w]),
          .data_in        (sel_in       [w]),
          .data_out       (mux_sel      [w])
        );

        assign mux_s2_valid [w] = acc_m_valid_last [w-1] && mask_partial[w];
        assign mux_s2_user  [w] = acc_m_user       [w-1];

        assign acc_s_valid  [w] = mux_m_valid[w] && (mux_sel[w] || mux_sel_none);

        assign mux_m_valid  [w] = mux_sel [w] ? mux_s2_valid [w] : mul_m_valid [w];
        assign acc_s_user   [w] = mux_sel [w] ? mux_s2_user  [w] : mul_m_user  [w];
        assign acc_s_last   [w] = mux_sel [w] ? 0                : mul_m_last  [w];
      end

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

      assign  acc_m_valid_last_masked  [w] = acc_m_valid_last[w] & mask_full[w] & !acc_m_valid_last_masked_delayed[w];

      register #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (0)
      )
      sel_registers
      (
        .clock          (clk    ),
        .clock_enable   (clken  ),
        .resetn         (resetn ),
        .data_in        (acc_m_valid_last_masked        [w] ),
        .data_out       (acc_m_valid_last_masked_delayed[w])
      );

      if (w != KERNEL_W_MAX-1) begin
        assign shift_sel      [w] = shift_out_valid  [w+1]; //-------GET THIS OUT

        assign shift_in_valid [w] = shift_sel  [w] ? shift_out_valid [w+1] : acc_m_valid_last_masked [w];
        assign shift_in_last  [w] = shift_sel  [w] ? shift_out_last  [w+1] : acc_m_valid_last_masked [w];
        assign shift_in_user  [w] = shift_sel  [w] ? shift_out_user  [w+1] : acc_m_user              [w];
      end

      assign shift_in_valid [KERNEL_W_MAX - 1] = acc_m_valid_last_masked [KERNEL_W_MAX - 1];
      assign shift_in_last  [KERNEL_W_MAX - 1] = acc_m_valid_last_masked [KERNEL_W_MAX - 1];
      assign shift_in_user  [KERNEL_W_MAX - 1] = acc_m_user              [KERNEL_W_MAX - 1];

      n_delay_stream #(
          .N           (1                 ),
          .WORD_WIDTH  (WORD_WIDTH_OUT    ),
          .TUSER_WIDTH (TUSER_WIDTH_CONV  )
      ) SHIFT_REG (
          .aclk       (clk    ),
          .aclken     (clken  ), // = m_ready of outside
          .aresetn    (resetn ),

          .valid_in   (shift_in_valid  [w]),
          .last_in    (shift_in_last   [w]),
          .user_in    (shift_in_user   [w]),

          .valid_out  (shift_out_valid [w]), 
          .last_out   (shift_out_last  [w]),
          .user_out   (shift_out_user  [w])
      );
    end
  endgenerate

  /*
    PAD FILTER
  */

  pad_filter # (
    .KERNEL_W_MAX      (KERNEL_W_MAX      ),
    .TUSER_WIDTH       (TUSER_WIDTH_CONV  ),
    .INDEX_IS_COLS_1_K2(I_IS_COLS_1_K2    ),
    .INDEX_IS_1x1      (I_IS_1X1          )
  )
  pad_filter_dut
  (
    .aclk            (clk               ),
    .aclken          (clken_acc         ),
    .aresetn         (resetn            ),
    .start           (start             ),
    .kernel_w_1_in   (s_user_kernel_w_1 ),
    .valid_last      (acc_m_valid_last  ),
    .user            (acc_m_user        ),
    .mask_partial    (mask_partial      ),
    .mask_full       (mask_full         )
  );

  assign m_valid = shift_out_valid [0];
  assign m_last  = shift_out_last  [0];
  assign m_user  = shift_out_user  [0];

  /*
    CONVOLUTION CORES

    - Each core computes an output channel
    - Pixels step buffer is kept  common to all cores, in engine (here, above)
    - Weights step buffer is placed inside each core, for weights of that output channel
    - Pixels and weights are not in sync at this point. They get into sync after weights buffer
  
  */

  generate
    /*
      PER-CORE STEP BUFFER FOR WEIGHTS
    */
    for (genvar c=0; c < CORES; c++) begin: c_step_weights
      step_buffer  #(
        .WORD_WIDTH       (WORD_WIDTH_IN    ),
        .STEPS            (KERNEL_W_MAX     ),
        .ACCUMULATOR_DELAY(ACCUMULATOR_DELAY),
        .TUSER_WIDTH      (TUSER_WIDTH_CONV )
      ) step_buffer_weights (
        .aclk       (clk),
        .aclken     (conv_s_ready),
        .aresetn    (resetn),
        .is_1x1     (m_shift_pixels_user[I_IS_1X1]),
        
        .s_data     (s_weights_data      [c]),
        .m_data     (m_step_weights_data [c])
      );
    end
    /*
      PER-UNIT STEP BUFFER FOR PIXELS
    */
    for (genvar u=0; u < UNITS; u++) begin: u_step_pixels
      for (genvar w=0 ; w < KERNEL_W_MAX; w++)
          assign s_step_pixels_repeated_data[u][w] = m_shift_pixels_data[u];

      step_buffer  #(
        .WORD_WIDTH       (WORD_WIDTH_IN),
        .STEPS            (KERNEL_W_MAX),
        .ACCUMULATOR_DELAY(ACCUMULATOR_DELAY),
        .TUSER_WIDTH      (TUSER_WIDTH_CONV)
      ) step_buffer_pixels (
        .aclk       (clk          ),
        .aclken     (conv_s_ready ),
        .aresetn    (resetn       ),
        .is_1x1     (m_shift_pixels_user[I_IS_1X1]),
        
        .s_data     (s_step_pixels_repeated_data[u]),
        .m_data     (m_step_pixels_data         [u])
      );
    end

    /*
      DOT PRODUCT CHAIN
    */
    for (genvar c=0; c < CORES; c++) begin: c
      for (genvar u=0; u < UNITS; u++) begin: u        
        for (genvar w=0; w < KERNEL_W_MAX; w++) begin: w

          multiplier multiplier 
          (
            .CLK    (clk      ),
            .CE     (clken_mul),
            .A      (m_step_pixels_data    [u][w]),
            .B      (m_step_weights_data[c]   [w]),
            .P      (mul_m_data         [c][u][w])
          );
          
          if (w==0) begin
            assign acc_s_data [c][u][w] = mul_m_data [c][u][w] & {WORD_WIDTH_IN{mul_m_valid[w]}};
          end
          else begin
            assign mux_s2_data[c][u][w] = acc_m_data [c][u][w-1];
            assign acc_s_data [c][u][w] = mux_sel [w] ? mux_s2_data [c][u][w] : WORD_WIDTH_OUT'(signed'(mul_m_data [c][u][w] & {(WORD_WIDTH_IN*2){mul_m_valid [w]}}));
          end
          
          // AND the input with valid such that invalid inputs are zeroed and accumulated
          accumulator accumulator 
          (
            .CLK    (clk),  
            .BYPASS (first_bypass[w]),  
            .CE     (clken_acc   [w]),  
            .B      (acc_s_data  [c][u][w]),  
            .Q      (acc_m_data  [c][u][w])  
          );

          n_delay_stream #(
              .N           (1             ),
              .WORD_WIDTH  (WORD_WIDTH_OUT),
              .TUSER_WIDTH (TUSER_WIDTH_CONV)
          ) SHIFT_REG (
              .aclk       (clk     ),
              .aclken     (clken   ), // = m_ready of outside
              .aresetn    (resetn ),
              .data_in    (shift_in_data  [c][u][w]),
              .data_out   (shift_out_data [c][u][w])
          );
          
          if (w == KERNEL_W_MAX-1) assign shift_in_data [c][u][w] = acc_m_data [c][u][w];
          else                     assign shift_in_data [c][u][w] = shift_sel  [w] ? shift_out_data [c][u][w+1] : acc_m_data [c][u][w];

          assign m_data [c][u] = shift_out_data  [c][u][0];
        end
      end
    end
  endgenerate

endmodule