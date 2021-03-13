`include "axis_tb.sv"

module axis_tb_demo();

  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  localparam WORD_WIDTH        = 8;
  localparam WORDS_PER_PACKET  = 37;
  localparam WORDS_PER_BEAT    = 4;
  localparam ITERATIONS        = 5;
  localparam BEATS             = int'($ceil(real'(WORDS_PER_PACKET)/real'(WORDS_PER_BEAT)));

  logic [WORD_WIDTH      -1:0] data [WORDS_PER_BEAT-1:0];
  logic [WORDS_PER_BEAT  -1:0] keep;
  logic valid, ready, last;

  string path = "D:/cnn-fpga/data/axis_test.txt";
  string out_base = "D:/cnn-fpga/data/axis_test_out_";


  AXIS_Slave #(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(WORDS_PER_BEAT), .VALID_PROB(70)) slave_obj  = new(.file_path(path), .words_per_packet(WORDS_PER_PACKET), .iterations(ITERATIONS));
  AXIS_Master#(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(WORDS_PER_BEAT), .READY_PROB(70), .CLK_PERIOD(CLK_PERIOD)) master_obj = new(.file_base(out_base));

  initial forever  slave_obj.axis_feed(aclk, ready, valid, data, keep, last);
  initial forever master_obj.axis_read(aclk, ready, valid, data, keep, last);

  initial begin
    @(posedge aclk);
    slave_obj.enable <= 1;
    master_obj.enable <= 1;
  end

  int s_words, s_itr, m_words, m_itr;

  initial begin
    forever begin
      @(posedge aclk);
      s_words = slave_obj.i_words;
      s_itr = slave_obj.i_itr;
      m_words = master_obj.i_words;
      m_itr = master_obj.i_itr;
    end
  end

endmodule
