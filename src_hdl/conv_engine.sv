/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.
Create Date: 26/07/2020
Design Name: Convolution Engine
Tool Versions: Vivado 2018.2
Description: 
             * To be tested:
                    - 1x1
                    - NxM
                    - ANY accumulator delay 
             * Limitations
                - 1x1: cin > KW_MAX (this is fine, for 1x1 cins are like 32, 64)
                - 3x3: last 2 cols are flipped
Dependencies: 
Revision:
Revision 0.01 - File Created
Additional Comments: 
//////////////////////////////////////////////////////////////////////////////////*/

`include "params.v"

module conv_engine (
    clk            ,
    clken          ,
    resetn         ,
    s_valid        ,
    s_ready        ,
    s_last         ,
    s_user         ,
    s_data_pixels_1_flat,
    s_data_pixels_2_flat,
    s_data_weights_flat ,
    m_valid        ,
    m_data_flat    ,
    m_last         ,
    m_user_flat    ,     
    m_keep_flat              
  );

  localparam COPIES              = `COPIES              ;
  localparam GROUPS              = `GROUPS              ;
  localparam MEMBERS             = `MEMBERS             ;
  localparam UNITS               = `UNITS               ;
  localparam WORD_WIDTH_IN       = `WORD_WIDTH          ;
  localparam WORD_WIDTH_OUT      = `WORD_WIDTH_ACC      ;
  localparam LATENCY_ACCUMULATOR = `LATENCY_ACCUMULATOR ;
  localparam LATENCY_MULTIPLIER  = `LATENCY_MULTIPLIER  ;
  localparam KERNEL_W_MAX        = `KERNEL_W_MAX        ;
  localparam KERNEL_H_MAX        = `KERNEL_H_MAX        ; // odd number
  localparam IM_CIN_MAX          = `IM_CIN_MAX          ;
  localparam IM_COLS_MAX         = `IM_COLS_MAX         ;
  localparam I_IS_NOT_MAX        = `I_IS_NOT_MAX        ;
  localparam I_IS_MAX            = `I_IS_MAX            ;
  localparam I_IS_1X1            = `I_IS_1X1            ;
  localparam I_IS_LRELU          = `I_IS_LRELU          ;
  localparam I_KERNEL_H_1        = `I_KERNEL_H_1        ;
  localparam I_IS_TOP_BLOCK      = `I_IS_TOP_BLOCK      ;
  localparam I_IS_BOTTOM_BLOCK   = `I_IS_BOTTOM_BLOCK   ;
  localparam I_IS_COLS_1_K2      = `I_IS_COLS_1_K2      ;
  localparam I_IS_CONFIG         = `I_IS_CONFIG         ;
  localparam I_IS_CIN_LAST       = `I_IS_CIN_LAST       ;
  localparam I_KERNEL_W_1        = `I_KERNEL_W_1        ;
  localparam I_CLR               = `I_CLR               ;
  localparam TUSER_WIDTH_CONV_IN = `TUSER_WIDTH_CONV_IN ;
  localparam TUSER_WIDTH_CONV_OUT= `TUSER_WIDTH_LRELU_IN;  

  localparam BITS_IM_CIN        = `BITS_IM_CIN  ;
  localparam BITS_IM_COLS       = `BITS_IM_COLS ;
  localparam BITS_KERNEL_W      = `BITS_KERNEL_W;
  localparam BITS_MEMBERS       = `BITS_MEMBERS ;
  localparam BITS_KW2           = `BITS_KW2     ;

  input  logic clk;
  input  logic clken;
  input  logic resetn;
  input  logic s_valid;
  output logic s_ready;
  input  logic s_last;
  output logic m_valid;
  output logic m_last ;
  input  logic [TUSER_WIDTH_CONV_IN                          -1:0] s_user;
  input  logic [WORD_WIDTH_IN *UNITS                         -1:0] s_data_pixels_1_flat;
  input  logic [WORD_WIDTH_IN *UNITS                         -1:0] s_data_pixels_2_flat;
  input  logic [WORD_WIDTH_IN *COPIES*GROUPS*MEMBERS         -1:0] s_data_weights_flat;                                                                        
  output logic [WORD_WIDTH_OUT*COPIES*GROUPS*MEMBERS*UNITS   -1:0] m_data_flat;
  output logic [WORD_WIDTH_OUT*COPIES*GROUPS*MEMBERS*UNITS/8 -1:0] m_keep_flat;
  output logic [TUSER_WIDTH_CONV_OUT*MEMBERS                 -1:0] m_user_flat;

  logic [WORD_WIDTH_IN         -1:0] s_data_pixels    [COPIES-1:0][UNITS -1:0];
  logic [WORD_WIDTH_IN         -1:0] s_data_weights   [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0];                                                                        
  logic [WORD_WIDTH_OUT        -1:0] m_data           [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0];
  logic [WORD_WIDTH_OUT/8      -1:0] m_keep           [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0];
  logic [TUSER_WIDTH_CONV_OUT  -1:0] m_user           [MEMBERS-1:0];

  assign s_data_pixels    [0] = {>>{s_data_pixels_1_flat}};
  assign s_data_pixels    [1] = {>>{s_data_pixels_2_flat}};
  assign s_data_weights       = {>>{s_data_weights_flat }};
  assign {>>{m_data_flat}}    = m_data;
  assign {>>{m_keep_flat}}    = m_keep;
  assign {>>{m_user_flat}}    = m_user;

  logic [BITS_KERNEL_W  -1:0] s_user_kernel_w_1;
  assign s_user_kernel_w_1 = s_user [I_KERNEL_W_1 + BITS_KERNEL_W-1 : I_KERNEL_W_1];


  logic mux_sel_none ;
  logic clken_mul;
  logic [MEMBERS-1:-1] mux_sel;
  logic [MEMBERS-1: 0] clken_acc, mul_m_valid, mul_m_last, mul_m_cin_last;
  logic [MEMBERS-1: 0] bypass, bypass_next;
  logic [MEMBERS-1: 0] acc_m_valid_delay_in, acc_s_valid, acc_s_last;
  logic [MEMBERS-1: 0] acc_m_valid, acc_m_valid_masked, acc_m_last, acc_m_last_masked;

  logic [BITS_KERNEL_W-1:0] acc_m_kw_1     [MEMBERS -1:0];
  logic [BITS_MEMBERS -1:0] last_m_kw2_lut [KERNEL_W_MAX/2:0];

  logic [MEMBERS-1: 1] selected_valid, mux_sel_en, mux_sel_next;
  logic [MEMBERS-1: 1] mux_s2_valid, mux_m_valid;

  logic [TUSER_WIDTH_CONV_IN -1: 0] mul_m_user    [MEMBERS-1: 0];
  logic [TUSER_WIDTH_CONV_IN -1: 0] acc_s_user    [MEMBERS-1: 0];
  logic [TUSER_WIDTH_CONV_IN -1: 0] mux_s2_user   [MEMBERS-1: 1];
  logic [TUSER_WIDTH_CONV_IN -1: 0] acc_m_user    [MEMBERS-1: 0];

  logic [MEMBERS-1: 1] mask_partial;
  logic [MEMBERS-1: 0] mask_full;
  logic [BITS_KERNEL_W  -1:0] pad_clr    [MEMBERS-1: 0];

  logic [WORD_WIDTH_IN*2-1:0] mul_m_data [COPIES-1:0][GROUPS-1:0][UNITS-1:0][MEMBERS-1:0];
  logic [WORD_WIDTH_OUT -1:0] acc_s_data [COPIES-1:0][GROUPS-1:0][UNITS-1:0][MEMBERS-1:0];
  logic [WORD_WIDTH_OUT -1:0] acc_m_data [COPIES-1:0][GROUPS-1:0][UNITS-1:0][MEMBERS-1:0];

  /*
    CONTROL PATHS
  */
  
  logic [MEMBERS-1:0] s_sub_base, s_sub_base_reg, step_sub_base, mul_m_sub_base, mux_s2_sub_base, acc_s_sub_base, acc_m_sub_base;
  logic sub_base_lut [MEMBERS-1:0][KERNEL_W_MAX/2:0];

  assign mux_sel_none = !(|(mux_sel[MEMBERS-1:0] & ~mul_m_sub_base));
  assign clken_mul    = clken &&  mux_sel_none;

  logic d_valid_ready;

  register #(
    .WORD_WIDTH     (1),
    .RESET_VALUE    (0)
  ) D_VALID_READY (
    .clock          (clk     ),
    .resetn         (resetn  ),
    .clock_enable   (clken   ),
    .data_in        (s_valid && s_ready),
    .data_out       (d_valid_ready     )
  );

  /*
    Variable Step Buffer for control
  */

  logic [WORD_WIDTH_IN      -1:0] m_delay_data_pixels  [COPIES -1:0][UNITS-1  : 0][MEMBERS-1: 0];
  logic [WORD_WIDTH_IN      -1:0] m_delay_data_weights [COPIES -1:0][GROUPS-1 : 0][MEMBERS-1: 0];
  logic                           m_delay_valid        [MEMBERS-1:0];
  logic                           m_delay_last         [MEMBERS-1:0];
  logic [TUSER_WIDTH_CONV_IN-1:0] m_delay_user         [MEMBERS-1:0];

  logic [WORD_WIDTH_IN-1:0]       m_step_data_pixels   [COPIES -1:0][UNITS -1: 0][MEMBERS-1: 0];
  logic [WORD_WIDTH_IN-1:0]       m_step_data_weights  [COPIES -1:0][GROUPS-1: 0][MEMBERS-1: 0];
  logic                           m_step_valid         [MEMBERS-1:0];
  logic                           m_step_last          [MEMBERS-1:0];
  logic [TUSER_WIDTH_CONV_IN-1:0] m_step_user          [MEMBERS-1:0];

  generate
    for (genvar m=0; m < MEMBERS; m++) begin

      logic resetn_base;
      assign resetn_base = resetn   && !(s_sub_base [m] || s_user[I_IS_CONFIG]);

      register #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (0),
        .LOCAL          (1)
      ) STEP_BUFFER_VALID (
        .clock          (clk        ),
        .resetn         (resetn_base),
        .clock_enable   (clken_mul  ),
        .data_in        (s_valid    ),
        .data_out       (m_delay_valid [m])
      );
      register #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (0),
        .LOCAL          (1)
      ) STEP_BUFFER_LAST (
        .clock          (clk         ),
        .resetn         (resetn_base ),
        .clock_enable   (clken_mul   ),
        .data_in        (s_last      ),
        .data_out       (m_delay_last  [m])
      );
      register #(
        .WORD_WIDTH     (TUSER_WIDTH_CONV_IN),
        .RESET_VALUE    (0)
      ) STEP_BUFFER_USER (
        .clock          (clk       ),
        .resetn         (resetn    ),
        .clock_enable   (clken_mul ),
        .data_in        (s_user    ),
        .data_out       (m_delay_user  [m])
      );
    end
  endgenerate

  /*
    STEP DELAY ENABLE
  */
  logic state, state_next;
  localparam S_BLOCK = 1;
  localparam S_PASS  = 0;

  for (genvar m=0; m<MEMBERS; m++) begin

    for (genvar kw2=0; kw2 < KERNEL_W_MAX/2 +1; kw2++)
      assign sub_base_lut[m][kw2] = (m % (kw2*2 + 1) == 0);

    assign s_sub_base [m] = sub_base_lut[m][s_user_kernel_w_1/2];
  end

  register #(
    .WORD_WIDTH     (MEMBERS ),
    .RESET_VALUE    (0       )
  ) S_SUB_BASE_REG (
    .clock          (clk           ),
    .resetn         (resetn        ),
    .clock_enable   (clken_mul     ),
    .data_in        (s_sub_base    ),
    .data_out       (s_sub_base_reg)
  );

  assign step_sub_base = (state == S_PASS) ? s_sub_base : s_sub_base_reg;

  for (genvar m=0; m<MEMBERS; m++) begin
    assign m_step_valid  [m] = step_sub_base [m] || s_user[I_IS_CONFIG] ? s_valid : m_delay_valid [m];
    assign m_step_last   [m] = step_sub_base [m] || s_user[I_IS_CONFIG] ? s_last  : m_delay_last  [m];
    assign m_step_user   [m] = step_sub_base [m] || s_user[I_IS_CONFIG] ? s_user  : m_delay_user  [m];
  end

  /*
    STATE MACHINE FOR S_BLOCKING
  */

  always_comb begin
    state_next = state;
    unique case (state)
      S_PASS  : if (s_valid && s_ready && s_last        ) state_next = S_BLOCK;
      S_BLOCK : if (!(m_step_valid[0] && m_step_last[0])) state_next = S_PASS ; 
      // S_BLOCK->S_PASS when valid_last clears
      // NOTE: step[0] = |(step[:]), since it is always delayed for kw>1
    endcase
  end

  register #(
    .WORD_WIDTH     (1),
    .RESET_VALUE    (S_PASS)
  ) STATE_S_BLOCK (
    .clock          (clk    ),
    .resetn         (resetn ),
    .clock_enable   (clken_mul ),
    .data_in        (state_next),
    .data_out       (state     )
  );

  assign s_ready       = (state == S_PASS) ? clken_mul  : 0;

  /*
    CONTROL CHAINS
  */
  generate
    for (genvar m=0; m < MEMBERS; m++) begin: m_gen

      /*
        Multiplier Delay
      */

      n_delay_stream #(
        .N          (LATENCY_MULTIPLIER   ),
        .WORD_WIDTH (WORD_WIDTH_IN        ),
        .TUSER_WIDTH(TUSER_WIDTH_CONV_IN+1)
      ) LATENCY_MULTIPLIER_CONTROL (
        .aclk       (clk),
        .aclken     (clken_mul),
        .aresetn    (resetn),

        .valid_in   (m_step_valid  [m]),
        .last_in    (m_step_last   [m]),
        .user_in    ({m_step_user  [m], step_sub_base  [m]}),

        .valid_out  (mul_m_valid [m]),
        .last_out   (mul_m_last  [m]),
        .user_out   ({mul_m_user [m], mul_m_sub_base [m]})
      );

      /*
        Directly connect Mul_0 to Acc_0
      */
      assign acc_s_valid    [0] = mul_m_valid [0] && mux_sel_none;
      
      assign acc_s_last     [0] = mul_m_last      [0];
      assign acc_s_user     [0] = mul_m_user      [0];
      assign acc_s_sub_base [0] = mul_m_sub_base  [0];

      /*
        MUX SEL

        * 1x1 : mux_sel   [i] = 0 ; permanently connecting mul to acc
        * NOTE: sel_register is updated using the true acc_m_valid, not pad_filtered one

        * nxm : Delays inside step_buffer should sync perfectly, such that
          for every datapath[i] (except 0):

        * See architecture.xlsx for required clock by clock operation
      */
      assign mux_sel[ 0] = 0;
      assign mux_sel[-1] = 0;
      assign mul_m_cin_last[m] = mul_m_user[m][I_IS_CIN_LAST];

      /*
      Switching logic:

      1. mux_sel_next    = mul_m_cin_last && mul_m_sub_base
      2. mux_sel        <= mux_sel_next @ mux_sel_en
      3. selected_valid  = mux_sel==0 ? mul_m_valid : acc_m_valid
      4. mux_sel_en      = selected_valid && clken
      5. mux_sel_none    = ...
      
      */

      if (m !=0 ) begin
        assign selected_valid [m] = (mux_sel[m]==0) ? mul_m_valid [m] : acc_m_valid [m-1];
        assign mux_sel_en     [m] = clken && selected_valid [m];
        assign mux_sel_next   [m] = mul_m_cin_last[m] && (!mul_m_sub_base[m]);
        
        register #(
          .WORD_WIDTH     (1),
          .RESET_VALUE    (0)
        ) MUX_SEL (
          .clock          (clk    ),
          .resetn         (resetn),
          .clock_enable   (mux_sel_en   [m]),
          .data_in        (mux_sel_next [m]),
          .data_out       (mux_sel      [m])
        );

        assign mux_s2_valid     [m] = acc_m_valid      [m-1] && mask_partial[m];
        assign mux_s2_user      [m] = acc_m_user       [m-1];
        assign mux_s2_sub_base  [m] = acc_m_sub_base   [m-1];

        assign mux_m_valid   [m] = mux_sel [m]    ?  mux_s2_valid [m]      : mul_m_valid [m];

        assign acc_s_valid   [m] = mux_m_valid[m] && (mux_sel         [m] || mux_sel_none);
        assign acc_s_user    [m] = mux_sel    [m] ?   mux_s2_user     [m]  : mul_m_user     [m];
        assign acc_s_sub_base[m] = mux_sel    [m] ?   mux_s2_sub_base [m]  : mul_m_sub_base [m];
        assign acc_s_last    [m] = mux_sel    [m] ?   0                    : mul_m_last     [m];
      end

      /* 
        CLKEN ACCUMULATOR

        * For datapath[0], keep accumulator enabled when "mux_sel_none"
        * Other datapaths, allow accumulator if:
          - mux_sel_none : to accumulate normal mul_m_data
          - mux_sel[w]   : to accumulate acc_m_data[w-1]
                          - &!mux_sel[w-1] : S_BLOCK when the lower accumulator is accumulating
        * See architecture.xlsx
      */
      assign clken_acc[m] = mul_m_sub_base[m] ? clken_mul : clken && (mux_sel_none || (mux_sel[m] && !mux_sel[m-1]));

      /*
        bypass

        * bypass => Fresh data
        * First data doesn't need bypass, since its fresh.
        * Hence we delay (is_cin_last || is_config)
        * enable: acc_s_valid, to delay by a data beat
      */

      assign bypass_next [m] = mul_m_user [m][I_IS_CONFIG] || mul_m_user [m][I_IS_CIN_LAST];

      register #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (0)
      ) bypass (
        .clock          (clk),
        .resetn         (resetn),
        .clock_enable   (acc_s_valid  [m] && clken_acc[m]),
        .data_in        (bypass_next  [m]),
        .data_out       (bypass       [m])
      );

      /*
        VALID DELAY

        * acc_m_valid should go high
          - after accumulating c_in data beats
          - for every beat during config
      */

      assign acc_m_valid_delay_in [m] = acc_s_valid [m] && (mul_m_cin_last[m] || mul_m_user[m][I_IS_CONFIG]);

      n_delay_stream #(
        .N              (LATENCY_ACCUMULATOR   ),
        .WORD_WIDTH     (1                     ),
        .TUSER_WIDTH    (TUSER_WIDTH_CONV_IN +1)
      ) LATENCY_ACCUMULATOR_CONTROL (
        .aclk       (clk   ),
        .aclken     (clken_acc   [m]),
        .aresetn    (resetn),

        .valid_in   (acc_m_valid_delay_in [m]),
        .last_in    (acc_s_last  [m]),
        .user_in    ({acc_s_user [m], acc_s_sub_base[m]}),

        .valid_out  (acc_m_valid [m]),
        .last_out   (acc_m_last  [m]),
        .user_out   ({acc_m_user [m], acc_m_sub_base[m]})
      );

      /*
        MASKING

        * m_valid - kept high for only one clock (since masked by clken_acc) and by pad filter

        * m_last  - acc_m_last goes high in all accumulators
                  - but m_last goes high only in the highest valid accumulator
                    - Eg: MEMBERS = 24:
                          - kw = 1 : w = 23
                          - kw = 3 : w = 23
                          - kw = 5 : w = 19
                    - Formula: (MEMBERS-1 - MEMBERS % kw)
      */
      
      if (m == 0)
        for (genvar kw2=0; kw2 <= KERNEL_W_MAX/2; kw2++) begin
          localparam kw = kw2*2 + 1;
          assign last_m_kw2_lut[kw2] = (MEMBERS/kw)*kw-1; // (12/3)*3-1 = 12-1 = 11
        end

      assign acc_m_kw_1         [m] = acc_m_user[m][BITS_KERNEL_W+I_KERNEL_W_1-1 : I_KERNEL_W_1];

      assign acc_m_last_masked  [m] = clken_acc[m] & acc_m_last [m] & (m == last_m_kw2_lut[acc_m_kw_1[m]/2]);
      assign acc_m_valid_masked [m] = clken_acc[m] & acc_m_valid[m] & mask_full[m];

    end
  endgenerate

  /*
    PAD FILTER
  */

  pad_filter # (
    .MEMBERS       (MEMBERS            ),
    .KERNEL_W_MAX  (KERNEL_W_MAX       ),
    .TUSER_WIDTH   (TUSER_WIDTH_CONV_IN),
    .I_IS_COLS_1_K2(I_IS_COLS_1_K2     ),
    .I_IS_CONFIG   (I_IS_CONFIG        ),
    .I_IS_1X1      (I_IS_1X1           ),
    .I_IS_CIN_LAST (I_IS_CIN_LAST      ),
    .I_KERNEL_W_1  (I_KERNEL_W_1       )
  )
  pad_filter_dut
  (
    .aclk            (clk               ),
    .aclken          (clken_acc         ),
    .aresetn         (resetn            ),
    .user_in         (acc_m_user        ),
    .valid_in        (acc_m_valid       ),
    .valid_masked_in (acc_m_valid_masked),
    .mask_partial    (mask_partial      ),
    .mask_full       (mask_full         ),
    .clr             (pad_clr           )
  );


  /*
    CONVOLUTION CORES

    - Each core computes an output channel
    - Pixels step buffer is kept  common to all cores
    - Weights step buffer is placed inside each core, for weights of that output channel  
  */



  generate
    /* PER-COPY*/
    for (genvar c=0; c < COPIES; c++) begin: c_step
      for (genvar g=0; g < GROUPS; g++) begin
        for (genvar m=0 ; m < MEMBERS; m++) begin
          n_delay #(
            .N (1),
            .WORD_WIDTH (WORD_WIDTH_IN)
          )
          DELAY_DATA_WEIGHTS
          (
            .clk      (clk      ),
            .resetn   (resetn   ),
            .clken    (clken_mul),
            .data_in  (s_data_weights      [c][g][m]),
            .data_out (m_delay_data_weights[c][g][m])
          );
          assign m_step_data_weights [c][g][m] = step_sub_base [m]  || s_user[I_IS_CONFIG] ? s_data_weights[c][g][m] : m_delay_data_weights[c][g][m];
        end
      end

      for (genvar u=0; u < UNITS; u++) begin
        for (genvar m=0 ; m < MEMBERS; m++) begin
          n_delay #(
            .N (1),
            .WORD_WIDTH (WORD_WIDTH_IN)
          )
          DELAY_DATA_PIXELS
          (
            .clk      (clk      ),
            .resetn   (resetn   ),
            .clken    (clken_mul),
            .data_in  (s_data_pixels      [c][u]),
            .data_out (m_delay_data_pixels[c][u][m])
          );
          assign m_step_data_pixels [c][u][m] = step_sub_base [m]  || s_user[I_IS_CONFIG] ? s_data_pixels[c][u] : m_delay_data_pixels[c][u][m];
        end
      end
    end

    /*
      DOT PRODUCT CHAIN
    */
    for (genvar c=0; c < COPIES; c++) begin: c_gen
      for (genvar g=0; g < GROUPS; g++) begin: r_gen
        for (genvar u=0; u < UNITS; u++) begin: u_gen
          for (genvar m=0; m < MEMBERS; m++) begin: m_gen

            multiplier multiplier 
            (
              .CLK    (clk      ),
              .CE     (clken_mul),
              .A      (m_step_data_pixels [c]   [u][m]),
              .B      (m_step_data_weights[c][g]   [m]),
              .P      (mul_m_data         [c][g][u][m])
            );
            
            assign acc_s_data [c][g][u][m] = (m!=0) && mux_sel [m] ? acc_m_data [c][g][u][m-1] : WORD_WIDTH_OUT'(signed'(mul_m_data [c][g][u][m] & {(WORD_WIDTH_IN*2){mul_m_valid [m]}}));
            // AND the input with valid such that invalid inputs are zeroed and accumulated
            
            accumulator accumulator 
            (
              .CLK    (clk),  
              .bypass (bypass      [m]),  
              .CE     (clken_acc   [m]),  
              .B      (acc_s_data  [c][g][u][m]),  
              .Q      (acc_m_data  [c][g][u][m])  
            );

            assign m_data [c][g][m][u] = acc_m_data [c][g][u][m];
          end
        end
      end
    end

    for (genvar m=0; m<MEMBERS; m++) begin
      assign m_user [m][I_IS_BOTTOM_BLOCK:I_IS_NOT_MAX] = acc_m_user [m][I_IS_BOTTOM_BLOCK:I_IS_NOT_MAX];
      assign m_user [m][I_CLR+BITS_KERNEL_W-1 :  I_CLR] = pad_clr    [m];

      assign m_last = |acc_m_last_masked;

      for (genvar c=0; c<COPIES; c++)
        for (genvar g=0; g<GROUPS; g++)
          for (genvar u=0; u<UNITS; u++)
            for (genvar b=0; b<WORD_WIDTH_OUT/8; b++)
              assign m_keep [c][g][m][u][b] = acc_m_valid_masked [m];
    end

    assign m_valid = |acc_m_valid_masked;
  endgenerate

endmodule