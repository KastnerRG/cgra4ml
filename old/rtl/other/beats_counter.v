`timescale 1ns / 1ps

module beats_counter #(
    AXIS_BYTES=4,
    COUNTER_BITS=32
    )(
    input aclk,
    input  s_axis_tvalid,
    output s_axis_tready,
    input  s_axis_tlast,
    input  [AXIS_BYTES*8-1:0] s_axis_tdata,
    input  [AXIS_BYTES-1  :0]s_axis_tkeep,
    
    output  m_axis_tvalid,
    input   m_axis_tready,
    output  m_axis_tlast,
    output  [AXIS_BYTES*8-1:0] m_axis_tdata,
    output  [AXIS_BYTES-1  :0] m_axis_tkeep,
    
    output reg [COUNTER_BITS-1:0] count=0,
    output valid
    );
    
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tdata  = s_axis_tdata;
    assign m_axis_tkeep  = s_axis_tkeep;
    assign m_axis_tlast  = s_axis_tlast;
    
    localparam WORK = 0;
    localparam DONE = 1;
     
    reg state = WORK; //work
    integer i;
    integer sum;
    always @(posedge aclk) begin
        if (state != DONE) begin
            if (s_axis_tready && s_axis_tvalid) begin:aa
                sum=0;
                for (i=0; i<AXIS_BYTES; i=i+1)
                    sum = sum + s_axis_tkeep[i];
                    
                count <= count + sum;
            end
        end
    end
    
    always @(posedge aclk)
        if (s_axis_tlast)
            state <= DONE;
    
    assign valid = (state == DONE);
    
endmodule
