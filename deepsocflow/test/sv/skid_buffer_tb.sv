`timescale 1ns/1ps

module skid_buffer_tb;

  localparam WORD_W=32, BUS_W=WORD_W, PROB_VALID=100, PROB_READY=70, NUM_DATA=((BUS_W/WORD_W)*200);

  logic aclk=0, aresetn;
  logic s_ready, s_valid, s_last;
  logic [BUS_W/WORD_W-1:0][WORD_W-1:0] s_data;
  logic [BUS_W/WORD_W-1:0]             s_keep;

  logic m_ready, m_valid, m_last;
  logic [BUS_W/WORD_W-1:0][WORD_W-1:0] m_data;
  logic [BUS_W/WORD_W-1:0]             m_keep;
  int file_in, file_out, status, value;
  localparam file_path_in  = "D:/axis_reg_in.txt";
  localparam file_path_out = "D:/axis_reg_out.txt";

  axis_pipeline_register #(BUS_W + BUS_W/WORD_W + 1, 3) dut (
    .s_data ({s_data, s_keep, s_last}),
    .m_data ({m_data, m_keep, m_last}),
    .*
  );

  initial forever #5 aclk = ~aclk;

 AXIS_Source #(.WORD_WIDTH(WORD_W), .BUS_WIDTH(BUS_W), .PROB_VALID(PROB_VALID), .FILE_PATH(file_path_in )) source (aclk, aresetn, s_ready, s_valid, s_last, s_data, s_keep);
 AXIS_Sink   #(.WORD_WIDTH(WORD_W), .BUS_WIDTH(BUS_W), .PROB_READY(PROB_READY), .FILE_PATH(file_path_out)) sink   (aclk, aresetn, m_ready, m_valid, m_last, m_data, m_keep);
  
  initial sink.axis_pull;
  initial begin
    file_in = $fopen(file_path_in, "w");
    for (int i=0; i<NUM_DATA; i++)
      $fdisplay(file_in, "%d", i);
    $fclose(file_in);
    source.axis_push;
  end


  initial begin
    $dumpfile ("axis_tb.vcd"); $dumpvars;

    aresetn = 0;
    repeat (5) @(posedge aclk); 
    aresetn = 1;


    while(!(m_valid && m_ready && m_last))
      @(posedge aclk);

    @(posedge aclk);

    file_out = $fopen(file_path_out, "r");
    for (int i=0; i<NUM_DATA; i++) begin
      status = $fscanf(file_out,"%d\n", value);
      assert (value == i) else $error("Output does not match");
    end

    $finish();
  end

endmodule