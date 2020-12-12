module axis_lrelu_engine_tb();
  
  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  localparam WORD_WIDTH_IN  = 32;
  localparam WORD_WIDTH_OUT = 8 ;
  localparam TUSER_WIDTH    = 4;
  localparam UNITS   = 8;
  localparam GROUPS  = 2;
  localparam COPIES  = 2;
  localparam MEMBERS = 8;

  logic aresetn      ;
  logic s_axis_tvalid;
  logic s_axis_tready;
  logic s_axis_tlast ;
  logic m_axis_tvalid;
  logic m_axis_tready;
  logic [MEMBERS * COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_axis_tdata ; // mcgu
  logic [          COPIES * GROUPS * UNITS * WORD_WIDTH_OUT-1:0] m_axis_tdata ; // cgu
  logic [MEMBERS * COPIES * GROUPS-1:0] s_axis_tkeep ;
  logic [          COPIES * GROUPS-1:0] m_axis_tkeep ;
  logic [TUSER_WIDTH-1:0] s_axis_tuser ;
  logic [1:0] m_axis_tuser ;

  logic [WORD_WIDTH_IN -1:0] s_data_mcgu [MEMBERS-1:0][COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [WORD_WIDTH_IN -1:0] m_data_cgu               [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic s_keep_mcg [MEMBERS-1:0][COPIES-1:0][GROUPS-1:0];
  logic m_keep_cg               [COPIES-1:0][GROUPS-1:0];

  assign {>>{s_axis_tdata}} = s_data_mcgu;
  assign m_data_cgu = {>>{m_axis_tdata}};
  assign {>>{s_keep_mcg}} = s_axis_tkeep;
  assign m_keep_cg = {>>{m_axis_tkeep}};


  axis_lrelu_engine #(
    .WORD_WIDTH_IN (WORD_WIDTH_IN ),
    .WORD_WIDTH_OUT(WORD_WIDTH_OUT),
    .TUSER_WIDTH   (TUSER_WIDTH),
    .UNITS   (UNITS  ),
    .GROUPS  (GROUPS ),
    .COPIES  (COPIES ),
    .MEMBERS (MEMBERS)
  ) dut (.*);

  initial begin
    aresetn       <= 1;
    m_axis_tready <= 1;
    s_axis_tvalid <= 0;
    s_axis_tkeep  <='1;
    s_axis_tuser  <= 3;
    s_axis_tlast  <= 0;

    @(posedge aclk);
    foreach (s_data_mcgu[m,c,g,u]) s_data_mcgu[m][c][g][u] = 10*g+u;
    s_axis_tvalid <= 1;
    @(posedge aclk);
    foreach (s_data_mcgu[m,c,g,u]) s_data_mcgu[m][c][g][u] = 10*g+u;
    s_axis_tvalid <= 1;
    s_axis_tlast  <= 1;
    @(posedge aclk);
    foreach (s_data_mcgu[m,c,g,u]) s_data_mcgu[m][c][g][u] = 10*g+u;
    s_axis_tvalid <= 1;
    s_axis_tlast  <= 0;
    @(posedge aclk);
    s_axis_tvalid <= 0;
    @(posedge aclk);
  end

endmodule