`timescale 1ns/1ps
`include "params.v"

module axis_dw_shift_1 #(
  ZERO         = 0,
  WORD_WIDTH   = 8,
  UNITS        = 8,
  MEMBERS      = 24,
  KW_MAX       = 11,
  SW_MAX       = 4,
  I_KW2        = 2,
  BITS_KW2     = $clog2(KW_MAX/2+1),
  I_SW_1       = I_KW2 + BITS_KW2,
  BITS_SW      = $clog2(SW_MAX  +1),
  TUSER_WIDTH  = `TUSER_WIDTH_LRELU_IN,
  BITS_MEMBERS = $clog2(MEMBERS)
) (
  aclk    ,
  aresetn ,
  aclken  ,

  s_data  ,
  s_valid ,
  not_valid_next,
  s_last  ,
  s_user  ,
  s_keep  ,

  m_kw2   ,
  m_sw_1  ,

  m_data  ,
  m_valid ,
  m_keep  ,
  m_last  , // not registered
  m_user
);

  input logic aclk, aresetn, aclken;

  input  logic s_valid, s_last;
  output logic not_valid_next;
  input  logic [MEMBERS-1:0][UNITS-1:0][WORD_WIDTH -1:0] s_data;
  input  logic [MEMBERS-1:0]                             s_keep;
  input  logic [MEMBERS-1:0][TUSER_WIDTH-1:0]            s_user;
  
  output logic [MEMBERS-1:0][UNITS-1:0][WORD_WIDTH -1:0] m_data;
  output logic [MEMBERS-1:0]                             m_keep;
  output logic [MEMBERS-1:0][TUSER_WIDTH-1:0]            m_user;
  output logic m_valid, m_last;
  output logic [BITS_KW2-1:0] m_kw2;
  output logic [BITS_SW -1:0] m_sw_1 ;

  logic valid_next_in;
  logic [BITS_KW2-1:0] s_kw2;
  logic [BITS_SW -1:0] s_sw_1;

  logic [KW_MAX/2:0][SW_MAX-1:0][BITS_MEMBERS-1:0] lut_valid_idx, lut_valid_next_idx, lut_valid_next_next_idx;

  localparam SHIFT_WORD_WIDTH = UNITS*WORD_WIDTH + TUSER_WIDTH;
  logic [MEMBERS -1:0][SHIFT_WORD_WIDTH-1:0] reg_data_s, reg_data_in, reg_data_m;
  logic reg_last, reg_en, last_en;

  generate

    for (genvar m=0; m<MEMBERS; m++) begin
      assign reg_data_s [m] = {s_data[m], s_user[m]};
      assign {m_data[m], m_user[m]} = reg_data_m[m];
    end

    // Extract kw2, sw_1, m_valid
    for (genvar kw2=0; kw2 <=KW_MAX/2; kw2++)
      for (genvar sw_1=0; sw_1 < SW_MAX; sw_1++) begin
        
        localparam k = kw2*2+1;
        localparam s = sw_1+1;
        localparam j = k==1 ? MEMBERS : k+s-1;

        if(`KS_COMBS_EXPR) begin
          assign lut_valid_idx     [kw2][sw_1]      = j-1;
          assign lut_valid_next_idx[kw2][sw_1]      = j-2;
          assign lut_valid_next_next_idx[kw2][sw_1] = j-3;
        end
      end

    assign m_kw2        = m_user[MEMBERS-1][BITS_KW2+I_KW2-1:I_KW2];
    assign m_sw_1       = m_user[MEMBERS-1][BITS_SW +I_SW_1-1:I_SW_1];

    assign s_kw2        = s_user[MEMBERS-1][BITS_KW2+I_KW2-1:I_KW2];
    assign s_sw_1       = s_user[MEMBERS-1][BITS_SW +I_SW_1-1:I_SW_1];
    assign valid_next_in= not_valid_next ? s_keep[lut_valid_next_idx[s_kw2][s_sw_1]] : m_keep[lut_valid_next_next_idx[m_kw2][m_sw_1]];

    register #(
      .WORD_WIDTH  (1),
      .RESET_VALUE (1),
      .LOCAL       (1)
    ) NOT_VALID_NEXT (
      .clock       (aclk),
      .clock_enable(aclken),
      .resetn      (aresetn),
      .data_in     (~valid_next_in),
      .data_out    (not_valid_next)
    );

    logic m_valid_in;
    assign m_valid_in = not_valid_next ? s_keep[lut_valid_idx[s_kw2][s_sw_1]] : m_keep[lut_valid_next_idx[m_kw2][m_sw_1]];

    register #(
      .WORD_WIDTH  (1),
      .RESET_VALUE (0),
      .LOCAL       (0)
    ) VALID (
      .clock       (aclk),
      .clock_enable(aclken),
      .resetn      (aresetn),
      .data_in     (m_valid_in),
      .data_out    (m_valid)
    );

    // OUTPUTS

    logic [MEMBERS-1:0] keep_in;
    assign keep_in = not_valid_next ? s_keep : m_keep << 1;

    register #(
      .WORD_WIDTH  (MEMBERS),
      .RESET_VALUE (0),
      .LOCAL       (0)
    ) M_KEEP (
      .clock       (aclk),
      .clock_enable(aclken),
      .resetn      (aresetn),
      .data_in     (keep_in),
      .data_out    (m_keep )
    );
    assign reg_en      = aclken & (not_valid_next ? s_valid : 1);
    assign reg_data_in = not_valid_next ? reg_data_s : reg_data_m << SHIFT_WORD_WIDTH;

    register #(
      .WORD_WIDTH  (MEMBERS*SHIFT_WORD_WIDTH),
      .RESET_VALUE (0),
      .LOCAL       (0)
    ) DATA (
      .clock       (aclk),
      .clock_enable(reg_en),
      .resetn      (aresetn),
      .data_in     (reg_data_in),
      .data_out    (reg_data_m )
    );

    assign last_en = aclken & not_valid_next & s_valid;
    register #(
      .WORD_WIDTH  (1),
      .RESET_VALUE (0),
      .LOCAL       (0)
    ) LAST (
      .clock       (aclk),
      .clock_enable(last_en),
      .resetn      (aresetn),
      .data_in     (s_last),
      .data_out    (reg_last)
    );

    assign m_last  = reg_last && not_valid_next;

  endgenerate
endmodule

module axis_dw_shift_2 #(
  ZERO         = 0,
  WORD_WIDTH   = 8,
  UNITS        = 8,
  MEMBERS      = 24,
  KW_MAX       = 11,
  SW_MAX       = 4,
  I_KW2        = 2,
  BITS_KW2     = $clog2(KW_MAX/2+1),
  I_SW_1       = I_KW2 + BITS_KW2,
  BITS_SW      = $clog2(SW_MAX  +1),
  TUSER_WIDTH  = `TUSER_WIDTH_LRELU_IN,
  BITS_MEMBERS = $clog2(MEMBERS)
) (
  aclk    ,
  aresetn ,
  aclken  ,

  s_data  ,
  s_valid ,
  not_valid_next ,
  s_last  ,
  s_user  ,
  s_keep  ,
  s_kw2   ,
  s_sw_1  ,

  m_data  ,
  m_valid ,
  m_last  ,
  m_user
);

  input logic aclk, aresetn, aclken;

  input  logic s_valid, s_last;
  output logic not_valid_next;
  input  logic [MEMBERS-1:0][UNITS-1:0][WORD_WIDTH -1:0] s_data;
  input  logic [MEMBERS-1:0]                             s_keep;
  input  logic [MEMBERS-1:0][TUSER_WIDTH-1:0]            s_user;
  input  logic [BITS_KW2-1:0] s_kw2;
  input  logic [BITS_SW -1:0] s_sw_1;
  
  output logic [UNITS-1:0][WORD_WIDTH -1:0] m_data;
  output logic [TUSER_WIDTH-1:0]            m_user;
  output logic m_valid, m_last;

  logic reg_last, reg_en, last_en;
  localparam SHIFT_WORD_WIDTH = UNITS*WORD_WIDTH + TUSER_WIDTH;
  logic [MEMBERS  -1:0][SHIFT_WORD_WIDTH-1:0] s_data_packed;
  logic [KW_MAX/2:0][SW_MAX-1:0][MEMBERS/3-1:0][SHIFT_WORD_WIDTH-1:0] reg_data_s_mux;
  logic [KW_MAX/2:0][SW_MAX-1:0][MEMBERS/3-1:0]                       reg_keep_s_mux;

  logic [MEMBERS/3-1:0][SHIFT_WORD_WIDTH-1:0]       reg_data_s_muxed, reg_data_in, reg_data_r;
  logic [MEMBERS/3-1:0][UNITS-1:0][WORD_WIDTH -1:0] r_data;
  logic [MEMBERS/3-1:0]           [WORD_WIDTH -1:0] r_user;
  logic [MEMBERS/3-1:0]                             reg_keep_s_muxed, reg_keep_in, r_keep;

  generate

    assign not_valid_next = ~r_keep[1];
    assign {m_data, m_user} = reg_data_r[0];
    
    for (genvar m3=0; m3<MEMBERS/3; m3++)
      assign {r_data[m3], r_user[m3]} = reg_data_r[m3];

    /*
      Input Mux
    */
    always_comb begin

      for (int m=0; m<MEMBERS; m++)
        s_data_packed [m] = {s_data[m], s_user[m]};

      reg_data_s_mux = 0;
      reg_keep_s_mux = 0;
      reg_data_s_mux[0][0][0] = s_data_packed[MEMBERS-1];
      reg_keep_s_mux[0][0][0] = s_keep       [MEMBERS-1];

      for (int m=0; m<MEMBERS; m++)
        for (int kw2=1; kw2 <=KW_MAX/2; kw2++)
          for (int sw_1=0; sw_1 < SW_MAX; sw_1++) begin

            automatic int k  = kw2*2+1;
            automatic int s  = sw_1+1;
            automatic int j  = k + sw_1;

            if(`KS_COMBS_EXPR)
              if (m%j == j-1) 
                begin
                  reg_data_s_mux[kw2][sw_1][m/j] = s_data_packed[m];
                  reg_keep_s_mux[kw2][sw_1][m/j] = s_keep       [m];
                end
          end
    end
    assign reg_data_s_muxed = reg_data_s_mux[s_kw2][s_sw_1];
    assign reg_keep_s_muxed = reg_keep_s_mux[s_kw2][s_sw_1];

    // OUTPUTS

    assign reg_keep_in = not_valid_next ? reg_keep_s_muxed : r_keep     >> 1;
    assign m_valid     = r_keep[0];
    register #(
      .WORD_WIDTH  (MEMBERS/3),
      .RESET_VALUE (0),
      .LOCAL       (0)
    ) M_KEEP (
      .clock       (aclk),
      .clock_enable(aclken),
      .resetn      (aresetn),
      .data_in     (reg_keep_in),
      .data_out    (r_keep     )
    );

    assign reg_en      = aclken & (not_valid_next ? s_valid : 1);
    assign reg_data_in = not_valid_next ? reg_data_s_muxed : reg_data_r >> SHIFT_WORD_WIDTH;

    register #(
      .WORD_WIDTH  ((MEMBERS/3)*SHIFT_WORD_WIDTH),
      .RESET_VALUE (0),
      .LOCAL       (0)
    ) DATA (
      .clock       (aclk),
      .clock_enable(reg_en),
      .resetn      (aresetn),
      .data_in     (reg_data_in),
      .data_out    (reg_data_r )
    );

    assign last_en = aclken & not_valid_next & s_valid;
    register #(
      .WORD_WIDTH  (1),
      .RESET_VALUE (0),
      .LOCAL       (0)
    ) LAST (
      .clock       (aclk),
      .clock_enable(last_en),
      .resetn      (aresetn),
      .data_in     (s_last),
      .data_out    (reg_last)
    );

    assign m_last  = reg_last && not_valid_next;

  endgenerate
endmodule

module axis_dw_shift #(
  ZERO         = 0,
  WORD_WIDTH   = 8,
  UNITS        = 8,
  MEMBERS      = 24,
  KW_MAX       = 11,
  SW_MAX       = 4,
  I_KW2        = 2,
  BITS_KW2     = $clog2(KW_MAX/2+1),
  I_SW_1       = I_KW2 + BITS_KW2,
  BITS_SW      = $clog2(SW_MAX  +1),
  TUSER_WIDTH  = `TUSER_WIDTH_LRELU_IN,
  BITS_MEMBERS = $clog2(MEMBERS)
) (
  aclk    ,
  aresetn ,

  s_data  ,
  s_valid ,
  s_ready ,
  s_last  ,
  s_user  ,
  s_keep  ,

  m_data  ,
  m_valid ,
  m_ready ,
  m_last  ,
  m_user
);

  input logic aclk, aresetn;

  input  logic s_valid, s_last;
  output logic s_ready;
  input  logic [MEMBERS-1:0][UNITS-1:0][WORD_WIDTH -1:0] s_data;
  input  logic [MEMBERS-1:0]                             s_keep;
  input  logic [MEMBERS-1:0][TUSER_WIDTH-1:0]            s_user;
  
  input  logic m_ready;
  output logic [UNITS-1:0][WORD_WIDTH -1:0] m_data;
  output logic [TUSER_WIDTH-1:0]            m_user;
  output logic m_valid, m_last;

  logic not_valid_next, i_1_not_valid_next, i_1_valid, i_1_last;
  logic [MEMBERS-1:0][UNITS-1:0][WORD_WIDTH -1:0] i_1_data;
  logic [MEMBERS-1:0]                             i_1_keep;
  logic [MEMBERS-1:0][TUSER_WIDTH-1:0]            i_1_user;
  logic [BITS_KW2-1:0] i_1_kw2;
  logic [BITS_SW -1:0] i_1_sw_1 ;

  logic i_2_ready;
  logic [UNITS-1:0][WORD_WIDTH -1:0] i_2_data;
  logic [TUSER_WIDTH-1:0]            i_2_user;
  logic i_2_valid, i_2_last;

  assign s_ready = not_valid_next & i_1_not_valid_next & i_2_ready;

  axis_dw_shift_1 #(
    .ZERO         (ZERO        ),
    .WORD_WIDTH   (WORD_WIDTH  ),
    .UNITS        (UNITS       ),
    .MEMBERS      (MEMBERS     ),
    .KW_MAX       (KW_MAX      ),
    .SW_MAX       (SW_MAX      ),
    .I_KW2        (I_KW2       ),
    .BITS_KW2     (BITS_KW2    ),
    .I_SW_1       (I_SW_1      ),
    .BITS_SW      (BITS_SW     ),
    .TUSER_WIDTH  (TUSER_WIDTH ),
    .BITS_MEMBERS (BITS_MEMBERS)
  ) dw_1 (
    .aclk              (aclk     ),
    .aresetn           (aresetn  ),
    .aclken            (i_1_not_valid_next & i_2_ready),
    .s_data            (s_data   ),
    .s_valid           (s_valid  ),
    .not_valid_next    (not_valid_next),
    .s_last            (s_last   ),
    .s_user            (s_user   ),
    .s_keep            (s_keep   ),
    .m_kw2             (i_1_kw2  ),
    .m_sw_1            (i_1_sw_1 ),
    .m_data            (i_1_data ),
    .m_valid           (i_1_valid),
    .m_keep            (i_1_keep ),
    .m_last            (i_1_last ),
    .m_user            (i_1_user )
  );

  axis_dw_shift_2 #(
    .ZERO         (ZERO        ),
    .WORD_WIDTH   (WORD_WIDTH  ),
    .UNITS        (UNITS       ),
    .MEMBERS      (MEMBERS     ),
    .KW_MAX       (KW_MAX      ),
    .SW_MAX       (SW_MAX      ),
    .I_KW2        (I_KW2       ),
    .BITS_KW2     (BITS_KW2    ),
    .I_SW_1       (I_SW_1      ),
    .BITS_SW      (BITS_SW     ),
    .TUSER_WIDTH  (TUSER_WIDTH ),
    .BITS_MEMBERS (BITS_MEMBERS)
  ) dw_2 (
    .aclk             (aclk     ),
    .aresetn          (aresetn  ),
    .aclken           (i_2_ready),
    .s_data           (i_1_data ),
    .s_valid          (i_1_valid),
    .not_valid_next   (i_1_not_valid_next),
    .s_last           (i_1_last ),
    .s_user           (i_1_user ),
    .s_keep           (i_1_keep ),
    .s_kw2            (i_1_kw2  ),
    .s_sw_1           (i_1_sw_1 ),
    .m_data           (i_2_data ),
    .m_valid          (i_2_valid),
    .m_last           (i_2_last ),
    .m_user           (i_2_user )
  );

  axis_register #
  (
    .DATA_WIDTH  (UNITS*WORD_WIDTH),
    .KEEP_ENABLE (0),
    .KEEP_WIDTH  (0),
    .LAST_ENABLE (1),
    .ID_ENABLE   (0),
    .DEST_ENABLE (0),
    .USER_ENABLE (1),
    .USER_WIDTH  (TUSER_WIDTH),
    .REG_TYPE    (2)
  ) SLICE (
    .clk          (aclk),
    .rst          (~aresetn),
    .s_axis_tdata (i_2_data ),
    .s_axis_tvalid(i_2_valid),
    .s_axis_tready(i_2_ready),
    .s_axis_tlast (i_2_last ),
    .s_axis_tuser (i_2_user ),
    .s_axis_tkeep (1'b0     ),
    .s_axis_tid   (1'b0     ),
    .s_axis_tdest (1'b0     ),
    .m_axis_tdata (m_data   ),
    .m_axis_tvalid(m_valid  ),
    .m_axis_tready(m_ready  ),
    .m_axis_tlast (m_last   ),
    .m_axis_tuser (m_user   )
  );

endmodule