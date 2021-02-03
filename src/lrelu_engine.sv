virtual class float_downsize #(parameter EXP_IN, FRA_IN, EXP_OUT, FRA_OUT);
  static function logic [EXP_OUT+FRA_OUT:0] downsize (input logic [EXP_IN+FRA_IN:0] float_in);
    /*
      Downsize
      * eg: Float32 -> Float16
          - EXP_IN  : 8
          - FRA_IN  : 23
          - EXP_OUT : 5
          - FRA_OUT : 10
      * Mantissa is rounded to avoid error
    */
    logic sign;
    logic [EXP_IN -1:0] exp_in;
    logic [FRA_IN -1:0] fra_in;
    logic [EXP_OUT-1:0] exp_out;
    logic [FRA_OUT  :0] fra_out_extra, fra_out_round;
    logic [FRA_OUT-1:0] fra_out;
    
    {sign, exp_in, fra_in} = float_in;
    exp_out = exp_in - (2**(EXP_IN-1)-2**(EXP_OUT-1));
    fra_out_extra = fra_in >> (FRA_IN-FRA_OUT-1);
    // fra_out_round = sign ? fra_out_extra - fra_in[FRA_IN-FRA_OUT]: fra_out_extra + fra_in[FRA_IN-FRA_OUT];
    // fra_out = fra_out_round >> 1;
    fra_out = fra_in >> (FRA_IN-FRA_OUT);
    return {sign, exp_out, fra_out};
  endfunction
endclass

virtual class float_upsize #(parameter EXP_IN, FRA_IN, EXP_OUT, FRA_OUT);  
  static function logic [EXP_OUT+FRA_OUT:0] upsize (input logic [EXP_IN+FRA_IN:0] float_in);
    /*
      Upsize
      * eg: Float32 -> Float16
          - EXP_IN  : 5
          - FRA_IN  : 10
          - EXP_OUT : 8
          - FRA_OUT : 23
      * No need to round
    */
    logic sign;
    logic [EXP_IN -1:0] exp_in;
    logic [FRA_IN -1:0] fra_in;
    logic [EXP_OUT-1:0] exp_out;
    logic [FRA_OUT-1:0] fra_out;
    
    {sign, exp_in, fra_in} = float_in;
    exp_out = exp_in + (2**(EXP_OUT-1)-2**(EXP_IN-1));
    fra_out = fra_in << (FRA_OUT-FRA_IN);
    return {sign, exp_out, fra_out};
  endfunction
endclass

module lrelu_engine (
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
  is_1x1_config  ,
  s_data_conv_out
);

  parameter WORD_WIDTH_IN     = 32;
  parameter WORD_WIDTH_OUT    = 8 ;
  parameter WORD_WIDTH_CONFIG = 8 ;
  parameter UNITS   = 8;
  parameter GROUPS  = 2;
  parameter COPIES  = 2;
  parameter MEMBERS = 2;
  parameter LRELU_ALPHA = 16'd11878;

  parameter BITS_EXP_CONFIG       = 5;
  parameter BITS_FRA_CONFIG       = 10;
  parameter BITS_EXP_FMA_1        = 8;
  parameter BITS_FRA_FMA_1        = 23;
  parameter BITS_EXP_FMA_2        = 5;
  parameter BITS_FRA_FMA_2        = 10;
  parameter LATENCY_FMA_1         = 16;
  parameter LATENCY_FMA_2         = 16;
  parameter LATENCY_FIXED_2_FLOAT =  6;
  parameter LATENCY_BRAM          =  2;

  parameter I_IS_NOT_MAX      = 0;
  parameter I_IS_MAX          = I_IS_NOT_MAX      + 1;
  parameter I_IS_LRELU        = I_IS_MAX          + 1;
  parameter I_IS_TOP_BLOCK    = I_IS_LRELU        + 1;
  parameter I_IS_BOTTOM_BLOCK = I_IS_TOP_BLOCK    + 1;
  parameter I_IS_1X1          = I_IS_BOTTOM_BLOCK + 1;
  parameter I_IS_LEFT_COL     = I_IS_1X1          + 1;
  parameter I_IS_RIGHT_COL    = I_IS_LEFT_COL     + 1;

  parameter TUSER_WIDTH_MAXPOOL_IN     = 1 + I_IS_MAX  ;
  parameter TUSER_WIDTH_LRELU_FMA_1_IN = 1 + I_IS_LRELU;
  parameter TUSER_WIDTH_LRELU_IN       = 1 + I_IS_RIGHT_COL;

  input  logic clk     ;
  input  logic clken   ;
  input  logic resetn  ;
  input  logic s_valid ;
  output logic m_valid ;
  input  logic [COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_data_flat_cgu;
  output logic [COPIES * GROUPS * UNITS * WORD_WIDTH_OUT-1:0] m_data_flat_cgu;
  input  logic [TUSER_WIDTH_LRELU_IN  -1:0] s_user  ;
  output logic [TUSER_WIDTH_MAXPOOL_IN-1:0] m_user  ;

  /*
    CONFIG HANDLING

    s_axis_tdata
    s_data_conv_out - cgmu
    s_data_config_cgm
    s_data_config_flat_cg
      config_s_data_cgv_sr
  */
  input  logic resetn_config, s_valid_config, is_1x1_config;
  input  logic [MEMBERS * COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_data_conv_out;

  logic [WORD_WIDTH_IN    -1:0] s_data_conv_out_cgmu [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0];
  logic [WORD_WIDTH_CONFIG-1:0] s_data_config_cgm    [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0];
  logic [MEMBERS * WORD_WIDTH_CONFIG-1:0] s_data_config_flat_cg [COPIES-1:0][GROUPS-1:0];

  assign s_data_conv_out_cgmu = {>>{s_data_conv_out}};
  generate
    for (genvar c = 0; c < COPIES; c++)
      for (genvar g = 0; g < GROUPS; g++) begin
        for (genvar m = 0; m < MEMBERS; m++)
            assign s_data_config_cgm[c][g][m] = WORD_WIDTH_CONFIG'(s_data_conv_out_cgmu[c][g][m][0]);

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

  localparam BITS_FMA_1 = BITS_FRA_FMA_1 + BITS_EXP_FMA_1 + 1;
  localparam BITS_FMA_2 = BITS_FRA_FMA_2 + BITS_EXP_FMA_2 + 1;

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
    * Fill delay
      - 1x1, 
        - B_cm is filled last and is needed immediately
        - Hence, we wait for LATENCY clocks in FILL_S
      - 3x3,
        - B_rb is filled last
        - B_l are needed first and then B_c are needed. 
        - B_l not needed until the left edge of image
        - So, no explicit fill delay, directly start reading
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
  assign bram_w_depth_1 = is_1x1_config ? BRAM_W_DEPTH_1X1-1 : BRAM_W_DEPTH_3X3-1;
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
                    if (is_1x1_config) w_sel_bram_next = 1;
                    else               w_sel_bram_next = 4;
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
    .WORD_WIDTH (4)
  ) W_SEL_BRAM_1 (
    .clk      (clk),
    .resetn   (resetn),
    .clken    (clken),
    .data_in  (w_sel_bram),
    .data_out (w_sel_bram_1)
  );
  logic w_sel_bram_2;
  n_delay #(
    .N          (LATENCY_FMA_1),
    .WORD_WIDTH (1)
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
    .WORD_WIDTH (1)
  ) CONFIG_VALID_1 (
    .clk      (clk),
    .resetn   (resetn),
    .clken    (clken),
    .data_in  (s_valid_config),
    .data_out (valid_config_1)
  );
  logic valid_config_2;
  n_delay #(
    .N          (LATENCY_FMA_1),
    .WORD_WIDTH (1)
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
    .WORD_WIDTH (1)
  ) CONFIG_RESETN_1 (
    .clk      (clk),
    .resetn   (resetn),
    .clken    (clken),
    .data_in  (resetn_config),
    .data_out (resetn_config_1)
  );
  logic resetn_config_2;
  n_delay #(
    .N          (LATENCY_FMA_1),
    .WORD_WIDTH (1)
  ) CONFIG_RESETN_2 (
    .clk      (clk),
    .resetn   (resetn),
    .clken    (clken),
    .data_in  (resetn_config_1),
    .data_out (resetn_config_2)
  );

  logic is_1x1_config_1;
  n_delay #(
    .N          (LATENCY_FIXED_2_FLOAT),
    .WORD_WIDTH (1)
  ) CONFIG_1x1_1 (
    .clk      (clk),
    .resetn   (resetn),
    .clken    (clken),
    .data_in  (is_1x1_config),
    .data_out (is_1x1_config_1)
  );

  /*
    INTERMEDIATE ACTIVE WIRES
  */

  logic m_valid_float32, m_valid_fma_1, m_valid_fma_2;
  logic [TUSER_WIDTH_LRELU_IN      -1:0] m_user_float32;
  logic [TUSER_WIDTH_LRELU_FMA_1_IN-1:0] s_user_fma_1, m_user_fma_1;
  logic [TUSER_WIDTH_MAXPOOL_IN    -1:0] s_user_fma_2, m_user_fma_2;

  assign s_user_fma_1 = TUSER_WIDTH_LRELU_FMA_1_IN'(m_user_float32);
  assign s_user_fma_2 = TUSER_WIDTH_MAXPOOL_IN'(m_user_fma_1);
  
  logic [BITS_BRAM_R_DEPTH-1:0] b_r_addr_max  ; 
  logic [BITS_BRAM_W_DEPTH-1:0] b_w_addr_max  ;
  assign b_w_addr_max   = is_1x1_config_1          ? BRAM_W_DEPTH_1X1-1 : BRAM_W_DEPTH_3X3-1;
  assign b_r_addr_max   = m_user_float32[I_IS_1X1] ? BRAM_R_DEPTH_1X1-1 : BRAM_R_DEPTH_3X3-1;

  /*
    Declare multidimensional wires
  */
  localparam VALS_CONFIG = MEMBERS * WORD_WIDTH_CONFIG / 16;

  logic [BITS_FMA_2-1:0] config_s_data_f16_cgv[COPIES-1:0][GROUPS-1:0][VALS_CONFIG-1:0];
  logic [BITS_FMA_2-1:0] config_fma1_f16_cgv  [COPIES-1:0][GROUPS-1:0][VALS_CONFIG-1:0];
  logic [BITS_FMA_2-1:0] config_fma2_f16_cg   [COPIES-1:0][GROUPS-1:0];

  logic [WORD_WIDTH_CONFIG * MEMBERS-1:0] config_flat_1_cg [COPIES-1:0][GROUPS-1:0];
  logic [BRAM_R_WIDTH-1:0] a_val_cg     [COPIES-1:0][GROUPS-1:0];
  logic [BITS_FMA_1-1:0]             a_val_f32_cg [COPIES-1:0][GROUPS-1:0];
  logic                    b_ready_cg_clr_mtb[COPIES-1:0][GROUPS-1:0][2:0][2:0];
  logic [BRAM_R_WIDTH-1:0] b_cg_clr_mtb_f16  [COPIES-1:0][GROUPS-1:0][2:0][2:0];
  logic [BITS_FMA_1-1:0] b_mid_f32_cg [COPIES-1:0][GROUPS-1:0];
  logic [BITS_FMA_1-1:0] b_top_f32_cg [COPIES-1:0][GROUPS-1:0]; 
  logic [BITS_FMA_1-1:0] b_bot_f32_cg [COPIES-1:0][GROUPS-1:0];
  logic [BITS_FMA_2-1:0] d_val_cg     [COPIES-1:0][GROUPS-1:0];
  logic [BRAM_R_WIDTH -1:0] config_flat_2_cg [COPIES-1:0][GROUPS-1:0];


  localparam WIDTH_FIXED_2_FLOAT_S_DATA = (WORD_WIDTH_IN/8 + ((WORD_WIDTH_IN % 8) !=0))*8; // ceil(WORD_WIDTH_IN/8.0)*8
  logic signed [WIDTH_FIXED_2_FLOAT_S_DATA-1:0] s_data_fix2float_cgu [COPIES-1:0][GROUPS-1:0][UNITS-1:0];

  logic [BITS_FMA_1-1:0] m_data_float32_cgu   [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [BITS_FMA_1-1:0] m_data_fma_1_cgu     [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [BITS_FMA_2-1:0] m_data_fma_1_cgu_f16 [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [BITS_FMA_2-1:0] m_data_fma_2_cgu     [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [BITS_FMA_2-1:0] c_val_cgu            [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [BITS_FMA_1-1:0] b_val_f32_cgu        [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic is_top_cgu                  [COPIES-1:0][GROUPS-1:0][UNITS-1:0]; 
  logic is_bot_cgu                  [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic is_lrelu_cgu                [COPIES-1:0][GROUPS-1:0][UNITS-1:0];

  /*
    CLR mux for B-BRAM

    - Only one of C,L,R can be true at a time
  */

  logic [1:0] fma1_index_clr;
  logic ready_mtb [2:0];
  always_comb begin
    if (m_user_float32[I_IS_1X1]) begin
      fma1_index_clr = 2'd0;
    end
    else begin
      if      (m_user_float32[I_IS_LEFT_COL   ])  fma1_index_clr = 2'd1;
      else if (m_user_float32[I_IS_RIGHT_COL  ])  fma1_index_clr = 2'd2;
      else                                        fma1_index_clr = 2'd0;
    end
  end


  generate
    for(genvar c=0; c<COPIES; c=c+1) begin: c_gen
      for(genvar g=0; g<GROUPS; g=g+1) begin: g_gen

        n_delay #(
          .N          (LATENCY_FIXED_2_FLOAT),
          .WORD_WIDTH (WORD_WIDTH_CONFIG * MEMBERS)
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
        assign a_val_f32_cg [c][g] = float_upsize #(BITS_EXP_CONFIG, BITS_FRA_CONFIG, BITS_EXP_FMA_1, BITS_FRA_FMA_1) :: upsize(a_val_cg [c][g]);

        always_valid_cyclic_bram #(
          .W_DEPTH (BRAM_W_DEPTH_1X1), 
          .W_WIDTH (BRAM_W_WIDTH),
          .R_WIDTH (BRAM_R_WIDTH),
          .LATENCY (LATENCY_BRAM),
          .IP_TYPE (0)
        ) BRAM_A (
          .clk          (clk),
          .clken        (clken),
          .resetn       (resetn_config_1),
          .s_valid_ready(valid_config_1 && (w_sel_bram_1 == 2)),
          .s_data       (config_flat_1_cg [c][g]),
          .m_data       (a_val_cg [c][g]),
          .m_ready      (m_valid_float32),
          .r_addr_min   (0),
          .r_addr_max   (b_r_addr_max  ),
          .w_addr_max   (b_w_addr_max  )
        );

        /*
          BRAM B
          - Only the nessasary BRAMs are ready (using ready)
        */
        for (genvar mtb=0; mtb < 3; mtb ++) begin: mtb_gen

          assign ready_mtb[mtb] = (mtb==0) || ~m_user_float32[I_IS_1X1] && (   (mtb==1 && m_user_float32[I_IS_TOP_BLOCK]) 
                                                                           || (mtb==2 && m_user_float32[I_IS_BOTTOM_BLOCK]));

          for (genvar clr=0; clr < 3; clr ++) begin: clr_gen
            
            assign b_ready_cg_clr_mtb[c][g][clr][mtb] = m_valid_float32 && (fma1_index_clr == clr) && ready_mtb[mtb];

            if (mtb==0 && clr ==0) begin // Center BRAM

              always_valid_cyclic_bram #(
                .W_DEPTH (BRAM_W_DEPTH_1X1), 
                .W_WIDTH (BRAM_W_WIDTH),
                .R_WIDTH (BRAM_R_WIDTH),
                .LATENCY (LATENCY_BRAM),
                .IP_TYPE (0)
              ) BRAM_B (
                .clk          (clk),
                .clken        (clken),
                .resetn       (resetn_config_1),
                .s_valid_ready(valid_config_1 && (w_sel_bram_1 == 3)),
                .s_data       (config_flat_1_cg [c][g]),
                .m_data       (b_cg_clr_mtb_f16[c][g][clr][mtb]),
                .m_ready      (b_ready_cg_clr_mtb[c][g][clr][mtb]),
                .r_addr_min   (0),
                .r_addr_max   (b_r_addr_max  ),
                .w_addr_max   (b_w_addr_max  )
              );
            end
            else begin // Edge BRAM
              always_valid_cyclic_bram #(
                .W_DEPTH (BRAM_W_DEPTH_3X3), 
                .W_WIDTH (BRAM_W_WIDTH),
                .R_WIDTH (BRAM_R_WIDTH),
                .LATENCY (LATENCY_BRAM),
                .IP_TYPE (1)
              ) BRAM_B (
                .clk          (clk),
                .clken        (clken),
                .resetn       (resetn_config_1),
                .s_valid_ready(valid_config_1 && (w_sel_bram_1 == 3 + clr*3 + mtb)),
                .s_data       (config_flat_1_cg [c][g]),
                .m_data       (b_cg_clr_mtb_f16[c][g][clr][mtb]),
                .m_ready      (b_ready_cg_clr_mtb[c][g][clr][mtb]),
                .r_addr_min   (0),
                .r_addr_max   (BRAM_R_DEPTH_3X3-1),
                .w_addr_max   (BRAM_W_DEPTH_3X3-1)
              );
            end
          end
        end

        /*
          MTB : Middle, Top and Bottom

          - All three can be needed at once (if there is only one block)
          - Hence, convert to f32 and keep them seperately
        */

        always_comb begin
          b_mid_f32_cg[c][g] = float_upsize #(BITS_EXP_CONFIG, BITS_FRA_CONFIG, BITS_EXP_FMA_1, BITS_FRA_FMA_1) :: upsize(b_cg_clr_mtb_f16[c][g][fma1_index_clr][0]);
          b_top_f32_cg[c][g] = float_upsize #(BITS_EXP_CONFIG, BITS_FRA_CONFIG, BITS_EXP_FMA_1, BITS_FRA_FMA_1) :: upsize(b_cg_clr_mtb_f16[c][g][fma1_index_clr][1]);
          b_bot_f32_cg[c][g] = float_upsize #(BITS_EXP_CONFIG, BITS_FRA_CONFIG, BITS_EXP_FMA_1, BITS_FRA_FMA_1) :: upsize(b_cg_clr_mtb_f16[c][g][fma1_index_clr][2]);
        end

        /*
          DELAY CONFIG FOR REGISTER
        */
        n_delay #(
          .N          (LATENCY_FMA_1),
          .WORD_WIDTH (BRAM_R_WIDTH)
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

        for (genvar u=0; u < UNITS; u++) begin:u_gen

          assign s_data_fix2float_cgu[c][g][u] = WIDTH_FIXED_2_FLOAT_S_DATA'(signed'(s_data_cgu[c][g][u]));

          /*
            Assign MTB BRAMs to each unit

            * Top if:
              - top unit (u=0) 
              - if max: first copy  (c=0)
              - else  : both copies
            * Bottom if:
              - bottom unit (u=-1) 
              - if max: second copy  (c=1)
              - else  : both copies 
          */
          
          assign is_top_cgu[c][g][u] = (u == 0      ) & (m_user_float32[I_IS_MAX] ? (c==0) : 1) & m_user_float32[I_IS_TOP_BLOCK];
          assign is_bot_cgu[c][g][u] = (u == UNITS-1) & (m_user_float32[I_IS_MAX] ? (c==1) : 1) & m_user_float32[I_IS_BOTTOM_BLOCK];

          always_comb begin
            if (m_user_float32[I_IS_1X1]) begin
              b_val_f32_cgu[c][g][u] = b_mid_f32_cg[c][g];
            end
            else begin
              unique case ({is_top_cgu[c][g][u], is_bot_cgu[c][g][u]})
                2'b00 : b_val_f32_cgu[c][g][u] = b_mid_f32_cg[c][g];
                2'b10 : b_val_f32_cgu[c][g][u] = b_top_f32_cg[c][g];
                2'b01 : b_val_f32_cgu[c][g][u] = b_bot_f32_cg[c][g];
              endcase
            end
          end

          assign m_data_fma_1_cgu_f16[c][g][u] = float_downsize #(BITS_EXP_FMA_1,BITS_FRA_FMA_1,BITS_EXP_FMA_2,BITS_FRA_FMA_2) :: downsize(m_data_fma_1_cgu[c][g][u]);

          /*
            LRELU
          */

          assign is_lrelu_cgu[c][g][u] = m_user_fma_1[I_IS_LRELU      ] && m_data_fma_1_cgu[c][g][u][BITS_FMA_1-1];
          assign c_val_cgu   [c][g][u] = is_lrelu_cgu[c][g][u] ? LRELU_ALPHA : 16'd15360 ; // 0.1 or 1

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
            fma_1_active FMA_1 (
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
            fma_2_active FMA_2 (
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
            fma_1 FMA_1 (
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
            fma_2 FMA_2 (
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

// generate
//   for(genvar c=0; c<COPIES; c=c+1) begin: cs
//     for(genvar g=0; g<GROUPS; g=g+1) begin: gs
//       for(genvar u=0; u<UNITS; u=u+1) begin: us
//         assign m_data_fma_1_cgu_sr [c][g][u] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(m_data_fma_1_cgu_f16[c][g][u]));
//         assign m_data_fma_2_cgu_sr [c][g][u] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(m_data_fma_2_cgu    [c][g][u]));
//         assign c_val_cgu_sr        [c][g][u] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(c_val_cgu           [c][g][u]));
//       end

//       assign config_s_data_f16_cgv [c][g] = {>>{s_data_config_flat_cg [c][g]}};
//       assign config_fma1_f16_cgv   [c][g] = {>>{config_flat_1_cg [c][g]}};

//       for(genvar v=0; v<VALS_CONFIG; v=v+1) begin: vs
//         assign config_s_data_cgv_sr[c][g][v] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(config_s_data_f16_cgv[c][g][v]));
//         assign config_fma1_cgv_sr  [c][g][v] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(config_fma1_f16_cgv  [c][g][v]));
//       end
//       assign config_flat_2_cg_sr   [c][g] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(config_flat_2_cg  [c][g]));
//       assign a_val_cg_sr           [c][g] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(a_val_cg          [c][g]));
//       assign d_val_cg_sr           [c][g] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(d_val_cg          [c][g]));

//       for (genvar clr=0; clr<3; clr++)
//         for (genvar mtb=0; mtb<3; mtb++)
//           assign b_cg_clr_mtb_sr   [c][g][clr][mtb] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(b_cg_clr_mtb_f16 [c][g][clr][mtb]));
//     end
//   end
// endgenerate
endmodule