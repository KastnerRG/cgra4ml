`timescale 1ns / 1ps

module axis_shift_buffer_tb();
    parameter CLK_PERIOD            = 10;
    parameter DATA_WIDTH            = 16;
    parameter CONV_UNITS            = 8;
    parameter KERNEL_H_MAX          = 3;
    parameter KERNEL_W_MAX          = 3;
    parameter CIN_COUNTER_WIDTH     = 5;
    parameter TUSER_WIDTH           = 4;
    parameter COLS_COUNTER_WIDTH    = 10;
    parameter ONE                   = 15360;

    parameter INDEX_IS_1x1          = 0;
    parameter INDEX_IS_MAX          = 1;
    parameter INDEX_IS_RELU         = 2;
    parameter INDEX_IS_COLS_1_K2    = 3;

    parameter KERNEL_H_1            = 3-1;
    parameter KERNEL_W_1            = 3-1;
    parameter CIN_1                 = 6-1;
    parameter COLS_1                = 10-1;
    
    localparam KERNEL_H_WIDTH       = $clog2(KERNEL_H_MAX + 1);
    localparam KERNEL_W_WIDTH       = $clog2(KERNEL_W_MAX + 1);


    reg                                         aclk                    = 0;
    reg                                         aresetn                 = 1;
    reg                                         start                   = 0;
    reg                                         S_AXIS_tvalid           = 0;
    reg                                         M_AXIS_tready           = 0;

    wire                                        S_AXIS_tready;
    wire                                        M_AXIS_tvalid;
    wire                                        M_AXIS_tlast;
    wire [TUSER_WIDTH     -1     : 0]           M_AXIS_tuser;
    wire [KERNEL_H_WIDTH  -1     : 0]           kernel_h_1_out;
    wire [KERNEL_W_WIDTH  -1     : 0]           kernel_w_1_out;

    reg  [DATA_WIDTH-1 : 0] s_data [CONV_UNITS+(KERNEL_H_MAX-1)-1:0] = '{default:0};
    wire [DATA_WIDTH-1 : 0] m_data [CONV_UNITS-1:0];

axis_shift_buffer
#(
    .DATA_WIDTH         (DATA_WIDTH),
    .CONV_UNITS         (CONV_UNITS),
    .KERNEL_H_MAX       (KERNEL_H_MAX),
    .KERNEL_W_MAX       (KERNEL_W_MAX),
    .CIN_COUNTER_WIDTH  (CIN_COUNTER_WIDTH),
    .COLS_COUNTER_WIDTH (COLS_COUNTER_WIDTH),
    .ONE                (ONE               ),
    .TUSER_WIDTH        (TUSER_WIDTH       ),
    .INDEX_IS_1x1       (INDEX_IS_1x1      ),
    .INDEX_IS_MAX       (INDEX_IS_MAX      ),
    .INDEX_IS_RELU      (INDEX_IS_RELU     ),
    .INDEX_IS_COLS_1_K2 (INDEX_IS_COLS_1_K2)
)
axis_shift_buffer_dut
(
    .aclk               (aclk),
    .aresetn            (aresetn),
    .start              (start),
    .kernel_h_1_in      (KERNEL_H_1),
    .kernel_w_1_in      (KERNEL_W_1),
    .is_max             (1),
    .is_relu            (1),
    .cols_1             (COLS_1),
    .cin_1              (CIN_1),
    .S_AXIS_tdata       (s_data),
    .S_AXIS_tvalid      (S_AXIS_tvalid),
    .S_AXIS_tready      (S_AXIS_tready),
    .M_AXIS_tdata       (m_data),
    .M_AXIS_tvalid      (M_AXIS_tvalid),
    .M_AXIS_tready      (M_AXIS_tready),
    .M_AXIS_tlast       (M_AXIS_tlast),
    .M_AXIS_tuser       (M_AXIS_tuser),
    .kernel_h_1_out     (kernel_h_1_out),
    .kernel_w_1_out     (kernel_w_1_out)
);

    genvar i;
    
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

        @(posedge aclk);
        start             <= 1;
        @(posedge aclk);
        start             <= 0;

        @(posedge aclk);
        #(CLK_PERIOD*3)

        // @(posedge aclk);
        // M_AXIS_tready     <= 1;
        // @(posedge aclk);
        // M_AXIS_tready     <= 0;

        for (m=0;   m < CONV_UNITS+(KERNEL_H_MAX-1);    m=m+1) begin
            s_data[m] <= m*100 + k;
        end

        for (n=0; n < 1000; n=n+1) begin
            @(posedge aclk);

            // Turn off ready in this region
            if (n > 24 && n < 29)
                M_AXIS_tready <= 0;
            else if (n < 10)
                M_AXIS_tready <= 0;
            else
                M_AXIS_tready <= 1;


            // Turn off valid in this reigion
            if(n > 30 && n < 40) begin
               S_AXIS_tvalid <= 0;
               continue; 
            end
            else
                S_AXIS_tvalid <= 1;


            if (S_AXIS_tready && S_AXIS_tvalid) begin
                k = k + 1;

                for (m=0; m<CONV_UNITS+(KERNEL_H_MAX-1); m=m+1) begin
                    s_data[m] <= m*100 + k;
                end

            end
                
            
    end

    end

endmodule