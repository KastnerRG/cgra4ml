/*
Engineer: Abarajithan G.
Design Name: AXIS Weight Rotator    
*/
`timescale 1ns/1ps
`include "../rtl/include/params.svh"

module axis_weight_rotator #(
  parameter 
    COLS                = `COLS                ,
    WORD_WIDTH          = `K_BITS              , 
    KW_MAX              = `KW_MAX              ,   // odd number
    CI_MAX              = `CI_MAX              ,
    XW_MAX              = `XW_MAX              ,
    XH_MAX              = `XH_MAX              ,
    XN_MAX              = `XN_MAX              ,
    S_WEIGHTS_WIDTH_LF  = `S_WEIGHTS_WIDTH_LF  ,
    DELAY_W_RAM         = `DELAY_W_RAM         ,
    RAM_WEIGHTS_DEPTH   = `RAM_WEIGHTS_DEPTH   ,
    CONFIG_BEATS        = `CONFIG_BEATS        ,

  localparam  
    BITS_KW2            = $clog2((KW_MAX+1)/2) ,
    BITS_KW             = $clog2(KW_MAX      ) ,
    BITS_CI             = $clog2(CI_MAX      ) ,
    BITS_IM_BLOCKS      = $clog2(XH_MAX/`ROWS) ,
    BITS_XW             = $clog2(XW_MAX      ) ,
    BITS_XN             = $clog2(XN_MAX      ) ,

    M_WIDTH             = WORD_WIDTH*COLS          ,
    BRAM_WIDTH          = M_WIDTH                  ,
    BRAM_DEPTH          = RAM_WEIGHTS_DEPTH        ,
    BITS_ADDR           = $clog2(RAM_WEIGHTS_DEPTH ),
    BITS_CONFIG_BEATS   = $clog2(CONFIG_BEATS+1)
  )(
    
    input logic aclk,
    input logic aresetn,

    output logic                                       s_axis_tready,
    input  logic                                       s_axis_tvalid,
    input  logic                                       s_axis_tlast ,
    input  logic [S_WEIGHTS_WIDTH_LF            -1:0]  s_axis_tdata ,
    input  logic [S_WEIGHTS_WIDTH_LF/8          -1:0]  s_axis_tkeep ,

    input  logic               m_axis_tready,
    output logic               m_axis_tvalid,
    output logic               m_axis_tlast ,
    output tuser_st            m_axis_tuser ,
    output logic [M_WIDTH-1:0] m_axis_tdata
  );

  enum {W_IDLE_S, W_GET_REF_S, W_WRITE_S, W_FILL_1_S, W_FILL_2_S, W_SWITCH_S} state_write;
  enum {R_IDLE_S, R_PASS_CONFIG_S, R_READ_S, R_SWITCH_S} state_read;
  enum {DW_PASS_S, DW_BLOCK_S} state_dw;

  logic i_read, i_write, dw_m_ready, dw_m_valid, dw_m_last, dw_s_valid, dw_s_ready;
  logic      [M_WIDTH-1:0] dw_m_data_flat;
  logic [1:0][M_WIDTH-1:0] bram_m_data;
  logic [1:0] done_read_next, done_write_next, en_ref, done_read, done_write, bram_resetn, bram_wen, bram_w_full, bram_m_ready;
  logic       bram_reg_resetn, bram_m_valid, bram_reg_m_valid;
  logic en_count_config, l_config, l_kw, l_cin, l_cols, l_blocks, l_xn, f_kw, f_cin, f_cols, f_blocks, lc_config, lc_kw, lc_cin, lc_cols, lc_blocks, lc_xn;
  typedef struct packed {
    logic [BITS_ADDR        -1:0] addr_max;
    logic [BITS_XN          -1:0] xn_1;
    logic [BITS_IM_BLOCKS   -1:0] blocks_1;
    logic [BITS_XW     -1:0] cols_1;
    logic [BITS_CI      -1:0] cin_1;
    logic [BITS_KW2         -1:0] kw2;
  } config_st;
  config_st s_config, count;
  logic [1:0][BITS_ADDR + BITS_XN + BITS_IM_BLOCKS + BITS_XW + BITS_CI + BITS_KW2 -1:0] ref_config;
  
  assign s_config = s_axis_tdata;
  wire s_handshake      = s_axis_tready && s_axis_tvalid;
  wire s_last_handshake = s_handshake   && s_axis_tlast;


  alex_axis_adapter_any #(
    .S_DATA_WIDTH  (S_WEIGHTS_WIDTH_LF),
    .M_DATA_WIDTH  (M_WIDTH),
    .S_KEEP_ENABLE (1),
    .M_KEEP_ENABLE (1),
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

  wire dw_m_handshake      = dw_m_valid     && dw_m_ready;
  wire dw_m_last_handshake = dw_m_handshake && dw_m_last;


  //  STATE MACHINE: WRITE
  always_ff @(posedge aclk) 
    if (!aresetn)                                              state_write <= W_IDLE_S;
    else unique case (state_write)
      W_IDLE_S    : if (done_read [i_write]   )                state_write <= W_GET_REF_S;
      W_GET_REF_S : if (s_handshake && state_dw == DW_BLOCK_S) state_write <= W_WRITE_S;
      W_WRITE_S   : if (dw_m_last_handshake   )                state_write <= W_FILL_1_S;    // dw_m_last_handshake and bram_w_full[w_i] should be same
      W_FILL_1_S  :                                            state_write <= W_SWITCH_S;
      W_SWITCH_S  :                                            state_write <= W_IDLE_S;
    endcase 


  //  STATE MACHINE: READ
  always_ff @(posedge aclk)
    if (!aresetn)                                state_read <= R_IDLE_S;
    else unique case (state_read)
      R_IDLE_S        : if (done_write [i_read]) state_read <= R_PASS_CONFIG_S;
      R_PASS_CONFIG_S : if (lc_config)           state_read <= R_READ_S;
      R_READ_S        : if (lc_xn    )           state_read <= R_SWITCH_S;
      R_SWITCH_S      :                          state_read <= R_IDLE_S;
    endcase 

  always_comb begin

    en_count_config   = 0;
    m_axis_tvalid     = 0;
    bram_reg_resetn   = 1;

    unique case (state_read)
      R_IDLE_S        : begin
                          en_count_config = 1;
                        end
      R_PASS_CONFIG_S : begin
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
  end

  // Switching RAMs
  always_ff @(posedge aclk)
    if (!aresetn)  {i_write, i_read} <= 0;
    else begin
      if (state_write == W_SWITCH_S)  i_write <= !i_write;
      if (state_read  == R_SWITCH_S)  i_read  <= !i_read;
    end
  

  // State machine DW
  always_ff @(posedge aclk)
    if (!aresetn)                       state_dw <= DW_BLOCK_S;
    else unique case (state_dw)
      DW_BLOCK_S: if (s_handshake)      state_dw <= DW_PASS_S;
      DW_PASS_S : if (s_last_handshake) state_dw <= DW_BLOCK_S;
    endcase

  always_comb begin
    dw_m_ready    = (state_write == W_WRITE_S);

    if (state_dw == DW_BLOCK_S) begin
      dw_s_valid    = 0;
      s_axis_tready = (state_write == W_GET_REF_S);
    end
    else begin
      dw_s_valid    = s_axis_tvalid;
      s_axis_tready = dw_s_ready;
    end
  end
  generate
    for (genvar i=0; i<2; i++) begin
      //  FSM Output Decoders for indexed signals
      always_comb begin
        bram_resetn     [i] = 1;
        bram_wen        [i] = 0;
        en_ref          [i] = 0;
        done_write_next [i] = done_write[i];
        
        done_read_next  [i]    = done_read[i];
        bram_m_ready    [i]    = 0;

        if (i==i_write) 
          case (state_write)
            W_GET_REF_S : begin
                            done_write_next [i] = 0;
                            bram_resetn     [i] = 0;
                            en_ref          [i] = s_handshake && (state_dw == DW_BLOCK_S);
                          end
            W_WRITE_S   :   bram_wen        [i] = dw_m_valid;
            W_SWITCH_S  :   done_write_next [i] = 1;
          endcase 

        if (i==i_read)
          case (state_read)
            R_PASS_CONFIG_S : begin
                                done_read_next [i] = 0;
                                bram_m_ready   [i] = m_axis_tready;
                              end
            R_READ_S        :   bram_m_ready   [i] = m_axis_tready;
            R_SWITCH_S      :   done_read_next [i] = 1;
          endcase 
      end

      config_st ref_i;
      assign ref_i = ref_config[i];
      cyclic_bram #(
        .R_DEPTH      (BRAM_DEPTH),
        .R_DATA_WIDTH (BRAM_WIDTH),
        .W_DATA_WIDTH (BRAM_WIDTH),
        .LATENCY      (DELAY_W_RAM ),
        .ABSORB       (0)
      ) BRAM (
        .clk          (aclk),
        .clken        (1'b1),
        .resetn       (aresetn && bram_resetn [i]),
        .s_data       (dw_m_data_flat),
        .w_en         (bram_wen    [i]),
        .m_data       (bram_m_data [i]),
        .r_en         (bram_m_ready[i]),
        .r_addr_min   (BITS_ADDR'(CONFIG_BEATS)),
        .r_addr_max   (ref_i.addr_max )
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
      
      always_ff @(posedge aclk) begin
        done_write[i] <= !aresetn ? 0 : done_write_next[i];
        done_read [i] <= !aresetn ? 1 : done_read_next [i];
      end

      // Reference Registers
      always_ff @(posedge aclk)
        if (en_ref[i]) ref_config [i] <= s_config;
    end
  endgenerate

  n_delay #(.N(DELAY_W_RAM ), .W(1)) BRAM_VALID (.c(aclk), .rn(aresetn & bram_reg_resetn), .e(1'b1), .i(bram_m_ready[i_read]), .o(bram_m_valid));

  axis_pipeline_register2 # (
    .DATA_WIDTH  (BRAM_WIDTH),
    .KEEP_ENABLE (0),
    .LAST_ENABLE (0),
    .ID_ENABLE   (0),
    .DEST_ENABLE (0),
    .USER_ENABLE (0),
    .REG_TYPE    (2), // skid buffer
    .LENGTH      (DELAY_W_RAM )
  ) REG_PIPE (
    .clk          (aclk),
    .rst          (~(aresetn & bram_reg_resetn)),
    .s_axis_tdata (bram_m_data [i_read]),
    .s_axis_tvalid(bram_m_valid),
    .m_axis_tdata (m_axis_tdata),
    .m_axis_tvalid(bram_reg_m_valid),
    .m_axis_tready(bram_m_ready[i_read])
  );

  // Counters
  logic [BITS_XW -1:0] c_cols;
  wire copy_config = (state_read == R_IDLE_S) && done_write [i_read];
  wire en_kw       = m_axis_tvalid && m_axis_tready && state_read == R_READ_S;
  config_st ref_i_read;
  assign ref_i_read = ref_config[i_read]; 

  counter #(.W(BITS_CONFIG_BEATS)) C_CONFIG    (.clk(aclk), .reset(copy_config), .en(en_count_config), .max_in(BITS_CONFIG_BEATS'( CONFIG_BEATS-1       )), .last_clk(lc_config), .last(l_config)                                  );
  counter #(.W(BITS_KW          )) C_KW        (.clk(aclk), .reset(copy_config), .en(en_kw          ), .max_in(BITS_KW          '( 2*ref_i_read.kw2     )), .last_clk(lc_kw    ), .last(l_kw    ), .first(f_kw    )                );
  counter #(.W(BITS_CI          )) C_CI        (.clk(aclk), .reset(copy_config), .en(lc_kw          ), .max_in(BITS_CI          '(   ref_i_read.cin_1   )), .last_clk(lc_cin   ), .last(l_cin   ), .first(f_cin   )                );
  counter #(.W(BITS_XW          )) C_XW        (.clk(aclk), .reset(copy_config), .en(lc_cin         ), .max_in(BITS_XW          '(   ref_i_read.cols_1  )), .last_clk(lc_cols  ), .last(l_cols  ), .first(f_cols  ), .count(c_cols));
  counter #(.W(BITS_IM_BLOCKS   )) C_IM_BLOCKS (.clk(aclk), .reset(copy_config), .en(lc_cols        ), .max_in(BITS_IM_BLOCKS   '(   ref_i_read.blocks_1)), .last_clk(lc_blocks), .last(l_blocks)                                  );
  counter #(.W(BITS_XN          )) C_XN        (.clk(aclk), .reset(copy_config), .en(lc_blocks      ), .max_in(BITS_XN          '(   ref_i_read.xn_1    )), .last_clk(lc_xn    ), .last(l_xn    )                                  );

  // Last & User

  assign m_axis_tlast = lc_xn;

  assign m_axis_tuser.is_config        = state_read  == R_PASS_CONFIG_S;
  assign m_axis_tuser.kw2              = ref_i_read.kw2;
  assign m_axis_tuser.is_w_first_clk   = f_cols && f_cin && f_kw;
  assign m_axis_tuser.is_cin_last      = l_kw   && l_cin;
  assign m_axis_tuser.is_w_first_kw2   = (ref_i_read.cols_1 - c_cols) < ref_i_read.kw2;
  assign m_axis_tuser.is_w_last        = l_cols;

endmodule


module axis_sync (
  input logic weights_m_valid, pixels_m_valid, m_axis_tready,
  input tuser_st weights_m_user,
  output logic m_axis_tvalid, weights_m_ready, pixels_m_ready
);
  assign m_axis_tvalid   = weights_m_valid && (pixels_m_valid || weights_m_user.is_config);
  assign weights_m_ready = m_axis_tready   && (pixels_m_valid || weights_m_user.is_config);
  assign pixels_m_ready  = m_axis_tready   && weights_m_valid && !weights_m_user.is_config;
endmodule