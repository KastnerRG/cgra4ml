module lrelu_beats_counter_tb ();
  timeunit 10ns;
  timeprecision 1ns;
  localparam CLK_PERIOD = 10;
  logic clk;
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk <= ~clk;
  end

  localparam MEMBERS       = 12;
  localparam KERNEL_H_MAX  = 3;
  localparam KERNEL_W_MAX  = 3;
  localparam BITS_KERNEL_H = $clog2(KERNEL_H_MAX);
  localparam BITS_KERNEL_W = $clog2(KERNEL_W_MAX);
  localparam CLR_I_MAX    = KERNEL_W_MAX/2;
  localparam BITS_CLR_I   = $clog2(CLR_I_MAX + 1);
  localparam BITS_W_SEL = 2;
  localparam W_ADDR_MAX  = lrelu_beats::calc_beats_max(.KERNEL_W_MAX(KERNEL_W_MAX), .MEMBERS(MEMBERS));
  localparam BITS_W_ADDR = $clog2(W_ADDR_MAX);

  // Total lut
  localparam BEATS_TOTAL_MAX = lrelu_beats::calc_beats_total_max (.KERNEL_W_MAX(KERNEL_W_MAX), .MEMBERS(MEMBERS));
  localparam BITS_BEATS_TOTAL = $clog2(BEATS_TOTAL_MAX+1);
  logic [BITS_BEATS_TOTAL-1:0] lut_lrelu_beats_1 [KERNEL_W_MAX/2:0];
  generate
    for (genvar KW2=0; KW2 <= KERNEL_W_MAX/2; KW2++)
      assign lut_lrelu_beats_1[KW2] = lrelu_beats::calc_beats_total (.kw2(KW2), .MEMBERS(MEMBERS)) -1;
  endgenerate

  logic rstn;
  logic en;
  logic [BITS_KERNEL_H-1 : 0] kh_1;
  logic [BITS_KERNEL_W-1 : 0] kw_1;
  logic full;
  logic [BITS_W_SEL    -1: 0] w_sel;
  logic [BITS_CLR_I    -1: 0] clr_i;
  logic [BITS_KERNEL_H -1: 0] mtb;
  logic [BITS_W_ADDR   -1 : 0] w_addr;

  lrelu_beats_counter #(
    .MEMBERS      (MEMBERS     ),
    .KERNEL_H_MAX (KERNEL_H_MAX),
    .KERNEL_W_MAX (KERNEL_W_MAX),
    .BITS_KERNEL_W(BITS_KERNEL_W),
    .BITS_KERNEL_H(BITS_KERNEL_H)
  ) dut (.*);

  initial begin
    rstn = 0;
    en   = 0;
    kh_1 = 3-1;
    kw_1 = 3-1;

    repeat(2) @(posedge clk);

    repeat (25) begin
      @(posedge clk); #1 
      en = 1;
    end

    @(posedge clk); #1 
    en = 0;

  end

endmodule