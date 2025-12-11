`timescale 1ns/1ps

module saxi_to_host #(
  parameter int AXI_ID_WIDTH    = 4,
  parameter int AXI_ADDR_WIDTH  = 32,
  parameter int AXI_DATA_WIDTH  = 32,   // must be 32
  parameter int AXI_STRB_WIDTH  = AXI_DATA_WIDTH/8
)(
  input  wire                         clk,
  input  wire                         rst_n,

  // ---------------- AXI4-Slave: Read Address ----------------
  input  wire [AXI_ID_WIDTH-1:0]      s_axi_arid,
  input  wire [AXI_ADDR_WIDTH-1:0]    s_axi_araddr,
  input  wire [7:0]                   s_axi_arlen,   // beats-1 (must be 0)
  input  wire [2:0]                   s_axi_arsize,  // must be 3'b010
  input  wire [1:0]                   s_axi_arburst, // INCR only (2'b01)
  input  wire                         s_axi_arvalid,
  output logic                        s_axi_arready,

  // ---------------- AXI4-Slave: Read Data --------------------
  output logic [AXI_ID_WIDTH-1:0]     s_axi_rid,
  output logic [AXI_DATA_WIDTH-1:0]   s_axi_rdata,
  output logic [1:0]                  s_axi_rresp,   // OKAY=2'b00, SLVERR=2'b10
  output logic                        s_axi_rlast,
  output logic                        s_axi_rvalid,
  input  wire                         s_axi_rready,

  // ---------------- AXI4-Slave: Write Address ----------------
  input  wire [AXI_ID_WIDTH-1:0]      s_axi_awid,
  input  wire [AXI_ADDR_WIDTH-1:0]    s_axi_awaddr,
  input  wire [7:0]                   s_axi_awlen,   // beats-1 (must be 0)
  input  wire [2:0]                   s_axi_awsize,  // must be 3'b010
  input  wire [1:0]                   s_axi_awburst, // INCR only
  input  wire                         s_axi_awvalid,
  output logic                        s_axi_awready,

  // ---------------- AXI4-Slave: Write Data -------------------
  input  wire [AXI_DATA_WIDTH-1:0]    s_axi_wdata,
  input  wire [AXI_STRB_WIDTH-1:0]    s_axi_wstrb,
  input  wire                         s_axi_wlast,
  input  wire                         s_axi_wvalid,
  output logic                        s_axi_wready,

  // ---------------- AXI4-Slave: Write Response ---------------
  output logic [AXI_ID_WIDTH-1:0]     s_axi_bid,
  output logic [1:0]                  s_axi_bresp,   // OKAY=2'b00, SLVERR=2'b10
  output logic                        s_axi_bvalid,
  input  wire                         s_axi_bready,

  // ---------------- Ibex LSU host port -----------------------
  output logic                        data_req_o,
  output logic [31:0]                 data_addr_o,   // byte address (unaligned allowed)
  output logic                        data_we_o,
  output logic [3:0]                  data_be_o,
  output logic [31:0]                 data_wdata_o,
  input  wire                         data_gnt_i,
  input  wire                         data_rvalid_i,
  input  wire                         data_err_i,
  input  wire [31:0]                  data_rdata_i
);

  // ---------------- Parameters / Local ----------------
  localparam logic [1:0] AXI_BURST_INCR = 2'b01;
  localparam logic [1:0] RESP_OKAY      = 2'b00;
  localparam logic [1:0] RESP_SLVERR    = 2'b10;

  initial begin
    if (AXI_DATA_WIDTH != 32) begin
      $error("AXI_DATA_WIDTH must be 32");
    end
  end

  typedef enum logic [2:0] {IDLE, R_ACTIVE, W_ACTIVE, ISSUE, WAIT_RSP} eng_e;
  eng_e eng_state, eng_state_n;

  // Read command regs
  logic                    rd_cmd_valid;
  logic [AXI_ID_WIDTH-1:0] rd_id;
  logic [31:0]             rd_addr;     // byte address (unaligned allowed)
  logic [7:0]              rd_len;      // beats remaining (inclusive count)
  logic                    rd_busy;     // burst accepted (address latched)

  // Write command regs
  logic                    wr_cmd_valid;
  logic [AXI_ID_WIDTH-1:0] wr_id;
  logic [31:0]             wr_addr;     // byte address (unaligned allowed)
  logic [7:0]              wr_len;
  logic                    wr_busy;

  // Write data buffer for current beat
  logic [31:0]             wr_data_q;
  logic [3:0]              wr_strb_q;
  logic                    wr_data_valid;

  // Engine bookkeeping
  logic                    cur_is_write;
  logic                    have_grant;
  logic                    error_seen;

  // R hold buffer (to obey RDATA stability while RVALID && !RREADY)
  logic                    r_hold_valid;
  logic [31:0]             r_hold_data;
  logic [1:0]              r_hold_resp;
  logic                    r_hold_last;

  // Next-beat address increment (32-bit, INCR)
  function automatic [31:0] next_addr(input [31:0] a);
    next_addr = a + 32'd4;
  endfunction

  // ---------------- AXI Address Acceptance ----------------
  // Don’t accept new bursts while there is any outstanding response we still need to send.
  wire r_resp_pending = s_axi_rvalid | r_hold_valid;
  wire b_resp_pending = s_axi_bvalid;

  // NOTE: alignment no longer checked here. Unaligned accesses are passed through.
  wire ar_ok = s_axi_arvalid &&
               (s_axi_arsize  == 3'b010) &&
               (s_axi_arburst == AXI_BURST_INCR) &&
               !rd_busy && !wr_busy &&
               (eng_state == IDLE) &&
               !r_resp_pending;

  wire aw_ok = s_axi_awvalid &&
               (s_axi_awsize  == 3'b010) &&
               (s_axi_awburst == AXI_BURST_INCR) &&
               !rd_busy && !wr_busy &&
               (eng_state == IDLE) &&
               !b_resp_pending;

  always_comb begin
    s_axi_arready = ar_ok;
    s_axi_awready = aw_ok;
  end

  // Latch read/write command when accepted
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_cmd_valid <= 1'b0;
      rd_busy      <= 1'b0;
      wr_cmd_valid <= 1'b0;
      wr_busy      <= 1'b0;

      rd_id        <= '0;
      wr_id        <= '0;
      rd_addr      <= '0;
      wr_addr      <= '0;
      rd_len       <= 8'd0;
      wr_len       <= 8'd0;
    end else begin
      if (ar_ok) begin
        rd_cmd_valid <= 1'b1;
        rd_busy      <= 1'b1;
        rd_id        <= s_axi_arid;
        rd_addr      <= s_axi_araddr;
        rd_len       <= s_axi_arlen + 8'd1; // beats
      end
      if (aw_ok) begin
        wr_cmd_valid <= 1'b1;
        wr_busy      <= 1'b1;
        wr_id        <= s_axi_awid;
        wr_addr      <= s_axi_awaddr;
        wr_len       <= s_axi_awlen + 8'd1;
      end
    end
  end

  // ---------------- Write Data Channel Handling ----------------
  wire want_wbeat = (eng_state==W_ACTIVE) && !wr_data_valid;

  always_comb begin
    s_axi_wready = want_wbeat;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_data_q     <= '0;
      wr_strb_q     <= '0;
      wr_data_valid <= 1'b0;
    end else begin
      if (s_axi_wvalid && s_axi_wready) begin
        wr_data_q     <= s_axi_wdata;
        wr_strb_q     <= s_axi_wstrb;
        wr_data_valid <= 1'b1;
      end
      // clear after LSU completion for that beat
      if ((eng_state==WAIT_RSP) && cur_is_write && data_rvalid_i) begin
        wr_data_valid <= 1'b0;
      end
    end
  end

  // ---------------- R/B channels & hold buffer ----------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s_axi_rvalid  <= 1'b0;
      s_axi_rlast   <= 1'b0;
      s_axi_rdata   <= '0;
      s_axi_rresp   <= RESP_OKAY;
      s_axi_rid     <= '0;

      s_axi_bvalid  <= 1'b0;
      s_axi_bresp   <= RESP_OKAY;
      s_axi_bid     <= '0;

      r_hold_valid  <= 1'b0;
      r_hold_data   <= '0;
      r_hold_resp   <= RESP_OKAY;
      r_hold_last   <= 1'b0;
    end else begin
      // ---- READ path ----
      // Capture LSU response ONLY when waiting for it and no unconsumed R is pending
      if (!cur_is_write && (eng_state==WAIT_RSP) && !r_hold_valid && !s_axi_rvalid && data_rvalid_i) begin
        r_hold_valid <= 1'b1;
        r_hold_data  <= data_rdata_i;
        r_hold_resp  <= (data_err_i || error_seen) ? RESP_SLVERR : RESP_OKAY;
        r_hold_last  <= (rd_len == 8'd1);
        // present on AXI R
        s_axi_rvalid <= 1'b1;
        s_axi_rdata  <= data_rdata_i;
        s_axi_rresp  <= (data_err_i || error_seen) ? RESP_SLVERR : RESP_OKAY;
        s_axi_rid    <= rd_id;
        s_axi_rlast  <= (rd_len == 8'd1);
      end
      // Hold RVALID high & keep data stable until master takes it
      else if (s_axi_rvalid && s_axi_rready) begin
        s_axi_rvalid <= 1'b0;
        s_axi_rlast  <= 1'b0;
        r_hold_valid <= 1'b0;
      end
      // else: keep RDATA/RRESP/RID/RLAST stable

      // ---- WRITE response (one per burst) ----
      if (cur_is_write && (eng_state==WAIT_RSP) && data_rvalid_i && (wr_len==8'd1)) begin
        s_axi_bvalid <= 1'b1;
        s_axi_bresp  <= (data_err_i || error_seen) ? RESP_SLVERR : RESP_OKAY;
        s_axi_bid    <= wr_id;
      end else if (s_axi_bvalid && s_axi_bready) begin
        s_axi_bvalid <= 1'b0;
      end
    end
  end

  // ---------------- LSU Engine FSM ----------------
  // Policy: prefer write if present; otherwise read.
  wire pick_write = wr_cmd_valid;
  wire pick_read  = rd_cmd_valid && !wr_cmd_valid;

  // issue fields
  logic [31:0] issue_addr;
  logic [3:0]  issue_be;
  logic [31:0] issue_wdata;

  // track grant & error accumulation
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      eng_state    <= IDLE;
      cur_is_write <= 1'b0;
      have_grant   <= 1'b0;
      error_seen   <= 1'b0;
    end else begin
      eng_state <= eng_state_n;

      if (eng_state==ISSUE) begin
        if (data_req_o && data_gnt_i) have_grant <= 1'b1;
      end else if (eng_state==WAIT_RSP && data_rvalid_i) begin
        have_grant <= 1'b0;
      end

      if (eng_state==WAIT_RSP && data_rvalid_i && data_err_i) begin
        error_seen <= 1'b1;
      end
      if (eng_state==IDLE) begin
        error_seen <= 1'b0;
      end
    end
  end

  // Beat counters & address update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // no-op
    end else begin
      if (eng_state==WAIT_RSP) begin
        if (cur_is_write) begin
          // write: decrement on LSU completion
          if (data_rvalid_i) begin
            if (wr_len != 0) begin
              wr_len  <= wr_len - 8'd1;
              wr_addr <= next_addr(wr_addr);
            end
          end
        end else begin
          // read: decrement on AXI R handshake (not LSU completion)
          if (s_axi_rvalid && s_axi_rready) begin
            if (rd_len != 0) begin
              rd_len  <= rd_len - 8'd1;
              rd_addr <= next_addr(rd_addr);
            end
          end
        end
      end

      // Clear busy/cmd_valid when the *channel* handshake for last beat completes
      if (!cur_is_write && (s_axi_rvalid && s_axi_rready) && (rd_len==8'd1)) begin
        rd_busy      <= 1'b0;
        rd_cmd_valid <= 1'b0;
      end
      if (cur_is_write && data_rvalid_i && (wr_len==8'd1)) begin
        wr_busy      <= 1'b0;
        wr_cmd_valid <= 1'b0;
      end
    end
  end

  // Compute current issue fields
  always_comb begin
    if (eng_state==W_ACTIVE || (eng_state==ISSUE && cur_is_write)) begin
      issue_addr  = wr_addr;
      issue_be    = wr_strb_q;
      issue_wdata = wr_data_q;
    end else begin
      issue_addr  = rd_addr;
      issue_be    = 4'hF; // full word read
      issue_wdata = 32'h00000000;
    end
  end

  // FSM transitions & LSU driving
  always_comb begin
    eng_state_n  = eng_state;
    data_req_o   = 1'b0;
    data_addr_o  = 32'd0;
    data_we_o    = 1'b0;
    data_be_o    = 4'h0;
    data_wdata_o = 32'd0;

    case (eng_state)
      IDLE: begin
        if (pick_write)      eng_state_n = W_ACTIVE;
        else if (pick_read)  eng_state_n = R_ACTIVE;
      end

      W_ACTIVE: begin
        if (wr_data_valid)   eng_state_n = ISSUE;
      end

      R_ACTIVE: begin
        eng_state_n = ISSUE;
      end

      ISSUE: begin
        data_req_o   = 1'b1;
        data_addr_o  = issue_addr;
        data_we_o    = cur_is_write;
        data_be_o    = issue_be;
        data_wdata_o = issue_wdata;
        if (data_gnt_i) eng_state_n = WAIT_RSP;
      end

      WAIT_RSP: begin
        if (cur_is_write) begin
          // writes: next beat when LSU responds
          if (data_rvalid_i) begin
            eng_state_n = (wr_len==8'd1) ? IDLE : W_ACTIVE;
          end
        end else begin
          // reads: next beat only after AXI R handshake (keeps RDATA stable)
          if (s_axi_rvalid && s_axi_rready) begin
            eng_state_n = (rd_len==8'd1) ? IDLE : R_ACTIVE;
          end
        end
      end

      default: eng_state_n = IDLE;
    endcase
  end

  // Set cur_is_write when entering a burst
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cur_is_write <= 1'b0;
    end else if (eng_state==IDLE) begin
      if (pick_write)      cur_is_write <= 1'b1;
      else if (pick_read)  cur_is_write <= 1'b0;
    end
  end

  // ---------------- Optional protocol sanity checks (simulation-only) ----------------
  // synopsys translate_off
  always_ff @(posedge clk) if (rst_n) begin
    if (s_axi_arvalid && s_axi_arready) begin
      if (s_axi_arsize  != 3'b010)          $error("saxi_to_host: arsize != 3'b010");
      if (s_axi_arburst != AXI_BURST_INCR)  $error("saxi_to_host: arburst != INCR");
      if (s_axi_arlen   != 8'd0)            $error("saxi_to_host: only single-beat reads supported (arlen != 0)");
      // NOTE: unaligned araddr is allowed now
      // if (s_axi_araddr[1:0] != 2'b00)    $warning("saxi_to_host: unaligned read address %h", s_axi_araddr);
    end
    if (s_axi_awvalid && s_axi_awready) begin
      if (s_axi_awsize  != 3'b010)          $error("saxi_to_host: awsize != 3'b010");
      if (s_axi_awburst != AXI_BURST_INCR)  $error("saxi_to_host: awburst != INCR");
      if (s_axi_awlen   != 8'd0)            $error("saxi_to_host: only single-beat writes supported (awlen != 0)");
      // NOTE: unaligned awaddr is allowed now
      // if (s_axi_awaddr[1:0] != 2'b00)    $warning("saxi_to_host: unaligned write address %h", s_axi_awaddr);
    end
    // Optional: check WLAST on write beat
    if (s_axi_wvalid && s_axi_wready && !s_axi_wlast)
      $warning("saxi_to_host: WLAST not observed on write beat (single-beat expected)");
  end
  // synopsys translate_on

endmodule
