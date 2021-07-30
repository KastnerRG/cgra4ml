`include "params.v"

module axis_accelerator (
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
    lrelu_m_axis_tlast    ,
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

  localparam CORES             = `CORES               ;
  localparam UNITS_EDGES       = `UNITS_EDGES         ;
  localparam IM_IN_S_DATA_WORDS= `IM_IN_S_DATA_WORDS  ;
  localparam BITS_KERNEL_H     = `BITS_KERNEL_H       ;
  localparam TKEEP_WIDTH_IM_IN = `TKEEP_WIDTH_IM_IN   ;
  localparam S_WEIGHTS_WIDTH   = `S_WEIGHTS_WIDTH     ;
  localparam M_DATA_WIDTH      = `M_DATA_WIDTH        ;

  localparam UNITS                      = `UNITS                ;
  localparam GROUPS                     = `GROUPS               ;
  localparam COPIES                     = `COPIES               ;
  localparam MEMBERS                    = `MEMBERS              ;
  localparam WORD_WIDTH                 = `WORD_WIDTH           ; 
  localparam WORD_WIDTH_ACC             = `WORD_WIDTH_ACC       ;
  // DEBUG WIDTHS
  localparam DEBUG_CONFIG_WIDTH_W_ROT   = `DEBUG_CONFIG_WIDTH_W_ROT  ;
  localparam DEBUG_CONFIG_WIDTH_IM_PIPE = `DEBUG_CONFIG_WIDTH_IM_PIPE;
  localparam DEBUG_CONFIG_WIDTH_LRELU   = `DEBUG_CONFIG_WIDTH_LRELU  ;
  localparam DEBUG_CONFIG_WIDTH_MAXPOOL = `DEBUG_CONFIG_WIDTH_MAXPOOL;
  localparam DEBUG_CONFIG_WIDTH         = `DEBUG_CONFIG_WIDTH        ;
  // LATENCIES & float widths 
  localparam TUSER_WIDTH_CONV_IN        = `TUSER_WIDTH_CONV_IN       ;
  localparam TUSER_WIDTH_MAXPOOL_IN     = `TUSER_WIDTH_MAXPOOL_IN    ;
  localparam TUSER_WIDTH_LRELU_FMA_1_IN = `TUSER_WIDTH_LRELU_FMA_1_IN;
  localparam TUSER_WIDTH_LRELU_IN       = `TUSER_WIDTH_LRELU_IN      ;

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

  output wire conv_dw_m_axis_tready;
  output wire conv_dw_m_axis_tvalid;
  output wire conv_dw_m_axis_tlast ;
  output wire [TUSER_WIDTH_LRELU_IN -1:0]                 conv_dw_m_axis_tuser;
  output wire [COPIES*GROUPS*UNITS*WORD_WIDTH_ACC   -1:0] conv_dw_m_axis_tdata;

  output wire lrelu_m_axis_tvalid;
  output wire lrelu_m_axis_tlast;
  input  wire lrelu_m_axis_tready;
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

  axis_input_pipe input_pipe (
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

  // // --synthesis translate_off

  // axis_conv_dw_bank DW_TEST (
  //   .aclk             (aclk                  ),
  //   .aresetn          (aresetn               ),
  //   .s_axis_tvalid    (conv_m_axis_tvalid    ),
  //   .s_axis_tready    (conv_m_axis_tready    ),
  //   .s_axis_tdata     (conv_m_axis_tdata     ),
  //   .s_axis_tkeep     (conv_m_axis_tkeep     ),
  //   .s_axis_tlast     (conv_m_axis_tlast     ),
  //   .s_axis_tuser     (conv_m_axis_tuser     ),
  //   .m_axis_tvalid    (conv_dw_m_axis_tvalid ),
  //   .m_axis_tready    (conv_dw_m_axis_tready ),
  //   .m_axis_tdata     (conv_dw_m_axis_tdata  ),
  //   .m_axis_tlast     (conv_dw_m_axis_tlast  ),
  //   .m_axis_tuser     (conv_dw_m_axis_tuser  )
  // );

  // // --synthesis translate_on

  axis_lrelu_engine LRELU_ENGINE (
    .aclk          (aclk                 ),
    .aresetn       (aresetn              ),
    .debug_config  (debug_config_lrelu   ),
    .s_axis_tvalid (conv_m_axis_tvalid   ),
    .s_axis_tready (conv_m_axis_tready   ),
    .s_axis_tdata  (conv_m_axis_tdata    ), // cgmu
    .s_axis_tkeep  (conv_m_axis_tkeep    ), // cgmu
    .s_axis_tlast  (conv_m_axis_tlast    ),
    .s_axis_tuser  (conv_m_axis_tuser    ),
    .m_axis_tvalid (lrelu_m_axis_tvalid  ),
    .m_axis_tready (lrelu_m_axis_tready  ),
    .m_axis_tlast  (lrelu_m_axis_tlast   ),
    .m_axis_tdata  (lrelu_m_axis_tdata   ), // cgu
    .m_axis_tuser  (lrelu_m_axis_tuser   )
  );

  // axis_maxpool_engine MAXPOOL_ENGINE (
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