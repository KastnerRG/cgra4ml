`timescale 1ns/1ps
//`include "../../../deepsocflow/rtl/defines.svh"
/// add a compiler directive here
//`include "sram_weights/sram_weights.v"
//`include "sram_edges/sram_edges.v"
//`include "sram_output/sram_output.v"

module ram_weights #(
  parameter   DEPTH   = `RAM_WEIGHTS_DEPTH,
              WIDTH   = `COLS * `K_BITS
)(
  input  logic clka ,
  input  logic ena  ,
  input  logic wea  ,
  input  logic [$clog2(DEPTH)-1:0] addra,
  input  logic [WIDTH        -1:0] dina ,
  output logic [WIDTH        -1:0] douta
);

  `ifdef TSMC28_SRAM
  sram_weights RAMW (
    .Q(douta),
    .CLK(clka),
    .CEN(~ena),
    .WEN(~wea),
    .A(addra),
    .D(dina),
    .EMA(3'b010),
    .EMAW(2'b00),
    .RET1N(1'b1),
    .WABL(1'b1),
    .WABLM(2'b00)
    );
  `endif

  `ifdef TSMC7_SRAM
  sram_weights RAMW (
    .Q(douta),
    .CLK(clka),
    .CEN(~ena),
    .GWEN(~wea),
    .A(addra),
    .D(dina),
    .STOV(1'b0),
    .EMA(3'b010),
    .EMAW(2'b00),
    .EMAS(1'b0),
    .RET(1'b1),
    .QNAP(1'b0)
    );
  `endif
  
endmodule

module ram_edges #(
  parameter   DEPTH   = `RAM_EDGES_DEPTH,
              WIDTH   = `X_BITS * (`KH_MAX/2)
)(
  input  logic clka ,
  input  logic ena  ,
  input  logic wea  ,
  input  logic [$clog2(DEPTH)-1:0] addra,
  input  logic [WIDTH        -1:0] dina ,
  output logic [WIDTH        -1:0] douta
);

  `ifdef TSMC28_SRAM
  sram_edges RAME (
    .Q(douta),
    .CLK(clka),
    .CEN(~ena),
    .WEN(~wea),
    .A(addra),
    .D(dina),
    .EMA(3'b010),
    .EMAW(2'b00),
    .RET1N(1'b1),
    .WABL(1'b1),
    .WABLM(2'b00)
  );
  `endif

  `ifdef TSMC7_SRAM
  sram_edges RAME (
    .Q(douta),
    .CLK(clka),
    .CEN(~ena),
    .GWEN(~wea),
    .A(addra),
    .D(dina),
    .STOV(1'b0),
    .EMA(3'b010),
    .EMAW(2'b00),
    .EMAS(1'b0),
    .RET(1'b1),
    .QNAP(1'b0)
  );
  `endif
endmodule