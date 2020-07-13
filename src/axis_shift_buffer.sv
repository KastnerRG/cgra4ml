/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.

Create Date: 11/07/2020
Design Name: AXIS Shift buffer
Tool Versions: Vivado 2018.2
Description: * Pipelined module that takes in AXIS of padded rows and releases kernel_h 
               shifted versions of them in kernel_h clocks as AXIS.
             * kernel_h is dynamically configurable.
             * Eg: If KERNEL_H_MAX == 7:
                    - (7,*) , (5,*), (3,*), (1,*) convolutions are possible
                    - * denotes that kernel can be non-square: (7*4) for example
                    - Input number of words are CONV_UNITS + (7-1) = 8 + 7 - 1 = 14
                    - Then if kernel_h == 3 (dynamically):
                        - kernel_h_1 is given as 2 (actual-1)
                        - 14 pixels will be shifted down 3 times
                        - First 10 (=8+2) words of 14 (=8+6) should be the valid 
                            padded inputs for 3x3
             

Dependencies: * axis_register_slice_data_buffer 
                    - Type: IP (axis_register_slice) configured
                    - Data width = {(KERNEL_H_MAX-1) * (DATA_WIDTH/8)} bytes

Revision:
Revision 0.01 - File Created
Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////*/

module axis_shift_buffer#(
    parameter DATA_WIDTH            = 16,
    parameter CONV_UNITS            = 8,
    parameter KERNEL_H_MAX          = 3,
    parameter CH_IN_COUNTER_WIDTH   = 10
)(
    aclk,
    aresetn,

    im_channels_in_1,   // = (im_channels_in    - 1)
    kernel_h_1,         // = (kernel_h          - 1)

    S_AXIS_tdata,
    S_AXIS_tvalid,
    S_AXIS_tready,

    M_AXIS_tdata,
    M_AXIS_tvalid,
    M_AXIS_tready,
    M_AXIS_tlast
);

    input   wire    aclk;
    input   wire    aresetn;
    input   wire    [CH_IN_COUNTER_WIDTH    -1       : 0]   im_channels_in_1;
    input   wire    [KERNEL_H_MAX           -1       : 0]   kernel_h_1;
    

    input   wire    [DATA_WIDTH * (CONV_UNITS + (KERNEL_H_MAX-1)) - 1 : 0]   S_AXIS_tdata;
    input   wire                                            S_AXIS_tvalid;
    output  wire                                            S_AXIS_tready;

    output  wire    [DATA_WIDTH * (CONV_UNITS) - 1 : 0]     M_AXIS_tdata;
    output  wire                                            M_AXIS_tvalid;
    input   wire                                            M_AXIS_tready;
    output  wire                                            M_AXIS_tlast;


    /* 
    Register kernel_h_1 for performance
    */

    wire [KERNEL_H_MAX           -1       : 0]  kernel_h_1_out;
    wire                                        kernel_h_clken;
    assign kernel_h_clken = S_AXIS_tready && S_AXIS_tvalid; // Slave's handshake

    register
    #(
        .WORD_WIDTH     (KERNEL_H_MAX),
        .RESET_VALUE    (1)         
    )
    kernel_h_1_reg
    (
        .clock          (aclk),
        .clock_enable   (kernel_h_clken),
        .resetn         (aresetn),
        .data_in        (kernel_h_1),
        .data_out       (kernel_h_1_out)
    );


    // HANDSHAKES

    wire insert;
    wire remove;

    wire slice_M_AXIS_tvalid;
        
    assign insert = slice_M_AXIS_tvalid && M_AXIS_tready;
    assign remove = M_AXIS_tvalid   && M_AXIS_tready;

    // STATE
    /*
    "state" register's current value denotes the positioning of data that is 
    "going into" the data_out registers in this clock cycle (will be available
    in m_data in the next clock). 

    eg: state == 0 means, first 8 is going into the regs now and those will be
    available in m_data in next clock cycle.

    state_next is combinational fed into the state reg in this clock.

    state = 0       :   state_next = 0 + insert
    state = 1       :   state_next = 1 + remove
    state = 2       :   state_next = 2 + remove
    state = last    :   state_next = 0

    if m_ready goes down at state=last, state_next is changed, but state_reg 
    is not updated (update_state = insert || remove). Hence it is safe.

    */

    localparam STATE_WIDTH = $clog2(KERNEL_H_MAX);

    wire [STATE_WIDTH-1:0]  state;
    reg  [STATE_WIDTH-1:0]  state_next;
    wire update_state;
    
    assign update_state = insert || remove;

    always @ (*) begin
        case(state)
            kernel_h_1_out  : state_next <= 0;
            0               : state_next <= insert;
            default         : state_next <= state + remove;
        endcase
    end

    register
    #(
        .WORD_WIDTH     (STATE_WIDTH),
        .RESET_VALUE    (1'b0)         // Initial state
    )
    state_reg
    (
        .clock          (aclk),
        .clock_enable   (update_state),
        .resetn         (aresetn),
        .data_in        (state_next),
        .data_out       (state)
    );
    
    /*
    Reg slice to skid the input AXI stream
    */

    wire [DATA_WIDTH * (CONV_UNITS + (KERNEL_H_MAX-1)) - 1 : 0]  slice_M_AXIS_tdata;
//    wire                                        slice_M_AXIS_tvalid; // Defined above slice to avoid warning
    wire                                        slice_M_AXIS_tready;

    assign slice_M_AXIS_tready = (state==0) && M_AXIS_tready;
    
    axis_register_slice_data_buffer reg_slice (
      .aclk(aclk),                    
      .aresetn(aresetn),              
      .s_axis_tvalid(S_AXIS_tvalid),  
      .s_axis_tready(S_AXIS_tready),  
      .s_axis_tdata(S_AXIS_tdata),    
      .m_axis_tvalid(slice_M_AXIS_tvalid),  
      .m_axis_tready(slice_M_AXIS_tready), 
      .m_axis_tdata(slice_M_AXIS_tdata)    
    );

    // OUTPUT VALID
    wire    m_valid_next;
    assign  m_valid_next = (state == 0) ? slice_M_AXIS_tvalid : M_AXIS_tvalid;

    register
    #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (1'b0)         // Initially invalid
    )
    m_valid_reg
    (
        .clock          (aclk),
        .clock_enable   (1'b1),
        .resetn         (aresetn),
        .data_in        (m_valid_next),
        .data_out       (M_AXIS_tvalid)
    );
    

    /*
    DATA REGISTERS

    * There are 10 (=8 + (KERNEL_H_MAX-1)) data registers
    * First 8 are connected to m_data
    * selected_data[-1] is only from d_in[-1]
    * all other selected_data[i] are muxed between data[i+1] and d_in[i]

    */


    wire    [DATA_WIDTH-1:0]    slice_s_data    [CONV_UNITS + (KERNEL_H_MAX-1)-1:0];
    wire    [DATA_WIDTH-1:0]    selected_data   [CONV_UNITS + (KERNEL_H_MAX-1)-1:0];
    wire    [DATA_WIDTH-1:0]    data_out        [CONV_UNITS + (KERNEL_H_MAX-1)-1:0];
    wire    [DATA_WIDTH-1:0]    m_data          [CONV_UNITS  -1:0];

    wire shift;
    assign shift = insert || remove;

    genvar i;
    generate

        // 10 slice_s_data mapped
        for (i=0; i < CONV_UNITS  + (KERNEL_H_MAX-1); i=i+1) begin: s_data_gen
            assign slice_s_data[i] = slice_M_AXIS_tdata[(i+1)*DATA_WIDTH-1: i*DATA_WIDTH];
        end
        
        // First 8 data_out registers (of 10) connected to m_data
        for (i=0; i < CONV_UNITS; i=i+1) begin: m_data_gen
            assign M_AXIS_tdata[(i+1)*DATA_WIDTH-1: i*DATA_WIDTH] = data_out[i];
        end

        // selected_data[9](1)     is from  slice_s_data[9](1)
        // selected_data[0..8](9) are muxed between data_out[1..9](9) and slice_s_data[0..8](9)
        assign selected_data[CONV_UNITS + (KERNEL_H_MAX-1)-1] = slice_s_data[CONV_UNITS + (KERNEL_H_MAX-1)-1];

        for (i=0; i < CONV_UNITS  + (KERNEL_H_MAX-1)-1; i=i+1) begin: selected_data_gen
            assign selected_data[i] = (state == 0) ? slice_s_data[i] : data_out[i+1];
        end

        // 10 data_out registers
        for (i=0; i < CONV_UNITS  + (KERNEL_H_MAX-1); i=i+1) begin: data_out_reg_gen
            register
            #(
                .WORD_WIDTH     (DATA_WIDTH),
                .RESET_VALUE    (0)
            )
            m_data_reg
            (
                .clock          (aclk),
                .clock_enable   (shift),
                .resetn         (aresetn),
                .data_in        (selected_data[i]),
                .data_out       (data_out[i])
            );
        end

    endgenerate

    // /*
    // TLAST GENERATON

    // * For every IM_CH_IN groups of input data beats, passes a single tlast bit at the
    //   last output data beat (every IM_CH_IN * KERNEL_H_MAX beats).
    // * IM_CH_IN is not given, but (IM_CH_IN_1 = IM_CH_IN-1) is give
    // * This is why inital value is kept at (-1). Else, it counts only IM_CH_IN-1 beats

    // * Last data beat is delayed by KERNEL_H_MAX (>3). Hence Tlast can be calculated by at least 3 regs

    // */

    // wire [CH_IN_COUNTER_WIDTH -1 : 0] im_channels_1_reg_out;

    // register
    // #(
    //     .WORD_WIDTH     (CH_IN_COUNTER_WIDTH),
    //     .RESET_VALUE    (1'b0)
    // )
    // im_channels_1_reg
    // (
    //     .clock          (aclk),
    //     .clock_enable   (1'b1),
    //     .resetn         (aresetn),
    //     .data_in        (im_channels_1),
    //     .data_out       (im_channels_1_reg_out)
    // );

    // // wire insert_reg_out;

    // // register
    // // #(
    // //     .WORD_WIDTH     (1),
    // //     .RESET_VALUE    (1'b0)         // Initial state
    // // )
    // // insert_reg
    // // (
    // //     .clock          (aclk),
    // //     .clock_enable   (1'b1),
    // //     .resetn         (aresetn),
    // //     .data_in        (insert),
    // //     .data_out       (insert_reg_out)
    // // );

    // wire [CH_IN_COUNTER_WIDTH-1 : 0] ch_in_counter_out;
    // wire [CH_IN_COUNTER_WIDTH-1 : 0] ch_in_counter_in;

    // assign ch_in_counter_in = tlast_delays[1] ? COUNTER_START : (ch_in_counter_out + insert);

    // register
    // #(
    //     .WORD_WIDTH     (CH_IN_COUNTER_WIDTH),
    //     .RESET_VALUE    (COUNTER_START)         // Initial state
    // )
    // ch_in_counter_reg
    // (
    //     .clock          (aclk),
    //     .clock_enable   (1'b1),
    //     .resetn         (aresetn),
    //     .data_in        (ch_in_counter_in),
    //     .data_out       (ch_in_counter_out)
    // );

    // /*
    // Tlast is asserted based on 3 things:

    // 1. Counter gets full : Checks if all channels have been received at input side (KERNEL_H_MAX clocks long)
    // 2. State = 2, since tlast compute takes 3 clocks already, to tie to that data
    // 3. remove: Previous data is being removed from m_data (output handshake).
    //     If not, if ready goes down in this clock, tlast=1 will be written in and 
    //     will get tied to second_to_last data as well (which wouldnt change).
    // */

    // localparam FURTHUR_DELAY = KERNEL_H_MAX - 3;    

    // wire [FURTHUR_DELAY+1 :0] tlast_delays;
    // assign tlast_delays[0]  = (ch_in_counter_out == im_channels_1_reg_out) && (state==2);
    // assign M_AXIS_tlast     = tlast_delays[FURTHUR_DELAY+1];

    // generate
    //     for(i=0; i<FURTHUR_DELAY+1; i=i+1) begin: tlast_delay_regs
    //         register
    //         #(
    //             .WORD_WIDTH     (1),
    //             .RESET_VALUE    (1'b0)         // Initial state
    //         )
    //         ch_in_compare_reg
    //         (
    //             .clock          (aclk),
    //             .clock_enable   (remove),
    //             .resetn         (aresetn),
    //             .data_in        (tlast_delays[i]),
    //             .data_out       (tlast_delays[i+1])
    //         );
    //     end
    // endgenerate


endmodule