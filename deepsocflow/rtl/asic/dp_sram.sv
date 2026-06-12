module dual_port_sram #(
    parameter int WIDTH      = 32,
    parameter int DEPTH      = 256,
    parameter int ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                  clk,
    input  logic                  wen,
    input  logic [ADDR_WIDTH-1:0] waddr,
    input  logic [WIDTH-1:0]      din,
    input  logic                  ren,
    input  logic [ADDR_WIDTH-1:0] raddr,
    output logic [WIDTH-1:0]      dout
);

  sram_dma sam5_2p_sram_dma (
`ifdef POWER_PINS
    .VDD       (1'b1),
    .VSS       (1'b0),
`endif
    // Port A — read
    .QA        (dout),
    .CLKA      (clk),
    .CENA      (~ren),
    .AA        (raddr),
    // Port B — write
    .CLKB      (clk),
    .CENB      (~wen),
    .AB        (waddr),
    .DB        (din),
    // Static tie-offs for 0.85V/0.95V but if you want <=0.75V change EMAB -> 3'b010
    .STOV      (1'b0),
    .EMAA      (3'b001),
    .EMASA     (1'b0),
    .EMAB      (3'b001),
    .DFTRAMBYP (1'b0),
    .RET       (1'b0),
    .QNAPA     (1'b0),
    .QNAPB     (1'b0),
    .RAWL      (1'b0),
    .RAWLM     (2'b00)
  );

endmodule
