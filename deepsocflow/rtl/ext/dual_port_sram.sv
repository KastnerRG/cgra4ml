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
    logic [WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (wen) mem[waddr] <= din;
        if (ren) dout       <= mem[raddr];
    end
endmodule
