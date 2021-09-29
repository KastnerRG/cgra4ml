`timescale 1ns / 1ps
module dw_tb();

  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  localparam S_DATA_WIDTH = 8*5;
  localparam M_DATA_WIDTH = 8*10;
  localparam S_KEEP_WIDTH = S_DATA_WIDTH/8;
  localparam M_KEEP_WIDTH = M_DATA_WIDTH/8;
  localparam USER_WIDTH   = 8;

  logic aresetn, aclken;
  logic s_axis_tvalid, s_axis_tready, s_axis_tlast;
  logic [S_KEEP_WIDTH-1:0][7:0] s_axis_tdata;
  logic [S_KEEP_WIDTH-1:0] s_axis_tkeep; 
  logic [USER_WIDTH  -1:0] s_axis_tuser;

  logic m_axis_tvalid, m_axis_tready, m_axis_tlast;
  logic [M_KEEP_WIDTH-1:0][7:0] m_axis_tdata;
  logic [M_KEEP_WIDTH-1:0] m_axis_tkeep;
  logic [USER_WIDTH  -1:0] m_axis_tuser;


  // axis_dw dw (
  //   .aclk           (aclk         ),                    
  //   .aresetn        (aresetn      ),              
  //   .aclken         (aclken       ),               
  //   .s_axis_tvalid  (s_axis_tvalid), 
  //   .s_axis_tready  (s_axis_tready),
  //   .s_axis_tdata   (s_axis_tdata ),  
  //   .s_axis_tkeep   (s_axis_tkeep ),   
  //   .s_axis_tuser   (s_axis_tuser ),   
  //   .s_axis_tlast   (s_axis_tlast ),   
  //   .m_axis_tvalid  (m_axis_tvalid), 
  //   .m_axis_tready  (m_axis_tready), 
  //   .m_axis_tdata   (m_axis_tdata ),  
  //   .m_axis_tkeep   (m_axis_tkeep ),   
  //   .m_axis_tuser   (m_axis_tuser ),   
  //   .m_axis_tlast   (m_axis_tlast )  
  // );

  logic s_axis_tid = 0;
  logic s_axis_tdest = 0;
  logic m_axis_tid, m_axis_tdest;

  logic clk, rst;
  assign clk = aclk;
  assign rst = ~aresetn;

  alex_axis_adapter_any #
  (
    .S_DATA_WIDTH  (S_DATA_WIDTH),
    .S_KEEP_ENABLE (1),
    .M_DATA_WIDTH  (M_DATA_WIDTH),
    .M_KEEP_ENABLE (0),
    .ID_ENABLE     (0),
    .DEST_ENABLE   (0),
    .USER_ENABLE   (1),
    .USER_WIDTH    (USER_WIDTH)
  ) DUT  (.*);

  initial begin
    aclken  <= 1;
    aresetn <= 1;
    s_axis_tvalid <= 0;
    m_axis_tready <= 1;
    s_axis_tkeep  <= 0;
    s_axis_tuser  <= 0;
    s_axis_tlast  <= 0;
    for (int i=0; i<8; i++)
      s_axis_tdata[i]   <= 0;

    repeat(5) @(posedge aclk);

    @(posedge aclk);
    #1;
    s_axis_tvalid <= 1;
    s_axis_tkeep  <= 8'b00001111;
    // s_axis_tkeep  <= '1;
    s_axis_tuser  <= 8'b00000100;
    s_axis_tlast  <= 1;
    for (int i=0; i<8; i++)
      s_axis_tdata[i]   <= 10+i;

    @(posedge aclk);
    #1;
    s_axis_tvalid <= 0;
    s_axis_tkeep  <= 0;
    s_axis_tuser  <= 0;
    s_axis_tlast  <= 0;
    for (int i=0; i<8; i++)
      s_axis_tdata[i]   <= 0;
  end


endmodule
