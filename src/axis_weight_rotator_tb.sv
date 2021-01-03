module axis_weight_rotator_tb ();
  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end
  
  localparam K_1      = 3-1;
  localparam CIN_1    = 4-1;
  localparam COLS_1   = 20-1;
  localparam BLOCKS_1 = 1-1; 

  localparam CORES             = 4;
  localparam WORD_WIDTH        = 8; 
  localparam KERNEL_H_MAX      = 3;   // odd number
  localparam KERNEL_W_MAX      = 3;   // odd number
  localparam IM_CIN_MAX        = 1024;
  localparam IM_BLOCKS_MAX     = 32;
  localparam IM_COLS_MAX       = 384;
  localparam WEIGHTS_DMA_BITS  = 32;

  localparam BEATS_CONFIG_3X3_1   = 21-1;
  localparam BEATS_CONFIG_1X1_1   = 13-1;

  localparam BRAM_LATENCY =  2;

  localparam BITS_KERNEL_W_MAX = $clog2(KERNEL_W_MAX);
  localparam BITS_KERNEL_H_MAX = $clog2(KERNEL_H_MAX);

  localparam I_KERNEL_W_1         = 0;
  localparam I_KERNEL_H_1         = I_KERNEL_W_1 + BITS_KERNEL_W_MAX + 0;
  localparam I_OTHER              = I_KERNEL_H_1 + BITS_KERNEL_H_MAX;
  localparam I_IS_CONFIG          = I_OTHER + 0;  
  localparam I_CONV_IS_1X1        = I_OTHER + 1;
  localparam I_LRELU_IS_TOP       = I_OTHER + 2;
  localparam I_LRELU_IS_BOTTOM    = I_OTHER + 3;
  localparam I_CONV_IS_COLS_1_K2  = I_OTHER + 4;
  localparam TUSER_WIDTH_CONV     = I_OTHER + 5;

  localparam BITS_CONFIG_COUNT    = $clog2(BEATS_CONFIG_3X3_1);
  localparam M_WIDTH              = WORD_WIDTH*CORES*KERNEL_W_MAX;

  localparam BRAM_W_WIDTH = WEIGHTS_DMA_BITS;
  localparam BRAM_R_WIDTH = M_WIDTH;
  localparam BRAM_R_DEPTH = KERNEL_H_MAX * IM_CIN_MAX + BEATS_CONFIG_3X3_1;
  localparam BRAM_W_DEPTH = BRAM_R_DEPTH * BRAM_R_WIDTH / BRAM_W_WIDTH;

  localparam BITS_R_ADDR       = $clog2(BRAM_R_DEPTH);
  localparam BITS_W_ADDR       = $clog2(BRAM_W_DEPTH);
  localparam BITS_IM_CIN       = $clog2(IM_CIN_MAX);
  localparam BITS_IM_BLOCKS    = $clog2(IM_BLOCKS_MAX);
  localparam BITS_IM_COLS      = $clog2(IM_COLS_MAX);

  logic aresetn;
  logic s_axis_tready;
  logic s_axis_tvalid;
  logic s_axis_tlast ;
  logic [WEIGHTS_DMA_BITS   -1:0] s_axis_tdata;
  logic [WEIGHTS_DMA_BITS/8 -1:0] s_axis_tkeep;

  logic m_axis_tready;
  logic m_axis_tvalid;
  logic [M_WIDTH -1:0]         m_axis_tdata;
  logic [TUSER_WIDTH_CONV-1:0] m_axis_tuser;
  logic m_axis_tlast;

  axis_weight_rotator #(
    .CORES               (CORES              ),
    .WORD_WIDTH          (WORD_WIDTH         ),
    .KERNEL_H_MAX        (KERNEL_H_MAX       ),
    .KERNEL_W_MAX        (KERNEL_W_MAX       ),
    .IM_CIN_MAX          (IM_CIN_MAX         ),
    .IM_BLOCKS_MAX       (IM_BLOCKS_MAX      ),
    .IM_COLS_MAX         (IM_COLS_MAX        ),
    .WEIGHTS_DMA_BITS    (WEIGHTS_DMA_BITS   ),
    .BEATS_CONFIG_3X3_1  (BEATS_CONFIG_3X3_1 ),
    .BEATS_CONFIG_1X1_1  (BEATS_CONFIG_1X1_1 ),
    .BRAM_LATENCY        (BRAM_LATENCY       ),
    .I_KERNEL_W_1        (I_KERNEL_W_1       ),
    .I_KERNEL_H_1        (I_KERNEL_H_1       ),
    .I_OTHER             (I_OTHER            ),
    .I_IS_CONFIG         (I_IS_CONFIG        ),
    .I_CONV_IS_1X1       (I_CONV_IS_1X1      ),
    .I_LRELU_IS_TOP      (I_LRELU_IS_TOP     ),
    .I_LRELU_IS_BOTTOM   (I_LRELU_IS_BOTTOM  ),
    .I_CONV_IS_COLS_1_K2 (I_CONV_IS_COLS_1_K2),
    .TUSER_WIDTH_CONV    (TUSER_WIDTH_CONV   )
  ) pipe (.*);

  logic [7:0] s_data_weights [WEIGHTS_DMA_BITS/8-1:0];
  logic [WORD_WIDTH-1:0] m_data_weights [CORES-1:0][KERNEL_W_MAX-1:0];

  assign {>>{s_axis_tdata}} = s_data_weights;
  assign m_data_weights = {>>{m_axis_tdata}};

  int status, file_weights;

  string path_weights = "D:/Vision Traffic/soc/mem_yolo/txt/weights_rot_in.txt";
  
  localparam CONFIG_BEATS_1 = K_1 == 0 ? BEATS_CONFIG_1X1_1 : BEATS_CONFIG_3X3_1;
  localparam W_BEATS = 1 + CONFIG_BEATS_1+1 + (K_1+1)*(CIN_1+1);
  localparam W_WORDS = (W_BEATS-1) * (K_1+1) * CORES + WEIGHTS_DMA_BITS/WORD_WIDTH;
  localparam W_WORDS_PER_BEAT = WEIGHTS_DMA_BITS/WORD_WIDTH;

  int s_words_w = 0; 

  task axis_feed_weights;
  begin
    if (s_axis_tready) begin
      s_axis_tvalid <= 1;

      for (int i=0; i < W_WORDS_PER_BEAT; i++) begin

        status = $fscanf(file_weights,"%d\n", s_data_weights[i]);
        
        if (s_words_w < W_WORDS) s_axis_tkeep[i] = 1;
        else                     s_axis_tkeep[i] = 0;
        s_words_w = s_words_w + 1;
      end

      if (s_words_w < W_WORDS)   s_axis_tlast <= 0;
      else                       s_axis_tlast <= 1;
    end
  end
  endtask

  int start_w =0;

  initial begin

    forever begin
      @(posedge aclk);

      if (start_w) begin
        axis_feed_weights;
        
        if (status != 1 && $feof(file_weights)) begin
          @(posedge aclk);
          s_axis_tvalid <= 0;
          s_axis_tlast  <= 0;
          s_words_w     <= 0;
          start_w       <= 0;
        end
      end
    end
  end

  initial begin

    aresetn       <=  0;
    s_axis_tvalid <=  0;
    s_axis_tlast  <=  0;
    m_axis_tready <=  0;
    s_axis_tkeep  <= -1;
 
    @(posedge aclk);
    #(CLK_PERIOD*3)
    @(posedge aclk);

    aresetn         <= 1;
    m_axis_tready   <= 1;

    @(posedge aclk);

    repeat(5) begin
      @(posedge aclk);
      file_weights   = $fopen(path_weights   ,"r");
      start_w = 1;
      while (!(start_w == 0)) @(posedge aclk);
    end

    $fclose(file_weights);
  end

endmodule