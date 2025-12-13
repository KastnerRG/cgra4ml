`timescale 1ns / 1ps

module asym_ram_sdp_read_wider2 #(
  parameter int WIDTHA      = 4,
  parameter int SIZEA       = 1024,
  parameter int ADDRWIDTHA  = 10,
  parameter int WIDTHB      = 16,
  parameter int SIZEB       = 256,
  parameter int ADDRWIDTHB  = 8
)(
  input  logic                  clkA,
  input  logic                  clkB,   // unused, must be same clk
  input  logic                  enaA,
  input  logic                  weA,
  input  logic                  enaB,
  input  logic [ADDRWIDTHA-1:0] addrA,  // narrow write addr
  input  logic [ADDRWIDTHB-1:0] addrB,  // wide read addr
  input  logic [WIDTHA    -1:0] diA,
  output logic [WIDTHB    -1:0] doB
);
  localparam int RATIO = WIDTHB / WIDTHA;      // assume power-of-2
  localparam int LOGR  = $clog2(RATIO);

  logic [WIDTHA-1:0] q [RATIO];

  wire [LOGR-1:0]       idx = addrA[LOGR-1:0];
  wire [ADDRWIDTHB-1:0] row = addrA[ADDRWIDTHA-1:LOGR];

  genvar i;
  generate
    for (i = 0; i < RATIO; i++) begin : g
      dual_port_sram #(
        .WIDTH(WIDTHA),
        .DEPTH(SIZEB)
      ) ram_i (
        .clk  (clkA),
        .wen  (enaA && weA && (idx == LOGR'(i))),
        .waddr(row),
        .din  (diA),
        .ren  (enaB),
        .raddr(addrB),
        .dout (q[i])
      );
    end
  endgenerate

  always_comb
    for (int j = 0; j < RATIO; j++)
      doB[j*WIDTHA +: WIDTHA] = q[j];

endmodule
