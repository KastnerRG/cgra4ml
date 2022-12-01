/*//////////////////////////////////////////////////////////////////////////////////
Engineer: Abarajithan G.
Create Date: 26/07/2020
Design Name: Convolution Engine
Tool Versions: Vivado 2018.2
Dependencies: 
Revision:
Revision 0.01 - File Created
Additional Comments: 
//////////////////////////////////////////////////////////////////////////////////*/
`timescale 1ns/1ps
`include "../include/params.v"

module conv_engine #(ZERO=0) (
    clk            ,
    clken          ,
    resetn         ,
    s_valid        ,
    s_ready        ,
    s_last         ,
    s_user         ,
    s_data_pixels  ,
    s_data_weights ,
    m_valid        ,
    m_data         ,
    m_last         ,
    m_user         
);

  localparam COPIES              = `COPIES              ;
  localparam GROUPS              = `GROUPS              ;
  localparam MEMBERS             = `MEMBERS             ;
  localparam UNITS               = `UNITS               ;
  localparam WORD_WIDTH_IN       = `WORD_WIDTH          ;
  localparam WORD_WIDTH_OUT      = `WORD_WIDTH_ACC      ;
  localparam LATENCY_ACCUMULATOR = `LATENCY_ACCUMULATOR ;
  localparam LATENCY_MULTIPLIER  = `LATENCY_MULTIPLIER  ;
  localparam KW_MAX              = `KW_MAX              ;
  localparam SW_MAX              = `SW_MAX              ;
  localparam I_IS_NOT_MAX        = `I_IS_NOT_MAX        ;
  localparam I_IS_BOTTOM_BLOCK   = `I_IS_BOTTOM_BLOCK   ;
  localparam I_IS_CONFIG         = `I_IS_CONFIG         ;
  localparam I_IS_CIN_LAST       = `I_IS_CIN_LAST       ;
  localparam I_IS_W_FIRST        = `I_IS_W_FIRST        ;
  localparam I_IS_COL_VALID      = `I_IS_COL_VALID      ;
  localparam I_IS_SUM_START      = `I_IS_SUM_START      ;
  localparam I_KW2               = `I_KW2               ;
  localparam I_SW_1              = `I_SW_1              ;
  localparam I_CLR               = `I_CLR               ;
  localparam TUSER_WIDTH_CONV_IN = `TUSER_WIDTH_CONV_IN ;
  localparam TUSER_WIDTH_CONV_OUT= `TUSER_CONV_DW_IN    ;  
  localparam TUSER_CONV_DW_BASE  = `TUSER_CONV_DW_BASE  ;  
  localparam BITS_OUT_SHIFT      = `BITS_OUT_SHIFT      ;  
  localparam BITS_KW             = `BITS_KW             ;
  localparam BITS_SW             = `BITS_SW             ;
  localparam BITS_MEMBERS        = `BITS_MEMBERS        ;
  localparam BITS_KW2            = `BITS_KW2            ;

  input  logic clk, clken, resetn;
  input  logic s_valid, s_last;
  output logic s_ready;
  output logic m_valid, m_last;
  input  logic [TUSER_WIDTH_CONV_IN-1:0] s_user;
  input  logic [COPIES-1:0][UNITS -1:0]                        [WORD_WIDTH_IN    -1:0] s_data_pixels;
  input  logic [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0]           [WORD_WIDTH_IN    -1:0] s_data_weights;                                                                        
  output logic [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0][WORD_WIDTH_OUT   -1:0] m_data;
  output logic [TUSER_WIDTH_CONV_OUT-1:0] m_user;
  
  logic [TUSER_CONV_DW_BASE -1:0] m_user_base;
  logic [BITS_MEMBERS  -1:0] m_shift_a;
  logic [BITS_OUT_SHIFT-1:0] m_shift_b;
  logic [MEMBERS-1:0][BITS_KW-1:0] m_clr;

  logic clken_mul, mux_sel_next, mux_sel, mul_m_valid, acc_m_valid_next, acc_m_valid, mul_m_last, acc_m_last;
  logic [BITS_KW2-1:0] mul_m_kw2, acc_m_kw2;
  logic [BITS_SW -1:0] acc_m_sw_1;
  logic [MEMBERS-1: 0] clken_acc, bypass_sum, bypass_sum_next, bypass;
  logic [MEMBERS-1: 0] acc_m_sum_start, acc_s_valid, acc_m_keep;
  logic [TUSER_WIDTH_CONV_IN -1: 0] mul_m_user, acc_s_user, mux_s2_user, acc_m_user;

  logic [KW_MAX/2:0][SW_MAX -1:0][MEMBERS -1:0] lut_sum_start;

  logic valid_mask;

  logic [WORD_WIDTH_IN*2-1:0] mul_m_data  [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0];
  logic [WORD_WIDTH_OUT -1:0] acc_s_data  [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0];
  logic [WORD_WIDTH_OUT -1:0] mux_s2_data [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0];

  assign s_ready = clken_mul;

  generate
    genvar c,g,u,m,b,kw2,sw_1;

    n_delay #(
      .N          (LATENCY_MULTIPLIER     ),
      .WORD_WIDTH (TUSER_WIDTH_CONV_IN + 2)
    ) MUL_CONTROL(
      .clk      (clk      ),
      .resetn   (resetn   ),
      .clken    (clken_mul),
      .data_in  ({s_valid    , s_last    , s_user    }),
      .data_out ({mul_m_valid, mul_m_last, mul_m_user})
    );

    assign mul_m_kw2 = mul_m_user[BITS_KW2+I_KW2-1 : I_KW2];

    for (c=0; c < COPIES; c++)
      for (g=0; g < GROUPS; g++)
        for (u=0; u < UNITS; u++)
          for (m=0; m < MEMBERS; m++)
            if (m==0) assign mux_s2_data [c][g][m][u] = 0;
            else      assign mux_s2_data [c][g][m][u] = m_data     [c][g][m-1][u];

    assign mux_sel_next = mul_m_valid && mul_m_user[I_IS_CIN_LAST] && (mul_m_kw2 != 0);

    register #(
      .WORD_WIDTH     (1),
      .RESET_VALUE    (0)
    ) MUX_SEL (
      .clock          (clk   ),
      .resetn         (resetn),
      .clock_enable   (clken ),
      .data_in        (mux_sel_next),
      .data_out       (mux_sel )
    );
    assign clken_mul = clken && !mux_sel;
            
    for (m=0; m < MEMBERS; m++) begin: Mb
      for (kw2=0; kw2 <= KW_MAX/2; kw2++)
        for (sw_1=0; sw_1 < SW_MAX; sw_1++) begin
          localparam k = kw2*2 + 1;
          localparam s = sw_1 + 1;
          localparam j = k + s -1;

          assign lut_sum_start[kw2][sw_1][m] = m % j < s; // m % 3 < 1 : 0,1
        end
      
      assign acc_m_sum_start [m] = lut_sum_start[acc_m_kw2][acc_m_sw_1][m] & acc_m_user[I_IS_SUM_START];
      assign acc_s_valid     [m] = mux_sel ? ~acc_m_sum_start [m] : mul_m_valid;

      assign bypass_sum_next [m] = mul_m_user[I_IS_CIN_LAST] || mul_m_user [I_IS_CONFIG];

      register #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (0)
      ) BYPASS_SUM (
        .clock          (clk   ),
        .resetn         (resetn),
        .clock_enable   (clken && acc_s_valid [m]), // first PE of each elastic core gets bypass for 2 clocks
        .data_in        (bypass_sum_next      [m]),
        .data_out       (bypass_sum           [m])
      );

      assign bypass    [m] = bypass_sum [m] || mul_m_user [I_IS_W_FIRST]; // clears all partial sums for every first col
      assign clken_acc [m] = clken && acc_s_valid [m];
    end

    for (c=0; c < COPIES; c++) begin: Ca
      for (g=0; g < GROUPS; g++) begin: Ga
        for (u=0; u < UNITS; u++) begin: Ua
          for (m=0; m < MEMBERS; m++) begin: Ma
            processing_element #(
              .WORD_WIDTH_IN (WORD_WIDTH_IN ),
              .WORD_WIDTH_OUT(WORD_WIDTH_OUT)
              ) PROCESSING_ELEMENT (
              .clk           (clk           ),
              .clken         (clken         ),
              .resetn        (resetn        ),
              .clken_mul     (clken_mul     ),
              .s_data_pixels (s_data_pixels [c]      [u]), 
              .s_data_weights(s_data_weights[c][g][m]   ),
              .mul_m_data    (mul_m_data    [c][g][m][u]),
              .mux_sel       (mux_sel       ),
              .mux_s2_data   (mux_s2_data   [c][g][m][u]),
              .bypass        (bypass        [m]),
              .clken_acc     (clken_acc     [m]),
              .acc_s_data    (acc_s_data    [c][g][m][u]),
              .m_data        (m_data        [c][g][m][u])
            );
    end end end end

    n_delay #(
      .N          (LATENCY_ACCUMULATOR),
      .WORD_WIDTH (TUSER_WIDTH_CONV_IN)
    ) ACC_USER (
      .clk      (clk         ),
      .resetn   (resetn      ),
      .clken    (clken & mul_m_valid),
      .data_in  (mul_m_user  ),
      .data_out (acc_m_user  )
    );

    assign acc_m_kw2  = acc_m_user[BITS_KW2+I_KW2-1 : I_KW2];
    assign acc_m_sw_1 = acc_m_user[BITS_SW+I_SW_1-1 : I_SW_1];

    assign acc_m_valid_next = !mux_sel && mul_m_valid && (mul_m_user[I_IS_CONFIG] || mul_m_user[I_IS_CIN_LAST]);
    
    n_delay #(
      .N          (LATENCY_ACCUMULATOR),
      .WORD_WIDTH (2)
    ) ACC_VALID_LAST(
      .clk      (clk   ),
      .resetn   (resetn),
      .clken    (clken ),
      .data_in  ({acc_m_valid_next, mul_m_last}),
      .data_out ({acc_m_valid     , acc_m_last})
    );

    pad_filter # (.ZERO(ZERO)) PAD_FILTER (
      .aclk            (clk                ),
      .aclken          (clken              ),
      .aresetn         (resetn             ),
      .user_in         (acc_m_user         ),
      .valid_in        (acc_m_valid        ),
      .shift_a         (m_shift_a          ),
      .shift_b         (m_shift_b          ),
      .valid_mask      (valid_mask         ),
      .clr             (m_clr              )
    );

    assign m_user_base[I_IS_BOTTOM_BLOCK:I_IS_NOT_MAX] = acc_m_user[I_IS_BOTTOM_BLOCK:I_IS_NOT_MAX];
    assign m_user  = {m_clr, m_shift_b, m_shift_a, m_user_base};
    assign m_last  = acc_m_last;
    assign m_valid = acc_m_valid & valid_mask;
  endgenerate
endmodule

module processing_element #(
  WORD_WIDTH_IN  = 8,
  WORD_WIDTH_OUT = 24
)(
  clk    ,
  clken  ,
  resetn ,

  clken_mul,
  s_data_pixels, 
  s_data_weights,
  mul_m_data,

  mux_sel,
  mux_s2_data,
  bypass,
  clken_acc,
  acc_s_data,
  m_data
);

  input  logic clk, clken, resetn;
  input  logic clken_mul, mux_sel, bypass, clken_acc;

  input  logic signed [WORD_WIDTH_IN  -1:0] s_data_pixels, s_data_weights;
  input  logic signed [WORD_WIDTH_OUT -1:0] mux_s2_data;
  output logic signed [WORD_WIDTH_IN*2-1:0] mul_m_data;
  output logic signed [WORD_WIDTH_OUT -1:0] acc_s_data;
  output logic signed [WORD_WIDTH_OUT -1:0] m_data;

  // Multiplier

  logic signed [WORD_WIDTH_IN  -1:0] s_data_pixels_q, s_data_weights_q;

  logic mul_in_valid, mul_valid;

  assign mul_in_valid    = (|s_data_pixels) && (|s_data_weights);

  wire clken_mul_valid = clken_mul & mul_in_valid;
  n_delay #(
    .N          (`LATENCY_MULTIPLIER),
    .WORD_WIDTH (WORD_WIDTH_IN*2),
    .LOCAL      (0)
  ) MUL_IN (
    .clk      (clk ),
    .resetn   (1'b1),
    .clken    (clken_mul_valid),
    .data_in  ({s_data_pixels  , s_data_weights  }),
    .data_out ({s_data_pixels_q, s_data_weights_q})
  );
  n_delay #(
    .N          (`LATENCY_MULTIPLIER),
    .WORD_WIDTH (1),
    .LOCAL      (0)
  ) MUL_VALID (
    .clk      (clk ),
    .resetn   (1'b1),
    .clken    (clken_mul),
    .data_in  (mul_in_valid),
    .data_out (mul_valid)
  );

  assign mul_m_data = s_data_pixels_q * s_data_weights_q;

  // Mux

  logic acc_s_valid, acc_s_valid_d, acc_in_valid;

  assign acc_s_data = mux_sel ? mux_s2_data  : WORD_WIDTH_OUT'(signed'(mul_m_data));
  assign acc_s_valid = mux_sel ? 1           : mul_valid;

  // Accumulator

  logic bypass_d;
  logic signed [WORD_WIDTH_OUT-1:0] acc_s_data_d;  

  wire clken_acc_s_valid = clken_acc & acc_s_valid;
  n_delay #(
    .N          (`LATENCY_ACCUMULATOR-1),
    .WORD_WIDTH (WORD_WIDTH_OUT +1),
    .LOCAL      (0)
  ) ACC_IN (
    .clk      (clk ),
    .resetn   (1'b1),
    .clken    (clken_acc_s_valid),
    .data_in  ({acc_s_data  , bypass  }),
    .data_out ({acc_s_data_d, bypass_d})
  );
  n_delay #(
    .N          (`LATENCY_ACCUMULATOR-1),
    .WORD_WIDTH (1),
    .LOCAL      (0)
  ) ACC_S_VALID (
    .clk      (clk ),
    .resetn   (1'b1),
    .clken    (clken_acc),
    .data_in  (acc_s_valid),
    .data_out (acc_s_valid_d)
  );

  logic signed [WORD_WIDTH_OUT-1:0] acc_in;
  assign acc_in = (acc_s_valid_d ? acc_s_data_d : 0) + (bypass_d ? 0 : m_data);

  wire clken_acc_valid = clken_acc && (acc_s_valid_d || bypass_d);
  register #(
    .WORD_WIDTH  (WORD_WIDTH_OUT),
    .RESET_VALUE (0),
    .LOCAL       (0)
  ) ACC (
    .clock       (clk),
    .clock_enable(clken_acc_valid),
    .resetn      (1'b1),
    .data_in     (acc_in),
    .data_out    (m_data)
  );

endmodule