`timescale 1ns/1ps

`include "../../rtl/defines.svh"
`include "config_tb.svh"

module axi_sys_tb;
  localparam  ADDR_WIDTH          = 40,
              DATA_WR_WIDTH       = 32,
              STRB_WIDTH          = 4,
              DATA_RD_WIDTH       = 32,
		          C_S_AXI_DATA_WIDTH	= `AXI_WIDTH,
		          C_S_AXI_ADDR_WIDTH	= 32,
              LSB = $clog2(C_S_AXI_DATA_WIDTH)-3;             


  // SIGNALS
  logic rstn = 0;
  logic [ADDR_WIDTH-1:0]     s_axil_awaddr;
  logic [2:0]                s_axil_awprot;
  logic                      s_axil_awvalid;
  logic                      s_axil_awready;
  logic [DATA_WR_WIDTH-1:0]  s_axil_wdata;
  logic [STRB_WIDTH-1:0]     s_axil_wstrb;
  logic                      s_axil_wvalid;
  logic                      s_axil_wready;
  logic [1:0]                s_axil_bresp;
  logic                      s_axil_bvalid;
  logic                      s_axil_bready;
  logic [ADDR_WIDTH-1:0]     s_axil_araddr;
  logic [2:0]                s_axil_arprot;
  logic                      s_axil_arvalid;
  logic                      s_axil_arready;
  logic [DATA_RD_WIDTH-1:0]  s_axil_rdata;
  logic [1:0]                s_axil_rresp;
  logic                      s_axil_rvalid;
  logic                      s_axil_rready;

  logic                              o_rd_pixel;
  logic [C_S_AXI_ADDR_WIDTH-LSB-1:0] o_raddr_pixel;
  logic [C_S_AXI_DATA_WIDTH    -1:0] i_rdata_pixel;
  logic                              o_rd_weights;
  logic [C_S_AXI_ADDR_WIDTH-LSB-1:0] o_raddr_weights;
  logic [C_S_AXI_DATA_WIDTH    -1:0] i_rdata_weights;
  logic                              o_we_output;
  logic [C_S_AXI_ADDR_WIDTH-LSB-1:0] o_waddr_output;
  logic [C_S_AXI_DATA_WIDTH    -1:0] o_wdata_output;
  logic [C_S_AXI_DATA_WIDTH/8  -1:0] o_wstrb_output;

  cgra4ml_axi2ram_tb dut(.*);

  logic clk = 0;
  initial forever #(`CLK_PERIOD/2) clk = ~clk;

  export "DPI-C" function get_config;
  export "DPI-C" function set_config;
  import "DPI-C" context function byte get_byte_a32 (int unsigned addr);
  import "DPI-C" context function void set_byte_a32 (int unsigned addr, byte data);
  import "DPI-C" context function chandle get_mp ();
  import "DPI-C" context function void print_output (chandle mpv);
  import "DPI-C" context function void model_setup(chandle mpv, chandle p_config);
  import "DPI-C" context function bit  model_run(chandle mpv, chandle p_config);


  function automatic int get_config(chandle config_base, input int offset);
    if (offset < 16)  return dut.OC_TOP.CONTROLLER.cfg        [offset   ];
    else              return dut.OC_TOP.CONTROLLER.sdp_ram.RAM[offset-16];
  endfunction


  function automatic set_config(chandle config_base, input int offset, input int data);
    if (offset < 16) dut.OC_TOP.CONTROLLER.cfg        [offset   ] <= data;
    else             dut.OC_TOP.CONTROLLER.sdp_ram.RAM[offset-16] <= data;
  endfunction


  always_ff @(posedge clk) begin : Axi_rw
    if (o_rd_pixel) 
      for (int i = 0; i < C_S_AXI_DATA_WIDTH/8; i++) 
        i_rdata_pixel[i*8 +: 8] <= get_byte_a32((32'(o_raddr_pixel) << LSB) + i);

    if (o_rd_weights) 
      for (int i = 0; i < C_S_AXI_DATA_WIDTH/8; i++)
        i_rdata_weights[i*8 +: 8] <= get_byte_a32((32'(o_raddr_weights) << LSB) + i);

    if (o_we_output) 
      for (int i = 0; i < C_S_AXI_DATA_WIDTH/8; i++) 
        if (o_wstrb_output[i]) 
          set_byte_a32((32'(o_waddr_output) << LSB) + i, o_wdata_output[i*8 +: 8]);
  end
  
  initial begin
    $dumpfile("axi_tb_sys.vcd");
    $dumpvars();
    // #2000us;
    // $finish;
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


