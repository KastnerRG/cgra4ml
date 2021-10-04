`timescale 1ns/1ps
`include "../include/params.v"

module lrelu_engine #(ZERO=0) (
  clk     ,
  clken   ,
  resetn  ,
  debug_config,
  s_valid ,
  s_last  ,
  s_user  ,
  m_valid ,
  m_last  ,
  m_user  ,
  s_data_flat_cgu,
  m_data_flat_cgu,

  resetn_config  ,
  s_valid_config ,
  config_kw2     ,
  s_data_conv_out,
  count_config_full
);

  

  localparam WORD_WIDTH_IN              = `WORD_WIDTH_ACC            ;
  localparam WORD_WIDTH_OUT             = `WORD_WIDTH                ;
  localparam WORD_WIDTH_CONFIG          = `WORD_WIDTH                ;
  localparam DEBUG_CONFIG_WIDTH_LRELU   = `DEBUG_CONFIG_WIDTH_LRELU  ;
  localparam UNITS                      = `UNITS                     ;
  localparam GROUPS                     = `GROUPS                    ;
  localparam COPIES                     = `COPIES                    ;
  localparam MEMBERS                    = `MEMBERS                   ;
  localparam KW_MAX                     = `KW_MAX                    ;
  localparam KH_MAX                     = `KH_MAX                    ;
  localparam LRELU_ALPHA                = `LRELU_ALPHA               ;
  localparam BITS_KH                    = `BITS_KH                   ;
  localparam BITS_KW                    = `BITS_KW                   ;
  localparam BITS_MEMBERS               = `BITS_MEMBERS              ;
  localparam BITS_KW2                   = `BITS_KW2                  ;
  localparam BITS_KH2                   = `BITS_KH2                  ;
  localparam BITS_EXP_CONFIG            = `BITS_EXP_CONFIG           ;
  localparam BITS_FRA_CONFIG            = `BITS_FRA_CONFIG           ;
  localparam BITS_EXP_FMA_1             = `BITS_EXP_FMA_1            ;
  localparam BITS_FRA_FMA_1             = `BITS_FRA_FMA_1            ;
  localparam BITS_EXP_FMA_2             = `BITS_EXP_FMA_2            ;
  localparam BITS_FRA_FMA_2             = `BITS_FRA_FMA_2            ;
  localparam LATENCY_FMA_1              = `LATENCY_FMA_1             ;
  localparam LATENCY_FMA_2              = `LATENCY_FMA_2             ;
  localparam LATENCY_FIXED_2_FLOAT      = `LATENCY_FIXED_2_FLOAT     ;
  localparam LATENCY_CYCLIC_REG         = `LATENCY_CYCLIC_REG        ;
  localparam LATENCY_FLOAT_UPSIZE       = `LATENCY_FLOAT_UPSIZE      ;
  localparam LATENCY_FLOAT_DOWNSIZE     = `LATENCY_FLOAT_DOWNSIZE    ;
  localparam I_IS_NOT_MAX               = `I_IS_NOT_MAX              ;
  localparam I_IS_MAX                   = `I_IS_MAX                  ;
  localparam I_KW2                      = `I_KW2                     ;
  localparam I_IS_LRELU                 = `I_IS_LRELU                ;
  localparam I_IS_TOP_BLOCK             = `I_IS_TOP_BLOCK            ;
  localparam I_IS_BOTTOM_BLOCK          = `I_IS_BOTTOM_BLOCK         ;
  localparam I_CLR                      = `I_CLR                     ;
  localparam TUSER_WIDTH_MAXPOOL_IN     = `TUSER_WIDTH_MAXPOOL_IN    ;
  localparam TUSER_WIDTH_LRELU_FMA_1_IN = `TUSER_WIDTH_LRELU_FMA_1_IN;
  localparam TUSER_WIDTH_LRELU_IN       = `TUSER_WIDTH_LRELU_IN      ;

  input  logic clk     ;
  input  logic clken   ;
  input  logic resetn  ;
  input  logic s_valid ;
  input  logic s_last  ;
  output logic m_valid ;
  output logic m_last  ;
  input  logic [COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_data_flat_cgu;
  output logic [COPIES * GROUPS * UNITS * WORD_WIDTH_OUT-1:0] m_data_flat_cgu;
  input  logic [TUSER_WIDTH_LRELU_IN  -1:0] s_user  ;
  output logic [TUSER_WIDTH_MAXPOOL_IN-1:0] m_user  ;

  /*
    CONFIG HANDLING

    s_axis_tdata
    s_data_conv_out - cgmu
    s_config_cgm
  */
  input  logic resetn_config, s_valid_config;
  input  logic [BITS_KW2-1:0] config_kw2;
  input  logic [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0][WORD_WIDTH_IN-1:0] s_data_conv_out;
  output logic count_config_full;

  logic [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0][WORD_WIDTH_CONFIG-1:0] s_config_cgm;

  generate
    for (genvar c = 0; c < COPIES; c++)
      for (genvar g = 0; g < GROUPS; g++)
        for (genvar m = 0; m < MEMBERS; m++)
          for (genvar u = 0; u < UNITS; u++)
            assign s_config_cgm[c][g][m] = WORD_WIDTH_CONFIG'(s_data_conv_out[c][g][m][0]);
  endgenerate

  /*
    Reshaping data
  */

  logic [WORD_WIDTH_IN -1:0] s_data_cgu [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [WORD_WIDTH_OUT-1:0] m_data_cgu [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  assign s_data_cgu = {>>{s_data_flat_cgu}};
  assign {>>{m_data_flat_cgu}} = m_data_cgu;

  localparam BRAM_R_WIDTH = 16;
  localparam BITS_FMA_1 = BITS_FRA_FMA_1 + BITS_EXP_FMA_1 + 1;
  localparam BITS_FMA_2 = BITS_FRA_FMA_2 + BITS_EXP_FMA_2 + 1;

  /* COUNTER */

  localparam CLR_I_MAX    = KW_MAX      /2;
  localparam BITS_CLR_I   = $clog2(CLR_I_MAX + 1);
  localparam BITS_W_SEL = 2;

  localparam W_ADDR_MAX  = calc_beats_max(KW_MAX,MEMBERS);
  localparam BITS_W_ADDR = $clog2(W_ADDR_MAX);

  logic [BITS_W_SEL    -1: 0] w_sel_bram, w_sel_bram_1;
  logic [BITS_CLR_I    -1: 0] w_clr_i, w_clr_i_1;
  logic [BITS_KH       -1: 0] w_mtb, w_mtb_1;
  logic [BITS_W_ADDR   -1: 0] w_addr, w_addr_1;

  lrelu_beats_counter #(
    .MEMBERS       (MEMBERS      ),
    .KH_MAX        (KH_MAX       ),
    .KW_MAX        (KW_MAX       ),
    .BITS_KH2      (BITS_KH2),
    .BITS_KW2      (BITS_KW2),
    .BITS_KW       (BITS_KW ),
    .BITS_KH       (BITS_KH )
  ) COUNTER (
    .clk   (clk            ),
    .rstn  (resetn_config  ),
    .en    (clken && s_valid_config),
    .full  (count_config_full),
    .kh2  (config_kw2      ),
    .kw2  (config_kw2      ),
    .w_sel (w_sel_bram     ),
    .clr_i (w_clr_i        ),
    .mtb   (w_mtb          ),
    .w_addr(w_addr         )
  );

  /*
    CONTROL DELAYS
  */
  logic w_sel_bram_2;
  logic valid_1;
  logic [TUSER_WIDTH_LRELU_IN-1:0] user_1;
  logic [BITS_KW2-1:0] user_1_kw2, user_2_kw2;
  logic [BITS_KW -1:0] user_1_clr;
  logic valid_config_1;
  logic valid_config_2;
  logic resetn_config_1;
  logic resetn_config_2;

  /*
    INTERMEDIATE ACTIVE WIRES
  */

  logic m_valid_float32, m_last_float32, m_valid_fma_1, m_last_fma_1, downsize_fma1_tvalid, s_last_fma_2, m_valid_fma_2, m_last_fma_2;
  logic [TUSER_WIDTH_LRELU_IN      -1:0] m_user_float32;
  logic [TUSER_WIDTH_LRELU_FMA_1_IN-1:0] s_user_fma_1, m_user_fma_1, user_2;
  logic [TUSER_WIDTH_MAXPOOL_IN    -1:0] s_user_fma_2, m_user_fma_2;

  assign s_user_fma_1 = TUSER_WIDTH_LRELU_FMA_1_IN'(m_user_float32);
  assign s_user_fma_2 = TUSER_WIDTH_MAXPOOL_IN'(user_2);
  
  logic ready_mtb [KH_MAX      -1:0];

  /*
    Declare multidimensional wires
  */
  localparam VALS_CONFIG = MEMBERS * WORD_WIDTH_CONFIG / 16;

  logic [BITS_FMA_2-1:0] config_s_data_f16_cgv[COPIES-1:0][GROUPS-1:0][VALS_CONFIG-1:0];
  logic [BITS_FMA_2-1:0] config_fma1_f16_cgv  [COPIES-1:0][GROUPS-1:0][VALS_CONFIG-1:0];
  logic [BITS_FMA_2-1:0] config_fma2_f16_cg   [COPIES-1:0][GROUPS-1:0];

  logic [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0][WORD_WIDTH_CONFIG-1:0] config_1_cgm;

  logic [BRAM_R_WIDTH-1:0] a_cg_16_delay_out [COPIES-1:0][GROUPS-1:0];
  logic [BRAM_R_WIDTH-1:0] a_cg_16_delay_in  [COPIES-1:0][GROUPS-1:0];
  logic [BITS_FMA_1-1:0]   a_cg_f32          [COPIES-1:0][GROUPS-1:0];
  logic                    b_ready_cg_clr_mtb[COPIES-1:0][GROUPS-1:0][KW_MAX      -1:0][KH_MAX      -1:0];
  logic [BRAM_R_WIDTH-1:0] b_cg_clr_mtb_f16  [COPIES-1:0][GROUPS-1:0][KW_MAX      -1:0][KH_MAX      -1:0];
  logic [BRAM_R_WIDTH-1:0] b_cg_mtb_f16  [COPIES-1:0][GROUPS-1:0][KH_MAX      -1:0];
  logic [BITS_FMA_1-1:0] b_cg_mtb_f32 [COPIES-1:0][GROUPS-1:0][KH_MAX      -1:0];
  logic [BITS_FMA_2-1:0] d_val_cg     [COPIES-1:0][GROUPS-1:0];
  logic [BRAM_R_WIDTH -1:0] config_2_cg [COPIES-1:0][GROUPS-1:0];


  localparam WIDTH_FIXED_2_FLOAT_S_DATA = (WORD_WIDTH_IN/8 + ((WORD_WIDTH_IN % 8) !=0))*8; // ceil(WORD_WIDTH_IN/8.0)*8
  logic signed [WIDTH_FIXED_2_FLOAT_S_DATA-1:0] s_data_fix2float_cgu [COPIES-1:0][GROUPS-1:0][UNITS-1:0];

  logic [BITS_FMA_1-1:0] m_data_float32_cgu   [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [BITS_FMA_1-1:0] m_data_fma_1_cgu     [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [BITS_FMA_2-1:0] m_data_fma_1_cgu_f16 [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [BITS_FMA_2-1:0] m_data_fma_2_cgu     [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [BITS_FMA_2-1:0] c_val_cgu            [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [BITS_FMA_1-1:0] b_val_f32_cgu_mtb_in [COPIES-1:0][GROUPS-1:0][KH_MAX      -1:0];
  logic [BITS_FMA_1-1:0] b_val_f32_cgu_mtb_out[COPIES-1:0][GROUPS-1:0][KH_MAX      -1:0];
  logic [BITS_FMA_1-1:0] b_val_f32_cgu_fma_in [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic is_lrelu_cgu                          [COPIES-1:0][GROUPS-1:0][UNITS-1:0];

  logic [COPIES-1:0] sel_is_top_c_in, sel_is_top_c_out, sel_is_bot_c_in, sel_is_bot_c_out;

  logic [BITS_MEMBERS-1:0] bram_b_r_max_lut  [KH_MAX      /2:0];
  generate
    for (genvar kw2=0; kw2<=KW_MAX      /2; kw2++) begin
      localparam kw = kw2*2+1;
      assign bram_b_r_max_lut [kw2] = MEMBERS/kw-1;
    end
  endgenerate

  output logic [DEBUG_CONFIG_WIDTH_LRELU-3-1:0] debug_config;
  assign debug_config = {w_sel_bram + d_val_cg[0][0]};

  generate
    for(genvar c=0; c<COPIES; c=c+1) begin: C
      for(genvar g=0; g<GROUPS; g=g+1) begin: G
        for (genvar u=0; u < UNITS; u++) begin: U

        assign s_data_fix2float_cgu[c][g][u] = WIDTH_FIXED_2_FLOAT_S_DATA'(signed'(s_data_cgu[c][g][u]));

          if (c==0 && g==0 && u==0)
            fixed_to_float_active FIX2FLOAT (
              .aclk                 (clk  ),                                  
              .aclken               (clken),                              
              // .aresetn              (resetn ),                           
              .s_axis_a_tvalid      (s_valid),            
              .s_axis_a_tlast       (s_last ),            
              .s_axis_a_tdata       (s_data_fix2float_cgu[c][g][u]),              
              .s_axis_a_tuser       (s_user ),              
              .m_axis_result_tvalid (m_valid_float32),  
              .m_axis_result_tlast  (m_last_float32),  
              .m_axis_result_tdata  (m_data_float32_cgu[c][g][u]),    
              .m_axis_result_tuser  (m_user_float32)    
            );
          else
            fixed_to_float        FIX2FLOAT (
              .aclk                 (clk),                                  
              .aclken               (clken),                              
              // .aresetn              (resetn),                           
              .s_axis_a_tvalid      (s_valid),            
              .s_axis_a_tdata       (s_data_fix2float_cgu[c][g][u]), 
              .m_axis_result_tdata  (m_data_float32_cgu[c][g][u])  
            );

          /*
            Delayed config
          */
          if (u ==0) begin
            localparam LATENCY_1 = LATENCY_FIXED_2_FLOAT-LATENCY_CYCLIC_REG-LATENCY_FLOAT_UPSIZE-1-1;

            n_delay #(
              .N          (LATENCY_1),
              .WORD_WIDTH (WORD_WIDTH_CONFIG * MEMBERS)
            ) CONFIG_DATA_FLAT_1 (
              .clk      (clk),
              .resetn   (resetn),
              .clken    (clken),
              .data_in  (s_config_cgm  [c][g]),
              .data_out (config_1_cgm  [c][g])
            );

            if (g==0 && c==0) begin
              n_delay #(
                .N          (LATENCY_1),
                .WORD_WIDTH (1)
              ) VALID_1 (
                .clk      (clk),
                .resetn   (resetn),
                .clken    (clken),
                .data_in  (s_valid),
                .data_out (valid_1)
              );
              n_delay #(
                .N          (LATENCY_1),
                .WORD_WIDTH (BITS_W_SEL)
              ) W_SEL_BRAM_1 (
                .clk      (clk),
                .resetn   (resetn),
                .clken    (clken),
                .data_in  (w_sel_bram),
                .data_out (w_sel_bram_1)
              );
              n_delay #(
                .N          (LATENCY_1),
                .WORD_WIDTH (BITS_CLR_I)
              ) CLR_I_1 (
                .clk      (clk),
                .resetn   (resetn),
                .clken    (clken),
                .data_in  (w_clr_i),
                .data_out (w_clr_i_1)
              );
              n_delay #(
                .N          (LATENCY_1),
                .WORD_WIDTH (BITS_KH)
              ) MTB_1 (
                .clk      (clk),
                .resetn   (resetn),
                .clken    (clken),
                .data_in  (w_mtb),
                .data_out (w_mtb_1)
              );
              n_delay #(
                .N          (LATENCY_1),
                .WORD_WIDTH (BITS_W_ADDR)
              ) W_ADDR_1 (
                .clk      (clk),
                .resetn   (resetn),
                .clken    (clken),
                .data_in  (w_addr),
                .data_out (w_addr_1)
              );
              n_delay #(
                .N          (LATENCY_1),
                .WORD_WIDTH (1)
              ) CONFIG_VALID_1 (
                .clk      (clk),
                .resetn   (resetn),
                .clken    (clken),
                .data_in  (s_valid_config),
                .data_out (valid_config_1)
              );
              n_delay #(
                .N          (LATENCY_1),
                .WORD_WIDTH (1)
              ) CONFIG_RESETN_1 (
                .clk      (clk),
                .resetn   (resetn),
                .clken    (clken),
                .data_in  (resetn_config),
                .data_out (resetn_config_1)
              );
              n_delay #(
                .N          (LATENCY_1),
                .WORD_WIDTH (TUSER_WIDTH_LRELU_IN)
              ) USER_1 (
                .clk      (clk),
                .resetn   (resetn),
                .clken    (clken),
                .data_in  (s_user),
                .data_out (user_1)
              );

              assign user_1_kw2  = user_1[I_KW2+BITS_KW2-1:I_KW2];
              assign user_1_clr  = user_1[I_CLR+BITS_KW-1:I_CLR];

            end
          end

          /*
            BRAM A
          */
          if (u == 0) begin

            localparam BRAM_R_DEPTH = MEMBERS;
            localparam BRAM_W_WIDTH = MEMBERS * WORD_WIDTH_CONFIG;
            localparam BRAM_W_DEPTH = BRAM_R_DEPTH * BRAM_R_WIDTH / BRAM_W_WIDTH;

            logic [$clog2(BRAM_R_DEPTH)-1:0] r_addr_max;
            assign r_addr_max = bram_b_r_max_lut[user_1_kw2];
            
            cyclic_shift_reg #(
              .R_DEPTH      (BRAM_R_DEPTH), 
              .R_DATA_WIDTH (BRAM_R_WIDTH),
              .W_DATA_WIDTH (BRAM_W_WIDTH),
              .OVERRIDE_W_ADDR (1)
            ) BRAM_A (
              .clk          (clk),
              .clken        (clken),
              .resetn       (resetn_config_1),
              .w_en         (w_sel_bram_1 == 2),
              .s_data       (config_1_cgm     [c][g]),
              .m_data       (a_cg_16_delay_in [c][g]),
              .r_en         (valid_1),
              .r_addr_max   (r_addr_max  ),
              .w_addr_max   ('0),
              .w_addr_in    (w_addr_1)
            );
            n_delay #(
              .N          (2),
              .WORD_WIDTH (BRAM_R_WIDTH)
            ) A_DELAY (
              .clk      (clk),
              .resetn   (resetn),
              .clken    (clken),
              .data_in  (a_cg_16_delay_in   [c][g]),
              .data_out (a_cg_16_delay_out  [c][g])
            );
            mod_float_upsize upsizer_a (
              .aclk                 (clk),
              .aclken               (clken),
              .s_axis_a_tvalid      (1'b1),           
              .s_axis_a_tdata       (a_cg_16_delay_out  [c][g]),
              .m_axis_result_tdata  (a_cg_f32           [c][g])
            );
          end

          /*
            BRAM B
            - Only the nessasary BRAMs are ready (using ready)
          */

          if (u == 0) begin

            for (genvar mtb=0; mtb < KH_MAX      ; mtb ++) begin: MTB
              /*
                READY:
                  - mtb = 0 is always ready
                  - mtb = 1,3,5 are ready only during top_block
                  - mtb = 2,4,6 are ready only during bot_block
              */
              localparam MTB_I     = (mtb+1)/2;
              localparam BRAM_KH   = MTB_I*2+1;


              assign ready_mtb[mtb] = (mtb==0) || (mtb%2==1 && user_1[I_IS_TOP_BLOCK]) || (mtb%2==0 && mtb!=0 && user_1[I_IS_BOTTOM_BLOCK]);

              for (genvar clr=0; clr < KW_MAX      ; clr ++) begin: CLR
                
                assign b_ready_cg_clr_mtb[c][g][clr][mtb] = valid_1 && (clr == user_1_clr) && ready_mtb[mtb]; //user_1_clr only for LATENCY=0

                localparam CLR_I        = (clr+1)/2;
                localparam BRAM_KW      = CLR_I*2+1;

                localparam BRAM_I       = (MTB_I > CLR_I) ? MTB_I : CLR_I;
                localparam BRAM_K_EFF   = BRAM_I*2 + 1;

                localparam BRAM_W_WORDS = MEMBERS/BRAM_K_EFF;
                localparam BRAM_W_WIDTH = BRAM_W_WORDS * WORD_WIDTH_CONFIG;

                logic [BRAM_W_WORDS-1:0][WORD_WIDTH_CONFIG-1:0] s_data;
                assign s_data = config_1_cgm[c][g][(clr+1)*BRAM_W_WORDS-1 : clr*BRAM_W_WORDS];


                localparam BRAM_R_DEPTH = MEMBERS/BRAM_K_EFF;
                localparam BRAM_W_DEPTH = BRAM_R_DEPTH * BRAM_R_WIDTH / BRAM_W_WIDTH;

                logic [$clog2(BRAM_R_DEPTH)-1:0] r_addr_max;
                assign r_addr_max = bram_b_r_max_lut[user_1_kw2];

                cyclic_shift_reg #(
                  .R_DEPTH      (BRAM_R_DEPTH), 
                  .R_DATA_WIDTH (BRAM_R_WIDTH),
                  .W_DATA_WIDTH (BRAM_W_WIDTH),
                  .W_WORD_WIDTH (WORD_WIDTH_CONFIG),
                  .OVERRIDE_W_ADDR (1)
                ) BRAM_B (
                  .clk          (clk),
                  .clken        (clken),
                  .resetn       (resetn_config_1),
                  .w_en         (w_sel_bram_1 == 3 && w_clr_i_1 == BRAM_I && w_mtb_1 == mtb),
                  .s_data       (s_data),
                  .m_data       (b_cg_clr_mtb_f16  [c][g][clr][mtb]),
                  .r_en         (b_ready_cg_clr_mtb[c][g][clr][mtb]),
                  .r_addr_max   (r_addr_max),
                  .w_addr_max   ('0),
                  .w_addr_in    (w_addr_1)
                );
                end
              end
            end
        /*
          MTB Mux with one latency

          * Top if:
            - top unit (u=0) 
            - if max: first copy  (c=0)
            - else  : both copies
          * Bottom if:
            - bottom unit (u=-1) 
            - if max: second copy  (c=1)
            - else  : both copies 
        */
          if (g==0 && u==0) begin
            for (genvar kh2=0; kh2<KH_MAX      ; kh2++) begin
              assign sel_is_top_c_in[c] = (user_1 [I_IS_MAX] ? (c==0) : 1) & user_1 [I_IS_TOP_BLOCK   ];
              assign sel_is_bot_c_in[c] = (user_1 [I_IS_MAX] ? (c==1) : 1) & user_1 [I_IS_BOTTOM_BLOCK];
              
              n_delay #(
                .N          (LATENCY_CYCLIC_REG + 1 + LATENCY_FLOAT_UPSIZE),
                .WORD_WIDTH (2)
              ) SEL_TOP_BOT (
                .clk      (clk),
                .resetn   (resetn),
                .clken    (clken),
                .data_in  ({sel_is_top_c_in [c],sel_is_bot_c_in [c]}),
                .data_out ({sel_is_top_c_out[c],sel_is_bot_c_out[c]})
              );
            end

            if (c==0)
              n_delay #(
                .N          (LATENCY_CYCLIC_REG + 1 + LATENCY_FLOAT_UPSIZE),
                .WORD_WIDTH (BITS_KW2)
              ) USER_KW2 (
                .clk      (clk),
                .resetn   (resetn),
                .clken    (clken),
                .data_in  (user_1_kw2),
                .data_out (user_2_kw2)
              );
          end
          /*
            CLR Mux

            kw=1: 000000000
            kw=3: 100000002
            kw=5: 130000042
            kw=7: 137000642
          */
          if (u == 0) begin
            for (genvar mtb=0; mtb < KH_MAX      ; mtb ++) begin
              register #(
                .WORD_WIDTH   (BRAM_R_WIDTH), 
                .RESET_VALUE  (0)
              ) B_MTB_16 (
                .clock        (clk),
                .clock_enable (clken),
                .resetn       (resetn),
                .data_in      (b_cg_clr_mtb_f16[c][g][user_1_clr][mtb]),
                .data_out     (b_cg_mtb_f16    [c][g][mtb])
              );

            /*
              MTB : Middle, Top and Bottom

              - All three can be needed at once (if there is only one block)
              - Hence, convert to f32 and keep them seperately

              kw: 1 3 5 7
              u
              0   0 1 1 1
              1   0 0 3 3
              2   0 0 0 5
              3   0 0 0 0
              4   0 0 0 0
              5   0 0 0 6
              6   0 0 4 4
              7   0 2 2 2
            */

            mod_float_upsize upsizer_mtb (
              .aclk                 (clk),
              .aclken               (clken),
              .s_axis_a_tvalid      (1'b1),           
              .s_axis_a_tdata       (b_cg_mtb_f16 [c][g][mtb]),
              .m_axis_result_tdata  (b_cg_mtb_f32 [c][g][mtb])
            );

            /*
              INTENDED OPERATION

              if top:
                if u < kw/2:
                  u <= u*2+1
                else:
                  u <= 0
              elif bot:
                if (UNITS-1-u > kw/2) : u > UNITS-kw/2-1 : u > 8-5/2-1 : u > 5
                  u <= (UNITS-u)*2
                else:
                  u <= 0
              else:
                  u <= 0             
            */

            /*
              MTB REGISTERS

              mtb <= user_1_kh_1:
                - mtb < kw
                - kh_max=7, kw=5 : mtb=0,1,2,3,4
              top:
                - is_top[c] && mtb is odd (1,3)
              bot:
                - is_bot[c] && mtb is even (0,1,2)
            */

            always_comb
              if (mtb <= user_2_kw2*2 && ((sel_is_top_c_out[c] && mtb%2==1) || (sel_is_bot_c_out[c] && mtb%2==0)))
                b_val_f32_cgu_mtb_in [c][g][mtb] = b_cg_mtb_f32[c][g][mtb];
              else
                b_val_f32_cgu_mtb_in [c][g][mtb] = b_cg_mtb_f32[c][g][0];

            n_delay #(
              .N          (1),
              .WORD_WIDTH (BITS_FMA_1)
            ) B_MTB_32 (
              .clk      (clk),
              .resetn   (resetn),
              .clken    (clken),
              .data_in  (b_val_f32_cgu_mtb_in  [c][g][mtb]),
              .data_out (b_val_f32_cgu_mtb_out [c][g][mtb])
            );
          end
        end
          /*
          KH = 5

          0 1
          1 3
          2
          3
          4
          5
          6 4
          7 2
          */
          if      (u <  KH_MAX      /2)
            assign b_val_f32_cgu_fma_in[c][g][u] = b_val_f32_cgu_mtb_out[c][g][u*2 +1     ];
          else if (u >= UNITS-KH_MAX      /2)
            assign b_val_f32_cgu_fma_in[c][g][u] = b_val_f32_cgu_mtb_out[c][g][(UNITS-u)*2];
          else
            assign b_val_f32_cgu_fma_in[c][g][u] = b_val_f32_cgu_mtb_out[c][g][0];

          /*
            FMA Operation:  fma_out = fma_a * fma_b + fma_c

            fma_a = data
            fma_b = a
            fma_c = b
          */
          if (c==0 && g==0 && u==0)
            fma_1_active FMA_1 (
              .aclk                 (clk),                                  
              .aclken               (clken),                              
              // .aresetn              (resetn),                            
              .s_axis_a_tvalid      (m_valid_float32),            
              .s_axis_a_tlast       (m_last_float32),            
              .s_axis_a_tdata       (m_data_float32_cgu[c][g][u]),              
              .s_axis_a_tuser       (s_user_fma_1),              
              .s_axis_b_tvalid      (1'b1),            
              .s_axis_b_tdata       (a_cg_f32     [c][g]),              
              .s_axis_c_tvalid      (1'b1),           
              .s_axis_c_tdata       (b_val_f32_cgu_fma_in[c][g][u]),              
              .m_axis_result_tvalid (m_valid_fma_1),  
              .m_axis_result_tlast  (m_last_fma_1),  
              .m_axis_result_tdata  (m_data_fma_1_cgu    [c][g][u]),    
              .m_axis_result_tuser  (m_user_fma_1)    
            );
          else
            fma_1 FMA_1 (
              .aclk                 (clk),                                  
              .aclken               (clken),                              
              // .aresetn              (resetn),                            
              .s_axis_a_tvalid      (m_valid_float32),            
              .s_axis_a_tdata       (m_data_float32_cgu [c][g][u]),              
              .s_axis_b_tvalid      (1'b1),            
              .s_axis_b_tdata       (a_cg_f32   [c][g]),              
              .s_axis_c_tvalid      (1'b1),           
              .s_axis_c_tdata       (b_val_f32_cgu_fma_in[c][g][u]),              
              .m_axis_result_tdata  (m_data_fma_1_cgu    [c][g][u])
            );

          if (c==0 && g==0 && u==0) begin
            n_delay #(
              .N          (LATENCY_FLOAT_DOWNSIZE),
              .WORD_WIDTH (TUSER_WIDTH_LRELU_FMA_1_IN)
            ) USER_2 (
              .clk      (clk),
              .resetn   (resetn),
              .clken    (clken),
              .data_in  (m_user_fma_1),
              .data_out (user_2)
            );
            n_delay #(
              .N          (LATENCY_FLOAT_DOWNSIZE),
              .WORD_WIDTH (1)
            ) LAST_2 (
              .clk      (clk),
              .resetn   (resetn),
              .clken    (clken),
              .data_in  (m_last_fma_1),
              .data_out (s_last_fma_2)
            );
          end

          /*
            DELAY CONFIG FOR REGISTER
          */
          if (u == 0) begin

            localparam LATENCY_2 = LATENCY_FIXED_2_FLOAT + LATENCY_FMA_1 + LATENCY_FLOAT_DOWNSIZE -1;

            n_delay #(
              .N          (LATENCY_2),
              .WORD_WIDTH (BRAM_R_WIDTH)
            ) CONFIG_DATA_FLAT_2 (
              .clk      (clk),
              .resetn   (resetn),
              .clken    (clken),
              .data_in  (16'(config_1_cgm [c][g])),
              .data_out (config_2_cg      [c][g])
            );

            if (c==0 && g==0) begin
              n_delay #(
                .N          (LATENCY_2),
                .WORD_WIDTH (1)
              ) W_SEL_BRAM_2 (
                .clk      (clk),
                .resetn   (resetn),
                .clken    (clken),
                .data_in  (w_sel_bram_1==1),
                .data_out (w_sel_bram_2   )
              );
              n_delay #(
                .N          (LATENCY_2),
                .WORD_WIDTH (1)
              ) CONFIG_VALID_2 (
                .clk      (clk),
                .resetn   (resetn),
                .clken    (clken),
                .data_in  (valid_config_1),
                .data_out (valid_config_2)
              );
              n_delay #(
                .N          (LATENCY_2),
                .WORD_WIDTH (1)
              ) CONFIG_RESETN_2 (
                .clk      (clk),
                .resetn   (resetn),
                .clken    (clken),
                .data_in  (resetn_config_1),
                .data_out (resetn_config_2)
              );
            end
          end

          /*
            D Register
          */
          if (u == 0)
            register #(
              .WORD_WIDTH   (BRAM_R_WIDTH), 
              .RESET_VALUE  (0)
            ) REG_D (
              .clock        (clk),
              .clock_enable (clken && valid_config_2 && (w_sel_bram_2==1)),
              .resetn       (resetn_config_2),
              .data_in      (config_2_cg [c][g]),
              .data_out     (d_val_cg [c][g])
            );

          /*
            LRELU
          */
          assign is_lrelu_cgu[c][g][u] = user_2[I_IS_LRELU      ] && m_data_fma_1_cgu_f16[c][g][u][BITS_FMA_2-1];
          assign c_val_cgu   [c][g][u] = is_lrelu_cgu[c][g][u] ? LRELU_ALPHA : 16'd15360 ; // 0.1 or 1

          if (c==0 && g==0 && u==0)
            mod_float_downsize downsize_fma1 (
              .aclk                 (clk),
              .aclken               (clken),
              .s_axis_a_tvalid      (m_valid_fma_1                  ),                      
              .s_axis_a_tdata       (m_data_fma_1_cgu    [c][g][u]  ),              
              .m_axis_result_tdata  (m_data_fma_1_cgu_f16[c][g][u]  ),
              .m_axis_result_tvalid (downsize_fma1_tvalid           )
            );
          else
            mod_float_downsize downsize_fma1 (
              .aclk                 (clk),
              .aclken               (clken),
              .s_axis_a_tvalid      (m_valid_fma_1                  ),            
              .s_axis_a_tdata       (m_data_fma_1_cgu    [c][g][u]  ),              
              .m_axis_result_tdata  (m_data_fma_1_cgu_f16[c][g][u]  )
            );

          /*
            FMA Operation:  fma_out = fma_a * fma_b + fma_c

            fma_a = data
            fma_b = c
            fma_c = d
          */
          if (c==0 && g==0 && u==0)
            fma_2_active FMA_2 (
              .aclk                 (clk),                                  
              .aclken               (clken),                              
              // .aresetn              (resetn),                            
              .s_axis_a_tvalid      (downsize_fma1_tvalid),            
              .s_axis_a_tlast       (s_last_fma_2 ),            
              .s_axis_a_tdata       (m_data_fma_1_cgu_f16 [c][g][u]),              
              .s_axis_a_tuser       (s_user_fma_2),              
              .s_axis_b_tvalid      (1'b1),            
              .s_axis_b_tdata       (c_val_cgu [c][g][u]),              
              .s_axis_c_tvalid      (1'b1),           
              .s_axis_c_tdata       (d_val_cg [c][g]),              
              .m_axis_result_tvalid (m_valid_fma_2),  
              .m_axis_result_tlast  (m_last_fma_2),  
              .m_axis_result_tdata  (m_data_fma_2_cgu [c][g][u]),    
              .m_axis_result_tuser  (m_user_fma_2)    
            );
          else
            fma_2 FMA_2 (
              .aclk                 (clk),                                  
              .aclken               (clken),                              
              // .aresetn              (resetn),                            
              .s_axis_a_tvalid      (downsize_fma1_tvalid),            
              .s_axis_a_tdata       (m_data_fma_1_cgu_f16[c][g][u]),              
              .s_axis_b_tvalid      (1'b1),            
              .s_axis_b_tdata       (c_val_cgu [c][g][u]),              
              .s_axis_c_tvalid      (1'b1),           
              .s_axis_c_tdata       (d_val_cg  [c][g]),              
              .m_axis_result_tdata  (m_data_fma_2_cgu [c][g][u])
            );

          if (c==0 && g==0 && u==0)
            float_to_fixed_active FLOAT2FIX (
              .aclk                 (clk),                                  
              .aclken               (clken),                              
              // .aresetn              (resetn),                            
              .s_axis_a_tvalid      (m_valid_fma_2),            
              .s_axis_a_tlast       (m_last_fma_2),            
              .s_axis_a_tdata       (m_data_fma_2_cgu [c][g][u]),              
              .s_axis_a_tuser       (m_user_fma_2),
              .m_axis_result_tvalid (m_valid), 
              .m_axis_result_tlast  (m_last ), 
              .m_axis_result_tdata  (m_data_cgu[c][g][u]),    
              .m_axis_result_tuser  (m_user)    
            );
          else
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
  endgenerate

  /*
    Convert float16 wires to shortreal for simulation
  */
  // synthesis translate_off

  shortreal m_data_fma_1_cgu_sr      [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  shortreal m_data_fma_2_cgu_sr      [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  shortreal c_val_cgu_sr             [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  shortreal config_s_data_cgv_sr     [COPIES-1:0][GROUPS-1:0][VALS_CONFIG-1:0];
  shortreal config_fma1_cgv_sr       [COPIES-1:0][GROUPS-1:0][VALS_CONFIG-1:0];
  shortreal a_val_cg_sr              [COPIES-1:0][GROUPS-1:0];
  shortreal b_cg_clr_mtb_sr          [COPIES-1:0][GROUPS-1:0][2:0][2:0];
  shortreal d_val_cg_sr              [COPIES-1:0][GROUPS-1:0];
  shortreal config_2_cg_sr      [COPIES-1:0][GROUPS-1:0];

generate
  for(genvar c=0; c<COPIES; c=c+1) begin: cs
    for(genvar g=0; g<GROUPS; g=g+1) begin: gs
      for(genvar u=0; u<UNITS; u=u+1) begin: us
        assign m_data_fma_1_cgu_sr [c][g][u] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(m_data_fma_1_cgu_f16[c][g][u]));
        assign m_data_fma_2_cgu_sr [c][g][u] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(m_data_fma_2_cgu    [c][g][u]));
        assign c_val_cgu_sr        [c][g][u] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(c_val_cgu           [c][g][u]));
      end

      assign config_s_data_f16_cgv [c][g] = {>>{s_config_cgm [c][g]}};
      assign config_fma1_f16_cgv   [c][g] = {>>{config_1_cgm [c][g]}};

      for(genvar v=0; v<VALS_CONFIG; v=v+1) begin: vs
        assign config_s_data_cgv_sr[c][g][v] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(config_s_data_f16_cgv[c][g][v]));
        assign config_fma1_cgv_sr  [c][g][v] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(config_fma1_f16_cgv  [c][g][v]));
      end
      assign config_2_cg_sr   [c][g] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(config_2_cg  [c][g]));
      assign a_val_cg_sr           [c][g] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(a_cg_16_delay_out          [c][g]));
      assign d_val_cg_sr           [c][g] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(d_val_cg          [c][g]));

      for (genvar clr=0; clr<3; clr++)
        for (genvar mtb=0; mtb<3; mtb++)
          assign b_cg_clr_mtb_sr   [c][g][clr][mtb] = $bitstoshortreal(float_upsize #(5,10,8,23)::upsize(b_cg_clr_mtb_f16 [c][g][clr][mtb]));
    end
  end
endgenerate

// synthesis translate_on

endmodule