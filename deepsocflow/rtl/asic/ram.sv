`timescale 1ns/1ps
`include "defines.svh"

module ram_weights #(
  parameter   DEPTH      = `RAM_WEIGHTS_DEPTH,
              WIDTH      = `K_BITS,
              LATENCY    = `DELAY_W_RAM,
  parameter   ADDR_WIDTH = $clog2(DEPTH)
)(
  input  logic                  clk,
  input  logic                  en,
  input  logic                  we,
  input  logic [ADDR_WIDTH-1:0] addr,
  input  logic [WIDTH-1:0]      di,
  output logic [WIDTH-1:0]      dout
);

  sram_weight sam5_sp_sram_weight (
`ifdef POWER_PINS
    .VDD       (1'b1),
    .VSS       (1'b0),
`endif
    .Q         (dout),
    .CLK       (clk),
    .CEN       (~en),
    .GWEN      (~we),
    .A         (addr),
    .D         (di),
    .STOV      (1'b0),
    .EMA       (3'b010),
    .EMAW      (2'b10),
    .EMAS      (1'b0),
    .DFTRAMBYP (1'b0),
    .RET       (1'b0),
    .QNAP      (1'b0),
    .RAWL      (1'b0),
    .RAWLM     (2'b00)
  );

endmodule


module ram_edges #(
  parameter   DEPTH      = `RAM_EDGES_DEPTH,
              WIDTH      = `X_BITS * (`KH_MAX/2),
              LATENCY    = 1,
  parameter   ADDR_WIDTH = $clog2(DEPTH)
)(
  input  logic                  clk,
  input  logic                  en,
  input  logic                  we,
  input  logic [ADDR_WIDTH-1:0] addr,
  input  logic [WIDTH-1:0]      di,
  output logic [WIDTH-1:0]      dout
);

  sram_edge sam5_sp_sram_edge (
`ifdef POWER_PINS
    .VDD       (1'b1),
    .VSS       (1'b0),
`endif
    .Q         (dout),
    .CLK       (clk),
    .CEN       (~en),
    .GWEN      (~we),
    .A         (addr),
    .D         (di),
    .STOV      (1'b0),
    .EMA       (3'b010),
    .EMAW      (2'b10),
    .EMAS      (1'b0),
    .DFTRAMBYP (1'b0),
    .RET       (1'b0),
    .QNAP      (1'b0),
    .RAWL      (1'b0),
    .RAWLM     (2'b00)
  );

endmodule
