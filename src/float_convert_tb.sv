module float_convert_tb();
  timeunit 1ns;
  timeprecision 1ps;
  logic clk;
  localparam CLK_PERIOD = 10;
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk <= ~clk;
  end

  logic [31:0] float_32;
  logic [15:0] float_16;

  function logic [31:0] float_16_to_32 (logic [15:0] float_16);
    logic [31:0] float_32;
    
    logic sign;
    logic [4 :0] exp_16;
    logic [9 :0] fra_16;

    logic [7 :0] exp_32;
    logic [22:0] fra_32;

    assign {sign, exp_16, fra_16} = float_16;
    assign fra_32 = fra_16 << 13; // 23-10
    assign exp_32 = exp_16 + 7'd112; //- 15 + 127;
    assign float_32 = {sign, exp_32, fra_32};
    return float_32;
  endfunction

function logic [15:0] float_32_to_16 (logic [31:0] float_32);
  logic [31:0] float_32;
  
  logic sign;
  logic [4 :0] exp_16;
  logic [9 :0] fra_16;

  logic [7 :0] exp_32;
  logic [22:0] fra_32;

  assign {sign, exp_32, fra_32} = float_32;
  assign fra_16 = (fra_32 + (32'b1 << 12)) >> 13 ;
  assign exp_16 = exp_32 - 7'd112; //- 15 + 127;
  assign float_16 = {sign, exp_16, fra_16};
  return float_16;
endfunction

  initial begin
    @(posedge clk);
    float_32 <= float_16_to_32(16'h4248); // 3.14
    @(posedge clk);
    float_32 <= float_16_to_32(16'h399A); //0.7
    float_16 <= float_32_to_16(float_32);
    @(posedge clk);
    float_32 <= float_16_to_32(16'hB029); //-0.13
    float_16 <= float_32_to_16(float_32);
    @(posedge clk);
    float_16 <= float_32_to_16(float_32);

  end

endmodule