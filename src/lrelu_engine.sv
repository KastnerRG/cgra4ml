module lrelu_engine #(
  WORD_WIDTH_IN  = 32,
  WORD_WIDTH_OUT = 8 ,
  TUSER_WIDTH    = 4 ,
  UNITS   = 8,
  GROUPS  = 2,
  COPIES  = 2,
  MEMBERS = 2
)(
  clk     ,
  clken   ,
  resetn  ,
  s_valid ,
  s_user  ,
  s_keep_flat_cg,
  m_valid ,
  m_user  ,
  m_keep_flat_cg,
  s_data_flat_cgu,
  m_data_flat_cgu
);

  input  logic clk     ;
  input  logic clken   ;
  input  logic resetn  ;
  input  logic s_valid ;
  output logic m_valid ;
  input  logic [COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_data_flat_cgu;
  output logic [COPIES * GROUPS * UNITS * WORD_WIDTH_OUT-1:0] m_data_flat_cgu;
  input  logic [TUSER_WIDTH-1:0] s_user  ;
  output logic [1:0] m_user  ;
  input  logic [COPIES * GROUPS-1:0] s_keep_flat_cg;
  output logic [COPIES * GROUPS-1:0] m_keep_flat_cg;

  logic [WORD_WIDTH_IN -1:0] s_data_cgu [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [WORD_WIDTH_OUT-1:0] m_data_cgu [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  assign s_data_cgu = {>>{s_data_flat_cgu}};
  assign {>>{m_data_flat_cgu}} = m_data_cgu;
  
  logic s_keep_cg [COPIES-1:0][GROUPS-1:0];
  logic m_keep_cg [COPIES-1:0][GROUPS-1:0];
  assign s_keep_cg = {>>{s_keep_flat_cg}};
  assign {>>{m_keep_flat_cg}} = m_keep_cg;

  logic       m_valid_cg [COPIES-1:0][GROUPS-1:0];
  logic [1:0] m_user_cg  [COPIES-1:0][GROUPS-1:0];
  assign m_valid = m_valid_cg[0][0];
  assign m_user  = m_user_cg [0][0];

  generate
    for(genvar c=0; c<COPIES; c=c+1) begin: c
      for(genvar g=0; g<GROUPS; g=g+1) begin: g
        lrelu_core #(
          .WORD_WIDTH_IN  (WORD_WIDTH_IN ),
          .WORD_WIDTH_OUT (WORD_WIDTH_OUT),
          .TUSER_WIDTH    (TUSER_WIDTH   ),
          .UNITS   (UNITS  ),
          .GROUPS  (GROUPS ),
          .COPIES  (COPIES ),
          .MEMBERS (MEMBERS),
          .ACTIVE  (g==0 && c==0)
        )core(
          .clk     (clk    ),
          .clken   (clken  ),
          .resetn  (resetn ),
          .s_valid (s_valid),
          .s_user  (s_user ),
          .s_keep  (s_keep_cg [c][g]),
          .m_valid (m_valid_cg[c][g]),
          .m_user  (m_user_cg [c][g]),
          .m_keep  (m_keep_cg [c][g]),
          .s_data_u(s_data_cgu[c][g]),
          .m_data_u(m_data_cgu[c][g])
        );
      end
    end      
  endgenerate
endmodule