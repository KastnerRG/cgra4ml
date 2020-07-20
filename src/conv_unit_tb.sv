`timescale 1ns / 1ps

module conv_unit_tb # ();

    parameter CLK_PERIOD            = 10;
    parameter DATA_WIDTH            = 16;
    parameter KERNEL_W_MAX          = 3;
    parameter TUSER_WIDTH           = 4;
    parameter ACCUMULATOR_DELAY     = 19;
    parameter MULTIPLIER_DELAY      = 6;

    parameter INDEX_IS_1x1          = 0;
    parameter INDEX_IS_MAX          = 1;
    parameter INDEX_IS_RELU         = 2;
    parameter INDEX_IS_BLOCKS_2     = 3;

    parameter KW_CIN    = 9;
    parameter IS_1x1    = 0;


    reg                       aclk                                  = 0;
    reg                       aclken                                = 0;               
    reg                       aresetn                               = 0;
    reg                       s_valid                               = 0;
    reg  [DATA_WIDTH  - 1: 0] s_data_pixels                         = 1;
    reg  [DATA_WIDTH  - 1: 0] s_data_weights [KERNEL_W_MAX - 1 : 0] = '{default:'0};
    wire                      s_ready                                  ;
    reg                       s_last                                = 0;
    reg  [TUSER_WIDTH - 1: 0] s_user                                = 1;

    wire                      m_valid       [KERNEL_W_MAX - 1 : 0] ;
    wire [DATA_WIDTH  - 1: 0] m_data        [KERNEL_W_MAX - 1 : 0] ;
    wire                      m_last        [KERNEL_W_MAX - 1 : 0] ;
    wire [TUSER_WIDTH - 1: 0] m_user        [KERNEL_W_MAX - 1 : 0] ;
    
    conv_unit # (
        .DATA_WIDTH               (DATA_WIDTH),
        .KERNEL_W_MAX             (KERNEL_W_MAX),
        .TUSER_WIDTH              (TUSER_WIDTH),
        .ACCUMULATOR_DELAY        (ACCUMULATOR_DELAY) ,
        .MULTIPLIER_DELAY         (MULTIPLIER_DELAY),
        .INDEX_IS_1x1             (INDEX_IS_1x1),
        .INDEX_IS_MAX             (INDEX_IS_MAX),
        .INDEX_IS_RELU            (INDEX_IS_RELU),
        .INDEX_IS_BLOCKS_2        (INDEX_IS_BLOCKS_2)
    )
    conv_unit_dut
    (
        .aclk           (aclk),
        .aclken         (aclken),
        .aresetn        (aresetn),

        .s_valid        (s_valid),       
        .s_data_pixels  (s_data_pixels), 
        .s_data_weights (s_data_weights),
        .s_ready        (s_ready),        
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
        s_user[INDEX_IS_1x1]    <= IS_1x1;

        for (n=0; n<1000; n=n+1) begin
            @(posedge aclk);

            if (n==6)
                aclken <= 1;

            if (s_ready) begin
                
                if(!s_last) begin
                    if (i == 2) begin
                        i <= 0;
                        k                   <= k + 1; 
                    end
                    else begin
                        i <= i+1;
                    end
                end

                s_valid                     <= 1;
                
                if (!s_last) begin 
                    s_data_weights[0]           <= k*100 + i;
                    s_data_weights[1]           <= k*100 + i + 1000;
                    s_data_weights[2]           <= k*100 + i + 2000;
                    s_last                      <= (k % KW_CIN == KW_CIN-1) && (i==2);
                    s_user[INDEX_IS_1x1]        <= IS_1x1;
                end
                else begin
                    s_data_weights[0]           <= 1;
                    s_data_weights[1]           <= 1;
                    s_data_weights[2]           <= 1;
                    s_last                      <= 0;
                    s_user[INDEX_IS_1x1]        <= IS_1x1;
                end
            end

        end
    end


endmodule