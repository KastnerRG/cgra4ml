/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.

Create Date: 03/11/2020
Design Name: ALWAYS_VALID_CYCLIC_BRAM
Tool Versions: Vivado 2018.2
Description: * Wrapper around BRAM to make it behave like always ready
                (hide its latency)
             * Valid goes high only after filling the entire RAM
             * Problems
                - Has a buffer of depth LATENCY+1
                    If BRAM is too wide (96 bytes), will take too many ffs here.
                - Can ommit the output fabric FF of BRAM, to have 2 latency
                    BRAM's output comes through a mux into buffer
                - m_data is not registered (Buf via mux)

Revision:
Revision 0.01 - File Created
Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////*/

module always_valid_cyclic_bram #(
  W_DEPTH = 8,
  W_WIDTH = 8,
  R_WIDTH = 8,
  LATENCY = 3,
  IP_TYPE = 0  // 0: depth=3m, 1: depth=m (edge) 2: weights
)(
  clk  ,
  clken,
  resetn,
  s_valid_ready,
  s_data,
  m_data,
  m_valid,
  m_ready,
  w_full,
  r_addr_max,
  r_addr_min,
  w_addr_max
);
  localparam R_DEPTH = W_DEPTH * W_WIDTH / R_WIDTH;
  localparam W_ADDR_WIDTH = $clog2(W_DEPTH);
  localparam R_ADDR_WIDTH = $clog2(R_DEPTH);

  localparam BUFFER_DEPTH = LATENCY + 1;
  localparam PTR_WIDTH    = $clog2(BUFFER_DEPTH);

  input  logic clk, clken, resetn;
  input  logic s_valid_ready, m_ready;
  output logic m_valid, w_full;
  input  logic [W_WIDTH-1:0] s_data;
  output logic [R_WIDTH-1:0] m_data;
  input  logic [R_ADDR_WIDTH-1:0] r_addr_max;
  input  logic [R_ADDR_WIDTH-1:0] r_addr_min;
  input  logic [W_ADDR_WIDTH-1:0] w_addr_max;

  
  logic m_valid_ready;
  assign m_valid_ready = m_valid && m_ready;
  logic bram_r_en;

  /*
    STATE MACHINE
  */
  localparam WRITE_S  = 0;
  localparam FILL_1_S = 1;
  localparam FILL_2_S = 2;
  localparam READ_S   = 3;  
  logic [1:0] state, state_next;

  register #(
    .WORD_WIDTH   (2), 
    .RESET_VALUE  (WRITE_S),
    .LOCAL        (1)
  ) STATE (
    .clock        (clk),
    .clock_enable (clken),
    .resetn       (resetn),
    .data_in      (state_next),
    .data_out     (state)
  );

  always_comb begin
    state_next = state; // else
    unique case (state)
      WRITE_S : if(addr_w == w_addr_max   && s_valid_ready) state_next = FILL_1_S;
      FILL_1_S: if(bram_valid_out)                            state_next = FILL_2_S;
      FILL_2_S: if(w_ptr  == BUFFER_DEPTH-1)                  state_next = READ_S  ;
    endcase
  end

  always_comb begin
    unique case (state)
      WRITE_S : begin
                  bram_r_en = 0;
                  m_valid = 0;
                end
      FILL_1_S: begin
                  bram_r_en = 1;
                  m_valid = 0;
                end
      FILL_2_S: begin
                  bram_r_en = 0;
                  m_valid   = 1;
                end
      READ_S  : begin
                  bram_r_en = m_ready;
                  m_valid = 1;
                end
    endcase
  end

  /*
    BRAM_WRITE_ADDRESS
  */

  logic [W_ADDR_WIDTH-1:0] addr_w_prev, addr_w;
  assign addr_w = (addr_w_prev == w_addr_max) ? 0 : addr_w_prev + 1;

  assign w_full = addr_w == w_addr_max;

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
    - typically 0 but for weights, we keep this as address beyond config bits
  */

  logic [R_ADDR_WIDTH-1:0] addr_r, addr_r_next;
  assign addr_r_next = (addr_r == r_addr_max) ? r_addr_min : addr_r + 1;

  register #(
    .WORD_WIDTH   (R_ADDR_WIDTH), 
    .RESET_VALUE  (0),
    .LOCAL        (1)
  ) ADD_R (
    .clock        (clk   ),
    .clock_enable (clken && bram_r_en),
    .resetn       (resetn),
    .data_in      (addr_r_next),
    .data_out     (addr_r     )
  );

  /*
    BRAM_VALID_OUT
    Simulates latency of BRAM for valid data
  */

  logic bram_valid_out;
  n_delay #(
      .N          (LATENCY),
      .WORD_WIDTH (1),
      .LOCAL      (1)
  ) BRAM_VALID (
      .clk        (clk           ),
      .resetn     (resetn        ),
      .clken      (clken         ),
      .data_in    (bram_r_en     ),
      .data_out   (bram_valid_out)
  );

  logic [R_WIDTH-1:0] bram_r_data;
  generate
    if (IP_TYPE == 0)
      bram_lrelu BRAM (
        .clka (clk               ),
        .ena  (clken             ),
        .wea  (s_valid_ready     ),
        .addra(addr_w            ),
        .dina (s_data            ),
        .clkb (clk               ),
        .enb  (clken             ),
        .addrb(addr_r            ),
        .doutb(bram_r_data       )
      );
    else if (IP_TYPE == 1)
      bram_lrelu_edge BRAM (
        .clka (clk               ),
        .ena  (clken             ),
        .wea  (s_valid_ready     ),
        .addra(addr_w            ),
        .dina (s_data            ),
        .clkb (clk               ),
        .enb  (clken             ),
        .addrb(addr_r            ),
        .doutb(bram_r_data       )
      );
    else if (IP_TYPE == 2)
      bram_weights BRAM (
        .clka (clk               ),
        .ena  (clken             ),
        .wea  (s_valid_ready     ),
        .addra(addr_w            ),
        .dina (s_data            ),
        .clkb (clk               ),
        .enb  (clken             ),
        .addrb(addr_r            ),
        .doutb(bram_r_data       )
      );
  endgenerate

  /*
    WRITE POINTER

    - Counts cyclically from 0 to BUFFER_DEPTH-1
        if "w_ptr_incr" (=s_valid_ready or bram_valid_out)

    - Prevent w_ptr incrementing from bram_valid immediately after a reset
      - W_PTR_RESET_COUNT activates after a reset and count downs for LATENCY clocks
      - w_ptr does not increment during this time
  */
  localparam LATENCY_BITS = $clog2(LATENCY+1);
  logic [LATENCY_BITS-1:0] w_ptr_reset_count, w_ptr_reset_count_next;
  assign w_ptr_reset_count_next =  w_ptr_reset_count - 1;
  register #(
    .WORD_WIDTH   (LATENCY_BITS), 
    .RESET_VALUE  (LATENCY),
    .LOCAL        (1)
  ) W_PTR_RESET_COUNT (
    .clock        (clk),
    .clock_enable (clken && (w_ptr_reset_count !=0)),
    .resetn       (resetn),
    .data_in      (w_ptr_reset_count_next),
    .data_out     (w_ptr_reset_count)
  );

  logic [PTR_WIDTH-1:0] w_ptr, w_ptr_next;

  assign w_ptr_next = (w_ptr == BUFFER_DEPTH-1) ? 0  : w_ptr + 1;

  register #(
    .WORD_WIDTH   (PTR_WIDTH), 
    .RESET_VALUE  (0),
    .LOCAL        (1)
  ) W_PTR (
    .clock        (clk),
    .clock_enable (clken && bram_valid_out && (w_ptr_reset_count==0)),
    .resetn       (resetn),
    .data_in      (w_ptr_next),
    .data_out     (w_ptr     )
  );


  /*
    BUFFER

    - buffer[w_ptr] <= bram_data
    - m_data = buffer[r_ptr]
  */

  logic [R_WIDTH-1:0] buffer_data       [BUFFER_DEPTH];
  logic               buffer_en         [BUFFER_DEPTH];

  generate
    for(genvar i=0; i < BUFFER_DEPTH; i++) begin: buf_data

      assign buffer_en[i] = (w_ptr == i) && bram_valid_out;

      register #(
        .WORD_WIDTH   (R_WIDTH), 
        .RESET_VALUE  (0)
      ) BUFFER_DATA (
        .clock        (clk   ),
        .clock_enable (clken && buffer_en[i]),
        .resetn       (resetn),
        .data_in      (bram_r_data),
        .data_out     (buffer_data [i])
      );
    end
  endgenerate

  logic [PTR_WIDTH-1:0] r_ptr, r_ptr_next;
  assign r_ptr_next = (r_ptr == BUFFER_DEPTH-1) ? 0 : r_ptr  + 1;

  register #(
    .WORD_WIDTH   (PTR_WIDTH), 
    .RESET_VALUE  (0),
    .LOCAL        (1)
  ) R_PTR (
    .clock        (clk   ),
    .clock_enable (clken && m_valid_ready),
    .resetn       (resetn),
    .data_in      (r_ptr_next),
    .data_out     (r_ptr     )
  );

  assign m_data  = buffer_data[r_ptr];
  
endmodule