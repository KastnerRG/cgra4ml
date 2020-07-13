`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 07/12/2019 07:26:45 PM
// Design Name: Convolution core wrapper test bench
// Module Name: conv_core_wrapper_tb
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: Test bench for AXI stream module (convolution block + controller) with real data
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module conv_core_wrapper_tb();

    // Parameters
    localparam CLK_PERIOD        = 100;
    localparam DATA_WIDTH        = 16;
    localparam CONV_UNITS        = 8;


    // IO definition
    // Controller
    reg        rstn       = 1;
    reg        clk        = 0;
    reg        mode       = 0;
    reg        r_rdy      = 1;
    reg        l_valid    = 0;
    reg [31:0] ch_in      = 32'd3; 
    reg [31:0] im_width   = 32'd384;
    reg [31:0] num_blocks = 32'd32;

    // wire [1:0] sel;
    // wire [1:0] A_sel;
    // wire       T_sel;
    // wire       T_en;
    wire       r_valid;
    // wire       MA_en;
    wire       l_rdy;
    // wire       buff_en;
    wire       finished;

    // wire [(DATA_WIDTH*(CONV_UNITS+2))-1:0] x_buff_in;
    // wire [(DATA_WIDTH*(CONV_UNITS+2))-1:0] x_buff_out;
    // wire [(DATA_WIDTH*CONV_UNITS)-1:0]     x_out_d_switch;

    wire [DATA_WIDTH-1:0]     T_out;

    // wire [DATA_WIDTH-1:0]     K1;
    // wire [DATA_WIDTH-1:0]     K2;
    // wire [DATA_WIDTH-1:0]     K3;
    // wire [DATA_WIDTH-1:0]     K4;
    // wire [DATA_WIDTH-1:0]     K5;
    // wire [DATA_WIDTH-1:0]     K6;
    // wire [DATA_WIDTH-1:0]     K7;
    // wire [DATA_WIDTH-1:0]     K8;
    // wire [DATA_WIDTH-1:0]     K9;

    // wire [DATA_WIDTH-1:0]     bias;


    // wire [DATA_WIDTH-1:0] conv_out_1;
    // wire [DATA_WIDTH-1:0] conv_out_2;
    // wire [DATA_WIDTH-1:0] conv_out_3;
    // wire [DATA_WIDTH-1:0] conv_out_4;
    // wire [DATA_WIDTH-1:0] conv_out_5;
    // wire [DATA_WIDTH-1:0] conv_out_6;
    // wire [DATA_WIDTH-1:0] conv_out_7;
    // wire [DATA_WIDTH-1:0] conv_out_8;
    // wire [DATA_WIDTH-1:0] conv_out_9;
    // wire [DATA_WIDTH-1:0] conv_out_10;
    // wire [DATA_WIDTH-1:0] conv_out_11;
    // wire [DATA_WIDTH-1:0] conv_out_12;

    // wire [31:0] conv_out_1_32;
    // wire [31:0] conv_out_2_32;
    // wire [31:0] conv_out_3_32;
    // wire [31:0] conv_out_4_32;
    // wire [31:0] conv_out_5_32;
    // wire [31:0] conv_out_6_32;
    // wire [31:0] conv_out_7_32;
    // wire [31:0] conv_out_8_32;
    // wire [31:0] conv_out_9_32;
    // wire [31:0] conv_out_10_32;
    // wire [31:0] conv_out_11_32;
    // wire [31:0] conv_out_12_32;


    // kernels 3x3
    integer j,outfile0,outfile1,outfile2,outfile3,status1;

    reg [15:0] KERNEL_3x3 [0:8] ; // without bias
    reg [(16*3)-1:0] BIAS ; //  biases K1|K2|K3
    reg [(DATA_WIDTH*(CONV_UNITS+2))-1:0] X_IN;

    // Assignments
    // assign bias_in = BIAS;
    // assign w_in_t  = KERNEL_T[STATE_R+(CH_COUNT)*9]; 
    // assign w_in_m  = KERNEL_M[STATE_R+(CH_COUNT)*9]; 
    // assign w_in_b  = KERNEL_B[STATE_R+(CH_COUNT)*9]; 
    
    // assign conv_out_1 = conv_out[15:0];
    // assign conv_out_2 = conv_out[31:16];
    // assign conv_out_3 = conv_out[47:32];
    // assign conv_out_4 = conv_out[63:48];
    // assign conv_out_5 = conv_out[79:64];
    // assign conv_out_6 = conv_out[95:80];
    // assign conv_out_7 = conv_out[111:96];
    // assign conv_out_8 = conv_out[127:112];
    // assign conv_out_9 = conv_out[143:128];
    // assign conv_out_10 = conv_out[159:144];
    // assign conv_out_11 = conv_out[175:160];
    // assign conv_out_12 = conv_out[191:176];
    wire [(DATA_WIDTH*9)-1:0] kernel_wire;
    assign kernel_wire = {KERNEL_3x3[8],
                          KERNEL_3x3[7],
                          KERNEL_3x3[6],
                          KERNEL_3x3[5],
                          KERNEL_3x3[4],
                          KERNEL_3x3[3],
                          KERNEL_3x3[2],
                          KERNEL_3x3[1],
                          KERNEL_3x3[0]  };

    // DUT instantiation


    conv_core_wrapper CONV_CORE_WRAPPER_DUT(
        .rstn(rstn),
        .clk(clk),
        .mode(mode),
        .X_IN(X_IN),
        .KERNEL(kernel_wire),
        .r_rdy(r_rdy),
        .l_valid(l_valid),
        .ch_in(ch_in),
        .im_width(im_width),
        .num_blocks(num_blocks),
        .BIAS(BIAS),
        .l_rdy(l_rdy),
        .r_valid(r_valid),
        .finished(finished),
        .T_out(T_out)
    );


    // controller #(
    //     .DATA_WIDTH(DATA_WIDTH),
    //     .CONV_UNITS(CONV_UNITS)
    // )CONTROLLER_DUT(
    //     .clk(clk),
    //     .rstn(rstn),
    //     .r_rdy(r_rdy),
    //     .l_valid(l_valid),
    //     .ch_in(ch_in),
    //     .im_width(im_width),
    //     .num_blocks(num_blocks),
    //     .mode(mode),
    //     .sel(sel),
    //     .A_sel(A_sel),
    //     .T_sel(T_sel),
    //     .T_en(T_en),
    //     .r_valid(r_valid),
    //     .MA_en(MA_en),
    //     .l_rdy(l_rdy),
    //     .buff_en(buff_en),
    //     .finished(finished)
    // );

    // d_in_buffer #(
    //     .DATA_WIDTH(DATA_WIDTH),
    //     .CONV_UNITS(CONV_UNITS)
    // )D_IN_BUFF(
    //     .clk(clk),
    //     .rstn(rstn),
    //     .buff_en(buff_en),
    //     .x_in(X_IN),
    //     .x_out(x_buff_out)
    // );

    // data_switch #(
    //     .DATA_WIDTH(DATA_WIDTH),
    //     .CONV_UNITS(CONV_UNITS)
    // )DATA_SWITCH(
    //     .sel(sel),
    //     .x_in(x_buff_out),
    //     .x_out(x_out_d_switch)
    // );
    
    // conv_core #(
    //     .DATA_WIDTH(DATA_WIDTH),
    //     .TOTAL_UNITS(CONV_UNITS)
    // )CONV_CORE(
    //     .clk(clk),
    //     .rstn(rstn),
    //     .x_in(x_out_d_switch),
    //     .dv_in(1'b1),
    //     .MA_en(MA_en),
    //     .kernel_sel(sel),
    //     .A_sel(A_sel),
    //     .T_sel(T_sel),
    //     .T_en(T_en),
    //     .K1(KERNEL_3x3[0]),
    //     .K2(KERNEL_3x3[1]),
    //     .K3(KERNEL_3x3[2]),
    //     .K4(KERNEL_3x3[3]),
    //     .K5(KERNEL_3x3[4]),
    //     .K6(KERNEL_3x3[5]),
    //     .K7(KERNEL_3x3[6]),
    //     .K8(KERNEL_3x3[7]),
    //     .K9(KERNEL_3x3[8]),
    //     .bias(BIAS),
    //     .buff_en(buff_en),
    //     .T_out(T_out)
    // );



    // floating_point_2 Debug_1 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_1),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_1_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_2 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_2),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_2_32)    // output wire [31 : 0] m_axis_result_tdata
    // );
    // floating_point_2 Debug_3 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_3),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_3_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_4 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_4),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_4_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_5 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_5),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_5_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_6 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_6),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_6_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_7 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_7),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_7_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_8 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_8),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_8_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_9 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_9),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_9_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_10 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_10),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_10_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_11 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_11),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_11_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // floating_point_2 Debug_12 (
    // .s_axis_a_tvalid(1'b1),            // input wire s_axis_a_tvalid
    // .s_axis_a_tdata(conv_out_12),              // input wire [15 : 0] s_axis_a_tdata
    // // .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    // .m_axis_result_tdata(conv_out_12_32)    // output wire [31 : 0] m_axis_result_tdata
    // );

    // Main code



    always // Clock generation
    begin
        #(CLK_PERIOD/2);
        clk <= ~ clk;
    end

   


    initial
    begin
        outfile2=$fopen("../../../../../src/text/conv_out_3x3.txt","w");
        // integer j;
    end

    always@(posedge clk)
        
    begin
        if(r_valid)// (r_valid & r_rdy) // try using this to avoid writing the same value again and again
        begin
            // for (j = 0 ; j<(CONV_UNITS+2); j = j + 1) begin
                // $fdisplay(outfile6,"%d",conv_out[DATA_WIDTH*(j+1)-1:DATA_WIDTH*j]);
                $fdisplay(outfile2,"%d",T_out);
                // #1;
            // end
        end
    end

    initial
    begin
        // outfile6=$fopen("../../../../../src/text/sim_output/weight_out.txt","w");
        areset;
        @(posedge clk);
        // 3x3 convolution
        // ch_in      <= 32'd3; 
        // im_width   <= 32'd384;
        // num_blocks <= 32'd32;
        // mode <= 0;
        // feed_data_3x3;
        
        //1x1 convolution
        ch_in      <= 32'd128; 
        im_width   <= 32'd96;
        num_blocks <= 32'd8;
        mode <= 1;
        feed_data_3x3;


        @(posedge finished);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        $fclose(outfile2);
    end


    task feed_data_3x3;
        integer i;
        integer k;
        integer r;
    begin
        outfile0=$fopen("../../../../../src/text/im_feed.txt","r");   //"r" means reading and "w" means writing
        outfile1=$fopen("../../../../../src/text/kernel_feed.txt","r");
        outfile3=$fopen("../../../../../src/text/bias_feed.txt","r");
        // outfile6=$fopen("../../../../../src/text/sim_output/weight_out.txt","w");
        i = 0;
        l_valid <= 1;
        for(i = 0; i <=((CONV_UNITS+2)-1) ; i = i +1)begin //read until an "end of file" is reached.
            status1 = $fscanf(outfile0,"%d\n",X_IN[((DATA_WIDTH*(1+i))-1)-:DATA_WIDTH]);
        end

        for(i = 0; i <=8 ; i = i +1)begin //read until an "end of file" is reached.
            // status1 = $fscanf(outfile1,"%d\n",KERNEL_3x3[((DATA_WIDTH*(1+i))-1)-:DATA_WIDTH]);
            status1 = $fscanf(outfile1,"%d\n",KERNEL_3x3[i]);
        end

        for(i = 0; i <=2 ; i = i +1)begin //read until an "end of file" is reached.
            status1 = $fscanf(outfile3,"%d\n",BIAS[((DATA_WIDTH*(1+i))-1)-:DATA_WIDTH]);
        end

        while (! $feof(outfile0)) begin
            @(posedge clk);
            if (l_rdy) begin
                #(10);
                for(i = 0; i <=((CONV_UNITS+2)-1) ; i = i +1)begin //read until an "end of file" is reached.
                    status1 = $fscanf(outfile0,"%d\n",X_IN[((DATA_WIDTH*(1+i))-1)-:DATA_WIDTH]);
                end

                if ($feof(outfile1)) begin
                    $fclose(outfile1);
                    outfile1=$fopen("../../../../../src/text/kernel_feed.txt","r");
                end

                for(i = 0; i <=8 ; i = i +1)begin //read until an "end of file" is reached.
                    // status1 = $fscanf(outfile1,"%d\n",KERNEL_3x3[((DATA_WIDTH*(1+i))-1)-:DATA_WIDTH]);
                    status1 = $fscanf(outfile1,"%d\n",KERNEL_3x3[i]);
                end
            end else begin
                X_IN       <= X_IN;
                // KERNEL_3x3 <= KERNEL_3x3;
            end
        end
        @(posedge clk);
        while (!l_rdy) begin
            @(posedge clk);
            X_IN       <= X_IN;
            // KERNEL_3x3 <= KERNEL_3x3;
            l_valid    <= 1;
        end
        l_valid <= 0;
        $fclose(outfile0);
        $fclose(outfile1);
        $fclose(outfile3);
    end 
    endtask


    // task feed_data;
    //     integer i;
    //     integer k;
    // begin
    //     outfile0=$fopen("../../../../../src/text/im_feed.txt","r");   //"r" means reading and "w" means writing
    //     outfile3=$fopen("../../../../../src/text/kernel_top.txt","r");
    //     outfile4=$fopen("../../../../../src/text/kernel_mid.txt","r");
    //     outfile5=$fopen("../../../../../src/text/kernel_end.txt","r");
    //     // outfile6=$fopen("../../../../../src/text/sim_output/weight_out.txt","w");
    //     i = 0;
    //     for(i = 0; i <=26 ; i = i +1)begin //read until an "end of file" is reached.
    //         status1 = $fscanf(outfile3,"%d\n",KERNEL_T[i]);
    //         status1 = $fscanf(outfile4,"%d\n",KERNEL_M[i]);
    //         status1 = $fscanf(outfile5,"%d\n",KERNEL_B[i]);
    //     end
    //     status1 = $fscanf(outfile3,"%d\n",BIAS);
    //     $fclose(outfile3);
    //     $fclose(outfile4);
    //     $fclose(outfile5);


    //     for ( k = 0 ; k<(CONV_UNITS+4); k = k+1) begin
    //         // status1 = $fscanf(outfile0,"%d\n",x_in[(DATA_WIDTH*(k+1))-1:DATA_WIDTH*k]);
    //         status1 = $fscanf(outfile0,"%d\n",x_in[((DATA_WIDTH*(k+1))-1)-:DATA_WIDTH]);
    //     end


    //     while (! $feof(outfile0)) begin //read until an "end of file" is reached.
    //         @(posedge clk);
    //         start <= 0;
    //         // $fdisplay(outfile6,"%d",16'd65535);
    //         if(s_ready)begin
    //             if(STATE_R == 4'd8) begin
    //                 for ( k = 0 ; k<(CONV_UNITS+4); k = k+1) begin
    //                     // status1 = $fscanf(outfile0,"%d\n",x_in[(DATA_WIDTH*(k+1))-1:DATA_WIDTH*k]);
    //                     status1 = $fscanf(outfile0,"%d\n",x_in[((DATA_WIDTH*(k+1))-1)-:DATA_WIDTH]);
    //                 end
    //             end else begin
    //                 x_in <= x_in;
    //             end

    //         end else begin
    //             x_in <= x_in;
    //         end
    //     end
    //     $fclose(outfile0);
    // end 
    // endtask



    task areset;
    begin
        #(CLK_PERIOD/4);
        rstn <= 0;
        #(CLK_PERIOD*4);
        rstn <= 1;
    end
    endtask


endmodule