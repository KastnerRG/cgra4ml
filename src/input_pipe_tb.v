`include "system_parameters.v"
`timescale 1ns / 1ps

module input_pipe_tb();
    parameter CLK_PERIOD = 10;
    parameter NUM_CYCLES = 100;

    parameter DATA_WIDTH = `DATA_WIDTH;
    parameter IMAGE_DMA_WIDTH = `IMAGE_DMA_WIDTH;
    parameter WEIGHTS_DMA_WIDTH = `WEIGHTS_DMA_WIDTH;
    parameter IM_NUM = IMAGE_DMA_WIDTH   / DATA_WIDTH;
    parameter W_NUM  = WEIGHTS_DMA_WIDTH / DATA_WIDTH;

    parameter CONV_PAIRS = `CONV_PAIRS;
    parameter CONV_UNITS = `CONV_UNITS;

    parameter CONV_CORES   = CONV_PAIRS*2;
    parameter Nb           = CONV_CORES*DATA_WIDTH;

    reg     aclk        = 0;
    reg     aresetn     = 0;
    reg     is_maxpool  = 0;
    reg     is_edges    = 0;
    reg     is_3x3      = 0;
    wire    [WEIGHTS_DMA_WIDTH-1:0]             S_W_DMA_AXIS_tdata;
    reg                                         S_W_DMA_AXIS_tvalid = 0;
    wire                                        S_W_DMA_AXIS_tready;
    wire    [IMAGE_DMA_WIDTH-1:0]               S_IM_DMA_0_AXIS_tdata;
    reg                                         S_IM_DMA_0_AXIS_tvalid = 0;
    wire                                        S_IM_DMA_0_AXIS_tready;
    wire    [IMAGE_DMA_WIDTH-1:0]               S_IM_DMA_1_AXIS_tdata;
    reg                                         S_IM_DMA_1_AXIS_tvalid = 0;
    wire                                        S_IM_DMA_1_AXIS_tready;
    wire    [2*DATA_WIDTH-1:0]                  S_EDGE_AXIS_tdata;
    reg                                         S_EDGE_AXIS_tvalid = 0;
    wire                                        S_EDGE_AXIS_tready;
    wire    [3*Nb-1:0]                          M_W_ROTATOR_AXIS_tdata;
    wire                                        M_W_ROTATOR_AXIS_tvalid;
    reg                                         M_W_ROTATOR_AXIS_tready = 0;
    reg     [3*Nb-1:0]                          S_W_ROTATOR_AXIS_tdata = 0;
    reg                                         S_W_ROTATOR_AXIS_tvalid = 0;
    wire                                        S_W_ROTATOR_AXIS_tready;
    reg                                         M_AXIS_tready = 0;
    wire                                        M_AXIS_tvalid;
    wire    [(9*Nb)-1:0]                        weights;
    wire    [2*(CONV_UNITS+2)*DATA_WIDTH-1:0]   image;

    reg     [DATA_WIDTH-1:0]   w_dma_data       [ W_NUM-1:0];
    reg     [DATA_WIDTH-1:0]   im_dma_0_data    [IM_NUM-1:0];
    reg     [DATA_WIDTH-1:0]   im_dma_1_data    [IM_NUM-1:0];
    reg     [DATA_WIDTH-1:0]   edges_data       [1:0];

    wire    [DATA_WIDTH-1:0]   image_out           [2*(CONV_UNITS+2)-1  :0];
    wire    [DATA_WIDTH-1:0]   weights_out         [9*CONV_CORES-1      :0];

    genvar j;
    generate
        for (j=0; j < W_NUM; j=j+1) begin: connect_weights
            assign S_W_DMA_AXIS_tdata       [(j+1)*DATA_WIDTH-1 : j*DATA_WIDTH] = w_dma_data[j];
        end
        for (j=0; j < IM_NUM; j=j+1) begin: connect_images
            assign S_IM_DMA_0_AXIS_tdata    [(j+1)*DATA_WIDTH-1 : j*DATA_WIDTH] = im_dma_0_data[j];
            assign S_IM_DMA_1_AXIS_tdata    [(j+1)*DATA_WIDTH-1 : j*DATA_WIDTH] = im_dma_1_data[j];
        end
        for (j=0; j < 2; j=j+1) begin: connect_edges
            assign S_EDGE_AXIS_tdata    [(j+1)*DATA_WIDTH-1 : j*DATA_WIDTH] = edges_data[j];
            assign S_EDGE_AXIS_tdata    [(j+1)*DATA_WIDTH-1 : j*DATA_WIDTH] = edges_data[j];
        end
        for (j=0; j < 2*(CONV_UNITS+2); j=j+1) begin: connect_image_out
            assign image_out    [j] = image[(j+1)*DATA_WIDTH-1 : j*DATA_WIDTH];
        end
        for (j=0; j <     9*CONV_CORES; j=j+1) begin: connect_weights_out
            assign weights_out  [j] = weights[(j+1)*DATA_WIDTH-1 : j*DATA_WIDTH];
        end
    endgenerate

    input_pipe #(
        .IMAGE_DMA_WIDTH(IMAGE_DMA_WIDTH),
        .WEIGHTS_DMA_WIDTH(WEIGHTS_DMA_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .CONV_PAIRS(CONV_PAIRS),
        .CONV_UNITS(CONV_UNITS)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .is_maxpool(is_maxpool),
        .is_3x3(is_3x3),
        .is_edges(is_edges),
        .S_W_DMA_AXIS_tdata(S_W_DMA_AXIS_tdata),
        .S_W_DMA_AXIS_tvalid(S_W_DMA_AXIS_tvalid),
        .S_W_DMA_AXIS_tready(S_W_DMA_AXIS_tready),
        .S_IM_DMA_0_AXIS_tdata(S_IM_DMA_0_AXIS_tdata),
        .S_IM_DMA_0_AXIS_tvalid(S_IM_DMA_0_AXIS_tvalid),
        .S_IM_DMA_0_AXIS_tready(S_IM_DMA_0_AXIS_tready),
        .S_IM_DMA_1_AXIS_tdata(S_IM_DMA_1_AXIS_tdata),
        .S_IM_DMA_1_AXIS_tvalid(S_IM_DMA_1_AXIS_tvalid),
        .S_IM_DMA_1_AXIS_tready(S_IM_DMA_1_AXIS_tready),
        .S_EDGE_AXIS_tdata(S_EDGE_AXIS_tdata),
        .S_EDGE_AXIS_tvalid(S_EDGE_AXIS_tvalid),
        .S_EDGE_AXIS_tready(S_EDGE_AXIS_tready),
        .S_W_ROTATOR_AXIS_tdata(S_W_ROTATOR_AXIS_tdata),
        .S_W_ROTATOR_AXIS_tvalid(S_W_ROTATOR_AXIS_tvalid),
        .S_W_ROTATOR_AXIS_tready(S_W_ROTATOR_AXIS_tready),
        .M_W_ROTATOR_AXIS_tdata(M_W_ROTATOR_AXIS_tdata),
        .M_W_ROTATOR_AXIS_tvalid(M_W_ROTATOR_AXIS_tvalid),
        .M_W_ROTATOR_AXIS_tready(M_W_ROTATOR_AXIS_tready),
        .M_AXIS_tready(M_AXIS_tready),
        .M_AXIS_tvalid(M_AXIS_tvalid),
        .weights(weights),
        .image(image)
    );
    
    integer i = 0;
    integer k = 0;
    integer l = 0;
    integer m = 0;
    integer n = 0;

    always begin
        #(CLK_PERIOD/2);
        aclk <= ~aclk;
    end

    always @(*) begin
        S_W_ROTATOR_AXIS_tdata  <= M_W_ROTATOR_AXIS_tdata;
        S_W_ROTATOR_AXIS_tvalid <= M_W_ROTATOR_AXIS_tvalid;
        M_W_ROTATOR_AXIS_tready <= S_W_ROTATOR_AXIS_tready;
    end

    initial begin
        @(posedge aclk);
        aresetn   <= 0;
        #(CLK_PERIOD*3)
        aresetn   <= 1;

        // Testing Image
        @(posedge aclk);
        is_3x3      <= 0;
        is_maxpool  <= 0;
        is_edges    <= 1;
        

        M_AXIS_tready           <= 1;

        while(k <NUM_CYCLES) begin
            @(posedge aclk);
            if(S_W_DMA_AXIS_tready) begin
                for (i=0; i < W_NUM; i=i+1) begin
                    S_W_DMA_AXIS_tvalid  <= 1;
                    w_dma_data[i] <= n*W_NUM + i;
                end
                n <= n + 1;
            end
            if(S_IM_DMA_0_AXIS_tready) begin
                for (i=0; i < IM_NUM; i=i+1) begin
                    S_IM_DMA_0_AXIS_tvalid  <= 1;
                    im_dma_0_data[i] <= k*IM_NUM + i;
                end
                k <= k + 1;
            end
            if(S_IM_DMA_1_AXIS_tready) begin
                for (i=0; i < IM_NUM; i=i+1) begin
                    S_IM_DMA_1_AXIS_tvalid  <= 1;
                    im_dma_0_data[i] <= m*IM_NUM + i;
                    im_dma_1_data[i] <= m*IM_NUM + i + 100;
                end
                m <= m + 1;
            end
            if(S_EDGE_AXIS_tready) begin
                edges_data[0]       <= l + 200;
                edges_data[1]       <= l + 300;
                S_EDGE_AXIS_tvalid  <= 1;
                l <= l + 1;
            end
        end
    
    end


endmodule