`include "system_parameters.v"

module full_pipe (
    input                                    aclk                      ,
    input                                    aresetn                   ,
    input                                    PIPES_is_maxpool          ,
    // input                                    PIPES_is_edges            ,
    input                                    PIPES_conv_mode           ,
    input                                    lrelu_en                  ,
    
    input                                    WR_conv_mode_in           ,
    input                                    WR_max_mode_in            ,
    input [`ADDRS_WIDTH-1:0]                 WR_write_depth            , 
    input [`ROTATE_WIDTH-1:0]                WR_rotate_amount          ,
    input [`CH_IN_COUNTER_WIDTH-1:0]         WR_im_channels_in         ,
    input [`IM_WIDTH_COUNTER_WIDTH-1:0]      WR_im_width_in            ,
    input [`NUM_BLKS_COUNTER_WIDTH-1:0]      WR_im_blocks_in           ,

    input    [`WEIGHTS_DMA_WIDTH-1:0]        IP_S_W_DMA_AXIS_tdata     ,
    input                                    IP_S_W_DMA_AXIS_tvalid    ,
    output                                   IP_S_W_DMA_AXIS_tready    ,
    input    [`WEIGHTS_DMA_WIDTH/8 -1:0]     IP_S_W_DMA_AXIS_tkeep     ,
    input                                    IP_S_W_DMA_AXIS_tlast     ,

    input    [`IMAGE_DMA_WIDTH-1:0]          IP_S_IM_DMA_0_AXIS_tdata  ,
    input                                    IP_S_IM_DMA_0_AXIS_tvalid ,
    output                                   IP_S_IM_DMA_0_AXIS_tready ,
    input    [`IMAGE_DMA_WIDTH/8 -1:0]       IP_S_IM_DMA_0_AXIS_tkeep  ,
    input                                    IP_S_IM_DMA_0_AXIS_tlast  ,

    input    [`IMAGE_DMA_WIDTH-1:0]          IP_S_IM_DMA_1_AXIS_tdata  ,
    input                                    IP_S_IM_DMA_1_AXIS_tvalid ,
    output                                   IP_S_IM_DMA_1_AXIS_tready ,
    input    [`IMAGE_DMA_WIDTH/8-1:0]        IP_S_IM_DMA_1_AXIS_tkeep  ,
    input                                    IP_S_IM_DMA_1_AXIS_tlast  ,
    
    // input    [2*`DATA_WIDTH-1:0]             IP_S_EDGE_AXIS_tdata      ,
    // input                                    IP_S_EDGE_AXIS_tvalid     ,
    // output                                   IP_S_EDGE_AXIS_tready     ,

    output [`OUTPUT_DMA_WIDTH-1:0]           LRELU_M_AXIS_tdata        ,
    output                                   LRELU_M_AXIS_tvalid       ,
    output                                   LRELU_M_AXIS_tlast        ,
    input                                    LRELU_M_AXIS_tready       ,
    output [`OUTPUT_DMA_WIDTH/8-1:0]         LRELU_M_AXIS_tkeep
        
);

parameter OUTPUT_TKEEP_WIDTH = `OUTPUT_DMA_WIDTH/8;

wire                                         IP_is_maxpool;
// wire                                         IP_is_edges  ;
wire                                         IP_is_3x3    ;

wire    [3*`Nb-1:0]                          IP_S_W_ROTATOR_AXIS_tdata;
wire                                         IP_S_W_ROTATOR_AXIS_tvalid;
wire                                         IP_S_W_ROTATOR_AXIS_tready;
wire    [3*`Nb-1:0]                          IP_M_W_ROTATOR_AXIS_tdata;
wire                                         IP_M_W_ROTATOR_AXIS_tvalid;
wire                                         IP_M_W_ROTATOR_AXIS_tready;
wire                                         IP_M_AXIS_tready;
wire                                         IP_M_AXIS_tvalid;
wire    [(9*`Nb)-1:0]                        IP_weights;
wire    [2*(`CONV_UNITS+2)*`DATA_WIDTH-1:0]  IP_image;

input_pipe #(
    .IMAGE_DMA_WIDTH   ( `IMAGE_DMA_WIDTH       ),
    .WEIGHTS_DMA_WIDTH ( `WEIGHTS_DMA_WIDTH     ),
    .DATA_WIDTH        ( `DATA_WIDTH            ),
    .CONV_PAIRS        ( `CONV_PAIRS            ),
    .CONV_UNITS        ( `CONV_UNITS            ),
    .CONV_CORES        ( `CONV_CORES            ),
    .Nb                ( `Nb                    )    
) INPUT_PIPE_DUT (
        .aclk                   (aclk                       ),//
        .aresetn                (aresetn                    ),//

        .is_maxpool             (IP_is_maxpool              ),
        .is_3x3                 (IP_is_3x3                  ),
        // .is_edges               (IP_is_edges                ),
        .S_W_DMA_AXIS_tdata     (IP_S_W_DMA_AXIS_tdata      ),
        .S_W_DMA_AXIS_tvalid    (IP_S_W_DMA_AXIS_tvalid     ),
        .S_W_DMA_AXIS_tready    (IP_S_W_DMA_AXIS_tready     ),
        .S_W_DMA_AXIS_tkeep     (IP_S_W_DMA_AXIS_tkeep      ),
        .S_W_DMA_AXIS_tlast     (IP_S_W_DMA_AXIS_tlast      ),

        .S_IM_DMA_0_AXIS_tdata  (IP_S_IM_DMA_0_AXIS_tdata   ),
        .S_IM_DMA_0_AXIS_tvalid (IP_S_IM_DMA_0_AXIS_tvalid  ),
        .S_IM_DMA_0_AXIS_tready (IP_S_IM_DMA_0_AXIS_tready  ),
        .S_IM_DMA_0_AXIS_tkeep  (IP_S_IM_DMA_0_AXIS_tkeep   ),
        .S_IM_DMA_0_AXIS_tlast  (IP_S_IM_DMA_0_AXIS_tlast   ),

        .S_IM_DMA_1_AXIS_tdata  (IP_S_IM_DMA_1_AXIS_tdata   ),
        .S_IM_DMA_1_AXIS_tvalid (IP_S_IM_DMA_1_AXIS_tvalid  ),
        .S_IM_DMA_1_AXIS_tready (IP_S_IM_DMA_1_AXIS_tready  ),
        .S_IM_DMA_1_AXIS_tkeep  (IP_S_IM_DMA_1_AXIS_tkeep   ),
        .S_IM_DMA_1_AXIS_tlast  (IP_S_IM_DMA_1_AXIS_tlast   ),

//        .S_EDGE_AXIS_tdata      (IP_S_EDGE_AXIS_tdata       ),
//        .S_EDGE_AXIS_tvalid     (IP_S_EDGE_AXIS_tvalid      ),
//        .S_EDGE_AXIS_tready     (IP_S_EDGE_AXIS_tready      ),

        .S_W_ROTATOR_AXIS_tdata (IP_S_W_ROTATOR_AXIS_tdata  ),
        .S_W_ROTATOR_AXIS_tvalid(IP_S_W_ROTATOR_AXIS_tvalid ),
        .S_W_ROTATOR_AXIS_tready(IP_S_W_ROTATOR_AXIS_tready ),
        .M_W_ROTATOR_AXIS_tdata (IP_M_W_ROTATOR_AXIS_tdata  ),
        .M_W_ROTATOR_AXIS_tvalid(IP_M_W_ROTATOR_AXIS_tvalid ),
        .M_W_ROTATOR_AXIS_tready(IP_M_W_ROTATOR_AXIS_tready ),
        .M_AXIS_tready          (IP_M_AXIS_tready           ),
        .M_AXIS_tvalid          (IP_M_AXIS_tvalid           ),
        .weights                (IP_weights                 ),
        .image                  (IP_image                   )
    );

    wire [(`CONV_CORES * 3 * `DATA_WIDTH)-1:0] WR_din            ;
    wire                                       WR_l_valid        ;
    wire                                       WR_l_rdy          ;

    wire                                       WR_r_rdy          ;
    wire                                       WR_r_valid        ;
    wire [(`CONV_CORES * 3 * `DATA_WIDTH)-1:0] WR_BIAS_out       ;
    wire [`CH_IN_COUNTER_WIDTH-1:0]            WR_im_channels_out;
    wire [`IM_WIDTH_COUNTER_WIDTH-1:0]         WR_im_width_out   ;
    wire [`NUM_BLKS_COUNTER_WIDTH-1:0]         WR_im_blocks_out  ;
    wire                                       WR_conv_mode_out  ;
    wire                                       WR_max_mode_out   ;
    wire [(`CONV_CORES * 3 * `DATA_WIDTH)-1:0] WR_dout           ;



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
        .clk                (aclk               ),
        .rstn               (aresetn            ),
        .din                (WR_din             ),

        .l_valid            (WR_l_valid         ),
        .r_rdy              (WR_r_rdy           ),
        .write_depth        (WR_write_depth     ),
        .rotate_amount      (WR_rotate_amount   ),
        .im_channels_in     (WR_im_channels_in  ),
        .im_width_in        (WR_im_width_in     ),
        .im_blocks_in       (WR_im_blocks_in    ),
        .conv_mode_in       (WR_conv_mode_in    ),
        .max_mode_in        (WR_max_mode_in     ),
        .l_rdy              (WR_l_rdy           ),
        .r_valid            (WR_r_valid         ),
        .BIAS_out           (WR_BIAS_out        ),
        .im_channels_out    (WR_im_channels_out ),
        .im_width_out       (WR_im_width_out    ),
        .im_blocks_out      (WR_im_blocks_out   ),
        .conv_mode_out      (WR_conv_mode_out   ),
        .max_mode_out       (WR_max_mode_out    ),
        .dout               (WR_dout            )
    ); 

           
    wire                                            CONV_conv_mode      ; // conv mode 0: 3x3 ; 1: 1x1 
    wire                                            CONV_max_mode       ; // conv mode 0: 3x3 ; 1: 1x1 
    wire                                            CONV_r_rdy          ;     
    wire                                            CONV_l_valid        ;   
    wire [`CH_IN_COUNTER_WIDTH-1:0]                 CONV_ch_in          ; // = 32'd3; 
    wire [`IM_WIDTH_COUNTER_WIDTH-1:0]              CONV_im_width       ; // = 32'd384;
    wire [`NUM_BLKS_COUNTER_WIDTH-1:0]              CONV_num_blocks     ; // = 32'd32;
    wire [(`CONV_CORES*`DATA_WIDTH*3)-1:0]          CONV_BIAS           ; //   biases {core n [K3|K2|K1]} , ..... , {core 2 [K3|K2|K1]} , {core 1 [K3|K2|K1]}
    wire [(2 * `DATA_WIDTH*(`CONV_UNITS+2))-1:0]    CONV_X_IN           ; //   {core type2 [R10|R9|R8|R7|R6|R5|R4|R3|R2|R1]} , {core type1 [R10|R9|R8|R7|R6|R5|R4|R3|R2|R1]}
    wire [(`CONV_CORES*`DATA_WIDTH*9)-1:0]          CONV_KERNEL         ; //   { core n [K9|K8|K7|K6|K5|K4|K3|K2|K1]} , .... , { core 1 [K9|K8|K7|K6|K5|K4|K3|K2|K1]}
    wire                                            CONV_r_valid        ;
    wire                                            CONV_l_rdy          ;
    wire                                            CONV_finished       ;
    wire                                            CONV_T_last         ;
    wire [(`DATA_WIDTH * `CONV_CORES)-1:0]          CONV_T_out          ; // {core n T_out} , ..... , {core 1 T_out}
    wire                                            CONV_max_mode_out   ;


    conv_block #(
        .DATA_WIDTH(`DATA_WIDTH),
        .CONV_UNITS(`CONV_UNITS),
        .CONV_PAIRS(`CONV_PAIRS)
    )CONV_BLOCK_DUT(
        .rstn           (aresetn),
        .clk            (aclk),

        .conv_mode      (CONV_conv_mode),
        .max_mode       (CONV_max_mode),
        .X_IN           (CONV_X_IN),
        .KERNEL         (CONV_KERNEL), 
        .r_rdy          (CONV_r_rdy),
        .l_valid        (CONV_l_valid),
        .ch_in          (CONV_ch_in),
        .im_width       (CONV_im_width),
        .num_blocks     (CONV_num_blocks),
        .BIAS           (CONV_BIAS),
        .l_rdy          (CONV_l_rdy),
        .r_valid        (CONV_r_valid),
        .finished       (CONV_finished),
        .T_out          (CONV_T_out),
        .max_mode_out   (CONV_max_mode_out),
        .T_last         (CONV_T_last)
    );

    wire                                   MAX_r_rdy        ;    
    wire                                   MAX_l_valid      ;   
    wire                                   MAX_T_last_in    ; 
    wire                                   MAX_mode         ;     
    wire [(`DATA_WIDTH*`CONV_CORES)-1:0]   MAX_d_in         ; 
    wire                                   MAX_r_valid      ;
    wire                                   MAX_l_rdy        ;   
    wire  [`DATA_WIDTH*`CONV_CORES-1:0]    MAX_T_out        ;
    wire                                   MAX_T_last_out   ;


    maxpool_block #(
        .DATA_WIDTH(`DATA_WIDTH),
        .CONV_UNITS(`CONV_UNITS),
        .CONV_CORES(`CONV_CORES)
    )MAXPOOL_BLOCK(
        .clk            (aclk),
        .rstn           (aresetn),

        .r_rdy          (MAX_r_rdy),
        .l_valid        (MAX_l_valid),
        .T_last_in      (MAX_T_last_in),
        .mode           (MAX_mode),
        .d_in           (MAX_d_in),
        .r_valid        (MAX_r_valid),
        .l_rdy          (MAX_l_rdy),
        .T_out          (MAX_T_out),
        .T_last_out     (MAX_T_last_out)
    );


    wire                                    OP_is_maxpool       ;
    wire                                    OP_is_3x3           ;
    wire [`CONV_PAIRS*2*`DATA_WIDTH-1:0]    OP_S_AXIS_tdata     ;
    wire                                    OP_S_AXIS_tvalid    ;
    wire                                    OP_S_AXIS_tready    ;

    wire [`OUTPUT_DMA_WIDTH-1:0]            OP_M_AXIS_tdata    ;
    wire                                    OP_M_AXIS_tvalid    ;
    wire                                    OP_M_AXIS_tlast    ;
    wire                                    OP_M_AXIS_tready    ;

    output_pipe #() output_dut (
    .aclk           (aclk),
    .aresetn        (aresetn),

    .is_maxpool     (OP_is_maxpool),
    .is_3x3         (OP_is_3x3),
    .S_AXIS_tdata   (OP_S_AXIS_tdata),
    .S_AXIS_tvalid  (OP_S_AXIS_tvalid),
    .S_AXIS_tready  (OP_S_AXIS_tready),
    
    .M_AXIS_tdata   (OP_M_AXIS_tdata),
    .M_AXIS_tvalid  (OP_M_AXIS_tvalid),
    .M_AXIS_tlast   (OP_M_AXIS_tlast),
    .M_AXIS_tready  (OP_M_AXIS_tready)
  );

    // wire                                    LRELU_M_AXIS_tready;
    wire                                    LRELU_S_AXIS_tvalid;
    wire                                    LRELU_S_AXIS_tlast;
    wire [(`DATA_WIDTH * `LReLU_UNITS)-1:0] LRELU_S_AXIS_tdata;
    wire                                    LRELU_S_AXIS_tready;

    LReLU_AXIS lrelu_dut(
    .aclk            (aclk),
    .aresetn         (aresetn),
    .en              (lrelu_en),

    .s_axis_tvalid   (LRELU_S_AXIS_tvalid),
    .s_axis_tdata    (LRELU_S_AXIS_tdata),
    .s_axis_tlast    (LRELU_S_AXIS_tlast),
    .s_axis_tready   (LRELU_S_AXIS_tready),

    .m_axis_tvalid   (LRELU_M_AXIS_tvalid),
    .m_axis_tready   (LRELU_M_AXIS_tready),
    .m_axis_tlast    (LRELU_M_AXIS_tlast),
    .m_axis_tdata    (LRELU_M_AXIS_tdata)
    );

  //* WEIGHT ROTATOR CONNECTIONS

  assign WR_din                     =   IP_M_W_ROTATOR_AXIS_tdata;
  assign WR_l_valid                 =   IP_M_W_ROTATOR_AXIS_tvalid;
  assign IP_M_W_ROTATOR_AXIS_tready =   WR_l_rdy;

  assign IP_S_W_ROTATOR_AXIS_tdata  =   WR_dout;
  assign IP_S_W_ROTATOR_AXIS_tvalid =   WR_r_valid;
  assign WR_r_rdy                   =   IP_S_W_ROTATOR_AXIS_tready;

  //* INPUT PIPE CONNECTIONS

  assign IP_is_maxpool  =   PIPES_is_maxpool;
//  assign IP_is_edges    =   PIPES_is_edges;
  assign IP_is_3x3      =  ~PIPES_conv_mode;

  //* CONV CONNECTION

  assign CONV_conv_mode     =   WR_conv_mode_out    ;   
  assign CONV_max_mode      =   WR_max_mode_out     ;    
  assign CONV_ch_in         =   WR_im_channels_out  ;       
  assign CONV_im_width      =   WR_im_width_out     ;    
  assign CONV_num_blocks    =   WR_im_blocks_out    ;  

  assign CONV_BIAS          =   WR_BIAS_out         ;     
  assign CONV_KERNEL        =   IP_weights          ;  
  assign CONV_X_IN          =   IP_image            ;  
  assign CONV_l_valid       =   IP_M_AXIS_tvalid    ;     
  assign IP_M_AXIS_tready   =   CONV_l_rdy;  

// assign CONV_finished      =   ;       

  //* MAX CONNECTION

  assign MAX_mode           =   CONV_max_mode_out;
  assign MAX_l_valid        =   CONV_r_valid;
  assign MAX_d_in           =   CONV_T_out;
  assign MAX_T_last_in      =   CONV_T_last;
  assign CONV_r_rdy         =   MAX_l_rdy;

  //* OUTPUT PIPE

  assign OP_is_maxpool      =   PIPES_is_maxpool;
  assign OP_is_3x3          =   ~PIPES_conv_mode;

  assign OP_S_AXIS_tdata    =   MAX_T_out;
  assign OP_S_AXIS_tvalid   =   MAX_r_valid;
  assign MAX_r_rdy          =   OP_S_AXIS_tready;

  //* LRELU CONNECTION

  assign LRELU_S_AXIS_tvalid = OP_M_AXIS_tvalid;
  assign LRELU_S_AXIS_tdata  = OP_M_AXIS_tdata;
  assign OP_M_AXIS_tready    = LRELU_S_AXIS_tready;
  assign LRELU_S_AXIS_tlast  = OP_M_AXIS_tlast;
  assign LRELU_M_AXIS_tkeep  = {OUTPUT_TKEEP_WIDTH{1'b1}};

endmodule