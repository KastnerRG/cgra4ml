/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.

Create Date: 20/08/2020
Design Name: AXIS Convolution Core
Tool Versions: Vivado 2018.2
Description:
            * One core computes one output filter.
            * Weights are stepped inside here.
            * Generates CONV_UNITS number of units, sets the first one ACTIVE and 
                provides the control signals driven by it to PASSIVE ones.

Revision:
Revision 0.01 - File Created
Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////*/

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

    s_step_pixels_data  , 
    s_step_pixels_last  , 
    s_step_pixels_user  ,     

    m_valid             ,
    m_data              ,
    m_last              ,
    m_user              

);
    localparam KERNEL_W_WIDTH       = $clog2(KERNEL_W_MAX   + 1)                                      ;
    localparam ACCUMULATOR_DELAY    = IS_FIXED_POINT ? FIXED_ACCUMULATOR_DELAY : FLOAT_ACCUMULATOR_DELAY ; 

    input  wire                      aclk                                                             ;
    input  wire                      aclken                                                           ;               
    input  wire                      aresetn                                                          ;

    input  wire                      start                                                            ;
    input  wire [KERNEL_W_WIDTH-1:0] kernel_w_1                                                       ;
    input  wire                      is_1x1                                                           ;

    output wire                      s_ready                                                          ;
    input  wire                      s_weights_valid                                                  ;
    input  wire [DATA_WIDTH  - 1: 0] s_weights_data                             [KERNEL_W_MAX - 1 : 0];

    input  wire [DATA_WIDTH  - 1: 0] s_step_pixels_data   [CONV_UNITS   - 1 : 0][KERNEL_W_MAX - 1 : 0];
    input  wire                      s_step_pixels_last                         [KERNEL_W_MAX - 1 : 0];
    input  wire [TUSER_WIDTH - 1: 0] s_step_pixels_user                         [KERNEL_W_MAX - 1 : 0];

    output wire                      m_valid                                                          ;
    output wire [DATA_WIDTH  - 1: 0] m_data               [CONV_UNITS  - 1  : 0]                      ;
    output wire                      m_last                                                           ;
    output wire [TUSER_WIDTH - 1: 0] m_user                                                           ;

    /*
        STEP BUFFER FOR WEIGHTS
    */

    wire                      m_step_weights_valid [KERNEL_W_MAX - 1 : 0];
    wire [DATA_WIDTH  - 1: 0] m_step_weights_data  [KERNEL_W_MAX - 1 : 0];

    step_buffer  #(
        .DATA_WIDTH       (DATA_WIDTH                   ),
        .STEPS            (KERNEL_W_MAX                 ),
        .ACCUMULATOR_DELAY(ACCUMULATOR_DELAY            ),
        .TUSER_WIDTH      (TUSER_WIDTH                  )
    )
    step_buffer_weights
    (
        .aclk       (aclk                               ),
        .aclken     (s_ready                            ),
        .aresetn    (aresetn                            ),
        .is_1x1     (is_1x1                             ),
        
        .s_valid    ('{KERNEL_W_MAX{s_weights_valid}}   ),
        .s_data     (s_weights_data                     ),

        .m_valid    (m_step_weights_valid               ),
        .m_data     (m_step_weights_data                )
    );

    
    /*
        - CONV_UNITS number of units are generated.
        - First unit is set ACTIVE, rest are set PASSIVE
        - s_ready, m_valid, m_user, m_last come from ACTIVE unit
    */

    // Wires that distribute driven signals from out_* of ACTIVE to in_* of passive units.

    wire [KERNEL_W_MAX-1 : 1] mux_sel                           ;
    wire                      clken_mul                         ;
    wire [KERNEL_W_MAX-1 : 0] clken_acc                         ;
    wire                      mux_s2_valid[KERNEL_W_MAX - 1 : 1];
    wire                      acc_s_valid [KERNEL_W_MAX - 1 : 0];
    wire                      acc_s_last  [KERNEL_W_MAX - 1 : 0];     
    wire                      shift_sel   [KERNEL_W_MAX - 2 : 0];     

    genvar i;
    generate
        for (i=0; i < CONV_UNITS; i++) begin: conv_unit_gen
            if (i == 0)
                conv_unit # (
                        .IS_ACTIVE                (1                      ),
                        .IS_FIXED_POINT           (IS_FIXED_POINT         ),
                        .DATA_WIDTH               (DATA_WIDTH             ),
                        .KERNEL_W_MAX             (KERNEL_W_MAX           ),
                        .TUSER_WIDTH              (TUSER_WIDTH            ),
                        .FIXED_ACCUMULATOR_DELAY  (FIXED_ACCUMULATOR_DELAY),
                        .FIXED_MULTIPLIER_DELAY   (FIXED_MULTIPLIER_DELAY ),
                        .INDEX_IS_1x1             (INDEX_IS_1x1           ),
                        .INDEX_IS_MAX             (INDEX_IS_MAX           ),
                        .INDEX_IS_RELU            (INDEX_IS_RELU          ),
                        .INDEX_IS_COLS_1_K2       (INDEX_IS_COLS_1_K2     )
                    )
                    CONV_UNIT
                    (
                        .aclk                   (aclk                     ),
                        .aclken                 (aclken                   ),
                        .aresetn                (aresetn                  ),
                        .s_step_pixels_data     (s_step_pixels_data   [i] ),
                        .s_step_weights_valid   (m_step_weights_valid     ),
                        .s_step_weights_data    (m_step_weights_data      ),
                        .m_data                 (m_data               [i] ),

                        .start                  (start                    ),
                        .kernel_w_1             (kernel_w_1               ),

                        .s_step_pixels_last     (s_step_pixels_last       ),
                        .s_step_pixels_user     (s_step_pixels_user       ),

                        .s_ready                (s_ready                  ),
                        .m_valid                (m_valid                  ),
                        .m_last                 (m_last                   ),
                        .m_user                 (m_user                   ),

                        .out_mux_sel            (mux_sel                  ),
                        .out_clken_mul          (clken_mul                ),
                        .out_clken_acc          (clken_acc                ),
                        .out_mux_s2_valid       (mux_s2_valid             ),
                        .out_acc_s_valid        (acc_s_valid              ),
                        .out_acc_s_last         (acc_s_last               ),
                        .out_shift_sel          (shift_sel                )

                    );
            else
                conv_unit # (
                        .IS_ACTIVE                (0                      ),
                        .IS_FIXED_POINT           (IS_FIXED_POINT         ),
                        .DATA_WIDTH               (DATA_WIDTH             ),
                        .KERNEL_W_MAX             (KERNEL_W_MAX           ),
                        .TUSER_WIDTH              (TUSER_WIDTH            ),
                        .FIXED_ACCUMULATOR_DELAY  (FIXED_ACCUMULATOR_DELAY),
                        .FIXED_MULTIPLIER_DELAY   (FIXED_MULTIPLIER_DELAY ),
                        .INDEX_IS_1x1             (INDEX_IS_1x1           ),
                        .INDEX_IS_MAX             (INDEX_IS_MAX           ),
                        .INDEX_IS_RELU            (INDEX_IS_RELU          ),
                        .INDEX_IS_COLS_1_K2       (INDEX_IS_COLS_1_K2     )
                    )
                    CONV_UNIT
                    (
                        .aclk                   (aclk                     ),
                        .aclken                 (aclken                   ),
                        .aresetn                (aresetn                  ),
                        .s_step_pixels_data     (s_step_pixels_data   [i] ),
                        .s_step_weights_valid   (m_step_weights_valid     ),
                        .s_step_weights_data    (m_step_weights_data      ),
                        .m_data                 (m_data               [i] ),

                        .in_mux_sel             (mux_sel                  ),
                        .in_clken_mul           (clken_mul                ),
                        .in_clken_acc           (clken_acc                ),
                        .in_mux_s2_valid        (mux_s2_valid             ),
                        .in_acc_s_valid         (acc_s_valid              ),
                        .in_acc_s_last          (acc_s_last               ),
                        .in_shift_sel           (shift_sel                )
                    );
        end
    endgenerate


endmodule