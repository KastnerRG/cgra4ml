  /*
    OUTPUT REORDER SCHEME

    - Input and output of maxpool is in big-endian GUC order.
        This is to make it easier to write RTL for loops:
          for g:cores, for u:units and then max across c.
    - But DMA might need continous tkeep values, with high at index:0 and low at index:max
    - So, m_data_guc[G][U][C] is reordered into m_data_guc[C-0][G-0][U-0] and flattened
  
  */

module maxpool_engine #(
    parameter UNITS      = 2,
    parameter GROUPS     = 2,
    parameter MEMBERS    = 8,
    parameter WORD_WIDTH = 8,
    parameter KERNEL_W_MAX = 3,

    parameter I_IS_NOT_MAX = 0,
    parameter I_IS_MAX     = 1,
    parameter I_IS_1X1     = 2
  )(
    clk,
    clken,
    resetn,

    s_valid,
    s_data_flat_cgu,
    s_ready,
    s_user,

    m_valid,
    m_data_flat_cgu,
    m_keep_flat_cgu,
    m_last
  );

  localparam TUSER_WIDTH = I_IS_1X1 + 1;

  input  logic clk, clken, resetn;
  input  logic s_valid;
  output logic m_valid, s_ready, m_last;
  input  logic [TUSER_WIDTH-1:0] s_user;

  input  logic [GROUPS*UNITS*2*WORD_WIDTH-1:0] s_data_flat_cgu;
  output logic [GROUPS*UNITS*2*WORD_WIDTH-1:0] m_data_flat_cgu;
  output logic [GROUPS*UNITS*2-1:0]            m_keep_flat_cgu;

  logic signed [WORD_WIDTH-1:0] s_data_cgu [1:0][GROUPS-1:0][UNITS-1:0];
  logic signed [WORD_WIDTH-1:0] m_data_cgu [1:0][GROUPS-1:0][UNITS-1:0];
  logic                         m_keep_cgu [1:0][GROUPS-1:0][UNITS-1:0];

  assign s_data_cgu = {>>{s_data_flat_cgu}};
  assign {>>{m_data_flat_cgu}} = m_data_cgu;
  assign {>>{m_keep_flat_cgu}} = m_keep_cgu;

  logic signed [WORD_WIDTH-1:0] s_data_guc [GROUPS-1:0][UNITS-1:0][1:0];
  logic signed [WORD_WIDTH-1:0] m_data_guc [GROUPS-1:0][UNITS-1:0][1:0];
  logic                         m_keep_guc [GROUPS-1:0][UNITS-1:0][1:0];

  generate
    for (genvar c=0; c<2; c++) begin
      for (genvar g=0; g<GROUPS; g++) begin
        for (genvar u=0; u<UNITS; u++) begin
          
          assign s_data_guc[g][u][c] = s_data_cgu[c][g][u];

          assign m_data_cgu[c][g][u] = m_data_guc[g][u][c];
          assign m_keep_cgu[c][g][u] = m_keep_guc[g][u][c];
          
          /*
            Same, less readable

            assign m_data_flat_cgu[(GROUPS*UNITS*c + UNITS*g + u +1)*WORD_WIDTH-1:(GROUPS*UNITS*c + UNITS*g + u)*WORD_WIDTH] = m_data_guc[g][u][c];
            assign m_keep_flat_cgu[(GROUPS*UNITS*c + UNITS*g + u +1)           -1:(GROUPS*UNITS*c + UNITS*g + u)           ] = m_keep_guc[g][u][c];
          */
        end
      end
    end
  endgenerate


  logic s_ready_cores [GROUPS];
  logic m_valid_cores [GROUPS];
  logic m_last_cores  [GROUPS];

  assign s_ready = s_ready_cores[0];
  assign m_valid = m_valid_cores[0];
  assign m_last  = m_last_cores [0];

  generate
    for (genvar i = 0; i < GROUPS; i++) begin: cores
      maxpool_core #(
        .UNITS            (UNITS           ),
        .MEMBERS          (MEMBERS         ),
        .WORD_WIDTH       (WORD_WIDTH      ),
        .KERNEL_W_MAX     (KERNEL_W_MAX    ),
        .I_IS_NOT_MAX     (I_IS_NOT_MAX    ),
        .I_IS_MAX         (I_IS_MAX        ),
        .I_IS_1X1         (I_IS_1X1        )
      ) max_core (
        .clk      (clk             ),
        .clken    (clken           ),
        .resetn   (resetn          ),
        .s_valid  (s_valid         ),
        .s_data_uc(s_data_guc   [i]),
        .s_ready  (s_ready_cores[i]),
        .s_user   (s_user          ),
        .m_valid  (m_valid_cores[i]),
        .m_data_uc(m_data_guc   [i]),
        .m_keep_uc(m_keep_guc   [i]),
        .m_last   (m_last_cores [i])
      );
    end
  endgenerate

endmodule