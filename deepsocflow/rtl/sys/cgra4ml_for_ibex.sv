`timescale 1ns/1ps

`include "config_hw.svh"

module cgra4ml_for_ibex #(
  parameter int AXI_WIDTH       = `AXI_WIDTH,
  parameter int AXI_ID_WIDTH    = 6,
  parameter int AXI_ADDR_WIDTH  = 32,
  parameter int AXIL_WIDTH      = 32,
  parameter int AXIL_ADDR_WIDTH = 32,
  parameter int STRB_WIDTH      = AXIL_WIDTH/8
  
)(
  input  logic clk,
  input  logic rstn,

  // -------------------- Ibex DEVICE port (CPU -> SA registers) --------------------
  input  logic        dev_req_i,
  input  logic [31:0] dev_addr_i,
  input  logic        dev_we_i,
  input  logic [3:0]  dev_be_i,
  input  logic [31:0] dev_wdata_i,
  output logic        dev_gnt_o,
  output logic        dev_rvalid_o,
  output logic        dev_err_o,
  output logic [31:0] dev_rdata_o,

  // -------------------- Ibex HOST ports (SA DMA -> system memory) -----------------
  output logic        host_req_o,
  output logic [31:0] host_addr_o,
  output logic        host_we_o,
  output logic [3:0]  host_be_o,
  output logic [31:0] host_wdata_o,
  input  logic        host_gnt_i,
  input  logic        host_rvalid_i,
  input  logic        host_err_i,
  input  logic [31:0] host_rdata_i
);

  // ---------------- AXI-Lite wires (dev_to_maxil -> SA "top") ----------------
  logic [AXIL_ADDR_WIDTH-1:0]  axil_awaddr;
  logic                        axil_awvalid;
  logic                        axil_awready;
  logic [AXIL_WIDTH-1:0]       axil_wdata;
  logic [STRB_WIDTH-1:0]       axil_wstrb;
  logic                        axil_wvalid;
  logic                        axil_wready;
  logic [1:0]                  axil_bresp;
  logic                        axil_bvalid;
  logic                        axil_bready;
  logic [AXIL_ADDR_WIDTH-1:0]  axil_araddr;
  logic                        axil_arvalid;
  logic                        axil_arready;
  logic [AXIL_WIDTH-1:0]       axil_rdata;
  logic [1:0]                  axil_rresp;
  logic                        axil_rvalid;
  logic                        axil_rready;

  // ---------------- AXI4 wires (SA masters -> host bridges) ----------------
  localparam int DW   = AXI_WIDTH;
  localparam int STRB = DW/8;

  logic [AXI_ID_WIDTH-1:0]      axi_arid, axi_rid;
  logic [AXI_ADDR_WIDTH-1:0]    axi_araddr;
  logic [7:0]                   axi_arlen;
  logic [2:0]                   axi_arsize;
  logic [1:0]                   axi_arburst;
  logic                         axi_arvalid, axi_arready;
  logic [DW-1:0]                axi_rdata;
  logic [1:0]                   axi_rresp;
  logic                         axi_rlast, axi_rvalid, axi_rready;
  logic [AXI_ID_WIDTH-1:0]      axi_awid, axi_bid;
  logic [AXI_ADDR_WIDTH-1:0]    axi_awaddr;
  logic [7:0]                   axi_awlen;
  logic [2:0]                   axi_awsize;
  logic [1:0]                   axi_awburst;
  logic                         axi_awvalid, axi_awready;
  logic [DW-1:0]                axi_wdata;
  logic [STRB-1:0]              axi_wstrb;
  logic                         axi_wlast, axi_wvalid, axi_wready;
  logic [1:0]                   axi_bresp;
  logic                         axi_bvalid, axi_bready;

  // Make local offset addresses for AXI-Lite
  logic [AXIL_ADDR_WIDTH-1:0]  axil_awaddr_off, axil_araddr_off;
  assign axil_awaddr_off = axil_awaddr;
  assign axil_araddr_off = axil_araddr;

  // ---------------- Instantiate SA core ----------------
  top_axi_int u_sa (
    .clk  (clk),
    .rstn (rstn),

    .s_axil_awaddr (axil_awaddr_off),
    .s_axil_awprot (3'b000),
    .s_axil_awvalid(axil_awvalid),
    .s_axil_awready(axil_awready),
    .s_axil_wdata  (axil_wdata),
    .s_axil_wstrb  (axil_wstrb),
    .s_axil_wvalid (axil_wvalid),
    .s_axil_wready (axil_wready),
    .s_axil_bresp  (axil_bresp),
    .s_axil_bvalid (axil_bvalid),
    .s_axil_bready (axil_bready),
    .s_axil_araddr (axil_araddr_off),
    .s_axil_arprot (3'b000),
    .s_axil_arvalid(axil_arvalid),
    .s_axil_arready(axil_arready),
    .s_axil_rdata  (axil_rdata),
    .s_axil_rresp  (axil_rresp),
    .s_axil_rvalid (axil_rvalid),
    .s_axil_rready (axil_rready),

    .m_axi_arid    (axi_arid),
    .m_axi_araddr  (axi_araddr),
    .m_axi_arlen   (axi_arlen),
    .m_axi_arsize  (axi_arsize),
    .m_axi_arburst (axi_arburst),
    .m_axi_arlock  (),     // unused sideband
    .m_axi_arcache (),
    .m_axi_arprot  (),
    .m_axi_arvalid (axi_arvalid),
    .m_axi_arready (axi_arready),
    .m_axi_rid     (axi_rid),
    .m_axi_rdata   (axi_rdata),
    .m_axi_rresp   (axi_rresp),
    .m_axi_rlast   (axi_rlast),
    .m_axi_rvalid  (axi_rvalid),
    .m_axi_rready  (axi_rready),
    .m_axi_awid    (axi_awid),
    .m_axi_awaddr  (axi_awaddr),
    .m_axi_awlen   (axi_awlen),
    .m_axi_awsize  (axi_awsize),
    .m_axi_awburst (axi_awburst),
    .m_axi_awlock  (),
    .m_axi_awcache (),
    .m_axi_awprot  (),
    .m_axi_awvalid (axi_awvalid),
    .m_axi_awready (axi_awready),
    .m_axi_wdata   (axi_wdata),
    .m_axi_wstrb   (axi_wstrb),
    .m_axi_wlast   (axi_wlast),
    .m_axi_wvalid  (axi_wvalid),
    .m_axi_wready  (axi_wready),
    .m_axi_bid     (axi_bid),
    .m_axi_bresp   (axi_bresp),
    .m_axi_bvalid  (axi_bvalid),
    .m_axi_bready  (axi_bready)
  );

  // ---------------- dev_to_maxil: Ibex device -> AXI-Lite master ----------------
  dev_to_maxil #(
    .AXI_ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXIL_WIDTH)
  ) u_cfg (
    .clk   (clk),
    .rst_n (rstn),

    // Ibex device-side
    .data_req_i    (dev_req_i),
    .data_addr_i   (dev_addr_i),
    .data_we_i     (dev_we_i),
    .data_be_i     (dev_be_i),
    .data_wdata_i  (dev_wdata_i),
    .data_gnt_o    (dev_gnt_o),
    .data_rvalid_o (dev_rvalid_o),
    .data_err_o    (dev_err_o),
    .data_rdata_o  (dev_rdata_o),

    // AXI-Lite master
    .M_AXI_AWADDR  (axil_awaddr),
    .M_AXI_AWVALID (axil_awvalid),
    .M_AXI_AWREADY (axil_awready),

    .M_AXI_WDATA   (axil_wdata),
    .M_AXI_WSTRB   (axil_wstrb),
    .M_AXI_WVALID  (axil_wvalid),
    .M_AXI_WREADY  (axil_wready),

    .M_AXI_BRESP   (axil_bresp),
    .M_AXI_BVALID  (axil_bvalid),
    .M_AXI_BREADY  (axil_bready),

    .M_AXI_ARADDR  (axil_araddr),
    .M_AXI_ARVALID (axil_arvalid),
    .M_AXI_ARREADY (axil_arready),

    .M_AXI_RDATA   (axil_rdata),
    .M_AXI_RRESP   (axil_rresp),
    .M_AXI_RVALID  (axil_rvalid),
    .M_AXI_RREADY  (axil_rready)
  );

  // ---------------- saxi_to_host instances ----------------

  // === mm2s_0 (READ) -> host0 ===
  saxi_to_host #(
    .AXI_ID_WIDTH   (AXI_ID_WIDTH),
    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH (DW)
  ) u_h0 (
    .clk   (clk),
    .rst_n (rstn),

    // AR/R from SA master
    .s_axi_arid    (axi_arid),
    .s_axi_araddr  (axi_araddr),
    .s_axi_arlen   (axi_arlen),
    .s_axi_arsize  (axi_arsize),   // expect 3'b010 for 32-bit data
    .s_axi_arburst (axi_arburst),  // expect INCR (2'b01)
    .s_axi_arvalid (axi_arvalid),
    .s_axi_arready (axi_arready),
    .s_axi_rid     (axi_rid),
    .s_axi_rdata   (axi_rdata),
    .s_axi_rresp   (axi_rresp),
    .s_axi_rlast   (axi_rlast),
    .s_axi_rvalid  (axi_rvalid),
    .s_axi_rready  (axi_rready),

    // AW/W/B from SA write master
    .s_axi_awid    (axi_awid),
    .s_axi_awaddr  (axi_awaddr),
    .s_axi_awlen   (axi_awlen),
    .s_axi_awsize  (axi_awsize),    // expect 3'b010
    .s_axi_awburst (axi_awburst),   // expect INCR
    .s_axi_awvalid (axi_awvalid),
    .s_axi_awready (axi_awready),
    .s_axi_wdata   (axi_wdata),
    .s_axi_wstrb   (axi_wstrb),
    .s_axi_wlast   (axi_wlast),
    .s_axi_wvalid  (axi_wvalid),
    .s_axi_wready  (axi_wready),
    .s_axi_bid     (axi_bid),
    .s_axi_bresp   (axi_bresp),
    .s_axi_bvalid  (axi_bvalid),
    .s_axi_bready  (axi_bready),

    .data_req_o    (host_req_o),
    .data_addr_o   (host_addr_o),
    .data_we_o     (host_we_o),
    .data_be_o     (host_be_o),
    .data_wdata_o  (host_wdata_o),
    .data_gnt_i    (host_gnt_i),
    .data_rvalid_i (host_rvalid_i),
    .data_err_i    (host_err_i),
    .data_rdata_i  (host_rdata_i)
  );

endmodule