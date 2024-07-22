`timescale 1ns/1ps
`include "defines.svh"

module ram_weights #(
  parameter   DEPTH   = `RAM_WEIGHTS_DEPTH,
              WIDTH   = `K_BITS,
              LATENCY = `DELAY_W_RAM,
  parameter  ADDR_WIDTH = $clog2(DEPTH)
)(
  input  logic clk ,
  input  logic en  ,
  input  logic we  ,
  input  logic [ADDR_WIDTH   -1:0] addr,
  input  logic [WIDTH        -1:0] di ,
  output logic [WIDTH        -1:0] dout
);
  logic [WIDTH-1:0] dout_ram;
  rams_sp_wf #(
    .WIDTH      (WIDTH  ),
    .DEPTH      (DEPTH  ),
    .ADDR_WIDTH (ADDR_WIDTH)
  ) RAM (
    .clk  (clk ),
    .en   (en  ),
    .we   (we  ),
    .addr (addr),
    .di   (di  ),
    .dout (dout_ram)
  );
  n_delay #(
    .N (LATENCY-1),
    .W (WIDTH)
  ) DELAY (
    .c   (clk),
    .e   (en),
    .rng (1'b1),
    .rnl (1'b1),
    .i   (dout_ram),
    .o   (dout)
  );
endmodule

module ram_edges #(
  parameter   DEPTH   = `RAM_EDGES_DEPTH,
              WIDTH   = `X_BITS * (`KH_MAX/2),
              LATENCY  = 1,
  parameter  ADDR_WIDTH = $clog2(DEPTH)
)(
  input  logic clk ,
  input  logic en  ,
  input  logic we  ,
  input  logic [ADDR_WIDTH   -1:0] addr,
  input  logic [WIDTH        -1:0] di ,
  output logic [WIDTH        -1:0] dout
);
  logic [WIDTH-1:0] dout_ram;
  rams_sp_wf #(
    .WIDTH      (WIDTH  ),
    .DEPTH      (DEPTH  ),
    .ADDR_WIDTH (ADDR_WIDTH)
  ) RAM (
    .clk  (clk ),
    .en   (en  ),
    .we   (we  ),
    .addr (addr),
    .di   (di  ),
    .dout (dout_ram)
  );
  n_delay #(
    .N (LATENCY-1),
    .W (WIDTH)
  ) DELAY (
    .c   (clk),
    .e   (en),
    .rng (1'b1),
    .rnl (1'b1),
    .i   (dout_ram),
    .o   (dout)
  );
endmodule

module ram_output #(
  parameter   DEPTH    = `COLS * `ROWS,
              WIDTH    = `Y_BITS,
              LATENCY  = 2,
  parameter  ADDR_WIDTH = $clog2(DEPTH)
)(
  input  logic clk ,
  input  logic en  ,
  input  logic we  ,
  input  logic [ADDR_WIDTH   -1:0] addr,
  input  logic [WIDTH        -1:0] di ,
  output logic [WIDTH        -1:0] dout
);
  logic [WIDTH-1:0] dout_ram;
  rams_sp_wf #(
    .WIDTH      (WIDTH  ),
    .DEPTH      (DEPTH  ),
    .ADDR_WIDTH (ADDR_WIDTH)
  ) RAM (
    .clk  (clk ),
    .en   (en  ),
    .we   (we  ),
    .addr (addr),
    .di   (di  ),
    .dout (dout_ram)
  );
  n_delay #(
    .N (LATENCY-1),
    .W (WIDTH)
  ) DELAY (
    .c   (clk),
    .e   (en),
    .rng (1'b1),
    .rnl (1'b1),
    .i   (dout_ram),
    .o   (dout)
  );
endmodule