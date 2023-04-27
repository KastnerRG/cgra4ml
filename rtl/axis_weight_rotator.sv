/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.

Create Date: 30/12/2020
Design Name: AXIS Weight Rotator
Tool Versions: Vivado 2018.2
Description: 
          - Contains two Always Valid Cyclic BRAMs and a DW converter
          - s_data is directly from DMA. 32 bits.
          - first beat contains ref values: {s_blocks_1, s_cols_1, s_cin_1, s_kh2 , s_kw2 }
          - first beat bypasses DWC and loaded to ref registers
          - Following data (lrelu_config: 21/13 m_beats + weights: k_h*cin m_beats) 
              written into one BRAM
          - When done_write, the BRAM is read and rotated (cols*blocks) times
              - Total weights beats: k_h*cin*cols*blocks
              - M_TLAST issued at last beat
              - T_TUSER: is_config, is_1x1, kw, top, bot, cols_1_k2            

Dependencies: 

Revision:
Revision 0.01 - File Created
Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////*/
`timescale 1ns/1ps
`include "../params/params.svh"

module axis_weight_rotator #(
  parameter 
    COLS                = `COLS                     ,
    WORD_WIDTH          = `WORD_WIDTH               , 
    KH_MAX              = `KH_MAX                   ,   // odd number
    KW_MAX              = `KW_MAX                   ,   // odd number
    SH_MAX              = `SH_MAX                   ,   // odd number
    SW_MAX              = `SW_MAX                   ,   // odd number
    IM_CIN_MAX          = `IM_CIN_MAX               ,
    IM_COLS_MAX         = `IM_COLS_MAX              ,
    IM_ROWS_MAX         = `IM_ROWS_MAX              ,
    S_WEIGHTS_WIDTH_LF  = `S_WEIGHTS_WIDTH_LF       ,
    LATENCY_BRAM        = `LATENCY_BRAM             ,
    BRAM_WEIGHTS_DEPTH  = `BRAM_WEIGHTS_DEPTH       ,
    SRAM_TYPE           = `SRAM_TYPE                ,

  localparam  
    BITS_KW2            = $clog2((KW_MAX+1)/2)     ,
    BITS_KH2            = $clog2((KH_MAX+1)/2)     ,
    BITS_SW             = $clog2(SW_MAX      )     ,
    BITS_KH             = $clog2(KH_MAX      )     ,
    BITS_IM_CIN         = $clog2(IM_CIN_MAX  )     ,
    BITS_IM_BLOCKS      = $clog2(IM_ROWS_MAX/`ROWS),
    BITS_IM_COLS        = $clog2(IM_COLS_MAX      ),

    M_WIDTH             = WORD_WIDTH*COLS          ,
    BRAM_WIDTH          = M_WIDTH                  ,
    BRAM_DEPTH          = BRAM_WEIGHTS_DEPTH       ,
    BITS_ADDR           = $clog2(BRAM_WEIGHTS_DEPTH),
    BRAM_TYPE           = SRAM_TYPE == "XILINX" ? "XILINX_WEIGHTS" : SRAM_TYPE,
    CONFIG_COUNT_MAX    = 1                        ,// lrelu_beats
    BITS_CONFIG_COUNT   = $clog2(CONFIG_COUNT_MAX)
  )(
    
    input logic aclk,
    input logic aresetn,

    output logic                                       s_axis_tready,
    input  logic                                       s_axis_tvalid,
    input  logic                                       s_axis_tlast ,
    input  logic [S_WEIGHTS_WIDTH_LF    -1:0]          s_axis_tdata ,
    input  logic [S_WEIGHTS_WIDTH_LF /WORD_WIDTH -1:0] s_axis_tkeep ,

    input  logic               m_axis_tready,
    output logic               m_axis_tvalid,
    output logic               m_axis_tlast ,
    output tuser_st            m_axis_tuser ,
    output logic [M_WIDTH-1:0] m_axis_tdata
  );
  
  typedef logic logic_2_t [2];
  typedef logic [BITS_CONFIG_COUNT-1:0] config_2_t [2];

  logic dw_m_ready, dw_m_valid, dw_m_last, dw_s_valid, dw_s_ready;
  logic [M_WIDTH -1:0] dw_m_data_flat;
  
  logic state_dw_next, state_dw, s_handshake, s_last_handshake;

  logic dw_m_handshake, dw_m_last_handshake;
  logic i_read, i_write, tog_i_read, tog_i_write;

  logic_2_t done_read_next, done_write_next, en_ref;
  logic_2_t done_read, done_write, bram_resetn, bram_wen, bram_w_full, bram_m_ready;
  logic     bram_reg_resetn, bram_m_valid, bram_reg_m_valid;

  logic[M_WIDTH-1:0]    bram_m_data  [2];
  
  logic [BITS_ADDR-1:0] s_addr_max; 
  logic [BITS_ADDR-1:0] s_addr_min; 
  logic [BITS_ADDR-1:0] r_addr_min    [2];
  logic [BITS_ADDR-1:0] addr_max      [2];
  logic [BITS_CONFIG_COUNT-1:0] count_config, count_next_config;

  logic [BITS_KW2         -1:0] s_kw2 , ref_kw2   [2];
  logic [BITS_KH2         -1:0] s_kh2 , ref_kh2   [2];
  logic [BITS_KH          -1:0] count_kh, count_next_kh;
  logic [BITS_SW          -1:0] s_sw_1    , count_sw    , count_next_sw    , ref_1_sw     [2];
  logic [BITS_IM_CIN      -1:0] s_cin_1   , count_cin   , count_next_cin   , ref_1_cin    [2];
  logic [BITS_IM_COLS     -1:0] s_cols_1  , count_cols  , count_next_cols  , ref_1_cols   [2];
  logic [BITS_IM_BLOCKS   -1:0] s_blocks_1, count_blocks, count_next_blocks, ref_1_blocks [2];
  
  logic en_count_kh, en_count_sw, en_count_cin, en_count_cols, en_count_blocks, en_count_config;

  logic last_config, last_kh, last_sw, last_cin, last_cols, last_blocks;
  logic last_next_config, last_next_kh, last_next_sw, last_next_cin, last_next_cols, last_next_blocks;
  

  // Total lut
  localparam BEATS_TOTAL_MAX = 1; // lrelu_beats
  localparam BITS_BEATS_TOTAL = $clog2(BEATS_TOTAL_MAX+1);
  logic [BITS_BEATS_TOTAL-1:0] lut_lrelu_beats_1 [KW_MAX      /2:0];
  generate
    for (genvar KW2=0; KW2 <= KW_MAX      /2; KW2++)
      assign lut_lrelu_beats_1[KW2] = 1 -1; // lrelu_beats
  endgenerate


  localparam DW_BLOCK_S = 0;
  localparam DW_PASS_S  = 1;

  alex_axis_adapter_any #(
    .S_DATA_WIDTH  (S_WEIGHTS_WIDTH_LF),
    .M_DATA_WIDTH  (M_WIDTH),
    .S_KEEP_ENABLE (1),
    .M_KEEP_ENABLE (1),
    .S_KEEP_WIDTH  (S_WEIGHTS_WIDTH_LF/WORD_WIDTH),
    .M_KEEP_WIDTH  (M_WIDTH/WORD_WIDTH),
    .ID_ENABLE     (0),
    .DEST_ENABLE   (0),
    .USER_ENABLE   (0)
  ) DW (
    .clk           (aclk       ),
    .rst           (~aresetn   ),
    .s_axis_tvalid (dw_s_valid  ),
    .s_axis_tready (dw_s_ready  ),
    .s_axis_tdata  (s_axis_tdata),
    .s_axis_tkeep  (s_axis_tkeep),
    .s_axis_tlast  (s_axis_tlast),
    .m_axis_tvalid (dw_m_valid     ),
    .m_axis_tready (dw_m_ready     ),
    .m_axis_tdata  (dw_m_data_flat ),
    .m_axis_tlast  (dw_m_last      )
  );

  assign dw_m_handshake      = dw_m_valid     && dw_m_ready;
  assign dw_m_last_handshake = dw_m_handshake && dw_m_last;

  /*
    STATE MACHINE: WRITE
  */

  localparam W_IDLE_S     = 0;
  localparam W_GET_REF_S  = 1;
  localparam W_WRITE_S    = 2;
  localparam W_FILL_1_S   = 3;
  localparam W_FILL_2_S   = 4;
  localparam W_SWITCH_S   = 5;

  localparam BITS_W_STATE = 3;

  logic [BITS_W_STATE-1:0] state_write, state_write_next;

  always_comb begin
    state_write_next = state_write;
    unique case (state_write)
      W_IDLE_S    : if (done_read [i_write]   ) state_write_next = W_GET_REF_S;
      W_GET_REF_S : if (s_handshake && state_dw == DW_BLOCK_S) state_write_next = W_WRITE_S;
      W_WRITE_S   : if (dw_m_last_handshake   ) state_write_next = W_FILL_1_S;    // dw_m_last_handshake and bram_w_full[w_i] should be same
      W_FILL_1_S  :                             state_write_next = W_SWITCH_S;
      // W_FILL_1_S  :                             state_write_next = W_FILL_2_S;
      // W_FILL_2_S  : if (~fifo_empty [i_write] ) state_write_next = W_SWITCH_S;
      W_SWITCH_S  : state_write_next = W_IDLE_S;
    endcase 
  end

  register #(
    .WORD_WIDTH   (BITS_W_STATE), 
    .RESET_VALUE  (W_IDLE_S)
  ) STATE_W (
    .clock        (aclk),
    .clock_enable (1'b1),
    .resetn       (aresetn),
    .data_in      (state_write_next),
    .data_out     (state_write)
  );

  /*
    STATE MACHINE: READ
  */

  localparam R_IDLE_S        = 0;
  localparam R_PASS_CONFIG_S = 1;
  localparam R_READ_S        = 2;
  localparam R_SWITCH_S      = 3;
  localparam BITS_R_STATE    = 2;

  logic [BITS_R_STATE-1:0] state_read, state_read_next;

  always_comb begin

    en_count_config   = 0;
    count_next_config = lut_lrelu_beats_1[ref_kh2 [i_read]];
    m_axis_tvalid     = 0;
    bram_reg_resetn   = 1;

    unique case (state_read)
      R_IDLE_S        : begin
                          en_count_config = 1;
                        end
      R_PASS_CONFIG_S : begin
                          count_next_config  = count_config -1;
                          m_axis_tvalid      = bram_reg_m_valid;
                          en_count_config    = m_axis_tvalid && m_axis_tready;
                        end
      R_READ_S        : begin
                          m_axis_tvalid      = bram_reg_m_valid;
                        end
      R_SWITCH_S      : begin
                          bram_reg_resetn    = 0;
                        end
    endcase 

    state_read_next = state_read;
    unique case (state_read)
      R_IDLE_S        : if (done_write [i_read])            state_read_next = R_PASS_CONFIG_S;
      R_PASS_CONFIG_S : if (en_count_config && last_config) state_read_next = R_READ_S;
      R_READ_S        : if (en_count_blocks && last_blocks) state_read_next = R_SWITCH_S;
      R_SWITCH_S      : state_read_next = R_IDLE_S;
    endcase 
  end

  register #(
    .WORD_WIDTH   (BITS_R_STATE), 
    .RESET_VALUE  (R_IDLE_S)
  ) STATE_R (
    .clock        (aclk),
    .clock_enable (1'b1),
    .resetn       (aresetn),
    .data_in      (state_read_next),
    .data_out     (state_read)
  );

  assign tog_i_write = state_write == W_SWITCH_S;
  assign tog_i_read  = state_read  == R_SWITCH_S;

  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) I_WEIGHTS_WRITE (
    .clock        (aclk),
    .clock_enable (tog_i_write),
    .resetn       (aresetn),
    .data_in      (~i_write),
    .data_out     ( i_write)
  );
  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) I_WEIGHTS_READ (
    .clock        (aclk),
    .clock_enable (tog_i_read),
    .resetn       (aresetn),
    .data_in      (~i_read),
    .data_out     ( i_read)
  );
  
    /*
    FSM to bypass DATAWIDTH CONVERTER

    - slave side is smaller (32 bits)
    - get config bits from slave side
  */
 
  assign s_handshake      = s_axis_tready && s_axis_tvalid;
  assign s_last_handshake = s_handshake   && s_axis_tlast;

  always_comb begin

    dw_m_ready    = (state_write == W_WRITE_S);

    if (state_dw == DW_BLOCK_S) begin
      dw_s_valid    = 0;
      s_axis_tready = (state_write == W_GET_REF_S);

      if (s_handshake)      state_dw_next = DW_PASS_S;
      else                  state_dw_next = DW_BLOCK_S;
    end
    else begin
      dw_s_valid    = s_axis_tvalid;
      s_axis_tready = dw_s_ready;

      if (s_last_handshake) state_dw_next = DW_BLOCK_S;
      else                  state_dw_next = DW_PASS_S;
    end
  end

  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (DW_BLOCK_S)
  ) STATE_DW (
    .clock        (aclk),
    .clock_enable (1'd1),
    .resetn       (aresetn),
    .data_in      (state_dw_next),
    .data_out     (state_dw)
  );

  /*
    Extract s_data into inputs of ref registers
    This will give error if SUM_BITS > S_WEIGHTS_WIDTH 
  */
  localparam SUM_BITS = BITS_ADDR + BITS_IM_BLOCKS + BITS_IM_COLS + BITS_IM_CIN + BITS_SW + BITS_KH2 + BITS_KW2;
  assign {s_addr_max, s_blocks_1, s_cols_1, s_cin_1, s_sw_1, s_kh2 , s_kw2 } = s_axis_tdata[SUM_BITS-1:0];
  
  // s_addr_max = (s_kh_1+1)*(s_cin_1+1)*(s_sw_1+1) = (s_kh_1 * s_cin_1) + s_kh_1 + s_cin_1 +1
  // assign s_addr_max = ((s_kh2 * (s_cin_1+1)) * 2 + s_cin_1 + s_addr_min)*s_sw_1 + ((s_kh2 * (s_cin_1+1)) * 2 + s_cin_1 + s_addr_min) + s_sw_1;
  assign s_addr_min = lut_lrelu_beats_1[s_kh2] + 1;


  generate
    for (genvar i=0; i<2; i++) begin

      /*
        FSM Output Decoders for indexed signals
      */

      always_comb begin
        bram_resetn     [i] = 1;
        bram_wen        [i] = 0;
        en_ref          [i] = 0;
        done_write_next [i] = done_write[i];
        
        done_read_next[i]    = done_read[i];
        bram_m_ready  [i]    = 0;

        if (i==i_write) begin
          unique case (state_write)
            W_IDLE_S    : begin
                          end
            W_GET_REF_S : begin
                            done_write_next [i] = 0;
                            bram_resetn     [i] = 0;
                            en_ref          [i] = s_handshake && (state_dw == DW_BLOCK_S);
                          end
            W_WRITE_S   : begin
                            bram_wen[i] = dw_m_valid;
                          end
            W_FILL_1_S  : bram_m_ready     [i] = 1;
            W_FILL_2_S  : begin end
            W_SWITCH_S  : begin
                            done_write_next[i] = 1;
                          end
          endcase 
        end

        if (i==i_read) begin
          unique case (state_read)
            R_IDLE_S        : begin
                              end
            R_PASS_CONFIG_S : begin
                                done_read_next [i] = 0;
                                bram_m_ready   [i] = m_axis_tready;
                              end
            R_READ_S        : begin
                                bram_m_ready   [i] = m_axis_tready;
                              end
            R_SWITCH_S      : begin
                                done_read_next [i] = 1;
                              end
          endcase 
        end
      end

      cyclic_bram #(
        .R_DEPTH      (BRAM_DEPTH),
        .R_DATA_WIDTH (BRAM_WIDTH),
        .W_DATA_WIDTH (BRAM_WIDTH),
        .LATENCY      (LATENCY_BRAM),
        .ABSORB       (0),
        .USE_W_LAST   (1),
        .USE_R_LAST   (0),
        .TYPE         (BRAM_TYPE)
      ) BRAM (
        .clk          (aclk),
        .clken        (1'b1),
        .resetn       (aresetn && bram_resetn [i]),
        .s_data       (dw_m_data_flat),
        .w_en         (bram_wen    [i]),
        .m_data       (bram_m_data [i]),
        .r_en         (bram_m_ready[i]),
        .r_addr_min   (r_addr_min  [i]),
        .w_last_in    (dw_m_last_handshake),
        .r_addr_max   (addr_max    [i])
      );

      /*
        DONE FLAGS

        - To synchronize the two FSMs: read and write

        done_write[i]
          - When FSM_write starts writing to BRAM_0, it sets done_write[0] = 0
          - Then, even if FSM_read wants to start reading BRAM_0, it will wait in IDLE state
          - When FSM_write finishes writing to BRAM_0, it sets done_write[0] = 1
          - FSM_read sees this, gets out of IDLE and starts reading BRAM_0

        done_read[i]
          - When FSM_read starts reading BRAM_0, it sets done_read[0] = 0
          - Even if FSM_write wants to write to BRAM_0, it waits in IDLE
          - When FSM_read finishes, it sets 1, FSM_write gets out of IDLE and starts reading
      */
      
      register #(
        .WORD_WIDTH   (1), 
        .RESET_VALUE  (0)
      ) DONE_WRITE (
        .clock        (aclk),
        .clock_enable (1'b1),
        .resetn       (aresetn),
        .data_in      (done_write_next[i]),
        .data_out     (done_write     [i])
      );
      register #(
        .WORD_WIDTH   (1), 
        .RESET_VALUE  (1)
      ) DONE_READ (
        .clock        (aclk),
        .clock_enable (1'b1),
        .resetn       (aresetn),
        .data_in      (done_read_next[i]),
        .data_out     (done_read     [i])
      );

      /*
        REFERENCE REGISTERS

        - We bypass DW converter and take s_data, since that has lower width (32)
        - Directly connect s_data (sliced appropriately) to ref registers
        - Enabled during GET_REF state:
          - en_ref [i_write] = (state == W_GET_REF_S)
      */

      register #(
        .WORD_WIDTH   (BITS_KW2), 
        .RESET_VALUE  (0)
      ) REF_KW2 (
        .clock        (aclk),
        .resetn       (aresetn),
        .data_in      (s_kw2 ),
        .clock_enable (en_ref    [i]),
        .data_out     (ref_kw2   [i])
      );
      register #(
        .WORD_WIDTH   (BITS_KH2), 
        .RESET_VALUE  (0)
      ) REF_KH2 (
        .clock        (aclk),
        .resetn       (aresetn),
        .data_in      (s_kh2 ),
        .clock_enable (en_ref    [i]),
        .data_out     (ref_kh2   [i])
      );
      register #(
        .WORD_WIDTH   (BITS_SW), 
        .RESET_VALUE  (0)
      ) REF_SW_1 (
        .clock        (aclk),
        .resetn       (aresetn),
        .data_in      (s_sw_1),
        .clock_enable (en_ref     [i]),
        .data_out     (ref_1_sw   [i])
      );
      register #(
        .WORD_WIDTH   (BITS_IM_CIN), 
        .RESET_VALUE  (0)
      ) REF_CIN_1 (
        .clock        (aclk),
        .resetn       (aresetn),
        .data_in      (s_cin_1),
        .clock_enable (en_ref     [i]),
        .data_out     (ref_1_cin  [i])
      );
      register #(
        .WORD_WIDTH   (BITS_IM_COLS), 
        .RESET_VALUE  (0)
      ) REF_COLS_1 (
        .clock        (aclk),
        .resetn       (aresetn),
        .data_in      (s_cols_1),
        .clock_enable (en_ref     [i]),
        .data_out     (ref_1_cols [i])
      );
      register #(
        .WORD_WIDTH   (BITS_IM_BLOCKS), 
        .RESET_VALUE  (0)
      ) REF_BLOCKS_1 (
        .clock        (aclk),
        .resetn       (aresetn),
        .data_in      (s_blocks_1),
        .clock_enable (en_ref       [i]),
        .data_out     (ref_1_blocks [i])
      );
      /*
        Address Max, Min registers:
      */
      register #(
        .WORD_WIDTH   (BITS_ADDR), 
        .RESET_VALUE  (0)
      ) R_ADDR_MIN (
        .clock        (aclk),
        .clock_enable (en_ref     [i]),
        .resetn       (aresetn),
        .data_in      (s_addr_min),
        .data_out     (r_addr_min [i])
      );
      register #(
        .WORD_WIDTH   (BITS_ADDR), 
        .RESET_VALUE  (0)
      ) ADDR_MAX (
        .clock        (aclk),
        .clock_enable (en_ref   [i]),
        .resetn       (aresetn),
        .data_in      (s_addr_max),
        .data_out     (addr_max [i])
      );

    end
  endgenerate

  n_delay #(
    .N         (LATENCY_BRAM),
    .WORD_WIDTH (1)
  ) BRAM_VALID (
    .clk       (aclk),
    .resetn    (aresetn & bram_reg_resetn),
    .clken     (1'b1),
    .data_in   (bram_m_ready[i_read]),
    .data_out  (bram_m_valid)
  );

  axis_pipeline_register2 # (
    .DATA_WIDTH  (BRAM_WIDTH),
    .KEEP_ENABLE (0),
    .LAST_ENABLE (0),
    .ID_ENABLE   (0),
    .DEST_ENABLE (0),
    .USER_ENABLE (0),
    .REG_TYPE    (2), // skid buffer
    .LENGTH      (LATENCY_BRAM)
  ) REG_PIPE (
    .clk          (aclk),
    .rst          (~(aresetn & bram_reg_resetn)),
    .s_axis_tdata (bram_m_data [i_read]),
    .s_axis_tvalid(bram_m_valid),
    .m_axis_tdata (m_axis_tdata),
    .m_axis_tvalid(bram_reg_m_valid),
    .m_axis_tready(bram_m_ready[i_read])
  );

  // axis_pipeline_register #(
  //   .WIDTH   (BRAM_WIDTH),
  //   .DEPTH   (LATENCY_BRAM)
  // ) REG_PIPE (
  //   .aclk    (aclk),
  //   .aresetn (aresetn & bram_reg_resetn),
  //   .s_data  (bram_m_data [i_read]),
  //   .s_valid (bram_m_valid),
  //   .m_data  (m_axis_tdata ),
  //   .m_valid (bram_reg_m_valid),
  //   .m_ready (bram_m_ready[i_read])
  // );

  /*
    COUNTER REGISTERS

    - Nested counters: k_h -> cin -> cols -> blocks
    - Down-counters
      - count from (ref-1) to 0
      - check 1, delay by 1 to get (count == 0)
        - (count==1) check will fail if ref = 1, that is ref_1 == 0
        - if ref_1==0, always last_next
        - This will fail at ref=0, but who the fuck counts to zero?

    - Enable
      - At last_config, to accept (ref-1) for the first time
      - At the last beat of smaller counter
  */

  assign en_count_kh        = m_axis_tvalid && m_axis_tready && (last_config || state_read == R_READ_S);
  assign en_count_cin       = m_axis_tvalid && m_axis_tready && (last_config || (last_kh));
  assign en_count_sw        = m_axis_tvalid && m_axis_tready && (last_config || (last_kh && last_cin)); // independant
  assign en_count_cols      = m_axis_tvalid && m_axis_tready && (last_config || (last_kh && last_cin));
  assign en_count_blocks    = m_axis_tvalid && m_axis_tready && (last_config || (last_kh && last_cin && last_cols));

  assign count_next_kh     = (last_kh       || last_config || ref_kh2      [i_read] == 0) ? 2*ref_kh2   [i_read] : count_kh     - 1;
  assign count_next_cin    = (last_cin      || last_config || ref_1_cin    [i_read] == 0) ? ref_1_cin   [i_read] : count_cin    - 1;
  assign count_next_sw     = (last_sw       || last_config || ref_1_sw     [i_read] == 0) ? ref_1_sw    [i_read] : count_sw     - 1;
  assign count_next_cols   = (last_cols     || last_config || ref_1_cols   [i_read] == 0) ? ref_1_cols  [i_read] : count_cols   - 1;
  assign count_next_blocks = (last_blocks   || last_config || ref_1_blocks [i_read] == 0) ? ref_1_blocks[i_read] : count_blocks - 1;

  assign last_next_config  = count_next_config == 0;
  assign last_next_kh      = count_next_kh     == 0 || ref_kh2      [i_read] == 0;
  assign last_next_cin     = count_next_cin    == 0 || ref_1_cin    [i_read] == 0;
  assign last_next_sw      = count_next_sw     == 0 || ref_1_sw     [i_read] == 0;
  assign last_next_cols    = count_next_cols   == 0 || ref_1_cols   [i_read] == 0;
  assign last_next_blocks  = count_next_blocks == 0 || ref_1_blocks [i_read] == 0;

  /*
    TLAST and TUSER
  */

  assign m_axis_tlast = last_kh && last_cin && last_cols && last_blocks;

  assign m_axis_tuser.is_config    = state_read  == R_PASS_CONFIG_S;
  assign m_axis_tuser.kw2          = ref_kw2  [i_read];
  assign m_axis_tuser.sw_1         = ref_1_sw [i_read];
  assign m_axis_tuser.is_w_first_clk   = count_cols == ref_1_cols[i_read] && count_cin == ref_1_cin[i_read] && count_kh == 2*ref_kh2 [i_read];
  assign m_axis_tuser.is_cin_last  = (last_kh && last_cin);
  assign m_axis_tuser.is_col_1_k2  = count_cols   == ref_kw2      [i_read]; // i = cols-1-k/2 === [cols-1-i] = k/2
  assign m_axis_tuser.is_top_block = count_blocks == ref_1_blocks [i_read];
  assign m_axis_tuser.is_bot_block = last_blocks;
  assign m_axis_tuser.is_col_valid = count_sw == ref_1_sw [i_read] - (ref_1_sw [i_read] == 0  ? 0 : 1); // if no stride, si=0 else si=1
  assign m_axis_tuser.is_sum_start = count_sw == ref_1_sw [i_read] - (ref_1_sw [i_read] == 2-1? 1 : 0); // if (7,2)    , si=1 else si=0
  assign m_axis_tuser.is_w_first_kw2   = (ref_1_cols[i_read] - count_cols) < ref_kh2 [i_read];
  assign m_axis_tuser.is_w_last        = count_cols == 0;

  register #(
    .WORD_WIDTH   (BITS_CONFIG_COUNT), 
    .RESET_VALUE  (0)
  ) COUNT_CONFIG (
    .clock        (aclk),
    .resetn       (aresetn),
    .clock_enable (en_count_config),
    .data_in      (count_next_config),
    .data_out     (count_config)
  );

  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) LAST_CONFIG (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (last_next_config),
    .clock_enable (en_count_config),
    .data_out     (last_config)
  );

  register #(
    .WORD_WIDTH   (BITS_KH), 
    .RESET_VALUE  (0)
  ) COUNT_KH (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (count_next_kh),
    .clock_enable (en_count_kh),
    .data_out     (count_kh)
  );
  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) LAST_KH (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (last_next_kh),
    .clock_enable (en_count_kh),
    .data_out     (last_kh)
  );
  register #(
    .WORD_WIDTH   (BITS_IM_CIN), 
    .RESET_VALUE  (0)
  ) COUNT_CIN (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (count_next_cin),
    .clock_enable (en_count_cin),
    .data_out     (count_cin)
  );
  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) LAST_CIN (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (last_next_cin),
    .clock_enable (en_count_cin),
    .data_out     (last_cin)
  );
  register #(
    .WORD_WIDTH   (BITS_SW), 
    .RESET_VALUE  (0)
  ) COUNT_SW (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (count_next_sw),
    .clock_enable (en_count_sw),
    .data_out     (count_sw)
  );
  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) LAST_SW (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (last_next_sw),
    .clock_enable (en_count_sw),
    .data_out     (last_sw)
  );
  register #(
    .WORD_WIDTH   (BITS_IM_COLS), 
    .RESET_VALUE  (0)
  ) COUNT_COLS (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (count_next_cols),
    .clock_enable (en_count_cols),
    .data_out     (count_cols)
  );
  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) LAST_COLS (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (last_next_cols),
    .clock_enable (en_count_cols),
    .data_out     (last_cols)
  );
  register #(
    .WORD_WIDTH   (BITS_IM_BLOCKS), 
    .RESET_VALUE  (0)
  ) COUNT_BLOCKS (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (count_next_blocks),
    .clock_enable (en_count_blocks),
    .data_out     (count_blocks)
  );
  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) LAST_BLOCKS (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (last_next_blocks),
    .clock_enable (en_count_blocks),
    .data_out     (last_blocks)
  );

endmodule
