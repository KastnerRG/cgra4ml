`include "params.v"

module axis_accelerator 
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
    debug_config          ,
    s_axis_pixels_1_tready, 
    s_axis_pixels_1_tvalid, 
    s_axis_pixels_1_tlast , 
    s_axis_pixels_1_tdata , 
    s_axis_pixels_1_tkeep , 
    s_axis_pixels_2_tready,  
    s_axis_pixels_2_tvalid,  
    s_axis_pixels_2_tlast ,   
    s_axis_pixels_2_tdata ,   
    s_axis_pixels_2_tkeep ,      
    s_axis_weights_tready ,
    s_axis_weights_tvalid ,
    s_axis_weights_tlast  ,
    s_axis_weights_tdata  ,
    s_axis_weights_tkeep  ,

    input_m_axis_tready        ,
    input_m_axis_tvalid        ,
    input_m_axis_tlast         ,
    input_m_axis_pixels_1_tdata,
    input_m_axis_pixels_2_tdata,
    input_m_axis_weights_tdata ,
    input_m_axis_tuser         ,

    conv_m_axis_tready    ,
    conv_m_axis_tvalid    ,
    conv_m_axis_tlast     ,
    conv_m_axis_tuser     ,
    conv_m_axis_tdata     ,
    conv_m_axis_tkeep     ,

    conv_dw_m_axis_tready ,
    conv_dw_m_axis_tvalid ,
    conv_dw_m_axis_tlast  ,
    conv_dw_m_axis_tuser  ,
    conv_dw_m_axis_tdata  ,

    lrelu_m_axis_tvalid   ,
    lrelu_m_axis_tready   ,
    lrelu_m_axis_tuser    ,
    lrelu_m_axis_tdata    ,

    maxpool_m_axis_tvalid ,
    maxpool_m_axis_tready ,
    maxpool_m_axis_tdata  ,
    maxpool_m_axis_tkeep  ,
    maxpool_m_axis_tlast  ,

    m_axis_tvalid         ,
    m_axis_tready         ,
    m_axis_tdata          ,
    m_axis_tkeep          ,
    m_axis_tlast
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

  output wire [DEBUG_CONFIG_WIDTH-1:0] debug_config;

  output wire s_axis_pixels_1_tready;
  input  wire s_axis_pixels_1_tvalid;
  input  wire s_axis_pixels_1_tlast ;
  input  wire [WORD_WIDTH*IM_IN_S_DATA_WORDS-1:0] s_axis_pixels_1_tdata;
  input  wire [TKEEP_WIDTH_IM_IN            -1:0] s_axis_pixels_1_tkeep;

  output wire s_axis_pixels_2_tready;
  input  wire s_axis_pixels_2_tvalid;
  input  wire s_axis_pixels_2_tlast ;
  input  wire [WORD_WIDTH*IM_IN_S_DATA_WORDS-1:0] s_axis_pixels_2_tdata;
  input  wire [TKEEP_WIDTH_IM_IN            -1:0] s_axis_pixels_2_tkeep;

  output wire s_axis_weights_tready;
  input  wire s_axis_weights_tvalid;
  input  wire s_axis_weights_tlast ;
  input  wire [S_WEIGHTS_WIDTH    -1:0] s_axis_weights_tdata;
  input  wire [S_WEIGHTS_WIDTH /8 -1:0] s_axis_weights_tkeep;

  output wire input_m_axis_tready;
  output wire input_m_axis_tvalid;
  output wire input_m_axis_tlast ;
  output wire [WORD_WIDTH*UNITS             -1:0] input_m_axis_pixels_1_tdata;
  output wire [WORD_WIDTH*UNITS             -1:0] input_m_axis_pixels_2_tdata;
  output wire [WORD_WIDTH*CORES*MEMBERS     -1:0] input_m_axis_weights_tdata ;
  output wire [TUSER_WIDTH_CONV_IN          -1:0] input_m_axis_tuser         ;

  output wire conv_m_axis_tready;
  output wire conv_m_axis_tvalid;
  output wire conv_m_axis_tlast ;
  output wire [TUSER_WIDTH_LRELU_IN*MEMBERS -1:0] conv_m_axis_tuser;
  output wire [COPIES*MEMBERS*GROUPS*UNITS*WORD_WIDTH_ACC/8 -1:0] conv_m_axis_tkeep;
  output wire [COPIES*MEMBERS*GROUPS*UNITS*WORD_WIDTH_ACC   -1:0] conv_m_axis_tdata; // cgmu

  input  wire conv_dw_m_axis_tready;
  output wire conv_dw_m_axis_tvalid;
  output wire conv_dw_m_axis_tlast ;
  output wire [TUSER_WIDTH_LRELU_IN -1:0]                 conv_dw_m_axis_tuser;
  output wire [COPIES*GROUPS*UNITS*WORD_WIDTH_ACC   -1:0] conv_dw_m_axis_tdata;

  output wire lrelu_m_axis_tvalid;
  output wire lrelu_m_axis_tready;
  output wire [COPIES*GROUPS*UNITS*WORD_WIDTH -1:0] lrelu_m_axis_tdata;
  output wire [TUSER_WIDTH_MAXPOOL_IN-1:0] lrelu_m_axis_tuser;

  output wire maxpool_m_axis_tvalid;
  output wire maxpool_m_axis_tready;
  output wire maxpool_m_axis_tlast;
  output wire [COPIES*GROUPS*UNITS_EDGES -1:0]            maxpool_m_axis_tkeep;
  output wire [COPIES*GROUPS*UNITS_EDGES*WORD_WIDTH -1:0] maxpool_m_axis_tdata;

  output wire m_axis_tready;
  output wire m_axis_tvalid;
  output wire m_axis_tlast;
  output wire [M_DATA_WIDTH  -1:0] m_axis_tdata;
  output wire [M_DATA_WIDTH/8-1:0] m_axis_tkeep;

  wire [GROUPS*UNITS_EDGES*WORD_WIDTH -1:0] max_dw_1_m_axis_tdata;
  wire [GROUPS*UNITS_EDGES-1:0] max_dw_1_m_axis_tkeep;
  wire max_dw_1_m_axis_tvalid, max_dw_1_m_axis_tready, max_dw_1_m_axis_tlast;

  wire [2*BITS_KERNEL_H+DEBUG_CONFIG_WIDTH_IM_PIPE+DEBUG_CONFIG_WIDTH_W_ROT-1:0] debug_config_input_pipe;
  wire [DEBUG_CONFIG_WIDTH_LRELU  -1:0] debug_config_lrelu;
  wire [DEBUG_CONFIG_WIDTH_MAXPOOL-1:0] debug_config_maxpool;

  assign debug_config = {debug_config_maxpool, debug_config_lrelu, debug_config_input_pipe};

  axis_input_pipe #(
    .UNITS                     (UNITS                    ),
    .CORES                     (CORES                    ),
    .WORD_WIDTH                (WORD_WIDTH               ),

    .DEBUG_CONFIG_WIDTH_W_ROT  (DEBUG_CONFIG_WIDTH_W_ROT  ),
    .DEBUG_CONFIG_WIDTH_IM_PIPE(DEBUG_CONFIG_WIDTH_IM_PIPE),

    .KERNEL_H_MAX              (KERNEL_H_MAX             ),
    .BEATS_CONFIG_3X3_1        (BEATS_CONFIG_3X3_1       ),
    .BEATS_CONFIG_1X1_1        (BEATS_CONFIG_1X1_1       ),
    .I_IMAGE_IS_NOT_MAX        (I_IMAGE_IS_NOT_MAX       ),
    .I_IMAGE_IS_MAX            (I_IMAGE_IS_MAX           ),
    .I_IMAGE_IS_LRELU          (I_IMAGE_IS_LRELU         ),
    .I_IMAGE_KERNEL_H_1        (I_IMAGE_KERNEL_H_1       ),
    .TUSER_WIDTH_IM_SHIFT_IN   (TUSER_WIDTH_IM_SHIFT_IN  ),
    .TUSER_WIDTH_IM_SHIFT_OUT  (TUSER_WIDTH_IM_SHIFT_OUT ),

    .IM_CIN_MAX                (IM_CIN_MAX               ),
    .IM_BLOCKS_MAX             (IM_BLOCKS_MAX            ),
    .IM_COLS_MAX               (IM_COLS_MAX              ),
    .S_WEIGHTS_WIDTH           (S_WEIGHTS_WIDTH          ),
    .LATENCY_BRAM              (LATENCY_BRAM             ),
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
    .I_KERNEL_W_1              (I_KERNEL_W_1             ),
    .TUSER_WIDTH_CONV_IN       (TUSER_WIDTH_CONV_IN      )
  ) input_pipe (
    .aclk                      (aclk                      ),
    .aresetn                   (aresetn                   ),
    .debug_config              (debug_config_input_pipe   ),
    .s_axis_pixels_1_tready    (s_axis_pixels_1_tready    ), 
    .s_axis_pixels_1_tvalid    (s_axis_pixels_1_tvalid    ), 
    .s_axis_pixels_1_tlast     (s_axis_pixels_1_tlast     ), 
    .s_axis_pixels_1_tdata     (s_axis_pixels_1_tdata     ), 
    .s_axis_pixels_1_tkeep     (s_axis_pixels_1_tkeep     ), 
    .s_axis_pixels_2_tready    (s_axis_pixels_2_tready    ),  
    .s_axis_pixels_2_tvalid    (s_axis_pixels_2_tvalid    ),  
    .s_axis_pixels_2_tlast     (s_axis_pixels_2_tlast     ),   
    .s_axis_pixels_2_tdata     (s_axis_pixels_2_tdata     ),   
    .s_axis_pixels_2_tkeep     (s_axis_pixels_2_tkeep     ),      
    .s_axis_weights_tready     (s_axis_weights_tready     ),
    .s_axis_weights_tvalid     (s_axis_weights_tvalid     ),
    .s_axis_weights_tlast      (s_axis_weights_tlast      ),
    .s_axis_weights_tdata      (s_axis_weights_tdata      ),
    .s_axis_weights_tkeep      (s_axis_weights_tkeep      ),
    .m_axis_tready             (input_m_axis_tready        ),      
    .m_axis_tvalid             (input_m_axis_tvalid        ),     
    .m_axis_tlast              (input_m_axis_tlast         ),     
    .m_axis_pixels_1_tdata     (input_m_axis_pixels_1_tdata),
    .m_axis_pixels_2_tdata     (input_m_axis_pixels_2_tdata),
    .m_axis_weights_tdata      (input_m_axis_weights_tdata ), // CMG_flat
    .m_axis_tuser              (input_m_axis_tuser         )
  );

  axis_conv_engine CONV_ENGINE (
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
    .m_axis_tkeep         (conv_m_axis_tkeep          ),
    .m_axis_tlast         (conv_m_axis_tlast          ),
    .m_axis_tuser         (conv_m_axis_tuser          )
    );

  // --synthesis translate_off

  axis_conv_dw_bank DW_TEST (
    .aclk             (aclk                  ),
    .aresetn          (aresetn               ),
    .s_axis_tvalid    (conv_m_axis_tvalid    ),
    .s_axis_tready    (conv_m_axis_tready    ),
    .s_axis_tdata     (conv_m_axis_tdata     ),
    .s_axis_tkeep     (conv_m_axis_tkeep     ),
    .s_axis_tlast     (conv_m_axis_tlast     ),
    .s_axis_tuser     (conv_m_axis_tuser     ),
    .m_axis_tvalid    (conv_dw_m_axis_tvalid ),
    .m_axis_tready    (conv_dw_m_axis_tready ),
    .m_axis_tdata     (conv_dw_m_axis_tdata  ),
    .m_axis_tlast     (conv_dw_m_axis_tlast  ),
    .m_axis_tuser     (conv_dw_m_axis_tuser  )
  );

  // --synthesis translate_on

  // axis_lrelu_engine #(
  //   .WORD_WIDTH_IN              (WORD_WIDTH_ACC            ),
  //   .WORD_WIDTH_OUT             (WORD_WIDTH                ),
  //   .DEBUG_CONFIG_WIDTH_LRELU   (DEBUG_CONFIG_WIDTH_LRELU  ),
  //   .UNITS                      (UNITS                     ),
  //   .GROUPS                     (GROUPS                    ),
  //   .COPIES                     (COPIES                    ),
  //   .MEMBERS                    (MEMBERS                   ),
  //   .LRELU_ALPHA                (LRELU_ALPHA               ),
  //   .BEATS_CONFIG_3X3_2         (BEATS_CONFIG_3X3_1    -1  ),
  //   .BEATS_CONFIG_1X1_2         (BEATS_CONFIG_1X1_1    -1  ),    
  //   .BITS_EXP_CONFIG            (BITS_EXP_CONFIG           ),
  //   .BITS_FRA_CONFIG            (BITS_FRA_CONFIG           ),
  //   .BITS_EXP_FMA_1             (BITS_EXP_FMA_1            ),
  //   .BITS_FRA_FMA_1             (BITS_FRA_FMA_1            ),
  //   .BITS_EXP_FMA_2             (BITS_EXP_FMA_2            ),
  //   .BITS_FRA_FMA_2             (BITS_FRA_FMA_2            ),
  //   .LATENCY_FMA_1              (LATENCY_FMA_1             ),
  //   .LATENCY_FMA_2              (LATENCY_FMA_2             ),
  //   .LATENCY_FIXED_2_FLOAT      (LATENCY_FIXED_2_FLOAT     ),
  //   .LATENCY_BRAM               (LATENCY_BRAM              ),
  //   .I_IS_MAX                   (I_IS_MAX                  ),
  //   .I_IS_NOT_MAX               (I_IS_NOT_MAX              ),
  //   .I_IS_1X1                   (I_IS_1X1                  ),
  //   .I_IS_LRELU                 (I_IS_LRELU                ),
  //   .I_IS_TOP_BLOCK             (I_IS_TOP_BLOCK            ),
  //   .I_IS_BOTTOM_BLOCK          (I_IS_BOTTOM_BLOCK         ),
  //   .I_IS_LEFT_COL              (I_IS_LEFT_COL             ),
  //   .I_IS_RIGHT_COL             (I_IS_RIGHT_COL            ),
  //   .TUSER_WIDTH_LRELU_IN       (TUSER_WIDTH_LRELU_IN      ),
  //   .TUSER_WIDTH_LRELU_FMA_1_IN (TUSER_WIDTH_LRELU_FMA_1_IN),
  //   .TUSER_WIDTH_MAXPOOL_IN     (TUSER_WIDTH_MAXPOOL_IN    )
  // ) LRELU_ENGINE (
  //   .aclk          (aclk                 ),
  //   .aresetn       (aresetn              ),
  //   .debug_config  (debug_config_lrelu   ),
  //   .s_axis_tvalid (conv_m_axis_tvalid   ),
  //   .s_axis_tready (conv_m_axis_tready   ),
  //   .s_axis_tdata  (conv_m_axis_tdata    ), // cmgu
  //   .s_axis_tlast  (conv_m_axis_tlast    ),
  //   .s_axis_tuser  (conv_m_axis_tuser    ),
  //   .m_axis_tvalid (lrelu_m_axis_tvalid  ),
  //   .m_axis_tready (lrelu_m_axis_tready  ),
  //   .m_axis_tdata  (lrelu_m_axis_tdata   ), // cgu
  //   .m_axis_tuser  (lrelu_m_axis_tuser   )
  // );

  // axis_maxpool_engine #(
  //   .UNITS        (UNITS       ),
  //   .GROUPS       (GROUPS      ),
  //   .MEMBERS      (MEMBERS     ),
  //   .WORD_WIDTH   (WORD_WIDTH  ),
  //   .DEBUG_CONFIG_WIDTH_MAXPOOL (DEBUG_CONFIG_WIDTH_MAXPOOL),
  //   .KERNEL_H_MAX (KERNEL_H_MAX),
  //   .KERNEL_W_MAX (KERNEL_W_MAX),
  //   .I_IS_NOT_MAX (I_IS_NOT_MAX),
  //   .I_IS_MAX     (I_IS_MAX    ),
  //   .I_IS_1X1     (I_IS_1X1    ),
  //   .TUSER_WIDTH  (TUSER_WIDTH_MAXPOOL_IN )
  // ) MAXPOOL_ENGINE (
  //   .aclk          (aclk                  ),
  //   .aresetn       (aresetn               ),
  //   .debug_config  (debug_config_maxpool  ),
  //   .s_axis_tvalid (lrelu_m_axis_tvalid   ),
  //   .s_axis_tready (lrelu_m_axis_tready   ),
  //   .s_axis_tdata  (lrelu_m_axis_tdata    ), // cgu
  //   .s_axis_tuser  (lrelu_m_axis_tuser    ),
  //   .m_axis_tvalid (maxpool_m_axis_tvalid ),
  //   .m_axis_tready (maxpool_m_axis_tready ),
  //   .m_axis_tdata  (maxpool_m_axis_tdata  ), //cgu
  //   .m_axis_tkeep  (maxpool_m_axis_tkeep  ),
  //   .m_axis_tlast  (maxpool_m_axis_tlast  )
  // );

  // axis_dw_max_1 DW_MAX_1 (
  //   .aclk           (aclk                   ),           
  //   .aresetn        (aresetn                ),        
  //   .s_axis_tvalid  (maxpool_m_axis_tvalid  ),  
  //   .s_axis_tready  (maxpool_m_axis_tready  ),  
  //   .s_axis_tdata   (maxpool_m_axis_tdata   ),   
  //   .s_axis_tkeep   (maxpool_m_axis_tkeep   ),   
  //   .s_axis_tlast   (maxpool_m_axis_tlast   ),   
  //   .m_axis_tvalid  (max_dw_1_m_axis_tvalid ),  
  //   .m_axis_tready  (max_dw_1_m_axis_tready ),  
  //   .m_axis_tdata   (max_dw_1_m_axis_tdata  ),   
  //   .m_axis_tkeep   (max_dw_1_m_axis_tkeep  ),   
  //   .m_axis_tlast   (max_dw_1_m_axis_tlast  )    
  // );

  // axis_dw_max_2 DW_MAX_2 (
  //   .aclk           (aclk                   ),           
  //   .aresetn        (aresetn                ),        
  //   .s_axis_tvalid  (max_dw_1_m_axis_tvalid ),  
  //   .s_axis_tready  (max_dw_1_m_axis_tready ),  
  //   .s_axis_tdata   (max_dw_1_m_axis_tdata  ),   
  //   .s_axis_tkeep   (max_dw_1_m_axis_tkeep  ),   
  //   .s_axis_tlast   (max_dw_1_m_axis_tlast  ),   
  //   .m_axis_tvalid  (m_axis_tvalid          ),  
  //   .m_axis_tready  (m_axis_tready          ),  
  //   .m_axis_tdata   (m_axis_tdata           ),   
  //   .m_axis_tkeep   (m_axis_tkeep           ),   
  //   .m_axis_tlast   (m_axis_tlast           )    
  // );

endmodule