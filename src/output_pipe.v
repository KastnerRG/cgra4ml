`include "system_parameters.v"

module output_pipe #(
    parameter DATA_WIDTH              = `DATA_WIDTH,
    parameter CONV_PAIRS              = `CONV_PAIRS,
    parameter OUTPUT_DMA_WIDTH        = `OUTPUT_DMA_WIDTH,
    parameter CONV_UNITS              = `CONV_UNITS,
    parameter CONV_CORES              = `CONV_CORES,
    parameter p_COUNT_3x3_ref         = `p_COUNT_3x3_ref,
    parameter p_COUNT_3x3_max_ref     = `p_COUNT_3x3_max_ref,
    parameter p_COUNT_1x1_ref         = `p_COUNT_1x1_ref,
    parameter p_COUNT_1x1_max_ref     = `p_COUNT_1x1_max_ref
)(
    aclk,
    aresetn,

    is_maxpool,
    is_3x3,

    // AXIS input
    S_AXIS_tdata,
    S_AXIS_tvalid,
    S_AXIS_tready,

    // AXIS output
    M_AXIS_tdata,
    M_AXIS_tvalid,
    M_AXIS_tlast,
    M_AXIS_tready
);
  
  input aclk;
  input aresetn;

  input is_maxpool;
  input is_3x3;

  // AXIS input
  input [CONV_PAIRS*2*DATA_WIDTH-1:0]  S_AXIS_tdata;
  input S_AXIS_tvalid;
  output reg S_AXIS_tready;

  // AXIS output
  output reg [OUTPUT_DMA_WIDTH-1:0]  M_AXIS_tdata;
  output reg M_AXIS_tvalid;
  output M_AXIS_tlast;
  input M_AXIS_tready;

  reg  [$clog2(p_COUNT_3x3_ref     + 1) : 0] COUNT_3x3_ref     = p_COUNT_3x3_ref;
  reg  [$clog2(p_COUNT_3x3_max_ref + 1) : 0] COUNT_3x3_max_ref = p_COUNT_3x3_max_ref;
  reg  [$clog2(p_COUNT_1x1_ref     + 1) : 0] COUNT_1x1_ref     = p_COUNT_1x1_ref;
  reg  [$clog2(p_COUNT_1x1_max_ref + 1) : 0] COUNT_1x1_max_ref = p_COUNT_1x1_max_ref;

  reg  [$clog2(p_COUNT_1x1_ref     + 1) : 0] count             = 0;
  reg  [$clog2(p_COUNT_1x1_ref     + 1) : 0] COUNT_ref;

  wire count_equal;
  wire v_and_r;

  reg                                                 dw_18_s_tvalid;
  wire [CONV_CORES-1:0]                               dw_18_s_tready;
  wire [DATA_WIDTH*CONV_CORES-1:0]                    dw_18_s_tdata ;
  wire [CONV_CORES-1:0]                               dw_18_m_tvalid;
  wire                                                dw_18_m_tready;
  wire [CONV_UNITS*DATA_WIDTH*CONV_CORES-1:0]         dw_18_m_tdata ;
  wire [(CONV_UNITS+2)*DATA_WIDTH*CONV_CORES-1:0]     dw_1_10_m_tdata ;

  wire [DATA_WIDTH-1:0]                               data_mid_8        [CONV_UNITS*CONV_CORES-1:0];

  reg                                                 dw_14_s_tvalid;
  wire [CONV_CORES-1:0]                               dw_14_s_tready;
  wire [DATA_WIDTH*CONV_CORES-1:0]                    dw_14_s_tdata ;
  wire [CONV_CORES-1:0]                               dw_14_m_tvalid;
  wire                                                dw_14_m_tready;
  wire [CONV_UNITS*DATA_WIDTH*CONV_CORES/2      -1:0] dw_14_m_tdata ;
  wire [(CONV_UNITS+2)*DATA_WIDTH*CONV_CORES/2  -1:0] dw_1_5_m_tdata ;

  wire [DATA_WIDTH-1:0]                             data_mid_4        [CONV_UNITS*CONV_PAIRS-1:0];
  

  genvar i;
  generate
      // Debug
      for (i=0; i < CONV_UNITS*CONV_PAIRS; i=i+1) begin: connect_mid_4
        assign data_mid_4[i] = dw_14_m_tdata  [(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH];
      end
      for (i=0; i < CONV_UNITS*CONV_CORES; i=i+1) begin: connect_mid_8
        assign data_mid_8[i] = dw_18_m_tdata  [(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH];
      end
      // End Debug

      for (i=0; i < CONV_CORES; i=i+1) begin: connect_cores
        axis_dwidth_converter_5 DW_1_8(
        // axis_dw_1_8 DW_1_8 (
          .aclk           (aclk                                               ),                        // input wire aclk
          .aresetn        (aresetn                                            ),                        // input wire aresetn
          .s_axis_tvalid  (dw_18_s_tvalid                                     ),                        // input wire s_axis_tvalid
          .s_axis_tready  (dw_18_s_tready [i]                                 ),                        // output wire s_axis_tready
          .s_axis_tdata   (dw_18_s_tdata  [(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH] ),                        // input wire [15 : 0] s_axis_tdata

          .m_axis_tvalid  (dw_18_m_tvalid [i]                                                       ),  // output wire m_axis_tvalid
          .m_axis_tready  (dw_18_m_tready                                                           ),  // input wire m_axis_tready
          .m_axis_tdata   (dw_18_m_tdata  [CONV_UNITS*(i+1)*DATA_WIDTH-1 : CONV_UNITS*i*DATA_WIDTH] )  // output wire [127 : 0] m_axis_tdata
        );

        // axis_dw_1_4 DW_1_4 (
        axis_dwidth_converter_6 DW_1_4 (
          .aclk           (aclk),                    // input wire aclk
          .aresetn        (aresetn),              // input wire aresetn
          .s_axis_tvalid  (dw_14_s_tvalid),  // input wire s_axis_tvalid
          .s_axis_tready  (dw_14_s_tready[i]),  // output wire s_axis_tready
          .s_axis_tdata   (dw_14_s_tdata  [(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH]),    // input wire [15 : 0] s_axis_tdata

          .m_axis_tvalid  (dw_14_m_tvalid [i]),  // output wire m_axis_tvalid
          .m_axis_tready  (dw_14_m_tready),  // input wire m_axis_tready
          .m_axis_tdata   (dw_14_m_tdata  [(i+1)*CONV_UNITS*DATA_WIDTH/2-1 : i*CONV_UNITS*DATA_WIDTH/2])   // output wire [127 : 0] m_axis_tdata
        );
      end

      for (i=0; i < CONV_CORES; i=i+1) begin: disperse_10
        assign dw_1_10_m_tdata [(CONV_UNITS+2)*(i+1)*DATA_WIDTH-1 : (CONV_UNITS+2)*i*DATA_WIDTH] = {{DATA_WIDTH{1'b0}}, dw_18_m_tdata[CONV_UNITS*(i+1)*DATA_WIDTH-1 : CONV_UNITS*i*DATA_WIDTH], {DATA_WIDTH{1'b0}}};
      end

      for (i=0; i < CONV_CORES/2; i=i+1) begin: disperse_5
        assign dw_1_5_m_tdata  [(CONV_UNITS+2)*(i+1)*DATA_WIDTH-1 : (CONV_UNITS+2)*i*DATA_WIDTH] = {{DATA_WIDTH{1'b0}}, dw_14_m_tdata[CONV_UNITS*(i+1)*DATA_WIDTH-1 : CONV_UNITS*i*DATA_WIDTH], {DATA_WIDTH{1'b0}}};
      end
  endgenerate




  wire                                              dw_10n_dma_s_tvalid;
  wire                                              dw_10n_dma_s_tready;
  wire [(CONV_UNITS+2)*DATA_WIDTH*CONV_CORES-1:0]   dw_10n_dma_s_tdata;
  wire                                              dw_10n_dma_m_tvalid;
  reg                                               dw_10n_dma_m_tready;
  wire [OUTPUT_DMA_WIDTH-1 :0]                      dw_10n_dma_m_tdata;
  // axis_dw_10n_dma dw_10n_dma (
  axis_dwidth_converter_7 dw_10n_dma (
    .aclk(aclk),                              // input wire aclk
    .aresetn(aresetn),                        // input wire aresetn
    .s_axis_tvalid    (dw_10n_dma_s_tvalid),   // input wire s_axis_tvalid
    .s_axis_tready    (dw_10n_dma_s_tready),   // output wire s_axis_tready
    .s_axis_tdata     (dw_10n_dma_s_tdata),    // input wire [127 : 0] s_axis_tdata
    .m_axis_tvalid    (dw_10n_dma_m_tvalid),   // output wire m_axis_tvalid
    .m_axis_tready    (dw_10n_dma_m_tready),   // input wire m_axis_tready
    .m_axis_tdata     (dw_10n_dma_m_tdata)    // output wire [31 : 0] m_axis_tdata
  );

  wire                                                dw_5n_dma_s_tvalid;
  wire                                                dw_5n_dma_s_tready;
  wire [(CONV_UNITS+2)*DATA_WIDTH*CONV_CORES/2-1:0]   dw_5n_dma_s_tdata;
  wire                                                dw_5n_dma_m_tvalid;
  reg                                                 dw_5n_dma_m_tready;
  wire [OUTPUT_DMA_WIDTH-1 :0]                        dw_5n_dma_m_tdata;
  // axis_dw_5n_dma dw_5n_dma (
  axis_dwidth_converter_8 dw_5n_dma (
    .aclk(aclk),                              // input wire aclk
    .aresetn(aresetn),                        // input wire aresetn
    .s_axis_tvalid    (dw_5n_dma_s_tvalid),   // input wire s_axis_tvalid
    .s_axis_tready    (dw_5n_dma_s_tready),   // output wire s_axis_tready
    .s_axis_tdata     (dw_5n_dma_s_tdata),    // input wire [127 : 0] s_axis_tdata
    .m_axis_tvalid    (dw_5n_dma_m_tvalid),   // output wire m_axis_tvalid
    .m_axis_tready    (dw_5n_dma_m_tready),   // input wire m_axis_tready
    .m_axis_tdata     (dw_5n_dma_m_tdata)    // output wire [31 : 0] m_axis_tdata
  );

//*** Logic

  assign dw_18_s_tdata      = S_AXIS_tdata;
  assign dw_14_s_tdata      = S_AXIS_tdata;

  assign dw_10n_dma_s_tdata  = dw_1_10_m_tdata;
  assign dw_10n_dma_s_tvalid = &dw_18_m_tvalid;
  assign dw_18_m_tready     = dw_10n_dma_s_tready;

  assign dw_5n_dma_s_tdata  = dw_1_5_m_tdata;
  assign dw_5n_dma_s_tvalid = &dw_14_m_tvalid;
  assign dw_14_m_tready     = dw_5n_dma_s_tready;

  assign M_AXIS_tlast       = count_equal && M_AXIS_tvalid; //v_and_r;
  assign count_equal        = (count == COUNT_ref);
  assign v_and_r            = M_AXIS_tvalid && M_AXIS_tready;

  always @ (*) begin
    if (is_maxpool) begin
      S_AXIS_tready       <= &dw_14_s_tready;

      dw_18_s_tvalid      <= 0;
      dw_14_s_tvalid      <= S_AXIS_tvalid;

      M_AXIS_tdata        <= dw_5n_dma_m_tdata;
      M_AXIS_tvalid       <= dw_5n_dma_m_tvalid;
      dw_5n_dma_m_tready  <= M_AXIS_tready;
      dw_10n_dma_m_tready  <= 0;
    end else begin
      S_AXIS_tready       <= &dw_18_s_tready;

      dw_18_s_tvalid      <= S_AXIS_tvalid;
      dw_14_s_tvalid      <= 0;

      M_AXIS_tdata        <= dw_10n_dma_m_tdata;
      M_AXIS_tvalid       <= dw_10n_dma_m_tvalid;
      dw_5n_dma_m_tready  <= 0;
      dw_10n_dma_m_tready  <= M_AXIS_tready;
    end
  end

  always @ (posedge aclk) begin
    case ({is_maxpool, is_3x3})
      2'b00 : COUNT_ref <= COUNT_1x1_ref;
      2'b01 : COUNT_ref <= COUNT_3x3_ref;
      2'b10 : COUNT_ref <= COUNT_1x1_max_ref;
      2'b11 : COUNT_ref <= COUNT_3x3_max_ref;
    endcase

    if (v_and_r) begin // Counting handshakes
      if (count_equal)
        count <= 0;
      else
        count <= count + 1'b1;
    end
  end

endmodule