`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: Maxpool Controller
// Module Name: controller_maxpool.v
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

module controller_maxpool(
    clk,
    rstn,
    r_rdy,
    l_valid, // directly from data pipe
    T_last_in,
    mode, // 0: not maxpooling; 1: maxpooling

    comp_en,
    S_buff_en,
    G_en,
    sel,
    r_valid,
    l_rdy,
    T_last_out
    );
    
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DATA_WIDTH  = 16;
    parameter CONV_UNITS  = 8;     // Convolution units in a core

    // localparam OUT_SIZE = CONV_UNITS/2;
    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    input clk;
    input rstn;
    input r_rdy;
    input l_valid;
    input mode; // 0 : no maxpool ; 1 : maxpool
    input T_last_in;
    
    output           comp_en;
    output           S_buff_en;
    output           G_en;
    output [1:0]     sel;           // for 4 mux controlling
    output reg       r_valid = 0;
    output           l_rdy;
    output reg       T_last_out = 0;
    
    

    ///////////////////////////////////////////// STATES //////////////////////////////////////////

    localparam IDLE         = 2'd0;
    localparam MAX_POOL     = 2'd1;
    localparam NOT_MAX_POOL = 2'd2;
    localparam FINISH       = 2'd3;

    reg [1:0]  MAX_STATE    = IDLE;
    



    ////////////////////////////////////// Wires and registers /////////////////////////////////////////

    wire counter_en;
    // wire T_last_out_temp;
    wire right_en;
    wire left_en;
    wire r_valid_temp;
    wire valid_buff_en;


    /////////////////////////////////////////// Counters //////////////////////////////////////////////
    reg [31:0] COUNTER = 0;
    reg        PHASE   = 0;

    ///////////////////////////////////////// Assignments ////////////////////////////////////////////

    // assign left_en    = r_rdy & l_valid;
    // assign right_en   = r_valid & r_rdy;
    // assign counter_en = left_en & mode_reg;// & right_en & mode_reg; // seems correct
    // assign T_last_out = mode_reg ? T_last_out_temp : T_last_in ;    ------------------------
    // assign l_rdy      = mode_reg ?  : r_rdy ; //   -------------------
    // assign r_valid    = mode_reg ? (r_valid_temp & counter_en) : l_valid ;//-------------------------
    // assign sel        = (COUNTER[0]) ? 2'd3 
    //                    :(PHASE ? 2'd2 : 2'd1 );
    // assign sel       = {(COUNTER[0] & mode_reg) , ( !COUNTER[0] & PHASE & mode_reg)}; // seems correct  maybe fuse mode_reg with counter_en
    // assign sel       = {COUNTER[0], (!COUNTER[0] & PHASE)}; // seems correct  when mode is 0, then 

    // assign G_en      = right_en & left_en;
    // assign S_buff_en = counter_en & (!COUNTER[0]);  // seems correct
    // assign r_valid_temp_in = mode_reg ? PHASE & !COUNTER[0] : l_valid ;


    // assign sel       = {(COUNTER[0] & mode_reg) , ( !COUNTER[0] & PHASE & mode_reg)}; // seems correct  maybe fuse mode_reg with counter_en
    // assign left_en    = l_valid;//r_rdy & l_valid;
    // assign counter_en = left_en;// & right_en & mode_reg; // seems correct
    // assign G_en       = left_en;
    // assign S_buff_en  = mode_reg & counter_en & (!COUNTER[0]);  // seems correct


    assign S_buff_en  = !COUNTER[0] & (MAX_STATE == MAX_POOL) & counter_en; 
    assign sel        = { (!MAX_STATE[1] & MAX_STATE[0] & COUNTER[0]) , (!MAX_STATE[1] & MAX_STATE[0] & PHASE & !COUNTER[0])};
    assign comp_en    = !MAX_STATE[1] & counter_en;
    assign G_en       = counter_en;
    assign counter_en = left_en ;
    assign left_en    = l_valid & l_rdy; 
    assign l_rdy      = !(r_valid & !r_rdy);
    // assign right_en   = ;
    assign r_valid_temp = counter_en & ( (!MAX_STATE[1] & !MAX_STATE[0] & !mode) | (!MAX_STATE[1] & MAX_STATE[0] & COUNTER[0] & PHASE) | (MAX_STATE[1] & !MAX_STATE[0]) );
    assign valid_buff_en = (r_rdy & r_valid) | counter_en;
    // assign r_valid_not_max = (MAX_STATE == NOT_MAX_POOL) & counter_en;
    //----------------------------------------------------------------------------------------------------
    ///////////////////////////////////////////// Instantiation //////////////////////////////////////////
    // reg_buffer #(
    //     .DELAY(1)
    // )T_last_buffer(
    //     .clk(clk),
    //     .rstn(rstn),
    //     .d_in(T_last_in),
    //     .en(valid_buff_en),

    //     .d_out(T_last_out)
    // );

    // reg_buffer #(
    //     .DELAY(1) //-- use a good delay
    // )r_valid_buffer(
    //     .clk(clk),
    //     .rstn(rstn),
    //     .d_in(r_valid_temp),
    //     .en(valid_buff_en),

    //     .d_out(r_valid)
    // );

    // Valid buffer
    always @(posedge clk ,negedge rstn)
    begin
        if (~rstn) begin
            T_last_out <= 0;
            r_valid    <= 0;
        end else begin
            if (valid_buff_en) begin
                T_last_out <= T_last_in;
                r_valid    <= r_valid_temp;
            end else begin
                T_last_out <= T_last_out;
                r_valid    <= r_valid;
            end
        end    
    end

    // reg_array_buffer #(
    //     .DATA_WIDTH(2),
    //     .DELAY(2)
    // )shft_buffer(
    //     .clk(clk),
    //     .rstn(rstn),
    //     .d_in(copy_amount_in),
    //     .en(MA_en),
    //     .d_out(copy_amount_out)
    // );
    ///////////////////////////////////////////// Code //////////////////////////////////////////



    // Maxpool state machine
    always @(posedge clk ,negedge rstn) 
    begin
        if (~rstn) begin
            // reset logic
            MAX_STATE <= IDLE;
            COUNTER   <= 0;
            PHASE     <= 0;
        end else begin
            case (MAX_STATE)
                IDLE:
                    begin
                        if (counter_en) begin
                            PHASE     <= 0;
                            if (mode) begin
                                MAX_STATE <= MAX_POOL;
                                COUNTER   <= COUNTER + 1;
                            end else begin
                                MAX_STATE <= NOT_MAX_POOL;
                                COUNTER   <= 0;
                            end
                        end else begin
                            COUNTER <= 0;
                            PHASE   <= 0;
                        end 
                    end 
                MAX_POOL:
                    begin
                        if (counter_en) begin
                            if(COUNTER < (CONV_UNITS - 1)) begin
                                COUNTER <= COUNTER + 1; 
                                PHASE   <= PHASE;
                            end else begin
                                COUNTER <= 0;    
                                if (T_last_in) begin
                                    MAX_STATE <= IDLE;
                                    PHASE     <= 0;
                                end else begin
                                    MAX_STATE <= MAX_STATE;
                                    PHASE     <= PHASE +1 ;
                                end
                            end                    
                        end else begin
                            COUNTER <= COUNTER;
                            PHASE   <= PHASE;        
                        end
                    end 
                NOT_MAX_POOL:
                    begin
                        PHASE   <= 0;
                        COUNTER <= 0;
                        if (counter_en & T_last_in) begin
                            MAX_STATE <= IDLE;
                        end else begin
                            MAX_STATE <= MAX_STATE;
                        end
                    end 
                // FINISH :
                //     begin
                        
                //     end 
                default: 
                    begin
                        MAX_STATE <= IDLE;
                        COUNTER   <= 0;
                        PHASE     <= 0;
                    end
            endcase
        end    
    end

    




endmodule