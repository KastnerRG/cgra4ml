
`timescale 1ns/1ps
`include "../include/params.h"

module axis_conv_engine #(ZERO=0) (
    aclk                 ,
    aresetn              ,
    s_axis_tvalid        ,
    s_axis_tready        ,
    s_axis_tlast         ,
    s_axis_tuser         ,
    s_axis_tdata_pixels  ,
    s_axis_tdata_weights ,
    m_axis_tvalid        ,
    m_axis_tready        ,
    m_axis_tdata         ,
    m_axis_tlast         ,
    m_axis_tuser         
  );

  localparam COPIES              = `COPIES              ;
  localparam GROUPS              = `GROUPS              ;
  localparam MEMBERS             = `MEMBERS             ;
  localparam UNITS               = `UNITS               ;
  localparam WORD_WIDTH_IN       = `WORD_WIDTH          ; 
  localparam WORD_WIDTH_OUT      = `WORD_WIDTH_ACC      ; 
  localparam TUSER_WIDTH_CONV_IN = `TUSER_WIDTH_CONV_IN ;
  localparam TUSER_WIDTH_CONV_OUT= `TUSER_CONV_DW_IN    ;

  input  wire aclk;
  input  wire aresetn;
  input  wire s_axis_tvalid;
  output wire s_axis_tready;
  input  wire s_axis_tlast;
  input  wire m_axis_tready;
  input  wire [TUSER_WIDTH_CONV_IN-1:0] s_axis_tuser;
  input  wire [COPIES-1:0][UNITS-1:0][WORD_WIDTH_IN-1:0] s_axis_tdata_pixels;
  input  wire [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0][WORD_WIDTH_IN-1:0] s_axis_tdata_weights;

  wire slice_s_ready;
  wire slice_s_valid;
  wire slice_s_last ;
  logic [TUSER_WIDTH_CONV_OUT-1:0] slice_s_user;
  logic [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0][WORD_WIDTH_OUT-1:0]   slice_s_data;

  output wire m_axis_tvalid;
  output wire m_axis_tlast ;
  output wire [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0][WORD_WIDTH_OUT-1:0] m_axis_tdata;
  output wire [TUSER_WIDTH_CONV_OUT-1:0] m_axis_tuser;

  conv_engine #(.ZERO(ZERO)) ENGINE (
    .clk           (aclk),
    .resetn        (aresetn),
    .clken         (slice_s_ready        ),
    .s_data_pixels (s_axis_tdata_pixels  ),
    .s_data_weights(s_axis_tdata_weights ),
    .s_valid       (s_axis_tvalid        ),
    .s_ready       (s_axis_tready        ),
    .s_last        (s_axis_tlast         ),
    .s_user        (s_axis_tuser         ),
    .m_valid       (slice_s_valid        ),
    .m_data        (slice_s_data         ),
    .m_last        (slice_s_last         ),
    .m_user        (slice_s_user         )
  );

  axis_register #
  (
    .DATA_WIDTH   (COPIES*GROUPS*MEMBERS*UNITS*WORD_WIDTH_OUT),
    .KEEP_ENABLE  (0),
    .LAST_ENABLE  (1),
    .ID_ENABLE    (0),
    .DEST_ENABLE  (0),
    .USER_ENABLE  (1),
    .USER_WIDTH   (TUSER_WIDTH_CONV_OUT),
    .REG_TYPE     (2)
  ) SLICE (
    .clk          (aclk        ),
    .rst          (~aresetn    ),
    .s_axis_tdata (slice_s_data ),
    .s_axis_tvalid(slice_s_valid),
    .s_axis_tready(slice_s_ready),
    .s_axis_tuser (slice_s_user ),
    .s_axis_tlast (slice_s_last ),
    .s_axis_tid   ('0),
    .s_axis_tdest ('0),
    .m_axis_tdata (m_axis_tdata ),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tuser (m_axis_tuser ),
    .m_axis_tlast (m_axis_tlast )
  );

endmodule