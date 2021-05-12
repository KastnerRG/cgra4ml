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
  W_DEPTH = 8,
  W_WIDTH = 8,
  R_WIDTH = 8,
  IP_TYPE = 0  // 0: depth=3m, 1: depth=m (edge)
)(
  clk  ,
  clken,
  resetn,
  s_valid_ready,
  s_data,
  m_data,
  m_ready,
  r_addr_max,
  w_addr_max
);
  localparam R_DEPTH = W_DEPTH * W_WIDTH / R_WIDTH;
  localparam W_ADDR_WIDTH = $clog2(W_DEPTH);
  localparam R_ADDR_WIDTH = $clog2(R_DEPTH);

  input  logic clk, clken, resetn;
  input  logic s_valid_ready, m_ready;
  input  logic [W_WIDTH-1:0] s_data;
  output logic [R_WIDTH-1:0] m_data;
  input  logic [R_ADDR_WIDTH-1:0] r_addr_max;
  input  logic [W_ADDR_WIDTH-1:0] w_addr_max;

  /*
    BRAM_WRITE_ADDRESS
  */

  logic [W_ADDR_WIDTH-1:0] addr_w_prev, addr_w;
  assign addr_w = (addr_w_prev == w_addr_max) ? 0 : addr_w_prev + 1;
  register #(
    .WORD_WIDTH   (W_ADDR_WIDTH), 
    .RESET_VALUE  (-1),
    .LOCAL        (1)
  ) ADDR_W (
    .clock        (clk        ),
    .clock_enable (clken && s_valid_ready),
    .resetn       (resetn     ),
    .data_in      (addr_w),
    .data_out     (addr_w_prev)
  );

  /*
    BRAM READ ADDRESS

    - Counts from 0
    - Resets to r_addr_min after maxing out
  */

  logic [R_ADDR_WIDTH-1:0] addr_r, addr_r_next;
  assign addr_r_next = (addr_r == r_addr_max) ? 0 : addr_r + 1;
  register #(
    .WORD_WIDTH   (R_ADDR_WIDTH), 
    .RESET_VALUE  (0),
    .LOCAL        (1)
  ) ADD_R (
    .clock        (clk   ),
    .clock_enable (clken && m_ready),
    .resetn       (resetn),
    .data_in      (addr_r_next),
    .data_out     (addr_r     )
  );

  generate
    if (IP_TYPE == 0)
      bram_lrelu BRAM (
        .clka (clk               ),
        .ena  (clken             ),
        .wea  (s_valid_ready     ),
        .addra(addr_w            ),
        .dina (s_data            ),
        .clkb (clk               ),
        .enb  (clken & ~s_valid_ready),
        .addrb(addr_r            ),
        .doutb(m_data            )
      );
    else if (IP_TYPE == 1)
      bram_lrelu_edge BRAM (
        .clka (clk               ),
        .ena  (clken             ),
        .wea  (s_valid_ready     ),
        .addra(addr_w            ),
        .dina (s_data            ),
        .clkb (clk               ),
        .enb  (clken & ~s_valid_ready),
        .addrb(addr_r            ),
        .doutb(m_data            )
      );
  endgenerate  
endmodule