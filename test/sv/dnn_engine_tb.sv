`timescale 1ns/1ps

`include "../../rtl/include/params.svh"
`include "../xsim/sim_params.svh"

typedef struct {
  int w_bpt, w_bpt_p0; // words per transfer
  int x_bpt, x_bpt_p0;
  int y_wpt, y_wpt_last;
  int n_it, n_p;
  int y_nl, y_w;
} Bundle_t;


module dnn_engine_tb;

  `include "model.svh"
  localparam  DIR_PATH   = `DIR_PATH;
  localparam  VALID_PROB = `VALID_PROB,
              READY_PROB = `READY_PROB;

  // CLOCK GENERATION

  localparam  FREQ_HIGH = 200, 
              FREQ_RATIO = 1,
              CLK_PERIOD_HF = 1000/FREQ_HIGH, 
              CLK_PERIOD_LF = FREQ_RATIO*CLK_PERIOD_HF;
  
  logic aclk = 0, hf_aclk = 0;
  initial forever #(CLK_PERIOD_LF/2) aclk    <= ~aclk;
  initial forever #(CLK_PERIOD_HF/2) hf_aclk <= ~hf_aclk;


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

  bit [0:W_BYTES    -1][7:0] w_mem;
  bit [0:X_BYTES_ALL-1][7:0] x_mem;

  logic aresetn;
  logic s_axis_pixels_tready, s_axis_pixels_tvalid, s_axis_pixels_tlast;
  logic [S_PIXELS_WIDTH_LF/X_BITS -1:0][X_BITS-1:0] s_axis_pixels_tdata;
  logic [S_PIXELS_WIDTH_LF/X_BITS -1:0] s_axis_pixels_tkeep;

  logic s_axis_weights_tready, s_axis_weights_tvalid, s_axis_weights_tlast;
  logic [S_WEIGHTS_WIDTH_LF/K_BITS-1:0][K_BITS-1:0] s_axis_weights_tdata;
  logic [S_WEIGHTS_WIDTH_LF/8-1:0] s_axis_weights_tkeep;

  bit bram_en_a, done_fill, t_done_proc;
  logic [(OUT_ADDR_WIDTH+2)-1:0]     bram_addr_a;
  logic [ OUT_BITS         -1:0]     bram_rddata_a;

  bit [31:0] y_sram [ROWS*COLS-1:0];

  dnn_engine #(
    .S_PIXELS_KEEP_WIDTH  (S_PIXELS_WIDTH_LF/X_BITS)
  ) pipe (.*);

  // SOURCEs & SINKS

  DMA_M2S #(S_PIXELS_WIDTH_LF , VALID_PROB, X_BYTES_ALL) source_x (aclk, aresetn, s_axis_pixels_tready , s_axis_pixels_tvalid , s_axis_pixels_tlast , s_axis_pixels_tdata , s_axis_pixels_tkeep , x_mem);
  DMA_M2S #(S_WEIGHTS_WIDTH_LF, VALID_PROB, W_BYTES    ) source_k (aclk, aresetn, s_axis_weights_tready, s_axis_weights_tvalid, s_axis_weights_tlast, s_axis_weights_tdata, s_axis_weights_tkeep, w_mem);

  bit y_done=0, x_done=0, w_done=0;
  string w_path, x_path;
  int w_offset=0, w_bpt=0, x_offset=0, x_bpt=0;
  
  import "DPI-C" function void load_x(inout bit x_done, inout int x_offset, x_bpt);
  import "DPI-C" function void load_w(inout bit w_done, inout int w_offset, w_bpt);
  import "DPI-C" function void load_y(inout bit y_done, inout bit t_done_proc, inout bit [31:0] y_sram [ROWS*COLS-1:0]);

  initial 
    while (1) begin
      load_w (w_done, w_offset, w_bpt);
      source_k.axis_push(w_offset, w_bpt);
      $display("Done weights dma at offset=%d, bpt=%d \n", w_offset, w_bpt);
      if (w_done) break;
    end

  initial 
    while (1) begin
      load_x (x_done, x_offset, x_bpt);
      source_x.axis_push(x_offset, x_bpt);
      $display("Done input dma at offset=%d, bpt=%d \n", x_offset, x_bpt);
      if (x_done) break;
    end

  `define RAND_DELAY repeat($urandom_range(1000/READY_PROB-1)) @(posedge aclk) #1;
  
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

  // START SIM  

  int w_file, w_status, x_file, x_status;

  initial begin
    aresetn = 0;

    // load weights
    $sformat(w_path, "%sw", DIR_PATH);
    w_file = $fopen(w_path, "rb");
    if (w_file == 0) $fatal(1, "File '%s' does not exist\n", w_path);
    w_status = $fread(w_mem, w_file);
    $fclose(w_file);

    for (int i=0; i<10; i++)
      $display("weights: i:%d, w:%b", i, $signed(w_mem[i]));

    // load all inputs
    $sformat(x_path, "%sx_all", DIR_PATH);
    x_file = $fopen(x_path, "rb");
    if (x_file == 0) $fatal(1, "File '%s' does not exist\n", x_path);
    x_status = $fread(x_mem, x_file);
    $fclose(x_file);

    for (int i=0; i<10; i++)
      $display("inputs: i:%d, w:%b", i, $signed(x_mem[i]));

    
    repeat(2) @(posedge aclk) #1;
    aresetn = 1;
    $display("STARTING");

    wait(y_done);
    @(posedge aclk) 
    $display("DONE all");
    $finish();
  end

endmodule