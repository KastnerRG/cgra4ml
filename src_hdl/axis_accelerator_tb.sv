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
  localparam string DIR_PATH = "D:/cnn-fpga/data/";


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
  localparam REPEATS = 3;


  class Layer #(IDX, K, IS_MAX, IM_HEIGHT, IM_WIDTH, IM_CIN);

    string IDX_s, path_im_1, path_im_2, path_weights, base_conv_out, base_lrelu_out, base_max_out, base_output;

    // Calculate beats

    parameter MAX_FACTOR = IS_MAX ? 2 : 1;

    parameter IM_BLOCKS = IM_HEIGHT/UNITS;
    parameter IM_COLS   = IM_WIDTH;

    parameter BEATS_2 = (IM_BLOCKS/MAX_FACTOR) * IM_COLS * IM_CIN;
    parameter WORDS_2 = BEATS_2 * UNITS_EDGES;
    parameter BEATS_1 = BEATS_2 + 1;
    parameter WORDS_1 = BEATS_1 * UNITS_EDGES;
    
    parameter BEATS_CONFIG_1   = K == 1 ? BEATS_CONFIG_1X1_1 : BEATS_CONFIG_3X3_1;
    parameter W_BEATS          = 1 + BEATS_CONFIG_1+1 + K*IM_CIN;
    parameter WORDS_W          = (W_BEATS-1) * KERNEL_W_MAX * CORES + S_WEIGHTS_WIDTH /WORD_WIDTH;
    parameter W_WORDS_PER_BEAT = S_WEIGHTS_WIDTH /WORD_WIDTH;

    parameter BEATS_PER_PACKET = (KERNEL_W_MAX/K)*MEMBERS;
    parameter PACKETS_PER_ITR  = (IM_BLOCKS/MAX_FACTOR)*IM_COLS/MAX_FACTOR;
    parameter BEATS_PER_ITR    = BEATS_PER_PACKET * PACKETS_PER_ITR;

    parameter WORDS_PER_BEAT_RELU = COPIES*GROUPS*UNITS;
    parameter WORDS_OUT_LRELU     = BEATS_PER_ITR * WORDS_PER_BEAT_RELU;

    parameter WORDS_PER_BEAT_MAX  = COPIES*GROUPS*UNITS_EDGES;
    parameter WORDS_OUT_MAX       = BEATS_PER_ITR*WORDS_PER_BEAT_MAX/(MAX_FACTOR**2);

    parameter BEATS_OUT_CONV = BEATS_CONFIG_1+1 + (IM_BLOCKS/MAX_FACTOR)*IM_COLS*(KERNEL_W_MAX/K);
    parameter WORDS_PER_BEAT_CONV = COPIES*MEMBERS*GROUPS*UNITS;
    parameter WORDS_OUT_CONV = BEATS_OUT_CONV * WORDS_PER_BEAT_CONV;

    // Out counters

    parameter IM_HEIGHT_OUT = IM_HEIGHT/MAX_FACTOR;
    parameter IM_WIDTH_OUT  = IM_WIDTH /MAX_FACTOR;
    parameter IM_BLOCKS_OUT = IM_HEIGHT_OUT/UNITS;

    parameter SUB_CORES     = KERNEL_W_MAX / K;
    parameter EFF_CORES     = CORES * SUB_CORES / MAX_FACTOR;

    parameter KW_PAD        = K - 2*IS_MAX;
    
    function new();
        IDX_s.itoa(IDX);
        path_im_1      = {DIR_PATH, IDX_s, "_conv_in_0.txt"    };
        path_im_2      = {DIR_PATH, IDX_s, "_conv_in_1.txt"    };
        path_weights   = {DIR_PATH, IDX_s, "_weights.txt"      };
        base_conv_out  = {DIR_PATH, IDX_s, "_conv_out_sim_"   };
        base_lrelu_out = {DIR_PATH, IDX_s, "_lrelu_out_sim_"  };
        base_max_out   = {DIR_PATH, IDX_s, "_maxpool_out_sim_"};
        base_output    = {DIR_PATH, IDX_s, "_output_sim_"     };
    endfunction

  endclass

  Layer #(.IDX (1 ), .K(3), .IS_MAX(1), .IM_HEIGHT(256), .IM_WIDTH(384), .IM_CIN(3  )) layer = new();
  // Layer #(.IDX (2 ), .K(3), .IS_MAX(1), .IM_HEIGHT(128), .IM_WIDTH(196), .IM_CIN(32  )) layer = new();
  // Layer #(.IDX (3 ), .K(3), .IS_MAX(0), .IM_HEIGHT(64 ), .IM_WIDTH(96 ), .IM_CIN(64 )) layer = new();
  // Layer #(.IDX (4 ), .K(1), .IS_MAX(0), .IM_HEIGHT(64 ), .IM_WIDTH(96 ), .IM_CIN(128)) layer = new();
  // Layer #(.IDX (14), .K(3), .IS_MAX(0), .IM_HEIGHT(8  ), .IM_WIDTH(12 ), .IM_CIN(512)) layer = new();

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


  AXIS_Slave #(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(IM_IN_S_DATA_WORDS), .VALID_PROB(VALID_PROB)) s_pixels_1  = new(.file_path(layer.path_im_1   ), .words_per_packet(layer.WORDS_1), .iterations(1));
  AXIS_Slave #(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(IM_IN_S_DATA_WORDS), .VALID_PROB(VALID_PROB)) s_pixels_2  = new(.file_path(layer.path_im_2   ), .words_per_packet(layer.WORDS_2), .iterations(1));
  AXIS_Slave #(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(layer.W_WORDS_PER_BEAT  ), .VALID_PROB(VALID_PROB)) s_weights   = new(.file_path(layer.path_weights), .words_per_packet(layer.WORDS_W), .iterations(1));
  initial forever s_pixels_1.axis_feed(aclk, s_axis_pixels_1_tready, s_axis_pixels_1_tvalid, s_data_pixels_1, s_axis_pixels_1_tkeep, s_axis_pixels_1_tlast);
  initial forever s_pixels_2.axis_feed(aclk, s_axis_pixels_2_tready, s_axis_pixels_2_tvalid, s_data_pixels_2, s_axis_pixels_2_tkeep, s_axis_pixels_2_tlast);
  initial forever s_weights .axis_feed(aclk, s_axis_weights_tready , s_axis_weights_tvalid , s_data_weights , s_axis_weights_tkeep , s_axis_weights_tlast );
  
  AXIS_Master#(.WORD_WIDTH(WORD_WIDTH_ACC), .WORDS_PER_BEAT(layer.WORDS_PER_BEAT_CONV), .READY_PROB(READY_PROB), .CLK_PERIOD(CLK_PERIOD), .IS_ACTIVE(0)) m_conv    = new(.file_base(layer.base_conv_out )); // sensitive to tlast
  AXIS_Master#(.WORD_WIDTH(WORD_WIDTH    ), .WORDS_PER_BEAT(layer.WORDS_PER_BEAT_RELU), .READY_PROB(READY_PROB), .CLK_PERIOD(CLK_PERIOD), .IS_ACTIVE(0)) m_lrelu   = new(.file_base(layer.base_lrelu_out), .words_per_packet(layer.WORDS_OUT_LRELU)); // sensitive to words_out
  AXIS_Master#(.WORD_WIDTH(WORD_WIDTH    ), .WORDS_PER_BEAT(layer.WORDS_PER_BEAT_MAX ), .READY_PROB(READY_PROB), .CLK_PERIOD(CLK_PERIOD), .IS_ACTIVE(0)) m_maxpool = new(.file_base(layer.base_max_out  ), .packets_per_file(layer.PACKETS_PER_ITR)); // sensitive to tlast, but multiple tlasts per file
  AXIS_Master#(.WORD_WIDTH(WORD_WIDTH    ), .WORDS_PER_BEAT(M_DATA_WIDTH/8     ), .READY_PROB(READY_PROB), .CLK_PERIOD(CLK_PERIOD), .IS_ACTIVE(1)) m_output  = new(.file_base(layer.base_output   ), .packets_per_file(layer.PACKETS_PER_ITR)); // sensitive to tlast, but multiple tlasts per file
  
  logic [layer.WORDS_PER_BEAT_CONV-1:0] temp_keep_conv  = '1;
  logic [layer.WORDS_PER_BEAT_RELU-1:0] temp_keep_lrelu = '1;
  logic zero_last = 0;

  logic [WORD_WIDTH_ACC-1:0] conv_m_data_linear    [layer.WORDS_PER_BEAT_CONV-1:0];
  logic [WORD_WIDTH    -1:0] lrelu_m_data_linear   [layer.WORDS_PER_BEAT_RELU-1:0];
  logic [WORD_WIDTH    -1:0] maxpool_m_data_linear [layer.WORDS_PER_BEAT_MAX -1:0];
  logic [WORD_WIDTH    -1:0] m_data_linear         [M_DATA_WIDTH/8     -1:0];

  assign conv_m_data_linear    = {>>{conv_m_axis_tdata}};
  assign lrelu_m_data_linear   = {>>{lrelu_m_axis_tdata}};
  assign maxpool_m_data_linear = {>>{maxpool_m_axis_tdata}};
  assign m_data_linear         = {>>{m_axis_tdata}};
  
  initial forever m_conv    .axis_read(aclk, conv_m_axis_tready   , conv_m_axis_tvalid   , conv_m_data_linear    , temp_keep_conv      , conv_m_axis_tlast   );
  initial forever m_lrelu   .axis_read(aclk, lrelu_m_axis_tready  , lrelu_m_axis_tvalid  , lrelu_m_data_linear   , temp_keep_lrelu     , zero_last           );
  initial forever m_maxpool .axis_read(aclk, maxpool_m_axis_tready, maxpool_m_axis_tvalid, maxpool_m_data_linear , maxpool_m_axis_tkeep, maxpool_m_axis_tlast);
  initial forever m_output  .axis_read(aclk, m_axis_tready        , m_axis_tvalid        , m_data_linear         , m_axis_tkeep        , m_axis_tlast        );

  /* COUNTING ELEMENTS*/

  int i_w           = 0;
  int i_w_flipped   = 0;
  int i_blocks      = 0;
  int i_cout        = 0;
  int i_arr, i_bpa;

  assign i_arr = i_blocks % layer.MAX_FACTOR;
  assign i_bpa = i_blocks / layer.MAX_FACTOR;

  initial forever begin
    @(posedge aclk);
    #(CLK_PERIOD*9/10);

    if (maxpool_m_axis_tready && maxpool_m_axis_tvalid) begin
      if (~maxpool_m_axis_tlast)
        i_cout        += GROUPS*COPIES/layer.MAX_FACTOR;
      else begin
        i_cout        = 0;

        if (i_w < layer.IM_WIDTH_OUT) begin
          i_w += 1;
          // flipping
          if (i_w > layer.IM_WIDTH_OUT+1 - layer.KW_PAD)
            i_w_flipped = 2 * layer.IM_WIDTH_OUT - (i_w + layer.KW_PAD);
          else
            i_w_flipped = i_w;
        end
        else begin
          i_w = 0;
          if (i_blocks < layer.IM_BLOCKS_OUT)
            i_blocks += 1;
          else
            i_blocks = 0;
        end
      end
    end
  end
  
  /*
    Get counters from drivers
  */
  bit s_en_1, s_en_2, s_en_w, m_en_conv, m_en_lrelu, m_en_max, m_en_out;
  int s_words_1, s_words_2, s_words_w, s_itr_1, s_itr_2, s_itr_w; 
  int m_words_out, m_words_max, m_words_lrelu, m_words_conv;  
  int m_itr_out, m_itr_max, m_itr_lrelu, m_itr_conv;  
  int m_packets_out, m_packets_max, m_packets_lrelu, m_packets_conv;

  initial forever begin
    @(posedge aclk);
    s_en_1     = s_pixels_1.enable;
    s_en_2     = s_pixels_2.enable;
    s_en_w     = s_weights.enable;
    m_en_conv  = m_conv.enable;
    m_en_lrelu = m_lrelu.enable;
    m_en_max   = m_maxpool.enable;
    m_en_out   = m_output.enable;

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
    if (layer.IS_MAX) s_pixels_2.enable = 1;
    s_weights .enable = 1;
    m_conv.enable     = 1;
    m_lrelu.enable    = 1;
    m_maxpool.enable  = 1;
    m_output.enable   = 1;

    while (m_output.i_itr == 0) begin
      @(posedge aclk);
    end

    repeat(100) @(posedge aclk);
    s_pixels_1.i_itr =0;
    s_pixels_1.enable = 1;
    s_pixels_2.i_itr =0;
    if (layer.IS_MAX) s_pixels_2.enable = 1;

    s_weights.i_itr  = 0;
    s_weights.enable = 1;

  end

endmodule