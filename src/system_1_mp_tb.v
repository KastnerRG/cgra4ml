`include "system_parameters.v"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 01/02/2020 07:26:45 PM
// Design Name: system_1_mp_tb
// Module Name: system_1_mp_tb
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: Test bench for partial system (convolution block + Data width converter + weight rotator) with real data
//              Use only for max pool case.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module system_1_mp_tb();

    // Parameters
    localparam CLK_PERIOD             = 100;

    // localparam IO_WIDTH   = (CONV_CORES *3 * DATA_WIDTH);
    localparam ch_in      = 4;
    localparam k_size     = 3;
    localparam im_width   = 384;
    localparam im_height  = 256;
    localparam num_blocks = im_height/`CONV_UNITS;

    localparam max_pool     = 1;
    localparam not_max_pool = 0;
    localparam conv_3x3     = 0;
    localparam conv_1x1     = 1;


    // IO definition
    reg clk  = 0;
    reg rstn = 1;
    reg data_l_valid = 0;

    // Weight rotator
    reg [(`CONV_CORES * 3 * `DATA_WIDTH)-1:0] WR_din            = 0;
    reg                                       WR_l_valid        = 0;
    reg [`ADDRS_WIDTH-1:0]                    WR_write_depth    = (k_size * ch_in) + 1 -1; // K_size * CH_in +1{for bias line}  (give this as 0 indexed. eg 3* 10 + 1 => 30 not 31) | give actual write_depth -1
    reg [`ROTATE_WIDTH-1:0]                   WR_rotate_amount  = (im_width * num_blocks)-1;
    reg [`CH_IN_COUNTER_WIDTH-1:0]            WR_im_channels_in = ch_in-1;
    reg [`IM_WIDTH_COUNTER_WIDTH-1:0]         WR_im_width_in    = im_width-1;
    reg [`NUM_BLKS_COUNTER_WIDTH-1:0]         WR_im_blocks_in   = num_blocks-1;
    reg                                       WR_conv_mode_in   = conv_3x3;
    reg                                       WR_max_mode_in    = max_pool;

    wire                                       WR_l_rdy;
    wire                                       WR_r_valid;
    wire                                       WR_conv_mode_out;
    wire                                       WR_max_mode_out;
    wire [(`CONV_CORES * 3 * `DATA_WIDTH)-1:0] WR_BIAS_out;
    wire [`CH_IN_COUNTER_WIDTH-1:0]            WR_im_channels_out;
    wire [`IM_WIDTH_COUNTER_WIDTH-1:0]         WR_im_width_out;
    wire [`NUM_BLKS_COUNTER_WIDTH-1:0]         WR_im_blocks_out;
    wire [(`CONV_CORES * 3 * `DATA_WIDTH)-1:0] WR_dout;


    // Data width converter NMP

    wire                                     DWC_l_rdy;
    wire                                     DWC_r_valid;
    wire [(`CONV_CORES*`DATA_WIDTH*9/2)-1:0] DWC_MP_dout;
    wire [(`CONV_CORES*`DATA_WIDTH*9)-1:0]   DWC_MP_mapped_dout;

    // Conv block
    reg [(`DATA_WIDTH*(`CONV_UNITS+2))-1:0] X_IN_type_1 = 0;
    reg [(`DATA_WIDTH*(`CONV_UNITS+2))-1:0] X_IN_type_2 = 0;
    

    wire [(`DATA_WIDTH * `CONV_CORES)-1:0] CONV_T_out;
    wire                                   CONV_l_valid;
    wire                                   CONV_mod_l_rdy;
    wire                                   CONV_l_rdy;
    wire                                   CONV_r_valid;
    wire                                   CONV_finished;
    wire                                   CONV_max_mode_out;
    wire                                   CONV_T_last;

    // Max pool block
    reg                                    MAX_r_rdy = 1;

    wire                                   MAX_r_valid;
    wire                                   MAX_l_rdy;
    wire                                   MAX_T_last_out;
    wire [(`DATA_WIDTH * `CONV_CORES)-1:0] MAX_T_out;

    ////////////////////////////////



    reg [31:0] counter  = 32'd0;
    reg [31:0] counter2 = 32'd0;
    reg        toggle   = 1'b1;
    reg        toggle2  = 1'b1;


    wire [(`DATA_WIDTH)-1:0]                  T_out_1;
    wire [(`DATA_WIDTH)-1:0]                  T_out_2;

    wire [(`DATA_WIDTH)-1:0]                  MAX_T_out_1;
    wire [(`DATA_WIDTH)-1:0]                  MAX_T_out_2;
    


    assign T_out_1 = CONV_T_out[`DATA_WIDTH-1:0];
    assign T_out_2 = CONV_T_out[(2*`DATA_WIDTH)-1:`DATA_WIDTH];

    assign MAX_T_out_1 = MAX_T_out[`DATA_WIDTH-1:0];
    assign MAX_T_out_2 = MAX_T_out[(2*`DATA_WIDTH)-1:`DATA_WIDTH];

    // kernels 3x3
    integer j,outfile0,outfile1,outfile2,outfile3,status1;
    integer            outfile4,outfile5,outfile6,outfile7,status2;


   


    ///////////////////////

    // Assignments
    assign CONV_l_valid   = DWC_r_valid & data_l_valid;
    assign CONV_mod_l_rdy = CONV_l_rdy & CONV_l_valid;

    // DUT instantiation
    /////////// 
    weight_rotator #(
        .DATA_WIDTH(`DATA_WIDTH),
        .CONV_CORES(`CONV_CORES),
        .ADDRS_WIDTH(`ADDRS_WIDTH),
        .ROTATE_WIDTH(`ROTATE_WIDTH),
        .FIFO_DEPTH(`FIFO_DEPTH),
        .FIFO_COUNTER_WIDTH(`FIFO_COUNTER_WIDTH),
        .RAM_LATENCY(`RAM_LATENCY),
        .CH_IN_COUNTER_WIDTH(`CH_IN_COUNTER_WIDTH),
        .NUM_BLKS_COUNTER_WIDTH(`NUM_BLKS_COUNTER_WIDTH),
        .IM_WIDTH_COUNTER_WIDTH(`IM_WIDTH_COUNTER_WIDTH)
    )WEIGHT_ROTATOR_DUT(
        .clk(clk),
        .rstn(rstn),
        .din(WR_din),
        .l_valid(WR_l_valid),
        .r_rdy(DWC_l_rdy),
        .write_depth(WR_write_depth),
        .rotate_amount(WR_rotate_amount),
        .im_channels_in(WR_im_channels_in),
        .im_width_in(WR_im_width_in),
        .im_blocks_in(WR_im_blocks_in),
        .conv_mode_in(WR_conv_mode_in),
        .max_mode_in(WR_max_mode_in),
        .l_rdy(WR_l_rdy),
        .r_valid(WR_r_valid),
        .BIAS_out(WR_BIAS_out),
        .im_channels_out(WR_im_channels_out),
        .im_width_out(WR_im_width_out),
        .im_blocks_out(WR_im_blocks_out),
        .conv_mode_out(WR_conv_mode_out),
        .max_mode_out(WR_max_mode_out),
        .dout(WR_dout)
    ); 



    axis_dwidth_converter_1 DWC_MP (
        .aclk(clk),                     // input wire aclk
        .aresetn(rstn),                 // input wire aresetn
        .s_axis_tvalid(WR_r_valid),     // input wire s_axis_tvalid
        .s_axis_tready(DWC_l_rdy),      // output wire s_axis_tready
        .s_axis_tdata(WR_dout),         // input wire [95 : 0] s_axis_tdata
        .m_axis_tvalid(DWC_r_valid),    // output wire m_axis_tvalid
        .m_axis_tready(CONV_mod_l_rdy), // input wire m_axis_tready
        .m_axis_tdata(DWC_MP_dout)      // output wire [143 : 0] m_axis_tdata
    );



    genvar v;
    generate
        for(v = 0; v <= (`CONV_PAIRS-1); v = v+1) begin: disperse_3x3 // dispersing the 9*N/2 kernel values to 9*N
            assign DWC_MP_mapped_dout[(9*2*`DATA_WIDTH*(v+1))-1:(9*2*`DATA_WIDTH*v)] = {2{DWC_MP_dout[(`DATA_WIDTH * 9 * (v+1))-1 : `DATA_WIDTH * 9 * v]}};
        end
    endgenerate


    conv_block #(
        .DATA_WIDTH(`DATA_WIDTH),
        .CONV_UNITS(`CONV_UNITS),
        .CONV_PAIRS(`CONV_PAIRS)
    )CONV_BLOCK_DUT(
        .rstn(rstn),
        .clk(clk),
        .conv_mode(WR_conv_mode_out),
        .max_mode(WR_max_mode_out),
        .X_IN({X_IN_type_2,X_IN_type_1}),
        .KERNEL(DWC_MP_mapped_dout), 
        .r_rdy(MAX_l_rdy),
        .l_valid(CONV_l_valid),
        .ch_in(WR_im_channels_out),
        .im_width(WR_im_width_out),
        .num_blocks(WR_im_blocks_out),
        .BIAS(WR_BIAS_out),
        .l_rdy(CONV_l_rdy),
        .r_valid(CONV_r_valid),
        .finished(CONV_finished),
        .T_out(CONV_T_out),
        .max_mode_out(CONV_max_mode_out),
        .T_last(CONV_T_last)
    );


    
    maxpool_block #(
        .DATA_WIDTH(`DATA_WIDTH),
        .CONV_UNITS(`CONV_UNITS),
        .CONV_CORES(`CONV_CORES)
    )MAXPOOL_BLOCK(
        .clk(clk),
        .rstn(rstn),
        .r_rdy(MAX_r_rdy),
        .l_valid(CONV_r_valid),
        .T_last_in(CONV_T_last),
        .mode(CONV_max_mode_out),
        .d_in(CONV_T_out),
        .r_valid(MAX_r_valid),
        .l_rdy(MAX_l_rdy),
        .T_out(MAX_T_out),
        .T_last_out(MAX_T_last_out)
    );

    ///////////





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



    // Main code



    always // Clock generation
    begin
        #(CLK_PERIOD/2);
        clk <= ~ clk;
    end

    // always @(posedge clk) 
    // begin
    //     if(counter2 < (32'd0-32'd1) )
    //     begin
    //         counter2 <= counter2 + 1;    
    //     end else begin
    //         counter2 <= counter2;
    //     end
        
    //     if ((counter2 >= 32'd30) & (counter2 <= 32'd260)) 
    //     begin
    //         r_rdy <= 0;
    //     end else begin
    //         r_rdy <= 1; 
    //     end
    // end


    initial
    begin
        outfile2=$fopen("./txt/conv_out_sys_mp_part_1.txt","w");
        outfile5=$fopen("./txt/conv_out_sys_mp_part_2.txt","w");
        outfile6=$fopen("./txt/conv_out_sys_b4mp_part_1.txt","w");
        outfile7=$fopen("./txt/conv_out_sys_b4mp_part_2.txt","w");
    end


    always@(posedge clk)
        
    begin
        if(MAX_r_valid & MAX_r_rdy)//(r_valid)// (r_valid & r_rdy) // try using this to avoid writing the same value again and again
        begin
                $fdisplay(outfile2,"%d",MAX_T_out_1);
                $fdisplay(outfile5,"%d",MAX_T_out_2);
        end
    end


    always@(posedge clk)
        
    begin
        if(CONV_r_valid & MAX_l_rdy)//(r_valid)// (r_valid & r_rdy) // try using this to avoid writing the same value again and again
        begin
                $fdisplay(outfile6,"%d",T_out_1);
                $fdisplay(outfile7,"%d",T_out_2);
        end
    end


    initial
    begin
        areset;
        @(posedge clk);
        // need to interuppt (for debugging)
        // toggle <= 0; 
        // 3x3 convolution max pool
        WR_write_depth    <= (k_size * ch_in / 2) + 1 -1;  // cut the number of filters by half
        WR_rotate_amount  <= (im_width * num_blocks/2)-1;  // convolution cores pair together to work on 2 blocks parallel
        WR_im_channels_in <= ch_in-1;
        WR_im_width_in    <= im_width-1;
        WR_im_blocks_in   <= num_blocks/2-1;
        WR_conv_mode_in   <= conv_3x3;
        WR_max_mode_in    <= max_pool;
        load_weights;
        MAX_r_rdy        <= 1;
        feed_data_3x3_mp;



        @(posedge MAX_T_last_out);
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
        $fclose(outfile5);
        $fclose(outfile6);
        $fclose(outfile7);
    end

    task load_weights;
        integer q;
    begin
        @(posedge clk);
        outfile1=$fopen("./txt/wb_1_itr_1.txt","r"); 
        while (! $feof(outfile1)) begin
            @(posedge clk);
            
            if(WR_l_rdy) begin
                #(10);
                WR_l_valid <= 1;
                for(q = 0; q <=((`CONV_CORES * 3)-1) ; q = q +1)begin //read until an "end of file" is reached.
                    status1 = $fscanf(outfile1,"%d\n",WR_din[((`DATA_WIDTH*(1+q))-1)-:`DATA_WIDTH]);
                end
            end else begin
                WR_din <= WR_din;
            end
        end
        @(posedge clk);
        while (!WR_l_rdy) begin
            WR_din <= WR_din;
            @(posedge clk);
        end
        WR_l_valid <= 0;
        $fclose(outfile1);
    end
    endtask





    task feed_data_3x3_mp;
        integer w;
    begin
        @(posedge clk);
        outfile0=$fopen("./txt/1_im_0.txt","r"); 
        outfile3=$fopen("./txt/1_im_1.txt","r"); 
        data_l_valid <= 1;
        for(w = 0; w <=((`CONV_UNITS+2)-1) ; w = w +1)begin //read until an "end of file" is reached.
            status1 = $fscanf(outfile0,"%d\n",X_IN_type_1[((`DATA_WIDTH*(1+w))-1)-:`DATA_WIDTH]);
            status2 = $fscanf(outfile3,"%d\n",X_IN_type_2[((`DATA_WIDTH*(1+w))-1)-:`DATA_WIDTH]);

        end
        while (! $feof(outfile0)) begin
            @(posedge clk);
            
            if(CONV_mod_l_rdy) begin
                #(10);
                
                for(w = 0; w <=((`CONV_UNITS+2)-1) ; w = w +1)begin //read until an "end of file" is reached.
                    status1 = $fscanf(outfile0,"%d\n",X_IN_type_1[((`DATA_WIDTH*(1+w))-1)-:`DATA_WIDTH]);
                    status2 = $fscanf(outfile3,"%d\n",X_IN_type_2[((`DATA_WIDTH*(1+w))-1)-:`DATA_WIDTH]);
                end
            end else begin
                X_IN_type_1 <= X_IN_type_1;
                X_IN_type_2 <= X_IN_type_2;
            end
        end
        @(posedge clk);
        while (!CONV_mod_l_rdy) begin
            X_IN_type_1 <= X_IN_type_1;
            X_IN_type_2 <= X_IN_type_2;
            @(posedge clk);
        end
        data_l_valid <= 0;
        $fclose(outfile0);
        $fclose(outfile3);
    end
    endtask












    task areset;
    begin
        #(CLK_PERIOD/4);
        rstn <= 0;
        #(CLK_PERIOD*4);
        rstn <= 1;
    end
    endtask


endmodule