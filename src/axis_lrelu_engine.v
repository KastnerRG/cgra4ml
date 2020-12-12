module axis_lrelu_engine #(
    WORD_WIDTH_IN  = 32,
    WORD_WIDTH_OUT = 8 ,
    TUSER_WIDTH    = 4,
    UNITS   = 8,
    GROUPS  = 2,
    COPIES  = 2,
    MEMBERS = 2
  )
  (
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
                .s_axis_tvalid  (s_axis_tvalid),  
                .s_axis_tready  (s_axis_tready),  
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
      .UNITS   (UNITS  ),
      .GROUPS  (GROUPS ),
      .COPIES  (COPIES ),
      .MEMBERS (MEMBERS)
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
      .m_data_flat_cgu  (m_data_e )
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