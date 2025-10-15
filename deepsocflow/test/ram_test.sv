module ram_test;

  parameter WIDTHA = 32;
  parameter SIZEA = 512;
  parameter ADDRWIDTHA = 9;

  parameter WIDTHB = 256;
  parameter SIZEB = 64;
  parameter ADDRWIDTHB = 6;

  logic clkA, aclk=0;
  logic clkB;
  logic weA=0;
  logic enaA=0, enaB=0;
  logic [ADDRWIDTHA-1:0] addrA='0;
  logic [ADDRWIDTHB-1:0] addrB='0;
  logic [WIDTHA-1:0] diA='0;
  logic [WIDTHB-1:0] doB='0;
    
    asym_ram_sdp_read_wider #(
        .WIDTHA(WIDTHA),
        .SIZEA(SIZEA),
        .ADDRWIDTHA(ADDRWIDTHA),
        .WIDTHB(WIDTHB),
        .SIZEB(SIZEB),
        .ADDRWIDTHB(ADDRWIDTHB)
    ) dut (
        .clkA(aclk),
        .clkB(aclk),
        .weA(weA),
        .enaA(enaA),
        .enaB(enaB),
        .addrA(addrA),
        .addrB(addrB),
        .diA(diA),
        .doB(doB)
    );
    //---------------------------------------------------------------------------//
    // Clock Generation
    //---------------------------------------------------------------------------//
    initial forever begin
        #(CLK_PERIOD/2) aclk <= ~aclk;
    end



    //---------------------------------------------------------------------------//
    // Stimulus Process
    //---------------------------------------------------------------------------//
    initial begin
        @(posedge aclk);
        enaA <= 1'b1;
        weA <= 1'b1;
        addrA <= 9'b0_0000_0000;
        diA <= 32'h0000_0453;

        @(posedge aclk);
        addrA <= 9'b0_0000_0001;
        diA <= 32'h0000_F000;
    
        @(posedge aclk);
        addrA <= 9'b0_0000_0010;
        diA <= 32'h000F_0453;
    
        @(posedge aclk);
        addrA <= 9'b0_0000_0011;
        diA <= 32'h00F0_0453;
    
        @(posedge aclk);
        addrA <= 9'b0_0000_0100;
        diA <= 32'h0F00_0453;
    
        @(posedge aclk);
        addrA <= 9'b0_0000_0101;
        diA <= 32'hF000_0453;
    
        @(posedge aclk);
        addrA <= 9'b0_0000_0110;
        diA <= 32'h000F_F453;
    
        @(posedge aclk);
        addrA <= 9'b0_0000_0111;
        diA <= 32'h00FF_F453;
    
        @(posedge aclk);
        enaA <= 1'b0;
        weA <= 1'b0;
        addrA <= 9'b0_0000_0000;
        diA <= 32'h0000_0000;

        enaB <= 1'b1;
        addrB <= 6'b00_0000;
    end
endmodule