`timescale 10ns / 1ns

module axis_conv_engine_tb # ();

  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  logic clk;
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk <= ~clk;
  end

  localparam IS_1X1    =  0 ;
  localparam KERNEL_W  =  3 ;
  localparam KERNEL_H  =  3 ;
  localparam IS_MAX    =  0 ; 
  localparam IS_RELU   =  0 ;

  localparam IM_HEIGHT   =  2 ;
  localparam IM_WIDTH    =  4 ;
  localparam IM_CIN      =  2 ;   // 3 CIN + 1 > 2(A-1)-1 => CIN > 2(A-2)/3 => CIN > 2(19-2)/3 => CIN > 11.33 => CIN_min = 12
  localparam IM_BLOCKS   = IM_HEIGHT / UNITS;
  localparam UNITS_EDGES = UNITS + (KERNEL_H_MAX-1);

  localparam CORES   = 1 ;
  localparam UNITS   = 2 ;

  localparam WORD_WIDTH_IN  =  8 ; 
  localparam WORD_WIDTH_OUT = 25 ; 

  localparam ACCUMULATOR_DELAY  =  2 ;
  localparam MULTIPLIER_DELAY   =  3 ;

  localparam KERNEL_W_MAX   =  3 ; 
  localparam KERNEL_H_MAX   =  3 ;   // odd number

  localparam IM_CIN_MAX     = 1024;
  localparam IM_COLS_MAX    = 1024;
  localparam BITS_IM_CIN    = $clog2(IM_CIN_MAX);
  localparam BITS_IM_COLS   = $clog2(IM_COLS_MAX);
  localparam BITS_KERNEL_W  = $clog2(KERNEL_W_MAX   + 1);
  localparam BITS_KERNEL_H  = $clog2(KERNEL_H_MAX   + 1);

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

  localparam I_IS_LEFT_COL     = I_KERNEL_W_1      + BITS_KERNEL_W;
  localparam I_IS_RIGHT_COL    = I_IS_LEFT_COL     + 1;

  localparam TUSER_WIDTH_LRELU_IN = 1 + I_IS_RIGHT_COL;
  localparam TUSER_WIDTH_CONV_IN  = BITS_KERNEL_W + I_KERNEL_W_1;
     
  string    im_in_path   = "D:/Vision Traffic/soc/mem_yolo/txt/1_im.txt";
  string    im_out_path  = "D:/Vision Traffic/soc/mem_yolo/txt/1_im_out_fpga.txt";
  string    weights_path = "D:/Vision Traffic/soc/mem_yolo/txt/1_wb.txt";
    

  logic resetn;
  logic clken;
  logic start;

  logic s_valid ;
  logic s_ready ;
  logic s_weights_valid;
  logic s_weights_ready;
  logic [TUSER_WIDTH_CONV_IN-1:0] s_user;
  logic [WORD_WIDTH_IN   -1:0] s_pixels_data  [UNITS_EDGES-1: 0];
  logic [WORD_WIDTH_IN   -1:0] s_weights_data [CORES-1:0][KERNEL_W_MAX-1:0];
                                                                                        
  logic m_valid;
  logic m_last ;
  logic [WORD_WIDTH_OUT   -1: 0] m_data       [CORES-1:0][UNITS-1:0];
  logic [TUSER_WIDTH_LRELU_IN-1: 0] m_user;

  logic [BITS_KERNEL_W  -1:0] s_user_kernel_w_1;
  assign s_user [I_KERNEL_W + BITS_KERNEL_W-1 : I_KERNEL_W] = s_user_kernel_w_1;

                                                                                         
  conv_engine # (
    .CORES                (CORES               ),
    .UNITS                (UNITS               ),
    .WORD_WIDTH_IN        (WORD_WIDTH_IN       ),
    .WORD_WIDTH_OUT       (WORD_WIDTH_OUT      ),
    .ACCUMULATOR_DELAY    (ACCUMULATOR_DELAY   ), 
    .MULTIPLIER_DELAY     (MULTIPLIER_DELAY    ), 
    .KERNEL_W_MAX         (KERNEL_W_MAX        ),  
    .KERNEL_H_MAX         (KERNEL_H_MAX        ), 
    .IM_CIN_MAX           (IM_CIN_MAX          ), 
    .IM_COLS_MAX          (IM_COLS_MAX         ), 
    .I_IS_NOT_MAX         (I_IS_NOT_MAX        ), 
    .I_IS_MAX             (I_IS_MAX            ), 
    .I_IS_LRELU           (I_IS_LRELU          ),
    .I_IS_TOP_BLOCK       (I_IS_TOP_BLOCK      ),  
    .I_IS_BOTTOM_BLOCK    (I_IS_BOTTOM_BLOCK   ),  
    .I_IS_1X1             (I_IS_1X1            ),  
    .I_IS_COLS_1_K2       (I_IS_COLS_1_K2      ),         
    .I_IS_CONFIG          (I_IS_CONFIG         ),
    .I_WEIGHTS_IS_ACC_LAST(I_WEIGHTS_IS_ACC_LAST),
    .I_KERNEL_W_1         (I_KERNEL_W_1        ),
    .TUSER_WIDTH_CONV_IN  (TUSER_WIDTH_CONV_IN ),  
    .TUSER_WIDTH_LRELU_IN (TUSER_WIDTH_LRELU_IN)
  )
  engine (.*);

  int status, file_im_out, file_im_in, file_weights;
  int im_rotate_count    = 0;
  int w_rotate_count     = 0;
  int wb_beats_count     = 0;
  int im_in_beats_count  = 0;
  int im_out_beats_count = 0;

  bit done_feed = 0;

  initial begin
    file_im_in   = $fopen(im_in_path   ,"r");
    file_weights = $fopen(weights_path ,"r");
    file_im_out  = $fopen(im_out_path  ,"w");
  end

  // CLOCK GENERATION
  always begin
    #(CLK_PERIOD/2);
    clk <= ~clk;
  end

  // Save outputs to file
  always @ (posedge clk) begin
    #(CLK_PERIOD/2);
    if (m_valid) begin
      im_out_beats_count = im_out_beats_count + 1;

      for (int c=0; c < CORES; c++)
        for (int u=0; u < UNITS; u++)
          $fdisplay(file_im_out, "%d", m_data[c][u]);
    end
  end

  /*
    Restart image file for every column & feed pixels
  */
  always @ (posedge clk) begin
    // #1;
    if (!done_feed) begin

      axis_feed_weights;

      if (status != 1 && $feof(file_weights)) begin

        $fclose(file_weights);
        file_weights = $fopen(weights_path,"r");

        if (w_rotate_count == IM_WIDTH * IM_BLOCKS - 1) // One COUT done
            w_rotate_count = 0;
        else                                      // One col done
            w_rotate_count = w_rotate_count + 1;

        axis_feed_weights;
      end
    end
  end

  initial begin
    resetn         <= 0;
    s_pixels_valid <= 0;
    s_weights_valid<= 0;

    s_user_cores      <= CORES    -1;
    s_user_cin_1      <= IM_CIN   -1;
    s_user_cols_1     <= IM_WIDTH -1;
    s_user_kernel_w_1 <= KERNEL_W -1;
    s_user_kernel_h_1 <= KERNEL_H -1;

    s_user [I_IS_1X1        ] <= I_IS_1X1;
    s_user [I_IS_LRELU] <= IS_RELU;
    s_user [I_IS_MAX] <= IS_MAX;
 
    @(posedge clk);
    #(CLK_PERIOD*3)
    @(posedge clk);

    resetn <= 1;
    start  <= 1;
    clken  <= 1;

    @(posedge clk);
    start <= 0;
    @(posedge clk);
    #(CLK_PERIOD*3);

    /*
        Restart image file for every output channel & feed pixels
    */
    while(1) begin
      @(posedge clk);
      // #1;

      axis_feed_pixels;

      if (status != 1 && $feof(file_im_in)) begin
        s_pixels_valid <= 0;
        break;
      end
    end

    /*
        Wait for all im_out beats to come out and close files
    */
    
    while(1) begin
      @(posedge clk);
      if (im_out_beats_count > IM_WIDTH * IM_BLOCKS - 1)
        break;
    end

    $fclose(file_im_in);
    $fclose(file_weights);
    $fclose(file_im_out);
    done_feed = 1;

  end
  
  /*
    Feed weights according to AXIS protocol
  */
  task axis_feed_weights;
  begin
    if (s_weights_ready) begin
      s_weights_valid <= 1;
      wb_beats_count = wb_beats_count + 1;

      for (int c=0; c < CORES; c++)
        for (int w=0; w < KERNEL_W_MAX; w++)
          status = $fscanf(file_weights,"%d\n",s_weights_data[c][w]);
    end
  end
  endtask

  /*
  Feed pixels according to AXIS protocol
  */
  task axis_feed_pixels;
  begin
    if (s_pixels_ready) begin
      s_pixels_valid      <= 1;
      im_in_beats_count   = im_in_beats_count + 1;

      for (int u=0; u < UNITS_EDGES; u++)
        status = $fscanf(file_im_in,"%d\n",s_pixels_data[u]);
            
    end
  end
  endtask

endmodule