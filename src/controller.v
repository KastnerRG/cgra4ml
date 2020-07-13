`include "system_parameters.v"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: Controller
// Module Name: controller.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: Controller for manipulating the control signals of the convolution cores
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module controller(
    clk,
    rstn,
    r_rdy,
    l_valid, // directly from data pipe
    ch_in,      // give actual - 1
    im_width,   // give actual - 1
    num_blocks, // give actual - 1
    mode,

    sel,
    A_sel,
    T_sel,
    T_en,
    r_valid,
    MA_en,
    l_rdy,
    buff_en,
    bias_buff_en,
    finished,
    T_last
    );
    
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DATA_WIDTH  = 16;
    parameter CONV_UNITS  = 8;     // Convolution units in a core

    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    input        clk;
    input        rstn;
    input        r_rdy;
    input        l_valid;
    input        mode; // 0 : 3x3 conv ,  1 : 1x1 conv
    input [`CH_IN_COUNTER_WIDTH-1:0]    ch_in;
    input [`IM_WIDTH_COUNTER_WIDTH-1:0] im_width;
    input [`NUM_BLKS_COUNTER_WIDTH-1:0] num_blocks;
    
    output           l_rdy;
    output           T_sel;
    output [1:0]     A_sel;         // Adder input mux select
    output [1:0]     sel;           // for kernel and data switch
    output           T_en;
    output           MA_en;
    output           buff_en;
    output           bias_buff_en;
    output           r_valid;
    output       reg finished = 0;
    output           T_last;
    
    

    ///////////////////////////////////////////// STATES //////////////////////////////////////////
    // T state machine's
    localparam IDLE_T  = 2'd0;
    localparam SHIFT_T = 2'd1;
    localparam PAUSE_T = 2'd2;

    reg [1:0]  T_STATE = IDLE_T;


    // Conv state machine's
    localparam IDLE_CONV  = 2'd0;
    localparam CLEAR_CONV = 2'd1;
    localparam MAIN_CONV  = 2'd2;
    localparam CLEAN_CONV = 3'd3;

    localparam CONV_3x3 = 0;
    localparam CONV_1x1 = 1;

    reg [1:0]  CONV_STATE = IDLE_CONV;



    ////////////////////////////////////// Wires and registers /////////////////////////////////////////
    wire T_busy;
    wire counter_en;
    wire right_en;
    wire left_en;
    wire copy_en_in;
    wire copy_en_out;

    wire [1:0] copy_amount_in; // 2'd1 transmit only T1; 2'd2 transmit only T1,T2; 2'd3 transmit T1,T2,T3
    wire [1:0] copy_amount_out;

    reg [1:0] SHIFT_REF    = 2'd1;
    reg       LAST_T_BATCH = 0;


    /////////////////////////////////////////// Counters //////////////////////////////////////////////
    reg [1:0]                         c_INNER = 0;     // for switching kernel switch
    reg [`CH_IN_COUNTER_WIDTH-1:0]    c_CH_I  = 0;     // counting current input channel
    reg [`IM_WIDTH_COUNTER_WIDTH-1:0] c_COL   = 0;     // counting current column
    reg [`NUM_BLKS_COUNTER_WIDTH-1:0] c_BLOCK = 0;     // counting current block
    // reg [31:0] c_CH_O  = 0;     // counting current output channel

    reg [`c_SHIFT_COUNTER_WIDTH-1:0] c_SHIFT  = 0;     // counting the number of shifts performed
    reg [1:0]                       c_SHIFT_BLK = 0;     // counting the number of block shifts performed (1: shift only T1s 2: shift only T2s)

    ///////////////////////////////////////// Assignments ////////////////////////////////////////////

    /* T_en
    Whenever T_state machine is IDLE, T_en should be off.
    Whenever the c_SHIFT counter reads the last of the shift register block T_en should be off
    While in shift state, if tready goes down T_en should be off
    ____________________________________________
    |T_en |tready|STATE== SHIFT|!(STATE== SHIFT)|
    |_____|______|_____________|________________|
    |__1__|__0___|_____0_______|_______1________|
    |__1__|__1___|_____0_______|_______1________|
    |__0__|__0___|_____1_______|_______0________|
    |__1__|__1___|_____1_______|_______0________|
    */
    
    /* left_en
    Whenever lvalid is not high when tready is not high turn enable off
    _________________________________
    |left_en|lvaild |l_rdy__|!l_rdy_|
    |_______|_______|_______|_______|
    |___1___|___0___|___0___|___1___|
    |___0___|___0___|___1___|___0___|
    |___1___|___1___|___0___|___1___|
    |___1___|___1___|___1___|___0___|
    
    */


    //-------------------------------------------signals----------------------------------------------
    assign copy_en_in = mode? (c_CH_I == ch_in)  // 1x1
                       :((c_INNER == 2'd2)&(c_CH_I == ch_in)&(c_COL!= 0));       // 3x3

    assign copy_amount_in = mode?(2'd3) // Transmit all T regs
                           :(((c_INNER == 2'd2)&(c_CH_I == ch_in)&(c_COL == im_width))?2'd2:2'd1); // Transmit T1 & T2 at right edges else only T1

    assign T_sel    = copy_en_out & MA_en; // 1: copy  0: shift
    assign T_en     = ((r_rdy) & (T_STATE == SHIFT_T))|(T_sel);
    assign sel      = c_INNER;
    // assign l_rdy    = (mode)?  // 1x1
    //                  :;        // 
    assign counter_en = right_en & left_en;
    assign l_rdy    = right_en & ((CONV_STATE == CLEAR_CONV)|((mode)?(              (c_CH_I != ch_in)&(CONV_STATE == MAIN_CONV)           ):(    (c_INNER == 2'd2)&(!((c_CH_I == ch_in)&(c_COL == im_width)))    )));
    assign MA_en    = counter_en & (CONV_STATE != IDLE_CONV);
    assign A_sel    = (mode)?(((c_INNER == 2'd1) & (c_CH_I == 0))? 2'd2 // Pass 0s
                       :2'd0                                     // accumulate
                       )
                     :(({c_INNER,c_CH_I,c_COL} == 0)      ? 2'd2 // pass 0s to 1 adder input
                       :((c_INNER == 2'd1) & (c_CH_I == 0))? 2'd1 // shift and add
                       :2'd0                                     // accumulate
                       );
    assign left_en      = !((!l_valid) & l_rdy);
    assign right_en     = !(copy_en_out & T_busy);
    assign buff_en      = l_rdy & l_valid;
    assign bias_buff_en = l_valid & (CONV_STATE == IDLE_CONV);
    assign T_busy       = T_STATE > IDLE_T;
    assign r_valid      = T_STATE == SHIFT_T;
    assign T_last       = (LAST_T_BATCH & r_valid & (c_SHIFT == (CONV_UNITS-1)) & (c_SHIFT_BLK == (SHIFT_REF -1)));
    //----------------------------------------------------------------------------------------------------
    ///////////////////////////////////////////// Instantiation //////////////////////////////////////////
    reg_buffer #(
        .DELAY(2)
    )dv_buffer(
        .clk(clk),
        .rstn(rstn),// maybe use a different signal to reset ();
        .d_in(copy_en_in),
        .en(MA_en),

        .d_out(copy_en_out)
    );

    reg_array_buffer #(
        .DATA_WIDTH(2),
        .DELAY(2)
    )shft_buffer(
        .clk(clk),
        .rstn(rstn),
        .d_in(copy_amount_in),
        .en(MA_en),
        .d_out(copy_amount_out)
    );
    ///////////////////////////////////////////// Code //////////////////////////////////////////

    // T handling state machine

    always@(posedge clk, negedge rstn)
    begin
        if (~rstn) begin
            // rst logic
            T_STATE      <= IDLE_T;
            SHIFT_REF    <= 0;//d'1;
            c_SHIFT      <= 0;
            c_SHIFT_BLK  <= 0;
            LAST_T_BATCH <= 0;
        end else begin
            case (T_STATE)
                IDLE_T:
                    begin
                        LAST_T_BATCH <= 0; //added this line
                        c_SHIFT      <= 0;
                        c_SHIFT_BLK  <= 0;
                        SHIFT_REF    <= SHIFT_REF;
                        if (T_sel) begin
                            T_STATE   <= SHIFT_T;
                            SHIFT_REF <= copy_amount_out; // noting the amount of T registers to transmit
                        end else begin
                            T_STATE <= IDLE_T;
                        end
                    end
                SHIFT_T:
                    begin
                        SHIFT_REF   <= SHIFT_REF;
                        if(finished) begin
                            LAST_T_BATCH <= 1;
                        end else begin
                            LAST_T_BATCH <= LAST_T_BATCH;
                        end
                        
                        if (r_rdy) begin
                            if (c_SHIFT == (CONV_UNITS-1)) begin  // Check whether single T set is transmitted
                                c_SHIFT     <= 0;
                                c_SHIFT_BLK <= c_SHIFT_BLK + 1; 
                                if (c_SHIFT_BLK == (SHIFT_REF -1)) begin  // Check whether required sets of T is transmitted
                                    T_STATE <= IDLE_T;
                                end else begin                            // More T sets needs to be transmitted
                                    T_STATE <= PAUSE_T;
                                end
                            end else begin
                                T_STATE     <= SHIFT_T;
                                c_SHIFT     <= c_SHIFT + 1;
                                c_SHIFT_BLK <= c_SHIFT_BLK;    
                            end
                        end else begin
                            T_STATE     <= SHIFT_T;
                            c_SHIFT     <= c_SHIFT;
                            c_SHIFT_BLK <= c_SHIFT_BLK;
                        end
                    end
                PAUSE_T:
                    begin
                        c_SHIFT      <= 0;
                        c_SHIFT_BLK  <= c_SHIFT_BLK;
                        SHIFT_REF    <= SHIFT_REF;
                        LAST_T_BATCH <= LAST_T_BATCH;
                        if (r_rdy) begin
                            T_STATE     <= SHIFT_T;
                        end else begin
                            T_STATE     <= PAUSE_T;  
                        end
                    end
                    
                default:
                    begin
                        T_STATE      <= IDLE_T;
                        SHIFT_REF    <= 0;//d'1;
                        c_SHIFT      <= 0;
                        c_SHIFT_BLK  <= 0;
                        LAST_T_BATCH <= 0;
                    end 
            endcase
        end
    end

//-------------------------------------new------------------------------------

// Convolution state machine
    always @(posedge clk, negedge rstn)
    begin
        if (~rstn) begin
            // reset logic
            finished   <= 0;
            c_CH_I     <= 0;
            c_INNER    <= 2'd3; // consider different option for c_INNER
            c_COL      <= 0;
            c_BLOCK    <= 0;
            CONV_STATE <= IDLE_CONV;
        end else begin
            
            case (CONV_STATE)
                IDLE_CONV:
                    begin
                        c_CH_I     <= 0;
                        c_INNER    <= 2'd3; // clear signal for conv_unit
                        c_COL      <= 0;
                        c_BLOCK    <= 0;
                        finished   <= 0;
                        if (l_valid) begin  // start with data valid of the input data pipe in
                            CONV_STATE <= CLEAR_CONV;
                        end else begin
                            CONV_STATE <= IDLE_CONV;
                        end
                        
                    end
                CLEAR_CONV:
                    begin
                        c_COL      <= c_COL;
                        c_BLOCK    <= c_BLOCK;
                        finished   <= 0;
                        if (counter_en) begin
                            c_CH_I     <= 0;
                            CONV_STATE <= MAIN_CONV;
                            if (!mode) begin //3x3
                                c_INNER    <= 0;
                            end else begin //1x1
                                c_INNER    <= 2'd1;
                            end
                        end else begin
                            c_CH_I     <= c_CH_I;
                            c_INNER    <= c_INNER;
                            CONV_STATE <= CONV_STATE;
                        end
                    end
                MAIN_CONV:
                    begin
                        finished   <= 0;
                        if(counter_en) begin// Not stalled
                            case (mode)
                                CONV_3x3:
                                    begin
                                        if (c_INNER == 2'd2) begin  // one channel done
                                            
                                            if (c_CH_I == (ch_in)) begin  // all channels done
                                                c_CH_I     <= 0;
                                                if (c_COL == (im_width)) begin  // columns done
                                                    c_COL      <= 0;
                                                    c_INNER    <= 2'd3;
                                                    if (c_BLOCK == (num_blocks)) begin  // all blocks done
                                                        // finished image
                                                        c_BLOCK    <= 0;
                                                        CONV_STATE <= CLEAN_CONV;
                                                    end else begin  // go to next block
                                                        c_BLOCK    <= c_BLOCK + 1;
                                                        CONV_STATE <= CLEAR_CONV;
                                                    end
                                                end else begin   // go to next column
                                                    c_INNER    <= 0;
                                                    c_COL      <= c_COL + 1;
                                                    c_BLOCK    <= c_BLOCK;
                                                    CONV_STATE <= MAIN_CONV;
                                                end
                                            end else begin              // go to next channel
                                                c_INNER    <= 0;
                                                c_CH_I     <= c_CH_I + 1;
                                                c_COL      <= c_COL;
                                                c_BLOCK    <= c_BLOCK;
                                                CONV_STATE <= MAIN_CONV;
                                            end
                                            
                                        end else begin    // process across kernel
                                            c_INNER    <= c_INNER + 1;
                                            c_CH_I     <= c_CH_I;
                                            c_COL      <= c_COL;
                                            c_BLOCK    <= c_BLOCK;
                                            CONV_STATE <= MAIN_CONV;
                                        end
                                    end
                                CONV_1x1:
                                    begin
                                        if (c_CH_I == (ch_in)) begin  // all channels done
                                            c_CH_I     <= 0;
                                            c_INNER    <= 2'd3;
                                            if (c_COL == (im_width)) begin  // columns done
                                                c_COL      <= 0;
                                                if (c_BLOCK == (num_blocks)) begin  // all blocks done
                                                    // finished image
                                                    c_BLOCK    <= 0;
                                                    CONV_STATE <= CLEAN_CONV;
                                                end else begin  // go to next block
                                                    c_BLOCK    <= c_BLOCK + 1;
                                                    CONV_STATE <= CLEAR_CONV;
                                                end
                                            end else begin   // go to next column
                                                c_COL      <= c_COL + 1;
                                                c_BLOCK    <= c_BLOCK;
                                                CONV_STATE <= CLEAR_CONV;
                                            end
                                        end else begin              // go to next channel
                                            c_INNER    <= 2'd1; // choose the middle route
                                            c_CH_I     <= c_CH_I + 1;
                                            c_COL      <= c_COL;
                                            c_BLOCK    <= c_BLOCK;
                                            CONV_STATE <= MAIN_CONV;
                                        end
                                        
                                    end 
                                default:
                                    begin
                                        CONV_STATE <= MAIN_CONV;
                                    end 
                            endcase

                            
                        end else begin   // Stalled
                            c_CH_I     <= c_CH_I;
                            c_INNER    <= c_INNER;
                            c_COL      <= c_COL;
                            c_BLOCK    <= c_BLOCK;
                            CONV_STATE <= CONV_STATE;
                        end
                    end
                CLEAN_CONV: // To complete the adder calculation
                    begin
                        if (T_sel) begin
                            finished   <= 1; 
                            c_INNER    <= 2'd3;
                            c_CH_I     <= 0;
                            c_COL      <= 0;
                            c_BLOCK    <= 0;
                            CONV_STATE <= IDLE_CONV;
                        end else begin
                            finished   <= 0; 
                            c_CH_I     <= c_CH_I;
                            c_INNER    <= c_INNER;
                            c_COL      <= c_COL;
                            c_BLOCK    <= c_BLOCK;
                            CONV_STATE <= CONV_STATE;
                        end
                    end
                default:
                    begin
                        c_CH_I     <= 0;
                        c_INNER    <= 2'd3;
                        c_COL      <= 0;
                        c_BLOCK    <= 0;
                        finished   <= 0;
                        CONV_STATE <= IDLE_CONV;
                    end 
            endcase            
        end
    end



endmodule