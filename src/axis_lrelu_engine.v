module axis_lrelu_engine #(
    WORD_WIDTH_IN  = 32,
    WORD_WIDTH_OUT = 8 ,
    TUSER_WIDTH    = 8 ,
    WORD_WIDTH_CONFIG = 8,

    UNITS   = 8,
    GROUPS  = 2,
    COPIES  = 2,
    MEMBERS = 2,

    CONFIG_BEATS_3X3_1 = 21-1,
    CONFIG_BEATS_1X1_1 = 9 -1,
    
    LATENCY_FIXED_2_FLOAT =  6,
    LATENCY_FLOAT_32      = 16,

    INDEX_IS_3X3     = 0
    INDEX_IS_RELU    = 1,
    INDEX_IS_MAX     = 2,
    INDEX_IS_NOT_MAX = 3,
    INDEX_IS_TOP     = 4,
    INDEX_IS_BOTTOM  = 5,
    INDEX_IS_LEFT    = 6,
    INDEX_IS_RIGHT   = 7
  )(
    aclk         ,
    aresetn      ,
    s_axis_tvalid,
    s_axis_tready,
    s_axis_tdata , // mcgu
    s_axis_tuser ,
    s_axis_tkeep ,
    s_axis_tlast ,
    m_axis_tvalid,
    m_axis_tready,
    m_axis_tdata , // cgu
    m_axis_tuser ,
    m_axis_tkeep 
  );

    input  wire aclk, aresetn;
    input  wire s_axis_tvalid, s_axis_tlast, m_axis_tready;
    output wire m_axis_tvalid, s_axis_tready;
    input  wire [TUSER_WIDTH-1:0] s_axis_tuser;
    output wire [1:0] m_axis_tuser;
    input  wire [MEMBERS * COPIES * GROUPS-1:0] s_axis_tkeep; 
    output wire [          COPIES * GROUPS-1:0] m_axis_tkeep; 

    input  wire [MEMBERS * COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_axis_tdata;
    output wire [          COPIES * GROUPS * UNITS * WORD_WIDTH_OUT-1:0] m_axis_tdata;

    wire [COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_data_e;
    wire [COPIES * GROUPS * UNITS * WORD_WIDTH_OUT-1:0] m_data_e;
    wire s_valid_e, s_last_e, m_valid_e;
    wire [COPIES * GROUPS-1:0] s_keep_e, m_keep_e; 
    wire [TUSER_WIDTH-1:0] s_user_e;
    wire [1:0] m_user_e;
    wire s_ready_slice;

    localparam BYTES_IN = WORD_WIDTH_IN/8;

    /*
      AXIS DEMUX

      * sel_config is driven by state machine 
        - 1: slave bypasses dw and directly connects to config port
        - 0: slave connects to dw bank
    */
    wire sel_config, dw_s_valid, dw_s_ready, config_s_valid, config_s_ready;

    assign dw_s_valid     = sel_config ? 0              : s_axis_tvalid;
    assign config_s_valid = sel_config ? s_axis_tvalid  : 0;
    assign s_axis_tready  = sel_config ? config_s_ready : dw_s_ready;

    /*
      STATE MACHINE

      * initial state: WRITE_1_S

      * PASS_S:
        - connect dw to slave
        - when a tlast enters dw, switch to BLOCK
      * BLOCK_S:
        - connect config to slave
        - keep s_ready low (block transactions)
        - wait until all members of last transactions leave dw
        - when tlast leaves dw, switch to RESET
      * RESET_S:
        - pass a config_resetn for one clock
        - keep s_ready low (block transactions)
        - this is tied to the delays. This goes just behind the data and clears 
            the bram buffer registers just after they process the tlast from previous cycle.
      * WRITE_1_S:
        - connect engine's config to slave
        - Get the first config beat
        - Also sample whether it is 3x3 or 1x1. 
        - Hence set the config_count as num_beats-1
      * WRITE_2_S:
        - connect engine's config to slave
        - config_count decremets at every config_handshake
        - when config_count = 0 and handshake, switch to PASS_S
      * FILL_S
        - Block input and wait for (BRAM_LATENCY+1) clocks for BRAMs to get valid
      * default:
        - same as PASS_S
    */
    wire config_handshake, resetn_config, s_vr_last_conv_out, s_vr_last_dw_out;

    assign s_vr_last_conv_out = s_axis_tlast  && s_axis_tvalid && s_axis_tready;
    assign s_vr_last_dw_out   = s_last_e      && s_valid_e     && s_ready_slice;
    assign config_handshake   = s_axis_tvalid && config_s_ready;

    localparam PASS_S    = 0;
    localparam BLOCK_S   = 1;
    localparam RESET_S   = 2;
    localparam WRITE_1_S = 3;
    localparam WRITE_2_S = 4;
    localparam FILL_S    = 5;

    wire [2:0] state, state_next;
    register #(
      .WORD_WIDTH   (3), 
      .RESET_VALUE  (WRITE_1_S)
    ) STATE (
      .clock        (clk   ),
      .resetn       (resetn),
      .clock_enable (1),
      .data_in      (state_next),
      .data_out     (state)
    );

    localparam CONFIG_BEATS_BITS = $clog2(CONFIG_BEATS_3X3);
    wire [CONFIG_BEATS_BITS-1:0] count_config, count_config_next, num_beats_1;    
    register #(
      .WORD_WIDTH   (CONFIG_BEATS_BITS), 
      .RESET_VALUE  (0)
    ) COUNT_CONFIG (
      .clock        (clk   ),
      .resetn       (resetn),
      .clock_enable (config_handshake ),
      .data_in      (count_config_next),
      .data_out     (count_config)
    );
    localparam FILL_BITS = $clog2(BRAM_LATENCY+1);
    wire [FILL_BITS-1:0] count_fill, count_fill_next;    
    register #(
      .WORD_WIDTH   (FILL_BITS), 
      .RESET_VALUE  (0)
    ) FILL_CONFIG (
      .clock        (clk   ),
      .resetn       (resetn),
      .clock_enable (s_ready_slice ),
      .data_in      (count_fill_next),
      .data_out     (count_fill)
    );

    always @ (*) begin
      state_next = state;
      case (state)
        PASS_S    : if (s_vr_last_conv_out) state_next = BLOCK_S;
        BLOCK_S   : if (s_vr_last_dw_out  ) state_next = RESET_S;
        RESET_S   : if (s_ready_slice)      state_next = WRITE_S;
        WRITE_1_S : if (config_handshake)   state_next = WRITE_2_S;
        WRITE_2_S : if ((count_config == 0)              && config_handshake) state_next = FILL_S;
        FILL_S    : if (count_fill == (BRAM_LATENCY+1-1) && s_ready_slice )   state_next = PASS_S;
        default   : state_next = state;
      endcase
    end

    always @ (*) begin
      case (state)
        PASS_S  : begin
                    sel_config        = 0;
                    config_s_ready    = 0;
                    resetn_config     = 1;
                    count_config_next = 0;
                    count_fill_next   = 0;
                  end
        BLOCK_S : begin
                    sel_config        = 1;
                    config_s_ready    = 0;
                    resetn_config     = 1;
                    count_config_next = 0;
                    count_fill_next   = 0;
                  end
        RESET_S : begin
                    sel_config        = 1;
                    config_s_ready    = 0;
                    resetn_config     = 0;
                    count_config_next = 0;
                    count_fill_next   = 0;
                  end
        WRITE_1_S:begin
                    sel_config        = 1;
                    config_s_ready    = s_ready_slice;
                    resetn_config     = 1;
                    count_config_next = s_axis_tuser[INDEX_IS_3X3] ? CONFIG_BEATS_3X3_1 : CONFIG_BEATS_1X1_1;
                    count_fill_next   = 0;
                  end
        WRITE_2_S:begin
                    sel_config        = 1;
                    config_s_ready    = s_ready_slice;
                    resetn_config     = 1;
                    count_config_next = count_config - 1;
                    count_fill_next   = 0;
                  end
        FILL_S:   begin
                    sel_config        = 1;
                    config_s_ready    = 0;
                    resetn_config     = 1;
                    count_config_next = 0;
                    count_fill_next   = count_fill + 1;
                  end
        default  :begin
                    sel_config        = 0;
                    config_s_ready    = 0;
                    resetn_config     = 1;
                    count_config_next = 0;
                    count_fill_next   = 0;
                  end
      endcase
    end

    /*
      DATAWIDTH CONVERTER BANKS

      * Size: MEMBERS -> 1 = 8x32->32 = 256 -> 32
      * Number: COPIES x GROUPS x UNITS = 2x2x8 = 32
    */
    generate
      for(genvar c=0; c<COPIES; c=c+1) begin: c
        for(genvar g=0; g<GROUPS; g=g+1) begin: g
          /*
            TKEEP
          */
          wire [BYTES_IN*MEMBERS-1:0] dw_s_keep;
          for(genvar m=0; m<MEMBERS; m=m+1) begin: m
            assign dw_s_keep[BYTES_IN*(m+1)-1:BYTES_IN*m] = {BYTES_IN{s_axis_tkeep[COPIES*GROUPS*m + GROUPS*c + g]}};
          end
          wire [BYTES_IN-1:0] dw_m_keep;
          assign s_keep_e[GROUPS*c + g] = dw_m_keep[0];

          for(genvar u=0; u<UNITS; u=u+1) begin: u
            
            wire [MEMBERS * WORD_WIDTH_IN-1:0] dw_s_data;
            wire [          WORD_WIDTH_IN-1:0] dw_m_data;

            for(genvar m=0; m<MEMBERS; m=m+1) begin: m
              assign dw_s_data[(m+1)*WORD_WIDTH_IN-1: m*WORD_WIDTH_IN] = s_axis_tdata[(GROUPS*UNITS*MEMBERS*c + UNITS*MEMBERS*g + MEMBERS*u + m +1)*WORD_WIDTH_IN-1 : (GROUPS*UNITS*MEMBERS*c + UNITS*MEMBERS*g + MEMBERS*u + m)*WORD_WIDTH_IN];
            end

            // DWIDTH 8 words -> 1 word
            if (c==0 && g==0) begin
              axis_dw_m_1_active dw (
                .aclk           (aclk),          
                .aresetn        (aresetn),             
                .s_axis_tvalid  (dw_s_valid),  
                .s_axis_tready  (dw_s_ready),  
                .s_axis_tdata   (dw_s_data),    
                .s_axis_tkeep   (dw_s_keep),    
                .s_axis_tlast   (s_axis_tlast),    
                .s_axis_tid     (s_axis_tuser),   

                .m_axis_tvalid  (s_valid_e),  
                .m_axis_tready  (s_ready_slice), 
                .m_axis_tdata   (dw_m_data), 
                .m_axis_tkeep   (dw_m_keep), 
                .m_axis_tlast   (s_last_e),  
                .m_axis_tid     (s_user_e)   
              );
            end else begin
              axis_dw_m_1 dw (
                .aclk           (aclk),          
                .aresetn        (aresetn),       
                .s_axis_tvalid  (s_axis_tvalid), 
                .s_axis_tdata   (dw_s_data),
                .s_axis_tkeep   (dw_s_keep),
                .m_axis_tready  (s_ready_slice),  
                .m_axis_tdata   (dw_m_data),
                .m_axis_tkeep   (dw_m_keep)
              );
            end
            assign s_data_e[(GROUPS*UNITS*c + UNITS*g + u +1)*WORD_WIDTH_IN-1:(GROUPS*UNITS*c + UNITS*g + u)*WORD_WIDTH_IN] = dw_m_data;
          end
        end
      end
    endgenerate

    lrelu_engine #(
      .WORD_WIDTH_IN  (WORD_WIDTH_IN ),
      .WORD_WIDTH_OUT (WORD_WIDTH_OUT),
      .TUSER_WIDTH    (TUSER_WIDTH   ),
      .WORD_WIDTH_CONFIG(WORD_WIDTH_CONFIG ),

      .UNITS   (UNITS  ),
      .GROUPS  (GROUPS ),
      .COPIES  (COPIES ),
      .MEMBERS (MEMBERS),

      .LATENCY_FIXED_2_FLOAT (LATENCY_FIXED_2_FLOAT),
      .LATENCY_FLOAT_32      (LATENCY_FLOAT_32     ),

      .INDEX_IS_3X3     (INDEX_IS_3X3    ),
      .INDEX_IS_RELU    (INDEX_IS_RELU   ),
      .INDEX_IS_MAX     (INDEX_IS_MAX    ),
      .INDEX_IS_NOT_MAX (INDEX_IS_NOT_MAX),
      .INDEX_IS_TOP     (INDEX_IS_TOP    ),
      .INDEX_IS_BOTTOM  (INDEX_IS_BOTTOM ),
      .INDEX_IS_LEFT    (INDEX_IS_LEFT   ),
      .INDEX_IS_RIGHT   (INDEX_IS_RIGHT  )
    )
    engine
    (
      .clk              (aclk    ),
      .clken            (s_ready_slice),
      .resetn           (aresetn  ),
      .s_valid          (s_valid_e),
      .s_user           (s_user_e ),
      .s_keep_flat_cg   (s_keep_e ),
      .m_valid          (m_valid_e),
      .m_user           (m_user_e ),
      .m_keep_flat_cg   (m_keep_e ),
      .s_data_flat_cgu  (s_data_e ),
      .m_data_flat_cgu  (m_data_e ),

      .resetn_config     (resetn_config ),
      .s_valid_config    (config_s_valid),
      .s_data_conv_out   (s_axis_tdata  )
    );

    axis_reg_slice_lrelu slice (
      .aclk           (aclk           ),
      .aresetn        (aresetn        ),
      .s_axis_tvalid  (m_valid_e      ),
      .s_axis_tready  (s_ready_slice  ),
      .s_axis_tdata   (m_data_e       ),
      .s_axis_tid     (m_keep_e       ),
      .s_axis_tuser   (m_user_e       ),  

      .m_axis_tvalid  (m_axis_tvalid  ),
      .m_axis_tready  (m_axis_tready  ),
      .m_axis_tdata   (m_axis_tdata   ),
      .m_axis_tid     (m_axis_tkeep   ),
      .m_axis_tuser   (m_axis_tuser   ) 
    );

endmodule