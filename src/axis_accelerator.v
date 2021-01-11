module axis_accelerator (
    aclk                  ,
    aresetn               ,
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
    m_axis_tvalid         ,
    m_axis_tready         ,
    m_axis_tdata          ,
    // m_axis_tkeep          ,
    m_axis_tuser          ,
    m_axis_tlast
  ); 

  parameter UNITS              = 8;
  parameter GROUPS             = 2;
  parameter COPIES             = 2;
  parameter MEMBERS            = 8;

  parameter WORD_WIDTH         = 8; 
  parameter WORD_WIDTH_ACC     = 25;
  parameter KERNEL_H_MAX       = 3;   // odd number
  parameter KERNEL_W_MAX       = 3;
  parameter BEATS_CONFIG_3X3_1 = 21-1;
  parameter BEATS_CONFIG_1X1_1 = 13-1;

  parameter CORES             = MEMBERS * COPIES * GROUPS;
  parameter UNITS_EDGES       = UNITS + KERNEL_H_MAX-1;
  parameter IM_IN_S_DATA_WORDS= 2**$clog2(UNITS_EDGES);
  parameter BITS_CONFIG_COUNT = $clog2(BEATS_CONFIG_3X3_1);
  parameter BITS_KERNEL_H     = $clog2(KERNEL_H_MAX);
  parameter BITS_KERNEL_W     = $clog2(KERNEL_W_MAX);

  parameter TKEEP_WIDTH_IM_IN = (WORD_WIDTH*IM_IN_S_DATA_WORDS)/8;

  /*
    IMAGE TUSER INDICES
  */
  parameter I_IMAGE_IS_NOT_MAX       = 0;
  parameter I_IMAGE_IS_MAX           = I_IMAGE_IS_NOT_MAX + 1;
  parameter I_IMAGE_IS_LRELU         = I_IMAGE_IS_MAX     + 1;
  parameter I_IMAGE_KERNEL_H_1       = I_IMAGE_IS_LRELU   + 1; 
  parameter TUSER_WIDTH_IM_SHIFT_IN  = I_IMAGE_KERNEL_H_1 + BITS_KERNEL_H;
  parameter TUSER_WIDTH_IM_SHIFT_OUT = I_IMAGE_IS_LRELU   + 1;

  parameter IM_CIN_MAX         = 1024;
  parameter IM_BLOCKS_MAX      = 32;
  parameter IM_COLS_MAX        = 384;
  parameter WEIGHTS_DMA_BITS   = 32;
  parameter LRELU_ALPHA        = 16'd11878;

  /*
    LATENCIES
  */

  parameter LATENCY_FIXED_2_FLOAT = 6;
  parameter LATENCY_FLOAT_32      = 16;
  parameter BRAM_LATENCY          = 2;
  parameter ACCUMULATOR_DELAY     = 2;
  parameter MULTIPLIER_DELAY      = 3;
  
  /*
    WEIGHTS TUSER INDICES
  */
  parameter I_WEIGHTS_IS_TOP_BLOCK    = 0;
  parameter I_WEIGHTS_IS_BOTTOM_BLOCK = I_WEIGHTS_IS_TOP_BLOCK    + 1;
  parameter I_WEIGHTS_IS_1X1          = I_WEIGHTS_IS_BOTTOM_BLOCK + 1;
  parameter I_WEIGHTS_IS_COLS_1_K2    = I_WEIGHTS_IS_1X1          + 1;
  parameter I_WEIGHTS_IS_CONFIG       = I_WEIGHTS_IS_COLS_1_K2    + 1;
  parameter I_WEIGHTS_IS_ACC_LAST     = I_WEIGHTS_IS_CONFIG       + 1;
  parameter I_WEIGHTS_KERNEL_W_1      = I_WEIGHTS_IS_ACC_LAST     + 1; 
  parameter TUSER_WIDTH_WEIGHTS_OUT   = I_WEIGHTS_KERNEL_W_1 + BITS_KERNEL_W;
  /*
    CONV TUSER INDICES
  */
  parameter I_IS_NOT_MAX         = 0;
  parameter I_IS_MAX             = I_IS_NOT_MAX      + 1;
  parameter I_IS_LRELU           = I_IS_MAX          + 1;
  parameter I_IS_TOP_BLOCK       = I_IS_LRELU        + 1;
  parameter I_IS_BOTTOM_BLOCK    = I_IS_TOP_BLOCK    + 1;
  parameter I_IS_1X1             = I_IS_BOTTOM_BLOCK + 1;
  parameter I_IS_COLS_1_K2       = I_IS_1X1          + 1;
  parameter I_IS_CONFIG          = I_IS_COLS_1_K2    + 1;
  parameter I_IS_ACC_LAST        = I_IS_CONFIG       + 1;
  parameter I_KERNEL_W_1         = I_IS_ACC_LAST     + 1; 
  parameter TUSER_WIDTH_CONV_IN  = BITS_KERNEL_W + I_KERNEL_W_1;
  
  /*
    LRELU & MAXPOOL TUSER INDICES
  */
  parameter I_IS_LEFT_COL        = I_IS_1X1      + 1;
  parameter I_IS_RIGHT_COL       = I_IS_LEFT_COL + 1;

  parameter TUSER_WIDTH_MAXPOOL_IN     = 1 + I_IS_MAX;
  parameter TUSER_WIDTH_LRELU_FMA_1_IN = 1 + I_IS_LRELU;
  parameter TUSER_WIDTH_LRELU_IN       = 1 + I_IS_RIGHT_COL;

  parameter M_DATA_WIDTH_CONV    = WORD_WIDTH*CORES*KERNEL_W_MAX;
  parameter M_DATA_WIDTH_LRELU   = WORD_WIDTH_ACC*UNITS*CORES;
  parameter M_DATA_WIDTH_MAXPOOL = GROUPS*UNITS_EDGES*COPIES*WORD_WIDTH;

  /* WIRES */

  input  wire aclk;
  input  wire aresetn;

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
  input  wire [WEIGHTS_DMA_BITS   -1:0] s_axis_weights_tdata;
  input  wire [WEIGHTS_DMA_BITS/8 -1:0] s_axis_weights_tkeep;

  wire conv_s_axis_tready;
  wire conv_s_axis_tvalid;
  wire conv_s_axis_tlast ;
  wire [WORD_WIDTH*UNITS             -1:0] conv_s_axis_pixels_1_tdata;
  wire [WORD_WIDTH*UNITS             -1:0] conv_s_axis_pixels_2_tdata;
  wire [WORD_WIDTH*CORES*KERNEL_W_MAX-1:0] conv_s_axis_weights_tdata ;
  wire [TUSER_WIDTH_CONV_IN          -1:0] conv_s_axis_tuser         ;

  wire lrelu_s_axis_tready;
  wire lrelu_s_axis_tvalid;
  wire lrelu_s_axis_tlast ;
  wire [M_DATA_WIDTH_CONV     -1:0] lrelu_s_axis_tdata_cmgu;
  wire [M_DATA_WIDTH_CONV     -1:0] lrelu_s_axis_tdata_mcgu;
  wire [TUSER_WIDTH_LRELU_IN  -1:0] lrelu_s_axis_tuser;

  wire maxpool_s_axis_tvalid;
  wire maxpool_s_axis_tready;
  wire [M_DATA_WIDTH_LRELU    -1:0] maxpool_s_axis_tdata;
  wire [TUSER_WIDTH_MAXPOOL_IN-1:0] maxpool_s_axis_tuser;

  wire maxpool_m_axis_tvalid;
  wire maxpool_m_axis_tready;
  wire [M_DATA_WIDTH_MAXPOOL     -1:0] maxpool_m_axis_tdata;
  wire [GROUPS*UNITS_EDGES*COPIES-1:0] maxpool_m_axis_tkeep;

  input  wire m_axis_tready;
  output wire m_axis_tvalid;
  output wire m_axis_tlast;
  // output wire [M_DATA_WIDTH_MAXPOOL     -1:0] m_axis_tdata;
  // output wire [GROUPS*UNITS_EDGES*COPIES-1:0] m_axis_tkeep;


  //*********** CONNECT OUTPUT FOR DEBUGGING ***********

  output wire [M_DATA_WIDTH_CONV   -1:0] m_axis_tdata;
  output wire [TUSER_WIDTH_LRELU_IN-1:0] m_axis_tuser;

  assign lrelu_s_axis_tready = m_axis_tready;
  assign m_axis_tvalid       = lrelu_s_axis_tvalid;
  assign m_axis_tuser        = lrelu_s_axis_tuser;
  assign m_axis_tdata        = lrelu_s_axis_tdata_cmgu;

  axis_input_pipe #(
    .UNITS                     (UNITS                    ),
    .WORD_WIDTH                (WORD_WIDTH               ),
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
    .WEIGHTS_DMA_BITS          (WEIGHTS_DMA_BITS         ),
    .BRAM_LATENCY              (BRAM_LATENCY             ),
    .I_WEIGHTS_IS_TOP_BLOCK    (I_WEIGHTS_IS_TOP_BLOCK   ),
    .I_WEIGHTS_IS_BOTTOM_BLOCK (I_WEIGHTS_IS_BOTTOM_BLOCK),
    .I_WEIGHTS_IS_1X1          (I_WEIGHTS_IS_1X1         ),
    .I_WEIGHTS_IS_COLS_1_K2    (I_WEIGHTS_IS_COLS_1_K2   ),
    .I_WEIGHTS_IS_CONFIG       (I_WEIGHTS_IS_CONFIG      ),
    .I_WEIGHTS_KERNEL_W_1      (I_WEIGHTS_KERNEL_W_1     ),
    .TUSER_WIDTH_WEIGHTS_OUT   (TUSER_WIDTH_WEIGHTS_OUT  ),

    .I_IS_NOT_MAX              (I_IS_NOT_MAX             ),
    .I_IS_MAX                  (I_IS_MAX                 ),
    .I_IS_LRELU                (I_IS_LRELU               ),
    .I_IS_TOP_BLOCK            (I_IS_TOP_BLOCK           ),
    .I_IS_BOTTOM_BLOCK         (I_IS_BOTTOM_BLOCK        ),
    .I_IS_1X1                  (I_IS_1X1                 ),
    .I_IS_COLS_1_K2            (I_IS_COLS_1_K2           ),
    .I_IS_CONFIG               (I_IS_CONFIG              ),
    .I_KERNEL_W_1              (I_KERNEL_W_1             ),
    .TUSER_WIDTH_CONV_IN       (TUSER_WIDTH_CONV_IN      )
  ) input_pipe (
    .aclk                      (aclk                      ),
    .aresetn                   (aresetn                   ),
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
    .m_axis_tready             (conv_s_axis_tready        ),      
    .m_axis_tvalid             (conv_s_axis_tvalid        ),     
    .m_axis_tlast              (conv_s_axis_tlast         ),     
    .m_axis_pixels_1_tdata     (conv_s_axis_pixels_1_tdata),
    .m_axis_pixels_2_tdata     (conv_s_axis_pixels_2_tdata),
    .m_axis_weights_tdata      (conv_s_axis_weights_tdata ),
    .m_axis_tuser              (conv_s_axis_tuser         )
  );

  axis_conv_engine #(
    .CORES                (CORES               ), 
    .UNITS                (UNITS               ), 
    .WORD_WIDTH_IN        (WORD_WIDTH          ),  
    .WORD_WIDTH_OUT       (WORD_WIDTH_ACC      ),  
    .ACCUMULATOR_DELAY    (ACCUMULATOR_DELAY   ), 
    .MULTIPLIER_DELAY     (MULTIPLIER_DELAY    ), 
    .KERNEL_W_MAX         (KERNEL_W_MAX        ),  
    .KERNEL_H_MAX         (KERNEL_H_MAX        ), 
    .IM_CIN_MAX           (IM_CIN_MAX          ), 
    .IM_COLS_MAX          (IM_COLS_MAX         ), 
    .I_IS_NOT_MAX         (I_IS_NOT_MAX        ), 
    .I_IS_MAX             (I_IS_MAX            ), 
    .I_IS_LRELU           (I_IS_LRELU          ), 
    .I_IS_TOP_BLOCK       (I_IS_TOP_BLOCK      ), 
    .I_IS_BOTTOM_BLOCK    (I_IS_BOTTOM_BLOCK   ), 
    .I_IS_1X1             (I_IS_1X1            ), 
    .I_IS_COLS_1_K2       (I_IS_COLS_1_K2      ), 
    .I_IS_CONFIG          (I_IS_CONFIG         ), 
    .I_IS_ACC_LAST        (I_IS_ACC_LAST       ), 
    .I_KERNEL_W_1         (I_KERNEL_W_1        ),  
    .I_IS_LEFT_COL        (I_IS_LEFT_COL       ), 
    .I_IS_RIGHT_COL       (I_IS_RIGHT_COL      ), 
    .TUSER_WIDTH_CONV_IN  (TUSER_WIDTH_CONV_IN ), 
    .TUSER_WIDTH_CONV_OUT (TUSER_WIDTH_LRELU_IN)
  ) CONV_ENGINE (
    .aclk                 (aclk                      ),
    .aresetn              (aresetn                   ),
    .s_axis_tvalid        (conv_s_axis_tvalid        ),
    .s_axis_tready        (conv_s_axis_tready        ),
    .s_axis_tlast         (conv_s_axis_tlast         ),
    .s_axis_tuser         (conv_s_axis_tuser         ),
    .s_axis_tdata_pixels_1(conv_s_axis_pixels_1_tdata), // cu
    .s_axis_tdata_pixels_2(conv_s_axis_pixels_2_tdata), // cu
    .s_axis_tdata_weights (conv_s_axis_weights_tdata ), // cr
    .m_axis_tvalid        (lrelu_s_axis_tvalid       ),
    .m_axis_tready        (lrelu_s_axis_tready       ),
    .m_axis_tdata         (lrelu_s_axis_tdata_cmgu   ), // cmgu
    .m_axis_tlast         (lrelu_s_axis_tlast        ),
    .m_axis_tuser         (lrelu_s_axis_tuser        )
    );
    /*
        Convert conv_out (cmgu) into lrelu_in (mcgu)
    */
    generate
      for (genvar c=0; c < COPIES; c=c+1) begin
        for (genvar m=0; m < MEMBERS; m=m+1) begin
          for (genvar g=0; g < GROUPS; g=g+1) begin
            for (genvar u=0; u < UNITS; u=u+1) begin
              assign lrelu_s_axis_tdata_mcgu[(m*COPIES*GROUPS*UNITS + c*GROUPS*UNITS + g*UNITS + u +1)*WORD_WIDTH_ACC-1:(m*COPIES*GROUPS*UNITS + c*GROUPS*UNITS + g*UNITS + u)*WORD_WIDTH_ACC] = lrelu_s_axis_tdata_cmgu[(c*MEMBERS*GROUPS*UNITS + m*GROUPS*UNITS + g*UNITS + u +1)*WORD_WIDTH_ACC-1:(c*MEMBERS*GROUPS*UNITS + m*GROUPS*UNITS + g*UNITS + u)*WORD_WIDTH_ACC];
            end
          end
        end
      end
    endgenerate

  axis_lrelu_engine #(
    .WORD_WIDTH_IN              (WORD_WIDTH_ACC            ),
    .WORD_WIDTH_OUT             (WORD_WIDTH                ),
    .UNITS                      (UNITS                     ),
    .GROUPS                     (GROUPS                    ),
    .COPIES                     (COPIES                    ),
    .MEMBERS                    (MEMBERS                   ),
    .ALPHA                      (LRELU_ALPHA               ),
    .CONFIG_BEATS_3X3_2         (BEATS_CONFIG_3X3_1    -1  ),
    .CONFIG_BEATS_1X1_2         (BEATS_CONFIG_1X1_1    -1  ),
    .LATENCY_FIXED_2_FLOAT      (LATENCY_FIXED_2_FLOAT     ),
    .LATENCY_FLOAT_32           (LATENCY_FLOAT_32          ),
    .BRAM_LATENCY               (BRAM_LATENCY              ),
    .I_IS_MAX                   (I_IS_MAX                  ),
    .I_IS_NOT_MAX               (I_IS_NOT_MAX              ),
    .I_IS_LRELU                 (I_IS_LRELU                ),
    .I_IS_TOP_BLOCK             (I_IS_TOP_BLOCK            ),
    .I_IS_BOTTOM_BLOCK          (I_IS_BOTTOM_BLOCK         ),
    .I_IS_LEFT_COL              (I_IS_LEFT_COL             ),
    .I_IS_RIGHT_COL             (I_IS_RIGHT_COL            ),
    .I_IS_1X1                   (I_IS_1X1                  ),
    .TUSER_WIDTH_LRELU_IN       (TUSER_WIDTH_LRELU_IN      ),
    .TUSER_WIDTH_LRELU_FMA_1_IN (TUSER_WIDTH_LRELU_FMA_1_IN),
    .TUSER_WIDTH_MAXPOOL_IN     (TUSER_WIDTH_MAXPOOL_IN    )
  ) LRELU_ENGINE (
    .aclk          (aclk                   ),
    .aresetn       (aresetn                ),
    .s_axis_tvalid (lrelu_s_axis_tvalid    ),
    .s_axis_tready (lrelu_s_axis_tready    ),
    .s_axis_tdata  (lrelu_s_axis_tdata_mcgu), // mcgu
    .s_axis_tlast  (lrelu_s_axis_tlast     ),
    .s_axis_tuser  (lrelu_s_axis_tuser     ),
    .m_axis_tvalid (maxpool_s_axis_tvalid  ),
    .m_axis_tready (maxpool_s_axis_tready  ),
    .m_axis_tdata  (maxpool_s_axis_tdata   ), // cgu
    .m_axis_tuser  (maxpool_s_axis_tuser   )
  );

  axis_maxpool_engine #(
    .UNITS            (UNITS        ),
    .GROUPS           (GROUPS       ),
    .MEMBERS          (MEMBERS      ),
    .WORD_WIDTH       (WORD_WIDTH   ),
    .KERNEL_H_MAX     (KERNEL_H_MAX ),
    .I_IS_NOT_MAX     (I_IS_NOT_MAX ),
    .I_IS_MAX         (I_IS_MAX     )
  ) MAXPOOL_ENGINE (
    .aclk         (aclk                  ),
    .aresetn      (aresetn               ),
    .s_axis_tvalid(maxpool_s_axis_tvalid ),
    .s_axis_tready(maxpool_s_axis_tready ),
    .s_axis_tdata (maxpool_s_axis_tdata  ), // cgu
    .s_axis_tuser (maxpool_s_axis_tuser  ),
    .m_axis_tvalid(m_axis_tvalid         ),
    .m_axis_tready(m_axis_tready         ),
    .m_axis_tdata (m_axis_tdata          ), //cgu
    .m_axis_tkeep (m_axis_tkeep          ),
    .m_axis_tlast (m_axis_tlast          )
  );

endmodule