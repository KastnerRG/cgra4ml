`timescale 1ns/1ps
`include "../../rtl/include/params.svh"

module ram_raw #(
  parameter   DEPTH   = 1,
              WIDTH   = 8,
              LATENCY = 2
)(
  input  logic clka ,
  input  logic ena  ,
  input  logic wea  ,
  input  logic [$clog2(DEPTH)-1:0] addra,
  input  logic [WIDTH        -1:0] dina ,
  output logic [WIDTH        -1:0] douta
);
  generate
      // Write
      logic [DEPTH-1:0][WIDTH-1:0] data;

      always_ff @(posedge clka)
        if (ena && wea) data[addra] <= dina;

      // Based on latency
      if (LATENCY == 1) begin
        always_ff @(posedge clka)
          if (ena) douta <= data[addra];

      end else begin
        logic [LATENCY-2:0][WIDTH-1:0] delay;
        always_ff @(posedge clka)
          if (ena) {douta, delay} <= {delay, data[addra]};
      end
  endgenerate
endmodule

module ram_weights #(
  parameter   DEPTH   = `RAM_WEIGHTS_DEPTH,
              WIDTH   = `COLS * `K_BITS,
              LATENCY = `DELAY_W_RAM
)(
  input  logic clka ,
  input  logic ena  ,
  input  logic wea  ,
  input  logic [$clog2(DEPTH)-1:0] addra,
  input  logic [WIDTH        -1:0] dina ,
  output logic [WIDTH        -1:0] douta
);

  ram_raw #(
    .DEPTH      (DEPTH  ),
    .WIDTH      (WIDTH  ),
    .LATENCY    (LATENCY)
  ) RAM (.*);

endmodule

module ram_edges #(
  parameter   DEPTH   = `RAM_EDGES_DEPTH,
              WIDTH   = `X_BITS * (`KH_MAX/2),
              LATENCY  = 1
)(
  input  logic clka ,
  input  logic ena  ,
  input  logic wea  ,
  input  logic [$clog2(DEPTH)-1:0] addra,
  input  logic [WIDTH        -1:0] dina ,
  output logic [WIDTH        -1:0] douta
);

  ram_raw #(
    .DEPTH   (DEPTH  ),
    .WIDTH   (WIDTH  ),
    .LATENCY (LATENCY)
  ) RAM (.*);

endmodule

module ram_output #(
  parameter   DEPTH    = `COLS * `ROWS,
              WIDTH    = `Y_BITS,
              LATENCY  = 2
)(
  input  logic clka ,
  input  logic ena  ,
  input  logic wea  ,
  input  logic [$clog2(DEPTH)-1:0] addra,
  input  logic [WIDTH        -1:0] dina ,
  output logic [WIDTH        -1:0] douta
);

  ram_raw #(
    .DEPTH   (DEPTH  ),
    .WIDTH   (WIDTH  ),
    .LATENCY (LATENCY)
  ) RAM (.*);

endmodule