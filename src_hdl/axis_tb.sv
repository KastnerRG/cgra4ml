class AXIS_Slave #(WORD_WIDTH, WORDS_PER_BEAT, VALID_PROB);

  string file_path;
  int words_per_packet, file, status, iterations, i_words;
  int i_itr = 0;
  bit enable = 0;
  bit first_beat = 1;

  rand bit s_valid;
  constraint c { s_valid dist { 0 := (100-VALID_PROB), 1 := (VALID_PROB)}; };

  function new(string file_path, int words_per_packet, int iterations);
    this.file_path = file_path;
    this.words_per_packet = words_per_packet;
    this.iterations = iterations;

    file = $fopen(file_path, "r");
  endfunction

  function void fill_beat(
    ref logic [WORD_WIDTH    -1:0] s_data [WORDS_PER_BEAT-1:0], 
    ref logic [WORDS_PER_BEAT-1:0] s_keep,
    ref logic s_last);

    if($feof(file)) $fatal("EOF found at i_words=%d, i_itr=%d; path=%s \n",i_words,i_itr,file_path);

    for (int i=0; i < WORDS_PER_BEAT; i++) begin
      status = $fscanf(file,"%d\n", s_data[i]);
      s_keep[i] = i_words < words_per_packet;
      i_words  += 1;
    end
    if(i_words >= words_per_packet) begin
      s_last = 1;
    end
  endfunction

  function void reset(
    ref logic s_ready,
    ref logic s_valid,
    ref logic [WORD_WIDTH    -1:0] s_data [WORDS_PER_BEAT-1:0], 
    ref logic [WORDS_PER_BEAT-1:0] s_keep,
    ref logic s_last
  );
    enable = 0;
    s_data = '{default:0};
    s_valid = 0;
    s_keep = 0;
    s_last = 0;
    first_beat = 1;
    i_words = 0;
  endfunction

  task axis_feed(
    ref logic aclk,
    ref logic s_ready,
    ref logic s_valid,
    ref logic [WORD_WIDTH    -1:0] s_data [WORDS_PER_BEAT-1:0], 
    ref logic [WORDS_PER_BEAT-1:0] s_keep,
    ref logic s_last
  );
    @(posedge aclk);
    this.randomize(); // random this.s_valid at every cycle

    // Start: set all signals zero
    if (~enable) begin
      this.reset(s_ready, s_valid, s_data, s_keep, s_last);

      if (s_ready && i_itr > 0 && i_itr < iterations) begin
        enable = 1;
        file = $fopen(file_path, "r");
      end
      return;
    end
    
    /*
      First beat:
        - We check this.svalid (randomized but unassigned) & previous s_ready (wire)
        - ensures transaction starts at a random clock cycle
        - we remove the first_beat flag
      Other beats:
        - We check previous s_valid (wire) & previous s_ready (wire)
        - Both high means transaction gone through. We change the data
    */
    if (s_ready && (first_beat ? this.s_valid : s_valid)) begin

      if(s_last) begin
        i_itr = i_itr + 1;
        this.reset(s_ready, s_valid, s_data, s_keep, s_last);
        return;
      end

      #1;
      this.fill_beat(s_data, s_keep, s_last);
      if (first_beat) first_beat = 0;
    end
    
    /*
      Randomized valid is not assigned to the wire until we fill the first beat
        - else, as this.s_valid and s_ready (wire -> previous) are out of sync, 
          they can both get high and will be mistaken as transaction.
      First beat flag down => transaction has started. 
      Now is either first beat or following beats.
    */
    if (~first_beat) s_valid = this.s_valid;

  endtask
endclass


class AXIS_Master #(WORD_WIDTH, WORDS_PER_BEAT, READY_PROB, CLK_PERIOD);
  string file_base, file_path, s_itr;
  int file, status;
  int i_itr = 0;
  int i_words = 0;
  bit enable = 0;

  rand bit m_ready;
  constraint c { m_ready dist { 0 := (100-READY_PROB), 1 := (READY_PROB)}; };

  function new(string file_base);
    this.file_base = file_base;
    open_file();
  endfunction

  function void open_file();
    s_itr.itoa(i_itr);
    file_path = {file_base, s_itr, ".txt"};
    $display(file_path);
    file = $fopen(file_path, "w");
  endfunction

  function void read_beat(
    ref logic [WORD_WIDTH    -1:0] m_data [WORDS_PER_BEAT-1:0], 
    ref logic [WORDS_PER_BEAT-1:0] m_keep,
    ref logic m_last);

    for (int i=0; i < WORDS_PER_BEAT; i++)
      if (m_keep[i]) begin
        $fdisplay(file, "%d", signed'(m_data[i]));
        i_words  += 1;
      end

    if(m_last) begin
      $fclose(file);
      i_itr += 1;
      enable = 0;
    end
  endfunction

  task axis_read(
    ref logic aclk,
    ref logic m_ready,
    ref logic m_valid,
    ref logic [WORD_WIDTH    -1:0] m_data [WORDS_PER_BEAT-1:0], 
    ref logic [WORDS_PER_BEAT-1:0] m_keep,
    ref logic m_last
  );
    @(posedge aclk);
    this.randomize(); // random this.m_ready at every cycle
    #1;
    m_ready = this.m_ready;

    #(CLK_PERIOD/2); // read at the middlle
    
    if (~enable && m_valid) begin // reset and open new file if only m_valid
      i_words = 0;
      enable = 1;
      open_file();
    end
    
    if (m_ready && m_valid) 
      this.read_beat(m_data, m_keep, m_last);

  endtask
endclass