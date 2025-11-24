`timescale 1ns/1ps

module writeback #(
  parameter
    SRAM_RD_DEPTH      = 8   , // number of bundles
    AXI_ADDR_WIDTH     = 32  ,
    AXI_DATA_WIDTH     = 32  ,

  localparam  
    WIDTH              = 32  ,
    VAR_PER_ROW        = 5   ,
    SRAM_RD_DATA_WIDTH = VAR_PER_ROW * WIDTH,
    SRAM_WR_DEPTH = SRAM_RD_DEPTH * SRAM_RD_DATA_WIDTH / WIDTH, // 2048
    SRAM_RD_ADDR_WIDTH  = $clog2(SRAM_RD_DEPTH), // 11
    SRAM_WR_ADDR_WIDTH  = $clog2(SRAM_WR_DEPTH)
)(
  input  logic clk,
  input  logic rstn,

  // SRAM port
  input  logic                      reg_wr_en  ,
  input  logic [AXI_ADDR_WIDTH-1:0] reg_wr_addr,
  input  logic [AXI_DATA_WIDTH-1:0] reg_wr_data,
  input  logic                      reg_rd_en  ,
  input  logic [AXI_ADDR_WIDTH-1:0] reg_rd_addr, 
  output logic [AXI_DATA_WIDTH-1:0] reg_rd_data
);

  localparam N_REG = 32;
  localparam // Addresses for local memory 0:32 is registers, rest is SRAM
    A_START       = 'h0,
    A_N_BUNDLES_1 = 'h1,
    A_EN_COUNT    = 'h2,
    A_READY       = 'h3,
    A_IB          = 'h4,
    A_IP          = 'h5,
    A_IN          = 'h6,
    A_IL          = 'h7,
    A_IWKW2       = 'h8
    ; // Max 32 registers
  logic [WIDTH-1:0] cfg [N_REG-1:0];
  wire en_count = 1'(cfg[A_EN_COUNT]);

  //------------------- BUNDLES SRAM  ---------------------------------------

  logic ram_rd_en, ram_wr_en, ram_rd_valid;
  logic [SRAM_RD_ADDR_WIDTH-1:0] ram_rd_addr;
  logic [SRAM_WR_ADDR_WIDTH-1:0] ram_wr_addr;
  logic [WIDTH             -1:0] ram_wr_data;
  logic [SRAM_RD_DATA_WIDTH-1:0] ram_rd_data;

  asym_ram_sdp_read_wider #(
    .WIDTHB     (SRAM_RD_DATA_WIDTH),
    .SIZEB      (SRAM_RD_DEPTH     ),
    .ADDRWIDTHB (SRAM_RD_ADDR_WIDTH),
    .WIDTHA     (WIDTH             ),
    .SIZEA      (SRAM_WR_DEPTH     ),
    .ADDRWIDTHA (SRAM_WR_ADDR_WIDTH)
  ) sdp_ram (
    .clkA  (clk        ), 
    .clkB  (clk        ), 
    .weA   (ram_wr_en  ), 
    .enaA  (ram_wr_en  ), 
    .addrA (ram_wr_addr), 
    .diA   (ram_wr_data), 
    .enaB  (ram_rd_en  ), 
    .addrB (ram_rd_addr), 
    .doB   (ram_rd_data)
  );

  logic [AXI_ADDR_WIDTH-1:0] reg_rd_addr_valid;
  always_ff @(posedge clk) begin
    ram_rd_valid <= ram_rd_en;
    reg_rd_addr_valid <= reg_rd_addr;
  end

  always_comb begin
    ram_wr_en   = reg_wr_en && (reg_wr_addr >= N_REG);
    ram_wr_addr = SRAM_WR_ADDR_WIDTH'(reg_wr_addr - N_REG);
    ram_wr_data = WIDTH'(reg_wr_data);
    ram_rd_en   = reg_rd_en && (reg_rd_addr >= N_REG);
    reg_rd_data = AXI_DATA_WIDTH'(cfg[reg_rd_addr]);
  end


  // ram_ are combinational from ram
  logic [WIDTH-1:0] ram_max_wkw2, ram_max_l, ram_max_n, ram_max_t, ram_max_p      ;
  logic [WIDTH-1:0] i_wkw2      , i_l      , i_n      , i_t      , i_p      , i_b ;
  logic             lc_wkw2     , lc_l     , lc_n     , lc_t     , lc_p     , lc_b;
  logic             l_wkw2      , l_l      , l_n      , l_t      , l_p      , l_b ;

  assign ram_rd_addr = SRAM_RD_ADDR_WIDTH'(i_b);
  assign {ram_max_wkw2, ram_max_l, ram_max_n, ram_max_t, ram_max_p} = ram_rd_data;

  counter #(.W(WIDTH)) C_B    (.clk(clk), .rstn_g(rstn), .rst_l(1'(cfg[A_START])), .en(lc_p    ), .max_in(WIDTH'(cfg[A_N_BUNDLES_1])), .last_clk(lc_b   ), .last(l_b   ), .first(), .count(i_b   ));
  counter #(.W(WIDTH)) C_P    (.clk(clk), .rstn_g(rstn), .rst_l(ram_rd_valid    ), .en(lc_t    ), .max_in(WIDTH'(ram_max_p         )), .last_clk(lc_p   ), .last(l_p   ), .first(), .count(i_p   ));
  counter #(.W(WIDTH)) C_T    (.clk(clk), .rstn_g(rstn), .rst_l(ram_rd_valid    ), .en(lc_n    ), .max_in(WIDTH'(ram_max_t         )), .last_clk(lc_t   ), .last(l_t   ), .first(), .count(i_t   ));
  counter #(.W(WIDTH)) C_N    (.clk(clk), .rstn_g(rstn), .rst_l(ram_rd_valid    ), .en(lc_l    ), .max_in(WIDTH'(ram_max_n         )), .last_clk(lc_n   ), .last(l_n   ), .first(), .count(i_n   ));
  counter #(.W(WIDTH)) C_L    (.clk(clk), .rstn_g(rstn), .rst_l(ram_rd_valid    ), .en(lc_wkw2 ), .max_in(WIDTH'(ram_max_l         )), .last_clk(lc_l   ), .last(l_l   ), .first(), .count(i_l   ));
  counter #(.W(WIDTH)) C_WKW2 (.clk(clk), .rstn_g(rstn), .rst_l(ram_rd_valid    ), .en(en_count), .max_in(WIDTH'(ram_max_wkw2      )), .last_clk(lc_wkw2), .last(l_wkw2), .first(), .count(i_wkw2));

  always_ff @(posedge clk) // All cfg written in this always block
    if (!rstn) begin 
      cfg[0] <= 0;
      cfg[1] <= 0;
      cfg[2] <= 0;
    end else begin

      if (en_count) begin
        cfg[A_EN_COUNT] <= WIDTH'(0);
        cfg[A_READY   ] <= WIDTH'(1);
      end
      if (1'(cfg[A_START])) begin
        cfg[A_START] <= WIDTH'(0);
      end

      cfg[A_IB     ] <= i_b  ;
      cfg[A_IP     ] <= i_p  ;
      cfg[A_IN     ] <= i_n  ;
      cfg[A_IL     ] <= i_l  ;
      cfg[A_IWKW2  ] <= i_wkw2;


      if (reg_wr_en && reg_wr_addr < N_REG) // PS has priority in writing to registers
        cfg[reg_wr_addr] <= WIDTH'(reg_wr_data);
    end
endmodule