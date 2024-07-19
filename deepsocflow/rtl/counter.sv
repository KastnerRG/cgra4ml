`timescale 1ns/1ps
`include "defines.svh"

module counter #(parameter W = 8)(
  input  logic clk, rstn_g, rst_l, en,
  input  logic [W-1:0] max_in,
  output logic [W-1:0] count,
  output logic last, last_clk, first
);
  logic [W-1:0] max;
  wire  [W-1:0] count_next = last ? max : count - 1;

  always_ff @(posedge clk `OR_NEGEDGE(rstn_g))
    if (!rstn_g)
      {count, max, last} <= '0;
    else if (rst_l) begin
      count  <= max_in;
      max    <= max_in;
      last   <= max_in==0;
    end
    else if (en) begin
      last   <= count_next == 0;
      count  <= count_next;
    end
  
  assign last_clk = en && last && rstn_g && !rst_l;
  assign first = count == max;

endmodule