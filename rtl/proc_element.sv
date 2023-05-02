module proc_element #(
  parameter
  WORD_WIDTH_IN  = 8,
  WORD_WIDTH_OUT = 24
)(
  input  logic clk, clken, resetn,
  input  logic clken_mul, mux_sel, bypass, clken_acc,

  input  logic signed [WORD_WIDTH_IN  -1:0] s_data_pixels, s_data_weights,
  input  logic signed [WORD_WIDTH_OUT -1:0] mux_s2_data,
  output logic signed [WORD_WIDTH_IN*2-1:0] mul_m_data,
  output logic signed [WORD_WIDTH_OUT -1:0] acc_s_data,
  output logic signed [WORD_WIDTH_OUT -1:0] m_data
);


  // Multiplier

  logic signed [WORD_WIDTH_IN  -1:0] s_data_pixels_q, s_data_weights_q;

  logic mul_in_valid, mul_valid;

  assign mul_in_valid    = (|s_data_pixels) && (|s_data_weights);

  wire clken_mul_valid = clken_mul & mul_in_valid;
  n_delay #(.N(`LATENCY_MULTIPLIER), .W(WORD_WIDTH_IN*2)) MUL_IN (.c(clk), .rn (1'b1), .e(clken_mul_valid), .i({s_data_pixels  , s_data_weights  }), .o ({s_data_pixels_q, s_data_weights_q}));
  n_delay #(.N(`LATENCY_MULTIPLIER), .W(1)) MUL_VALID            (.c(clk), .rn (1'b1), .e(clken_mul      ), .i(mul_in_valid),                        .o (mul_valid));

  assign mul_m_data = s_data_pixels_q * s_data_weights_q;

  // Mux

  logic acc_s_valid, acc_s_valid_d, acc_in_valid;

  assign acc_s_data = mux_sel ? mux_s2_data  : WORD_WIDTH_OUT'($signed(mul_m_data));
  assign acc_s_valid = mux_sel ? 1           : mul_valid;

  // Accumulator

  logic bypass_d;
  logic signed [WORD_WIDTH_OUT-1:0] acc_s_data_d;  

  wire clken_acc_s_valid = clken_acc & acc_s_valid;
  n_delay #(.N(`LATENCY_ACCUMULATOR-1), .W (WORD_WIDTH_OUT +1)) ACC_IN (.c(clk), .rn(1'b1), .e (clken_acc_s_valid), .i({acc_s_data, bypass}), .o({acc_s_data_d, bypass_d}));
  n_delay #(.N(`LATENCY_ACCUMULATOR-1), .W (1))            ACC_S_VALID (.c(clk), .rn(1'b1), .e (clken_acc),         .i(acc_s_valid),          .o(acc_s_valid_d));

  logic signed [WORD_WIDTH_OUT-1:0] acc_in;
  assign acc_in = (acc_s_valid_d ? acc_s_data_d : 0) + (bypass_d ? 0 : m_data);

  wire clken_acc_valid = clken_acc && (acc_s_valid_d || bypass_d);

  always_ff @(posedge clk)
    if (clken_acc_valid) m_data <= acc_in;

endmodule