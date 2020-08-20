module conv_core # (
    parameter IS_FIXED_POINT         ,
    parameter CONV_UNITS             ,
    parameter DATA_WIDTH             ,
    parameter KERNEL_W_MAX           ,
    parameter TUSER_WIDTH            ,
    parameter FLOAT_ACCUMULATOR_DELAY,
    parameter FLOAT_MULTIPLIER_DELAY ,
    parameter FIXED_ACCUMULATOR_DELAY,
    parameter FIXED_MULTIPLIER_DELAY ,

    parameter INDEX_IS_1x1           ,
    parameter INDEX_IS_MAX           ,
    parameter INDEX_IS_RELU          ,
    parameter INDEX_IS_COLS_1_K2      
)(
    aclk                ,
    aclken              ,
    aresetn             ,
    start               ,
    kernel_w_1          ,
    is_1x1              ,

    s_ready             ,
    s_weights_valid     ,
    s_weights_data      ,

    s_step_pixels_valid ,
    s_step_pixels_data  , 
    s_step_pixels_last  , 
    s_step_pixels_user  ,     

    m_valid             ,
    m_data              ,
    m_last              ,
    m_user              

);
    localparam KERNEL_W_WIDTH       = $clog2(KERNEL_W_MAX   + 1);
    localparam ACCUMULATOR_DELAY    = IS_FIXED_POINT ? FIXED_ACCUMULATOR_DELAY : FLOAT_ACCUMULATOR_DELAY ; 

    input  wire                      aclk;
    input  wire                      aclken;               
    input  wire                      aresetn;

    input  wire                      start;
    input  wire [KERNEL_W_WIDTH-1:0] kernel_w_1;
    input  wire                      is_1x1;

    output wire                      s_ready                                                          ;
    input  wire                      s_weights_valid                                                  ;
    input  wire [DATA_WIDTH  - 1: 0] s_weights_data                             [KERNEL_W_MAX - 1 : 0];

    input  wire                      s_step_pixels_valid                        [KERNEL_W_MAX - 1 : 0];
    input  wire [DATA_WIDTH  - 1: 0] s_step_pixels_data   [CONV_UNITS   - 1 : 0][KERNEL_W_MAX - 1 : 0];
    input  wire                      s_step_pixels_last                         [KERNEL_W_MAX - 1 : 0];
    input  wire [TUSER_WIDTH - 1: 0] s_step_pixels_user                         [KERNEL_W_MAX - 1 : 0];

    output wire                      m_valid                                    ;
    output wire [DATA_WIDTH  - 1: 0] m_data               [CONV_UNITS  - 1  : 0];
    output wire                      m_last                                     ;
    output wire [TUSER_WIDTH - 1: 0] m_user                                     ;

    /*
        STEP BUFFER FOR WEIGHTS
    */

    assign s_ready  = conv_s_ready [0];

    wire                      m_step_weights_valid [KERNEL_W_MAX - 1 : 0];
    wire [DATA_WIDTH  - 1: 0] m_step_weights_data  [KERNEL_W_MAX - 1 : 0];

    step_buffer  #(
        .DATA_WIDTH       (DATA_WIDTH),
        .STEPS            (KERNEL_W_MAX),
        .ACCUMULATOR_DELAY(ACCUMULATOR_DELAY),
        .TUSER_WIDTH      (TUSER_WIDTH)
    )
    step_buffer_weights
    (
        .aclk       (aclk                            ),
        .aclken     (s_ready                         ), // clken_mul
        .aresetn    (aresetn                         ),
        .is_1x1     (is_1x1                          ),
        
        .s_valid    ('{KERNEL_W_MAX{s_weights_valid}}),
        .s_data     (s_weights_data                  ),

        .m_valid    (m_step_weights_valid            ),
        .m_data     (m_step_weights_data             )
    );

    wire                   conv_s_ready [CONV_UNITS-1 : 0];
    wire                   conv_m_valid [CONV_UNITS-1 : 0];
    wire                   conv_m_last  [CONV_UNITS-1 : 0];
    wire [TUSER_WIDTH-1:0] conv_m_user  [CONV_UNITS-1 : 0];

    assign m_valid = conv_m_valid [0];
    assign m_last  = conv_m_last  [0];
    assign m_user  = conv_m_user  [0];
    
    genvar i;
    generate
    for (i=0; i < CONV_UNITS; i++) begin: conv_unit_gen
            
       conv_unit # (
            .IS_FIXED_POINT           (IS_FIXED_POINT),
            .DATA_WIDTH               (DATA_WIDTH),
            .KERNEL_W_MAX             (KERNEL_W_MAX),
            .TUSER_WIDTH              (TUSER_WIDTH),
            .FIXED_ACCUMULATOR_DELAY  (FIXED_ACCUMULATOR_DELAY),
            .FIXED_MULTIPLIER_DELAY   (FIXED_MULTIPLIER_DELAY),
            .INDEX_IS_1x1             (INDEX_IS_1x1),
            .INDEX_IS_MAX             (INDEX_IS_MAX),
            .INDEX_IS_RELU            (INDEX_IS_RELU),
            .INDEX_IS_COLS_1_K2       (INDEX_IS_COLS_1_K2)
        )
        CONV_UNIT
        (
            .aclk               (aclk                     ),
            .aclken             (aclken                   ),
            .aresetn            (aresetn                  ),
            .start              (start                    ),
            .kernel_w_1         (kernel_w_1               ),

            .s_ready            (conv_s_ready         [i] ),
            .s_step_pixels_valid(s_step_pixels_valid      ),
            .s_step_pixels_data (s_step_pixels_data   [i] ),
            .s_step_weights_data(m_step_weights_data      ),
            .s_step_pixels_last (s_step_pixels_last       ),
            .s_step_pixels_user (s_step_pixels_user       ),

            .m_valid            (conv_m_valid         [i] ),
            .m_data             (m_data               [i] ),
            .m_last             (conv_m_last          [i] ),
            .m_user             (conv_m_user          [i] )
        );
    end
    endgenerate


endmodule