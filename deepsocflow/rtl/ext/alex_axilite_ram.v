/*

Copyright (c) 2021 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001
`timescale 1ns / 1ps
/*
 * AXI lite register interface module
 */
module alex_axilite_ram #
(
    // Width of data bus in bits
    parameter DATA_WR_WIDTH = 32,
    parameter DATA_RD_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 40,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = 4,
    // Timeout delay (cycles)
    parameter TIMEOUT = 0
)
(
    input  wire                   clk,
    input  wire                   rstn,

    /*
     * AXI-Lite slave interface
     */
    input  wire [ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire [2:0]             s_axil_awprot,
    input  wire                   s_axil_awvalid,
    output wire                   s_axil_awready,
    input  wire [DATA_WR_WIDTH-1:0]  s_axil_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axil_wstrb,
    input  wire                   s_axil_wvalid,
    output wire                   s_axil_wready,
    output wire [1:0]             s_axil_bresp,
    output wire                   s_axil_bvalid,
    input  wire                   s_axil_bready,
    input  wire [ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire [2:0]             s_axil_arprot,
    input  wire                   s_axil_arvalid,
    output wire                   s_axil_arready,
    output wire [DATA_RD_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]             s_axil_rresp,
    output wire                   s_axil_rvalid,
    input  wire                   s_axil_rready,

    /*
     * Register interface
     */
    output wire [ADDR_WIDTH-1:0]  reg_wr_addr,
    output wire [DATA_WR_WIDTH-1:0]  reg_wr_data,
    output wire [STRB_WIDTH-1:0]  reg_wr_strb,
    output wire                   reg_wr_en,
    input  wire                   reg_wr_wait,
    input  wire                   reg_wr_ack,
    output wire [ADDR_WIDTH-1:0]  reg_rd_addr,
    output wire                   reg_rd_en,
    input  wire [DATA_RD_WIDTH-1:0]  reg_rd_data,
    input  wire                   reg_rd_wait,
    input  wire                   reg_rd_ack
);

alex_axilite_wr #(
    .DATA_WIDTH(DATA_WR_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .TIMEOUT(TIMEOUT)
)
axilite_wr_inst (
    .clk(clk),
    .rstn(rstn),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awprot(s_axil_awprot),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),
    .s_axil_wstrb(s_axil_wstrb),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),

    /*
     * Register interface
     */
    .reg_wr_addr(reg_wr_addr),
    .reg_wr_data(reg_wr_data),
    .reg_wr_strb(reg_wr_strb),
    .reg_wr_en(reg_wr_en),
    .reg_wr_wait(reg_wr_wait),
    .reg_wr_ack(reg_wr_ack)
);

alex_axilite_rd #(
    .DATA_WIDTH(DATA_RD_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .TIMEOUT(TIMEOUT)
)
axilite_rd_inst (
    .clk(clk),
    .rstn(rstn),

    /*
     * AXI-Lite slave interface
     */
    .s_axil_araddr(s_axil_araddr),
    .s_axil_arprot(s_axil_arprot),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),

    /*
     * Register interface
     */
    .reg_rd_addr(reg_rd_addr),
    .reg_rd_en(reg_rd_en),
    .reg_rd_data(reg_rd_data),
    .reg_rd_wait(reg_rd_wait),
    .reg_rd_ack(reg_rd_ack)
);

endmodule
