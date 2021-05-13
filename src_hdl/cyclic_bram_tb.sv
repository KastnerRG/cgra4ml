module cyclic_bram_tb();
  
  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk <= ~clk;
  end

  localparam W_DEPTH   = 2 ;
  localparam W_WIDTH   = 32;
  localparam R_WIDTH   = 16 ;
  localparam LATENCY   = 3 ;

  localparam R_DEPTH = W_DEPTH * W_WIDTH / R_WIDTH;
  localparam R_ADDR_WIDTH = $clog2(R_DEPTH);
  localparam W_ADDR_WIDTH = $clog2(W_DEPTH);

  logic clk, clken, resetn;
  logic s_valid_ready, m_ready;
  logic m_valid;
  logic [W_WIDTH-1:0] s_data;
  logic [R_WIDTH-1:0] m_data;
  logic [R_ADDR_WIDTH-1:0] r_addr_max;
  logic [R_ADDR_WIDTH-1:0] r_addr_min;

  cyclic_bram #(
    .W_DEPTH (W_DEPTH),
    .W_WIDTH (W_WIDTH),
    .R_WIDTH (R_WIDTH),
    .IP_TYPE (1),  // 0: depth=3m, 1: depth=m (edge)
    .ABSORB_LATENCY (LATENCY)
  ) dut (
    .clk        (clk   ),
    .clken      (clken ),
    .resetn     (resetn),
    .w_en       (s_valid_ready),
    .r_en       (m_ready),
    .s_data     (s_data),
    .m_data     (m_data),
    .m_valid    (m_valid),
    .r_addr_max (r_addr_max),
    .r_addr_min (1)
  );


  initial begin
    @(posedge clk);
    clken  <= 1;
    resetn <= 1;
    r_addr_max  <= R_DEPTH-1;

    s_valid_ready <= 0;
    s_data        <= 0;
    m_ready       <= 0;

    @(posedge clk);
    s_valid_ready <= 1;
    s_data        <= {16'd11, 16'd10};
    @(posedge clk);
    s_valid_ready <= 1;
    s_data        <= {16'd13, 16'd12};


    @(posedge clk);
    s_valid_ready <= 0;

    repeat (6) @(posedge clk);

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

      @(posedge clk);
      m_ready       <= 0;

      @(posedge clk);
      @(posedge clk);
      @(posedge clk);
      resetn        <= 0;
      @(posedge clk);
      resetn        <= 1;
      s_valid_ready <= 1;
      s_data        <= {16'd21, 16'd20};
      @(posedge clk);
      s_valid_ready <= 1;
      s_data        <= {16'd23, 16'd22};

      @(posedge clk);
      s_valid_ready <= 0;
      m_ready       <= 1;

  end

endmodule