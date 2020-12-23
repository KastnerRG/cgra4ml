module axis_lrelu_engine_tb();
  
  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  localparam IS_3X3  = 1;
  localparam IS_RELU = 1;

  localparam WORD_WIDTH_IN     = 32;
  localparam WORD_WIDTH_OUT    = 8 ;
  localparam WORD_WIDTH_CONFIG = 8 ;

  localparam UNITS   = 3;
  localparam GROUPS  = 1;
  localparam COPIES  = 1;
  localparam MEMBERS = 4;

  localparam ALPHA = 16'd11878;

  localparam CONFIG_BEATS_3X3_1 = 19; // D(1) + A(2) + B(9*2) -2
  localparam CONFIG_BEATS_1X1_1 = 9 -1-1;

  localparam LATENCY_FIXED_2_FLOAT =  6;
  localparam LATENCY_FLOAT_32      = 16;
  localparam BRAM_LATENCY          =  2;

  localparam BITS_CONV_CORE       = $clog2(GROUPS * COPIES * MEMBERS);
  localparam I_IS_3X3             = BITS_CONV_CORE + 0;  
  localparam I_MAXPOOL_IS_MAX     = BITS_CONV_CORE + 1;
  localparam I_MAXPOOL_IS_NOT_MAX = BITS_CONV_CORE + 2;
  localparam I_LRELU_IS_LRELU     = BITS_CONV_CORE + 3;
  localparam I_LRELU_IS_TOP       = BITS_CONV_CORE + 4;
  localparam I_LRELU_IS_BOTTOM    = BITS_CONV_CORE + 5;
  localparam I_LRELU_IS_LEFT      = BITS_CONV_CORE + 6;
  localparam I_LRELU_IS_RIGHT     = BITS_CONV_CORE + 7;

  localparam TUSER_WIDTH_LRELU       = BITS_CONV_CORE + 8;
  localparam TUSER_WIDTH_LRELU_FMA_1 = BITS_CONV_CORE + 4;
  localparam TUSER_WIDTH_MAXPOOL     = BITS_CONV_CORE + 3;

  logic aresetn      ;
  logic s_axis_tvalid;
  logic s_axis_tready;
  logic s_axis_tlast ;
  logic m_axis_tvalid;
  logic m_axis_tready;
  logic [MEMBERS * COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_axis_tdata ; // mcgu
  logic [          COPIES * GROUPS * UNITS * WORD_WIDTH_OUT-1:0] m_axis_tdata ; // cgu
  logic [TUSER_WIDTH_LRELU  -1:0] s_axis_tuser ;
  logic [TUSER_WIDTH_MAXPOOL-1:0] m_axis_tuser ;

  logic [WORD_WIDTH_IN  -1:0] s_data_int_mcgu [MEMBERS-1:0][COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [WORD_WIDTH_OUT -1:0] m_data_cgu               [COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  

  assign {>>{s_axis_tdata}} = s_data_int_mcgu;
  assign m_data_cgu = {>>{m_axis_tdata}};

  axis_lrelu_engine #(
    .WORD_WIDTH_IN (WORD_WIDTH_IN ),
    .WORD_WIDTH_OUT(WORD_WIDTH_OUT),

    .UNITS   (UNITS  ),
    .GROUPS  (GROUPS ),
    .COPIES  (COPIES ),
    .MEMBERS (MEMBERS),

    .ALPHA   (ALPHA),

    .CONFIG_BEATS_3X3_1 (CONFIG_BEATS_3X3_1),
    .CONFIG_BEATS_1X1_1 (CONFIG_BEATS_1X1_1),

    .LATENCY_FIXED_2_FLOAT(LATENCY_FIXED_2_FLOAT),
    .LATENCY_FLOAT_32     (LATENCY_FLOAT_32     ),
    .BRAM_LATENCY         (BRAM_LATENCY         ),

    .BITS_CONV_CORE       (BITS_CONV_CORE      ),
    .I_IS_3X3             (I_IS_3X3            ),
    .I_MAXPOOL_IS_MAX     (I_MAXPOOL_IS_MAX    ),
    .I_MAXPOOL_IS_NOT_MAX (I_MAXPOOL_IS_NOT_MAX),
    .I_LRELU_IS_LRELU     (I_LRELU_IS_LRELU    ),
    .I_LRELU_IS_TOP       (I_LRELU_IS_TOP      ),
    .I_LRELU_IS_BOTTOM    (I_LRELU_IS_BOTTOM   ),
    .I_LRELU_IS_LEFT      (I_LRELU_IS_LEFT     ),
    .I_LRELU_IS_RIGHT     (I_LRELU_IS_RIGHT    ),

    .TUSER_WIDTH_LRELU       (TUSER_WIDTH_LRELU      ),
    .TUSER_WIDTH_LRELU_FMA_1 (TUSER_WIDTH_LRELU_FMA_1),
    .TUSER_WIDTH_MAXPOOL     (TUSER_WIDTH_MAXPOOL    )
  ) dut (.*);

  int status, file_data_in, file_data_out;
  string data_in_path = "D:/Vision Traffic/soc/python/fpga_support/lrelu_input.txt";
  string data_out_path = "D:/Vision Traffic/soc/python/fpga_support/lrelu_output.txt";

  int config_beats = 0;
  int data_beats = 0;

  localparam COLS   = 3;
  localparam BLOCKS = 3;

  initial begin
    file_data_in    = $fopen(data_in_path   ,"r");
    file_data_out   = $fopen(data_out_path   ,"w");
  end

  initial begin

    while (1) begin
      @(posedge aclk);

      #(CLK_PERIOD/2);
      if (m_axis_tvalid) begin
          for (int c=0; c < COPIES; c++)
            for (int g=0; g < GROUPS; g++)
              for (int u=0; u < UNITS; u++) begin
                $display("saving %d", m_data_cgu[c][g][u]);
                $fdisplay(file_data_out, "%d", signed'(m_data_cgu[c][g][u]));
              end
      end
    end

    
  end

  initial begin
    aresetn       <= 1;
    m_axis_tready <= 1;
    s_axis_tvalid <= 0;
    s_axis_tlast  <= 0;

    s_axis_tuser [BITS_CONV_CORE-1:0  ] <= GROUPS * COPIES * MEMBERS -1;
    s_axis_tuser [I_IS_3X3            ] <= IS_3X3;
    s_axis_tuser [I_MAXPOOL_IS_MAX    ] <= 0;
    s_axis_tuser [I_MAXPOOL_IS_NOT_MAX] <= 1;
    s_axis_tuser [I_LRELU_IS_LRELU    ] <= IS_RELU;

    while (1) begin
      @(posedge aclk);
      #1;
      if ($feof(file_data_in)) break;
      else  axis_feed_data;
    end

    // $finish();

    @(posedge aclk);
    config_beats  <= 0;
    data_beats    <= 0;
    s_axis_tvalid <= 0;
    s_axis_tuser  <= 0;
    s_axis_tlast  <= 0;
    s_data_int_mcgu  <= '{default:0};

    repeat(300) @(posedge aclk);
    $fclose(file_data_out);
    $display("closing file");
    $finish();

  end

  task axis_feed_data;
    if (s_axis_tready) begin
        s_axis_tvalid <= 1;

        if   (config_beats != 21) config_beats <= config_beats + 1;
        else begin
          if   (data_beats % COLS == 0)  begin
            s_axis_tuser [I_LRELU_IS_LEFT     ] <= 1;
            s_axis_tuser [I_LRELU_IS_RIGHT    ] <= 0;
          end
          else if (data_beats % COLS == COLS-1)  begin
            s_axis_tuser [I_LRELU_IS_LEFT     ] <= 0;
            s_axis_tuser [I_LRELU_IS_RIGHT    ] <= 1;
          end
          else begin
            s_axis_tuser [I_LRELU_IS_LEFT     ] <= 0;
            s_axis_tuser [I_LRELU_IS_RIGHT    ] <= 0;
          end

          if   (data_beats / COLS == 0)  begin
            s_axis_tuser [I_LRELU_IS_TOP      ] <= 1;
            s_axis_tuser [I_LRELU_IS_BOTTOM   ] <= 0;
          end
          else if (data_beats / COLS == BLOCKS-1)  begin
            s_axis_tuser [I_LRELU_IS_TOP      ] <= 0;
            s_axis_tuser [I_LRELU_IS_BOTTOM   ] <= 1;
          end
          else begin
            s_axis_tuser [I_LRELU_IS_TOP      ] <= 0;
            s_axis_tuser [I_LRELU_IS_BOTTOM   ] <= 0;
          end

          if (data_beats == UNITS*MEMBERS*COLS*BLOCKS-1) s_axis_tlast <= 1;
          
          data_beats <= data_beats + 1;
        end

        for (int m=0; m < MEMBERS; m++)
          for (int c=0; c < COPIES; c++)
            for (int g=0; g < GROUPS; g++)
              for (int u=0; u < UNITS; u++)
                status = $fscanf(file_data_in,"%d\n",s_data_int_mcgu[m][c][g][u]);
    end
  endtask

endmodule