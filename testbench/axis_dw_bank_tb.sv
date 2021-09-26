`include "../src_hdl/params.v"

module axis_dw_bank_tb ();
  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  localparam WORD_WIDTH   = 8 ;
  localparam UNITS        = 2 ;
  localparam MEMBERS      = 24;
  localparam KH_MAX       = 11;
  localparam SH_MAX       = 4 ;
  localparam I_KH2        = 2 ;
  localparam BITS_KH2     = $clog2(KH_MAX/2+1)   ;
  localparam I_SH         = I_KH2 + BITS_KH2     ;
  localparam BITS_SH      = $clog2(SH_MAX  +1)   ;
  localparam TUSER_WIDTH  = `TUSER_WIDTH_LRELU_IN;
  localparam BITS_MEMBERS = $clog2(MEMBERS)      ;

  localparam KW_MAX    = KH_MAX;
  localparam BITS_KW2  = BITS_KH2;
  localparam I_KW2     = I_KH2;
  localparam SW_MAX    = SH_MAX;
  localparam BITS_SW   = BITS_SH;
  localparam I_SW      = I_SH;

  /*
    Settings
  */
  localparam K = 7;
  localparam S = 2;
  localparam J = K + S -1;

  logic aresetn;

  logic s_valid, s_last;
  logic s_ready;
  logic [MEMBERS-1:0][UNITS-1:0][WORD_WIDTH -1:0] s_data;
  logic [MEMBERS-1:0]                             s_keep;
  logic [MEMBERS-1:0][TUSER_WIDTH-1:0]            s_user;
  
  logic m_ready;
  logic [UNITS-1:0][WORD_WIDTH -1:0] m_data;
  logic [TUSER_WIDTH-1:0]            m_user;
  logic m_valid, m_last;

  axis_dw_shift #(
    .ZERO         (0           ),
    .WORD_WIDTH   (WORD_WIDTH  ),
    .UNITS        (UNITS       ),
    .MEMBERS      (MEMBERS     ),
    .KH_MAX       (KH_MAX      ),
    .SH_MAX       (SH_MAX      ),
    .I_KH2        (I_KH2       ),
    .BITS_KH2     (BITS_KH2    ),
    .I_SH         (I_SH        ),
    .BITS_SH      (BITS_SH     ),
    .TUSER_WIDTH  (TUSER_WIDTH ),
    .BITS_MEMBERS (BITS_MEMBERS)) dut (.*);

  initial begin
    aresetn  <= 1;
    s_valid  <= 0;
    s_keep   <= 0;
    s_last   <= 0;
    m_ready  <= 0;
    s_data   <= 0;
    s_user   <= 0;
    for (int m=0; m< MEMBERS; m++) begin
      s_user[m][BITS_KW2+I_KW2-1:I_KW2] <= K/2;
      s_user[m][BITS_SW +I_SW -1:I_SW ] <= S-1;
    end

    repeat(3) @(posedge aclk);
    #1
    s_valid <= 1;
    s_last  <= 1;
    for (int m=0; m<MEMBERS; m++) begin
      for (int u=0; u<UNITS; u++)
        s_data[m][u] <= m*10 + (u+1);
        s_keep[m] <= (m % J >= K-1);
    end
    @(posedge aclk);
    #1
    s_valid  <= 0;
    s_keep   <= 0;
    s_last   <= 0;
    s_data   <= 0;

    repeat(3) @(posedge aclk);
    #1
    m_ready <= 1;


    repeat(3) @(posedge aclk);
    #1
    s_valid <= 1;
    s_last  <= 1;

    for (int m=0; m<MEMBERS; m++) begin
      for (int u=0; u<UNITS; u++)
        s_data[m][u] <= m*10 + (u+1);
        s_keep[m] <= (m % J >= K-1-S);
    end

    @(posedge aclk);
    #1
    s_valid  <= 0;
    s_keep   <= 0;
    s_last   <= 0;
    s_data   <= 0;

    wait(s_ready);
    @(posedge aclk);
    #1
    m_ready <= 0;

    repeat(4) @(posedge aclk);
    #1
    m_ready <= 1;

    repeat(3) @(posedge aclk);
    #1
    m_ready <= 0;

    repeat(20) @(posedge aclk);
    #1
    m_ready <= 1;

    repeat(4) @(posedge aclk);
    #1
    m_ready <= 0;

  end
endmodule