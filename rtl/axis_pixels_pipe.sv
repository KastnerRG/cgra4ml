`timescale 1ns/1ps
`include "../params/params.v"

module axis_pixels_pipe (
    aclk     ,
    aresetn  ,
    s_ready  , 
    s_valid  , 
    s_last   , 
    s_data   , 
    s_keep   ,    
    m_ready  ,      
    m_valid  ,   
    m_data   ,
    m_user
  );

  localparam UNITS              = `UNITS                   ;
  localparam COPIES             = `COPIES                  ;
  localparam WORD_WIDTH         = `WORD_WIDTH              ; 
  localparam IM_SHIFT_REGS      = `IM_SHIFT_REGS           ;
  localparam TUSER_WIDTH_PIXELS = `TUSER_WIDTH_PIXELS      ;
  localparam BITS_IM_SHIFT      = `BITS_IM_SHIFT           ;
  localparam S_PIXELS_WIDTH_LF  = `S_PIXELS_WIDTH_LF       ;

  input logic aclk;
  input logic aresetn;

  output logic s_ready;
  input  logic s_valid;
  input  logic s_last ;
  input  logic [S_PIXELS_WIDTH_LF/WORD_WIDTH-1:0][WORD_WIDTH-1:0] s_data;
  input  logic [S_PIXELS_WIDTH_LF/WORD_WIDTH-1:0] s_keep;

  logic i_ready;
  logic i_valid;
  logic i_ones;
  logic [IM_SHIFT_REGS-1:0][WORD_WIDTH-1:0] i_data;
  logic [TUSER_WIDTH_PIXELS-1:0] i_user;
  logic [BITS_IM_SHIFT-1:0] i_shift;

  input  logic m_ready;
  output logic m_valid;
  output logic [COPIES-1:0][UNITS-1:0][WORD_WIDTH-1:0] m_data;
  output logic [TUSER_WIDTH_PIXELS-1:0] m_user;

  axis_pixels_dw DW (
    .aclk    (aclk   ),
    .aresetn (aresetn),
    .s_ready (s_ready), 
    .s_valid (s_valid), 
    .s_last  (s_last ), 
    .s_data  (s_data ), 
    .s_keep  (s_keep ),    
    .m_shift (i_shift),
    .m_ones  (i_ones ),
    .m_ready (i_ready),      
    .m_valid (i_valid),   
    .m_data  (i_data ),
    .m_user  (i_user )
  );

  axis_pixels_shift SHIFT (
    .aclk    (aclk   ),
    .aresetn (aresetn),
    .s_shift (i_shift),
    .s_ones  (i_ones ),
    .s_ready (i_ready),  
    .s_valid (i_valid),  
    .s_data  (i_data ),   
    .s_user  (i_user ),   
    .m_ready (m_ready),      
    .m_valid (m_valid),     
    .m_data  (m_data ),
    .m_user  (m_user ) 
  );
endmodule