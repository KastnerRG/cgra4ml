module axis_image_pipe (
    aclk           ,
    aresetn        ,
    s_axis_1_tready, 
    s_axis_1_tvalid, 
    s_axis_1_tlast , 
    s_axis_1_tdata , 
    s_axis_1_tkeep , 
    s_axis_2_tready,  
    s_axis_2_tvalid,  
    s_axis_2_tlast ,   
    s_axis_2_tdata ,   
    s_axis_2_tkeep ,      
    m_axis_tready  ,      
    m_axis_tvalid  ,     
    m_axis_tlast   ,      
    m_axis_tdata   ,
    m_axis_tuser
  );
  parameter UNITS              = 2;
  parameter WORD_WIDTH         = 8; 
  parameter KERNEL_H_MAX       = 3;   // odd number
  parameter BEATS_CONFIG_3X3_1 = 21-1;
  parameter BEATS_CONFIG_1X1_1 = 13-1;
  parameter BITS_OTHER         = 8;
  parameter I_IM_IN_IS_MAXPOOL = 0;
  parameter I_IM_IN_KERNEL_H_1 = I_IM_IN_IS_MAXPOOL + BITS_OTHER + 0;
  
  localparam UNITS_EDGES       = UNITS + KERNEL_H_MAX-1;
  localparam IM_IN_S_DATA_WORDS= 2**$clog2(UNITS_EDGES);
  localparam BITS_CONFIG_COUNT = $clog2(BEATS_CONFIG_3X3_1);
  localparam BITS_KERNEL_H_MAX = $clog2(KERNEL_H_MAX);

  parameter  TUSER_WIDTH_IM_IN  = BITS_KERNEL_H_MAX;
  localparam TKEEP_WIDTH_IM_IN = (WORD_WIDTH*IM_IN_S_DATA_WORDS)/8;

  input wire aclk;
  input wire aresetn;

  output wire s_axis_1_tready;
  input  wire s_axis_1_tvalid;
  input  wire s_axis_1_tlast ;
  input  wire [WORD_WIDTH*IM_IN_S_DATA_WORDS-1:0] s_axis_1_tdata;
  input  wire [TKEEP_WIDTH_IM_IN            -1:0] s_axis_1_tkeep;

  output wire s_axis_2_tready;
  input  wire s_axis_2_tvalid;
  input  wire s_axis_2_tlast ;
  input  wire [WORD_WIDTH*IM_IN_S_DATA_WORDS-1:0] s_axis_2_tdata;
  input  wire [TKEEP_WIDTH_IM_IN            -1:0] s_axis_2_tkeep;

  input  wire m_axis_tready;
  output reg  m_axis_tvalid;
  output wire m_axis_tlast ;
  output wire [TUSER_WIDTH_IM_IN-1:0] m_axis_tuser;
  output wire [WORD_WIDTH*UNITS_EDGES*2  -1:0] m_axis_tdata;

  /*
    DATA WIDTH CONVERTERS
  */

  reg  dw_1_m_ready;
  wire dw_1_m_valid;
  wire dw_1_m_last ;
  wire [WORD_WIDTH*UNITS_EDGES  -1:0] dw_1_m_data_flat;

  reg  dw_2_m_ready;
  wire dw_2_m_valid;
  wire dw_2_m_last ;
  wire [WORD_WIDTH*UNITS_EDGES  -1:0] dw_2_m_data_flat;

  axis_dw_image_input dw_1 (
    .aclk          (aclk   ),                    
    .aresetn       (aresetn),              
    .s_axis_tvalid (s_axis_1_tvalid ),  
    .s_axis_tready (s_axis_1_tready ),  
    .s_axis_tdata  (s_axis_1_tdata  ),    
    .s_axis_tkeep  (s_axis_1_tkeep  ),    
    .s_axis_tlast  (s_axis_1_tlast  ),    
    .m_axis_tvalid (dw_1_m_valid    ),  
    .m_axis_tready (dw_1_m_ready    ),  
    .m_axis_tdata  (dw_1_m_data_flat),
    .m_axis_tlast  (dw_1_m_last     )    
  );
  axis_dw_image_input dw_2 (
    .aclk          (aclk   ),                    
    .aresetn       (aresetn),              
    .s_axis_tvalid (s_axis_2_tvalid ),  
    .s_axis_tready (s_axis_2_tready ),  
    .s_axis_tdata  (s_axis_2_tdata  ),    
    .s_axis_tkeep  (s_axis_2_tkeep  ),    
    .s_axis_tlast  (s_axis_2_tlast  ),    
    .m_axis_tvalid (dw_2_m_valid    ),  
    .m_axis_tready (dw_2_m_ready    ),  
    .m_axis_tdata  (dw_2_m_data_flat),
    .m_axis_tlast  (dw_2_m_last     )    
  );


  wire [1:0] state;
  reg  [1:0] state_next;
  wire is_max_in, is_max_out;
  wire [BITS_KERNEL_H_MAX-1:0] kernel_h_1_in, kernel_h_1_out;
  wire [BITS_CONFIG_COUNT-1:0] beats_config, ones_count_next, ones_count;
  wire dw_1_handshake_last;
  wire dw_1_handshake;
  wire [WORD_WIDTH-1:0] dw_1_m_data [UNITS_EDGES-1:0];
  wire [WORD_WIDTH-1:0] dw_2_m_data [UNITS_EDGES-1:0];
  wire [WORD_WIDTH-1:0] m_data    [2*UNITS_EDGES-1:0];

  assign dw_1_handshake      = dw_1_m_ready && dw_1_m_valid;
  assign dw_1_handshake_last = dw_1_m_last  && dw_1_m_ready && dw_1_m_valid;

  /*
    STATE MACHINE

    - One entire image is loaded into the DMA. TLAST goes HIGH at the end of the image
    - 1 iteration = 1 input image
    - Each iteration, 
      - ALl conv cores calculate new output channels
      - we need to load RELU config values for A and B
      - Can choose to keep is_max, kernel_h, is_relu and other config bits between iterations, but we choose not to
      - Less cumbersome to keep iterations independant from each other and load everything in each iteration
      - We look at ONLY tlast and reload everything

    * SET_S  - loads is_max and kernel_h_1 into regs
    * ONES_s - Keeps m_data = 1, for RELU config bits
    * PASS_S - muxes the two halves of m_data from two dw_m_data's based on is_max
  */

  localparam SET_S  = 0;
  localparam ONES_S = 1;
  localparam PASS_S = 2;

  // Next state decoder
  always @(*) begin
    state_next = state;
    case (state)
      SET_S   : if (dw_1_handshake)             state_next = ONES_S;
      ONES_S  : if (ones_count == beats_config) state_next = PASS_S;
      default : if (dw_1_handshake_last)        state_next = SET_S ;
    endcase
  end

  // Output decoder
  always @(*) begin
    case (state)
      SET_S   : begin
                  m_axis_tvalid = 0;
                  dw_1_m_ready  = 1;
                  dw_2_m_ready  = 0;
                end
      ONES_S  : begin
                  m_axis_tvalid = 1;
                  dw_1_m_ready  = 0;
                  dw_2_m_ready  = 0;
                end
      default : begin // PASS_S
                  m_axis_tvalid = is_max_out ? (dw_1_m_valid  && dw_2_m_valid) : dw_1_m_valid;
                  dw_1_m_ready  = is_max_out ? (m_axis_tready && dw_2_m_valid) : m_axis_tready;
                  dw_2_m_ready  = is_max_out ? (m_axis_tready && dw_1_m_valid) : 0;
                end
    endcase
  end

  // State sequencer
  register #(
    .WORD_WIDTH     (2),
    .RESET_VALUE    (0)
  ) STATE (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (1),
    .data_in        (state_next),
    .data_out       (state)
  );

  assign beats_config    = (kernel_h_1_out == 0       ) ? BEATS_CONFIG_1X1_1 : BEATS_CONFIG_3X3_1;
  assign ones_count_next = (ones_count == beats_config) ? 0 : ones_count + 1;

  register #(
    .WORD_WIDTH     (BITS_CONFIG_COUNT),
    .RESET_VALUE    (0)
  ) ONES_COUNT (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (state == ONES_S && m_axis_tready),
    .data_in        (ones_count_next),
    .data_out       (ones_count)
  );

  /*
    Registers IS_MAX and KERNEL_H sample data during SET_S and hold them 
  */

  assign is_max_in = dw_1_m_data_flat [I_IM_IN_IS_MAXPOOL];

  register #(
    .WORD_WIDTH     (1),
    .RESET_VALUE    (0)
  ) IS_MAX (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (state == SET_S),
    .data_in        (is_max_in ),
    .data_out       (is_max_out)
  );

  assign kernel_h_1_in = dw_1_m_data_flat [I_IM_IN_KERNEL_H_1 + BITS_OTHER-1: I_IM_IN_KERNEL_H_1];

  register #(
    .WORD_WIDTH     (BITS_KERNEL_H_MAX),
    .RESET_VALUE    (0)
  ) KERNEL_H (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (state == SET_S),
    .data_in        (kernel_h_1_in),
    .data_out       (kernel_h_1_out)
  );

  /*
    MUX the output data
  */

  generate
    for (genvar u=0; u < UNITS_EDGES; u=u+1) begin
      assign dw_1_m_data[u] = dw_1_m_data_flat [WORD_WIDTH * (u+1) -1 : WORD_WIDTH * u];
      assign dw_2_m_data[u] = dw_2_m_data_flat [WORD_WIDTH * (u+1) -1 : WORD_WIDTH * u];
    end

    for (genvar u=0; u < 2*UNITS_EDGES; u=u+1)begin
      assign m_axis_tdata [WORD_WIDTH * (u+1) -1 : WORD_WIDTH * u] = m_data[u];
    end
    
    for (genvar u=0; u < UNITS_EDGES; u=u+1) begin
      assign m_data [u]               = (state == ONES_S) ? 1 : dw_1_m_data[u];
      assign m_data [UNITS_EDGES + u] = (state == ONES_S) ? 1              : 
                                        is_max_out        ? dw_2_m_data[u] : dw_1_m_data[u];
    end
  endgenerate

  assign m_axis_tuser = kernel_h_1_out;
  assign m_axis_tlast = dw_1_m_last;

endmodule