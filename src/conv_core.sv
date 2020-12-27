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
    parameter CONV_UNITS        ,
    parameter WORD_WIDTH_IN     ,
    parameter WORD_WIDTH_OUT    ,
    parameter KERNEL_W_MAX      ,
    parameter TUSER_WIDTH       ,
    parameter ACCUMULATOR_DELAY ,
    parameter MULTIPLIER_DELAY  ,
    parameter INDEX_IS_1x1      ,
    parameter INDEX_IS_MAX      ,
    parameter INDEX_IS_RELU     ,
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
    localparam KERNEL_W_WIDTH = $clog2(KERNEL_W_MAX   + 1);

    input  logic aclk;
    input  logic aclken;               
    input  logic aresetn;

    input  logic start;
    input  logic [KERNEL_W_WIDTH-1:0] kernel_w_1;
    input  logic is_1x1;

    output logic s_ready;
    input  logic s_weights_valid;
    input  logic s_step_pixels_last [KERNEL_W_MAX - 1 : 0];
    input  logic [TUSER_WIDTH - 1: 0] s_step_pixels_user [KERNEL_W_MAX - 1 : 0];

    input  logic [WORD_WIDTH_IN  - 1: 0] s_weights_data                             [KERNEL_W_MAX - 1 : 0];
    input  logic [WORD_WIDTH_IN  - 1: 0] s_step_pixels_data   [CONV_UNITS   - 1 : 0][KERNEL_W_MAX - 1 : 0];

    output logic m_valid;
    output logic m_last ;
    output logic [WORD_WIDTH_OUT-1: 0] m_data [CONV_UNITS  - 1  : 0];
    output logic [TUSER_WIDTH - 1: 0]  m_user ;

    /*
        STEP BUFFER FOR WEIGHTS
    */

    logic                      m_step_weights_valid    [KERNEL_W_MAX - 1 : 0];
    logic [WORD_WIDTH_IN  - 1: 0] m_step_weights_data  [KERNEL_W_MAX - 1 : 0];

    step_buffer  #(
        .WORD_WIDTH       (WORD_WIDTH_IN    ),
        .STEPS            (KERNEL_W_MAX     ),
        .ACCUMULATOR_DELAY(ACCUMULATOR_DELAY),
        .TUSER_WIDTH      (TUSER_WIDTH      )
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

    logic [KERNEL_W_MAX-1 : 1] mux_sel                           ;
    logic                      clken_mul                         ;
    logic [KERNEL_W_MAX-1 : 0] clken_acc                         ;
    logic                      mux_s2_valid[KERNEL_W_MAX - 1 : 1];
    logic                      acc_s_valid [KERNEL_W_MAX - 1 : 0];
    logic                      acc_s_last  [KERNEL_W_MAX - 1 : 0];     
    logic                      shift_sel   [KERNEL_W_MAX - 2 : 0];     

    genvar i;
    generate
        for (i=0; i < CONV_UNITS; i++) begin: conv_unit_gen
            if (i == 0)
                conv_unit # (
                        .IS_ACTIVE                (1                      ),
                        .WORD_WIDTH_IN            (WORD_WIDTH_IN          ),
                        .WORD_WIDTH_OUT           (WORD_WIDTH_OUT         ),
                        .KERNEL_W_MAX             (KERNEL_W_MAX           ),
                        .TUSER_WIDTH              (TUSER_WIDTH            ),
                        .ACCUMULATOR_DELAY        (ACCUMULATOR_DELAY      ),
                        .MULTIPLIER_DELAY         (MULTIPLIER_DELAY       ),
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
                        .WORD_WIDTH_IN            (WORD_WIDTH_IN          ),
                        .WORD_WIDTH_OUT           (WORD_WIDTH_OUT         ),
                        .KERNEL_W_MAX             (KERNEL_W_MAX           ),
                        .TUSER_WIDTH              (TUSER_WIDTH            ),
                        .ACCUMULATOR_DELAY        (ACCUMULATOR_DELAY      ),
                        .MULTIPLIER_DELAY         (MULTIPLIER_DELAY       ),
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