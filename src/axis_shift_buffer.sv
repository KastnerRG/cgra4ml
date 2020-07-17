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
    localparam STATE_WIDTH = $clog2(KERNEL_H_MAX+1);

    wire [CH_IN_COUNTER_WIDTH-1 : 0] selected_count;
    assign selected_count = (kernel_h_1_out == 0) ? count_next : count;

    wire tlast_in = (state == kernel_h_1_out) && (selected_count == im_channels_1_reg_out);


    wire [STATE_WIDTH-1:0]  state;
    reg [STATE_WIDTH-1:0]  state_next;
    wire update_state;
    
    assign update_state = insert || remove;

    always @ (*) begin
        if (tlast_in)
            state_next <= 3'd7;
        else if (state == kernel_h_1_out)
            state_next <= 0;
        else if (state == 0)
            state_next <= insert;
        else 
            state_next <= state + remove;
    end


    register
    #(
        .WORD_WIDTH     (STATE_WIDTH),
        .RESET_VALUE    (0)         // Initial state
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
    REG SLICE
    
    * Skids the input AXI stream if m_ready goes down in same cycle as the insert handshake
    * M_ready is AND'ed with (state=0) => last shift data is being accepted downstream in this clock, 
        next is first data (zero shift).
    * If skid_m_valid stays high in this clock, they together form a "remove" handshake, data gets copied
        from reg slice into data_out at, at next rising edge and will be available throughout next clock

    */

    wire [DATA_WIDTH * (CONV_UNITS + (KERNEL_H_MAX-1)) - 1 : 0]  slice_M_AXIS_tdata;
    wire                                        slice_M_AXIS_tready;
//  wire                                        slice_M_AXIS_tvalid;              // Defined above slice to avoid warning

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

    /*
    MASTER_VALID
    */
    reg m_valid_next;
    wire cond_vA;
    wire cond_vB;
    wire result_vB;
    
    wire change_data = ((state == 0) && insert) || remove;


    always @(*) begin
        if (state_data_out == 3'd7)
            m_valid_next <= 1;
        else if (state ==  0)
            m_valid_next <= slice_M_AXIS_tvalid;
        else 
            m_valid_next <= M_AXIS_tvalid;
    end

    register
    #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (1)         // Initially invalid
    )
    m_valid_reg
    (
        .clock          (aclk),
        .clock_enable   (change_data),
        .resetn         (aresetn),
        .data_in        (m_valid_next),
        .data_out       (M_AXIS_tvalid)
    );

    register
    #(
        .WORD_WIDTH     (STATE_WIDTH),
        .RESET_VALUE    (3'd7)         // Initial state
    )
    state_out
    (
        .clock          (aclk),
        .clock_enable   (change_data),
        .resetn         (aresetn),
        .data_in        (state),
        .data_out       (state_data_out)
    );
    

    /*
    DATA REGISTERS

    * There are 10 (= CONV_UNITS + (KERNEL_H_MAX-1)) data registers
    * First CONV_UNITS (=8) are connected to m_data
    * selected_data[-1] is only from d_in[-1]
    * all other selected_data[i] are muxed between data[i+1] and d_in[i]

    */


    wire    [DATA_WIDTH-1:0]    slice_m_data    [CONV_UNITS + (KERNEL_H_MAX-1)-1:0];
    wire    [DATA_WIDTH-1:0]    selected_data   [CONV_UNITS + (KERNEL_H_MAX-1)-1:0];
    wire    [DATA_WIDTH-1:0]    data_out        [CONV_UNITS + (KERNEL_H_MAX-1)-1:0];
    wire    [DATA_WIDTH-1:0]    m_data          [CONV_UNITS  -1:0];

    assign shift = remove;
    wire resetn_data;
    assign reset_data = !aresetn || (state==3'd7 && remove);

    genvar i;
    generate

        // 10 slice_m_data mapped
        for (i=0; i < CONV_UNITS  + (KERNEL_H_MAX-1); i=i+1) begin: s_data_gen
            assign slice_m_data[i] = slice_M_AXIS_tdata[(i+1)*DATA_WIDTH-1: i*DATA_WIDTH];
        end
        
        // First 8 data_out registers (of 10) connected to m_data
        for (i=0; i < CONV_UNITS; i=i+1) begin: m_data_gen
            assign M_AXIS_tdata[(i+1)*DATA_WIDTH-1: i*DATA_WIDTH] = data_out[i];
        end

        // selected_data[9](1)     is from  slice_m_data[9](1)
        // selected_data[0..8](9) are muxed between data_out[1..9](9) and slice_m_data[0..8](9)
        assign selected_data[CONV_UNITS + (KERNEL_H_MAX-1)-1] = slice_m_data[CONV_UNITS + (KERNEL_H_MAX-1)-1];

        for (i=0; i < CONV_UNITS  + (KERNEL_H_MAX-1)-1; i=i+1) begin: selected_data_gen
            assign selected_data[i] = (state == 0) ? slice_m_data[i] : data_out[i+1];
        end

        // 10 data_out registers
        for (i=0; i < CONV_UNITS  + (KERNEL_H_MAX-1); i=i+1) begin: data_out_reg_gen
            register
            #(
                .WORD_WIDTH     (DATA_WIDTH),
                .RESET_VALUE    (15360)
            )
            m_data_reg
            (
                .clock          (aclk),
                .clock_enable   (change_data),
                .resetn         (!reset_data),
                .data_in        (selected_data[i]),
                .data_out       (data_out[i])
            );
        end

    endgenerate

    /*
    * Register im_channels_1 for performance (and why not?)
    * clken
        - slave side handshake
        - im_channels_1 is tied to the S_AXIS_tdata beats
    */

    wire [CH_IN_COUNTER_WIDTH -1 : 0]   im_channels_1_reg_out;
    wire                                im_channels_1_reg_clken;

    assign im_channels_1_reg_clken = S_AXIS_tready && S_AXIS_tvalid;

    register
    #(
        .WORD_WIDTH     (CH_IN_COUNTER_WIDTH),
        .RESET_VALUE    (1'b0)
    )
    im_channels_1_reg
    (
        .clock          (aclk),
        .clock_enable   (im_channels_1_reg_clken),
        .resetn         (aresetn),
        .data_in        (im_channels_in_1),
        .data_out       (im_channels_1_reg_out)
    );

    /*
    Counter

    * Starts at 0, counts upto (=) IM_CH_IN_1 and resets to zero
    * clken:
        - remove & (particular state) rises for one clock only for an input data beat. Hence "counting"
        - (state = 0) ensures count_out stays tied to d_out in all (0,1,2..) shifts of same input data beat
        - count_out points to the ch_in of the data available at M_AXIS_tdata at this clock
    */

    wire [CH_IN_COUNTER_WIDTH-1 : 0] count;
    reg  [CH_IN_COUNTER_WIDTH-1 : 0] count_next;
    wire                             counter_clken;

    assign counter_clken = remove && (state == 0);

    always @(*)begin
        case(count)
            im_channels_1_reg_out : count_next <= 0;
            default               : count_next <= count + 1;
        endcase
    end

    register
    #(
        .WORD_WIDTH     (CH_IN_COUNTER_WIDTH),
        .RESET_VALUE    (0) 
    )
    ch_in_counter_reg
    (
        .clock          (aclk),
        .clock_enable   (counter_clken),
        .resetn         (aresetn),
        .data_in        (count_next),
        .data_out       (count)
    );

    /*
    TLAST GENERATON ---------------------------------------------------------------------

    * For every IM_CH_IN groups of input data beats, passes a single tlast bit at the
      last shifted data beat (every IM_CH_IN * KERNEL_H_MAX beats).
    * IM_CH_IN is not given, but (IM_CH_IN_1 = IM_CH_IN-1) is given.

    */

    register
    #(
        .WORD_WIDTH     (CH_IN_COUNTER_WIDTH),
        .RESET_VALUE    (0) 
    )
    tlast_reg
    (
        .clock          (aclk),
        .clock_enable   (remove),
        .resetn         (aresetn),
        .data_in        (tlast_in),
        .data_out       (M_AXIS_tlast)
    );



endmodule