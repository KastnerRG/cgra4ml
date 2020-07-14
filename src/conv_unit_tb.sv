`timescale 1ns / 1ps

module conv_unit_tb # ();

    parameter DATA_WIDTH            = 16;
    parameter KERNEL_W_MAX          = 3;
    parameter TUSER_WIDTH           = 5;
    parameter ACCUMULATOR_DELAY     = 21;
    parameter CLK_PERIOD = 10;

    reg                       aclk                                  = 0;
    reg                       aclken                                = 1;               
    reg                       aresetn                               = 0;
    reg                       s_valid                               = 0;
    reg  [DATA_WIDTH  - 1: 0] s_data_pixels                         = 0;
    reg  [DATA_WIDTH  - 1: 0] s_data_weights [KERNEL_W_MAX - 1 : 0] = '{default:'0};
    reg  [DATA_WIDTH  - 1: 0] s_data_bias                           = 0;
    reg                       s_last                                = 0;
    reg  [TUSER_WIDTH - 1: 0] s_user                                = 0;

    wire                      m_valid                              ;
    wire [DATA_WIDTH  - 1: 0] m_data        [KERNEL_W_MAX - 1 : 0] ;
    wire                      m_last                               ;
    wire [TUSER_WIDTH - 1: 0] m_user                               ;
    
    conv_unit # (
        .DATA_WIDTH         (DATA_WIDTH),
        .KERNEL_W_MAX       (KERNEL_W_MAX),
        .TUSER_WIDTH        (TUSER_WIDTH),
        .ACCUMULATOR_DELAY  (ACCUMULATOR_DELAY) 
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

    initial begin
        @(posedge aclk);
        #(CLK_PERIOD*3)
        aresetn <= 1;

        

    end


endmodule