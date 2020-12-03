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
  logic state, state_next;
  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (IDLE)
  ) STATE (
    .clock        (clk   ),
    .clock_enable (clken ),
    .resetn       (resetn),
    .data_in      (state_next),
    .data_out     (state     )
  );
  always_comb begin
    if (state == IDLE) begin
      if (w_ptr == BUFFER_DEPTH-1 && s_valid_ready) begin
            state_next = WORK;
      end
      else  state_next = IDLE;
    end
    else    state_next = WORK;
  end

  /*
    WRITE POINTER

    - Counts cyclically from 0 to BUFFER_DEPTH-1
        if "w_ptr_incr" (=s_valid_ready or bram_valid_out)
  */
  logic w_ptr_incr;
  logic [BUFFER_DEPTH-1:0] w_ptr, w_ptr_next;
  register #(
    .WORD_WIDTH   (BUFFER_DEPTH), 
    .RESET_VALUE  (0)
  ) W_PTR (
    .clock        (clk   ),
    .clock_enable (clken ),
    .resetn       (resetn),
    .data_in      (w_ptr_next),
    .data_out     (w_ptr     )
  );
  always_comb begin
    if (state == IDLE) w_ptr_incr = s_valid_ready;
    else               w_ptr_incr = bram_valid_out;

    if (w_ptr_incr) begin
      if (w_ptr == BUFFER_DEPTH-1) w_ptr_next = 0;
      else                         w_ptr_next = w_ptr + 1;
    end
    else begin
      w_ptr_next = w_ptr;
    end
  end

  /*
    BUFFER

    - buffer[w_ptr] <= s_data OR bram_data
    - m_data = buffer[r_ptr]
  */

  logic [WIDTH-1:0] buffer_data       [BUFFER_DEPTH];
  logic [WIDTH-1:0] buffer_data_next  [BUFFER_DEPTH];
  generate
    for(genvar i=0; i < BUFFER_DEPTH; i++) begin: buf_data
      register #(
        .WORD_WIDTH   (WIDTH), 
        .RESET_VALUE  (0)
      ) BUFFER_DATA (
        .clock        (clk   ),
        .clock_enable (clken ),
        .resetn       (resetn),
        .data_in      (buffer_data_next[i]),
        .data_out     (buffer_data     [i])
      );
    end
  endgenerate
  always_comb begin
    m_data  = buffer_data[r_ptr];

    buffer_data_next = buffer_data; // default
    if (state == IDLE)begin
      if (s_valid_ready)  buffer_data_next[w_ptr] = s_data;
    end
    else begin
      if (bram_valid_out) buffer_data_next[w_ptr] = bram_r_data;
      else                buffer_data_next[w_ptr] = buffer_data_next[w_ptr];
    end
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
  register #(
    .WORD_WIDTH   (ADDR_WIDTH), 
    .RESET_VALUE  (-1)
  ) ADDR_W (
    .clock        (clk        ),
    .clock_enable (clken      ),
    .resetn       (resetn     ),
    .data_in      (addr_w),
    .data_out     (addr_w_prev     )
  );
  always_comb begin
    if (s_valid_ready) begin
      if (addr_w_prev == addr_max_1) addr_w = 0;
      else                           addr_w = addr_w_prev + 1;
    end
    else begin
      addr_w = addr_w_prev;
    end
  end

  /*
    BRAM READ ADDRESS
  */

  logic [ADDR_WIDTH-1:0] addr_r, addr_r_next;
  logic [BUFFER_DEPTH-1:0] r_ptr, r_ptr_next;
  register #(
    .WORD_WIDTH   (ADDR_WIDTH), 
    .RESET_VALUE  (BUFFER_DEPTH)
  ) ADD_R (
    .clock        (clk   ),
    .clock_enable (clken ),
    .resetn       (resetn),
    .data_in      (addr_r_next),
    .data_out     (addr_r     )
  );
  register #(
    .WORD_WIDTH   (BUFFER_DEPTH), 
    .RESET_VALUE  (0)
  ) R_PTR (
    .clock        (clk   ),
    .clock_enable (clken ),
    .resetn       (resetn),
    .data_in      (r_ptr_next),
    .data_out     (r_ptr     )
  );
  always_comb begin
    if (m_valid_ready) begin
      if (addr_r == addr_max_1)    addr_r_next = 0;
      else                         addr_r_next = addr_r + 1;

      if (r_ptr == BUFFER_DEPTH-1) r_ptr_next  = 0;
      else                         r_ptr_next  = r_ptr  + 1;
    end
    else begin
      addr_r_next = addr_r;
      r_ptr_next  = r_ptr;
    end
  end

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
    .doutb(bram_r_data       )
  );
  
endmodule