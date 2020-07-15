`timescale 1ns / 1ps

module conv_unit_tb # ();

    parameter DATA_WIDTH            = 16;
    parameter KERNEL_W_MAX          = 3;
    parameter TUSER_WIDTH           = 5;
    parameter ACCUMULATOR_DELAY     = 4;
    parameter MULTIPLIER_DELAY      = 3;
    parameter CLK_PERIOD = 10;

    reg                       aclk                                  = 0;
    reg                       aclken                                = 0;               
    reg                       aresetn                               = 0;
    reg                       s_valid                               = 0;
    reg  [DATA_WIDTH  - 1: 0] s_data_pixels                         = 0;
    reg  [DATA_WIDTH  - 1: 0] s_data_weights [KERNEL_W_MAX - 1 : 0] = '{default:'0};
    reg  [DATA_WIDTH  - 1: 0] s_data_bias                           = 0;
    reg                       s_last                                = 0;
    reg  [TUSER_WIDTH - 1: 0] s_user                                = 0;

    wire                      m_valid       [KERNEL_W_MAX - 1 : 0] ;
    wire [DATA_WIDTH  - 1: 0] m_data        [KERNEL_W_MAX - 1 : 0] ;
    wire                      m_last        [KERNEL_W_MAX - 1 : 0] ;
    wire [TUSER_WIDTH - 1: 0] m_user        [KERNEL_W_MAX - 1 : 0] ;
    
    conv_unit # (
        .DATA_WIDTH         (DATA_WIDTH),
        .KERNEL_W_MAX       (KERNEL_W_MAX),
        .TUSER_WIDTH        (TUSER_WIDTH),
        .ACCUMULATOR_DELAY  (ACCUMULATOR_DELAY) ,
        .MULTIPLIER_DELAY   (MULTIPLIER_DELAY) 
    )
    conv_unit_dut
    (
        .aclk           (aclk),
        .aclken         (aclken),
        .aresetn        (aresetn),

        .s_valid        (s_valid),       
        .s_data_pixels  (s_data_pixels), 
        .s_data_weights (s_data_weights),
        .s_data_bias    (s_data_bias),   
        .s_last         (s_last),        
        .s_user         (s_user),        

        .m_valid        (m_valid),
        .m_data         (m_data),
        .m_last         (m_last),
        .m_user         (m_user)
    );

    always begin
        #(CLK_PERIOD/2);
        aclk <= ~aclk;
    end

    integer n = 0;
    integer k = 0;
    integer i = 0;

    initial begin
        @(posedge aclk);
        #(CLK_PERIOD*3)
        aresetn <= 1;

        for (n=0; n<100; n=n+1) begin
            @(posedge aclk);

            if (n==6)
                aclken <= 1;

            if (aclken == 1) begin

                if (i == 2)
                    i <= 0;
                else
                    i <= i+1;
                k      = k + 1;
                
                s_valid         <= 1;
                s_data_pixels   <= k*100 + i;

            end

        end
    end


endmodule