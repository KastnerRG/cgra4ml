module axis_mux #(
    parameter DATA_WIDTH,
    parameter TUSER_WIDTH
)
(
    sel,

    S0_AXIS_tvalid,
    S0_AXIS_tready,
    S0_AXIS_tdata,
    S0_AXIS_tkeep,
    S0_AXIS_tlast,
    S0_AXIS_tuser,

    S1_AXIS_tvalid,
    S1_AXIS_tready,
    S1_AXIS_tdata,
    S1_AXIS_tkeep,
    S1_AXIS_tlast,
    S1_AXIS_tuser,

    M_AXIS_tvalid,
    M_AXIS_tready,
    M_AXIS_tdata,
    M_AXIS_tkeep,
    M_AXIS_tlast,
    M_AXIS_tuser
);

localparam KEEP_SIZE = DATA_WIDTH/8;

input wire sel;

input  wire                     S0_AXIS_tvalid;
output wire                     S0_AXIS_tready;
input  wire [DATA_WIDTH-1 : 0]  S0_AXIS_tdata;
input  wire [KEEP_SIZE-1 :  0]  S0_AXIS_tkeep;
input  wire                     S0_AXIS_tlast;
input  wire [TUSER_WIDTH-1: 0]  S0_AXIS_tuser;

input  wire                     S1_AXIS_tvalid;
output wire                     S1_AXIS_tready;
input  wire [DATA_WIDTH-1 : 0]  S1_AXIS_tdata;
input  wire [KEEP_SIZE-1 : 0]   S1_AXIS_tkeep;
input  wire                     S1_AXIS_tlast;
input  wire [TUSER_WIDTH-1: 0]  S1_AXIS_tuser;

output wire                     M_AXIS_tvalid;
input  wire                     M_AXIS_tready;
output wire [DATA_WIDTH-1 : 0]  M_AXIS_tdata;
output wire [KEEP_SIZE-1 : 0]   M_AXIS_tkeep;
output wire                     M_AXIS_tlast;
output wire [TUSER_WIDTH-1: 0]  M_AXIS_tuser;

assign S0_AXIS_tready   = (sel==0) ? M_AXIS_tready  : 0;
assign S1_AXIS_tready   = (sel==0) ? 0              : M_AXIS_tready;

assign M_AXIS_tvalid    = (sel==0) ? S0_AXIS_tvalid : S1_AXIS_tvalid;
assign M_AXIS_tdata     = (sel==0) ? S0_AXIS_tdata  : S1_AXIS_tdata;
assign M_AXIS_tkeep     = (sel==0) ? S0_AXIS_tkeep  : S1_AXIS_tkeep;
assign M_AXIS_tlast     = (sel==0) ? S0_AXIS_tlast  : S1_AXIS_tlast;
assign M_AXIS_tuser     = (sel==0) ? S0_AXIS_tuser  : S1_AXIS_tuser;


endmodule