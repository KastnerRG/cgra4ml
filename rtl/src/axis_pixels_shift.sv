`timescale 1ns/1ps
`include "../include/params.v"

module axis_pixels_shift #(ZERO=0) (
    aclk   ,
    aresetn,

    s_shift,
    s_ones ,
    s_ready,  
    s_valid,  
    s_data ,   
    s_user ,   
    
    m_ready,      
    m_valid,     
    m_data ,
    m_user
  );

  localparam COPIES          = `COPIES        ;
  localparam UNITS           = `UNITS         ;
  localparam WORD_WIDTH      = `WORD_WIDTH    ; 
  localparam KH_MAX          = `KH_MAX        ;
  localparam IM_SHIFT_REGS   = `IM_SHIFT_REGS ;
  localparam BITS_SH         = `BITS_SH       ;
  localparam BITS_KH         = `BITS_KH       ;
  localparam BITS_IM_SHIFT   = `BITS_IM_SHIFT ;
  
  localparam I_IS_NOT_MAX             = `I_IS_NOT_MAX; 
  localparam I_IS_MAX                 = `I_IS_MAX; 
  localparam I_IS_LRELU               = `I_IS_LRELU; 
  localparam I_KH2                    = `I_KH2 ; 
  localparam I_SH_1                   = `I_SH_1; 
  localparam TUSER_WIDTH_PIXELS       = `TUSER_WIDTH_PIXELS;

  input logic aclk;
  input logic aresetn;

  output logic s_ready;
  input  logic s_valid;
  input  logic s_ones;
  input  logic [IM_SHIFT_REGS-1:0][WORD_WIDTH-1:0] s_data;
  input  logic [TUSER_WIDTH_PIXELS           -1:0] s_user;
  input  logic [BITS_IM_SHIFT-1:0] s_shift;

  input  logic m_ready;
  output logic m_valid;
  output logic [COPIES-1:0][UNITS-1:0][WORD_WIDTH-1:0] m_data;
  output logic [TUSER_WIDTH_PIXELS               -1:0] m_user;

  logic clken ;

  // Counter

  logic count_en, count_last;
  logic [BITS_KH-1:0] count_next, count;

  assign count_en   = clken & (count_last ? s_valid : 1);
  assign count_last = count == 0;
  assign count_next = count_last ? s_shift : count - 1'b1;

  register #(
    .WORD_WIDTH     (BITS_KH),
    .RESET_VALUE    (0)
  ) COUNT (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (count_en),
    .data_in        (count_next),
    .data_out       (count)
  );
  assign s_ready = clken & count_last;

  // Data: shift Registers

  logic [IM_SHIFT_REGS-1:0][WORD_WIDTH-1:0] reg_data_in ;
  logic [IM_SHIFT_REGS-1:0][WORD_WIDTH-1:0] reg_data;

  assign reg_data_in = count_last ? s_data : reg_data >> WORD_WIDTH;

  register #(
    .WORD_WIDTH     (IM_SHIFT_REGS*WORD_WIDTH),
    .RESET_VALUE    (0)
  ) REG (
    .clock          (aclk   ),
    .resetn         (aresetn),
    .clock_enable   (count_en   ),
    .data_in        (reg_data_in),
    .data_out       (reg_data   )
  );

  // valid, user
  
  logic reg_valid;

  register #(
    .WORD_WIDTH     (1),
    .RESET_VALUE    (0)
  ) REG_VALID (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (s_ready),
    .data_in        (s_valid),
    .data_out       (reg_valid)
  );

  logic [TUSER_WIDTH_PIXELS -1:0] reg_user;
  logic reg_ones;
  register #(
    .WORD_WIDTH     (TUSER_WIDTH_PIXELS+1),
    .RESET_VALUE    (0)
  ) REG_USER (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (s_valid & s_ready),
    .data_in        ({s_user, s_ones}),
    .data_out       ({reg_user, reg_ones})
  );

  // Broadcast same values if not is_max

  logic [COPIES-1:0][UNITS-1:0][WORD_WIDTH-1:0] slice_s_data;
  assign slice_s_data [0] = reg_data[UNITS-1:0];
  generate
    for (genvar c=1; c<COPIES; c++)
      assign slice_s_data [c] = (reg_user[I_IS_MAX] & ~reg_ones) ? reg_data [(c+1)*UNITS-1 : c*UNITS] : reg_data [UNITS-1:0];
  endgenerate

  axis_register #
  (
    .DATA_WIDTH   (COPIES*UNITS*WORD_WIDTH),
    .KEEP_ENABLE  (0),
    .LAST_ENABLE  (0),
    .ID_ENABLE    (0),
    .DEST_ENABLE  (0),
    .USER_ENABLE  (1),
    .USER_WIDTH   (TUSER_WIDTH_PIXELS),
    .REG_TYPE     (2)
  ) SLICE (
    .clk          (aclk        ),
    .rst          (~aresetn    ),
    .s_axis_tdata (slice_s_data),
    .s_axis_tvalid(reg_valid   ),
    .s_axis_tready(clken       ),
    .s_axis_tuser (reg_user),
    .s_axis_tlast ('0),
    .s_axis_tkeep ('0),
    .s_axis_tid   ('0),
    .s_axis_tdest ('0),
    .m_axis_tdata (m_data ),
    .m_axis_tvalid(m_valid),
    .m_axis_tready(m_ready),
    .m_axis_tuser (m_user )
  );

endmodule