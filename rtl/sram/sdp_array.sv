
module sdp_array #(
  parameter
  WIDTH = 96*8,
  DEPTH = 2048,
  SDP_WIDTH = 32
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

  localparam BITS_DEPTH = $clog2(DEPTH);
  localparam NUM_SDP = WIDTH/SDP_WIDTH;

  input  logic clka, ena, wea, clkb, enb;  
  input  logic [BITS_DEPTH            -1:0] addra;
  input  logic [BITS_DEPTH            -1:0] addrb;
  input  logic [NUM_SDP-1:0][SDP_WIDTH-1:0] dina ;
  output logic [NUM_SDP-1:0][SDP_WIDTH-1:0] doutb;

  generate
    for (genvar n=0; n<NUM_SDP; n++) begin
      wire         CENYA    ; // output - 
      wire         WENYA    ; // output - 
      wire [10:0]  AYA      ; // output - 
      wire         CENYB    ; // output - 
      wire         WENYB    ; // output - 
      wire [10:0]  AYB      ; // output - 
      wire [31:0]  QA       ; // output - 
      wire [31:0]  QB    =  doutb[n]; // output - 
      wire [1:0]   SOA      ; // output - 
      wire [1:0]   SOB      ; // output - 

      // All enables are active low
      wire         CLKA  = clka ; // input  - 
      wire         CENA  = ~ena ; // input  - 
      wire         WENA  = ~wea ; // input  - 
      wire [10:0]  AA    = addra; // input  - 
      wire [31:0]  DA    = dina[n]; // input  - 
      wire         CLKB  = clkb ; // input  - 
      wire         CENB  = ~enb ; // input  - 
      wire         WENB  = 1'b1 ; // input  - active low
      wire [10:0]  AB    = addrb; // input  - 
      wire [31:0]  DB    = 1'b0 ; // input  - 

      wire [2:0]   EMAA      = 3'b010; // input  - default
      wire [1:0]   EMAWA     = 2'b00 ; // input  - default
      wire [2:0]   EMAB      = 3'b010; // input  - default
      wire [1:0]   EMAWB     = 2'b00 ; // input  - default
      wire         TENA      = 1'b1; // input  - 
      wire         TCENA     = 1'b1; // input  - 
      wire         TWENA     = 1'b1; // input  - 
      wire [10:0]  TAA       = 0; // input  - 
      wire [31:0]  TDA       = 0; // input  - 
      wire         TENB      = 1'b1; // input  - 
      wire         TCENB     = 1'b1; // input  - 
      wire         TWENB     = 1'b1; // input  - 
      wire [10:0]  TAB       = 0; // input  - 
      wire [31:0]  TDB       = 0; // input  - 
      wire         RET1N     = 1'b1; // input  - active low
      wire [1:0]   SIA       = 0; // input  - 
      wire         SEA       = 1'b1; // input  - 
      wire         DFTRAMBYP = 1'b1; // input  - 
      wire [1:0]   SIB       = 0; // input  - 
      wire         SEB       = 1'b1; // input  - 
      wire         COLLDISN  = 1'b1; // input  - 

      sdp_32_2048 sdp (.*);
    end
  endgenerate
endmodule