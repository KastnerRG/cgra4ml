`include "../src_hdl/params.v"

module axis_conv_dw_bank_tb ();

  timeunit 10ns;
  timeprecision 1ns;
  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  localparam UNITS                = `UNITS                ;
  localparam GROUPS               = `GROUPS               ;
  localparam COPIES               = `COPIES               ;
  localparam MEMBERS              = `MEMBERS              ;
  localparam WORD_WIDTH           = `WORD_WIDTH_ACC       ;
  localparam TUSER_WIDTH_LRELU_IN = `TUSER_WIDTH_LRELU_IN ; 
  localparam WORD_BYTES           =  WORD_WIDTH/8;

  logic aresetn, s_axis_tvalid, s_axis_tlast, s_axis_tready;

  logic [COPIES -1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0][WORD_WIDTH          -1:0] s_axis_tdata;
  logic [COPIES -1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0][WORD_BYTES          -1:0] s_axis_tkeep;
  logic                          [MEMBERS-1:0]           [TUSER_WIDTH_LRELU_IN-1:0] s_axis_tuser;

  logic m_axis_tready;
  logic [COPIES -1:0][GROUPS-1:0][UNITS-1:0][WORD_WIDTH  -1:0] m_axis_tdata;
  logic [TUSER_WIDTH_LRELU_IN  -1:0] m_axis_tuser;
  logic m_axis_tvalid, m_axis_tlast;

  axis_conv_dw_bank #(.ZERO(0)) DUT (
    .aclk          (aclk         ),
    .aresetn       (aresetn      ),
    .s_axis_tdata  (s_axis_tdata ),
    .s_axis_tvalid (s_axis_tvalid),
    .s_axis_tready (s_axis_tready),
    .s_axis_tlast  (s_axis_tlast ),
    .s_axis_tuser  (s_axis_tuser ),
    .s_axis_tkeep  (s_axis_tkeep ),
    .m_axis_tdata  (m_axis_tdata ),
    .m_axis_tvalid (m_axis_tvalid),
    .m_axis_tready (m_axis_tready),
    .m_axis_tlast  (m_axis_tlast ),
    .m_axis_tuser  (m_axis_tuser )
  );

  initial begin
    aresetn      <= 1;

    s_axis_tvalid <= 0;
    m_axis_tready <= 0;
    s_axis_tlast  <= 0;
    s_axis_tdata  <= '0;
    s_axis_tuser  <= '0;
    s_axis_tkeep  <= '0;

    @(posedge aclk);
    @(posedge aclk);

    s_axis_tvalid <= 1;
    m_axis_tready <= 1;
    s_axis_tlast  <= 1;

    for (int c= 0; c<COPIES; c++)
      for (int g= 0; g<GROUPS; g++)
        for (int m= 0; m<MEMBERS; m++)
          for (int u= 0; u<UNITS; u++) begin
            s_axis_tdata [c][g][m][u] <= 1000*c+100*g+10*m+u;
            s_axis_tkeep [c][g][m][u] <= {WORD_BYTES{m % 3 == 0}};

            if (c==0 & g==0 & u==0) s_axis_tuser[m] <= 9; 
          end

    @(posedge aclk);
    s_axis_tvalid <= 0;
    m_axis_tready <= 1;
    s_axis_tlast  <= 0;
    s_axis_tdata  <= '0;
    s_axis_tuser  <= '0;
    s_axis_tkeep  <= '0;

  end

endmodule