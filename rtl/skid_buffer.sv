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

module skid_buffer_tb;

  localparam WORD_W=32, BUS_W=WORD_W, PROB_VALID=100, PROB_READY=70, NUM_DATA=((BUS_W/WORD_W)*200);

  logic aclk=0, aresetn;
  logic s_ready, s_valid, s_last;
  logic [BUS_W/WORD_W-1:0][WORD_W-1:0] s_data;
  logic [BUS_W/WORD_W-1:0]             s_keep;

  logic m_ready, m_valid, m_last;
  logic [BUS_W/WORD_W-1:0][WORD_W-1:0] m_data;
  logic [BUS_W/WORD_W-1:0]             m_keep;
  int file_in, file_out, status, value;
  localparam file_path_in  = "D:/axis_reg_in.txt";
  localparam file_path_out = "D:/axis_reg_out.txt";

  axis_pipeline_register #(BUS_W + BUS_W/WORD_W + 1, 3) dut (
    .s_data ({s_data, s_keep, s_last}),
    .m_data ({m_data, m_keep, m_last}),
    .*
  );

  initial forever #5 aclk = ~aclk;

 AXIS_Source #(.WORD_WIDTH(WORD_W), .BUS_WIDTH(BUS_W), .PROB_VALID(PROB_VALID), .FILE_PATH(file_path_in )) source (aclk, aresetn, s_ready, s_valid, s_last, s_data, s_keep);
 AXIS_Sink   #(.WORD_WIDTH(WORD_W), .BUS_WIDTH(BUS_W), .PROB_READY(PROB_READY), .FILE_PATH(file_path_out)) sink   (aclk, aresetn, m_ready, m_valid, m_last, m_data, m_keep);
  
  initial sink.axis_pull;
  initial begin
    file_in = $fopen(file_path_in, "w");
    for (int i=0; i<NUM_DATA; i++)
      $fdisplay(file_in, "%d", i);
    $fclose(file_in);
    source.axis_push;
  end


  initial begin
    $dumpfile ("axis_tb.vcd"); $dumpvars;

    aresetn = 0;
    repeat (5) @(posedge aclk); 
    aresetn = 1;


    while(!(m_valid && m_ready && m_last))
      @(posedge aclk);

    @(posedge aclk);

    file_out = $fopen(file_path_out, "r");
    for (int i=0; i<NUM_DATA; i++) begin
      status = $fscanf(file_out,"%d\n", value);
      assert (value == i) else $error("Output does not match");
    end

    $finish();
  end

endmodule