module cyclic_shift_reg_tb();
  
  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  logic clk = 0;
  initial begin
    forever #(CLK_PERIOD/2) clk <= ~clk;
  end

  localparam R_DEPTH   = 24;
  localparam R_WIDTH   = 16;
  localparam W_WIDTH   = 16*3;

  localparam SIZE = R_DEPTH * R_WIDTH; //24*16
  localparam W_DEPTH =  SIZE / W_WIDTH; // 8
  localparam R_ADDR_WIDTH = $clog2(R_DEPTH);
  localparam W_ADDR_WIDTH = $clog2(W_DEPTH);

  logic clken, resetn;
  logic s_valid_ready, m_ready;
  logic [W_WIDTH/R_WIDTH-1:0][R_WIDTH-1:0] s_data;
  logic [R_WIDTH-1:0] m_data;
  logic [R_ADDR_WIDTH-1:0] r_addr_max;
  logic [R_ADDR_WIDTH-1:0] w_addr_max;

  cyclic_shift_reg #(
    .R_DEPTH      (R_DEPTH),
    .R_DATA_WIDTH (R_WIDTH),
    .W_DATA_WIDTH (W_WIDTH)
  ) dut (
    .clk        (clk   ),
    .clken      (clken ),
    .resetn     (resetn),
    .w_en       (s_valid_ready),
    .r_en       (m_ready),
    .s_data     (s_data),
    .m_data     (m_data),
    .r_addr_max (r_addr_max),
    .w_addr_max (w_addr_max)
  );


  initial begin
    clken  <= 1;
    resetn <= 0;
    s_valid_ready <= 0;
    m_ready <= 0;
    s_data  <= 0;
    r_addr_max  <= R_DEPTH/2-1;
    w_addr_max  <= W_DEPTH/2-1;

    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    #1
    resetn <= 1;

    s_valid_ready <= 0;
    s_data        <= 0;
    m_ready       <= 0;

    for (int i=0, n=10; i< W_DEPTH/2; i++) begin
      @(posedge clk);
      #1
      s_valid_ready <= 1;
      for (int j=0; j < W_WIDTH/R_WIDTH; j++) begin
        s_data[j] = n;
        n = n+1;
      end
    end

    @(posedge clk);
    #1
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