`timescale 1ns/1ps

`include "../../rtl/include/params.svh"
`include "../xsim/sim_params.svh"

module dnn_engine_tb;

  localparam  DIR_PATH   = `DIR_PATH;
  localparam  VALID_PROB = `VALID_PROB,
              READY_PROB = `READY_PROB;

  // CLOCK GENERATION
  logic aclk = 0;
  localparam  CLK_PERIOD = 10ns;
  initial forever #(CLK_PERIOD/2) aclk    <= ~aclk;

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

  bit bram_en_a, done_fill, t_done_proc;
  logic [(OUT_ADDR_WIDTH+2)-1:0]     bram_addr_a;
  logic [ OUT_BITS         -1:0]     bram_rddata_a;


  dnn_engine pipe (.*);

  // SOURCEs & SINKS

  DMA_M2S #(S_PIXELS_WIDTH_LF , VALID_PROB, 1) source_x (aclk, aresetn, s_axis_pixels_tready , s_axis_pixels_tvalid , s_axis_pixels_tlast , s_axis_pixels_tdata , s_axis_pixels_tkeep );
  DMA_M2S #(S_WEIGHTS_WIDTH_LF, VALID_PROB, 0) source_k (aclk, aresetn, s_axis_weights_tready, s_axis_weights_tvalid, s_axis_weights_tlast, s_axis_weights_tdata, s_axis_weights_tkeep);

  bit y_done=0, x_done=0, w_done=0;
  string w_path, x_path;
  int w_offset=0, w_bpt=0, x_offset=0, x_bpt=0;
  
  import "DPI-C" function void load_x(inout bit x_done, inout int x_offset, x_bpt);
  import "DPI-C" function void load_w(inout bit w_done, inout int w_offset, w_bpt);
  import "DPI-C" function void load_y(inout bit y_done, inout bit t_done_proc, inout bit [31:0] y_sram [ROWS*COLS-1:0]);
  import "DPI-C" function void fill_memory();
  import "DPI-C" function byte get_byte_wx (int addr, int mode);


  // W DMA
  initial 
    while (1) begin
      load_w (w_done, w_offset, w_bpt);
      source_k.axis_push(w_offset, w_bpt);
      $display("Done weights dma at offset=%d, bpt=%d \n", w_offset, w_bpt);
      if (w_done) break;
    end

  // X DMA
  initial 
    while (1) begin
      load_x (x_done, x_offset, x_bpt);
      source_x.axis_push(x_offset, x_bpt);
      $display("Done input dma at offset=%d, bpt=%d \n", x_offset, x_bpt);
      if (x_done) break;
    end

  // Y_SRAM
  int file, y_wpt, dout;
  initial  begin
    {bram_addr_a, bram_en_a, t_done_proc} = 0;
    wait(aresetn);
    repeat(2) @(posedge aclk);

    while (!y_done) begin
      wait (done_fill); // callback trigger

      for (int unsigned ir=0; ir < ROWS*COLS; ir++) begin // DPI-C cannot consume time in verilator, so read in advance
        bram_addr_a <= ir*(OUT_BITS/8); // 4 byte words
        bram_en_a <= 1;
        repeat(2) @(posedge aclk) #1ps;
        y_sram[ir] = bram_rddata_a;
      end
      load_y(y_done, t_done_proc, y_sram);
    end
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

    fill_memory();

    for (int i=0; i<50; i++)
      $display("weights: i:%d, w:%b", i, get_byte_wx(i, 0));
    for (int i=0; i<10; i++)
      $display("inputs: i:%d, w:%b", i, get_byte_wx(i,1));
    
    repeat(2) @(posedge aclk) #1;
    aresetn = 1;
    $display("STARTING");

    wait(y_done);
    @(posedge aclk) 
    $display("Done all. time taken=%t", $time);
    $finish();
  end

endmodule