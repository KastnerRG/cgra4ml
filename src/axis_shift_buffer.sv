module axis_shift_buffer#(
    parameter DATA_WIDTH            = 16,
    parameter CONV_UNITS            = 8,
    parameter DEPTH                 = 3,
    parameter STATE_WIDTH           = $clog2(DEPTH),
    parameter CH_IN_COUNTER_WIDTH   = 10
)(
    aclk,
    aresetn,

    im_channels_in_1,

    S_AXIS_tdata,
    S_AXIS_tvalid,
    S_AXIS_tready,
    S_AXIS_tlast,

    M_AXIS_tdata,
    M_AXIS_tvalid,
    M_AXIS_tready,
    M_AXIS_tlast
);

    input   wire    aclk;
    input   wire    aresetn;
    input   wire    [CH_IN_COUNTER_WIDTH    -1       : 0]   im_channels_in_1;
    input   wire    [DATA_WIDTH * (CONV_UNITS+2) - 1 : 0]   S_AXIS_tdata;
    input   wire                                            S_AXIS_tvalid;
    output  wire                                            S_AXIS_tready;
    input   wire                                            S_AXIS_tlast;
    output  wire    [DATA_WIDTH * (CONV_UNITS) - 1 : 0]     M_AXIS_tdata;
    output  wire                                            M_AXIS_tvalid;
    input   wire                                            M_AXIS_tready;
    output  wire                                            M_AXIS_tlast;

    // HANDSHAKES

    wire insert;
    wire remove;

    assign insert = S_AXIS_tvalid && S_AXIS_tready;
    assign remove = M_AXIS_tvalid && M_AXIS_tready;

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

    wire [STATE_WIDTH-1:0]  state;
    reg  [STATE_WIDTH-1:0]  state_next;
    wire update_state;
    
    assign update_state = insert || remove;

    always @ (*) begin
        case(state)
            0        : state_next <= insert;
            DEPTH -1 : state_next <= 0;
            default  : state_next <= state + remove;
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

    // INPUT READY

    wire    s_ready_next;
    assign  s_ready_next = (state_next == 0) && M_AXIS_tready;

    register
    #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (1'b1)         // Initially ready
    )
    s_ready_reg
    (
        .clock          (aclk),
        .clock_enable   (1'b1),
        .resetn         (aresetn),
        .data_in        (s_ready_next),
        .data_out       (S_AXIS_tready)
    );

    // OUTPUT VALID
    wire    m_valid_next;
    assign  m_valid_next = (state == 0) ? S_AXIS_tvalid : M_AXIS_tvalid;

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

    // TLAST_IN
    // copied at insert
    wire    s_tlast_reg_out;
    wire    s_tlast_clken;
    assign  s_tlast_clken = insert;

    register
    #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (1'b0)         // Initially not last
    )
    s_tlast_reg
    (
        .clock          (aclk),
        .clock_enable   (s_tlast_clken),
        .resetn         (aresetn),
        .data_in        (S_AXIS_tlast),
        .data_out       (s_tlast_reg_out)
    ); 

    // TLAST_IN
    // s_tlast_reg_out is copied at state_next = last
    wire    m_tlast;
    
    wire    m_tlast_din;
    assign  m_tlast_din     = (state==0) ? 0 : s_tlast_reg_out; // turn off if state=0
    
    wire    m_tlast_clken;
    assign  m_tlast_clken   = ((state==DEPTH-1) || (state==0)) && remove ; // Assign only if state is first or last

    register
    #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (1'b0)         // Initially not last
    )
    m_tlast_reg
    (
        .clock          (aclk),
        .clock_enable   (m_tlast_clken),
        .resetn         (aresetn),
        .data_in        (m_tlast_din),
        .data_out       (M_AXIS_tlast)
    ); 
    

    /*
    DATA REGISTERS

    * There are 10 (=8+2) data registers
    * First 8 are connected to m_data
    * selected_data[-1] is only from d_in[-1]
    * all other selected_data[i] are muxed between data[i+1] and d_in[i]

    */


    wire    [DATA_WIDTH-1:0]    s_data          [CONV_UNITS+2-1:0];
    wire    [DATA_WIDTH-1:0]    selected_data   [CONV_UNITS+2-1:0];
    wire    [DATA_WIDTH-1:0]    data_out        [CONV_UNITS+2-1:0];
    wire    [DATA_WIDTH-1:0]    m_data          [CONV_UNITS  -1:0];

    wire shift;
    assign shift = insert || remove;

    genvar i;
    generate

        // 10 s_data mapped
        for (i=0; i < CONV_UNITS +2; i=i+1) begin: s_data_gen
            assign s_data[i] = S_AXIS_tdata[(i+1)*DATA_WIDTH-1: i*DATA_WIDTH];
        end
        
        // First 8 data_out registers (of 10) connected to m_data
        for (i=0; i < CONV_UNITS; i=i+1) begin: m_data_gen
            assign M_AXIS_tdata[(i+1)*DATA_WIDTH-1: i*DATA_WIDTH] = data_out[i];
        end

        // selected_data[9](1)     is from  s_data[9](1)
        // selected_data[0..8](9) are muxed between data_out[1..9](9) and s_data[0..8](9)
        assign selected_data[CONV_UNITS+2-1] = s_data[CONV_UNITS+2-1];

        for (i=0; i < CONV_UNITS +2-1; i=i+1) begin: selected_data_gen
            assign selected_data[i] = (state == 0) ? s_data[i] : data_out[i+1];
        end

        // 10 data_out registers
        for (i=0; i < CONV_UNITS +2; i=i+1) begin: data_out_reg_gen
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


endmodule