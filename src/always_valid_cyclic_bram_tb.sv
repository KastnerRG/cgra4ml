module always_valid_cyclic_bram_tb();
  
  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk <= ~clk;
  end

  localparam W_DEPTH   = 8 ;
  localparam W_WIDTH   = 16;
  localparam R_WIDTH   = 8 ;
  localparam LATENCY   = 2 ;

  localparam R_DEPTH = W_DEPTH * W_WIDTH / R_WIDTH;
  localparam R_ADDR_WIDTH = $clog2(R_DEPTH);
  localparam W_ADDR_WIDTH = $clog2(W_DEPTH);

  logic clk, clken, resetn;
  logic s_valid_ready, m_ready;
  logic m_valid;
  logic [W_WIDTH-1:0] s_data;
  logic [R_WIDTH-1:0] m_data;
  logic [R_ADDR_WIDTH-1:0] r_addr_max_1;
  logic [W_ADDR_WIDTH-1:0] w_addr_max_1;

  always_valid_cyclic_bram #(
    .W_DEPTH (W_DEPTH),
    .W_WIDTH (W_WIDTH),
    .R_WIDTH (R_WIDTH),
    .LATENCY (LATENCY)
    ) dut (.*);


  initial begin
    @(posedge clk);
    clken  <= 1;
    resetn <= 1;
    w_addr_max_1  <= 3-1;
    r_addr_max_1  <= 6-1;

    s_valid_ready <= 0;
    s_data        <= 0;
    m_ready       <= 1;

    @(posedge clk);
    s_valid_ready <= 1;
    s_data        <= {8'd2, 8'd1};
    @(posedge clk);
    s_valid_ready <= 1;
    s_data        <= {8'd4, 8'd3};
    @(posedge clk);
    s_valid_ready <= 0;
    @(posedge clk);
    s_valid_ready <= 1;
    s_data        <= {8'd6, 8'd5};
    // @(posedge clk);
    // s_valid_ready <= 1;
    // s_data        <= 4;
    // @(posedge clk);
    // s_valid_ready <= 1;
    // s_data        <= 5;
    // @(posedge clk);
    // s_valid_ready <= 1;
    // s_data        <= 6;
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