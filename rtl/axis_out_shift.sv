`include "../rtl/include/params.svh"

module axis_out_shift #(
  localparam ROWS                 = `ROWS                 ,
             COLS                 = `COLS                 ,
             KW_MAX               = `KW_MAX               ,
             WORD_WIDTH           = `Y_BITS       

)(
  input logic aclk, aresetn,

  input  logic s_valid, s_last,
  output logic s_ready,
  input  tuser_st s_user,
  input  logic [COLS   -1:0][ROWS -1:0][WORD_WIDTH-1:0] s_data,

  input  logic m_ready,
  output logic [ROWS -1:0][WORD_WIDTH  -1:0] m_data,
  output tuser_st m_user,
  output logic m_valid, m_last, m_last_pkt
);

  logic [COLS-1:0][ROWS -1:0][WORD_WIDTH-1:0] shift_data;
  logic [KW_MAX/2:0][COLS-1:0] lut_valid, lut_valid_last, lut_last_pkt, lut_last; 
  logic [COLS-1:0] shift_last, shift_last_pkt, shift_valid;

  genvar k2, c_1;
  for (k2=0; k2 <= KW_MAX/2; k2++)
    for (c_1=0; c_1 <  COLS; c_1++) begin
      localparam k = k2*2+1,  c = c_1 + 1;
      assign lut_valid      [k2][c_1] = (c % k == 0);
      assign lut_valid_last [k2][c_1] = ((c % k > k2) || (c % k == 0)) && (c <= (COLS/k)*k);
      assign lut_last       [k2][c_1] = (c == k);
      assign lut_last_pkt   [k2][c_1] = (c == k2+1);
    end

  wire valid_mask = !s_user.is_w_first_kw2 && !s_user.is_config;
  wire [COLS-1:0] s_valid_cols_sel = s_user.is_w_last ? lut_valid_last[s_user.kw2] : lut_valid[s_user.kw2];
  wire [COLS-1:0] s_last_cols_sel  = s_user.is_w_last ? lut_last_pkt  [s_user.kw2] : lut_last [s_user.kw2];


  logic [$clog2(COLS+1)-1:0] counter;
  enum {IDLE, SHIFT} state;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin 
      state   <= IDLE;
      s_ready <= 1;
      {shift_valid, shift_last_pkt, shift_last} <= '0;
    end else case (state)
      IDLE  : if (s_valid && valid_mask) begin 
                state   <= SHIFT;
                s_ready <= 0;

                shift_data  <= s_data;
                shift_valid <= s_valid_cols_sel & {COLS{valid_mask}};
                shift_last  <= s_last_cols_sel;
                shift_last_pkt <= {COLS{s_last}} & lut_last_pkt[s_user.kw2];
              end
      SHIFT : if (m_ready) begin

                shift_data  <= shift_data  << (ROWS * WORD_WIDTH);
                shift_valid <= shift_valid << 1;
                shift_last  <= shift_last  << 1;
                shift_last_pkt  <= shift_last_pkt  << 1;

                if (counter == 1) begin
                  state   <= IDLE;
                  s_ready <= 1;
                end
              end
    endcase    
  end

  always_ff @(posedge aclk or negedge aresetn)
    if      (!aresetn)                counter <= COLS;
    else if (state==SHIFT && m_ready) counter <= counter == 1 ? COLS : counter - 1;

  assign m_data   = shift_data [COLS-1];
  assign m_valid  = shift_valid[COLS-1];
  assign m_last   = shift_last [COLS-1];
  assign m_last_pkt = shift_last_pkt [COLS-1];

endmodule