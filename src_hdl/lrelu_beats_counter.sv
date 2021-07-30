`include "params.v"

package lrelu_beats;

  function integer calc_beats_b (
      input integer clr_i, 
      input integer  kw2, 
      input integer MEMBERS
    );
    
    automatic integer clr_kw, kw, WIDTH_Bi, WRITE_DEPTH;
    
    clr_kw  = clr_i*2 + 1;
    kw      = kw2  *2 + 1;

    WIDTH_Bi    = MEMBERS/clr_kw;
    WRITE_DEPTH = 2*(MEMBERS/kw);
    
    calc_beats_b  = `CEIL(WRITE_DEPTH, WIDTH_Bi);
  endfunction

  function integer calc_beats_max (
      input integer KERNEL_W_MAX, 
      input integer MEMBERS 
    );
    calc_beats_max = 2; // max(A)
    for (int kw2 = 0; kw2 <= KERNEL_W_MAX/2; kw2++) begin
      automatic int kw = kw2*2 +1;
      for (int clr_i = 0; clr_i <= kw2; clr_i++) begin
        automatic int beats_b = calc_beats_b(.clr_i(clr_i), .kw2(kw2), .MEMBERS(MEMBERS));
        calc_beats_max = beats_b > calc_beats_max ? beats_b : calc_beats_max;
      end
    end    
  endfunction

  function integer calc_beats_total (
      input integer  kw2, 
      input integer MEMBERS
    );

    automatic integer kw = kw2*2 + 1;
    calc_beats_total = 1 + `CEIL(2, kw);
    
    for (int clr_i = 0; clr_i <= kw2; clr_i++)
      for (int mtb = 0; mtb <= clr_i*2; mtb++)
        calc_beats_total += calc_beats_b(.clr_i(clr_i), .kw2(kw2), .MEMBERS(MEMBERS));

  endfunction

  function integer calc_beats_total_max (
      input integer KERNEL_W_MAX, 
      input integer MEMBERS 
    );
    calc_beats_total_max = 2; // max(A)
    for (int kw2 = 0; kw2 <= KERNEL_W_MAX/2; kw2++) begin
      automatic integer beats_tot = calc_beats_total(.kw2(kw2), .MEMBERS(MEMBERS));
      calc_beats_total_max = beats_tot > calc_beats_total_max ? beats_tot : calc_beats_total_max;
    end
  endfunction

endpackage

module lrelu_beats_counter (
  clk,
  rstn,
  en,
  kh_1,
  kw_1,

  full,
  w_sel,
  clr_i,
  mtb,
  w_addr
);
  /*
    w_sel:
      0 : IDLE
      1 : D Register
      2 : BRAM_A
      3 : BRAM_B_ij
    
    clr_i [0: bits((KW_MAX+1)/2)-1]
      0 : fills (clr = 0)
      1 : fills (clr = 1,2)
      2 : fills (clr = 3,4)
      3 : fills (clr = 5,6)

    mtb   [0:kh-1]
  */

  parameter MEMBERS       = `MEMBERS     ;
  parameter KERNEL_H_MAX  = `KERNEL_H_MAX;
  parameter KERNEL_W_MAX  = `KERNEL_W_MAX;
  parameter BITS_KERNEL_H = `BITS_KERNEL_H;
  parameter BITS_KERNEL_W = `BITS_KERNEL_W;

  localparam CLR_I_MAX    = KERNEL_W_MAX/2;
  localparam BITS_CLR_I   = $clog2(CLR_I_MAX + 1);

  localparam BITS_W_SEL = 2;

  localparam W_ADDR_MAX  = lrelu_beats::calc_beats_max(.KERNEL_W_MAX(KERNEL_W_MAX), .MEMBERS(MEMBERS));
  localparam BITS_W_ADDR = $clog2(W_ADDR_MAX);

  input  logic clk;
  input  logic rstn;
  input  logic en;
  input  logic [BITS_KERNEL_H-1 : 0] kh_1;
  input  logic [BITS_KERNEL_W-1 : 0] kw_1;

  output logic full;
  output logic [BITS_W_SEL    -1: 0] w_sel;
  output logic [BITS_CLR_I    -1: 0] clr_i;
  output logic [BITS_KERNEL_H -1: 0] mtb;
  output logic [BITS_W_ADDR   -1 : 0] w_addr;

  logic [BITS_W_SEL    -1: 0] w_sel_next;
  logic [BITS_CLR_I    -1: 0] clr_i_next;
  logic [BITS_KERNEL_H -1: 0] mtb_next  ;
  logic [BITS_W_ADDR   -1: 0] w_addr_next;

  logic clr_i_last, mtb_last, a_w_addr_last, b_w_addr_last;
  logic en_w_addr, en_mtb, en_clr_i, en_w_sel;

  logic [BITS_W_ADDR-1:0] lut_beats_1_bram_a_kw2      [KERNEL_W_MAX/2:0];
  logic [BITS_W_ADDR-1:0] lut_beats_1_bram_b_kw2_clri [KERNEL_W_MAX/2:0][KERNEL_W_MAX/2:0];
  generate
    for (genvar KW2=0; KW2 <= KERNEL_W_MAX/2; KW2++) begin
      localparam KW = KW2*2+1;
      assign lut_beats_1_bram_a_kw2[KW2] = `CEIL(2, KW)-1;

      for (genvar CLR_I = 0; CLR_I <= KW2; CLR_I++)
        assign lut_beats_1_bram_b_kw2_clri[KW2][CLR_I] = lrelu_beats::calc_beats_b(.clr_i(CLR_I), .kw2(KW2), .MEMBERS(MEMBERS)) -1;
    end
  endgenerate

  /*
    STATE MACHINE
  */

  localparam S_REG_D  = 1;
  localparam S_BRAM_A = 2;
  localparam S_BRAM_B = 3;


  // NEXT
  always_comb begin
    w_sel_next  = w_sel;
    unique case (w_sel)
      S_REG_D  :  w_sel_next = S_BRAM_A;
      S_BRAM_A :  w_sel_next = S_BRAM_B;
      S_BRAM_B :  w_sel_next = S_REG_D;
    endcase
  end
  assign clr_i_next  = clr_i_last  ? 0 : clr_i  + 1;
  assign mtb_next    = mtb_last    ? 0 : mtb    + 1;
  assign w_addr_next = (a_w_addr_last || b_w_addr_last) ? 0 : w_addr + 1;


  // LAST
  assign clr_i_last    = clr_i == kw_1/2;  // to generalize: max(kw_1/2, kh/2)
  assign mtb_last      = mtb   == clr_i*2; // to generalize: min(2*clr_i, kh-1)
  assign a_w_addr_last = w_sel == S_BRAM_A  &&  w_addr == lut_beats_1_bram_a_kw2     [kw_1/2];
  assign b_w_addr_last = w_sel == S_BRAM_B  &&  w_addr == lut_beats_1_bram_b_kw2_clri[kw_1/2][clr_i];

  // FULL
  assign full = b_w_addr_last && mtb_last && clr_i_last;

  // EN
  assign en_w_addr = en && w_sel != S_REG_D;
  assign en_mtb    = en_w_addr && b_w_addr_last;
  assign en_clr_i  = en_mtb    && mtb_last;

  always_comb begin
    en_w_sel  = 0;
    unique case (w_sel)
      S_REG_D  : en_w_sel  = en;
      S_BRAM_A : if (en_w_addr && a_w_addr_last)  
                  en_w_sel = en;
      S_BRAM_B : if (en_clr_i  && clr_i_last   )  
                  en_w_sel = en;
      default  : en_w_sel  = 0;
    endcase
  end

  register #(
    .WORD_WIDTH   (BITS_W_SEL), 
    .RESET_VALUE  (S_REG_D)
  ) W_SEL (
    .clock        (clk),
    .clock_enable (en_w_sel),
    .resetn       (rstn),
    .data_in      (w_sel_next),
    .data_out     (w_sel)
  );
  register #(
    .WORD_WIDTH   (BITS_CLR_I), 
    .RESET_VALUE  (0)
  ) CLR_I (
    .clock        (clk),
    .clock_enable (en_clr_i),
    .resetn       (rstn),
    .data_in      (clr_i_next),
    .data_out     (clr_i)
  );
  register #(
    .WORD_WIDTH   (BITS_KERNEL_H), 
    .RESET_VALUE  (0)
  ) MTB (
    .clock        (clk),
    .clock_enable (en_mtb),
    .resetn       (rstn),
    .data_in      (mtb_next),
    .data_out     (mtb)
  );
  register #(
    .WORD_WIDTH   (BITS_W_ADDR), 
    .RESET_VALUE  (0)
  ) W_ADDR (
    .clock        (clk),
    .clock_enable (en_w_addr),
    .resetn       (rstn),
    .data_in      (w_addr_next),
    .data_out     (w_addr)
  );
endmodule

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