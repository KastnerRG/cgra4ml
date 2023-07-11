`timescale 1ns/1ps

`include "../../rtl/include/params.svh"
`include "../xsim/sim_params.svh"


module dnn_engine_tb;

  localparam  DIR_PATH   = `DIR_PATH;
  localparam  VALID_PROB = `VALID_PROB,
              READY_PROB = `READY_PROB,
              NUM_IT     = `NUM_IT;

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
              M_DATA_WIDTH_HF_CONV_DW    = ROWS  * Y_BITS     ; 

  logic aresetn, hf_aresetn;
  logic s_axis_pixels_tready, s_axis_pixels_tvalid, s_axis_pixels_tlast;
  logic [S_PIXELS_WIDTH_LF/X_BITS -1:0][X_BITS-1:0] s_axis_pixels_tdata;
  logic [S_PIXELS_WIDTH_LF/X_BITS -1:0] s_axis_pixels_tkeep;

  logic s_axis_weights_tready, s_axis_weights_tvalid, s_axis_weights_tlast;
  logic [S_WEIGHTS_WIDTH_LF/K_BITS-1:0][K_BITS-1:0] s_axis_weights_tdata;
  logic [S_WEIGHTS_WIDTH_LF/K_BITS-1:0] s_axis_weights_tkeep;

  logic m_axis_tvalid, m_axis_tready, m_axis_tlast;
  logic [M_OUTPUT_WIDTH_LF/Y_BITS-1:0][Y_BITS-1:0] m_axis_tdata;
  logic [M_OUTPUT_WIDTH_LF/Y_BITS-1:0] m_axis_tkeep;

  assign hf_aresetn = aresetn;

  dnn_engine #(
    .S_PIXELS_KEEP_WIDTH  (S_PIXELS_WIDTH_LF      /X_BITS),
    .S_WEIGHTS_KEEP_WIDTH (S_WEIGHTS_WIDTH_LF     /K_BITS),
    .M_KEEP_WIDTH         (M_OUTPUT_WIDTH_LF      /Y_BITS),
    .DW_IN_KEEP_WIDTH     (M_DATA_WIDTH_HF_CONV_DW/Y_BITS)
  ) pipe (.*);

  // SOURCEs & SINKS

  AXIS_Source #(X_BITS, S_PIXELS_WIDTH_LF , VALID_PROB) source_x (aclk, aresetn, s_axis_pixels_tready , s_axis_pixels_tvalid , s_axis_pixels_tlast , s_axis_pixels_tdata , s_axis_pixels_tkeep );
  AXIS_Source #(K_BITS, S_WEIGHTS_WIDTH_LF, VALID_PROB) source_k (aclk, aresetn, s_axis_weights_tready, s_axis_weights_tvalid, s_axis_weights_tlast, s_axis_weights_tdata, s_axis_weights_tkeep);
  AXIS_Sink   #(Y_BITS, M_OUTPUT_WIDTH_LF , READY_PROB) sink_y   (aclk, aresetn, m_axis_tready        , m_axis_tvalid        , m_axis_tlast        , m_axis_tdata        , m_axis_tkeep        );

  bit done_y = 0;
  string w_path, x_path, y_path;

  initial for (int i=0; i<NUM_IT; i++) begin
    $sformat(w_path, "%s%0d_w.txt", DIR_PATH, i);
    source_k.axis_push (w_path);
    $display("done w %d", i);
  end

  initial for (int i=0; i<NUM_IT; i++) begin
    $sformat(x_path, "%s%0d_x.txt", DIR_PATH, i);
    source_x.axis_push (x_path);
    $display("done x %d", i);
  end

  initial  begin 
    for (int i=0; i<NUM_IT; i++) begin
      $sformat(y_path, "%s%0d_y_sim.txt", DIR_PATH, i);
      sink_y.axis_pull (y_path);
      $display("done y %d", i);
    end
    done_y = 1;
  end

  // START SIM  

  initial begin
    aresetn = 0;
    repeat(2) @(posedge aclk);
    aresetn = 1;
    $display("STARTING");

    wait(done_y);
    @(posedge aclk) 
    $display("DONE. m_last accepted at sink_y.i_words=%d.", sink_y.i_words);
    $finish();
  end

endmodule