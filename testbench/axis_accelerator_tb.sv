`timescale 1ns/1ps

`include "../src_hdl/params.v"
`include "axis_tb.sv"
import lrelu_beats::*;

module axis_accelerator_tb ();

  localparam FREQ_HIGH = `FREQ_HIGH;
  localparam FREQ_RATIO = `FREQ_RATIO ;

  localparam CLK_PERIOD_HF = 1000/FREQ_HIGH;
  localparam CLK_PERIOD_LF = FREQ_RATIO*CLK_PERIOD_HF;
  
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD_LF/2) aclk <= ~aclk;
  end

  logic hf_aclk;
  initial begin
    hf_aclk = 0;
    forever #(CLK_PERIOD_HF/2) hf_aclk <= ~hf_aclk;
  end

  localparam ITERATIONS = 1;
  localparam VALID_PROB = 100;
  localparam READY_PROB = 100;
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
  localparam BITS_KH2                   = `BITS_KH2        ;
  localparam TUSER_WIDTH_CONV_IN        = `TUSER_WIDTH_CONV_IN;
  localparam TUSER_WIDTH_MAXPOOL_IN     = `TUSER_WIDTH_MAXPOOL_IN    ;
  localparam TUSER_WIDTH_LRELU_FMA_1_IN = `TUSER_WIDTH_LRELU_FMA_1_IN;
  localparam TUSER_WIDTH_LRELU_IN       = `TUSER_WIDTH_LRELU_IN      ;

  localparam S_WEIGHTS_WIDTH_LF      = `S_WEIGHTS_WIDTH_LF     ;
  localparam S_WEIGHTS_WIDTH_HF      = `S_WEIGHTS_WIDTH_HF     ;
  localparam M_DATA_WIDTH_HF_CONV    = `M_DATA_WIDTH_HF_CONV   ;
  localparam M_DATA_WIDTH_HF_LRELU   = `M_DATA_WIDTH_HF_LRELU  ;
  localparam M_DATA_WIDTH_HF_MAXPOOL = `M_DATA_WIDTH_HF_MAXPOOL;
  localparam M_DATA_WIDTH_LF_CONV_DW = `M_DATA_WIDTH_LF_CONV_DW;
  localparam M_DATA_WIDTH_LF_LRELU   = `M_DATA_WIDTH_LF_LRELU  ;
  localparam M_DATA_WIDTH_LF_MAXPOOL = `M_DATA_WIDTH_LF_MAXPOOL;

  localparam UNITS_EDGES        = `UNITS_EDGES;
  localparam IM_IN_S_DATA_WORDS = `IM_IN_S_DATA_WORDS;
  localparam TKEEP_WIDTH_IM_IN  = `TKEEP_WIDTH_IM_IN;
  localparam REPEATS = 3;


  class Layer #(IDX=0, K=0, IS_MAX=0, IM_HEIGHT=0, IM_WIDTH=0, IM_CIN=0);

    string IDX_s, path_im_1, path_im_2, path_weights, base_conv_out, base_lrelu_out, base_max_out, base_output, base_conv_out_dw;

    // Calculate beats

    parameter MAX_FACTOR = IS_MAX ? 2 : 1;

    parameter IM_BLOCKS = IM_HEIGHT/UNITS;
    parameter IM_COLS   = IM_WIDTH;

    parameter BEATS_2 = (IM_BLOCKS/MAX_FACTOR) * IM_COLS * IM_CIN;
    parameter WORDS_2 = BEATS_2 * UNITS_EDGES;
    parameter BEATS_1 = BEATS_2 + 1;
    parameter WORDS_1 = BEATS_1 * UNITS_EDGES;
    
    parameter BEATS_CONFIG_1     = lrelu_beats::calc_beats_total (.kw2(K/2), .MEMBERS(MEMBERS)) -1;
    parameter W_M_BEATS          = BEATS_CONFIG_1+1 + K*IM_CIN;
    parameter W_S_LF_WORDS_PER_BEAT = S_WEIGHTS_WIDTH_LF /WORD_WIDTH;
    parameter W_S_HF_WORDS_PER_BEAT = S_WEIGHTS_WIDTH_HF /WORD_WIDTH;
    parameter WORDS_W            = W_S_HF_WORDS_PER_BEAT + W_M_BEATS*COPIES*GROUPS*MEMBERS;

    parameter BEATS_PER_PACKET = MEMBERS/K;
    parameter PACKETS_PER_ITR  = (IM_BLOCKS/MAX_FACTOR)*IM_COLS;
    parameter PACKETS_PER_ITR_MAX  = (IM_BLOCKS/MAX_FACTOR)*(IM_COLS/MAX_FACTOR);
    parameter BEATS_PER_ITR    = BEATS_PER_PACKET * PACKETS_PER_ITR;

    parameter WORDS_PER_BEAT_RELU = COPIES*GROUPS*UNITS;
    parameter WORDS_OUT_LRELU     = BEATS_PER_ITR * WORDS_PER_BEAT_RELU;

    parameter WORDS_PER_BEAT_MAX  = COPIES*GROUPS*UNITS_EDGES;
    parameter WORDS_OUT_MAX       = BEATS_PER_ITR*WORDS_PER_BEAT_MAX/(MAX_FACTOR**2);

    parameter BEATS_OUT_CONV = BEATS_CONFIG_1+1 + (IM_BLOCKS/MAX_FACTOR)*IM_COLS;
    parameter WORDS_PER_BEAT_CONV_RAW = COPIES*GROUPS*UNITS*MEMBERS;
    parameter WORDS_PER_BEAT_CONV = COPIES*GROUPS*UNITS*(MEMBERS/K);
    parameter WORDS_OUT_CONV = BEATS_OUT_CONV * WORDS_PER_BEAT_CONV;

    parameter BEATS_OUT_CONV_DW = BEATS_CONFIG_1+1 + (IM_BLOCKS/MAX_FACTOR)*IM_COLS*(MEMBERS/K);
    parameter WORDS_PER_BEAT_CONV_DW = COPIES*GROUPS*UNITS;
    parameter WORDS_OUT_CONV_DW = BEATS_OUT_CONV * WORDS_PER_BEAT_CONV;

    // Out counters

    parameter IM_HEIGHT_OUT = IM_HEIGHT/MAX_FACTOR;
    parameter IM_WIDTH_OUT  = IM_WIDTH /MAX_FACTOR;
    parameter IM_BLOCKS_OUT = IM_HEIGHT_OUT/UNITS;

    parameter SUB_CORES     = MEMBERS / K;
    parameter EFF_CORES     = CORES * SUB_CORES / MAX_FACTOR;

    parameter KW_PAD        = K - 2*IS_MAX;
    
    function new();
        IDX_s.itoa(IDX);
        path_im_1      = {DIR_PATH, IDX_s, "_conv_in_0.txt"    };
        path_im_2      = {DIR_PATH, IDX_s, "_conv_in_1.txt"    };
        path_weights   = {DIR_PATH, IDX_s, "_weights.txt"      };
        base_conv_out  = {DIR_PATH, IDX_s, "_conv_out_sim_"   };
        base_conv_out_dw = {DIR_PATH, IDX_s, "_conv_out_dw_sim_" };
        base_lrelu_out = {DIR_PATH, IDX_s, "_lrelu_out_sim_"  };
        base_max_out   = {DIR_PATH, IDX_s, "_maxpool_out_sim_"};
        base_output    = {DIR_PATH, IDX_s, "_output_sim_"     };

        $display("IDX                     = %d", IDX                    );
        $display("MAX_FACTOR              = %d", MAX_FACTOR             );
        $display("IM_BLOCKS               = %d", IM_BLOCKS              );
        $display("IM_COLS                 = %d", IM_COLS                );
        $display("BEATS_2                 = %d", BEATS_2                );
        $display("WORDS_2                 = %d", WORDS_2                );
        $display("BEATS_1                 = %d", BEATS_1                );
        $display("WORDS_1                 = %d", WORDS_1                );
        $display("BEATS_CONFIG_1          = %d", BEATS_CONFIG_1         );
        $display("W_M_BEATS               = %d", W_M_BEATS              );
        $display("W_S_HF_WORDS_PER_BEAT   = %d", W_S_HF_WORDS_PER_BEAT  );
        $display("W_S_LF_WORDS_PER_BEAT   = %d", W_S_LF_WORDS_PER_BEAT  );
        $display("WORDS_W                 = %d", WORDS_W                );
        $display("BEATS_PER_PACKET        = %d", BEATS_PER_PACKET       );
        $display("PACKETS_PER_ITR         = %d", PACKETS_PER_ITR        );
        $display("PACKETS_PER_ITR_MAX     = %d", PACKETS_PER_ITR_MAX    );
        $display("BEATS_PER_ITR           = %d", BEATS_PER_ITR          );
        $display("WORDS_PER_BEAT_RELU     = %d", WORDS_PER_BEAT_RELU    );
        $display("WORDS_OUT_LRELU         = %d", WORDS_OUT_LRELU        );
        $display("WORDS_PER_BEAT_MAX      = %d", WORDS_PER_BEAT_MAX     );
        $display("WORDS_OUT_MAX           = %d", WORDS_OUT_MAX          );
        $display("BEATS_OUT_CONV          = %d", BEATS_OUT_CONV         );
        $display("WORDS_PER_BEAT_CONV_RAW = %d", WORDS_PER_BEAT_CONV_RAW);
        $display("WORDS_PER_BEAT_CONV     = %d", WORDS_PER_BEAT_CONV    );
        $display("WORDS_OUT_CONV          = %d", WORDS_OUT_CONV         );
        $display("BEATS_OUT_CONV_DW       = %d", BEATS_OUT_CONV_DW      );
        $display("WORDS_PER_BEAT_CONV_DW  = %d", WORDS_PER_BEAT_CONV_DW );
        $display("WORDS_OUT_CONV_DW       = %d", WORDS_OUT_CONV_DW      );
        $display("IM_HEIGHT_OUT           = %d", IM_HEIGHT_OUT          );
        $display("IM_WIDTH_OUT            = %d", IM_WIDTH_OUT           );
        $display("IM_BLOCKS_OUT           = %d", IM_BLOCKS_OUT          );
        $display("SUB_CORES               = %d", SUB_CORES              );
        $display("EFF_CORES               = %d", EFF_CORES              );
        $display("KW_PAD                  = %d", KW_PAD                 );
    endfunction

  endclass

  Layer #(.IDX (1 ), .K(3), .IS_MAX(1), .IM_HEIGHT(256), .IM_WIDTH(384), .IM_CIN(3  )) layer = new();
  // Layer #(.IDX (2 ), .K(3), .IS_MAX(1), .IM_HEIGHT(128), .IM_WIDTH(196), .IM_CIN(32  )) layer = new();
  // Layer #(.IDX (3 ), .K(3), .IS_MAX(0), .IM_HEIGHT(64 ), .IM_WIDTH(96 ), .IM_CIN(64 )) layer = new();
  // Layer #(.IDX (4 ), .K(1), .IS_MAX(0), .IM_HEIGHT(64 ), .IM_WIDTH(96 ), .IM_CIN(128)) layer = new();
  // Layer #(.IDX (14), .K(3), .IS_MAX(0), .IM_HEIGHT(8  ), .IM_WIDTH(12 ), .IM_CIN(512)) layer = new();

  localparam PACKETS_PER_ITR     = layer.PACKETS_PER_ITR;
  localparam PACKETS_PER_ITR_MAX = layer.PACKETS_PER_ITR_MAX;
  localparam WORDS_OUT_LRELU     = layer.WORDS_OUT_LRELU;

  logic aresetn;
  logic hf_aresetn;
  logic s_axis_pixels_1_tready;
  logic s_axis_pixels_1_tvalid;
  logic s_axis_pixels_1_tlast ;
  logic [IM_IN_S_DATA_WORDS -1:0][WORD_WIDTH-1:0] s_axis_pixels_1_tdata;
  logic [TKEEP_WIDTH_IM_IN-1:0] s_axis_pixels_1_tkeep;

  logic s_axis_pixels_2_tready;
  logic s_axis_pixels_2_tvalid;
  logic s_axis_pixels_2_tlast ;
  logic [IM_IN_S_DATA_WORDS -1:0][WORD_WIDTH-1:0] s_axis_pixels_2_tdata;
  logic [TKEEP_WIDTH_IM_IN-1:0] s_axis_pixels_2_tkeep;

  logic s_axis_weights_tready;
  logic s_axis_weights_tvalid;
  logic s_axis_weights_tlast ;
  logic [S_WEIGHTS_WIDTH_LF/WORD_WIDTH-1:0][WORD_WIDTH-1:0] s_axis_weights_tdata;
  logic [S_WEIGHTS_WIDTH_LF/8 -1:0] s_axis_weights_tkeep;

  bit   conv_m_axis_tready;
  logic conv_m_axis_tvalid;
  logic conv_m_axis_tlast ;
  logic [MEMBERS-1:0][TUSER_WIDTH_LRELU_IN -1:0] conv_m_axis_tuser;
  logic [M_DATA_WIDTH_HF_CONV/WORD_WIDTH_ACC -1:0][WORD_WIDTH_ACC   -1:0] conv_m_axis_tdata;
  logic [M_DATA_WIDTH_HF_CONV/WORD_WIDTH_ACC -1:0][WORD_WIDTH_ACC/8 -1:0] conv_m_axis_tkeep;
  logic [M_DATA_WIDTH_HF_CONV/WORD_WIDTH_ACC -1:0] conv_m_axis_tkeep_acc;

  generate
    for (genvar i=0; i<M_DATA_WIDTH_HF_CONV/WORD_WIDTH_ACC; i++)
      assign conv_m_axis_tkeep_acc[i] = conv_m_axis_tkeep[i][0];
  endgenerate

  bit   conv_dw2_lf_m_axis_tready = 1;
  logic conv_dw2_lf_m_axis_tvalid;
  logic conv_dw2_lf_m_axis_tlast ;
  logic [M_DATA_WIDTH_LF_CONV_DW/WORD_WIDTH_ACC -1:0][WORD_WIDTH_ACC   -1:0] conv_dw2_lf_m_axis_tdata;
  logic [M_DATA_WIDTH_LF_CONV_DW/WORD_WIDTH_ACC -1:0][WORD_WIDTH_ACC/8 -1:0] conv_dw2_lf_m_axis_tkeep;

  logic lrelu_m_axis_tvalid;
  bit   lrelu_m_axis_tready;
  logic lrelu_m_axis_tlast;
  logic [M_DATA_WIDTH_HF_LRELU/WORD_WIDTH-1:0][WORD_WIDTH-1:0] lrelu_m_axis_tdata;
  logic [TUSER_WIDTH_MAXPOOL_IN -1:0] lrelu_m_axis_tuser;
  logic [M_DATA_WIDTH_HF_LRELU/WORD_WIDTH-1:0] lrelu_m_axis_tkeep = '1;

  bit   lrelu_dw_lf_m_axis_tready = 1;
  logic lrelu_dw_lf_m_axis_tvalid;
  logic lrelu_dw_lf_m_axis_tlast;
  logic [M_DATA_WIDTH_LF_LRELU/WORD_WIDTH-1:0][WORD_WIDTH-1:0] lrelu_dw_lf_m_axis_tdata;
  logic [M_DATA_WIDTH_LF_LRELU/8 -1:0] lrelu_dw_lf_m_axis_tkeep;

  logic max_m_axis_tvalid;
  bit   max_m_axis_tready;
  logic max_m_axis_tlast;
  logic [M_DATA_WIDTH_HF_MAXPOOL/WORD_WIDTH -1:0] max_m_axis_tkeep;
  logic [M_DATA_WIDTH_HF_MAXPOOL/WORD_WIDTH -1:0][WORD_WIDTH-1:0] max_m_axis_tdata;

  logic max_dw2_lf_m_axis_tvalid;
  bit   max_dw2_lf_m_axis_tready;
  logic max_dw2_lf_m_axis_tlast;
  logic [M_DATA_WIDTH_LF_MAXPOOL/WORD_WIDTH -1:0][WORD_WIDTH-1:0] max_dw2_lf_m_axis_tdata;
  logic [M_DATA_WIDTH_LF_MAXPOOL/8 -1:0] max_dw2_lf_m_axis_tkeep;

  logic [DEBUG_CONFIG_WIDTH_W_ROT  -1:0] debug_config_w_rot;
  logic [DEBUG_CONFIG_WIDTH_IM_PIPE-1:0] debug_config_im_pipe;
  logic [BITS_KH2                  -1:0] debug_config_im_shift_1, debug_config_im_shift_2;
  logic [DEBUG_CONFIG_WIDTH_LRELU  -1:0] debug_config_lrelu  ;
  logic [DEBUG_CONFIG_WIDTH_MAXPOOL-1:0] debug_config_maxpool;

  assign hf_aresetn = aresetn;
  
  logic [DEBUG_CONFIG_WIDTH-1:0] debug_config;
  assign {debug_config_maxpool,debug_config_lrelu,debug_config_im_pipe,debug_config_im_shift_2,debug_config_im_shift_1,debug_config_w_rot} = debug_config;

  // splitter sp (.input_0(debug_config));

  axis_accelerator pipe (.*);

  AXIS_Slave #(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(IM_IN_S_DATA_WORDS), .VALID_PROB(VALID_PROB)) s_pixels_1  = new(.file_path(layer.path_im_1   ), .words_per_packet(layer.WORDS_1), .iterations(1));
  AXIS_Slave #(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(IM_IN_S_DATA_WORDS), .VALID_PROB(VALID_PROB)) s_pixels_2  = new(.file_path(layer.path_im_2   ), .words_per_packet(layer.WORDS_2), .iterations(1));
  AXIS_Slave #(.WORD_WIDTH(WORD_WIDTH), .WORDS_PER_BEAT(layer.W_S_LF_WORDS_PER_BEAT  ), .VALID_PROB(VALID_PROB)) s_weights   = new(.file_path(layer.path_weights), .words_per_packet(layer.WORDS_W), .iterations(1));

  initial forever s_pixels_1.axis_feed(aclk, s_axis_pixels_1_tready, s_axis_pixels_1_tvalid, s_axis_pixels_1_tdata, s_axis_pixels_1_tkeep, s_axis_pixels_1_tlast);
  initial forever s_pixels_2.axis_feed(aclk, s_axis_pixels_2_tready, s_axis_pixels_2_tvalid, s_axis_pixels_2_tdata, s_axis_pixels_2_tkeep, s_axis_pixels_2_tlast);
  initial forever s_weights .axis_feed(aclk, s_axis_weights_tready , s_axis_weights_tvalid , s_axis_weights_tdata , s_axis_weights_tkeep , s_axis_weights_tlast );
  
  AXIS_Master#(.WORD_WIDTH(WORD_WIDTH_ACC), .WORDS_PER_BEAT(M_DATA_WIDTH_HF_CONV/WORD_WIDTH_ACC), .READY_PROB(READY_PROB), .CLK_PERIOD(CLK_PERIOD_HF), .IS_ACTIVE(0)) m_conv    = new(.file_base(layer.base_conv_out   )); // sensitive to tlast
  AXIS_Master#(.WORD_WIDTH(WORD_WIDTH    ), .WORDS_PER_BEAT(M_DATA_WIDTH_HF_LRELU/WORD_WIDTH   ), .READY_PROB(READY_PROB), .CLK_PERIOD(CLK_PERIOD_HF), .IS_ACTIVE(0)) m_lrelu   = new(.file_base(layer.base_lrelu_out   ), .words_per_packet(layer.WORDS_OUT_LRELU    )); // sensitive to words_out
  AXIS_Master#(.WORD_WIDTH(WORD_WIDTH    ), .WORDS_PER_BEAT(M_DATA_WIDTH_LF_MAXPOOL/WORD_WIDTH ), .READY_PROB(READY_PROB), .CLK_PERIOD(CLK_PERIOD_LF), .IS_ACTIVE(1)) m_max     = new(.file_base(layer.base_output      ), .packets_per_file(layer.PACKETS_PER_ITR_MAX)); // sensitive to tlast, but multiple tlasts per file

  initial forever m_conv .axis_read(hf_aclk, conv_m_axis_tready      , conv_m_axis_tvalid      , conv_m_axis_tdata      , conv_m_axis_tkeep_acc   , conv_m_axis_tlast      );
  initial forever m_lrelu.axis_read(hf_aclk, lrelu_m_axis_tready     , lrelu_m_axis_tvalid     , lrelu_m_axis_tdata     , lrelu_m_axis_tkeep      , lrelu_m_axis_tlast     );
  initial forever m_max  .axis_read(   aclk, max_dw2_lf_m_axis_tready, max_dw2_lf_m_axis_tvalid, max_dw2_lf_m_axis_tdata, max_dw2_lf_m_axis_tkeep , max_dw2_lf_m_axis_tlast);

  /* COUNTING ELEMENTS*/

  int i_w           = 0;
  int i_w_flipped   = 0;
  int i_blocks      = 0;
  int i_cout        = 0;
  int i_arr, i_bpa;

  assign i_arr = i_blocks % layer.MAX_FACTOR;
  assign i_bpa = i_blocks / layer.MAX_FACTOR;
  
  /*
    Get counters from drivers
  */
  bit s_en_1, s_en_2, s_en_w, m_en_conv, m_en_lrelu, m_en_max;
  int s_words_1, s_words_2, s_words_w, s_itr_1, s_itr_2, s_itr_w; 
  int m_words_max, m_words_lrelu, m_words_conv;  
  int m_itr_max, m_itr_lrelu, m_itr_conv;  
  int m_packets_max, m_packets_lrelu, m_packets_conv;

  initial forever begin
    @(posedge aclk);
    s_en_1     = s_pixels_1.enable;
    s_en_2     = s_pixels_2.enable;
    s_en_w     = s_weights.enable;
    m_en_conv  = m_conv.enable;
    m_en_lrelu = m_lrelu.enable;
    m_en_max   = m_max    .enable;

    s_words_1     = s_pixels_1.i_words;
    s_words_2     = s_pixels_2.i_words;
    s_words_w     = s_weights .i_words;
    m_words_max   = m_max     .i_words;
    m_words_lrelu = m_lrelu   .i_words;
    m_words_conv  = m_conv.i_words;  

    s_itr_1       = s_pixels_1.i_itr;
    s_itr_2       = s_pixels_2.i_itr;
    s_itr_w       = s_weights .i_itr;
    m_itr_max     = m_max     .i_itr; 
    m_itr_lrelu   = m_lrelu   .i_itr;
    m_itr_conv = m_conv .i_itr;

    m_packets_max   = m_max     .i_packets;
    m_packets_lrelu = m_lrelu   .i_packets;
    m_packets_conv = m_conv .i_packets;
  end

  initial begin

    aresetn = 0;
    repeat(2) @(posedge aclk);
    aresetn = 1;

    s_pixels_1.enable = 1;
    if (layer.IS_MAX) s_pixels_2.enable = 1;
    s_weights .enable = 1;
    m_conv.enable  = 1;
    m_lrelu.enable    = 1;
    m_max    .enable  = 1;

    while (m_max.i_itr == 0) begin
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