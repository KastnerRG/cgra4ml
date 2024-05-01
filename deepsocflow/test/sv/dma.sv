// This was first written using classes: https://github.com/abarajithan11/dnn-engine/blob/1b7742d24c1ece4e47340f7402e51b54c6d087a3/rtl/tb/axis_tb.sv
// But iVerilog does not support {class, ref, break, rand}

`timescale 1ns/1ps
`include "config_tb.svh"

module DMA_M2S #(
  parameter BUS_WIDTH=8, PROB_VALID=20,
  parameter BYTES_PER_BEAT = BUS_WIDTH/8
)(
    input  logic aclk, aresetn, s_ready, 
    output logic s_valid='0, s_last='0,
    output logic [BYTES_PER_BEAT-1:0][7:0] s_data='0,
    output logic [BYTES_PER_BEAT-1:0] s_keep='0
); 

  clocking cs @(posedge aclk);
    default input #(`INPUT_DELAY_NS) output #(`OUTPUT_DELAY_NS);
    input  s_ready;
    output s_valid, s_last, s_data, s_keep;
  endclocking

  logic s_last_val;
  logic [BYTES_PER_BEAT-1:0][7:0] s_data_val;
  logic [BYTES_PER_BEAT-1:0] s_keep_val;

  int status;
  longint unsigned i_bytes=0;
  bit prev_handshake=1; // data is released first
  bit prev_slast=0, is_valid;

  import "DPI-C" function byte get_byte (longint unsigned addr);

  task axis_push (input longint unsigned base_addr, input int bytes_per_transfer);
    {cs.s_valid, cs.s_data, cs.s_last, cs.s_keep} <= '0;

    wait(aresetn); // wait for slave to begin
    
    // iverilog doesnt support break. so the loop is rolled to have break at top
    while (~prev_slast) begin    // loop goes from (aresetn & s_ready) to s_last
      if (prev_handshake) begin  // change data
        for (int i=0; i < BYTES_PER_BEAT; i++) begin
          if(i_bytes >= 64'(bytes_per_transfer)) begin
            s_data_val[i] = 0;
            s_keep_val[i] = 0;
          end
          else begin
            s_data_val[i] = get_byte(base_addr + i_bytes);
            s_keep_val[i] = 1;
            i_bytes  += 1;
          end
          s_last_val = i_bytes >= 64'(bytes_per_transfer);
        end
      end
      is_valid = $urandom_range(0,999) < PROB_VALID;
      cs.s_valid <= is_valid;       // randomize s_valid
      
      // scramble data signals on every cycle if !valid to catch slave reading it at wrong time
      cs.s_data <= is_valid ? s_data_val : '1;
      cs.s_keep <= is_valid ? s_keep_val : '1;
      cs.s_last <= is_valid ? s_last_val : '1;

      // -------------- LOOP BEGINS HERE -----------
      @(cs);
      prev_handshake = s_valid && cs.s_ready; // read at posedge
      prev_slast     = s_valid && cs.s_ready && s_last;
      
      // #10ps; // Delay before writing s_valid, s_data, s_keep
    end

    // Reset & close packet after done
    {cs.s_valid, cs.s_data, cs.s_keep, cs.s_last} <= '0;
    {prev_slast, i_bytes} <= '0;
    prev_handshake = 1;
    @(cs);
  endtask
endmodule


module DMA_S2M #(
  parameter  BUS_WIDTH=8, PROB_READY=20,
  parameter  BYTES_PER_BEAT = BUS_WIDTH/8
)(
    input  logic aclk, aresetn,
    output logic m_ready='0,
    input  logic m_valid, m_last,
    input  logic [BYTES_PER_BEAT-1:0][7:0] m_data, 
    input  logic [BYTES_PER_BEAT-1:0] m_keep,
    input  logic [31:0] hw_bpt
);

  clocking cb @(posedge aclk);
    default input #(`INPUT_DELAY_NS) output #(`OUTPUT_DELAY_NS);
    output m_ready;
    input  m_valid, m_last, m_data, m_keep;
  endclocking

  longint unsigned i_bytes = 0;
  bit done = 0;

  import "DPI-C" function void set_byte (longint unsigned addr, byte data);

  task axis_pull (input longint unsigned base_addr, input int bytes_per_transfer);
    cb.m_ready <= 0;
    wait(aresetn);
    
    while (!done) begin

      @(cb);
      if (m_ready && cb.m_valid) begin  // read at posedge
        assert (bytes_per_transfer == hw_bpt) else $display("Error: bytes_per_transfer=%d, hw_bpt=%d", bytes_per_transfer, hw_bpt);
        for (int i=0; i < BYTES_PER_BEAT; i=i+1)
          if (cb.m_keep[i]) begin
            set_byte(base_addr + i_bytes, cb.m_data[i]);
            i_bytes  += 1;
          end
        if (cb.m_last) done = 1;
      end

      // #10ps // delay before writing
      cb.m_ready <= $urandom_range(0,999) < PROB_READY;
    end

    {done, i_bytes} = 0;
  endtask
endmodule