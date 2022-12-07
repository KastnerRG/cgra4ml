`timescale 1ns/1ps

class AXIS_Sink #(WORD_WIDTH=8, BUS_WIDTH=8, READY_PROB=100);

  localparam WORDS_PER_BEAT = BUS_WIDTH/WORD_WIDTH;
  string file_path;
  int status, file, i_words = 0;
  rand bit random;
  constraint c { random dist { 0 := (100-READY_PROB), 1 := (READY_PROB)}; };

  function new(string file_path);
    this.file_path = file_path;
    file = $fopen(file_path, "w"); // Open and close in "w" to initialize empty file
    $fclose(file);
  endfunction

  task axis_pull(
    ref logic aclk, aresetn, m_ready, m_valid, m_last,
    ref logic [WORDS_PER_BEAT-1:0][WORD_WIDTH-1:0] m_data, 
    ref logic [WORDS_PER_BEAT-1:0] m_keep
  );
    m_ready = 0;
    wait(aresetn);
    
    while (1) begin

      @(posedge aclk)
      if (m_ready && m_valid) begin  // read at posedge

        file = $fopen(file_path, "a"); // open and close file in "a" on each beat
        if (file==0) 
          $fatal(1, "File '%s' does not exist\n", file_path);

        for (int i=0; i < WORDS_PER_BEAT; i=i+1)
          if (m_keep[i]) begin
            $fdisplay(file, "%d", signed'(m_data[i]));
            i_words  += 1;
          end
        $fclose(file);
      end

      #1 // delay before writing
      this.randomize(); // random m_ready at every cycle
      m_ready = random;

    end
  endtask
endclass



class AXIS_Source #(WORD_WIDTH=8, BUS_WIDTH=8, VALID_PROB=100);

  localparam WORDS_PER_BEAT = BUS_WIDTH/WORD_WIDTH;
  string file_path;
  int status, i_words=0, file=0;
  logic prev_handshake, prev_slast;

  rand bit random;
  constraint c { random dist { 0 := (100-VALID_PROB), 1 := (VALID_PROB)}; };

  function new(string file_path);
    this.file_path = file_path;
    this.file = $fopen(this.file_path, "r");
    if (this.file == 0) $fatal(1, "File '%s' does not exist\n", file_path);
  endfunction


  task axis_push(
    ref logic aclk, aresetn, s_ready, s_valid, s_last,
    ref logic [WORDS_PER_BEAT-1:0][WORD_WIDTH-1:0] s_data,
    ref logic [WORDS_PER_BEAT-1:0] s_keep
  );
    {s_valid, s_data, s_last, s_keep} = '0;

    wait(aresetn & s_ready); // wait for slave to begin

    while (1) begin          // loop goes from (aresetn & s_ready) to s_last

      @(posedge aclk);
      prev_handshake = s_valid && s_ready; // read at posedge
      prev_slast     = s_valid && s_ready && s_last;
      
      #1 // Delay before writing s_valid, s_data, s_keep
      
      if (prev_slast) begin
        // Reset & close packet after done
        {s_valid, s_data, s_keep, s_last} = '0;
        $display("Closing file '%s' at i_words=%d \n", file_path, i_words);
        $fclose(file);
        return;
      end

      if (prev_handshake) begin  // change data
        for (int i=0; i < WORDS_PER_BEAT; i++) begin
          if($feof(file)) begin
            $display(1, "EOF found at i_words=%d, path=%s \n", i_words, file_path); // If files ends in the middle of beat, fill rest with zeros
            s_data[i] = 0;
            s_keep[i] = 0;
          end
          else begin
            status = $fscanf(file,"%d\n", s_data[i]);
            s_keep[i] = 1;
            i_words  += 1;
          end
          s_last = $feof(file); // need to check one extra time to catch eof
        end
      end

      this.randomize();
      s_valid = random;      // randomize s_valid
    end
  endtask
endclass


module axis_tb;

  localparam WORD_W = 16, BUS_W=64, VALID_PROB=20, READY_PROB=20, NUM_DATA = ((BUS_W/WORD_W)*101)/2;
  logic aclk=0, aresetn, i_ready, i_valid, i_last;
  logic [BUS_W/WORD_W-1:0][WORD_W-1:0] i_data;
  logic [BUS_W/WORD_W-1:0]             i_keep;
  int file_in, file_out, status, value;
  string file_path_in  = "D:/axis_test_in.txt";
  string file_path_out = "D:/axis_test_out.txt";


  AXIS_Source #(WORD_W, BUS_W , VALID_PROB) source = new(file_path_in );
  AXIS_Sink   #(WORD_W, BUS_W , READY_PROB) sink   = new(file_path_out);
  
  initial forever #5 aclk = ~aclk;
  initial sink  .axis_pull(aclk, aresetn, i_ready, i_valid, i_last, i_data, i_keep);
  initial begin
    file_in = $fopen(file_path_in, "w");
    for (int i=0; i<NUM_DATA; i++)
      $fdisplay(file_in, "%d", i);
    $fclose(file_in);
    source.axis_push(aclk, aresetn, i_ready, i_valid, i_last, i_data, i_keep);
  end


  initial begin
    aresetn = 0;
    repeat(2) @(posedge aclk)
    aresetn = 1;

    @(negedge i_last) 
    @(posedge aclk)

    file_out = $fopen(file_path_out, "r");
    for (int i=0; i<NUM_DATA; i++) begin
      status = $fscanf(file_out,"%d\n", value);
      assert (value == i) else $error("Output does not match");
    end

    $finish();
  end

endmodule