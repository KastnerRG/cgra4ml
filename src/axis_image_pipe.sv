/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.

Create Date: 30/12/2020
Design Name: AXIS Image Pipe & AXIS Image Shift Buffer
Tool Versions: Vivado 2018.2
Description: 
            AXIS Image Pipe

            * Takes data from 2 DMAs via an AXIS channel of nearest_2's_power(UNITS + EDGES) words each
            * Converts the data_width to UNITS + EDGES words
            * From the first beat, reads and stores
               - is_max
               - k_h/2
            * Then passes ones, for conv_engine to multiply with RELU config bits from weights rotator
            * Then muxes the dw_m_data:
               - if max: each output channel is connected to each dw_converter
               - if not max: both output channels are connected to dw_converter_1
            * TUSER = k_h-1 (times to be shifted-1)

            AXIS Image Shift Buffer

            * Samples data (words: UNITS + EDGES) and tuser (=times_to_shift-1)
            * Input data is symmetrically padded with edges / zeros
            * de-centers the data when sampling
            * shift the de-centered data by given times, while holding input ready off

Dependencies: 

Revision:
Revision 0.01 - File Created
Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////*/

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
    m_axis_1_tdata ,
    m_axis_2_tdata ,
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

  input logic aclk;
  input logic aresetn;

  output logic s_axis_1_tready;
  input  logic s_axis_1_tvalid;
  input  logic s_axis_1_tlast ;
  input  logic [WORD_WIDTH*IM_IN_S_DATA_WORDS-1:0] s_axis_1_tdata;
  input  logic [TKEEP_WIDTH_IM_IN            -1:0] s_axis_1_tkeep;

  output logic s_axis_2_tready;
  input  logic s_axis_2_tvalid;
  input  logic s_axis_2_tlast ;
  input  logic [WORD_WIDTH*IM_IN_S_DATA_WORDS-1:0] s_axis_2_tdata;
  input  logic [TKEEP_WIDTH_IM_IN            -1:0] s_axis_2_tkeep;

  input  logic m_axis_tready;
  output logic m_axis_tvalid;
  output logic [TUSER_WIDTH_IM_IN-1:0] m_axis_tuser;
  output logic [WORD_WIDTH*UNITS_EDGES  -1:0] m_axis_1_tdata;
  output logic [WORD_WIDTH*UNITS_EDGES  -1:0] m_axis_2_tdata;

  /*
    DATA WIDTH CONVERTERS
  */

  logic dw_1_m_ready;
  logic dw_1_m_valid;
  logic dw_1_m_last ;
  logic [WORD_WIDTH*UNITS_EDGES  -1:0] dw_1_m_data_flat;

  logic dw_2_m_ready;
  logic dw_2_m_valid;
  logic [WORD_WIDTH*UNITS_EDGES  -1:0] dw_2_m_data_flat;

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
    .m_axis_tvalid (dw_2_m_valid    ),  
    .m_axis_tready (dw_2_m_ready    ),  
    .m_axis_tdata  (dw_2_m_data_flat)
  );


  logic [1:0] state, state_next;
  logic is_max_in, is_max_out;
  logic [BITS_KERNEL_H_MAX-1:0] kernel_h_1_in, kernel_h_1_out;
  logic [BITS_CONFIG_COUNT-1:0] beats_config, ones_count_next, ones_count;
  logic dw_1_handshake_last, dw_1_handshake;
  logic [WORD_WIDTH-1:0] dw_1_m_data [UNITS_EDGES-1:0];
  logic [WORD_WIDTH-1:0] dw_2_m_data [UNITS_EDGES-1:0];
  logic [WORD_WIDTH-1:0] m_data_1    [UNITS_EDGES-1:0];
  logic [WORD_WIDTH-1:0] m_data_2    [UNITS_EDGES-1:0];

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
  always_comb begin
    state_next = state;
    unique case (state)
      SET_S   : if (dw_1_handshake)             state_next = ONES_S;
      ONES_S  : if (ones_count == beats_config) state_next = PASS_S;
      default : if (dw_1_handshake_last)        state_next = SET_S ;
    endcase
  end

  // Output decoder
  always_comb begin
    unique case (state)
      SET_S   : begin
                  m_axis_tvalid = 0;
                  dw_1_m_ready  = 1;
                  dw_2_m_ready  = 0;
                  m_axis_tuser  = kernel_h_1_out;
                end
      ONES_S  : begin
                  m_axis_tvalid = 1;
                  dw_1_m_ready  = 0;
                  dw_2_m_ready  = 0;
                  m_axis_tuser  = 0;
                end
      default : begin // PASS_S
                  m_axis_tvalid = is_max_out ? (dw_1_m_valid  && dw_2_m_valid) : dw_1_m_valid;
                  dw_1_m_ready  = is_max_out ? (m_axis_tready && dw_2_m_valid) : m_axis_tready;
                  dw_2_m_ready  = is_max_out ? (m_axis_tready && dw_1_m_valid) : 0;
                  m_axis_tuser  = kernel_h_1_out;
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
    .data_in        (1'(is_max_in)),
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
    .data_in        (BITS_KERNEL_H_MAX'(kernel_h_1_in)),
    .data_out       (kernel_h_1_out)
  );

  /*
    MUX the output data
  */

  assign dw_1_m_data = {>>{dw_1_m_data_flat}};
  assign dw_2_m_data = {>>{dw_2_m_data_flat}};

  generate
    for (genvar u=0; u < UNITS_EDGES; u=u+1) begin
      assign m_data_1 [u] = (state == ONES_S) ? 1 : dw_1_m_data[u];
      assign m_data_2 [u] = (state == ONES_S) ? 1              : 
                            is_max_out        ? dw_2_m_data[u] : dw_1_m_data[u];
    end
  endgenerate

  assign {>>{m_axis_1_tdata}} = m_data_1;
  assign {>>{m_axis_2_tdata}} = m_data_2;

endmodule


module axis_image_shift_buffer (
    aclk         ,
    aresetn      ,

    s_axis_tready,  
    s_axis_tvalid,  
    s_axis_tlast ,   
    s_axis_tdata ,   
    s_axis_tuser ,   
    
    m_axis_tready,      
    m_axis_tvalid,     
    m_axis_tdata 
  );

  parameter UNITS              = 2;
  parameter WORD_WIDTH         = 8; 
  parameter KERNEL_H_MAX       = 3;   // odd number
  
  localparam UNITS_EDGES       = UNITS + KERNEL_H_MAX-1;
  localparam BITS_KERNEL_H_MAX = $clog2(KERNEL_H_MAX);
  localparam TUSER_WIDTH       = BITS_KERNEL_H_MAX;

  input logic aclk;
  input logic aresetn;

  output logic s_axis_tready;
  input  logic s_axis_tvalid;
  input  logic s_axis_tlast ;
  input  logic [WORD_WIDTH*UNITS_EDGES-1:0] s_axis_tdata;
  input  logic [TUSER_WIDTH-1:0] s_axis_tuser;

  input  logic m_axis_tready;
  output logic m_axis_tvalid;
  output logic [WORD_WIDTH*UNITS -1:0] m_axis_tdata;

  logic slice_s_ready;
  logic slice_s_valid;
  logic [WORD_WIDTH*UNITS -1:0] slice_s_data;

  logic aclken;
  logic [BITS_KERNEL_H_MAX-1:0] count_next, count;

  logic [WORD_WIDTH-1:0] s_data            [UNITS_EDGES-1:0];
  logic [WORD_WIDTH-1:0] s_data_decentered [UNITS_EDGES-1:0][KERNEL_H_MAX/2 +1-1:0];
  logic [WORD_WIDTH-1:0] buf_data_in       [UNITS_EDGES-1:0];
  logic [WORD_WIDTH-1:0] buf_data_out      [UNITS_EDGES-1:0];

  logic buf_valid_in;


  assign aclken = slice_s_ready;
  assign s_data = {>>{s_axis_tdata}};
  assign {>>{slice_s_data}} = buf_data_out [UNITS-1:0];

  register #(
    .WORD_WIDTH     (BITS_KERNEL_H_MAX),
    .RESET_VALUE    (0)
  ) COUNT (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (aclken && ((count == 0 && s_axis_tvalid) || (count != 0 && slice_s_ready))),
    .data_in        (count_next),
    .data_out       (count)
  );
  
  always_comb begin
    unique case (count)
      0       : begin
                  buf_valid_in  = s_axis_tvalid;
                  s_axis_tready = slice_s_ready;
                  count_next    = s_axis_tuser ;
                end
      default : begin
                  buf_valid_in  = 1;
                  s_axis_tready = 0;
                  count_next    = count-1;
                end
    endcase
  end

  generate
    for (genvar u=0; u<UNITS_EDGES; u++) begin
      
      /*
        DE-CENTERING THE S_DATA

        * s_data is padded symmetrically with edges / zeros
        * But we shift linearly (asymmetrically)
        * if KERNEL_H_MAX = 5 and  k_h = s_user+1 = 3
          - s_data[0] = 0 and s_data[-1] = 0 with actual data in between
          - we need to take buf_data_in[u] <= s_data[u+1]
          - then shift buf_data_in[u] <= buf_data_in[u+1]
        * For this, we de-center the data

        KERNEL_H_MAX = 5

        s_axis_tuser/2 : h2:0 => s_data_decentered[u] = s_data[u + 2] = s_data[u + 2 - 0]
        s_axis_tuser/2 : h2:1 => s_data_decentered[u] = s_data[u + 1] = s_data[u + 2 - 1]
        s_axis_tuser/2 : h2:2 => s_data_decentered[u] = s_data[u + 0] = s_data[u + 2 - 2]

        s_data_decentered[u] = s_data[u + KERNEL_H_MAX/2 - h2]
      */

      for (genvar h2=0; h2 <= KERNEL_H_MAX/2; h2++) begin
        if (u <= UNITS_EDGES - KERNEL_H_MAX/2)
          assign s_data_decentered[u][h2] = s_data[u + KERNEL_H_MAX/2 - h2];
        else 
          assign s_data_decentered[u][h2] = 0;
      end
      
      if (u == UNITS_EDGES-1) assign buf_data_in[u] = s_data_decentered[u][s_axis_tuser/2];
      else                    assign buf_data_in[u] = count == 0 ? s_data_decentered[u][s_axis_tuser/2] : buf_data_out[u+1];

      register #(
        .WORD_WIDTH     (WORD_WIDTH),
        .RESET_VALUE    (0)
      ) BUF_DATA (
        .clock          (aclk),
        .resetn         (aresetn),
        .clock_enable   (aclken),
        .data_in        (buf_data_in [u]),
        .data_out       (buf_data_out[u])
      );
    end
  endgenerate


  register #(
    .WORD_WIDTH     (1),
    .RESET_VALUE    (0)
  ) BUF_VALID (
    .clock          (aclk),
    .resetn         (aresetn),
    .clock_enable   (aclken),
    .data_in        (buf_valid_in ),
    .data_out       (slice_s_valid)
  );

  axis_reg_slice_image_pipe slice (
    .aclk           (aclk           ),
    .aresetn        (aresetn        ),              
    .s_axis_tvalid  (slice_s_valid  ),  
    .s_axis_tready  (slice_s_ready  ),  
    .s_axis_tdata   (slice_s_data   ),   
    .m_axis_tvalid  (m_axis_tvalid  ),  
    .m_axis_tready  (m_axis_tready  ),  
    .m_axis_tdata   (m_axis_tdata   )
  );

endmodule