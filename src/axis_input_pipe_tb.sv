module axis_input_pipe_tb ();
  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  /*
    IMAGE & KERNEL PARAMETERS
  */
  
  localparam K          = 3;
  localparam IM_HEIGHT  = 4;
  localparam IM_WIDTH   = 4;
  localparam IM_CIN     = 4;

  localparam ITERATIONS = 5;

  /*
    SYSTEM PARAMS
  */

  localparam UNITS            = 4;
  localparam CORES            = 4;
  localparam WORD_WIDTH       = 8; 
  localparam KERNEL_H_MAX     = 3;   // odd number
  localparam KERNEL_W_MAX     = 3;
  localparam IM_CIN_MAX       = 1024;
  localparam IM_BLOCKS_MAX    = 32;
  localparam IM_COLS_MAX      = 384;
  localparam WEIGHTS_DMA_BITS = 32;
  localparam BRAM_LATENCY     = 2;
  localparam BEATS_CONFIG_3X3_1  = 21-1;
  localparam BEATS_CONFIG_1X1_1  = 13-1;

  localparam IM_BLOCKS     = IM_HEIGHT/UNITS;
  localparam IM_COLS       = IM_WIDTH;

  localparam BITS_KERNEL_W = $clog2(KERNEL_W_MAX);
  localparam BITS_KERNEL_H = $clog2(KERNEL_H_MAX);

  localparam UNITS_EDGES        = UNITS + KERNEL_H_MAX-1;
  localparam IM_IN_S_DATA_WORDS = 2**$clog2(UNITS_EDGES);
  localparam TKEEP_WIDTH_IM_IN  = WORD_WIDTH*IM_IN_S_DATA_WORDS/8;


  /*
    IMAGE TUSER INDICES
  */
  localparam I_IMAGE_IS_NOT_MAX   = 0;
  localparam I_IMAGE_IS_MAX       = I_IMAGE_IS_NOT_MAX + 1;
  localparam I_IMAGE_IS_LRELU     = I_IMAGE_IS_MAX     + 1;
  localparam I_IMAGE_KERNEL_H_1   = I_IMAGE_IS_LRELU   + 1; 

  localparam TUSER_WIDTH_IM_SHIFT_IN  = I_IMAGE_KERNEL_H_1 + BITS_KERNEL_H;
  localparam TUSER_WIDTH_IM_SHIFT_OUT = I_IMAGE_IS_LRELU   + 1;

  /*
    WEIGHTS TUSER INDICES
  */
  localparam I_WEIGHTS_IS_TOP_BLOCK    = 0;
  localparam I_WEIGHTS_IS_BOTTOM_BLOCK = I_WEIGHTS_IS_TOP_BLOCK    + 1;
  localparam I_WEIGHTS_IS_1X1          = I_WEIGHTS_IS_BOTTOM_BLOCK + 1;
  localparam I_WEIGHTS_IS_COLS_1_K2    = I_WEIGHTS_IS_1X1          + 1;
  localparam I_WEIGHTS_IS_CONFIG       = I_WEIGHTS_IS_COLS_1_K2    + 1;
  localparam I_WEIGHTS_IS_ACC_LAST     = I_WEIGHTS_IS_CONFIG       + 1;
  localparam I_WEIGHTS_KERNEL_W_1      = I_WEIGHTS_IS_ACC_LAST     + 1; 

  localparam TUSER_WIDTH_WEIGHTS_OUT   = I_WEIGHTS_KERNEL_W_1 + BITS_KERNEL_W;

  /*
    CONV TUSER INDICES
  */
  localparam I_IS_NOT_MAX      = 0;
  localparam I_IS_MAX          = I_IS_NOT_MAX      + 1;
  localparam I_IS_LRELU        = I_IS_MAX          + 1;
  localparam I_IS_TOP_BLOCK    = I_IS_LRELU        + 1;
  localparam I_IS_BOTTOM_BLOCK = I_IS_TOP_BLOCK    + 1;
  localparam I_IS_1X1          = I_IS_BOTTOM_BLOCK + 1;
  localparam I_IS_COLS_1_K2    = I_IS_1X1          + 1;
  localparam I_IS_CONFIG       = I_IS_COLS_1_K2    + 1;
  localparam I_IS_ACC_LAST     = I_IS_CONFIG       + 1;
  localparam I_KERNEL_W_1      = I_IS_ACC_LAST     + 1; 

  localparam TUSER_WIDTH_CONV_IN        = BITS_KERNEL_W + I_KERNEL_W_1;


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

  logic s_axis_weights_tready;
  logic s_axis_weights_tvalid;
  logic s_axis_weights_tlast ;
  logic [WEIGHTS_DMA_BITS   -1:0] s_axis_weights_tdata;
  logic [WEIGHTS_DMA_BITS/8 -1:0] s_axis_weights_tkeep;

  logic m_axis_tready;
  logic m_axis_tvalid;
  logic m_axis_tlast;
  logic [WORD_WIDTH*UNITS             -1:0] m_axis_pixels_1_tdata;
  logic [WORD_WIDTH*UNITS             -1:0] m_axis_pixels_2_tdata;
  logic [WORD_WIDTH*CORES*KERNEL_W_MAX-1:0] m_axis_weights_tdata;
  logic [TUSER_WIDTH_CONV_IN-1:0] m_axis_tuser;

  axis_input_pipe #(
    .UNITS              (UNITS             ),
    .WORD_WIDTH         (WORD_WIDTH        ),
    .KERNEL_H_MAX       (KERNEL_H_MAX      ),
    .BEATS_CONFIG_3X3_1 (BEATS_CONFIG_3X3_1),
    .BEATS_CONFIG_1X1_1 (BEATS_CONFIG_1X1_1),
    .I_IMAGE_IS_NOT_MAX        (I_IMAGE_IS_NOT_MAX       ),
    .I_IMAGE_IS_MAX            (I_IMAGE_IS_MAX           ),
    .I_IMAGE_IS_LRELU          (I_IMAGE_IS_LRELU         ),
    .I_IMAGE_KERNEL_H_1        (I_IMAGE_KERNEL_H_1       ),
    .TUSER_WIDTH_IM_SHIFT_IN   (TUSER_WIDTH_IM_SHIFT_IN  ),
    .TUSER_WIDTH_IM_SHIFT_OUT  (TUSER_WIDTH_IM_SHIFT_OUT ),

    .IM_CIN_MAX                (IM_CIN_MAX      ),
    .IM_BLOCKS_MAX             (IM_BLOCKS_MAX   ),
    .IM_COLS_MAX               (IM_COLS_MAX     ),
    .WEIGHTS_DMA_BITS          (WEIGHTS_DMA_BITS),
    .BRAM_LATENCY              (BRAM_LATENCY    ),
    .I_WEIGHTS_IS_TOP_BLOCK    (I_WEIGHTS_IS_TOP_BLOCK   ),
    .I_WEIGHTS_IS_BOTTOM_BLOCK (I_WEIGHTS_IS_BOTTOM_BLOCK),
    .I_WEIGHTS_IS_1X1          (I_WEIGHTS_IS_1X1         ),
    .I_WEIGHTS_IS_COLS_1_K2    (I_WEIGHTS_IS_COLS_1_K2   ),
    .I_WEIGHTS_IS_CONFIG       (I_WEIGHTS_IS_CONFIG      ),
    .I_WEIGHTS_KERNEL_W_1      (I_WEIGHTS_KERNEL_W_1     ),
    .TUSER_WIDTH_WEIGHTS_OUT   (TUSER_WIDTH_WEIGHTS_OUT  ),

    .I_IS_NOT_MAX              (I_IS_NOT_MAX             ),
    .I_IS_MAX                  (I_IS_MAX                 ),
    .I_IS_LRELU                (I_IS_LRELU               ),
    .I_IS_TOP_BLOCK            (I_IS_TOP_BLOCK           ),
    .I_IS_BOTTOM_BLOCK         (I_IS_BOTTOM_BLOCK        ),
    .I_IS_1X1                  (I_IS_1X1                 ),
    .I_IS_COLS_1_K2            (I_IS_COLS_1_K2           ),
    .I_IS_CONFIG               (I_IS_CONFIG              ),
    .I_IS_ACC_LAST             (I_IS_ACC_LAST            ),
    .I_KERNEL_W_1              (I_KERNEL_W_1             ),
    .TUSER_WIDTH_CONV_IN       (TUSER_WIDTH_CONV_IN      )
  ) pipe (.*);

  logic [WORD_WIDTH-1:0] s_data_pixels_1 [IM_IN_S_DATA_WORDS-1:0];
  logic [WORD_WIDTH-1:0] s_data_pixels_2 [IM_IN_S_DATA_WORDS-1:0];
  logic [7:0]            s_data_weights  [WEIGHTS_DMA_BITS/8-1:0];
  logic [WORD_WIDTH-1:0] m_data_pixels_1 [UNITS-1:0];
  logic [WORD_WIDTH-1:0] m_data_pixels_2 [UNITS-1:0];
  logic [WORD_WIDTH-1:0] m_data_weights  [CORES-1:0][KERNEL_W_MAX-1:0];

  assign {>>{s_axis_pixels_1_tdata}} = s_data_pixels_1;
  assign {>>{s_axis_pixels_2_tdata}} = s_data_pixels_2;
  assign {>>{s_axis_weights_tdata}}  = s_data_weights;
  assign m_data_pixels_1 = {>>{m_axis_pixels_1_tdata}};
  assign m_data_pixels_2 = {>>{m_axis_pixels_2_tdata}};
  assign m_data_weights  = {>>{m_axis_weights_tdata }};

  int status, file_im_1, file_im_2, file_weights;

  string path_im_1 = "D:/Vision Traffic/soc/mem_yolo/txt/im_pipe_in.txt";
  string path_im_2 = "D:/Vision Traffic/soc/mem_yolo/txt/im_pipe_in_2.txt";
  string path_weights = "D:/Vision Traffic/soc/mem_yolo/txt/weights_rot_in.txt";

  localparam BEATS_2 = IM_BLOCKS * IM_COLS * IM_CIN;
  localparam WORDS_2 = BEATS_2 * UNITS_EDGES;
  localparam BEATS_1 = BEATS_2 + 1;
  localparam WORDS_1 = BEATS_1 * UNITS_EDGES;
  
  localparam CONFIG_BEATS_1   = K == 1 ? BEATS_CONFIG_1X1_1 : BEATS_CONFIG_3X3_1;
  localparam W_BEATS          = 1 + CONFIG_BEATS_1+1 + K*IM_CIN;
  localparam WORDS_W          = (W_BEATS-1) * KERNEL_W_MAX * CORES + WEIGHTS_DMA_BITS/WORD_WIDTH;
  localparam W_WORDS_PER_BEAT = WEIGHTS_DMA_BITS/WORD_WIDTH;

  int s_words_1 = 0; 
  int s_words_2 = 0; 
  int s_words_w = 0; 
  int start_1 =0;
  int start_2 =0;
  int start_w =0;
  int itr_count_im_1 = 0;
  int itr_count_im_2 = 0;
  int itr_count_w    = 0;

  task axis_feed_pixels_1;
    @(posedge aclk);
    if (start_1) begin
      if (s_axis_pixels_1_tready) begin
        if (s_words_1 < WORDS_1) begin
          s_axis_pixels_1_tvalid= 1;

          for (int i=0; i < IM_IN_S_DATA_WORDS; i++) begin
            if (~$feof(file_im_1))
              status = $fscanf(file_im_1,"%d\n", s_data_pixels_1[i]);
            
            s_axis_pixels_1_tkeep[i] = s_words_1 < WORDS_1;
            s_words_1 = s_words_1 + 1;
          end

          s_axis_pixels_1_tlast = ~(s_words_1 < WORDS_1);
        end
        else begin
          s_axis_pixels_1_tvalid <= 0;
          s_axis_pixels_1_tlast  <= 0;
          s_words_1              <= 0;

          if (itr_count_im_1 < ITERATIONS-1) begin
            file_im_1               = $fopen(path_im_1   ,"r");
            itr_count_im_1          = itr_count_im_1 + 1;
          end
        end
      end
    end
  endtask

  task axis_feed_pixels_2;
    @(posedge aclk);
    if (start_2) begin
      if (s_axis_pixels_2_tready) begin
        if (s_words_2 < WORDS_2) begin
          s_axis_pixels_2_tvalid = 1;

          for (int i=0; i < IM_IN_S_DATA_WORDS; i++) begin
            if (~$feof(file_im_2))
              status = $fscanf(file_im_2,"%d\n", s_data_pixels_2[i]);

            s_axis_pixels_2_tkeep[i] = s_words_2 < WORDS_2;
            s_words_2 = s_words_2 + 1;
          end

          s_axis_pixels_2_tlast = ~(s_words_2 < WORDS_2);
        end
        else begin
          s_axis_pixels_2_tvalid <= 0;
          s_axis_pixels_2_tlast  <= 0;
          s_words_2              <= 0;

          if (itr_count_im_2 < ITERATIONS-1) begin
            file_im_2               = $fopen(path_im_2   ,"r");
            itr_count_im_2          = itr_count_im_2 + 1;
          end
        end
      end
    end
  endtask

  task axis_feed_weights;
    @(posedge aclk);
    if (start_w) begin
      if (s_axis_weights_tready) begin
        if (s_words_w < WORDS_W) begin
          s_axis_weights_tvalid = 1;
          for (int i=0; i < W_WORDS_PER_BEAT; i++) begin
            if (~$feof(file_weights))
              status = $fscanf(file_weights,"%d\n", s_data_weights[i]);
            
            s_axis_weights_tkeep[i] = s_words_w < WORDS_W;
            s_words_w = s_words_w + 1;
          end

          s_axis_weights_tlast = ~(s_words_w < WORDS_W);
        end
        else begin
          s_axis_weights_tvalid <= 0;
          s_axis_weights_tlast  <= 0;
          s_words_w             <= 0;
          
          if (itr_count_w < ITERATIONS-1) begin
            file_weights         = $fopen(path_weights ,"r");
            itr_count_w          = itr_count_w + 1;
          end
        end
      end
    end
  endtask

  initial begin
    forever axis_feed_pixels_1;
  end

  initial begin
    forever axis_feed_pixels_2;
  end

  initial begin
    forever axis_feed_weights;
  end

  initial begin

    aresetn                <= 0;
    s_axis_pixels_1_tvalid <= 0;
    s_axis_pixels_2_tvalid <= 0;
    s_axis_weights_tvalid  <= 0;
    s_axis_pixels_1_tlast  <= 0;
    s_axis_pixels_2_tlast  <= 0;
    s_axis_weights_tlast   <= 0;
    m_axis_tready          <= 0;

    s_axis_pixels_1_tkeep  <= -1;
    s_axis_pixels_2_tkeep  <= -1;
    s_axis_weights_tkeep   <= -1;
 
    @(posedge aclk);
    #(CLK_PERIOD*3)
    
    @(posedge aclk);
    aresetn         <= 1;
    m_axis_tready   <= 1;
    
    @(posedge aclk);
    file_im_1    = $fopen(path_im_1   ,"r");
    file_im_2    = $fopen(path_im_2   ,"r");
    file_weights = $fopen(path_weights,"r");
    start_1 = 1;
    start_2 = 1;
    start_w = 1;
  end

endmodule