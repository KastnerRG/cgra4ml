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

  
  logic [WIDTH-1:0] data_r;
  logic m_valid_ready;

  /*
    REGISTERS
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
      if (w_ptr == BUFFER_DEPTH-1) state_next = WORK;
      else                         state_next = IDLE;
    end
    else                           state_next = WORK;
  end

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
    buffer_data_next = buffer_data; // default
    if (state == IDLE)begin
      if (s_valid_ready)  buffer_data_next[w_ptr] = s_data;
    end
    else begin
      if (bram_valid_out) buffer_data_next[w_ptr] = data_r;
      else                buffer_data_next[w_ptr] = buffer_data_next[w_ptr];
    end
  end

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

  logic [ADDR_WIDTH-1:0] addr_w, addr_w_next;
  register #(
    .WORD_WIDTH   (ADDR_WIDTH), 
    .RESET_VALUE  (-1)
  ) ADDR_W (
    .clock        (clk        ),
    .clock_enable (clken      ),
    .resetn       (resetn     ),
    .data_in      (addr_w_next),
    .data_out     (addr_w     )
  );
  always_comb begin
    if (s_valid_ready) begin
      if (addr_w == addr_max_1) addr_w_next = 0;
      else                      addr_w_next = addr_w + 1;
    end
    else begin
      addr_w_next = addr_w;
    end
  end


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

  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) MVALID (
    .clock        (clk    ),
    .clock_enable (clken && (addr_w_next==addr_max_1) && s_valid_ready),
    .resetn       (resetn ),
    .data_in      (1),
    .data_out     (m_valid)
  );
  always_comb begin
    m_data      = buffer_data[r_ptr];
    m_valid_ready = m_valid && m_ready;
  end

  sdpram sdpram (
    .clka (clk          ),
    .ena  (clken        ),
    .wea  (s_valid_ready),
    .addra(addr_w_next  ),
    .dina (s_data       ),
    .clkb (clk          ),
    .enb  (clken        ),
    .addrb(addr_r       ),
    .doutb(data_r       )
  );
  
endmodule