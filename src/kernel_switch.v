`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 18/09/2019 10:59:45 AM
// Design Name: Kernel switch
// Module Name: kernel_switch.v
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: Used once in each core to feed kernel values for the conv units
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module kernel_switch(
    sel,
    K1,
    K2,
    K3,
    K4,
    K5,
    K6,
    K7,
    K8,
    K9,
    bias,

    L_kernel,
    M_kernel,
    R_kernel
    
    );
    
    ////////////////////////////////////////// Parameters ////////////////////////////////////////////
    parameter DATA_WIDTH = 16;

    ////////////////////////////////////// Port declaration ////////////////////////////////////////////
    input [1:0]            sel;
    input [DATA_WIDTH-1:0] K1;
    input [DATA_WIDTH-1:0] K2;
    input [DATA_WIDTH-1:0] K3;
    input [DATA_WIDTH-1:0] K4;
    input [DATA_WIDTH-1:0] K5;
    input [DATA_WIDTH-1:0] K6;
    input [DATA_WIDTH-1:0] K7;
    input [DATA_WIDTH-1:0] K8;
    input [DATA_WIDTH-1:0] K9;
    input [(DATA_WIDTH*3)-1:0] bias;  // bias for  K3:K2:K1 order
    

    output reg [DATA_WIDTH-1:0] L_kernel;
    output reg [DATA_WIDTH-1:0] M_kernel;
    output reg [DATA_WIDTH-1:0] R_kernel;

    ///////////////////////////////////////// Assignments ////////////////////////////////////////////
    always@(*)
    begin
        case(sel)
            2'd0    :
                begin
                    L_kernel <= K1;
                    M_kernel <= K2;
                    R_kernel <= K3;
                end 
            2'd1    :
                begin
                    L_kernel <= K4;
                    M_kernel <= K5;
                    R_kernel <= K6;
                end 
            2'd2    :
                begin
                    L_kernel <= K7;
                    M_kernel <= K8;
                    R_kernel <= K9;
                end
            2'd3    :
                begin
                    L_kernel <= bias[15:0];  // bias for K1
                    M_kernel <= bias[31:16]; // bias for K2
                    R_kernel <= bias[47:32]; // bias for K3
                end  
            default : 
                begin
                    L_kernel <= K1;
                    M_kernel <= K2;
                    R_kernel <= K3;
                end 
        endcase
    end

endmodule