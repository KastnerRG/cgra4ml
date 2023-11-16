`timescale 1ns/1ps

module counter #(parameter W = 8)(
  input  logic clk, reset, en,
  input  logic [W-1:0] max_in,
  output logic [W-1:0] count,
  output logic last, last_clk, first
);
  logic [W-1:0] max;
  wire  [W-1:0] count_next = last ? max : count - 1;

  always_ff @(posedge clk)
    if (reset) begin
      count  <= max_in;
      max    <= max_in;
      last   <= max_in==0;
    end
    else if (en) begin
      last   <= count_next == 0;
      count  <= count_next;
    end
  
  assign last_clk = en && last;
  assign first = count == max;

endmodule