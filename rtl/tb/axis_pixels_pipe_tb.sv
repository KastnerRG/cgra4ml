`include "../include/params.h"
`include "axis_tb.sv"

module axis_pixels_pipe_tb ();
  timeunit 10ns;
  timeprecision 1ns;
  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  localparam VALID_PROB = 20;
  localparam READY_PROB = 20;
  localparam string FILEPATH = "D:/cnn-fpga/data/im_in_text.txt";
  localparam NUM_WORDS = 100;

  localparam UNITS              = `UNITS              ;
  localparam COPIES             = `COPIES             ;
  localparam WORD_WIDTH         = `WORD_WIDTH         ; 
  localparam IM_SHIFT_REGS      = `IM_SHIFT_REGS      ;
  localparam TUSER_WIDTH_PIXELS = `TUSER_WIDTH_PIXELS ;
  localparam BITS_KH            = `BITS_KH            ;
  localparam S_PIXELS_WIDTH_LF  = `S_PIXELS_WIDTH_LF  ;

  logic aresetn;
  logic s_ready;
  logic s_valid;
  logic s_last ;
  logic [S_PIXELS_WIDTH_LF/WORD_WIDTH-1:0][WORD_WIDTH-1:0] s_data;
  logic [S_PIXELS_WIDTH_LF/8                         -1:0] s_keep;
  logic m_ready;
  logic m_valid;
  logic [COPIES-1:0][UNITS-1:0][WORD_WIDTH-1:0] m_data;
  logic [TUSER_WIDTH_PIXELS-1:0] m_user;

  axis_pixels_pipe DUT (.*);

  AXIS_Slave #(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(S_PIXELS_WIDTH_LF/WORD_WIDTH), .VALID_PROB(VALID_PROB)) s_pixels  = new(.file_path(FILEPATH), .words_per_packet(NUM_WORDS), .iterations(1));
  initial forever s_pixels.axis_feed(aclk, s_ready, s_valid, s_data, s_keep, s_last);

  class Rand #();
    rand bit val;
    constraint c { val dist { 0 := (100-READY_PROB), 1 := (READY_PROB)}; };
  endclass
  Rand rand_obj = new();

  initial forever begin
    @(posedge aclk);
    rand_obj.randomize();
    #1 m_ready = rand_obj.val;
  end

  /*
    Print possible KSM combinations
  */
  function bit valid_n (input integer n);
    automatic integer k, s, shift, words;
    valid_n = 0;
    for (integer i_kh2 = 0; i_kh2 <= `KH_MAX/2; i_kh2++)
      for (integer i_sh_1 = 0; i_sh_1 < `SH_MAX; i_sh_1++)
        for (integer m = 1; m <= COPIES; m++) begin
          k     = i_kh2*2+1;
          s     = i_sh_1+1;
          shift = `CEIL(k,s)-1;
          words = m*UNITS + shift;
          if(`KSM_COMBS_EXPR & n==words) begin
            $display("words:%d,  K:%d, S:%d, M:%d", words, k, s, m);
            return 1;
          end 
        end
  endfunction

  initial begin

    for (int m_words = UNITS; m_words <= IM_SHIFT_REGS; m_words++) begin
      $display("words:%d", m_words);
      valid_n(m_words);
    end

    aresetn = 1;
    
    repeat (3) @(posedge aclk);
    #1
    s_pixels.enable = 1;
  end

endmodule