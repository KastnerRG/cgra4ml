module cyclic_shift_reg #(
  R_DEPTH        = 24     ,
  R_DATA_WIDTH   = 16     ,
  W_DATA_WIDTH   = 24*8   ,
  LATENCY        = 2      
)(
  clk        ,
  clken      ,
  resetn     ,
  w_en       ,
  r_en       ,
  s_data     ,
  m_data     ,
  r_addr_max ,
  w_addr_max 
);
  localparam SIZE = R_DEPTH * R_DATA_WIDTH;
  localparam W_DEPTH =  SIZE / W_DATA_WIDTH;
  localparam RATIO = W_DATA_WIDTH/R_DATA_WIDTH;
  localparam W_ADDR_WIDTH = $clog2(W_DEPTH);
  localparam R_ADDR_WIDTH = $clog2(R_DEPTH);

  input  logic clk, clken, resetn;
  input  logic w_en, r_en;
  input  logic [W_DATA_WIDTH-1:0] s_data;
  output logic [R_DATA_WIDTH-1:0] m_data;
  input  logic [R_ADDR_WIDTH-1:0] r_addr_max;
  input  logic [W_ADDR_WIDTH-1:0] w_addr_max;

  logic [R_DATA_WIDTH-1:0] w_data_in  [RATIO  -1:0];
  assign w_data_in = {>>{s_data}};

  logic [R_DATA_WIDTH-1:0] data_in    [R_DEPTH-1:0];
  logic [R_DATA_WIDTH-1:0] r_data_in  [R_DEPTH-1:0];
  logic [R_DATA_WIDTH-1:0] r_data_out [R_DEPTH-1:0];

  logic [R_DATA_WIDTH-1:0] r_data_latency    [LATENCY:0];

  // Write Address

  logic [W_ADDR_WIDTH-1:0] w_addr, w_addr_next;
  assign w_addr_next = (w_addr == w_addr_max) ? 0 : w_addr + 1;

  register #(
    .WORD_WIDTH   (W_ADDR_WIDTH), 
    .RESET_VALUE  (0)
  ) W_ADDR (
    .clock        (clk           ),
    .clock_enable (clken && w_en ),
    .resetn       (resetn        ),
    .data_in      (w_addr_next   ),
    .data_out     (w_addr        )
  );
  logic [R_DEPTH-1:0] w_sel;

  generate
    for (genvar r=0; r<R_DEPTH; r++) begin: REG

      assign w_sel[r] = w_en && (w_addr == r/RATIO);

      // Cyclic read
      assign r_data_in [r] = (r_addr_max==r) ? r_data_out [0] : r_data_out [(r+1) % R_DEPTH];

      // Data select
      assign data_in [r] = w_sel[r] ? w_data_in [r%RATIO] : r_data_in [r];
      
      // Registers
      register #(
        .WORD_WIDTH   (R_DATA_WIDTH), 
        .RESET_VALUE  (0)
      ) REG (
        .clock        (clk            ),
        .clock_enable (clken && (r_en || w_sel[r])),
        .resetn       (resetn         ),
        .data_in      (data_in    [r] ),
        .data_out     (r_data_out [r] )
      );
    end

    assign r_data_latency[0] = r_data_out [0];

    for (genvar l=0; l<LATENCY; l++) begin
      register #(
        .WORD_WIDTH   (R_DATA_WIDTH), 
        .RESET_VALUE  (0)
      ) OUT_REG (
        .clock        (clk                  ),
        .clock_enable (clken && r_en        ),
        .resetn       (resetn               ),
        .data_in      (r_data_latency [l  ] ),
        .data_out     (r_data_latency [l+1] )
      );
    end

    assign m_data = r_data_latency[LATENCY];

  endgenerate
  
endmodule