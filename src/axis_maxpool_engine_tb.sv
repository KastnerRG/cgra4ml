module axis_maxpool_engine_tb();
  
  timeunit 1ns;
  timeprecision 1ps;
  logic aclk;
  localparam CLK_PERIOD = 10;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  localparam UNITS      = 4;
  localparam GROUPS     = 1;
  localparam MEMBERS    = 4;
  localparam WORD_WIDTH = 8;

  localparam IS_1X1      = 1;

  localparam KERNEL_H_MAX = 3; // odd
  localparam KERNEL_W_MAX = 3; // odd
  localparam UNITS_EDGES  = UNITS + KERNEL_H_MAX-1;
  localparam SUB_MEMBERS = IS_1X1 ? KERNEL_W_MAX*MEMBERS : MEMBERS;

  localparam I_IS_NOT_MAX = 0;
  localparam I_IS_MAX     = I_IS_NOT_MAX + 1;
  localparam I_IS_1X1     = I_IS_MAX + 1;

  localparam TUSER_WIDTH  = I_IS_1X1 + 1;

  typedef logic signed [WORD_WIDTH-1:0] word_t;

  logic aresetn;
  logic s_axis_tvalid, s_axis_tready, m_axis_tready, m_axis_tvalid, m_axis_tlast;
  
  logic [TUSER_WIDTH-1:0] s_axis_tuser;

  logic [GROUPS*UNITS*2*WORD_WIDTH-1:0]       s_axis_tdata_flat_cgu;
  logic [GROUPS*UNITS_EDGES*2*WORD_WIDTH-1:0] m_axis_tdata_flat_cgu;
  logic [GROUPS*UNITS_EDGES*2-1:0]            m_axis_tkeep_flat_cgu;

  logic signed [WORD_WIDTH-1:0] s_axis_tdata_cgu [1:0][GROUPS-1:0][UNITS-1:0];
  logic signed [WORD_WIDTH-1:0] m_axis_tdata_cgu [1:0][GROUPS-1:0][UNITS_EDGES-1:0];
  logic                         m_axis_tkeep_cgu [1:0][GROUPS-1:0][UNITS_EDGES-1:0];

  assign {>>{s_axis_tdata_flat_cgu}} = s_axis_tdata_cgu;
  assign m_axis_tdata_cgu = {>>{m_axis_tdata_flat_cgu}};
  assign m_axis_tkeep_cgu = {>>{m_axis_tkeep_flat_cgu}};

  string path_in, path_out;
  int file_in, file_out, status, s_words, m_words, S_WORDS, M_WORDS, start_in,start_out;
  int k, max_factor, im_height, im_width, im_cin;
  logic is_1x1, is_max, is_not_max;    

  axis_maxpool_engine #(
    .UNITS            (UNITS           ),
    .GROUPS           (GROUPS          ),
    .MEMBERS          (MEMBERS         ),
    .WORD_WIDTH       (WORD_WIDTH      ),
    .KERNEL_H_MAX     (KERNEL_H_MAX    ),
    .KERNEL_W_MAX     (KERNEL_W_MAX    ),
    .I_IS_NOT_MAX     (I_IS_NOT_MAX    ),
    .I_IS_MAX         (I_IS_MAX        ),
    .I_IS_1X1         (I_IS_1X1        )
  )dut(
    .aclk         (aclk          ),
    .aresetn      (aresetn       ),
    .s_axis_tvalid(s_axis_tvalid ),
    .s_axis_tready(s_axis_tready ),
    .s_axis_tdata (s_axis_tdata_flat_cgu),
    .s_axis_tuser (s_axis_tuser  ),
    .m_axis_tvalid(m_axis_tvalid ),
    .m_axis_tready(m_axis_tready ),
    .m_axis_tdata (m_axis_tdata_flat_cgu),
    .m_axis_tkeep (m_axis_tkeep_flat_cgu),
    .m_axis_tlast (m_axis_tlast  )
  );

  task axis_feed;
    @(posedge aclk);
    if (start_in) begin
      if (s_axis_tready) begin
        if (s_words < S_WORDS) begin
          #1;
          s_axis_tvalid <= 1;
          for (int c=0; c < 2; c++)
            for (int g=0; g<GROUPS; g++)
              for (int u=0; u<UNITS; u++) begin
                if (~$feof(file_in))
                  status = $fscanf(file_in,"%d\n", s_axis_tdata_cgu[c][g][u]);
                s_words = s_words + 1;
              end
          s_axis_tuser[I_IS_MAX    ] <= is_max;
          s_axis_tuser[I_IS_NOT_MAX] <= is_not_max;
          s_axis_tuser[I_IS_1X1    ] <= is_1x1;
        end
        else begin
          s_axis_tvalid <= 0;
          s_words       <= 0;
          start_in      <= 0;
        end
      end
    end
  endtask

  task axis_receive;
    @(posedge aclk);
    #(CLK_PERIOD/2);
    if (start_out) begin
      if (m_axis_tvalid) begin
        if (m_words < M_WORDS) begin
          for (int c=0; c < 2; c++) begin
            for (int g=0; g < GROUPS; g++) begin
              for (int u=0; u < UNITS_EDGES; u++) begin
                if (m_axis_tkeep_cgu[c][g][u]) begin
                  $fdisplay(file_out, "%d", signed'(m_axis_tdata_cgu[c][g][u]));
                  m_words = m_words + 1;
                end
              end
            end
          end
        end
        else begin
          m_words   <= 0;
          $fclose(file_out);
          start_out  = 0;
        end
      end
    end
  endtask

  initial begin
    forever axis_feed;
  end
  initial begin
    forever axis_receive;
  end

  initial begin
    aresetn       <= 1;
    m_axis_tready <= 1;
    s_axis_tvalid <= 0;

    // // 3x3 Non maxpool
    // k          = 3;
    // max_factor = 1;
    // is_not_max = 1;
    // im_height  = 64;
    // im_width   = 96;
    // im_cin     = 64;
    // path_in      = "D:/Vision Traffic/soc/data/3_lrelu_out_fpga.txt";
    // path_out     = "D:/Vision Traffic/soc/data/3_max_unit_out_fpga.txt";

    // S_WORDS   = (im_height/UNITS/max_factor)*im_width*(KERNEL_W_MAX/k)*MEMBERS*2*GROUPS*UNITS;
    // M_WORDS   = (S_WORDS/UNITS)*UNITS_EDGES/(max_factor**2);
    // is_max    = max_factor != 1;
    // is_1x1    = k == 1;
    // start_in  = 1;
    // start_out = 1;
    // s_words   = 0;
    // m_words   = 0;

    // file_in   = $fopen(path_in ,"r");
    // file_out  = $fopen(path_out,"w");

    // wait(start_out==0);
    // $finish();

    // 3x3 maxpool
    k          = 3;
    max_factor = 2;
    is_not_max = 0;
    im_height  = 256;
    im_width   = 384;
    im_cin     = 3;
    path_in    = "D:/Vision Traffic/soc/data/1_lrelu_out_fpga.txt";
    path_out   = "D:/Vision Traffic/soc/data/1_max_unit_out_fpga.txt";

    S_WORDS   = (im_height/UNITS/max_factor)*im_width*(KERNEL_W_MAX/k)*MEMBERS*2*GROUPS*UNITS;
    M_WORDS   = (S_WORDS/UNITS)*UNITS_EDGES/(max_factor**2);
    is_max    = max_factor != 1;
    is_1x1    = k == 1;
    start_in  = 1;
    start_out = 1;
    s_words   = 0;
    m_words   = 0;

    file_in   = $fopen(path_in ,"r");
    file_out  = $fopen(path_out,"w");

    wait(start_out==0);
    $finish();

  end

endmodule