/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.

Create Date: 12/05/2021
Design Name: CYCLIC_BRAM
Tool Versions: Vivado 2018.2

Revision:
Revision 0.01 - File Created
Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////*/

module cyclic_bram #(
  R_DEPTH      = 8,
  R_DATA_WIDTH = 8,
  W_DATA_WIDTH = 8,
  LATENCY      = 3,
  ABSORB       = 0
)(
  clk  ,
  clken,
  resetn,
  w_en,
  r_en,
  s_data,
  m_data,
  m_valid,
  r_addr_max,
  w_addr_max,
  r_addr_min
  );
  localparam SIZE = R_DEPTH * R_DATA_WIDTH;
  localparam W_DEPTH =  SIZE / W_DATA_WIDTH;
  localparam W_ADDR_WIDTH = $clog2(W_DEPTH);
  localparam R_ADDR_WIDTH = $clog2(R_DEPTH);

  input  logic clk, clken, resetn;
  input  logic w_en, r_en;
  input  logic [W_DATA_WIDTH-1:0] s_data;
  output logic [R_DATA_WIDTH-1:0] m_data;
  output logic m_valid;
  input  logic [R_ADDR_WIDTH-1:0] r_addr_max, r_addr_min;
  input  logic [W_ADDR_WIDTH-1:0] w_addr_max;
 
  /*
    BRAM_WRITE_ADDRESS
  */

  logic [R_ADDR_WIDTH-1:0] w_addr_next, w_addr;
  assign w_addr_next = (w_addr < w_addr_max) ? w_addr + 1 : 0;
  register #(
    .WORD_WIDTH   (R_ADDR_WIDTH), 
    .RESET_VALUE  (0),
    .LOCAL        (1)
  ) ADDR_W (
    .clock        (clk        ),
    .clock_enable (clken && w_en),
    .resetn       (resetn     ),
    .data_in      (w_addr_next),
    .data_out     (w_addr)
  );

  /*
    BRAM READ ADDRESS
  */

  logic [R_ADDR_WIDTH-1:0] r_addr, r_addr_next;
  assign r_addr_next = (r_addr < r_addr_max) ?  r_addr + 1 : r_addr_min;
  register #(
    .WORD_WIDTH   (R_ADDR_WIDTH), 
    .RESET_VALUE  (0),
    .LOCAL        (1)
  ) ADD_R (
    .clock        (clk   ),
    .clock_enable (clken && r_en),
    .resetn       (resetn),
    .data_in      (r_addr_next),
    .data_out     (r_addr     )
  );

  logic [R_DATA_WIDTH-1 :0] bram_m_data;

  xpm_memory_sdpram_wrapper #(
    .R_DEPTH      (R_DEPTH     ),
    .R_DATA_WIDTH (R_DATA_WIDTH),
    .W_DATA_WIDTH (W_DATA_WIDTH),
    .LATENCY      (LATENCY     )
  ) BRAM (
    .clken  (clken ),
    .resetn (resetn),
    .r_clk  (clk   ),
    .r_en   (clken && r_en  ),
    .r_addr (r_addr),
    .r_data (bram_m_data),
    .w_clk  (clk   ),
    .w_en   (clken && w_en  ),
    .w_addr (w_addr),
    .w_data (s_data)
  );

  /*
    FIFO and Delay to make an always valid cyclic BRAM
  */

  if (ABSORB) begin
    
    logic empty, fifo_r_en, r_en_delayed;

    n_delay #(
      .N          (LATENCY),
      .WORD_WIDTH (1)
    ) VALID (
      .clk      (clk),
      .resetn   (resetn),
      .clken    (clken),
      .data_in  (r_en),
      .data_out (r_en_delayed)
    );

   xpm_fifo_sync_wrapper #(
      .READ_DATA_WIDTH  (R_DATA_WIDTH ),
      .WRITE_DATA_WIDTH (R_DATA_WIDTH ),
      .DEPTH            (16) //2**$clog2(LATENCY+1)
    ) fifo (
      .rst        (~resetn), 
      .rd_en      (clken && fifo_r_en), 
      .wr_en      (clken && r_en_delayed), 
      .wr_clk     (clk), 
      .empty      (empty), 
      // .full  (), 
      .data_valid (m_valid),
      .din        (bram_m_data), 
      .dout       (m_data)
    );

    assign fifo_r_en = ~empty && r_en;
  end
  else assign m_data = bram_m_data;

endmodule