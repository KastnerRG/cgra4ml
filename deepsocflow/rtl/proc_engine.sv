`timescale 1ns/1ps
`include "defines.svh"

module proc_engine #(
  localparam  COLS                = `COLS                ,
              ROWS                = `ROWS                ,
              X_BITS              = `X_BITS              ,
              K_BITS              = `K_BITS              ,
              Y_BITS              = `Y_BITS              ,
              DELAY_ACC           = `DELAY_ACC           ,
              DELAY_MUL           = `DELAY_MUL           ,
              KW_MAX              = `KW_MAX              ,
              TUSER_WIDTH         = `TUSER_WIDTH         ,
              M_BITS              = X_BITS + K_BITS
)(
  input  logic clk, resetn,

  output logic s_ready,
  input  logic s_valid, s_last,
  input  logic [ROWS-1:0][X_BITS-1:0] s_data_pixels,
  input  logic [COLS-1:0][K_BITS-1:0] s_data_weights,                                                                        
  input  tuser_st s_user,

  input  logic m_ready,
  output logic m_valid, m_last,
  output logic [COLS-1:0][ROWS-1:0][Y_BITS-1:0] m_data,
  output tuser_st m_user
);

  logic en, clken_mul, sel_shift_next, sel_shift, mul_m_valid, acc_m_valid_next, acc_m_valid, mul_m_last, acc_m_last;
  tuser_st mul_m_user, acc_s_user, mux_s2_user, acc_m_user;
  logic [COLS-1:0] clken_acc, bypass_sum, bypass_sum_next, bypass, acc_m_sum_start, acc_s_valid, acc_m_keep;
  logic [COLS-1:0] lut_sum_start [KW_MAX/2:0];
  logic [COLS-1:0][ROWS-1:0][M_BITS -1:0] mul_m_data;
  logic [COLS-1:0][ROWS-1:0][Y_BITS -1:0] shift_data, acc_m_data;

  assign s_ready = clken_mul;

  generate
    genvar r,c,kw2,sw_1;
    n_delay #(.N(DELAY_MUL), .W(TUSER_WIDTH+2)) MUL_CONTROL (.c(clk), .rn(resetn), .e(clken_mul), .i({s_valid, s_last, s_user}), .o ({mul_m_valid, mul_m_last, mul_m_user}));

    assign sel_shift_next = mul_m_valid && mul_m_user.is_cin_last && (mul_m_user.kw2 != 0);

    always_ff @(posedge clk)
      if (!resetn) sel_shift <= 0;
      else if (en) sel_shift <= sel_shift_next;

    assign clken_mul = en  && !sel_shift;
            
    for (c=0; c < COLS; c++) begin: Mb
      for (kw2=0; kw2 <= KW_MAX/2; kw2++)
        assign lut_sum_start[kw2][c] = c % (kw2*2+1) == 0; // c % 3 < 1 : 0,1
      
      assign acc_m_sum_start [c] = lut_sum_start[acc_m_user.kw2][c];
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
        assign shift_data [c][r] = c==0 ? 0 : m_data [c-1][r];
        proc_element #(
          .X_BITS (X_BITS),
          .K_BITS (K_BITS),
          .Y_BITS (Y_BITS)
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
          .m_data        (acc_m_data    [c][r])
        );
    end end

    n_delay #(.N(DELAY_ACC), .W(TUSER_WIDTH)) ACC_USER (.c(clk), .rn(resetn), .e(en & mul_m_valid), .i(mul_m_user), .o(acc_m_user));

    assign acc_m_valid_next = !sel_shift && mul_m_valid && (mul_m_user.is_config || mul_m_user.is_cin_last);
    
    n_delay #(.N(DELAY_ACC), .W(2)) ACC_VALID_LAST(.c(clk), .rn(resetn), .e(en), .i({acc_m_valid_next, mul_m_last}), .o({acc_m_valid, acc_m_last}));

    // AXI Stream
    assign en = m_valid ? m_ready : 1;
    assign {m_data, m_valid, m_last, m_user} = {acc_m_data, acc_m_valid, acc_m_last, acc_m_user};

  endgenerate
endmodule