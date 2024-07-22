`timescale 1ns/1ps
`define VERILOG
`include "defines.svh"
`undef  VERILOG

module dnn_engine #(
    parameter   ROWS                    = `ROWS               ,
                COLS                    = `COLS               ,
                X_BITS                  = `X_BITS             , 
                K_BITS                  = `K_BITS             , 
                Y_BITS                  = `Y_BITS             ,
                Y_OUT_BITS              = `Y_OUT_BITS         ,
                M_DATA_WIDTH_HF_CONV    = COLS  * ROWS  * Y_BITS,
                M_DATA_WIDTH_HF_CONV_DW = ROWS  * Y_BITS      ,

                AXI_WIDTH               = `AXI_WIDTH          ,
                W_BPT                   = `W_BPT              ,
                HEADER_WIDTH             = `HEADER_WIDTH        ,

                OUT_ADDR_WIDTH          = 10,
                OUT_BITS                = 32
  )(
    input  wire aclk,
    input  wire aresetn,

    output wire s_axis_pixels_tready,
    input  wire s_axis_pixels_tvalid,
    input  wire s_axis_pixels_tlast ,
    input  wire [AXI_WIDTH  -1:0]   s_axis_pixels_tdata,
    input  wire [AXI_WIDTH/8-1:0]   s_axis_pixels_tkeep,
    input  wire [HEADER_WIDTH  :0]   s_axis_pixels_tuser, // header + 1

    output wire s_axis_weights_tready,
    input  wire s_axis_weights_tvalid,
    input  wire s_axis_weights_tlast ,
    input  wire [AXI_WIDTH  -1:0]  s_axis_weights_tdata,
    input  wire [AXI_WIDTH/8-1:0]  s_axis_weights_tkeep,
    input  wire [HEADER_WIDTH  :0]  s_axis_weights_tuser, // header + 1

    input  wire m_axis_tready, 
    output wire m_axis_tvalid, m_axis_tlast,
    output wire [AXI_WIDTH   -1:0] m_axis_tdata,
    output wire [AXI_WIDTH/8 -1:0] m_axis_tkeep,
    output wire [W_BPT-1:0] m_bytes_per_transfer
  ); 

  localparam  TUSER_WIDTH = `TUSER_WIDTH;

  /* WIRES */

  wire pixels_m_valid, pixels_m_ready;
  wire [COLS-1:0] weights_m_valid, weights_m_ready, weights_m_last;
  wire [COLS-1:0] conv_s_valid, conv_s_ready;
  wire [X_BITS*ROWS -1:0] pixels_m_data;
  wire [K_BITS*COLS -1:0] weights_m_data;
  wire [COLS*TUSER_WIDTH -1:0] weights_m_user;
  wire [W_BPT-1:0] s_bytes_per_transfer;
  wire [COLS-1:0] pixels_m_valid_pipe;
  //wire [1:0] weights_rd_state;


  // Unpack tkeep_bytes into tkeep_words
  wire [AXI_WIDTH /X_BITS-1:0]  s_axis_pixels_tkeep_words;
  wire [AXI_WIDTH/K_BITS-1:0]  s_axis_weights_tkeep_words;

  genvar ik, ix;
  generate
    for (ix=0; ix<AXI_WIDTH/X_BITS; ix=ix+1) begin : px_keep
      assign s_axis_pixels_tkeep_words[ix] = s_axis_pixels_tkeep[ix/(8/X_BITS)];
    end

    for (ik=0; ik<AXI_WIDTH/K_BITS; ik=ik+1) begin : wt_keep
      assign s_axis_weights_tkeep_words[ik] = s_axis_weights_tkeep[ik/(8/K_BITS)];
    end
  endgenerate

  axis_pixels PIXELS (
    .aclk   (aclk   ),
    .aresetn(aresetn),
    .s_ready(s_axis_pixels_tready),
    .s_valid(s_axis_pixels_tvalid),
    .s_last (s_axis_pixels_tlast ),
    .s_data (s_axis_pixels_tdata ),
    .s_user (s_axis_pixels_tuser ),
    .s_keep (s_axis_pixels_tkeep_words),
    .m_valid(pixels_m_valid      ),
    .m_ready(pixels_m_ready      ),
    .m_data (pixels_m_data       )
  );

  axis_weight_rotator WEIGHTS_ROTATOR (
    .aclk          (aclk                 ),
    .aresetn       (aresetn              ),
    .s_axis_tready (s_axis_weights_tready), 
    .s_axis_tvalid (s_axis_weights_tvalid), 
    .s_axis_tlast  (s_axis_weights_tlast ), 
    .s_axis_tdata  (s_axis_weights_tdata ),
    .s_axis_tkeep  (s_axis_weights_tkeep_words),
    .s_axis_tuser  (s_axis_weights_tuser ),
    .m_axis_tready (weights_m_ready      ),      
    .m_axis_tvalid (weights_m_valid      ),   
    .m_axis_tdata  (weights_m_data       ),
    .m_axis_tlast  (weights_m_last       ),
    //.m_rd_state (weights_rd_state),
    .m_axis_tuser  (weights_m_user       ) 
  );

  axis_sync SYNC (
    .aclk(aclk),
    .weights_m_valid (weights_m_valid), 
    .pixels_m_valid  (pixels_m_valid ), 
    .m_axis_tready   (conv_s_ready   ),
    .weights_m_user  (weights_m_user ),
    .pixels_m_valid_pipe(pixels_m_valid_pipe),
    //.weights_rd_state (weights_rd_state),
    .m_axis_tvalid   (conv_s_valid   ), 
    .weights_m_ready (weights_m_ready), 
    .pixels_m_ready  (pixels_m_ready ) 
  );

  wire m_ready, m_valid, m_last;
  wire [M_DATA_WIDTH_HF_CONV_DW -1:0] m_data;

  proc_engine_out PROC_OUT (
    .aclk           (aclk    ),
    .aresetn        (aresetn ),
    .s_valid        (conv_s_valid               ),
    .s_ready        (conv_s_ready               ),
    .pixels_m_valid_pipe(pixels_m_valid_pipe),
    .s_last         (weights_m_last             ),
    .s_user         (weights_m_user             ),
    .s_data_pixels  (pixels_m_data              ),
    .s_data_weights (weights_m_data             ),
    .pixels_m_valid  (pixels_m_valid            ), 
    .m_ready        (m_ready                    ),
    .m_valid        (m_valid                    ),
    .m_data         (m_data                     ),
    .m_last_pkt     (),
    .m_last         (m_last                     ),
    .m_bytes_per_transfer  (s_bytes_per_transfer)
  );

  localparam Y_PADDING     = Y_OUT_BITS-Y_BITS;
  wire [Y_OUT_BITS*ROWS-1:0] m_data_padded;
  genvar iy;
  generate
    for (iy=0; iy<ROWS; iy=iy+1) begin : R
      // Sign padding: can be done as $signed(), but verilator gives warning for width mismatch
      wire sign_bit = m_data[Y_BITS*(iy+1)-1];
      assign m_data_padded[Y_OUT_BITS*(iy+1)-1:Y_OUT_BITS*iy] = {{Y_PADDING{sign_bit}}, m_data[Y_BITS*(iy+1)-1:Y_BITS*iy]};
    end
  endgenerate
  

  alex_axis_adapter_any #(
    .S_DATA_WIDTH  (Y_OUT_BITS*ROWS),
    .M_DATA_WIDTH  (AXI_WIDTH ),
    .S_KEEP_ENABLE (1),
    .M_KEEP_ENABLE (1),
    .S_KEEP_WIDTH  (Y_OUT_BITS*ROWS/8),
    .M_KEEP_WIDTH  (AXI_WIDTH/8),
    .ID_ENABLE     (0),
    .DEST_ENABLE   (0),
    .USER_WIDTH    (W_BPT),
    .USER_ENABLE   (1)
  ) DW (
    .clk           (aclk         ),
    .rstn          (aresetn      ),
    .s_axis_tready (m_ready      ),
    .s_axis_tvalid (m_valid      ),
    .s_axis_tdata  (m_data_padded),
    .s_axis_tlast  (m_last       ),
    .s_axis_tkeep  ({(Y_OUT_BITS*ROWS/8){1'b1}}),
    .m_axis_tready (m_axis_tready),
    .m_axis_tvalid (m_axis_tvalid),
    .m_axis_tdata  (m_axis_tdata ),
    .m_axis_tlast  (m_axis_tlast ),
    .m_axis_tkeep  (m_axis_tkeep ),
    .s_axis_tid    (8'b0),
    .s_axis_tdest  (8'b0),
    .s_axis_tuser  (s_bytes_per_transfer),
    .m_axis_tid    (),
    .m_axis_tdest  (),
    .m_axis_tuser  (m_bytes_per_transfer)
  );
endmodule


module proc_engine_out #(
  parameter 
    M_DATA_WIDTH_HF_CONV = `COLS  * `ROWS  * `Y_BITS,
    M_DATA_WIDTH_HF_CONV_DW = `ROWS  * `Y_BITS,
    COLS = `COLS,
    W_BPT                   = `W_BPT,
    TUSER_WIDTH = `TUSER_WIDTH
)(
    input wire aclk          ,
    input wire aresetn       ,
    input wire [COLS-1:0] s_valid       ,
    output wire[COLS-1:0] s_ready       ,
    input wire [COLS-1:0] s_last        ,
    input wire [COLS*TUSER_WIDTH  -1:0] s_user        ,
    input wire [`X_BITS*`ROWS -1:0] s_data_pixels ,
    input wire [`K_BITS*`COLS -1:0] s_data_weights,
    input wire pixels_m_valid,
    output wire [COLS-1:0] pixels_m_valid_pipe,

    input wire m_ready,
    output wire m_valid,
    output wire [M_DATA_WIDTH_HF_CONV_DW-1:0] m_data,
    output wire m_last_pkt,
    output wire m_last,
    output wire [W_BPT-1:0] m_bytes_per_transfer
  );

  wire conv_m_axis_tready, conv_m_axis_tvalid, conv_m_axis_tlast ;
  wire [`TUSER_WIDTH         -1:0] conv_m_axis_tuser;
  wire [M_DATA_WIDTH_HF_CONV -1:0] conv_m_axis_tdata; // cgmu

  proc_engine PROC_ENGINE (
    .clk            (aclk    ),
    .resetn         (aresetn ),
    .s_valid        (s_valid                    ),
    .s_ready        (s_ready                    ),
    .s_last         (s_last                     ),
    .s_user         (s_user                     ),
    .s_data_pixels  (s_data_pixels              ),
    .s_data_weights (s_data_weights             ),
    .pixels_m_valid (pixels_m_valid),
    .pixels_m_valid_pipe(pixels_m_valid_pipe),
    // .m_valid        (conv_m_axis_tvalid         ),
    // .m_ready        (conv_m_axis_tready         ),
    // .m_data         (conv_m_axis_tdata          ),
    // .m_last         (conv_m_axis_tlast          ),
    // .m_user         (conv_m_axis_tuser          )
    .m_ready (m_ready               ),
    .m_valid (m_valid               ),
    .m_data  (m_data                ),
    .m_last_pkt (m_last_pkt         ),
    .m_last     (m_last             ),
    .m_bytes_per_transfer  (m_bytes_per_transfer)
  );
  // axis_out_shift OUT (
  //   .aclk    (aclk   ),
  //   .aresetn (aresetn),
  //   .s_ready (conv_m_axis_tready    ),
  //   .s_valid (conv_m_axis_tvalid    ),
  //   .s_data  (conv_m_axis_tdata     ),
  //   .s_user  (conv_m_axis_tuser     ),
  //   .s_last  (conv_m_axis_tlast     ),
  //   .m_ready (m_ready               ),
  //   .m_valid (m_valid               ),
  //   .m_data  (m_data                ),
  //   .m_last_pkt (m_last_pkt         ),
  //   .m_last     (m_last             ),
  //   .m_bytes_per_transfer  (m_bytes_per_transfer)
  // );

endmodule
