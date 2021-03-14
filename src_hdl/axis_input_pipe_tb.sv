`include "params.v"
`include "axis_tb.sv"

module axis_input_pipe_tb ();
  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  /*
    IMAGE & KERNEL PARAMETERS
  */
  
  localparam K          = 3;
  localparam IM_HEIGHT  = 2;
  localparam IM_WIDTH   = 4;
  localparam IM_CIN     = 4;

  localparam ITERATIONS = 5;

  /*
    SYSTEM PARAMS
  */

  localparam UNITS  = 2;
  localparam CORES  = 2;
  
  localparam WORD_WIDTH            = `WORD_WIDTH    ; 
  localparam WORD_WIDTH_ACC        = `WORD_WIDTH_ACC; 
  localparam KERNEL_H_MAX          = `KERNEL_H_MAX  ;   // odd number
  localparam KERNEL_W_MAX          = `KERNEL_W_MAX  ;
  localparam BITS_KERNEL_W         = `BITS_KERNEL_W;
  localparam BITS_KERNEL_H         = `BITS_KERNEL_H;
  localparam IM_CIN_MAX            = `IM_CIN_MAX    ;
  localparam IM_BLOCKS_MAX         = `IM_BLOCKS_MAX ;
  localparam IM_COLS_MAX           = `IM_COLS_MAX   ;
  localparam S_WEIGHTS_WIDTH       = `S_WEIGHTS_WIDTH ;
  localparam LRELU_ALPHA           = `LRELU_ALPHA;
  localparam BITS_EXP_CONFIG       = `BITS_EXP_CONFIG      ;
  localparam BITS_FRA_CONFIG       = `BITS_FRA_CONFIG      ;
  localparam BITS_EXP_FMA_1        = `BITS_EXP_FMA_1       ;
  localparam BITS_FRA_FMA_1        = `BITS_FRA_FMA_1       ;
  localparam BITS_EXP_FMA_2        = `BITS_EXP_FMA_2       ;
  localparam BITS_FRA_FMA_2        = `BITS_FRA_FMA_2       ;
  localparam LATENCY_FMA_1         = `LATENCY_FMA_1        ;
  localparam LATENCY_FMA_2         = `LATENCY_FMA_2        ;
  localparam LATENCY_FIXED_2_FLOAT = `LATENCY_FIXED_2_FLOAT;
  localparam LATENCY_BRAM          = `LATENCY_BRAM         ;
  localparam LATENCY_ACCUMULATOR   = `LATENCY_ACCUMULATOR  ;
  localparam LATENCY_MULTIPLIER    = `LATENCY_MULTIPLIER   ;
  localparam BEATS_CONFIG_3X3_1    = `BEATS_CONFIG_3X3_1   ;
  localparam BEATS_CONFIG_1X1_1    = `BEATS_CONFIG_1X1_1   ;
  localparam I_IMAGE_IS_NOT_MAX         = `I_IMAGE_IS_NOT_MAX;
  localparam I_IMAGE_IS_MAX             = `I_IMAGE_IS_MAX    ;
  localparam I_IMAGE_IS_LRELU           = `I_IMAGE_IS_LRELU  ;
  localparam I_IMAGE_KERNEL_H_1         = `I_IMAGE_KERNEL_H_1; 
  localparam TUSER_WIDTH_IM_SHIFT_IN    = `TUSER_WIDTH_IM_SHIFT_IN ;
  localparam TUSER_WIDTH_IM_SHIFT_OUT   = `TUSER_WIDTH_IM_SHIFT_OUT;
  localparam I_WEIGHTS_IS_TOP_BLOCK     = `I_WEIGHTS_IS_TOP_BLOCK   ;
  localparam I_WEIGHTS_IS_BOTTOM_BLOCK  = `I_WEIGHTS_IS_BOTTOM_BLOCK;
  localparam I_WEIGHTS_IS_1X1           = `I_WEIGHTS_IS_1X1         ;
  localparam I_WEIGHTS_IS_COLS_1_K2     = `I_WEIGHTS_IS_COLS_1_K2   ;
  localparam I_WEIGHTS_IS_CONFIG        = `I_WEIGHTS_IS_CONFIG      ;
  localparam I_WEIGHTS_IS_CIN_LAST      = `I_WEIGHTS_IS_CIN_LAST    ;
  localparam I_WEIGHTS_KERNEL_W_1       = `I_WEIGHTS_KERNEL_W_1     ; 
  localparam TUSER_WIDTH_WEIGHTS_OUT    = `TUSER_WIDTH_WEIGHTS_OUT;
  localparam I_IS_NOT_MAX               = `I_IS_NOT_MAX     ;
  localparam I_IS_MAX                   = `I_IS_MAX         ;
  localparam I_IS_1X1                   = `I_IS_1X1         ;
  localparam I_IS_LRELU                 = `I_IS_LRELU       ;
  localparam I_IS_TOP_BLOCK             = `I_IS_TOP_BLOCK   ;
  localparam I_IS_BOTTOM_BLOCK          = `I_IS_BOTTOM_BLOCK;
  localparam I_IS_COLS_1_K2             = `I_IS_COLS_1_K2   ;
  localparam I_IS_CONFIG                = `I_IS_CONFIG      ;
  localparam I_IS_CIN_LAST              = `I_IS_CIN_LAST    ;
  localparam I_KERNEL_W_1               = `I_KERNEL_W_1     ; 
  localparam TUSER_WIDTH_CONV_IN        = `TUSER_WIDTH_CONV_IN;

  localparam UNITS_EDGES        = UNITS + KERNEL_H_MAX-1;
  localparam IM_IN_S_DATA_WORDS = 2**$clog2(UNITS_EDGES);
  localparam TKEEP_WIDTH_IM_IN  = WORD_WIDTH*IM_IN_S_DATA_WORDS/8;
  localparam IM_BLOCKS          = IM_HEIGHT/UNITS;
  localparam IM_COLS            = IM_WIDTH;

  string path_im_1     = "D:/cnn-fpga/data/im_pipe_in.txt";
  string path_im_2     = "D:/cnn-fpga/data/im_pipe_in_2.txt";
  string path_weights  = "D:/cnn-fpga/data/weights_rot_in.txt";
  string base_im_out_1 = "D:/cnn-fpga/data/im_pipe_out_1_";
  string base_im_out_2 = "D:/cnn-fpga/data/im_pipe_out_2_";

  localparam BEATS_2 = IM_BLOCKS * IM_COLS * IM_CIN;
  localparam WORDS_2 = BEATS_2 * UNITS_EDGES;
  localparam BEATS_1 = BEATS_2 + 1;
  localparam WORDS_1 = BEATS_1 * UNITS_EDGES;
  
  localparam BEATS_CONFIG_1   = K == 1 ? BEATS_CONFIG_1X1_1 : BEATS_CONFIG_3X3_1;
  localparam W_BEATS          = 1 + BEATS_CONFIG_1+1 + K*IM_CIN;
  localparam WORDS_W          = (W_BEATS-1) * KERNEL_W_MAX * CORES + S_WEIGHTS_WIDTH /WORD_WIDTH;
  localparam W_WORDS_PER_BEAT = S_WEIGHTS_WIDTH /WORD_WIDTH;

  logic aresetn;
  logic s_axis_pixels_1_tready;
  logic s_axis_pixels_1_tvalid;
  logic s_axis_pixels_1_tlast ;
  logic [WORD_WIDTH*IM_IN_S_DATA_WORDS    -1:0] s_axis_pixels_1_tdata;
  logic [TKEEP_WIDTH_IM_IN-1:0] s_axis_pixels_1_tkeep;

  logic s_axis_pixels_2_tready;
  logic s_axis_pixels_2_tvalid;
  logic s_axis_pixels_2_tlast ;
  logic [WORD_WIDTH*IM_IN_S_DATA_WORDS    -1:0] s_axis_pixels_2_tdata;
  logic [TKEEP_WIDTH_IM_IN-1:0] s_axis_pixels_2_tkeep;

  logic s_axis_weights_tready;
  logic s_axis_weights_tvalid;
  logic s_axis_weights_tlast ;
  logic [S_WEIGHTS_WIDTH    -1:0] s_axis_weights_tdata;
  logic [S_WEIGHTS_WIDTH /8 -1:0] s_axis_weights_tkeep;

  logic m_axis_tready;
  logic m_axis_tvalid;
  logic m_axis_tlast;
  logic [WORD_WIDTH*UNITS             -1:0] m_axis_pixels_1_tdata;
  logic [WORD_WIDTH*UNITS             -1:0] m_axis_pixels_2_tdata;
  logic [WORD_WIDTH*CORES*KERNEL_W_MAX-1:0] m_axis_weights_tdata;
  logic [TUSER_WIDTH_CONV_IN-1:0] m_axis_tuser;

  localparam DEBUG_CONFIG_WIDTH = 2*BITS_KERNEL_H + `DEBUG_CONFIG_WIDTH_IM_PIPE + `DEBUG_CONFIG_WIDTH_W_ROT;
  logic [DEBUG_CONFIG_WIDTH-1:0] debug_config;

  axis_input_pipe #(
    .UNITS              (UNITS             ),
    .CORES              (CORES             ),
    .WORD_WIDTH         (WORD_WIDTH        ),
    .KERNEL_H_MAX       (KERNEL_H_MAX      ),
    .BEATS_CONFIG_3X3_1 (BEATS_CONFIG_3X3_1),
    .BEATS_CONFIG_1X1_1 (BEATS_CONFIG_1X1_1),
    .I_IMAGE_IS_NOT_MAX        (I_IMAGE_IS_NOT_MAX       ),
    .I_IMAGE_IS_MAX            (I_IMAGE_IS_MAX           ),
    .I_IMAGE_IS_LRELU          (I_IMAGE_IS_LRELU         ),
    .I_IMAGE_KERNEL_H_1        (I_IMAGE_KERNEL_H_1       ),
    .TUSER_WIDTH_IM_SHIFT_IN   (TUSER_WIDTH_IM_SHIFT_IN  ),
    .TUSER_WIDTH_IM_SHIFT_OUT  (TUSER_WIDTH_IM_SHIFT_OUT ),

    .IM_CIN_MAX                (IM_CIN_MAX      ),
    .IM_BLOCKS_MAX             (IM_BLOCKS_MAX   ),
    .IM_COLS_MAX               (IM_COLS_MAX     ),
    .S_WEIGHTS_WIDTH           (S_WEIGHTS_WIDTH ),
    .LATENCY_BRAM              (LATENCY_BRAM    ),
    .I_WEIGHTS_IS_TOP_BLOCK    (I_WEIGHTS_IS_TOP_BLOCK   ),
    .I_WEIGHTS_IS_BOTTOM_BLOCK (I_WEIGHTS_IS_BOTTOM_BLOCK),
    .I_WEIGHTS_IS_1X1          (I_WEIGHTS_IS_1X1         ),
    .I_WEIGHTS_IS_COLS_1_K2    (I_WEIGHTS_IS_COLS_1_K2   ),
    .I_WEIGHTS_IS_CONFIG       (I_WEIGHTS_IS_CONFIG      ),
    .I_WEIGHTS_KERNEL_W_1      (I_WEIGHTS_KERNEL_W_1     ),
    .TUSER_WIDTH_WEIGHTS_OUT   (TUSER_WIDTH_WEIGHTS_OUT  ),

    .I_IS_NOT_MAX              (I_IS_NOT_MAX             ),
    .I_IS_MAX                  (I_IS_MAX                 ),
    .I_IS_1X1                  (I_IS_1X1                 ),
    .I_IS_LRELU                (I_IS_LRELU               ),
    .I_IS_TOP_BLOCK            (I_IS_TOP_BLOCK           ),
    .I_IS_BOTTOM_BLOCK         (I_IS_BOTTOM_BLOCK        ),
    .I_IS_COLS_1_K2            (I_IS_COLS_1_K2           ),
    .I_IS_CONFIG               (I_IS_CONFIG              ),
    .I_IS_CIN_LAST             (I_IS_CIN_LAST            ),
    .I_KERNEL_W_1              (I_KERNEL_W_1             ),
    .TUSER_WIDTH_CONV_IN       (TUSER_WIDTH_CONV_IN      )
  ) pipe (.*);

  logic [WORD_WIDTH-1:0] s_data_pixels_1 [IM_IN_S_DATA_WORDS-1:0];
  logic [WORD_WIDTH-1:0] s_data_pixels_2 [IM_IN_S_DATA_WORDS-1:0];
  logic [7:0]            s_data_weights  [S_WEIGHTS_WIDTH /8-1:0];
  logic [WORD_WIDTH-1:0] m_data_pixels_1 [UNITS-1:0];
  logic [WORD_WIDTH-1:0] m_data_pixels_2 [UNITS-1:0];
  logic [WORD_WIDTH-1:0] m_data_weights  [CORES-1:0][KERNEL_W_MAX-1:0];
  logic [WORD_WIDTH-1:0] m_data_weights_linear  [CORES*KERNEL_W_MAX-1:0];
  logic [UNITS-1:0] m_axis_tkeep = {UNITS{1'b1}};

  assign {>>{s_axis_pixels_1_tdata}} = s_data_pixels_1;
  assign {>>{s_axis_pixels_2_tdata}} = s_data_pixels_2;
  assign {>>{s_axis_weights_tdata}}  = s_data_weights;
  assign m_data_pixels_1 = {>>{m_axis_pixels_1_tdata}};
  assign m_data_pixels_2 = {>>{m_axis_pixels_2_tdata}};
  assign m_data_weights  = {>>{m_axis_weights_tdata }};
  assign m_data_weights_linear  = {>>{m_axis_weights_tdata}};

  int status, file_im_1, file_im_2, file_weights;

  AXIS_Slave #(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(IM_IN_S_DATA_WORDS), .VALID_PROB(10)) s_pixels_1  = new(.file_path(path_im_1   ), .words_per_packet(WORDS_1), .iterations(ITERATIONS));
  AXIS_Slave #(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(IM_IN_S_DATA_WORDS), .VALID_PROB(10)) s_pixels_2  = new(.file_path(path_im_2   ), .words_per_packet(WORDS_2), .iterations(ITERATIONS));
  AXIS_Slave #(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(S_WEIGHTS_WIDTH /8), .VALID_PROB(10)) s_weights   = new(.file_path(path_weights), .words_per_packet(WORDS_W), .iterations(ITERATIONS));
  initial forever s_pixels_1.axis_feed(aclk, s_axis_pixels_1_tready, s_axis_pixels_1_tvalid, s_data_pixels_1, s_axis_pixels_1_tkeep, s_axis_pixels_1_tlast);
  initial forever s_pixels_2.axis_feed(aclk, s_axis_pixels_2_tready, s_axis_pixels_2_tvalid, s_data_pixels_2, s_axis_pixels_2_tkeep, s_axis_pixels_2_tlast);
  initial forever  s_weights.axis_feed(aclk, s_axis_weights_tready , s_axis_weights_tvalid , s_data_weights , s_axis_weights_tkeep , s_axis_weights_tlast);
  
  AXIS_Master#(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(UNITS), .READY_PROB(10), .CLK_PERIOD(CLK_PERIOD)) m_pixels_1 = new(.file_base(base_im_out_1));
  // AXIS_Master#(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(UNITS), .READY_PROB(70), .CLK_PERIOD(CLK_PERIOD)) m_pixels_2 = new(.file_base(base_im_out_2));
  // AXIS_Master#(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(CORES*KERNEL_W_MAX), .READY_PROB(70), .CLK_PERIOD(CLK_PERIOD)) m_weights = new(.file_base(base_weights));
  initial forever m_pixels_1.axis_read(aclk, m_axis_tready, m_axis_tvalid, m_data_pixels_1, m_axis_tkeep, m_axis_tlast);
  // initial forever m_pixels_2.axis_read(aclk, m_axis_tready, m_axis_tvalid, m_data_pixels_2, {UNITS{1'b1}}, m_axis_tlast);
  // initial forever m_weights .axis_read(aclk, m_axis_tready, m_axis_tvalid, m_data_weights_linear , {UNITS{1'b1}}, m_axis_tlast);
  

  /*
    Extract the counters to waveform
  */
  int s_words_1, s_words_2, s_words_w, m_words_1, m_words_w, s_itr_1, s_itr_2, s_itr_w, m_itr; 
  initial forever begin
    @(posedge aclk);
    s_words_1 = s_pixels_1.i_words;
    s_words_2 = s_pixels_2.i_words;
    s_words_w = s_weights.i_words;
    // m_words_1 = m_pixels_1.i_words;
    // m_words_w = m_weights.i_words;
    s_itr_1 = s_pixels_1.i_itr;
    s_itr_2 = s_pixels_2.i_itr;
    s_itr_w = s_weights.i_itr;
    m_itr = m_pixels_1.i_itr;
  end

  initial begin
    aresetn           <= 0;
    aresetn           <= 1;
    #(CLK_PERIOD*3)

    @(posedge aclk);
    s_pixels_1.enable <= 1;
    s_pixels_2.enable <= 1;
    s_weights.enable  <= 1;
    m_pixels_1.enable <= 1;
  end

endmodule