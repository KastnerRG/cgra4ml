/* 
    Top module for simulation
    Components
    RTL on-chip Top
        - DNN engine
        - Controller
            -BRAM and register
        - axilite interface (connected but not used in simulation), we write to controller reg directly using DPI-C
        - 3 Alex DMAs
    Top module for simulation also includes 3 zip cpus converting AXI4 requests to ram rw requests
    Unused ports: connect 0 for input, do not connect for output
*/
/*
    TODO:
        - Merge the params
        - Addr convertion PS (byte-addressed) to PL (word-addressed)
*/
`timescale 1ns/1ps
`define VERILOG
`include "defines.svh"
`undef  VERILOG

module axi_cgra4ml #(
                // For engine
    parameter   ROWS                    = `ROWS               ,
                COLS                    = `COLS               ,
                X_BITS                  = `X_BITS             , 
                K_BITS                  = `K_BITS             , 
                Y_BITS                  = `Y_BITS             ,
                Y_OUT_BITS              = `Y_OUT_BITS         ,
                M_DATA_WIDTH_HF_CONV    = COLS  * ROWS  * Y_BITS,
                M_DATA_WIDTH_HF_CONV_DW = ROWS  * Y_BITS,

                // Full AXI
                AXI_WIDTH               = `AXI_WIDTH   ,
                AXI_ID_WIDTH            = 6,
                AXI_STRB_WIDTH          = (AXI_WIDTH/8),
                AXI_MAX_BURST_LEN       = `AXI_MAX_BURST_LEN,
                AXI_ADDR_WIDTH          = 32,
                // AXI-Lite
                AXIL_WIDTH              = 32,
                AXIL_ADDR_WIDTH              = 40,
                STRB_WIDTH              = 4,
                W_BPT                   = `W_BPT              

) (
    // axilite interface for configuration
    input  wire                   clk,
    input  wire                   rstn,

    /*
     * AXI-Lite slave interface
     */
    input  wire [AXIL_ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire [2:0]             s_axil_awprot,
    input  wire                   s_axil_awvalid,
    output wire                   s_axil_awready,
    input  wire [AXIL_WIDTH-1:0]  s_axil_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axil_wstrb,
    input  wire                   s_axil_wvalid,
    output wire                   s_axil_wready,
    output wire [1:0]             s_axil_bresp,
    output wire                   s_axil_bvalid,
    input  wire                   s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire [2:0]             s_axil_arprot,
    input  wire                   s_axil_arvalid,
    output wire                   s_axil_arready,
    output wire [AXIL_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]             s_axil_rresp,
    output wire                   s_axil_rvalid,
    input  wire                   s_axil_rready,
    /*
        * AXI 4 Master interface
    */
    // Pixel
    output wire [AXI_ID_WIDTH-1:0]    m_axi_pixel_arid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_pixel_araddr,
    output wire [7:0]                 m_axi_pixel_arlen,
    output wire [2:0]                 m_axi_pixel_arsize,
    output wire [1:0]                 m_axi_pixel_arburst,
    output wire                       m_axi_pixel_arlock,
    output wire [3:0]                 m_axi_pixel_arcache,
    output wire [2:0]                 m_axi_pixel_arprot,
    output wire                       m_axi_pixel_arvalid,
    input  wire                       m_axi_pixel_arready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_pixel_rid,
    input  wire [AXI_WIDTH   -1:0]    m_axi_pixel_rdata,
    input  wire [1:0]                 m_axi_pixel_rresp,
    input  wire                       m_axi_pixel_rlast,
    input  wire                       m_axi_pixel_rvalid,
    output wire                       m_axi_pixel_rready,
    // Weights
    output wire [AXI_ID_WIDTH-1:0]    m_axi_weights_arid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_weights_araddr,
    output wire [7:0]                 m_axi_weights_arlen,
    output wire [2:0]                 m_axi_weights_arsize,
    output wire [1:0]                 m_axi_weights_arburst,
    output wire                       m_axi_weights_arlock,
    output wire [3:0]                 m_axi_weights_arcache,
    output wire [2:0]                 m_axi_weights_arprot,
    output wire                       m_axi_weights_arvalid,
    input  wire                       m_axi_weights_arready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_weights_rid,
    input  wire [AXI_WIDTH   -1:0]  m_axi_weights_rdata,
    input  wire [1:0]                 m_axi_weights_rresp,
    input  wire                       m_axi_weights_rlast,
    input  wire                       m_axi_weights_rvalid,
    output wire                       m_axi_weights_rready,
    // Output
    output wire [AXI_ID_WIDTH-1:0]    m_axi_output_awid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_output_awaddr,
    output wire [7:0]                 m_axi_output_awlen,
    output wire [2:0]                 m_axi_output_awsize,
    output wire [1:0]                 m_axi_output_awburst,
    output wire                       m_axi_output_awlock,
    output wire [3:0]                 m_axi_output_awcache,
    output wire [2:0]                 m_axi_output_awprot,
    output wire                       m_axi_output_awvalid,
    input  wire                       m_axi_output_awready,
    (* mark_debug = "true" *) output wire [AXI_WIDTH   -1:0]  m_axi_output_wdata,
    (* mark_debug = "true" *) output wire [AXI_STRB_WIDTH-1:0]  m_axi_output_wstrb,
    (* mark_debug = "true" *) output wire                       m_axi_output_wlast,
    (* mark_debug = "true" *) output wire                       m_axi_output_wvalid,
    (* mark_debug = "true" *) input  wire                       m_axi_output_wready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_output_bid,
    input  wire [1:0]                 m_axi_output_bresp,
    input  wire                       m_axi_output_bvalid,
    output wire                       m_axi_output_bready

);

localparam      OUT_ADDR_WIDTH          = 10,
                OUT_BITS                = 32,
    // Parameters for controller
                SRAM_RD_DATA_WIDTH      = 256,
                SRAM_RD_DEPTH           = `MAX_N_BUNDLES,
                COUNTER_WIDTH           = 16,
                AXI_LEN_WIDTH           = 32,
                AXIL_BASE_ADDR          = `CONFIG_BASEADDR,
                TIMEOUT                 = 2, // since 0 gives error

    // Alex AXI DMA RD                
                AXIS_ID_WIDTH           = 6,
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
    

// Wires connecting AXIL2RAM to CONTROLLER
wire [AXIL_ADDR_WIDTH-1:0] reg_wr_addr;
wire [AXIL_WIDTH-1:0] reg_wr_data;
wire [STRB_WIDTH-1:0] reg_wr_strb;
wire reg_wr_en;
wire reg_wr_ack;
wire [AXIL_ADDR_WIDTH-1:0] reg_rd_addr;
wire reg_rd_en;
wire [AXIL_WIDTH-1:0] reg_rd_data;
wire reg_rd_ack;

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
wire s_axis_pixels_tready;
wire s_axis_pixels_tvalid;
wire s_axis_pixels_tlast ;
wire [AXI_WIDTH  -1:0]   s_axis_pixels_tdata;
wire [AXI_WIDTH/8-1:0]   s_axis_pixels_tkeep;
wire [AXIS_USER_WIDTH-1:0] s_axis_pixels_tuser;

wire s_axis_weights_tready;
wire s_axis_weights_tvalid;
wire s_axis_weights_tlast ;
wire [AXI_WIDTH  -1:0]  s_axis_weights_tdata;
wire [AXI_WIDTH/8-1:0]  s_axis_weights_tkeep;
wire [AXIS_USER_WIDTH-1:0] s_axis_weights_tuser;

    // AND, controller monitors the axis output status
wire m_axis_output_tready; 
wire m_axis_output_tvalid;
wire m_axis_output_tlast;
wire [AXI_WIDTH   -1:0] m_axis_output_tdata;
wire [AXI_WIDTH/8 -1:0] m_axis_output_tkeep;
wire [W_BPT-1:0] m_bytes_per_transfer;

wire [AXIL_ADDR_WIDTH-1:0] reg_wr_addr_ctrl = (reg_wr_addr-AXIL_BASE_ADDR) >> 2;
wire [AXIL_ADDR_WIDTH-1:0] reg_rd_addr_ctrl = (reg_rd_addr-AXIL_BASE_ADDR) >> 2;



alex_axilite_ram #(
    .DATA_WR_WIDTH(AXIL_WIDTH),
    .DATA_RD_WIDTH(AXIL_WIDTH),
    .ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .TIMEOUT(TIMEOUT)
) AXIL2RAM (
    .clk(clk),
    .rstn(rstn),
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awprot(s_axil_awprot),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),
    .s_axil_wstrb(s_axil_wstrb),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),
    .s_axil_araddr(s_axil_araddr),
    .s_axil_arprot(s_axil_arprot),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),
    .reg_wr_addr(reg_wr_addr),
    .reg_wr_data(reg_wr_data),
    .reg_wr_strb(reg_wr_strb),
    .reg_wr_en(reg_wr_en),
    .reg_wr_wait(1'b0),
    .reg_wr_ack(reg_wr_ack),
    .reg_rd_addr(reg_rd_addr),
    .reg_rd_en(reg_rd_en),
    .reg_rd_data(reg_rd_data),
    .reg_rd_wait(1'b0),
    .reg_rd_ack(reg_rd_ack)
);

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
    .o_ready(m_axis_output_tready),
    .o_valid(m_axis_output_tvalid),
    .o_last(m_axis_output_tlast),
    .o_bpt(m_bytes_per_transfer),
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

alex_axi_dma_rd #(
    .AXI_DATA_WIDTH(AXI_WIDTH   ),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
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
    .ENABLE_UNALIGNED(ENABLE_UNALIGNED)
) PIXEL_DMA (
    .clk(clk),
    .rstn(rstn),
    .s_axis_read_desc_tdata(m_xd_axis_write_desc_tdata),
    .s_axis_read_desc_tag({TAG_WIDTH{1'b0}}),
    .s_axis_read_desc_tid({AXI_ID_WIDTH{1'b0}}),
    .s_axis_read_desc_tdest({AXIS_DEST_WIDTH{1'b0}}),
    .s_axis_read_desc_tuser(m_xd_axis_write_desc_tuser),
    .s_axis_read_desc_tvalid(m_xd_axis_write_desc_tvalid),
    .s_axis_read_desc_tready(m_xd_axis_write_desc_tready),
    .m_axis_read_desc_status_tag(),
    .m_axis_read_desc_status_error(),
    .m_axis_read_desc_status_valid(),
    .m_axis_read_data_tdata(s_axis_pixels_tdata),
    .m_axis_read_data_tkeep(s_axis_pixels_tkeep),
    .m_axis_read_data_tvalid(s_axis_pixels_tvalid),
    .m_axis_read_data_tready(s_axis_pixels_tready),
    .m_axis_read_data_tlast(s_axis_pixels_tlast),
    .m_axis_read_data_tid(),
    .m_axis_read_data_tdest(),
    .m_axis_read_data_tuser(s_axis_pixels_tuser),
    .m_axi_arid(m_axi_pixel_arid),
    .m_axi_araddr(m_axi_pixel_araddr),
    .m_axi_arlen(m_axi_pixel_arlen),
    .m_axi_arsize(m_axi_pixel_arsize),
    .m_axi_arburst(m_axi_pixel_arburst),
    .m_axi_arlock(m_axi_pixel_arlock),
    .m_axi_arcache(m_axi_pixel_arcache),
    .m_axi_arprot(m_axi_pixel_arprot),
    .m_axi_arvalid(m_axi_pixel_arvalid),
    .m_axi_arready(m_axi_pixel_arready),
    .m_axi_rid(m_axi_pixel_rid),
    .m_axi_rdata(m_axi_pixel_rdata),
    .m_axi_rresp(m_axi_pixel_rresp),
    .m_axi_rlast(m_axi_pixel_rlast),
    .m_axi_rvalid(m_axi_pixel_rvalid),
    .m_axi_rready(m_axi_pixel_rready),
    .enable(1'b1)
);

alex_axi_dma_rd #(
    .AXI_DATA_WIDTH(AXI_WIDTH   ),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
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
    .ENABLE_UNALIGNED(ENABLE_UNALIGNED)
) WEIGHTS_DMA (
    .clk(clk),
    .rstn(rstn),
    .s_axis_read_desc_tdata(m_wd_axis_write_desc_tdata),
    .s_axis_read_desc_tag({TAG_WIDTH{1'b0}}),
    .s_axis_read_desc_tid({AXI_ID_WIDTH{1'b0}}),
    .s_axis_read_desc_tdest({AXIS_DEST_WIDTH{1'b0}}),
    .s_axis_read_desc_tuser(m_wd_axis_write_desc_tuser),
    .s_axis_read_desc_tvalid(m_wd_axis_write_desc_tvalid),
    .s_axis_read_desc_tready(m_wd_axis_write_desc_tready),
    .m_axis_read_desc_status_tag(),
    .m_axis_read_desc_status_error(),
    .m_axis_read_desc_status_valid(),
    .m_axis_read_data_tdata(s_axis_weights_tdata),
    .m_axis_read_data_tkeep(s_axis_weights_tkeep),
    .m_axis_read_data_tvalid(s_axis_weights_tvalid),
    .m_axis_read_data_tready(s_axis_weights_tready),
    .m_axis_read_data_tlast(s_axis_weights_tlast),
    .m_axis_read_data_tid(),
    .m_axis_read_data_tdest(),
    .m_axis_read_data_tuser(s_axis_weights_tuser),
    .m_axi_arid(m_axi_weights_arid),
    .m_axi_araddr(m_axi_weights_araddr),
    .m_axi_arlen(m_axi_weights_arlen),
    .m_axi_arsize(m_axi_weights_arsize),
    .m_axi_arburst(m_axi_weights_arburst),
    .m_axi_arlock(m_axi_weights_arlock),
    .m_axi_arcache(m_axi_weights_arcache),
    .m_axi_arprot(m_axi_weights_arprot),
    .m_axi_arvalid(m_axi_weights_arvalid),
    .m_axi_arready(m_axi_weights_arready),
    .m_axi_rid(m_axi_weights_rid),
    .m_axi_rdata(m_axi_weights_rdata),
    .m_axi_rresp(m_axi_weights_rresp),
    .m_axi_rlast(m_axi_weights_rlast),
    .m_axi_rvalid(m_axi_weights_rvalid),
    .m_axi_rready(m_axi_weights_rready),
    .enable(1'b1)
);

alex_axi_dma_wr #(
    .AXI_DATA_WIDTH(AXI_WIDTH   ),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
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
    .ENABLE_UNALIGNED(ENABLE_UNALIGNED)
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
    .s_axis_write_data_tdata(m_axis_output_tdata),
    .s_axis_write_data_tkeep(m_axis_output_tkeep),
    .s_axis_write_data_tvalid(m_axis_output_tvalid),
    .s_axis_write_data_tready(m_axis_output_tready),
    .s_axis_write_data_tlast(m_axis_output_tlast),
    .s_axis_write_data_tid(),
    .s_axis_write_data_tdest(),
    .s_axis_write_data_tuser(),
    .m_axi_awid(m_axi_output_awid),
    .m_axi_awaddr(m_axi_output_awaddr),
    .m_axi_awlen(m_axi_output_awlen),
    .m_axi_awsize(m_axi_output_awsize),
    .m_axi_awburst(m_axi_output_awburst),
    .m_axi_awlock(m_axi_output_awlock),
    .m_axi_awcache(m_axi_output_awcache),
    .m_axi_awprot(m_axi_output_awprot),
    .m_axi_awvalid(m_axi_output_awvalid),
    .m_axi_awready(m_axi_output_awready),
    .m_axi_wdata(m_axi_output_wdata),
    .m_axi_wstrb(m_axi_output_wstrb),
    .m_axi_wlast(m_axi_output_wlast),
    .m_axi_wvalid(m_axi_output_wvalid),
    .m_axi_wready(m_axi_output_wready),
    .m_axi_bid(m_axi_output_bid),
    .m_axi_bresp(m_axi_output_bresp),
    .m_axi_bvalid(m_axi_output_bvalid),
    .m_axi_bready(m_axi_output_bready),
    .enable(1'b1),
    .abort(1'b0)
);

endmodule
