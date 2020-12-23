module lrelu_engine #(
  WORD_WIDTH_IN  = 32,
  WORD_WIDTH_OUT = 8 ,
  WORD_WIDTH_CONFIG = 8 ,

  UNITS   = 8,
  GROUPS  = 2,
  COPIES  = 2,
  MEMBERS = 2,

  ALPHA = 16'd11878,

  LATENCY_FIXED_2_FLOAT =  6,
  LATENCY_FLOAT_32      = 16,
  BRAM_LATENCY          =  2,

  BITS_CONV_CORE       = $clog2(GROUPS * COPIES * MEMBERS),
  I_IS_3X3             = BITS_CONV_CORE + 0,  
  I_MAXPOOL_IS_MAX     = BITS_CONV_CORE + 1,
  I_MAXPOOL_IS_NOT_MAX = BITS_CONV_CORE + 2,
  I_LRELU_IS_LRELU     = BITS_CONV_CORE + 3,
  I_LRELU_IS_TOP       = BITS_CONV_CORE + 4,
  I_LRELU_IS_BOTTOM    = BITS_CONV_CORE + 5,
  I_LRELU_IS_LEFT      = BITS_CONV_CORE + 6,
  I_LRELU_IS_RIGHT     = BITS_CONV_CORE + 7,

  TUSER_WIDTH_LRELU       = BITS_CONV_CORE + 8,
  TUSER_WIDTH_LRELU_FMA_1 = BITS_CONV_CORE + 4,
  TUSER_WIDTH_MAXPOOL     = BITS_CONV_CORE + 3
)(
  clk     ,
  clken   ,
  resetn  ,
  s_valid ,
  s_user  ,
  m_valid ,
  m_user  ,
  s_data_flat_cgu,
  m_data_flat_cgu,

  resetn_config  ,
  s_valid_config ,
  is_3x3_config  ,
  s_data_conv_out
);

  input  logic clk     ;
  input  logic clken   ;
  input  logic resetn  ;
  input  logic s_valid ;
  output logic m_valid ;
  input  logic [COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_data_flat_cgu;
  output logic [COPIES * GROUPS * UNITS * WORD_WIDTH_OUT-1:0] m_data_flat_cgu;
  input  logic [TUSER_WIDTH_LRELU  -1:0] s_user  ;
  output logic [TUSER_WIDTH_MAXPOOL-1:0] m_user  ;

  /*
    CONFIG HANDLING

    s_axis_tdata
    s_data_conv_out
    s_data_conv_out_mcgu
    s_data_config_cgm
    s_data_config_flat_cg
      config_s_data_cgv_sr
  */
  input  logic resetn_config, s_valid_config, is_3x3_config;
  input  logic [MEMBERS * COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_data_conv_out;

  logic [WORD_WIDTH_IN    -1:0] s_data_conv_out_mcgu [MEMBERS-1:0][COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [WORD_WIDTH_CONFIG-1:0] s_data_config_cgm    [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0];
  logic [MEMBERS * WORD_WIDTH_CONFIG-1:0] s_data_config_flat_cg [COPIES-1:0][GROUPS-1:0];

  assign s_data_conv_out_mcgu = {>>{s_data_conv_out}};
  generate
    for (genvar c = 0; c < COPIES; c++)
      for (genvar g = 0; g < GROUPS; g++) begin
        for (genvar m = 0; m < MEMBERS; m++)
            assign s_data_config_cgm[c][g][m] = WORD_WIDTH_CONFIG'(s_data_conv_out_mcgu[m][c][g][0]);

        assign {>>{s_data_config_flat_cg [c][g]}} = s_data_config_cgm[c][g];
      end
  endgenerate

  /*
    Reshaping data
  */

  logic [WORD_WIDTH_IN -1:0] s_data_cgu [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [WORD_WIDTH_OUT-1:0] m_data_cgu [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  assign s_data_cgu = {>>{s_data_flat_cgu}};
  assign {>>{m_data_flat_cgu}} = m_data_cgu;

  localparam BRAM_R_WIDTH = 16;
  localparam BRAM_W_WIDTH = MEMBERS * WORD_WIDTH_CONFIG;

  localparam BRAM_R_DEPTH_3X3 = MEMBERS;
  localparam BRAM_W_DEPTH_3X3 = BRAM_R_DEPTH_3X3 * BRAM_R_WIDTH / BRAM_W_WIDTH;

  localparam BRAM_R_DEPTH_1X1 = MEMBERS * 3; ;
  localparam BRAM_W_DEPTH_1X1 = BRAM_R_DEPTH_1X1 * BRAM_R_WIDTH / BRAM_W_WIDTH;

  localparam BITS_BRAM_R_DEPTH = $clog2(BRAM_R_DEPTH_1X1);
  localparam BITS_BRAM_W_DEPTH = $clog2(BRAM_W_DEPTH_1X1);

  /*
    CONTROL LOGIC
  */

  /*
    STATE MACHINE W_SEL

        0 : None
        1 : D register
        2 : A BRAM (depth = 3m or 1m)
        3 : B's middle BRAM (0,0) (depth = 3m or 1m)
     4-11 : 8 BRAMs of B's edges  (depth = 1m)
              == 3 + clr*3 + mtb
              ct,cb, lm,lt,lb, rm,rt,rb

    * BRAMs write when (sel == their index) & valid
    * Delayed by Fix2float-1 latency to match the config latency
  */

  logic [3:0] w_sel_bram_next, w_sel_bram, w_sel_bram_1;
  register #(
    .WORD_WIDTH   (4), 
    .RESET_VALUE  (1)
  ) W_SEL_BRAM (
    .clock        (clk),
    .clock_enable (clken && s_valid_config),
    .resetn       (resetn_config),
    .data_in      (w_sel_bram_next),
    .data_out     (w_sel_bram)
  );

  logic [BITS_BRAM_W_DEPTH-1:0] bram_w_depth_1, bram_addr_next, bram_addr;
  assign bram_w_depth_1 = is_3x3_config ? BRAM_W_DEPTH_3X3-1 : BRAM_W_DEPTH_1X1-1;
  register #(
    .WORD_WIDTH   (BITS_BRAM_W_DEPTH), 
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
                  if (bram_addr == bram_w_depth_1) begin
                    bram_addr_next  = 0;
                    w_sel_bram_next = 3;
                  end
                  else begin
                    bram_addr_next  = bram_addr + 1;
                    w_sel_bram_next = w_sel_bram;
                  end
                end
      3       : begin // B RAM center (0,0)
                  if (bram_addr == bram_w_depth_1) begin
                    bram_addr_next  = 0;
                    if (is_3x3_config) w_sel_bram_next = 4;
                    else               w_sel_bram_next = 1;
                  end
                  else begin
                    bram_addr_next  = bram_addr + 1;
                    w_sel_bram_next = w_sel_bram;
                  end
                end
      default : begin // Other 8 of B ram
                  if (bram_addr == bram_w_depth_1) begin
                    bram_addr_next  = 0;
                    if (w_sel_bram == 11) w_sel_bram_next = 1;
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
    CONTROL DELAYS
  */

  n_delay #(
    .N          (LATENCY_FIXED_2_FLOAT),
    .DATA_WIDTH (4)
  ) W_SEL_BRAM_1 (
    .clk      (clk),
    .resetn   (resetn),
    .clken    (clken),
    .data_in  (w_sel_bram),
    .data_out (w_sel_bram_1)
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

  /*
    INTERMEDIATE ACTIVE WIRES
  */

  logic m_valid_float32, m_valid_fma_1, m_valid_fma_2;
  logic [TUSER_WIDTH_LRELU      -1:0] m_user_float32;
  logic [TUSER_WIDTH_LRELU_FMA_1-1:0] s_user_fma_1, m_user_fma_1;
  logic [TUSER_WIDTH_MAXPOOL    -1:0] s_user_fma_2, m_user_fma_2;

  assign s_user_fma_1 = TUSER_WIDTH_LRELU_FMA_1'(m_user_float32);
  assign s_user_fma_2 = TUSER_WIDTH_MAXPOOL'(m_user_fma_1);
  
  logic [BITS_BRAM_R_DEPTH-1:0] b_r_addr_max_1; 
  logic [BITS_BRAM_W_DEPTH-1:0] b_w_addr_max_1;
  assign b_w_addr_max_1 = is_3x3_config_1          ? BRAM_W_DEPTH_3X3-1 : BRAM_W_DEPTH_1X1-1;
  assign b_r_addr_max_1 = m_user_float32[I_IS_3X3] ? BRAM_R_DEPTH_3X3-1 : BRAM_R_DEPTH_1X1-1;

  /*
    Declare multidimensional wires
  */
  localparam VALS_CONFIG = MEMBERS * WORD_WIDTH_CONFIG / 16;

  logic [15:0] config_s_data_f16_cgv[COPIES-1:0][GROUPS-1:0][VALS_CONFIG-1:0];
  logic [15:0] config_fma1_f16_cgv  [COPIES-1:0][GROUPS-1:0][VALS_CONFIG-1:0];
  logic [15:0] config_fma2_f16_cg   [COPIES-1:0][GROUPS-1:0];

  logic [WORD_WIDTH_CONFIG * MEMBERS-1:0] config_flat_1_cg [COPIES-1:0][GROUPS-1:0];
  logic [BRAM_R_WIDTH-1:0] a_val_cg     [COPIES-1:0][GROUPS-1:0];
  logic [31:0]             a_val_f32_cg [COPIES-1:0][GROUPS-1:0];
  logic                    b_ready_cg_clr_mtb[COPIES-1:0][GROUPS-1:0][2:0][2:0];
  logic [BRAM_R_WIDTH-1:0] b_cg_clr_mtb_f16  [COPIES-1:0][GROUPS-1:0][2:0][2:0];
  logic [31:0] b_mid_f32_cg [COPIES-1:0][GROUPS-1:0];
  logic [31:0] b_top_f32_cg [COPIES-1:0][GROUPS-1:0]; 
  logic [31:0] b_bot_f32_cg [COPIES-1:0][GROUPS-1:0];
  logic [15:0] d_val_cg     [COPIES-1:0][GROUPS-1:0];
  logic [BRAM_R_WIDTH -1:0] config_flat_2_cg [COPIES-1:0][GROUPS-1:0];


  localparam WIDTH_FIXED_2_FLOAT_S_DATA = (WORD_WIDTH_IN/8 + ((WORD_WIDTH_IN % 8) !=0))*8; // ceil(WORD_WIDTH_IN/8.0)*8
  logic signed [WIDTH_FIXED_2_FLOAT_S_DATA-1:0] s_data_fix2float_cgu [COPIES-1:0][GROUPS-1:0][UNITS-1:0];

  logic [31:0] m_data_float32_cgu   [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [31:0] m_data_fma_1_cgu     [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [15:0] m_data_fma_1_cgu_f16 [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [15:0] m_data_fma_2_cgu     [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [15:0] c_val_cgu            [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [31:0] b_val_f32_cgu        [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic is_top_cgu                  [COPIES-1:0][GROUPS-1:0][UNITS-1:0]; 
  logic is_bot_cgu                  [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic is_lrelu_cgu                [COPIES-1:0][GROUPS-1:0][UNITS-1:0];

  /*

  */

  logic [1:0] fma1_index_clr;
  logic ready_mtb [2:0];
  always_comb begin
    if (m_user_float32[I_IS_3X3]) begin
      if      (m_user_float32[I_LRELU_IS_LEFT ])  fma1_index_clr = 2'd1;
      else if (m_user_float32[I_LRELU_IS_RIGHT])  fma1_index_clr = 2'd2;
      else                                        fma1_index_clr = 2'd0;
    end
    else begin
      fma1_index_clr = 2'd0;
    end
  end


  generate
    for(genvar c=0; c<COPIES; c=c+1) begin: c
      for(genvar g=0; g<GROUPS; g=g+1) begin: g

        n_delay #(
          .N          (LATENCY_FIXED_2_FLOAT),
          .DATA_WIDTH (WORD_WIDTH_CONFIG * MEMBERS)
        ) CONFIG_DATA_FLAT_1 (
          .clk      (clk),
          .resetn   (resetn),
          .clken    (clken),
          .data_in  (s_data_config_flat_cg [c][g]),
          .data_out (config_flat_1_cg [c][g])
        );

        /*
          BRAM A
        */
        assign a_val_f32_cg [c][g] = float_16_to_32(a_val_cg [c][g]);

        always_valid_cyclic_bram #(
          .W_DEPTH (BRAM_W_DEPTH_1X1), 
          .W_WIDTH (BRAM_W_WIDTH),
          .R_WIDTH (BRAM_R_WIDTH),
          .LATENCY (BRAM_LATENCY),
          .IP_TYPE (1)
        ) BRAM_A (
          .clk          (clk),
          .clken        (clken),
          .resetn       (resetn_config_1),
          .s_valid_ready(valid_config_1 && (w_sel_bram_1 == 2)),
          .s_data       (config_flat_1_cg [c][g]),
          .m_data       (a_val_cg [c][g]),
          .m_ready      (m_valid_float32),
          .r_addr_max_1 (BRAM_R_DEPTH_3X3-1),
          .w_addr_max_1 (BRAM_W_DEPTH_3X3-1)
        );

        /*
          BRAM B
        */
        for (genvar mtb=0; mtb < 3; mtb ++) begin: mtb

          assign ready_mtb[mtb] = (mtb==0) || m_user_float32[I_IS_3X3] && (   (mtb==1 && m_user_float32[I_LRELU_IS_TOP]) 
                                                                           || (mtb==2 && m_user_float32[I_LRELU_IS_BOTTOM]));

          for (genvar clr=0; clr < 3; clr ++) begin: clr
          assign b_ready_cg_clr_mtb[c][g][clr][mtb] = m_valid_float32 && (fma1_index_clr == clr) && ready_mtb[mtb];

            if (mtb==0 && clr ==0) begin // Center BRAM

              always_valid_cyclic_bram #(
                .W_DEPTH (BRAM_W_DEPTH_1X1), 
                .W_WIDTH (BRAM_W_WIDTH),
                .R_WIDTH (BRAM_R_WIDTH),
                .LATENCY (BRAM_LATENCY),
                .IP_TYPE (0)
              ) BRAM_B (
                .clk          (clk),
                .clken        (clken),
                .resetn       (resetn_config_1),
                .s_valid_ready(valid_config_1 && (w_sel_bram_1 == 3)),
                .s_data       (config_flat_1_cg [c][g]),
                .m_data       (b_cg_clr_mtb_f16[c][g][clr][mtb]),
                .m_ready      (b_ready_cg_clr_mtb[c][g][clr][mtb]),
                .r_addr_max_1 (b_r_addr_max_1),
                .w_addr_max_1 (b_w_addr_max_1)
              );
            end
            else begin // Edge BRAM
              always_valid_cyclic_bram #(
                .W_DEPTH (BRAM_W_DEPTH_3X3), 
                .W_WIDTH (BRAM_W_WIDTH),
                .R_WIDTH (BRAM_R_WIDTH),
                .LATENCY (BRAM_LATENCY),
                .IP_TYPE (1)
              ) BRAM_B (
                .clk          (clk),
                .clken        (clken),
                .resetn       (resetn_config_1),
                .s_valid_ready(valid_config_1 && (w_sel_bram_1 == 3 + clr*3 + mtb)),
                .s_data       (config_flat_1_cg [c][g]),
                .m_data       (b_cg_clr_mtb_f16[c][g][clr][mtb]),
                .m_ready      (b_ready_cg_clr_mtb[c][g][clr][mtb]),
                .r_addr_max_1 (BRAM_R_DEPTH_3X3-1),
                .w_addr_max_1 (BRAM_W_DEPTH_3X3-1)
              );
            end
          end
        end

        always_comb begin
          b_mid_f32_cg[c][g] = float_16_to_32(b_cg_clr_mtb_f16[c][g][fma1_index_clr][0]);
          b_top_f32_cg[c][g] = float_16_to_32(b_cg_clr_mtb_f16[c][g][fma1_index_clr][1]);
          b_bot_f32_cg[c][g] = float_16_to_32(b_cg_clr_mtb_f16[c][g][fma1_index_clr][2]);
        end

        /*
          DELAY CONFIG FOR REGISTER
        */
        n_delay #(
          .N          (LATENCY_FLOAT_32),
          .DATA_WIDTH (BRAM_R_WIDTH)
        ) CONFIG_DATA_FLAT_2 (
          .clk      (clk),
          .resetn   (resetn),
          .clken    (clken),
          .data_in  (16'(config_flat_1_cg [c][g])),
          .data_out (config_flat_2_cg [c][g])
        );
        /*
          D Register
        */
        register #(
          .WORD_WIDTH   (BRAM_R_WIDTH), 
          .RESET_VALUE  (0)
        ) REG_D (
          .clock        (clk),
          .clock_enable (clken && valid_config_2 && (w_sel_bram_2==1)),
          .resetn       (resetn_config_2),
          .data_in      (config_flat_2_cg [c][g]),
          .data_out     (d_val_cg [c][g])
        );

        /*
          UNITS
        */

        for (genvar u=0; u < UNITS; u++) begin:u

          assign s_data_fix2float_cgu[c][g][u] = WIDTH_FIXED_2_FLOAT_S_DATA'(signed'(s_data_cgu[c][g][u]));
          
          assign is_top_cgu[c][g][u] = (u == 0      ) && m_user_float32[I_LRELU_IS_TOP];
          assign is_bot_cgu[c][g][u] = (u == UNITS-1) && m_user_float32[I_LRELU_IS_BOTTOM];

          always_comb begin
            if (m_user_float32[I_IS_3X3]) begin
              unique case ({is_top_cgu[c][g][u], is_bot_cgu[c][g][u]})
                2'b00 : b_val_f32_cgu[c][g][u] = b_mid_f32_cg[c][g];
                2'b10 : b_val_f32_cgu[c][g][u] = b_top_f32_cg[c][g];
                2'b01 : b_val_f32_cgu[c][g][u] = b_bot_f32_cg[c][g];
              endcase
            end
            else begin
              b_val_f32_cgu[c][g][u] = b_mid_f32_cg[c][g];
            end
          end

          assign m_data_fma_1_cgu_f16[c][g][u] = float_32_to_16(m_data_fma_1_cgu[c][g][u]);

          assign is_lrelu_cgu[c][g][u] = m_user_fma_1[I_LRELU_IS_LRELU] && m_data_fma_1_cgu[c][g][u][31];
          assign c_val_cgu   [c][g][u] = is_lrelu_cgu[c][g][u] ? ALPHA : 16'd15360 ; // 0.1 or 1

          if (c==0 && g==0 && u==0) begin
            fixed_to_float_active FIX2FLOAT (
              .aclk                 (clk  ),                                  
              .aclken               (clken),                              
              // .aresetn              (resetn ),                           
              .s_axis_a_tvalid      (s_valid),            
              .s_axis_a_tdata       (s_data_fix2float_cgu[c][g][u]),              
              .s_axis_a_tuser       (s_user ),              
              .m_axis_result_tvalid (m_valid_float32),  
              .m_axis_result_tdata  (m_data_float32_cgu[c][g][u]),    
              .m_axis_result_tuser  (m_user_float32)    
            );
            /*
             FMA Operation:  fma_out = fma_a * fma_b + fma_c

             fma_a = data
             fma_b = a
             fma_c = b
            */
            float_32_ma_active FMA_1 (
              .aclk                 (clk),                                  
              .aclken               (clken),                              
              // .aresetn              (resetn),                            
              .s_axis_a_tvalid      (m_valid_float32),            
              .s_axis_a_tdata       (m_data_float32_cgu[c][g][u]),              
              .s_axis_a_tuser       (s_user_fma_1),              
              .s_axis_b_tvalid      (1'b1),            
              .s_axis_b_tdata       (a_val_f32_cg [c][g]),              
              .s_axis_c_tvalid      (1'b1),           
              .s_axis_c_tdata       (b_val_f32_cgu[c][g][u]),              
              .m_axis_result_tvalid (m_valid_fma_1),  
              .m_axis_result_tdata  (m_data_fma_1_cgu[c][g][u]),    
              .m_axis_result_tuser  (m_user_fma_1)    
            );
            /*
             FMA Operation:  fma_out = fma_a * fma_b + fma_c

             fma_a = data
             fma_b = c
             fma_c = d
            */
            float_16_ma_active FMA_2 (
              .aclk                 (clk),                                  
              .aclken               (clken),                              
              // .aresetn              (resetn),                            
              .s_axis_a_tvalid      (m_valid_fma_1),            
              .s_axis_a_tdata       (m_data_fma_1_cgu_f16 [c][g][u]),              
              .s_axis_a_tuser       (s_user_fma_2),              
              .s_axis_b_tvalid      (1'b1),            
              .s_axis_b_tdata       (c_val_cgu [c][g][u]),              
              .s_axis_c_tvalid      (1'b1),           
              .s_axis_c_tdata       (d_val_cg [c][g]),              
              .m_axis_result_tvalid (m_valid_fma_2),  
              .m_axis_result_tdata  (m_data_fma_2_cgu [c][g][u]),    
              .m_axis_result_tuser  (m_user_fma_2)    
            );
            float_to_fixed_active FLOAT2FIX (
              .aclk                 (clk),                                  
              .aclken               (clken),                              
              // .aresetn              (resetn),                            
              .s_axis_a_tvalid      (m_valid_fma_2),            
              .s_axis_a_tdata       (m_data_fma_2_cgu [c][g][u]),              
              .s_axis_a_tuser       (m_user_fma_2),
              .m_axis_result_tvalid (m_valid), 
              .m_axis_result_tdata  (m_data_cgu[c][g][u]),    
              .m_axis_result_tuser  (m_user)    
            );
          end
          else begin
            fixed_to_float        FIX2FLOAT (
              .aclk                 (clk),                                  
              .aclken               (clken),                              
              // .aresetn              (resetn),                           
              .s_axis_a_tvalid      (s_valid),            
              .s_axis_a_tdata       (s_data_fix2float_cgu[c][g][u]), 
              .m_axis_result_tdata  (m_data_float32_cgu[c][g][u])  
            );
            /*
             FMA Operation:  fma_out = fma_a * fma_b + fma_c

             fma_a = data
             fma_b = a
             fma_c = b
            */
            float_32_ma FMA_1 (
              .aclk                 (clk),                                  
              .aclken               (clken),                              
              // .aresetn              (resetn),                            
              .s_axis_a_tvalid      (m_valid_float32),            
              .s_axis_a_tdata       (m_data_float32_cgu [c][g][u]),              
              .s_axis_b_tvalid      (1'b1),            
              .s_axis_b_tdata       (a_val_f32_cg  [c][g]),              
              .s_axis_c_tvalid      (1'b1),           
              .s_axis_c_tdata       (b_val_f32_cgu [c][g][u]),              
              .m_axis_result_tdata  (m_data_fma_1_cgu [c][g][u])
            );
            /*
             FMA Operation:  fma_out = fma_a * fma_b + fma_c

             fma_a = data
             fma_b = c
             fma_c = d
            */
            float_16_ma FMA_2 (
              .aclk                 (clk),                                  
              .aclken               (clken),                              
              // .aresetn              (resetn),                            
              .s_axis_a_tvalid      (m_valid_fma_1),            
              .s_axis_a_tdata       (m_data_fma_1_cgu_f16[c][g][u]),              
              .s_axis_b_tvalid      (1'b1),            
              .s_axis_b_tdata       (c_val_cgu [c][g][u]),              
              .s_axis_c_tvalid      (1'b1),           
              .s_axis_c_tdata       (d_val_cg  [c][g]),              
              .m_axis_result_tdata  (m_data_fma_2_cgu [c][g][u])
            );
            float_to_fixed FLOAT2FIX (
              .aclk                 (clk),                                  
              .aclken               (clken),                              
              // .aresetn              (resetn),                            
              .s_axis_a_tvalid      (m_valid_fma_2),            
              .s_axis_a_tdata       (m_data_fma_2_cgu [c][g][u]),              
              .m_axis_result_tdata  (m_data_cgu       [c][g][u])
            );
          end
        end
      end
    end 
  endgenerate
  /*
    Convert float16 wires to shortreal for simulation
  */

  shortreal m_data_fma_1_cgu_sr      [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  shortreal m_data_fma_2_cgu_sr      [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  shortreal c_val_cgu_sr             [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  shortreal config_s_data_cgv_sr     [COPIES-1:0][GROUPS-1:0][VALS_CONFIG-1:0];
  shortreal config_fma1_cgv_sr       [COPIES-1:0][GROUPS-1:0][VALS_CONFIG-1:0];
  shortreal a_val_cg_sr              [COPIES-1:0][GROUPS-1:0];
  shortreal b_cg_clr_mtb_sr          [COPIES-1:0][GROUPS-1:0][2:0][2:0];
  shortreal d_val_cg_sr              [COPIES-1:0][GROUPS-1:0];
  shortreal config_flat_2_cg_sr      [COPIES-1:0][GROUPS-1:0];

  generate
    for(genvar c=0; c<COPIES; c=c+1) begin: cs
      for(genvar g=0; g<GROUPS; g=g+1) begin: gs
        for(genvar u=0; u<UNITS; u=u+1) begin: us
          assign m_data_fma_1_cgu_sr [c][g][u] = $bitstoshortreal(float_16_to_32(m_data_fma_1_cgu_f16[c][g][u]));
          assign m_data_fma_2_cgu_sr [c][g][u] = $bitstoshortreal(float_16_to_32(m_data_fma_2_cgu    [c][g][u]));
          assign c_val_cgu_sr        [c][g][u] = $bitstoshortreal(float_16_to_32(c_val_cgu           [c][g][u]));
        end

        assign config_s_data_f16_cgv [c][g] = {>>{s_data_config_flat_cg [c][g]}};
        assign config_fma1_f16_cgv   [c][g] = {>>{config_flat_1_cg [c][g]}};

        for(genvar v=0; v<VALS_CONFIG; v=v+1) begin: vs
          assign config_s_data_cgv_sr[c][g][v] = $bitstoshortreal(float_16_to_32(config_s_data_f16_cgv[c][g][v]));
          assign config_fma1_cgv_sr  [c][g][v] = $bitstoshortreal(float_16_to_32(config_fma1_f16_cgv  [c][g][v]));
        end
        assign config_flat_2_cg_sr   [c][g] = $bitstoshortreal(float_16_to_32(config_flat_2_cg  [c][g]));
        assign a_val_cg_sr           [c][g] = $bitstoshortreal(float_16_to_32(a_val_cg          [c][g]));
        assign d_val_cg_sr           [c][g] = $bitstoshortreal(float_16_to_32(d_val_cg          [c][g]));

        for (genvar clr=0; clr<3; clr++)
          for (genvar mtb=0; mtb<3; mtb++)
            assign b_cg_clr_mtb_sr   [c][g][clr][mtb] = $bitstoshortreal(float_16_to_32(b_cg_clr_mtb_f16 [c][g][clr][mtb]));
      end
    end
  endgenerate
endmodule

function logic [31:0] float_16_to_32 (input logic [15:0] float_16);
    logic [31:0] float_32;
    
    logic sign;
    logic [4 :0] exp_16;
    logic [9 :0] fra_16;

    logic [7 :0] exp_32;
    logic [22:0] fra_32;

    assign {sign, exp_16, fra_16} = float_16;
    assign fra_32 = fra_16 << 13; // 23-10
    assign exp_32 = exp_16 + 7'd112; //- 15 + 127;
    assign float_32 = {sign, exp_32, fra_32};
    return float_32;
  endfunction

function logic [15:0] float_32_to_16 (input logic [31:0] float_32);
  logic [15:0] float_16;
  
  logic sign;
  logic [4 :0] exp_16;
  logic [9 :0] fra_16;

  logic [7 :0] exp_32;
  logic [22:0] fra_32;

  assign {sign, exp_32, fra_32} = float_32;
  assign fra_16 = fra_32 >> 13 ;
  assign exp_16 = exp_32 - 7'd112; //- 15 + 127;
  assign float_16 = {sign, exp_16, fra_16};
  return float_16;
endfunction