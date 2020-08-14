`timescale 1ns / 1ps

module float_tb # ();

    parameter CLK_PERIOD        = 10;
    parameter DATA_WIDTH        = 16;
    parameter TUSER_WIDTH       = 4;

    parameter ACCUMULATOR_DELAY = 19;
    parameter MULTIPLIER_DELAY  = 6;

    parameter F16_1             = 15360;
    parameter F16_2             = 16384;
    parameter F16_3             = 16896;
    parameter F16_4             = 17408;
    parameter F16_5             = 17664;

    parameter F16_6             = 17920;
    parameter F16_8             = 18432;
    parameter F16_12            = 18944;

    parameter F16_15            = 19328; // sum[1:5]
    parameter F16_26            = 20096; // sum[6,8,12]

    reg                         aclk          = 0; 
    reg                         aresetn       = 0; 
    reg                         aclken        = 1; 

    reg                         mul_a_axis_tvalid = 0; 
    wire                        mul_a_axis_tready    ; 
    reg   [DATA_WIDTH -1 :0]    mul_a_axis_tdata  = 0; 
    reg   [TUSER_WIDTH -1 :0]   mul_a_axis_tuser  = 0; 
    reg                         mul_a_axis_tlast  = 0; 
    
    reg                         mul_b_axis_tvalid = 0; 
    wire                        mul_b_axis_tready    ; 
    reg   [DATA_WIDTH -1 :0]    mul_b_axis_tdata  = 0; 
    wire  [TUSER_WIDTH -1 :0]   mul_b_axis_tuser     ; 


    wire                        mul_m_axis_tvalid    ; 
    reg                         mul_m_axis_tready = 1; 
    wire  [DATA_WIDTH -1 :0]    mul_m_axis_tdata     ; 
    wire  [TUSER_WIDTH -1 :0]   mul_m_axis_tuser     ; 
    wire                        mul_m_axis_tlast     ; 

    reg   [DATA_WIDTH -1 :0]    dum_mul_a_axis_tdata  = 0; 
    reg   [DATA_WIDTH -1 :0]    dum_mul_b_axis_tdata  = 0; 
    wire                        dum_mul_m_axis_tvalid    ; 
    wire  [DATA_WIDTH -1 :0]    dum_mul_m_axis_tdata     ; 
    wire  [TUSER_WIDTH -1 :0]   dum_mul_m_axis_tuser     ; 
    wire                        dum_mul_m_axis_tlast     ; 

    reg                         acc_s_axis_tvalid = 0; 
    wire                        acc_s_axis_tready    ; 
    reg   [DATA_WIDTH -1 :0]    acc_s_axis_tdata  = 0; 
    reg   [TUSER_WIDTH -1 :0]   acc_s_axis_tuser  = 0; 
    reg                         acc_s_axis_tlast  = 0; 
    wire                        acc_m_axis_tvalid    ; 
    reg                         acc_m_axis_tready = 1; 
    wire  [DATA_WIDTH -1 :0]    acc_m_axis_tdata     ; 
    wire  [TUSER_WIDTH -1 :0]   acc_m_axis_tuser     ; 
    wire                        acc_m_axis_tlast     ; 

    wire                        dum_acc_m_axis_tvalid    ; 
    reg   [DATA_WIDTH -1 :0]    dum_acc_s_axis_tdata  = 0; 
    wire  [DATA_WIDTH -1 :0]    dum_acc_m_axis_tdata     ; 
    wire  [TUSER_WIDTH -1 :0]   dum_acc_m_axis_tuser     ; 
    wire                        dum_acc_m_axis_tlast     ; 

    floating_point_accumulator acc (
        .aclk                   (aclk),                                 
        .aclken                 (aclken),                               
        .aresetn                (aresetn),                              
        .s_axis_a_tvalid        (acc_s_axis_tvalid),                      
        .s_axis_a_tdata         (acc_s_axis_tdata),                                
        .s_axis_a_tlast         (acc_s_axis_tlast),                       
        .s_axis_a_tuser         (acc_s_axis_tuser),                               
        .m_axis_result_tvalid   (acc_m_axis_tvalid),                  
        .m_axis_result_tdata    (acc_m_axis_tdata),                            
        .m_axis_result_tlast    (acc_m_axis_tlast),                    
        .m_axis_result_tuser    (acc_m_axis_tuser)                           
    );

    dummy_accumulator #(
        .ACCUMULATOR_DELAY(ACCUMULATOR_DELAY),
        .DATA_WIDTH(DATA_WIDTH),
        .TUSER_WIDTH(TUSER_WIDTH)
    )
    dummy_accumulator_unit
    (
        .aclk       (aclk),
        .aclken     (aclken),
        .aresetn    (aresetn),

        .valid_in   (acc_s_axis_tvalid),
        .data_in    (dum_acc_s_axis_tdata),
        .last_in    (acc_s_axis_tlast),
        .user_in    (acc_s_axis_tuser),
        .valid_out  (dum_acc_m_axis_tvalid),
        .data_out   (dum_acc_m_axis_tdata),
        .last_out   (dum_acc_m_axis_tlast),
        .user_out   (dum_acc_m_axis_tuser)
    );

    floating_point_multiplier mul (
        .aclk                   (aclk),                                            
        .aclken                 (aclken),                                          
        .aresetn                (aresetn),                                         
        .s_axis_a_tvalid        (mul_a_axis_tvalid  ),                                 
        .s_axis_a_tdata         (mul_a_axis_tdata   ),                                           
        .s_axis_a_tlast         (mul_a_axis_tlast   ),                                  
        .s_axis_a_tuser         (mul_a_axis_tuser   ),                                          
        .s_axis_b_tvalid        (mul_b_axis_tvalid  ),                                 
        .s_axis_b_tdata         (mul_b_axis_tdata   ),                                           
        .m_axis_result_tvalid   (mul_m_axis_tvalid  ),                             
        .m_axis_result_tdata    (mul_m_axis_tdata   ),                                       
        .m_axis_result_tlast    (mul_m_axis_tlast   ),                               
        .m_axis_result_tuser    (mul_m_axis_tuser   )                                      
    );

    dummy_multiplier #(
        .MULTIPLIER_DELAY(MULTIPLIER_DELAY),
        .DATA_WIDTH(DATA_WIDTH),
        .TUSER_WIDTH(TUSER_WIDTH)
    )
    dummy_multiplier_unit
    (
        .aclk       (aclk),
        .aclken     (aclken),
        .aresetn    (aresetn),

        .valid_in_1 (mul_a_axis_tvalid      ),
        .data_in_1  (dum_mul_a_axis_tdata   ),
        .last_in_1  (mul_a_axis_tlast       ),
        .user_in_1  (mul_a_axis_tuser       ),
        .valid_in_2 (mul_b_axis_tvalid      ),
        .data_in_2  (dum_mul_b_axis_tdata   ),
        .valid_out  (dum_mul_m_axis_tvalid  ),
        .data_out   (dum_mul_m_axis_tdata   ),
        .last_out   (dum_mul_m_axis_tlast   ),
        .user_out   (dum_mul_m_axis_tuser   )
    );

    always begin
        #(CLK_PERIOD/2);
        aclk <= ~aclk;
    end


    initial begin
        @(posedge aclk);
        #(CLK_PERIOD*5)
        @(posedge aclk);
        aresetn                 <= 1;
        #(CLK_PERIOD*7)

        @(posedge aclk);
        aclken <= 1;
        acc_s_axis_tvalid       <= 1;
        acc_s_axis_tdata        <= F16_1;
        dum_acc_s_axis_tdata    <= 1;
        acc_s_axis_tuser        <= 4'd1;
        
        @(posedge aclk);
        acc_s_axis_tvalid       <= 1;
        acc_s_axis_tdata        <= F16_2;
        dum_acc_s_axis_tdata    <= 2;
        acc_s_axis_tuser        <= 4'd2;

        @(posedge aclk);
        aclken <= 1;
        acc_s_axis_tvalid       <= 0;
        acc_s_axis_tdata        <= F16_15;
        dum_acc_s_axis_tdata    <= 15;
        acc_s_axis_tuser        <= 4'd15;
        @(posedge aclk);

        @(posedge aclk);
        acc_s_axis_tvalid       <= 1;
        acc_s_axis_tdata        <= F16_3;
        dum_acc_s_axis_tdata    <= 3;
        acc_s_axis_tuser        <= 4'd3;

        @(posedge aclk);
        acc_s_axis_tvalid       <= 1;
        acc_s_axis_tdata        <= F16_5;
        dum_acc_s_axis_tdata    <= 5;
        acc_s_axis_tuser        <= 4'd5;
        acc_s_axis_tlast        <= 1;

        @(posedge aclk);
        acc_s_axis_tvalid       <= 0;
        acc_s_axis_tdata        <= F16_6;
        dum_acc_s_axis_tdata    <= 6;
        acc_s_axis_tuser        <= 4'd6;
        acc_s_axis_tlast        <= 0;



        @(posedge aclk);
        mul_a_axis_tvalid       <= 1;
        mul_b_axis_tvalid       <= 0;
        mul_a_axis_tdata        <= F16_2;
        mul_b_axis_tdata        <= F16_3;
        mul_a_axis_tuser        <= 2;
        dum_mul_a_axis_tdata    <= 2;
        dum_mul_b_axis_tdata    <= 3;

        @(posedge aclk);
        mul_a_axis_tvalid       <= 0;
        mul_b_axis_tvalid       <= 0;

        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        mul_a_axis_tvalid       <= 1;
        mul_a_axis_tdata        <= F16_3;
        mul_a_axis_tuser        <= 3;
        dum_mul_a_axis_tdata    <= 3;
        @(posedge aclk);
        @(posedge aclk);

        @(posedge aclk);
        mul_b_axis_tvalid       <= 1;
        mul_b_axis_tdata        <= F16_4;
        dum_mul_b_axis_tdata    <= 4;
        mul_a_axis_tlast        <= 1;

        @(posedge aclk);
        mul_a_axis_tvalid       <= 0;
        mul_b_axis_tvalid       <= 0;
        mul_a_axis_tlast        <= 0;


    end


endmodule