`timescale 1ns / 1ps

module axis_conv_engine_tb # ();
    parameter CLK_PERIOD           = 10 ;
    parameter CONV_UNITS           =  8 ; 
    parameter DATA_WIDTH           = 16 ; 
    parameter KERNEL_W_MAX         =  3 ; 
    parameter KERNEL_H_MAX         =  3 ;   // odd number
    parameter TUSER_WIDTH          =  4 ; 
    parameter CIN_COUNTER_WIDTH    = 10 ;
    parameter COLS_COUNTER_WIDTH   = 10 ;
    parameter ONE                  = 1  ;     //15360 ;
    parameter ACCUMULATOR_DELAY    = 4  ;     //19 ; 
    parameter MULTIPLIER_DELAY     = 3  ;     // 6 ; 

    parameter INDEX_IS_1x1         =  0 ; 
    parameter INDEX_IS_MAX         =  1 ; 
    parameter INDEX_IS_RELU        =  2 ; 
    parameter INDEX_IS_COLS_1_K2   =  3 ; 

    parameter KERNEL_W             =  3 ;
    parameter KERNEL_H             =  3 ;
    parameter IS_MAX               =  0 ; 
    parameter IS_RELU              =  0 ;

    parameter HEIGHT               =  8 ;
    parameter WIDTH                =  4 ;
    parameter CIN                  =  3 ;   // 3 CIN + 1 > 2(A-1)-1 => CIN > 2(A-2)/3 => CIN > 2(19-2)/3 => CIN > 11.33 => CIN_min = 12
    

    string    im_in_path           = "D:/Vision Traffic/soc/mem_yolo/txt/1_im.txt";
    string    im_out_path          = "D:/Vision Traffic/soc/mem_yolo/txt/1_im_out_fpga.txt";
    string    weights_path         = "D:/Vision Traffic/soc/mem_yolo/txt/1_wb.txt";

    localparam BLOCKS              =  HEIGHT / CONV_UNITS;
    localparam KERNEL_W_WIDTH       = $clog2(KERNEL_W_MAX   + 1);
    localparam KERNEL_H_WIDTH       = $clog2(KERNEL_H_MAX   + 1);

    reg                           aclk                                               = 0;
    reg                           aclken                                             = 1;               
    reg                           aresetn                                            = 1;
                                                
    reg                           start                                              = 0;
    reg  [KERNEL_W_WIDTH-1:0]     kernel_w_1                                         = 0;
    reg  [KERNEL_H_WIDTH-1:0]     kernel_h_1                                         = 0;
    reg                           is_max                                             = 0;
    reg                           is_relu                                            = 0;
    reg  [COLS_COUNTER_WIDTH-1:0] cols_1                                             = 0;
    reg  [CIN_COUNTER_WIDTH -1:0] cin_1                                              = 0;

    reg                       pixels_s_valid                                         = 0;
    reg  [DATA_WIDTH  - 1: 0] pixels_s_data  [CONV_UNITS + (KERNEL_H_MAX-1) -1 : 0]  = '{default:0};
    wire                      pixels_s_ready                                            ;
    
    reg                       weights_s_valid                                        = 0;
    wire                      weights_s_ready                                           ;
    reg  [DATA_WIDTH  - 1: 0] weights_s_data [KERNEL_W_MAX - 1 : 0]                  = '{default:0};
                                                                                         
    wire                      m_valid                                                   ;
    wire [DATA_WIDTH  - 1: 0] m_data         [CONV_UNITS   - 1 : 0]                     ;
    wire                      m_last                                                    ;
    wire [TUSER_WIDTH - 1: 0] m_user                                                    ;
                                                                                         
    axis_conv_engine # (
        .CONV_UNITS           (CONV_UNITS        ) ,
        .DATA_WIDTH           (DATA_WIDTH        ) ,
        .KERNEL_W_MAX         (KERNEL_W_MAX      ) ,
        .KERNEL_H_MAX         (KERNEL_H_MAX      ) , // odd number
        .TUSER_WIDTH          (TUSER_WIDTH       ) ,
        .CIN_COUNTER_WIDTH    (CIN_COUNTER_WIDTH ) ,
        .COLS_COUNTER_WIDTH   (COLS_COUNTER_WIDTH) ,
        .ONE                  (ONE               ) ,
        .ACCUMULATOR_DELAY    (ACCUMULATOR_DELAY ) ,
        .MULTIPLIER_DELAY     (MULTIPLIER_DELAY  ) ,
        .INDEX_IS_1x1         (INDEX_IS_1x1      ) ,
        .INDEX_IS_MAX         (INDEX_IS_MAX      ) ,
        .INDEX_IS_RELU        (INDEX_IS_RELU     ) ,
        .INDEX_IS_COLS_1_K2   (INDEX_IS_COLS_1_K2)  
    )
    conv_engine_dut
    (
        .aclk            (aclk           ),
        .aclken          (aclken         ),
        .aresetn         (aresetn        ),

        .start           (start          ),
        .kernel_w_1      (kernel_w_1     ),
        .kernel_h_1      (kernel_h_1     ),
        .is_max          (is_max         ),
        .is_relu         (is_relu        ),
        .cols_1          (cols_1         ),
        .cin_1           (cin_1          ),

        .pixels_s_valid  (pixels_s_valid ),       
        .pixels_s_data   (pixels_s_data  ),   
        .pixels_s_ready  (pixels_s_ready ),

        .weights_s_valid (weights_s_valid),       
        .weights_s_data  (weights_s_data ),
        .weights_s_ready (weights_s_ready),

        .m_valid         (m_valid        ),
        .m_data          (m_data         ),
        .m_last          (m_last         ),
        .m_user          (m_user         )
    );

    integer m = 0;
    integer n = 0;
    integer status, file_im_out, file_im_in, file_weights;

    integer im_rotate_count    = 0;
    integer w_rotate_count     = 0;
    integer wb_beats_count     = 0;
    integer im_in_beats_count  = 0;
    integer im_out_beats_count = 0;

    bit done_feed = 0;

    initial begin
        file_im_in   = $fopen(im_in_path   ,"r");
        file_weights = $fopen(weights_path ,"r");
        file_im_out  = $fopen(im_out_path  ,"w");
    end

    // CLOCK GENERATION
    always begin
        #(CLK_PERIOD/2);
        aclk <= ~aclk;
    end

    // Save outputs to file
    always @ (posedge aclk) begin
        #(CLK_PERIOD/2);
        if (aclken && m_valid) begin
            im_out_beats_count = im_out_beats_count + 1;
            for (m=0; m < CONV_UNITS; m = m+1)
                $fdisplay(file_im_out, "%d", m_data[m]);
        end
    end

    /*
        Restart image file for every column & feed pixels
    */
    always @ (posedge aclk) begin
        #1;
        if (!done_feed) begin

            axis_feed_weights;

            if (status != 1 && $feof(file_weights)) begin

                    $fclose(file_weights);
                    file_weights = $fopen(weights_path,"r");

                    if (w_rotate_count == WIDTH * BLOCKS - 1) // One COUT done
                        w_rotate_count = 0;
                    else                                      // One col done
                        w_rotate_count = w_rotate_count + 1;

                    axis_feed_weights;
            end
        end
    end

    initial begin
        @(posedge aclk);
        #(CLK_PERIOD*3)
        @(posedge aclk);

        kernel_w_1              <=  KERNEL_W - 1;
        kernel_h_1              <=  KERNEL_H - 1;
        is_max                  <=  IS_MAX      ;
        is_relu                 <=  IS_RELU     ;
        cols_1                  <=  WIDTH    - 1;
        cin_1                   <=  CIN      - 1;

        aresetn                 <= 1;
        start                   <= 1;

        @(posedge aclk);
        start                   <= 0;
        @(posedge aclk);
        #(CLK_PERIOD*3);

        /*
            Restart image file for every output channel & feed pixels
        */
        while(1) begin
            @(posedge aclk);
            #1;

            axis_feed_pixels;

            if (status != 1 && $feof(file_im_in)) begin
                pixels_s_valid <= 0;
                break;
            end
        end

        /*
            Wait for all im_out beats to come out and close files
        */
        
        while(1) begin
            @(posedge aclk);
            if (im_out_beats_count > WIDTH * BLOCKS - 1)
                break;
        end

        $fclose(file_im_in);
        $fclose(file_weights);
        $fclose(file_im_out);
        done_feed = 1;

    end
    
    /*
    Feed weights according to AXIS protocol
    */
    task axis_feed_weights;
    begin
        if (weights_s_ready) begin
            weights_s_valid <= 1;
            wb_beats_count = wb_beats_count + 1;
            for (m=0; m < KERNEL_W_MAX; m = m+1)
                status = $fscanf(file_weights,"%d\n",weights_s_data[m]);
        end
        else begin
            for (m=0; m < KERNEL_W_MAX; m = m+1)
                weights_s_data[m] <= weights_s_data[m];    
        end
    end
    endtask

    /*
    Feed pixels according to AXIS protocol
    */
    task axis_feed_pixels;
    begin
        if (pixels_s_ready) begin
            pixels_s_valid      <= 1;
            im_in_beats_count   = im_in_beats_count + 1;

            for (m=0; m < CONV_UNITS + (KERNEL_H_MAX-1); m = m+1)
                status = $fscanf(file_im_in,"%d\n",pixels_s_data[m]);
                
        end
        else begin
            for (m=0; m < CONV_UNITS + (KERNEL_H_MAX-1); m = m+1)
                pixels_s_data[m] <= pixels_s_data[m];
        end
    end
    endtask

endmodule