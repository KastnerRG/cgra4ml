`timescale 1ns / 1ps

module axis_conv_engine_tb # ();
    parameter CLK_PERIOD           = 10;
    parameter CONV_UNITS           =  8 ; 
    parameter DATA_WIDTH           = 16 ; 
    parameter KERNEL_W_MAX         =  3 ; 
    parameter KERNEL_H_MAX         =  3 ;  // odd number
    parameter TUSER_WIDTH          =  4 ; 
    parameter ACCUMULATOR_DELAY    = 19 ; 
    parameter MULTIPLIER_DELAY     =  6 ; 

    parameter INDEX_IS_1x1         =  0 ; 
    parameter INDEX_IS_MAX         =  1 ; 
    parameter INDEX_IS_RELU        =  2 ; 
    parameter INDEX_IS_COLS_1_K2   =  3 ; 

    localparam KERNEL_W_WIDTH       = $clog2(KERNEL_W_MAX   + 1);
    localparam KERNEL_H_WIDTH       = $clog2(KERNEL_H_MAX   + 1);

    reg                       aclk                                                   = 0;
    reg                       aclken                                                 = 1;               
    reg                       aresetn                                                = 1;
                                
    reg                       start                                                  = 0;
    reg  [KERNEL_W_WIDTH-1:0] kernel_w_1                                             = 0;
    reg  [KERNEL_H_WIDTH-1:0] kernel_h_1                                             = 0;
    reg                       is_max                                                 = 0;
    reg                       is_relu                                                = 0;
    reg                       blocks_1                                               = 0;
    reg                       cin_1                                                  = 0;
      
    reg                       pixels_s_valid                                         = 0;
    reg  [DATA_WIDTH  - 1: 0] pixels_s_data  [CONV_UNITS + (KERNEL_H_MAX-1) -1 : 0]  = '{default:0};
    wire                      pixels_s_ready                                            ;
    reg                       pixels_s_last                                          = 0;
    reg  [TUSER_WIDTH - 1: 0] pixels_s_user                                          = 0;
    
    reg                       weights_s_valid                                        = 0;
    wire                      weights_s_ready                                           ;
    reg  [DATA_WIDTH  - 1: 0] weights_s_data [KERNEL_W_MAX - 1 : 0]                  = '{default:0};
    reg                       weights_s_last                                         = 0;
                                                                                         
    wire                      m_valid                                                   ;
    wire [DATA_WIDTH  - 1: 0] m_data                                                    ;
    wire                      m_last                                                    ;
    wire [TUSER_WIDTH - 1: 0] m_user                                                    ;
                                                                                         
    wire                      done                                                      ;

    axis_conv_engine # (
        .CONV_UNITS           (CONV_UNITS        ) ,
        .DATA_WIDTH           (DATA_WIDTH        ) ,
        .KERNEL_W_MAX         (KERNEL_W_MAX      ) ,
        .KERNEL_H_MAX         (KERNEL_H_MAX      ) , // odd number
        .TUSER_WIDTH          (TUSER_WIDTH       ) ,
        .ACCUMULATOR_DELAY    (ACCUMULATOR_DELAY ) ,
        .MULTIPLIER_DELAY     (MULTIPLIER_DELAY  ) ,
        .INDEX_IS_1x1         (INDEX_IS_1x1      ) ,
        .INDEX_IS_MAX         (INDEX_IS_MAX      ) ,
        .INDEX_IS_RELU        (INDEX_IS_RELU     ) ,
        .INDEX_IS_COLS_1_K2   (INDEX_IS_COLS_1_K2)  
    )
    conv_engine_dut
    (
        .aclk            (aclk           ),
        .aclken          (aclken         ),
        .aresetn         (aresetn        ),

        .start           (start          ),
        .kernel_w_1      (kernel_w_1     ),
        .kernel_h_1      (kernel_h_1     ),
        .is_max          (is_max         ),
        .is_relu         (is_relu        ),
        .blocks_1        (blocks_1       ),
        .cin_1           (cin_1          ),

        .pixels_s_valid  (pixels_s_valid ),       
        .pixels_s_data   (pixels_s_data  ),   
        .pixels_s_ready  (pixels_s_ready ),

        .weights_s_valid (weights_s_valid),       
        .weights_s_data  (weights_s_data ),
        .weights_s_ready (weights_s_ready),

        .m_valid         (m_valid        ),
        .m_data          (m_data         ),
        .m_last          (m_last         ),
        .m_user          (m_user         ),

        .done            (done           )//

    );

    always begin
        #(CLK_PERIOD/2);
        aclk <= ~aclk;
    end

    integer n = 0;
    integer k = 0;
    integer m = 0;

    initial begin
        @(posedge aclk);
        #(CLK_PERIOD*3)

        aresetn                 <= 1;
        start                   <= 1;

        @(posedge aclk);
        start                   <= 0;
        @(posedge aclk);
        #(CLK_PERIOD*3)

        for (m=0;   m < CONV_UNITS+(KERNEL_H_MAX-1);    m=m+1) begin
            pixels_s_data[m] <= m*100 + k;
        end

        for (n=0; n < 1000; n=n+1) begin
            @(posedge aclk);

        end

    end

endmodule