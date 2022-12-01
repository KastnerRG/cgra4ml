class AXIS_Sink #(WORD_WIDTH=8, WORDS_PER_BEAT=1, READY_PROB=100, CLK_PERIOD=10);

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
    
    while (1) begin
      @(posedge aclk) #1
      if (~aresetn) continue;
      this.randomize(); // random m_ready at every cycle
      m_ready = random;

      if (m_ready && m_valid) begin

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
    end
  endtask
endclass



class AXIS_Source #(WORD_WIDTH=8, WORDS_PER_BEAT=1, VALID_PROB=100);

  string file_path;
  int status, i_words=0, file=0;

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
      wait(s_ready);         // hold (data, valid, last) until slave accepts
      if (s_last) break;     // If s_last has been accepted, packet done.
      
      #1                     // Delay before writing
      this.randomize();
      s_valid = random;      // randomize s_valid

      if (s_valid) begin     // push data if s_valid
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
      @(posedge aclk); // give a clock for data to be accepted
      // no logic beyond here. s_valid is new. loop back, wait for s_ready (slave to accept)
    end

    // Reset & close packet after done
    {s_valid, s_data, s_keep, s_last} = '0;
    $display("Closing file '%s' at i_words=%d \n", file_path, i_words);
    $fclose(file);

  endtask
endclass