`include "params.v"

module axis_lrelu_engine_tb();
  
  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  localparam IS_1X1  = 0;
  localparam IS_MAX  = 0;
  localparam IS_RELU = 1;

  localparam COLS    = 3;
  localparam BLOCKS  = 3;

  localparam UNITS   = `UNITS  ;
  localparam GROUPS  = `GROUPS ;
  localparam COPIES  = `COPIES ;
  localparam MEMBERS = `MEMBERS;

  localparam WORD_WIDTH_IN     = 32;
  localparam WORD_WIDTH_OUT    = 8 ;
  localparam WORD_WIDTH_CONFIG = 8 ;

  localparam LRELU_ALPHA                = `LRELU_ALPHA               ;
  localparam BEATS_CONFIG_3X3_2         = `BEATS_CONFIG_3X3_1 -1     ; // D(1) + A(2) + B(9*2) -2   = 21 -2 = 19
  localparam BEATS_CONFIG_1X1_2         = `BEATS_CONFIG_1X1_1 -1     ; // D(1) + A(2*3) + B(2*3) -2 = 13 -2 = 11
  localparam BITS_EXP_CONFIG            = `BITS_EXP_CONFIG           ;
  localparam BITS_FRA_CONFIG            = `BITS_FRA_CONFIG           ;
  localparam BITS_EXP_FMA_1             = `BITS_EXP_FMA_1            ;
  localparam BITS_FRA_FMA_1             = `BITS_FRA_FMA_1            ;
  localparam BITS_EXP_FMA_2             = `BITS_EXP_FMA_2            ;
  localparam BITS_FRA_FMA_2             = `BITS_FRA_FMA_2            ;
  localparam LATENCY_FMA_1              = `LATENCY_FMA_1             ;
  localparam LATENCY_FMA_2              = `LATENCY_FMA_2             ;
  localparam LATENCY_FIXED_2_FLOAT      = `LATENCY_FIXED_2_FLOAT     ;
  localparam LATENCY_BRAM               = `LATENCY_BRAM              ;
  localparam I_IS_NOT_MAX               = `I_IS_NOT_MAX              ;
  localparam I_IS_MAX                   = `I_IS_MAX                  ;
  localparam I_IS_1X1                   = `I_IS_1X1                  ;
  localparam I_IS_LRELU                 = `I_IS_LRELU                ;
  localparam I_IS_TOP_BLOCK             = `I_IS_TOP_BLOCK            ;
  localparam I_IS_BOTTOM_BLOCK          = `I_IS_BOTTOM_BLOCK         ;
  localparam I_IS_LEFT_COL              = `I_IS_LEFT_COL             ;
  localparam I_IS_RIGHT_COL             = `I_IS_RIGHT_COL            ;
  localparam TUSER_WIDTH_MAXPOOL_IN     = `TUSER_WIDTH_MAXPOOL_IN    ;
  localparam TUSER_WIDTH_LRELU_FMA_1_IN = `TUSER_WIDTH_LRELU_FMA_1_IN;
  localparam TUSER_WIDTH_LRELU_IN       = `TUSER_WIDTH_LRELU_IN      ;
  localparam DEBUG_CONFIG_WIDTH_LRELU   = `DEBUG_CONFIG_WIDTH_LRELU  ;

  logic aresetn      ;
  logic s_axis_tvalid;
  logic s_axis_tready;
  logic s_axis_tlast ;
  logic m_axis_tvalid;
  logic m_axis_tready;
  logic [MEMBERS * COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_axis_tdata ; // cmgu
  logic [          COPIES * GROUPS * UNITS * WORD_WIDTH_OUT-1:0] m_axis_tdata ; // cgu
  logic [TUSER_WIDTH_LRELU_IN  -1:0] s_axis_tuser ;
  logic [TUSER_WIDTH_MAXPOOL_IN-1:0] m_axis_tuser ;

  logic [WORD_WIDTH_IN  -1:0] s_data_int_cmgu [COPIES-1:0][MEMBERS-1:0][GROUPS-1:0][UNITS-1:0];
  logic [WORD_WIDTH_OUT -1:0] m_data_cgu      [COPIES-1:0][GROUPS-1:0][UNITS-1:0];

  logic [DEBUG_CONFIG_WIDTH_LRELU-1:0] debug_config;
  

  assign {>>{s_axis_tdata}} = s_data_int_cmgu;
  assign m_data_cgu = {>>{m_axis_tdata}};

  axis_lrelu_engine #(
    .WORD_WIDTH_IN (WORD_WIDTH_IN ),
    .WORD_WIDTH_OUT(WORD_WIDTH_OUT),

    .UNITS   (UNITS  ),
    .GROUPS  (GROUPS ),
    .COPIES  (COPIES ),
    .MEMBERS (MEMBERS),

    .LRELU_ALPHA   (LRELU_ALPHA),

    .BEATS_CONFIG_3X3_2 (BEATS_CONFIG_3X3_2),
    .BEATS_CONFIG_1X1_2 (BEATS_CONFIG_1X1_2),

    .BITS_EXP_CONFIG      (BITS_EXP_CONFIG      ),
    .BITS_FRA_CONFIG      (BITS_FRA_CONFIG      ),
    .BITS_EXP_FMA_1       (BITS_EXP_FMA_1       ),
    .BITS_FRA_FMA_1       (BITS_FRA_FMA_1       ),
    .BITS_EXP_FMA_2       (BITS_EXP_FMA_2       ),
    .BITS_FRA_FMA_2       (BITS_FRA_FMA_2       ),
    .LATENCY_FMA_1        (LATENCY_FMA_1        ),
    .LATENCY_FMA_2        (LATENCY_FMA_2        ),
    .LATENCY_FIXED_2_FLOAT(LATENCY_FIXED_2_FLOAT),
    .LATENCY_BRAM         (LATENCY_BRAM         ),

    .I_IS_MAX             (I_IS_MAX            ),
    .I_IS_NOT_MAX         (I_IS_NOT_MAX        ),
    .I_IS_1X1             (I_IS_1X1            ),
    .I_IS_LRELU           (I_IS_LRELU          ),
    .I_IS_TOP_BLOCK       (I_IS_TOP_BLOCK      ),
    .I_IS_BOTTOM_BLOCK    (I_IS_BOTTOM_BLOCK   ),
    .I_IS_LEFT_COL        (I_IS_LEFT_COL       ),
    .I_IS_RIGHT_COL       (I_IS_RIGHT_COL      ),

    .TUSER_WIDTH_LRELU_IN       (TUSER_WIDTH_LRELU_IN      ),
    .TUSER_WIDTH_LRELU_FMA_1_IN (TUSER_WIDTH_LRELU_FMA_1_IN),
    .TUSER_WIDTH_MAXPOOL_IN     (TUSER_WIDTH_MAXPOOL_IN    )
  ) dut (.*);

  int status, file_data_in, file_data_out;
  string data_in_path = "D:/cnn-fpga/data/lrelu_input.txt";
  string data_out_path_1 = "D:/cnn-fpga/data/lrelu_output_1.txt";
  string data_out_path_2 = "D:/cnn-fpga/data/lrelu_output_2.txt";

  int config_beats = 0;
  int data_beats = 0;

  int data_out_beats = 0;
  int times = 0;

  int sub_cores = 0;

  initial begin

    while (1) begin
      @(posedge aclk);

      #(CLK_PERIOD/2);
      if (m_axis_tvalid && m_axis_tready) begin
        for (int c=0; c < COPIES; c++)
          for (int g=0; g < GROUPS; g++)
            for (int u=0; u < UNITS; u++) begin
              $display("saving %d", m_data_cgu[c][g][u]);
              $fdisplay(file_data_out, "%d", signed'(m_data_cgu[c][g][u]));
            end

        if (data_out_beats < COLS*BLOCKS*sub_cores*MEMBERS-1)
          data_out_beats <= data_out_beats + 1;
        else begin
          data_out_beats <= 0;
          $fclose(file_data_out);
          if (times == 0) begin
            file_data_out <= $fopen(data_out_path_2   ,"w");
            times <= times + 1;
          end else begin
            $finish();
          end
        end
        
      end
    end

    
  end

  class Random_Bit;
  rand bit rand_bit;
  constraint c {
    rand_bit dist { 0 := 0, 1 := 1};
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
    file_data_in    = $fopen(data_in_path   ,"r");
    file_data_out   = $fopen(data_out_path_1,"w");

    aresetn       <= 1;
    // m_axis_tready <= 1;
    s_axis_tvalid <= 0;
    s_axis_tlast  <= 0;

    s_axis_tuser [I_IS_1X1    ] <= IS_1X1;
    s_axis_tuser [I_IS_MAX    ] <= IS_MAX;
    s_axis_tuser [I_IS_NOT_MAX] <= 1;
    s_axis_tuser [I_IS_LRELU  ] <= IS_RELU;

    sub_cores <= IS_1X1 ? 3 : 1;

    while (1) begin
      @(posedge aclk);

      if (s_axis_tready) begin
        if (s_axis_tlast) break;

        #1;
        axis_feed_data;
      end
    end

    file_data_in  <= $fopen(data_in_path   ,"r");
    config_beats  <= 0;
    data_beats    <= 0;
    s_axis_tvalid <= 0;
    s_axis_tlast  <= 0;
    s_axis_tuser [I_IS_1X1  ] <= IS_1X1;
    s_axis_tuser [I_IS_LRELU] <= IS_RELU;
    s_axis_tlast  <= 0;
    s_data_int_cmgu  <= '{default:0};
    sub_cores <= IS_1X1 ? 3 : 1;

    @(posedge aclk);

    while (1) begin
      @(posedge aclk);

      if (s_axis_tready) begin
        if (s_axis_tlast) break;

        #1;
        axis_feed_data;
      end
    end

    s_axis_tvalid <= 0;
    s_axis_tlast  <= 0;

  end

  task axis_feed_data;
        s_axis_tvalid <= 1;

        if (config_beats < (IS_1X1 ? BEATS_CONFIG_1X1_2+2 : BEATS_CONFIG_3X3_2+2)) 
          config_beats <= config_beats + 1;

        else begin
          if   (data_beats % (sub_cores*COLS) == 0)  begin
            s_axis_tuser [I_IS_LEFT_COL       ] <= 1;
            s_axis_tuser [I_IS_RIGHT_COL      ] <= 0;
          end
          else if (data_beats % (sub_cores*COLS) == COLS-1)  begin
            s_axis_tuser [I_IS_LEFT_COL       ] <= 0;
            s_axis_tuser [I_IS_RIGHT_COL      ] <= 1;
          end
          else begin
            s_axis_tuser [I_IS_LEFT_COL       ] <= 0;
            s_axis_tuser [I_IS_RIGHT_COL      ] <= 0;
          end

          if   (data_beats / (sub_cores*COLS) == 0)  begin
            s_axis_tuser [I_IS_TOP_BLOCK      ] <= 1;
            s_axis_tuser [I_IS_BOTTOM_BLOCK   ] <= 0;
          end
          else if (data_beats / (sub_cores*COLS) == BLOCKS-1)  begin
            s_axis_tuser [I_IS_TOP_BLOCK      ] <= 0;
            s_axis_tuser [I_IS_BOTTOM_BLOCK   ] <= 1;
          end
          else begin
            s_axis_tuser [I_IS_TOP_BLOCK      ] <= 0;
            s_axis_tuser [I_IS_BOTTOM_BLOCK   ] <= 0;
          end

          if (data_beats == sub_cores*COLS*BLOCKS-1) s_axis_tlast <= 1;
          
          data_beats <= data_beats + 1;
        end

        for (int c=0; c < COPIES; c++)
          for (int m=0; m < MEMBERS; m++)
            for (int g=0; g < GROUPS; g++)
              for (int u=0; u < UNITS; u++)
                status = $fscanf(file_data_in,"%d\n",s_data_int_cmgu[c][m][g][u]);
  endtask

endmodule