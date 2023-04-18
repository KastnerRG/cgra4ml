
`timescale 1ns/1ps
`include "../params/params.sv"

module axis_conv_engine (
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

  localparam COLS                = `COLS                ;
  localparam ROWS                = `ROWS                ;
  localparam WORD_WIDTH_IN       = `WORD_WIDTH          ; 
  localparam WORD_WIDTH_OUT      = `WORD_WIDTH_ACC      ; 
  localparam TUSER_WIDTH         = `TUSER_WIDTH         ; 

  input  wire aclk;
  input  wire aresetn;
  input  wire s_axis_tvalid;
  output wire s_axis_tready;
  input  wire s_axis_tlast;
  input  wire m_axis_tready;
  input  tuser_st s_axis_tuser;
  input  wire [ROWS -1:0][WORD_WIDTH_IN-1:0] s_axis_tdata_pixels;
  input  wire [COLS   -1:0][WORD_WIDTH_IN-1:0] s_axis_tdata_weights;

  wire slice_s_ready;
  wire slice_s_valid;
  wire slice_s_last ;
  tuser_st slice_s_user;
  logic [COLS   -1:0][ROWS -1:0][WORD_WIDTH_OUT-1:0]   slice_s_data;

  output wire m_axis_tvalid;
  output wire m_axis_tlast ;
  output wire [COLS   -1:0][ROWS -1:0][WORD_WIDTH_OUT-1:0] m_axis_tdata;
  output tuser_st m_axis_tuser;

  /*
    To fully adhere to AXIS, slice_reg needs to have two reg stages, which costs lot of area 
    With one reg stage, it turns down s_ready on clock after s_valid, which would freeze conv engine unnessarily.
    
    Conv engine will NEVER release valid data on consecutive clocks. So, the following is done to keep area low 
  */

  logic valid_prev, clken_engine;
  assign clken_engine = valid_prev | slice_s_ready;


  conv_engine ENGINE (
    .clk           (aclk),
    .resetn        (aresetn),
    .clken         (clken_engine),
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

  register #(
    .WORD_WIDTH (1),
    .RESET_VALUE(1),
    .LOCAL      (0)
  ) VALID_PREV (
    .clock       (aclk),
    .clock_enable(1'b1),
    .resetn      (aresetn),
    .data_in     (slice_s_valid),
    .data_out    (valid_prev)
  );

  skid_buffer #(
    .WIDTH   (COLS   *ROWS *WORD_WIDTH_OUT + TUSER_WIDTH + 1)
  ) AXIS_REG (
    .aclk    (aclk        ),
    .aresetn (aresetn     ),
    .s_ready (slice_s_ready),
    .s_valid (slice_s_valid),
    .s_data  ({slice_s_data, slice_s_user, slice_s_last}),
    .m_data  ({m_axis_tdata, m_axis_tuser, m_axis_tlast}),
    .m_valid (m_axis_tvalid),
    .m_ready (m_axis_tready)
  );

endmodule