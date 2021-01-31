`include "params.v"

module axis_accelerator_tb ();
  timeunit 10ns;
  timeprecision 1ns;
  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  int status, file_im_1, file_im_2, file_weights, file_out;

  /*
    IMAGE & KERNEL PARAMETERS
  */

  //################ LAYER 1 : 3x3, maxpool ####################
  
  localparam K          = 3;
  localparam MAX_FACTOR = 2;
  localparam IM_HEIGHT  = 256;
  localparam IM_WIDTH   = 384;
  localparam IM_CIN     = 3;
  string path_im_1    = "D:/Vision Traffic/soc/data/1_conv_in_0.txt";
  string path_im_2    = "D:/Vision Traffic/soc/data/1_conv_in_1.txt";
  string path_weights = "D:/Vision Traffic/soc/data/1_weights.txt";
  string path_out     = "D:/Vision Traffic/soc/data/1_lrelu_out_fpga.txt";

  // //############ LAYER 3 : 3x3, non-maxpool ####################

  // localparam K          = 3;
  // localparam MAX_FACTOR = 1;
  // localparam IM_HEIGHT  = 64;
  // localparam IM_WIDTH   = 96;
  // localparam IM_CIN     = 64;
  // string path_im_1    = "D:/Vision Traffic/soc/data/3_conv_in_0.txt";
  // string path_im_2    = "D:/Vision Traffic/soc/data/3_conv_in_1.txt";
  // string path_weights = "D:/Vision Traffic/soc/data/3_weights.txt";
  // string path_out     = "D:/Vision Traffic/soc/data/3_lrelu_out_fpga.txt";

  // //#################### LAYER 4 : 1x1 ####################

  // localparam K          = 1;
  // localparam MAX_FACTOR = 1;
  // localparam IM_HEIGHT  = 64;
  // localparam IM_WIDTH   = 96;
  // localparam IM_CIN     = 128;
  // string path_im_1    = "D:/Vision Traffic/soc/data/4_conv_in_0.txt";
  // string path_im_2    = "D:/Vision Traffic/soc/data/4_conv_in_1.txt";
  // string path_weights = "D:/Vision Traffic/soc/data/4_weights.txt";
  // string path_out     = "D:/Vision Traffic/soc/data/4_lrelu_out_fpga.txt";

  /*
    SYSTEM PARAMS
  */
  localparam UNITS                 = `UNITS                ;
  localparam GROUPS                = `GROUPS               ;
  localparam COPIES                = `COPIES               ;
  localparam MEMBERS               = `MEMBERS              ;
  localparam CORES                 = `CORES                ;
  localparam WORD_WIDTH            = `WORD_WIDTH           ; 
  localparam WORD_WIDTH_ACC        = `WORD_WIDTH_ACC       ; 
  localparam KERNEL_H_MAX          = `KERNEL_H_MAX         ;   // odd number
  localparam KERNEL_W_MAX          = `KERNEL_W_MAX         ;
  localparam BITS_KERNEL_W         = `BITS_KERNEL_W        ;
  localparam BITS_KERNEL_H         = `BITS_KERNEL_H        ;
  localparam IM_CIN_MAX            = `IM_CIN_MAX           ;
  localparam IM_BLOCKS_MAX         = `IM_BLOCKS_MAX        ;
  localparam IM_COLS_MAX           = `IM_COLS_MAX          ;
  localparam WEIGHTS_DMA_BITS      = `WEIGHTS_DMA_BITS     ;
  localparam LRELU_ALPHA           = `LRELU_ALPHA          ;
  localparam BITS_EXP_CONFIG       = `BITS_EXP_CONFIG      ;
  localparam BITS_FRA_CONFIG       = `BITS_FRA_CONFIG      ;
  localparam BITS_EXP_FMA_1        = `BITS_EXP_FMA_1       ;
  localparam BITS_FRA_FMA_1        = `BITS_FRA_FMA_1       ;
  localparam BITS_EXP_FMA_2        = `BITS_EXP_FMA_2       ;
  localparam BITS_FRA_FMA_2        = `BITS_FRA_FMA_2       ;
  localparam LATENCY_FMA_1         = `LATENCY_FMA_1        ;
  localparam LATENCY_FMA_2         = `LATENCY_FMA_2        ;
  localparam LATENCY_FIXED_2_FLOAT = `LATENCY_FIXED_2_FLOAT;
  localparam LATENCY_BRAM          = `LATENCY_BRAM         ;
  localparam LATENCY_ACCUMULATOR   = `LATENCY_ACCUMULATOR  ;
  localparam LATENCY_MULTIPLIER    = `LATENCY_MULTIPLIER   ;
  localparam BEATS_CONFIG_3X3_1    = `BEATS_CONFIG_3X3_1   ;
  localparam BEATS_CONFIG_1X1_1    = `BEATS_CONFIG_1X1_1   ;
  localparam I_IMAGE_IS_NOT_MAX         = `I_IMAGE_IS_NOT_MAX;
  localparam I_IMAGE_IS_MAX             = `I_IMAGE_IS_MAX    ;
  localparam I_IMAGE_IS_LRELU           = `I_IMAGE_IS_LRELU  ;
  localparam I_IMAGE_KERNEL_H_1         = `I_IMAGE_KERNEL_H_1; 
  localparam TUSER_WIDTH_IM_SHIFT_IN    = `TUSER_WIDTH_IM_SHIFT_IN ;
  localparam TUSER_WIDTH_IM_SHIFT_OUT   = `TUSER_WIDTH_IM_SHIFT_OUT;
  localparam I_WEIGHTS_IS_TOP_BLOCK     = `I_WEIGHTS_IS_TOP_BLOCK   ;
  localparam I_WEIGHTS_IS_BOTTOM_BLOCK  = `I_WEIGHTS_IS_BOTTOM_BLOCK;
  localparam I_WEIGHTS_IS_1X1           = `I_WEIGHTS_IS_1X1         ;
  localparam I_WEIGHTS_IS_COLS_1_K2     = `I_WEIGHTS_IS_COLS_1_K2   ;
  localparam I_WEIGHTS_IS_CONFIG        = `I_WEIGHTS_IS_CONFIG      ;
  localparam I_WEIGHTS_IS_CIN_LAST      = `I_WEIGHTS_IS_CIN_LAST    ;
  localparam I_WEIGHTS_KERNEL_W_1       = `I_WEIGHTS_KERNEL_W_1     ; 
  localparam TUSER_WIDTH_WEIGHTS_OUT    = `TUSER_WIDTH_WEIGHTS_OUT;
  localparam I_IS_NOT_MAX               = `I_IS_NOT_MAX     ;
  localparam I_IS_MAX                   = `I_IS_MAX         ;
  localparam I_IS_1X1                   = `I_IS_1X1         ;
  localparam I_IS_LRELU                 = `I_IS_LRELU       ;
  localparam I_IS_TOP_BLOCK             = `I_IS_TOP_BLOCK   ;
  localparam I_IS_BOTTOM_BLOCK          = `I_IS_BOTTOM_BLOCK;
  localparam I_IS_COLS_1_K2             = `I_IS_COLS_1_K2   ;
  localparam I_IS_CONFIG                = `I_IS_CONFIG      ;
  localparam I_IS_CIN_LAST              = `I_IS_CIN_LAST    ;
  localparam I_KERNEL_W_1               = `I_KERNEL_W_1     ; 
  localparam TUSER_WIDTH_CONV_IN        = `TUSER_WIDTH_CONV_IN;
  localparam I_IS_LEFT_COL              = `I_IS_LEFT_COL ;
  localparam I_IS_RIGHT_COL             = `I_IS_RIGHT_COL;
  localparam TUSER_WIDTH_MAXPOOL_IN     = `TUSER_WIDTH_MAXPOOL_IN    ;
  localparam TUSER_WIDTH_LRELU_FMA_1_IN = `TUSER_WIDTH_LRELU_FMA_1_IN;
  localparam TUSER_WIDTH_LRELU_IN       = `TUSER_WIDTH_LRELU_IN      ;

  localparam UNITS_EDGES        = UNITS + KERNEL_H_MAX-1;
  localparam IM_IN_S_DATA_WORDS = 2**$clog2(UNITS_EDGES);
  localparam TKEEP_WIDTH_IM_IN  = WORD_WIDTH*IM_IN_S_DATA_WORDS/8;
  localparam IM_BLOCKS          = IM_HEIGHT/UNITS;
  localparam IM_COLS            = IM_WIDTH;
  localparam REPEATS = 1;


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

  logic [TUSER_WIDTH_MAXPOOL_IN-1:0]         m_axis_tuser;
  logic [WORD_WIDTH*COPIES*GROUPS*UNITS-1:0] m_axis_tdata;
  logic [WORD_WIDTH-1:0]                     m_data [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [GROUPS*UNITS_EDGES*COPIES-1:0]      m_axis_tkeep;

  axis_accelerator #(
    .UNITS                     (UNITS                     ),
    .GROUPS                    (GROUPS                    ),
    .COPIES                    (COPIES                    ),
    .MEMBERS                   (MEMBERS                   ),
    .WORD_WIDTH                (WORD_WIDTH                ),
    .KERNEL_H_MAX              (KERNEL_H_MAX              ),
    .BEATS_CONFIG_3X3_1        (BEATS_CONFIG_3X3_1        ),
    .BEATS_CONFIG_1X1_1        (BEATS_CONFIG_1X1_1        ),
    .I_IMAGE_IS_NOT_MAX        (I_IMAGE_IS_NOT_MAX        ),
    .I_IMAGE_IS_MAX            (I_IMAGE_IS_MAX            ),
    .I_IMAGE_IS_LRELU          (I_IMAGE_IS_LRELU          ),
    .I_IMAGE_KERNEL_H_1        (I_IMAGE_KERNEL_H_1        ),
    .TUSER_WIDTH_IM_SHIFT_IN   (TUSER_WIDTH_IM_SHIFT_IN   ),
    .TUSER_WIDTH_IM_SHIFT_OUT  (TUSER_WIDTH_IM_SHIFT_OUT  ),
    .WORD_WIDTH_ACC            (WORD_WIDTH_ACC            ),
    .IM_CIN_MAX                (IM_CIN_MAX                ),
    .IM_BLOCKS_MAX             (IM_BLOCKS_MAX             ),
    .IM_COLS_MAX               (IM_COLS_MAX               ),
    .WEIGHTS_DMA_BITS          (WEIGHTS_DMA_BITS          ),
    .LRELU_ALPHA               (LRELU_ALPHA               ),
    .BITS_EXP_CONFIG           (BITS_EXP_CONFIG           ),
    .BITS_FRA_CONFIG           (BITS_FRA_CONFIG           ),
    .BITS_EXP_FMA_1            (BITS_EXP_FMA_1            ),
    .BITS_FRA_FMA_1            (BITS_FRA_FMA_1            ),
    .BITS_EXP_FMA_2            (BITS_EXP_FMA_2            ),
    .BITS_FRA_FMA_2            (BITS_FRA_FMA_2            ),
    .LATENCY_FMA_1             (LATENCY_FMA_1             ),
    .LATENCY_FMA_2             (LATENCY_FMA_2             ),
    .LATENCY_FIXED_2_FLOAT     (LATENCY_FIXED_2_FLOAT     ),
    .LATENCY_BRAM              (LATENCY_BRAM              ),
    .LATENCY_ACCUMULATOR       (LATENCY_ACCUMULATOR       ),
    .LATENCY_MULTIPLIER        (LATENCY_MULTIPLIER        ),
    .I_WEIGHTS_IS_TOP_BLOCK    (I_WEIGHTS_IS_TOP_BLOCK    ),
    .I_WEIGHTS_IS_BOTTOM_BLOCK (I_WEIGHTS_IS_BOTTOM_BLOCK ),
    .I_WEIGHTS_IS_1X1          (I_WEIGHTS_IS_1X1          ),
    .I_WEIGHTS_IS_COLS_1_K2    (I_WEIGHTS_IS_COLS_1_K2    ),
    .I_WEIGHTS_IS_CONFIG       (I_WEIGHTS_IS_CONFIG       ),
    .I_WEIGHTS_KERNEL_W_1      (I_WEIGHTS_KERNEL_W_1      ),
    .TUSER_WIDTH_WEIGHTS_OUT   (TUSER_WIDTH_WEIGHTS_OUT   ),
    .I_IS_NOT_MAX              (I_IS_NOT_MAX              ),
    .I_IS_MAX                  (I_IS_MAX                  ),
    .I_IS_1X1                  (I_IS_1X1                  ),
    .I_IS_LRELU                (I_IS_LRELU                ),
    .I_IS_TOP_BLOCK            (I_IS_TOP_BLOCK            ),
    .I_IS_BOTTOM_BLOCK         (I_IS_BOTTOM_BLOCK         ),
    .I_IS_COLS_1_K2            (I_IS_COLS_1_K2            ),
    .I_IS_CONFIG               (I_IS_CONFIG               ),
    .I_KERNEL_W_1              (I_KERNEL_W_1              ),
    .TUSER_WIDTH_CONV_IN       (TUSER_WIDTH_CONV_IN       ),
    .I_IS_LEFT_COL             (I_IS_LEFT_COL             ),
    .I_IS_RIGHT_COL            (I_IS_RIGHT_COL            ),
    .TUSER_WIDTH_LRELU_FMA_1_IN(TUSER_WIDTH_LRELU_FMA_1_IN),
    .TUSER_WIDTH_LRELU_IN      (TUSER_WIDTH_LRELU_IN      ),
    .TUSER_WIDTH_MAXPOOL_IN    (TUSER_WIDTH_MAXPOOL_IN    )    
  ) pipe (.*);

  logic [WORD_WIDTH-1:0] s_data_pixels_1 [IM_IN_S_DATA_WORDS-1:0];
  logic [WORD_WIDTH-1:0] s_data_pixels_2 [IM_IN_S_DATA_WORDS-1:0];
  logic [7:0]            s_data_weights  [WEIGHTS_DMA_BITS/8-1:0];

  assign {>>{s_axis_pixels_1_tdata}} = s_data_pixels_1;
  assign {>>{s_axis_pixels_2_tdata}} = s_data_pixels_2;
  assign {>>{s_axis_weights_tdata}}  = s_data_weights;
  assign m_data                      = {>>{m_axis_tdata}};


  localparam BEATS_2 = (IM_BLOCKS/MAX_FACTOR) * IM_COLS * IM_CIN;
  localparam WORDS_2 = BEATS_2 * UNITS_EDGES;
  localparam BEATS_1 = BEATS_2 + 1;
  localparam WORDS_1 = BEATS_1 * UNITS_EDGES;
  
  localparam BEATS_CONFIG_1   = K == 1 ? BEATS_CONFIG_1X1_1 : BEATS_CONFIG_3X3_1;
  localparam W_BEATS          = 1 + BEATS_CONFIG_1+1 + K*IM_CIN;
  localparam WORDS_W          = (W_BEATS-1) * KERNEL_W_MAX * CORES + WEIGHTS_DMA_BITS/WORD_WIDTH;
  localparam W_WORDS_PER_BEAT = WEIGHTS_DMA_BITS/WORD_WIDTH;

  // localparam BEATS_OUT = BEATS_CONFIG_1+1 + (IM_BLOCKS/MAX_FACTOR)*IM_COLS*(KERNEL_W_MAX/K);
  localparam BEATS_OUT = (IM_BLOCKS/MAX_FACTOR)*IM_COLS*(KERNEL_W_MAX/K)*MEMBERS;
  localparam WORDS_OUT = BEATS_OUT*COPIES*GROUPS*UNITS;

  int s_words_1 = 0; 
  int s_words_2 = 0; 
  int s_words_w = 0; 
  int m_words   = 0; 
  int start_1   = 0;
  int start_2   = 0;
  int start_w   = 0;
  int start_o   = 0;
  int repats_im_1 = 0;
  int repats_im_2 = 0;
  int repats_w    = 0;
  int repats_out  = 0;

  task axis_feed_pixels_1;
    @(posedge aclk);
    if (start_1) begin
      if (s_axis_pixels_1_tready) begin
        if (s_words_1 < WORDS_1) begin
          #1;
          s_axis_pixels_1_tvalid <= 1;

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

          file_im_1            = $fopen(path_im_1   ,"r");
          repats_im_1          = repats_im_1 + 1;
        end
      end
    end
  endtask

  task axis_feed_pixels_2;
    @(posedge aclk);
    if (start_2) begin
      if (s_axis_pixels_2_tready) begin
        if (s_words_2 < WORDS_2) begin
          #1;
          s_axis_pixels_2_tvalid <= 1;

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

          file_im_2               = $fopen(path_im_2   ,"r");
          repats_im_2             = repats_im_2 + 1;
        end
      end
    end
  endtask

  task axis_feed_weights;
    @(posedge aclk);
    if (start_w) begin
      if (s_axis_weights_tready) begin
        if (s_words_w < WORDS_W) begin
          #1;
          s_axis_weights_tvalid <= 1;
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

          file_weights         = $fopen(path_weights ,"r");
          repats_w             = repats_w + 1;
        end
      end
    end
  endtask

  task axis_receive;
    @(posedge aclk);
    #(CLK_PERIOD/2);
    if (start_o) begin
      if (m_axis_tvalid & m_axis_tready) begin
        if (m_words < WORDS_OUT) begin
          for (int c=0; c < COPIES; c++) begin
            for (int g=0; g < GROUPS; g++) begin
              for (int u=0; u < UNITS; u++) begin
                $fdisplay(file_out, "%d", signed'(m_data[c][g][u]));
                m_words = m_words + 1;
              end
            end
          end
        end
        else begin
          m_words           <= 0;
          if (repats_out < REPEATS-1) begin
            repats_out   = repats_out + 1;
          end
          else begin
            $fclose(file_out);
            start_o = 0;
            $finish();
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
    forever axis_receive;
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
    file_out     = $fopen(path_out,    "w");
    start_1 = 1;
    start_2 = 1;
    start_w = 1;
    start_o = 1;
  end

endmodule