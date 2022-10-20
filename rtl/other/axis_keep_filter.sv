`include "params.v"

module axis_keep_filter (
  aclk             ,
  aresetn          ,

  s_axis_tdata     ,
  s_axis_tvalid    ,
  s_axis_tready    ,
  s_axis_tlast     ,
  s_axis_tuser     ,
  s_axis_tkeep     ,
  s_axis_kw_1      ,

  m_axis_tdata     ,
  m_axis_tvalid    ,
  m_axis_tready    ,
  m_axis_tlast     ,
  m_axis_tkeep     ,
  m_axis_tuser
);

  localparam IS_CONV_DW_SLICE     = `IS_CONV_DW_SLICE     ;
  localparam UNITS                = `UNITS                ;
  localparam GROUPS               = `GROUPS               ;
  localparam COPIES               = `COPIES               ;
  localparam MEMBERS              = `MEMBERS              ;
  localparam KERNEL_W_MAX         = `KERNEL_W_MAX         ;
  localparam WORD_WIDTH           = `WORD_WIDTH_ACC       ;
  localparam TUSER_WIDTH_LRELU_IN = `TUSER_WIDTH_LRELU_IN ; 

  localparam WORD_BYTES = WORD_WIDTH/8;
  localparam BITS_KERNEL_W = $clog2(KERNEL_W_MAX);

  input logic aclk, aresetn;

  input  logic s_axis_tvalid, s_axis_tlast;
  output logic s_axis_tready;
  input  logic [COPIES*GROUPS-1:0][MEMBERS-1:0][UNITS*WORD_WIDTH     -1:0] s_axis_tdata;
  input  logic [COPIES*GROUPS-1:0][MEMBERS-1:0][UNITS*WORD_BYTES     -1:0] s_axis_tkeep;
  input  logic                    [MEMBERS*TUSER_WIDTH_LRELU_IN      -1:0] s_axis_tuser;
  input  logic [BITS_KERNEL_W-1:0] s_axis_kw_1;

  output logic m_axis_tvalid, m_axis_tlast;
  input  logic m_axis_tready;
  output logic [COPIES*GROUPS-1:0][MEMBERS-1:0][UNITS*WORD_WIDTH     -1:0] m_axis_tdata;
  output logic [COPIES*GROUPS-1:0][MEMBERS-1:0][UNITS*WORD_BYTES     -1:0] m_axis_tkeep;
  output logic                    [MEMBERS*TUSER_WIDTH_LRELU_IN      -1:0] m_axis_tuser;

  logic reg_en, state, state_next;
  logic [COPIES*GROUPS-1:0][MEMBERS-1:0][UNITS*WORD_BYTES-1:0] m_keep_raw;
  logic [MEMBERS-1:0] m_keep_mask_next, m_keep_mask;
  logic [BITS_KERNEL_W-1:0] count_next, count, s_axis_kw_1_reg;

  /*
   STATE MACHINE

   When s_valid & s_ready, accept data beat into regs and block (s_ready=0, s_valid=1), then count down
  */

  localparam PASS_S  = 0;
  localparam BLOCK_S = 1;
  localparam BITS_STATE = 1;

  always_comb begin
    state_next = state;
    case (state)
      PASS_S  : if (s_axis_tvalid && s_axis_tready) state_next = BLOCK_S;
      BLOCK_S : if (~m_keep_raw [0][count_next][0]) state_next = PASS_S ;
    endcase
  end
 
  register #(
    .WORD_WIDTH     (1),
    .RESET_VALUE    (0)         
  ) STATE (
    .clock          (aclk   ),
    .clock_enable   (1'b1   ),
    .resetn         (aresetn),
    .data_in        (state_next  ),
    .data_out       (state       )
  );

  always_comb begin
    unique case (state)
      PASS_S  : begin
                  s_axis_tready = m_axis_tready;
                  count_next    = s_axis_kw_1;
                end
      BLOCK_S : begin
                  s_axis_tready = 1'b0;
                  count_next    = count - 1'b1;
                end
    endcase
  end

  register #(
    .WORD_WIDTH     (BITS_KERNEL_W),
    .RESET_VALUE    (0)         
  ) COUNT (
    .clock          (aclk          ),
    .clock_enable   (m_axis_tready ),
    .resetn         (aresetn       ),
    .data_in        (count_next    ),
    .data_out       (count         )
  );

  logic [BITS_KERNEL_W-2:0] lut_m_mod_k2 [MEMBERS-1:0][KERNEL_W_MAX/2:0];

  generate
    for (genvar m=0; m<MEMBERS; m++) begin: M

      for (genvar k2=0; k2 <= KERNEL_W_MAX/2; k2++)
        assign lut_m_mod_k2[m][k2] = m % (k2*2+1);
      
      assign m_keep_mask_next[m] = (lut_m_mod_k2[m][s_axis_kw_1_reg/2] == count_next);

      for (genvar cg=0; cg < COPIES*GROUPS; cg++)
        for (genvar uw=0; uw < UNITS*WORD_BYTES; uw++)
          assign m_axis_tkeep[cg][m][uw] = m_keep_raw[cg][m][uw] && m_keep_mask[m];
    end
  endgenerate
  
  register #(
    .WORD_WIDTH     (MEMBERS),
    .RESET_VALUE    (0)         
  ) KEEP_MASK (
    .clock          (aclk            ),
    .clock_enable   (m_axis_tready   ),
    .resetn         (aresetn         ),
    .data_in        (m_keep_mask_next),
    .data_out       (m_keep_mask     )
  );

  assign reg_en = s_axis_tready;

  register #(
    .WORD_WIDTH     (1),
    .RESET_VALUE    (0)         
  ) VALID (
    .clock          (aclk           ),
    .clock_enable   (reg_en         ),
    .resetn         (aresetn        ),
    .data_in        (s_axis_tvalid  ),
    .data_out       (m_axis_tvalid  )
  );
  register #(
    .WORD_WIDTH     (1),
    .RESET_VALUE    (0)         
  ) LAST (
    .clock          (aclk           ),
    .clock_enable   (reg_en         ),
    .resetn         (aresetn        ),
    .data_in        (s_axis_tlast   ),
    .data_out       (m_axis_tlast   )
  );
  register #(
    .WORD_WIDTH     (COPIES*GROUPS*MEMBERS*UNITS*WORD_WIDTH),
    .RESET_VALUE    (0)         
  ) DATA (
    .clock          (aclk           ),
    .clock_enable   (reg_en         ),
    .resetn         (aresetn        ),
    .data_in        (s_axis_tdata  ),
    .data_out       (m_axis_tdata  )
  );
  register #(
    .WORD_WIDTH     (MEMBERS*TUSER_WIDTH_LRELU_IN),
    .RESET_VALUE    (0)         
  ) USER (
    .clock          (aclk           ),
    .clock_enable   (reg_en         ),
    .resetn         (aresetn        ),
    .data_in        (s_axis_tuser   ),
    .data_out       (m_axis_tuser   )
  );
  register #(
    .WORD_WIDTH     (BITS_KERNEL_W),
    .RESET_VALUE    (0)         
  ) KW_1 (
    .clock          (aclk           ),
    .clock_enable   (reg_en         ),
    .resetn         (aresetn        ),
    .data_in        (s_axis_kw_1    ),
    .data_out       (s_axis_kw_1_reg)
  );
  register #(
    .WORD_WIDTH     (COPIES*GROUPS*MEMBERS*UNITS*WORD_BYTES),
    .RESET_VALUE    (0)         
  ) KEEP (
    .clock          (aclk           ),
    .clock_enable   (reg_en         ),
    .resetn         (aresetn        ),
    .data_in        (s_axis_tkeep   ),
    .data_out       (m_keep_raw     )
  );

endmodule

module axis_keep_filter_tb ();
  timeunit 10ns;
  timeprecision 1ns;
  localparam CLK_PERIOD = 10;
  logic aclk;
  initial begin
    aclk = 0;
    forever #(CLK_PERIOD/2) aclk <= ~aclk;
  end

  localparam IS_CONV_DW_SLICE     = `IS_CONV_DW_SLICE     ;
  localparam UNITS                = `UNITS                ;
  localparam GROUPS               = `GROUPS               ;
  localparam COPIES               = `COPIES               ;
  localparam MEMBERS              = `MEMBERS              ;
  localparam KERNEL_W_MAX         = `KERNEL_W_MAX         ;
  localparam WORD_WIDTH           = `WORD_WIDTH_ACC       ;
  localparam TUSER_WIDTH_LRELU_IN = `TUSER_WIDTH_LRELU_IN ; 

  localparam WORD_BYTES = WORD_WIDTH/8;
  localparam BITS_KERNEL_W = $clog2(KERNEL_W_MAX);
  localparam S_USER_WIDTH = TUSER_WIDTH_LRELU_IN + BITS_KERNEL_W;

  logic aresetn;
  logic s_axis_tvalid, s_axis_tlast;
  logic s_axis_tready;
  logic [COPIES*GROUPS-1:0][MEMBERS-1:0][UNITS*WORD_WIDTH -1:0] s_axis_tdata;
  logic [COPIES*GROUPS-1:0][MEMBERS-1:0][UNITS*WORD_BYTES -1:0] s_axis_tkeep;
  logic [MEMBERS-1:0] s_keep;
  logic                    [MEMBERS*S_USER_WIDTH          -1:0] s_axis_tuser;
  logic [BITS_KERNEL_W-1:0] s_axis_kw_1;

  logic m_axis_tvalid, m_axis_tlast;
  logic m_axis_tready;
  logic [COPIES*GROUPS-1:0][MEMBERS-1:0][UNITS*WORD_WIDTH     -1:0] m_axis_tdata;
  logic [COPIES*GROUPS-1:0][MEMBERS-1:0][UNITS*WORD_BYTES     -1:0] m_axis_tkeep;
  logic                    [MEMBERS*TUSER_WIDTH_LRELU_IN      -1:0] m_axis_tuser;

  axis_keep_filter dut (.*);

  generate
    for (genvar cg=0; cg < COPIES*GROUPS; cg++)
      for (genvar m=0; m < MEMBERS; m++)
        for (genvar uw=0; uw < UNITS*WORD_BYTES; uw++)
          assign s_axis_tkeep[cg][m][uw] = s_keep[m];
  endgenerate

  initial begin
    aresetn       <= 0;

    s_axis_tvalid <= 0;
    s_axis_tdata  <= 0;
    s_keep        <= 0;
    s_axis_tuser  <= 0;
    s_axis_kw_1   <= 0;
    s_axis_tlast  <= 0;

    m_axis_tready <= 0;


    repeat (2) @(posedge aclk);
    
    #1;
    s_axis_tvalid <= 1;
    s_axis_tdata  <= '1;
    // s_keep        <= {1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1};
    s_keep        <= 12'b100100100100;
    s_axis_tuser  <= '1;
    // s_axis_kw_1   <= BITS_KERNEL_W'(0);
    s_axis_kw_1   <= BITS_KERNEL_W'(2);
    s_axis_tlast  <= 0;

    m_axis_tready <= 0;

    @(posedge aclk);
    #1;
    m_axis_tready <= 1;

    @(posedge aclk);
    #1;
    s_axis_tvalid <= 0;
    s_axis_tdata  <= 0;
    s_keep        <= 0;
    s_axis_tuser  <= 0;
    s_axis_kw_1   <= 0;
    s_axis_tlast  <= 0;

    m_axis_tready <= 1;

    @(posedge s_axis_tready);
    #1;

  end
  
endmodule