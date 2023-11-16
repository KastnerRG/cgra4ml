`include "defines.svh"

module out_ram_switch #(
  localparam ROWS                 = `ROWS   ,
             COLS                 = `COLS   ,
             KW_MAX               = `KW_MAX ,
             Y_BITS               = `Y_BITS ,
             RAM_LATENCY          = 2,
             WORD_WIDTH           = 32,  // always 32, byte enable available for smaller width, but complicated
             ADDR_WIDTH           = 10   // word address
)(
  input  logic clk, rstn,

  output logic                          s_ready,
  input  logic [ROWS -1:0][Y_BITS -1:0] s_data,
  input  logic                          s_valid, s_last,

  input  logic [(ADDR_WIDTH+2)-1:0]     m_ram_addr_a,
  output logic [ WORD_WIDTH   -1:0]     m_ram_rddata_a,
  input  logic                          m_ram_en_a,

  output logic m_done_fill,
  input  logic m_t_done_proc
);

  localparam BITS_COLS = $clog2(COLS), BITS_ROWS = $clog2(ROWS);
  enum {W_IDLE_S, W_WRITE_S, W_FILL_S, W_SWITCH_S} state_write, state_write_next;
  enum {R_IDLE_S, R_DONE_FILL_S, R_READ_S, R_WAIT_S, R_SWITCH_S} state_read, state_read_next;

  logic i_read, i_write, s_first, en_shift, last, dp_prev, lc_rows, l_rows;

  logic [ADDR_WIDTH-1:0] ram_w_addr, ram_r_addr;
  logic [ROWS-1:0][Y_BITS -1:0] shift_reg;
  logic           [Y_BITS -1:0] ram_din;

  logic [1:0][ADDR_WIDTH-1:0] ram_addr;
  logic [1:0][Y_BITS    -1:0] ram_dout;
  logic [1:0] done_read, done_write, ram_wen;

  // Switching RAMs
  always_ff @(posedge clk)
    if (!rstn)  {i_write, i_read} <= 0;
    else begin
      if (state_write == W_SWITCH_S)  i_write <= !i_write;
      if (state_read  == R_SWITCH_S)  i_read  <= !i_read;
    end

  always_ff @(posedge clk) begin
    state_write <= !rstn ? W_IDLE_S : state_write_next;
    state_read  <= !rstn ? R_IDLE_S : state_read_next;
  end


  // -----
  // WRITE
  // -----
  always_comb
    unique case (state_write)
      W_IDLE_S    : if (done_read [i_write]) state_write_next = W_WRITE_S; // counter
      W_WRITE_S   : if (lc_rows && last    ) state_write_next = W_FILL_S;
      W_FILL_S    :                          state_write_next = W_SWITCH_S;
      W_SWITCH_S  :                          state_write_next = W_IDLE_S;
    endcase

  always_ff @(posedge clk)  // Special case - first beat of a packet. Bcz lc_rows = 0 at start
    if      (!rstn || (state_write == W_FILL_S)) s_first <= 1;
    else if (s_valid && s_ready)                 s_first <= 0;

  always_comb begin
    s_ready   = (state_write == W_WRITE_S && state_write_next == W_WRITE_S) && (s_first || l_rows);     // first or after shifting rows 
    en_shift  = (state_write == W_WRITE_S) && (l_rows ? s_valid || last : 1) && !s_first;  // if last, wait for valid 
    ram_din   = shift_reg[0];
  end

  always_ff @(posedge clk) // SHIFT REG - write data
    if      (s_valid && s_ready)        shift_reg <= s_data;
    else if (en_shift)                  shift_reg <= shift_reg >> Y_BITS;

  counter #(.W(BITS_ROWS)) C_ROWS (.clk(clk), .reset(state_write == W_IDLE_S), .en(en_shift), .max_in(BITS_ROWS'(ROWS-1)), .last_clk(lc_rows), .last(l_rows));

  always_ff @(posedge clk) // w_addr
    if (!rstn || state_write==W_IDLE_S) ram_w_addr <= 0;
    else if (en_shift)                  ram_w_addr <= ram_w_addr + 1'b1;

  always_ff @(posedge clk) // Store last
    if (!rstn)                          last <= 0;
    else if (s_valid && s_ready)        last <= s_last;



  // -----
  // READ
  // -----
  // 1. fw starts, waits for t_m_done_fill to toggle
  // 2. mod toggles t_m_done_fill, moving to READ_S, waits for m_t_done_proc
  // 3. fw continues, finishes processing, toggles m_t_done_proc
  // 4. mod senses m_t_done_proc in READ_S, moves, waits for done_write, toggles t_m_done_fill
  // 5. fw loops to beginning, waits for t_m_done_fill to toggle

  always_comb
    unique case (state_read)
      R_IDLE_S    : if (done_write [i_read])           state_read_next = R_DONE_FILL_S;
      R_DONE_FILL_S:                                   state_read_next = R_READ_S;
      R_READ_S    : if (dp_prev != m_t_done_proc)      state_read_next = R_WAIT_S;
      R_WAIT_S    :                                    state_read_next = R_SWITCH_S;
      R_SWITCH_S  :                                    state_read_next = R_IDLE_S;
    endcase 

  assign ram_r_addr      = m_ram_addr_a[(ADDR_WIDTH+2)-1:2];
  assign m_ram_rddata_a  = WORD_WIDTH'(signed'(ram_dout[i_read])); // pad to 32
  assign m_done_fill     = state_read == R_DONE_FILL_S; // one clock for interrupt

  // always_ff @(posedge clk)
  //   if (!rstn)                            t_m_done_fill <= 0;
  //   else if (state_read == R_DONE_FILL_S) t_m_done_fill <= !t_m_done_fill;

  always_ff @(posedge clk)
    if (!rstn)                            dp_prev <= 0;              // m_t_done_proc starts at 0
    else if (state_read_next == R_WAIT_S) dp_prev <= m_t_done_proc;  // sample dp_prev at end of reading

  // -----
  // PING PONG
  // -----
  generate
    for (genvar i=0; i<2; i++) begin: I

      always_ff @(posedge clk)
        if (!rstn)                              done_write[i] <= 0;
        else if (i==i_write)
          if (state_write_next == W_WRITE_S)    done_write[i] <= 0;
          else if (state_write == W_SWITCH_S)   done_write[i] <= 1;

      always_ff @(posedge clk)
        if (!rstn)                              done_read [i] <= 1;
        else if (i==i_read) 
            if (state_read_next == R_READ_S)    done_read [i] <= 0;
            else if (state_read == R_SWITCH_S)  done_read [i] <= 1;
      
      assign ram_wen  [i] =  i == i_write && en_shift && !s_first;
      assign ram_addr [i] = (i == i_write && state_write == W_WRITE_S) ? ram_w_addr : ram_r_addr;

      localparam RAM_ADDR_BITS = $clog2(COLS*ROWS);
      ram_output RAM (
        .clka  (clk),
        .ena   (1'b1),
        .wea   (ram_wen [i] ),
        .addra (RAM_ADDR_BITS'(ram_addr[i])),
        .dina  (ram_din     ),
        .douta (ram_dout[i] )
      );     
    end
  endgenerate
endmodule