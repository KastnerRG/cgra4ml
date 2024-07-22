/*
Engineer: Abarajithan G.
Design Name: AXIS Weight Rotator    
*/
`timescale 1ns/1ps
`include "defines.svh"

module axis_weight_rotator #(
  parameter 
    COLS                = `COLS                ,
    WORD_WIDTH          = `K_BITS              , 
    KW_MAX              = `KW_MAX              ,   // odd number
    CI_MAX              = `CI_MAX              ,
    XW_MAX              = `XW_MAX              ,
    XH_MAX              = `XH_MAX              ,
    XN_MAX              = `XN_MAX              ,
    AXI_WIDTH           = `AXI_WIDTH           ,
    HEADER_WIDTH        = `HEADER_WIDTH        , 
    DELAY_W_RAM         = `DELAY_W_RAM         ,
    RAM_WEIGHTS_DEPTH   = `RAM_WEIGHTS_DEPTH   ,
    CONFIG_BEATS        = `CONFIG_BEATS        ,

  parameter  
    BITS_KW2            = $clog2((KW_MAX+1)/2) ,
    BITS_KW             = $clog2(KW_MAX      ) ,
    BITS_CI             = $clog2(CI_MAX      ) ,
    BITS_IM_BLOCKS      = $clog2(XH_MAX/`ROWS) ,
    BITS_XW             = $clog2(XW_MAX      ) ,
    BITS_XN             = $clog2(XN_MAX      ) ,

    BITS_SB_CNTR        = $clog2(2*DELAY_W_RAM) + 1,

    M_WIDTH             = WORD_WIDTH*COLS          ,
    BRAM_WIDTH          = WORD_WIDTH                  ,
    BRAM_DEPTH          = RAM_WEIGHTS_DEPTH        ,
    BITS_ADDR           = $clog2(RAM_WEIGHTS_DEPTH ),
    BITS_CONFIG_BEATS   = $clog2(CONFIG_BEATS)+1
  )(
    
    input logic aclk,
    input logic aresetn,

    output logic                             s_axis_tready,
    input  logic                             s_axis_tvalid,
    input  logic                             s_axis_tlast ,
    input  logic [AXI_WIDTH            -1:0] s_axis_tdata ,
    input  logic [AXI_WIDTH/WORD_WIDTH -1:0] s_axis_tkeep ,
    input  logic [HEADER_WIDTH           :0] s_axis_tuser ,

    input  logic    [COLS-1:0]               m_axis_tready,
    output logic    [COLS-1:0]               m_axis_tvalid,
    output logic    [COLS-1:0]               m_axis_tlast ,
    output tuser_st [COLS-1:0]               m_axis_tuser ,

    output logic [COLS-1:0][WORD_WIDTH-1:0] m_axis_tdata
  );

  // always @ (posedge aclk)
  //   if (s_axis_tvalid && s_axis_tready && s_axis_tlast)
  //     $display("weights: s_axis_tuser = %d", s_axis_tuser);

  enum {W_IDLE_S, W_WRITE_S, W_FILL_1_S, W_SWITCH_S} state_write;
  typedef enum {R_IDLE_S, R_PASS_CONFIG_S, R_READ_S, R_SWITCH_S} rd_state;
  rd_state state_read [COLS-1:0]; // independent state for each column
  //enum {R_IDLE_S, R_PASS_CONFIG_S, R_READ_S, R_SWITCH_S} state_read;

  logic i_write, dw_m_ready, dw_m_valid, dw_m_last;
  logic [COLS-1:0] i_read;
  logic      [M_WIDTH-1:0] dw_m_data_flat;
  logic [1:0][M_WIDTH-1:0] bram_m_data;
  logic [1:0] done_write_next, en_ref, done_write, bram_resetn, bram_wen;
  logic [1:0][COLS-1:0] done_read_next, done_read;
  logic [1:0][COLS-1:0] bram_m_ready;
  logic [COLS-1:0] bram_reg_resetn;
  logic [COLS-1:0] bram_m_valid, bram_reg_m_valid;
  logic [COLS-1:0] sb_valid, sb_ready;
  logic [COLS-1:0][WORD_WIDTH-1:0] sb_data;
  logic [COLS-1:0][BITS_SB_CNTR-1:0] fill_skid_buffer_cntr; 
  logic [COLS-1:0] en_count_config, l_config, l_kw, l_cin, l_cols, l_blocks, l_xn, f_kw, f_cin, f_cols, lc_config, lc_kw, lc_cin, lc_cols, lc_blocks, lc_xn;
  logic [COLS-1:0]     last_config;

  typedef struct packed {
    logic [BITS_ADDR        -1:0] addr_p_max;
    logic [BITS_ADDR        -1:0] addr_p0_max;
    logic [BITS_XN          -1:0] xn_1;
    logic [BITS_CI          -1:0] cin_p_1;
    logic [BITS_CI          -1:0] cin_p0_1;
    logic [BITS_IM_BLOCKS   -1:0] blocks_1;
    logic [BITS_XW          -1:0] cols_1;
    logic [BITS_KW2         -1:0] kw2;
    logic                         is_first_p;
  } config_input_st;
  config_input_st sci;
  assign sci = config_input_st'(s_axis_tuser);

  localparam BITS_CONFIG = BITS_ADDR + BITS_XN + BITS_IM_BLOCKS + BITS_XW + BITS_CI + BITS_KW2;
  typedef struct packed {
    logic [BITS_ADDR        -1:0] addr_max;
    logic [BITS_XN          -1:0] xn_1;
    logic [BITS_IM_BLOCKS   -1:0] blocks_1;
    logic [BITS_XW          -1:0] cols_1;
    logic [BITS_CI          -1:0] cin_1;
    logic [BITS_KW2         -1:0] kw2;
  } config_st;
  config_st s_config, dw_config;
  assign s_config = {(sci.is_first_p ? sci.addr_p0_max : sci.addr_p_max), sci.xn_1, sci.blocks_1, sci.cols_1, (sci.is_first_p ? sci.cin_p0_1 : sci.cin_p_1), sci.kw2};

  logic [1:0][BITS_ADDR + BITS_XN + BITS_IM_BLOCKS + BITS_XW + BITS_CI + BITS_KW2-1:0] ref_config;

  wire s_handshake      = s_axis_tready && s_axis_tvalid;
  wire s_last_handshake = s_handshake   && s_axis_tlast;
  //assign m_rd_state = state_read;


  alex_axis_adapter_any #(
    .S_DATA_WIDTH  (AXI_WIDTH),
    .M_DATA_WIDTH  (M_WIDTH),
    .S_KEEP_ENABLE (1),
    .M_KEEP_ENABLE (1),
    .S_KEEP_WIDTH  (AXI_WIDTH/WORD_WIDTH),
    .M_KEEP_WIDTH  (M_WIDTH/WORD_WIDTH),
    .ID_ENABLE     (0),
    .DEST_ENABLE   (0),
    .USER_ENABLE   (1),
    .USER_WIDTH    (BITS_CONFIG)
  ) DW (
    .clk           (aclk       ),
    .rstn          (aresetn    ),
    .s_axis_tvalid (s_axis_tvalid),
    .s_axis_tready (s_axis_tready),
    .s_axis_tdata  (s_axis_tdata),
    .s_axis_tkeep  (s_axis_tkeep),
    .s_axis_tlast  (s_axis_tlast),
    .s_axis_tuser  (s_config    ),
    .m_axis_tvalid (dw_m_valid     ),
    .m_axis_tready (dw_m_ready     ),
    .m_axis_tdata  (dw_m_data_flat ),
    .m_axis_tlast  (dw_m_last      ),
    .m_axis_tuser  (dw_config      ),
    // Extras
    .s_axis_tid    ('0),
    .s_axis_tdest  ('0),
    .m_axis_tid    (),
    .m_axis_tdest  (),
    .m_axis_tkeep  ()
  );

  wire dw_m_handshake      = dw_m_valid     && dw_m_ready;
  wire dw_m_last_handshake = dw_m_handshake && dw_m_last;
 // wire and_ready = &m_axis_tready;


  //  STATE MACHINE: WRITE
  always_ff @(posedge aclk `OR_NEGEDGE(aresetn)) 
    if (!aresetn)                                              state_write <= W_IDLE_S;
    else unique case (state_write)
      W_IDLE_S    : if (&done_read [i_write]  )                state_write <= W_WRITE_S;
      W_WRITE_S   : if (dw_m_last_handshake   )                state_write <= W_FILL_1_S;    // dw_m_last_handshake and bram_w_full[w_i] should be same
      W_FILL_1_S  :                                            state_write <= W_SWITCH_S;
      W_SWITCH_S  :                                            state_write <= W_IDLE_S;
    endcase 
  
  assign dw_m_ready = (state_write == W_WRITE_S);


  //  STATE MACHINE: READ
  genvar col;
  generate
  for(col=0; col<COLS; col = col+1) begin : col_read_fsm
    always_ff @(posedge aclk `OR_NEGEDGE(aresetn))
      if (!aresetn)                                 state_read[col]<= R_IDLE_S;
      else unique case (state_read[col])
        R_IDLE_S        : if (done_write [i_read[col]])  state_read[col] <= CONFIG_BEATS==0 ? (fill_skid_buffer_cntr[col]>=2*DELAY_W_RAM-1 ? R_READ_S : R_IDLE_S) : R_PASS_CONFIG_S;
        R_PASS_CONFIG_S : if (last_config[col] && fill_skid_buffer_cntr[col]>=2*DELAY_W_RAM-1)  state_read[col] <= R_READ_S;
        R_READ_S        : if (m_axis_tlast[col]) state_read[col] <= R_SWITCH_S;
        R_SWITCH_S      :                           state_read[col] <= R_IDLE_S;
      endcase 
  end
  endgenerate

  
  // FILL_SKID_BUFFER_CNTR
  // This counter counts cycles for skid buffer to get filled. 
  // The read state machine stays in IDLE state with RAM rden=1 for 2*DELAY_W_RAM cycles so that
  // the skid buffer is completely filled with data when it enters the read state.
   //genvar col;
   generate
   for(col=0; col<COLS; col = col+1) begin : col_fill_sb
    always_ff @(posedge aclk `OR_NEGEDGE(aresetn))
      if (!aresetn) fill_skid_buffer_cntr[col]<= 0;
      else begin
        if (state_read[col]==R_SWITCH_S) fill_skid_buffer_cntr[col]<= 0; // reset cntr on switch
        else if (CONFIG_BEATS==0 ? (state_read[col]==R_IDLE_S && done_write [i_read[col]]) : (state_read[col]==R_PASS_CONFIG_S)) begin 
          if (fill_skid_buffer_cntr[col] < 2*DELAY_W_RAM) fill_skid_buffer_cntr[col] <= fill_skid_buffer_cntr[col] + 1;
        end
      end
    end
   endgenerate

  always_comb begin

    en_count_config   = '0;
    m_axis_tvalid     = '0;
    bram_reg_resetn   = '1;

    for (int col=0; col<COLS; col = col+1) begin
    unique case (state_read[col])
      R_IDLE_S        : begin
                          en_count_config [col] = 1;
                        end
      R_PASS_CONFIG_S : begin
                          m_axis_tvalid[col]      = bram_reg_m_valid[col];
                          en_count_config[col]   = m_axis_tvalid[col] & m_axis_tready[col];
                        end
      R_READ_S        : begin
                            m_axis_tvalid[col]      = bram_reg_m_valid[col];
                        end
      R_SWITCH_S      : begin
                          bram_reg_resetn[col]    = 0;
                        end
    endcase 
    end
  end

  // Switching RAMs
  always_ff @(posedge aclk `OR_NEGEDGE(aresetn))
    if (!aresetn)  {i_write, i_read} <= 0;
    else begin
      if (state_write == W_SWITCH_S)  i_write <= !i_write;
      for (int col=0; col<COLS; col = col+1) begin
        if (state_read[col]  == R_SWITCH_S)  i_read[col] <= !i_read[col];
      end
    end

  genvar i;
  generate
    for (i=0; i<2; i++) begin : i0
      //  FSM Output Decoders for indexed signals
      always_comb begin
        bram_resetn     [i] = 1;
        bram_wen        [i] = 0;
        en_ref          [i] = 0;
        done_write_next [i] = done_write[i];
        
        done_read_next  [i]    = done_read[i];
        bram_m_ready    [i]    = '0;

        if (i==i_write) begin
          en_ref          [i] = dw_m_last_handshake;
          done_write_next [i] = 0;
          case (state_write)
            W_WRITE_S   :   bram_wen        [i] = dw_m_valid;
            W_SWITCH_S  : begin  
                            bram_resetn     [i] = 0;
                            done_write_next [i] = 1;
                          end
          endcase 
        end

        for (int j=0; j<COLS; j = j+1) begin :j0
          if (i==i_read[j]) begin

            if (CONFIG_BEATS==0 ? (state_read[j]==R_IDLE_S && done_write [i_read[j]] && fill_skid_buffer_cntr[j]<=2*DELAY_W_RAM-1) : (state_read[j]==R_PASS_CONFIG_S && fill_skid_buffer_cntr[j]<=2*DELAY_W_RAM-1)) begin
              done_read_next [i][j] = 0;
              bram_m_ready   [i][j] = 1;
            end

            case (state_read[j])
              R_PASS_CONFIG_S, R_READ_S :   bram_m_ready   [i][j] = m_axis_tready[j];
              R_SWITCH_S                :   done_read_next [i][j] = 1;
            endcase 
          end
        end
      end

      config_st ref_i;
      assign ref_i = ref_config[i];
      genvar j;
      for (j=0; j<COLS; j++) begin : col_RAM

        // always_ff@(posedge aclk `OR_NEGEDGE(aresetn)) begin
        //   if(j!=0) begin
        //     if (!aresetn) bram_m_ready[i][j] <= 0;
        //     else begin
        //       //if(and_ready)
        //         bram_m_ready[i][j] <= bram_m_ready[i][j-1];
        //     end
        //   end
        // end
        cyclic_bram #(
          .R_DEPTH      (BRAM_DEPTH),
          .R_DATA_WIDTH (BRAM_WIDTH),
          .W_DATA_WIDTH (BRAM_WIDTH),
          .LATENCY      (DELAY_W_RAM ),
          .ABSORB       (0)
        ) BRAM (
          .clk          (aclk),
          .clken        (1'b1),
          .resetn_global(aresetn),
          .resetn_local (bram_resetn [i]),
          .s_data       (dw_m_data_flat[WORD_WIDTH*(j+1)-1:WORD_WIDTH*j]),
          .w_en         (bram_wen    [i]),
          .m_data       (bram_m_data [i][WORD_WIDTH*(j+1)-1:WORD_WIDTH*j]),
          .r_en         (bram_m_ready[i][j]),
          .r_addr_min   (BITS_ADDR'(CONFIG_BEATS)),
          .r_addr_max   (ref_i.addr_max )
        );
      end

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
      
      always_ff @(posedge aclk `OR_NEGEDGE(aresetn))
        if (!aresetn) begin
          done_write[i] <= 0;
          done_read [i] <= '1;
        end else begin
          done_write[i] <= done_write_next[i];
          done_read [i] <= done_read_next [i];
        end

      // Reference Registers
      always_ff @(posedge aclk `OR_NEGEDGE(aresetn))
        if (!aresetn)       ref_config [i] <= '0;
        else if (en_ref[i]) ref_config [i] <= dw_config;
    end
  endgenerate

  genvar j;
  generate
    for (j=0; j<COLS; j++) begin : j_skidbuf
      n_delay #(.N(DELAY_W_RAM ), .W(1)) BRAM_VALID (.c(aclk), .rng(aresetn), .rnl(bram_reg_resetn[j]), .e(1'b1), .i(bram_m_ready[i_read[j]][j]), .o(bram_m_valid[j]));

      axis_pipeline_register2 # (
        .DATA_WIDTH  (BRAM_WIDTH),
        .KEEP_ENABLE (0),
        .KEEP_WIDTH  (1),
        .LAST_ENABLE (0),
        .ID_ENABLE   (0),
        .DEST_ENABLE (0),
        .USER_ENABLE (0),
        .REG_TYPE    (2), // skid buffer
        .LENGTH      (DELAY_W_RAM )
      ) REG_PIPE (
        .clk          (aclk),
        .rstn         (aresetn),
        .rstn_local   (bram_reg_resetn[j]),
        .s_axis_tdata (bram_m_data [i_read[j]][WORD_WIDTH*(j+1)-1:WORD_WIDTH*j]),
        .s_axis_tvalid(bram_m_valid[j]),
        .m_axis_tdata (m_axis_tdata[j]),
        .m_axis_tvalid(bram_reg_m_valid[j]),
        .m_axis_tready(bram_m_ready[i_read[j]][j]),
        // Unused
        .s_axis_tkeep ('0),
        .s_axis_tlast ('0),
        .s_axis_tid   ('0),
        .s_axis_tdest ('0),
        .s_axis_tuser ('0),
        .s_axis_tready(),
        .m_axis_tkeep (),
        .m_axis_tlast (),
        .m_axis_tid   (),
        .m_axis_tdest (),
        .m_axis_tuser ()
      );

      // axis_pipeline_register2 # (
      //   .DATA_WIDTH  (BRAM_WIDTH),
      //   .KEEP_ENABLE (0),
      //   .KEEP_WIDTH  (1),
      //   .LAST_ENABLE (0),
      //   .ID_ENABLE   (0),
      //   .DEST_ENABLE (0),
      //   .USER_ENABLE (0),
      //   .REG_TYPE    (2), // skid buffer
      //   .LENGTH      (DELAY_W_RAM )
      // ) REG_PIPE_2 (
      //   .clk          (aclk),
      //   .rstn         (aresetn),
      //   .rstn_local   (bram_reg_resetn[j]),
      //   .s_axis_tdata (sb_data[j]),
      //   .s_axis_tvalid(sb_valid[j]),
      //   .m_axis_tdata (m_axis_tdata[j]),
      //   .m_axis_tvalid(bram_reg_m_valid[j]),
      //   .m_axis_tready(bram_m_ready[i_read[j]][j]),
      //   // Unused
      //   .s_axis_tkeep ('0),
      //   .s_axis_tlast ('0),
      //   .s_axis_tid   ('0),
      //   .s_axis_tdest ('0),
      //   .s_axis_tuser ('0),
      //   .s_axis_tready(sb_ready[j]),
      //   .m_axis_tkeep (),
      //   .m_axis_tlast (),
      //   .m_axis_tid   (),
      //   .m_axis_tdest (),
      //   .m_axis_tuser ()
      // );
    end
  endgenerate

  // Counters
  logic [COLS-1:0][BITS_XW -1:0] c_cols;

  wire [COLS-1:0] copy_config;
  config_st [COLS-1:0] ref_i_read;

  generate
  for (i=0; i<COLS; i++ ) begin : i1
    assign copy_config[i] = (state_read[i] == R_IDLE_S) && done_write [i_read[i]];
    assign ref_i_read[i] = ref_config[i_read[i]];
  end
  endgenerate
 

  wire [BITS_CONFIG_BEATS-1:0] config_beats_const = CONFIG_BEATS-1;

  generate 
  for (i=0; i<COLS; i++ ) begin : i_cntr
    wire en_kw       = m_axis_tvalid[i] && m_axis_tready[i] && state_read[i] == R_READ_S;

    counter #(.W(BITS_CONFIG_BEATS)) C_CONFIG    (.clk(aclk), .rstn_g(aresetn), .rst_l(copy_config[i]), .en(en_count_config[i]), .max_in(                      config_beats_const     ), .last_clk(lc_config[i]), .last(l_config[i]), .first(),          .count()         );
    counter #(.W(BITS_KW          )) C_KW        (.clk(aclk), .rstn_g(aresetn), .rst_l(copy_config[i]), .en(en_kw             ), .max_in(BITS_KW          '( 2*ref_i_read[i].kw2     )), .last_clk(lc_kw    [i]), .last(l_kw    [i]), .first(f_kw  [i]), .count()         );
    counter #(.W(BITS_CI          )) C_CI        (.clk(aclk), .rstn_g(aresetn), .rst_l(copy_config[i]), .en(lc_kw          [i]), .max_in(BITS_CI          '(   ref_i_read[i].cin_1   )), .last_clk(lc_cin   [i]), .last(l_cin   [i]), .first(f_cin [i]), .count()         );
    counter #(.W(BITS_XW          )) C_XW        (.clk(aclk), .rstn_g(aresetn), .rst_l(copy_config[i]), .en(lc_cin         [i]), .max_in(BITS_XW          '(   ref_i_read[i].cols_1  )), .last_clk(lc_cols  [i]), .last(l_cols  [i]), .first(f_cols[i]), .count(c_cols[i]));
    counter #(.W(BITS_IM_BLOCKS   )) C_IM_BLOCKS (.clk(aclk), .rstn_g(aresetn), .rst_l(copy_config[i]), .en(lc_cols        [i]), .max_in(BITS_IM_BLOCKS   '(   ref_i_read[i].blocks_1)), .last_clk(lc_blocks[i]), .last(l_blocks[i]), .first(),          .count()         );
    counter #(.W(BITS_XN          )) C_XN        (.clk(aclk), .rstn_g(aresetn), .rst_l(copy_config[i]), .en(lc_blocks      [i]), .max_in(BITS_XN          '(   ref_i_read[i].xn_1    )), .last_clk(lc_xn    [i]), .last(l_xn    [i]), .first(),          .count()         );
  
  // Last & User

    assign m_axis_tlast[i] = lc_xn[i];
    assign last_config[i] = lc_config[i];

    assign m_axis_tuser[i].is_config        = state_read[i]  == R_PASS_CONFIG_S;
    assign m_axis_tuser[i].kw2              = ref_i_read[i].kw2;
    assign m_axis_tuser[i].is_w_first_clk   = f_cols[i] && f_cin[i] && f_kw[i];
    assign m_axis_tuser[i].is_cin_last      = l_kw[i]   && l_cin[i];
    assign m_axis_tuser[i].is_w_first_kw2   = (ref_i_read[i].cols_1 - c_cols[i]) < BITS_XW'(ref_i_read[i].kw2);
    assign m_axis_tuser[i].is_w_last        = l_cols[i];
  end
  endgenerate

  // generate
  //   for (genvar j=0; j<COLS; j++) begin

  //   always_ff@(posedge aclk) begin
  //     if(j!=0) begin
  //       //if(and_ready) begin
  //       m_axis_tlast[j] <= m_axis_tlast[j-1];
  //       m_axis_tuser[j] <= m_axis_tuser[j-1];
  //       last_config[j]  <=  last_config[j-1];
  //       //end
  //     end

  //   end
  //   end
  // endgenerate

endmodule



module axis_sync #(
    parameter   COLS                    = `COLS)(
  input logic [COLS-1:0] weights_m_valid, m_axis_tready,
  input logic aclk,
  input logic pixels_m_valid,
  input tuser_st [COLS-1:0] weights_m_user,
  input logic [COLS-1:0] pixels_m_valid_pipe,
  output logic [COLS-1:0] m_axis_tvalid, weights_m_ready, 
  output logic pixels_m_ready
);

genvar i;
generate
for ( i=0; i<COLS; i++) begin : sync_val
  assign m_axis_tvalid[i]   = weights_m_valid[i];// && (pixels_m_valid_pipe[i] || weights_m_user[i].is_config);
  assign weights_m_ready[i] = m_axis_tready[i]   && (pixels_m_valid_pipe[i] || weights_m_user[i].is_config);
end
endgenerate
  assign pixels_m_ready  = m_axis_tready[0]   && weights_m_valid[0] && !weights_m_user[0].is_config;
endmodule