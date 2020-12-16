module lrelu_engine #(
  WORD_WIDTH_IN  = 32,
  WORD_WIDTH_OUT = 8 ,
  TUSER_WIDTH    = 8 ,
  WORD_WIDTH_CONFIG = 8 ,

  UNITS   = 8,
  GROUPS  = 2,
  COPIES  = 2,
  MEMBERS = 2,

  LATENCY_FIXED_2_FLOAT =  6,
  LATENCY_FLOAT_32      = 16,

  INDEX_IS_3X3     = 0
  INDEX_IS_RELU    = 1,
  INDEX_IS_MAX     = 2,
  INDEX_IS_NOT_MAX = 3,
  INDEX_IS_TOP     = 4,
  INDEX_IS_BOTTOM  = 5,
  INDEX_IS_LEFT    = 6,
  INDEX_IS_RIGHT   = 7
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
  m_data_flat_cgu,

  resetn_config  ,
  s_valid_config ,
  s_data_conv_out
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

  /*
    CONFIG HANDLING
  */
  input  logic resetn_config;
  input  logic s_valid_config ;
  input  logic [MEMBERS * COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_data_conv_out;

  logic [WORD_WIDTH_IN    -1:0] s_data_conv_out_mcgu [MEMBERS-1:0][COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [WORD_WIDTH_CONFIG-1:0] s_data_config_cgm    [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0];
  assign conv_out_mcgu = {>>{s_data_conv_out}};
  generate
    for (genvar m = 0; m < MEMBERS; m++)
      for (genvar c = 0; c < COPIES; c++)
        for (genvar g = 0; g < GROUPS; g++)
          for (genvar u = 0; u < UNITS; u++)
            s_data_config_cgm[m][c][g][m] = WORD_WIDTH_CONFIG'(s_data_conv_out_mcgu[m][c][g][0]);
  endgenerate

  /*
    Reshaping data
  */

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

  localparam BRAM_R_WIDTH = 16;
  localparam BRAM_R_DEPTH = MEMBERS * 3;
  localparam BRAM_W_WIDTH = MEMBERS * WORD_WIDTH_CONFIG;
  localparam BRAM_W_DEPTH = R_DEPTH * R_WIDTH / W_WIDTH;
  localparam BRAM_LATENCY = 2;
  localparam BRAM_W_DEPTH_3X3_1 = (MEMBERS * R_WIDTH     / W_WIDTH) -1;
  localparam BRAM_W_DEPTH_3X3_1 = (MEMBERS * R_WIDTH * 3 / W_WIDTH) -1;

  generate
    for(genvar c=0; c<COPIES; c=c+1) begin: c
      for(genvar g=0; g<GROUPS; g=g+1) begin: g
        lrelu_core #(
          .ACTIVE  (g==0 && c==0),
          .WORD_WIDTH_IN  (WORD_WIDTH_IN ),
          .WORD_WIDTH_OUT (WORD_WIDTH_OUT),
          .TUSER_WIDTH    (TUSER_WIDTH   ),
          .UNITS   (UNITS  ),
          .GROUPS  (GROUPS ),
          .COPIES  (COPIES ),
          .MEMBERS (MEMBERS),
          .LATENCY_FIXED_2_FLOAT (LATENCY_FIXED_2_FLOAT),
          .LATENCY_FLOAT_32      (LATENCY_FLOAT_32     ),
          .INDEX_IS_3X3     (INDEX_IS_3X3    )
          .INDEX_IS_RELU    (INDEX_IS_RELU   ),
          .INDEX_IS_MAX     (INDEX_IS_MAX    ),
          .INDEX_IS_NOT_MAX (INDEX_IS_NOT_MAX),
          .INDEX_IS_TOP     (INDEX_IS_TOP    ),
          .INDEX_IS_BOTTOM  (INDEX_IS_BOTTOM ),
          .INDEX_IS_LEFT    (INDEX_IS_LEFT   ),
          .INDEX_IS_RIGHT   (INDEX_IS_RIGHT  ),
          .BRAM_R_WIDTH (BRAM_R_WIDTH),
          .BRAM_R_DEPTH (BRAM_R_DEPTH),
          .BRAM_W_WIDTH (BRAM_W_WIDTH),
          .BRAM_W_DEPTH (BRAM_W_DEPTH),
          .BRAM_LATENCY (BRAM_LATENCY)
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
          .m_data_u(m_data_cgu[c][g]),

          .resetn_config   (resetn_config          ),
          .s_valid_config  (s_valid_config         ),
          .s_data_config_m (s_data_config_cgm[c][g])
        );
      end
    end      
  endgenerate
endmodule