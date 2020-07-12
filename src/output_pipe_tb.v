`include "system_parameters.v"
`timescale 1ns / 1ps

module output_pipe_tb();
  parameter CLK_PERIOD = 10;
  parameter NUM_CYCLES = 100;
  parameter PACKET_SIZE = 8;

  reg aclk = 0;
  reg aresetn = 0;

  reg is_maxpool = 0;
  reg is_3x3 = 0;

  // AXIS reg
  wire [`CONV_CORES*`DATA_WIDTH-1:0]  S_AXIS_tdata;
  reg S_AXIS_tvalid = 0;
  reg S_AXIS_tlast  = 0;
  wire S_AXIS_tready;

  // AXIS output
  wire [`OUTPUT_DMA_WIDTH-1:0]  M_AXIS_tdata;
  wire M_AXIS_tvalid;
  wire M_AXIS_tlast;
  reg  M_AXIS_tready  = 0;

  reg  [`DATA_WIDTH-1:0] data_in  [`CONV_CORES-1:0];
  wire [`DATA_WIDTH-1:0] data_out [`OUTPUT_DMA_WIDTH/`DATA_WIDTH-1:0]; 

  genvar j;
  generate
    for (j=0; j < `CONV_CORES; j=j+1) begin: connect_input_cores
       assign S_AXIS_tdata[(j+1)*`DATA_WIDTH-1: j*`DATA_WIDTH] = data_in[j];
    end
    for (j=0; j < `OUTPUT_DMA_WIDTH/`DATA_WIDTH; j=j+1) begin: connect_output_cores
      assign data_out[j]  = M_AXIS_tdata[(j+1)*`DATA_WIDTH-1: j*`DATA_WIDTH];
    end
  endgenerate


  output_pipe #() dut (
    .aclk(aclk),
    .aresetn(aresetn),

    .is_maxpool(is_maxpool),
    .is_3x3(is_3x3),

    // AXIS reg
    .S_AXIS_tdata(S_AXIS_tdata),
    .S_AXIS_tvalid(S_AXIS_tvalid),
    .S_AXIS_tlast(S_AXIS_tlast),
    .S_AXIS_tready(S_AXIS_tready),

    // AXIS output
    .M_AXIS_tdata(M_AXIS_tdata),
    .M_AXIS_tvalid(M_AXIS_tvalid),
    .M_AXIS_tlast(M_AXIS_tlast),
    .M_AXIS_tready(M_AXIS_tready)
  );

  integer i = 0;
  integer k = 0;
  integer l = 0;

  always begin
      #(CLK_PERIOD/2);
      aclk <= ~aclk;
  end

  initial begin
    @(posedge aclk);
    aresetn       <= 0;
    #(CLK_PERIOD*3)
    aresetn       <= 1;

    // Testing Image
    @(posedge aclk);
    is_3x3        <= 0;
    is_maxpool    <= 0;    

    M_AXIS_tready <= 1;

    while(k <NUM_CYCLES) begin
      for (l=0; l < PACKET_SIZE; l=l+1) begin
        @(posedge aclk);
        if(S_AXIS_tready) begin
          for (i=0; i < `CONV_CORES; i=i+1) begin
              S_AXIS_tvalid  <= 1;
              data_in[i] <= 10*i + l;
          end
          k <= k + 1;
        end else begin
          l = l-1;
        end
      end
    end
  end
  


endmodule