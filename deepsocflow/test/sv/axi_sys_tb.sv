`timescale 1ns/1ps

`include "../../rtl/defines.svh"
`include "config_tb.svh"

module axi_sys_tb;
  localparam  ADDR_WIDTH = 40,
              DATA_WR_WIDTH           = 32,
              STRB_WIDTH              = 4,
              DATA_RD_WIDTH           = 32,
		          C_S_AXI_DATA_WIDTH	= 128,
		          C_S_AXI_ADDR_WIDTH	= 32,
              LSB = $clog2(C_S_AXI_DATA_WIDTH)-3;             


  // SIGNALS
  logic rstn = 0;
  logic enable, abort;
  logic [ADDR_WIDTH-1:0]  s_axil_awaddr;
  logic [2:0]             s_axil_awprot;
  logic                   s_axil_awvalid;
  logic                   s_axil_awready;
  logic [DATA_WR_WIDTH-1:0]  s_axil_wdata;
  logic [STRB_WIDTH-1:0]  s_axil_wstrb;
  logic                   s_axil_wvalid;
  logic                   s_axil_wready;
  logic [1:0]             s_axil_bresp;
  logic                   s_axil_bvalid;
  logic                   s_axil_bready;
  logic [ADDR_WIDTH-1:0]  s_axil_araddr;
  logic [2:0]             s_axil_arprot;
  logic                   s_axil_arvalid;
  logic                   s_axil_arready;
  logic [DATA_RD_WIDTH-1:0]  s_axil_rdata;
  logic [1:0]             s_axil_rresp;
  logic                   s_axil_rvalid;
  logic                   s_axil_rready;
  logic                                  o_rd_pixel;
  logic   [C_S_AXI_ADDR_WIDTH-LSB-1:0]   o_raddr_pixel;
  logic   [C_S_AXI_DATA_WIDTH-1:0]       i_rdata_pixel;
  logic                                  o_rd_weights;
  logic   [C_S_AXI_ADDR_WIDTH-LSB-1:0]   o_raddr_weights;
  logic   [C_S_AXI_DATA_WIDTH-1:0]       i_rdata_weights;
  logic                                  o_we_output;
  logic  [C_S_AXI_ADDR_WIDTH-LSB-1:0]    o_waddr_output;
  logic  [C_S_AXI_DATA_WIDTH-1:0]        o_wdata_output;
  logic  [C_S_AXI_DATA_WIDTH/8-1:0]      o_wstrb_output;

  bit y_done;

  rtl_sim_top dut(.*);
  logic clk = 0;
  initial forever #(`CLK_PERIOD/2) clk = ~clk;

  
  export "DPI-C" function get_config;
  export "DPI-C" function set_config;
  import "DPI-C" context function byte get_byte_32 (int unsigned addr);
  import "DPI-C" context function void set_byte_32 (int unsigned addr, byte data);
  import "DPI-C" context function void model_setup();
  import "DPI-C" context function void model_run();
  import "DPI-C" context function void load_y(inout bit p_done);

  function automatic get_config(input int offset);
    if (offset < 16*4)
      return dut.OC_TOP.CONTROLLER.cfg[offset/4];
    else
      return dut.OC_TOP.CONTROLLER.sdp_ram.RAM[offset/4-16];
  endfunction

  function automatic set_config(input int offset, input int data);
    if (offset < 16*4)begin
      //$display("Setting config[%x] = %x", offset/4, data);
      dut.OC_TOP.CONTROLLER.cfg[offset/4] <= data;
    end
    else begin
      //$display("Setting bram[%x] = %x", offset/4, data);
      dut.OC_TOP.CONTROLLER.sdp_ram.RAM[offset/4-16] <= data;
    end
  endfunction
/*
  function automatic AXI_read(input logic[C_S_AXI_ADDR_WIDTH-LSB-1:0] rd_addr, output logic [C_S_AXI_DATA_WIDTH-1:0] rd_data );
        logic [C_S_AXI_ADDR_WIDTH-1:0] rd_addr_base = rd_addr << LSB;
        $display("AXI read %x", rd_addr_base);
        for (int i = 0; i < C_S_AXI_DATA_WIDTH/8; i++) begin 
          rd_data[i*8 +: 8] = get_byte_32(rd_addr_base+i);
        end
        return rd_data;
  endfunction //automatic

  function automatic AXI_write(input logic[C_S_AXI_ADDR_WIDTH-LSB-1:0] wr_addr, input logic [C_S_AXI_DATA_WIDTH-1:0] wr_data, input logic [C_S_AXI_DATA_WIDTH/8-1:0] wr_strb);
        logic [C_S_AXI_ADDR_WIDTH-1:0] wr_addr_base = wr_addr << LSB;
        $display("AXI write %x", wr_addr_base);
        for (int i = 0; i < C_S_AXI_DATA_WIDTH/8; i++) begin
          if (wr_strb[i]) begin
            set_byte_32(wr_addr_base+i, wr_data[i*8 +: 8]);
          end
        end
  endfunction //automatic
*/

  always_ff @(posedge clk ) begin : Axi_rw
    if (o_rd_pixel) begin
      for (int i = 0; i < C_S_AXI_DATA_WIDTH/8; i++) begin 
        i_rdata_pixel[i*8 +: 8] <= get_byte_32((o_raddr_pixel << LSB) + i);
      end  
    end
    if (o_rd_weights) begin
        for (int i = 0; i < C_S_AXI_DATA_WIDTH/8; i++) begin 
          i_rdata_weights[i*8 +: 8] <= get_byte_32((o_raddr_weights << LSB) + i);
        end      
    end
    if (o_we_output) begin
      for (int i = 0; i < C_S_AXI_DATA_WIDTH/8; i++) begin
        if (o_wstrb_output[i]) begin
          set_byte_32((o_waddr_output << LSB)+i, o_wdata_output[i*8 +: 8]);
        end
      end
    end
  end

/*
  initial forever begin
    @(posedge clk);
    if (o_rd_pixel) begin
      #10ps;
      AXI_read(o_raddr_pixel, i_rdata_pixel);
    end
    if (o_rd_weights) begin
      #10ps;
      AXI_read(o_raddr_weights, i_rdata_weights);
    end
    if (o_we_output) begin
      AXI_write(o_waddr_output, o_wdata_output, o_wstrb_output);
    end
  end
*/
  
  initial begin
    $display("Start...");
    $dumpfile("axi_tb_sys.vcd");
    $dumpvars();
    rstn = 0;
    enable = 0;
    repeat(2) @(posedge clk);
    #10ps;
    rstn = 1;
    enable = 1;
    abort = 0;
    
    model_setup();
    
    repeat(2) @(posedge clk);
    #10ps;
    model_run();
    while (1) begin
      @(posedge clk);
      #10ps;
      load_y(y_done);
      if (y_done) break;
    end
    $finish;
  end

endmodule


