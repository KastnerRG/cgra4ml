`timescale 1ns/1ps
`include "../params/params.v"

module axis_dw_shift (
    aclk   ,
    aresetn,

    s_ready,  
    s_valid,  
    s_data ,   
    s_user ,   
    s_last ,   
    
    m_ready,      
    m_valid,     
    m_data ,
    m_user ,
    m_last
  );
  localparam WORD_WIDTH          = `WORD_WIDTH_ACC      ;
  localparam UNITS               = `UNITS               ;
  localparam MEMBERS             = `MEMBERS             ;
  localparam KW_MAX              = `KW_MAX              ;
  localparam SW_MAX              = `SW_MAX              ;
  localparam I_KW2               = `I_KW2               ;
  localparam BITS_KW2            = `BITS_KW2            ;
  localparam I_SW_1              = `I_SW_1              ;
  localparam BITS_SW             = `BITS_SW             ;
  localparam TUSER_CONV_DW_BASE  = `TUSER_CONV_DW_BASE  ;
  localparam BITS_MEMBERS        = `BITS_MEMBERS        ;
  localparam BITS_OUT_SHIFT      = `BITS_OUT_SHIFT      ;
  localparam USER_WIDTH_IN       = `TUSER_CONV_DW_IN    ;
  localparam CLR_WIDTH           = `BITS_KW             ;
  localparam USER_WIDTH_OUT      = `TUSER_WIDTH_LRELU_IN;

  input logic aclk, aresetn;

  input  logic s_valid, s_last;
  output logic s_ready;
  input  logic [MEMBERS-1:0][UNITS-1:0][WORD_WIDTH -1:0] s_data;
  input  logic [USER_WIDTH_IN -1:0] s_user;

  input  logic m_ready;
  output logic [UNITS-1:0][WORD_WIDTH -1:0] m_data;
  output logic [USER_WIDTH_OUT        -1:0] m_user;
  output logic m_valid, m_last;

  logic b_ready, slice_ready;

  /*
    SECTION A
  */

  logic  [TUSER_CONV_DW_BASE -1:0] s_user_base;
  logic  [BITS_MEMBERS  -1:0] s_shift_a;
  logic  [BITS_OUT_SHIFT-1:0] s_shift_b;
  logic  [MEMBERS-1:0][CLR_WIDTH-1:0] s_clr;
  assign {s_clr, s_shift_b, s_shift_a, s_user_base} = s_user;

  // Counter
  logic count_a_en, count_a_last;
  logic [BITS_MEMBERS-1:0] count_a_next, count_a;

  assign count_a_en   = b_ready & (count_a_last ? s_valid : 1);
  assign count_a_last = count_a == 0;
  assign count_a_next = count_a_last ? s_shift_a : count_a - 1'b1;

  register #(
    .WORD_WIDTH     (BITS_MEMBERS),
    .RESET_VALUE    (0)
  ) COUNT_A (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (count_a_en),
    .data_in        (count_a_next),
    .data_out       (count_a)
  );
  assign s_ready = b_ready & count_a_last;

  // Data: shift Registers
  localparam SHIFT_WORD_WIDTH = UNITS*WORD_WIDTH + CLR_WIDTH;
  logic [MEMBERS -1:0][SHIFT_WORD_WIDTH-1:0] reg_a_data_s, reg_a_data_in, reg_a_data;
  logic [MEMBERS-1:0][UNITS-1:0][WORD_WIDTH -1:0] a_data;
  logic [MEMBERS-1:0][CLR_WIDTH-1:0] a_clr;

  generate
    for (genvar m=0; m<MEMBERS; m++) begin
      assign reg_a_data_s [m] = {s_data[m], s_clr[m]};
      assign {a_data[m], a_clr[m]} = reg_a_data[m];
    end
  endgenerate

  assign reg_a_data_in = count_a_last ? reg_a_data_s : reg_a_data << SHIFT_WORD_WIDTH;

  register #(
    .WORD_WIDTH     (MEMBERS*SHIFT_WORD_WIDTH),
    .RESET_VALUE    (0)
  ) REG_A_DATA (
    .clock          (aclk   ),
    .resetn         (aresetn),
    .clock_enable   (count_a_en   ),
    .data_in        (reg_a_data_in),
    .data_out       (reg_a_data)
  );

  // valid, last
  logic a_valid;
  register #(
    .WORD_WIDTH     (1),
    .RESET_VALUE    (0)
  ) REG_A_VALID (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (s_ready),
    .data_in        (s_valid),
    .data_out       (a_valid)
  );

  logic [TUSER_CONV_DW_BASE -1:0] a_user_base;
  logic [BITS_OUT_SHIFT-1:0] a_shift_b;
  logic a_last, reg_a_last_temp;
  register #(
    .WORD_WIDTH     (1 + BITS_OUT_SHIFT + TUSER_CONV_DW_BASE),
    .RESET_VALUE    (0)
  ) REG_A_USER_LAST (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (s_valid & s_ready),
    .data_in        ({s_last         , s_shift_b, s_user_base}),
    .data_out       ({reg_a_last_temp, a_shift_b, a_user_base})
  );
  assign a_last = reg_a_last_temp & count_a_last;

  logic [BITS_KW2-1:0] a_kw2;
  logic [BITS_SW -1:0] a_sw_1;
  assign a_kw2 = a_user_base [BITS_KW2+I_KW2 -1:I_KW2 ];
  assign a_sw_1 = a_user_base[BITS_SW +I_SW_1-1:I_SW_1];

  /*
    SECTION B
  */

  // Counter
  logic count_b_en, count_b_last;
  logic [BITS_OUT_SHIFT-1:0] count_b_next, count_b;

  assign count_b_en   = slice_ready & (count_b_last ? a_valid : 1);
  assign count_b_last = count_b == 0;
  assign count_b_next = count_b_last ? a_shift_b : count_b - 1'b1;

  register #(
    .WORD_WIDTH     (BITS_OUT_SHIFT),
    .RESET_VALUE    (0)
  ) COUNT_B (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (count_b_en),
    .data_in        (count_b_next),
    .data_out       (count_b)
  );
  assign b_ready = slice_ready & count_b_last;

  // Data: shift Registers

  logic [KW_MAX/2:0][SW_MAX-1:0][MEMBERS/3-1:0][SHIFT_WORD_WIDTH-1:0] reg_b_data_mux;
  logic [MEMBERS/3-1:0][SHIFT_WORD_WIDTH-1:0]       reg_b_data_muxed, reg_b_data_in, reg_b_data;
  logic [MEMBERS/3-1:0][UNITS-1:0][WORD_WIDTH -1:0] b_data;
  logic [MEMBERS/3-1:0][CLR_WIDTH-1:0] b_clr;

  generate
    always_comb begin
      reg_b_data_mux = 0;
      reg_b_data_mux[0][0][0] = reg_a_data[MEMBERS-1];
      for (int m=0; m<MEMBERS; m++)
        for (int kw2=1; kw2 <=KW_MAX/2; kw2++)
          for (int sw_1=0; sw_1 < SW_MAX; sw_1++) begin

            static int k, s, j;
            k  = kw2*2+1;
            s  = sw_1+1;
            j  = k + sw_1;

            if(`KS_COMBS_EXPR)
              if (m%j == j-1) 
                  reg_b_data_mux[kw2][sw_1][m/j] = reg_a_data[m];
          end
    end
    assign reg_b_data_muxed = reg_b_data_mux[a_kw2][a_sw_1];
  endgenerate

  assign reg_b_data_in = count_b_last ? reg_b_data_muxed : reg_b_data >> SHIFT_WORD_WIDTH;

  register #(
    .WORD_WIDTH     ((MEMBERS/3)*SHIFT_WORD_WIDTH),
    .RESET_VALUE    (0)
  ) REG_B_DATA (
    .clock          (aclk   ),
    .resetn         (aresetn),
    .clock_enable   (count_b_en),
    .data_in        (reg_b_data_in),
    .data_out       (reg_b_data)
  );

  generate
    for (genvar m=0; m<MEMBERS/3; m++)
      assign {b_data[m], b_clr[m]} = reg_b_data[m];
  endgenerate

  // valid, last
  logic b_valid;
  register #(
    .WORD_WIDTH     (1),
    .RESET_VALUE    (0)
  ) REG_B_VALID (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (b_ready),
    .data_in        (a_valid),
    .data_out       (b_valid)
  );

  logic [TUSER_CONV_DW_BASE -1:0] b_user_base;
  logic b_last, reg_b_last_temp;
  register #(
    .WORD_WIDTH     (1 + TUSER_CONV_DW_BASE),
    .RESET_VALUE    (0)
  ) REG_B_USER_LAST (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (a_valid & b_ready),
    .data_in        ({a_last         , a_user_base}),
    .data_out       ({reg_b_last_temp, b_user_base})
  );
  assign b_last = reg_b_last_temp & count_b_last;

  logic [USER_WIDTH_OUT-1:0] b_user;
  assign b_user = {b_clr[0], b_user_base};


  axis_register #
  (
    .DATA_WIDTH  (UNITS*WORD_WIDTH),
    .KEEP_ENABLE (0),
    .LAST_ENABLE (1),
    .ID_ENABLE   (0),
    .DEST_ENABLE (0),
    .USER_ENABLE (1),
    .USER_WIDTH  (USER_WIDTH_OUT),
    .REG_TYPE    (2)
  ) SLICE (
    .clk          (aclk       ),
    .rst          (~aresetn   ),
    .s_axis_tready(slice_ready),
    .s_axis_tdata (b_data  [0]),
    .s_axis_tvalid(b_valid    ),
    .s_axis_tlast (b_last     ),
    .s_axis_tuser (b_user     ),
    .m_axis_tdata (m_data     ),
    .m_axis_tvalid(m_valid    ),
    .m_axis_tready(m_ready    ),
    .m_axis_tlast (m_last     ),
    .m_axis_tuser (m_user     )
  );

endmodule

module axis_conv_dw_bank (
  aclk       ,
  aresetn    ,
  s_data     ,
  s_valid    ,
  s_ready    ,
  s_last     ,
  s_user     ,
  m_data     ,
  m_valid    ,
  m_ready    ,
  m_last     ,
  m_user
);

  localparam UNITS                = `UNITS                ;
  localparam GROUPS               = `GROUPS               ;
  localparam COPIES               = `COPIES               ;
  localparam MEMBERS              = `MEMBERS              ;
  localparam WORD_WIDTH           = `WORD_WIDTH_ACC       ;
  localparam TUSER_WIDTH_LRELU_IN = `TUSER_WIDTH_LRELU_IN ;  
  localparam TUSER_CONV_DW_IN     = `TUSER_CONV_DW_IN     ;  

  localparam WORD_BYTES = WORD_WIDTH/8;

  input logic aclk, aresetn;

  input  logic s_valid, s_last;
  output logic s_ready;
  input  logic [TUSER_CONV_DW_IN-1:0] s_user;
  input  logic [COPIES -1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0][WORD_WIDTH-1:0] s_data;

  input  logic m_ready;
  output logic [COPIES -1:0][GROUPS-1:0][UNITS-1:0][WORD_WIDTH  -1:0] m_data;
  output logic [TUSER_WIDTH_LRELU_IN-1:0] m_user;
  output logic m_valid, m_last;

  logic [COPIES-1:0][GROUPS-1:0] s_ready_cg;
  logic [COPIES-1:0][GROUPS-1:0] m_valid_cg;
  logic [COPIES-1:0][GROUPS-1:0] m_last_cg;
  logic [COPIES-1:0][GROUPS-1:0][TUSER_WIDTH_LRELU_IN-1:0] m_user_cg;

  generate
    for (genvar c=0 ; c<COPIES; c++) begin: C
      for (genvar g=0 ; g<GROUPS; g++) begin: G
        axis_dw_shift CONV_DW (
          .aclk    (aclk             ),
          .aresetn (aresetn          ),
          .s_ready (s_ready_cg [c][g]),
          .s_valid (s_valid          ),
          .s_data  (s_data     [c][g]),
          .s_user  (s_user           ),
          .s_last  (s_last           ),
          .m_ready (m_ready          ),
          .m_valid (m_valid_cg [c][g]),
          .m_data  (m_data     [c][g]),
          .m_user  (m_user_cg  [c][g]),
          .m_last  (m_last_cg  [c][g])
        );
      end 
    end 
  endgenerate

  assign s_ready = s_ready_cg[0][0];
  assign m_valid = m_valid_cg[0][0];
  assign m_last  = m_last_cg [0][0];
  assign m_user  = m_user_cg [0][0];

endmodule