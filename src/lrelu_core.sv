
function logic [31:0] float_16_to_32 (logic [15:0] float_16);
  logic [31:0] float_32;
  
  logic sign;
  logic [4 :0] exp_16;
  logic [0 :9] fra_16;

  logic [7: 0] exp_32;
  logic [0:22] fra_32;

  assign {sign, exp_16, fra_16} = float_16;
  assign fra_32 = fra_16;
  assign exp_32 = exp_16 + 7'd112; //- 15 + 127;
  assign float_32 = {sign, exp_32, fra_32};
  return float_32;
endfunction

function logic [15:0] float_32_to_16 (logic [31:0] float_32);
  logic [31:0] float_32;
  
  logic sign;
  logic [4 :0] exp_16;
  logic [0 :9] fra_16;

  logic [7: 0] exp_32;
  logic [0:22] fra_32;

  assign {sign, exp_32, fra_32} = float_32;
  assign fra_16 = fra_32;
  assign exp_16 = exp_32 - 7'd112; //- 15 + 127;
  assign float_16 = {sign, exp_16, fra_16};
  return float_16;
endfunction

module lrelu_core #(
  ACTIVE = 0,

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
  INDEX_IS_RIGHT   = 7,

  BRAM_R_WIDTH = 16,
  BRAM_W_WIDTH = 64,
  BRAM_LATENCY =  2
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
  m_data_u,
  bram_r_addr_max_1,
  resetn_config,
  s_data_config_m,
  s_valid_config,
  is_3x3_config
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

  input  logic resetn_config;
  input  logic [WORD_WIDTH_CONFIG-1:0] s_data_config_m [MEMBERS-1:0];
  input  logic s_valid_config;

  logic [WORD_WIDTH_CONFIG * MEMBERS -1:0] s_data_config_m_flat;
  assign {>>{s_data_config_m_flat}} = s_data_config_m;

  generate
    for (genvar u=0; u<UNITS; u++) begin
      assign m_data_u[u] = WORD_WIDTH_OUT'(s_data_u[u]);
    end
  endgenerate
  
  assign m_user  = 2'(s_user);
  assign m_valid = s_valid;
  assign m_keep  = s_keep;

  /*
    STATE MACHINE W_SEL

    0 : None
    1 : D register
    2 : A BRAM (depth = 3m or 1m)
    3 : B's middle BRAM (0,0) (depth = 3m or 1m)
 4-11 : 8 BRAMs of B's edges  (depth = 1m)
        == 3 + mtb*3 + clr
        ml,mr, tc,tl,tr, bc,bl,br

    * BRAMs write when (sel == their index) & valid
    * Delayed by Fix2float-1 latency to match the config latency
  */

  localparam BRAM_R_DEPTH_3M = MEMBERS * 3;
  localparam BRAM_R_DEPTH_1M = MEMBERS;
  localparam BRAM_W_DEPTH_3M = R_DEPTH * R_WIDTH / W_WIDTH;
  localparam BRAM_R_DEPTH_BITS = $clog2(BRAM_R_DEPTH_3M);

  logic [BRAM_R_DEPTH_BITS-1:0] bram_r_depth_1 = is_3x3_config ? BRAM_R_DEPTH_1M-1 : BRAM_R_DEPTH_3M-1;

  logic [3:0] w_sel_bram_next, w_sel_bram;
  register #(
    .WORD_WIDTH   (4), 
    .RESET_VALUE  (0)
  ) W_SEL_BRAM (
    .clock        (clk),
    .clock_enable (clken && s_valid_config),
    .resetn       (resetn_config),
    .data_in      (w_sel_bram_next),
    .data_out     (w_sel_bram)
  );
  logic [3:0] bram_addr_next, bram_addr;
  register #(
    .WORD_WIDTH   (R_DEPTH), 
    .RESET_VALUE  (0)
  ) BRAM_W_ADDR (
    .clock        (clk),
    .clock_enable (clken && s_valid_config),
    .resetn       (resetn_config),
    .data_in      (bram_addr_next),
    .data_out     (bram_addr)
  );

  always_comb begin
    unique case (w_sel_bram)
      0       : begin // None
                  bram_addr_next  = 0;
                  w_sel_bram_next = 1;
                end
      1       : begin // D Register
                  bram_addr_next  = 0;
                  w_sel_bram_next = 2;
                end
      2       : begin // A RAM
                  if (bram_addr == bram_r_depth_1) begin
                    bram_addr_next  = 0;
                    w_sel_bram_next = 3;
                  end
                  else begin
                    bram_addr_next  = bram_addr + 1;
                    w_sel_bram_next = w_sel_bram;
                  end
                end
      3       : begin // B RAM center (0,0)
                  if (bram_addr == bram_r_depth_1) begin
                    bram_addr_next  = 0;
                    if (is_3x3_config) w_sel_bram_next = 4;
                    else               w_sel_bram_next = 0;
                  end
                  else begin
                    bram_addr_next  = bram_addr + 1;
                    w_sel_bram_next = w_sel_bram;
                  end
                end
      default : begin // Other 8 of B ram
                  if (bram_addr == bram_r_depth_1) begin
                    bram_addr_next  = 0;
                    if (w_sel_bram == 11) w_sel_bram_next = 0;
                    else                  w_sel_bram_next = w_sel_bram + 1;
                  end
                  else begin
                    bram_addr_next  = bram_addr + 1;
                    w_sel_bram_next = w_sel_bram;
                  end
                end
    endcase
  end

  /*
    FIXED TO FLOAT
  */
  logic [31:0]            m_data_float32_u  [UNITS-1:0];
  logic                   m_valid_float32   [UNITS-1:0];
  logic [TUSER_WIDTH-1:0] m_user_float32    [UNITS-1:0];
  generate
    for (genvar u=0; u < UNITS; u++) begin

      if (u==0) fixed_to_float_active FIX2FLOAT (
                  .aclk                 (clk  ),                                  
                  .aclken               (clken),                              
                  .aresetn              (resetn ),                           
                  .s_axis_a_tvalid      (s_valid),            
                  .s_axis_a_tdata       (s_data_u[u]),              
                  .s_axis_a_tuser       (s_user ),              
                  .m_axis_result_tvalid (m_valid_float32),  
                  .m_axis_result_tdata  (m_data_float32_u  [u]),    
                  .m_axis_result_tuser  (m_user_float32)    
                );
      else      fixed_to_float        FIX2FLOAT (
                  .aclk                 (clk),                                  
                  .aclken               (clken),                              
                  .aresetn              (resetn),                           
                  .s_axis_a_tvalid      (s_valid),            
                  .s_axis_a_tdata       (s_data_u[u]), 
                  .m_axis_result_tdata  (m_data_float32_u[u])  
                );
    end
  endgenerate


  logic [WORD_WIDTH_CONFIG * MEMBERS -1:0] config_flat_1;
  n_delay #(
    .N          (LATENCY_FIXED_2_FLOAT),
    .DATA_WIDTH (WORD_WIDTH_CONFIG * MEMBERS)
  ) CONFIG_DATA_FLAT_1 (
    .clk      (clk),
    .resetn   (resetn),
    .clken    (clken),
    .data_in  (s_data_config_flat),
    .data_out (config_flat_1)
  );
  logic valid_config_1;
  n_delay #(
    .N          (LATENCY_FIXED_2_FLOAT),
    .DATA_WIDTH (1)
  ) CONFIG_VALID_1 (
    .clk      (clk),
    .resetn   (resetn),
    .clken    (clken),
    .data_in  (s_valid_config),
    .data_out (valid_config_1)
  );
  logic resetn_config_1;
  n_delay #(
    .N          (LATENCY_FIXED_2_FLOAT),
    .DATA_WIDTH (1)
  ) CONFIG_RESETN_1 (
    .clk      (clk),
    .resetn   (resetn),
    .clken    (clken),
    .data_in  (resetn_config),
    .data_out (resetn_config_1)
  );
  logic is_3x3_config_1;
  n_delay #(
    .N          (LATENCY_FIXED_2_FLOAT),
    .DATA_WIDTH (1)
  ) CONFIG_3x3_1 (
    .clk      (clk),
    .resetn   (resetn),
    .clken    (clken),
    .data_in  (is_3x3_config),
    .data_out (is_3x3_config_1)
  );
  logic bram_r_addr_max_1_1;
  n_delay #(
    .N          (LATENCY_FIXED_2_FLOAT),
    .DATA_WIDTH ($clog2(BRAM_R_DEPTH))
  ) R_ADDR_MAX_1 (
    .clk      (clk),
    .resetn   (resetn),
    .clken    (clken),
    .data_in  (bram_r_addr_max_1),
    .data_out (bram_r_addr_max_1_1)
  );
  logic w_sel_bram_1;
  n_delay #(
    .N          (LATENCY_FIXED_2_FLOAT-1), // (-1) since already reg'd once
    .DATA_WIDTH (4)
  ) W_SEL_BRAM_1 (
    .clk      (clk),
    .resetn   (resetn),
    .clken    (clken),
    .data_in  (w_sel_bram),
    .data_out (w_sel_bram_1)
  );

  logic [BRAM_R_WIDTH-1:0] a_val;
  logic [31:0] a_val_f32;
  assign a_val_f32 = float_16_to_32(a_val);

  always_valid_cyclic_bram #(
    .W_DEPTH (BRAM_W_DEPTH_3M), 
    .W_WIDTH (BRAM_W_WIDTH),
    .R_WIDTH (BRAM_R_WIDTH),
    .LATENCY (BRAM_LATENCY),
    .IP_TYPE (0)
  ) BRAM_A (
    .clk          (clk),
    .clken        (clken),
    .resetn       (resetn_config_1),
    .s_valid_ready(valid_config_1 && (w_sel_bram_1 == 2)),
    .s_data       (config_flat_1),
    .m_data       (a_val),
    .m_ready      (m_valid_float32_u),
    .r_addr_max_1 (bram_r_addr_max_1_1),
    .w_addr_max_1 (is_3x3_config_1 ? BRAM_W_DEPTH_3X3_1 : BRAM_W_DEPTH_1X1_1)
  );

  logic [BRAM_R_WIDTH-1:0] b_clr_mtb     [2:0][2:0];
  logic [          31  :0] b_clr_mtb_f32 [2:0][2:0];
  generate
    for (genvar mtb=0; mtb < 3; mtb ++) begin: mtb
      for (genvar clr=0; clr < 3; clr ++) begin: clr

        if (mtb==0 && clr ==0) begin // Center BRAM

          localparam BRAM_R_DEPTH = MEMBERS * 3;
          localparam BRAM_W_DEPTH = R_DEPTH * R_WIDTH / W_WIDTH;

          always_valid_cyclic_bram #(
            .W_DEPTH (BRAM_W_DEPTH), 
            .W_WIDTH (BRAM_W_WIDTH),
            .R_WIDTH (BRAM_R_WIDTH),
            .LATENCY (BRAM_LATENCY),
            .IP_TYPE (IS_EDGE     )
          ) BRAM_B (
            .clk          (clk),
            .clken        (clken),
            .resetn       (resetn_config_1),
            .s_valid_ready(valid_config_1 && (w_sel_bram_1 == 3)),
            .s_data       (config_flat_1),
            .m_data       (b_clr_mtb[clr][mtb]),
            .m_ready      (m_valid_float32_u),
            .r_addr_max_1 (bram_r_addr_max_1_1),
            .w_addr_max_1 (is_3x3_config_1 ? BRAM_W_DEPTH_3X3_1 : BRAM_W_DEPTH_1X1_1)
          );
        end
        else begin // Edge BRAM

          localparam BRAM_R_DEPTH = MEMBERS;
          localparam BRAM_W_DEPTH = R_DEPTH * R_WIDTH / W_WIDTH;

          always_valid_cyclic_bram #(
            .W_DEPTH (BRAM_W_DEPTH), 
            .W_WIDTH (BRAM_W_WIDTH),
            .R_WIDTH (BRAM_R_WIDTH),
            .LATENCY (BRAM_LATENCY),
            .IP_TYPE (IS_EDGE     )
          ) BRAM_B (
            .clk          (clk),
            .clken        (clken),
            .resetn       (resetn_config_1),
            .s_valid_ready(valid_config_1 && (w_sel_bram_1 == 3 + mtb*3 + clr)),
            .s_data       (config_flat_1),
            .m_data       (b_clr_mtb[clr][mtb]),
            .m_ready      (m_valid_float32_u),
            .r_addr_max_1 (BRAM_W_DEPTH_3X3_1),
            .w_addr_max_1 (BRAM_W_DEPTH_3X3_1)
          );
        end
        assign b_clr_mtb_f32[clr][mtb] = float_16_to_32(b_clr_mtb[clr][mtb]);
      end
    end
  endgenerate

  logic [BRAM_R_WIDTH-1:0] b_mid_f32, b_top_f32, b_bot_f32;
  always_comb begin
    unique case({m_user_float32_u[INDEX_IS_LEFT], m_user_float32_u[INDEX_IS_RIGHT]})
      'b00: begin
              b_mid_f32 = b_clr_mtb_f32[0][0];
              b_top_f32 = b_clr_mtb_f32[0][1];
              b_bot_f32 = b_clr_mtb_f32[0][2];
            end
      'b01: begin
              b_mid_f32 = b_clr_mtb_f32[1][0];
              b_top_f32 = b_clr_mtb_f32[1][1];
              b_bot_f32 = b_clr_mtb_f32[1][2];
            end
      'b10: begin
              b_mid_f32 = b_clr_mtb_f32[2][0];
              b_top_f32 = b_clr_mtb_f32[2][1];
              b_bot_f32 = b_clr_mtb_f32[2][2];
            end
    endcase
  end

  logic [31:0]            m_data_fma_1_u  [UNITS-1:0];
  logic                   m_valid_fma_1   [UNITS-1:0];
  logic [TUSER_WIDTH-1:0] m_user_fma_1    [UNITS-1:0];
  generate
    for (genvar u=0; u<UNITS; u++) begin
      
      logic  is_top, is_bot;
      assign is_top = u == 0       && m_valid_float32_u[u][INDEX_IS_3X3] && m_valid_float32_u[u][INDEX_IS_TOP];
      assign is_bot = u == UNITS-1 && m_valid_float32_u[u][INDEX_IS_3X3] && m_valid_float32_u[u][INDEX_IS_TOP];

      logic [BRAM_R_WIDTH-1:0] b_val_f32;
      assign b_val_f32 = is_top ? b_top_f32 : 
                     is_bot ? b_bot_f32 : b_mid;


      if (u==0) float_32_ma_active FMA_1 (
                  .aclk                 (clk),                                  
                  .aclken               (clken),                              
                  .aresetn              (resetn),                            
                  .s_axis_a_tvalid      (m_data_float32),            
                  .s_axis_a_tdata       (m_valid_float32_u [u]),              
                  .s_axis_a_tuser       (m_user_float32 ),              
                  .s_axis_b_tvalid      (1),            
                  .s_axis_b_tdata       (b_val_f32),              
                  .s_axis_c_tvalid      (1),           
                  .s_axis_c_tdata       (a_val_f32),              
                  .m_axis_result_tvalid (m_valid_fma_1),  
                  .m_axis_result_tdata  (m_data_fma_1_u [u]),    
                  .m_axis_result_tuser  (m_user_fma_1)    
                );
      else      float_32_ma_active FMA_1 (
                  .aclk                 (clk),                                  
                  .aclken               (clken),                              
                  .aresetn              (resetn),                            
                  .s_axis_a_tvalid      (m_data_float32),            
                  .s_axis_a_tdata       (m_valid_float32_u [u]),              
                  .s_axis_a_tuser       (m_user_float32 ),              
                  .s_axis_b_tvalid      (1),            
                  .s_axis_b_tdata       (b_val_f32),              
                  .s_axis_c_tvalid      (1),           
                  .s_axis_c_tdata       (a_val_f32),              
                  .m_axis_result_tdata  (m_data_fma_1_u [u])
                );
    end
  endgenerate

  logic [WORD_WIDTH_CONFIG * MEMBERS -1:0] config_flat_2;
  n_delay #(
    .N          (LATENCY_FLOAT_32),
    .DATA_WIDTH (WORD_WIDTH_CONFIG * MEMBERS)
  ) CONFIG_DATA_FLAT_2 (
    .clk      (clk),
    .resetn   (resetn),
    .clken    (clken),
    .data_in  (config_flat_1),
    .data_out (config_flat_2)
  );
  logic valid_config_2;
  n_delay #(
    .N          (LATENCY_FLOAT_32),
    .DATA_WIDTH (1)
  ) CONFIG_VALID_2 (
    .clk      (clk),
    .resetn   (resetn),
    .clken    (clken),
    .data_in  (valid_config_1),
    .data_out (valid_config_2)
  );
  logic resetn_config_2;
  n_delay #(
    .N          (LATENCY_FLOAT_32),
    .DATA_WIDTH (1)
  ) CONFIG_RESETN_2 (
    .clk      (clk),
    .resetn   (resetn),
    .clken    (clken),
    .data_in  (resetn_config_1),
    .data_out (resetn_config_2)
  );
  logic w_sel_bram_2;
  n_delay #(
    .N          (LATENCY_FLOAT_32),
    .DATA_WIDTH (1)
  ) W_SEL_BRAM_2 (
    .clk      (clk),
    .resetn   (resetn),
    .clken    (clken),
    .data_in  (w_sel_bram_1==1),
    .data_out (w_sel_bram_2   )
  );

  logic [15:0] d_val;
  register #(
    .WORD_WIDTH   (BRAM_R_WIDTH), 
    .RESET_VALUE  (0)
  ) REG_D (
    .clock        (clk),
    .clock_enable (clken && valid_config_2 && (w_sel_bram_2==1)),
    .resetn       (resetn_config_2),
    .data_in      (16'(config_flat_2)),
    .data_out     (d_val)
  );

  logic [16:0]            m_data_fma_1_u_f32 [UNITS-1:0];
  logic [16:0]            m_data_fma_2_u     [UNITS-1:0];
  logic [16:0]            c_val_u            [UNITS-1:0];
  logic                   m_valid_fma_2;
  logic [TUSER_WIDTH-1:0] m_user_fma_2 ;
  generate
    for (genvar u=0; u<UNITS; u++) begin
      
      assign m_data_fma_1_u_f32[u] = float_32_to_16(m_data_fma_1_u[u]);
      assign c_val_u [u] = (m_user_fma_1[INDEX_IS_RELU] && m_data_fma_1_u[u][0]) ? 16'd11878 : 16'd15360 ; // 0.1 or 1

      if (u==0) begin
        float_16_ma_active FMA_2 (
          .aclk                 (clk),                                  
          .aclken               (clken),                              
          .aresetn              (resetn),                            
          .s_axis_a_tvalid      (m_valid_fma_1),            
          .s_axis_a_tdata       (m_data_fma_1_u_f32[u]),              
          .s_axis_a_tuser       (m_user_fma_1),              
          .s_axis_b_tvalid      (1),            
          .s_axis_b_tdata       (c_val),              
          .s_axis_c_tvalid      (1),           
          .s_axis_c_tdata       (d_val),              
          .m_axis_result_tvalid (m_valid_fma_2),  
          .m_axis_result_tdata  (m_data_fma_2_u [u]),    
          .m_axis_result_tuser  (m_user_fma_2)    
        );
        float_to_fixed_active FLOAT2FIX (
          .aclk                 (clk),                                  
          .aclken               (clken),                              
          .aresetn              (resetn),                            
          .s_axis_a_tvalid      (m_valid_fma_2_u),            
          .s_axis_a_tdata       (m_data_fma_1_u_f32[u]),              
          .s_axis_a_tuser       ({m_user_fma_2_u[INDEX_IS_MAX], m_user_fma_2_u[INDEX_IS_NOT_MAX]}),
          .m_axis_result_tvalid (m_valid), 
          .m_axis_result_tdata  (m_data[u]),    
          .m_axis_result_tuser  (m_user)    
        );
      else begin
        float_16_ma FMA_2 (
          .aclk                 (clk),                                  
          .aclken               (clken),                              
          .aresetn              (resetn),                            
          .s_axis_a_tvalid      (m_valid_fma_1),            
          .s_axis_a_tdata       (m_data_fma_1_u_f32[u]),              
          .s_axis_a_tuser       (m_user_fma_1),              
          .s_axis_b_tvalid      (1),            
          .s_axis_b_tdata       (c_val),              
          .s_axis_c_tvalid      (1),           
          .s_axis_c_tdata       (d_val),              
          .m_axis_result_tdata  (m_data_fma_2_u [u])
        );
        float_to_fixed FLOAT2FIX (
          .aclk                 (clk),                                  
          .aclken               (clken),                              
          .aresetn              (resetn),                            
          .s_axis_a_tvalid      (m_valid_fma_2),            
          .s_axis_a_tdata       (m_data_fma_2_u [u]),              
          .s_axis_a_tuser       ({m_user_fma_2[INDEX_IS_MAX], m_user_fma_2[INDEX_IS_NOT_MAX]}),
          .m_axis_result_tdata  (m_data[u])
        );
      end
    end
  endgenerate

endmodule