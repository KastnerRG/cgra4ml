`timescale 1ns/1ps

`include "../../rtl/include/params.svh"
`include "../xsim/sim_params.svh"

typedef struct packed {
  int w_wpt, w_wpt_p0; // words per transfer
  int x_wpt, x_wpt_p0;
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

  logic aresetn;
  logic s_axis_pixels_tready, s_axis_pixels_tvalid, s_axis_pixels_tlast;
  logic [S_PIXELS_WIDTH_LF/X_BITS -1:0][X_BITS-1:0] s_axis_pixels_tdata;
  logic [S_PIXELS_WIDTH_LF/X_BITS -1:0] s_axis_pixels_tkeep;

  logic s_axis_weights_tready, s_axis_weights_tvalid, s_axis_weights_tlast;
  logic [S_WEIGHTS_WIDTH_LF/K_BITS-1:0][K_BITS-1:0] s_axis_weights_tdata;
  logic [S_WEIGHTS_WIDTH_LF/K_BITS-1:0] s_axis_weights_tkeep;

  logic bram_en_a, done_fill, done_firmware;
  logic [(OUT_ADDR_WIDTH+2)-1:0]     bram_addr_a;
  logic [ OUT_BITS         -1:0]     bram_rddata_a;

  dnn_engine #(
    .S_PIXELS_KEEP_WIDTH  (S_PIXELS_WIDTH_LF      /X_BITS),
    .S_WEIGHTS_KEEP_WIDTH (S_WEIGHTS_WIDTH_LF     /K_BITS),
    .M_KEEP_WIDTH         (M_OUTPUT_WIDTH_LF      /Y_BITS)
  ) pipe (.*);

  // SOURCEs & SINKS

  AXIS_Source #(X_BITS, S_PIXELS_WIDTH_LF , VALID_PROB) source_x (aclk, aresetn, s_axis_pixels_tready , s_axis_pixels_tvalid , s_axis_pixels_tlast , s_axis_pixels_tdata , s_axis_pixels_tkeep );
  AXIS_Source #(K_BITS, S_WEIGHTS_WIDTH_LF, VALID_PROB) source_k (aclk, aresetn, s_axis_weights_tready, s_axis_weights_tvalid, s_axis_weights_tlast, s_axis_weights_tdata, s_axis_weights_tkeep);

  bit done_y = 0;
  string w_path, x_path, y_path;

  initial 
    for (int ib=0; ib < N_BUNDLES; ib++)
      for (int ip=0; ip < bundles[ib].n_p; ip++)
        for (int it=0; it < bundles[ib].n_it; it++) begin
            $sformat(w_path, "%s%0d_%0d_%0d_w.txt", DIR_PATH, ib, ip, it);
            source_k.axis_push (w_path);
            $display("done w: %0d_%0d_%0d_w.txt", ib, ip, it);
          end

  initial
    for (int ib=0; ib < N_BUNDLES; ib++)
      for (int ip=0; ip < bundles[ib].n_p; ip++)
        for (int it=0; it < bundles[ib].n_it; it++) begin
          $sformat(x_path, "%s%0d_%0d_x.txt", DIR_PATH, ib, ip);
          source_x.axis_push (x_path);
          $display("done x: %0d_%0d_x.txt", ib, ip);
        end

  `define RAND_DELAY //repeat($urandom_range(100))@(posedge aclk) #1;
  
  int file, y_wpt, dout;
  initial  begin
    {bram_addr_a, bram_en_a, done_firmware} = 0;
    wait(aresetn);
    repeat(2) @(posedge aclk);

    for (int ib=0; ib < N_BUNDLES; ib++)
      for (int ip=0; ip < bundles[ib].n_p; ip++)
        for (int it=0; it < bundles[ib].n_it; it++) begin

          $sformat(y_path, "%s%0d_%0d_%0d_y_sim.txt", DIR_PATH, ib, ip, it);
          file = $fopen(y_path, "w");
          $fclose(file);

          `RAND_DELAY
          for (int i_nl=0; i_nl < bundles[ib].y_nl; i_nl++)
            for (int i_w=0; i_w < bundles[ib].y_w; i_w++) begin
              wait (done_fill);
              `RAND_DELAY
              done_firmware <= 0;
              file = $fopen(y_path, "a");

              y_wpt = i_w==(bundles[ib].y_w-1) ? bundles[ib].y_wpt_last : bundles[ib].y_wpt;
              for (int unsigned i_w=0; i_w < y_wpt; i_w++) begin
                bram_addr_a <= i_w*(OUT_BITS/8); // 4 byte words
                bram_en_a <= 1;
                repeat(2) @(posedge aclk) #1ps;
                $fdisplay(file, "%d", $signed(bram_rddata_a));
              end
              `RAND_DELAY
              done_firmware <= 1;
              $fclose(file);
              `RAND_DELAY
            end
          $display("done y: %0d_%0d_%0d_y_sim.txt", ib, ip, it);
        end
    done_y = 1;
  end

  // START SIM  

  initial begin
    aresetn = 0;
    repeat(2) @(posedge aclk) #1;
    aresetn = 1;
    $display("STARTING");

    wait(done_y);
    @(posedge aclk) 
    $display("DONE all");
    $finish();
  end

endmodule