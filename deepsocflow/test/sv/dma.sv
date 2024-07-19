// This was first written using classes: https://github.com/abarajithan11/dnn-engine/blob/1b7742d24c1ece4e47340f7402e51b54c6d087a3/rtl/tb/axis_tb.sv
// But iVerilog does not support {class, ref, break, rand}

`timescale 1ns/1ps

module DMA_M2S #(
  parameter BUS_WIDTH=8, PROB_VALID=20,
  parameter BYTES_PER_BEAT = BUS_WIDTH/8
)(
    input  logic aclk, aresetn, s_ready, 
    output logic s_valid, s_last,
    output logic [BYTES_PER_BEAT-1:0][7:0] s_data,
    output logic [BYTES_PER_BEAT-1:0] s_keep
); 

  logic s_last_val;
  logic [BYTES_PER_BEAT-1:0][7:0] s_data_val;
  logic [BYTES_PER_BEAT-1:0] s_keep_val;

  int status;
  longint unsigned i_bytes=0;
  bit prev_handshake=1; // data is released first
  bit prev_slast=0;

  import "DPI-C" function byte get_byte (longint unsigned addr);

  task axis_push (input longint unsigned base_addr, input int bytes_per_transfer);
    {s_valid, s_data, s_last, s_keep} = '0;

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
            // $display("DMA: start:%d, i_bytes:%d, val:%d", offset, i_bytes, $signed(s_data_val[i]));
            s_keep_val[i] = 1;
            i_bytes  += 1;
          end
          s_last_val = i_bytes >= 64'(bytes_per_transfer);
        end
      end
      s_valid = $urandom_range(0,999) < PROB_VALID;      // randomize s_valid
      
      // scrable data signals on every cycle if !valid to catch slave reading it at wrong time
      s_data = s_valid ? s_data_val : 'x;
      s_keep = s_valid ? s_keep_val : 'x;
      s_last = s_valid ? s_last_val : 'x;

      // -------------- LOOP BEGINS HERE -----------
      @(posedge aclk);
      prev_handshake = s_valid && s_ready; // read at posedge
      prev_slast     = s_valid && s_ready && s_last;
      
      #10ps; // Delay before writing s_valid, s_data, s_keep
    end

    // Reset & close packet after done
    {s_valid, s_data, s_keep, s_last, prev_slast, i_bytes} = '0;
    prev_handshake = 1;
    @(posedge aclk);
  endtask
endmodule


module DMA_S2M #(
  parameter  BUS_WIDTH=8, PROB_READY=20,
  parameter  BYTES_PER_BEAT = BUS_WIDTH/8
)(
    input  logic aclk, aresetn,
    output logic m_ready,
    input  logic m_valid, m_last,
    input  logic [BYTES_PER_BEAT-1:0][7:0] m_data, 
    input  logic [BYTES_PER_BEAT-1:0] m_keep,
    input  logic [31:0] hw_bpt
);

  longint unsigned i_bytes = 0;
  bit done = 0;

  import "DPI-C" function void set_byte (longint unsigned addr, byte data);

  task axis_pull (input longint unsigned base_addr, input int bytes_per_transfer);
    m_ready = 0;
    wait(aresetn);
    
    while (!done) begin

      @(posedge aclk)
      if (m_ready && m_valid) begin  // read at posedge
        // assert (bytes_per_transfer == hw_bpt) else $display("Error: bytes_per_transfer=%d, hw_bpt=%d", bytes_per_transfer, hw_bpt);
        for (int i=0; i < BYTES_PER_BEAT; i=i+1)
          if (m_keep[i]) begin
            set_byte(base_addr + i_bytes, m_data[i]);
            i_bytes  += 1;
          end
        if (m_last) done = 1;
      end

      #10ps // delay before writing
      m_ready = $urandom_range(0,999) < PROB_READY;
    end

    {done, i_bytes} = 0;
  endtask
endmodule