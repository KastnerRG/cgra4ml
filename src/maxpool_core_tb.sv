module maxpool_core_tb();
  
  timeunit 1ns;
  timeprecision 1ps;
  logic clk;
  localparam CLK_PERIOD = 10;
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk <= ~clk;
  end

  localparam UNITS      = 3;
  localparam MEMEBERS   = 8;
  localparam WORD_WIDTH = 16;
  localparam INDEX_IS_NOT_MAX = 0;
  localparam INDEX_IS_MAX     = 1;

  typedef logic signed [WORD_WIDTH-1:0] word_t;

  logic clken, resetn;
  logic s_valid, s_ready, m_ready, m_valid;
  logic [0:1] s_user;

  word_t s_data [UNITS][2];
  word_t m_data [UNITS][2];
  logic  m_keep [UNITS][2];

  maxpool_core #(
    .UNITS       (UNITS     ),
    .MEMEBERS    (MEMEBERS  ),
    .WORD_WIDTH  (WORD_WIDTH),
    .INDEX_IS_MAX    (INDEX_IS_MAX    ),
    .INDEX_IS_NOT_MAX(INDEX_IS_NOT_MAX)
  ) dut (.*);

  task fill_data (input int init, input logic is_max, is_not_max);
    @(posedge clk);
    for (int u = 0; u< UNITS; u++) begin
      for (int c = 0; c< 2; c++) begin
        s_data[u][c] <= init + 10*u + c;
        s_valid      <= 1;
        s_user[INDEX_IS_MAX    ] <= is_max;
        s_user[INDEX_IS_NOT_MAX] <= is_not_max;
      end
    end
  endtask

  initial begin
    clken = 1;
    resetn = 1;

    // NO MAXPOOL

    for (int i=0; i < MEMEBERS; i++) begin
      repeat (1) @(posedge clk);
      fill_data(100*i, 0, 1);
      @(posedge clk);
      s_valid <= 0;
    end
    
    repeat (5) @(posedge clk);


    // MAXPOOL ONLY

    for (int i=0; i < MEMEBERS; i++) begin
      repeat (3) @(posedge clk);
      fill_data(1000+100*i, 1, 0);
      @(posedge clk);
      s_valid <= 0;
    end

    repeat (5) @(posedge clk);

    for (int i=0; i < MEMEBERS; i++) begin
      repeat (3) @(posedge clk);
      fill_data(100*i, 1, 0);
      @(posedge clk);
      s_valid <= 0;
    end

    // MAX and NON MAXPOOL

    repeat (5) @(posedge clk);

    for (int i=0; i < MEMEBERS; i++) begin
      repeat (3) @(posedge clk);
      fill_data(1000+100*i, 1, 1);
      @(posedge clk);
      s_valid <= 0;
    end

    repeat (5) @(posedge clk);

    for (int i=0; i < MEMEBERS; i++) begin
      repeat (3) @(posedge clk);
      fill_data(i*100, 1, 1);
      @(posedge clk);
      s_valid <= 0;
    end

  end

endmodule