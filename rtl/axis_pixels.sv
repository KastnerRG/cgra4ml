`timescale 1ns/1ps
`include "../params/params.svh"

module axis_pixels #(
  localparam  ROWS               = `ROWS                    ,
              KH_MAX             = `KH_MAX                  ,
              BITS_KH            = `BITS_KH                 ,
              BITS_KH2           = `BITS_KH2                ,
              BITS_IM_CIN        = `BITS_IM_CIN             ,
              BITS_IM_COLS       = `BITS_IM_COLS            ,
              BITS_IM_BLOCKS     = `BITS_IM_BLOCKS          ,
              WORD_WIDTH         = `WORD_WIDTH              ,
              RAM_EDGES_DEPTH    = `RAM_EDGES_DEPTH         , 
              SRAM_TYPE          = `SRAM_TYPE               ,
              EDGE_WORDS         =  KH_MAX/2,
              IM_SHIFT_REGS      =  ROWS + KH_MAX-1         ,
              BITS_IM_PASS       = $clog2(IM_SHIFT_REGS+1)  ,
              S_PIXELS_WIDTH_LF  = `S_PIXELS_WIDTH_LF       

  )(
    input logic aclk, aresetn,

    output logic s_ready,
    input  logic s_valid,
    input  logic s_last ,
    input  logic [S_PIXELS_WIDTH_LF/WORD_WIDTH-1:0][WORD_WIDTH-1:0] s_data,
    input  logic [S_PIXELS_WIDTH_LF/WORD_WIDTH-1:0] s_keep,

    input  logic m_ready,
    output logic m_valid,
    output logic [ROWS -1:0][WORD_WIDTH-1:0] m_data,
    output tuser_st m_user
  );

  logic dw_s_valid, dw_s_ready, dw_m_ready, dw_m_valid, dw_m_last;
  logic [ROWS+EDGE_WORDS-1:0][WORD_WIDTH-1:0] dw_m_data;

  alex_axis_adapter_any #(
    .S_DATA_WIDTH  (S_PIXELS_WIDTH_LF),
    .M_DATA_WIDTH  (WORD_WIDTH*(ROWS+EDGE_WORDS)),
    .S_KEEP_ENABLE (1),
    .M_KEEP_ENABLE (1),
    .S_KEEP_WIDTH  (S_PIXELS_WIDTH_LF/WORD_WIDTH),
    .M_KEEP_WIDTH  ((ROWS+EDGE_WORDS)),
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
    .s_axis_tready (dw_s_ready ),
    .m_axis_tdata  (dw_m_data  ),
    .m_axis_tready (dw_m_ready ),
    .m_axis_tvalid (dw_m_valid ),
    .m_axis_tlast  (dw_m_last  )
  );

  // State machine
  enum {SET, PASS , BLOCK} state;

  logic en_config, en_shift, en_copy, last_clk_kh, last_clk_ci, last_clk_w, last_l, m_last_reg, m_last, first_l, first_l_ram;
  logic [BITS_KH2      -1:0] ref_kh2, ref_kh2_in;
  logic [BITS_IM_CIN   -1:0] ref_ci_in;
  logic [BITS_IM_COLS  -1:0] ref_w_in ;
  logic [BITS_IM_BLOCKS-1:0] ref_l_in ;

  assign {ref_l_in, ref_w_in, ref_ci_in, ref_kh2_in} = s_data;

  wire dw_m_last_beat = dw_m_valid && dw_m_ready && dw_m_last;
  wire s_last_beat    = s_valid    && s_ready    && s_last;
  wire dw_m_beat      = dw_m_valid && dw_m_ready;
  wire m_last_beat    = m_ready    && m_valid    && m_last;
  wire m_beat         = m_ready    && m_valid;

  always_ff @(posedge aclk)
    if (!aresetn)                      state <= SET ;
    else case (state)
      SET   : if (s_valid && s_ready)  state <= PASS;
      PASS  : if (s_last_beat)
                if (m_last_beat)       state <= SET;
                else                   state <= BLOCK;
      BLOCK : if (m_last_beat)         state <= SET;
    endcase

  always_comb 
    unique case (state)
      SET  :  begin
                en_config    = 1;
                en_shift     = 0;
                en_copy      = 0;

                s_ready      = 1;
                dw_s_valid   = 0;
                dw_m_ready   = 0;
              end
      PASS  : begin
                en_config    = 0;
                en_shift     = m_ready;
                en_copy      = dw_m_valid && last_clk_kh;

                s_ready      = dw_s_ready;
                dw_s_valid   = s_valid;
                dw_m_ready   = en_copy;
              end
      BLOCK : begin
                en_config    = 0;
                en_shift     = m_ready;
                en_copy      = dw_m_valid && last_clk_kh;

                s_ready      = 0;
                dw_s_valid   = 0;
                dw_m_ready   = en_copy;
            end
    endcase

  always_ff @(posedge aclk)
    if (!aresetn || m_last_beat) {m_valid, m_last_reg} <= '0;
    else if (en_copy)            {m_valid, m_last_reg} <= {1'b1, dw_m_last};
  
  assign m_last = m_last_reg && last_clk_kh;

  // Counters: KH, CI, W, Blocks

  counter #(.W(BITS_KH),        .ALLOW_ONE(1)) C_KH (.clk(aclk), .reset(en_config), .en(en_shift   ), .max_in(ref_kh2_in*2 ), .reset_val(ref_kh2_in*2 ), .last_clk(last_clk_kh ));
  counter #(.W(BITS_IM_CIN                  )) C_CI (.clk(aclk), .reset(en_config), .en(last_clk_kh), .max_in(ref_ci_in    ), .reset_val('0           ), .last_clk(last_clk_ci ));
  counter #(.W(BITS_IM_COLS                 )) C_W  (.clk(aclk), .reset(en_config), .en(last_clk_ci), .max_in(ref_w_in     ), .reset_val('0           ), .last_clk(last_clk_w  ));
  counter #(.W(BITS_IM_BLOCKS), .ALLOW_ONE(1)) C_L  (.clk(aclk), .reset(en_config), .en(last_clk_w ), .max_in(ref_l_in     ), .reset_val('0           ), .last    (last_l      ), .first(first_l));

  // RAM
  logic [$clog2(RAM_EDGES_DEPTH) -1:0] ram_addr;
  logic [EDGE_WORDS-1:0][WORD_WIDTH-1:0] ram_dout, edge_top, edge_bot;

  assign edge_bot = dw_m_data[ROWS+EDGE_WORDS-1 : ROWS];
  assign edge_top = first_l ? '0 : ram_dout;

  always_ff @(posedge aclk)
    if (en_config || last_clk_w) ram_addr <= 0;
    else if (en_copy)            ram_addr <= ram_addr + 1;

  bram_sdp_shell #(
    .R_DEPTH      (RAM_EDGES_DEPTH),
    .R_DATA_WIDTH (WORD_WIDTH*EDGE_WORDS),
    .W_DATA_WIDTH (WORD_WIDTH*EDGE_WORDS),
    .LATENCY      (1),
    .TYPE         (SRAM_TYPE)
    ) RAM (
    // Write
    .clka  (aclk),    
    .ena   (en_copy),     
    .wea   (en_copy && !last_l),     
    .addra (ram_addr),  
    .dina  (edge_bot),   
    // Read
    .clkb  (aclk),   
    .enb   (en_copy && !first_l),     
    .addrb (ram_addr),  
    .doutb (ram_dout)
  );

  // Shift Regs
  logic [IM_SHIFT_REGS-1:0][WORD_WIDTH-1:0] shift_reg;

  always_ff @(posedge aclk)
    if      (en_copy ) shift_reg <= {dw_m_data, edge_top};
    else if (en_shift) shift_reg <= shift_reg >> WORD_WIDTH;

  // Out mux
  always_ff @(posedge aclk )
    if (en_config) ref_kh2 <= ref_kh2_in;

  always_comb
    for (int r=0; r<ROWS; r=r+1)
      m_data[r] = shift_reg[r + EDGE_WORDS-ref_kh2];

  // m_user
  assign m_user.is_not_max = 1;
  assign m_user.is_max     = 0;
  assign m_user.is_lrelu   = 0;

endmodule