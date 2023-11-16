(* use_dsp = "yes" *) module proc_element #(
  parameter
    X_BITS = 8,
    K_BITS = 4,
    Y_BITS = 24,
    M_BITS = X_BITS + K_BITS
)(
  input  logic clk, clken, resetn,
  input  logic clken_mul, sel_shift, bypass, clken_acc,

  input  logic signed [X_BITS-1:0] s_data_pixels,
  input  logic signed [K_BITS-1:0] s_data_weights,
  input  logic signed [Y_BITS-1:0] shift_data,
  output logic signed [M_BITS-1:0] mul_m_data,
  output logic signed [Y_BITS-1:0] m_data
);

  // logic signed [M_BITS-1:0] mul_m_data2;
  // always_ff @(posedge clk)
  //   if (clken_mul) mul_m_data2 <= mul_m_data_d;

  wire signed [M_BITS-1:0] mul_m_data_d = s_data_pixels * s_data_weights;
  n_delay #(.N(`DELAY_MUL), .W(M_BITS)) MUL (.c(clk), .rn(1'b1), .e(clken_mul), .i(mul_m_data_d), .o(mul_m_data));
  
  wire signed [Y_BITS -1:0] add_in_1 = sel_shift ? shift_data : Y_BITS'($signed(mul_m_data));
  wire signed [Y_BITS -1:0] add_in_2 = bypass    ? 0          : m_data;

  always_ff @(posedge clk)
    if (clken_acc) m_data <= add_in_1 + add_in_2;

endmodule