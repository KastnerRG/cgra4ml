// Single-Port Block RAM Write-First Mode (recommended template)
// File: rams_sp_wf.v
`timescale 1ns/1ps
module rams_sp_wf (clk, we, en, addr, di, dout);
  parameter WIDTH = 16;
  parameter DEPTH = 1024;
  parameter ADDR_WIDTH = 10;

  input clk;
  input we;
  input en;
  input [ADDR_WIDTH-1:0] addr;
  input [WIDTH-1:0] di;
  output [WIDTH-1:0] dout;
  reg [WIDTH-1:0] RAM [DEPTH-1:0];
  reg [WIDTH-1:0] dout;

  always @(posedge clk)
  begin
    if (en)
    begin
      if (we)
      begin
        RAM[addr] <= di;
        dout <= di;
      end
      else
        dout <= RAM[addr];
    end
  end
endmodule