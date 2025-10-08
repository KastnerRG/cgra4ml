`timescale 1ns/1ps

module dev_to_maxil #(
  parameter int AXI_ADDR_WIDTH = 32,
  parameter int AXI_DATA_WIDTH = 32,
  // minimum gap (in cycles) between accepted READ requests
  parameter int POLL_GAP       = 8
)(
  input  logic                      clk,
  input  logic                      rst_n,

  // Ibex device-side (target)
  input  logic                      data_req_i,
  input  logic [31:0]               data_addr_i,    // word aligned
  input  logic                      data_we_i,
  input  logic [3:0]                data_be_i,
  input  logic [31:0]               data_wdata_i,
  output logic                      data_gnt_o,
  output logic                      data_rvalid_o,
  output logic                      data_err_o,
  output logic [31:0]               data_rdata_o,

  // AXI-Lite Master
  output logic [AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR,
  output logic                      M_AXI_AWVALID,
  input  logic                      M_AXI_AWREADY,

  output logic [AXI_DATA_WIDTH-1:0]   M_AXI_WDATA,
  output logic [AXI_DATA_WIDTH/8-1:0] M_AXI_WSTRB,
  output logic                        M_AXI_WVALID,
  input  logic                        M_AXI_WREADY,

  input  logic [1:0]                M_AXI_BRESP,
  input  logic                      M_AXI_BVALID,
  output logic                      M_AXI_BREADY,

  output logic [AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR,
  output logic                      M_AXI_ARVALID,
  input  logic                      M_AXI_ARREADY,

  input  logic [AXI_DATA_WIDTH-1:0] M_AXI_RDATA,
  input  logic [1:0]                M_AXI_RRESP,
  input  logic                      M_AXI_RVALID,
  output logic                      M_AXI_RREADY
);

  typedef enum logic [2:0] {
    S_IDLE,
    S_W_AW, S_W_W, S_W_B,
    S_R_AR, S_R_WAIT, S_R_R,
    S_RESP
  } state_e;

  state_e state, nstate;

  // Latched request (1-deep pending)
  logic        req_valid;      // we have a latched request
  logic [31:0] req_addr;
  logic        req_we;
  logic [3:0]  req_be;
  logic [31:0] req_wdata;

  // Response capture
  logic        resp_err;
  logic [31:0] resp_rdata;

  // Word-aligned address (defensive)
  wire [AXI_ADDR_WIDTH-1:0] req_addr_aligned = {req_addr[AXI_ADDR_WIDTH-1:2], 2'b00};

  // AXI handshakes
  wire aw_hs = M_AXI_AWVALID & M_AXI_AWREADY;
  wire w_hs  = M_AXI_WVALID  & M_AXI_WREADY;
  wire b_hs  = M_AXI_BVALID  & M_AXI_BREADY;
  wire ar_hs = M_AXI_ARVALID & M_AXI_ARREADY;
  wire r_hs  = M_AXI_RVALID  & M_AXI_RREADY;

  // -----------------------
  // READ throttle (cooldown)
  // -----------------------
  localparam int CW = (POLL_GAP <= 1) ? 1 : $clog2(POLL_GAP);
  logic [CW-1:0] rd_cooldown;
  wire           rd_ok = (POLL_GAP == 0) ? 1'b1 :
                         (POLL_GAP == 1) ? 1'b1 : (rd_cooldown == '0);

  // Accept/grant logic
  // Only grant when we can actually move out of IDLE next cycle,
  // and (for reads) when the cooldown allows.
  wire can_accept_read  = rd_ok;
  wire can_accept_write = 1'b1;

  wire want_read  = data_req_i && !data_we_i;
  wire want_write = data_req_i &&  data_we_i;

  wire can_grant = (state == S_IDLE) && !req_valid &&
                   ( (want_write && can_accept_write) ||
                     (want_read  && can_accept_read) );

  // -----------------------
  // Sequential
  // -----------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      req_valid   <= 1'b0;
      req_addr    <= '0;
      req_we      <= 1'b0;
      req_be      <= '0;
      req_wdata   <= '0;
      resp_err    <= 1'b0;
      resp_rdata  <= '0;
      rd_cooldown <= '0;
    end else begin
      state <= nstate;

      // Latch request only on "grant"
      if (can_grant) begin
        req_valid <= 1'b1;
        req_addr  <= data_addr_i;
        req_we    <= data_we_i;
        req_be    <= data_be_i;
        req_wdata <= data_wdata_i;
        // start cooldown if this is a READ we are about to issue
        if (!data_we_i && POLL_GAP > 1)
          rd_cooldown <= POLL_GAP[CW-1:0] - 1;
      end else begin
        // cooldown counts down each cycle
        if (POLL_GAP > 1 && rd_cooldown != '0)
          rd_cooldown <= rd_cooldown - 1'b1;
      end

      // Clear pending once we complete the AXI transaction (enter RESP)
      if (state == S_RESP && nstate == S_IDLE) begin
        req_valid <= 1'b0;
      end

      // Write response
      if (b_hs) begin
        resp_err <= (M_AXI_BRESP != 2'b00);
      end

      // Read response
      if (r_hs) begin
        resp_err   <= (M_AXI_RRESP != 2'b00);
        resp_rdata <= M_AXI_RDATA;
      end
    end
  end

  // -----------------------
  // Next-state
  // -----------------------
  always_comb begin
    nstate = state;
    unique case (state)
      S_IDLE: begin
        if (req_valid) begin
          nstate = req_we ? S_W_AW : S_R_AR;
        end
      end

      // WRITE serialized
      S_W_AW:    if (aw_hs)  nstate = S_W_W;
      S_W_W:     if (w_hs)   nstate = S_W_B;
      S_W_B:     if (b_hs)   nstate = S_RESP;

      // READ with 1-cycle guard
      S_R_AR:    if (ar_hs)  nstate = S_R_WAIT;
      S_R_WAIT:              nstate = S_R_R;     // one full cycle after AR
      S_R_R:     if (r_hs)   nstate = S_RESP;

      S_RESP:               nstate = S_IDLE;
      default:              nstate = S_IDLE;
    endcase
  end

  // -----------------------
  // Drive AXI & Ibex pulses
  // -----------------------
  always_comb begin
    // Defaults
    M_AXI_AWADDR  = req_addr_aligned;
    M_AXI_WDATA   = req_wdata;
    M_AXI_WSTRB   = req_be;
    M_AXI_ARADDR  = req_addr_aligned;

    M_AXI_AWVALID = (state == S_W_AW);
    M_AXI_WVALID  = (state == S_W_W);
    M_AXI_BREADY  = (state == S_W_B);

    M_AXI_ARVALID = (state == S_R_AR);
    M_AXI_RREADY  = (state == S_R_R);   // do not accept zero-latency R

    // Device-side handshake:
    // Grant only when we actually capture a request.
    data_gnt_o    = can_grant;

    // Response back
    data_rvalid_o = (state == S_RESP);
    data_err_o    = (state == S_RESP) ? resp_err   : 1'b0;
    data_rdata_o  = (state == S_RESP) ? resp_rdata : 32'h0;
  end

endmodule
