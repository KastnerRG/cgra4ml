`timescale 1ns/1ps

module alex_axis_adapter_any #(
  parameter
  S_DATA_WIDTH  = 8,
  S_KEEP_ENABLE = 1,
  S_KEEP_WIDTH  = (S_DATA_WIDTH/8),
  M_DATA_WIDTH  = 8,
  M_KEEP_ENABLE = 1,
  M_KEEP_WIDTH  = (M_DATA_WIDTH/8),
  ID_ENABLE     = 0,
  ID_WIDTH      = 8,
  DEST_ENABLE   = 0,
  DEST_WIDTH    = 8,
  USER_ENABLE   = 1,
  USER_WIDTH    = 1
)(
  input  logic                     clk           ,
  input  logic                     rstn          ,
  input  logic [S_DATA_WIDTH-1:0]  s_axis_tdata  ,
  input  logic [S_KEEP_WIDTH-1:0]  s_axis_tkeep  ,
  input  logic                     s_axis_tvalid ,
  output logic                     s_axis_tready ,
  input  logic                     s_axis_tlast  ,
  input  logic [ID_WIDTH-1:0]      s_axis_tid    ,
  input  logic [DEST_WIDTH-1:0]    s_axis_tdest  ,
  input  logic [USER_WIDTH-1:0]    s_axis_tuser  ,
  output logic [M_DATA_WIDTH-1:0]  m_axis_tdata  ,
  output logic [M_KEEP_WIDTH-1:0]  m_axis_tkeep  ,
  output logic                     m_axis_tvalid ,
  input  logic                     m_axis_tready ,
  output logic                     m_axis_tlast  ,
  output logic [ID_WIDTH-1:0]      m_axis_tid    ,
  output logic [DEST_WIDTH-1:0]    m_axis_tdest  ,
  output logic [USER_WIDTH-1:0]    m_axis_tuser  
);

  function integer lcm (input integer x, input integer y);
    for (int m=x*y; m >= x; m=m-x) // Every multiple of x from x*y down to x
      if (m % y == 0) lcm = m;     // Return the smallest multiple of x that is divisible by y
  endfunction

  localparam I_DATA_WIDTH  = lcm(S_DATA_WIDTH, M_DATA_WIDTH);
  localparam I_KEEP_ENABLE = 1;
  localparam I_KEEP_WIDTH  = lcm(S_KEEP_WIDTH, M_KEEP_WIDTH);

  logic [I_DATA_WIDTH-1:0] i_axis_tdata ;
  logic [I_KEEP_WIDTH-1:0] i_axis_tkeep ;
  logic                    i_axis_tvalid;
  logic                    i_axis_tready;
  logic                    i_axis_tlast ;
  logic [ID_WIDTH-1:0]     i_axis_tid   ;
  logic [DEST_WIDTH-1:0]   i_axis_tdest ;
  logic [USER_WIDTH-1:0]   i_axis_tuser ;

  generate
    if (S_DATA_WIDTH == I_DATA_WIDTH) begin
      assign i_axis_tdata  = s_axis_tdata ;
      assign i_axis_tkeep  = s_axis_tkeep ;
      assign i_axis_tvalid = s_axis_tvalid;
      assign i_axis_tlast  = s_axis_tlast ;
      assign i_axis_tid    = s_axis_tid   ;
      assign i_axis_tdest  = s_axis_tdest ;
      assign i_axis_tuser  = s_axis_tuser ;
      assign s_axis_tready = i_axis_tready;
    end else begin
      axis_adapter #(
        .S_DATA_WIDTH  (S_DATA_WIDTH ),
        .S_KEEP_ENABLE (S_KEEP_ENABLE),
        .S_KEEP_WIDTH  (S_KEEP_WIDTH ),
        .M_DATA_WIDTH  (I_DATA_WIDTH ),
        .M_KEEP_ENABLE (I_KEEP_ENABLE),
        .M_KEEP_WIDTH  (I_KEEP_WIDTH ),
        .ID_ENABLE     (ID_ENABLE    ),
        .ID_WIDTH      (ID_WIDTH     ),
        .DEST_ENABLE   (DEST_ENABLE  ),
        .DEST_WIDTH    (DEST_WIDTH   ),
        .USER_ENABLE   (USER_ENABLE  ),
        .USER_WIDTH    (USER_WIDTH   )
      ) SLAVE_ADAPTER (
        .clk           (clk          ),
        .rstn          (rstn         ),
        .s_axis_tdata  (s_axis_tdata ),
        .s_axis_tkeep  (s_axis_tkeep ),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),
        .s_axis_tlast  (s_axis_tlast ),
        .s_axis_tid    (s_axis_tid   ),
        .s_axis_tdest  (s_axis_tdest ),
        .s_axis_tuser  (s_axis_tuser ),
        .m_axis_tdata  (i_axis_tdata ),
        .m_axis_tkeep  (i_axis_tkeep ),
        .m_axis_tvalid (i_axis_tvalid),
        .m_axis_tready (i_axis_tready),
        .m_axis_tlast  (i_axis_tlast ),
        .m_axis_tid    (i_axis_tid   ),
        .m_axis_tdest  (i_axis_tdest ),
        .m_axis_tuser  (i_axis_tuser )
      );
    end

    if (M_DATA_WIDTH == I_DATA_WIDTH) begin
      assign m_axis_tdata  = i_axis_tdata ;
      assign m_axis_tkeep  = i_axis_tkeep ;
      assign m_axis_tvalid = i_axis_tvalid;
      assign m_axis_tlast  = i_axis_tlast ;
      assign m_axis_tid    = i_axis_tid   ;
      assign m_axis_tdest  = i_axis_tdest ;
      assign m_axis_tuser  = i_axis_tuser ;
      assign i_axis_tready = m_axis_tready;
    end else begin
      axis_adapter #(
        .S_DATA_WIDTH  (I_DATA_WIDTH ),
        .S_KEEP_ENABLE (I_KEEP_ENABLE),
        .S_KEEP_WIDTH  (I_KEEP_WIDTH ),
        .M_DATA_WIDTH  (M_DATA_WIDTH ),
        .M_KEEP_ENABLE (M_KEEP_ENABLE),
        .M_KEEP_WIDTH  (M_KEEP_WIDTH ),
        .ID_ENABLE     (ID_ENABLE    ),
        .ID_WIDTH      (ID_WIDTH     ),
        .DEST_ENABLE   (DEST_ENABLE  ),
        .DEST_WIDTH    (DEST_WIDTH   ),
        .USER_ENABLE   (USER_ENABLE  ),
        .USER_WIDTH    (USER_WIDTH   )
      ) MASTER_ADAPTER (
        .clk           (clk          ),
        .rstn          (rstn         ),
        .s_axis_tdata  (i_axis_tdata ),
        .s_axis_tkeep  (i_axis_tkeep ),
        .s_axis_tvalid (i_axis_tvalid),
        .s_axis_tready (i_axis_tready),
        .s_axis_tlast  (i_axis_tlast ),
        .s_axis_tid    (i_axis_tid   ),
        .s_axis_tdest  (i_axis_tdest ),
        .s_axis_tuser  (i_axis_tuser ),
        .m_axis_tdata  (m_axis_tdata ),
        .m_axis_tkeep  (m_axis_tkeep ),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tready (m_axis_tready),
        .m_axis_tlast  (m_axis_tlast ),
        .m_axis_tid    (m_axis_tid   ),
        .m_axis_tdest  (m_axis_tdest ),
        .m_axis_tuser  (m_axis_tuser )
      );
    end
  endgenerate

endmodule
