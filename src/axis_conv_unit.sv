/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.

Create Date: 11/07/2020
Design Name: AXIS Convolution unit
Tool Versions: Vivado 2018.2
Description:    * Fully pipelined
                * Supports (n x m) convolution kernel
                * tuser
                    0 : block_last
                    1 : is 3x3
                    2 : max
                    3 : relu

Dependencies: * Floating point IP
                    - name : floating_point_multiplier
              * Floating point IP
                    - name : 

Revision:
Revision 0.01 - File Created
Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////*/

module axis_conv_unit # (
    parameter DATA_WIDTH   = 16,
    parameter KERNEL_W_MAX = 3,
    parameter TUSER_WIDTH  = 4
)(
    aclk,
    aresetn,

    S_AXIS_tvalid,
    S_AXIS_tready,
    S_AXIS_tdata_pixels,
    S_AXIS_tdata_weights,
    S_AXIS_tdata_bias,
    S_AXIS_tlast,
    S_AXIS_tuser,
    
    M_AXIS_tvalid,
    M_AXIS_tready,
    M_AXIS_tdata,
    M_AXIS_tlast

);

    input  wire                                     aclk;
    input  wire                                     aresetn;

    input  wire                                     is_1x1;

    input  wire                                     S_AXIS_tvalid;
    output wire                                     S_AXIS_tready;
    input  wire [DATA_WIDTH                 - 1: 0] S_AXIS_tdata_pixels;
    input  wire [DATA_WIDTH * KERNEL_W_MAX  - 1: 0] S_AXIS_tdata_weights;
    input  wire [DATA_WIDTH                 - 1: 0] S_AXIS_tdata_bias;
    input  wire                                     S_AXIS_tlast;
    input  wire [TUSER_WIDTH                - 1: 0] S_AXIS_tuser;

    output wire                                     M_AXIS_tvalid;
    input  wire                                     M_AXIS_tready;
    output wire [DATA_WIDTH * KERNEL_W_MAX  - 1: 0] M_AXIS_tdata;
    output wire                                     M_AXIS_tlast;
    output wire [TUSER_WIDTH                - 1: 0] M_AXIS_tuser;



    wire   [DATA_WIDTH - 1 : 0] mul_s_data  [KERNEL_W_MAX - 1 : 0];

    wire   [DATA_WIDTH - 1 : 0] mul_m_data          [KERNEL_W_MAX - 1 : 0];
    wire                        mul_m_valid         [KERNEL_W_MAX - 1 : 0];
    wire                        mul_m_ready         [KERNEL_W_MAX - 1 : 0];
    wire                        mul_m_last          [KERNEL_W_MAX - 1 : 0];
    wire                        mul_m_user          [TUSER_WIDTH  - 1 : 0];
    wire   [TUSER_WIDTH - 1: 0] mul_m_user          [TUSER_WIDTH  - 1 : 0];
    
    wire   [DATA_WIDTH - 1 : 0] acc_s_data  [KERNEL_W_MAX - 1 : 0];
    wire                        acc_s_valid [KERNEL_W_MAX - 1 : 0];
    wire                        acc_s_ready [KERNEL_W_MAX - 1 : 0];
    wire                        acc_s_last  [KERNEL_W_MAX - 1 : 0];
    wire   [TUSER_WIDTH - 1: 0] acc_s_user  [TUSER_WIDTH  - 1 : 0];


    wire   [DATA_WIDTH - 1 : 0] acc_m_data  [KERNEL_W_MAX - 1 : 0];
    wire                        acc_m_valid [KERNEL_W_MAX - 1 : 0];
    wire                        acc_m_ready [KERNEL_W_MAX - 1 : 0];
    wire                        acc_m_last  [KERNEL_W_MAX - 1 : 0];
    wire   [TUSER_WIDTH - 1: 0] acc_m_user  [TUSER_WIDTH  - 1 : 0];


    wire   [DATA_WIDTH - 1 : 0] mux_s2_data [KERNEL_W_MAX - 1 : 0];
    wire                        mux_s2_valid[KERNEL_W_MAX - 1 : 0];
    wire                        mux_s2_ready[KERNEL_W_MAX - 1 : 0];
    wire                        mux_s2_last [KERNEL_W_MAX - 1 : 0];
    wire   [TUSER_WIDTH - 1: 0] mux_s2_user [TUSER_WIDTH  - 1 : 0];


    wire                        mux_sel     [KERNEL_W_MAX - 1 : 0];



    genvar i;
    generate
        for (i=0; i < KERNEL_W_MAX; i++) begin : multipliers_gen

            floating_point_multiplier multiplier (
                .aclk                   (aclk),                                  
                .aresetn                (aresetn),
                
                .s_axis_a_tvalid        (S_AXIS_tvalid),            
                .s_axis_a_tready        (S_AXIS_tready),            
                .s_axis_a_tdata         (S_AXIS_tdata_pixels),              
                .s_axis_a_tlast         (S_AXIS_tlast_im_channels_in),              

                .s_axis_b_tvalid        (S_AXIS_tvalid),            
                .s_axis_b_tready        (S_AXIS_tready),
                .s_axis_b_tdata         (mul_s_data     [i]),
                
                .m_axis_result_tvalid   (mul_m_valid    [i]),  
                .m_axis_result_tready   (mul_m_ready    [i]),  
                .m_axis_result_tdata    (mul_m_data     [i]),    
                .m_axis_result_tlast    (mul_m_last     [i])     
            );
        end

        for (i=0; i < KERNEL_W_MAX; i++) begin : accumulators_gen

            floating_point_accumulator accumulator (
                .aclk                   (aclk),                                  
                .aresetn                (aresetn),

                .s_axis_a_tvalid        (acc_s_valid    [i]),
                .s_axis_a_tready        (acc_s_ready    [i]), 
                .s_axis_a_tdata         (acc_s_data     [i]),    
                .s_axis_a_tlast         (acc_s_last     [i]),     

                .m_axis_result_tvalid   (acc_s_valid    [i]), 
                .m_axis_result_tready   (acc_s_ready    [i]), 
                .m_axis_result_tdata    (acc_s_data     [i]),  
                .m_axis_result_tlast    (acc_s_last     [i])   
            );
        end

        for (i=0; i < KERNEL_W_MAX; i++) begin : sel_regs_gen

            assign remove = acc_s_valid[i] && acc_s_ready[i];
            
            register #(
                parameter WORD_WIDTH  = DATA_WIDTH,
                parameter RESET_VALUE = 0
            )
            sel_registers
            (
                .clock          (aclk),
                .clock_enable   (remove),
                .resetn         (aresetn),
                .data_in        (mul_m_last [i]),
                .data_out       (mux_sel    [i])
            );
        end

        for (i=0; i < KERNEL_W_MAX; i++) begin : mux_gen

            axis_mux #(
                parameter DATA_WIDTH = DATA_WIDTH
            )
            mux
            (
                .aclk               (aclk),
                .aresetn            (aresetn),
                .sel                (mux_sel        [i]),

                .S0_AXIS_tdata      (mul_m_data     [i]),
                .S0_AXIS_tvalid     (mul_m_valid    [i]),
                .S0_AXIS_tready     (mul_m_ready    [i]),
                .S0_AXIS_tlast      (mul_m_last     [i]),

                .S1_AXIS_tdata      (mux_s2_data    [i]), 
                .S1_AXIS_tvalid     (mux_s2_valid   [i]),
                .S1_AXIS_tready     (mux_s2_ready   [i]),
                .S1_AXIS_tlast      (mux_s2_last    [i]),

                .M_AXIS_tdata       (acc_s_data     [i]),
                .M_AXIS_tvalid      (acc_s_valid    [i]),
                .M_AXIS_tready      (acc_s_ready    [i]),
                .M_AXIS_tlast       (acc_s_last     [i]),
            );
        end

        assign mux_s2_data   [0]    = S_AXIS_tdata_bias;
        assign mux_s2_valid  [0]    = S_AXIS_tvalid;
        assign mux_s2_ready  [0]    = S_AXIS_tready;
        assign mux_s2_last   [0]    = S_AXIS_tlast_blocks;

        for (i=1; i < KERNEL_W_MAX; i++) begin : acc_to_mux

            assign mux_s2_data   [i]    = acc_m_data    [i-1];
            assign mux_s2_valid  [i]    = acc_m_valid   [i-1];
            assign mux_s2_ready  [i]    = acc_m_ready   [i-1];
            assign mux_s2_last   [i]    = acc_m_last    [i-1];

        end

    endgenerate


    floating_point_accumulator accumulator (
        .aclk                   (aclk),                                  
        .aresetn                (aresetn),

        .s_axis_a_tvalid        (s_axis_a_tvalid),
        .s_axis_a_tready        (s_axis_a_tready), 
        .s_axis_a_tdata         (s_axis_a_tdata),    
        .s_axis_a_tlast         (s_axis_a_tlast),     

        .m_axis_result_tvalid   (m_axis_result_tvalid), 
        .m_axis_result_tready   (m_axis_result_tready), 
        .m_axis_result_tdata    (m_axis_result_tdata),  
        .m_axis_result_tlast    (m_axis_result_tlast)   
    );

    wire sel;

    

endmodule

