`timescale 1ns/1ps
`include "config_hw.svh"
`include "config_tb.svh"

module top_tb;
  localparam
    // Defined in config_hw.svh
    AXIL_BASE_ADDR      = `CONFIG_BASEADDR   ,
    VALID_PROB          = `VALID_PROB        ,
    READY_PROB          = `READY_PROB        ,
    CLK_PERIOD          = `CLK_PERIOD        ,
    AXI_WIDTH           = `AXI_WIDTH         ,
    WA                  = 32                 ,
    LM                  = 1                  ,
    LA                  = 1                  ,
    AXI_ID_WIDTH        = 6                  ,
    AXI_STRB_WIDTH      = AXI_WIDTH/8        ,
    AXI_MAX_BURST_LEN   = 32                 ,
    AXI_ADDR_WIDTH      = 32                 ,
    AXIL_WIDTH          = 32                 ,
    AXIL_ADDR_WIDTH     = 32                 ,
    AXIL_STRB_WIDTH     = 4                  ,
    DATA_WR_WIDTH       = AXIL_WIDTH         ,
    DATA_RD_WIDTH       = AXIL_WIDTH         ,
    LSB                 = $clog2(AXI_WIDTH)-3;

  logic clk /* verilator public */ = 0, rstn, firebridge_done;
  initial forever #(CLK_PERIOD/2) clk = ~clk;

  localparam S_COUNT = 1;
  localparam M_COUNT = 3;

  wire [S_COUNT-1:0][AXI_ID_WIDTH   -1:0]   s_axi_awid   ;
  wire [S_COUNT-1:0][AXIL_ADDR_WIDTH-1:0]   s_axi_awaddr ;
  wire [S_COUNT-1:0][7:0]                   s_axi_awlen  ;
  wire [S_COUNT-1:0][2:0]                   s_axi_awsize ;
  wire [S_COUNT-1:0][1:0]                   s_axi_awburst;
  wire [S_COUNT-1:0]                        s_axi_awlock ;
  wire [S_COUNT-1:0][3:0]                   s_axi_awcache;
  wire [S_COUNT-1:0][2:0]                   s_axi_awprot ;
  wire [S_COUNT-1:0]                        s_axi_awvalid;
  wire [S_COUNT-1:0]                        s_axi_awready;
  wire [S_COUNT-1:0][AXIL_WIDTH-1:0]        s_axi_wdata  ;
  wire [S_COUNT-1:0][AXIL_STRB_WIDTH-1:0]   s_axi_wstrb  ;
  wire [S_COUNT-1:0]                        s_axi_wlast  ;
  wire [S_COUNT-1:0]                        s_axi_wvalid ;
  wire [S_COUNT-1:0]                        s_axi_wready ;
  wire [S_COUNT-1:0][AXI_ID_WIDTH-1:0]      s_axi_bid    ;
  wire [S_COUNT-1:0][1:0]                   s_axi_bresp  ;
  wire [S_COUNT-1:0]                        s_axi_bvalid ;
  wire [S_COUNT-1:0]                        s_axi_bready ;
  wire [S_COUNT-1:0][AXI_ID_WIDTH-1:0]      s_axi_arid   ;
  wire [S_COUNT-1:0][AXIL_ADDR_WIDTH-1:0]   s_axi_araddr ;
  wire [S_COUNT-1:0][7:0]                   s_axi_arlen  ;
  wire [S_COUNT-1:0][2:0]                   s_axi_arsize ;
  wire [S_COUNT-1:0][1:0]                   s_axi_arburst;
  wire [S_COUNT-1:0]                        s_axi_arlock ;
  wire [S_COUNT-1:0][3:0]                   s_axi_arcache;
  wire [S_COUNT-1:0][2:0]                   s_axi_arprot ;
  wire [S_COUNT-1:0]                        s_axi_arvalid;
  wire [S_COUNT-1:0]                        s_axi_arready;
  wire [S_COUNT-1:0][AXI_ID_WIDTH-1:0]      s_axi_rid    ;
  wire [S_COUNT-1:0][AXIL_WIDTH-1:0]        s_axi_rdata  ;
  wire [S_COUNT-1:0][1:0]                   s_axi_rresp  ;
  wire [S_COUNT-1:0]                        s_axi_rlast  ;
  wire [S_COUNT-1:0]                        s_axi_rvalid ;
  wire [S_COUNT-1:0]                        s_axi_rready ;
  wire [M_COUNT-1:0][AXI_ID_WIDTH-1:0]      m_axi_awid   ;
  wire [M_COUNT-1:0][AXI_ADDR_WIDTH-1:0]    m_axi_awaddr ;
  wire [M_COUNT-1:0][7:0]                   m_axi_awlen  ;
  wire [M_COUNT-1:0][2:0]                   m_axi_awsize ;
  wire [M_COUNT-1:0][1:0]                   m_axi_awburst;
  wire [M_COUNT-1:0]                        m_axi_awlock ;
  wire [M_COUNT-1:0][3:0]                   m_axi_awcache;
  wire [M_COUNT-1:0][2:0]                   m_axi_awprot ;
  wire [M_COUNT-1:0]                        m_axi_awvalid;
  wire [M_COUNT-1:0]                        m_axi_awready;
  wire [M_COUNT-1:0][AXI_WIDTH-1:0]         m_axi_wdata  ;
  wire [M_COUNT-1:0][AXI_STRB_WIDTH-1:0]    m_axi_wstrb  ;
  wire [M_COUNT-1:0]                        m_axi_wlast  ;
  wire [M_COUNT-1:0]                        m_axi_wvalid ;
  wire [M_COUNT-1:0]                        m_axi_wready ;
  wire [M_COUNT-1:0][AXI_ID_WIDTH-1:0]      m_axi_bid    ;
  wire [M_COUNT-1:0][1:0]                   m_axi_bresp  ;
  wire [M_COUNT-1:0]                        m_axi_bvalid ;
  wire [M_COUNT-1:0]                        m_axi_bready ;
  wire [M_COUNT-1:0][AXI_ID_WIDTH-1:0]      m_axi_arid   ;
  wire [M_COUNT-1:0][AXI_ADDR_WIDTH-1:0]    m_axi_araddr ;
  wire [M_COUNT-1:0][7:0]                   m_axi_arlen  ;
  wire [M_COUNT-1:0][2:0]                   m_axi_arsize ;
  wire [M_COUNT-1:0][1:0]                   m_axi_arburst;
  wire [M_COUNT-1:0]                        m_axi_arlock ;
  wire [M_COUNT-1:0][3:0]                   m_axi_arcache;
  wire [M_COUNT-1:0][2:0]                   m_axi_arprot ;
  wire [M_COUNT-1:0]                        m_axi_arvalid;
  wire [M_COUNT-1:0]                        m_axi_arready;
  wire [M_COUNT-1:0][AXI_ID_WIDTH-1:0]      m_axi_rid    ;
  wire [M_COUNT-1:0][AXI_WIDTH-1:0]         m_axi_rdata  ;
  wire [M_COUNT-1:0][1:0]                   m_axi_rresp  ;
  wire [M_COUNT-1:0]                        m_axi_rlast  ;
  wire [M_COUNT-1:0]                        m_axi_rvalid ;
  wire [M_COUNT-1:0]                        m_axi_rready ;

  fb_axi_vip #(
    .S_COUNT           (S_COUNT          ),
    .M_COUNT           (M_COUNT          ),
    .M_AXI_DATA_WIDTH  (AXI_WIDTH        ), 
    .M_AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH   ), 
    .M_AXI_ID_WIDTH    (AXI_ID_WIDTH     ), 
    .M_AXI_STRB_WIDTH  (AXI_STRB_WIDTH   ), 
    .S_AXI_DATA_WIDTH  (AXIL_WIDTH       ), 
    .S_AXI_ADDR_WIDTH  (AXIL_ADDR_WIDTH  ), 
    .S_AXI_STRB_WIDTH  (AXIL_STRB_WIDTH  ), 
    .S_AXI_BASE_ADDR   (AXIL_BASE_ADDR   ),
    .VALID_PROB        (VALID_PROB       ),
    .READY_PROB        (READY_PROB       )
  ) FB (.*);


  axi_cgra4ml  TOP (
  .clk (clk), 
  .rstn(rstn),

  .s_axil_awaddr   (s_axi_awaddr ),
  .s_axil_awprot   (s_axi_awprot ),
  .s_axil_awvalid  (s_axi_awvalid),
  .s_axil_awready  (s_axi_awready),
  .s_axil_wdata    (s_axi_wdata  ),
  .s_axil_wstrb    (s_axi_wstrb  ),
  .s_axil_wvalid   (s_axi_wvalid ),
  .s_axil_wready   (s_axi_wready ),
  .s_axil_bresp    (s_axi_bresp  ),
  .s_axil_bvalid   (s_axi_bvalid ),
  .s_axil_bready   (s_axi_bready ),
  .s_axil_araddr   (s_axi_araddr ),
  .s_axil_arprot   (s_axi_arprot ),
  .s_axil_arvalid  (s_axi_arvalid),
  .s_axil_arready  (s_axi_arready),
  .s_axil_rdata    (s_axi_rdata  ),
  .s_axil_rresp    (s_axi_rresp  ),
  .s_axil_rvalid   (s_axi_rvalid ),
  .s_axil_rready   (s_axi_rready ),
  // Weights
  .m_axi_pixel_arid      (m_axi_arid   [0]),
  .m_axi_pixel_araddr    (m_axi_araddr [0]),
  .m_axi_pixel_arlen     (m_axi_arlen  [0]),
  .m_axi_pixel_arsize    (m_axi_arsize [0]),
  .m_axi_pixel_arburst   (m_axi_arburst[0]),
  .m_axi_pixel_arlock    (m_axi_arlock [0]),
  .m_axi_pixel_arcache   (m_axi_arcache[0]),
  .m_axi_pixel_arprot    (m_axi_arprot [0]),
  .m_axi_pixel_arvalid   (m_axi_arvalid[0]),
  .m_axi_pixel_arready   (m_axi_arready[0]),
  .m_axi_pixel_rid       (m_axi_rid    [0]),
  .m_axi_pixel_rdata     (m_axi_rdata  [0]),
  .m_axi_pixel_rresp     (m_axi_rresp  [0]),
  .m_axi_pixel_rlast     (m_axi_rlast  [0]),
  .m_axi_pixel_rvalid    (m_axi_rvalid [0]),
  .m_axi_pixel_rready    (m_axi_rready [0]),
  .m_axi_weights_arid    (m_axi_arid   [1]),
  .m_axi_weights_araddr  (m_axi_araddr [1]),
  .m_axi_weights_arlen   (m_axi_arlen  [1]),
  .m_axi_weights_arsize  (m_axi_arsize [1]),
  .m_axi_weights_arburst (m_axi_arburst[1]),
  .m_axi_weights_arlock  (m_axi_arlock [1]),
  .m_axi_weights_arcache (m_axi_arcache[1]),
  .m_axi_weights_arprot  (m_axi_arprot [1]),
  .m_axi_weights_arvalid (m_axi_arvalid[1]),
  .m_axi_weights_arready (m_axi_arready[1]),
  .m_axi_weights_rid     (m_axi_rid    [1]),
  .m_axi_weights_rdata   (m_axi_rdata  [1]),
  .m_axi_weights_rresp   (m_axi_rresp  [1]),
  .m_axi_weights_rlast   (m_axi_rlast  [1]),
  .m_axi_weights_rvalid  (m_axi_rvalid [1]),
  .m_axi_weights_rready  (m_axi_rready [1]),
  .m_axi_output_awid     (m_axi_awid   [2]),
  .m_axi_output_awaddr   (m_axi_awaddr [2]),
  .m_axi_output_awlen    (m_axi_awlen  [2]),
  .m_axi_output_awsize   (m_axi_awsize [2]),
  .m_axi_output_awburst  (m_axi_awburst[2]),
  .m_axi_output_awlock   (m_axi_awlock [2]),
  .m_axi_output_awcache  (m_axi_awcache[2]), 
  .m_axi_output_awprot   (m_axi_awprot [2]),
  .m_axi_output_awvalid  (m_axi_awvalid[2]),
  .m_axi_output_awready  (m_axi_awready[2]),
  .m_axi_output_wdata    (m_axi_wdata  [2]),
  .m_axi_output_wstrb    (m_axi_wstrb  [2]),
  .m_axi_output_wlast    (m_axi_wlast  [2]),
  .m_axi_output_wvalid   (m_axi_wvalid [2]),
  .m_axi_output_wready   (m_axi_wready [2]),
  .m_axi_output_bid      (m_axi_bid    [2]),
  .m_axi_output_bresp    (m_axi_bresp  [2]),
  .m_axi_output_bvalid   (m_axi_bvalid [2]),
  .m_axi_output_bready   (m_axi_bready [2])
  );

  initial begin
    $dumpfile("axi_tb_sys.vcd");
    $dumpvars();
    #2000us;
    $fatal(1, "Error: Timeout.");
  end

  int file_out, file_exp, status, error=0, i=0;
  byte out_byte, exp_byte;

  initial begin
    rstn <= 0;
    repeat(2) @(posedge clk) #10ps;
    rstn <= 1;
    
    wait(firebridge_done);
    
    $finish;
  end

endmodule