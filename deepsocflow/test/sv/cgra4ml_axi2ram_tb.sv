/* 
    Top module for simulation
    Components
    RTL on-chip Top
        - DNN engine
        - Controller
            -BRAM and register
        - axilite interface (connected but not used in simulation), we write to controller reg directly using DPI-C
        - 3 Alex DMAs
    3 Zip cpus converting AXI4 requests to ram rw requests
*/
`timescale 1ns/1ps
`define VERILOG
`include "../../rtl/defines.svh"
`include "config_tb.svh"
`undef  VERILOG

module cgra4ml_axi2ram_tb #(
    // Parameters for DNN engine
    parameter   ROWS                    = `ROWS               ,
                COLS                    = `COLS               ,
                X_BITS                  = `X_BITS             , 
                K_BITS                  = `K_BITS             , 
                Y_BITS                  = `Y_BITS             ,
                Y_OUT_BITS              = `Y_OUT_BITS         ,
                M_DATA_WIDTH_HF_CONV    = COLS  * ROWS  * Y_BITS,
                M_DATA_WIDTH_HF_CONV_DW = ROWS  * Y_BITS,

                AXI_WIDTH               = `AXI_WIDTH  ,
                AXI_MAX_BURST_LEN       = `AXI_MAX_BURST_LEN,
                W_BPT                   = `W_BPT,

                OUT_ADDR_WIDTH          = 10,
                OUT_BITS                = 32,
    // Parameters for controller
                SRAM_RD_DATA_WIDTH      = 256,
                SRAM_RD_DEPTH           = `MAX_N_BUNDLES,
                COUNTER_WIDTH           = 16,
                AXI_ADDR_WIDTH          = 32,
                AXIL_WIDTH              = 32,
                AXI_LEN_WIDTH           = 32,
                AXIL_BASE_ADDR          = `CONFIG_BASEADDR,
    
    // Parameters for axilite to ram
                DATA_WR_WIDTH           = 32,
                DATA_RD_WIDTH           = 32,
                AXIL_ADDR_WIDTH              = 40,
                STRB_WIDTH              = 4,
                TIMEOUT                 = 2,

    // Alex AXI DMA RD
                AXI_DATA_WIDTH_PS       = AXI_WIDTH,
                //AXI_ADDR_WIDTH          = 32, same as above
                AXI_STRB_WIDTH          = (AXI_WIDTH/8),
                AXI_ID_WIDTH            = 6,
                AXIS_DATA_WIDTH         = AXI_WIDTH,//AXIL_DATA_WIDTH,
                AXIS_KEEP_ENABLE        = 1,//(AXIS_DATA_WIDTH>8),
                AXIS_KEEP_WIDTH         = (AXI_WIDTH/8),//(AXIS_DATA_WIDTH/8),
                AXIS_LAST_ENABLE        = 1,
                AXIS_ID_ENABLE          = 0,
                AXIS_ID_WIDTH           = 6,
                AXIS_DEST_ENABLE        = 0,
                AXIS_DEST_WIDTH         = 8,
                AXIS_USER_ENABLE        = 1,
                AXIS_USER_WIDTH         = 1,
                LEN_WIDTH               = 32,
                TAG_WIDTH               = 8,
                ENABLE_SG               = 0,
                ENABLE_UNALIGNED        = 1,
    
    // Parameters for zip cpu
		        C_S_AXI_ID_WIDTH	    = 6,
		        C_S_AXI_DATA_WIDTH	    = AXI_WIDTH,
		        C_S_AXI_ADDR_WIDTH	    = 32,
		        OPT_LOCK                = 1'b0,
		        OPT_LOCKID              = 1'b1,
		        OPT_LOWPOWER            = 1'b0,
    // Randomizer for AXI4 requests
                VALID_PROB              = `VALID_PROB,
                READY_PROB              = `READY_PROB,

    localparam	LSB = $clog2(C_S_AXI_DATA_WIDTH)-3                
)(
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
    input  wire [DATA_WR_WIDTH-1:0]  s_axil_wdata,
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
    output wire [DATA_RD_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]             s_axil_rresp,
    output wire                   s_axil_rvalid,
    input  wire                   s_axil_rready,
    
    // ram rw interface for interacting with DDR in sim
    output wire                   o_rd_pixel,
    output wire   [C_S_AXI_ADDR_WIDTH-LSB-1:0]   o_raddr_pixel,
    input  wire   [C_S_AXI_DATA_WIDTH-1:0]       i_rdata_pixel,

    output wire                   o_rd_weights,
    output wire   [C_S_AXI_ADDR_WIDTH-LSB-1:0]   o_raddr_weights,
    input  wire  [C_S_AXI_DATA_WIDTH-1:0]       i_rdata_weights,

    output wire                   o_we_output,
    output wire  [C_S_AXI_ADDR_WIDTH-LSB-1:0]    o_waddr_output,
    output wire  [C_S_AXI_DATA_WIDTH-1:0]        o_wdata_output,
    output wire  [C_S_AXI_DATA_WIDTH/8-1:0]      o_wstrb_output
);

// AXI ports from top on-chip module
    wire [AXI_ID_WIDTH-1:0]    m_axi_pixel_arid;
    wire [AXI_ADDR_WIDTH-1:0]  m_axi_pixel_araddr;
    wire [7:0]                 m_axi_pixel_arlen;
    wire [2:0]                 m_axi_pixel_arsize;
    wire [1:0]                 m_axi_pixel_arburst;
    wire                       m_axi_pixel_arlock;
    wire [3:0]                 m_axi_pixel_arcache;
    wire [2:0]                 m_axi_pixel_arprot;
    wire                       m_axi_pixel_arvalid;
    wire                       m_axi_pixel_arvalid_zipcpu;
    wire                       m_axi_pixel_arready;
    wire                       m_axi_pixel_arready_zipcpu;
    wire [AXI_ID_WIDTH-1:0]    m_axi_pixel_rid;
    wire [AXI_DATA_WIDTH_PS-1:0]  m_axi_pixel_rdata;
    wire [1:0]                 m_axi_pixel_rresp;
    wire                       m_axi_pixel_rlast;
    wire                       m_axi_pixel_rvalid;
    wire                       m_axi_pixel_rvalid_zipcpu;
    wire                       m_axi_pixel_rready;
    wire                       m_axi_pixel_rready_zipcpu;

    wire [AXI_ID_WIDTH-1:0]    m_axi_weights_arid;
    wire [AXI_ADDR_WIDTH-1:0]  m_axi_weights_araddr;
    wire [7:0]                 m_axi_weights_arlen;
    wire [2:0]                 m_axi_weights_arsize;
    wire [1:0]                 m_axi_weights_arburst;
    wire                       m_axi_weights_arlock;
    wire [3:0]                 m_axi_weights_arcache;
    wire [2:0]                 m_axi_weights_arprot;
    wire                       m_axi_weights_arvalid;
    wire                       m_axi_weights_arvalid_zipcpu;
    wire                       m_axi_weights_arready;
    wire                       m_axi_weights_arready_zipcpu;
    wire [AXI_ID_WIDTH-1:0]    m_axi_weights_rid;
    wire [AXI_DATA_WIDTH_PS-1:0]  m_axi_weights_rdata;
    wire [1:0]                 m_axi_weights_rresp;
    wire                       m_axi_weights_rlast;
    wire                       m_axi_weights_rvalid;
    wire                       m_axi_weights_rvalid_zipcpu;
    wire                       m_axi_weights_rready;
    wire                       m_axi_weights_rready_zipcpu;

    wire [AXI_ID_WIDTH-1:0]    m_axi_output_awid;
    wire [AXI_ADDR_WIDTH-1:0]  m_axi_output_awaddr;
    wire [7:0]                 m_axi_output_awlen;
    wire [2:0]                 m_axi_output_awsize;
    wire [1:0]                 m_axi_output_awburst;
    wire                       m_axi_output_awlock;
    wire [3:0]                 m_axi_output_awcache;
    wire [2:0]                 m_axi_output_awprot;
    wire                       m_axi_output_awvalid;
    wire                       m_axi_output_awvalid_zipcpu;
    wire                       m_axi_output_awready;
    wire                       m_axi_output_awready_zipcpu;
    wire [AXI_DATA_WIDTH_PS-1:0]  m_axi_output_wdata;
    wire [AXI_STRB_WIDTH-1:0]  m_axi_output_wstrb;
    wire                       m_axi_output_wlast;
    wire                       m_axi_output_wvalid;
    wire                       m_axi_output_wvalid_zipcpu;
    wire                       m_axi_output_wready;
    wire                       m_axi_output_wready_zipcpu;
    wire [AXI_ID_WIDTH-1:0]    m_axi_output_bid;
    wire [1:0]                 m_axi_output_bresp;
    wire                       m_axi_output_bvalid;
    wire                       m_axi_output_bvalid_zipcpu;
    wire                       m_axi_output_bready;
    wire                       m_axi_output_bready_zipcpu;

    logic rand_pixel_ar;
    logic rand_pixel_r;
    logic rand_weights_ar;
    logic rand_weights_r;
    logic rand_output_aw;
    logic rand_output_w;
    logic rand_output_b;

    // Randomizer for AXI4 requests
    always_ff @( posedge clk ) begin
        rand_pixel_r    <= $urandom_range(0, 1000) < VALID_PROB;
        rand_pixel_ar   <= $urandom_range(0, 1000) < VALID_PROB;
        rand_weights_r  <= $urandom_range(0, 1000) < VALID_PROB;
        rand_weights_ar <= $urandom_range(0, 1000) < VALID_PROB;
        rand_output_aw  <= $urandom_range(0, 1000) < READY_PROB;
        rand_output_w   <= $urandom_range(0, 1000) < READY_PROB;
        rand_output_b   <= $urandom_range(0, 1000) < READY_PROB;
    end

    assign m_axi_pixel_arvalid_zipcpu   = rand_pixel_ar & m_axi_pixel_arvalid;
    assign m_axi_pixel_arready          = rand_pixel_ar & m_axi_pixel_arready_zipcpu;
    assign m_axi_pixel_rvalid           = rand_pixel_r  & m_axi_pixel_rvalid_zipcpu;
    assign m_axi_pixel_rready_zipcpu    = rand_pixel_r  & m_axi_pixel_rready;

    assign m_axi_weights_arvalid_zipcpu = rand_weights_ar & m_axi_weights_arvalid;
    assign m_axi_weights_arready        = rand_weights_ar & m_axi_weights_arready_zipcpu;
    assign m_axi_weights_rvalid         = rand_weights_r  & m_axi_weights_rvalid_zipcpu;
    assign m_axi_weights_rready_zipcpu  = rand_weights_r  & m_axi_weights_rready;

    assign m_axi_output_awvalid_zipcpu = rand_output_aw & m_axi_output_awvalid;
    assign m_axi_output_awready        = rand_output_aw & m_axi_output_awready_zipcpu;
    assign m_axi_output_wvalid_zipcpu  = rand_output_w  & m_axi_output_wvalid;
    assign m_axi_output_wready         = rand_output_w  & m_axi_output_wready_zipcpu;
    assign m_axi_output_bvalid         = rand_output_b  & m_axi_output_bvalid_zipcpu;
    assign m_axi_output_bready_zipcpu  = rand_output_b  & m_axi_output_bready;


zipcpu_axi2ram #(
    .C_S_AXI_ID_WIDTH(C_S_AXI_ID_WIDTH),
    .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
    .OPT_LOCK(OPT_LOCK),
    .OPT_LOCKID(OPT_LOCKID),
    .OPT_LOWPOWER(OPT_LOWPOWER)
) ZIP_PIXELS (
    .o_we(),
    .o_waddr(),
    .o_wdata(),
    .o_wstrb(),
    .o_rd(o_rd_pixel),
    .o_raddr(o_raddr_pixel),
    .i_rdata(i_rdata_pixel),
    .S_AXI_ACLK(clk),
    .S_AXI_ARESETN(rstn),
    .S_AXI_AWID(),
    .S_AXI_AWADDR(),
    .S_AXI_AWLEN(),
    .S_AXI_AWSIZE(),
    .S_AXI_AWBURST(),
    .S_AXI_AWLOCK(),
    .S_AXI_AWCACHE(),
    .S_AXI_AWPROT(),
    .S_AXI_AWQOS(),
    .S_AXI_AWVALID(1'b0),
    .S_AXI_AWREADY(),
    .S_AXI_WDATA(),
    .S_AXI_WSTRB(),
    .S_AXI_WLAST(),
    .S_AXI_WVALID(1'b0),
    .S_AXI_WREADY(),
    .S_AXI_BID(),
    .S_AXI_BRESP(),
    .S_AXI_BVALID(),
    .S_AXI_BREADY(),
    .S_AXI_ARID(m_axi_pixel_arid),
    .S_AXI_ARADDR(m_axi_pixel_araddr),
    .S_AXI_ARLEN(m_axi_pixel_arlen),
    .S_AXI_ARSIZE(m_axi_pixel_arsize),
    .S_AXI_ARBURST(m_axi_pixel_arburst),
    .S_AXI_ARLOCK(m_axi_pixel_arlock),
    .S_AXI_ARCACHE(m_axi_pixel_arcache),
    .S_AXI_ARPROT(m_axi_pixel_arprot),
    .S_AXI_ARQOS(),
    .S_AXI_ARVALID(m_axi_pixel_arvalid_zipcpu),
    .S_AXI_ARREADY(m_axi_pixel_arready_zipcpu),
    .S_AXI_RID(m_axi_pixel_rid),
    .S_AXI_RDATA(m_axi_pixel_rdata),
    .S_AXI_RRESP(m_axi_pixel_rresp),
    .S_AXI_RLAST(m_axi_pixel_rlast),
    .S_AXI_RVALID(m_axi_pixel_rvalid_zipcpu),
    .S_AXI_RREADY(m_axi_pixel_rready_zipcpu)
);

zipcpu_axi2ram #(
    .C_S_AXI_ID_WIDTH(C_S_AXI_ID_WIDTH),
    .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
    .OPT_LOCK(OPT_LOCK),
    .OPT_LOCKID(OPT_LOCKID),
    .OPT_LOWPOWER(OPT_LOWPOWER)
) ZIP_WEIGHTS (
    .o_we(),
    .o_waddr(),
    .o_wdata(),
    .o_wstrb(),
    .o_rd(o_rd_weights),
    .o_raddr(o_raddr_weights),
    .i_rdata(i_rdata_weights),
    .S_AXI_ACLK(clk),
    .S_AXI_ARESETN(rstn),
    .S_AXI_AWID(),
    .S_AXI_AWADDR(),
    .S_AXI_AWLEN(),
    .S_AXI_AWSIZE(),
    .S_AXI_AWBURST(),
    .S_AXI_AWLOCK(),
    .S_AXI_AWCACHE(),
    .S_AXI_AWPROT(),
    .S_AXI_AWQOS(),
    .S_AXI_AWVALID('0),
    .S_AXI_AWREADY(),
    .S_AXI_WDATA(),
    .S_AXI_WSTRB(),
    .S_AXI_WLAST(),
    .S_AXI_WVALID(1'b0),
    .S_AXI_WREADY(),
    .S_AXI_BID(),
    .S_AXI_BRESP(),
    .S_AXI_BVALID(),
    .S_AXI_BREADY(),
    .S_AXI_ARID(m_axi_weights_arid),
    .S_AXI_ARADDR(m_axi_weights_araddr),
    .S_AXI_ARLEN(m_axi_weights_arlen),
    .S_AXI_ARSIZE(m_axi_weights_arsize),
    .S_AXI_ARBURST(m_axi_weights_arburst),
    .S_AXI_ARLOCK(m_axi_weights_arlock),
    .S_AXI_ARCACHE(m_axi_weights_arcache),
    .S_AXI_ARPROT(m_axi_weights_arprot),
    .S_AXI_ARQOS(),
    .S_AXI_ARVALID(m_axi_weights_arvalid_zipcpu),
    .S_AXI_ARREADY(m_axi_weights_arready_zipcpu),
    .S_AXI_RID(m_axi_weights_rid),
    .S_AXI_RDATA(m_axi_weights_rdata),
    .S_AXI_RRESP(m_axi_weights_rresp),
    .S_AXI_RLAST(m_axi_weights_rlast),
    .S_AXI_RVALID(m_axi_weights_rvalid_zipcpu),
    .S_AXI_RREADY(m_axi_weights_rready_zipcpu)
);

zipcpu_axi2ram #(
    .C_S_AXI_ID_WIDTH(C_S_AXI_ID_WIDTH),
    .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
    .OPT_LOCK(OPT_LOCK),
    .OPT_LOCKID(OPT_LOCKID),
    .OPT_LOWPOWER(OPT_LOWPOWER)
) ZIP_OUTPUT (
    .o_we(o_we_output),
    .o_waddr(o_waddr_output),
    .o_wdata(o_wdata_output),
    .o_wstrb(o_wstrb_output),
    .o_rd(),
    .o_raddr(),
    .i_rdata(),
    .S_AXI_ACLK(clk),
    .S_AXI_ARESETN(rstn),
    .S_AXI_AWID(m_axi_output_awid),
    .S_AXI_AWADDR(m_axi_output_awaddr),
    .S_AXI_AWLEN(m_axi_output_awlen),
    .S_AXI_AWSIZE(m_axi_output_awsize),
    .S_AXI_AWBURST(m_axi_output_awburst),
    .S_AXI_AWLOCK(m_axi_output_awlock),
    .S_AXI_AWCACHE(m_axi_output_awcache),
    .S_AXI_AWPROT(m_axi_output_awprot),
    .S_AXI_AWQOS(),
    .S_AXI_AWVALID(m_axi_output_awvalid_zipcpu),
    .S_AXI_AWREADY(m_axi_output_awready_zipcpu),
    .S_AXI_WDATA(m_axi_output_wdata),
    .S_AXI_WSTRB(m_axi_output_wstrb),
    .S_AXI_WLAST(m_axi_output_wlast),
    .S_AXI_WVALID(m_axi_output_wvalid_zipcpu),
    .S_AXI_WREADY(m_axi_output_wready_zipcpu),
    .S_AXI_BID(m_axi_output_bid),
    .S_AXI_BRESP(m_axi_output_bresp),
    .S_AXI_BVALID(m_axi_output_bvalid_zipcpu),
    .S_AXI_BREADY(m_axi_output_bready_zipcpu),
    .S_AXI_ARID(),
    .S_AXI_ARADDR(),
    .S_AXI_ARLEN(),
    .S_AXI_ARSIZE(),
    .S_AXI_ARBURST(),
    .S_AXI_ARLOCK(),
    .S_AXI_ARCACHE(),
    .S_AXI_ARPROT(),
    .S_AXI_ARQOS(),
    .S_AXI_ARVALID(1'b0),
    .S_AXI_ARREADY(),
    .S_AXI_RID(),
    .S_AXI_RDATA(),
    .S_AXI_RRESP(),
    .S_AXI_RLAST(),
    .S_AXI_RVALID(),
    .S_AXI_RREADY(1'b0)
);

axi_cgra4ml #(
    .ROWS(ROWS),
    .COLS(COLS),
    .X_BITS(X_BITS),
    .K_BITS(K_BITS),
    .Y_BITS(Y_BITS),
    .Y_OUT_BITS(Y_OUT_BITS),
    .M_DATA_WIDTH_HF_CONV(M_DATA_WIDTH_HF_CONV),
    .M_DATA_WIDTH_HF_CONV_DW(M_DATA_WIDTH_HF_CONV_DW),

    .AXI_WIDTH(AXI_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),

    .AXIL_WIDTH(AXIL_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .W_BPT(W_BPT)
) OC_TOP (
    .*
);

endmodule