module proc_element #(
  parameter
  WORD_WIDTH_IN  = 8,
  WORD_WIDTH_OUT = 24
)(
  clk    ,
  clken  ,
  resetn ,

  clken_mul,
  s_data_pixels, 
  s_data_weights,
  mul_m_data,

  mux_sel,
  mux_s2_data,
  bypass,
  clken_acc,
  acc_s_data,
  m_data
);

  input  logic clk, clken, resetn;
  input  logic clken_mul, mux_sel, bypass, clken_acc;

  input  logic signed [WORD_WIDTH_IN  -1:0] s_data_pixels, s_data_weights;
  input  logic signed [WORD_WIDTH_OUT -1:0] mux_s2_data;
  output logic signed [WORD_WIDTH_IN*2-1:0] mul_m_data;
  output logic signed [WORD_WIDTH_OUT -1:0] acc_s_data;
  output logic signed [WORD_WIDTH_OUT -1:0] m_data;

  // Multiplier

  logic signed [WORD_WIDTH_IN  -1:0] s_data_pixels_q, s_data_weights_q;

  logic mul_in_valid, mul_valid;

  assign mul_in_valid    = (|s_data_pixels) && (|s_data_weights);

  wire clken_mul_valid = clken_mul & mul_in_valid;
  n_delay #(
    .N          (`LATENCY_MULTIPLIER),
    .WORD_WIDTH (WORD_WIDTH_IN*2),
    .LOCAL      (0)
  ) MUL_IN (
    .clk      (clk ),
    .resetn   (1'b1),
    .clken    (clken_mul_valid),
    .data_in  ({s_data_pixels  , s_data_weights  }),
    .data_out ({s_data_pixels_q, s_data_weights_q})
  );
  n_delay #(
    .N          (`LATENCY_MULTIPLIER),
    .WORD_WIDTH (1),
    .LOCAL      (0)
  ) MUL_VALID (
    .clk      (clk ),
    .resetn   (1'b1),
    .clken    (clken_mul),
    .data_in  (mul_in_valid),
    .data_out (mul_valid)
  );

  assign mul_m_data = s_data_pixels_q * s_data_weights_q;

  // Mux

  logic acc_s_valid, acc_s_valid_d, acc_in_valid;

  assign acc_s_data = mux_sel ? mux_s2_data  : WORD_WIDTH_OUT'($signed(mul_m_data));
  assign acc_s_valid = mux_sel ? 1           : mul_valid;

  // Accumulator

  logic bypass_d;
  logic signed [WORD_WIDTH_OUT-1:0] acc_s_data_d;  

  wire clken_acc_s_valid = clken_acc & acc_s_valid;
  n_delay #(
    .N          (`LATENCY_ACCUMULATOR-1),
    .WORD_WIDTH (WORD_WIDTH_OUT +1),
    .LOCAL      (0)
  ) ACC_IN (
    .clk      (clk ),
    .resetn   (1'b1),
    .clken    (clken_acc_s_valid),
    .data_in  ({acc_s_data  , bypass  }),
    .data_out ({acc_s_data_d, bypass_d})
  );
  n_delay #(
    .N          (`LATENCY_ACCUMULATOR-1),
    .WORD_WIDTH (1),
    .LOCAL      (0)
  ) ACC_S_VALID (
    .clk      (clk ),
    .resetn   (1'b1),
    .clken    (clken_acc),
    .data_in  (acc_s_valid),
    .data_out (acc_s_valid_d)
  );

  logic signed [WORD_WIDTH_OUT-1:0] acc_in;
  assign acc_in = (acc_s_valid_d ? acc_s_data_d : 0) + (bypass_d ? 0 : m_data);

  wire clken_acc_valid = clken_acc && (acc_s_valid_d || bypass_d);
  register #(
    .WORD_WIDTH  (WORD_WIDTH_OUT),
    .RESET_VALUE (0),
    .LOCAL       (0)
  ) ACC (
    .clock       (clk),
    .clock_enable(clken_acc_valid),
    .resetn      (1'b1),
    .data_in     (acc_in),
    .data_out    (m_data)
  );

endmodule