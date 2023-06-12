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
`include "../rtl/include/params.svh"

module proc_engine #(
  localparam  COLS                = `COLS                ,
              ROWS                = `ROWS                ,
              WORD_WIDTH_IN       = `WORD_WIDTH          ,
              WORD_WIDTH_OUT      = `WORD_WIDTH_ACC      ,
              LATENCY_ACCUMULATOR = `LATENCY_ACCUMULATOR ,
              LATENCY_MULTIPLIER  = `LATENCY_MULTIPLIER  ,
              KW_MAX              = `KW_MAX              ,
              SW_MAX              = `SW_MAX              ,
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

  logic clken_mul, sel_shift_next, sel_shift, mul_m_valid, acc_m_valid_next, acc_m_valid, mul_m_last, acc_m_last;
  logic [COLS   -1: 0] clken_acc, bypass_sum, bypass_sum_next, bypass;
  logic [COLS   -1: 0] acc_m_sum_start, acc_s_valid, acc_m_keep;
  tuser_st mul_m_user, acc_s_user, mux_s2_user, acc_m_user;

  logic [COLS    -1:0] lut_sum_start [KW_MAX/2:0][SW_MAX -1:0];

  logic [WORD_WIDTH_IN*2-1:0] mul_m_data  [COLS   -1:0][ROWS -1:0];
  logic [WORD_WIDTH_OUT -1:0] shift_data  [COLS   -1:0][ROWS -1:0];

  assign s_ready = clken_mul;

  generate
    genvar r,c,kw2,sw_1;
    n_delay #(.N(LATENCY_MULTIPLIER), .W(TUSER_WIDTH+2)) MUL_CONTROL (.c(clk), .rn(resetn), .e(clken_mul), .i({s_valid, s_last, s_user}), .o ({mul_m_valid, mul_m_last, mul_m_user}));

    assign sel_shift_next = mul_m_valid && mul_m_user.is_cin_last && (mul_m_user.kw2 != 0);

    always_ff @(posedge clk)
      if (!resetn) sel_shift <= 0;
      else if (en) sel_shift <= sel_shift_next;

    assign clken_mul = en  && !sel_shift;
            
    for (c=0; c < COLS   ; c++) begin: Mb
      for (kw2=0; kw2 <= KW_MAX/2; kw2++)
        for (sw_1=0; sw_1 < SW_MAX; sw_1++) begin
          localparam k = kw2*2 + 1;
          localparam s = sw_1 + 1;
          localparam j = k + s -1;

          assign lut_sum_start[kw2][sw_1][c] = c % j < s; // c % 3 < 1 : 0,1
        end
      
      assign acc_m_sum_start [c] = lut_sum_start[acc_m_user.kw2][acc_m_user.sw_1][c];
      assign acc_s_valid     [c] = sel_shift ? ~acc_m_sum_start [c] : mul_m_valid;
      assign clken_acc       [c] = en    && acc_s_valid [c];

      assign bypass_sum_next [c] = mul_m_user.is_cin_last || mul_m_user.is_config;

      always_ff @(posedge clk)
        if (!resetn)            bypass_sum [c] <= 0;
        else if (clken_acc [c]) bypass_sum [c] <= bypass_sum_next [c];

      assign bypass    [c] = bypass_sum [c] || mul_m_user.is_w_first_clk; // clears all partial sums for every first col

    end

    for (r=0; r < ROWS ; r++) begin: Ua
      for (c=0; c < COLS   ; c++) begin: Ma
        assign shift_data [c][r] = c==0 ? 0 : i_data [c-1][r];
        proc_element #(
          .WORD_WIDTH_IN (WORD_WIDTH_IN ),
          .WORD_WIDTH_OUT(WORD_WIDTH_OUT)
          ) PE (
          .clk           (clk           ),
          .clken         (en            ),
          .resetn        (resetn        ),
          .clken_mul     (clken_mul     ),
          .sel_shift     (sel_shift     ),
          .s_data_pixels (s_data_pixels    [r]), 
          .s_data_weights(s_data_weights[c]   ),
          .mul_m_data    (mul_m_data    [c][r]),
          .shift_data    (shift_data    [c][r]),
          .bypass        (bypass        [c]),
          .clken_acc     (clken_acc     [c]),
          .m_data        (i_data        [c][r])
        );
    end end

    n_delay #(.N(LATENCY_ACCUMULATOR), .W(TUSER_WIDTH)) ACC_USER (.c(clk), .rn(resetn), .e(en & mul_m_valid), .i(mul_m_user), .o(acc_m_user));

    assign acc_m_valid_next = !sel_shift && mul_m_valid && (mul_m_user.is_config || mul_m_user.is_cin_last);
    
    n_delay #(.N(LATENCY_ACCUMULATOR), .W(2)) ACC_VALID_LAST(.c(clk), .rn(resetn), .e(en), .i({acc_m_valid_next, mul_m_last}), .o({acc_m_valid, acc_m_last}));

    // AXI Stream

    assign i_user  = acc_m_user;
    assign i_last  = acc_m_last;
    assign i_valid = acc_m_valid;

    logic valid_prev, i_ready;
    assign en = valid_prev | i_ready;

    always_ff @(posedge clk)
      if (!resetn)  valid_prev <= 0;
      else          valid_prev <= i_valid;

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