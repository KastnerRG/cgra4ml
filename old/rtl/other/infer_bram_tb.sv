module infer_bram_tb ();
  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  logic clk = 0;
  initial begin
    forever #(CLK_PERIOD/2) clk <= ~clk;
  end

  localparam R_WIDTH = 16;
  localparam R_DEPTH = 12;
  localparam W_WIDTH = 12*8;
  // localparam R_WIDTH = 16;
  // localparam R_DEPTH = 8;
  // localparam W_WIDTH = 8*8;
  
  localparam SIZE    = R_WIDTH*R_DEPTH;
  localparam W_DEPTH = SIZE/W_WIDTH;
  localparam W_ADDR_WIDTH = $clog2(W_DEPTH);
  localparam R_ADDR_WIDTH = $clog2(R_DEPTH);

  logic rstn, clken, r_en, w_en;
  logic [W_ADDR_WIDTH-1:0] w_addr;
  logic [W_WIDTH     -1:0] w_data;
  logic [R_ADDR_WIDTH-1:0] r_addr;
  logic [R_WIDTH     -1:0] r_data;

  localparam W_BYTES = W_WIDTH/8;
  localparam R_BYTES = R_WIDTH/8;

  logic [7:0] w_data_arr [W_BYTES-1:0];
  logic [7:0] r_data_arr [R_BYTES-1:0];

  assign {>>{w_data}} = w_data_arr;
  assign r_data_arr = {>>{r_data}};

  // asym_ram_sdp_write_wider #(
  //   .WIDTHB      (R_WIDTH),
  //   .WIDTHA      (W_WIDTH),
  //   .SIZE        (SIZE)
  // ) dut (
  //   .clkA  (clk), 
  //   .clkB  (clk), 
  //   .weA   (w_en), 
  //   .enaA  (clken),
  //   .enaB  (r_en && clken), 
  //   .addrA (w_addr), 
  //   .addrB (r_addr), 
  //   .diA   (w_data),
  //   .doB   (r_data)
  // );

  asym_ram_tdp_read_first #(
    .WIDTHB    (R_WIDTH     ),
    .SIZEB     (R_DEPTH     ),
    .ADDRWIDTHB(R_ADDR_WIDTH),
    .WIDTHA    (W_WIDTH     ),
    .SIZEA     (W_DEPTH     ),
    .ADDRWIDTHA(W_ADDR_WIDTH)
  ) dut (
    .clkA (clk), 
    .clkB (clk), 
    .enaA (clken), 
    .weA  (w_en), 
    .enaB (clken && r_en), 
    .weB  (0), 
    .addrA(w_addr), 
    .addrB(r_addr), 
    .diA  (w_data), 
    .doB  (r_data),
    .diB  (0)
    // .doA  (), 
  );

  initial begin
    rstn   <= 1;
    clken  <= 1;
    r_en   <= 0;
    w_en   <= 0;
    w_addr <= 0;
    r_addr <= 0;

    repeat (5) @(posedge clk);

    @(posedge clk);
    #1;
    w_en   <= 1;
    r_en   <= 0;
    w_addr <= 0;
    for (int i=0; i<W_BYTES; i++)
      w_data_arr[i] <= 10+i;
    
    @(posedge clk);
    #1;
    w_addr <= 1;
    for (int i=0; i<W_BYTES; i++)
      w_data_arr[i] <= 30+i;

    @(posedge clk);
    #1;
    w_en   <= 0;
    for (int i=0; i<W_BYTES; i++)
      w_data_arr[i] <= 0;

    repeat (5) @(posedge clk);

    for (int i=0; i<R_DEPTH; i++) begin
      @(posedge clk);
      #1;
      r_en   <= 1;
      r_addr <= i;
    end


  end

endmodule