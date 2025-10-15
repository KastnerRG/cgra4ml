`timescale 1ns/1ps

`include "../../rtl/defines.svh"
`include "config_tb.svh"

module axi_int_reg_tb;
  localparam  

    AXI_WIDTH               = `AXI_WIDTH   ,
    AXI_ID_WIDTH            = 6,
    AXI_ADDR_WIDTH          = 32,
    AXI_STRB_WIDTH          = (AXI_WIDTH/8),
    OPT_LOCK                = 1'b0,
    OPT_LOCKID              = 1'b1,
    OPT_LOWPOWER            = 1'b0,
  // Randomizer for AXI4 requests
    VALID_PROB              = `VALID_PROB,
    READY_PROB              = `READY_PROB,
    LSB                     = $clog2(AXI_WIDTH)-3;

  logic clk /*verilator public*/ = 0;
  logic rstn;
  initial forever #(`CLK_PERIOD/2) clk = ~clk;

  // AXI
  logic [AXI_ID_WIDTH-1:0]    m_axi_awid;
  logic [AXI_ADDR_WIDTH-1:0]  m_axi_awaddr;
  logic [7:0]                 m_axi_awlen;
  logic [2:0]                 m_axi_awsize;
  logic [1:0]                 m_axi_awburst;
  logic                       m_axi_awlock;
  logic [3:0]                 m_axi_awcache;
  logic [2:0]                 m_axi_awprot;
  logic                       m_axi_awvalid;
  logic                       m_axi_awready;
  logic [AXI_WIDTH   -1:0]    m_axi_wdata;
  logic [AXI_STRB_WIDTH-1:0]  m_axi_wstrb;
  logic                       m_axi_wlast;
  logic                       m_axi_wvalid;
  logic                       m_axi_wready;
  logic [AXI_ID_WIDTH-1:0]    m_axi_bid;
  logic [1:0]                 m_axi_bresp;
  logic                       m_axi_bvalid;
  logic                       m_axi_bready;
  logic [AXI_ID_WIDTH-1:0]    m_axi_arid   ;
  logic [AXI_ADDR_WIDTH-1:0]  m_axi_araddr ;
  logic [7:0]                 m_axi_arlen  ;
  logic [2:0]                 m_axi_arsize ;
  logic [1:0]                 m_axi_arburst;
  logic                       m_axi_arlock ;
  logic [3:0]                 m_axi_arcache;
  logic [2:0]                 m_axi_arprot ;
  logic                       m_axi_arvalid;
  logic                       m_axi_arready;
  logic [AXI_ID_WIDTH-1:0]    m_axi_rid    ;
  logic [AXI_WIDTH   -1:0]    m_axi_rdata  ;
  logic [1:0]                 m_axi_rresp  ;
  logic                       m_axi_rlast  ;
  logic                       m_axi_rvalid ;
  logic                       m_axi_rready ;
  logic reg_wr_en;
  logic reg_wr_ack;
  logic [AXI_ADDR_WIDTH-1:0] reg_wr_addr;
  logic [AXI_WIDTH-1:0] reg_wr_data;
  logic reg_rd_en;
  logic reg_rd_ack;
  logic [AXI_ADDR_WIDTH-1:0] reg_rd_addr;
  logic [AXI_WIDTH-1:0] reg_rd_data;

  axi_int_reg_cgra4ml dut(.*);


  logic                          o_rd;
  logic [AXI_ADDR_WIDTH-LSB-1:0] o_raddr;
  logic [AXI_WIDTH         -1:0] i_rdata;
  logic                          o_we;
  logic [AXI_ADDR_WIDTH-LSB-1:0] o_waddr;
  logic [AXI_WIDTH         -1:0] o_wdata;
  logic [AXI_WIDTH/8       -1:0] o_wstrb;

  logic m_axi_arvalid_zipcpu;
  logic m_axi_arready_zipcpu;
  logic m_axi_rvalid_zipcpu;
  logic m_axi_rready_zipcpu;
  logic m_axi_awvalid_zipcpu;
  logic m_axi_awready_zipcpu;
  logic m_axi_wvalid_zipcpu;
  logic m_axi_wready_zipcpu;
  logic m_axi_bvalid_zipcpu;
  logic m_axi_bready_zipcpu;
  logic rand_ar;
  logic rand_r;
  logic rand_aw;
  logic rand_w;
  logic rand_b;

  zipcpu_axi2ram #(
  .C_S_AXI_ID_WIDTH(AXI_ID_WIDTH),
  .C_S_AXI_DATA_WIDTH(AXI_WIDTH),
  .C_S_AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
  .OPT_LOCK(OPT_LOCK),
  .OPT_LOCKID(OPT_LOCKID),
  .OPT_LOWPOWER(OPT_LOWPOWER)
  ) ZIP (
    .o_we(o_we),
    .o_waddr(o_waddr),
    .o_wdata(o_wdata),
    .o_wstrb(o_wstrb),
    .o_rd(o_rd),
    .o_raddr(o_raddr),
    .i_rdata(i_rdata),

    .S_AXI_ACLK(clk),
    .S_AXI_ARESETN(rstn),
    .S_AXI_AWID(m_axi_awid),
    .S_AXI_AWADDR(m_axi_awaddr),
    .S_AXI_AWLEN(m_axi_awlen),
    .S_AXI_AWSIZE(m_axi_awsize),
    .S_AXI_AWBURST(m_axi_awburst),
    .S_AXI_AWLOCK(m_axi_awlock),
    .S_AXI_AWCACHE(m_axi_awcache),
    .S_AXI_AWPROT(m_axi_awprot),
    .S_AXI_AWQOS(),
    .S_AXI_AWVALID(m_axi_awvalid_zipcpu),
    .S_AXI_AWREADY(m_axi_awready_zipcpu),
    .S_AXI_WDATA(m_axi_wdata),
    .S_AXI_WSTRB(m_axi_wstrb),
    .S_AXI_WLAST(m_axi_wlast),
    .S_AXI_WVALID(m_axi_wvalid_zipcpu),
    .S_AXI_WREADY(m_axi_wready_zipcpu),
    .S_AXI_BID(m_axi_bid),
    .S_AXI_BRESP(m_axi_bresp),
    .S_AXI_BVALID(m_axi_bvalid_zipcpu),
    .S_AXI_BREADY(m_axi_bready_zipcpu),
    .S_AXI_ARID(m_axi_arid),
    .S_AXI_ARADDR(m_axi_araddr),
    .S_AXI_ARLEN(m_axi_arlen),
    .S_AXI_ARSIZE(m_axi_arsize),
    .S_AXI_ARBURST(m_axi_arburst),
    .S_AXI_ARLOCK(m_axi_arlock),
    .S_AXI_ARCACHE(m_axi_arcache),
    .S_AXI_ARPROT(m_axi_arprot),
    .S_AXI_ARQOS(),
    .S_AXI_ARVALID(m_axi_arvalid_zipcpu),
    .S_AXI_ARREADY(m_axi_arready_zipcpu),
    .S_AXI_RID(m_axi_rid),
    .S_AXI_RDATA(m_axi_rdata),
    .S_AXI_RRESP(m_axi_rresp),
    .S_AXI_RLAST(m_axi_rlast),
    .S_AXI_RVALID(m_axi_rvalid_zipcpu),
    .S_AXI_RREADY(m_axi_rready_zipcpu)
  );

  always_ff @( posedge clk ) begin
    rand_r   <= $urandom_range(0, 1000) < VALID_PROB;
    rand_ar  <= $urandom_range(0, 1000) < VALID_PROB;
    rand_aw  <= $urandom_range(0, 1000) < READY_PROB;
    rand_w   <= $urandom_range(0, 1000) < READY_PROB;
    rand_b   <= $urandom_range(0, 1000) < READY_PROB;
  end
  assign m_axi_arvalid_zipcpu   = rand_ar & m_axi_arvalid;
  assign m_axi_arready          = rand_ar & m_axi_arready_zipcpu;
  assign m_axi_rvalid           = rand_r  & m_axi_rvalid_zipcpu;
  assign m_axi_rready_zipcpu    = rand_r  & m_axi_rready;
  assign m_axi_awvalid_zipcpu = rand_aw & m_axi_awvalid;
  assign m_axi_awready        = rand_aw & m_axi_awready_zipcpu;
  assign m_axi_wvalid_zipcpu  = rand_w  & m_axi_wvalid;
  assign m_axi_wready         = rand_w  & m_axi_wready_zipcpu;
  assign m_axi_bvalid         = rand_b  & m_axi_bvalid_zipcpu;
  assign m_axi_bready_zipcpu  = rand_b  & m_axi_bready;


  // Testbench logic



  export "DPI-C" function get_config;
  export "DPI-C" function set_config;
  import "DPI-C" context function byte get_byte_a32 (int unsigned addr);
  import "DPI-C" context function void set_byte_a32 (int unsigned addr, byte data);
  import "DPI-C" context function chandle get_mp ();
  import "DPI-C" context function void print_output (chandle mpv);
  import "DPI-C" context function void model_setup(chandle mpv, chandle p_config);
  import "DPI-C" context function bit  model_run(chandle mpv, chandle p_config);

  function automatic int get_config(chandle config_base, input int offset);
    if (offset < 16)  return dut.CONTROLLER.cfg        [offset   ];
    else              return dut.CONTROLLER.sdp_ram.RAM[offset-16];
  endfunction


  function automatic set_config(chandle config_base, input int offset, input int data);
    if (offset < 16) dut.CONTROLLER.cfg        [offset   ] <= data;
    else             dut.CONTROLLER.sdp_ram.RAM[offset-16] <= data;
  endfunction


  always_ff @(posedge clk) begin : Axi_rw
    if (o_rd) 
      for (int i = 0; i < AXI_WIDTH/8; i++) 
        i_rdata[i*8 +: 8] <= get_byte_a32((32'(o_raddr) << LSB) + i);
    if (o_we) 
      for (int i = 0; i < AXI_WIDTH/8; i++) 
        if (o_wstrb[i]) 
          set_byte_a32((32'(o_waddr) << LSB) + i, o_wdata[i*8 +: 8]);
  end
  
  initial begin
    $dumpfile("axi_int_reg_tb.vcd");
    $dumpvars();
    #10000us;
    $finish;
  end

  chandle mpv, cp;
  initial begin
    rstn = 0;
    repeat(2) @(posedge clk) #10ps;
    rstn = 1;
    mpv = get_mp();
    
    model_setup(mpv, cp);
    repeat(2) @(posedge clk) #10ps;

    while (model_run(mpv, cp)) @(posedge clk) #10ps;

    print_output(mpv);
    $finish;
  end

endmodule

