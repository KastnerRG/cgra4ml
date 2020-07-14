module axis_mux_tb();

parameter DATA_WIDTH = 16;
parameter TUSER_WIDTH = 5;
parameter KEEP_SIZE  = DATA_WIDTH/8;
parameter CLK_PERIOD = 10;

reg aclk = 0;
reg aresetn = 1;
reg sel = 0;

reg [DATA_WIDTH-1 : 0]  S0_AXIS_tdata   = 1;
reg                     S0_AXIS_tvalid  = 1;
reg [KEEP_SIZE-1 : 0]   S0_AXIS_tkeep   = 1;
reg                     S0_AXIS_tlast   = 1;
reg [TUSER_WIDTH-1 : 0] S0_AXIS_tuser   = 1;

reg [DATA_WIDTH-1 : 0]  S1_AXIS_tdata   = 0;
reg                     S1_AXIS_tvalid  = 0;
reg [KEEP_SIZE-1 : 0]   S1_AXIS_tkeep   = 0;
reg                     S1_AXIS_tlast   = 0;
reg [TUSER_WIDTH-1 : 0] S1_AXIS_tuser   = 0;

reg                     M_AXIS_tready   = 1;

wire                     M_AXIS_tlast;
wire                     S0_AXIS_tready;
wire                     S1_AXIS_tready;
wire [DATA_WIDTH-1 : 0]  M_AXIS_tdata;
wire                     M_AXIS_tvalid;
wire [KEEP_SIZE-1   : 0] M_AXIS_tkeep;
wire [TUSER_WIDTH-1 : 0] M_AXIS_tuser;

axis_mux 
#(
    .DATA_WIDTH(DATA_WIDTH)
)
axis_mux_dut
(
    .aclk(aclk),
    .aresetn(aresetn),
    .sel(sel),
    .S0_AXIS_tdata(S0_AXIS_tdata),
    .S0_AXIS_tvalid(S0_AXIS_tvalid),
    .S0_AXIS_tready(S0_AXIS_tready),
    .S0_AXIS_tkeep(S0_AXIS_tkeep),
    .S0_AXIS_tlast(S0_AXIS_tlast),
    .S0_AXIS_tuser(S0_AXIS_tuser),
    
    .S1_AXIS_tdata(S1_AXIS_tdata),
    .S1_AXIS_tvalid(S1_AXIS_tvalid),
    .S1_AXIS_tready(S1_AXIS_tready),
    .S1_AXIS_tkeep(S1_AXIS_tkeep),
    .S1_AXIS_tlast(S1_AXIS_tlast),
    .S1_AXIS_tuser(S0_AXIS_tuser),
    
    .M_AXIS_tdata(M_AXIS_tdata),
    .M_AXIS_tvalid(M_AXIS_tvalid),
    .M_AXIS_tready(M_AXIS_tready),
    .M_AXIS_tkeep(M_AXIS_tkeep),
    .M_AXIS_tlast(M_AXIS_tlast),
    .M_AXIS_tuser(M_AXIS_tuser)
);

always begin
    #(CLK_PERIOD/2);
    aclk <= ~aclk;
end

integer n = 0;

initial begin
    
    for (n=0; n<100; n=n+1) begin
        @(posedge aclk);

        if (n>10 && n <20) begin
            sel <= 1;

            S0_AXIS_tdata   <= 1;
            S0_AXIS_tvalid  <= 1;
            S0_AXIS_tkeep   <= 1;
            S0_AXIS_tlast   <= 1;

            S1_AXIS_tdata   <= 2;
            S1_AXIS_tvalid  <= 2;
            S1_AXIS_tkeep   <= 2;
            S1_AXIS_tlast   <= 2;
        end

        if (n>25 && n <30) begin
            sel <= 0;
            M_AXIS_tready   <= 0;
            
            S0_AXIS_tdata   <= 1;
            S0_AXIS_tvalid  <= 1;
            S0_AXIS_tkeep   <= 1;
            S0_AXIS_tlast   <= 1;

            S1_AXIS_tdata   <= 2;
            S1_AXIS_tvalid  <= 2;
            S1_AXIS_tkeep   <= 2;
            S1_AXIS_tlast   <= 2;
        end

    end
end

endmodule