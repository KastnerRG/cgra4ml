/*//////////////////////////////////////////////////////////////////////////////////
Engineer: Abarajithan G.
Create Date: 26/07/2020
Design Name: Convolution Engine
Tool Versions: Vivado 2018.2
Dependencies: 
Revision:
Revision 0.01 - File Created
Additional Comments: 
//////////////////////////////////////////////////////////////////////////////////*/
`timescale 1ns/1ps
`include "../params/params.sv"

module proc_engine #(
  localparam  COLS                = `COLS                ,
              ROWS                = `ROWS                ,
              WORD_WIDTH_IN       = `WORD_WIDTH          ,
              WORD_WIDTH_OUT      = `WORD_WIDTH_ACC      ,
              LATENCY_ACCUMULATOR = `LATENCY_ACCUMULATOR ,
              LATENCY_MULTIPLIER  = `LATENCY_MULTIPLIER  ,
              KW_MAX              = `KW_MAX              ,
              SW_MAX              = `SW_MAX              ,
              BITS_OUT_SHIFT      = `BITS_OUT_SHIFT      ,  
              BITS_KW             = `BITS_KW             ,
              BITS_SW             = `BITS_SW             ,
              BITS_MEMBERS        = `BITS_MEMBERS        ,
              BITS_KW2            = `BITS_KW2            ,
              TUSER_WIDTH         = `TUSER_WIDTH         
)(
  input  logic clk, resetn,

  output logic s_ready,
  input  logic s_valid, s_last,
  input  logic [ROWS-1:0][WORD_WIDTH_IN-1:0] s_data_pixels,
  input  logic [COLS-1:0][WORD_WIDTH_IN-1:0] s_data_weights,                                                                        
  input  tuser_st s_user,

  input  logic m_ready,
  output logic m_valid, m_last,
  output logic [COLS-1:0][ROWS-1:0][WORD_WIDTH_OUT-1:0] m_data,
  output tuser_st m_user
);
  logic en, i_valid, i_last;
  logic [COLS-1:0][ROWS -1:0][WORD_WIDTH_OUT-1:0] i_data;
  tuser_st i_user;
  
  logic [BITS_MEMBERS  -1:0] m_shift_a;
  logic [BITS_OUT_SHIFT-1:0] m_shift_b;
  logic [COLS   -1:0][BITS_KW-1:0] m_clr;

  logic clken_mul, mux_sel_next, mux_sel, mul_m_valid, acc_m_valid_next, acc_m_valid, mul_m_last, acc_m_last;
  logic [BITS_KW2-1:0] mul_m_kw2, acc_m_kw2;
  logic [BITS_SW -1:0] acc_m_sw_1;
  logic [COLS   -1: 0] clken_acc, bypass_sum, bypass_sum_next, bypass;
  logic [COLS   -1: 0] acc_m_sum_start, acc_s_valid, acc_m_keep;
  tuser_st mul_m_user, acc_s_user, mux_s2_user, acc_m_user;

  logic [COLS    -1:0] lut_sum_start [KW_MAX/2:0][SW_MAX -1:0];

  logic valid_mask;

  logic [WORD_WIDTH_IN*2-1:0] mul_m_data  [COLS   -1:0][ROWS -1:0];
  logic [WORD_WIDTH_OUT -1:0] acc_s_data  [COLS   -1:0][ROWS -1:0];
  logic [WORD_WIDTH_OUT -1:0] mux_s2_data [COLS   -1:0][ROWS -1:0];

  assign s_ready = clken_mul;

  generate
    genvar u,m,b,kw2,sw_1;

    n_delay #(
      .N          (LATENCY_MULTIPLIER     ),
      .WORD_WIDTH (TUSER_WIDTH + 2)
    ) MUL_CONTROL(
      .clk      (clk      ),
      .resetn   (resetn   ),
      .clken    (clken_mul),
      .data_in  ({s_valid    , s_last    , s_user    }),
      .data_out ({mul_m_valid, mul_m_last, mul_m_user})
    );

    assign mul_m_kw2 = mul_m_user.kw2;

        for (u=0; u < ROWS ; u++)
          for (m=0; m < COLS   ; m++)
            if (m==0) assign mux_s2_data [m][u] = 0;
            else      assign mux_s2_data [m][u] = i_data     [m-1][u];

    assign mux_sel_next = mul_m_valid && mul_m_user.is_cin_last && (mul_m_kw2 != 0);

    register #(
      .WORD_WIDTH     (1),
      .RESET_VALUE    (0)
    ) MUX_SEL (
      .clock          (clk   ),
      .resetn         (resetn),
      .clock_enable   (en    ),
      .data_in        (mux_sel_next),
      .data_out       (mux_sel )
    );
    assign clken_mul = en    && !mux_sel;
            
    for (m=0; m < COLS   ; m++) begin: Mb
      for (kw2=0; kw2 <= KW_MAX/2; kw2++)
        for (sw_1=0; sw_1 < SW_MAX; sw_1++) begin
          localparam k = kw2*2 + 1;
          localparam s = sw_1 + 1;
          localparam j = k + s -1;

          assign lut_sum_start[kw2][sw_1][m] = m % j < s; // m % 3 < 1 : 0,1
        end
      
      assign acc_m_sum_start [m] = lut_sum_start[acc_m_kw2][acc_m_sw_1][m] & acc_m_user.is_sum_start;
      assign acc_s_valid     [m] = mux_sel ? ~acc_m_sum_start [m] : mul_m_valid;

      assign bypass_sum_next [m] = mul_m_user.is_cin_last || mul_m_user.is_config;

      register #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (0)
      ) BYPASS_SUM (
        .clock          (clk   ),
        .resetn         (resetn),
        .clock_enable   (en    && acc_s_valid [m]), // first PE of each elastic core gets bypass for 2 clocks
        .data_in        (bypass_sum_next      [m]),
        .data_out       (bypass_sum           [m])
      );

      assign bypass    [m] = bypass_sum [m] || mul_m_user.is_w_first; // clears all partial sums for every first col
      assign clken_acc [m] = en    && acc_s_valid [m];
    end

        for (u=0; u < ROWS ; u++) begin: Ua
          for (m=0; m < COLS   ; m++) begin: Ma
            proc_element #(
              .WORD_WIDTH_IN (WORD_WIDTH_IN ),
              .WORD_WIDTH_OUT(WORD_WIDTH_OUT)
              ) PE (
              .clk           (clk           ),
              .clken         (en            ),
              .resetn        (resetn        ),
              .clken_mul     (clken_mul     ),
              .s_data_pixels (s_data_pixels    [u]), 
              .s_data_weights(s_data_weights[m]   ),
              .mul_m_data    (mul_m_data    [m][u]),
              .mux_sel       (mux_sel       ),
              .mux_s2_data   (mux_s2_data   [m][u]),
              .bypass        (bypass        [m]),
              .clken_acc     (clken_acc     [m]),
              .acc_s_data    (acc_s_data    [m][u]),
              .m_data        (i_data        [m][u])
            );
    end end

    n_delay #(
      .N          (LATENCY_ACCUMULATOR),
      .WORD_WIDTH (TUSER_WIDTH)
    ) ACC_USER (
      .clk      (clk         ),
      .resetn   (resetn      ),
      .clken    (en    & mul_m_valid),
      .data_in  (mul_m_user  ),
      .data_out (acc_m_user  )
    );

    assign acc_m_kw2  = acc_m_user.kw2;
    assign acc_m_sw_1 = acc_m_user.sw_1;

    assign acc_m_valid_next = !mux_sel && mul_m_valid && (mul_m_user.is_config || mul_m_user.is_cin_last);
    
    n_delay #(
      .N          (LATENCY_ACCUMULATOR),
      .WORD_WIDTH (2)
    ) ACC_VALID_LAST(
      .clk      (clk   ),
      .resetn   (resetn),
      .clken    (en    ),
      .data_in  ({acc_m_valid_next, mul_m_last}),
      .data_out ({acc_m_valid     , acc_m_last})
    );

    pad_filter PAD_FILTER (
      .aclk            (clk                ),
      .aclken          (en                 ),
      .aresetn         (resetn             ),
      .user_in         (acc_m_user         ),
      .valid_in        (acc_m_valid        ),
      .shift_a         (m_shift_a          ),
      .shift_b         (m_shift_b          ),
      .valid_mask      (valid_mask         ),
      .clr             (m_clr              )
    );

    assign i_user.kw2 = acc_m_user.kw2;
    assign i_last  = acc_m_last;
    assign i_valid = acc_m_valid && valid_mask && !acc_m_user.is_config;

    // AXI Stream

    logic valid_prev, i_ready;
    assign en = valid_prev | i_ready;

    register #(
      .WORD_WIDTH (1),
      .RESET_VALUE(1),
      .LOCAL      (0)
    ) VALID_PREV (
      .clock       (clk),
      .clock_enable(1'b1),
      .resetn      (resetn),
      .data_in     (i_valid),
      .data_out    (valid_prev)
    );

    skid_buffer #(
      .WIDTH   (COLS   *ROWS *WORD_WIDTH_OUT + TUSER_WIDTH + 1)
    ) AXIS_REG (
      .aclk    (clk),
      .aresetn (resetn),
      .s_ready (i_ready),
      .s_valid (i_valid),
      .s_data  ({i_data, i_user, i_last}),
      .m_data  ({m_data, m_user, m_last}),
      .m_valid (m_valid),
      .m_ready (m_ready)
    );

  endgenerate
endmodule