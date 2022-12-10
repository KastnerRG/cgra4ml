// This was first written using classes: https://github.com/abarajithan11/dnn-engine/blob/1b7742d24c1ece4e47340f7402e51b54c6d087a3/rtl/tb/axis_tb.sv
// But iVerilog does not support {class, ref, break, rand}

`timescale 1ns/1ps

module AXIS_Sink #(
  parameter  WORD_WIDTH=8, BUS_WIDTH=8, PROB_READY=20, FILE_PATH="",
  parameter  WORDS_PER_BEAT = BUS_WIDTH/WORD_WIDTH
)(
    input  logic aclk, aresetn,
    output logic m_ready,
    input  logic m_valid, m_last,
    input  logic [WORDS_PER_BEAT-1:0][WORD_WIDTH-1:0] m_data, 
    input  logic [WORDS_PER_BEAT-1:0] m_keep
);

  int i_words = 0, file;

  task axis_pull;
    // clear the file
    file = $fopen(FILE_PATH, "w");
    $fclose(file);
    file = $fopen(FILE_PATH, "a");

    // start at reset
    m_ready = 0;
    wait(aresetn);
    
    while (1) begin

      @(posedge aclk)
      if (m_ready && m_valid) begin  // read at posedge

        file = $fopen(FILE_PATH, "a"); // open and close file in "a" on each beat
        if (file==0) 
          $fatal(1, "File '%s' does not exist\n", FILE_PATH);

        for (int i=0; i < WORDS_PER_BEAT; i=i+1)
          if (m_keep[i]) begin
            $fdisplay(file, "%d", $signed(m_data[i]));
            i_words  += 1;
          end
        $fclose(file);
      end

      #10ps // delay before writing
      m_ready = $urandom_range(0,99) < PROB_READY;

    end
  endtask
endmodule


module AXIS_Source #(
  parameter WORD_WIDTH=8, BUS_WIDTH=8, PROB_VALID=20, FILE_PATH="",
  parameter WORDS_PER_BEAT = BUS_WIDTH/WORD_WIDTH
)(
    input  logic aclk, aresetn, s_ready, 
    output logic s_valid, s_last,
    output logic [WORDS_PER_BEAT-1:0][WORD_WIDTH-1:0] s_data,
    output logic [WORDS_PER_BEAT-1:0] s_keep
); 

  logic s_last_val;
  logic [WORDS_PER_BEAT-1:0][WORD_WIDTH-1:0] s_data_val;
  logic [WORDS_PER_BEAT-1:0] s_keep_val;

  int status, i_words=0, file, val;
  logic prev_handshake=1; // data is released first
  logic prev_slast=0;

  task axis_push;
    {s_valid, s_data, s_last, s_keep} = '0;

    file = $fopen(FILE_PATH, "r");
    if (file == 0) 
      $fatal(1, "File '%s' does not exist\n", FILE_PATH);

    wait(aresetn); // wait for slave to begin
    
    // iverilog doesnt support break. so the loop is rolled to have break at top
    while (~prev_slast) begin    // loop goes from (aresetn & s_ready) to s_last
      if (prev_handshake) begin  // change data
        for (int i=0; i < WORDS_PER_BEAT; i++) begin
          if($feof(file)) begin
            $display(1, "EOF found at i_words=%d, path=%s \n", i_words, FILE_PATH); // If files ends in the middle of beat, fill rest with zeros
            s_data_val[i] = 0;
            s_keep_val[i] = 0;
          end
          else begin
            status = $fscanf(file,"%d\n", val);
            s_data_val[i] = val;
            s_keep_val[i] = 1;
            i_words  += 1;
          end
          s_last_val = $feof(file); // need to check one extra time to catch eof
        end
      end
      s_valid = $urandom_range(0,99) < PROB_VALID;      // randomize s_valid
      
      // scrable data signals on every cycle if !valid to catch slave reading it at wrong time
      s_data = s_valid ? s_data_val : '1;
      s_keep = s_valid ? s_keep_val : '1;
      s_last = s_valid ? s_last_val :  1;

      // -------------- LOOP BEGINS HERE -----------
      @(posedge aclk);
      prev_handshake = s_valid && s_ready; // read at posedge
      prev_slast     = s_valid && s_ready && s_last;
      
      #10ps; // Delay before writing s_valid, s_data, s_keep
    end

    // Reset & close packet after done
    {s_valid, s_data, s_keep, s_last} = '0;
    $display("Closing file '%s' at i_words=%d \n", FILE_PATH, i_words);
    $fclose(file);

  endtask
endmodule


module axis_tb;

  localparam WORD_W = 16, BUS_W=64, PROB_VALID=5, PROB_READY=20, NUM_DATA=((BUS_W/WORD_W)*101)/2;

  logic aclk=0, aresetn, i_ready, i_valid, i_last;
  logic [BUS_W/WORD_W-1:0][WORD_W-1:0] i_data;
  logic [BUS_W/WORD_W-1:0]             i_keep;
  int file_in, file_out, status, value;
  localparam file_path_in  = "axis_test_in.txt";
  localparam file_path_out = "axis_test_out.txt";

  initial forever #5 aclk = ~aclk;

  AXIS_Source #(.WORD_WIDTH(WORD_W), .BUS_WIDTH(BUS_W), .PROB_VALID(PROB_VALID), .FILE_PATH(file_path_in )) source (aclk, aresetn, i_ready, i_valid, i_last, i_data, i_keep);
  AXIS_Sink   #(.WORD_WIDTH(WORD_W), .BUS_WIDTH(BUS_W), .PROB_READY(PROB_READY), .FILE_PATH(file_path_out)) sink   (aclk, aresetn, i_ready, i_valid, i_last, i_data, i_keep);
  
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
    repeat(2) @(posedge aclk);
    aresetn = 1;

    while(!(i_valid && i_ready && i_last))
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