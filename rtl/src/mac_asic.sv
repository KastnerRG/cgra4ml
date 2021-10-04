`timescale 1ns/1ps
`include "../include/params.v"

module accumulator_raw #(
  WORD_WIDTH = `WORD_WIDTH_ACC,
  LATENCY    = `LATENCY_ACCUMULATOR
)(
  input  logic CLK   ,
  input  logic bypass,
  input  logic CE    ,
  input  logic signed [WORD_WIDTH-1:0] B,     
  output logic signed [WORD_WIDTH-1:0] Q     
);

  logic bypass_d;
  logic signed [WORD_WIDTH-1:0] B_d;  

  n_delay #(
    .N          (LATENCY    -1),
    .WORD_WIDTH (WORD_WIDTH +1),
    .LOCAL      (0)
  ) DELAY (
    .clk      (CLK ),
    .resetn   (1'b1),
    .clken    (CE  ),
    .data_in  ({B  , bypass  }),
    .data_out ({B_d, bypass_d})
  );

  logic signed [WORD_WIDTH-1:0] reg_in;
  assign reg_in = B_d + (bypass_d ? 0 : Q);

  register #(
    .WORD_WIDTH  (WORD_WIDTH),
    .RESET_VALUE (0),
    .LOCAL       (0)
  ) REG (
    .clock       (CLK),
    .clock_enable(CE),
    .resetn      (1'b1),
    .data_in     (reg_in),
    .data_out    (Q)
  );
endmodule 


module multiplier_raw # (
  WORD_WIDTH = `WORD_WIDTH,
  LATENCY    = `LATENCY_MULTIPLIER
)
(
  input  logic CLK ,
  input  logic CE  ,
  input  logic signed [WORD_WIDTH   -1:0] A,
  input  logic signed [WORD_WIDTH   -1:0] B,
  output logic signed [WORD_WIDTH*2 -1:0] P   
);

  logic signed [WORD_WIDTH-1:0] A_d, B_d;

  n_delay #(
    .N          (LATENCY   -1),
    .WORD_WIDTH (WORD_WIDTH*2),
    .LOCAL      (0)
  ) DELAY (
    .clk      (CLK ),
    .resetn   (1'b1),
    .clken    (CE  ),
    .data_in  ({A,B}),
    .data_out ({A_d,B_d})
  );

  logic signed [WORD_WIDTH*2-1:0] mul_in;
  assign mul_in = A_d * B_d;

  register #(
    .WORD_WIDTH  (WORD_WIDTH*2),
    .RESET_VALUE (0),
    .LOCAL       (0)
  ) REG (
    .clock       (CLK),
    .clock_enable(CE),
    .resetn      (1'b1),
    .data_in     (mul_in),
    .data_out    (P)
  );

endmodule