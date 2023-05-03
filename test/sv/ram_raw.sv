`timescale 1ns/1ps
`include "../../params/params.svh"

module ram_raw #(
  parameter   R_DEPTH      = 1,
              R_DATA_WIDTH = 8,
              W_DATA_WIDTH = 8,
              LATENCY      = 2,

  localparam  SIZE = R_DEPTH * R_DATA_WIDTH,
              W_DEPTH =  SIZE / W_DATA_WIDTH,
              W_ADDR_WIDTH = $clog2(W_DEPTH),
              R_ADDR_WIDTH = $clog2(R_DEPTH)
)(
  input  logic clka ,
  input  logic clkb ,
  input  logic ena  ,
  input  logic wea  ,
  input  logic enb  ,
  input  logic [W_ADDR_WIDTH-1:0] addra,
  input  logic [R_ADDR_WIDTH-1:0] addrb,
  input  logic [W_DATA_WIDTH-1:0] dina ,
  output logic [R_DATA_WIDTH-1:0] doutb
);
  generate
      // Write
      logic [W_DEPTH-1:0][W_DATA_WIDTH-1:0] data;

      always_ff @(posedge clka)
        if (ena && wea) data[addra] <= dina;

      // Read
      wire  [R_DEPTH-1:0][R_DATA_WIDTH-1:0] data_r = data;

      // Based on latency
      if (LATENCY == 1) begin
        always_ff @(posedge clkb)
          if (enb) doutb <= data_r[addrb];

      end else begin
        logic [LATENCY-2:0][R_DATA_WIDTH-1:0] delay;
        always_ff @(posedge clkb)
          if (enb) {doutb, delay} <= {delay, data_r[addrb]};
      end
  endgenerate
endmodule

module ram_weights #(
  parameter   R_DEPTH      = `BRAM_WEIGHTS_DEPTH,
              R_DATA_WIDTH = `COLS * `WORD_WIDTH,
              W_DATA_WIDTH = `COLS * `WORD_WIDTH,
              LATENCY      = `LATENCY_BRAM,
              W_DEPTH      =  (R_DEPTH * R_DATA_WIDTH) / W_DATA_WIDTH
)(
  input  logic clka ,
  input  logic clkb ,
  input  logic ena  ,
  input  logic wea  ,
  input  logic enb  ,
  input  logic [$clog2(W_DEPTH)-1:0] addra,
  input  logic [$clog2(R_DEPTH)-1:0] addrb,
  input  logic [W_DATA_WIDTH   -1:0] dina ,
  output logic [R_DATA_WIDTH   -1:0] doutb
);

  ram_raw #(
    .R_DEPTH      (R_DEPTH     ),
    .R_DATA_WIDTH (R_DATA_WIDTH),
    .W_DATA_WIDTH (W_DATA_WIDTH),
    .LATENCY      (LATENCY     )
  ) RAM (.*);

endmodule

module ram_edges #(
  parameter   R_DEPTH      = `RAM_EDGES_DEPTH,
              R_DATA_WIDTH = `WORD_WIDTH * (`KH_MAX/2),
              W_DATA_WIDTH = `WORD_WIDTH * (`KH_MAX/2),
              LATENCY      = 1,
              W_DEPTH      =  (R_DEPTH * R_DATA_WIDTH) / W_DATA_WIDTH
)(
  input  logic clka ,
  input  logic clkb ,
  input  logic ena  ,
  input  logic wea  ,
  input  logic enb  ,
  input  logic [$clog2(W_DEPTH)-1:0] addra,
  input  logic [$clog2(R_DEPTH)-1:0] addrb,
  input  logic [W_DATA_WIDTH   -1:0] dina ,
  output logic [R_DATA_WIDTH   -1:0] doutb
);

  ram_raw #(
    .R_DEPTH      (R_DEPTH     ),
    .R_DATA_WIDTH (R_DATA_WIDTH),
    .W_DATA_WIDTH (W_DATA_WIDTH),
    .LATENCY      (LATENCY     )
  ) RAM (.*);

endmodule