`timescale 1ns / 1ps

module dwidth_converter_tb # ();

    parameter CLK_PERIOD            = 10;
    parameter IN_BYTES              = 24;
    parameter OUT_BYTES             = 4;
    parameter DATA_WIDTH            = 8;

    reg                                aclk          = 0; 
    reg                                aresetn       = 0; 
    reg                                s_axis_tvalid = 0; 
    wire                               s_axis_tready    ; 
    wire  [DATA_WIDTH * IN_BYTES-1 :0] s_axis_tdata     ; 
    reg   [IN_BYTES             -1 :0] s_axis_tkeep  = 0; 
    reg                                s_axis_tlast  = 0; 
    wire                               m_axis_tvalid    ; 
    reg                                m_axis_tready = 1; 
    wire  [DATA_WIDTH *OUT_BYTES-1 :0] m_axis_tdata     ; 
    wire  [OUT_BYTES            -1 :0] m_axis_tkeep     ; 
    wire                               m_axis_tlast     ; 
    
    reg   [DATA_WIDTH           -1 :0] s_data  [IN_BYTES -1 :0] = '{default:'0}; 
    wire  [DATA_WIDTH           -1 :0] m_data  [OUT_BYTES-1 :0]; 

    axis_dwidth_converter_0 dw (
        .aclk           (aclk           ),                    
        .aresetn        (aresetn        ),              
        .s_axis_tvalid  (s_axis_tvalid  ),  
        .s_axis_tready  (s_axis_tready  ),  
        .s_axis_tdata   (s_axis_tdata   ),    
        .s_axis_tkeep   (s_axis_tkeep   ),    
        .s_axis_tlast   (s_axis_tlast   ),    
        .m_axis_tvalid  (m_axis_tvalid  ),  
        .m_axis_tready  (m_axis_tready  ),  
        .m_axis_tdata   (m_axis_tdata   ),    
        .m_axis_tkeep   (m_axis_tkeep   ),    
        .m_axis_tlast   (m_axis_tlast   )     
    );

    genvar i;
    generate
        for(i=0; i<IN_BYTES; i=i+1) begin: s
            assign s_axis_tdata[DATA_WIDTH*(i+1)-1  :DATA_WIDTH*i   ] = s_data[i];
        end

        for(i=0; i<OUT_BYTES; i=i+1)  begin: m
            assign m_data[i] = m_axis_tdata[DATA_WIDTH*(i+1)-1 : DATA_WIDTH*i];
        end
    endgenerate

    always begin
        #(CLK_PERIOD/2);
        aclk <= ~aclk;
    end

    integer n = 0;
    integer k = 0;

    initial begin
        @(posedge aclk);
        #(CLK_PERIOD*3)
        aresetn                 <= 1;

        #(CLK_PERIOD*3)
        @(posedge aclk);

        // while (!m_axis_tready)
        //     @(posedge aclk);

        #(CLK_PERIOD*10)
        @(posedge aclk);

        s_axis_tvalid <= 1;

        for (k = 0; k < IN_BYTES; k = k+1) begin
            s_data[k]       = k;
            s_axis_tkeep[k] = 1;
        end
        @(posedge aclk);
        s_axis_tvalid <= 0;
        for (k = 0; k < IN_BYTES; k = k+1) begin
            s_data[k]       = 0;
            s_axis_tkeep[k] = 0;
        end

        #(CLK_PERIOD*10)
        @(posedge aclk);

        @(posedge aclk);
        s_axis_tvalid <= 1;
        for (k = 0; k < IN_BYTES; k = k+1) begin
            s_data[k]       = k;
            if (k>15 && k<25)
                s_axis_tkeep[k] = 1;
            else
                s_axis_tkeep[k] = 0;
        end

        @(posedge aclk);
        s_axis_tvalid <= 0;
        for (k = 0; k < IN_BYTES; k = k+1) begin
            s_data[k]       = 0;
            s_axis_tkeep[k] = 0;
        end

    end

endmodule