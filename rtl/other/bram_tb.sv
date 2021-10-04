module bram_test();

  timeunit 1ns;
  timeprecision 1ps;
  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  logic ena, wea;
  logic [1:0] addra;
  logic [31:0] dina;
  logic [15:0] douta;

  // bram_lrelu_edge BRAM (
  //   .clka (aclk ),
  //   .ena  (ena  ),
  //   .wea  (wea  ),
  //   .addra(addra),
  //   .dina (dina ),
  //   .douta(douta)
  // );

  initial begin
    #1
    ena   = 0;
    wea   = 0;
    addra = 0;
    dina  = 0;

    @(posedge aclk);
    #1
    ena   = 1;
    wea   = 0;
    addra = 0;
    dina  = 0;
    @(posedge aclk);
    @(posedge aclk);
    @(posedge aclk);

    @(posedge aclk);
    #1
    ena   = 1;
    wea   = 1;
    addra = 0;
    dina  = 32'h00020001;

    @(posedge aclk);
    #1
    ena   = 1;
    wea   = 1;
    addra = 2;
    dina  = 32'h00040003;

    @(posedge aclk);
    #1
    ena   = 1;
    wea   = 0;
    addra = 0;
    dina  = 0;
    @(posedge aclk);
    @(posedge aclk);
    @(posedge aclk);

    @(posedge aclk);
    #1
    ena   = 1;
    wea   = 0;
    addra = 1;
    dina  = 0;
    @(posedge aclk);
    #1
    ena   = 1;
    wea   = 0;
    addra = 2;
    dina  = 0;
    @(posedge aclk);
    #1
    ena   = 1;
    wea   = 0;
    addra = 3;
    dina  = 0;
    @(posedge aclk);
    #1
    ena   = 1;
    wea   = 0;
    addra = 0;
    dina  = 0;

  end

endmodule