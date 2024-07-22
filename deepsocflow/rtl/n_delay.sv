`timescale 1ns/1ps
`include "defines.svh"

module n_delay #(
  parameter N = 1,
            W = 8
)(
  input  wire     c, e, rng, rnl,
  input  wire [W-1 : 0]  i,
  output wire [W-1 : 0]  o
);

  logic [W-1 : 0] data [(N+1)-1:0];

  always_comb data [0] = i;
  assign o = data[(N+1)-1];

  genvar n;
  generate 
  for (n=0 ; n < N; n++) begin : n_dat
    always_ff @(posedge c `OR_NEGEDGE(rng))
      if (!rng)      data [n+1] <= 0;
      else if (!rnl) data [n+1] <= 0;
      else if (e)    data [n+1] <= data [n];
  end
  endgenerate

endmodule