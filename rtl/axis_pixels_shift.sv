`timescale 1ns/1ps
`include "../params/params.sv"

module axis_pixels_shift (
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

  localparam ROWS            = `ROWS          ;
  localparam WORD_WIDTH      = `WORD_WIDTH    ; 
  localparam TUSER_WIDTH     = `TUSER_WIDTH   ; 
  localparam KH_MAX          = `KH_MAX        ;
  localparam IM_SHIFT_REGS   = `IM_SHIFT_REGS ;
  localparam BITS_SH         = `BITS_SH       ;
  localparam BITS_KH         = `BITS_KH       ;
  localparam BITS_IM_SHIFT   = `BITS_IM_SHIFT ;


  input logic aclk;
  input logic aresetn;

  output logic s_ready;
  input  logic s_valid;
  input  logic s_ones;
  input  logic [IM_SHIFT_REGS-1:0][WORD_WIDTH-1:0] s_data;
  input  tuser_st s_user;
  input  logic [BITS_IM_SHIFT-1:0] s_shift;

  input  logic m_ready;
  output logic m_valid;
  output logic [ROWS -1:0][WORD_WIDTH-1:0] m_data;
  output tuser_st m_user;

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

  logic [TUSER_WIDTH -1:0] reg_user;
  logic reg_ones;
  register #(
    .WORD_WIDTH     (TUSER_WIDTH+1),
    .RESET_VALUE    (0)
  ) REG_USER (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (s_valid & s_ready),
    .data_in        ({s_user, s_ones}),
    .data_out       ({reg_user, reg_ones})
  );

  // Broadcast same values if not is_max

  logic [ROWS -1:0][WORD_WIDTH-1:0] slice_s_data;
  assign slice_s_data = reg_data[ROWS -1:0];

  skid_buffer #(
    .WIDTH   (ROWS *WORD_WIDTH + TUSER_WIDTH)
  ) AXIS_REG (
    .aclk    (aclk        ),
    .aresetn (aresetn     ),
    .s_ready (clken       ),
    .s_valid (reg_valid   ),
    .s_data  ({slice_s_data, reg_user}),
    .m_data  ({m_data, m_user        }),
    .m_valid (m_valid),
    .m_ready (m_ready)
  );

endmodule