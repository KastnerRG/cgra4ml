`timescale 10ns / 1ns
`include "../params/params.v"
// `default_nettype none

/*
Why Register

It may seem silly to implement a register module rather than let the HDL infer it, 
but doing so separates data and control at the most basic level, including various 
kinds of resets, which are part of control. This separation of data and control 
allows us to simplify the control logic and reduce the need for some routing resources.

http://fpgacpu.ca/fpga/Register.html

Power-on-Reset

On FPGAs, the initial state of registers is set in the configuration 
bitstream and applied by special power-on reset circuitry. 
The initial state of a design is available "for free" and can be 
returned to at run-time, which removes the need for that control and data logic.

Asynchronous Reset

The asynchronous reset is not implemented here as its existence prevents 
register retiming, even if tied to zero. This limitation complicates design 
and reduces performance as we would have to manually place registers to properly 
pipeline logic. If you absolutely need an asynchronous reset for ASIC implementation 
or for some critical registers, use the Register_areset instead.

Synchronous Reset (a.k.a. Clear)

If you need to clear the register during normal operation, use the synchronous 
clear input. This may create extra logic, but that logic gets folded into other 
logic feeding data to the register, and would have been necessary anyway but present 
as another case in the surrounding logic. Having a clear input allows us to get to 
the initial power-on-reset state without complicating the design.

*/

module register
#(
  parameter WORD_WIDTH  = 0,
  parameter RESET_VALUE = 0,
  parameter LOCAL       = 0
)
(
  input   wire                        clock,
  input   wire                        clock_enable,
  input   wire                        resetn,
  input   wire    [WORD_WIDTH-1:0]    data_in,

`ifdef ASIC_REG
  output  reg     [WORD_WIDTH-1:0]    data_out
`else
  output  reg     [WORD_WIDTH-1:0]    data_out = RESET_VALUE
`endif

);


`ifdef ASIC_REG
  always @(posedge clock or negedge resetn) begin
    if (~resetn) data_out <= RESET_VALUE;
`else
  always @(posedge clock) begin
    if (LOCAL && ~resetn ) data_out <= RESET_VALUE;
`endif

    else if (clock_enable) data_out <= data_in;
    else                   data_out <= data_out;
  end

endmodule


