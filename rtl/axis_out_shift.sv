`include "../params/params.sv"

module axis_out_shift #(
  localparam ROWS                 = `ROWS                 ,
             COLS                 = `COLS                 ,
             BITS_KW              = `BITS_KW              ,
             BITS_KW2             = `BITS_KW2             ,
             WORD_WIDTH           = `WORD_WIDTH_ACC       

)(
  input logic aclk, aresetn,

  input  logic s_valid, s_last,
  output logic s_ready,
  input  tuser_st s_user,
  input  logic [COLS   -1:0][ROWS -1:0][WORD_WIDTH-1:0] s_data,

  input  logic m_ready,
  output logic [ROWS -1:0][WORD_WIDTH  -1:0] m_data,
  output tuser_st m_user,
  output logic m_valid, m_last
);

  logic [COLS-1:0][ROWS -1:0][WORD_WIDTH-1:0] data;
  logic last, last_kw;
  logic [BITS_KW:0] kw;

  logic [$clog2(COLS+1)-1:0] counter;
  enum {IDLE, SHIFT} state;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin 
      state   <= IDLE;
      s_ready <= 1;
    end else case (state)
      IDLE  : if (s_valid) begin 
                state   <= SHIFT;
                data    <= s_data;
                last    <= s_last;
                kw      <= 2*s_user.kw2 + 1;
                s_ready <= 0;
              end
      SHIFT : if (m_ready) begin
                data    <= data << (ROWS * WORD_WIDTH);
                if (counter == 1) begin
                  state   <= IDLE;
                  s_ready <= 1;
                  last    <= 0;
                end
              end
    endcase    
  end

  always_ff @(posedge aclk or negedge aresetn)
    if      (!aresetn)                counter <= COLS;
    else if (state==SHIFT && m_ready) counter <= counter == 1 ? COLS : counter - 1;

  assign m_data  = data[COLS-1];
  assign last_kw = last &&  ((COLS-(COLS+1-counter)) < kw);
  assign m_valid = state == SHIFT && (counter % kw == 0 || (last && (counter % kw > kw/2)));
  assign m_last  = m_valid && last_kw && (counter == kw/2+1);

endmodule