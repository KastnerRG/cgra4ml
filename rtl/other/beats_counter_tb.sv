`timescale 1ns / 1ps

module beats_counter_tb();
    logic aclk;
    initial begin
        aclk = 0;
        forever #5 aclk <= ~aclk;
    end
    
    localparam AXIS_BYTES = 24;
    localparam COUNTER_BITS = 32;
    
    logic aclk, s_axis_tvalid, m_axis_tready, s_axis_tlast, s_axis_valid;
    logic m_axis_tvalid, s_axis_tready, m_axis_tlast;
    logic [AXIS_BYTES*8-1:0] s_axis_tdata, m_axis_tdata;
    logic [AXIS_BYTES-1  :0] s_axis_tkeep, m_axis_tkeep;
    logic [COUNTER_BITS-1:0] count;
    logic valid;
    
    beats_counter #(.AXIS_BYTES(AXIS_BYTES), .COUNTER_BITS(COUNTER_BITS))dut (.*);
    
    initial begin
        s_axis_tvalid <= 0;
        m_axis_tready <= 0;
        s_axis_tlast  <= 0;
        s_axis_tkeep  <= 0;
        
        @(posedge aclk);
        #1
        s_axis_tvalid <= 1;
        
        @(posedge aclk);
        #1
        m_axis_tready <= 1;
        s_axis_tkeep  <= '1;
        s_axis_tlast  <= 1;
        
        @(posedge aclk);
        #1
        s_axis_tvalid <= 0;
        
//        @(posedge aclk);
//        #1
//        s_axis_tvalid <= 1;
//        s_axis_tkeep  <= 1;
        
        repeat(5) @(posedge aclk);
        
//        s_axis_tlast <= 1;
        @(posedge aclk);
        #1
        s_axis_tvalid <= 0;
        s_axis_tlast  <= 0;
        
        repeat(5) @(posedge aclk);
        #1
        s_axis_tkeep  <= 3;
        s_axis_tvalid <= 1;
        
    end
endmodule
