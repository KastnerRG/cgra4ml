`timescale 1ns/1ps
`define VERILOG
`include "defines.svh"
`undef  VERILOG

module axi_int_reg_cgra4ml #(
  localparam  
    AXI_WIDTH               = `AXI_WIDTH   ,
    AXI_ID_WIDTH            = 6,
    AXI_ADDR_WIDTH          = 32,
    AXI_STRB_WIDTH          = (AXI_WIDTH/8)            

) (
    input  wire                   clk,
    input  wire                   rstn,

    // Register interface
    input  logic reg_wr_en,
    output logic reg_wr_ack,
    input  logic [AXI_ADDR_WIDTH-1:0] reg_wr_addr,
    input  logic [AXI_WIDTH-1:0] reg_wr_data,
    input  logic reg_rd_en,
    output logic reg_rd_ack,
    input  logic [AXI_ADDR_WIDTH-1:0] reg_rd_addr, 
    output logic [AXI_WIDTH-1:0] reg_rd_data,

    // AXI4 Master interface
    output wire [AXI_ID_WIDTH-1:0]    m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_awaddr,
    output wire [7:0]                 m_axi_awlen,
    output wire [2:0]                 m_axi_awsize,
    output wire [1:0]                 m_axi_awburst,
    output wire                       m_axi_awlock,
    output wire [3:0]                 m_axi_awcache,
    output wire [2:0]                 m_axi_awprot,
    output wire                       m_axi_awvalid,
    input  wire                       m_axi_awready,
    output wire [AXI_WIDTH   -1:0]    m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]  m_axi_wstrb,
    output wire                       m_axi_wlast,
    output wire                       m_axi_wvalid,
    input  wire                       m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_bid,
    input  wire [1:0]                 m_axi_bresp,
    input  wire                       m_axi_bvalid,
    output wire                       m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0]    m_axi_arid   ,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_araddr ,
    output wire [7:0]                 m_axi_arlen  ,
    output wire [2:0]                 m_axi_arsize ,
    output wire [1:0]                 m_axi_arburst,
    output wire                       m_axi_arlock ,
    output wire [3:0]                 m_axi_arcache,
    output wire [2:0]                 m_axi_arprot ,
    output wire                       m_axi_arvalid,
    input  wire                       m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_rid    ,
    input  wire [AXI_WIDTH   -1:0]    m_axi_rdata  ,
    input  wire [1:0]                 m_axi_rresp  ,
    input  wire                       m_axi_rlast  ,
    input  wire                       m_axi_rvalid ,
    output wire                       m_axi_rready 
);

localparam      
  ROWS                    = `ROWS               ,
  COLS                    = `COLS               ,
  X_BITS                  = `X_BITS             , 
  K_BITS                  = `K_BITS             , 
  Y_BITS                  = `Y_BITS             ,
  Y_OUT_BITS              = `Y_OUT_BITS         ,
  M_DATA_WIDTH_HF_CONV    = COLS  * ROWS  * Y_BITS,
  M_DATA_WIDTH_HF_CONV_DW = ROWS  * Y_BITS,
  // Full AXI
  DMA_ID_WIDTH            = AXI_ID_WIDTH-$clog2(3),
  AXI_MAX_BURST_LEN       = `AXI_MAX_BURST_LEN,
  // AXI-Lite
  AXIL_WIDTH              = 32,
  AXIL_ADDR_WIDTH         = 32,
  STRB_WIDTH              = 4,
  W_BPT                   = `W_BPT,
  OUT_ADDR_WIDTH          = 10,
  OUT_BITS                = 32,
// Parameters for controller
  SRAM_RD_DATA_WIDTH      = 256,
  SRAM_RD_DEPTH           = `MAX_N_BUNDLES,
  COUNTER_WIDTH           = 16,
  AXI_LEN_WIDTH           = 32,
  AXIL_BASE_ADDR          = `CONFIG_BASEADDR,
  TIMEOUT                 = 2, // since 0 gives error

// Alex AXI DMA RD                
  AXIS_ID_WIDTH           = DMA_ID_WIDTH,
  AXIS_KEEP_ENABLE        = 1,//(AXI_WIDTH>8),
  AXIS_KEEP_WIDTH         = (AXI_WIDTH/8),//(AXI_WIDTH/8),
  AXIS_LAST_ENABLE        = 1,
  AXIS_ID_ENABLE          = 0,
  AXIS_DEST_ENABLE        = 0,
  AXIS_DEST_WIDTH         = 8,
  HEADER_WIDTH            = `HEADER_WIDTH,
  AXIS_USER_WIDTH         = HEADER_WIDTH+1,
  LEN_WIDTH               = 32,
  TAG_WIDTH               = 8,
  ENABLE_SG               = 0,
  ENABLE_UNALIGNED        = 1;

// Controller with Alex DMAs: desc signals (including od tag) and status signals
wire [AXI_ADDR_WIDTH+AXI_LEN_WIDTH-1:0] m_od_axis_write_desc_tdata;
wire m_od_axis_write_desc_tvalid;
wire m_od_axis_write_desc_tready;
wire [TAG_WIDTH-1:0] m_od_axis_write_desc_tag;
wire [TAG_WIDTH-1:0] m_os_axis_write_desc_status_tag;
wire [3:0] m_os_axis_write_desc_status_error;
wire m_os_axis_write_desc_status_valid;


wire [AXI_ADDR_WIDTH+AXI_LEN_WIDTH-1:0] m_xd_axis_write_desc_tdata;
wire [AXIS_USER_WIDTH-1:0] m_xd_axis_write_desc_tuser;
wire m_xd_axis_write_desc_tvalid;
wire m_xd_axis_write_desc_tready;

wire [AXI_ADDR_WIDTH+AXI_LEN_WIDTH-1:0] m_wd_axis_write_desc_tdata;
wire [AXIS_USER_WIDTH-1:0] m_wd_axis_write_desc_tuser;
wire m_wd_axis_write_desc_tvalid;
wire m_wd_axis_write_desc_tready;

// AXIS input & outputs to DNN engine
wire                       s_axis_pixels_tready, s_axis_pixels_skid_tready ;
wire                       s_axis_pixels_tvalid, s_axis_pixels_skid_tvalid ;
wire                       s_axis_pixels_tlast , s_axis_pixels_skid_tlast  ;
wire [AXI_WIDTH  -1:0]     s_axis_pixels_tdata , s_axis_pixels_skid_tdata  ;
wire [AXI_WIDTH/8-1:0]     s_axis_pixels_tkeep , s_axis_pixels_skid_tkeep  ;
wire [AXIS_USER_WIDTH-1:0] s_axis_pixels_tuser , s_axis_pixels_skid_tuser  ;

wire                       s_axis_weights_tready, s_axis_weights_skid_tready;
wire                       s_axis_weights_tvalid, s_axis_weights_skid_tvalid;
wire                       s_axis_weights_tlast , s_axis_weights_skid_tlast ;
wire [AXI_WIDTH  -1:0]     s_axis_weights_tdata , s_axis_weights_skid_tdata ;
wire [AXI_WIDTH/8-1:0]     s_axis_weights_tkeep , s_axis_weights_skid_tkeep ;
wire [AXIS_USER_WIDTH-1:0] s_axis_weights_tuser , s_axis_weights_skid_tuser ;

    // AND, controller monitors the axis output status
wire                    m_axis_output_tready, m_axis_output_skid_tready;
wire                    m_axis_output_tvalid, m_axis_output_skid_tvalid;
wire                    m_axis_output_tlast , m_axis_output_skid_tlast ;
wire [AXI_WIDTH   -1:0] m_axis_output_tdata , m_axis_output_skid_tdata ;
wire [AXI_WIDTH/8 -1:0] m_axis_output_tkeep , m_axis_output_skid_tkeep ;
wire [W_BPT-1:0]        m_bytes_per_transfer, m_bytes_per_transfer_skid;

wire [AXIL_ADDR_WIDTH-1:0] reg_wr_addr_ctrl = (reg_wr_addr-AXIL_BASE_ADDR) >> 2;
wire [AXIL_ADDR_WIDTH-1:0] reg_rd_addr_ctrl = (reg_rd_addr-AXIL_BASE_ADDR) >> 2;

// AXI Master Interfaces
wire [DMA_ID_WIDTH-1:0]    m_axi_s2mm_awid   , m_axi_mm2s_1_awid   , m_axi_mm2s_0_awid   ;
wire [AXI_ADDR_WIDTH-1:0]  m_axi_s2mm_awaddr , m_axi_mm2s_1_awaddr , m_axi_mm2s_0_awaddr ;
wire [7:0]                 m_axi_s2mm_awlen  , m_axi_mm2s_1_awlen  , m_axi_mm2s_0_awlen  ;
wire [2:0]                 m_axi_s2mm_awsize , m_axi_mm2s_1_awsize , m_axi_mm2s_0_awsize ;
wire [1:0]                 m_axi_s2mm_awburst, m_axi_mm2s_1_awburst, m_axi_mm2s_0_awburst;
wire                       m_axi_s2mm_awlock , m_axi_mm2s_1_awlock , m_axi_mm2s_0_awlock ;
wire [3:0]                 m_axi_s2mm_awcache, m_axi_mm2s_1_awcache, m_axi_mm2s_0_awcache;
wire [2:0]                 m_axi_s2mm_awprot , m_axi_mm2s_1_awprot , m_axi_mm2s_0_awprot ;
wire                       m_axi_s2mm_awvalid, m_axi_mm2s_1_awvalid, m_axi_mm2s_0_awvalid;
wire                       m_axi_s2mm_awready, m_axi_mm2s_1_awready, m_axi_mm2s_0_awready;
wire [AXI_WIDTH   -1:0]    m_axi_s2mm_wdata  , m_axi_mm2s_1_wdata  , m_axi_mm2s_0_wdata  ;
wire [AXI_STRB_WIDTH-1:0]  m_axi_s2mm_wstrb  , m_axi_mm2s_1_wstrb  , m_axi_mm2s_0_wstrb  ;
wire                       m_axi_s2mm_wlast  , m_axi_mm2s_1_wlast  , m_axi_mm2s_0_wlast  ;
wire                       m_axi_s2mm_wvalid , m_axi_mm2s_1_wvalid , m_axi_mm2s_0_wvalid ;
wire                       m_axi_s2mm_wready , m_axi_mm2s_1_wready , m_axi_mm2s_0_wready ;
wire [DMA_ID_WIDTH-1:0]    m_axi_s2mm_bid    , m_axi_mm2s_1_bid    , m_axi_mm2s_0_bid    ;
wire [1:0]                 m_axi_s2mm_bresp  , m_axi_mm2s_1_bresp  , m_axi_mm2s_0_bresp  ;
wire                       m_axi_s2mm_bvalid , m_axi_mm2s_1_bvalid , m_axi_mm2s_0_bvalid ;
wire                       m_axi_s2mm_bready , m_axi_mm2s_1_bready , m_axi_mm2s_0_bready ;
wire [DMA_ID_WIDTH-1:0]    m_axi_s2mm_arid   , m_axi_mm2s_1_arid   , m_axi_mm2s_0_arid   ;
wire [AXI_ADDR_WIDTH-1:0]  m_axi_s2mm_araddr , m_axi_mm2s_1_araddr , m_axi_mm2s_0_araddr ;
wire [7:0]                 m_axi_s2mm_arlen  , m_axi_mm2s_1_arlen  , m_axi_mm2s_0_arlen  ;
wire [2:0]                 m_axi_s2mm_arsize , m_axi_mm2s_1_arsize , m_axi_mm2s_0_arsize ;
wire [1:0]                 m_axi_s2mm_arburst, m_axi_mm2s_1_arburst, m_axi_mm2s_0_arburst;
wire                       m_axi_s2mm_arlock , m_axi_mm2s_1_arlock , m_axi_mm2s_0_arlock ;
wire [3:0]                 m_axi_s2mm_arcache, m_axi_mm2s_1_arcache, m_axi_mm2s_0_arcache;
wire [2:0]                 m_axi_s2mm_arprot , m_axi_mm2s_1_arprot , m_axi_mm2s_0_arprot ;
wire                       m_axi_s2mm_arvalid, m_axi_mm2s_1_arvalid, m_axi_mm2s_0_arvalid;
wire                       m_axi_s2mm_arready, m_axi_mm2s_1_arready, m_axi_mm2s_0_arready;
wire [DMA_ID_WIDTH-1:0]    m_axi_s2mm_rid    , m_axi_mm2s_1_rid    , m_axi_mm2s_0_rid    ;
wire [AXI_WIDTH   -1:0]    m_axi_s2mm_rdata  , m_axi_mm2s_1_rdata  , m_axi_mm2s_0_rdata  ;
wire [1:0]                 m_axi_s2mm_rresp  , m_axi_mm2s_1_rresp  , m_axi_mm2s_0_rresp  ;
wire                       m_axi_s2mm_rlast  , m_axi_mm2s_1_rlast  , m_axi_mm2s_0_rlast  ;
wire                       m_axi_s2mm_rvalid , m_axi_mm2s_1_rvalid , m_axi_mm2s_0_rvalid ;
wire                       m_axi_s2mm_rready , m_axi_mm2s_1_rready , m_axi_mm2s_0_rready ;

assign {m_axi_mm2s_1_awid   , m_axi_mm2s_0_awid   } = 0; // i
assign {m_axi_mm2s_1_awaddr , m_axi_mm2s_0_awaddr } = 0; // i
assign {m_axi_mm2s_1_awlen  , m_axi_mm2s_0_awlen  } = 0; // i
assign {m_axi_mm2s_1_awsize , m_axi_mm2s_0_awsize } = 0; // i
assign {m_axi_mm2s_1_awburst, m_axi_mm2s_0_awburst} = 0; // i
assign {m_axi_mm2s_1_awlock , m_axi_mm2s_0_awlock } = 0; // i
assign {m_axi_mm2s_1_awcache, m_axi_mm2s_0_awcache} = 0; // i
assign {m_axi_mm2s_1_awprot , m_axi_mm2s_0_awprot } = 0; // i
assign {m_axi_mm2s_1_awvalid, m_axi_mm2s_0_awvalid} = 0; // i
assign {m_axi_mm2s_1_wdata  , m_axi_mm2s_0_wdata  } = 0; // i
assign {m_axi_mm2s_1_wstrb  , m_axi_mm2s_0_wstrb  } = 0; // i
assign {m_axi_mm2s_1_wlast  , m_axi_mm2s_0_wlast  } = 0; // i
assign {m_axi_mm2s_1_wvalid , m_axi_mm2s_0_wvalid } = 0; // i
assign {m_axi_mm2s_1_bready , m_axi_mm2s_0_bready } = 0; // i
assign m_axi_s2mm_arid    = 0; // i
assign m_axi_s2mm_araddr  = 0; // i
assign m_axi_s2mm_arlen   = 0; // i
assign m_axi_s2mm_arsize  = 0; // i
assign m_axi_s2mm_arburst = 0; // i
assign m_axi_s2mm_arlock  = 0; // i
assign m_axi_s2mm_arcache = 0; // i
assign m_axi_s2mm_arprot  = 0; // i
assign m_axi_s2mm_arvalid = 0; // i
assign m_axi_s2mm_rready  = 0; // i

dma_controller #(
    .SRAM_RD_DATA_WIDTH(SRAM_RD_DATA_WIDTH),
    .SRAM_RD_DEPTH(SRAM_RD_DEPTH),
    .COUNTER_WIDTH(COUNTER_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
    .AXI_DATA_WIDTH(AXIL_WIDTH),
    .AXI_LEN_WIDTH(AXI_LEN_WIDTH),
    .AXI_TAG_WIDTH(TAG_WIDTH)
) CONTROLLER (
    .clk(clk),
    .rstn(rstn),
    .reg_wr_en(reg_wr_en),
    .reg_wr_ack(reg_wr_ack),
    .reg_wr_addr(reg_wr_addr_ctrl[AXI_ADDR_WIDTH-1:0]),
    .reg_wr_data(reg_wr_data),
    .reg_rd_en(reg_rd_en),
    .reg_rd_ack(reg_rd_ack),
    .reg_rd_addr(reg_rd_addr_ctrl[AXI_ADDR_WIDTH-1:0]),
    .reg_rd_data(reg_rd_data),
    .o_ready(m_axis_output_skid_tready),
    .o_valid(m_axis_output_skid_tvalid),
    .o_last(m_axis_output_skid_tlast),
    .o_bpt(m_bytes_per_transfer_skid),
    .os_tag(m_os_axis_write_desc_status_tag),
    .os_error(m_os_axis_write_desc_status_error),
    .os_valid(m_os_axis_write_desc_status_valid),
    .m_od_addr(m_od_axis_write_desc_tdata[AXI_ADDR_WIDTH-1:0]),
    .m_od_len(m_od_axis_write_desc_tdata[AXI_ADDR_WIDTH+AXI_LEN_WIDTH-1:AXI_ADDR_WIDTH]),
    .m_od_valid(m_od_axis_write_desc_tvalid),
    .m_od_ready(m_od_axis_write_desc_tready),
    .m_od_tag(m_od_axis_write_desc_tag),
    .m_xd_addr(m_xd_axis_write_desc_tdata[AXI_ADDR_WIDTH-1:0]),
    .m_xd_user(m_xd_axis_write_desc_tuser),
    .m_xd_len(m_xd_axis_write_desc_tdata[AXI_ADDR_WIDTH+AXI_LEN_WIDTH-1:AXI_ADDR_WIDTH]),
    .m_xd_valid(m_xd_axis_write_desc_tvalid),
    .m_xd_ready(m_xd_axis_write_desc_tready),
    .m_wd_addr(m_wd_axis_write_desc_tdata[AXI_ADDR_WIDTH-1:0]),
    .m_wd_user(m_wd_axis_write_desc_tuser),
    .m_wd_len((m_wd_axis_write_desc_tdata[AXI_ADDR_WIDTH+AXI_LEN_WIDTH-1:AXI_ADDR_WIDTH])),
    .m_wd_valid(m_wd_axis_write_desc_tvalid),
    .m_wd_ready(m_wd_axis_write_desc_tready)
);

dnn_engine #(
    .ROWS(ROWS),
    .COLS(COLS),
    .X_BITS(X_BITS),
    .K_BITS(K_BITS),
    .Y_BITS(Y_BITS),
    .Y_OUT_BITS(Y_OUT_BITS),
    .HEADER_WIDTH(HEADER_WIDTH),
    .M_DATA_WIDTH_HF_CONV(M_DATA_WIDTH_HF_CONV),
    .M_DATA_WIDTH_HF_CONV_DW(M_DATA_WIDTH_HF_CONV_DW),
    .AXI_WIDTH(AXI_WIDTH),
    .W_BPT(W_BPT),
    .OUT_ADDR_WIDTH(OUT_ADDR_WIDTH),
    .OUT_BITS(OUT_BITS)
) ENGINE ( 
    .aclk(clk),
    .aresetn(rstn),
    .s_axis_pixels_tready(s_axis_pixels_tready),
    .s_axis_pixels_tvalid(s_axis_pixels_tvalid),
    .s_axis_pixels_tlast(s_axis_pixels_tlast),
    .s_axis_pixels_tdata(s_axis_pixels_tdata),
    .s_axis_pixels_tuser(s_axis_pixels_tuser),
    .s_axis_pixels_tkeep(s_axis_pixels_tkeep),
    .s_axis_weights_tready(s_axis_weights_tready),
    .s_axis_weights_tvalid(s_axis_weights_tvalid),
    .s_axis_weights_tlast(s_axis_weights_tlast),
    .s_axis_weights_tdata(s_axis_weights_tdata),
    .s_axis_weights_tuser(s_axis_weights_tuser),
    .s_axis_weights_tkeep(s_axis_weights_tkeep),
    .m_axis_tready(m_axis_output_tready),
    .m_axis_tvalid(m_axis_output_tvalid),
    .m_axis_tlast(m_axis_output_tlast),
    .m_axis_tdata(m_axis_output_tdata),
    .m_axis_tkeep(m_axis_output_tkeep),
    .m_bytes_per_transfer(m_bytes_per_transfer)
);

skid_buffer #(
  .WIDTH(AXI_WIDTH + AXI_WIDTH/8 + AXIS_USER_WIDTH + 1)
  ) SKID_X (
  .clk     (clk ),
  .rstn    (rstn),
  .s_ready (s_axis_pixels_skid_tready ),
  .s_valid (s_axis_pixels_skid_tvalid ),
  .s_data  ({s_axis_pixels_skid_tdata, s_axis_pixels_skid_tuser, s_axis_pixels_skid_tkeep, s_axis_pixels_skid_tlast}),
  .m_ready (s_axis_pixels_tready      ),
  .m_valid (s_axis_pixels_tvalid      ),
  .m_data  ({s_axis_pixels_tdata,      s_axis_pixels_tuser,      s_axis_pixels_tkeep,      s_axis_pixels_tlast     })
);

skid_buffer #(
  .WIDTH(AXI_WIDTH + AXI_WIDTH/8 + AXIS_USER_WIDTH + 1)
  ) SKID_W (
  .clk     (clk ),
  .rstn    (rstn),
  .s_ready (s_axis_weights_skid_tready ),
  .s_valid (s_axis_weights_skid_tvalid ),
  .s_data  ({s_axis_weights_skid_tdata, s_axis_weights_skid_tuser, s_axis_weights_skid_tkeep, s_axis_weights_skid_tlast}),
  .m_ready (s_axis_weights_tready      ),
  .m_valid (s_axis_weights_tvalid      ),
  .m_data  ({s_axis_weights_tdata,      s_axis_weights_tuser,      s_axis_weights_tkeep,      s_axis_weights_tlast     })
);

skid_buffer #(
  .WIDTH(AXI_WIDTH + AXI_WIDTH/8 + W_BPT + 1)
  ) SKID_Y (
  .clk     (clk ),
  .rstn    (rstn),
  .s_ready (m_axis_output_tready),
  .s_valid (m_axis_output_tvalid),
  .s_data  ({m_axis_output_tdata,      m_axis_output_tkeep,      m_bytes_per_transfer,        m_axis_output_tlast     }),
  .m_ready (m_axis_output_skid_tready),
  .m_valid (m_axis_output_skid_tvalid),
  .m_data  ({m_axis_output_skid_tdata, m_axis_output_skid_tkeep, m_bytes_per_transfer_skid,   m_axis_output_skid_tlast})
);

wire m_axi_mm2s_0_arvalid_masked = m_axi_mm2s_0_arvalid && s_axis_pixels_skid_tready;
wire m_axi_mm2s_0_arready_masked = m_axi_mm2s_0_arready && s_axis_pixels_skid_tready;

alex_axi_dma_rd #(
    .AXI_DATA_WIDTH(AXI_WIDTH   ),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(DMA_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .AXIS_DATA_WIDTH(AXI_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_ENABLE),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(AXIS_LAST_ENABLE),
    .AXIS_ID_ENABLE(AXIS_ID_ENABLE),
    .AXIS_ID_WIDTH(AXIS_ID_WIDTH),
    .AXIS_DEST_ENABLE(AXIS_DEST_ENABLE),
    .AXIS_DEST_WIDTH(AXIS_DEST_WIDTH),
    .AXIS_USER_ENABLE(1),
    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .ENABLE_SG(ENABLE_SG),
    .ENABLE_UNALIGNED(ENABLE_UNALIGNED),
    .AXI_ID(1)
) PIXEL_DMA (
    .clk(clk),
    .rstn(rstn),
    .s_axis_read_desc_tdata(m_xd_axis_write_desc_tdata),
    .s_axis_read_desc_tag({TAG_WIDTH{1'b0}}),
    .s_axis_read_desc_tid({DMA_ID_WIDTH{1'b0}}),
    .s_axis_read_desc_tdest({AXIS_DEST_WIDTH{1'b0}}),
    .s_axis_read_desc_tuser(m_xd_axis_write_desc_tuser),
    .s_axis_read_desc_tvalid(m_xd_axis_write_desc_tvalid),
    .s_axis_read_desc_tready(m_xd_axis_write_desc_tready),
    .m_axis_read_desc_status_tag(),
    .m_axis_read_desc_status_error(),
    .m_axis_read_desc_status_valid(),
    .m_axis_read_data_tdata(s_axis_pixels_skid_tdata),
    .m_axis_read_data_tkeep(s_axis_pixels_skid_tkeep),
    .m_axis_read_data_tvalid(s_axis_pixels_skid_tvalid),
    .m_axis_read_data_tready(s_axis_pixels_skid_tready),
    .m_axis_read_data_tlast(s_axis_pixels_skid_tlast),
    .m_axis_read_data_tid(),
    .m_axis_read_data_tdest(),
    .m_axis_read_data_tuser(s_axis_pixels_skid_tuser),
    .m_axi_arid(m_axi_mm2s_0_arid),
    .m_axi_araddr(m_axi_mm2s_0_araddr),
    .m_axi_arlen(m_axi_mm2s_0_arlen),
    .m_axi_arsize(m_axi_mm2s_0_arsize),
    .m_axi_arburst(m_axi_mm2s_0_arburst),
    .m_axi_arlock(m_axi_mm2s_0_arlock),
    .m_axi_arcache(m_axi_mm2s_0_arcache),
    .m_axi_arprot(m_axi_mm2s_0_arprot),
    .m_axi_arvalid(m_axi_mm2s_0_arvalid),
    .m_axi_arready(m_axi_mm2s_0_arready_masked),
    .m_axi_rid(m_axi_mm2s_0_rid),
    .m_axi_rdata(m_axi_mm2s_0_rdata),
    .m_axi_rresp(m_axi_mm2s_0_rresp),
    .m_axi_rlast(m_axi_mm2s_0_rlast),
    .m_axi_rvalid(m_axi_mm2s_0_rvalid),
    .m_axi_rready(m_axi_mm2s_0_rready),
    .enable(1'b1)
);

wire m_axi_mm2s_1_arvalid_masked = m_axi_mm2s_1_arvalid && s_axis_weights_skid_tready;
wire m_axi_mm2s_1_arready_masked = m_axi_mm2s_1_arready && s_axis_weights_skid_tready;

alex_axi_dma_rd #(
    .AXI_DATA_WIDTH(AXI_WIDTH   ),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(DMA_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .AXIS_DATA_WIDTH(AXI_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_ENABLE),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(AXIS_LAST_ENABLE),
    .AXIS_ID_ENABLE(AXIS_ID_ENABLE),
    .AXIS_ID_WIDTH(AXIS_ID_WIDTH),
    .AXIS_DEST_ENABLE(AXIS_DEST_ENABLE),
    .AXIS_DEST_WIDTH(AXIS_DEST_WIDTH),
    .AXIS_USER_ENABLE(1),
    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .ENABLE_SG(ENABLE_SG),
    .ENABLE_UNALIGNED(ENABLE_UNALIGNED),
    .AXI_ID(2)
) WEIGHTS_DMA (
    .clk(clk),
    .rstn(rstn),
    .s_axis_read_desc_tdata(m_wd_axis_write_desc_tdata),
    .s_axis_read_desc_tag({TAG_WIDTH{1'b0}}),
    .s_axis_read_desc_tid({DMA_ID_WIDTH{1'b0}}),
    .s_axis_read_desc_tdest({AXIS_DEST_WIDTH{1'b0}}),
    .s_axis_read_desc_tuser(m_wd_axis_write_desc_tuser),
    .s_axis_read_desc_tvalid(m_wd_axis_write_desc_tvalid),
    .s_axis_read_desc_tready(m_wd_axis_write_desc_tready),
    .m_axis_read_desc_status_tag(),
    .m_axis_read_desc_status_error(),
    .m_axis_read_desc_status_valid(),
    .m_axis_read_data_tdata(s_axis_weights_skid_tdata),
    .m_axis_read_data_tkeep(s_axis_weights_skid_tkeep),
    .m_axis_read_data_tvalid(s_axis_weights_skid_tvalid),
    .m_axis_read_data_tready(s_axis_weights_skid_tready),
    .m_axis_read_data_tlast(s_axis_weights_skid_tlast),
    .m_axis_read_data_tid(),
    .m_axis_read_data_tdest(),
    .m_axis_read_data_tuser(s_axis_weights_skid_tuser),
    .m_axi_arid(m_axi_mm2s_1_arid),
    .m_axi_araddr(m_axi_mm2s_1_araddr),
    .m_axi_arlen(m_axi_mm2s_1_arlen),
    .m_axi_arsize(m_axi_mm2s_1_arsize),
    .m_axi_arburst(m_axi_mm2s_1_arburst),
    .m_axi_arlock(m_axi_mm2s_1_arlock),
    .m_axi_arcache(m_axi_mm2s_1_arcache),
    .m_axi_arprot(m_axi_mm2s_1_arprot),
    .m_axi_arvalid(m_axi_mm2s_1_arvalid),
    .m_axi_arready(m_axi_mm2s_1_arready_masked),
    .m_axi_rid(m_axi_mm2s_1_rid),
    .m_axi_rdata(m_axi_mm2s_1_rdata),
    .m_axi_rresp(m_axi_mm2s_1_rresp),
    .m_axi_rlast(m_axi_mm2s_1_rlast),
    .m_axi_rvalid(m_axi_mm2s_1_rvalid),
    .m_axi_rready(m_axi_mm2s_1_rready),
    .enable(1'b1)
);

alex_axi_dma_wr #(
    .AXI_DATA_WIDTH(AXI_WIDTH   ),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(DMA_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .AXIS_DATA_WIDTH(AXI_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_ENABLE),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(AXIS_LAST_ENABLE),
    .AXIS_ID_ENABLE(AXIS_ID_ENABLE),
    .AXIS_ID_WIDTH(AXIS_ID_WIDTH),
    .AXIS_DEST_ENABLE(AXIS_DEST_ENABLE),
    .AXIS_DEST_WIDTH(AXIS_DEST_WIDTH),
    .AXIS_USER_ENABLE(0),
    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .ENABLE_SG(ENABLE_SG),
    .ENABLE_UNALIGNED(ENABLE_UNALIGNED),
    .AXI_ID(3)
) OUT_DMA (
    .clk(clk),
    .rstn(rstn),
    .s_axis_write_desc_tdata(m_od_axis_write_desc_tdata),
    .s_axis_write_desc_tag(m_od_axis_write_desc_tag),
    .s_axis_write_desc_tvalid(m_od_axis_write_desc_tvalid),
    .s_axis_write_desc_tready(m_od_axis_write_desc_tready),
    .m_axis_write_desc_status_len(),
    .m_axis_write_desc_status_tag(m_os_axis_write_desc_status_tag),
    .m_axis_write_desc_status_id(),
    .m_axis_write_desc_status_dest(),
    .m_axis_write_desc_status_user(),
    .m_axis_write_desc_status_error(m_os_axis_write_desc_status_error),
    .m_axis_write_desc_status_valid(m_os_axis_write_desc_status_valid),
    .s_axis_write_data_tdata(m_axis_output_skid_tdata),
    .s_axis_write_data_tkeep(m_axis_output_skid_tkeep),
    .s_axis_write_data_tvalid(m_axis_output_skid_tvalid),
    .s_axis_write_data_tready(m_axis_output_skid_tready),
    .s_axis_write_data_tlast(m_axis_output_skid_tlast),
    .s_axis_write_data_tid(),
    .s_axis_write_data_tdest(),
    .s_axis_write_data_tuser(),
    .m_axi_awid(m_axi_s2mm_awid),
    .m_axi_awaddr(m_axi_s2mm_awaddr),
    .m_axi_awlen(m_axi_s2mm_awlen),
    .m_axi_awsize(m_axi_s2mm_awsize),
    .m_axi_awburst(m_axi_s2mm_awburst),
    .m_axi_awlock(m_axi_s2mm_awlock),
    .m_axi_awcache(m_axi_s2mm_awcache),
    .m_axi_awprot(m_axi_s2mm_awprot),
    .m_axi_awvalid(m_axi_s2mm_awvalid),
    .m_axi_awready(m_axi_s2mm_awready),
    .m_axi_wdata(m_axi_s2mm_wdata),
    .m_axi_wstrb(m_axi_s2mm_wstrb),
    .m_axi_wlast(m_axi_s2mm_wlast),
    .m_axi_wvalid(m_axi_s2mm_wvalid),
    .m_axi_wready(m_axi_s2mm_wready),
    .m_axi_bid(m_axi_s2mm_bid),
    .m_axi_bresp(m_axi_s2mm_bresp),
    .m_axi_bvalid(m_axi_s2mm_bvalid),
    .m_axi_bready(m_axi_s2mm_bready),
    .enable(1'b1),
    .abort(1'b0)
);

localparam S_COUNT = 3;
localparam M_COUNT = 1;

axi_crossbar #(
  .S_COUNT         (S_COUNT                       ),
  .M_COUNT         (M_COUNT                       ),
  .DATA_WIDTH      (AXI_WIDTH                     ),
  .ADDR_WIDTH      (AXI_ADDR_WIDTH                ),
  .STRB_WIDTH      (AXI_STRB_WIDTH                ),
  .S_ID_WIDTH      (DMA_ID_WIDTH                  ),
  .M_ID_WIDTH      (AXI_ID_WIDTH                  ),
  // .AWUSER_ENABLE   (0                             ),
  // .AWUSER_WIDTH    (1                             ),
  // .WUSER_ENABLE    (0                             ),
  // .WUSER_WIDTH     (1                             ),
  // .BUSER_ENABLE    (0                             ),
  // .BUSER_WIDTH     (1                             ),
  // .ARUSER_ENABLE   (0                             ),
  // .ARUSER_WIDTH    (1                             ),
  // .RUSER_ENABLE    (0                             ),
  // .RUSER_WIDTH     (1                             ),
  // .S_THREADS       ({S_COUNT{32'd2}}              ),
  // .S_ACCEPT        ({S_COUNT{32'd16}}             ),
  .M_REGIONS       (1                             ),
  .M_BASE_ADDR     (0                             ),
  .M_ADDR_WIDTH    (AXI_ADDR_WIDTH                ),
  // .M_CONNECT_READ  ({M_COUNT{{S_COUNT{1'b1}}}}    ),
  // .M_CONNECT_WRITE ({M_COUNT{{S_COUNT{1'b1}}}}    ),
  // .M_ISSUE         ({M_COUNT{32'd4}}              ),
  // .M_SECURE        ({M_COUNT{1'b0}}               ),
  .S_AW_REG_TYPE   ({S_COUNT{2'd2}}               ),
  .S_W_REG_TYPE    ({S_COUNT{2'd2}}               ),
  .S_B_REG_TYPE    ({S_COUNT{2'd2}}               ),
  .S_AR_REG_TYPE   ({S_COUNT{2'd2}}               ),
  .S_R_REG_TYPE    ({S_COUNT{2'd2}}               ),
  .M_AW_REG_TYPE   ({M_COUNT{2'd2}}               ),
  .M_W_REG_TYPE    ({M_COUNT{2'd2}}               ),
  .M_B_REG_TYPE    ({M_COUNT{2'd2}}               ),
  .M_AR_REG_TYPE   ({M_COUNT{2'd2}}               ),
  .M_R_REG_TYPE    ({M_COUNT{2'd2}}               )
) AXI_INTC (
  .clk           (clk),
  .rstn          (rstn),
  
  .s_axi_awqos   (0),
  .s_axi_awuser  (0),
  .s_axi_wuser   (0),
  .s_axi_buser   (),
  .s_axi_arqos   (0),
  .s_axi_aruser  (0),
  .s_axi_ruser   (),

  .m_axi_awqos   (),
  .m_axi_awuser  (),
  .m_axi_wuser   (),
  .m_axi_buser   (),
  .m_axi_arqos   (),
  .m_axi_aruser  (),
  .m_axi_ruser   (0),
  .m_axi_awregion(),
  .m_axi_arregion(),

  .s_axi_awid    ({m_axi_s2mm_awid   , m_axi_mm2s_1_awid   , m_axi_mm2s_0_awid   }), // i
  .s_axi_awaddr  ({m_axi_s2mm_awaddr , m_axi_mm2s_1_awaddr , m_axi_mm2s_0_awaddr }), // i
  .s_axi_awlen   ({m_axi_s2mm_awlen  , m_axi_mm2s_1_awlen  , m_axi_mm2s_0_awlen  }), // i
  .s_axi_awsize  ({m_axi_s2mm_awsize , m_axi_mm2s_1_awsize , m_axi_mm2s_0_awsize }), // i
  .s_axi_awburst ({m_axi_s2mm_awburst, m_axi_mm2s_1_awburst, m_axi_mm2s_0_awburst}), // i
  .s_axi_awlock  ({m_axi_s2mm_awlock , m_axi_mm2s_1_awlock , m_axi_mm2s_0_awlock }), // i
  .s_axi_awcache ({m_axi_s2mm_awcache, m_axi_mm2s_1_awcache, m_axi_mm2s_0_awcache}), // i
  .s_axi_awprot  ({m_axi_s2mm_awprot , m_axi_mm2s_1_awprot , m_axi_mm2s_0_awprot }), // i
  .s_axi_awvalid ({m_axi_s2mm_awvalid, m_axi_mm2s_1_awvalid, m_axi_mm2s_0_awvalid}), // i
  .s_axi_awready ({m_axi_s2mm_awready, m_axi_mm2s_1_awready, m_axi_mm2s_0_awready}), // o
  .s_axi_wdata   ({m_axi_s2mm_wdata  , m_axi_mm2s_1_wdata  , m_axi_mm2s_0_wdata  }), // i
  .s_axi_wstrb   ({m_axi_s2mm_wstrb  , m_axi_mm2s_1_wstrb  , m_axi_mm2s_0_wstrb  }), // i
  .s_axi_wlast   ({m_axi_s2mm_wlast  , m_axi_mm2s_1_wlast  , m_axi_mm2s_0_wlast  }), // i
  .s_axi_wvalid  ({m_axi_s2mm_wvalid , m_axi_mm2s_1_wvalid , m_axi_mm2s_0_wvalid }), // i
  .s_axi_wready  ({m_axi_s2mm_wready , m_axi_mm2s_1_wready , m_axi_mm2s_0_wready }), // o
  .s_axi_bid     ({m_axi_s2mm_bid    , m_axi_mm2s_1_bid    , m_axi_mm2s_0_bid    }), // o
  .s_axi_bresp   ({m_axi_s2mm_bresp  , m_axi_mm2s_1_bresp  , m_axi_mm2s_0_bresp  }), // o
  .s_axi_bvalid  ({m_axi_s2mm_bvalid , m_axi_mm2s_1_bvalid , m_axi_mm2s_0_bvalid }), // o
  .s_axi_bready  ({m_axi_s2mm_bready , m_axi_mm2s_1_bready , m_axi_mm2s_0_bready }), // i
  .s_axi_arid    ({m_axi_s2mm_arid   , m_axi_mm2s_1_arid   , m_axi_mm2s_0_arid   }), // i
  .s_axi_araddr  ({m_axi_s2mm_araddr , m_axi_mm2s_1_araddr , m_axi_mm2s_0_araddr }), // i
  .s_axi_arlen   ({m_axi_s2mm_arlen  , m_axi_mm2s_1_arlen  , m_axi_mm2s_0_arlen  }), // i
  .s_axi_arsize  ({m_axi_s2mm_arsize , m_axi_mm2s_1_arsize , m_axi_mm2s_0_arsize }), // i
  .s_axi_arburst ({m_axi_s2mm_arburst, m_axi_mm2s_1_arburst, m_axi_mm2s_0_arburst}), // i
  .s_axi_arlock  ({m_axi_s2mm_arlock , m_axi_mm2s_1_arlock , m_axi_mm2s_0_arlock }), // i
  .s_axi_arcache ({m_axi_s2mm_arcache, m_axi_mm2s_1_arcache, m_axi_mm2s_0_arcache}), // i
  .s_axi_arprot  ({m_axi_s2mm_arprot , m_axi_mm2s_1_arprot , m_axi_mm2s_0_arprot }), // i
  .s_axi_arvalid ({m_axi_s2mm_arvalid, m_axi_mm2s_1_arvalid_masked, m_axi_mm2s_0_arvalid_masked}), // i
  .s_axi_arready ({m_axi_s2mm_arready, m_axi_mm2s_1_arready, m_axi_mm2s_0_arready}), // o
  .s_axi_rid     ({m_axi_s2mm_rid    , m_axi_mm2s_1_rid    , m_axi_mm2s_0_rid    }), // o
  .s_axi_rdata   ({m_axi_s2mm_rdata  , m_axi_mm2s_1_rdata  , m_axi_mm2s_0_rdata  }), // o
  .s_axi_rresp   ({m_axi_s2mm_rresp  , m_axi_mm2s_1_rresp  , m_axi_mm2s_0_rresp  }), // o
  .s_axi_rlast   ({m_axi_s2mm_rlast  , m_axi_mm2s_1_rlast  , m_axi_mm2s_0_rlast  }), // o
  .s_axi_rvalid  ({m_axi_s2mm_rvalid , m_axi_mm2s_1_rvalid , m_axi_mm2s_0_rvalid }), // o
  .s_axi_rready  ({m_axi_s2mm_rready , m_axi_mm2s_1_rready , m_axi_mm2s_0_rready }), // i



  .m_axi_awid    (m_axi_awid   ), // o
  .m_axi_awaddr  (m_axi_awaddr ), // o
  .m_axi_awlen   (m_axi_awlen  ), // o
  .m_axi_awsize  (m_axi_awsize ), // o
  .m_axi_awburst (m_axi_awburst), // o
  .m_axi_awlock  (m_axi_awlock ), // o
  .m_axi_awcache (m_axi_awcache), // o
  .m_axi_awprot  (m_axi_awprot ), // o
  .m_axi_awvalid (m_axi_awvalid), // o
  .m_axi_awready (m_axi_awready), // i
  .m_axi_wdata   (m_axi_wdata  ), // o
  .m_axi_wstrb   (m_axi_wstrb  ), // o
  .m_axi_wlast   (m_axi_wlast  ), // o
  .m_axi_wvalid  (m_axi_wvalid ), // o
  .m_axi_wready  (m_axi_wready ), // i
  .m_axi_bid     (m_axi_bid    ), // i
  .m_axi_bresp   (m_axi_bresp  ), // i
  .m_axi_bvalid  (m_axi_bvalid ), // i
  .m_axi_bready  (m_axi_bready ), // o
  .m_axi_arid    (m_axi_arid   ), // o
  .m_axi_araddr  (m_axi_araddr ), // o
  .m_axi_arlen   (m_axi_arlen  ), // o
  .m_axi_arsize  (m_axi_arsize ), // o
  .m_axi_arburst (m_axi_arburst), // o
  .m_axi_arlock  (m_axi_arlock ), // o
  .m_axi_arcache (m_axi_arcache), // o
  .m_axi_arprot  (m_axi_arprot ), // o
  .m_axi_arvalid (m_axi_arvalid), // o
  .m_axi_arready (m_axi_arready), // i
  .m_axi_rid     (m_axi_rid    ), // i
  .m_axi_rdata   (m_axi_rdata  ), // i
  .m_axi_rresp   (m_axi_rresp  ), // i
  .m_axi_rlast   (m_axi_rlast  ), // i
  .m_axi_rvalid  (m_axi_rvalid ), // i
  .m_axi_rready  (m_axi_rready )  // o
);

endmodule
