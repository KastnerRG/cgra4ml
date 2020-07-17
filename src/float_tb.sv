`timescale 1ns / 1ps

module float_tb # ();

    parameter CLK_PERIOD        = 10;
    parameter DATA_WIDTH        = 16;
    parameter TUSER_WIDTH       = 4;

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
    wire  [TUSER_WIDTH -1 :0]   mul_a_axis_tuser     ; 
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

    reg                         acc_s_axis_tvalid = 0; 
    wire                        acc_s_axis_tready    ; 
    reg   [DATA_WIDTH -1 :0]    acc_s_axis_tdata  = 0; 
    wire  [TUSER_WIDTH -1 :0]   acc_s_axis_tuser     ; 
    reg                         acc_s_axis_tlast  = 0; 
    wire                        acc_m_axis_tvalid    ; 
    reg                         acc_m_axis_tready = 1; 
    wire  [DATA_WIDTH -1 :0]    acc_m_axis_tdata     ; 
    wire  [TUSER_WIDTH -1 :0]   acc_m_axis_tuser     ; 
    wire                        acc_m_axis_tlast     ; 

    floating_point_accumulator acc (
        .aclk                   (aclk),                                 
        .aclken                 (aclken),                               
        .aresetn                (aresetn),                              
        .s_axis_a_tvalid        (acc_s_axis_tvalid),                      
        .s_axis_a_tdata         (acc_s_axis_tdata),                                
        .s_axis_a_tuser         (acc_s_axis_tuser),                               
        .s_axis_a_tlast         (acc_s_axis_tlast),                       
        .m_axis_result_tvalid   (acc_m_axis_tvalid),                  
        .m_axis_result_tdata    (acc_m_axis_tdata),                            
        .m_axis_result_tuser    (acc_m_axis_tuser),                           
        .m_axis_result_tlast    (acc_m_axis_tlast)                    
    );

    floating_point_multiplier mul (
        .aclk                   (aclk),                                            
        .aclken                 (aclken),                                          
        .aresetn                (aresetn),                                         
        .s_axis_a_tvalid        (mul_a_axis_tvalid),                                 
        .s_axis_a_tdata         (mul_a_axis_tdata),                                           
        .s_axis_a_tuser         (mul_a_axis_tuser),                                          
        .s_axis_a_tlast         (mul_a_axis_tlast),                                  
        .s_axis_b_tvalid        (mul_b_axis_tvalid),                                 
        .s_axis_b_tdata         (mul_b_axis_tdata),                                           
        .m_axis_result_tvalid   (mul_m_axis_tvalid),                             
        .m_axis_result_tdata    (mul_m_axis_tdata),                                       
        .m_axis_result_tuser    (mul_m_axis_tuser),                                      
        .m_axis_result_tlast    (mul_m_axis_tlast)                               
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
        aclken <= 0;
        acc_s_axis_tvalid  <= 1;
        acc_s_axis_tdata   <= F16_1;
        
        @(posedge aclk);
        acc_s_axis_tvalid  <= 1;
        acc_s_axis_tdata   <= F16_2;

        @(posedge aclk);
        aclken <= 1;
        acc_s_axis_tvalid  <= 0;
        acc_s_axis_tdata   <= F16_15;
        @(posedge aclk);

        @(posedge aclk);
        acc_s_axis_tvalid  <= 1;
        acc_s_axis_tdata   <= F16_3;

        @(posedge aclk);
        acc_s_axis_tvalid  <= 1;
        acc_s_axis_tdata   <= F16_5;
        acc_s_axis_tlast   <= 1;

        @(posedge aclk);
        acc_s_axis_tvalid  <= 0;
        acc_s_axis_tdata   <= F16_6;
        acc_s_axis_tlast   <= 0;



        @(posedge aclk);
        mul_a_axis_tvalid  <= 1;
        mul_b_axis_tvalid  <= 0;
        mul_a_axis_tdata   <= F16_2;
        mul_b_axis_tdata   <= F16_3;

        @(posedge aclk);
        mul_a_axis_tvalid  <= 0;
        mul_b_axis_tvalid  <= 0;

        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        @(posedge aclk);
        mul_a_axis_tvalid  <= 1;
        mul_a_axis_tdata   <= F16_3;
        @(posedge aclk);
        @(posedge aclk);

        @(posedge aclk);
        mul_b_axis_tvalid  <= 1;
        mul_b_axis_tdata   <= F16_4;
        mul_a_axis_tlast   <= 1;

        @(posedge aclk);
        mul_a_axis_tvalid  <= 0;
        mul_b_axis_tvalid  <= 0;
        mul_a_axis_tlast   <= 0;


    end


endmodule