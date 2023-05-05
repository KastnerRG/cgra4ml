`timescale 1ns/1ps
module cyclic_bram #(
  parameter   R_DEPTH      = 8,
              R_DATA_WIDTH = 8,
              W_DATA_WIDTH = 8,
              LATENCY      = 3,
              ABSORB       = 0,
              TYPE         = "RAW", //, "EMPTY",
  localparam  SIZE = R_DEPTH * R_DATA_WIDTH ,
              W_DEPTH =  SIZE / W_DATA_WIDTH,
              W_ADDR_WIDTH = $clog2(W_DEPTH),
              R_ADDR_WIDTH = $clog2(R_DEPTH)
  )(
    input  logic clk, clken, resetn,
    input  logic w_en, r_en,
    input  logic [W_DATA_WIDTH-1:0] s_data,
    output logic [R_DATA_WIDTH-1:0] m_data,
    output logic m_valid,
    input  logic [R_ADDR_WIDTH-1:0] r_addr_max, r_addr_min,
    input  logic [W_ADDR_WIDTH-1:0] w_addr_max
  );

  logic [W_ADDR_WIDTH-1:0] w_addr;
  logic [R_ADDR_WIDTH-1:0] r_addr;
 
  always_ff @(posedge clk) 
    if (!resetn)            w_addr <= 0;
    else if (clken && w_en) w_addr <= w_addr + 1;

  always_ff @(posedge clk) 
    if (!resetn)            r_addr <= 0;
    else if (clken && r_en) r_addr <= r_addr == r_addr_max ?  r_addr_min : r_addr + 1;

  ram_weights BRAM (
    .clka   (clk),    
    .ena    (clken),     
    .wea    (w_en),  
    .addra  (w_en ? w_addr : r_addr),  
    .dina   (s_data),   
    .douta  (m_data)  
  );

endmodule