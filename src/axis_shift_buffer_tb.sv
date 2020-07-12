`timescale 1ns / 1ps

module axis_shift_buffer_tb();
    parameter CLK_PERIOD = 10;
    parameter DATA_WIDTH = 16;
    parameter CONV_UNITS = 8;
    parameter DEPTH = 3;
    parameter STATE_WIDTH = $clog2(DEPTH);

    reg                                         aclk            = 0;
    reg                                         aresetn         = 1;
    wire [DATA_WIDTH * (CONV_UNITS+2) - 1 : 0]  S_AXIS_tdata;
    reg                                         S_AXIS_tvalid   = 0;
    reg                                         S_AXIS_tlast    = 0;
    reg                                         M_AXIS_tready   = 1;

    wire                                        S_AXIS_tready;
    wire [DATA_WIDTH * (CONV_UNITS) - 1 : 0]    M_AXIS_tdata;
    wire                                        M_AXIS_tvalid;
    wire                                        M_AXIS_tlast;

    reg  [DATA_WIDTH-1 : 0] s_data [CONV_UNITS+2-1:0];
    wire [DATA_WIDTH-1 : 0] m_data [CONV_UNITS-1:0];

axis_shift_buffer
#(
    .DATA_WIDTH(DATA_WIDTH),
    .CONV_UNITS(CONV_UNITS),
    .DEPTH(DEPTH),
    .STATE_WIDTH(STATE_WIDTH)
)
axis_shift_buffer_dut
(
    .aclk(aclk),
    .aresetn(aresetn),
    .S_AXIS_tdata(S_AXIS_tdata),
    .S_AXIS_tvalid(S_AXIS_tvalid),
    .S_AXIS_tready(S_AXIS_tready),
    .S_AXIS_tlast(S_AXIS_tlast),
    .M_AXIS_tdata(M_AXIS_tdata),
    .M_AXIS_tvalid(M_AXIS_tvalid),
    .M_AXIS_tready(M_AXIS_tready),
    .M_AXIS_tlast(M_AXIS_tlast)
);

    genvar i;
    generate
        // 10 s_data mapped
        for (i=0; i < CONV_UNITS +2; i=i+1) begin: s_data_gen
            assign S_AXIS_tdata[(i+1)*DATA_WIDTH-1: i*DATA_WIDTH] = s_data[i];
        end

        // 8 m_data mapped
        for (i=0; i < CONV_UNITS; i=i+1) begin: m_data_gen
            assign m_data[i] = M_AXIS_tdata[(i+1)*DATA_WIDTH-1: i*DATA_WIDTH];
        end
    endgenerate

    always begin
        #(CLK_PERIOD/2);
        aclk <= ~aclk;
    end

    integer k = 0;
    integer m = 0;
    integer n = 0;

    initial begin
        @(posedge aclk);
        #(CLK_PERIOD*3)

        for (n=0; n < 100; n=n+1) begin
            @(posedge aclk);

            // Turn off ready in this region
            if (n > 28 && n < 30)
                M_AXIS_tready <= 0;
            else
                M_AXIS_tready <= 1;


            // Turn off valid in this reigion
            if(n > 28 && n < 34) begin
               S_AXIS_tvalid <= 0;
               continue; 
            end
            else
                S_AXIS_tvalid <= 1;


            if (S_AXIS_tready && S_AXIS_tvalid) begin
                k = k + 1;

                for (m=0; m<CONV_UNITS+2; m=m+1) begin
                    s_data[m] <= m*100 + k;
                end

                if (k % 10 == 0) begin
                    S_AXIS_tlast <= 1;
                end
                else begin
                    S_AXIS_tlast <= 0;
                end
            end
                
            
    end

    end

endmodule