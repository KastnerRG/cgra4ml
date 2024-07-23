`timescale 1ns/1ps

module dma_controller #(
  parameter
    SRAM_RD_DATA_WIDTH = 32*8,
    SRAM_RD_DEPTH      = 8   , // number of bundles
    COUNTER_WIDTH      = 16  , // T, P, B counters
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
  (* mark_debug = "true" *) input  logic reg_wr_en,
  output logic reg_wr_ack,
  (* mark_debug = "true" *) input  logic [AXI_ADDR_WIDTH-1:0] reg_wr_addr,
  (* mark_debug = "true" *) input  logic [AXI_DATA_WIDTH-1:0] reg_wr_data,
  (* mark_debug = "true" *) input  logic reg_rd_en,
  output logic reg_rd_ack,
  (* mark_debug = "true" *) input  logic [AXI_ADDR_WIDTH-1:0] reg_rd_addr, 
  (* mark_debug = "true" *) output logic [AXI_DATA_WIDTH-1:0] reg_rd_data,

  // AXIS-Out monitoring signals
  input  logic o_ready, 
  input  logic o_valid,
  input  logic o_last,
  input  logic [AXI_LEN_WIDTH -1:0] o_bpt,  // Varies for each transfer

  
  /*
  input  logic [1:0] o_axi_bresp,
  input  logic       o_axi_bvalid,
  input  logic       o_axi_bready,
  */
  // M_AXI-OUT monitoring, to the ping-pong buffer on the PS side (?), we use the status from dma, instead of b_resp
  input logic  [AXI_TAG_WIDTH -1:0] os_tag,
  input logic  [3:0] os_error,
  input logic  os_valid,

  // DMA output descriptor
  (* mark_debug = "true" *) output logic [AXI_ADDR_WIDTH-1:0]  m_od_addr ,
  (* mark_debug = "true" *) output logic [AXI_LEN_WIDTH -1:0]  m_od_len  ,
  (* mark_debug = "true" *) output logic                       m_od_valid,
  (* mark_debug = "true" *) output logic [AXI_TAG_WIDTH -1:0]  m_od_tag  ,
  (* mark_debug = "true" *) input  logic                       m_od_ready,

  // DMA pixels descriptor
  (* mark_debug = "true" *) output logic [AXI_ADDR_WIDTH-1:0]  m_xd_addr ,
  (* mark_debug = "true" *) output logic [AXIS_USER_WIDTH-1:0] m_xd_user ,
  (* mark_debug = "true" *) output logic [AXI_LEN_WIDTH -1:0]  m_xd_len  ,
  (* mark_debug = "true" *) output logic                       m_xd_valid,
  (* mark_debug = "true" *) input  logic                       m_xd_ready,

  // DMA weights descriptor
  (* mark_debug = "true" *) output logic [AXI_ADDR_WIDTH-1:0]  m_wd_addr ,
  (* mark_debug = "true" *) output logic [AXIS_USER_WIDTH-1:0] m_wd_user ,
  (* mark_debug = "true" *) output logic [AXI_LEN_WIDTH -1:0]  m_wd_len  ,
  (* mark_debug = "true" *) output logic                       m_wd_valid,
  (* mark_debug = "true" *) input  logic                       m_wd_ready
);
  localparam // Addresses for local memory 0:15 is registers, rest is SRAM
    A_START        = 'h0,
    A_DONE_READ    = 'h1, // 2
    A_DONE_WRITE   = 'h3, // 2
    A_OCM_BASE     = 'h5, // 2
    A_WEIGHTS_BASE = 'h7,
    A_BUNDLE_DONE  = 'h8,
    A_N_BUNDLES_1  = 'h9,
    A_W_DONE       = 'hA, // W,X,O done are written by PL, read by PS to debug which one hangs
    A_X_DONE       = 'hB, 
    A_O_DONE       = 'hC
    ; // Max 16 registers
  (* mark_debug = "true" *) logic [12:0][AXI_DATA_WIDTH-1:0] cfg ;

  always_ff @(posedge clk)  // PS READ (1 clock latency)
    if (!rstn)          {reg_rd_data} <= '0;
    else if (reg_rd_en) begin
      //reg_rd_ack  <= reg_rd_en;
      reg_rd_data <= cfg[reg_rd_addr];
    end

  assign reg_wr_ack = 1'b1;
  assign reg_rd_ack = 1'b1;

  //------------------- BUNDLES SRAM  ---------------------------------------

  logic ram_rd_en, ram_wr_en;
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

  assign ram_wr_en   = reg_wr_en && (reg_wr_addr >= 16);
  assign ram_wr_addr = SRAM_WR_ADDR_WIDTH'(reg_wr_addr - 16);
  assign ram_wr_data = reg_wr_data;

   // ram_ are combinational from ram
  (* mark_debug = "true" *) logic [COUNTER_WIDTH-1:0] ram_max_t, ram_max_p;
  (* mark_debug = "true" *) logic [31:0] ram_w_bpt, ram_w_bpt_p0, ram_x_bpt, ram_x_bpt_p0, w_bpt, w_bpt_p0, x_bpt, x_bpt_p0;
  logic [AXI_ADDR_WIDTH-1:0] ram_xb_base_addr;
  logic [63:0] ram_header, x_header, w_header;
  assign {ram_header, ram_max_t, ram_max_p, ram_w_bpt, ram_w_bpt_p0, ram_x_bpt, ram_x_bpt_p0, ram_xb_base_addr} = 256'(ram_rd_data);

  // SRAM rd_en arbitration
  (* mark_debug = "true" *) logic w_ram_rd_en, x_ram_rd_en, w_ram_rd_valid, x_ram_rd_valid;
  (* mark_debug = "true" *) logic [SRAM_RD_ADDR_WIDTH-1:0] w_ram_rd_addr, x_ram_rd_addr;

  assign ram_rd_addr = x_ram_rd_en ? x_ram_rd_addr : w_ram_rd_addr;
  assign ram_rd_en   = x_ram_rd_en || w_ram_rd_en;

  always_ff @(posedge clk) // SRAM has latency = 1, pixels conroller gets priority, valids tell each controller SRAM data belongs to them
    if (!rstn)              {x_ram_rd_valid, w_ram_rd_valid} <= 2'b00;
    else
      if (x_ram_rd_en) {x_ram_rd_valid, w_ram_rd_valid} <= 2'b10; // priority to weights, at this time
      else if (w_ram_rd_en) {x_ram_rd_valid, w_ram_rd_valid} <= 2'b01;
      else                  {x_ram_rd_valid, w_ram_rd_valid} <= 2'b00;
  

  //------------------- WEIGHTS DMA CONTROLLER -----------------------------------

  logic en_wt, lc_wt, lc_wp, lc_wb, f_wp, set_n_bundles_w;
  logic [COUNTER_WIDTH-1:0] count_wb;
  enum  {W_IDLE, W_WAIT_RAM, W_EXEC} w_state, w_state_next;

  // Increment m_wd_addr
  always_ff @(posedge clk)
    if (!rstn)                 m_wd_addr <= 0;
    else if ((cfg[A_START][0])) m_wd_addr <= cfg[A_WEIGHTS_BASE];
    else if (en_wt)            m_wd_addr <= m_wd_addr + AXI_ADDR_WIDTH'(m_wd_len); // increment for every transfer

  // Weight DMA state machine
  always_comb begin
    w_state_next = w_state;
    unique case (w_state)
      W_IDLE    : if ((cfg[A_START][0]))  w_state_next = W_WAIT_RAM;
      W_WAIT_RAM: if (w_ram_rd_valid)    w_state_next = W_EXEC;
      W_EXEC    : if (lc_wb)             w_state_next = W_IDLE; // all bundles done, idle
                  else if (lc_wp)        w_state_next = W_WAIT_RAM; // this bundle done, request next bundle params
    endcase
  end
  always_ff @(posedge clk)
    if (!rstn) w_state <= W_IDLE;
    else       w_state <= w_state_next;

  // State decoding
  assign w_ram_rd_en   = w_state == W_WAIT_RAM && w_state_next == W_WAIT_RAM; // correction: rd should only be high for 1 cycle.
  assign w_ram_rd_addr = SRAM_RD_ADDR_WIDTH'(cfg[A_N_BUNDLES_1] - 1 - 32'(count_wb)); // count is decrementing, eg: 10 bundles: 9 - (9,8,7,6...0) = (0,1,2,3...9)
  assign m_wd_len      = f_wp ? w_bpt_p0 : w_bpt;
  assign m_wd_valid    = w_state == W_EXEC;
  assign en_wt         = m_wd_valid && m_wd_ready;
  assign m_wd_user     = {w_header, f_wp};

  always_ff @(posedge clk)
    if (!rstn)               {w_header, w_bpt_p0, w_bpt} <= 0;
    else if (w_ram_rd_valid) {w_header, w_bpt_p0, w_bpt} <= {ram_header, ram_w_bpt_p0, ram_w_bpt};

  

  counter #(.W(COUNTER_WIDTH)) C_WT (.clk(clk), .rstn_g(rstn), .rst_l(w_ram_rd_valid  ), .en(en_wt), .max_in(COUNTER_WIDTH'(32'(ram_max_t)-1    )), .last_clk(lc_wt), .last(), .first(    ), .count(        ));
  counter #(.W(COUNTER_WIDTH)) C_WP (.clk(clk), .rstn_g(rstn), .rst_l(w_ram_rd_valid  ), .en(lc_wt), .max_in(COUNTER_WIDTH'(32'(ram_max_p)-1    )), .last_clk(lc_wp), .last(), .first(f_wp), .count(        ));
  counter #(.W(COUNTER_WIDTH)) C_WB (.clk(clk), .rstn_g(rstn), .rst_l(1'(cfg[A_START])), .en(lc_wp), .max_in(COUNTER_WIDTH'(cfg[A_N_BUNDLES_1]-1)), .last_clk(lc_wb), .last(), .first(    ), .count(count_wb));


  //------------------- PIXELS DMA CONTROLLER -----------------------------------

  (* mark_debug = "true" *) logic [COUNTER_WIDTH-1:0] count_xb;
  (* mark_debug = "true" *) logic en_xt, lc_xt, lc_xp, lc_xb, f_xp, set_n_bundles_x;
  (* mark_debug = "true" *) enum  {X_IDLE, X_WAIT_RAM, X_WAIT_WRITE, X_EXEC} x_state, x_state_next;

  always_comb begin
    x_state_next = x_state;
    unique case (x_state)
      X_IDLE      : if (cfg[A_START][0])       x_state_next = X_WAIT_RAM;
      X_WAIT_RAM  : if (x_ram_rd_valid)         x_state_next = X_WAIT_WRITE;
      X_WAIT_WRITE: if (cfg[A_BUNDLE_DONE][0]) x_state_next = X_EXEC;
      X_EXEC      : if (lc_xb)                  x_state_next = X_IDLE; // all bundles done, idle
                    else if (lc_xp)             x_state_next = X_WAIT_RAM; // this bundle done, request next bundle params
    endcase
  end
  always_ff @(posedge clk)
    if (!rstn) x_state <= X_IDLE;
    else       x_state <= x_state_next;

  // State decoding
  assign x_ram_rd_en   = x_state == X_WAIT_RAM && x_state_next == X_WAIT_RAM;
  assign x_ram_rd_addr = SRAM_RD_ADDR_WIDTH'(cfg[A_N_BUNDLES_1] - 1 - 32'(count_xb)); // eg: 10 bundles: 9 - (9,8,7,6...0) = (0,1,2,3...9)
  assign m_xd_len      = f_xp ? x_bpt_p0 : x_bpt;
  assign m_xd_valid    = x_state == X_EXEC;
  assign en_xt         = m_xd_valid && m_xd_ready;
  assign m_xd_user     = {x_header, f_xp};

  // Increment m_xd_addr
  always_ff @(posedge clk)
    if (!rstn)               m_xd_addr <= 0;
    else if (x_ram_rd_valid) m_xd_addr <= ram_xb_base_addr; // ib==0 ? mem.x : mem.out_buffers[bundles[ib].in_buffer_idx]
    else if (lc_xt)          m_xd_addr <= m_xd_addr + AXI_ADDR_WIDTH'(m_xd_len); // increment address every p (after t transfers)

  always_ff @(posedge clk)
    if (!rstn)               {x_header, x_bpt_p0, x_bpt} <= 0;
    else if (x_ram_rd_valid) {x_header, x_bpt_p0, x_bpt} <= {ram_header, ram_x_bpt_p0, ram_x_bpt};

  (* mark_debug = "true" *) logic [COUNTER_WIDTH-1:0] count_xt_monitor;
  (* mark_debug = "true" *) logic count_xt_last_monitor;

  counter #(.W(COUNTER_WIDTH)) C_XT (.clk(clk), .rstn_g(rstn), .rst_l(x_ram_rd_valid  ), .en(en_xt), .max_in(COUNTER_WIDTH'(32'(ram_max_t)     - 1)), .last_clk(lc_xt), .last(count_xt_last_monitor), .first(    ), .count(count_xt_monitor));
  counter #(.W(COUNTER_WIDTH)) C_XP (.clk(clk), .rstn_g(rstn), .rst_l(x_ram_rd_valid  ), .en(lc_xt), .max_in(COUNTER_WIDTH'(32'(ram_max_p)     - 1)), .last_clk(lc_xp), .last(),                      .first(f_xp), .count(        ));
  counter #(.W(COUNTER_WIDTH)) C_XB (.clk(clk), .rstn_g(rstn), .rst_l(1'(cfg[A_START])), .en(lc_xp), .max_in(COUNTER_WIDTH'(cfg[A_N_BUNDLES_1] - 1)), .last_clk(lc_xb), .last(),                      .first(    ), .count(count_xb));


  //------------------- OUTPUT DMA CONTROLLER -----------------------------------

  logic [31:0] ocm_idx, ocm_idx_next; // index of current ocm bank being written by dma
  logic got_o_last;                   // to ensure o_bpt is for the NEXT (new) transfer, not currently ongoing transfer

  wire ocm_idx_1 = ocm_idx[0];
  assign ocm_idx_next = 32'(!ocm_idx_1); // next bank to be written by DMA
  assign m_od_len     = o_bpt;
  assign m_od_tag     = 8'(ocm_idx);
  //wire   o_axi_ok     = o_axi_bvalid && o_axi_bready && (o_axi_bresp == 2'b00); // why? what is the resp during transfer?
  wire o_axi_ok  =  os_valid && (os_error == 4'b0);

  always_ff @(posedge clk) // All cfg written in this always block
    if (!rstn) begin 
      cfg[A_START       ] <= 0; 
      cfg[A_DONE_READ +0] <= 32'd1;
      cfg[A_DONE_READ +1] <= 32'd1;
      cfg[A_DONE_WRITE+0] <= 32'd0;
      cfg[A_DONE_WRITE+1] <= 32'd0;
      cfg[A_OCM_BASE  +0] <= 32'd0;
      cfg[A_OCM_BASE  +1] <= 32'd0;
      cfg[A_WEIGHTS_BASE] <= 32'd0;
      cfg[A_BUNDLE_DONE ] <= 32'd1;
      cfg[A_N_BUNDLES_1 ] <= 32'd0;
      cfg[A_W_DONE      ] <= 32'd0;
      cfg[A_X_DONE      ] <= 32'd0;
      cfg[A_O_DONE      ] <= 32'd0;

      ocm_idx     <= 1; // before first transfer idx = 1, so first idx = 0
      m_od_addr   <= 0;
      m_od_valid  <= 0;
      got_o_last  <= 1; // to say first o_bpt comes from engine is for new data
    end else begin

      if (o_valid && o_ready && o_last) // previous packet completed(AXIS from engine to DMA) , only @ 1 cycle
        got_o_last <= 1;

      if (m_od_ready && o_valid && got_o_last) begin // DMA wants descriptor + o_bpt from engine is valid + o_bpt is for new data
        if (cfg[A_DONE_READ+ocm_idx_next][0]) begin  // wait for NEXT bank to done reading
          cfg[A_DONE_READ +ocm_idx_next] <= 0;   // clear done_read flag
          cfg[A_DONE_WRITE+ocm_idx_next] <= 0;   // tell PS NEXT bank is being written
          ocm_idx    <= ocm_idx_next;   // switch bank in next clock
          m_od_addr  <= cfg[A_OCM_BASE+ocm_idx_next];
          m_od_valid <= 1; // next clock, DMA will get valid; addr & length are given combinatinally
          got_o_last <= 0;
        end
      end
   
      if (m_od_valid && m_od_ready) // desc_valid stays high for only 1 clock with ready (this gets priority)
        m_od_valid <= 0;

      if (o_axi_ok) // DMA has completed writing THIS bank
        cfg[A_DONE_WRITE+os_tag] <= 1;

    // --------------------------------- OTHER REGISTERS -----------------------------------

      //
      if (cfg[A_START][0]) 
        cfg[A_START] <= 0; // written by PS after all config, stays high for only 1 clock

      if (cfg[A_BUNDLE_DONE][0] && x_state == X_WAIT_WRITE) // stays high until sampled by x_state
        cfg[A_BUNDLE_DONE] <= 0; 

      cfg[A_W_DONE] <= AXI_DATA_WIDTH'(w_state == W_IDLE);
      cfg[A_X_DONE] <= AXI_DATA_WIDTH'(x_state == X_IDLE);

      if (cfg[A_START][0] || o_valid) // not done if engine wants to send data
        cfg[A_O_DONE] <= 0;
      else if (got_o_last && o_axi_ok) // O has no state, so hv to infer from AXIS tlast & AXI resp
        cfg[A_O_DONE] <= 1;

      //reg_wr_ack <= reg_wr_en; // Write has 1 clock latency
      if (reg_wr_en && reg_wr_addr < 16) // PS has priority in writing to registers
        cfg[reg_wr_addr] <= reg_wr_data;
    end
endmodule