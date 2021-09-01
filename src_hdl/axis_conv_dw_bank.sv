`include "params.v"

module axis_conv_dw_bank #(ZERO) (
  aclk             ,
  aresetn          ,

  s_axis_tdata     ,
  s_axis_tvalid    ,
  s_axis_tready    ,
  s_axis_tlast     ,
  s_axis_tuser     ,
  s_axis_tkeep     ,

  m_axis_tdata     ,
  m_axis_tvalid    ,
  m_axis_tready    ,
  m_axis_tlast     ,
  m_axis_tuser
);

  localparam IS_CONV_DW_SLICE     = `IS_CONV_DW_SLICE     ;
  localparam UNITS                = `UNITS                ;
  localparam GROUPS               = `GROUPS               ;
  localparam COPIES               = `COPIES               ;
  localparam MEMBERS              = `MEMBERS              ;
  localparam K                    = `DW_FACTOR_1          ;
  localparam WORD_WIDTH           = `WORD_WIDTH_ACC       ;
  localparam TUSER_WIDTH_LRELU_IN = `TUSER_WIDTH_LRELU_IN ; 

  localparam WORD_BYTES = WORD_WIDTH/8;
  localparam SUB_CORES      = MEMBERS/K;

  input logic aclk, aresetn;

  input  logic s_axis_tvalid, s_axis_tlast;
  output logic s_axis_tready;
  input  logic [COPIES -1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0][WORD_WIDTH          -1:0] s_axis_tdata;
  input  logic [COPIES -1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0][WORD_BYTES          -1:0] s_axis_tkeep;
  input  logic                          [MEMBERS-1:0]           [TUSER_WIDTH_LRELU_IN-1:0] s_axis_tuser;

  logic dw_m_valid, slice_s_valid, slice_s_ready, slice_s_last;
  logic [UNITS-1:0][WORD_BYTES-1:0] dw_m_keep;
  logic [UNITS-1:0][WORD_BYTES-1:0][TUSER_WIDTH_LRELU_IN  -1:0] dw_m_user;
  logic [COPIES -1:0][GROUPS-1:0][UNITS-1:0][WORD_WIDTH  -1:0] slice_s_data;

  input  logic m_axis_tready;
  output logic [COPIES -1:0][GROUPS-1:0][UNITS-1:0][WORD_WIDTH  -1:0] m_axis_tdata;
  output logic [TUSER_WIDTH_LRELU_IN  -1:0] m_axis_tuser;
  output logic m_axis_tvalid, m_axis_tlast;


  logic [COPIES-1:0][GROUPS-1:0][UNITS-1:0][SUB_CORES-1:0][K-1:0][WORD_WIDTH-1:0] dw_s_data;
  logic [COPIES-1:0][GROUPS-1:0][UNITS-1:0][SUB_CORES-1:0][K-1:0][WORD_BYTES-1:0] dw_s_keep;
  logic [COPIES-1:0][GROUPS-1:0][UNITS-1:0][SUB_CORES-1:0][WORD_WIDTH-1:0] dw_m_1_data;
  logic [COPIES-1:0][GROUPS-1:0][UNITS-1:0][SUB_CORES-1:0][WORD_BYTES-1:0] dw_m_1_keep;
  logic [UNITS-1:0][SUB_CORES-1:0][K-1:0][WORD_BYTES-1:0][TUSER_WIDTH_LRELU_IN  -1:0] dw_s_user;
  logic [UNITS-1:0][SUB_CORES-1:0]       [WORD_BYTES-1:0][TUSER_WIDTH_LRELU_IN  -1:0] dw_m_1_user;
  logic dw_m_1_last, dw_m_1_valid, dw_m_1_ready;


  generate
    for (genvar c=0; c<COPIES; c++) begin: C
      for (genvar g=0; g<GROUPS; g++) begin: G
        for (genvar u=0; u<UNITS; u++) begin: U

          for (genvar s=0; s<SUB_CORES; s++) begin
            for (genvar k=0; k<K; k++) begin
                
              assign dw_s_data[c][g][u][s][k] = s_axis_tdata[c][g][s*K + k][u];

              for (genvar b=0; b<WORD_BYTES; b++) begin
                assign dw_s_keep[c][g][u][s][k][b] = s_axis_tkeep[c][g][s*K + k][u][b];
                if (c==0 && g==0) 
                  assign dw_s_user[u][s][k][b] = s_axis_tuser[s*K + k];
              end
            end
          end

        if (K != 1) begin
          for (genvar s=0; s<SUB_CORES; s++)
            if (c==0 && g==0 && u==0)
              if (s==0)
                axis_dw_lrelu_1_active DW_K_1 (
                  .aclk           (aclk),          
                  .aresetn        (aresetn),             
                  .s_axis_tvalid  (s_axis_tvalid   ),  
                  .s_axis_tready  (s_axis_tready   ),  
                  .s_axis_tdata   (dw_s_data    [c][g][u][s]),
                  .s_axis_tlast   (s_axis_tlast    ),    
                  .s_axis_tuser   (dw_s_user    [u][s]),   
                  .s_axis_tkeep   (dw_s_keep    [c][g][u][s]),   

                  .m_axis_tvalid  (dw_m_1_valid    ),  
                  .m_axis_tready  (dw_m_1_ready    ), 
                  .m_axis_tdata   (dw_m_1_data  [c][g][u][s]),
                  .m_axis_tlast   (dw_m_1_last     ),  
                  .m_axis_tuser   (dw_m_1_user  [u][s]),
                  .m_axis_tkeep   (dw_m_1_keep  [c][g][u][s])   
                );
              else
                axis_dw_lrelu_1_active DW_K_1 (
                  .aclk           (aclk),          
                  .aresetn        (aresetn),             
                  .s_axis_tvalid  (s_axis_tvalid   ),  
                  .s_axis_tdata   (dw_s_data    [c][g][u][s]),
                  .s_axis_tlast   (s_axis_tlast    ),    
                  .s_axis_tuser   (dw_s_user    [u][s]),   
                  .s_axis_tkeep   (dw_s_keep    [c][g][u][s]),   

                  .m_axis_tready  (dw_m_1_ready    ), 
                  .m_axis_tdata   (dw_m_1_data  [c][g][u][s]),
                  .m_axis_tuser   (dw_m_1_user  [u][s]),
                  .m_axis_tkeep   (dw_m_1_keep  [c][g][u][s])   
                );
            else
              axis_dw_lrelu_1 DW_K_1 (
                .aclk           (aclk),          
                .aresetn        (aresetn),             
                .s_axis_tvalid  (s_axis_tvalid         ),  
                .s_axis_tdata   (dw_s_data    [c][g][u][s]),
                .s_axis_tkeep   (dw_s_keep    [c][g][u][s]),   

                .m_axis_tready  (dw_m_1_ready          ), 
                .m_axis_tdata   (dw_m_1_data  [c][g][u][s]),
                .m_axis_tkeep   (dw_m_1_keep  [c][g][u][s])   
              );
        end 
        else begin
          assign dw_m_1_data       = dw_s_data   ;
          assign dw_m_1_keep       = dw_s_keep   ;
          assign dw_m_1_user       = dw_s_user   ;
          assign dw_m_1_last       = s_axis_tlast;
          assign dw_m_1_valid      = s_axis_tvalid;
          assign s_axis_tready     = dw_m_1_ready;
        end

        if (c==0 && g==0 && u==0)begin
          axis_dw_lrelu_2_active DW_R_1 (
            .aclk           (aclk),          
            .aresetn        (aresetn),           
            .s_axis_tvalid  (dw_m_1_valid    ),
            .s_axis_tready  (dw_m_1_ready    ),
            .s_axis_tdata   (dw_m_1_data  [c][g][u]),
            .s_axis_tlast   (dw_m_1_last     ),
            .s_axis_tuser   (dw_m_1_user  [u]),
            .s_axis_tkeep   (dw_m_1_keep  [c][g][u]),

            .m_axis_tvalid  (dw_m_valid      ),  
            .m_axis_tready  (slice_s_ready   ), 
            .m_axis_tdata   (slice_s_data [c][g][u]),
            .m_axis_tlast   (slice_s_last    ),  
            .m_axis_tuser   (dw_m_user    [u]),
            .m_axis_tkeep   (dw_m_keep    [u])   
          );
          assign slice_s_valid = dw_m_valid && dw_m_keep[0][0];
        end
        else
          axis_dw_lrelu_2 DW_R_1 (
            .aclk           (aclk),          
            .aresetn        (aresetn),           
            .s_axis_tvalid  (dw_m_1_valid    ),
            .s_axis_tdata   (dw_m_1_data  [c][g][u]),
            .s_axis_tkeep   (dw_m_1_keep  [c][g][u]),

            .m_axis_tready  (slice_s_ready      ), 
            .m_axis_tdata   (slice_s_data [c][g][u])
          );

        end

        if (IS_CONV_DW_SLICE) begin
          if (c==0 && g==0)
            axis_reg_slice_lrelu_dw_active SLICE_1_1 (
              .aclk           (aclk),                     
              .aresetn        (aresetn),              
              .s_axis_tvalid  (slice_s_valid      ),   
              .s_axis_tready  (slice_s_ready      ),   
              .s_axis_tdata   (slice_s_data [c][g]),    
              .s_axis_tlast   (slice_s_last       ),    
              .s_axis_tid     (dw_m_user [0][0]   ),   

              .m_axis_tvalid  (m_axis_tvalid      ),  
              .m_axis_tready  (m_axis_tready      ),   
              .m_axis_tdata   (m_axis_tdata [c][g]),    
              .m_axis_tlast   (m_axis_tlast       ),    
              .m_axis_tid     (m_axis_tuser       )     
            );
          else
            axis_reg_slice_lrelu_dw SLICE_1_1 (
              .aclk           (aclk),                     
              .aresetn        (aresetn),              
              .s_axis_tvalid  (slice_s_valid ),   
              .s_axis_tdata   (slice_s_data [c][g]),    
              
              .m_axis_tready  (m_axis_tready      ),   
              .m_axis_tdata   (m_axis_tdata [c][g])
            );
        end
        else begin
          assign m_axis_tvalid       = slice_s_valid       ; 
          assign slice_s_ready       = m_axis_tready       ; 
          assign m_axis_tdata [c][g] = slice_s_data [c][g] ; 
          assign m_axis_tlast        = slice_s_last        ; 
          assign m_axis_tuser        = dw_m_user [0][0]    ; 
        end
      end
    end
  endgenerate

endmodule