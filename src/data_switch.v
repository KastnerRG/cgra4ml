`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: Data switch
// Module Name: data_switch.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: Used to multiplex correct data to the inputs of the core
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module data_switch(
    sel,
    x_in,

    x_out
    );
    
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DATA_WIDTH = 16;
    parameter CONV_UNITS = 8;

    localparam IN_SIZE   = CONV_UNITS+2;

    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    input [1:0]                      sel;
    input [(DATA_WIDTH*IN_SIZE)-1:0] x_in;

    output [(DATA_WIDTH*CONV_UNITS)-1:0] x_out;
    

    ///////////////////////////////////// Wires and Register ////////////////////////////////////////////
    wire [DATA_WIDTH-1:0] x_in_array  [0:IN_SIZE-1];
    reg  [DATA_WIDTH-1:0] x_out_array [0:CONV_UNITS-1];

    //////////////////////////////////////// Instantiations ////////////////////////////////////////////
    // Connecting the output and the muxes
    genvar i;
    generate

        for (i=1; i<=CONV_UNITS; i=i+1) begin : generate_units // <-- example block name
            assign x_out[(DATA_WIDTH*i)-1:DATA_WIDTH*(i-1)] = x_out_array[i-1];

            always@(*)
            begin : muxes
                case(sel)
                    2'd0   :
                        begin
                            x_out_array[i-1] <= x_in_array[i-1];
                        end
                    2'd1   :
                        begin
                            x_out_array[i-1] <= x_in_array[i];
                        end
                    2'd2   :
                        begin
                            x_out_array[i-1] <= x_in_array[i+1];
                        end
                    2'd3   :
                        begin
                            x_out_array[i-1] <= 16'd15360; //1
                        end 
                    default:
                        begin
                            x_out_array[i-1] <= 16'd15360; //1
                        end
                endcase
            end
        end 
    endgenerate


    // Connecting the inputs
    genvar j;
    generate

        for (j=0; j<IN_SIZE; j=j+1) begin : connect_in_wires // <-- example block name
            assign x_in_array[j] = x_in[(DATA_WIDTH*(j+1))-1:DATA_WIDTH*j];
        end 
    endgenerate

endmodule