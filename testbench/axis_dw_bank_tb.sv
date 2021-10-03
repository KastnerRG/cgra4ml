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
  localparam WORD_WIDTH          = `WORD_WIDTH_ACC      ;
  localparam UNITS               = `UNITS               ;
  localparam MEMBERS             = `MEMBERS             ;
  localparam KW_MAX              = `KW_MAX              ;
  localparam SW_MAX              = `SW_MAX              ;
  localparam I_KW2               = `I_KW2               ;
  localparam BITS_KW2            = `BITS_KW2            ;
  localparam I_SW_1              = `I_SW_1              ;
  localparam I_CLR               = `I_CLR               ;
  localparam BITS_SW             = `BITS_SW             ;
  localparam TUSER_CONV_DW_BASE  = `TUSER_CONV_DW_BASE  ;
  localparam BITS_MEMBERS        = `BITS_MEMBERS        ;
  localparam BITS_OUT_SHIFT      = `BITS_OUT_SHIFT      ;
  localparam USER_WIDTH_IN       = `TUSER_CONV_DW_IN    ;
  localparam CLR_WIDTH           = `BITS_KW             ;
  localparam USER_WIDTH_OUT      = `TUSER_WIDTH_LRELU_IN;

  /*
    Settings
  */

  logic aresetn;

  logic s_valid, s_last;
  logic s_ready;
  logic [MEMBERS-1:0][UNITS-1:0][WORD_WIDTH -1:0] s_data;
  logic [USER_WIDTH_IN -1:0] s_user;

  logic m_ready;
  logic [UNITS-1:0][WORD_WIDTH -1:0] m_data;
  logic [USER_WIDTH_OUT        -1:0] m_user;
  logic m_valid, m_last;

  axis_dw_bank #() dut (.*);

  logic [TUSER_CONV_DW_BASE -1:0] s_user_base;
  logic [BITS_MEMBERS  -1:0] s_shift_a;
  logic [BITS_OUT_SHIFT-1:0] s_shift_b;
  logic [MEMBERS-1:0][CLR_WIDTH-1:0] s_clr;
  logic [BITS_KW2-1:0] s_kw2;
  logic [BITS_SW -1:0] s_sw_1;
  logic [CLR_WIDTH-1:0] m_clr;

  assign s_user = {s_clr, s_shift_b, s_shift_a, s_user_base};
  assign s_user_base[BITS_KW2+I_KW2 -1:I_KW2 ] = s_kw2 ;
  assign s_user_base[BITS_SW +I_SW_1-1:I_SW_1] = s_sw_1;
  assign m_clr = m_user[I_CLR+CLR_WIDTH-1:I_CLR];

  initial begin
    aresetn  <= 1;
    s_valid  <= 0;
    s_last   <= 0;
    m_ready  <= 0;
    s_data   <= 0;

    //---------------------------
    // K=1, S=1, any
    s_kw2     <= 1/2;    
    s_sw_1    <= 0;    
    s_shift_a <= MEMBERS-1;
    s_shift_b <= 0;

    // // K=3, S=1, mid
    // s_kw2     <= 3/2;    
    // s_sw_1    <= 0;    
    // s_shift_a <= 0;
    // s_shift_b <= MEMBERS/3-1;

    // // K=3, S=1, end
    // s_kw2     <= 3/2;    
    // s_sw_1    <= 0;    
    // s_shift_a <= 2-1;
    // s_shift_b <= MEMBERS/3-1;

    // // K=11, S=4, mid
    // s_kw2     <= 11/2;    
    // s_sw_1    <= 4-1;    
    // s_shift_a <= 4-1;
    // s_shift_b <= MEMBERS/(11+4-1)-1;

    // // K=3, S=1, end
    // s_kw2     <= 11/2;    
    // s_sw_1    <= 4-1;    
    // s_shift_a <= 2*4-1;
    // s_shift_b <= MEMBERS/(11+4-1)-1;

    //---------------------------

    for (int m=0; m< MEMBERS; m++)
      s_clr[m] <= m+1;

    repeat(3) @(posedge aclk);
    #1
    s_valid <= 1;
    s_last  <= 1;
    for (int m=0; m<MEMBERS; m++)
      for (int u=0; u<UNITS; u++)
        s_data[m][u] <= m*10 + (u+1);
    @(posedge aclk);
    #1
    s_valid  <= 0;
    s_last   <= 0;
    s_data   <= 0;

    repeat(3) @(posedge aclk);
    #1
    m_ready <= 1;


    repeat(3) @(posedge aclk);

    wait(s_ready);
    @(posedge aclk);
    #1
    s_valid <= 1;
    s_last  <= 1;

    for (int m=0; m<MEMBERS; m++) begin
      for (int u=0; u<UNITS; u++)
        s_data[m][u] <= m*10 + (u+1);
    end

    @(posedge aclk);
    #1
    s_valid  <= 0;
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

    repeat(2) @(posedge aclk);
    #1
    m_ready <= 1;

  end
endmodule