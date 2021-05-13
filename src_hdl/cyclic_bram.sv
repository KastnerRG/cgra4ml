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
  IP_TYPE = 0,  // 0: depth=3m, 1: depth=m (edge), 2: bram_weights
  ABSORB_LATENCY = 0
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
  r_addr_min
  );
  localparam R_DEPTH = W_DEPTH * W_WIDTH / R_WIDTH;
  localparam W_ADDR_WIDTH = $clog2(W_DEPTH);
  localparam R_ADDR_WIDTH = $clog2(R_DEPTH);

  input  logic clk, clken, resetn;
  input  logic w_en, r_en;
  input  logic [W_WIDTH-1:0] s_data;
  output logic [R_WIDTH-1:0] m_data;
  output logic m_valid;
  input  logic [R_ADDR_WIDTH-1:0] r_addr_max, r_addr_min;
 
  /*
    BRAM_WRITE_ADDRESS
  */

  logic [R_ADDR_WIDTH-1:0] addr_w_next, addr_w;
  assign addr_w_next = (addr_w < r_addr_max) ? addr_w + (W_WIDTH / R_WIDTH) : 0;
  register #(
    .WORD_WIDTH   (R_ADDR_WIDTH), 
    .RESET_VALUE  (0),
    .LOCAL        (1)
  ) ADDR_W (
    .clock        (clk        ),
    .clock_enable (clken && w_en),
    .resetn       (resetn     ),
    .data_in      (addr_w_next),
    .data_out     (addr_w)
  );

  /*
    BRAM READ ADDRESS
  */

  logic [R_ADDR_WIDTH-1:0] addr_r, addr_r_next;
  assign addr_r_next = (addr_r < r_addr_max) ?  addr_r + 1 : r_addr_min;
  register #(
    .WORD_WIDTH   (R_ADDR_WIDTH), 
    .RESET_VALUE  (0),
    .LOCAL        (1)
  ) ADD_R (
    .clock        (clk   ),
    .clock_enable (clken && r_en),
    .resetn       (resetn),
    .data_in      (addr_r_next),
    .data_out     (addr_r     )
  );

  logic [R_ADDR_WIDTH-1:0] addr;
  assign addr = w_en ? addr_w : addr_r;

  logic [R_WIDTH-1 :0] bram_m_data;
  generate
    if (IP_TYPE == 0)
      bram_lrelu BRAM (
        .clka (clk               ),
        .ena  (clken             ),
        .wea  (w_en              ),
        .addra(addr              ),
        .dina (s_data            ),
        .douta(bram_m_data       )
      );
    else if (IP_TYPE == 1)
      bram_lrelu_edge BRAM (
        .clka (clk               ),
        .ena  (clken             ),
        .wea  (w_en              ),
        .addra(addr              ),
        .dina (s_data            ),
        .douta(bram_m_data       )
      );
    else if (IP_TYPE == 2)
      bram_weights BRAM (
        .clka (clk               ),
        .ena  (clken             ),
        .wea  (w_en              ),
        .addra(addr              ),
        .dina (s_data            ),
        .douta(bram_m_data       )
      );
  endgenerate

  /*
    FIFO and Delay to make an always valid cyclic BRAM
  */

  if (ABSORB_LATENCY != 0) begin
    
    logic fifo_w_en, empty, fifo_r_en, full, r_en_delayed;

    n_delay #(
      .N          (ABSORB_LATENCY),
      .WORD_WIDTH (1)
    ) VALID (
      .clk      (clk),
      .resetn   (resetn),
      .clken    (clken),
      .data_in  (r_en),
      .data_out (r_en_delayed)
    );

    bram_fifo fifo (
      .clk   (clk          ),
      .srst  (~resetn      ),
      .din   (bram_m_data  ),
      .wr_en (r_en_delayed ),
      .rd_en (fifo_r_en    ), 
      .dout  (m_data       ),
      .full  (full         ),
      .empty (empty        ) 
    );

    assign fifo_r_en = ~empty && r_en;
    assign m_valid   = ~empty; 

  end
  else assign m_data = bram_m_data;

endmodule