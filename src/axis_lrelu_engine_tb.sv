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

  localparam WORD_WIDTH_IN     = 26;
  localparam WORD_WIDTH_OUT    = 8 ;
  localparam WORD_WIDTH_CONFIG = 8 ;

  localparam UNITS   = 8;
  localparam GROUPS  = 2;
  localparam COPIES  = 2;
  localparam MEMBERS = 8;

  localparam CONFIG_BEATS_3X3_1 = 21-1;
  localparam CONFIG_BEATS_1X1_1 = 9 -1;

  localparam LATENCY_FIXED_2_FLOAT =  6;
  localparam LATENCY_FLOAT_32      = 16;

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

  logic [WORD_WIDTH_IN  -1:0] s_data_mcgu [MEMBERS-1:0][COPIES-1:0][GROUPS-1:0][UNITS-1:0];
  logic [WORD_WIDTH_OUT -1:0] m_data_cgu               [COPIES-1:0][GROUPS-1:0][UNITS-1:0];

  assign {>>{s_axis_tdata}} = s_data_mcgu;
  assign m_data_cgu = {>>{m_axis_tdata}};

  /*
    Build config
  */
  localparam K_MEMBERS = IS_3X3 ? 1 : 3;
  localparam B_VALS    = IS_3X3 ? 3 : 1;

  shortreal d_sr;
  shortreal a_sr [K_MEMBERS-1:0][MEMBERS-1:0][COPIES-1:0][GROUPS-1:0];
  shortreal b_sr [K_MEMBERS-1:0][MEMBERS-1:0][COPIES-1:0][GROUPS-1:0][B_VALS-1:0][B_VALS-1:0]; //clr_mtb
  shortreal s_config_sr_cgm   [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0] = '{default:0};

  localparam BEATS = 16 / WORD_WIDTH_CONFIG;
  localparam VALS_CONFIG = MEMBERS / BEATS;
  logic [15:0] s_config_f16_cgm  [COPIES-1:0][GROUPS-1:0][MEMBERS-1:0];
  logic [15:0] s_config_f16_mcg  [MEMBERS-1:0][COPIES-1:0][GROUPS-1:0];
  logic [MEMBERS*COPIES*GROUPS*16-1:0] s_config_f16_mcg_flat;
  logic [15:0] s_config_f16_bvcg [BEATS -1:0][VALS_CONFIG-1:0][COPIES-1:0][GROUPS-1:0];
  logic [15:0] s_config_f16_bcgv [BEATS -1:0][COPIES-1:0][GROUPS-1:0][VALS_CONFIG-1:0];
  logic [MEMBERS*COPIES*GROUPS*WORD_WIDTH_CONFIG-1:0] s_config_f16_bcgv_flat;
  logic [WORD_WIDTH_CONFIG-1 :0] s_config_bcgm     [BEATS -1:0][COPIES-1 :0][GROUPS-1:0][MEMBERS-1:0];
  logic [WORD_WIDTH_IN-1 :0]     s_config_pad_bmcgu    [BEATS -1:0][MEMBERS-1:0][COPIES-1:0][GROUPS-1:0][UNITS-1:0];

  generate
    assign {>>{s_config_f16_mcg_flat}} = s_config_f16_mcg;
    assign s_config_f16_bvcg = {>>{s_config_f16_mcg_flat}};
    assign {>>{s_config_f16_bcgv_flat}} = s_config_f16_bcgv;
    assign s_config_bcgm = {>>{s_config_f16_bcgv_flat}};


    for (genvar c=0; c<COPIES; c++) begin
      for (genvar g=0; g<GROUPS; g++) begin
        for (genvar m=0; m<MEMBERS; m++) begin
          assign s_config_f16_cgm[c][g][m] = float_32_to_16($shortrealtobits(s_config_sr_cgm[c][g][m]));
          assign s_config_f16_mcg[m][c][g] = s_config_f16_cgm [c][g][m];
        end

        for (genvar b=0; b<BEATS; b++) begin
          for (genvar v=0; v<VALS_CONFIG; v++) begin
            assign s_config_f16_bcgv [b][c][g][v] = s_config_f16_bvcg [b][v][c][g];
          end
          for (genvar m=0; m<MEMBERS; m++) begin
            assign s_config_pad_bmcgu[b][m][c][g][0] = WORD_WIDTH_IN'(s_config_bcgm[b][c][g][m]);
          end
        end
      end
    end
  endgenerate

  task load_config;
    // Pass D
    s_config_sr_cgm[0][0][0] <= d_sr;
    @(posedge aclk);
    s_data_mcgu <= s_config_pad_bmcgu [0];

    // Pass A
    for (int k=0; k<K_MEMBERS; k++) begin
      for (int c=0; c<COPIES; c++)
        for (int g=0; g<GROUPS; g++)
          for (int m=0; m<MEMBERS; m++)
            s_config_sr_cgm [c][g][m] <= a_sr [k][m][c][g];

      for (int b=0; b<BEATS; b++) load_config_beat(b);
    end

    // Pass B
    for (int clr=0; clr<B_VALS; clr++)
      for (int mtb=0; mtb<B_VALS; mtb++)
        for (int k=0; k<K_MEMBERS; k++) begin
          for (int c=0; c<COPIES; c++)
            for (int g=0; g<GROUPS; g++)
              for (int m=0; m<MEMBERS; m++)
                s_config_sr_cgm [c][g][m] <= b_sr [k][m][c][g][clr][mtb];
          
          for (int b=0; b<BEATS; b++) load_config_beat(b);
        end
  endtask

  task load_config_beat (input int b);
      @(posedge aclk);
      s_data_mcgu   <= s_config_pad_bmcgu [b];
      s_axis_tvalid <= 1;
  endtask

  axis_lrelu_engine #(
    .WORD_WIDTH_IN (WORD_WIDTH_IN ),
    .WORD_WIDTH_OUT(WORD_WIDTH_OUT),

    .UNITS   (UNITS  ),
    .GROUPS  (GROUPS ),
    .COPIES  (COPIES ),
    .MEMBERS (MEMBERS),

    .CONFIG_BEATS_3X3_1 (CONFIG_BEATS_3X3_1),
    .CONFIG_BEATS_1X1_1 (CONFIG_BEATS_1X1_1),

    .LATENCY_FIXED_2_FLOAT(LATENCY_FIXED_2_FLOAT),
    .LATENCY_FLOAT_32     (LATENCY_FLOAT_32     ),

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
    s_axis_tuser [I_LRELU_IS_TOP      ] <= 1;
    s_axis_tuser [I_LRELU_IS_BOTTOM   ] <= 1;
    s_axis_tuser [I_LRELU_IS_LEFT     ] <= 1;
    s_axis_tuser [I_LRELU_IS_RIGHT    ] <= 0;

    // d = 

    @(posedge aclk);
    
  end

endmodule