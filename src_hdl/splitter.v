`timescale 1ns / 1ps
module splitter#(IN_WIDTH = 131)(
    input  wire [IN_WIDTH-1:0] input_0,
    output wire [31:0] out_0,
    output wire [31:0] out_1,
    output wire [31:0] out_2,
    output wire [31:0] out_3,
    output wire [31:0] out_4
);
    assign out_0 = input_0[1*32 -1 : 0*32];
    assign out_1 = input_0[2*32 -1 : 1*32];
    assign out_2 = input_0[3*32 -1 : 2*32];
    assign out_3 = input_0[4*32 -1 : 3*32];
    assign out_4 = {29'b0, input_0[IN_WIDTH -1 : 4*32]};
endmodule
