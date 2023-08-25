`include "../rtl/include/params.svh"

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

  input  logic [(ADDR_WIDTH+2)-1:0]     bram_addr_a,
  output logic [ WORD_WIDTH   -1:0]     bram_rddata_a,
  input  logic                          bram_en_a,

  output logic done_fill,
  input  logic done_firmware
);

  localparam BITS_COLS = $clog2(COLS), BITS_ROWS = $clog2(ROWS);
  enum {W_IDLE_S, W_WRITE_S, W_FILL_S, W_SWITCH_S} state_write, state_write_next;
  enum {R_IDLE_S, R_DONE_FILL, R_READ_S, R_WAIT_S, R_SWITCH_S} state_read, state_read_next;

  logic i_read, i_write, s_first, en_shift, last, df_was_high, lc_rows, l_rows;

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
  always_comb
    unique case (state_read)
      R_IDLE_S    : if (done_write [i_read])           state_read_next = R_DONE_FILL;
      R_DONE_FILL :                                    state_read_next = R_READ_S;
      R_READ_S    : if (!df_was_high && done_firmware) state_read_next = R_WAIT_S;
      R_WAIT_S    :                                    state_read_next = R_SWITCH_S;
      R_SWITCH_S  :                                    state_read_next = R_IDLE_S;
    endcase 

  assign ram_r_addr    = bram_addr_a[(ADDR_WIDTH+2)-1:2];
  assign bram_rddata_a = WORD_WIDTH'(signed'(ram_dout[i_read])); // pad to 32
  assign done_fill     = state_read == R_DONE_FILL; // one clock

  // Done Firmware Was High
  // To prevent the case: fsm waits READ, firmware raises df, fsm leaves READ, goes around WAIT, SWITCH, READ - df is still high, so, fsm moves to WAIT.
  // with this, df being pulled down is recorded in df_was_high. fsm waits in READ until !df_was_high && done_firmware
  always_ff @(posedge clk)
    if (!rstn)                                 df_was_high <= 0;
    else if (done_firmware==0 && df_was_high)  df_was_high <= 0; // df is going to zero
    else if (state_read == R_READ_S)
      if (!df_was_high && done_firmware)       df_was_high <= 1; // df is going to high during READ_S

  // Wait for done firmware to fall before deasserting done_fill - to prevent the loop in firmware missing done_fill
  // always_ff @(posedge clk)
  //   if      (!rstn)                            done_fill <= 0; 
  //   else if (state_read_next == R_DONE_FILL)   done_fill <= 1;
  //   else if (df_was_high && !done_firmware )   done_fill <= 0;


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
            if (state_read_next == R_DONE_FILL) done_read [i] <= 0;
            else if (state_read == R_SWITCH_S)  done_read [i] <= 1;
      
      assign ram_wen  [i] =  i == i_write && en_shift && !s_first;
      assign ram_addr [i] = (i == i_write && state_write == W_WRITE_S) ? ram_w_addr : ram_r_addr;

      localparam RAM_ADDR_BITS = $clog2(COLS*ROWS);
      ram_output #(
        .DEPTH    (COLS * ROWS),
        .WIDTH    (Y_BITS     ),
        .LATENCY  (RAM_LATENCY)
      ) RAM (
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