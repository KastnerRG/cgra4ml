`timescale 1ns/1ps

`define VERILOG
`include "defines.svh"
`undef  VERILOG

module top_axi_int #(
    parameter
      AXI_WIDTH  = `AXI_WIDTH,
      // Full AXI
      AXI_ID_WIDTH            = 6,
      DMA_ID_WIDTH            = 6-$clog2(4),
      AXI_STRB_WIDTH          = (AXI_WIDTH/8),
      AXI_ADDR_WIDTH          = 32,
      AXIS_USER_WIDTH         = 8,         
      // AXI-Lite
      AXIL_WIDTH              = 32,
      AXIL_ADDR_WIDTH         = 32,
      STRB_WIDTH              = 4
) (
    // axilite interface for configuration
    input  wire                   clk,
    input  wire                   rstn,

    // AXI-Lite Slave interface
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

axi_cgra4ml #(.AXI_ID_WIDTH(DMA_ID_WIDTH)) AXI_CGRA4ML (
    .clk                   (clk                   ),
    .rstn                  (rstn                  ),
    .s_axil_awaddr         (s_axil_awaddr         ),
    .s_axil_awprot         (s_axil_awprot         ),
    .s_axil_awvalid        (s_axil_awvalid        ),
    .s_axil_awready        (s_axil_awready        ),
    .s_axil_wdata          (s_axil_wdata          ),
    .s_axil_wstrb          (s_axil_wstrb          ),
    .s_axil_wvalid         (s_axil_wvalid         ),
    .s_axil_wready         (s_axil_wready         ),
    .s_axil_bresp          (s_axil_bresp          ),
    .s_axil_bvalid         (s_axil_bvalid         ),
    .s_axil_bready         (s_axil_bready         ),
    .s_axil_araddr         (s_axil_araddr         ),
    .s_axil_arprot         (s_axil_arprot         ),
    .s_axil_arvalid        (s_axil_arvalid        ),
    .s_axil_arready        (s_axil_arready        ),
    .s_axil_rdata          (s_axil_rdata          ),
    .s_axil_rresp          (s_axil_rresp          ),
    .s_axil_rvalid         (s_axil_rvalid         ),
    .s_axil_rready         (s_axil_rready         ),
    .m_axi_pixel_arid      (m_axi_mm2s_0_arid      ),
    .m_axi_pixel_araddr    (m_axi_mm2s_0_araddr    ),
    .m_axi_pixel_arlen     (m_axi_mm2s_0_arlen     ),
    .m_axi_pixel_arsize    (m_axi_mm2s_0_arsize    ),
    .m_axi_pixel_arburst   (m_axi_mm2s_0_arburst   ),
    .m_axi_pixel_arlock    (m_axi_mm2s_0_arlock    ),
    .m_axi_pixel_arcache   (m_axi_mm2s_0_arcache   ),
    .m_axi_pixel_arprot    (m_axi_mm2s_0_arprot    ),
    .m_axi_pixel_arvalid   (m_axi_mm2s_0_arvalid   ),
    .m_axi_pixel_arready   (m_axi_mm2s_0_arready   ),
    .m_axi_pixel_rid       (m_axi_mm2s_0_rid       ),
    .m_axi_pixel_rdata     (m_axi_mm2s_0_rdata     ),
    .m_axi_pixel_rresp     (m_axi_mm2s_0_rresp     ),
    .m_axi_pixel_rlast     (m_axi_mm2s_0_rlast     ),
    .m_axi_pixel_rvalid    (m_axi_mm2s_0_rvalid    ),
    .m_axi_pixel_rready    (m_axi_mm2s_0_rready    ),
    .m_axi_weights_arid    (m_axi_mm2s_1_arid    ),
    .m_axi_weights_araddr  (m_axi_mm2s_1_araddr  ),
    .m_axi_weights_arlen   (m_axi_mm2s_1_arlen   ),
    .m_axi_weights_arsize  (m_axi_mm2s_1_arsize  ),
    .m_axi_weights_arburst (m_axi_mm2s_1_arburst ),
    .m_axi_weights_arlock  (m_axi_mm2s_1_arlock  ),
    .m_axi_weights_arcache (m_axi_mm2s_1_arcache ),
    .m_axi_weights_arprot  (m_axi_mm2s_1_arprot  ),
    .m_axi_weights_arvalid (m_axi_mm2s_1_arvalid ),
    .m_axi_weights_arready (m_axi_mm2s_1_arready ),
    .m_axi_weights_rid     (m_axi_mm2s_1_rid     ),
    .m_axi_weights_rdata   (m_axi_mm2s_1_rdata   ),
    .m_axi_weights_rresp   (m_axi_mm2s_1_rresp   ),
    .m_axi_weights_rlast   (m_axi_mm2s_1_rlast   ),
    .m_axi_weights_rvalid  (m_axi_mm2s_1_rvalid  ),
    .m_axi_weights_rready  (m_axi_mm2s_1_rready  ),
    .m_axi_output_awid     (m_axi_s2mm_awid     ),
    .m_axi_output_awaddr   (m_axi_s2mm_awaddr   ),
    .m_axi_output_awlen    (m_axi_s2mm_awlen    ),
    .m_axi_output_awsize   (m_axi_s2mm_awsize   ),
    .m_axi_output_awburst  (m_axi_s2mm_awburst  ),
    .m_axi_output_awlock   (m_axi_s2mm_awlock   ),
    .m_axi_output_awcache  (m_axi_s2mm_awcache  ),
    .m_axi_output_awprot   (m_axi_s2mm_awprot   ),
    .m_axi_output_awvalid  (m_axi_s2mm_awvalid  ),
    .m_axi_output_awready  (m_axi_s2mm_awready  ),
    .m_axi_output_wdata    (m_axi_s2mm_wdata    ),
    .m_axi_output_wstrb    (m_axi_s2mm_wstrb    ),
    .m_axi_output_wlast    (m_axi_s2mm_wlast    ),
    .m_axi_output_wvalid   (m_axi_s2mm_wvalid   ),
    .m_axi_output_wready   (m_axi_s2mm_wready   ),
    .m_axi_output_bid      (m_axi_s2mm_bid      ),
    .m_axi_output_bresp    (m_axi_s2mm_bresp    ),
    .m_axi_output_bvalid   (m_axi_s2mm_bvalid   ),
    .m_axi_output_bready   (m_axi_s2mm_bready   )
);


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


axi_crossbar #(
  .S_COUNT         (3                             ),
  .M_COUNT         (1                             ),
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
  .M_ADDR_WIDTH    (AXI_ADDR_WIDTH                )
  // .M_CONNECT_READ  ({M_COUNT{{S_COUNT{1'b1}}}}    ),
  // .M_CONNECT_WRITE ({M_COUNT{{S_COUNT{1'b1}}}}    ),
  // .M_ISSUE         ({M_COUNT{32'd4}}              ),
  // .M_SECURE        ({M_COUNT{1'b0}}               ),
  // .S_AW_REG_TYPE   ({S_COUNT{2'd0}}               ),
  // .S_W_REG_TYPE    ({S_COUNT{2'd0}}               ),
  // .S_B_REG_TYPE    ({S_COUNT{2'd1}}               ),
  // .S_AR_REG_TYPE   ({S_COUNT{2'd0}}               ),
  // .S_R_REG_TYPE    ({S_COUNT{2'd2}}               ),
  // .M_AW_REG_TYPE   ({M_COUNT{2'd1}}               ),
  // .M_W_REG_TYPE    ({M_COUNT{2'd2}}               ),
  // .M_B_REG_TYPE    ({M_COUNT{2'd0}}               ),
  // .M_AR_REG_TYPE   ({M_COUNT{2'd1}}               ),
  // .M_R_REG_TYPE    ({M_COUNT{2'd0}}               )
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
  .s_axi_arvalid ({m_axi_s2mm_arvalid, m_axi_mm2s_1_arvalid, m_axi_mm2s_0_arvalid}), // i
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