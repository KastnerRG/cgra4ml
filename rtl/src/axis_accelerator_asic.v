`timescale 1ns/1ps
`include "../include/params.v"

module axis_accelerator_asic #(ZERO=0) (
    aclk                  ,
    aresetn               ,

    s_axis_pixels_tready  , 
    s_axis_pixels_tvalid  , 
    s_axis_pixels_tlast   , 
    s_axis_pixels_tdata   , 
    s_axis_pixels_tkeep   ,   
    s_axis_weights_tready ,
    s_axis_weights_tvalid ,
    s_axis_weights_tlast  ,
    s_axis_weights_tdata  ,
    s_axis_weights_tkeep  ,

    m_axis_tready ,
    m_axis_tvalid ,
    m_axis_tlast  ,
    m_axis_tdata  ,
    m_axis_tkeep  
  ); 

  localparam M_OUTPUT_WIDTH_LF = `M_OUTPUT_WIDTH_LF;
  localparam S_PIXELS_WIDTH_LF = `S_PIXELS_WIDTH_LF   ;
  localparam BITS_KH2          = `BITS_KH2            ;

  localparam S_WEIGHTS_WIDTH_LF= `S_WEIGHTS_WIDTH_LF  ;
  localparam M_DATA_WIDTH_HF_CONV    = `M_DATA_WIDTH_HF_CONV   ;
  localparam M_DATA_WIDTH_HF_CONV_DW = `M_DATA_WIDTH_HF_CONV_DW;

  localparam UNITS                      = `UNITS                ;
  localparam GROUPS                     = `GROUPS               ;
  localparam COPIES                     = `COPIES               ;
  localparam MEMBERS                    = `MEMBERS              ;
  localparam WORD_WIDTH                 = `WORD_WIDTH           ; 
  localparam WORD_WIDTH_ACC             = `WORD_WIDTH_ACC       ;

  // LATENCIES & float widths 
  localparam TUSER_WIDTH_CONV_IN        = `TUSER_WIDTH_CONV_IN       ;
  localparam TUSER_CONV_DW_IN           = `TUSER_CONV_DW_IN          ;
  localparam TUSER_WIDTH_MAXPOOL_IN     = `TUSER_WIDTH_MAXPOOL_IN    ;
  localparam TUSER_WIDTH_LRELU_FMA_1_IN = `TUSER_WIDTH_LRELU_FMA_1_IN;
  localparam TUSER_WIDTH_LRELU_IN       = `TUSER_WIDTH_LRELU_IN      ;

  localparam I_IS_CONFIG = `I_IS_CONFIG;

  /* WIRES */

  input  wire aclk;
  input  wire aresetn;

  output wire s_axis_pixels_tready;
  input  wire s_axis_pixels_tvalid;
  input  wire s_axis_pixels_tlast ;
  input  wire [S_PIXELS_WIDTH_LF  -1:0] s_axis_pixels_tdata;
  input  wire [S_PIXELS_WIDTH_LF/8-1:0] s_axis_pixels_tkeep;

  output wire s_axis_weights_tready;
  input  wire s_axis_weights_tvalid;
  input  wire s_axis_weights_tlast ;
  input  wire [S_WEIGHTS_WIDTH_LF    -1:0] s_axis_weights_tdata;
  input  wire [S_WEIGHTS_WIDTH_LF /8 -1:0] s_axis_weights_tkeep;

  wire input_m_axis_tready;
  wire input_m_axis_tvalid;
  wire input_m_axis_tlast ;
  wire [COPIES*WORD_WIDTH*UNITS          -1:0] input_m_axis_pixels_tdata;
  wire [WORD_WIDTH*COPIES*GROUPS*MEMBERS -1:0] input_m_axis_weights_tdata;
  wire [TUSER_WIDTH_CONV_IN              -1:0] input_m_axis_tuser        ;

  wire conv_m_axis_tready;
  wire conv_m_axis_tvalid;
  wire conv_m_axis_tlast ;
  wire [TUSER_CONV_DW_IN             -1:0] conv_m_axis_tuser;
  wire [M_DATA_WIDTH_HF_CONV         -1:0] conv_m_axis_tdata; // cgmu

  wire dw_s_axis_tready;
  wire dw_s_axis_tvalid;
  wire dw_s_axis_tlast ;
  wire [TUSER_WIDTH_LRELU_IN    -1:0] dw_s_axis_tuser ;
  wire [M_DATA_WIDTH_HF_CONV_DW -1:0] dw_s_axis_tdata ;

  input  wire m_axis_tready;
  output wire m_axis_tvalid;
  output wire m_axis_tlast ;
  output wire [M_OUTPUT_WIDTH_LF       -1:0] m_axis_tdata;
  output wire [M_OUTPUT_WIDTH_LF/8     -1:0] m_axis_tkeep;

  axis_input_pipe #(.ZERO(ZERO)) input_pipe (
    .aclk                      (aclk    ),
    .aresetn                   (aresetn ),
    .s_axis_pixels_tready      (s_axis_pixels_tready       ), 
    .s_axis_pixels_tvalid      (s_axis_pixels_tvalid       ), 
    .s_axis_pixels_tlast       (s_axis_pixels_tlast        ), 
    .s_axis_pixels_tdata       (s_axis_pixels_tdata        ), 
    .s_axis_pixels_tkeep       (s_axis_pixels_tkeep        ), 
    .s_axis_weights_tready     (s_axis_weights_tready      ),
    .s_axis_weights_tvalid     (s_axis_weights_tvalid      ),
    .s_axis_weights_tlast      (s_axis_weights_tlast       ),
    .s_axis_weights_tdata      (s_axis_weights_tdata       ),
    .s_axis_weights_tkeep      (s_axis_weights_tkeep       ),
    .m_axis_tready             (input_m_axis_tready        ),      
    .m_axis_tvalid             (input_m_axis_tvalid        ),     
    .m_axis_tlast              (input_m_axis_tlast         ),     
    .m_axis_pixels_tdata       (input_m_axis_pixels_tdata  ),
    .m_axis_weights_tdata      (input_m_axis_weights_tdata ), // CMG_flat
    .m_axis_tuser              (input_m_axis_tuser         )
  );
  axis_conv_engine #(.ZERO(ZERO)) CONV_ENGINE (
    .aclk                 (aclk    ),
    .aresetn              (aresetn ),
    .s_axis_tvalid        (input_m_axis_tvalid        ),
    .s_axis_tready        (input_m_axis_tready        ),
    .s_axis_tlast         (input_m_axis_tlast         ),
    .s_axis_tuser         (input_m_axis_tuser         ),
    .s_axis_tdata_pixels  (input_m_axis_pixels_tdata  ), // cu
    .s_axis_tdata_weights (input_m_axis_weights_tdata ), // cr = cmg
    .m_axis_tvalid        (conv_m_axis_tvalid         ),
    .m_axis_tready        (conv_m_axis_tready         ),
    .m_axis_tdata         (conv_m_axis_tdata          ), // cmgu
    .m_axis_tlast         (conv_m_axis_tlast          ),
    .m_axis_tuser         (conv_m_axis_tuser          )
    );
  axis_conv_dw_bank #(.ZERO(ZERO)) CONV_DW (
    .aclk    (aclk   ),
    .aresetn (aresetn),
    .s_ready (conv_m_axis_tready    ),
    .s_valid (conv_m_axis_tvalid & ~conv_m_axis_tuser[I_IS_CONFIG]),
    .s_data  (conv_m_axis_tdata     ),
    .s_user  (conv_m_axis_tuser     ),
    .s_last  (conv_m_axis_tlast     ),
    .m_ready (dw_s_axis_tready),
    .m_valid (dw_s_axis_tvalid),
    .m_data  (dw_s_axis_tdata ),
    .m_user  (dw_s_axis_tuser ),
    .m_last  (dw_s_axis_tlast )
  );

  alex_axis_adapter_any #(
    .S_DATA_WIDTH  (M_DATA_WIDTH_HF_CONV_DW),
    .M_DATA_WIDTH  (M_OUTPUT_WIDTH_LF),
    .S_KEEP_ENABLE (1),
    .M_KEEP_ENABLE (1),
    .ID_ENABLE     (0),
    .DEST_ENABLE   (0),
    .USER_ENABLE   (0)
  ) DW_OUT (
    .clk           (aclk    ),
    .rst           (~aresetn),
    .s_axis_tready (dw_s_axis_tready),
    .s_axis_tvalid (dw_s_axis_tvalid),
    .s_axis_tdata  (dw_s_axis_tdata ),
    .s_axis_tkeep  ({(M_DATA_WIDTH_HF_CONV_DW/8){1'b1}}),
    .s_axis_tlast  (dw_s_axis_tlast ),
    .m_axis_tready (m_axis_tready),
    .m_axis_tvalid (m_axis_tvalid),
    .m_axis_tdata  (m_axis_tdata ),
    .m_axis_tkeep  (m_axis_tkeep ),
    .m_axis_tlast  (m_axis_tlast )
  );
endmodule