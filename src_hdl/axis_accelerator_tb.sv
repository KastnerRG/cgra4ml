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

  int status, file_im_1, file_im_2, file_weights, file_out_conv, file_out_lrelu, file_out_max;

  /*
    IMAGE & KERNEL PARAMETERS
  */

   // //################ LAYER 1 : 3x3, maxpool ####################
  
   localparam K          = 3;
   localparam MAX_FACTOR = 2;
   localparam IM_HEIGHT  = 256;
   localparam IM_WIDTH   = 384;
   localparam IM_CIN     = 3;
   string path_im_1      = "D:/cnn-fpga/data/1_conv_in_0.txt";
   string path_im_2      = "D:/cnn-fpga/data/1_conv_in_1.txt";
   string path_weights   = "D:/cnn-fpga/data/1_weights.txt";
   string path_conv_out  = "D:/cnn-fpga/data/1_conv_out_fpga.txt";
   string path_lrelu_out = "D:/cnn-fpga/data/1_lrelu_out_fpga.txt";
   string path_max_out   = "D:/cnn-fpga/data/1_max_out_fpga.txt";

////  ############ LAYER 3 : 3x3, non-maxpool ####################

//  localparam K          = 3;
//  localparam MAX_FACTOR = 1;
//  localparam IM_HEIGHT  = 64;
//  localparam IM_WIDTH   = 96;
//  localparam IM_CIN     = 64;
//  string path_im_1      = "D:/cnn-fpga/data/3_conv_in_0.txt";
//  string path_im_2      = "D:/cnn-fpga/data/3_conv_in_1.txt";
//  string path_weights   = "D:/cnn-fpga/data/3_weights.txt";
//  string path_conv_out  = "D:/cnn-fpga/data/3_conv_out_fpga.txt";
//  string path_lrelu_out = "D:/cnn-fpga/data/3_lrelu_out_fpga.txt";
//  string path_max_out   = "D:/cnn-fpga/data/3_max_out_fpga.txt";

//   // #################### LAYER 4 : 1x1 ####################

//   localparam K          = 1;
//   localparam MAX_FACTOR = 1;
//   localparam IM_HEIGHT  = 64;
//   localparam IM_WIDTH   = 96;
//   localparam IM_CIN     = 128;
//   string path_im_1      = "D:/cnn-fpga/data/4_conv_in_0.txt";
//   string path_im_2      = "D:/cnn-fpga/data/4_conv_in_1.txt";
//   string path_weights   = "D:/cnn-fpga/data/4_weights.txt";
//   string path_conv_out  = "D:/cnn-fpga/data/4_conv_out_fpga.txt";
//   string path_lrelu_out = "D:/cnn-fpga/data/4_lrelu_out_fpga.txt";
//   string path_max_out   = "D:/cnn-fpga/data/4_max_out_fpga.txt";

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
  localparam S_WEIGHTS_WIDTH       = `S_WEIGHTS_WIDTH      ;
  localparam M_DATA_WIDTH          = `M_DATA_WIDTH         ;
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
  logic [S_WEIGHTS_WIDTH    -1:0] s_axis_weights_tdata;
  logic [S_WEIGHTS_WIDTH /8 -1:0] s_axis_weights_tkeep;

  logic conv_m_axis_tready;
  logic conv_m_axis_tvalid;
  logic conv_m_axis_tlast ;
  logic [TUSER_WIDTH_LRELU_IN  -1:0] conv_m_axis_tuser;
  logic [COPIES*MEMBERS*GROUPS*UNITS*WORD_WIDTH_ACC-1:0] conv_m_axis_tdata; // cmgu
  logic [WORD_WIDTH_ACC-1:0] conv_m_data [COPIES-1:0][MEMBERS-1:0][GROUPS-1:0][UNITS-1:0];

  logic lrelu_m_axis_tvalid;
  logic lrelu_m_axis_tready;
  logic [COPIES*GROUPS*UNITS*WORD_WIDTH -1:0] lrelu_m_axis_tdata;
  logic [WORD_WIDTH-1:0] lrelu_m_data [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [TUSER_WIDTH_MAXPOOL_IN-1:0] lrelu_m_axis_tuser;
  
  logic m_axis_tready;
  logic m_axis_tvalid;
  logic m_axis_tlast;

  logic [M_DATA_WIDTH  -1:0] m_axis_tdata;
  logic [M_DATA_WIDTH/8-1:0] m_axis_tkeep;

  // logic [COPIES*GROUPS*UNITS_EDGES*WORD_WIDTH -1:0] m_axis_tdata;
  // logic [COPIES*GROUPS*UNITS_EDGES-1:0]      m_axis_tkeep;

  logic [WORD_WIDTH-1:0] m_data [COPIES-1:0][GROUPS-1:0][UNITS_EDGES-1:0];
  logic                  m_axis_tkeep_cgu [1:0][GROUPS-1:0][UNITS_EDGES-1:0];

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
    .S_WEIGHTS_WIDTH           (S_WEIGHTS_WIDTH           ),
    .M_DATA_WIDTH              (M_DATA_WIDTH              ),
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
  logic [7:0]            s_data_weights  [S_WEIGHTS_WIDTH /8-1:0];

  assign {>>{s_axis_pixels_1_tdata}} = s_data_pixels_1;
  assign {>>{s_axis_pixels_2_tdata}} = s_data_pixels_2;
  assign {>>{s_axis_weights_tdata}}  = s_data_weights;
  assign m_data                      = {>>{m_axis_tdata[COPIES*GROUPS*UNITS_EDGES*WORD_WIDTH-1:0]}};
  assign lrelu_m_data                = {>>{lrelu_m_axis_tdata}};
  assign conv_m_data                 = {>>{conv_m_axis_tdata}};
  assign m_axis_tkeep_cgu = {>>{m_axis_tkeep[COPIES*GROUPS*UNITS_EDGES-1:0]}};


  localparam BEATS_2 = (IM_BLOCKS/MAX_FACTOR) * IM_COLS * IM_CIN;
  localparam WORDS_2 = BEATS_2 * UNITS_EDGES;
  localparam BEATS_1 = BEATS_2 + 1;
  localparam WORDS_1 = BEATS_1 * UNITS_EDGES;
  
  localparam BEATS_CONFIG_1   = K == 1 ? BEATS_CONFIG_1X1_1 : BEATS_CONFIG_3X3_1;
  localparam W_BEATS          = 1 + BEATS_CONFIG_1+1 + K*IM_CIN;
  localparam WORDS_W          = (W_BEATS-1) * KERNEL_W_MAX * CORES + S_WEIGHTS_WIDTH /WORD_WIDTH;
  localparam W_WORDS_PER_BEAT = S_WEIGHTS_WIDTH /WORD_WIDTH;

  localparam BEATS_OUT = (IM_BLOCKS/MAX_FACTOR)*IM_COLS*(KERNEL_W_MAX/K)*MEMBERS;
  localparam WORDS_OUT_LRELU = BEATS_OUT*COPIES*GROUPS*UNITS;
  localparam WORDS_OUT_MAX   = BEATS_OUT*COPIES*GROUPS*UNITS_EDGES/(MAX_FACTOR**2);

  localparam BEATS_OUT_CONV = BEATS_CONFIG_1+1 + (IM_BLOCKS/MAX_FACTOR)*IM_COLS*(KERNEL_W_MAX/K);
  localparam WORDS_OUT_CONV = BEATS_OUT_CONV*COPIES*MEMBERS*GROUPS*UNITS;

  int s_words_1 = 0; 
  int s_words_2 = 0; 
  int s_words_w = 0; 
  int m_words_max   = 0; 
  int m_words_lrelu = 0; 
  int m_words_conv  = 0; 
  int start_1   = 0;
  int start_2   = 0;
  int start_w   = 0;
  int start_o_max   = 0;
  int start_o_lrelu = 0;
  int start_o_conv  = 0;
  int repeats_im_1 = 0;
  int repeats_im_2 = 0;
  int repeats_w    = 0;
  int repeats_out_max    = 0;
  int repeats_out_lrelu  = 0;
  int repeats_out_conv   = 0;

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
          repeats_im_1          = repeats_im_1 + 1;
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
          repeats_im_2             = repeats_im_2 + 1;
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
          repeats_w             = repeats_w + 1;
        end
      end
    end
  endtask

  task axis_receive_max;
    @(posedge aclk);
    #(CLK_PERIOD/2);
    if (start_o_max) begin
      if (m_axis_tvalid & m_axis_tready) begin
        if (m_words_max < WORDS_OUT_MAX) begin
          for (int c=0; c < COPIES; c++) begin
            for (int g=0; g < GROUPS; g++) begin
              for (int u=0; u < UNITS_EDGES; u++) begin
                if (m_axis_tkeep_cgu[c][g][u]) begin
                  $fdisplay(file_out_max, "%d", signed'(m_data[c][g][u]));
                  m_words_max = m_words_max + 1;
                end
              end
            end
          end
        end
        else begin
          m_words_max           <= 0;
          if (repeats_out_max < REPEATS-1) begin
            repeats_out_max   = repeats_out_max + 1;
          end
          else begin
            $fclose(file_out_max);
            start_o_max = 0;
            $finish();
          end
        end
      end
    end
  endtask

  task axis_receive_lrelu;
    @(posedge aclk);
    #(CLK_PERIOD/2);
    if (start_o_lrelu) begin
      if (lrelu_m_axis_tvalid & lrelu_m_axis_tready) begin
        if (m_words_lrelu < WORDS_OUT_LRELU) begin
          for (int c=0; c < COPIES; c++) begin
            for (int g=0; g < GROUPS; g++) begin
              for (int u=0; u < UNITS; u++) begin
                $fdisplay(file_out_lrelu, "%d", signed'(lrelu_m_data[c][g][u]));
                m_words_lrelu = m_words_lrelu + 1;
              end
            end
          end
        end
        else begin
          m_words_lrelu           <= 0;
          if (repeats_out_lrelu < REPEATS-1) begin
            repeats_out_lrelu   = repeats_out_lrelu + 1;
          end
          else begin
            $fclose(file_out_lrelu);
            start_o_lrelu = 0;
            // $finish();
          end
        end
      end
    end
  endtask

  task axis_receive_conv;
    @(posedge aclk);
    #(CLK_PERIOD/2);
    if (start_o_conv) begin
      if (conv_m_axis_tvalid & conv_m_axis_tready) begin
        if (m_words_conv < WORDS_OUT_CONV) begin
          for (int c=0; c < COPIES; c++) begin
            for (int m=0; m < MEMBERS; m++) begin
              for (int g=0; g < GROUPS; g++) begin
                for (int u=0; u < UNITS; u++) begin
                  $fdisplay(file_out_conv, "%d", signed'(conv_m_data[c][m][g][u]));
                  m_words_conv = m_words_conv + 1;
                end
              end
            end
          end
        end
        else begin
          m_words_conv           <= 0;
          if (repeats_out_conv < REPEATS-1) begin
            repeats_out_conv   = repeats_out_conv + 1;
          end
          else begin
            $fclose(file_out_conv);
            start_o_conv = 0;
          end
        end
      end
    end
  endtask


  initial forever axis_feed_pixels_1;
  initial forever axis_feed_pixels_2;
  initial forever axis_feed_weights;
  initial forever axis_receive_max;
  initial forever axis_receive_lrelu;
  initial forever axis_receive_conv;

  /*
    Test AXIS functionality
    Randomize m_ready with P(1) = 0.7
  */

  class Random_Bit;
    rand bit rand_bit;
    constraint c {
      rand_bit dist { 0 := 3, 1 := 7};
    }
  endclass

  Random_Bit rand_obj = new();

  initial begin
    forever begin
      @(posedge aclk);
      #1;
      rand_obj.randomize();
      m_axis_tready = rand_obj.rand_bit;
      // m_axis_tready = 1;
    end
  end

  initial begin

    aresetn                <= 0;
    s_axis_pixels_1_tvalid <= 0;
    s_axis_pixels_2_tvalid <= 0;
    s_axis_weights_tvalid  <= 0;
    s_axis_pixels_1_tlast  <= 0;
    s_axis_pixels_2_tlast  <= 0;
    s_axis_weights_tlast   <= 0;

    s_axis_pixels_1_tkeep  <= -1;
    s_axis_pixels_2_tkeep  <= -1;
    s_axis_weights_tkeep   <= -1;
 
    @(posedge aclk);
    #(CLK_PERIOD*3)

    @(posedge aclk);
    aresetn         <= 1;
    
    @(posedge aclk);
    file_im_1     = $fopen(path_im_1   ,"r");
    file_im_2     = $fopen(path_im_2   ,"r");
    file_weights  = $fopen(path_weights,"r");
    file_out_max  = $fopen(path_max_out,  "w");
    file_out_conv = $fopen(path_conv_out, "w");
    file_out_lrelu= $fopen(path_lrelu_out,"w");
    start_1 = 1;
    start_2 = 1;
    start_w = 1;
    start_o_conv  = 1;
    start_o_lrelu = 1;
    start_o_max   = 1;
  end

endmodule