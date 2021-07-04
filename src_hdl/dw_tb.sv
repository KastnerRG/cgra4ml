`timescale 1ns / 1ps
module dw_tb();

  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  logic aresetn, aclken;
  logic s_axis_tvalid, s_axis_tready, s_axis_tlast;
  logic m_axis_tvalid, m_axis_tready, m_axis_tlast;

  logic [7 :0] s_axis_tkeep; 
  logic [7 :0] s_axis_tuser; 

  logic [0 :0] m_axis_tkeep;
  logic [0 :0] m_axis_tuser;

  logic [63:0] s_axis_tdata;
  logic [7 :0] m_axis_tdata;

  axis_dw dw (
    .aclk           (aclk         ),                    
    .aresetn        (aresetn      ),              
    .aclken         (aclken       ),               
    .s_axis_tvalid  (s_axis_tvalid), 
    .s_axis_tready  (s_axis_tready),
    .s_axis_tdata   (s_axis_tdata ),  
    .s_axis_tkeep   (s_axis_tkeep ),   
    .s_axis_tuser   (s_axis_tuser ),   
    .s_axis_tlast   (s_axis_tlast ),   
    .m_axis_tvalid  (m_axis_tvalid), 
    .m_axis_tready  (m_axis_tready), 
    .m_axis_tdata   (m_axis_tdata ),  
    .m_axis_tkeep   (m_axis_tkeep ),   
    .m_axis_tuser   (m_axis_tuser ),   
    .m_axis_tlast   (m_axis_tlast )  
  );

  logic [7:0] s_data [7:0];
  logic [7:0] m_data;

  assign {>>{s_axis_tdata}} = s_data;
  assign m_data = m_axis_tdata;

  initial begin
    aclken  <= 1;
    aresetn <= 1;
    s_axis_tvalid <= 0;
    m_axis_tready <= 1;
    s_axis_tkeep  <= 0;
    s_axis_tuser  <= 0;
    s_axis_tlast  <= 0;
    for (int i=0; i<8; i++)
      s_data[i]   <= 0;

    repeat(5) @(posedge aclk);

    @(posedge aclk);
    #1;
    s_axis_tvalid <= 1;
    s_axis_tkeep  <= 8'b00100100;
    s_axis_tuser  <= 8'b00000100;
    s_axis_tlast  <= 1;
    for (int i=0; i<8; i++)
      s_data[i]   <= 10+i;

    @(posedge aclk);
    #1;
    s_axis_tvalid <= 0;
    s_axis_tkeep  <= 0;
    s_axis_tuser  <= 0;
    s_axis_tlast  <= 0;
    for (int i=0; i<8; i++)
      s_data[i]   <= 0;




  end


endmodule
