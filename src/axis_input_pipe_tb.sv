module axis_input_pipe_tb ();
  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  localparam UNITS        = 3;
  localparam WORD_WIDTH   = 8; 
  localparam KERNEL_H_MAX = 3;   // odd number
  localparam BITS_KERNEL_H_MAX = $clog2(KERNEL_H_MAX);

  localparam BEATS_CONFIG_3X3_1  = 21-1;
  localparam BEATS_CONFIG_1X1_1  = 13-1;

  localparam UNITS_EDGES  = UNITS + KERNEL_H_MAX-1;
  localparam IM_IN_S_DATA_WORDS = 2**$clog2(UNITS_EDGES);

  localparam TUSER_WIDTH_IM_IN = BITS_KERNEL_H_MAX;
  localparam TKEEP_WIDTH_IM_IN = (WORD_WIDTH*IM_IN_S_DATA_WORDS)/8;

  localparam BITS_OTHER         = 8;
  localparam I_IM_IN_IS_MAXPOOL = 0;
  localparam I_IM_IN_KERNEL_H_1 = I_IM_IN_IS_MAXPOOL + BITS_OTHER + 0;

  logic aresetn;
  logic s_axis_pixels_1_tready;
  logic s_axis_pixels_1_tvalid;
  logic s_axis_pixels_1_tlast ;
  logic [WORD_WIDTH*IM_IN_S_DATA_WORDS    -1:0] s_axis_pixels_1_tdata;
  logic [TKEEP_WIDTH_IM_IN-1:0] s_axis_pixels_1_tkeep;

  logic s_axis_pixels_2_tready;
  logic s_axis_pixels_2_tvalid;
  logic s_axis_pixels_2_tlast ;
  logic [WORD_WIDTH*IM_IN_S_DATA_WORDS    -1:0] s_axis_pixels_2_tdata;
  logic [TKEEP_WIDTH_IM_IN-1:0] s_axis_pixels_2_tkeep;

  logic m_axis_tready;
  logic m_axis_tvalid;
  logic [WORD_WIDTH*UNITS -1:0] m_axis_pixels_1_tdata;
  logic [WORD_WIDTH*UNITS -1:0] m_axis_pixels_2_tdata;

  axis_input_pipe #(
    .UNITS              (UNITS             ),
    .WORD_WIDTH         (WORD_WIDTH        ),
    .KERNEL_H_MAX       (KERNEL_H_MAX      ),
    .BEATS_CONFIG_3X3_1 (BEATS_CONFIG_3X3_1),
    .BEATS_CONFIG_1X1_1 (BEATS_CONFIG_1X1_1),
    .BITS_OTHER         (BITS_OTHER        ),
    .I_IM_IN_IS_MAXPOOL (I_IM_IN_IS_MAXPOOL),
    .I_IM_IN_KERNEL_H_1 (I_IM_IN_KERNEL_H_1),
    .TUSER_WIDTH_IM_IN  (TUSER_WIDTH_IM_IN )
  ) pipe (.*);

  logic [WORD_WIDTH-1:0] s_data_pixels_1 [IM_IN_S_DATA_WORDS-1:0];
  logic [WORD_WIDTH-1:0] s_data_pixels_2 [IM_IN_S_DATA_WORDS-1:0];
  logic [WORD_WIDTH-1:0] m_data_pixels_1 [UNITS-1:0];
  logic [WORD_WIDTH-1:0] m_data_pixels_2 [UNITS-1:0];

  assign {>>{s_axis_pixels_1_tdata}} = s_data_pixels_1;
  assign {>>{s_axis_pixels_2_tdata}} = s_data_pixels_2;
  assign m_data_pixels_1 = {>>{m_axis_pixels_1_tdata}};
  assign m_data_pixels_2 = {>>{m_axis_pixels_2_tdata}};

  int status, file_im_1, file_im_2;

  string path_im_1 = "D:/Vision Traffic/soc/mem_yolo/txt/im_pipe_in.txt";
  string path_im_2 = "D:/Vision Traffic/soc/mem_yolo/txt/im_pipe_in_2.txt";

  localparam BEATS_2 = 4;
  localparam WORDS_2 = BEATS_2 * UNITS_EDGES;
  localparam BEATS_1 = BEATS_2 + 1;
  localparam WORDS_1 = BEATS_1 * UNITS_EDGES;
  // localparam S_BEATS = (M_BEATS * UNITS_EDGES) / IM_IN_S_DATA_WORDS + ((M_BEATS * UNITS_EDGES) % IM_IN_S_DATA_WORDS != 0);
  int s_words_1 = 0; 
  int s_words_2 = 0; 

  task axis_feed_pixels_1;
  begin
    if (s_axis_pixels_1_tready) begin
      s_axis_pixels_1_tvalid <= 1;

      for (int i=0; i < IM_IN_S_DATA_WORDS; i++) begin

        status = $fscanf(file_im_1,"%d\n", s_data_pixels_1[i]);
        
        if (s_words_1 < WORDS_1) s_axis_pixels_1_tkeep[i] = 1;
        else                     s_axis_pixels_1_tkeep[i] = 0;
        s_words_1 = s_words_1 + 1;
      end

      if (s_words_1 < WORDS_1)   s_axis_pixels_1_tlast <= 0;
      else                       s_axis_pixels_1_tlast <= 1;
    end
  end
  endtask

  task axis_feed_pixels_2;
    if (s_axis_pixels_2_tready) begin
      s_axis_pixels_2_tvalid <= 1;

      for (int i=0; i < IM_IN_S_DATA_WORDS; i++) begin
        status = $fscanf(file_im_2,"%d\n", s_data_pixels_2[i]);

        if (s_words_2 < WORDS_2) s_axis_pixels_2_tkeep[i] = 1;
        else                     s_axis_pixels_2_tkeep[i] = 0;
        s_words_2 = s_words_2 + 1;
      end

      if (s_words_2 < WORDS_2)   s_axis_pixels_2_tlast <= 0;
      else                       s_axis_pixels_2_tlast <= 1;
    end
  endtask

  int start_1 =0;
  int start_2 =0;

  initial begin

    forever begin
      @(posedge aclk);

      if (start_1) begin
        axis_feed_pixels_1;
        
        if (status != 1 && $feof(file_im_1)) begin
          @(posedge aclk);
          s_axis_pixels_1_tvalid <= 0;
          s_axis_pixels_1_tlast  <= 0;
          s_words_1       <= 0;
          start_1         <= 0;
        end
      end
    end
  end

  initial begin
    
    forever begin
      @(posedge aclk);

      if (start_2) begin
        axis_feed_pixels_2;

        if (status != 1 && $feof(file_im_2)) begin
          @(posedge aclk);
          s_axis_pixels_2_tvalid <= 0;
          s_axis_pixels_2_tlast  <= 0;
          s_words_2       <= 0;
          start_2         <= 0;
        end
      end
    end
  end

  initial begin

    aresetn         <= 0;
    s_axis_pixels_1_tvalid <= 0;
    s_axis_pixels_2_tvalid <= 0;
    s_axis_pixels_1_tlast  <= 0;
    s_axis_pixels_2_tlast  <= 0;
    m_axis_tready   <= 0;

    s_axis_pixels_1_tkeep  <= -1;
    s_axis_pixels_2_tkeep  <= -1;
 
    @(posedge aclk);
    #(CLK_PERIOD*3)
    @(posedge aclk);

    aresetn         <= 1;
    m_axis_tready   <= 1;

    @(posedge aclk);
    @(posedge aclk);

    file_im_1   = $fopen(path_im_1   ,"r");
    file_im_2   = $fopen(path_im_2   ,"r");
    start_1 = 1;
    start_2 = 1;
    while (!(start_1 == 0 && start_2 == 0)) @(posedge aclk);

    @(posedge aclk);
    file_im_1   = $fopen(path_im_1   ,"r");
    file_im_2   = $fopen(path_im_2   ,"r");
    start_1 = 1;
    start_2 = 1;
    while (!(start_1 == 0 && start_2 == 0)) @(posedge aclk);
    $fclose(file_im_1);
    $fclose(file_im_2);
  end

endmodule