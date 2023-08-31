// This was first written using classes: https://github.com/abarajithan11/dnn-engine/blob/1b7742d24c1ece4e47340f7402e51b54c6d087a3/rtl/tb/axis_tb.sv
// But iVerilog does not support {class, ref, break, rand}

`timescale 1ns/1ps

module AXIS_M2S #(
  parameter WORD_WIDTH=8, BUS_WIDTH=8, PROB_VALID=20,
  parameter MEM_DEPTH=1,
  parameter WORDS_PER_BEAT = BUS_WIDTH/WORD_WIDTH
)(
    input  logic aclk, aresetn, s_ready, 
    output logic s_valid, s_last,
    output logic [WORDS_PER_BEAT-1:0][WORD_WIDTH-1:0] s_data,
    output logic [WORDS_PER_BEAT-1:0] s_keep,
    ref    bit   [0:MEM_DEPTH-1][WORD_WIDTH-1:0] memory
); 

  logic s_last_val;
  logic [WORDS_PER_BEAT-1:0][WORD_WIDTH-1:0] s_data_val;
  logic [WORDS_PER_BEAT-1:0] s_keep_val;

  int status, i_words=0;
  bit prev_handshake=1; // data is released first
  bit prev_slast=0;

  task axis_push (input int START_ADDR, input int N_WORDS);
    {s_valid, s_data, s_last, s_keep} = '0;

    wait(aresetn); // wait for slave to begin
    
    // iverilog doesnt support break. so the loop is rolled to have break at top
    while (~prev_slast) begin    // loop goes from (aresetn & s_ready) to s_last
      if (prev_handshake) begin  // change data
        for (int i=0; i < WORDS_PER_BEAT; i++) begin
          if(i_words >= N_WORDS) begin
            $display(1, "finished at i_words=%d\n", i_words); // End, fill rest with zeros
            s_data_val[i] = 0;
            s_keep_val[i] = 0;
          end
          else begin
            s_data_val[i] = memory[START_ADDR + i_words];
            // $display("DMA: start:%d, i_words:%d, val:%d", START_ADDR, i_words, $signed(s_data_val[i]));
            s_keep_val[i] = 1;
            i_words  += 1;
          end
          s_last_val = i_words >= N_WORDS;
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
    {s_valid, s_data, s_keep, s_last, prev_slast, i_words} = '0;
    prev_handshake = 1;
    @(posedge aclk);
  endtask
endmodule