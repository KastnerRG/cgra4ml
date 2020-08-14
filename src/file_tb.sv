`timescale 1ns / 1ps

module file_tb();
    parameter CLK_PERIOD = 10;
    reg aclk             = 0;
    reg [15:1] data      = 0;

    integer test_file, status;

    always begin
        #(CLK_PERIOD/2);
        aclk <= ~aclk;
    end

    initial begin
        test_file = $fopen("D:/Vision Traffic/soc/mem_yolo/txt/123.txt","r");

        while(1) begin
            @(posedge aclk)
            status = $fscanf(test_file,"%d\n",data);

            if ($feof(test_file)) begin
                $fclose(test_file);
                test_file = $fopen("D:/Vision Traffic/soc/mem_yolo/txt/123.txt","r");
            end
        end
    end
endmodule