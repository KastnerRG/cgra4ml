`timescale 1ns/1ps

module bram_sdp_shell #(
  R_DEPTH      = 8,
  R_DATA_WIDTH = 8,
  W_DATA_WIDTH = 8,
  LATENCY      = 2,
  TYPE         = "XILINX_WEIGHTS" //, "EMPTY"
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

  genvar i;
  generate
    if (TYPE =="EMPTY")
      assign doutb = dina & ena & wea & enb & addra & addrb;

    else if (TYPE == "XILINX_WEIGHTS")
      bram_weights bram (
        .clka   (clka),    
        .ena    (ena),     
        .wea    (wea),     
        .addra  (addra),  
        .dina   (dina),   
        .clkb   (clkb),   
        .enb    (enb),     
        .addrb  (addrb),  
        .doutb  (doutb)  
      );
    else if (TYPE == "ASIC")
      sdp_array bram (
        .clka   (clka),    
        .ena    (ena),     
        .wea    (wea),     
        .addra  (addra),  
        .dina   (dina),   
        .clkb   (clkb),   
        .enb    (enb),     
        .addrb  (addrb),  
        .doutb  (doutb)  
      );
    else if (TYPE == "RAW") begin

      wire [W_DEPTH-1:0][W_DATA_WIDTH-1:0] data;

      for (i=0; i < W_DEPTH; i++) begin: WD 
        register #(
          .WORD_WIDTH     (W_DATA_WIDTH),
          .RESET_VALUE    (0)
        ) CELL (
          .clock          (clka        ),
          .resetn         (1'b1        ),
          .clock_enable   (ena & wea & (i == addra)),
          .data_in        (dina        ),
          .data_out       (data     [i])
        );
      end

      wire [R_DEPTH-1:0][R_DATA_WIDTH-1:0] data_r = data;
      n_delay #(
        .N          (LATENCY     ),
        .WORD_WIDTH (R_DATA_WIDTH)
      ) DELAY (
        .clk      (clkb         ),
        .resetn   (1'b1         ),
        .clken    (enb          ),
        .data_in  (data_r[addrb]),
        .data_out (doutb        )
      );
    end
  endgenerate
endmodule