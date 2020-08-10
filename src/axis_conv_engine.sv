/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.

Create Date: 26/07/2020
Design Name: AXIS Convolution Engine
Tool Versions: Vivado 2018.2
Description: * Not AXIS yet
             * Only one core, as 8 units
             * All step buffers are inside unit

Dependencies: 

Revision:
Revision 0.01 - File Created
Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////*/

module axis_conv_engine # (
    parameter CONV_UNITS            ,
    parameter DATA_WIDTH            ,
    parameter KERNEL_W_MAX          ,
    parameter KERNEL_H_MAX          , // odd number
    parameter TUSER_WIDTH           ,
    parameter CIN_COUNTER_WIDTH     ,
    parameter COLS_COUNTER_WIDTH    ,
    parameter ONE                   ,
    parameter ACCUMULATOR_DELAY     ,
    parameter MULTIPLIER_DELAY      ,

    parameter INDEX_IS_1x1          ,
    parameter INDEX_IS_MAX          ,
    parameter INDEX_IS_RELU         ,
    parameter INDEX_IS_COLS_1_K2     
)(
    aclk            ,
    aclken          ,
    aresetn         ,

    start           ,
    kernel_w_1      ,
    kernel_h_1      ,
    is_max          ,
    is_relu         ,
    cols_1          ,
    cin_1           ,

    pixels_s_valid  ,       
    pixels_s_data   ,   
    pixels_s_ready  ,

    weights_s_valid ,       
    weights_s_data  ,
    weights_s_ready ,

    m_valid         ,
    m_data          ,
    m_last          ,
    m_user          
);
    genvar i;
    localparam KERNEL_W_WIDTH       = $clog2(KERNEL_W_MAX   + 1);
    localparam KERNEL_H_WIDTH       = $clog2(KERNEL_H_MAX   + 1);

    input  wire                          aclk                                                   ;
    input  wire                          aclken                                                 ;               
    input  wire                          aresetn                                                ;
                                                                                                                                            
    input  wire                          start                                                  ;
    input  wire [KERNEL_W_WIDTH    -1:0] kernel_w_1                                             ;
    input  wire [KERNEL_H_WIDTH    -1:0] kernel_h_1                                             ;
    input  wire                          is_max                                                 ;
    input  wire                          is_relu                                                ;
    input  wire [COLS_COUNTER_WIDTH-1:0] cols_1                                                 ;
    input  wire [CIN_COUNTER_WIDTH -1:0] cin_1                                                  ;
                                                                                                
    input  wire                          pixels_s_valid                                         ;
    input  wire [DATA_WIDTH        -1:0] pixels_s_data  [CONV_UNITS + (KERNEL_H_MAX-1) -1 : 0]  ;
    output wire                          pixels_s_ready                                         ;
                                                                                                    
    input  wire                          weights_s_valid                                        ;
    output wire                          weights_s_ready                                        ;
    input  wire [DATA_WIDTH        -1:0] weights_s_data [KERNEL_W_MAX                  -1 : 0]  ;
                                                                                                    
    output wire                          m_valid                                                ;
    output wire [DATA_WIDTH        -1:0] m_data         [CONV_UNITS                    -1 : 0]  ;
    output wire                          m_last                                                 ;
    output wire [TUSER_WIDTH       -1:0] m_user                                                 ;
                                                                                                    


    //-----------------------------------------------------------------
    
    
    wire    [DATA_WIDTH -1 : 0]   shift_pixels_m_data   [CONV_UNITS-1 : 0];
    wire                          shift_pixels_m_valid                    ;
    wire                          shift_pixels_m_ready                    ;
    wire                          shift_pixels_m_last                     ;
    wire    [TUSER_WIDTH-1 : 0]   shift_pixels_m_user                     ;

    axis_shift_buffer #(
        .DATA_WIDTH         (DATA_WIDTH),
        .CONV_UNITS         (CONV_UNITS),
        .KERNEL_H_MAX       (KERNEL_H_MAX),
        .KERNEL_W_MAX       (KERNEL_W_MAX),
        .CIN_COUNTER_WIDTH  (CIN_COUNTER_WIDTH ),
        .COLS_COUNTER_WIDTH (COLS_COUNTER_WIDTH),
        .ONE                (ONE               ),
        .TUSER_WIDTH        (TUSER_WIDTH       ),
        .INDEX_IS_1x1       (INDEX_IS_1x1      ),
        .INDEX_IS_MAX       (INDEX_IS_MAX      ),
        .INDEX_IS_RELU      (INDEX_IS_RELU     ),
        .INDEX_IS_COLS_1_K2 (INDEX_IS_COLS_1_K2)
    )
    SHIFT_BUFFER
    (
        .aclk               (aclk           ),
        .aresetn            (aresetn        ),
        .start              (start          ),
        .kernel_h_1_in      (kernel_w_1     ),
        .kernel_w_1_in      (kernel_h_1     ),
        .is_max             (is_max         ),
        .is_relu            (is_relu        ),
        .cols_1             (cols_1         ),
        .cin_1              (cin_1          ),

        .S_AXIS_tdata       (pixels_s_data        ),
        .S_AXIS_tvalid      (pixels_s_valid       ),
        .S_AXIS_tready      (pixels_s_ready       ),

        .M_AXIS_tdata       (shift_pixels_m_data   ),
        .M_AXIS_tvalid      (shift_pixels_m_valid  ),
        .M_AXIS_tready      (shift_pixels_m_ready  ),
        .M_AXIS_tlast       (shift_pixels_m_last   ),
        .M_AXIS_tuser       (shift_pixels_m_user   )
    );

    /*
    SYNC WEIGHTS and PIXELS
    */

    wire conv_s_valid;

    assign conv_s_valid             = weights_s_valid   & shift_pixels_m_valid;
    assign weights_s_ready          = conv_s_ready [0]  & shift_pixels_m_valid;
    assign shift_pixels_m_ready     = conv_s_ready [0]  & weights_s_valid;

    wire                   conv_s_ready [CONV_UNITS-1 : 0];
    wire                   conv_m_valid [CONV_UNITS-1 : 0];
    wire                   conv_m_last  [CONV_UNITS-1 : 0];
    wire [TUSER_WIDTH-1:0] conv_m_user  [CONV_UNITS-1 : 0];

    assign m_valid  = conv_m_valid[0];
    assign m_last   = conv_m_last [0];
    assign m_user   = conv_m_user [0];

    generate
    for (i=0; i < CONV_UNITS; i++) begin: conv_unit_gen
            
       conv_unit # (
            .DATA_WIDTH               (DATA_WIDTH),
            .KERNEL_W_MAX             (KERNEL_W_MAX),
            .TUSER_WIDTH              (TUSER_WIDTH),
            .ACCUMULATOR_DELAY        (ACCUMULATOR_DELAY) ,
            .MULTIPLIER_DELAY         (MULTIPLIER_DELAY),
            .INDEX_IS_1x1             (INDEX_IS_1x1),
            .INDEX_IS_MAX             (INDEX_IS_MAX),
            .INDEX_IS_RELU            (INDEX_IS_RELU),
            .INDEX_IS_COLS_1_K2       (INDEX_IS_COLS_1_K2)
        )
        CONV_UNIT
        (
            .aclk           (aclk                     ),
            .aclken         (aclken                   ),
            .aresetn        (aresetn                  ),
            .start          (start                    ),
            .kernel_w_1     (kernel_w_1               ),

            .s_valid        (conv_s_valid             ),       
            .s_data_pixels  (shift_pixels_m_data  [i] ), 
            .s_data_weights (weights_s_data           ),
            .s_ready        (conv_s_ready  [i]        ),        
            .s_last         (shift_pixels_m_last      ),        
            .s_user         (shift_pixels_m_user      ),        

            .m_valid        (conv_m_valid  [i]        ),
            .m_data         (m_data        [i]        ),
            .m_last         (conv_m_last   [i]        ),
            .m_user         (conv_m_user   [i]        )
        );
    end
    endgenerate

endmodule;