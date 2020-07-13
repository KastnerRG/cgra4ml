`include "system_parameters.v"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : ABruTECH
// Engineer: W.M.R.R.Wickramasinghe
// 
// Create Date: 01/02/2020 07:26:45 PM
// Design Name: system_1_nmp_tb
// Module Name: system_1_nmp_tb
// Project Name: FYP
// Target Devices: Zync ultra96
// Tool Versions: Vivado 2018.2
// Description: Test bench for partial system (convolution block + Data width converter + weight rotator) with real data
//              Use only for non max pool case.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module system_1_nmp_tb();

    // Parameters
    localparam CLK_PERIOD             = 1000;




    // localparam IO_WIDTH   = (CONV_CORES *3 * DATA_WIDTH);
    localparam ch_in      = 64;
    localparam k_size     = 3;
    localparam im_width   = 96;
    localparam num_blocks = 8;

    localparam max_pool     = 1;
    localparam not_max_pool = 0;
    localparam conv_3x3     = 0;
    localparam conv_1x1     = 1;

   reg [8:0] temp_reg     = 0;
   reg [16:0] temp_reg_2  = 1;
    
    reg                                    aclk              = 0 ;
    reg                                    aresetn           = 1 ;
    reg                                    PIPES_is_maxpool  = 0 ;
    reg                                    PIPES_is_edges    = 0 ;
    reg                                    PIPES_conv_mode   = 0 ;
    reg                                    lrelu_en          = 1;
    
    
    reg                                    WR_conv_mode_in      = 0;
    reg                                    WR_max_mode_in       = 0;
    reg [`ADDRS_WIDTH-1:0]                 WR_write_depth       = 0;
    reg [`ROTATE_WIDTH-1:0]                WR_rotate_amount     = 0;
    reg [`CH_IN_COUNTER_WIDTH-1:0]         WR_im_channels_in    = 0;
    reg [`IM_WIDTH_COUNTER_WIDTH-1:0]      WR_im_width_in       = 0;
    reg [`NUM_BLKS_COUNTER_WIDTH-1:0]      WR_im_blocks_in      = 0;


    reg    [`WEIGHTS_DMA_WIDTH-1:0]        IP_S_W_DMA_AXIS_tdata   = 0;
    reg                                    IP_S_W_DMA_AXIS_tvalid  = 0;
    wire                                   IP_S_W_DMA_AXIS_tready;
    reg    [`WEIGHTS_DMA_WIDTH/8 -1:0]     IP_S_W_DMA_AXIS_tkeep  = {16{1'b1}};
    reg                                    IP_S_W_DMA_AXIS_tlast = 0;

    reg    [`IMAGE_DMA_WIDTH-1:0]          IP_S_IM_DMA_0_AXIS_tdata  = 0;
    reg                                    IP_S_IM_DMA_0_AXIS_tvalid = 0;
    wire                                   IP_S_IM_DMA_0_AXIS_tready;
    reg    [`IMAGE_DMA_WIDTH/8 -1:0]       IP_S_IM_DMA_0_AXIS_tkeep = 0;
    reg                                    IP_S_IM_DMA_0_AXIS_tlast = 0;

    reg    [`IMAGE_DMA_WIDTH-1:0]          IP_S_IM_DMA_1_AXIS_tdata  = 0 ;
    reg                                    IP_S_IM_DMA_1_AXIS_tvalid = 0 ;
    wire                                   IP_S_IM_DMA_1_AXIS_tready ;
    reg    [`IMAGE_DMA_WIDTH/8-1:0]        IP_S_IM_DMA_1_AXIS_tkeep = 0;
    reg                                    IP_S_IM_DMA_1_AXIS_tlast = 0;
    
    reg    [2*`DATA_WIDTH-1:0]             IP_S_EDGE_AXIS_tdata   = 0 ;
    reg                                    IP_S_EDGE_AXIS_tvalid  = 0 ;
    wire                                   IP_S_EDGE_AXIS_tready ;

    // wire [`OUTPUT_DMA_WIDTH-1:0]           OP_M_AXIS_tdata ;
    // wire                                   OP_M_AXIS_tvalid;
    // wire                                   OP_M_AXIS_tlast ;
    // reg                                    OP_M_AXIS_tready =0;   

    wire [`OUTPUT_DMA_WIDTH-1:0]           LRELU_M_AXIS_tdata  ;
    wire                                   LRELU_M_AXIS_tvalid ;
    wire                                   LRELU_M_AXIS_tlast  ;
    reg                                    LRELU_M_AXIS_tready = 1;           

        

    wire [15:0] L1;
    wire [15:0] L2;

    assign L1 = LRELU_M_AXIS_tdata[15:0];
    assign L2 = LRELU_M_AXIS_tdata[31:16];


    ////////////////////////////////



    // reg [31:0] counter  = 32'd0;
    // reg [31:0] counter2 = 32'd0;
    reg        toggle   = 1'b1;
    // reg        toggle2  = 1'b1;


    // wire [(`DATA_WIDTH)-1:0]                  T_out_1;
    // wire [(`DATA_WIDTH)-1:0]                  T_out_2;

    // wire [(`DATA_WIDTH)-1:0]                  MAX_T_out_1;
    // wire [(`DATA_WIDTH)-1:0]                  MAX_T_out_2;
    


    // assign T_out_1 = CONV_T_out[`DATA_WIDTH-1:0];
    // assign T_out_2 = CONV_T_out[(2*`DATA_WIDTH)-1:`DATA_WIDTH];

    // assign MAX_T_out_1 = MAX_T_out[`DATA_WIDTH-1:0];
    // assign MAX_T_out_2 = MAX_T_out[(2*`DATA_WIDTH)-1:`DATA_WIDTH];

    // kernels 3x3
    integer j,outfile0,outfile1,outfile2,outfile3,status1;
    integer            outfile4,outfile5,outfile6,status2;


    

    ///////////////////////

    // Assignments

    // DUT instantiation
    ///////////
    full_pipe DUT(
    .aclk            (aclk            ),
    .aresetn         (aresetn         ),
    .PIPES_is_maxpool(PIPES_is_maxpool),
    .PIPES_is_edges  (PIPES_is_edges  ),
    .PIPES_conv_mode (PIPES_conv_mode ),
    .lrelu_en(lrelu_en),
    
    .WR_conv_mode_in  (WR_conv_mode_in  ),
    .WR_max_mode_in   (WR_max_mode_in   ),
    .WR_write_depth   (WR_write_depth   ), 
    .WR_rotate_amount (WR_rotate_amount ),
    .WR_im_channels_in(WR_im_channels_in),
    .WR_im_width_in   (WR_im_width_in   ),
    .WR_im_blocks_in  (WR_im_blocks_in  ),

    .IP_S_W_DMA_AXIS_tdata (IP_S_W_DMA_AXIS_tdata ),
    .IP_S_W_DMA_AXIS_tvalid(IP_S_W_DMA_AXIS_tvalid),
    .IP_S_W_DMA_AXIS_tready(IP_S_W_DMA_AXIS_tready),
    .IP_S_W_DMA_AXIS_tkeep(IP_S_W_DMA_AXIS_tkeep),
    .IP_S_W_DMA_AXIS_tlast(IP_S_W_DMA_AXIS_tlast),

    .IP_S_IM_DMA_0_AXIS_tdata (IP_S_IM_DMA_0_AXIS_tdata ),
    .IP_S_IM_DMA_0_AXIS_tvalid(IP_S_IM_DMA_0_AXIS_tvalid),
    .IP_S_IM_DMA_0_AXIS_tready(IP_S_IM_DMA_0_AXIS_tready),
    .IP_S_IM_DMA_0_AXIS_tkeep(IP_S_IM_DMA_0_AXIS_tkeep),
    .IP_S_IM_DMA_0_AXIS_tlast(IP_S_IM_DMA_0_AXIS_tlast),

    .IP_S_IM_DMA_1_AXIS_tdata (IP_S_IM_DMA_1_AXIS_tdata ),
    .IP_S_IM_DMA_1_AXIS_tvalid(IP_S_IM_DMA_1_AXIS_tvalid),
    .IP_S_IM_DMA_1_AXIS_tready(IP_S_IM_DMA_1_AXIS_tready),
    .IP_S_IM_DMA_1_AXIS_tkeep(IP_S_IM_DMA_1_AXIS_tkeep),
    .IP_S_IM_DMA_1_AXIS_tlast(IP_S_IM_DMA_1_AXIS_tlast),

    .IP_S_EDGE_AXIS_tdata (IP_S_EDGE_AXIS_tdata ),
    .IP_S_EDGE_AXIS_tvalid(IP_S_EDGE_AXIS_tvalid),
    .IP_S_EDGE_AXIS_tready(IP_S_EDGE_AXIS_tready),

    // .OP_M_AXIS_tdata (OP_M_AXIS_tdata ),
    // .OP_M_AXIS_tvalid(OP_M_AXIS_tvalid),
    // .OP_M_AXIS_tlast (OP_M_AXIS_tlast ),
    // .OP_M_AXIS_tready(OP_M_AXIS_tready)   

    .LRELU_M_AXIS_tdata (LRELU_M_AXIS_tdata ),
    .LRELU_M_AXIS_tvalid(LRELU_M_AXIS_tvalid),
    .LRELU_M_AXIS_tlast (LRELU_M_AXIS_tlast ),
    .LRELU_M_AXIS_tready(LRELU_M_AXIS_tready)
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
        aclk <= ~ aclk;
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


    // initial
    // begin
    //     outfile2=$fopen("../../../../../src/text/conv_out_sys_1_1.txt","w");
    //     outfile5=$fopen("../../../../../src/text/conv_out_sys_1_2.txt","w");
    //     // integer j;
    // end

    // always@(posedge clk)
        
    // begin
    //     if(CONV_r_valid & CONV_r_rdy)//(r_valid)// (r_valid & r_rdy) // try using this to avoid writing the same value again and again
    //     begin
    //         // for (j = 0 ; j<(CONV_UNITS+2); j = j + 1) begin
    //             // $fdisplay(outfile6,"%d",conv_out[DATA_WIDTH*(j+1)-1:DATA_WIDTH*j]);
    //             $fdisplay(outfile2,"%d",T_out_1);
    //             $fdisplay(outfile5,"%d",T_out_2);
    //             // #1;
    //         // end
    //     end
    // end


    // always@(posedge aclk)
        
    // begin
    //     if(MAX_r_valid & MAX_r_rdy)//(r_valid)// (r_valid & r_rdy) // try using this to avoid writing the same value again and again
    //     begin
    //         // for (j = 0 ; j<(CONV_UNITS+2); j = j + 1) begin
    //             // $fdisplay(outfile6,"%d",conv_out[DATA_WIDTH*(j+1)-1:DATA_WIDTH*j]);
    //             $fdisplay(outfile2,"%d",MAX_T_out_1);
    //             $fdisplay(outfile5,"%d",MAX_T_out_2);
    //             // #1;
    //         // end
    //     end
    // end


    initial
    begin
        @(posedge LRELU_M_AXIS_tvalid);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        LRELU_M_AXIS_tready <=0;
        
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        toggle <= 0;
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);   
        LRELU_M_AXIS_tready <=1;  
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);   
        toggle <= 1;

    end



    initial
    begin
        // outfile6=$fopen("../../../../../src/text/sim_output/weight_out.txt","w");
        areset;
        @(posedge aclk);
        // need to interuppt (for debugging)
        // toggle <= 0; 
        // 3x3 convolution
        PIPES_is_maxpool  <= 0 ;
        PIPES_is_edges    <= 0 ;
        PIPES_conv_mode   <= 0 ;        

        WR_conv_mode_in      <= 0;
        WR_max_mode_in       <= 0;
        WR_write_depth       <= (k_size * ch_in) + 1 -1;
        WR_rotate_amount     <= (im_width * num_blocks)-1;
        WR_im_channels_in    <= ch_in-1;
        WR_im_width_in       <= im_width-1;
        WR_im_blocks_in      <= num_blocks-1;

        

        // IP_S_W_DMA_AXIS_tdata   <= 0;
        // IP_S_W_DMA_AXIS_tvalid  <= 0;
        // IP_S_W_DMA_AXIS_tkeep   <= {4'b0,{12{1'b1}}};

        // IP_S_IM_DMA_0_AXIS_tdata  <= 0;
        // IP_S_IM_DMA_0_AXIS_tvalid <= 0;
        IP_S_IM_DMA_0_AXIS_tkeep  <= {(`IMAGE_DMA_WIDTH/8){1'b1}};

        IP_S_IM_DMA_1_AXIS_tdata  <= 0 ;
        IP_S_IM_DMA_1_AXIS_tvalid <= 0 ;
        IP_S_IM_DMA_1_AXIS_tkeep  <= 0 ;

        IP_S_EDGE_AXIS_tdata   <= 0 ;
        IP_S_EDGE_AXIS_tvalid  <= 0 ;

        // LRELU_M_AXIS_tready <=1;     

        load_weights;
        @(posedge aclk);
        feed_data_3x3_nmp;



        // WR_write_depth    <= (k_size * ch_in) + 1 -1;
        // WR_rotate_amount  <= (im_width * num_blocks)-1;
        // WR_im_channels_in <= ch_in-1;
        // WR_im_width_in    <= im_width-1;
        // WR_im_blocks_in   <= num_blocks-1;
        // WR_conv_mode_in   <= conv_3x3;
        // WR_max_mode_in    <= not_max_pool;
        // load_weights;
        // MAX_r_rdy        <= 1;
        // feed_data_3x3_nmp;

        // ch_in      <= 32'd1; 
        // im_width   <= 32'd2;
        // num_blocks <= 32'd1;
        // mode <= 0;
        // feed_data_3x3;
        
        //1x1 convolution
        // ch_in      <= 32'd128; 
        // im_width   <= 32'd96;
        // num_blocks <= 32'd8;
        // mode <= 1;
        // feed_data_3x3;


        // @(posedge CONV_finished);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // @(posedge aclk);
        // $fclose(outfile2);
        // $fclose(outfile5);
    end

    task load_weights;
        integer q;
    begin
        @(posedge aclk);
        outfile1=$fopen("../../../../../src/text/wb_3_itr_1.txt","r"); 
        while (! $feof(outfile1)) begin
            @(posedge aclk);
            
            if(IP_S_W_DMA_AXIS_tready) begin
                #(10);
                IP_S_W_DMA_AXIS_tvalid <= 1;
                temp_reg <= temp_reg +1;
                for(q = 0; q <=((`WEIGHTS_DMA_WIDTH/`DATA_WIDTH)-1) ; q = q +1)begin //read until an "end of file" is reached.
                    status1 = $fscanf(outfile1,"%d\n",IP_S_W_DMA_AXIS_tdata[((`DATA_WIDTH*(1+q))-1)-:`DATA_WIDTH]);
                end 
                #(10);
                if ($feof(outfile1)) begin
                    IP_S_W_DMA_AXIS_tkeep   <= {4'b0,{12{1'b1}}};
                    IP_S_W_DMA_AXIS_tlast   <= 1;
                end else begin
                    IP_S_W_DMA_AXIS_tkeep   <= {16{1'b1}};
                    IP_S_W_DMA_AXIS_tlast   <= 0;
                end
            end else begin
                IP_S_W_DMA_AXIS_tdata <= IP_S_W_DMA_AXIS_tdata;
            end
        end
        @(posedge aclk);
        while (!IP_S_W_DMA_AXIS_tready) begin
            IP_S_W_DMA_AXIS_tdata <= IP_S_W_DMA_AXIS_tdata;
            @(posedge aclk);
        end
        IP_S_W_DMA_AXIS_tvalid <= 0;
        IP_S_W_DMA_AXIS_tlast   <= 0;
        $fclose(outfile1);
    end
    endtask





    task feed_data_3x3_nmp;
        integer w;
    begin
        @(posedge aclk);
        outfile0=$fopen("../../../../../src/text/im_3.txt","r"); 
        IP_S_IM_DMA_0_AXIS_tvalid <= 1;
        for(w = 0; w <=((`IMAGE_DMA_WIDTH/`DATA_WIDTH)-1) ; w = w +1)begin //read until an "end of file" is reached.
            status1 = $fscanf(outfile0,"%d\n",IP_S_IM_DMA_0_AXIS_tdata[((`DATA_WIDTH*(1+w))-1)-:`DATA_WIDTH]);
        end
        while (! $feof(outfile0)) begin
            @(posedge aclk);
            if (toggle) begin
                
                IP_S_IM_DMA_0_AXIS_tvalid <= 1;
                if(IP_S_IM_DMA_0_AXIS_tready) begin
                    #(10);
                    temp_reg_2 <= temp_reg_2 + 1;
                    for(w = 0; w <=((`IMAGE_DMA_WIDTH/`DATA_WIDTH)-1) ; w = w +1)begin //read until an "end of file" is reached.
                        status1 = $fscanf(outfile0,"%d\n",IP_S_IM_DMA_0_AXIS_tdata[((`DATA_WIDTH*(1+w))-1)-:`DATA_WIDTH]);

                    end
                end else begin
                    IP_S_IM_DMA_0_AXIS_tdata <= IP_S_IM_DMA_0_AXIS_tdata;
                end
                    
            end else begin
                IP_S_IM_DMA_0_AXIS_tdata <= IP_S_IM_DMA_0_AXIS_tdata;
                IP_S_IM_DMA_0_AXIS_tvalid <= 0;
                temp_reg_2 <= temp_reg_2;
            end
        end
        IP_S_IM_DMA_0_AXIS_tlast <= 1;
        @(posedge aclk);
        while (!IP_S_IM_DMA_0_AXIS_tready) begin
            IP_S_IM_DMA_0_AXIS_tdata <= IP_S_IM_DMA_0_AXIS_tdata;
            @(posedge aclk);
        end
        IP_S_IM_DMA_0_AXIS_tvalid <= 0;
        IP_S_IM_DMA_0_AXIS_tlast  <= 0;
        $fclose(outfile0);
    end
    endtask







    // task feed_data_3x3;
    //     integer i;
    //     integer k;
    //     integer r;
    //     integer u;
    // begin
    //     outfile0=$fopen("../../../../../src/text/im_feed.txt","r");   //"r" means reading and "w" means writing
    //     outfile1=$fopen("../../../../../src/text/kernel_feed_1.txt","r");
    //     outfile4=$fopen("../../../../../src/text/kernel_feed_2.txt","r");
    //     outfile3=$fopen("../../../../../src/text/bias_feed_1.txt","r");
    //     outfile6=$fopen("../../../../../src/text/bias_feed_2.txt","r");
        
    //     i = 0;
    //     l_valid <= 1;
    //     for(i = 0; i <=((CONV_UNITS+2)-1) ; i = i +1)begin //read until an "end of file" is reached.
    //         status1 = $fscanf(outfile0,"%d\n",X_IN[((DATA_WIDTH*(1+i))-1)-:DATA_WIDTH]);
    //     end

    //     for(i = 0; i <=8 ; i = i +1)begin //read until an "end of file" is reached.
    //         // status1 = $fscanf(outfile1,"%d\n",KERNEL_3x3[((DATA_WIDTH*(1+i))-1)-:DATA_WIDTH]);
    //         status1 = $fscanf(outfile1,"%d\n",KERNEL_3x3_1[i]);
    //         status2 = $fscanf(outfile4,"%d\n",KERNEL_3x3_2[i]);
    //     end

    //     for(i = 0; i <=2 ; i = i +1)begin //read until an "end of file" is reached.
    //         status1 = $fscanf(outfile3,"%d\n",BIAS_1[((DATA_WIDTH*(1+i))-1)-:DATA_WIDTH]);
    //         status2 = $fscanf(outfile6,"%d\n",BIAS_2[((DATA_WIDTH*(1+i))-1)-:DATA_WIDTH]);
    //     end

    //     while (! $feof(outfile0)) begin
    //         @(posedge clk);
    //         counter <= counter +1;
    //         if ((toggle == 1) & (counter == 32'd158)) begin
    //             for (u = 0;u<100 ; u = u+1 ) begin
    //                 l_valid <= 0;
    //                 // r_rdy   <= 0;
    //                 @(posedge clk);
    //             end
    //             l_valid <= 1;
    //             // r_rdy   <= 1;
    //             toggle <= 0;
    //             @(posedge clk);
    //         end
            
            
    //         if (l_rdy) begin
    //             #(10);
    //             for(i = 0; i <=((CONV_UNITS+2)-1) ; i = i +1)begin //read until an "end of file" is reached.
    //                 status1 = $fscanf(outfile0,"%d\n",X_IN[((DATA_WIDTH*(1+i))-1)-:DATA_WIDTH]);
    //             end

    //             if ($feof(outfile1)) begin
    //                 $fclose(outfile1);
    //                 $fclose(outfile4);
    //                 outfile1=$fopen("../../../../../src/text/kernel_feed_1.txt","r");
    //                 outfile4=$fopen("../../../../../src/text/kernel_feed_2.txt","r");
    //             end

    //             for(i = 0; i <=8 ; i = i +1)begin //read until an "end of file" is reached.
    //                 // status1 = $fscanf(outfile1,"%d\n",KERNEL_3x3[((DATA_WIDTH*(1+i))-1)-:DATA_WIDTH]);
    //                 status1 = $fscanf(outfile1,"%d\n",KERNEL_3x3_1[i]);
    //                 status2 = $fscanf(outfile4,"%d\n",KERNEL_3x3_2[i]);
    //             end
    //         end else begin
    //             X_IN       <= X_IN;
    //             // KERNEL_3x3 <= KERNEL_3x3;
    //         end
    //     end
    //     @(posedge clk);
    //     while (!l_rdy) begin
    //         @(posedge clk);
    //         X_IN       <= X_IN;
    //         // KERNEL_3x3 <= KERNEL_3x3;
    //         l_valid    <= 1;
    //     end
    //     l_valid <= 0;
    //     $fclose(outfile0);
    //     $fclose(outfile1);
    //     $fclose(outfile4);
    //     $fclose(outfile3);
    //     $fclose(outfile6);
    // end 
    // endtask





    task areset;
    begin
        #(CLK_PERIOD/4);
        aresetn <= 0;
        #(CLK_PERIOD*4);
        aresetn <= 1;
    end
    endtask


endmodule