`timescale 1ns/1ps
`define VERILOG
`include "../params/params.svh"
`undef  VERILOG

module dnn_engine #(
    parameter   S_PIXELS_KEEP_WIDTH     = `S_PIXELS_WIDTH_LF /8,
                S_WEIGHTS_KEEP_WIDTH    = `S_WEIGHTS_WIDTH_LF/8,
                M_KEEP_WIDTH            = `M_OUTPUT_WIDTH_LF /8,

                ROWS                    = `ROWS               ,
                COLS                    = `COLS               ,
                WORD_WIDTH              = `WORD_WIDTH         , 
                WORD_WIDTH_ACC          = `WORD_WIDTH_ACC     ,
                M_DATA_WIDTH_HF_CONV    = COLS  * ROWS  * WORD_WIDTH_ACC,
                M_DATA_WIDTH_HF_CONV_DW = ROWS  * WORD_WIDTH_ACC,
                DW_IN_KEEP_WIDTH        = M_DATA_WIDTH_HF_CONV_DW/8,

                S_PIXELS_WIDTH_LF       = `S_PIXELS_WIDTH_LF  ,
                S_WEIGHTS_WIDTH_LF      = `S_WEIGHTS_WIDTH_LF ,
                M_OUTPUT_WIDTH_LF       = `M_OUTPUT_WIDTH_LF      
  )(
    input  wire aclk,
    input  wire aresetn,

    output wire s_axis_pixels_tready,
    input  wire s_axis_pixels_tvalid,
    input  wire s_axis_pixels_tlast ,
    input  wire [S_PIXELS_WIDTH_LF  -1:0]   s_axis_pixels_tdata,
    input  wire [S_PIXELS_KEEP_WIDTH-1:0]   s_axis_pixels_tkeep,

    output wire s_axis_weights_tready,
    input  wire s_axis_weights_tvalid,
    input  wire s_axis_weights_tlast ,
    input  wire [S_WEIGHTS_WIDTH_LF -1:0]   s_axis_weights_tdata,
    input  wire [S_WEIGHTS_KEEP_WIDTH-1:0]  s_axis_weights_tkeep,

    input  wire m_axis_tready,
    output wire m_axis_tvalid,
    output wire m_axis_tlast ,
    output wire [M_OUTPUT_WIDTH_LF-1:0] m_axis_tdata,
    output wire [M_KEEP_WIDTH     -1:0] m_axis_tkeep
  ); 

  localparam  TUSER_WIDTH = `TUSER_WIDTH;

  /* WIRES */

  wire pixels_m_valid, pixels_m_ready;
  wire weights_m_valid, weights_m_ready, weights_m_last;
  wire conv_s_valid, conv_s_ready;
  wire [WORD_WIDTH*ROWS    -1:0] pixels_m_data;
  wire [WORD_WIDTH*COLS    -1:0] weights_m_data;
  wire [TUSER_WIDTH        -1:0] weights_m_user;

  wire conv_m_axis_tready, conv_m_axis_tvalid, conv_m_axis_tlast ;
  wire [TUSER_WIDTH          -1:0] conv_m_axis_tuser;
  wire [M_DATA_WIDTH_HF_CONV -1:0] conv_m_axis_tdata; // cgmu

  wire dw_s_axis_tready, dw_s_axis_tvalid, dw_s_axis_tlast ;
  wire [TUSER_WIDTH    -1:0] dw_s_axis_tuser ;
  wire [M_DATA_WIDTH_HF_CONV_DW -1:0] dw_s_axis_tdata ;

  axis_pixels PIXELS (
    .aclk   (aclk   ),
    .aresetn(aresetn),
    .s_ready(s_axis_pixels_tready),
    .s_valid(s_axis_pixels_tvalid),
    .s_last (s_axis_pixels_tlast ),
    .s_data (s_axis_pixels_tdata ),
    .s_keep (s_axis_pixels_tkeep ),
    .m_valid(pixels_m_valid      ),
    .m_ready(pixels_m_ready      ),
    .m_data (pixels_m_data       )
  );

  axis_weight_rotator WEIGHTS_ROTATOR (
    .aclk          (aclk                 ),
    .aresetn       (aresetn              ),
    .s_axis_tready (s_axis_weights_tready), 
    .s_axis_tvalid (s_axis_weights_tvalid), 
    .s_axis_tlast  (s_axis_weights_tlast ), 
    .s_axis_tdata  (s_axis_weights_tdata ),
    .s_axis_tkeep  (s_axis_weights_tkeep ),
    .m_axis_tready (weights_m_ready      ),      
    .m_axis_tvalid (weights_m_valid      ),   
    .m_axis_tdata  (weights_m_data       ),
    .m_axis_tlast  (weights_m_last       ),
    .m_axis_tuser  (weights_m_user       ) 
  );

  axis_sync SYNC (
    .weights_m_valid (weights_m_valid), 
    .pixels_m_valid  (pixels_m_valid ), 
    .m_axis_tready   (conv_s_ready   ),
    .weights_m_user  (weights_m_user ),
    .m_axis_tvalid   (conv_s_valid   ), 
    .weights_m_ready (weights_m_ready), 
    .pixels_m_ready  (pixels_m_ready ) 
  );

  proc_engine PROC_ENGINE (
    .clk            (aclk    ),
    .resetn         (aresetn ),
    .s_valid        (conv_s_valid               ),
    .s_ready        (conv_s_ready               ),
    .s_last         (weights_m_last             ),
    .s_user         (weights_m_user             ),
    .s_data_pixels  (pixels_m_data              ),
    .s_data_weights (weights_m_data             ),
    .m_valid        (conv_m_axis_tvalid         ),
    .m_ready        (conv_m_axis_tready         ),
    .m_data         (conv_m_axis_tdata          ),
    .m_last         (conv_m_axis_tlast          ),
    .m_user         (conv_m_axis_tuser          )
    );
  axis_out_shift OUT (
    .aclk    (aclk   ),
    .aresetn (aresetn),
    .s_ready (conv_m_axis_tready    ),
    .s_valid (conv_m_axis_tvalid    ),
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
    .S_KEEP_WIDTH  (DW_IN_KEEP_WIDTH),
    .M_KEEP_WIDTH  (M_KEEP_WIDTH),
    .ID_ENABLE     (0),
    .DEST_ENABLE   (0),
    .USER_ENABLE   (0)
  ) DW_OUT (
    .clk           (aclk    ),
    .rst           (~aresetn),
    .s_axis_tready (dw_s_axis_tready),
    .s_axis_tvalid (dw_s_axis_tvalid),
    .s_axis_tdata  (dw_s_axis_tdata ),
    .s_axis_tkeep  ({DW_IN_KEEP_WIDTH{1'b1}}),
    .s_axis_tlast  (dw_s_axis_tlast ),
    .m_axis_tready (m_axis_tready),
    .m_axis_tvalid (m_axis_tvalid),
    .m_axis_tdata  (m_axis_tdata ),
    .m_axis_tkeep  (m_axis_tkeep ),
    .m_axis_tlast  (m_axis_tlast )
  );
endmodule