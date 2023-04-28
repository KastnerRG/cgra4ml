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