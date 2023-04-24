`timescale 1ns/1ps

module counter #(parameter W = 8, ALLOW_ONE=0)(
  input  logic clk, reset, en,
  input  logic [W-1:0] max_in, reset_val,
  output logic [W-1:0] count,
  output logic last, last_clk, first
);
  logic [W-1:0] max_1, max;

  // If max == 0 is not needed, we can register last signal
  if (ALLOW_ONE) begin

    assign last = count == max;
    always_ff @(posedge clk)
      if (reset) max <= max_in;

  end else
    always_ff @(posedge clk)
      if (reset) begin
        max_1  <= max_in-1;
        last   <= 0;
      end
      else if (en)
        last   <= count == max_1;

  always_ff @(posedge clk)
    if (reset)   count <= reset_val;
    else if (en) count <= last ? '0 : count + 1;
  
  assign last_clk = en && last;
  assign first = count == 0;

endmodule


module counter_tb;
  localparam W = 8;
  logic clk=0, reset=0, en=0;
  logic [W-1:0] max_in;
  logic [W-1:0] count ;
  logic last, last_clk;

  counter #(.W(W)) dut (.*);
  initial forever #5 clk <= !clk;

  initial begin
    repeat ($urandom_range(20)) begin
      repeat ($urandom_range(10)) @(posedge clk);

      #1 max_in = $urandom_range(20); reset <= 1;
      @(posedge clk);
      #1 reset <= 0;

      repeat (5) begin
        while (!last_clk) @(posedge clk) #1 en <= $urandom_range(100) < 20;
        @(posedge clk);
        en <= 0; 
      end
    end
    $finish();
  end

endmodule