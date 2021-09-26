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

  s_data  ,
  s_valid ,
  s_ready ,
  s_last  ,
  s_user  ,
  s_keep  ,

  m_kw2   ,
  m_sw_1  ,

  m_data  ,
  m_valid ,
  m_keep  ,
  m_ready ,
  m_last  , // not registered
  m_user
);

  input logic aclk, aresetn;

  input  logic s_valid, s_last;
  output logic s_ready;
  input  logic [MEMBERS-1:0][UNITS-1:0][WORD_WIDTH -1:0] s_data;
  input  logic [MEMBERS-1:0]                             s_keep;
  input  logic [MEMBERS-1:0][TUSER_WIDTH-1:0]            s_user;
  
  input  logic m_ready;
  output logic [MEMBERS-1:0][UNITS-1:0][WORD_WIDTH -1:0] m_data;
  output logic [MEMBERS-1:0]                             m_keep;
  output logic [MEMBERS-1:0][TUSER_WIDTH-1:0]            m_user;
  output logic m_valid, m_last;
  output logic [BITS_KW2-1:0] m_kw2;
  output logic [BITS_SW -1:0] m_sw_1 ;

  logic [KW_MAX/2:0][SW_MAX-1:0][BITS_MEMBERS-1:0] lut_valid_next_idx;

  localparam SHIFT_WORD_WIDTH = UNITS*WORD_WIDTH + TUSER_WIDTH + 1;
  logic [MEMBERS -1:0][SHIFT_WORD_WIDTH-1:0] reg_data_s, reg_data_in, reg_data_m;
  logic m_valid_next, s_ready_next, reg_last, reg_en, last_en;

  generate

    for (genvar m=0; m<MEMBERS; m++) begin
      assign reg_data_s [m] = {s_data[m], s_user[m], s_keep[m]};
      assign {m_data[m], m_user[m], m_keep[m]} = reg_data_m[m];
    end

    // Extract kw2, sw_1, m_valid_next, m_valid
    assign lut_valid_next_idx[0][0] = MEMBERS-2;
    for (genvar kw2=1; kw2 <=KW_MAX/2; kw2++)
      for (genvar sw_1=0; sw_1 < kw2 && sw_1 < SW_MAX; sw_1++) begin
        localparam kw = kw2*2+1;
        localparam sw = sw_1+1;
        if ((kw==0 & sw==1)|(kw==3 & sw==1)|(kw==5 & sw==1)|(kw==7 & sw==2)|(kw==11 & sw==4)) // only allowed combos, to reduce mux
          assign lut_valid_next_idx[kw2][sw_1] = (kw2*2+1) + (sw_1+1)-3;
      end

    assign m_kw2        = m_user[MEMBERS-1][BITS_KW2+I_KW2-1:I_KW2];
    assign m_sw_1       = m_user[MEMBERS-1][BITS_SW +I_SW_1-1:I_SW_1];
    assign m_valid_next = m_keep[lut_valid_next_idx[m_kw2][m_sw_1]];

    // STATE MACHINE

    localparam RX = 0;
    localparam TX = 1;
    logic state, state_next;

    always_comb begin
      state_next = state;
      unique case (state)
        RX : if (s_valid)                  state_next = TX;
        TX : if (m_ready && !m_valid_next) state_next = RX;
      endcase
    end    

    register #(
      .WORD_WIDTH  (1),
      .RESET_VALUE (RX),
      .LOCAL       (0)
    ) STATE (
      .clock       (aclk),
      .clock_enable(1'b1),
      .resetn      (aresetn),
      .data_in     (state_next),
      .data_out    (state     )
    );

    always_comb begin
      unique case (state)
        RX :  begin
                reg_en      = s_valid;
                reg_data_in = reg_data_s;
              end
        TX :  begin
                reg_en      = m_ready;
                reg_data_in = reg_data_m << SHIFT_WORD_WIDTH;
              end
      endcase
    end

    // OUTPUTS

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

    assign m_valid      = state;       // TX = 1
    assign s_ready_next = ~state_next; // RX = 0
    register #(
      .WORD_WIDTH  (1),
      .RESET_VALUE (1),
      .LOCAL       (0)
    ) S_READY (
      .clock       (aclk),
      .clock_enable(1'b1),
      .resetn      (aresetn),
      .data_in     (s_ready_next),
      .data_out    (s_ready     )
    );

    assign last_en = s_ready & s_valid;
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

    assign m_last  = reg_last && !m_valid_next;

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

  s_data  ,
  s_valid ,
  s_ready ,
  s_last  ,
  s_user  ,
  s_keep  ,
  s_kw2   ,
  s_sw_1  ,

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
  input  logic [BITS_KW2-1:0] s_kw2;
  input  logic [BITS_SW -1:0] s_sw_1;
  
  input  logic m_ready;
  output logic [UNITS-1:0][WORD_WIDTH -1:0] m_data;
  output logic [TUSER_WIDTH-1:0]            m_user;
  output logic m_valid, m_last;

  logic m_valid_next, s_ready_next, reg_last, reg_en, last_en;
  localparam SHIFT_WORD_WIDTH = UNITS*WORD_WIDTH + TUSER_WIDTH + 1;
  logic [MEMBERS  -1:0][SHIFT_WORD_WIDTH-1:0] s_data_packed;
  logic [KW_MAX/2:0][SW_MAX-1:0][MEMBERS/3-1:0][SHIFT_WORD_WIDTH-1:0] reg_data_s_mux;

  logic [MEMBERS/3-1:0][SHIFT_WORD_WIDTH-1:0]       reg_data_s_muxed, reg_data_in, reg_data_r;
  logic [MEMBERS/3-1:0][UNITS-1:0][WORD_WIDTH -1:0] r_data;
  logic [MEMBERS/3-1:0]           [WORD_WIDTH -1:0] r_user;
  logic [MEMBERS/3-1:0]                             r_keep;

  generate
    
    for (genvar m3=0; m3<MEMBERS/3; m3++)
      assign {r_data[m3], r_user[m3], r_keep[m3]} = reg_data_r[m3];

    assign {m_data, m_user, m_valid} = reg_data_r[0];

    /*
      Input Mux
    */
    always_comb begin
      reg_data_s_mux = 0;
      for (int m=0; m<MEMBERS; m++) begin
        s_data_packed [m] = {s_data[m], s_user[m], s_keep[m]};

        reg_data_s_mux[0][0][0] = s_data_packed[MEMBERS-1];
        for (int kw2=1; kw2 <=KW_MAX/2; kw2++)
          for (int sw_1=0; sw_1 < kw2 && sw_1 < SW_MAX; sw_1++) begin
            automatic int kw = kw2*2+1;
            automatic int sw = sw_1+1;
            automatic int j  = kw + sw_1;

            if ((kw==0 & sw==1)|(kw==3 & sw==1)|(kw==5 & sw==1)|(kw==7 & sw==2)|(kw==11 & sw==4)) // only allowed combinations, to minimize mux
              if (m%j == j-1) 
                reg_data_s_mux[kw2][sw_1][m/j] = s_data_packed[m];
          end
      end
    end
    assign reg_data_s_muxed = reg_data_s_mux[s_kw2][s_sw_1];

    // STATE MACHINE

    localparam RX = 0;
    localparam TX = 1;
    logic state, state_next;

    always_comb begin
      state_next = state;
      unique case (state)
        RX : if (s_valid)                  state_next = TX;
        TX : if (m_ready && !m_valid_next) state_next = RX;
      endcase
    end    

    register #(
      .WORD_WIDTH  (1),
      .RESET_VALUE (RX),
      .LOCAL       (0)
    ) STATE (
      .clock       (aclk),
      .clock_enable(1'b1),
      .resetn      (aresetn),
      .data_in     (state_next),
      .data_out    (state     )
    );

    always_comb begin
      unique case (state)
        RX :  begin
                reg_en      = s_valid;
                reg_data_in = reg_data_s_muxed;
              end
        TX :  begin
                reg_en      = m_ready;
                reg_data_in = reg_data_r >> SHIFT_WORD_WIDTH;
              end
      endcase
    end

    assign m_valid_next     = reg_data_in[0];

    // OUTPUTS

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

    assign s_ready_next = ~state_next; // RX = 0
    register #(
      .WORD_WIDTH  (1),
      .RESET_VALUE (1),
      .LOCAL       (0)
    ) S_READY (
      .clock       (aclk),
      .clock_enable(1'b1),
      .resetn      (aresetn),
      .data_in     (s_ready_next),
      .data_out    (s_ready     )
    );

    assign last_en = s_ready & s_valid;
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

    assign m_last  = reg_last && !m_valid_next;

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

  logic i_ready, i_valid, i_last;
  logic [MEMBERS-1:0][UNITS-1:0][WORD_WIDTH -1:0] i_data;
  logic [MEMBERS-1:0]                             i_keep;
  logic [MEMBERS-1:0][TUSER_WIDTH-1:0]            i_user;
  logic [BITS_KW2-1:0] i_kw2;
  logic [BITS_SW -1:0] i_sw_1 ;

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
    .aclk    (aclk   ),
    .aresetn (aresetn),
    .s_data  (s_data ),
    .s_valid (s_valid),
    .s_ready (s_ready),
    .s_last  (s_last ),
    .s_user  (s_user ),
    .s_keep  (s_keep ),
    .m_kw2   (i_kw2  ),
    .m_sw_1  (i_sw_1 ),
    .m_data  (i_data ),
    .m_valid (i_valid),
    .m_keep  (i_keep ),
    .m_ready (i_ready),
    .m_last  (i_last ),
    .m_user  (i_user )
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
    .aclk    (aclk   ),
    .aresetn (aresetn),
    .s_data  (i_data ),
    .s_valid (i_valid),
    .s_ready (i_ready),
    .s_last  (i_last ),
    .s_user  (i_user ),
    .s_keep  (i_keep ),
    .s_kw2   (i_kw2  ),
    .s_sw_1  (i_sw_1 ),
    .m_data  (m_data ),
    .m_valid (m_valid),
    .m_ready (m_ready),
    .m_last  (m_last ),
    .m_user  (m_user )
  );

endmodule