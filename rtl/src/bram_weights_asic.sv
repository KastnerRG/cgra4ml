`timescale 1ns/1ps

module bram_weights_asic #(
  R_DEPTH      = 8,
  R_DATA_WIDTH = 8,
  W_DATA_WIDTH = 8
)(
  clka ,    
  ena  ,     
  wea  ,     
  addra,  
  dina ,   
  clkb ,   
  enb  ,     
  addrb,  
  doutb
);

  localparam SIZE = R_DEPTH * R_DATA_WIDTH;
  localparam W_DEPTH =  SIZE / W_DATA_WIDTH;
  localparam W_ADDR_WIDTH = $clog2(W_DEPTH);
  localparam R_ADDR_WIDTH = $clog2(R_DEPTH);

  input  logic clka ;
  input  logic clkb ;
  input  logic ena  ;
  input  logic wea  ;
  input  logic enb  ;
  input  logic [W_ADDR_WIDTH-1:0] addra;
  input  logic [R_ADDR_WIDTH-1:0] addrb;
  input  logic [W_DATA_WIDTH-1:0] dina ;
  output logic [R_DATA_WIDTH-1:0] doutb;

  assign doutb = dina & ena & wea & enb & addra & addrb;

endmodule