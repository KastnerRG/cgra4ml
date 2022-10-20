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
  localparam KH_MAX        = 3;
  localparam KW_MAX        = 3;
  localparam BITS_KH      = $clog2(KH_MAX+1);
  localparam BITS_KW      = $clog2(KW_MAX+1);
  localparam BITS_KH2     = $clog2((KH_MAX+1)/2);
  localparam BITS_KW2     = $clog2((KW_MAX+1)/2);
  localparam CLR_I_MAX    = KW_MAX      /2;
  localparam BITS_CLR_I   = $clog2(CLR_I_MAX + 1);
  localparam BITS_W_SEL = 2;

  
  localparam W_ADDR_MAX  = calc_beats_max(KW_MAX, MEMBERS);
  localparam BITS_W_ADDR = $clog2(W_ADDR_MAX);

  // Total lut
  localparam BEATS_TOTAL_MAX = calc_beats_total_max (KW_MAX, MEMBERS);
  localparam BITS_BEATS_TOTAL = $clog2(BEATS_TOTAL_MAX+1);
  logic [BITS_BEATS_TOTAL-1:0] lut_lrelu_beats_1 [KW_MAX/2:0];
  generate
    for (genvar KW2=0; KW2 <= KW_MAX/2; KW2++)
      assign lut_lrelu_beats_1[KW2] = calc_beats_total(KW2, MEMBERS) -1;
  endgenerate

  logic rstn;
  logic en;
  logic [BITS_KH2-1 : 0] kh2;
  logic [BITS_KW2-1 : 0] kw2;
  logic full;
  logic [BITS_W_SEL    -1: 0] w_sel;
  logic [BITS_CLR_I    -1: 0] clr_i;
  logic [BITS_KH       -1: 0] mtb;
  logic [BITS_W_ADDR   -1 : 0] w_addr;

  lrelu_beats_counter #(
    .MEMBERS      (MEMBERS     ),
    .KH_MAX       (KH_MAX      ),
    .KW_MAX       (KW_MAX      ),
    .BITS_KW      (BITS_KW     ),
    .BITS_KH      (BITS_KH     )
  ) dut (.*);

  initial begin
    rstn = 0;
    en   = 0;
    kh2  = 3/2;
    kw2  = 3/2;

    repeat(2) @(posedge clk);

    repeat (25) begin
      @(posedge clk); #1 
      en = 1;
    end

    @(posedge clk); #1 
    en = 0;

  end

endmodule