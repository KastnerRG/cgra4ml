module axis_weight_rotator_tb ();
  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end
  
  localparam K_1      = 1-1;
  localparam CIN_1    = 4-1;
  localparam COLS_1   = 20-1;
  localparam BLOCKS_1 = 1-1; 

  localparam CORES             = 4;

  localparam WORD_WIDTH         = `WORD_WIDTH        ; 
  localparam KERNEL_H_MAX       = `KERNEL_H_MAX      ;   // odd number
  localparam KERNEL_W_MAX       = `KERNEL_W_MAX      ;
  localparam IM_CIN_MAX         = `IM_CIN_MAX        ;
  localparam IM_BLOCKS_MAX      = `IM_BLOCKS_MAX     ;
  localparam IM_COLS_MAX        = `IM_COLS_MAX       ;
  localparam S_WEIGHTS_WIDTH    = `S_WEIGHTS_WIDTH   ;
  localparam BEATS_CONFIG_3X3_1 = `BEATS_CONFIG_3X3_1;
  localparam BEATS_CONFIG_1X1_1 = `BEATS_CONFIG_1X1_1;

  localparam LATENCY_BRAM  = `LATENCY_BRAM ;
  localparam BITS_KERNEL_W = `BITS_KERNEL_W;
  localparam BITS_KERNEL_H = `BITS_KERNEL_H;

  localparam I_WEIGHTS_IS_TOP_BLOCK    = `I_WEIGHTS_IS_TOP_BLOCK   ;
  localparam I_WEIGHTS_IS_BOTTOM_BLOCK = `I_WEIGHTS_IS_BOTTOM_BLOCK;
  localparam I_WEIGHTS_IS_1X1          = `I_WEIGHTS_IS_1X1         ;
  localparam I_WEIGHTS_IS_COLS_1_K2    = `I_WEIGHTS_IS_COLS_1_K2   ;
  localparam I_WEIGHTS_IS_CONFIG       = `I_WEIGHTS_IS_CONFIG      ;
  localparam I_WEIGHTS_IS_CIN_LAST     = `I_WEIGHTS_IS_CIN_LAST    ;
  localparam I_WEIGHTS_KERNEL_W_1      = `I_WEIGHTS_KERNEL_W_1     ; 
  localparam TUSER_WIDTH_WEIGHTS_OUT   = `TUSER_WIDTH_WEIGHTS_OUT;

  localparam BITS_CONFIG_COUNT    = $clog2(BEATS_CONFIG_3X3_1+1);
  localparam M_WIDTH              = WORD_WIDTH*CORES*KERNEL_W_MAX;

  localparam BRAM_W_WIDTH = S_WEIGHTS_WIDTH ;
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
  logic [S_WEIGHTS_WIDTH    -1:0] s_axis_tdata;
  logic [S_WEIGHTS_WIDTH /8 -1:0] s_axis_tkeep;

  logic m_axis_tready;
  logic m_axis_tvalid;
  logic [M_WIDTH -1:0]         m_axis_tdata;
  logic [TUSER_WIDTH_WEIGHTS_OUT-1:0] m_axis_tuser;
  logic m_axis_tlast;

  axis_weight_rotator #(
    .CORES               (CORES              ),
    .WORD_WIDTH          (WORD_WIDTH         ),
    .KERNEL_H_MAX        (KERNEL_H_MAX       ),
    .KERNEL_W_MAX        (KERNEL_W_MAX       ),
    .IM_CIN_MAX          (IM_CIN_MAX         ),
    .IM_BLOCKS_MAX       (IM_BLOCKS_MAX      ),
    .IM_COLS_MAX         (IM_COLS_MAX        ),
    .S_WEIGHTS_WIDTH     (S_WEIGHTS_WIDTH    ),
    .BEATS_CONFIG_3X3_1  (BEATS_CONFIG_3X3_1 ),
    .BEATS_CONFIG_1X1_1  (BEATS_CONFIG_1X1_1 ),
    .LATENCY_BRAM        (LATENCY_BRAM       ),   
    .I_WEIGHTS_IS_TOP_BLOCK      (I_WEIGHTS_IS_TOP_BLOCK     ),
    .I_WEIGHTS_IS_BOTTOM_BLOCK   (I_WEIGHTS_IS_BOTTOM_BLOCK  ),
    .I_WEIGHTS_IS_1X1            (I_WEIGHTS_IS_1X1           ),
    .I_WEIGHTS_IS_COLS_1_K2      (I_WEIGHTS_IS_COLS_1_K2     ),
    .I_WEIGHTS_IS_CONFIG         (I_WEIGHTS_IS_CONFIG        ),
    .I_WEIGHTS_IS_CIN_LAST       (I_WEIGHTS_IS_CIN_LAST      ),
    .I_WEIGHTS_KERNEL_W_1        (I_WEIGHTS_KERNEL_W_1       ),
    .TUSER_WIDTH_WEIGHTS_OUT(TUSER_WIDTH_WEIGHTS_OUT)
  ) pipe (.*);

  logic [7:0] s_data_weights [S_WEIGHTS_WIDTH /8-1:0];
  logic [WORD_WIDTH-1:0] m_data_weights [CORES-1:0][KERNEL_W_MAX-1:0];

  assign {>>{s_axis_tdata}} = s_data_weights;
  assign m_data_weights = {>>{m_axis_tdata}};

  int status, file_weights;

  string path_weights = "D:/Vision Traffic/soc/mem_yolo/txt/weights_rot_in.txt";
  
  localparam BEATS_CONFIG_1 = K_1 == 0 ? BEATS_CONFIG_1X1_1 : BEATS_CONFIG_3X3_1;
  localparam W_BEATS = 1 + BEATS_CONFIG_1+1 + (K_1+1)*(CIN_1+1);
  localparam W_WORDS = (W_BEATS-1) * KERNEL_W_MAX * CORES + S_WEIGHTS_WIDTH /WORD_WIDTH;
  localparam W_WORDS_PER_BEAT = S_WEIGHTS_WIDTH /WORD_WIDTH;

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