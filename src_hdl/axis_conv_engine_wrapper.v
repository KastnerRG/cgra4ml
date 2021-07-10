`include "params.v"

module conv_splitter (
  s_axis_tdata,
  input_m_axis_pixels_1_tdata,
  input_m_axis_pixels_2_tdata,
  input_m_axis_weights_tdata ,
  input_m_axis_tuser         
);

  `define ZEROS_WIDTH 5
  `define S_WIDTH `WORD_WIDTH*`UNITS + `WORD_WIDTH*`UNITS + `WORD_WIDTH*`CORES*`KERNEL_W_MAX + `TUSER_WIDTH_CONV_IN + `ZEROS_WIDTH

  input  wire [`S_WIDTH-1:0] s_axis_tdata;

  output wire [`WORD_WIDTH*`UNITS              -1:0] input_m_axis_pixels_1_tdata;
  output wire [`WORD_WIDTH*`UNITS              -1:0] input_m_axis_pixels_2_tdata;
  output wire [`WORD_WIDTH*`CORES*`KERNEL_W_MAX-1:0] input_m_axis_weights_tdata ;
  output wire [`TUSER_WIDTH_CONV_IN            -1:0] input_m_axis_tuser         ;

  wire [`ZEROS_WIDTH-1:0] zeros;
  assign {zeros, input_m_axis_tuser, input_m_axis_weights_tdata, input_m_axis_pixels_2_tdata, input_m_axis_pixels_1_tdata} = s_axis_tdata;

endmodule

module axis_conv_engine_wrapper
  #(
    UNITS                      = `UNITS                     ,
    GROUPS                     = `GROUPS                    ,
    COPIES                     = `COPIES                    ,
    MEMBERS                    = `MEMBERS                   ,
    WORD_WIDTH                 = `WORD_WIDTH                , 
    WORD_WIDTH_ACC             = `WORD_WIDTH_ACC            ,
    KERNEL_H_MAX               = `KERNEL_H_MAX              ,   // odd number
    KERNEL_W_MAX               = `KERNEL_W_MAX              ,
    BEATS_CONFIG_3X3_1         = `BEATS_CONFIG_3X3_1        ,
    BEATS_CONFIG_1X1_1         = `BEATS_CONFIG_1X1_1        ,
    // IMAGE TUSER INDICES 
    I_IMAGE_IS_NOT_MAX         = `I_IMAGE_IS_NOT_MAX        ,
    I_IMAGE_IS_MAX             = `I_IMAGE_IS_MAX            ,
    I_IMAGE_IS_LRELU           = `I_IMAGE_IS_LRELU          ,
    I_IMAGE_KERNEL_H_1         = `I_IMAGE_KERNEL_H_1        , 
    TUSER_WIDTH_IM_SHIFT_IN    = `TUSER_WIDTH_IM_SHIFT_IN   ,
    TUSER_WIDTH_IM_SHIFT_OUT   = `TUSER_WIDTH_IM_SHIFT_OUT  ,
    IM_CIN_MAX                 = `IM_CIN_MAX                ,
    IM_BLOCKS_MAX              = `IM_BLOCKS_MAX             ,
    IM_COLS_MAX                = `IM_COLS_MAX               ,
    S_WEIGHTS_WIDTH            = `S_WEIGHTS_WIDTH           ,
    M_DATA_WIDTH               = `M_DATA_WIDTH              ,
    LRELU_ALPHA                = `LRELU_ALPHA               ,
    // DEBUG WIDTHS
    DEBUG_CONFIG_WIDTH_W_ROT   = `DEBUG_CONFIG_WIDTH_W_ROT  ,
    DEBUG_CONFIG_WIDTH_IM_PIPE = `DEBUG_CONFIG_WIDTH_IM_PIPE,
    DEBUG_CONFIG_WIDTH_LRELU   = `DEBUG_CONFIG_WIDTH_LRELU  ,
    DEBUG_CONFIG_WIDTH_MAXPOOL = `DEBUG_CONFIG_WIDTH_MAXPOOL,
    DEBUG_CONFIG_WIDTH         = `DEBUG_CONFIG_WIDTH        ,
    // LATENCIES & float widths 
    BITS_EXP_CONFIG            = `BITS_EXP_CONFIG           ,
    BITS_FRA_CONFIG            = `BITS_FRA_CONFIG           ,
    BITS_EXP_FMA_1             = `BITS_EXP_FMA_1            ,
    BITS_FRA_FMA_1             = `BITS_FRA_FMA_1            ,
    BITS_EXP_FMA_2             = `BITS_EXP_FMA_2            ,
    BITS_FRA_FMA_2             = `BITS_FRA_FMA_2            ,
    LATENCY_FMA_1              = `LATENCY_FMA_1             ,
    LATENCY_FMA_2              = `LATENCY_FMA_2             ,
    LATENCY_FIXED_2_FLOAT      = `LATENCY_FIXED_2_FLOAT     ,
    LATENCY_BRAM               = `LATENCY_BRAM              ,
    LATENCY_ACCUMULATOR        = `LATENCY_ACCUMULATOR       ,
    LATENCY_MULTIPLIER         = `LATENCY_MULTIPLIER        ,
    // WEIGHTS TUSER INDICES
    I_WEIGHTS_IS_TOP_BLOCK     = `I_WEIGHTS_IS_TOP_BLOCK    ,
    I_WEIGHTS_IS_BOTTOM_BLOCK  = `I_WEIGHTS_IS_BOTTOM_BLOCK ,
    I_WEIGHTS_IS_1X1           = `I_WEIGHTS_IS_1X1          ,
    I_WEIGHTS_IS_COLS_1_K2     = `I_WEIGHTS_IS_COLS_1_K2    ,
    I_WEIGHTS_IS_CONFIG        = `I_WEIGHTS_IS_CONFIG       ,
    I_WEIGHTS_IS_CIN_LAST      = `I_WEIGHTS_IS_CIN_LAST     ,
    I_WEIGHTS_KERNEL_W_1       = `I_WEIGHTS_KERNEL_W_1      , 
    TUSER_WIDTH_WEIGHTS_OUT    = `TUSER_WIDTH_WEIGHTS_OUT   ,
    // CONV TUSER INDICES
    I_IS_NOT_MAX               = `I_IS_NOT_MAX              ,
    I_IS_MAX                   = `I_IS_MAX                  ,
    I_IS_1X1                   = `I_IS_1X1                  ,
    I_IS_LRELU                 = `I_IS_LRELU                ,
    I_IS_TOP_BLOCK             = `I_IS_TOP_BLOCK            ,
    I_IS_BOTTOM_BLOCK          = `I_IS_BOTTOM_BLOCK         ,
    I_IS_COLS_1_K2             = `I_IS_COLS_1_K2            ,
    I_IS_CONFIG                = `I_IS_CONFIG               ,
    I_IS_CIN_LAST              = `I_IS_CIN_LAST             ,
    I_KERNEL_W_1               = `I_KERNEL_W_1              , 
    TUSER_WIDTH_CONV_IN        = `TUSER_WIDTH_CONV_IN       ,
    // LRELU & MAXPOOL TUSER INDICES
    I_IS_LEFT_COL              = `I_IS_LEFT_COL             ,
    I_IS_RIGHT_COL             = `I_IS_RIGHT_COL            ,
    TUSER_WIDTH_MAXPOOL_IN     = `TUSER_WIDTH_MAXPOOL_IN    ,
    TUSER_WIDTH_LRELU_FMA_1_IN = `TUSER_WIDTH_LRELU_FMA_1_IN,
    TUSER_WIDTH_LRELU_IN       = `TUSER_WIDTH_LRELU_IN      
  )(
    aclk                  ,
    aresetn               ,

    input_m_axis_tready   ,
    input_m_axis_tvalid   ,
    input_m_axis_tlast    ,
    input_m_axis_pixels_1_tdata,
    input_m_axis_pixels_2_tdata,
    input_m_axis_weights_tdata ,
    input_m_axis_tuser         ,
    
    conv_m_axis_tready,
    conv_m_axis_tvalid,
    conv_m_axis_tlast ,
    conv_m_axis_tuser ,
    conv_m_axis_tdata 
  ); 

  parameter CORES             = `CORES               ;
  parameter UNITS_EDGES       = `UNITS_EDGES         ;
  parameter IM_IN_S_DATA_WORDS= `IM_IN_S_DATA_WORDS  ;
  parameter BITS_CONFIG_COUNT = `BITS_CONFIG_COUNT   ;
  parameter BITS_KERNEL_H     = `BITS_KERNEL_H       ;
  parameter BITS_KERNEL_W     = `BITS_KERNEL_W       ;
  parameter TKEEP_WIDTH_IM_IN = `TKEEP_WIDTH_IM_IN   ;

  /* WIRES */

  input  wire aclk;
  input  wire aresetn;

  input  wire conv_m_axis_tready;
  output wire conv_m_axis_tvalid;
  output wire conv_m_axis_tlast ;
  output wire [TUSER_WIDTH_LRELU_IN  -1:0] conv_m_axis_tuser;
  output wire [COPIES*MEMBERS*GROUPS*UNITS*WORD_WIDTH_ACC-1:0] conv_m_axis_tdata; // cmgu

  output input_m_axis_tready;
  input  input_m_axis_tvalid;
  input  input_m_axis_tlast ;
  input  [WORD_WIDTH*UNITS             -1:0] input_m_axis_pixels_1_tdata;
  input  [WORD_WIDTH*UNITS             -1:0] input_m_axis_pixels_2_tdata;
  input  [WORD_WIDTH*CORES*KERNEL_W_MAX-1:0] input_m_axis_weights_tdata ;
  input  [TUSER_WIDTH_CONV_IN          -1:0] input_m_axis_tuser         ;

  axis_conv_engine #(
    .CORES                (CORES               ), 
    .UNITS                (UNITS               ), 
    .WORD_WIDTH_IN        (WORD_WIDTH          ),  
    .WORD_WIDTH_OUT       (WORD_WIDTH_ACC      ),  
    .LATENCY_ACCUMULATOR  (LATENCY_ACCUMULATOR ), 
    .LATENCY_MULTIPLIER   (LATENCY_MULTIPLIER  ), 
    .KERNEL_W_MAX         (KERNEL_W_MAX        ),  
    .KERNEL_H_MAX         (KERNEL_H_MAX        ), 
    .IM_CIN_MAX           (IM_CIN_MAX          ), 
    .IM_COLS_MAX          (IM_COLS_MAX         ), 
    .I_IS_NOT_MAX         (I_IS_NOT_MAX        ), 
    .I_IS_MAX             (I_IS_MAX            ), 
    .I_IS_1X1             (I_IS_1X1            ), 
    .I_IS_LRELU           (I_IS_LRELU          ), 
    .I_IS_TOP_BLOCK       (I_IS_TOP_BLOCK      ), 
    .I_IS_BOTTOM_BLOCK    (I_IS_BOTTOM_BLOCK   ), 
    .I_IS_COLS_1_K2       (I_IS_COLS_1_K2      ), 
    .I_IS_CONFIG          (I_IS_CONFIG         ), 
    .I_IS_CIN_LAST        (I_IS_CIN_LAST       ), 
    .I_KERNEL_W_1         (I_KERNEL_W_1        ),  
    .I_IS_LEFT_COL        (I_IS_LEFT_COL       ), 
    .I_IS_RIGHT_COL       (I_IS_RIGHT_COL      ), 
    .TUSER_WIDTH_CONV_IN  (TUSER_WIDTH_CONV_IN ), 
    .TUSER_WIDTH_CONV_OUT (TUSER_WIDTH_LRELU_IN)
  ) CONV_ENGINE (
    .aclk                 (aclk                       ),
    .aresetn              (aresetn                    ),
    .s_axis_tvalid        (input_m_axis_tvalid        ),
    .s_axis_tready        (input_m_axis_tready        ),
    .s_axis_tlast         (input_m_axis_tlast         ),
    .s_axis_tuser         (input_m_axis_tuser         ),
    .s_axis_tdata_pixels_1(input_m_axis_pixels_1_tdata), // cu
    .s_axis_tdata_pixels_2(input_m_axis_pixels_2_tdata), // cu
    .s_axis_tdata_weights (input_m_axis_weights_tdata ), // cr = cmg
    .m_axis_tvalid        (conv_m_axis_tvalid         ),
    .m_axis_tready        (conv_m_axis_tready         ),
    .m_axis_tdata         (conv_m_axis_tdata          ), // cmgu
    .m_axis_tlast         (conv_m_axis_tlast          ),
    .m_axis_tuser         (conv_m_axis_tuser          )
    );

endmodule