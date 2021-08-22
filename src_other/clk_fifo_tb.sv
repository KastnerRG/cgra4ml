module clk_fifo_tb();
  timeunit 10ns;
  timeprecision 1ns;
  localparam CLK_PERIOD_A = 20; //slow
  localparam CLK_PERIOD_B = 10; //fast
  logic clk_a, clk_b;
  initial begin
    clk_a = 0;
    forever #(CLK_PERIOD_A/2) clk_a <= ~clk_a;
  end
  initial begin
    clk_b = 0;
    forever #(CLK_PERIOD_B/2) clk_b <= ~clk_b;
  end
  // initial begin
  //   clk_a = 0;
  //   forever @(posedge clk_b) clk_a <= ~clk_a;
  // end

  localparam RATIO = CLK_PERIOD_A/CLK_PERIOD_B;
  localparam WIDTH_B = 8;
  localparam WIDTH_A = WIDTH_B*RATIO;

  logic rstn;
  logic [WIDTH_A-1:0] s_data, i_data;
  logic s_ready, s_valid, i_ready, i_valid; 
  logic [WIDTH_B-1:0] m_data;
  logic m_ready, m_valid; 

  axis_clock_conv axis_clock_conv (
  .s_axis_aresetn(rstn),  // input wire s_axis_aresetn
  .m_axis_aresetn(rstn),  // input wire m_axis_aresetn
  .s_axis_aclk(clk_a),        // input wire s_axis_aclk
  .s_axis_tvalid(s_valid),    // input wire s_axis_tvalid
  .s_axis_tready(s_ready),    // output wire s_axis_tready
  .s_axis_tdata(s_data),      // input wire [15 : 0] s_axis_tdata
  .m_axis_aclk(clk_b),        // input wire m_axis_aclk
  .m_axis_tvalid(i_valid),    // output wire m_axis_tvalid
  .m_axis_tready(i_ready),    // input wire m_axis_tready
  .m_axis_tdata(i_data)      // output wire [15 : 0] m_axis_tdata
);

axis_dw2 dw (
  .aclk(clk_b),                    // input wire aclk
  .aresetn(rstn),              // input wire aresetn
  .s_axis_tvalid(i_valid),  // input wire s_axis_tvalid
  .s_axis_tready(i_ready),  // output wire s_axis_tready
  .s_axis_tdata(i_data),    // input wire [15 : 0] s_axis_tdata
  .m_axis_tvalid(m_valid),  // output wire m_axis_tvalid
  .m_axis_tready(m_ready),  // input wire m_axis_tready
  .m_axis_tdata(m_data)    // output wire [7 : 0] m_axis_tdata
);

  /*
            Slave -> Switch -> Master
    Clock:  1     : 2       : 2
    Data :  2     : 2       : 1
  */

  // axis_interconnect_0 dut (
  //   .ACLK(clk_b),                                // input wire ACLK
  //   .ARESETN(rstn),                          // input wire ARESETN
  //   .S00_AXIS_ACLK(clk_a),              // input wire S00_AXIS_ACLK
  //   .S00_AXIS_ARESETN(rstn),        // input wire S00_AXIS_ARESETN
  //   .S00_AXIS_TVALID(s_valid),          // input wire S00_AXIS_TVALID
  //   .S00_AXIS_TREADY(s_ready),          // output wire S00_AXIS_TREADY
  //   .S00_AXIS_TDATA(s_data),            // input wire [15 : 0] S00_AXIS_TDATA
  //   .M00_AXIS_ACLK(clk_b),              // input wire M00_AXIS_ACLK
  //   .M00_AXIS_ARESETN(rstn),        // input wire M00_AXIS_ARESETN
  //   .M00_AXIS_TVALID(m_valid),          // output wire M00_AXIS_TVALID
  //   .M00_AXIS_TREADY(m_ready),          // input wire M00_AXIS_TREADY
  //   .M00_AXIS_TDATA(m_data)            // output wire [7 : 0] M00_AXIS_TDATA
  //   // .S00_FIFO_DATA_COUNT(S00_FIFO_DATA_COUNT),  // output wire [31 : 0] S00_FIFO_DATA_COUNT
  //   // .M00_FIFO_DATA_COUNT(M00_FIFO_DATA_COUNT)  // output wire [31 : 0] M00_FIFO_DATA_COUNT
  // );

  // logic full, empty;

  // assign m_valid = ~empty;
  // assign s_ready = ~full;

  // localparam FIFO_WRITE_DEPTH = 16;

  // fifo_generator_0 fifo (
  //   .rst(~rstn),                  // input wire rst
  //   .wr_clk(clk_a),            // input wire wr_clk
  //   .rd_clk(clk_b),            // input wire rd_clk
  //   .din(s_data),                  // input wire [15 : 0] din
  //   .wr_en(s_ready&s_valid),              // input wire wr_en
  //   .rd_en(m_ready&m_valid),              // input wire rd_en
  //   .dout(m_data),                // output wire [7 : 0] dout
  //   .full(full),                // output wire full
  //   .empty(empty)              // output wire empty
  //   // .wr_rst_busy(wr_rst_busy),  // output wire wr_rst_busy
  //   // .rd_rst_busy(rd_rst_busy)  // output wire rd_rst_busy
  // );

//   xpm_fifo_async #(
//       .CDC_SYNC_STAGES(2),       // DECIMAL
//       .DOUT_RESET_VALUE("0"),    // String
//       .ECC_MODE("no_ecc"),       // String
//       .FIFO_MEMORY_TYPE("block"), // String: auto, block, distributed
//       .FIFO_READ_LATENCY(0),     // DECIMAL
//       .FIFO_WRITE_DEPTH(FIFO_WRITE_DEPTH),   // DECIMAL
//       .FULL_RESET_VALUE(0),      // DECIMAL
//       .PROG_EMPTY_THRESH(10),    // DECIMAL
//       .PROG_FULL_THRESH(10),     // DECIMAL
//       .RD_DATA_COUNT_WIDTH( $clog2(FIFO_WRITE_DEPTH*WIDTH_A/WIDTH_B)+1 ),   // DECIMAL
//       .READ_DATA_WIDTH(WIDTH_B),      // DECIMAL
//       .READ_MODE("fwft"),         // String
//       .RELATED_CLOCKS(0),        // DECIMAL
//       .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
//       .USE_ADV_FEATURES("0000"), // String
//       .WAKEUP_TIME(0),           // DECIMAL
//       .WRITE_DATA_WIDTH(WIDTH_A),     // DECIMAL
//       .WR_DATA_COUNT_WIDTH( $clog2(FIFO_WRITE_DEPTH)+1)    // DECIMAL

// // | Defines the width of the read data port, dout                                                                       |
// // |                                                                                                                     |
// // |   Write and read width aspect ratio must be 1:1, 1:2, 1:4, 1:8, 8:1, 4:1 and 2:1                                    |
// // |   For example, if WRITE_DATA_WIDTH is 32, then the READ_DATA_WIDTH must be 32, 64,128, 256, 16, 8, 4.               |
// // |                                                                                                                     |
// // | NOTE:                                                                                                               |
// // |                                                                                                                     |
// // |   READ_DATA_WIDTH should be equal to WRITE_DATA_WIDTH if FIFO_MEMORY_TYPE is set to "auto". Violating this may result incorrect behavior. |
// // |   The maximum FIFO size (width x depth) is limited to 150-Megabits.                                                 |
//   ) dut (
//       // .almost_empty(almost_empty),   // 1-bit output: Almost Empty : When asserted, this signal indicates that
//       //                                // only one more read can be performed before the FIFO goes to empty.

//       // .almost_full(almost_full),     // 1-bit output: Almost Full: When asserted, this signal indicates that
//       //                                // only one more write can be performed before the FIFO is full.

//       // .data_valid(data_valid),       // 1-bit output: Read Data Valid: When asserted, this signal indicates
//       //                                // that valid data is available on the output bus (dout).

//       // .dbiterr(dbiterr),             // 1-bit output: Double Bit Error: Indicates that the ECC decoder detected
//       //                                // a double-bit error and data in the FIFO core is corrupted.

//       .dout(m_data),                   // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
//                                      // when reading the FIFO.

//       .empty(empty),                 // 1-bit output: Empty Flag: When asserted, this signal indicates that the
//                                      // FIFO is empty. Read requests are ignored when the FIFO is empty,
//                                      // initiating a read while empty is not destructive to the FIFO.

//       .full(full),                   // 1-bit output: Full Flag: When asserted, this signal indicates that the
//                                      // FIFO is full. Write requests are ignored when the FIFO is full,
//                                      // initiating a write when the FIFO is full is not destructive to the
//                                      // contents of the FIFO.

//       // .overflow(overflow),           // 1-bit output: Overflow: This signal indicates that a write request
//       //                                // (wren) during the prior clock cycle was rejected, because the FIFO is
//       //                                // full. Overflowing the FIFO is not destructive to the contents of the
//       //                                // FIFO.

//       // .prog_empty(prog_empty),       // 1-bit output: Programmable Empty: This signal is asserted when the
//       //                                // number of words in the FIFO is less than or equal to the programmable
//       //                                // empty threshold value. It is de-asserted when the number of words in
//       //                                // the FIFO exceeds the programmable empty threshold value.

//       // .prog_full(prog_full),         // 1-bit output: Programmable Full: This signal is asserted when the
//       //                                // number of words in the FIFO is greater than or equal to the
//       //                                // programmable full threshold value. It is de-asserted when the number of
//       //                                // words in the FIFO is less than the programmable full threshold value.

//       // .rd_data_count(rd_data_count), // RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the
//       //                                // number of words read from the FIFO.

//       // .rd_rst_busy(rd_rst_busy),     // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read
//       //                                // domain is currently in a reset state.

//       // .sbiterr(sbiterr),             // 1-bit output: Single Bit Error: Indicates that the ECC decoder detected
//       //                                // and fixed a single-bit error.

//       // .underflow(underflow),         // 1-bit output: Underflow: Indicates that the read request (rd_en) during
//       //                                // the previous clock cycle was rejected because the FIFO is empty. Under
//       //                                // flowing the FIFO is not destructive to the FIFO.

//       // .wr_ack(wr_ack),               // 1-bit output: Write Acknowledge: This signal indicates that a write
//       //                                // request (wr_en) during the prior clock cycle is succeeded.

//       // .wr_data_count(wr_data_count), // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
//       //                                // the number of words written into the FIFO.

//       // .wr_rst_busy(wr_rst_busy),     // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
//       //                                // write domain is currently in a reset state.

//       .din(s_data),                     // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
//                                      // writing the FIFO.

//       .injectdbiterr(0),             // 1-bit input: Double Bit Error Injection: Injects a double bit error if
//                                      // the ECC feature is used on block RAMs or UltraRAM macros.

//       .injectsbiterr(0),             // 1-bit input: Single Bit Error Injection: Injects a single bit error if
//                                      // the ECC feature is used on block RAMs or UltraRAM macros.

//       .rd_clk(clk_b),               // 1-bit input: Read clock: Used for read operation. rd_clk must be a free
//                                      // running clock.

//       .rd_en(m_valid & m_ready),                 // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
//                                      // signal causes data (on dout) to be read from the FIFO. Must be held
//                                      // active-low when rd_rst_busy is active high.

//       .rst(~rstn),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
//                                      // unstable at the time of applying reset, but reset must be released only
//                                      // after the clock(s) is/are stable.

//       .sleep(0),                 // 1-bit input: Dynamic power saving: If sleep is High, the memory/fifo
//                                      // block is in power saving mode.

//       .wr_clk(clk_a),               // 1-bit input: Write clock: Used for write operation. wr_clk must be a
//                                      // free running clock.

//       .wr_en(s_valid & s_ready)                  // 1-bit input: Write Enable: If the FIFO is not full, asserting this
//                                      // signal causes data (on din) to be written to the FIFO. Must be held
//                                      // active-low when rst or wr_rst_busy is active high.
//    );
   
   initial begin
      rstn    <= 1;
      s_valid <=0;
      s_data  <=0;
      m_ready <=0;

      repeat(2) @(posedge clk_a);
      #1
      rstn    <= 1;
      m_ready <= 1;

      repeat(2) 
      @(posedge clk_a);
      #1
      s_data  <= {8'd11, 8'd12};
      s_valid <= 1;
      wait(s_ready);

      @(posedge clk_a);
      #1
      s_data  <= 0;
      s_valid <= 0;

      @(posedge clk_a);
      #1
      s_data  <= 0;
      s_valid <= 0;

      @(posedge clk_a);
      #1
      s_data  <= {8'd13, 8'd14};
      s_valid <= 1;
      wait(s_ready);

      @(posedge clk_a);
      #1
      s_data  <= {8'd15, 8'd16};
      s_valid <= 1;
      wait(s_ready);

      @(posedge clk_a);
      #1
      s_data  <= 0;
      s_valid <= 0;

   end

endmodule