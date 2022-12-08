`timescale 1ns/1ps
`include "../params/params.v"

module axis_pixels_dw (
    aclk     ,
    aresetn  ,
    s_ready  , 
    s_valid  , 
    s_last   , 
    s_data   , 
    s_keep   ,    
    m_shift  ,
    m_ones   ,
    m_ready  ,      
    m_valid  ,   
    m_data   ,
    m_user
  );
  

  localparam UNITS                = `UNITS             ;
  localparam COPIES               = `COPIES            ;
  localparam WORD_WIDTH           = `WORD_WIDTH        ; 
  localparam MEMBERS              = `MEMBERS           ;
  localparam IM_SHIFT_REGS        = `IM_SHIFT_REGS     ;
  localparam LATENCY_BRAM         = `LATENCY_BRAM      ;
  localparam KH_MAX               = `KH_MAX            ;
  localparam KW_MAX               = `KW_MAX            ;
  localparam SH_MAX               = `SH_MAX            ;
  localparam I_IS_NOT_MAX         = `I_IS_NOT_MAX      ;
  localparam I_IS_MAX             = `I_IS_MAX          ;
  localparam I_IS_LRELU           = `I_IS_LRELU        ;
  localparam I_KH2                = `I_KH2             ; 
  localparam I_SH_1               = `I_SH_1            ; 
  localparam TUSER_WIDTH_PIXELS   = `TUSER_WIDTH_PIXELS;
  localparam OUTPUT_MODE          = `OUTPUT_MODE       ;
  localparam S_PIXELS_WIDTH_LF    = `S_PIXELS_WIDTH_LF ;
  localparam BITS_KH              = `BITS_KH           ;
  localparam BITS_KH2             = `BITS_KH2          ;
  localparam BITS_IM_SHIFT        = `BITS_IM_SHIFT     ;
  localparam BITS_IM_SHIFT_REGS   = `BITS_IM_SHIFT_REGS;
  localparam BITS_KW2             = `BITS_KW2          ;
  localparam BITS_SH              = `BITS_SH           ;
  localparam CONFIG_COUNT_MAX     = 1; // lrelu_beats
  localparam BITS_CONFIG_COUNT    = $clog2(CONFIG_COUNT_MAX);

  input logic aclk;
  input logic aresetn;

  output logic s_ready;
  input  logic s_valid;
  input  logic s_last ;
  input  logic [S_PIXELS_WIDTH_LF/WORD_WIDTH-1:0][WORD_WIDTH-1:0] s_data;
  input  logic [S_PIXELS_WIDTH_LF/WORD_WIDTH                -1:0] s_keep;

  input  logic m_ready;
  output logic m_valid;
  output logic [TUSER_WIDTH_PIXELS                -1:0] m_user;
  output logic [IM_SHIFT_REGS     -1:0][WORD_WIDTH-1:0] m_data;
  output logic [BITS_IM_SHIFT-1:0] m_shift;
  output logic m_ones;

  logic s_beat, s_last_beat, m_beat;
  assign s_beat         = s_ready & s_valid;
  assign s_last_beat    = s_beat & s_last;
  assign m_beat         = m_ready & m_valid;

  /*
    Sample config params
  */
  logic config_en;
  logic is_max, is_not_max, is_lrelu;
  logic [BITS_KH2           -1:0] kh2;
  logic [BITS_KW2           -1:0] kw2;
  logic [BITS_SH            -1:0] sh_1;
  logic [BITS_IM_SHIFT_REGS -1:0] words;

  localparam CONFIG_WIDTH = BITS_IM_SHIFT_REGS + BITS_SH + BITS_KW2 + BITS_KH2 + 3;

  register #(
    .WORD_WIDTH   (CONFIG_WIDTH),
    .RESET_VALUE  (0)
  ) CONFIG (
    .clock        (aclk),
    .resetn       (aresetn),
    .clock_enable (config_en),
    .data_in      (CONFIG_WIDTH'(s_data)),
    .data_out     ({words, sh_1, kw2, kh2, is_lrelu, is_max, is_not_max})
  );
  assign m_user [I_IS_NOT_MAX ] = COPIES!=1 && is_not_max;
  assign m_user [I_IS_MAX     ] = COPIES!=1 && is_max    ;
  assign m_user [I_IS_LRELU   ] = OUTPUT_MODE != "CONV" && is_lrelu;

  /*
    DW BANKS
  */

  logic dw_s_valid, dw_m_ready;
  logic [IM_SHIFT_REGS:UNITS] mux_dw_s_ready, mux_dw_m_valid, mux_dw_m_last;
  logic [IM_SHIFT_REGS:UNITS][IM_SHIFT_REGS-1:0][WORD_WIDTH-1:0] mux_dw_m_data;

  function bit valid_n (input integer n);
    static integer k, s, shift, words;
    valid_n = 0;
    for (integer i_kh2 = 0; i_kh2 <= KH_MAX/2; i_kh2++)
      for (integer i_sh_1 = 0; i_sh_1 < SH_MAX; i_sh_1++)
        for (integer m = 1; m <= COPIES; m++) begin
          k     = i_kh2*2+1;
          s     = i_sh_1+1;
          shift = `CEIL(k,s)-1;
          words = m*UNITS + shift;
          if(`KSM_COMBS_EXPR & n==words) valid_n = 1;
        end
  endfunction

  generate
    for (genvar m_words = UNITS; m_words <= IM_SHIFT_REGS; m_words++) begin:N
      if (valid_n(m_words)) begin
        logic [m_words-1:0][WORD_WIDTH-1:0] dw_m_data;
        assign mux_dw_m_data[m_words] = dw_m_data;

        alex_axis_adapter_any #(
          .S_DATA_WIDTH  (S_PIXELS_WIDTH_LF),
          .M_DATA_WIDTH  (m_words*WORD_WIDTH),
          .S_KEEP_ENABLE (1),
          .M_KEEP_ENABLE (1),
          .S_KEEP_WIDTH  (S_PIXELS_WIDTH_LF/WORD_WIDTH),
          .M_KEEP_WIDTH  (m_words),
          .ID_ENABLE     (0),
          .DEST_ENABLE   (0),
          .USER_ENABLE   (0)
        ) DW (
          .clk           (aclk       ),
          .rst           (~aresetn   ),
          .s_axis_tdata  (s_data     ),
          .s_axis_tkeep  (s_keep     ),
          .s_axis_tvalid (dw_s_valid ),
          .s_axis_tlast  (s_last     ),
          .s_axis_tready (mux_dw_s_ready [m_words]),
          .m_axis_tdata  (dw_m_data),
          .m_axis_tready (dw_m_ready),
          .m_axis_tvalid (mux_dw_m_valid [m_words]),
          .m_axis_tlast  (mux_dw_m_last  [m_words])
        );
      end
    end
  endgenerate

  logic muxed_dw_s_ready, muxed_dw_m_valid, m_last;
  logic [IM_SHIFT_REGS-1:0][WORD_WIDTH-1:0] muxed_dw_m_data;
  assign muxed_dw_s_ready = mux_dw_s_ready [words];
  assign muxed_dw_m_valid = mux_dw_m_valid [words];
  assign m_last           = mux_dw_m_last  [words];
  assign muxed_dw_m_data  = mux_dw_m_data  [words];

  logic dw_m_beat, dw_m_last_beat;
  assign dw_m_beat      = dw_m_ready & muxed_dw_m_valid;
  assign dw_m_last_beat = dw_m_beat & m_last;

  /*
    ONES COUNTER
  */
  logic [BITS_CONFIG_COUNT-1:0] beats_config_1_lut [KH_MAX      /2:0][KW_MAX      /2:0];
  generate
    for(genvar i_kh2=0; i_kh2<=KH_MAX/2; i_kh2++)
      for(genvar i_kw2=0; i_kw2<=KW_MAX/2; i_kw2++)
        assign beats_config_1_lut[i_kh2][i_kw2] =  1-1; // lrelu_beats
  endgenerate

  logic [BITS_CONFIG_COUNT-1:0] ones_count_next, ones_count;
  logic ones_count_en, ones_last;

  assign ones_last = ones_count == beats_config_1_lut[kh2][kw2];

  register #(
    .WORD_WIDTH     (BITS_CONFIG_COUNT),
    .RESET_VALUE    (0)
  ) ONES_COUNT (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (ones_count_en),
    .data_in        (ones_count_next),
    .data_out       (ones_count)
  );

  // Counters for shift
  logic count_sh_en, count_sh_last;
  logic [BITS_SH    -1:0] count_sh_next , count_sh;

  assign count_sh_last = count_sh == sh_1;
  assign count_sh_next = count_sh_last ? 0 : count_sh + 1'b1;

  register #(
    .WORD_WIDTH     (BITS_SH),
    .RESET_VALUE    (0)
  ) COUNT_SH (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (count_sh_en),
    .data_in        (count_sh_next),
    .data_out       (count_sh)
  );

  // Calculate shift amount

  logic [BITS_KH-1:0] lut_ks_shift_general [KH_MAX/2:0][SH_MAX-1:0];
  logic [BITS_KH-1:0] lut_ks_shift_last    [KH_MAX/2:0][SH_MAX-1:0];

  generate
    for (genvar i_kh2 = 0; i_kh2 <= KH_MAX/2; i_kh2++)
      for (genvar i_sh_1 = 0; i_sh_1 < SH_MAX; i_sh_1++) begin
        
          localparam k = i_kh2*2+1;
          localparam s = i_sh_1+1;
          
          if (`KS_COMBS_EXPR) begin
            assign lut_ks_shift_general[i_kh2][i_sh_1] = `CEIL(k,s)-1;
            assign lut_ks_shift_last   [i_kh2][i_sh_1] = k/s       -1;
          end
      end
  endgenerate
  
  /*
    STATE MACHINE
    - One entire image is loaded into the DMA. TLAST goes HIGH at the end of the image
    * SET   - loads config into regs
    * ONES  - Keeps m_data = 1, for RELU config bits
    * PASS  - sends muxed_data out
    * BLOCK - wait until pipe is cleared
  */

  logic [1:0] state, state_next;
  localparam S_SET   = 0;
  localparam S_ONES  = 1;
  localparam S_PASS  = 2;
  localparam S_BLOCK = 3;

  // Next state decoder
  always_comb begin
    state_next = state;
    unique case (state)
      S_SET   : if (s_beat)               state_next = S_ONES ;
      S_ONES  : if (ones_last && m_ready) state_next = S_PASS ;
      S_PASS  : if (s_last_beat)
                  if (dw_m_last_beat)     state_next = S_SET  ;
                  else                    state_next = S_BLOCK;
      S_BLOCK : if (dw_m_last_beat)       state_next = S_SET  ;
    endcase
  end

  // Output decoder
  always_comb begin

    config_en       = 0;
    ones_count_en   = 1;
    ones_count_next = 0;
    m_data          = muxed_dw_m_data;
    count_sh_en     = 0;
    m_shift         = count_sh_last ? lut_ks_shift_last[kh2][sh_1] : lut_ks_shift_general[kh2][sh_1];
    m_ones          = 0;

    unique case (state)
      S_SET   : begin
                  config_en       = s_valid;
                  
                  s_ready         = 1;
                  dw_s_valid      = 0;
                  dw_m_ready      = 0;
                  m_valid         = 0;
                end
      S_ONES  : begin
                  ones_count_en   = m_ready;
                  ones_count_next = ones_count + 1;

                  s_ready         = muxed_dw_s_ready;
                  dw_s_valid      = s_valid;
                  dw_m_ready      = 0;
                  m_valid         = 1;

                  m_data          = WORD_WIDTH'(1'b1);
                  // m_data          = {2{WORD_WIDTH'(1'b1)}}; // after verification, change to {WORD_WIDTH'(1'b1)
                  m_shift         = 0;
                  m_ones          = 1;
                end
      S_PASS : begin
                  s_ready         = muxed_dw_s_ready;
                  dw_s_valid      = s_valid;
                  dw_m_ready      = m_ready;
                  m_valid         = muxed_dw_m_valid;

                  count_sh_en     = m_beat;
                end
      S_BLOCK : begin
                  s_ready         = 0;
                  dw_s_valid      = 0;
                  dw_m_ready      = m_ready;
                  m_valid         = muxed_dw_m_valid;

                  count_sh_en     = m_beat;
                end
    endcase
  end

  register #(
    .WORD_WIDTH     (2),
    .RESET_VALUE    (0)
  ) STATE (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (1'b1),
    .data_in        (state_next),
    .data_out       (state)
  );  

endmodule