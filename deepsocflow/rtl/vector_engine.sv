`timescale 1ns/1ps

module vector_engine #(
  parameter
    SRAM_RD_DATA_WIDTH = 32*8,
    SRAM_RD_DEPTH      = 8   , // number of bundles
    CW                 = 16  , // T, P, B counters
    AXI_ADDR_WIDTH     = 32  ,
    AXI_DATA_WIDTH     = 32  ,
    AXIS_USER_WIDTH    = 65  ,
    AXI_LEN_WIDTH      = 32  , // WIDTH_BPT
    AXI_TAG_WIDTH      = 8   , // WIDTH_TAG

  parameter  
    SRAM_WR_DEPTH = SRAM_RD_DEPTH * SRAM_RD_DATA_WIDTH / AXI_DATA_WIDTH, // 2048
    SRAM_RD_ADDR_WIDTH  = $clog2(SRAM_RD_DEPTH), // 11
    SRAM_WR_ADDR_WIDTH  = $clog2(SRAM_WR_DEPTH)
)(
  input  logic clk,
  input  logic rstn,

  // SRAM port
  input  logic reg_wr_en,
  output logic reg_wr_ack,
  input  logic [AXI_ADDR_WIDTH-1:0] reg_wr_addr,
  input  logic [AXI_DATA_WIDTH-1:0] reg_wr_data,
  input  logic reg_rd_en,
  output logic reg_rd_ack,
  input  logic [AXI_ADDR_WIDTH-1:0] reg_rd_addr, 
  output logic [AXI_DATA_WIDTH-1:0] reg_rd_data,

  // AXIS-Out monitoring signals
  input  logic o_ready, 
  input  logic o_valid,
  input  logic o_last,
  input  logic [AXI_LEN_WIDTH -1:0] o_bpt
);

  localparam N_REG = 16;

  localparam
    A_START        = 'h0,
    A_N_BUNDLES_1  = 'h1
    ; // Max 16 registers
  logic [N_REG-1:0][AXI_DATA_WIDTH-1:0] cfg;

  always_ff @(posedge clk)  // PS READ (1 clock latency)
    if (!rstn)          reg_rd_data <= '0;
    else if (reg_rd_en) reg_rd_data <= cfg[reg_rd_addr];

  wire start = 1'(cfg[A_START]);
  wire [CW-1:0] n_bundles_1 = CW'(cfg[A_N_BUNDLES_1]);

  typedef struct packed {
    logic [15:0]  n, l, kw, coe, h, w, ci, co, w_kw2, t, p, cm, cm_p0, on, oh, ow, oc, ch, ph, cw, pw, pkh, psh, pkw, psw;
    logic [31:0]  xp_words, b_offset, w_bpt, w_bpt_p0, x_bpt, x_bpt_p0, o_words, o_bytes;
    logic [7 :0]  ib_out, in_buffer_idx, out_buffer_idx, add_out_buffer_idx, add_in_buffer_idx;
    logic [7 :0]  is_bias, is_pool, is_flatten, is_softmax;
    logic [7 :0]  x_pad, b_val_shift, b_bias_shift, ca_nzero, ca_shift, ca_pl_scale, aa_nzero, aa_shift, aa_pl_scale, pa_nzero, pa_shift, pa_pl_scale, softmax_frac;
    logic [7 :0]  csh, csh_shift, psh_shift, csw, csw_shift, psw_shift, pool;
    logic [31:0]  softmax_max_f;
    logic [63:0]  header;
    logic [31:0]  debug_nhwc_words;
  } bundle_t;

  bundle_t ram_rd, max;

  // SRAM

  logic ram_rd_en, ram_wr_en, ram_v;
  logic [SRAM_RD_ADDR_WIDTH-1:0] ram_rd_addr;
  logic [SRAM_WR_ADDR_WIDTH-1:0] ram_wr_addr;
  logic [AXI_DATA_WIDTH    -1:0] ram_wr_data;
  logic [SRAM_RD_DATA_WIDTH-1:0] ram_rd_data;

  asym_ram_sdp_read_wider #(
    .WIDTHB     (SRAM_RD_DATA_WIDTH),
    .SIZEB      (SRAM_RD_DEPTH     ),
    .ADDRWIDTHB (SRAM_RD_ADDR_WIDTH),
    .WIDTHA     (AXI_DATA_WIDTH    ),
    .SIZEA      (SRAM_WR_DEPTH     ),
    .ADDRWIDTHA (SRAM_WR_ADDR_WIDTH)
  ) sdp_ram (
    .clkA  (clk        ), 
    .clkB  (clk        ), 
    .weA   (ram_wr_en  ), 
    .enaA  (ram_wr_en  ), 
    .addrA (ram_wr_addr), 
    .diA   (ram_wr_data), 
    .enaB  (ram_rd_en  ), 
    .addrB (ram_rd_addr), 
    .doB   (ram_rd_data)
  );

  always_comb begin
    ram_wr_en   = reg_wr_en && (reg_wr_addr >= N_REG);
    ram_wr_addr = SRAM_WR_ADDR_WIDTH'(reg_wr_addr - N_REG);
    ram_wr_data = reg_wr_data;
    ram_rd      = bundle_t'(ram_rd_data);
  end

  always_ff @(posedge clk)
    if (!rstn) ram_v <= 0;
    else       ram_v <= ram_rd_en;


  // Counters

  logic l_w_kw2;
  logic lc_b, lc_p, lc_t, lc_n, lc_l, lc_w_kw2, lc_coe, lc_wlast;
  logic en_b, en_p, en_t, en_n, en_l, en_w_kw2, en_coe, en_wlast;
  logic [CW-1:0] max_b, max_p, max_t, max_n, max_l, max_w_kw2, max_coe, max_wlast;
  logic [CW-1:0] i_b, i_p, i_t, i_n, i_l, i_w_kw2, i_w_kw2_next, i_coe, i_wlast;


  counter #(.W(CW)) C_WLAST (.clk(clk), .rstn_g(rstn), .rst_l(en_w_kw2), .en(en_wlast), .max_in(max_wlast               ), .last_clk(lc_wlast), .last(       ), .first( ), .count(i_wlast), .count_next());
  counter #(.W(CW)) C_COE   (.clk(clk), .rstn_g(rstn), .rst_l(ram_v   ), .en(lc_wlast), .max_in(CW'(32'(ram_rd.coe  )-1)), .last_clk(lc_coe  ), .last(       ), .first( ), .count(i_coe  ), .count_next());
  counter #(.W(CW)) C_W_KW2 (.clk(clk), .rstn_g(rstn), .rst_l(ram_v   ), .en(lc_coe  ), .max_in(CW'(32'(ram_rd.w_kw2)-1)), .last_clk(lc_w_kw2), .last(l_w_kw2), .first( ), .count(i_w_kw2), .count_next(i_w_kw2_next));
  counter #(.W(CW)) C_L     (.clk(clk), .rstn_g(rstn), .rst_l(ram_v   ), .en(lc_w_kw2), .max_in(CW'(32'(ram_rd.l    )-1)), .last_clk(lc_l    ), .last(       ), .first( ), .count(i_l    ), .count_next());
  counter #(.W(CW)) C_N     (.clk(clk), .rstn_g(rstn), .rst_l(ram_v   ), .en(lc_l    ), .max_in(CW'(32'(ram_rd.n    )-1)), .last_clk(lc_n    ), .last(       ), .first( ), .count(i_n    ), .count_next());
  counter #(.W(CW)) C_T     (.clk(clk), .rstn_g(rstn), .rst_l(ram_v   ), .en(lc_n    ), .max_in(CW'(32'(ram_rd.t    )-1)), .last_clk(lc_t    ), .last(       ), .first( ), .count(i_t    ), .count_next());
  counter #(.W(CW)) C_P     (.clk(clk), .rstn_g(rstn), .rst_l(ram_v   ), .en(lc_t    ), .max_in(CW'(32'(ram_rd.p    )-1)), .last_clk(lc_p    ), .last(       ), .first( ), .count(i_p    ), .count_next());
  counter #(.W(CW)) C_B     (.clk(clk), .rstn_g(rstn), .rst_l(start   ), .en(lc_p    ), .max_in(n_bundles_1             ), .last_clk(lc_b    ), .last(       ), .first( ), .count(i_b    ), .count_next());


  always_ff @(posedge clk)
    if (!rstn)      max <= bundle_t'(0);
    else if (ram_v) max <= ram_rd;
    
  always_comb begin
    en_wlast  = o_valid && o_ready;
    max_wlast = (i_w_kw2_next==0) ? max.kw/2 : 0;
  end

  

endmodule