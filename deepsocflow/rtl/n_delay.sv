`timescale 1ns/1ps
module n_delay #(
  parameter N = 1,
            W = 8
)(
  input  wire     c, e, rn,
  input  wire [W-1 : 0]  i,
  output wire [W-1 : 0]  o
);

  logic [W-1 : 0] data [(N+1)-1:0];

  always_comb data [0] = i;
  assign o = data[(N+1)-1];

  genvar n;
  for (n=0 ; n < N; n++)
    always_ff @(posedge c)
      if (!rn)    data [n+1] <= 0;
      else if (e) data [n+1] <= data [n];

endmodule