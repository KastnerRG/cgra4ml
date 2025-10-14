`timescale 1ns/1ps
// `include "../defines.svh" this need to be remove for vcs

`ifdef FPGA
module ram_weights #(
  parameter   DEPTH   = `RAM_WEIGHTS_DEPTH,
              WIDTH   = `K_BITS,
              LATENCY = `DELAY_W_RAM,
  parameter  ADDR_WIDTH = $clog2(DEPTH)
)(
  input  logic clk ,
  input  logic en  ,
  input  logic we  ,
  input  logic [ADDR_WIDTH   -1:0] addr,
  input  logic [WIDTH        -1:0] di ,
  output logic [WIDTH        -1:0] dout
);
  logic [WIDTH-1:0] dout_ram;
  rams_sp_wf #(
    .WIDTH      (WIDTH  ),
    .DEPTH      (DEPTH  ),
    .ADDR_WIDTH (ADDR_WIDTH)
  ) RAM (
    .clk  (clk ),
    .en   (en  ),
    .we   (we  ),
    .addr (addr),
    .di   (di  ),
    .dout (dout_ram)
  );
  n_delay #(
    .N (LATENCY-1),
    .W (WIDTH)
  ) DELAY (
    .c   (clk),
    .e   (en),
    .rng (1'b1),
    .rnl (1'b1),
    .i   (dout_ram),
    .o   (dout)
  );
endmodule

module ram_edges #(
  parameter   DEPTH   = `RAM_EDGES_DEPTH,
              WIDTH   = `X_BITS * (`KH_MAX/2),
              LATENCY  = 1,
  parameter  ADDR_WIDTH = $clog2(DEPTH)
)(
  input  logic clk ,
  input  logic en  ,
  input  logic we  ,
  input  logic [ADDR_WIDTH   -1:0] addr,
  input  logic [WIDTH        -1:0] di ,
  output logic [WIDTH        -1:0] dout
);
  logic [WIDTH-1:0] dout_ram;
  rams_sp_wf #(
    .WIDTH      (WIDTH  ),
    .DEPTH      (DEPTH  ),
    .ADDR_WIDTH (ADDR_WIDTH)
  ) RAM (
    .clk  (clk ),
    .en   (en  ),
    .we   (we  ),
    .addr (addr),
    .di   (di  ),
    .dout (dout_ram)
  );
  n_delay #(
    .N (LATENCY-1),
    .W (WIDTH)
  ) DELAY (
    .c   (clk),
    .e   (en),
    .rng (1'b1),
    .rnl (1'b1),
    .i   (dout_ram),
    .o   (dout)
  );
endmodule

module ram_output #(
  parameter   DEPTH    = `COLS * `ROWS,
              WIDTH    = `Y_BITS,
              LATENCY  = 2,
  parameter  ADDR_WIDTH = $clog2(DEPTH)
)(
  input  logic clk ,
  input  logic en  ,
  input  logic we  ,
  input  logic [ADDR_WIDTH   -1:0] addr,
  input  logic [WIDTH        -1:0] di ,
  output logic [WIDTH        -1:0] dout
);
  logic [WIDTH-1:0] dout_ram;
  rams_sp_wf #(
    .WIDTH      (WIDTH  ),
    .DEPTH      (DEPTH  ),
    .ADDR_WIDTH (ADDR_WIDTH)
  ) RAM (
    .clk  (clk ),
    .en   (en  ),
    .we   (we  ),
    .addr (addr),
    .di   (di  ),
    .dout (dout_ram)
  );
  n_delay #(
    .N (LATENCY-1),
    .W (WIDTH)
  ) DELAY (
    .c   (clk),
    .e   (en),
    .rng (1'b1),
    .rnl (1'b1),
    .i   (dout_ram),
    .o   (dout)
  );
endmodule
`else

module asym_ram_sdp_read_wider (
    clkA,
    clkB,
    enaA,
    weA,
    enaB,
    addrA,
    addrB,
    diA,
    doB
);
  parameter WIDTHA = 4;
  parameter SIZEA = 1024;
  parameter ADDRWIDTHA = 10;

  parameter WIDTHB = 16;
  parameter SIZEB = 256;
  parameter ADDRWIDTHB = 8;
  input clkA;
  input clkB;
  input weA;
  input enaA, enaB;
  input [ADDRWIDTHA-1:0] addrA;
  input [ADDRWIDTHB-1:0] addrB;
  input [WIDTHA-1:0] diA;
  output [WIDTHB-1:0] doB;
  `define max(a, b) ((a) > (b) ? (a) : (b))
  `define min(a, b) ((a) < (b) ? (a) : (b))

  localparam maxSIZE = `max(SIZEA, SIZEB);
  localparam minSIZE = `min(SIZEA, SIZEB);
  localparam maxWIDTH = `max(WIDTHA, WIDTHB);
  localparam minWIDTH = `min(WIDTHA, WIDTHB);

  localparam RATIO = maxWIDTH / minWIDTH;
  localparam log2RATIO = $clog2(RATIO);

  reg [maxWIDTH-1:0] RAM[0:minSIZE-1];
  reg [maxWIDTH-1:0] wrData;
  reg [maxWIDTH-1:0] bitMaskEN;
  reg [WIDTHB-1:0] readB;
  reg [ADDRWIDTHB-1:0] addrWR;

  always_comb begin
    unique case (addrA[log2RATIO-1:0])
      3'b000: begin
          wrData = {{minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, diA};
          bitMaskEN = {{minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b1}}};
      end 
      3'b001: begin
          wrData = {{minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, diA, {minWIDTH{1'b0}}};
          bitMaskEN = {{minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b1}}, {minWIDTH{1'b0}}};
      end 
      3'b010: begin
          wrData = {{minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, diA, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}};
          bitMaskEN = {{minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b1}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}};
      end 
      3'b011: begin
          wrData = {{minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, diA, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}};
          bitMaskEN = {{minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b1}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}};
      end 
      3'b100: begin
          wrData = {{minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, diA, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}};
          bitMaskEN = {{minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b1}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}};
      end 
      3'b101: begin
          wrData = {{minWIDTH{1'b0}}, {minWIDTH{1'b0}}, diA, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}};
          bitMaskEN = {{minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b1}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}};
      end 
      3'b110: begin
          wrData = {{minWIDTH{1'b0}}, diA, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}};
          bitMaskEN = {{minWIDTH{1'b0}}, {minWIDTH{1'b1}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}};
      end 
      3'b111: begin
          wrData = {diA, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}};
          bitMaskEN = {{minWIDTH{1'b1}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}};
      end
      default: begin
          wrData = {{minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, diA};
          bitMaskEN = {{minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b0}}, {minWIDTH{1'b1}}};
      end     
    endcase
    addrWR = addrA >> log2RATIO;
  end

  always @(posedge clkA) begin : ramwrite
    if (enaA) begin
      if (weA) RAM[addrWR] <= wrData & bitMaskEN; // bitwise and
    end
  end

  always @(posedge clkB) begin : ramread
    if (enaB) begin
      readB <= RAM[addrB];
    end
  end
  assign doB = readB;

endmodule

module ram_weights #(
  parameter   DEPTH   = `RAM_WEIGHTS_DEPTH,
              WIDTH   = `K_BITS,
              LATENCY = `DELAY_W_RAM,
  parameter  ADDR_WIDTH = $clog2(DEPTH)
)(
  input  logic clk ,
  input  logic en  ,
  input  logic we  ,
  input  logic [ADDR_WIDTH   -1:0] addr,
  input  logic [WIDTH        -1:0] di ,
  output logic [WIDTH        -1:0] dout
);
  logic [WIDTH-1:0] dout_ram;
  rams_sp_wf #(
    .WIDTH      (WIDTH  ),
    .DEPTH      (DEPTH  ),
    .ADDR_WIDTH (ADDR_WIDTH)
  ) RAM (
    .clk  (clk ),
    .en   (en  ),
    .we   (we  ),
    .addr (addr),
    .di   (di  ),
    .dout (dout_ram)
  );
  n_delay #(
    .N (LATENCY-1),
    .W (WIDTH)
  ) DELAY (
    .c   (clk),
    .e   (en),
    .rng (1'b1),
    .rnl (1'b1),
    .i   (dout_ram),
    .o   (dout)
  );
endmodule

module ram_edges #(
  parameter   DEPTH   = `RAM_EDGES_DEPTH,
              WIDTH   = `X_BITS * (`KH_MAX/2),
              LATENCY  = 1,
  parameter  ADDR_WIDTH = $clog2(DEPTH)
)(
  input  logic clk ,
  input  logic en  ,
  input  logic we  ,
  input  logic [ADDR_WIDTH   -1:0] addr,
  input  logic [WIDTH        -1:0] di ,
  output logic [WIDTH        -1:0] dout
);
  logic [WIDTH-1:0] dout_ram;
  rams_sp_wf #(
    .WIDTH      (WIDTH  ),
    .DEPTH      (DEPTH  ),
    .ADDR_WIDTH (ADDR_WIDTH)
  ) RAM (
    .clk  (clk ),
    .en   (en  ),
    .we   (we  ),
    .addr (addr),
    .di   (di  ),
    .dout (dout_ram)
  );
  n_delay #(
    .N (LATENCY-1),
    .W (WIDTH)
  ) DELAY (
    .c   (clk),
    .e   (en),
    .rng (1'b1),
    .rnl (1'b1),
    .i   (dout_ram),
    .o   (dout)
  );
endmodule

`endif