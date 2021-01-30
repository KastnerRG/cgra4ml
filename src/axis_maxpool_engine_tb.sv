module axis_maxpool_engine_tb();
  
  timeunit 1ns;
  timeprecision 1ps;
  logic aclk;
  localparam CLK_PERIOD = 10;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  localparam UNITS      = 3;
  localparam GROUPS     = 2;
  localparam MEMBERS    = 8;
  localparam WORD_WIDTH = 8;

  localparam IS_1X1      = 1;
  localparam SUB_MEMBERS = IS_1X1 ? KERNEL_W_MAX*MEMBERS : MEMBERS;

  localparam KERNEL_H_MAX = 3; // odd
  localparam KERNEL_W_MAX = 3; // odd
  localparam UNITS_EDGES  = UNITS + KERNEL_H_MAX-1;

  localparam I_IS_NOT_MAX = 0;
  localparam I_IS_MAX     = I_IS_NOT_MAX + 1;
  localparam I_IS_1X1     = I_IS_MAX + 1;

  localparam TUSER_WIDTH  = I_IS_1X1 + 1;

  typedef logic signed [WORD_WIDTH-1:0] word_t;

  logic aresetn;
  logic s_valid, s_ready, m_ready, m_valid, m_last;
  
  logic [TUSER_WIDTH-1:0] s_user;

  logic [GROUPS*UNITS*2*WORD_WIDTH-1:0] s_data_flat_cgu;
  logic [GROUPS*UNITS_EDGES*2*WORD_WIDTH-1:0] m_data_flat_cgu;
  logic [GROUPS*UNITS_EDGES*2-1:0]            m_keep_flat_cgu;

  logic signed [WORD_WIDTH-1:0] s_data_cgu [1:0][GROUPS-1:0][UNITS-1:0];
  logic signed [WORD_WIDTH-1:0] m_data_cgu [1:0][GROUPS-1:0][UNITS_EDGES-1:0];
  logic                         m_keep_cgu [1:0][GROUPS-1:0][UNITS_EDGES-1:0];

  assign {>>{s_data_flat_cgu}} = s_data_cgu;
  assign m_data_cgu = {>>{m_data_flat_cgu}};
  assign m_keep_cgu = {>>{m_keep_flat_cgu}};

  logic signed [WORD_WIDTH-1:0] s_data_guc [GROUPS-1:0][UNITS-1:0][1:0];
  logic signed [WORD_WIDTH-1:0] m_data_guc [GROUPS-1:0][UNITS_EDGES-1:0][1:0];
  logic                         m_keep_guc [GROUPS-1:0][UNITS_EDGES-1:0][1:0];


  generate
    for (genvar c = 0; c < 2; c++) begin
      for (genvar g = 0; g < GROUPS; g++) begin
        for (genvar u = 0; u < UNITS; u++) begin
          assign s_data_cgu[c][g][u] = s_data_guc[g][u][c];
        end
        for (genvar u = 0; u < UNITS_EDGES; u++) begin
          assign m_data_guc[g][u][c] = m_data_cgu[c][g][u];
          assign m_keep_guc[g][u][c] = m_keep_cgu[c][g][u];
        end
      end
    end
  endgenerate

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
    .aclk         (aclk       ),
    .aresetn      (aresetn    ),
    .s_axis_tvalid(s_valid    ),
    .s_axis_tready(s_ready    ),
    .s_axis_tdata (s_data_flat_cgu),
    .s_axis_tuser (s_user     ),
    .m_axis_tvalid(m_valid    ),
    .m_axis_tready(m_ready    ),
    .m_axis_tdata (m_data_flat_cgu),
    .m_axis_tkeep (m_keep_flat_cgu),
    .m_axis_tlast (m_last     )
  );

  task fill_data (input int init, input logic is_max, is_not_max, is_1x1);
    @(posedge aclk);
    foreach (s_data_guc[g,u,c]) s_data_guc[g][u][c] <= init + 10*u + c;

    s_valid      <= 1;
    s_user[I_IS_MAX    ] <= is_max;
    s_user[I_IS_NOT_MAX] <= is_not_max;
    s_user[I_IS_1X1    ] <= is_1x1;
  endtask

  initial begin
    aresetn <= 1;
    m_ready <= 1;
    s_valid <= 0;

    // NO MAXPOOL

    for (int i=0; i < SUB_MEMBERS ; i++) begin
      repeat (1) @(posedge aclk);
      fill_data(100 + i, 0, 1, 0);
      @(posedge aclk);
      s_valid <= 0;
    end

    // NO MAXPOOL 1x1

    for (int i=0; i < SUB_MEMBERS ; i++) begin
      repeat (1) @(posedge aclk);
      fill_data(100 + i, 0, 1, 1);
      @(posedge aclk);
      s_valid <= 0;
    end
    
    repeat (5) @(posedge aclk);


    // MAXPOOL ONLY

    for (int i=0; i < SUB_MEMBERS ; i++) begin
      repeat (3) @(posedge aclk);
      fill_data(100 + i, 1, 0, 0);
      @(posedge aclk);
      s_valid <= 0;
    end

    repeat (5) @(posedge aclk);

    for (int i=0; i < SUB_MEMBERS ; i++) begin
      repeat (3) @(posedge aclk);
      fill_data(i, 1, 0, 0);
      @(posedge aclk);
      s_valid <= 0;
    end

    // MAX and NON MAXPOOL

    repeat (5) @(posedge aclk);

    for (int i=0; i < SUB_MEMBERS ; i++) begin
      repeat (3) @(posedge aclk);
      fill_data(100+i, 1, 1, 0);
      @(posedge aclk);
      s_valid <= 0;
    end

    repeat (5) @(posedge aclk);

    for (int i=0; i < SUB_MEMBERS ; i++) begin
      repeat (3) @(posedge aclk);
      fill_data(i, 1, 1, 0);
      @(posedge aclk);
      s_valid <= 0;
    end

  end

endmodule