`include "params.v"
`include "axis_tb.sv"

module axis_accelerator_tb ();
  timeunit 10ns;
  timeprecision 1ns;
  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  localparam ITERATIONS = 2;
  localparam VALID_PROB = 30;
  localparam READY_PROB = 30;

  /*
    IMAGE & KERNEL PARAMETERS
  */

  //  // //################ LAYER 1 : 3x3, maxpool ####################
  
  //  localparam K          = 3;
  //  localparam MAX_FACTOR = 2;
  //  localparam IM_HEIGHT  = 256;
  //  localparam IM_WIDTH   = 384;
  //  localparam IM_CIN     = 3;
  //  string path_im_1      = "D:/cnn-fpga/data/1_conv_in_0.txt";
  //  string path_im_2      = "D:/cnn-fpga/data/1_conv_in_1.txt";
  //  string path_weights   = "D:/cnn-fpga/data/1_weights.txt";
  //  string base_conv_out  = "D:/cnn-fpga/data/1_conv_out_fpga_";
  //  string base_lrelu_out = "D:/cnn-fpga/data/1_lrelu_out_fpga_";
  //  string base_max_out   = "D:/cnn-fpga/data/1_maxpool_out_fpga_";
  //  string base_output    = "D:/cnn-fpga/data/1_output_fpga_";

//  ############ LAYER 3 : 3x3, non-maxpool ####################

 localparam K          = 3;
 localparam MAX_FACTOR = 1;
 localparam IM_HEIGHT  = 64;
 localparam IM_WIDTH   = 96;
 localparam IM_CIN     = 64;
 string path_im_1      = "D:/cnn-fpga/data/3_conv_in_0.txt";
 string path_im_2      = "D:/cnn-fpga/data/3_conv_in_1.txt";
 string path_weights   = "D:/cnn-fpga/data/3_weights.txt";
 string base_conv_out  = "D:/cnn-fpga/data/3_conv_out_fpga_";
 string base_lrelu_out = "D:/cnn-fpga/data/3_lrelu_out_fpga_";
 string base_max_out   = "D:/cnn-fpga/data/3_maxpool_out_fpga_";
 string base_output    = "D:/cnn-fpga/data/3_output_fpga_";

//   // #################### LAYER 4 : 1x1 ####################

//   localparam K          = 1;
//   localparam MAX_FACTOR = 1;
//   localparam IM_HEIGHT  = 64;
//   localparam IM_WIDTH   = 96;
//   localparam IM_CIN     = 128;
//   string path_im_1      = "D:/cnn-fpga/data/4_conv_in_0.txt";
//   string path_im_2      = "D:/cnn-fpga/data/4_conv_in_1.txt";
//   string path_weights   = "D:/cnn-fpga/data/4_weights.txt";
//   string base_conv_out  = "D:/cnn-fpga/data/4_conv_out_fpga_";
//   string base_lrelu_out = "D:/cnn-fpga/data/4_lrelu_out_fpga_";
//   string base_max_out   = "D:/cnn-fpga/data/4_maxpool_out_fpga_";
//   string base_output    = "D:/cnn-fpga/data/4_output_fpga_";

  /*
    SYSTEM PARAMS
  */
  localparam UNITS                 = `UNITS                ;
  localparam GROUPS                = `GROUPS               ;
  localparam COPIES                = `COPIES               ;
  localparam MEMBERS               = `MEMBERS              ;
  localparam CORES                 = `CORES                ;
  localparam WORD_WIDTH            = `WORD_WIDTH           ; 
  localparam WORD_WIDTH_ACC        = `WORD_WIDTH_ACC       ; 
  localparam DEBUG_CONFIG_WIDTH_W_ROT   = `DEBUG_CONFIG_WIDTH_W_ROT  ;
  localparam DEBUG_CONFIG_WIDTH_IM_PIPE = `DEBUG_CONFIG_WIDTH_IM_PIPE;
  localparam DEBUG_CONFIG_WIDTH_LRELU   = `DEBUG_CONFIG_WIDTH_LRELU  ;
  localparam DEBUG_CONFIG_WIDTH_MAXPOOL = `DEBUG_CONFIG_WIDTH_MAXPOOL;
  localparam DEBUG_CONFIG_WIDTH         = `DEBUG_CONFIG_WIDTH        ;
  localparam KERNEL_H_MAX          = `KERNEL_H_MAX         ;   // odd number
  localparam KERNEL_W_MAX          = `KERNEL_W_MAX         ;
  localparam BITS_KERNEL_W         = `BITS_KERNEL_W        ;
  localparam BITS_KERNEL_H         = `BITS_KERNEL_H        ;
  localparam IM_CIN_MAX            = `IM_CIN_MAX           ;
  localparam IM_BLOCKS_MAX         = `IM_BLOCKS_MAX        ;
  localparam IM_COLS_MAX           = `IM_COLS_MAX          ;
  localparam S_WEIGHTS_WIDTH       = `S_WEIGHTS_WIDTH      ;
  localparam M_DATA_WIDTH          = `M_DATA_WIDTH         ;
  localparam LRELU_ALPHA           = `LRELU_ALPHA          ;
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
  localparam I_IS_LEFT_COL              = `I_IS_LEFT_COL ;
  localparam I_IS_RIGHT_COL             = `I_IS_RIGHT_COL;
  localparam TUSER_WIDTH_MAXPOOL_IN     = `TUSER_WIDTH_MAXPOOL_IN    ;
  localparam TUSER_WIDTH_LRELU_FMA_1_IN = `TUSER_WIDTH_LRELU_FMA_1_IN;
  localparam TUSER_WIDTH_LRELU_IN       = `TUSER_WIDTH_LRELU_IN      ;

  localparam UNITS_EDGES        = UNITS + KERNEL_H_MAX-1;
  localparam IM_IN_S_DATA_WORDS = 2**$clog2(UNITS_EDGES);
  localparam TKEEP_WIDTH_IM_IN  = WORD_WIDTH*IM_IN_S_DATA_WORDS/8;
  localparam IM_BLOCKS          = IM_HEIGHT/UNITS;
  localparam IM_COLS            = IM_WIDTH;
  localparam REPEATS = 3;


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

  logic conv_m_axis_tready;
  logic conv_m_axis_tvalid;
  logic conv_m_axis_tlast ;
  logic [TUSER_WIDTH_LRELU_IN  -1:0] conv_m_axis_tuser;
  logic [COPIES*MEMBERS*GROUPS*UNITS*WORD_WIDTH_ACC-1:0] conv_m_axis_tdata; // cmgu
  logic [WORD_WIDTH_ACC-1:0] conv_m_data [COPIES-1:0][MEMBERS-1:0][GROUPS-1:0][UNITS-1:0];

  logic lrelu_m_axis_tvalid;
  logic lrelu_m_axis_tready;
  logic [COPIES*GROUPS*UNITS*WORD_WIDTH -1:0] lrelu_m_axis_tdata;
  logic [WORD_WIDTH-1:0] lrelu_m_data [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [TUSER_WIDTH_MAXPOOL_IN-1:0] lrelu_m_axis_tuser;

  logic maxpool_m_axis_tvalid;
  logic maxpool_m_axis_tready;
  logic maxpool_m_axis_tlast;
  logic [COPIES*GROUPS*UNITS_EDGES*WORD_WIDTH -1:0] maxpool_m_axis_tdata;
  logic [COPIES*GROUPS*UNITS_EDGES -1:0]            maxpool_m_axis_tkeep;
  logic [WORD_WIDTH-1:0] maxpool_m_data   [COPIES-1:0][GROUPS-1:0][UNITS_EDGES-1:0];
  logic                  maxpool_keep_cgu [COPIES-1:0][GROUPS-1:0][UNITS_EDGES-1:0];
  
  logic m_axis_tready;
  logic m_axis_tvalid;
  logic m_axis_tlast;
  logic [M_DATA_WIDTH  -1:0] m_axis_tdata;
  logic [WORD_WIDTH    -1:0] m_data        [M_DATA_WIDTH/WORD_WIDTH-1:0];
  logic [M_DATA_WIDTH/8-1:0] m_axis_tkeep;

  logic [DEBUG_CONFIG_WIDTH_W_ROT  -1:0] debug_config_w_rot;
  logic [DEBUG_CONFIG_WIDTH_IM_PIPE-1:0] debug_config_im_pipe;
  logic [BITS_KERNEL_H-1           -1:0] debug_config_im_shift_1, debug_config_im_shift_2;
  logic [DEBUG_CONFIG_WIDTH_LRELU  -1:0] debug_config_lrelu  ;
  logic [DEBUG_CONFIG_WIDTH_MAXPOOL-1:0] debug_config_maxpool;

  logic [DEBUG_CONFIG_WIDTH-1:0] debug_config;
  assign {debug_config_maxpool,debug_config_lrelu,debug_config_im_pipe,debug_config_im_shift_2,debug_config_im_shift_1,debug_config_w_rot} = debug_config;

  splitter sp (.input_0(debug_config));

  axis_accelerator #(
    .UNITS                     (UNITS                     ),
    .GROUPS                    (GROUPS                    ),
    .COPIES                    (COPIES                    ),
    .MEMBERS                   (MEMBERS                   ),
    .WORD_WIDTH                (WORD_WIDTH                ),
    .KERNEL_H_MAX              (KERNEL_H_MAX              ),
    .BEATS_CONFIG_3X3_1        (BEATS_CONFIG_3X3_1        ),
    .BEATS_CONFIG_1X1_1        (BEATS_CONFIG_1X1_1        ),
    .I_IMAGE_IS_NOT_MAX        (I_IMAGE_IS_NOT_MAX        ),
    .I_IMAGE_IS_MAX            (I_IMAGE_IS_MAX            ),
    .I_IMAGE_IS_LRELU          (I_IMAGE_IS_LRELU          ),
    .I_IMAGE_KERNEL_H_1        (I_IMAGE_KERNEL_H_1        ),
    .TUSER_WIDTH_IM_SHIFT_IN   (TUSER_WIDTH_IM_SHIFT_IN   ),
    .TUSER_WIDTH_IM_SHIFT_OUT  (TUSER_WIDTH_IM_SHIFT_OUT  ),
    .WORD_WIDTH_ACC            (WORD_WIDTH_ACC            ),
    .IM_CIN_MAX                (IM_CIN_MAX                ),
    .IM_BLOCKS_MAX             (IM_BLOCKS_MAX             ),
    .IM_COLS_MAX               (IM_COLS_MAX               ),
    .S_WEIGHTS_WIDTH           (S_WEIGHTS_WIDTH           ),
    .M_DATA_WIDTH              (M_DATA_WIDTH              ),
    .LRELU_ALPHA               (LRELU_ALPHA               ),
    .BITS_EXP_CONFIG           (BITS_EXP_CONFIG           ),
    .BITS_FRA_CONFIG           (BITS_FRA_CONFIG           ),
    .BITS_EXP_FMA_1            (BITS_EXP_FMA_1            ),
    .BITS_FRA_FMA_1            (BITS_FRA_FMA_1            ),
    .BITS_EXP_FMA_2            (BITS_EXP_FMA_2            ),
    .BITS_FRA_FMA_2            (BITS_FRA_FMA_2            ),
    .LATENCY_FMA_1             (LATENCY_FMA_1             ),
    .LATENCY_FMA_2             (LATENCY_FMA_2             ),
    .LATENCY_FIXED_2_FLOAT     (LATENCY_FIXED_2_FLOAT     ),
    .LATENCY_BRAM              (LATENCY_BRAM              ),
    .LATENCY_ACCUMULATOR       (LATENCY_ACCUMULATOR       ),
    .LATENCY_MULTIPLIER        (LATENCY_MULTIPLIER        ),
    .I_WEIGHTS_IS_TOP_BLOCK    (I_WEIGHTS_IS_TOP_BLOCK    ),
    .I_WEIGHTS_IS_BOTTOM_BLOCK (I_WEIGHTS_IS_BOTTOM_BLOCK ),
    .I_WEIGHTS_IS_1X1          (I_WEIGHTS_IS_1X1          ),
    .I_WEIGHTS_IS_COLS_1_K2    (I_WEIGHTS_IS_COLS_1_K2    ),
    .I_WEIGHTS_IS_CONFIG       (I_WEIGHTS_IS_CONFIG       ),
    .I_WEIGHTS_KERNEL_W_1      (I_WEIGHTS_KERNEL_W_1      ),
    .TUSER_WIDTH_WEIGHTS_OUT   (TUSER_WIDTH_WEIGHTS_OUT   ),
    .I_IS_NOT_MAX              (I_IS_NOT_MAX              ),
    .I_IS_MAX                  (I_IS_MAX                  ),
    .I_IS_1X1                  (I_IS_1X1                  ),
    .I_IS_LRELU                (I_IS_LRELU                ),
    .I_IS_TOP_BLOCK            (I_IS_TOP_BLOCK            ),
    .I_IS_BOTTOM_BLOCK         (I_IS_BOTTOM_BLOCK         ),
    .I_IS_COLS_1_K2            (I_IS_COLS_1_K2            ),
    .I_IS_CONFIG               (I_IS_CONFIG               ),
    .I_KERNEL_W_1              (I_KERNEL_W_1              ),
    .TUSER_WIDTH_CONV_IN       (TUSER_WIDTH_CONV_IN       ),
    .I_IS_LEFT_COL             (I_IS_LEFT_COL             ),
    .I_IS_RIGHT_COL            (I_IS_RIGHT_COL            ),
    .TUSER_WIDTH_LRELU_FMA_1_IN(TUSER_WIDTH_LRELU_FMA_1_IN),
    .TUSER_WIDTH_LRELU_IN      (TUSER_WIDTH_LRELU_IN      ),
    .TUSER_WIDTH_MAXPOOL_IN    (TUSER_WIDTH_MAXPOOL_IN    )    
  ) pipe (.*);

  logic [WORD_WIDTH-1:0] s_data_pixels_1 [IM_IN_S_DATA_WORDS-1:0];
  logic [WORD_WIDTH-1:0] s_data_pixels_2 [IM_IN_S_DATA_WORDS-1:0];
  logic [7:0]            s_data_weights  [S_WEIGHTS_WIDTH /8-1:0];

  assign {>>{s_axis_pixels_1_tdata}} = s_data_pixels_1;
  assign {>>{s_axis_pixels_2_tdata}} = s_data_pixels_2;
  assign {>>{s_axis_weights_tdata}}  = s_data_weights;
  assign conv_m_data                 = {>>{conv_m_axis_tdata}};
  assign lrelu_m_data                = {>>{lrelu_m_axis_tdata}};
  assign maxpool_m_data              = {>>{maxpool_m_axis_tdata}};
  assign maxpool_keep_cgu            = {>>{maxpool_m_axis_tkeep}};
  assign m_data                      = {>>{m_axis_tdata}};

  localparam BEATS_2 = (IM_BLOCKS/MAX_FACTOR) * IM_COLS * IM_CIN;
  localparam WORDS_2 = BEATS_2 * UNITS_EDGES;
  localparam BEATS_1 = BEATS_2 + 1;
  localparam WORDS_1 = BEATS_1 * UNITS_EDGES;
  
  localparam BEATS_CONFIG_1   = K == 1 ? BEATS_CONFIG_1X1_1 : BEATS_CONFIG_3X3_1;
  localparam W_BEATS          = 1 + BEATS_CONFIG_1+1 + K*IM_CIN;
  localparam WORDS_W          = (W_BEATS-1) * KERNEL_W_MAX * CORES + S_WEIGHTS_WIDTH /WORD_WIDTH;
  localparam W_WORDS_PER_BEAT = S_WEIGHTS_WIDTH /WORD_WIDTH;

  localparam BEATS_PER_PACKET = (KERNEL_W_MAX/K)*MEMBERS;
  localparam PACKETS_PER_ITR = (IM_BLOCKS/MAX_FACTOR)*IM_COLS;
  localparam BEATS_PER_ITR = BEATS_PER_PACKET * PACKETS_PER_ITR;

  localparam WORDS_PER_BEAT_RELU = COPIES*GROUPS*UNITS;
  localparam WORDS_OUT_LRELU     = BEATS_PER_ITR * WORDS_PER_BEAT_RELU;

  localparam WORDS_PER_BEAT_MAX  = COPIES*GROUPS*UNITS_EDGES/(MAX_FACTOR**2);
  localparam WORDS_OUT_MAX       = BEATS_PER_ITR*WORDS_PER_BEAT_MAX;

  localparam BEATS_OUT_CONV = BEATS_CONFIG_1+1 + (IM_BLOCKS/MAX_FACTOR)*IM_COLS*(KERNEL_W_MAX/K);
  localparam WORDS_PER_BEAT_CONV = COPIES*MEMBERS*GROUPS*UNITS;
  localparam WORDS_OUT_CONV = BEATS_OUT_CONV * WORDS_PER_BEAT_CONV;

  AXIS_Slave #(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(IM_IN_S_DATA_WORDS), .VALID_PROB(VALID_PROB)) s_pixels_1  = new(.file_path(path_im_1   ), .words_per_packet(WORDS_1), .iterations(ITERATIONS));
  AXIS_Slave #(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(IM_IN_S_DATA_WORDS), .VALID_PROB(VALID_PROB)) s_pixels_2  = new(.file_path(path_im_2   ), .words_per_packet(WORDS_2), .iterations(ITERATIONS));
  AXIS_Slave #(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(W_WORDS_PER_BEAT  ), .VALID_PROB(VALID_PROB)) s_weights   = new(.file_path(path_weights), .words_per_packet(WORDS_W), .iterations(ITERATIONS));
  initial forever s_pixels_1.axis_feed(aclk, s_axis_pixels_1_tready, s_axis_pixels_1_tvalid, s_data_pixels_1, s_axis_pixels_1_tkeep, s_axis_pixels_1_tlast);
  initial forever s_pixels_2.axis_feed(aclk, s_axis_pixels_2_tready, s_axis_pixels_2_tvalid, s_data_pixels_2, s_axis_pixels_2_tkeep, s_axis_pixels_2_tlast);
  initial forever s_weights .axis_feed(aclk, s_axis_weights_tready , s_axis_weights_tvalid , s_data_weights , s_axis_weights_tkeep , s_axis_weights_tlast );
  
  AXIS_Master#(.WORD_WIDTH(WORD_WIDTH_ACC), .WORDS_PER_BEAT(WORDS_PER_BEAT_CONV), .READY_PROB(READY_PROB), .CLK_PERIOD(CLK_PERIOD), .IS_ACTIVE(0)) m_conv    = new(.file_base(base_conv_out )); // sensitive to tlast
  AXIS_Master#(.WORD_WIDTH(WORD_WIDTH    ), .WORDS_PER_BEAT(WORDS_PER_BEAT_RELU), .READY_PROB(READY_PROB), .CLK_PERIOD(CLK_PERIOD), .IS_ACTIVE(0)) m_lrelu   = new(.file_base(base_lrelu_out), .words_per_packet(WORDS_OUT_LRELU)); // sensitive to words_out
  AXIS_Master#(.WORD_WIDTH(WORD_WIDTH    ), .WORDS_PER_BEAT(WORDS_PER_BEAT_MAX ), .READY_PROB(READY_PROB), .CLK_PERIOD(CLK_PERIOD), .IS_ACTIVE(0)) m_maxpool = new(.file_base(base_max_out  ), .packets_per_file(PACKETS_PER_ITR)); // sensitive to tlast, but multiple tlasts per file
  AXIS_Master#(.WORD_WIDTH(WORD_WIDTH    ), .WORDS_PER_BEAT(M_DATA_WIDTH/8     ), .READY_PROB(READY_PROB), .CLK_PERIOD(CLK_PERIOD), .IS_ACTIVE(1)) m_output  = new(.file_base(base_output   ), .packets_per_file(PACKETS_PER_ITR)); // sensitive to tlast, but multiple tlasts per file
  
  logic [WORDS_PER_BEAT_CONV-1:0] temp_keep_conv  = '1;
  logic [WORDS_PER_BEAT_RELU-1:0] temp_keep_lrelu = '1;
  logic zero_last = 0;

  logic [WORD_WIDTH_ACC-1:0] conv_m_data_linear    [WORDS_PER_BEAT_CONV-1:0];
  logic [WORD_WIDTH    -1:0] lrelu_m_data_linear   [WORDS_PER_BEAT_RELU-1:0];
  logic [WORD_WIDTH    -1:0] maxpool_m_data_linear [WORDS_PER_BEAT_MAX -1:0];
  logic [WORD_WIDTH    -1:0] m_data_linear         [M_DATA_WIDTH/8     -1:0];

  assign conv_m_data_linear    = {>>{conv_m_axis_tdata}};
  assign lrelu_m_data_linear   = {>>{lrelu_m_axis_tdata}};
  assign maxpool_m_data_linear = {>>{maxpool_m_axis_tdata}};
  assign m_data_linear         = {>>{m_axis_tdata}};
  
  initial forever m_conv    .axis_read(aclk, conv_m_axis_tready   , conv_m_axis_tvalid   , conv_m_data_linear    , temp_keep_conv      , conv_m_axis_tlast   );
  initial forever m_lrelu   .axis_read(aclk, lrelu_m_axis_tready  , lrelu_m_axis_tvalid  , lrelu_m_data_linear   , temp_keep_lrelu     , zero_last           );
  initial forever m_maxpool .axis_read(aclk, maxpool_m_axis_tready, maxpool_m_axis_tvalid, maxpool_m_data_linear , maxpool_m_axis_tkeep, maxpool_m_axis_tlast);
  initial forever m_output  .axis_read(aclk, m_axis_tready        , m_axis_tvalid        , m_data_linear         , m_axis_tkeep        , m_axis_tlast        );

  /*
    Get counters from drivers
  */

  int s_words_1, s_words_2, s_words_w, s_itr_1, s_itr_2, s_itr_w; 
  int m_words_out, m_words_max, m_words_lrelu, m_words_conv;  
  int m_itr_out, m_itr_max, m_itr_lrelu, m_itr_conv;  
  int m_packets_out, m_packets_max, m_packets_lrelu, m_packets_conv;

  initial forever begin
    @(posedge aclk);
    s_words_1     = s_pixels_1.i_words;
    s_words_2     = s_pixels_2.i_words;
    s_words_w     = s_weights .i_words;
    m_words_out   = m_output  .i_words;
    m_words_max   = m_maxpool .i_words;
    m_words_lrelu = m_lrelu   .i_words;
    m_words_conv  = m_conv    .i_words;

    s_itr_1       = s_pixels_1.i_itr;
    s_itr_2       = s_pixels_2.i_itr;
    s_itr_w       = s_weights .i_itr;
    m_itr_out     = m_output  .i_itr;
    m_itr_max     = m_maxpool .i_itr; 
    m_itr_lrelu   = m_lrelu   .i_itr;
    m_itr_conv    = m_conv    .i_itr;

    m_packets_out   = m_output  .i_packets;
    m_packets_max   = m_maxpool .i_packets;
    m_packets_lrelu = m_lrelu   .i_packets;
    m_packets_conv  = m_conv    .i_packets;
  end

  initial begin

    aresetn = 0;
    repeat(2) @(posedge aclk);
    aresetn = 1;

    s_pixels_1.enable = 1;
    s_pixels_2.enable = 1;
    s_weights .enable = 1;
    m_conv.enable     = 1;
    m_lrelu.enable    = 1;
    m_maxpool.enable  = 1;
    m_output.enable   = 1;
  end

endmodule