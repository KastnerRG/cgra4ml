module clk_tb ();

  timeunit 10ns;
  timeprecision 1ns;

  localparam SLOW_BYTES = 8;
  localparam FAST_BYTES = 4;

  localparam SLOW_PERIOD = 10;
  localparam FAST_PERIOD = 5;

  logic [8*SLOW_BYTES-1:0] S00_AXIS_TDATA, M01_AXIS_TDATA;
  logic [8*FAST_BYTES-1:0] S01_AXIS_TDATA, M00_AXIS_TDATA;

  logic [7:0] s_data_0 [SLOW_BYTES-1:0];
  logic [7:0] m_data_1 [SLOW_BYTES-1:0];
  logic [7:0] s_data_1 [FAST_BYTES-1:0];
  logic [7:0] m_data_0 [FAST_BYTES-1:0];

  assign {>>{S00_AXIS_TDATA}} = s_data_0;
  assign m_data_0 = {>>{M00_AXIS_TDATA}};
  assign m_data_1 = {>>{M01_AXIS_TDATA}};
  assign s_data_1 = {>>{S01_AXIS_TDATA}};

  logic ACLK, ARESETN;
  logic S00_AXIS_ACLK, S00_AXIS_ARESETN, S00_AXIS_TVALID, S00_AXIS_TREADY, S00_AXIS_TLAST, S00_AXIS_TDEST, S00_DECODE_ERR;
  logic S01_AXIS_ACLK, S01_AXIS_ARESETN, S01_AXIS_TVALID, S01_AXIS_TREADY, S01_AXIS_TLAST, S01_AXIS_TDEST, S01_DECODE_ERR;
  logic M00_AXIS_ARESETN, M00_AXIS_TVALID, M00_AXIS_TREADY, M00_AXIS_TLAST, M00_AXIS_TDEST, M00_SPARSE_TKEEP_REMOVED;
  logic M01_AXIS_ARESETN, M01_AXIS_TVALID, M01_AXIS_TREADY, M01_AXIS_TLAST, M01_AXIS_TDEST, M01_SPARSE_TKEEP_REMOVED;

  axis_interconnect_0 int0 (
    .ACLK                    (ACLK),                                          // input wire ACLK
    .ARESETN                 (ARESETN),                                    // input wire ARESETN
    .S00_AXIS_ACLK           (S00_AXIS_ACLK),                        // input wire S00_AXIS_ACLK
    .S01_AXIS_ACLK           (S01_AXIS_ACLK),                        // input wire S01_AXIS_ACLK
    .S00_AXIS_ARESETN        (S00_AXIS_ARESETN),                  // input wire S00_AXIS_ARESETN
    .S01_AXIS_ARESETN        (S01_AXIS_ARESETN),                  // input wire S01_AXIS_ARESETN
    .S00_AXIS_TVALID         (S00_AXIS_TVALID),                    // input wire S00_AXIS_TVALID
    .S01_AXIS_TVALID         (S01_AXIS_TVALID),                    // input wire S01_AXIS_TVALID
    .S00_AXIS_TREADY         (S00_AXIS_TREADY),                    // output wire S00_AXIS_TREADY
    .S01_AXIS_TREADY         (S01_AXIS_TREADY),                    // output wire S01_AXIS_TREADY
    .S00_AXIS_TDATA          (S00_AXIS_TDATA),                      // input wire [63 : 0] S00_AXIS_TDATA
    .S01_AXIS_TDATA          (S01_AXIS_TDATA),                      // input wire [31 : 0] S01_AXIS_TDATA
    .S00_AXIS_TLAST          (S00_AXIS_TLAST),                      // input wire S00_AXIS_TLAST
    .S01_AXIS_TLAST          (S01_AXIS_TLAST),                      // input wire S01_AXIS_TLAST
    .S00_AXIS_TDEST          (S00_AXIS_TDEST),                      // input wire [0 : 0] S00_AXIS_TDEST
    .S01_AXIS_TDEST          (S01_AXIS_TDEST),                      // input wire [0 : 0] S01_AXIS_TDEST
    .M00_AXIS_ACLK           (M00_AXIS_ACLK),                        // input wire M00_AXIS_ACLK
    .M01_AXIS_ACLK           (M01_AXIS_ACLK),                        // input wire M01_AXIS_ACLK
    .M00_AXIS_ARESETN        (M00_AXIS_ARESETN),                  // input wire M00_AXIS_ARESETN
    .M01_AXIS_ARESETN        (M01_AXIS_ARESETN),                  // input wire M01_AXIS_ARESETN
    .M00_AXIS_TVALID         (M00_AXIS_TVALID),                    // output wire M00_AXIS_TVALID
    .M01_AXIS_TVALID         (M01_AXIS_TVALID),                    // output wire M01_AXIS_TVALID
    .M00_AXIS_TREADY         (M00_AXIS_TREADY),                    // input wire M00_AXIS_TREADY
    .M01_AXIS_TREADY         (M01_AXIS_TREADY),                    // input wire M01_AXIS_TREADY
    .M00_AXIS_TDATA          (M00_AXIS_TDATA),                      // output wire [31 : 0] M00_AXIS_TDATA
    .M01_AXIS_TDATA          (M01_AXIS_TDATA),                      // output wire [63 : 0] M01_AXIS_TDATA
    .M00_AXIS_TLAST          (M00_AXIS_TLAST),                      // output wire M00_AXIS_TLAST
    .M01_AXIS_TLAST          (M01_AXIS_TLAST),                      // output wire M01_AXIS_TLAST
    .M00_AXIS_TDEST          (M00_AXIS_TDEST),                      // output wire [0 : 0] M00_AXIS_TDEST
    .M01_AXIS_TDEST          (M01_AXIS_TDEST),                      // output wire [0 : 0] M01_AXIS_TDEST
    .S00_DECODE_ERR          (S00_DECODE_ERR),                      // output wire S00_DECODE_ERR
    .S01_DECODE_ERR          (S01_DECODE_ERR),                      // output wire S01_DECODE_ERR
    .M00_SPARSE_TKEEP_REMOVED(M00_SPARSE_TKEEP_REMOVED),  // output wire M00_SPARSE_TKEEP_REMOVED
    .M01_SPARSE_TKEEP_REMOVED(M01_SPARSE_TKEEP_REMOVED)   // output wire M01_SPARSE_TKEEP_REMOVED
  );

  initial begin
    ACLK <= 0;
    forever #(FAST_PERIOD/2) ACLK <= ~ACLK;
  end

  assign S01_AXIS_ACLK = ACLK;
  assign M00_AXIS_ACLK = ACLK;

  initial begin
    S00_AXIS_ACLK <= 0;
    forever #(SLOW_PERIOD/2) S00_AXIS_ACLK <= ~S00_AXIS_ACLK;
  end
  assign M01_AXIS_ACLK = S00_AXIS_ACLK;

  assign S01_AXIS_TDATA  = M00_AXIS_TDATA ;
  assign S01_AXIS_TLAST  = M00_AXIS_TLAST ;
  assign S01_AXIS_TVALID = M00_AXIS_TVALID;
  assign M00_AXIS_TREADY = S01_AXIS_TREADY;

  assign ARESETN = 1;
  assign S00_AXIS_ARESETN = 1;
  assign S01_AXIS_ARESETN = 1;
  assign M00_AXIS_ARESETN = 1;
  assign M01_AXIS_ARESETN = 1;

  int x = 0;

  initial begin
    S00_AXIS_TVALID <= 0;
    S00_AXIS_TDEST  <= 0;
    S00_AXIS_TLAST  <= 0;
    M01_AXIS_TREADY <= 1;
    s_data_0  <= '{default:0};
    repeat (5) @(posedge S00_AXIS_ACLK);

    forever begin
      @(posedge S00_AXIS_ACLK);

      if (S00_AXIS_TREADY) begin
        #1
        S00_AXIS_TVALID <= 1;

        for (int i=0; i<SLOW_BYTES; i++) begin
          if (x < 256) x++;
          else x <= 0;

          S00_AXIS_TDATA[i] <= x;
        end

        S00_AXIS_TLAST <= (x % 64 ==0); 
      end
    end
  end


endmodule