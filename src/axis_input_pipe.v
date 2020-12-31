module axis_input_pipe (
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
    m_axis_tready         ,      
    m_axis_tvalid         ,     
    m_axis_pixels_1_tdata ,
    m_axis_pixels_2_tdata 
  ); 

  parameter UNITS              = 2;
  parameter WORD_WIDTH         = 8; 
  parameter KERNEL_H_MAX       = 3;   // odd number
  parameter BEATS_CONFIG_3X3_1 = 21-1;
  parameter BEATS_CONFIG_1X1_1 = 13-1;
  parameter BITS_OTHER         = 8;
  parameter I_IM_IN_IS_MAXPOOL = 0;
  parameter I_IM_IN_KERNEL_H_1 = I_IM_IN_IS_MAXPOOL + BITS_OTHER + 0;
  
  localparam UNITS_EDGES       = UNITS + KERNEL_H_MAX-1;
  localparam IM_IN_S_DATA_WORDS= 2**$clog2(UNITS_EDGES);
  localparam BITS_CONFIG_COUNT = $clog2(BEATS_CONFIG_3X3_1);
  localparam BITS_KERNEL_H_MAX = $clog2(KERNEL_H_MAX);

  parameter  TUSER_WIDTH_IM_IN  = BITS_KERNEL_H_MAX;
  localparam TKEEP_WIDTH_IM_IN = (WORD_WIDTH*IM_IN_S_DATA_WORDS)/8;

  input wire aclk;
  input wire aresetn;

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

  wire im_mux_m_ready;
  wire im_mux_m_valid;
  wire [TUSER_WIDTH_IM_IN-1:0] im_mux_m_user;
  wire [WORD_WIDTH*UNITS_EDGES-1:0] im_mux_m_data_1;
  wire [WORD_WIDTH*UNITS_EDGES-1:0] im_mux_m_data_2;

  input  wire m_axis_tready;
  output wire m_axis_tvalid;
  output wire [WORD_WIDTH*UNITS -1:0] m_axis_pixels_1_tdata;
  output wire [WORD_WIDTH*UNITS -1:0] m_axis_pixels_2_tdata;

  axis_image_pipe #(
    .UNITS              (UNITS             ),
    .WORD_WIDTH         (WORD_WIDTH        ),
    .KERNEL_H_MAX       (KERNEL_H_MAX      ),
    .BEATS_CONFIG_3X3_1 (BEATS_CONFIG_3X3_1),
    .BEATS_CONFIG_1X1_1 (BEATS_CONFIG_1X1_1),
    .BITS_OTHER         (BITS_OTHER        ),
    .I_IM_IN_IS_MAXPOOL (I_IM_IN_IS_MAXPOOL),
    .I_IM_IN_KERNEL_H_1 (I_IM_IN_KERNEL_H_1),
    .TUSER_WIDTH_IM_IN  (TUSER_WIDTH_IM_IN )
  ) im_mux (
    .aclk            (aclk   ),
    .aresetn         (aresetn),
    .s_axis_1_tready (s_axis_pixels_1_tready), 
    .s_axis_1_tvalid (s_axis_pixels_1_tvalid), 
    .s_axis_1_tlast  (s_axis_pixels_1_tlast ), 
    .s_axis_1_tdata  (s_axis_pixels_1_tdata ), 
    .s_axis_1_tkeep  (s_axis_pixels_1_tkeep ), 
    .s_axis_2_tready (s_axis_pixels_2_tready),  
    .s_axis_2_tvalid (s_axis_pixels_2_tvalid),  
    .s_axis_2_tlast  (s_axis_pixels_2_tlast ),   
    .s_axis_2_tdata  (s_axis_pixels_2_tdata ),   
    .s_axis_2_tkeep  (s_axis_pixels_2_tkeep ),      
    .m_axis_tready   (im_mux_m_ready ),      
    .m_axis_tvalid   (im_mux_m_valid ),     
    .m_axis_1_tdata  (im_mux_m_data_1),
    .m_axis_2_tdata  (im_mux_m_data_2),
    .m_axis_tuser    (im_mux_m_user  )
  );

  axis_image_shift_buffer #(
    .UNITS         (UNITS       ),
    .WORD_WIDTH    (WORD_WIDTH  ),
    .KERNEL_H_MAX  (KERNEL_H_MAX)
  ) image_shift_1 (
    .aclk          (aclk           ),
    .aresetn       (aresetn        ),
    .s_axis_tready (im_mux_m_ready ),  
    .s_axis_tvalid (im_mux_m_valid ),  
    .s_axis_tdata  (im_mux_m_data_1),   
    .s_axis_tuser  (im_mux_m_user  ),   
    .m_axis_tready (m_axis_tready  ),      
    .m_axis_tvalid (m_axis_tvalid  ),     
    .m_axis_tdata  (m_axis_pixels_1_tdata)
  );

  axis_image_shift_buffer #(
    .UNITS         (UNITS       ),
    .WORD_WIDTH    (WORD_WIDTH  ),
    .KERNEL_H_MAX  (KERNEL_H_MAX)
  ) image_shift_2 (
    .aclk          (aclk           ),
    .aresetn       (aresetn        ),
    .s_axis_tvalid (im_mux_m_valid ),  
    .s_axis_tdata  (im_mux_m_data_2),   
    .s_axis_tuser  (im_mux_m_user  ),   
    .m_axis_tready (m_axis_tready  ),      
    .m_axis_tdata  (m_axis_pixels_2_tdata)
  );

endmodule