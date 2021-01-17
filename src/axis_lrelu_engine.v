/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.

Create Date: 16/12/2020
Design Name: AXIS RELU ENGINE
Tool Versions: Vivado 2018.2
Description:  * Performs LRelu with requantization
              * Requires slave to give a tlast at the last beat of each iteration
                  and give config bits at the beginning of next iteration
              * Contains DW converter to reduce width (and increase rate) 
                  by factor of MEMBERS
              * Config state machine (present here) overrides the DW converter
                  by looking at tlast on either side of DW
                  to pull config bits into the engine at full width
              * w_sel state machine (present in engine) counts the BRAMs (10 of them)
                  to fill them with config
              * Afterwards DW converter is connected to the slave for data to flow

Revision:
Revision 0.01 - File Created
Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////*/


module axis_lrelu_engine (
    aclk         ,
    aresetn      ,
    s_axis_tvalid,
    s_axis_tready,
    s_axis_tdata , // mcgu
    s_axis_tuser ,
    s_axis_tlast ,
    m_axis_tvalid,
    m_axis_tready,
    m_axis_tdata , // cgu
    m_axis_tuser 
  );
    parameter WORD_WIDTH_IN     = 32;
    parameter WORD_WIDTH_OUT    = 8 ;
    parameter WORD_WIDTH_CONFIG = 8 ;

    parameter UNITS   = 8;
    parameter GROUPS  = 2;
    parameter COPIES  = 2;
    parameter MEMBERS = 2;

    parameter ALPHA = 16'd11878;

    parameter CONFIG_BEATS_3X3_2 = 19; // D(1) + A(2) + B(9*2) -2 = 21-2 = 19
    parameter CONFIG_BEATS_1X1_2 = 11; // D(1) + A(2*3) + B(2*3) -2 = 13 -2 = 11

    parameter LATENCY_FIXED_2_FLOAT = 6 ;
    parameter LATENCY_FLOAT_32      = 16;
    parameter BRAM_LATENCY          = 2 ;

    parameter I_IS_NOT_MAX      = 0;
    parameter I_IS_MAX          = I_IS_NOT_MAX      + 1;
    parameter I_IS_LRELU        = I_IS_MAX          + 1;
    parameter I_IS_TOP_BLOCK    = I_IS_LRELU        + 1;
    parameter I_IS_BOTTOM_BLOCK = I_IS_TOP_BLOCK    + 1;
    parameter I_IS_1X1          = I_IS_BOTTOM_BLOCK + 1;
    parameter I_IS_LEFT_COL     = I_IS_1X1          + 1;
    parameter I_IS_RIGHT_COL    = I_IS_LEFT_COL     + 1;

    parameter TUSER_WIDTH_MAXPOOL_IN     = 1 + I_IS_MAX  ;
    parameter TUSER_WIDTH_LRELU_FMA_1_IN = 1 + I_IS_LRELU;
    parameter TUSER_WIDTH_LRELU_IN       = 1 + I_IS_RIGHT_COL;

    input  wire aclk, aresetn;
    input  wire s_axis_tvalid, s_axis_tlast, m_axis_tready;
    output wire m_axis_tvalid;
    output reg  s_axis_tready;
    input  wire [TUSER_WIDTH_LRELU_IN  -1:0] s_axis_tuser;
    output wire [TUSER_WIDTH_MAXPOOL_IN-1:0] m_axis_tuser;

    input  wire [MEMBERS * COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_axis_tdata;
    output wire [          COPIES * GROUPS * UNITS * WORD_WIDTH_OUT-1:0] m_axis_tdata;

    wire [MEMBERS * COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_axis_tdata_cmgu;

    wire [COPIES * GROUPS * UNITS * WORD_WIDTH_IN -1:0] s_data_e, s_dw_slice_data;
    wire [COPIES * GROUPS * UNITS * WORD_WIDTH_OUT-1:0] m_data_e;
    wire s_valid_e, s_last_e, m_valid_e;
    wire s_dw_slice_valid, s_dw_slice_last, s_dw_slice_ready;
    wire [TUSER_WIDTH_LRELU_IN  -1:0] s_user_e, s_dw_slice_user;
    wire [TUSER_WIDTH_MAXPOOL_IN-1:0] m_user_e;
    wire s_ready_slice;

    localparam BYTES_IN = WORD_WIDTH_IN/8;

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
        - config_count decremets at every handshake
        - when config_count = 0 and handshake, switch to PASS_S if 3x3 or to FILL_S if 1x1
      * FILL_S
        - For 1x1 case, since B_cm is needed immediately
        - Block input and wait for (BRAM_LATENCY+1) clocks for BRAMs to get valid
        - For 3x3, B_rb is filled last and is needed after several clocks, so no need
      * default:
        - same as PASS_S
    */
    wire handshake, s_vr_last_conv_out, s_vr_last_dw_out;

    assign s_vr_last_conv_out = s_axis_tlast  && s_axis_tvalid && s_axis_tready;
    assign s_vr_last_dw_out   = s_last_e      && s_valid_e     && s_ready_slice;
    assign handshake          = s_axis_tvalid && s_axis_tready;

    localparam PASS_S    = 0;
    localparam BLOCK_S   = 1;
    localparam RESET_S   = 2;
    localparam WRITE_1_S = 3;
    localparam WRITE_2_S = 4;
    localparam FILL_S    = 5;

    wire [2:0] state;
    reg  [2:0] state_next;
    register #(
      .WORD_WIDTH   (3), 
      .RESET_VALUE  (WRITE_1_S)
    ) STATE (
      .clock        (aclk   ),
      .resetn       (aresetn),
      .clock_enable (1'b1),
      .data_in      (state_next),
      .data_out     (state)
    );

    localparam CONFIG_BEATS_BITS = $clog2(CONFIG_BEATS_3X3_2 + 1);
    wire [CONFIG_BEATS_BITS-1:0] count_config;
    reg  [CONFIG_BEATS_BITS-1:0] count_config_next;
    register #(
      .WORD_WIDTH   (CONFIG_BEATS_BITS), 
      .RESET_VALUE  (0)
    ) COUNT_CONFIG (
      .clock        (aclk   ),
      .resetn       (aresetn),
      .clock_enable (handshake ),
      .data_in      (count_config_next),
      .data_out     (count_config)
    );
    localparam FILL_DELAY = 2*BRAM_LATENCY-1;

    localparam FILL_BITS = $clog2(FILL_DELAY);
    wire [FILL_BITS-1:0] count_fill;
    reg  [FILL_BITS-1:0] count_fill_next;    
    register #(
      .WORD_WIDTH   (FILL_BITS), 
      .RESET_VALUE  (0)
    ) FILL_CONFIG (
      .clock        (aclk   ),
      .resetn       (aresetn),
      .clock_enable (s_ready_slice ),
      .data_in      (count_fill_next),
      .data_out     (count_fill)
    );
    /*
      Fill delay:
        - M clocks to fill
        - L clocks for first value to come out (and written)
        - L clocks for the rest of the buffer (L+1) to fill 
    */
    always @ (*) begin
      state_next = state;
      case (state)
        PASS_S    : if (s_vr_last_conv_out) state_next = BLOCK_S;
        BLOCK_S   : if (s_vr_last_dw_out  ) state_next = RESET_S;
        RESET_S   : if (s_ready_slice)      state_next = WRITE_1_S;
        WRITE_1_S : if (handshake)   state_next = WRITE_2_S;
        WRITE_2_S : if ((count_config == 0) && handshake) 
                      if (s_axis_tuser[I_IS_1X1]) state_next = FILL_S;
                      else                        state_next = PASS_S;
        FILL_S    : if (count_fill == FILL_DELAY && s_ready_slice )   state_next = PASS_S;
        default   : state_next = state;
      endcase
    end

    wire dw_s_ready;
    reg  config_s_valid, dw_s_valid, resetn_config, config_s_ready;

    always @ (*) begin
      case (state)
        PASS_S  : begin
                    config_s_valid    = 0;
                    dw_s_valid        = s_axis_tvalid;
                    s_axis_tready     = dw_s_ready;
                    
                    resetn_config     = 1;
                    count_config_next = 0;
                    count_fill_next   = 0;
                  end
        BLOCK_S : begin
                    config_s_valid    = 0;
                    dw_s_valid        = 0;
                    s_axis_tready     = 0;

                    resetn_config     = 1;
                    count_config_next = 0;
                    count_fill_next   = 0;
                  end
        RESET_S : begin
                    config_s_valid    = 0;
                    dw_s_valid        = 0;
                    s_axis_tready     = 0;

                    resetn_config     = 0;
                    count_config_next = 0;
                    count_fill_next   = 0;
                  end
        WRITE_1_S:begin
                    config_s_valid    = s_axis_tvalid;
                    dw_s_valid        = 0;
                    s_axis_tready     = s_ready_slice;

                    resetn_config     = 1;
                    count_config_next = s_axis_tuser[I_IS_1X1] ? CONFIG_BEATS_1X1_2 : CONFIG_BEATS_3X3_2;
                    count_fill_next   = 0;
                  end
        WRITE_2_S:begin
                    config_s_valid    = s_axis_tvalid;
                    dw_s_valid        = 0;
                    s_axis_tready     = s_ready_slice;

                    resetn_config     = 1;
                    count_config_next = count_config - 1;
                    count_fill_next   = 0;
                  end
        FILL_S:   begin
                    config_s_valid    = 0;
                    dw_s_valid        = 0;
                    s_axis_tready     = 0;

                    resetn_config     = 1;
                    count_config_next = 0;
                    count_fill_next   = count_fill + 1;
                  end
        default  :begin
                    config_s_valid    = 0;
                    dw_s_valid        = s_axis_tvalid;
                    s_axis_tready     = dw_s_ready;

                    resetn_config     = 1;
                    count_config_next = 0;
                    count_fill_next   = 0;
                  end
      endcase
    end
    
    wire is_1x1_config;
    assign is_1x1_config = s_axis_tuser[I_IS_1X1];

    /*
      DATAWIDTH CONVERTER BANKS

      * Size: GUM(W) -> GU(W) : 2*8*8*(26) -> 2*8*(26) : 3328 -> 416 : 416B -> 52B
      * Number: 2 (one per copy)
    */
    generate
      for(genvar c=0; c<COPIES; c=c+1) begin: c_gen

        // Transpose MCGU -> CGUM
        for (genvar g=0; g<GROUPS; g=g+1) begin: g_gen
          for (genvar u=0; u<UNITS; u=u+1) begin: u_gen
            for (genvar m=0; m<MEMBERS; m=m+1) begin: m_gen
              assign s_axis_tdata_cmgu [(c*MEMBERS*GROUPS*UNITS + m*GROUPS*UNITS + g*UNITS + u +1)*WORD_WIDTH_IN-1:(c*MEMBERS*GROUPS*UNITS + m*GROUPS*UNITS + g*UNITS + u)*WORD_WIDTH_IN] = s_axis_tdata[(m*COPIES*GROUPS*UNITS + c*GROUPS*UNITS + g*UNITS + u +1)*WORD_WIDTH_IN-1:(m*COPIES*GROUPS*UNITS + c*GROUPS*UNITS + g*UNITS + u)*WORD_WIDTH_IN];
            end
          end
        end

        wire [MEMBERS * GROUPS * UNITS * WORD_WIDTH_IN-1:0] dw_s_data_mgu;
        wire [          GROUPS * UNITS * WORD_WIDTH_IN-1:0] dw_m_data_gu ;
        
        assign dw_s_data_mgu = s_axis_tdata_cmgu[(c+1)*MEMBERS*GROUPS*UNITS*WORD_WIDTH_IN-1:(c)*MEMBERS*GROUPS*UNITS*WORD_WIDTH_IN];
        assign s_dw_slice_data[(c+1)*GROUPS*UNITS*WORD_WIDTH_IN-1:(c)*GROUPS*UNITS*WORD_WIDTH_IN] = dw_m_data_gu;

        if (c==0) begin
          axis_dw_gum_gu_active dw (
            .aclk           (aclk),          
            .aresetn        (aresetn),             
            .s_axis_tvalid  (dw_s_valid),  
            .s_axis_tready  (dw_s_ready),  
            .s_axis_tdata   (dw_s_data_mgu),
            .s_axis_tlast   (s_axis_tlast),    
            .s_axis_tid     (s_axis_tuser),   

            .m_axis_tvalid  (s_dw_slice_valid),  
            .m_axis_tready  (s_dw_slice_ready), 
            .m_axis_tdata   (dw_m_data_gu),
            .m_axis_tlast   (s_dw_slice_last),  
            .m_axis_tid     (s_dw_slice_user)   
          );
        end
        else begin
          axis_dw_gum_gu dw (
            .aclk           (aclk),          
            .aresetn        (aresetn),             
            .s_axis_tvalid  (dw_s_valid),  
            .s_axis_tdata   (dw_s_data_mgu),

            .m_axis_tready  (s_dw_slice_ready), 
            .m_axis_tdata   (dw_m_data_gu)
          );
        end
      end
    endgenerate

    axis_reg_slice_lrelu_dw dw_slice (
      .aclk           (aclk),                     
      .aresetn        (aresetn),              
      .s_axis_tvalid  (s_dw_slice_valid ),   
      .s_axis_tready  (s_dw_slice_ready ),   
      .s_axis_tdata   (s_dw_slice_data  ),    
      .s_axis_tlast   (s_dw_slice_last  ),    
      .s_axis_tuser   (s_dw_slice_user  ),   
      .m_axis_tvalid  (s_valid_e        ),  
      .m_axis_tready  (s_ready_slice    ),   
      .m_axis_tdata   (s_data_e         ),    
      .m_axis_tlast   (s_last_e         ),    
      .m_axis_tuser   (s_user_e         )     
    );

// assign s_valid_e        = s_dw_slice_valid ;
// assign s_dw_slice_ready = s_ready_slice;
// assign s_data_e         = s_dw_slice_data  ;
// assign s_last_e         = s_dw_slice_last  ;
// assign s_user_e         = s_dw_slice_user  ;

    lrelu_engine #(
      .WORD_WIDTH_IN  (WORD_WIDTH_IN ),
      .WORD_WIDTH_OUT (WORD_WIDTH_OUT),
      .WORD_WIDTH_CONFIG(WORD_WIDTH_CONFIG ),

      .UNITS   (UNITS  ),
      .GROUPS  (GROUPS ),
      .COPIES  (COPIES ),
      .MEMBERS (MEMBERS),

      .ALPHA   (ALPHA),

      .LATENCY_FIXED_2_FLOAT (LATENCY_FIXED_2_FLOAT),
      .LATENCY_FLOAT_32      (LATENCY_FLOAT_32     ),

      .I_IS_MAX             (I_IS_MAX            ),
      .I_IS_NOT_MAX         (I_IS_NOT_MAX        ),
      .I_IS_LRELU           (I_IS_LRELU          ),
      .I_IS_TOP_BLOCK       (I_IS_TOP_BLOCK      ),
      .I_IS_BOTTOM_BLOCK    (I_IS_BOTTOM_BLOCK   ),
      .I_IS_LEFT_COL        (I_IS_LEFT_COL       ),
      .I_IS_RIGHT_COL       (I_IS_RIGHT_COL      ),
      .I_IS_1X1             (I_IS_1X1            ),

      .TUSER_WIDTH_LRELU_IN       (TUSER_WIDTH_LRELU_IN      ),
      .TUSER_WIDTH_LRELU_FMA_1_IN (TUSER_WIDTH_LRELU_FMA_1_IN),
      .TUSER_WIDTH_MAXPOOL_IN     (TUSER_WIDTH_MAXPOOL_IN    )
    )
    engine
    (
      .clk              (aclk    ),
      .clken            (s_ready_slice),
      .resetn           (aresetn  ),
      .s_valid          (s_valid_e),
      .s_user           (s_user_e ),
      .m_valid          (m_valid_e),
      .m_user           (m_user_e ),
      .s_data_flat_cgu  (s_data_e ),
      .m_data_flat_cgu  (m_data_e ),

      .resetn_config     (resetn_config ),
      .s_valid_config    (config_s_valid),
      .is_1x1_config     (is_1x1_config ),
      .s_data_conv_out   (s_axis_tdata  )
    );

    axis_reg_slice_lrelu slice (
      .aclk           (aclk           ),
      .aresetn        (aresetn        ),
      .s_axis_tvalid  (m_valid_e      ),
      .s_axis_tready  (s_ready_slice  ),
      .s_axis_tdata   (m_data_e       ),
      .s_axis_tuser   (m_user_e       ),  

      .m_axis_tvalid  (m_axis_tvalid  ),
      .m_axis_tready  (m_axis_tready  ),
      .m_axis_tdata   (m_axis_tdata   ),
      .m_axis_tuser   (m_axis_tuser   ) 
    );

endmodule