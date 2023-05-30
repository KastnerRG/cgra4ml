`timescale 1ns/1ps

module skid_buffer #( parameter WIDTH = 8)(
  input  logic aclk, aresetn, s_valid, m_ready,
  input  logic [WIDTH-1:0] s_data,
  output logic [WIDTH-1:0] m_data,
  output logic m_valid, s_ready
);
  enum {FULL, EMPTY} state, state_next;
  always_comb begin
    state_next = state;
    case (state)
      EMPTY : if(!m_ready && s_ready && s_valid) state_next = FULL;
      FULL  : if(m_ready)                        state_next = EMPTY;
    endcase
  end
  always_ff @(posedge aclk)
    if      (!aresetn)              state <= EMPTY;
    else if (m_ready || s_ready) state <= state_next;

  logic b_valid;
  logic [WIDTH-1:0] b_data;
  wire  [WIDTH-1:0] m_data_next  = (state      == FULL) ? b_data  : s_data;
  wire              m_valid_next = (state      == FULL) ? b_valid : s_valid;
  wire              buffer_en    = (state_next == FULL) && (state==EMPTY);
  wire              m_en         = m_valid_next & m_ready;

  always_ff @(posedge aclk)
    if (!aresetn) begin
      s_ready <= 1;
      {m_valid, b_valid} <= '0;
    end else begin
      s_ready <= state_next == EMPTY;
      if (buffer_en) b_valid <= s_valid;      
      if (m_ready  ) m_valid <= m_valid_next;
    end
    
  always_ff @(posedge aclk) begin
    if (m_en)                 m_data <= m_data_next;
    if (buffer_en && s_valid) b_data <= s_data;
  end
endmodule


module axis_pipeline_register #(
    parameter WIDTH = 8,
              DEPTH = 2
)(
    input  logic aclk,
    input  logic aresetn,
    input  logic [WIDTH-1:0] s_data,
    input  logic             s_valid,
    output logic             s_ready,
    output logic [WIDTH-1:0] m_data,
    output logic             m_valid,
    input  logic             m_ready
);

wire [WIDTH-1:0] i_data  [0:DEPTH];
wire             i_valid [0:DEPTH];
wire             i_ready [0:DEPTH];

assign i_data [0] = s_data;
assign i_valid[0] = s_valid;
assign s_ready = i_ready[0];

assign m_data  = i_data [DEPTH];
assign m_valid = i_valid[DEPTH];
assign i_ready[DEPTH] = m_ready;

generate
    genvar i;
    for (i = 0; i < DEPTH; i = i + 1) begin : pipe_reg
        skid_buffer #(.WIDTH(WIDTH))
        reg_inst (
            .aclk   (aclk),
            .aresetn(aresetn),
            .s_data (i_data [i]),
            .s_valid(i_valid[i]),
            .s_ready(i_ready[i]),
            .m_data (i_data [i+1]),
            .m_valid(i_valid[i+1]),
            .m_ready(i_ready[i+1])
        );
    end
endgenerate

endmodule
