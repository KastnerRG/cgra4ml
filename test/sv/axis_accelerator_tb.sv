`timescale 1ns/1ps

`include "../../params/params.v"


module axis_accelerator_tb #( 
parameter
  VALID_PROB = 20,
  READY_PROB = 20,

`ifdef ICARUS
  DIR_PATH   = "vectors/",
`else
  DIR_PATH   = "D:/dnn-engine/test/vectors/",
`endif

  // MODEL      = "vgg16_quant",
  // IDX        = "5"
  MODEL      = "test",
  IDX        = "0"
);

  // CLOCK GENERATION

  localparam  FREQ_HIGH = `FREQ_HIGH, 
              FREQ_RATIO = `FREQ_RATIO,
              CLK_PERIOD_HF = 1000/FREQ_HIGH, 
              CLK_PERIOD_LF = FREQ_RATIO*CLK_PERIOD_HF;
  
  logic aclk = 0, hf_aclk = 0;
  initial forever #(CLK_PERIOD_LF/2) aclk    <= ~aclk;
  initial forever #(CLK_PERIOD_HF/2) hf_aclk <= ~hf_aclk;


  // SIGNALS

  localparam  UNITS                      = `UNITS                     ,
              GROUPS                     = `GROUPS                    ,
              COPIES                     = `COPIES                    ,
              MEMBERS                    = `MEMBERS                   ,
              WORD_WIDTH                 = `WORD_WIDTH                , 
              WORD_WIDTH_ACC             = `WORD_WIDTH_ACC            ,
              DEBUG_CONFIG_WIDTH_W_ROT   = `DEBUG_CONFIG_WIDTH_W_ROT  ,
              DEBUG_CONFIG_WIDTH_IM_PIPE = `DEBUG_CONFIG_WIDTH_IM_PIPE,
              DEBUG_CONFIG_WIDTH_LRELU   = `DEBUG_CONFIG_WIDTH_LRELU  ,
              DEBUG_CONFIG_WIDTH_MAXPOOL = `DEBUG_CONFIG_WIDTH_MAXPOOL,
              DEBUG_CONFIG_WIDTH         = `DEBUG_CONFIG_WIDTH        ,
              BITS_KH2                   = `BITS_KH2                  ,
              TUSER_WIDTH_CONV_IN        = `TUSER_WIDTH_CONV_IN       ,
              TUSER_WIDTH_MAXPOOL_IN     = `TUSER_WIDTH_MAXPOOL_IN    ,
              TUSER_WIDTH_LRELU_FMA_1_IN = `TUSER_WIDTH_LRELU_FMA_1_IN,
              TUSER_WIDTH_LRELU_IN       = `TUSER_WIDTH_LRELU_IN      ,
              M_OUTPUT_WIDTH_LF          = `M_OUTPUT_WIDTH_LF         ,
              S_WEIGHTS_WIDTH_LF         = `S_WEIGHTS_WIDTH_LF        ,
              M_DATA_WIDTH_HF_CONV       = `M_DATA_WIDTH_HF_CONV      ,
              M_DATA_WIDTH_HF_LRELU      = `M_DATA_WIDTH_HF_LRELU     ,
              M_DATA_WIDTH_HF_MAXPOOL    = `M_DATA_WIDTH_HF_MAXPOOL   ,
              M_DATA_WIDTH_HF_CONV_DW    = `M_DATA_WIDTH_HF_CONV_DW   ,
              M_DATA_WIDTH_LF_LRELU      = `M_DATA_WIDTH_LF_LRELU     ,
              M_DATA_WIDTH_LF_MAXPOOL    = `M_DATA_WIDTH_LF_MAXPOOL   ,
              UNITS_EDGES                = `UNITS_EDGES               ,
              S_PIXELS_WIDTH_LF          = `S_PIXELS_WIDTH_LF         ,

              WORD_WIDTH_OUT             = WORD_WIDTH_ACC             ; 

  logic aresetn, hf_aresetn;
  logic s_axis_pixels_tready, s_axis_pixels_tvalid, s_axis_pixels_tlast;
  logic [S_PIXELS_WIDTH_LF/WORD_WIDTH -1:0][WORD_WIDTH-1:0] s_axis_pixels_tdata;
  logic [S_PIXELS_WIDTH_LF/WORD_WIDTH -1:0] s_axis_pixels_tkeep;

  logic s_axis_weights_tready, s_axis_weights_tvalid, s_axis_weights_tlast;
  logic [S_WEIGHTS_WIDTH_LF/WORD_WIDTH-1:0][WORD_WIDTH-1:0] s_axis_weights_tdata;
  logic [S_WEIGHTS_WIDTH_LF/WORD_WIDTH-1:0] s_axis_weights_tkeep;

  logic m_axis_tvalid, m_axis_tready, m_axis_tlast;
  logic [M_OUTPUT_WIDTH_LF/WORD_WIDTH_OUT-1:0][WORD_WIDTH_OUT-1:0] m_axis_tdata;
  logic [M_OUTPUT_WIDTH_LF/WORD_WIDTH_OUT-1:0] m_axis_tkeep;

  assign hf_aresetn = aresetn;

  axis_accelerator_asic pipe (.*);

  // SOURCEs & SINKS

  AXIS_Source #(WORD_WIDTH    , S_PIXELS_WIDTH_LF , VALID_PROB, {DIR_PATH, MODEL, "_conv_", IDX, "_x.txt"    }) source_x (aclk, aresetn, s_axis_pixels_tready , s_axis_pixels_tvalid , s_axis_pixels_tlast , s_axis_pixels_tdata , s_axis_pixels_tkeep );
  AXIS_Source #(WORD_WIDTH    , S_WEIGHTS_WIDTH_LF, VALID_PROB, {DIR_PATH, MODEL, "_conv_", IDX, "_w.txt"    }) source_k (aclk, aresetn, s_axis_weights_tready, s_axis_weights_tvalid, s_axis_weights_tlast, s_axis_weights_tdata, s_axis_weights_tkeep);
  AXIS_Sink   #(WORD_WIDTH_OUT, M_OUTPUT_WIDTH_LF , READY_PROB, {DIR_PATH, MODEL, "_conv_", IDX, "_y_sim.txt"}) sink_y   (aclk, aresetn, m_axis_tready        , m_axis_tvalid        , m_axis_tlast        , m_axis_tdata        , m_axis_tkeep        );

  initial source_x.axis_push;
  initial source_k.axis_push;
  initial sink_y  .axis_pull;

  // START SIM  

  initial begin
    aresetn = 0;
    repeat(2) @(posedge aclk);
    aresetn = 1;
    $display("STARTING");

    wait(m_axis_tlast && m_axis_tvalid && m_axis_tready);
    @(posedge aclk) 
    $display("DONE. m_last accepted at sink_y.i_words=%d.", sink_y.i_words);

    @(negedge m_axis_tlast)
    @(posedge aclk)
    $finish();
  end

endmodule