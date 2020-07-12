`timescale 1ns / 1ps

module axis_shell_tb();
    parameter CLK_PERIOD = 10;
    parameter DATA_WIDTH = 8;
    parameter DELAY = 5;

    reg                         aclk                = 0;
    reg                         aresetn             = 0;
    reg [DATA_WIDTH - 1 : 0]    S_AXIS_tdata        = 99;
    reg                         S_AXIS_tvalid       = 0;
    reg                         S_AXIS_tlast        = 0;
    reg                         M_AXIS_tready       = 1;
    wire                        S_AXIS_tready;
    wire [DATA_WIDTH - 1 : 0]   M_AXIS_tdata;
    wire                        M_AXIS_tvalid;
    wire                        M_AXIS_tlast;


axis_shell
#(
    .DATA_WIDTH(DATA_WIDTH),
    .DELAY(DELAY)
)
axis_shell_dut
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

    always begin
        #(CLK_PERIOD/2);
        aclk <= ~aclk;
    end

    integer k = 0;
    integer n = 0;

    initial begin
        @(posedge aclk);
        #(CLK_PERIOD*3)
        
        aresetn <= 1;

        for (n=0; n < 100; n=n+1) begin
            @(posedge aclk);

            // Turn off ready in this region
            if (n > 28 && n < 30)
                M_AXIS_tready <= 0;
            else
                M_AXIS_tready <= 1;


            // Turn off valid in this reigion
            if(n > 10 && n < 20) begin
               S_AXIS_tvalid = 0;
               continue; 
            end
            else
                S_AXIS_tvalid = 1;


            if (M_AXIS_tready && S_AXIS_tvalid) begin
                
                k = k + 1;
                S_AXIS_tdata <= k;

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