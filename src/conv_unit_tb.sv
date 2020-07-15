`timescale 1ns / 1ps

module conv_unit_tb # ();

    parameter CLK_PERIOD            = 10;
    parameter DATA_WIDTH            = 16;
    parameter KERNEL_W_MAX          = 3;
    parameter TUSER_WIDTH           = 5;
    parameter ACCUMULATOR_DELAY     = 4;
    parameter MULTIPLIER_DELAY      = 3;

    parameter IS_1x1_INDEX          = 0;
    parameter IS_MAX_INDEX          = 1;
    parameter IS_RELU_INDEX         = 2;
    parameter IS_BLOCK_LAST_INDEX   = 3;
    parameter IS_CIN_FIRST_INDEX    = 4;


    reg                       aclk                                  = 0;
    reg                       aclken                                = 0;               
    reg                       aresetn                               = 0;
    reg                       s_valid                               = 0;
    reg  [DATA_WIDTH  - 1: 0] s_data_pixels                         = 9;
    reg  [DATA_WIDTH  - 1: 0] s_data_weights [KERNEL_W_MAX - 1 : 0] = '{default:'0};
    reg  [DATA_WIDTH  - 1: 0] s_data_bias                           = 9;
    wire                      s_ready                                  ;
    reg                       s_last                                = 0;
    reg  [TUSER_WIDTH - 1: 0] s_user                                = 1;

    wire                      m_valid       [KERNEL_W_MAX - 1 : 0] ;
    wire [DATA_WIDTH  - 1: 0] m_data        [KERNEL_W_MAX - 1 : 0] ;
    wire                      m_last        [KERNEL_W_MAX - 1 : 0] ;
    wire [TUSER_WIDTH - 1: 0] m_user        [KERNEL_W_MAX - 1 : 0] ;
    
    conv_unit # (
        .DATA_WIDTH         (DATA_WIDTH),
        .KERNEL_W_MAX       (KERNEL_W_MAX),
        .TUSER_WIDTH        (TUSER_WIDTH),
        .ACCUMULATOR_DELAY  (ACCUMULATOR_DELAY) ,
        .MULTIPLIER_DELAY   (MULTIPLIER_DELAY),
        .IS_1x1_INDEX       (IS_1x1_INDEX),
        .IS_MAX_INDEX       (IS_MAX_INDEX),
        .IS_RELU_INDEX      (IS_RELU_INDEX),
        .IS_BLOCK_LAST_INDEX(IS_BLOCK_LAST_INDEX),
        .IS_CIN_FIRST_INDEX (IS_CIN_FIRST_INDEX) 
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
        .s_ready         (s_ready),        
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

        aresetn                 <= 1;
        s_user[IS_1x1_INDEX]    <= 0;

        for (n=0; n<100; n=n+1) begin
            @(posedge aclk);

            if (n==6)
                aclken <= 1;

            if (s_ready) begin

                if (i == 2) begin
                    i <= 0;
                    k                       <= k + 1; 
                end
                else begin
                    i <= i+1;
                end

                s_valid                     <= 1;
                

                s_data_pixels               <= k*100 + i;
                s_data_bias                 <= k*1000 +500 + i;
                s_last                      <= (k % 10 == 9) && (i==2);
                s_user[IS_CIN_FIRST_INDEX]  <= (k % 10 == 0) && (i==0);
            end

        end
    end


endmodule