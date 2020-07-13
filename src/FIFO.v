`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: FIFO
// Module Name: FIFO.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: FIFO module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module FIFO(
    clk,
    rstn,
    din,
    we,
    re,
    l_rdy,

    r_valid,
    almost_empty,
    last_data,
    dout
    );
    
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter IN_WIDTH      = 16;
    parameter DEPTH         = 4; 
    parameter COUNTER_WIDTH = 2; // $clog2(DEPTH)

    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    input                clk;
    input                rstn;
    input [IN_WIDTH-1:0] din;
    input                we;
    input                re;

    output                l_rdy;
    output [IN_WIDTH-1:0] dout;
    output                r_valid;
    output                almost_empty;
    output                last_data;

    ///////////////////////////////////// Wires and Registers ////////////////////////////////////////////
    reg [IN_WIDTH-1:0] SHIFT_REGS [0:DEPTH-1]; 
    
    ///////////////////////////////////////// Counters ////////////////////////////////////////////
    localparam nW_nR = 2'd0;
    localparam nW_R  = 2'd1;
    localparam W_nR  = 2'd2;
    localparam W_R   = 2'd3;

    ///////////////////////////////////////// Assignments ////////////////////////////////////////////
    reg [COUNTER_WIDTH-1:0] read_pointer  = 0;
    reg [COUNTER_WIDTH-1:0] write_pointer = 0;
    reg [COUNTER_WIDTH:0]   num_items     = 0;

    wire empty;
    wire enabled;
    wire full;
    wire [1:0] STATE;

    assign dout         = SHIFT_REGS[read_pointer];
    assign r_valid      = !empty;
    assign l_rdy        = !full;
    assign full         = (num_items == DEPTH);
    assign empty        = (num_items == 0);
    assign almost_empty = (num_items == 1);
    assign last_data    = (num_items == 1) & ({we,re} == nW_R );
    assign STATE        = enabled ? {we,re} : nW_nR;
    assign enabled      = !((empty & re)|(full & !re & we));

    

    integer k;

    always @(posedge clk ,negedge rstn) begin
        if (~rstn) begin
            read_pointer  <= 0;
            write_pointer <= 0;
            num_items     <= 0;
            for (k = (DEPTH-1); k >=0 ; k = k-1) begin
                SHIFT_REGS[k] <= 0;
            end
        end else begin
            // if (we & !full) begin
            //     SHIFT_REGS[write_pointer] <= din;
            // end else begin
            //     SHIFT_REGS[write_pointer] <= SHIFT_REGS[write_pointer];
            // end
            
        
            case (STATE)
                nW_nR:
                    begin
                        read_pointer  <= read_pointer ;
                        write_pointer <= write_pointer;
                        num_items     <= num_items;
                    end 
                nW_R : 
                    begin
                        read_pointer  <= read_pointer + 1;
                        write_pointer <= write_pointer;
                        num_items     <= num_items - 1;
                    end 
                W_nR : 
                    begin
                        read_pointer  <= read_pointer ;
                        write_pointer <= write_pointer + 1;
                        num_items     <= num_items + 1;
                        SHIFT_REGS[write_pointer] <= din;
                    end 
                W_R  : 
                    begin
                        read_pointer  <= read_pointer  + 1;
                        write_pointer <= write_pointer + 1;   
                        num_items     <= num_items;    
                        SHIFT_REGS[write_pointer] <= din;          
                    end 
                default: 
                    begin
                        read_pointer  <= read_pointer ;
                        write_pointer <= write_pointer;   
                        num_items     <= num_items;             
                    end 
            endcase  

                      
        end
    end

endmodule