`timescale 1ns / 1ps

module axis_skid_reg_tb();

localparam CLK_PERIOD        = 100;
localparam DATA_WIDTH        = 8;

reg                     clk          = 0;
reg                     resetn       = 1;
reg                     input_valid  = 1;
reg [DATA_WIDTH-1 :0]   input_data   = 0;
reg                     output_ready = 0;

wire [DATA_WIDTH-1 :0]  output_data;
wire                    output_valid;
wire                    input_ready;


// axis_skid_reg
// #(
//     .WORD_WIDTH (DATA_WIDTH)
// )
// axis_skid_reg_dut
// (
//     .clock(clk),
//     .resetn(resetn),
//     .input_valid(input_valid),
//     .input_ready(input_ready),
//     .input_data(input_data),
//     .output_valid(output_valid),
//     .output_ready(output_ready),
//     .output_data(output_data)
// );

wire output_last;
axis_reg_slice axis_reg_slice_dut(
  .aclk(clk),
  .aresetn(resetn),
  .s_axis_tvalid(input_valid),
  .s_axis_tready(input_ready),
  .s_axis_tdata(input_data),
  .s_axis_tlast(1'b0),
  .m_axis_tvalid((output_valid)),
  .m_axis_tready(output_ready),
  .m_axis_tdata(output_data),
  .m_axis_tlast(output_last)
);

always begin
    #(CLK_PERIOD/2);
    clk <= ~clk;
end

integer k = 0;
integer n = 0;

initial begin
    @(posedge clk);
    resetn <= 0;
    #(CLK_PERIOD*3)
    resetn <= 1;

    #(CLK_PERIOD*3)

    while (n < 100) begin
        n <= n + 1;
        @(posedge clk);
        
        if (n > 30 && n <35) begin
            output_ready <= 0;
        end
        else begin
            output_ready <= 1;
        end
        
        if (n > 10 && n < 20)begin
           input_valid <= 0;
        end
        else if(input_ready) begin
            k <= k + 1;
            input_data <= k;
            input_valid <= 1;
        end
    end



end

endmodule