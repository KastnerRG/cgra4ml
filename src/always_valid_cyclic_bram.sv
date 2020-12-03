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
  DEPTH   = 8 ,
  WIDTH   = 64,
  LATENCY = 3
)(
  clk  ,
  clken,
  resetn,
  s_valid_ready,
  s_data,
  m_data,
  m_valid,
  m_ready,
  addr_max_1
);
  localparam BUFFER_DEPTH = LATENCY + 1;
  localparam ADDR_WIDTH = $clog2(DEPTH);
  localparam BUFFER_ADDR_WIDTH = $clog2(LATENCY+1);

  input  logic clk, clken, resetn;
  input  logic s_valid_ready, m_ready;
  output logic m_valid;
  input  logic [WIDTH-1:0] s_data;
  output logic [WIDTH-1:0] m_data;
  input  logic [ADDR_WIDTH-1:0] addr_max_1;

  
  logic m_valid_ready;
  assign m_valid_ready = m_valid && m_ready;

  /*
    STATES
      - IDLE : Fill buffer with s_data
      - WORK : Fill buffer with bram_dout
  */

  localparam IDLE = 0;
  localparam WORK = 1;
  logic state;
  logic state_trigger;

  assign state_trigger = (w_ptr == BUFFER_DEPTH-1 && s_valid_ready);

  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (IDLE)
  ) STATE (
    .clock        (clk   ),
    .clock_enable (clken && state_trigger),
    .resetn       (resetn),
    .data_in      (WORK  ),
    .data_out     (state )
  );

  /*
    WRITE POINTER

    - Counts cyclically from 0 to BUFFER_DEPTH-1
        if "w_ptr_incr" (=s_valid_ready or bram_valid_out)
  */
  logic w_ptr_incr;
  logic [BUFFER_DEPTH-1:0] w_ptr, w_ptr_next;

  assign w_ptr_incr = (state == IDLE) ? s_valid_ready : bram_valid_out;
  assign w_ptr_next = (w_ptr == BUFFER_DEPTH-1) ? 0   : w_ptr + 1;

  register #(
    .WORD_WIDTH   (BUFFER_DEPTH), 
    .RESET_VALUE  (0)
  ) W_PTR (
    .clock        (clk   ),
    .clock_enable (clken && w_ptr_incr),
    .resetn       (resetn),
    .data_in      (w_ptr_next),
    .data_out     (w_ptr     )
  );

  /*
    BUFFER

    - buffer[w_ptr] <= s_data OR bram_data
    - m_data = buffer[r_ptr]
  */

  logic [WIDTH-1:0] buffer_data       [BUFFER_DEPTH];
  logic [WIDTH-1:0] buffer_data_next  [BUFFER_DEPTH];

  logic buff_w_trigger;
  assign buff_w_trigger = (state == IDLE) ? s_valid_ready : bram_valid_out;
  assign m_data  = buffer_data[r_ptr];

  generate
    for(genvar i=0; i < BUFFER_DEPTH; i++) begin: buf_data
      register #(
        .WORD_WIDTH   (WIDTH), 
        .RESET_VALUE  (0)
      ) BUFFER_DATA (
        .clock        (clk   ),
        .clock_enable (clken && buff_w_trigger),
        .resetn       (resetn),
        .data_in      (buffer_data_next[i]),
        .data_out     (buffer_data     [i])
      );
    end
  endgenerate
  always_comb begin
    buffer_data_next = buffer_data; // default
    if      (s_valid_ready)  buffer_data_next[w_ptr] = s_data;
    else if (bram_valid_out) buffer_data_next[w_ptr] = bram_r_data;
    else                     buffer_data_next[w_ptr] = buffer_data[w_ptr];
  end

  /*
    BRAM_VALID_OUT
    Simulates latency of BRAM for valid data
  */

  logic bram_valid_out;
  n_delay #(
      .N          (LATENCY),
      .DATA_WIDTH (1)
  ) BRAM_VALID (
      .clk        (clk           ),
      .resetn     (resetn        ),
      .clken      (clken         ),
      .data_in    (m_valid_ready ),
      .data_out   (bram_valid_out)
  );

  /*
    BRAM_WRITE_ADDRESS
  */

  logic [ADDR_WIDTH-1:0] addr_w_prev, addr_w;
  assign addr_w = (addr_w_prev == addr_max_1) ? 0 : addr_w_prev + 1;

  register #(
    .WORD_WIDTH   (ADDR_WIDTH), 
    .RESET_VALUE  (-1)
  ) ADDR_W (
    .clock        (clk        ),
    .clock_enable (clken && s_valid_ready),
    .resetn       (resetn     ),
    .data_in      (addr_w),
    .data_out     (addr_w_prev)
  );

  /*
    BRAM READ ADDRESS
  */

  logic [ADDR_WIDTH-1:0] addr_r, addr_r_next;
  assign addr_r_next = (addr_r == addr_max_1) ? 0 : addr_r + 1;

  register #(
    .WORD_WIDTH   (ADDR_WIDTH), 
    .RESET_VALUE  (BUFFER_DEPTH)
  ) ADD_R (
    .clock        (clk   ),
    .clock_enable (clken && m_valid_ready),
    .resetn       (resetn),
    .data_in      (addr_r_next),
    .data_out     (addr_r     )
  );

  logic [BUFFER_DEPTH-1:0] r_ptr, r_ptr_next;
  assign r_ptr_next = (r_ptr == BUFFER_DEPTH-1) ? 0 : r_ptr  + 1;

  register #(
    .WORD_WIDTH   (BUFFER_DEPTH), 
    .RESET_VALUE  (0)
  ) R_PTR (
    .clock        (clk   ),
    .clock_enable (clken && m_valid_ready),
    .resetn       (resetn),
    .data_in      (r_ptr_next),
    .data_out     (r_ptr     )
  );

  /*
    M_VALID

    * Goes high after filling the entire BRAM
    * Writing to BRAM happens via AXIS. It may stop, start and take long time to fil
      completely.
    * Hence, cannot guarantee all data in BRAM are valid during writing.
    * Can check the write address and pull valid down -- but that won't be always valid
  */
  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) MVALID (
    .clock        (clk    ),
    .clock_enable (clken && (addr_w==addr_max_1) && s_valid_ready),
    .resetn       (resetn ),
    .data_in      (1),
    .data_out     (m_valid)
  );

  logic [WIDTH-1:0] bram_r_data;
  sdpram sdpram (
    .clka (clk          ),
    .ena  (clken        ),
    .wea  (s_valid_ready),
    .addra(addr_w       ),
    .dina (s_data       ),
    .clkb (clk          ),
    .enb  (clken        ),
    .addrb(addr_r       ),
    .doutb(bram_r_data  )
  );
  
endmodule