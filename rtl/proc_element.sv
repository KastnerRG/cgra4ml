(* use_dsp = "yes" *) module proc_element #(
  parameter
  WORD_WIDTH_IN  = 8,
  WORD_WIDTH_OUT = 24
)(
  input  logic clk, clken, resetn,
  input  logic clken_mul, mux_sel, bypass, clken_acc,

  input  logic signed [WORD_WIDTH_IN  -1:0] s_data_pixels, s_data_weights,
  input  logic signed [WORD_WIDTH_OUT -1:0] mux_s2_data,
  output logic signed [WORD_WIDTH_IN*2-1:0] mul_m_data,
  output logic signed [WORD_WIDTH_OUT -1:0] m_data
);

  // logic signed [WORD_WIDTH_IN*2-1:0] mul_m_data2;
  // always_ff @(posedge clk)
  //   if (clken_mul) mul_m_data2 <= mul_m_data_d;

  wire signed [WORD_WIDTH_IN*2-1:0] mul_m_data_d = s_data_pixels * s_data_weights;
  n_delay #(.N(`LATENCY_MULTIPLIER), .W(WORD_WIDTH_IN*2)) MUL (.c(clk), .rn(1'b1), .e(clken_mul), .i(mul_m_data_d), .o(mul_m_data));
  
  wire signed [WORD_WIDTH_OUT -1:0] add_in_1 = mux_sel ? mux_s2_data  : WORD_WIDTH_OUT'($signed(mul_m_data));
  wire signed [WORD_WIDTH_OUT -1:0] add_in_2 = bypass  ? 0            : m_data;

  always_ff @(posedge clk)
    if (clken_acc) m_data <= add_in_1 + add_in_2;

endmodule