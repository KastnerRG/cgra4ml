module lrelu_core #(
  WORD_WIDTH_IN  = 32,
  WORD_WIDTH_OUT = 8 ,
  TUSER_WIDTH    = 4 ,
  UNITS   = 8,
  GROUPS  = 2,
  COPIES  = 2,
  MEMBERS = 2,
  ACTIVE  = 0
)(
  clk     ,
  clken   ,
  resetn  ,
  s_valid ,
  s_user  ,
  s_keep  ,
  m_valid ,
  m_user  ,
  m_keep  ,
  s_data_u,
  m_data_u
);

  input  logic clk     ;
  input  logic clken   ;
  input  logic resetn  ;
  input  logic s_valid ;
  output logic m_valid ;
  input  logic [WORD_WIDTH_IN -1:0] s_data_u [UNITS-1:0];
  output logic [WORD_WIDTH_OUT-1:0] m_data_u [UNITS-1:0];
  input  logic [TUSER_WIDTH-1:0] s_user  ;
  output logic [1:0] m_user  ;
  input  logic s_keep  ;
  output logic m_keep  ;

  generate
    for (genvar u=0; u<UNITS; u++) begin
      assign m_data_u[u] = WORD_WIDTH_OUT'(s_data_u[u]);
    end
  endgenerate
  
  assign m_user  = 2'(s_user);
  assign m_valid = s_valid;
  assign m_keep  = s_keep;

endmodule