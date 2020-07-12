`include "system_parameters.v"

module input_pipe #(
    parameter IMAGE_DMA_WIDTH   = `IMAGE_DMA_WIDTH,
    parameter WEIGHTS_DMA_WIDTH = `WEIGHTS_DMA_WIDTH,
    parameter DATA_WIDTH        = `DATA_WIDTH,
    parameter CONV_PAIRS        = `CONV_PAIRS,
    parameter CONV_UNITS        = `CONV_UNITS,
    parameter CONV_CORES        = `CONV_CORES,
    parameter Nb                = `Nb
)(
    aclk,
    aresetn,

    is_maxpool,
    is_3x3,
    
    // Weights DMA in
    S_W_DMA_AXIS_tdata,
    S_W_DMA_AXIS_tvalid,
    S_W_DMA_AXIS_tready,
    S_W_DMA_AXIS_tkeep,
    S_W_DMA_AXIS_tlast,

    // Image DMA in
    S_IM_DMA_0_AXIS_tdata,
    S_IM_DMA_0_AXIS_tvalid,
    S_IM_DMA_0_AXIS_tready,
    S_IM_DMA_0_AXIS_tkeep,
    S_IM_DMA_0_AXIS_tlast,

    // Image DMA in
    S_IM_DMA_1_AXIS_tdata,
    S_IM_DMA_1_AXIS_tvalid,
    S_IM_DMA_1_AXIS_tready,
    S_IM_DMA_1_AXIS_tkeep,
    S_IM_DMA_1_AXIS_tlast,

    // Weights Rotator in
    S_W_ROTATOR_AXIS_tdata,
    S_W_ROTATOR_AXIS_tvalid,
    S_W_ROTATOR_AXIS_tready,

    // Weights Rotator out
    M_W_ROTATOR_AXIS_tdata,
    M_W_ROTATOR_AXIS_tvalid,
    M_W_ROTATOR_AXIS_tready,

    // AXIS Master (Output)
    M_AXIS_tready,
    M_AXIS_tvalid,
    weights,
    image

);

input   aclk;
input   aresetn;

input   is_maxpool;
input   is_3x3;
reg     is_edges = 0;

// Weights DMA in
input [WEIGHTS_DMA_WIDTH-1:0]   S_W_DMA_AXIS_tdata;
input                           S_W_DMA_AXIS_tvalid;
output                          S_W_DMA_AXIS_tready;
input [WEIGHTS_DMA_WIDTH/8-1:0] S_W_DMA_AXIS_tkeep;
input                           S_W_DMA_AXIS_tlast;

// Image DMA in top
input [IMAGE_DMA_WIDTH-1:0]     S_IM_DMA_0_AXIS_tdata;
input                           S_IM_DMA_0_AXIS_tvalid;
output                          S_IM_DMA_0_AXIS_tready;
input [IMAGE_DMA_WIDTH/8-1:0]   S_IM_DMA_0_AXIS_tkeep;
input                           S_IM_DMA_0_AXIS_tlast;

// Image DMA in bot
input [IMAGE_DMA_WIDTH-1:0]     S_IM_DMA_1_AXIS_tdata;
input                           S_IM_DMA_1_AXIS_tvalid;
output reg                      S_IM_DMA_1_AXIS_tready;
input [IMAGE_DMA_WIDTH/8-1:0]   S_IM_DMA_1_AXIS_tkeep;
input                           S_IM_DMA_1_AXIS_tlast;

// Weights Rotator out
output     [3*Nb-1:0]           M_W_ROTATOR_AXIS_tdata;
output                          M_W_ROTATOR_AXIS_tvalid;
input                           M_W_ROTATOR_AXIS_tready;

// Weights Rotator in
input [3*Nb-1:0]                S_W_ROTATOR_AXIS_tdata;
input                           S_W_ROTATOR_AXIS_tvalid;
output reg                      S_W_ROTATOR_AXIS_tready;

// AXIS Master (Output)
input                                                   M_AXIS_tready;
output reg                                              M_AXIS_tvalid;
output reg [(9*Nb)-1:0]                                 weights;
output     [2*(CONV_UNITS+2)*DATA_WIDTH-1:0]            image;

//Others
wire    im_v_and_r;
wire     w_v_and_r;
reg     im_valid;
reg     weights_valid;

reg [DATA_WIDTH-1:0             ]  im_0_top;
reg [CONV_UNITS*DATA_WIDTH-1:0  ]  im_0_mid;
reg [DATA_WIDTH-1:0             ]  im_0_bot;
reg [DATA_WIDTH-1:0             ]  im_1_top;
reg [CONV_UNITS*DATA_WIDTH-1:0  ]  im_1_mid;
reg [DATA_WIDTH-1:0             ]  im_1_bot;

// wire [DATA_WIDTH-1: 0] edges_top;
// wire [DATA_WIDTH-1: 0] edges_bot;
wire [DATA_WIDTH-1: 0] dw_0_10_top;
wire [DATA_WIDTH-1: 0] dw_0_10_bot;
wire [DATA_WIDTH-1: 0] dw_1_10_top;
wire [DATA_WIDTH-1: 0] dw_1_10_bot;
wire [CONV_UNITS*DATA_WIDTH-1: 0] dw_0_10_mid;
wire [CONV_UNITS*DATA_WIDTH-1: 0] dw_1_10_mid;

wire [9*Nb-1:0] dispersed_weights_3n_9n;
wire [9*Nb-1:0] dispersed_weights_9n2_9n ;



//*************** Sync signals *********************
assign im_v_and_r  = im_valid && M_AXIS_tready;
assign  w_v_and_r  = weights_valid && M_AXIS_tready;

always @ (*) begin
    if (~aresetn)
        M_AXIS_tvalid <= 0;
    else
        M_AXIS_tvalid <= im_valid && weights_valid;
end

//**************** Image Routing ********************

//*** Instantitations
wire                                    dw_0_10_s_tvalid;
wire                                    dw_0_10_s_tready;
wire [IMAGE_DMA_WIDTH-1   :0]           dw_0_10_s_tdata;
wire [IMAGE_DMA_WIDTH/8-1 :0]           dw_0_10_s_tkeep;
wire                                    dw_0_10_s_tlast;
wire                                    dw_0_10_m_tvalid;
reg                                     dw_0_10_m_tready;
wire [(CONV_UNITS+2)*DATA_WIDTH-1:0]    dw_0_10_m_tdata;
// axis_dw_10 DW_0_10 (
axis_dwidth_converter_3 DW_0_10 (
  .aclk(aclk),                          // input wire aclk
  .aresetn(aresetn),                    // input wire aresetn
  .s_axis_tvalid  (dw_0_10_s_tvalid),   // input wire s_axis_tvalid
  .s_axis_tready  (dw_0_10_s_tready),   // output wire s_axis_tready
  .s_axis_tdata   (dw_0_10_s_tdata),    // input wire  s_axis_tdata
  .s_axis_tkeep   (dw_0_10_s_tkeep),    // input wire  s_axis_tdata
  .s_axis_tlast   (dw_0_10_s_tlast),   // input wire s_axis_tvalid

  .m_axis_tvalid  (dw_0_10_m_tvalid),   // output wire m_axis_tvalid
  .m_axis_tready  (dw_0_10_m_tready),   // input wire m_axis_tready
  .m_axis_tdata   (dw_0_10_m_tdata)     // output wire  m_axis_tdata
);

wire                                   dw_1_10_s_tvalid;
wire                                   dw_1_10_s_tready;
wire                                   dw_1_10_s_tlast;
wire [IMAGE_DMA_WIDTH-1   :0]          dw_1_10_s_tdata;
wire [IMAGE_DMA_WIDTH/8-1 :0]          dw_1_10_s_tkeep;
wire                                   dw_1_10_m_tvalid;
reg                                    dw_1_10_m_tready;
wire [(CONV_UNITS+2)*DATA_WIDTH-1:0]   dw_1_10_m_tdata;
// axis_dw_10 DW_1_10 (
axis_dwidth_converter_3 DW_1_10 (
  .aclk(aclk),                          // input wire aclk
  .aresetn(aresetn),                    // input wire aresetn
  .s_axis_tvalid  (dw_1_10_s_tvalid),   // input wire s_axis_tvalid
  .s_axis_tready  (dw_1_10_s_tready),   // output wire s_axis_tready
  .s_axis_tdata   (dw_1_10_s_tdata),    // input wire  s_axis_tdata`
  .s_axis_tkeep   (dw_1_10_s_tkeep),    // input wire  s_axis_tdata`
  .s_axis_tlast   (dw_1_10_s_tlast),   // input wire s_axis_tvalid

  .m_axis_tvalid  (dw_1_10_m_tvalid),   // output wire m_axis_tvalid
  .m_axis_tready  (dw_1_10_m_tready),   // input wire m_axis_tready
  .m_axis_tdata   (dw_1_10_m_tdata)     // output wire  m_axis_tdata
);

// wire                                    dw_0_8_s_tvalid;
// wire                                    dw_0_8_s_tready;
// wire [IMAGE_DMA_WIDTH   -1  :0]         dw_0_8_s_tdata;
// wire [IMAGE_DMA_WIDTH/8 -1  :0]         dw_0_8_s_tkeep;
// wire                                    dw_0_8_s_tlast;
// wire                                    dw_0_8_m_tvalid;
// reg                                     dw_0_8_m_tready;
// wire [CONV_UNITS*DATA_WIDTH-1:0]        dw_0_8_m_tdata;
// // axis_dw_8 DW_0_8 (
// axis_dwidth_converter_4 DW_0_8 (
//   .aclk(aclk),                          // input wire aclk
//   .aresetn(aresetn),                    // input wire aresetn
//   .s_axis_tvalid  (dw_0_8_s_tvalid),    // input wire s_axis_tvalid
//   .s_axis_tready  (dw_0_8_s_tready),    // output wire s_axis_tready
//   .s_axis_tdata   (dw_0_8_s_tdata),     // input wire  s_axis_tdata
//   .s_axis_tkeep   (dw_0_8_s_tkeep),     // input wire  s_axis_tdata
//   .s_axis_tlast   (dw_0_8_s_tlast),    // input wire s_axis_tvalid

//   .m_axis_tvalid  (dw_0_8_m_tvalid),    // output wire m_axis_tvalid
//   .m_axis_tready  (dw_0_8_m_tready),    // input wire m_axis_tready
//   .m_axis_tdata   (dw_0_8_m_tdata)      // output wire  m_axis_tdata
// );

// wire                                    dw_1_8_s_tvalid;
// wire                                    dw_1_8_s_tready;
// wire [IMAGE_DMA_WIDTH    -1  :0]        dw_1_8_s_tdata;
// wire [IMAGE_DMA_WIDTH/8  -1  :0]        dw_1_8_s_tkeep;
// wire                                    dw_1_8_s_tlast;
// wire                                    dw_1_8_m_tvalid;
// reg                                     dw_1_8_m_tready;
// wire [CONV_UNITS*DATA_WIDTH-1:0]        dw_1_8_m_tdata;
// // axis_dw_8 DW_1_8 (
// axis_dwidth_converter_4 DW_1_8 (
//   .aclk(aclk),                          // input wire aclk
//   .aresetn(aresetn),                    // input wire aresetn
//   .s_axis_tvalid  (dw_1_8_s_tvalid),    // input wire s_axis_tvalid
//   .s_axis_tready  (dw_1_8_s_tready),    // output wire s_axis_tready
//   .s_axis_tdata   (dw_1_8_s_tdata),     // input wire  s_axis_tdata
//   .s_axis_tkeep   (dw_1_8_s_tkeep),     // input wire  s_axis_tdata
//   .s_axis_tlast  (dw_1_8_s_tlast),    // input wire s_axis_tvalid

//   .m_axis_tvalid  (dw_1_8_m_tvalid),    // output wire m_axis_tvalid
//   .m_axis_tready  (dw_1_8_m_tready),    // input wire m_axis_tready
//   .m_axis_tdata   (dw_1_8_m_tdata)      // output wire  m_axis_tdata
// );


//*** Splitting wires

// assign edges_top    = S_EDGE_AXIS_tdata [               DATA_WIDTH-1  : 0];
// assign edges_bot    = S_EDGE_AXIS_tdata [             2*DATA_WIDTH-1  : DATA_WIDTH];
assign dw_0_10_top  = dw_0_10_m_tdata   [               DATA_WIDTH-1  : 0];
assign dw_0_10_mid  = dw_0_10_m_tdata   [             9*DATA_WIDTH-1  : DATA_WIDTH];
assign dw_0_10_bot  = dw_0_10_m_tdata   [(CONV_UNITS+2)*DATA_WIDTH-1  : (CONV_UNITS+1)*DATA_WIDTH];
assign dw_1_10_top  = dw_1_10_m_tdata   [               DATA_WIDTH-1  : 0];
assign dw_1_10_mid  = dw_1_10_m_tdata   [             9*DATA_WIDTH-1  : DATA_WIDTH];
assign dw_1_10_bot  = dw_1_10_m_tdata   [(CONV_UNITS+2)*DATA_WIDTH-1  : (CONV_UNITS+1)*DATA_WIDTH];

assign dw_0_10_s_tdata  = S_IM_DMA_0_AXIS_tdata;
assign dw_0_10_s_tvalid = S_IM_DMA_0_AXIS_tvalid;
assign dw_0_10_s_tkeep  = S_IM_DMA_0_AXIS_tkeep;
assign dw_0_10_s_tlast  = S_IM_DMA_0_AXIS_tlast;

// assign dw_0_8_s_tdata   = S_IM_DMA_0_AXIS_tdata;
// assign dw_0_8_s_tvalid  = S_IM_DMA_0_AXIS_tvalid;
// assign dw_0_8_s_tkeep   = S_IM_DMA_0_AXIS_tkeep;
// assign dw_0_8_s_tlast   = S_IM_DMA_0_AXIS_tlast;

assign dw_1_10_s_tdata  = S_IM_DMA_1_AXIS_tdata;
assign dw_1_10_s_tvalid = S_IM_DMA_1_AXIS_tvalid;
assign dw_1_10_s_tkeep  = S_IM_DMA_1_AXIS_tkeep;
assign dw_1_10_s_last  = S_IM_DMA_1_AXIS_tlast;

// assign dw_1_8_s_tdata   = S_IM_DMA_1_AXIS_tdata;
// assign dw_1_8_s_tvalid  = S_IM_DMA_1_AXIS_tvalid;
// assign dw_1_8_s_tkeep   = S_IM_DMA_1_AXIS_tkeep;
// assign dw_1_8_s_tlast   = S_IM_DMA_1_AXIS_tlast;

assign image            = {im_1_bot, im_1_mid, im_1_top, im_0_bot, im_0_mid, im_0_top};

//*** Routing

//assign S_IM_DMA_0_AXIS_tready = is_edges ? dw_0_8_s_tready : dw_0_10_s_tready;
assign S_IM_DMA_0_AXIS_tready = dw_0_10_s_tready;
always @ (*) begin
    // case ({is_edges, is_maxpool})
    //     2'b01:      S_IM_DMA_1_AXIS_tready <= dw_1_10_s_tready;
    //     2'b11:      S_IM_DMA_1_AXIS_tready <= dw_1_8_s_tready;
    //     default:    S_IM_DMA_1_AXIS_tready <= 0;
    // endcase
    S_IM_DMA_1_AXIS_tready <= dw_1_10_s_tready;
end

always @ (*) begin
        // if (is_edges) begin
        //     im_0_top <= edges_top;
        //     im_0_mid <= dw_0_8_m_tdata;
        // end else begin
            im_0_top <= dw_0_10_top;
            im_0_mid <= dw_0_10_mid;
        // end

        case ({ is_edges, is_maxpool })
            2'b00: begin
                // No edges, no maxpool
                // dw_0_10 is connected to both, provides edges also

                im_0_bot            <= dw_0_10_bot;

                im_1_top            <= dw_0_10_top;
                im_1_mid            <= dw_0_10_mid;
                im_1_bot            <= dw_0_10_bot;

//                S_EDGE_AXIS_tready  <= 0;
                dw_0_10_m_tready    <= w_v_and_r;
//                dw_0_8_m_tready     <= 0;
                dw_1_10_m_tready    <= 0;
//                dw_1_8_m_tready     <= 0;

                im_valid            <= dw_0_10_m_tvalid;
            end
            2'b01: begin
                // No edges, maxpool
                // Get from both 10 width, edges also

                im_0_bot            <= dw_0_10_bot;

                im_1_top            <= dw_1_10_top;
                im_1_mid            <= dw_1_10_mid;
                im_1_bot            <= dw_1_10_bot;

//                S_EDGE_AXIS_tready  <= 0;
                dw_0_10_m_tready    <= w_v_and_r && dw_1_10_m_tvalid;
//                dw_0_8_m_tready     <= 0;
                dw_1_10_m_tready    <= w_v_and_r && dw_0_10_m_tvalid;
//                dw_1_8_m_tready     <= 0;

                im_valid            <= dw_0_10_m_tvalid && dw_1_10_m_tvalid;
            end
            // 2'b10: begin
            //     // Edges given, no maxpool
            //     // dw_0_8 is connected to both mids
            //     // all edges come from edges

            //     im_0_bot            <= edges_bot;

            //     im_1_top            <= edges_top;
            //     im_1_mid            <= dw_0_8_m_tdata;
            //     im_1_bot            <= edges_bot;

            //     S_EDGE_AXIS_tready  <= w_v_and_r && dw_0_8_m_tvalid;
            //     dw_0_10_m_tready    <= 0;
            //     dw_0_8_m_tready     <= w_v_and_r && S_EDGE_AXIS_tvalid;
            //     dw_1_10_m_tready    <= 0;
            //     dw_1_8_m_tready     <= 0;

            //     im_valid            <= dw_0_8_m_tvalid && S_EDGE_AXIS_tvalid;
            // end
            // 2'b11: begin
            //     // Edges given, maxpool
            //     // Both dmas are connected
            //     // Mid edges cris-crossed
            //     // Top & bottom from edges
                
            //     im_0_bot            <= dw_1_8_m_tdata[  DATA_WIDTH-1    :   0];
            //     im_1_top            <= dw_0_8_m_tdata[  8*DATA_WIDTH-1  :   7*DATA_WIDTH];
            //     im_1_mid            <= dw_1_8_m_tdata;
            //     im_1_bot            <= edges_bot;

            //     S_EDGE_AXIS_tready  <= w_v_and_r && dw_0_8_m_tvalid && dw_1_8_m_tvalid;
            //     dw_0_10_m_tready    <= 0;
            //     dw_0_8_m_tready     <= w_v_and_r && dw_1_8_m_tvalid && S_EDGE_AXIS_tvalid;
            //     dw_1_10_m_tready    <= 0;
            //     dw_1_8_m_tready     <= w_v_and_r && dw_0_8_m_tvalid && S_EDGE_AXIS_tvalid;

            //     im_valid            <= dw_0_8_m_tvalid && dw_1_8_m_tvalid && S_EDGE_AXIS_tvalid;
            // end
        endcase
    // end
end


// //************** WEIGHTS ROUTING

// always @(posedge aclk)
//     weights_valid <= 1;

//**Instantiations

wire                            dw_dma_3n_s_tvalid;
wire                            dw_dma_3n_s_tready;
wire [WEIGHTS_DMA_WIDTH   -1:0] dw_dma_3n_s_tdata;
wire [WEIGHTS_DMA_WIDTH/8 -1:0] dw_dma_3n_s_tkeep;
wire                            dw_dma_3n_s_tlast;
wire                            dw_dma_3n_m_tvalid;
wire                            dw_dma_3n_m_tready;
wire [3*Nb-1:0]                 dw_dma_3n_m_tdata;
// axis_dw_dma_3n DW_DMA_3N (
axis_dwidth_converter_0 DW_DMA_3N (
  .aclk(aclk),                    // input wire aclk
  .aresetn(aresetn),              // input wire aresetn
  .s_axis_tvalid(dw_dma_3n_s_tvalid),  // input wire s_axis_tvalid
  .s_axis_tready(dw_dma_3n_s_tready),  // output wire s_axis_tready
  .s_axis_tdata(dw_dma_3n_s_tdata),    // input wire [511 : 0] s_axis_tdata
  .s_axis_tkeep(dw_dma_3n_s_tkeep),    // input wire [511 : 0] s_axis_tdata
  .s_axis_tlast(dw_dma_3n_s_tlast),    // input wire [511 : 0] s_axis_tdata

  .m_axis_tvalid(dw_dma_3n_m_tvalid),  // output wire m_axis_tvalid
  .m_axis_tready(dw_dma_3n_m_tready),  // input wire m_axis_tready
  .m_axis_tdata(dw_dma_3n_m_tdata)    // output wire [383 : 0] m_axis_tdata
);

wire                        dw_3n_9n_s_tvalid;
wire                        dw_3n_9n_s_tready;
wire [3*Nb-1:0]             dw_3n_9n_s_tdata;
wire                        dw_3n_9n_m_tvalid;
wire                        dw_3n_9n_m_tready;
wire [9*Nb-1:0]             dw_3n_9n_m_tdata;
// axis_dw_3n_9n DW_3N_9N (
axis_dwidth_converter_1 DW_3N_9N (
  .aclk(aclk),                    // input wire aclk
  .aresetn(aresetn),              // input wire aresetn
  .s_axis_tvalid(dw_3n_9n_s_tvalid),  // input wire s_axis_tvalid
  .s_axis_tready(dw_3n_9n_s_tready),  // output wire s_axis_tready
  .s_axis_tdata(dw_3n_9n_s_tdata),    // input wire [383 : 0] s_axis_tdata
  .m_axis_tvalid(dw_3n_9n_m_tvalid),  // output wire m_axis_tvalid
  .m_axis_tready(dw_3n_9n_m_tready),  // input wire m_axis_tready
  .m_axis_tdata(dw_3n_9n_m_tdata)    // output wire [1151 : 0] m_axis_tdata
);

wire                        dw_3n_9n2_s_tvalid;
wire                        dw_3n_9n2_s_tready;
wire [3*Nb-1:0]             dw_3n_9n2_s_tdata;
wire                        dw_3n_9n2_m_tvalid;
wire                        dw_3n_9n2_m_tready;
wire [9*Nb/2-1:0]           dw_3n_9n2_m_tdata;
// axis_dw_3n_9n2 DW_3N_9N2 (
axis_dwidth_converter_2 DW_3N_9N2 (
  .aclk(aclk),                    // input wire aclk
  .aresetn(aresetn),              // input wire aresetn
  .s_axis_tvalid(dw_3n_9n2_s_tvalid),  // input wire s_axis_tvalid
  .s_axis_tready(dw_3n_9n2_s_tready),  // output wire s_axis_tready
  .s_axis_tdata(dw_3n_9n2_s_tdata),    // input wire [383 : 0] s_axis_tdata
  .m_axis_tvalid(dw_3n_9n2_m_tvalid),  // output wire m_axis_tvalid
  .m_axis_tready(dw_3n_9n2_m_tready),  // input wire m_axis_tready
  .m_axis_tdata(dw_3n_9n2_m_tdata)    // output wire [1151 : 0] m_axis_tdata
);



//******************** FIXED CONNECTIONS

// Valid & Data Fixed
assign dw_dma_3n_s_tvalid       = S_W_DMA_AXIS_tvalid;
assign dw_dma_3n_s_tdata        = S_W_DMA_AXIS_tdata;
assign dw_dma_3n_s_tkeep        = S_W_DMA_AXIS_tkeep;
assign dw_dma_3n_s_tlast        = S_W_DMA_AXIS_tlast;

assign M_W_ROTATOR_AXIS_tvalid  = dw_dma_3n_m_tvalid;
assign M_W_ROTATOR_AXIS_tdata   = dw_dma_3n_m_tdata;

assign dw_3n_9n_s_tvalid        = S_W_ROTATOR_AXIS_tvalid;
assign dw_3n_9n_s_tdata         = S_W_ROTATOR_AXIS_tdata;

assign dw_3n_9n2_s_tvalid       = S_W_ROTATOR_AXIS_tvalid;
assign dw_3n_9n2_s_tdata        = S_W_ROTATOR_AXIS_tdata;

// Ready Fixed
assign S_W_DMA_AXIS_tready      = dw_dma_3n_s_tready;
assign dw_dma_3n_m_tready       = M_W_ROTATOR_AXIS_tready;
assign dw_3n_9n_m_tready        = im_v_and_r;
assign dw_3n_9n2_m_tready       = im_v_and_r;


// Dispersed data for 1x1: 3N -> 9N mapping
genvar i;
generate
    for(i=0; i < CONV_CORES; i=i+1) begin: disperse_1x1         // 0,1,2,3,4,5,6,7,8

        assign  dispersed_weights_3n_9n [9*DATA_WIDTH*(i+1)-1 : 9*DATA_WIDTH*i ] = {
                S_W_ROTATOR_AXIS_tdata  [3*DATA_WIDTH*(i+1)-1 : 3*DATA_WIDTH*i ],
                S_W_ROTATOR_AXIS_tdata  [3*DATA_WIDTH*(i+1)-1 : 3*DATA_WIDTH*i ],
                S_W_ROTATOR_AXIS_tdata  [3*DATA_WIDTH*(i+1)-1 : 3*DATA_WIDTH*i ]};
    end
endgenerate

// 9N2 -> 9N mapping
generate
    for(i=0; i < CONV_PAIRS; i=i+1) begin: disperse_3x3_max     // 0,1,2,3

        assign  dispersed_weights_9n2_9n    [18*DATA_WIDTH*(i+1)-1  : 18*DATA_WIDTH*i ] = {
                dw_3n_9n2_m_tdata           [ 9*DATA_WIDTH*(i+1)-1  :  9*DATA_WIDTH*i ],
                dw_3n_9n2_m_tdata           [ 9*DATA_WIDTH*(i+1)-1  :  9*DATA_WIDTH*i ]};
    end
endgenerate


//** WEIGHTS ROUTING

// Valid & Ready routing
always @ (*) begin
    case ({is_3x3, is_maxpool})
        2'b10: begin
            // 3x3, no max
            // 9N is given out
            S_W_ROTATOR_AXIS_tready <= dw_3n_9n_s_tready;
        end
        2'b11: begin
            // 3x3 max
            // 9N2 is copied and given to both
            S_W_ROTATOR_AXIS_tready <= dw_3n_9n2_s_tready;
        end
        default: begin
            // 1x1
            // rotator_out (3N) is directly dispersed and sent out
            S_W_ROTATOR_AXIS_tready <= im_v_and_r;
        end
    endcase
end

always @ (*) begin
// always @ (posedge aclk or negedge aresetn) begin
//     if (~aresetn) begin
//         weights_valid <= 0;
//     end else begin
        case ({is_3x3, is_maxpool})
            2'b10: begin
                // 3x3, no max
                // 9N is given out
                weights_valid           <= dw_3n_9n_m_tvalid;
                weights                 <= dw_3n_9n_m_tdata;
            end
            2'b11: begin
                // 3x3 max
                // 9N2 is copied and given to both
                weights_valid           <= dw_3n_9n2_m_tvalid;
                weights                 <= dispersed_weights_9n2_9n;
            end
            default: begin
                // 1x1
                // rotator_out (3N) is directly dispersed and sent out
                weights_valid           <= S_W_ROTATOR_AXIS_tvalid;
                weights                 <= dispersed_weights_3n_9n;
            end
        endcase
    // end
end


endmodule