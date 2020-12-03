module always_valid_cyclic_bram_tb();
  
  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk <= ~clk;
  end

  localparam DEPTH   = 8 ;
  localparam WIDTH   = 64;
  localparam LATENCY = 3 ;
  localparam ADDR_WIDTH = $clog2(DEPTH);

  logic clk, clken, resetn;
  logic s_valid_ready, m_ready;
  logic m_valid;
  logic [WIDTH-1:0] s_data;
  logic [WIDTH-1:0] m_data;
  logic [ADDR_WIDTH-1:0] addr_max_1;

  always_valid_cyclic_bram #(
    .DEPTH   (DEPTH  ),
    .WIDTH   (WIDTH  ),
    .LATENCY (LATENCY)
    ) dut (.*);


  initial begin
    @(posedge clk);
    clken  <= 1;
    resetn <= 1;
    addr_max_1    <= 5;

    s_valid_ready <= 0;
    s_data        <= 0;
    m_ready       <= 1;

    @(posedge clk);
    s_valid_ready <= 1;
    s_data        <= 1;
    @(posedge clk);
    s_valid_ready <= 1;
    s_data        <= 2;
    @(posedge clk);
    s_valid_ready <= 0;
    @(posedge clk);
    s_valid_ready <= 1;
    s_data        <= 3;
    @(posedge clk);
    s_valid_ready <= 1;
    s_data        <= 4;
    @(posedge clk);
    s_valid_ready <= 1;
    s_data        <= 5;
    @(posedge clk);
    s_valid_ready <= 1;
    s_data        <= 6;
    @(posedge clk);
    s_valid_ready <= 0;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    m_ready       <= 1;

    repeat(5) begin
      @(posedge clk);
      s_valid_ready <= 0;
      m_ready       <= 1;
    end

    repeat(2) begin
      @(posedge clk);
      s_valid_ready <= 0;
      m_ready       <= 0;
    end
    
    repeat(6) begin
      @(posedge clk);
      s_valid_ready <= 0;
      m_ready       <= 1;
    end

    @(posedge clk);
    s_valid_ready <= 0;
    m_ready       <= 0;

    repeat(10) begin
      @(posedge clk);
      m_ready       <= 1;
    end

    repeat(10) begin
      @(posedge clk);
      m_ready       <= 0;
    end
    repeat(10) begin
      @(posedge clk);
      m_ready       <= 1;
    end
  end

endmodule