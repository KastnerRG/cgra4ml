`timescale 1ns/1ps
`include "../params/params.svh"

module axis_input_pipe 
  #(
    parameter     
    ROWS                      = `ROWS                     ,
    COLS                      = `COLS                     ,
    WORD_WIDTH                = `WORD_WIDTH               , 
    S_WEIGHTS_WIDTH_LF        = `S_WEIGHTS_WIDTH_LF       
  )(
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
    m_axis_tready         ,      
    m_axis_tvalid         ,     
    m_axis_tlast          ,     
    m_axis_tuser          ,
    m_axis_pixels_tdata   ,
    m_axis_weights_tdata  
  ); 


  localparam S_PIXELS_WIDTH_LF = `S_PIXELS_WIDTH_LF;

  input wire aclk;
  input wire aresetn;

  output wire s_axis_pixels_tready;
  input  wire s_axis_pixels_tvalid;
  input  wire s_axis_pixels_tlast ;
  input  wire [S_PIXELS_WIDTH_LF   -1:0] s_axis_pixels_tdata;
  input  wire [S_PIXELS_WIDTH_LF/WORD_WIDTH -1:0] s_axis_pixels_tkeep;

  output wire s_axis_weights_tready;
  input  wire s_axis_weights_tvalid;
  input  wire s_axis_weights_tlast ;
  input  wire [S_WEIGHTS_WIDTH_LF -1:0] s_axis_weights_tdata;
  input  wire [S_WEIGHTS_WIDTH_LF /WORD_WIDTH -1:0] s_axis_weights_tkeep;

  wire pixels_m_ready;
  wire pixels_m_valid;
  
  wire weights_m_ready;
  wire weights_m_valid;
  wire weights_m_last;
  tuser_st weights_m_user;
  output wire [WORD_WIDTH*ROWS          -1:0] m_axis_pixels_tdata;

  input  wire m_axis_tready;
  output wire m_axis_tvalid;
  output wire m_axis_tlast ;
  output wire [WORD_WIDTH*COLS   -1:0] m_axis_weights_tdata;
  output tuser_st m_axis_tuser;

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
    .m_data (m_axis_pixels_tdata )
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
    .m_axis_tdata  (m_axis_weights_tdata ),
    .m_axis_tlast  (weights_m_last       ),
    .m_axis_tuser  (weights_m_user       ) 
  );

  /*
    Synchronizing streams
  */

  assign m_axis_tvalid   = weights_m_valid && (pixels_m_valid || m_axis_tuser.is_config);
  assign weights_m_ready = m_axis_tready   && (pixels_m_valid || m_axis_tuser.is_config);
  assign pixels_m_ready  = m_axis_tready   && weights_m_valid && !m_axis_tuser.is_config;

  /* 
    TUSER 
  */
  
  assign m_axis_tlast    = weights_m_last;
  assign m_axis_tuser    = weights_m_user;

endmodule