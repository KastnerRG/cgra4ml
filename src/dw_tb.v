`timescale 1ns / 1ps

module dw_tb();
    parameter CLK_PERIOD        = 10;
    parameter DATA_WIDTH        = 16;
    parameter IMAGE_DMA_WIDTH   = 256;
    parameter IM_NUM            = IMAGE_DMA_WIDTH / DATA_WIDTH;
    parameter NUM_CYCLES        = 100;

    reg     aclk        = 0;
    reg     aresetn     = 0;
    reg                         dw_0_10_s_tvalid;
    wire                        dw_0_10_s_tready;
    reg  [IMAGE_DMA_WIDTH-1:0]  dw_0_10_s_tdata;
    wire                        dw_0_10_m_tvalid;
    reg                         dw_0_10_m_tready;
    wire [10*Nb-1:0]            dw_0_10_m_tdata;
    axis_dw_0_10 DW_0_10 (
    .aclk(aclk),                    // input wire aclk
    .aresetn(aresetn),              // input wire aresetn
    .s_axis_tvalid  (dw_0_10_s_tvalid),  // input wire s_axis_tvalid
    .s_axis_tready  (dw_0_10_s_tready),  // output wire s_axis_tready
    .s_axis_tdata   (dw_0_10_s_tdata),    // input wire  s_axis_tdata
    .m_axis_tvalid  (dw_0_10_m_tvalid),  // output wire m_axis_tvalid
    .m_axis_tready  (dw_0_10_m_tready),  // input wire m_axis_tready
    .m_axis_tdata   (dw_0_10_m_tdata)    // output wire  m_axis_tdata
    );

    reg     [DATA_WIDTH-1:0]   im_dma_0_data    [IM_NUM-1:0];
    wire    [DATA_WIDTH-1:0]   image_out        [19      :0];

    genvar j;
    generate
        for (j=0; j < IM_NUM; j=j+1) begin: connect_images
            assign dw_0_10_s_tdata    [(j+1)*DATA_WIDTH-1 : j*DATA_WIDTH] = im_dma_0_data[j];
        end
        for (j=0; j < 20    ; j=j+1) begin: connect_image_out
            assign image_out    [j] = image[(j+1)*DATA_WIDTH-1 : j*DATA_WIDTH];
        end
    endgenerate

    integer i;
    integer k;

    always begin
        #(CLK_PERIOD/2);
        aclk <= ~aclk;
    end

    always @(posedge aclk) begin
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
        is_maxpool  <= 0;
        is_edges    <= 0;
        is_3x3      <= 1;

        dw_0_10_m_tready        <= 1;
        dw_0_10_s_tvalid        <= 1;
    
        for (k=0; k < NUM_CYCLES; k=k+1) begin
            @(posedge aclk);
            for (i=0; i < IM_NUM; i=i+1) begin
                while(~dw_0_10_s_tready) begin
                   @(posedge aclk);
                end
                im_dma_0_data[i] <= k*IM_NUM + i;
            end
        end
    end

endmodule