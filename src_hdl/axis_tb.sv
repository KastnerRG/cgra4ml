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
    // Before beginning: set all signals zero
    if (~enable) begin
      this.reset(s_valid, s_data, s_keep, s_last);
      @(posedge aclk);
      return;
    end

    @(posedge aclk);
    this.randomize(); // random this.s_valid at every cycle
    
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
      /*
        If s_last has passed with a handshake, packet done. start next itr
      */
      if(s_last) begin #1;

        $fclose(file);
        i_itr = i_itr + 1;
        this.reset(s_valid, s_data, s_keep, s_last);

        if (i_itr < iterations) begin
          enable = 1;
          file = $fopen(file_path, "r");
        end
        else return;
      end
      else #1;

      this.fill_beat(s_data, s_keep, s_last);
      if (first_beat) first_beat = 0;
    end
    else #1;
    
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


class AXIS_Master #(WORD_WIDTH, WORDS_PER_BEAT, READY_PROB, CLK_PERIOD, IS_ACTIVE=1);
  string file_base, file_path, s_itr;
  int file, status, words_per_packet, packets_per_file;
  int i_itr = 0;
  int i_words = 0;
  int i_packets = 0;
  bit enable = 0;

  rand bit m_ready;
  constraint c { m_ready dist { 0 := (100-READY_PROB), 1 := (READY_PROB)}; };

  function new(string file_base, int words_per_packet=-1, int packets_per_file=1);
  /*
    If (words_per_packet = -1), file is closed and reopened at tlast
    Else, at words_per_packet
  */
    this.words_per_packet = words_per_packet;
    this.file_base = file_base;
    this.packets_per_file = packets_per_file;
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

    if(words_per_packet == -1 ? m_last : i_words >= words_per_packet) begin

      i_words = 0;
      i_packets += 1;

      if (i_packets >= packets_per_file) begin
        $fclose(file);
        i_itr += 1;
        enable = 0;
        i_packets = 0;
      end
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
    #1;
    if (IS_ACTIVE) begin
      this.randomize(); // random this.m_ready at every cycle
      m_ready = this.m_ready;
    end

    #(CLK_PERIOD/2); // read at the middlle
    
    if (~enable && m_valid) begin // reset and open new file if only m_valid
      enable = 1;
      open_file();
    end
    
    if (m_ready && m_valid) 
      this.read_beat(m_data, m_keep, m_last);

  endtask
endclass

module axis_tb_demo();

  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  localparam WORD_WIDTH        = 8;
  localparam WORDS_PER_PACKET  = 40;
  localparam WORDS_PER_BEAT    = 4;
  localparam ITERATIONS        = 6;
  localparam BEATS             = int'($ceil(real'(WORDS_PER_PACKET)/real'(WORDS_PER_BEAT)));

  logic [WORD_WIDTH      -1:0] data [WORDS_PER_BEAT-1:0];
  logic [WORDS_PER_BEAT  -1:0] keep;
  logic valid, ready, last;

  string path = "D:/cnn-fpga/data/axis_test.txt";
  string out_base = "D:/cnn-fpga/data/axis_test_out_";


  AXIS_Slave #(
    .WORD_WIDTH    (WORD_WIDTH    ), 
    .WORDS_PER_BEAT(WORDS_PER_BEAT), 
    .VALID_PROB    (70            )
    ) slave_obj  = new(
      .file_path       (path), 
      .words_per_packet(WORDS_PER_PACKET), 
      .iterations      (ITERATIONS)
      );
  AXIS_Master #(
    .WORD_WIDTH    (WORD_WIDTH    ), 
    .WORDS_PER_BEAT(WORDS_PER_BEAT), 
    .READY_PROB    (70            ), 
    .CLK_PERIOD    (CLK_PERIOD    ),
    .IS_ACTIVE     (1             )
    ) master_obj = new(
      .file_base(out_base),
      .words_per_packet(-1),
      .packets_per_file(2)
      );

  // assign ready = 1;
  // logic m_last = 0;
  initial forever  slave_obj.axis_feed(aclk, ready, valid, data, keep, last);
  initial forever master_obj.axis_read(aclk, ready, valid, data, keep, last);

  initial begin
    @(posedge aclk);
    slave_obj.enable <= 1;
    master_obj.enable <= 1;
  end

  int s_words, s_itr, m_words, m_itr, m_packets, m_packets_per_file;

  initial begin
    forever begin
      @(posedge aclk);
      s_words = slave_obj.i_words;
      s_itr = slave_obj.i_itr;
      m_words = master_obj.i_words;
      m_itr = master_obj.i_itr;
      m_packets = master_obj.i_packets;
      m_packets_per_file = master_obj.packets_per_file;
    end
  end

endmodule
