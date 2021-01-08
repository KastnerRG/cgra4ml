
module axis_conv_engine (
    aclk                 ,
    aresetn              ,
    s_axis_tvalid        ,
    s_axis_tready        ,
    s_axis_tlast         ,
    s_axis_tuser         ,
    s_axis_tdata_pixels_1,
    s_axis_tdata_pixels_2,
    s_axis_tdata_weights ,
    m_axis_tvalid        ,
    m_axis_tready        ,
    m_axis_tdata         ,
    m_axis_tlast         ,
    m_axis_tuser         
  );

  parameter  CORES              = 32 ;
  parameter  UNITS              = 8  ;
  parameter  WORD_WIDTH_IN      =  8 ; 
  parameter  WORD_WIDTH_OUT     = 25 ; 
  parameter  ACCUMULATOR_DELAY  =  2 ;
  parameter  MULTIPLIER_DELAY   =  3 ;
  parameter  KERNEL_W_MAX       =  3 ; 
  parameter  KERNEL_H_MAX       =  3 ;   // odd number
  parameter  IM_CIN_MAX         = 1024;
  parameter  IM_COLS_MAX        = 1024;
  localparam BITS_IM_CIN        = $clog2(IM_CIN_MAX);
  localparam BITS_IM_COLS       = $clog2(IM_COLS_MAX);
  localparam BITS_KERNEL_W      = $clog2(KERNEL_W_MAX   + 1);
  localparam BITS_KERNEL_H      = $clog2(KERNEL_H_MAX   + 1);

  parameter I_IS_NOT_MAX        = 0;
  parameter I_IS_MAX            = I_IS_NOT_MAX      + 1;
  parameter I_IS_LRELU          = I_IS_MAX          + 1;
  parameter I_IS_TOP_BLOCK      = I_IS_LRELU        + 1;
  parameter I_IS_BOTTOM_BLOCK   = I_IS_TOP_BLOCK    + 1;
  parameter I_IS_1X1            = I_IS_BOTTOM_BLOCK + 1;
  parameter I_IS_COLS_1_K2      = I_IS_1X1          + 1;
  parameter I_IS_CONFIG         = I_IS_COLS_1_K2    + 1;
  parameter I_IS_ACC_LAST       = I_IS_CONFIG       + 1;
  parameter I_KERNEL_W_1        = I_IS_ACC_LAST     + 1; 

  parameter I_IS_LEFT_COL       = I_IS_1X1          + 1;
  parameter I_IS_RIGHT_COL      = I_IS_LEFT_COL     + 1;

  parameter TUSER_WIDTH_CONV_IN  = BITS_KERNEL_W + I_KERNEL_W_1;
  parameter TUSER_WIDTH_CONV_OUT = 1 + I_IS_RIGHT_COL;

  input  wire aclk;
  input  wire aresetn;
  input  wire s_axis_tvalid;
  output wire s_axis_tready;
  input  wire s_axis_tlast;
  input  wire m_axis_tready;
  input  wire [TUSER_WIDTH_CONV_IN             -1:0] s_axis_tuser;
  input  wire [WORD_WIDTH_IN*UNITS             -1:0] s_axis_tdata_pixels_1;
  input  wire [WORD_WIDTH_IN*UNITS             -1:0] s_axis_tdata_pixels_2;
  input  wire [WORD_WIDTH_IN*CORES*KERNEL_W_MAX-1:0] s_axis_tdata_weights;    

  wire slice_s_axis_tready;
  wire slice_s_axis_tvalid;
  wire slice_s_axis_tlast ;
  wire [WORD_WIDTH_OUT*CORES*UNITS/2-1:0] slice_s_axis_tdata_1;
  wire [WORD_WIDTH_OUT*CORES*UNITS/2-1:0] slice_s_axis_tdata_2;
  wire [WORD_WIDTH_OUT*CORES*UNITS/2-1:0] slice_m_axis_tdata_1;
  wire [WORD_WIDTH_OUT*CORES*UNITS/2-1:0] slice_m_axis_tdata_2;
  wire [TUSER_WIDTH_CONV_OUT        -1:0] slice_s_axis_tuser;

  output wire m_axis_tvalid;
  output wire m_axis_tlast ;
  output wire [WORD_WIDTH_OUT*CORES*UNITS-1:0] m_axis_tdata;
  output wire [TUSER_WIDTH_CONV_OUT      -1:0] m_axis_tuser;


  conv_engine #(
    .CORES                (CORES               ),
    .UNITS                (UNITS               ),
    .WORD_WIDTH_IN        (WORD_WIDTH_IN       ), 
    .WORD_WIDTH_OUT       (WORD_WIDTH_OUT      ), 
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
    .TUSER_WIDTH_CONV_OUT (TUSER_WIDTH_CONV_OUT)
  ) ENGINE (
    .clk          (aclk),
    .clken        (slice_s_axis_tready),
    .resetn       (aresetn            ),
    .s_valid      (s_axis_tvalid      ),
    .s_ready      (s_axis_tready      ),
    .s_last       (s_axis_tlast       ),
    .s_user       (s_axis_tuser       ),
    .m_valid      (slice_s_axis_tvalid),
    .m_data_flat  ({slice_s_axis_tdata_2, slice_s_axis_tdata_1}),
    .m_last       (slice_s_axis_tlast ),
    .m_user       (slice_s_axis_tuser ),
    .s_data_pixels_1_flat (s_axis_tdata_pixels_1),
    .s_data_pixels_2_flat (s_axis_tdata_pixels_2),
    .s_data_weights_flat  (s_axis_tdata_weights )
  );

  slice_conv_active slice_1 (
    .aclk           (aclk                 ),
    .aresetn        (aresetn              ),
    .s_axis_tvalid  (slice_s_axis_tvalid  ),
    .s_axis_tready  (slice_s_axis_tready  ),
    .s_axis_tdata   (slice_s_axis_tdata_1 ),
    .s_axis_tuser   (slice_s_axis_tuser   ),  
    .s_axis_tlast   (slice_s_axis_tlast   ),  
    .m_axis_tvalid  (m_axis_tvalid        ),
    .m_axis_tready  (m_axis_tready        ),
    .m_axis_tdata   (slice_m_axis_tdata_1 ),
    .m_axis_tuser   (m_axis_tuser         ),
    .m_axis_tlast   (m_axis_tlast         )
  );
  slice_conv slice_2 (
    .aclk           (aclk                 ),
    .aresetn        (aresetn              ),
    .s_axis_tvalid  (slice_s_axis_tvalid  ),
    .s_axis_tdata   (slice_s_axis_tdata_2 ),
    .m_axis_tready  (m_axis_tready        ),
    .m_axis_tdata   (slice_m_axis_tdata_2 )
  );

  assign m_axis_tdata = {slice_m_axis_tdata_2, slice_m_axis_tdata_1};

endmodule