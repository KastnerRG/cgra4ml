`timescale 1ns/1ps

`include "../../rtl/defines.svh"
`include "config_tb.svh"

module dnn_engine_tb;

  localparam  VALID_PROB = `VALID_PROB,
              READY_PROB = `READY_PROB;

  // CLOCK GENERATION
  logic aclk = 0;
  localparam  CLK_PERIOD = 10ns;
  initial forever #(CLK_PERIOD/2) aclk = ~aclk;

  // SIGNALS

  localparam  ROWS                       = `ROWS    ,
              COLS                       = `COLS    ,
              Y_BITS                     = `Y_BITS  ,
              X_BITS                     = `X_BITS  ,
              K_BITS                     = `K_BITS  ,
              M_OUTPUT_WIDTH_LF          = `M_OUTPUT_WIDTH_LF ,
              S_WEIGHTS_WIDTH_LF         = `S_WEIGHTS_WIDTH_LF,
              S_PIXELS_WIDTH_LF          = `S_PIXELS_WIDTH_LF ,
              OUT_ADDR_WIDTH             = 10,
              OUT_BITS                   = 32;

  bit [31:0] y_sram [ROWS*COLS-1:0];

  logic aresetn;
  logic s_axis_pixels_tready, s_axis_pixels_tvalid, s_axis_pixels_tlast;
  logic [S_PIXELS_WIDTH_LF/X_BITS -1:0][X_BITS-1:0] s_axis_pixels_tdata;
  logic [S_PIXELS_WIDTH_LF/8 -1:0] s_axis_pixels_tkeep;

  logic s_axis_weights_tready, s_axis_weights_tvalid, s_axis_weights_tlast;
  logic [S_WEIGHTS_WIDTH_LF/K_BITS-1:0][K_BITS-1:0] s_axis_weights_tdata;
  logic [S_WEIGHTS_WIDTH_LF/8-1:0] s_axis_weights_tkeep;

  bit m_axis_tready, m_axis_tvalid, m_axis_tlast;
  logic [M_OUTPUT_WIDTH_LF   -1:0] m_axis_tdata;
  logic [M_OUTPUT_WIDTH_LF/8 -1:0] m_axis_tkeep;

  dnn_engine pipe (.*);

  // SOURCEs & SINKS

  DMA_M2S #(S_PIXELS_WIDTH_LF , VALID_PROB) source_x (aclk, aresetn, s_axis_pixels_tready , s_axis_pixels_tvalid , s_axis_pixels_tlast , s_axis_pixels_tdata , s_axis_pixels_tkeep );
  DMA_M2S #(S_WEIGHTS_WIDTH_LF, VALID_PROB) source_k (aclk, aresetn, s_axis_weights_tready, s_axis_weights_tvalid, s_axis_weights_tlast, s_axis_weights_tdata, s_axis_weights_tkeep);
  DMA_S2M #(M_OUTPUT_WIDTH_LF , READY_PROB) sink_y   (aclk, aresetn, m_axis_tready        , m_axis_tvalid        , m_axis_tlast        , m_axis_tdata        , m_axis_tkeep);

  bit y_done=0, x_done=0, w_done=0, bundle_read_done=0, bundle_write_done=0;
  longint unsigned w_base=0, x_base=0, y_base=0;
  int w_bpt=0, x_bpt=0, y_bpt=0;
  
  import "DPI-C" function void load_x(inout bit x_done, bundle_read_done, inout longint unsigned x_base, inout int x_bpt);
  import "DPI-C" function void load_w(inout bit w_done, inout longint unsigned w_base, inout int w_bpt);
  import "DPI-C" function void load_y(inout bit y_done, inout longint unsigned y_base, inout int y_bpt);
  import "DPI-C" function void fill_memory(inout longint unsigned w_base, x_base);
  import "DPI-C" function byte get_byte (longint unsigned addr);
  import "DPI-C" function byte get_is_bundle_write_done();
  import "DPI-C" function void set_is_bundle_write_done(input bit val);


  // W DMA
  initial 
    while (1) begin
      load_w (w_done, w_base, w_bpt);
      source_k.axis_push(w_base, w_bpt);
      $display("Done weights dma at offset=%h, bpt=%d \n", w_base, w_bpt);
      if (w_done) break;
    end

  // X DMA
  initial 
    while (1) begin
      load_x (x_done, bundle_read_done, x_base, x_bpt);
      source_x.axis_push(x_base, x_bpt);
      while(bundle_read_done && get_is_bundle_write_done()==8'b0) #10ps;
      $display("Done input dma at offset=%h, bpt=%d \n", x_base, x_bpt);
      if (x_done) break;
    end

  // Y DMA
  initial 
    while (1) begin
      load_y (y_done, y_base, y_bpt);
      sink_y.axis_pull(y_base, y_bpt);
      // $display("Done output dma at offset=%h, bpt=%d \n", y_base, y_bpt);
      if (y_done) break;
    end

  // initial begin
  //   $dumpfile("dnn_engine_tb.vcd");
  //   $dumpvars(0, dnn_engine_tb);
  //   #600us;
  //   $display("Finished early!");
  //   $finish();
  // end

  // START SIM  
  initial begin
    aresetn = 0;

    fill_memory(w_base, x_base);

    for (longint i=0; i<50; i++)
      $display("weights: i:%h, w:%b", i, get_byte(w_base + i));
    for (longint i=0; i<10; i++)
      $display("inputs : i:%h, w:%b", i, get_byte(x_base + i));
    
    repeat(2) @(posedge aclk) #1;
    aresetn = 1;
    $display("STARTING");

    wait(y_done);
    @(posedge aclk) 
    $display("Done all. time taken=%t", $time);
    $finish();
  end

endmodule